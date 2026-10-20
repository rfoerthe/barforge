#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Roland Foerther

# Builds a signed, notarized DMG on this Mac with your own Developer ID, the way
# the release workflow does for the official app: build, sign, notarize and
# staple the app, package the DMG, sign, notarize and staple it, then verify
# that Gatekeeper accepts both. The result is dist/Barforge-<version>.dmg.
#
# One-time setup:
#   1. A "Developer ID Application" certificate with its private key in the
#      login keychain (Xcode → Settings → Accounts → Manage Certificates → +).
#   2. Notarization credentials stored in the keychain under a profile name:
#        xcrun notarytool store-credentials vorssaint-notary \
#            --key AuthKey_XXXXXXXXXX.p8 --key-id XXXXXXXXXX --issuer <issuer-uuid>
#      or, with an app-specific password instead of an API key:
#        xcrun notarytool store-credentials vorssaint-notary \
#            --apple-id you@example.com --team-id <TEAMID>
#
# Options:
#   --skip-notarize   sign only (Gatekeeper still warns on other Macs)
#   --allow-dirty     build from a working tree with uncommitted changes
#
# Environment:
#   SIGNING_IDENTITY  the identity to use when several Developer IDs are
#                     installed (default: the only one)
#   NOTARY_PROFILE    the notarytool keychain profile (default: vorssaint-notary)
set -euo pipefail
umask 022
cd "$(dirname "$0")/.."

NOTARIZE=1
ALLOW_DIRTY=0
for arg in "$@"; do
    case "$arg" in
        --skip-notarize) NOTARIZE=0 ;;
        --allow-dirty)   ALLOW_DIRTY=1 ;;
        -h|--help)       sed -n '5,27p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "✗ unknown option: $arg" >&2; exit 1 ;;
    esac
done

APP_NAME="Barforge"
APP="build/stage/$APP_NAME.app"
APP_BUNDLE_ID="de.foerther.barforge"
NOTARY_PROFILE="${NOTARY_PROFILE:-vorssaint-notary}"
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

# ── Preflight ────────────────────────────────────────────────────────────────
IDENTITIES=("${(@f)$(security find-identity -v -p codesigning 2>/dev/null \
    | grep 'Developer ID Application' | sed -E 's/.*"(.*)".*/\1/' || true)}")
