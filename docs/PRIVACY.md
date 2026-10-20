# Privacy

Barforge is built to be local-first. Core features run on your Mac, and the app has no account or cloud dashboard. Barforge operates no servers of its own: temporary screenshot and recording links and feedback you explicitly choose to send go to services operated by the Vorssaint project.

## The short version

- **No account.** There is nothing to sign up for and nobody to log in as.
- **No subscription.** The app is free and stays free, with nothing held back behind a paid tier.
- **No automatic telemetry.** Barforge gathers no usage stats, crash reports or device identifiers. Feedback sends technical details only when you select them after seeing the complete list.
- **No Barforge analytics or tracking.** There are no analytics kits, no ad networks and no third party tracking anywhere in the app.
- **No data selling.** Barforge never sells personal information or shared screenshots and recordings.
- **Your settings stay put.** Preferences and saved state live in the app's own local storage on your Mac and are never uploaded.

## What it reads, and where that stays

Everything Barforge shows you, from the CPU and memory load to the temperatures, the battery details, the network rates, the window list, per app volume and the files on the Shelf, is read locally through native macOS APIs and shown to you right there. Those readings are not uploaded automatically.

Clipboard history, including the images and files you copy, lives in the app's local storage on your Mac and never leaves it. Content marked as confidential by its source app is never recorded. Guessing sensitive content from the text is optional and off by default; unmarked passwords can be saved when it is off. Copy text from screen recognizes the text entirely on device with Apple's Vision framework, and the temporary capture is deleted as soon as the text is read. Automatic clearing, when you switch it on, only empties the system clipboard on this Mac: nothing is sent anywhere, and items already saved to your history are left as they are.

Command Bar saves how often you choose an item and a limited set of associations between typed search prefixes and the items you chose, so app and emoji ranking survives a restart. It stores keyed digests of those prefixes locally, not the search text itself, and excludes this learning and its local key from settings backups. You can clear it with Forget learned ranking in Command Bar settings.

Recent Captures keeps up to 12 screenshots, within a 256 MB limit, in the app's private local cache so you can reopen them. Recordings are not duplicated: only their existing path and a small thumbnail are kept. Clear removes that history and its cached images. When a screenshot is copied as a file, its private local PNG is kept temporarily so other apps can finish reading it, then cleaned on later copies once it is older than 24 hours or earlier when the bounded cache fills. None of these local caches is uploaded automatically.

When a feature needs a macOS permission such as Accessibility, Screen Recording or Microphone, that access is used only for the feature it belongs to. Captured content leaves the Mac only when you explicitly share it, from the Share menu or with a temporary link, and the audio of apps you route to AirPlay goes only to the speaker you pick on your local network. The [permissions guide](PERMISSIONS.md) breaks down each permission.

The camera mirror starts only after an explicit action. Its frames go to the local preview and are not saved or uploaded by that feature. Closing the preview, disabling it or locking the Mac stops capture.

## Network connections

Barforge opens only a few kinds of connection, and each one belongs to a visible feature.

