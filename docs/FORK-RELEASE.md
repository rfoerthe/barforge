# Signed fork builds

How to build a signed and notarized DMG of this fork on your own Mac with your
own Apple Developer Program membership. The official app is released by
[the release workflow](../.github/workflows/release.yml), which only runs in
upstream [vorssaint/vorssaint-utils](https://github.com/vorssaint/vorssaint-utils).

Before you hand a build to anyone else, read [TRADEMARKS.md](../TRADEMARKS.md):
a redistributed fork needs its own name, icon, bundle identifier and signing
identity. This fork ships as Barforge with its own anvil icon and the bundle
identifier `de.foerther.barforge`; the signing identity is your Developer ID.

## One-time setup

1. **Developer ID Application certificate.** In Xcode → Settings → Accounts,
   select your team, open Manage Certificates and add a *Developer ID
   Application* certificate. Only the account holder can create one. The private
   key exists only in this Mac's login keychain: export the certificate with its
   key as a `.p12` from Keychain Access and keep it somewhere safe.

   ```bash
   security find-identity -v -p codesigning | grep 'Developer ID Application'
   ```

   should list `Developer ID Application: <Name> (<TEAMID>)`. An *Apple
   Development* certificate is not enough: Gatekeeper and the notary service
   accept only Developer ID.

2. **Notarization credentials**, stored once in the keychain under the profile
   name `vorssaint-notary`. Either an App Store Connect API key (App Store
   Connect → Users and Access → Integrations → Team Keys, role *Developer*):

   ```bash
   xcrun notarytool store-credentials vorssaint-notary --key AuthKey_XXXXXXXXXX.p8 --key-id XXXXXXXXXX --issuer <issuer-uuid>
   ```

   or your Apple ID with an app-specific password from
   [account.apple.com](https://account.apple.com):

   ```bash
   xcrun notarytool store-credentials vorssaint-notary --apple-id you@example.com --team-id <TEAMID>
   ```

## Building a release

From a clean, committed working tree:

```bash
./Tools/release-local.sh
```

The script builds the app with `./build.sh` (which picks the Developer ID
automatically, with the hardened runtime and a secure timestamp), checks that
it is signed by your team, notarizes and staples it, packages the DMG, signs,
notarizes and staples that too, and finally checks that Gatekeeper reports
`source=Notarized Developer ID` for both. The result is
`dist/Barforge-<version>.dmg` with a `.sha256` file next to it.

`--skip-notarize` signs without notarizing, for a quick check on your own Mac.
`--allow-dirty` builds from uncommitted changes. With several Developer ID
identities installed, choose one with `SIGNING_IDENTITY`; a different keychain
profile goes in `NOTARY_PROFILE`.

## Publishing on GitHub

Before you publish, give the version a dated entry in
[CHANGELOG-BARFORGE.md](../CHANGELOG-BARFORGE.md), `## [1.0.0] - 2026-10-21` with its `Based on Vorssaint 3.4.1.` line, and
push that commit. Then:

```bash
./Tools/github-release.sh
```

The script lists the DMGs in `dist/` that have a `.sha256` file next to them
and asks you to pick one. It checks the checksum and that Gatekeeper accepts
the DMG and the app inside as notarized, and reads the version from the app.
Unless the tag `v<version>` exists already, it tags HEAD, which must be clean,
pushed and carry the same version in `Resources/Info.plist`. After you confirm,
it pushes the tag, creates a draft release with the DMG and its `.sha256`
attached and the changelog entry as notes, followed by a "From Vorssaint"
section that links the Vorssaint release it is based on and what changed since
the previous release's base. It refuses an entry whose base differs from
`BarforgeUpstreamVersion`, checks that GitHub reports the same
SHA-256 for both files, and publishes it. Versions with `-alpha.`, `-beta.` or
`-rc.` become pre-releases; all others are marked as the latest release.

`--dry-run` runs every check and shows the tag, the release and its notes
without changing anything. `--yes` skips the confirmation. The release goes to
the repository of the `origin` remote; choose another with `GIT_REMOTE` or
`GITHUB_REPO`. Upstream is refused, since its releases come from the release
workflow.

## Team ID

Nothing in the source names your Team ID. Fan Control's app and helper each
read the team that signed them and trust only that team, so a build signed
with any Developer ID works. Builds without a team (ad-hoc or the local
self-signed identity) cannot use Fan Control, as before. The in-app updater
still trusts only the official team, which does not matter here: a fork build
never updates itself.
