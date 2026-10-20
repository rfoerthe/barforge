#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Roland Foerther

# Publishes a DMG from dist/ as a GitHub release of this fork. Lists the DMGs
# that have a .sha256 file next to them, lets you pick exactly one, checks the
# checksum, the signature and the notarization, reads the version from the app
# inside, tags the commit as v<version>, and creates the release with the DMG
# and its .sha256 attached and the notes from CHANGELOG-BARFORGE.md. The release is
# created as a draft and published only after GitHub reports the same SHA-256
# for every asset, so it also works with immutable releases switched on.
#
# Requirements: the GitHub CLI (gh), signed in with write access to the repo,
# and a DMG from Tools/release-local.sh.
#
# Without an existing tag, the script tags HEAD: the working tree must be clean,
# HEAD must already be pushed, and its Resources/Info.plist and CHANGELOG-BARFORGE.md
# must carry the DMG's version, the changelog entry with a date.
#
# Options:
#   --dry-run   run every check and show what would happen, change nothing
#   --yes       publish without asking for confirmation
#
# Environment:
#   GIT_REMOTE   the remote to tag and release on (default: origin)
#   GITHUB_REPO  owner/name of the repository (default: read from GIT_REMOTE)
set -euo pipefail
umask 022
cd "$(dirname "$0")/.."

DRY_RUN=0
ASSUME_YES=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --yes)     ASSUME_YES=1 ;;
        -h|--help) sed -n '5,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "✗ unknown option: $arg" >&2; exit 1 ;;
    esac
done

APP_NAME="Barforge"
CHANGELOG="CHANGELOG-BARFORGE.md"
GIT_REMOTE="${GIT_REMOTE:-origin}"
WORK=""
MOUNT=""

cleanup() {
    if [[ -n "$MOUNT" ]]; then
        hdiutil detach "$MOUNT" -quiet 2>/dev/null || hdiutil detach "$MOUNT" -force -quiet 2>/dev/null || true
        rmdir "$MOUNT" 2>/dev/null || true
    fi
    [[ -n "$WORK" ]] && rm -rf "$WORK"
    return 0
}
trap cleanup EXIT
trap 'exit 1' INT TERM HUP
WORK="$(mktemp -d)"

die() { echo "✗ $*" >&2; exit 1; }

# ── Preflight ────────────────────────────────────────────────────────────────
command -v gh >/dev/null 2>&1 || die "The GitHub CLI is not installed: brew install gh"
gh auth status >/dev/null 2>&1 || die "The GitHub CLI is not signed in: gh auth login"
git remote get-url "$GIT_REMOTE" >/dev/null 2>&1 || die "There is no git remote \"$GIT_REMOTE\"."

REPO="${GITHUB_REPO:-}"
if [[ -z "$REPO" ]]; then
    REPO="$(git remote get-url "$GIT_REMOTE" | sed -E 's#^(git@[^:]+:|ssh://[^/]+/|https?://[^/]+/)##; s#\.git$##')"
