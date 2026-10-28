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

## [1.0.4-beta.3] - 2026-10-28

Based on Vorssaint 3.4.2.

### Added
- The menu panel's mixer sliders can be adjusted with a mouse wheel or trackpad. Thanks to @JB-OD.
- An optional Zoom feature turns a modifier and mouse-wheel movement into app zoom or pinch gestures, with separate controls and scroll exceptions. Thanks to @ahmadhatahet.
- An optional Quit apps panel can request normal quits for one app, all apps or all except the current app, with a saved list of apps to keep running. Thanks to @thedankest.
- Command Bar converts days, weeks and fixed 365-day years, with English and Portuguese unit names. Thanks to @asim-sde.
- Settings backups can be exported or imported with `--export-settings FILE` and `--import-settings FILE`; importing requires the app to be closed. Thanks to @DrakeEvans.
- Clipboard history can show source app icons in list view. The option starts off and preserves file icons and selection controls. Settings → Clipboard history → Show source app icons in list view. Thanks to @ywu73.

### Changed
- Barforge brings the further changes Vorssaint made since 1.0.4-beta.2, listed here, except those for the Dynamic Island, which Barforge does not include.
- Homebrew opens installer, setup and password-required commands in the default app for Unix executables, without Terminal Automation consent. Barforge no longer asks for Automation access to Terminal. Thanks to @hertza-haeon.
- Snippet lists in Settings and the library use alphabetical order. Thanks to @Zekuath.
- The window switcher allows up to 10 columns while preserving Auto and screen-width limits. Settings → Window switcher → Options → Maximum columns. Thanks to @EugeneCarldotme.

### Fixed
- The radial menu's action editor keeps its file picker over the editor window, avoiding an invisible panel on multi-display setups. Thanks to @saiganeshreddy7.
- Mic Mute describes its device-control limits and reports known failures even when no microphone could be changed. Siri and some apps may still hear audio. Thanks to @sarat03 for the diagnosis.
- The onboarding feature picker stays responsive when scrolling. Thanks to @yousefhamza.
- Ultra-wide wallpaper previews stay within their own grid cells. Thanks to @ozanuslan.
- Command Bar finds English built-in commands and system answers when the interface uses another language. Thanks to @ywu73.
- Extra Brightness keeps app windows visible in Mission Control's desktop thumbnails. Thanks to @othmanehousni.

## [1.0.4-beta.2] - 2026-10-25

Based on Vorssaint 3.4.2.

### Added
- Screenshots can copy only image data, without a file URL, for apps that otherwise paste the file instead of its image. Settings → Screenshot → Copy as image only.
- Quit on close can handle selected menu bar apps that keep a Dock icon after their last window closes. The list starts empty, and existing exceptions still apply. Settings → Quit on close → Menu bar apps to quit.
- Window layout can reserve space for Stage Manager when maximizing or arranging windows, including the green-button override. Settings → Window layout → Reserve space for Stage Manager.
- Switch Spaces by dragging a button now accepts the middle mouse button, including upward drags for Mission Control and downward drags for App Exposé. A short click keeps its normal behavior. Settings → Mouse → Mouse button shortcuts.
- Volume mixer has its own slider for the alert volume under System sounds, the level macOS uses for alerts and sound effects.

### Changed
- Barforge brings the further changes Vorssaint made after 3.4.2, listed here, except those for the Dynamic Island and Fan Control, which Barforge does not include.
- Clipboard history uses a smaller decoded-thumbnail cache while keeping the window preview cache unchanged.
- Shelf's Remove items after dropping explains that holding ⌥ Option while dragging always copies files instead of moving them.