1. **No update check.** Barforge does not check for updates and never asks GitHub's releases API on its own. New versions come from the fork's [releases page](https://github.com/rfoerthe/barforge/releases).

2. **The internet speed test, only when you ask.** The optional speed test in the Network section measures latency and your download and upload throughput against Apple's servers at `mensura.cdn-apple.com`, the ones macOS's own `networkQuality` tool uses. If they cannot be reached, it falls back to Cloudflare's public speed endpoints at `speed.cloudflare.com`. This happens only when you start a test yourself, and never on its own. Download and upload run for about ten seconds each, so on a fast line a test moves a gigabyte or more; keep that in mind on a metered connection. The upload is zeros, never your data.

3. **Homebrew actions, only when you use the Homebrew manager.** Search, install and uninstall actions run the local `brew` command, which may contact Homebrew, GitHub and package vendor hosts to search metadata or download files. Popularity badges use Homebrew's public aggregate analytics JSON from `formulae.brew.sh`. Barforge does not send its own analytics, capture passwords or run `brew` as root.

4. **The app update check, only with App updates switched on.** Finding out which apps are behind uses the sources you leave enabled. The Homebrew source runs the local `brew` command, exactly as above. The App Store source sends store identifiers to `uclient-api.itunes.apple.com`, falling back to bundle identifiers at `itunes.apple.com`, along with your Mac's region, to find the current Mac version.

The Online source checks supported public update addresses declared inside installed apps. These requests go to the app developer's server or its release hosting service, including `github.com` and redirected download hosts. The server receives your public IP address and the requested URL, which can reveal which app is being checked. Barforge does not add your app inventory, local paths, account details or device identifiers to these requests, and does not use stored cookies or credentials. The declared URL, including any query parameters it already contains, is sent as provided by the app. These services may process ordinary request data under their own privacy policies.

The Online source also downloads the complete public app catalog from `formulae.brew.sh` as a fallback. That catalog request does not send the names, paths or bundle identifiers of apps on your Mac. Version comparisons happen locally; updates from developer feeds are installed by the app's own updater after you open it.

The check runs when you open the list or press Check now, and on a schedule only if you set one. The three source switches under App updates control these connections independently. Turning off the App Store source stops its store and bundle identifier lookups. Turning off the Online source stops both developer feed requests and public catalog requests on subsequent checks.

5. **Temporary screenshot links, only when you choose to create one.** Creating a link sends the rendered PNG and your chosen expiration of 1, 6 or 24 hours to the Vorssaint service over HTTPS. It does not send your name, account, device identifier or MAC address. On your Mac, the feature keeps only the link, expiration and private deletion token while the link is active, so you can copy it or delete it early. The service holds your public IP address in memory for no more than 24 hours to prevent abuse, while network providers may process normal HTTPS request data under their own policies.

The uploaded PNG is decoded and rebuilt without embedded metadata. The image and its link metadata are permanently deleted when the link expires or you delete it, and the service does not create screenshot backups. Private moderation stores the active link, not another uploaded image, and removes that message when the link ends. Anyone with the link can view, download, save or redistribute the image, and active links are available to the service operator for abuse moderation. Share only with people you trust.

6. **Temporary recording links, only when you choose to create one.** The finished video is compressed on your Mac and sent over HTTPS with the audio you kept and your chosen expiration of 1 or 6 hours. It does not send your name, account or device identifier. On your Mac, the feature keeps only the link, expiration and private deletion token while the link is active. The service temporarily processes your public IP address to prevent abuse, while network providers may process normal HTTPS request data under their own policies.

The service validates and rebuilds the MP4 without its original metadata. The video and link metadata are permanently deleted when the link expires or you delete it, and the service does not create backups. Anyone with the link can view, download, save or redistribute the video, and active links are available to the service operator for abuse moderation. Share only with people you trust.

7. **Feedback, only when you press Send.** A submission sends the category you choose and the text you type. The optional technical details switch adds only the app version and build, macOS version, Mac model and app language shown in the form. It never includes your name, account, email address, device identifier, logs, screenshots, files or clipboard content. Your public IP address is processed temporarily in memory for rate limiting and is not attached to the feedback.

Feedback is delivered to private support channels visible to the service owner. After delivery, the text and any technical details you selected remain there until the service owner deletes them. The temporary delivery copy is then deleted; if delivery never succeeds, that copy is permanently deleted after 7 days. No contact information is sent, so feedback cannot receive a direct reply.

8. **Per-app AirPlay, only while you route an app to AirPlay.** The audio of the apps you set to AirPlay in the Volume Mixer is streamed, from memory, to the AirPlay speaker you pick on your local network. Barforge hands it to macOS's own AirPlay stack, which finds the speaker and makes the connection; Barforge does not contact the speaker or any other address itself, and nothing leaves your local network through this feature. Only the routed apps' audio is sent. It is not saved or recorded, and streaming stops as soon as no app is routed to AirPlay or the speaker is disconnected.

That is the entire list. There are no hidden beacons or background uploads.

## Changes to this document

This page describes how the current version of Barforge behaves. If the app's behavior around privacy ever changes, this page changes with it.

## Questions

If anything here is unclear, open a question in [GitHub issues](https://github.com/rfoerthe/barforge/issues), or have a look at [support](../SUPPORT.md).