fi
[[ "$REPO" == */* ]] || die "Cannot read owner/name from the remote \"$GIT_REMOTE\"; set GITHUB_REPO."
# Official releases come from .github/workflows/release.yml, signed by the
# upstream team; a local build must never end up there.
[[ "$REPO" != "vorssaint/vorssaint-utils" ]] || die "$REPO is upstream; its releases come from the release workflow."

# ── Pick a DMG ───────────────────────────────────────────────────────────────
DMGS=(dist/*.dmg(N.om))
(( ${#DMGS} )) || die "No DMG in dist/. Build one with ./Tools/release-local.sh."

CANDIDATES=()
SKIPPED=()
for dmg in "${DMGS[@]}"; do
    if [[ -f "$dmg.sha256" ]]; then
        CANDIDATES+=("$dmg")
    else
        SKIPPED+=("$dmg")
    fi
done

echo "DMGs in dist/:"
for (( i = 1; i <= ${#CANDIDATES}; i++ )); do
    dmg="${CANDIDATES[$i]}"
    printf '  %d) %-40s %4d MB  %s\n' "$i" "${dmg:t}" $(( $(stat -f %z "$dmg") / 1048576 )) \
        "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$dmg")"
done
for dmg in "${SKIPPED[@]}"; do
    printf '  -) %-40s no %s, skipped\n' "${dmg:t}" "${dmg:t}.sha256"
done
(( ${#CANDIDATES} )) || die "No DMG in dist/ has a .sha256 file next to it."

if (( ${#CANDIDATES} == 1 )); then
    PROMPT="Which DMG? [1, q to quit, Enter for 1] "
else
    PROMPT="Which DMG? [1-${#CANDIDATES}, q to quit] "
fi
DMG=""
while [[ -z "$DMG" ]]; do
    printf '%s' "$PROMPT"
    read -r CHOICE || die "No DMG chosen."
    [[ -z "$CHOICE" && ${#CANDIDATES} -eq 1 ]] && CHOICE=1
    case "$CHOICE" in
        q|Q) echo "Cancelled."; exit 0 ;;
        <->) (( CHOICE >= 1 && CHOICE <= ${#CANDIDATES} )) && DMG="${CANDIDATES[$CHOICE]}" ;;
    esac
    [[ -n "$DMG" ]] || echo "  Enter one number from the list."
done
DMG_NAME="${DMG:t}"
SHA_FILE="$DMG.sha256"

# ── Verify the DMG ───────────────────────────────────────────────────────────
echo "▸ Checking $DMG_NAME…"
SHA_LINE="$(<"$SHA_FILE")"
SHA="${SHA_LINE%% *}"
[[ "$SHA" =~ ^[0-9a-f]{64}$ && "${SHA_LINE##* }" == "$DMG_NAME" ]] \
    || die "${SHA_FILE:t} does not hold a SHA-256 for $DMG_NAME."
( cd dist && shasum -a 256 -c "${SHA_FILE:t}" >/dev/null ) || die "$DMG_NAME does not match ${SHA_FILE:t}."

xcrun stapler validate "$DMG" >/dev/null 2>&1 || die "$DMG_NAME has no notarization ticket stapled."
SPCTL="$(spctl -a -t open --context context:primary-signature -vv "$DMG" 2>&1 || true)"
[[ "$SPCTL" == *"source=Notarized Developer ID"* ]] || die "Gatekeeper does not accept $DMG_NAME: $SPCTL"
SIGNER="$(sed -n 's/^origin=//p' <<< "$SPCTL")"

MOUNT="$(mktemp -d)"
if diskutil image -h >/dev/null 2>&1; then
    diskutil image attach --nobrowse --readOnly --mountPoint "$MOUNT" "$DMG" >/dev/null
else
    hdiutil attach -nobrowse -readonly -mountpoint "$MOUNT" "$DMG" >/dev/null
fi
APP="$MOUNT/$APP_NAME.app"
[[ -d "$APP" ]] || die "$DMG_NAME does not contain $APP_NAME.app."
codesign --verify --deep --strict "$APP" 2>/dev/null || die "$APP_NAME.app in $DMG_NAME is not validly signed."
xcrun stapler validate "$APP" >/dev/null 2>&1 || die "$APP_NAME.app in $DMG_NAME has no notarization ticket stapled."
SPCTL="$(spctl -a -t exec -vv "$APP" 2>&1 || true)"
[[ "$SPCTL" == *"source=Notarized Developer ID"* ]] || die "Gatekeeper does not accept $APP_NAME.app: $SPCTL"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")"
hdiutil detach "$MOUNT" -quiet
rmdir "$MOUNT"
MOUNT=""
[[ "$DMG_NAME" == "$APP_NAME-$VERSION.dmg" ]] || die "$DMG_NAME holds version $VERSION; expected $APP_NAME-$VERSION.dmg."

TAG="v$VERSION"
PRERELEASE=0
[[ "$VERSION" =~ -(alpha|beta|rc)\. ]] && PRERELEASE=1

# ── Tag ──────────────────────────────────────────────────────────────────────
echo "▸ Checking tag $TAG…"
git fetch -q "$GIT_REMOTE"
REMOTE_TAG_COMMIT="$(git ls-remote --tags "$GIT_REMOTE" "refs/tags/$TAG^{}" | cut -f1)"
[[ -n "$REMOTE_TAG_COMMIT" ]] || REMOTE_TAG_COMMIT="$(git ls-remote --tags "$GIT_REMOTE" "refs/tags/$TAG" | cut -f1)"
LOCAL_TAG_COMMIT="$(git rev-parse -q --verify "refs/tags/$TAG^{commit}" 2>/dev/null || true)"

CREATE_TAG=0
PUSH_TAG=0
if [[ -n "$REMOTE_TAG_COMMIT" ]]; then
    if [[ -z "$LOCAL_TAG_COMMIT" ]]; then
        git fetch -q "$GIT_REMOTE" "refs/tags/$TAG:refs/tags/$TAG"
        LOCAL_TAG_COMMIT="$(git rev-parse "refs/tags/$TAG^{commit}")"
    fi
    [[ "$LOCAL_TAG_COMMIT" == "$REMOTE_TAG_COMMIT" ]] \
        || die "The local tag $TAG and the one on $GIT_REMOTE point to different commits."
    TAG_COMMIT="$REMOTE_TAG_COMMIT"
elif [[ -n "$LOCAL_TAG_COMMIT" ]]; then
    TAG_COMMIT="$LOCAL_TAG_COMMIT"
    PUSH_TAG=1
else
    [[ -z "$(git status --porcelain)" ]] || die "The working tree has uncommitted changes; commit them first."
    TAG_COMMIT="$(git rev-parse HEAD)"
    CREATE_TAG=1
    PUSH_TAG=1
fi

[[ -n "$(git branch -r --contains "$TAG_COMMIT" --list "$GIT_REMOTE/*")" ]] \
    || die "Commit ${TAG_COMMIT:0:8} is on no branch of $GIT_REMOTE; push it first."
TAG_VERSION="$(git show "$TAG_COMMIT:Resources/Info.plist" | plutil -extract CFBundleShortVersionString raw -o - -)"
[[ "$TAG_VERSION" == "$VERSION" ]] \
    || die "Commit ${TAG_COMMIT:0:8} is version $TAG_VERSION, the DMG is $VERSION."

git show "$TAG_COMMIT:$CHANGELOG" > "$WORK/changelog.md"
grep -Fq "## [$VERSION] - " "$WORK/changelog.md" \
    || die "$CHANGELOG at ${TAG_COMMIT:0:8} has no dated entry \"## [$VERSION] - YYYY-MM-DD\"."
NOTES_FILE="$WORK/notes.md"
awk -v hdr="## [$VERSION]" 'index($0,hdr)==1{g=1;next} /^## \[/&&g{exit} g{print}' "$WORK/changelog.md" > "$NOTES_FILE"
[[ -n "$(tr -d '[:space:]' < "$NOTES_FILE")" ]] || die "The $CHANGELOG entry for $VERSION is empty."

# The entry names the Vorssaint release it is made from ("Based on Vorssaint
# 3.4.1."), which must be the bundle's; the next older entry's base marks where
# the Vorssaint releases this one brings begin.
BASE_RE='^Based on Vorssaint ([0-9][^ ]*)\.$'
UPSTREAM_BASE="$(sed -nE "s/$BASE_RE/\\1/p" "$NOTES_FILE" | head -1)"
[[ -n "$UPSTREAM_BASE" ]] || die "The $CHANGELOG entry for $VERSION has no \"Based on Vorssaint X.Y.Z.\" line."
PLIST_BASE="$(git show "$TAG_COMMIT:Resources/Info.plist" | plutil -extract BarforgeUpstreamVersion raw -o - - 2>/dev/null || true)"
[[ "$PLIST_BASE" == "$UPSTREAM_BASE" ]] \
    || die "$CHANGELOG says $VERSION is based on Vorssaint $UPSTREAM_BASE, Info.plist says ${PLIST_BASE:-nothing}."
PREVIOUS_BASE="$(awk -v hdr="## [$VERSION]" 'index($0,hdr)==1{g=1;next} g&&/^## \[/{h=1} h' "$WORK/changelog.md" \
    | sed -nE "s/$BASE_RE/\\1/p" | head -1)"
sed -i '' -E "/$BASE_RE/d" "$NOTES_FILE"
UPSTREAM_URL="https://github.com/vorssaint/vorssaint-utils"
UPSTREAM_NOTE="Based on [Vorssaint $UPSTREAM_BASE]($UPSTREAM_URL/releases/tag/v$UPSTREAM_BASE)."
if [[ -n "$PREVIOUS_BASE" && "$PREVIOUS_BASE" != "$UPSTREAM_BASE" ]]; then
    UPSTREAM_NOTE+=" Brings the Vorssaint releases after $PREVIOUS_BASE: [what changed]($UPSTREAM_URL/compare/v$PREVIOUS_BASE...v$UPSTREAM_BASE) and [their release notes]($UPSTREAM_URL/releases)."
fi
cat >> "$NOTES_FILE" <<EOF

### From Vorssaint

$UPSTREAM_NOTE

Signed with an Apple Developer ID and notarized by Apple. Requires macOS 26 or later. Open the .dmg below and drag $APP_NAME to Applications. $APP_NAME is an unofficial fork of Vorssaint, built from $REPO. It is not an official Vorssaint release and is not endorsed by the Vorssaint project.
EOF

# ── Release ──────────────────────────────────────────────────────────────────
EXISTING_DRAFT=0
if RELEASE_STATE="$(gh release view "$TAG" -R "$REPO" --json isDraft --jq '.isDraft' 2>/dev/null)"; then
    [[ "$RELEASE_STATE" == "true" ]] || die "$REPO already has a published release $TAG: https://github.com/$REPO/releases/tag/${TAG//+/%2B}"
    EXISTING_DRAFT=1
fi

echo
echo "  Repository:  $REPO"
echo "  DMG:         $DMG_NAME (signed by ${SIGNER:-unknown}, notarized)"
echo "  SHA-256:     $SHA"
echo "  Tag:         $TAG → ${TAG_COMMIT:0:8} $(git log -1 --format=%s "$TAG_COMMIT")$( (( CREATE_TAG )) && echo ' (new)' || true)"
echo "  Release:     $( (( EXISTING_DRAFT )) && echo 'update the existing draft' || echo 'new'), $( (( PRERELEASE )) && echo 'pre-release' || echo 'marked as latest')"
echo "  Notes:"
sed 's/^/    │ /' "$NOTES_FILE"
echo

if (( DRY_RUN )); then
    echo "✓ Dry run: everything checks out, nothing was changed."
    exit 0
fi
if (( ! ASSUME_YES )); then
    printf 'Publish %s on %s? [y/N] ' "$TAG" "$REPO"
    read -r ANSWER || ANSWER=""
    [[ "$ANSWER" == [yYjJ]* ]] || { echo "Cancelled."; exit 0; }
fi

if (( CREATE_TAG )); then
    echo "▸ Tagging ${TAG_COMMIT:0:8} as $TAG…"
    git tag -a "$TAG" -m "$APP_NAME $VERSION (fork)" "$TAG_COMMIT"
fi
if (( PUSH_TAG )); then
    echo "▸ Pushing $TAG to $GIT_REMOTE…"
    git push -q "$GIT_REMOTE" "refs/tags/$TAG"
fi

FILES=("$DMG" "$SHA_FILE")
if (( EXISTING_DRAFT )); then
    echo "▸ Uploading to the existing draft…"
    gh release upload "$TAG" "${FILES[@]}" -R "$REPO" --clobber
    gh release edit "$TAG" -R "$REPO" --title "$TAG" --notes-file "$NOTES_FILE" >/dev/null
else
    echo "▸ Creating the draft release and uploading…"
    CREATE_ARGS=("$TAG" "${FILES[@]}" -R "$REPO" --verify-tag --draft --title "$TAG" --notes-file "$NOTES_FILE")
    (( PRERELEASE )) && CREATE_ARGS+=(--prerelease)
    gh release create "${CREATE_ARGS[@]}" >/dev/null
fi

echo "▸ Verifying the uploaded assets…"
RELEASE_ID="$(gh release view "$TAG" -R "$REPO" --json databaseId --jq '.databaseId')"
gh api "repos/$REPO/releases/$RELEASE_ID/assets" --jq '.[] | [.name, .digest] | @tsv' > "$WORK/assets.tsv"
(( $(wc -l < "$WORK/assets.tsv") == ${#FILES} )) \
    || die "The draft has other assets than ${(j:, :)${FILES[@]:t}}; check it on GitHub before publishing."
for file in "${FILES[@]}"; do
    expected="sha256:$(shasum -a 256 "$file" | cut -d' ' -f1)"
    actual="$(awk -F '\t' -v name="${file:t}" '$1 == name { print $2 }' "$WORK/assets.tsv")"
    [[ "$actual" == "$expected" ]] \
        || die "GitHub reports ${actual:-no digest} for ${file:t}, expected $expected. The release stays a draft."
done

echo "▸ Publishing…"
if (( PRERELEASE )); then
    gh release edit "$TAG" -R "$REPO" --draft=false --prerelease --latest=false >/dev/null
else
    gh release edit "$TAG" -R "$REPO" --draft=false --prerelease=false --latest >/dev/null
fi

DOWNLOAD="$(gh release view "$TAG" -R "$REPO" --json assets \
    --jq ".assets[] | select(.name == \"$DMG_NAME\") | .url")"
echo "✓ Published: $(gh release view "$TAG" -R "$REPO" --json url --jq '.url')"
echo "  Download:  $DOWNLOAD"
