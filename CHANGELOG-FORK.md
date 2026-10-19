# Fork Changelog

Changes made only in the [rfoerthe/vorssaint-utils](https://github.com/rfoerthe/vorssaint-utils)
fork. Everything else comes from upstream
[vorssaint/vorssaint-utils](https://github.com/vorssaint/vorssaint-utils) and is
recorded in [CHANGELOG.md](CHANGELOG.md), which stays identical to upstream.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Fork builds carry the upstream version plus build metadata, such as `3.4.1+mx.1`.

## [Unreleased]

### Added
- The System card lists each fan and its current speed, read-only, without the Fan Control extension. Settings → Monitor → System → Fan speed.

### Changed
- The speed test in the Network card measures latency, download and upload one after the other, each as a bar with its value in ms or Mbps, updated four times a second while it runs; download and upload take about ten seconds each, and their result is the mean of the readings after the first 2.5 seconds of ramp-up. Results on fast fibre lines now match breitbandmessung.de: about 6 ms, 1000 to 1060 and 545 Mbps on a 1000/500 line, where the test showed 65 ms, 394 and 198 Mbps before. It measures against Apple's networkQuality servers and falls back to Cloudflare when they do not answer, and a running test can be stopped.
- The Network card's apps using network list starts folded behind an arrow, like the CPU apps list. Per-app traffic is measured only while the list is open.

### Fixed
- Fan Control works in a build signed with a Developer ID other than the official one, such as a signed build of this fork. The app and its helper now trust the team that signed them instead of a fixed one.
- The menu bar icon's right-click menu no longer offers Check for updates…, since a fork build does not update itself.

## [3.4.1+mx.1]

### Added
- Logitech MX Master 3, 3S and 4 mice can give every button, the gesture or thumb button and the thumb wheel an action, with gesture sets for windows, media, zoom and panning, over a Bolt or Unifying receiver or Bluetooth. Settings → Mouse & Trackpad → Logitech MX mice.
- The same panel sets pointer speed and a second speed to switch to, SmartShift and its sensitivity, scrolling force and wheel direction, and on the MX Master 4 haptic feedback and the haptic sense panel's pressure point. Each connected mouse shows its battery charge.

### Changed
- This build comes from the rfoerthe/vorssaint-utils fork and is versioned 3.4.1+mx.1. GitHub links lead to the fork, and automatic updates are off so no official release replaces it. Settings → About.