### Fixed
- Features keeps its rows and scroll position stable when restart and unused-feature notices change.
- The window switcher can travel directly to fullscreen and hidden-Space windows, recover their titles and observe closing without repeating a delivered close request.
- Opening the window switcher uses fewer Accessibility requests when many windows are open.
- The window switcher's search field stays within its panel and remains readable on light backgrounds and Liquid Glass.
- Focus follows mouse preserves window order when Bring the window to the front is off.
- Quit on close ignores confirmed stale surfaces left by closed windows while preserving minimized windows and windows on other Spaces.
- The menu bar panel recovers from interrupted closes so later clicks can open it again.
- Recent captures keeps its Clear history confirmation open and removes a pending confirmation when the palette closes.
- The screenshot editor copies the latest edits when an earlier automatic copy is still pending.
- Volume mixer preserves gain on supported multichannel outputs and rebuilds its audio capture when device formats or sample rates change.
- Disk-space alerts refresh capacity readings and avoid treating a smaller capacity estimate as the only available free space.
- System monitor recognizes the alternate M1 CPU sensor layout and the measured 14-core M4 Max configuration while preserving readings on other Max models.
- Power can use desktop DC input when the adapter reading is unavailable, without presenting it as system-only consumption.
- Scrolling screenshots preserve the selected width, keep sparse Terminal output aligned and continue through smaller overlaps on long pages, including blank spacing and low-contrast content.
- Volume mixer leaves Discord and Teams audio untouched by default to prevent call echo when sharing audio. Their app menus can re-enable volume control, with a reminder to turn it off before sharing; saved levels and outputs are preserved.
- Volume mixer no longer cuts off buffered sound or replays it late after short gaps in captured audio.
- Screen recordings avoid loud noise from 16-bit USB microphones.

## [1.0.4-beta.1] - 2026-10-24

Based on Vorssaint 3.4.2.

### Changed
- The menu bar icon's right-click menu is grouped more clearly. Keep awake stays at the top, followed by Settings…, About Barforge and Check for updates…, then the tools from Homebrew to Open shelf, and Quit Barforge at the bottom, each group set apart by a separator.
- The right-click menu's Kill Process entry reads Kill Process…, since it opens a list to pick from.

## [1.0.3] - 2026-10-24

Based on Vorssaint 3.4.2.

### Added
- The menu bar icon's right-click menu has Homebrew, Kill Process and Port Manager entries above Uninstall an app…, each opening Settings on its page. Each appears only while its feature is installed.

### Changed
- Barforge is based on Vorssaint 3.4.2 and also brings the changes Vorssaint made after it so far. Both are listed here, except those for the Dynamic Island, which Barforge does not include.
- Barforge has beta versions. They are offered only with Settings → About → Updates → Receive beta updates switched on, which a beta turns on by itself; Barforge 1.0.3 and other stable versions do not receive them otherwise.
- Command Bar accepts British unit spellings and spaced fluid-ounce names.
- The window switcher's icon row, previews and hints use Liquid Glass when available and enabled.
- An available update no longer turns the menu bar icon blue, which barely stood out on a blue menu bar. The banner in the menu bar panel still announces it, and the icon stays shown while one is waiting even when it is set to hide beside the menu bar metrics.
- Feedback goes to Barforge instead of the Vorssaint project. Continue on GitHub in the feedback window opens the bug report or feature request form of rfoerthe/barforge in the browser, filled in with the text and, if selected, the technical details, and the issue is filed only once it is submitted there. Issues are public and can be answered. A text too long for the link is put on the clipboard to paste into the form.
- Check for updates… in the menu bar icon's right-click menu opens Settings on About, where the Updates section shows the check and its result.

### Fixed
- After the menu bar icon was clicked several times in a row, a click on an entry in the menu bar panel could close the panel instead of opening the entry.
- The cleaner leaves system log files out of app leftovers.
- Command Bar handles extreme date offsets without crashing and keeps tiny non-temperature unit conversions from reading as zero.
- Clipboard history ignores marked temporary content and restores the previous copy without another notice, while preserving ordinary copies and sensitive-text filtering.
- Pinned GPU, temperature and fan menu bar readings follow the selected System monitor update interval.
- Volume mixer recognizes headphones from their Core Audio device information, including models whose names do not say headphones.
- Screenshot area selection keeps its crosshair over other apps, and card shadows follow the captured window's own rounded corners.
- Looking for updates with beta updates switched on no longer reports "Check failed: -" when GitHub briefly answers with an empty list of releases; Barforge asks again a few seconds later. A check that does fail names the reason, such as the HTTP status.

