# Signed fork builds

How to build a signed and notarized DMG of this fork on your own Mac with your
own Apple Developer Program membership. The official app is released by
[the release workflow](../.github/workflows/release.yml), which only runs in
upstream [vorssaint/vorssaint-utils](https://github.com/vorssaint/vorssaint-utils).

Before you hand a build to anyone else, read [TRADEMARKS.md](../TRADEMARKS.md):
a redistributed fork needs its own name, icon, bundle identifier and signing
identity.

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
`dist/Vorssaint-<version>.dmg` with a `.sha256` file next to it.

`--skip-notarize` signs without notarizing, for a quick check on your own Mac.
`--allow-dirty` builds from uncommitted changes. With several Developer ID
identities installed, choose one with `SIGNING_IDENTITY`; a different keychain
profile goes in `NOTARY_PROFILE`.

## Team ID

Nothing in the source names your Team ID. Fan Control's app and helper each
read the team that signed them and trust only that team, so a build signed
with any Developer ID works. Builds without a team (ad-hoc or the local
self-signed identity) cannot use Fan Control, as before. The in-app updater
still trusts only the official team, which does not matter here: a fork build
never updates itself.
