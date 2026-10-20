# Barforge Changelog

Changes made only in the [rfoerthe/barforge](https://github.com/rfoerthe/barforge)
fork. Everything else comes from upstream
[vorssaint/vorssaint-utils](https://github.com/vorssaint/vorssaint-utils) and is
recorded in [CHANGELOG.md](CHANGELOG.md), which stays identical to upstream.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Barforge numbers its own releases with [semantic versioning](https://semver.org),
starting at 1.0.0. Each release names the Vorssaint release it is made from on a
line of its own, `Based on Vorssaint X.Y.Z.`, matching `BarforgeUpstreamVersion`
in `Resources/Info.plist`. The app's release notes and What's New show a
release's entries from this file first, then the notes of the Vorssaint releases
it brings: those after the previous release's base up to its own, read from
CHANGELOG.md.

## [1.0.0] - 2026-10-20

Based on Vorssaint 3.4.1.

### Added
- Logitech MX Master 3, 3S and 4 mice can give every button, the gesture or thumb button and the thumb wheel an action, with gesture sets for windows, media, zoom and panning, over a Bolt or Unifying receiver or Bluetooth. Settings → Mouse & Trackpad → Logitech MX mice.
- The same panel sets pointer speed and a second speed to switch to, SmartShift and its sensitivity, scrolling force and wheel direction, and on the MX Master 4 haptic feedback and the haptic sense panel's pressure point. Each connected mouse shows its battery charge.
- The System card lists each fan and its current speed. Settings → Monitor → System → Fan speed.

### Changed
- Barforge needs macOS 26 Tahoe or later.
- The fork is called Barforge, with its own anvil icon and the bundle identifier `de.foerther.barforge`, as Vorssaint's trademark policy asks of forks. It installs as Barforge.app and shares no settings or permissions with Vorssaint or an earlier build of the fork: export your settings there under Settings → Advanced → Backup, remove an earlier fork build with its fan helper (Settings → Advanced → Uninstall completely), then install Barforge, import the settings and grant its permissions again.
- A new app icon: a lit, bevelled anvil on a light tile. The Dock icon on macOS 26 shows the anvil in two tones, its lit top and bevels lighter than the body, and keeps its light, dark and tinted looks, and the menu bar icon and the in-app mark take the new anvil outline.
- Barforge has its own version numbers, starting with 1.0.0, based on Vorssaint 3.4.1. Settings → About shows both. Release notes and What's New list Barforge's changes first, then those of the Vorssaint releases a version brings.
- Settings → About names Vorssaint as the original project, says Barforge is an unofficial version it does not endorse, and links the GPL. GitHub links lead to rfoerthe/barforge.
- Barforge does not update itself, so no Vorssaint release replaces it: new versions come from its releases page, and the menu bar icon's right-click menu offers no Check for updates….
- Settings no longer offers donations, Discord or X for the original project, and no support note follows an update.
- The speed test in the Network card measures latency, download and upload one after the other, each as a bar with its value in ms or Mbps, updated four times a second while it runs; download and upload take about ten seconds each, and their result is the mean of the readings after the first 2.5 seconds of ramp-up. Results on fast fibre lines now match breitbandmessung.de: about 6 ms, 1000 to 1060 and 545 Mbps on a 1000/500 line, where the test showed 65 ms, 394 and 198 Mbps before. It measures against Apple's networkQuality servers and falls back to Cloudflare when they do not answer, and a running test can be stopped.
- The Network card's apps using network list starts folded behind an arrow, like the CPU apps list. Per-app traffic is measured only while the list is open.

### Removed
- Fan Control. Barforge no longer sets fan speeds or temperature curves and ships no privileged fan helper, so it never asks to add a background item for one and never writes to the SMC. Fan speeds stay visible, read-only, in the System card and the menu bar; outside the System card they follow the CPU monitor in Settings → Features. Leftover Fan Control settings are deleted on first launch.
- The Dynamic Island, with all its extensions: music, lyrics, queue and live equalizer, notifications, calendar, timers, accessories, downloads and file tools, gestures, the mascot and the AI agents readout for Claude, Codex, OpenCode and GitHub Copilot. Its Settings pages, the features-hub card, the island tour after updates and the brightness prompt go with it. Barforge no longer asks for calendar access, ships no Now Playing adapter and no AI price list, and opens no connection for lyrics, covers, AI prices or agent limits. Command Bar, Shelf, Screenshot, Camera preview, Scratchpad, Quick Launcher, the mixer and brightness keys keep working in their own windows.
- The radial menu's Now Playing item. The Media preset starts with play/pause, next and previous track; a Now Playing item in a saved wheel is dropped.
- The orange and red low-battery color of the menu bar's battery reading, which the island's battery thresholds set.
- Leftover Dynamic Island settings are deleted on first launch.