## [1.0.3-beta.2] - 2026-10-23

Based on Vorssaint 3.4.2.

### Changed
- Barforge brings the changes Vorssaint made after 3.4.2 so far, listed below, except the one for the Dynamic Island, which Barforge does not include.
- Command Bar accepts British unit spellings and spaced fluid-ounce names.
- The window switcher's icon row, previews and hints use Liquid Glass when available and enabled.
- An available update no longer turns the menu bar icon blue, which barely stood out on a blue menu bar. The banner in the menu bar panel still announces it, and the icon stays shown while one is waiting even when it is set to hide beside the menu bar metrics.
- Feedback goes to Barforge instead of the Vorssaint project. Continue on GitHub in the feedback window opens the bug report or feature request form of rfoerthe/barforge in the browser, filled in with the text and, if selected, the technical details, and the issue is filed only once it is submitted there. Issues are public and can be answered. A text too long for the link is put on the clipboard to paste into the form.
- Check for updates… in the menu bar icon's right-click menu opens Settings on About, where the Updates section shows the check and its result.

### Fixed
- The cleaner leaves system log files out of app leftovers.
- Command Bar handles extreme date offsets without crashing and keeps tiny non-temperature unit conversions from reading as zero.
- Clipboard history ignores marked temporary content and restores the previous copy without another notice, while preserving ordinary copies and sensitive-text filtering.
- Pinned GPU, temperature and fan menu bar readings follow the selected System monitor update interval.
- Volume mixer recognizes headphones from their Core Audio device information, including models whose names do not say headphones.
- Screenshot area selection keeps its crosshair over other apps, and card shadows follow the captured window's own rounded corners.
- Looking for updates with beta updates switched on no longer reports "Check failed: -" when GitHub briefly answers with an empty list of releases; Barforge asks again a few seconds later. A check that does fail names the reason, such as the HTTP status.

## [1.0.3-beta.1] - 2026-10-21

Based on Vorssaint 3.4.2.

### Changed
- Barforge is based on Vorssaint 3.4.2 and brings its changes listed below, except those for the Dynamic Island, which Barforge does not include.
- Barforge has beta versions. They are offered only with Settings → About → Updates → Receive beta updates switched on, which a beta turns on by itself; Barforge 1.0.2 and other stable versions do not receive them otherwise.

## [1.0.2] - 2026-10-20

Based on Vorssaint 3.4.1.

### Changed
- Barforge updates itself again, from the releases of rfoerthe/barforge. It looks for a new version after launch and then hourly, and installs one only when the disk image and the app inside are signed with the same Developer ID as the running Barforge and notarized by Apple, so a Vorssaint release never replaces it. Settings → About → Updates switches the check off, includes betas and shows the release notes first, as in Vorssaint, and the menu bar icon's right-click menu offers Check for updates… again. Barforge 1.0.1 and earlier do not update themselves: install 1.0.2 once from the releases page, and later versions arrive on their own.
- A build that is not signed with a Developer ID says in Settings → About → Updates that it cannot update itself.
- Settings in the menu bar panel, and every other way to open Settings, closes the panel, so only the Settings window stays on screen. The panel can still be opened again beside it.

## [1.0.1] - 2026-10-20

Based on Vorssaint 3.4.1.

### Changed
- The menu bar icon and the in-app mark show the anvil with a window through its waist, so the one-color mark no longer reads as a solid blot. The app icon stays as it is.
- The About tab, onboarding and What's New show the full-resolution app icon, the same picture as the README logo, instead of the one-color mark on a dark tile.
- The menu bar panel no longer shows the mark above its tabs, so the panel starts right with the tab bar.

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