IDENTITIES=(${(u)IDENTITIES:#})
if (( ${#IDENTITIES} == 0 )); then
    echo "✗ No valid \"Developer ID Application\" identity in the keychain." >&2
    echo "  Create one in Xcode → Settings → Accounts → Manage Certificates → +." >&2
    exit 1
fi
IDENTITY="${SIGNING_IDENTITY:-}"
if [[ -z "$IDENTITY" ]]; then
    if (( ${#IDENTITIES} > 1 )); then
        echo "✗ Several Developer ID identities are installed; pick one with SIGNING_IDENTITY:" >&2
        printf '    %s\n' "${IDENTITIES[@]}" >&2
        exit 1
    fi
    IDENTITY="${IDENTITIES[1]}"
elif (( ! ${IDENTITIES[(Ie)$IDENTITY]} )); then
    echo "✗ SIGNING_IDENTITY \"$IDENTITY\" is not a valid Developer ID identity here." >&2
    exit 1
fi
# build.sh signs with the first Developer ID it finds; with several installed it
# could pick another one than this script. The requirement check below would
# catch that, but only after a full build.
if [[ "$IDENTITY" != "${IDENTITIES[1]}" ]]; then
    echo "✗ build.sh would sign with \"${IDENTITIES[1]}\", not \"$IDENTITY\"." >&2
    exit 1
fi
TEAM_ID="$(sed -nE 's/.*\(([A-Z0-9]{10})\)$/\1/p' <<< "$IDENTITY")"
if [[ -z "$TEAM_ID" ]]; then
    echo "✗ Cannot read the Team ID from \"$IDENTITY\"." >&2
    exit 1
fi
APP_REQUIREMENT="identifier \"$APP_BUNDLE_ID\" and anchor apple generic and certificate leaf[subject.OU] = \"$TEAM_ID\""
DMG_REQUIREMENT="anchor apple generic and certificate leaf[subject.OU] = \"$TEAM_ID\""

if (( NOTARIZE )) && ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    echo "✗ notarytool cannot use the keychain profile \"$NOTARY_PROFILE\"." >&2
    echo "  Store credentials once (see the top of this script), or pass --skip-notarize." >&2
    exit 1
fi

if (( ! ALLOW_DIRTY )) && [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
    echo "✗ The working tree has uncommitted changes; commit them or pass --allow-dirty." >&2
    exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)"
echo "▸ Releasing $APP_NAME $VERSION ($(git rev-parse --short HEAD 2>/dev/null || echo unknown))"
echo "  identity: $IDENTITY"
(( NOTARIZE )) && echo "  notary profile: $NOTARY_PROFILE" || echo "  notarization: skipped"

# Submits a zip/dmg, waits for the verdict and prints Apple's log when it is
# not accepted, since notarytool's own exit status does not say so reliably.
notarize() {
    local target="$1" submit="$1" result verdict id
    if [[ "$target" == *.app ]]; then
        submit="$WORK/$(basename "$target").zip"
        rm -f "$submit"
        /usr/bin/ditto -c -k --keepParent "$target" "$submit"
    fi
    echo "▸ Notarizing $(basename "$target") (usually a few minutes)…"
    result="$WORK/notary.json"
    xcrun notarytool submit "$submit" --keychain-profile "$NOTARY_PROFILE" \
        --wait --output-format json > "$result"
    verdict="$(plutil -extract status raw -o - "$result" 2>/dev/null || echo unknown)"
    id="$(plutil -extract id raw -o - "$result" 2>/dev/null || true)"
    if [[ "$verdict" != "Accepted" ]]; then
        echo "✗ Notarization of $(basename "$target") ended with status: $verdict" >&2
        [[ -n "$id" ]] && xcrun notarytool log "$id" --keychain-profile "$NOTARY_PROFILE" >&2 || true
        exit 1
    fi
    xcrun stapler staple "$target"
}

# ── App ──────────────────────────────────────────────────────────────────────
echo "▸ Building…"
./build.sh
codesign --verify --deep --strict -R="$APP_REQUIREMENT" "$APP"
# Read the details first: grep -q stops at the match, codesign then dies of
# SIGPIPE, and pipefail would report a correctly signed app as unsigned.
SIGNATURE="$(codesign -dv "$APP" 2>&1)"
if [[ "$SIGNATURE" != *"flags="*"runtime"* ]]; then
    echo "✗ $APP is not signed with the hardened runtime." >&2
    exit 1
fi
./build/$APP_NAME --selftest
(( NOTARIZE )) && notarize "$APP"

# ── DMG ──────────────────────────────────────────────────────────────────────
./Tools/make-dmg.sh
DMG="dist/$APP_NAME-$VERSION.dmg"
[[ -f "$DMG" ]] || { echo "✗ $DMG was not created" >&2; exit 1; }
echo "▸ Signing $(basename "$DMG")…"
codesign --force --timestamp --sign "$IDENTITY" "$DMG"
codesign --verify --strict -R="$DMG_REQUIREMENT" "$DMG"
(( NOTARIZE )) && notarize "$DMG"

# ── Verify what a user downloads ─────────────────────────────────────────────
echo "▸ Verifying…"
MOUNT="$(mktemp -d)"
if diskutil image -h >/dev/null 2>&1; then
    diskutil image attach --nobrowse --readOnly --mountPoint "$MOUNT" "$DMG" >/dev/null
else
    hdiutil attach -nobrowse -readonly -mountpoint "$MOUNT" "$DMG" >/dev/null
fi
codesign --verify --deep --strict -R="$APP_REQUIREMENT" "$MOUNT/$APP_NAME.app"
if (( NOTARIZE )); then
    xcrun stapler validate "$DMG"
    xcrun stapler validate "$MOUNT/$APP_NAME.app"
    spctl -a -t open --context context:primary-signature -vv "$DMG" 2>&1 \
        | tee "$WORK/spctl-dmg.txt"
    grep -q "source=Notarized Developer ID" "$WORK/spctl-dmg.txt"
    spctl -a -t exec -vv "$MOUNT/$APP_NAME.app" 2>&1 | tee "$WORK/spctl-app.txt"
    grep -q "source=Notarized Developer ID" "$WORK/spctl-app.txt"
fi
hdiutil detach "$MOUNT" -quiet
rmdir "$MOUNT"
MOUNT=""

( cd dist && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256" )
echo "✓ $( (( NOTARIZE )) && echo 'Signed and notarized' || echo 'Signed (not notarized)'): $DMG"
cat "$DMG.sha256"
