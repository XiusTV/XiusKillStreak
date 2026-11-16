# Xius Kill Streak

A ten-tier kill streak announcer for **modern World of Warcraft** and **World of Warcraft Forever**. Mobs and enemy players both count. Each new tier fills the screen with a banner and an announcer call, and a small counter shows the chain plus the time left to keep it going. Dying clears the streak.

Settings open inside [Xius Core](https://github.com/XiusTV/XiusCore). Xius Core is required.

**Folder name:** `XiusKillStreak`  
**Interface:** `120105`, `120107`, `16001`  
**Commands:** `/xks` · `/xiuskillstreak`  
**Version:** `1.3.1`

## Features

### Escalating streaks

- **Ten tiers:** Double Kill, Triple Kill, Multi Kill, Mega Kill, Ultra Kill, Monster Kill, Godlike, Holy Shit, Finish Him, and Toasty.
- **Tightening window:** The first kill has 25 seconds. Each tier after that allows less time for the next kill, down to 3 seconds at Toasty.
- **One kill, one point:** A killing blow on a mob or an enemy player advances the chain. The same death is counted once.
- **Death resets:** Dying clears the streak.

| Tier | Kills | Next kill within | Call |
| --- | --- | --- | --- |
| 1 | 2 | 22s | Double Kill |
| 2 | 3 | 18s | Triple Kill |
| 3 | 5 | 15s | Multi Kill |
| 4 | 8 | 12s | Mega Kill |
| 5 | 12 | 10s | Ultra Kill |
| 6 | 16 | 8s | Monster Kill |
| 7 | 20 | 6s | Godlike |
| 8 | 25 | 5s | Holy Shit |
| 9 | 30 | 4s | Finish Him |
| 10 | 40 | 3s | Toasty |

The first kill, before any tier, has 25 seconds.

### Banner and counter

- **Banner:** The tier name and kill count. It is the only place the custom fonts are used.
- **Counter:** A small default-styled box, `Streak: 4` and `Next kill: 12s`, shown while a chain is live.
- **Move and resize:** Unlock the frames, drag the banner or the counter, and drag the counter corner to resize it.
- **Sounds:** Each tier plays its announcer call. Sounds can be turned off. The test button still plays.

Counting does not use the combat log. Experience text, the killing-blow float, "You have slain", party kills, honor, and your current target dying cover kills that grant no experience or hide names in combat.

## Controls & Slash Commands

| Command / Input | Action |
| --- | --- |
| `/xks` or `/xiuskillstreak` | Open Kill Streak in Xius Core |
| `/xius streak` | Open Kill Streak in Xius Core |
| `/xks test` | Play the Toasty banner |
| `/xks test 1` through `/xks test 10` | Play that tier |
| `/xks reset` or `/xks clear` | Clear the current streak |
| `/xks unlock` / `/xks lock` | Unlock or lock the banner and counter |
| `/xks resetpos` or `/xks default` | Reset banner and counter position and size |
| `/xks sound` | Toggle announcer sounds |
| `/xks on` / `/xks off` | Enable or disable kill streaks |
| Drag the banner or counter | Move them (when unlocked) |
| Counter corner | Resize the counter (when unlocked) |

## Configuration

Open the page with `/xks` or `/xius streak`. Xius Core has to be installed and enabled.

- **Enable kill streaks:** Count killing blows. Turning this off clears the current streak and hides the banner.
- **Play streak sounds:** Announcer voice on each new tier.
- **Unlock banner and counter:** Drag to move. Drag the counter corner to resize.
- **Test Banner** and **Reset Position**.

Position, size, and these options are saved for the account.

## Installation

1. Install [Xius Core](https://www.curseforge.com/wow/addons/xius-core) first.
2. Download the latest release `.zip` (or use **Code → Download ZIP** on this page).
3. Extract the `XiusKillStreak` folder into your client's addon directory:
   - Forever: `World of Warcraft Forever\Interface\AddOns`
   - Retail: `World of Warcraft\_retail_\Interface\AddOns`
   - If you downloaded the repository ZIP, rename the extracted `XiusKillStreak-main` folder to `XiusKillStreak`.
4. Verify the folder contains `XiusKillStreak.toc`, `Config.lua`, `Banner.lua`, `Options.lua`, and `Core.lua`, plus `Sounds` and `Font`.
5. Launch the game, confirm Xius Core and Xius Kill Streak are checked in your AddOns menu, and run `/reload`.
6. Type `/xks test` to preview Toasty, then `/xks unlock` and drag the banner and counter into place.

**Compatibility:** World of Warcraft Forever (TOC `16001`) and modern retail (TOC `120105`, `120107`). Requires Xius Core.

## More From Xius

### Xius Core - [GitHub](https://github.com/XiusTV/XiusCore) · [CurseForge](https://www.curseforge.com/wow/addons/xius-core)

The settings and quality-of-life hub for the Xius addons. One window holds Quality of Life, General, account gold, and the settings for every other Xius addon you have installed.

### Xius Threat Meter - [GitHub](https://github.com/XiusTV/XiusThreatMeter) · [CurseForge](https://www.curseforge.com/wow/addons/xius-threat-meter)

A threat meter. Shows who is on the enemy's threat table, how much threat each player and pet has, and warns you before you pull aggro.

### Xius XP & Reputation Tracker - [GitHub](https://github.com/XiusTV/XiusXPTracker) · [CurseForge](https://www.curseforge.com/wow/addons/xius-xp-and-reputation-tracker)

A HUD card for level, XP, rested XP, watched faction, session rates, gold, and time-to-level.

### Xius Marks Bar - [GitHub](https://github.com/XiusTV/XiusMarksBar) · [CurseForge](https://www.curseforge.com/wow/addons/xius-marks-bar)

A raid marking bar. Click the flag for world markers or the star for target markers. Includes 5 / 10 / 20 pull timers, ready check, and role check.

### Xius Max Graphics - [GitHub](https://github.com/XiusTV/XiusMaxGFX) · [CurseForge](https://www.curseforge.com/wow/addons/xius-max-graphics)

Graphics presets for Forever and retail. Ultimate, Balance, and Defaults raise view distance, grass, shadows, water, and image clarity, with optional loot and gathering sparkles.

Their settings open from Xius Core.

## Credits

The banner title uses CF Night of the Damned. The banner subtitle uses Blood Crow by Iconian Fonts (Daniel Zadorozny). Blood Crow may be freely distributed for non-commercial use.

## License

Released under the [GNU General Public License v3.0](LICENSE).

## Development & AI Disclosure

This addon was built and refactored with the assistance of AI development tools (Cursor / LLMs) for code generation, UI layout structure, and kill-tracking flow, with manual architecture, in-game verification, and maintenance by Xius.
