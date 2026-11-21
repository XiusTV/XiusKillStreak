# Changelog

All notable changes to Xius Kill Streak are documented here.

## 1.4.0

### Added
- Kill Streak settings now use two Xius Core tabs: General, and Audio & Announcements.
- PvE and PvP filters, plus an option to ignore gray mobs.
- Streak reset timer from 5 to 60 seconds. Later tiers scale down from that base. At 25 seconds the original tier windows are unchanged.
- Banner scale from 50% to 200%, and horizontal and vertical offset sliders.
- Preview tier picker, Test Preview, and Clear Streak on the action row with Reset Position and Defaults.
- Announcer sound channel and a volume control that only affects streak calls.
- Optional chat callouts on each tier: local chat, emote, say, yell, party, or raid / instance. Group channels fall back to local chat when you are not in a group.
- Optional voice emote on each tier (Roar, Cheer, Victory, Flex, Charge, or Laugh).
- A switch for each tier. A disabled tier stays silent while the streak counter and timer keep advancing.
- The banner and counter register with Xius Core frame movers.
- Addon-list icon and a gold-and-red title.

### Changed
- Startup looks for XiusCore only. XiusUI is no longer treated as a substitute.
- The retail manifest also loads on Forever and Camelot, and lists interface 120100 alongside 120105, 120107, and 16001. Options load after Core.
- Protected banner and counter updates still wait until you leave combat.

## 1.3.2

### Changed
- Every script now stops at startup when XiusCore is not loaded.

## 1.3.1

### Changed
- XiusCore is now a required dependency. The addon stops at startup if XiusCore is not loaded, so settings and kill tracking cannot error on their own.

## 1.3.0

### Added
- Ten-tier kill streak announcer for modern World of Warcraft and World of Warcraft Forever.
- Banner and announcer call from Double Kill through Toasty. The first kill has 25 seconds, and each tier after that uses a shorter window.
- Small streak counter that shows the current chain and the time left for the next kill.
- Movable banner and counter. The counter can be resized from the corner while unlocked.
- Options to enable streaks, play announcer sounds, and unlock the frames.
- `/xks` slash commands, including a test for each tier.

### Changed
- Removed unused Blood Crow font styles. The banner still uses Blood Crow Regular and CF Night of the Damned.
