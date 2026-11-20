# Glass UI

**The rest of the interface, in liquid glass.**

**Glass UI** reskins **World of Warcraft: Forever**'s own windows in liquid glass: the merchant,
your bags, the character window, the world map, the quest dialogs, the guild window and more. It's
a reskin only. Every window works exactly as before; Glass UI only changes how it looks, and each
window's skin has its own switch.

If you use other Glass addons, Glass UI is also their home: one glass and one look for the whole
family, and their settings under one "Glass UI" entry. It's optional both ways. Every Glass addon
works without Glass UI, and Glass UI works without any of them.

## What it does

**Blizzard's windows, in glass.** Each window gets a glass body with a smoky title band. Its
portrait sits on a glass disc, and its close button is glass too. Item slots become glass wells,
and buttons and tabs sit on small glass. The text keeps Blizzard's fonts and colours, so
everything reads the way you're used to.

| Window | Switch |
|---|---|
| Merchant | `merchant` |
| Bags, every bag window and the combined bag | `bags` |
| The Escape menu | `gamemenu` |
| Guild & Communities | `guild` |
| The character window: equipment, stats, reputation, skills | `character` |
| The world map and quest log | `map` |
| The loot window | `loot` |
| Loot rolls (`/loot`) | `loothistory` |
| Trade | `trade` |
| The gossip window | `gossip` |
| The NPC quest dialog | `quest` |
| The quest details popup | `questpopup` |
| Blizzard's damage meter | `meter` |
| The quest tracker | `tracker` |
| The breath, fatigue and feign death timers | `mirror` |
| RestedXP's guide window, when RestedXP is installed | `rxp` |
| RestedXP's waypoint arrow, in the suite accent | `rxparrow` |

**Every skin has a switch.** `/glassui skin bags off` gives a window back its Blizzard look at once,
with no `/reload`, and `/glassui off` does the same for every skin.

**One look for the family.** On the "Suite look" settings page, choose clear, smoked or
class-colour glass, a gold or ice accent for the titles, and how buttons answer the mouse (glass,
soft or minimal). Changes apply at once to Glass UI's skins and to every Glass addon that follows
Glass UI's appearance. The main page lists the family, and you choose there which addons follow
Glass UI and which keep their own settings.

**Light quest text on glass.** An option on the settings page turns on Blizzard's Dark quest text,
so quest pages read well on glass. It's off until you turn it on, and turning it off gives back
the setting you had.

**Steps aside.** When another addon replaces a window, Glass UI leaves that window alone:
- bag addons (Bagnon, Baganator, AdiBags, ArkInventory, BetterBags, EllesmereUI's bags);
- Leatrix Maps' simple map;
- Glass Maps and Glass Quest Tracker, which own their windows.

With ElvUI, EllesmereUI or Tukui loaded, or the gamepad interface on, every skin stays off.
`/glassui skins` says why.

## Install

Install **Glass UI** from [CurseForge](https://www.curseforge.com/wow/addons/glass-ui) with the
CurseForge app, or from [Wago Addons](https://addons.wago.io/addons/mNwwPlNo) with the Wago app.
Both keep it up to date. Or download the zip from
[GitHub Releases](https://github.com/Spotnick2/GlassUI/releases) and unzip it into the
`Interface\AddOns` folder inside your Forever game folder. Then `/reload`, or start the game.

## Getting started

Open any of the windows above: the glass is already there. Use `/glassui options` for the settings
page (Esc > Options > AddOns > Glass UI), or `/glassui help` for every command.

| Command | What it does |
|---|---|
| `/glassui help` | List the commands |
| `/glassui skins` | Every skin and whether it's on |
| `/glassui skin <name> on` / `off` | One window's skin (the names are in the table above) |
| `/glassui on` / `off` | Every skin at once |
| `/glassui theme clear` / `smoked` / `class` | The glass tint |
| `/glassui look` | The suite look: `look tint smoked`, `look preset soft` |
| `/glassui suite` | The Glass addons, and whether each follows Glass UI |
| `/glassui suite follow <addon> on` / `off` | Whether an addon follows Glass UI (after a `/reload`) |
| `/glassui questtext on` / `off` | Light quest text on glass |
| `/glassui options` | The settings page |
| `/glassui failures` | What failed to build, if something did |
| `/glassui version` | The addon's version and the client build |

`/gui` works too.

## Good to know

- **It never changes what a window does.** It doesn't move, resize, open or close Blizzard's
  windows. Edit Mode still places what it places, and addons that improve a window keep working.
- **Light quest text changes one game setting,** Blizzard's Quest Text Contrast. Turn the option
  off before you uninstall Glass UI to get your previous setting back.
- **A window opened in combat** may get its glass a frame after it appears.
- **If a skin fails,** it stops, and `/reload` restores the window. `/glassui failures` says what
  happened.
- **Not in glass yet:** tooltips, the spellbook and talents, the auction house, professions, the
  group finder and the friends list. They keep Blizzard's look for now.
- **This is an early version** (an alpha), tested on the 1.60.1.70888 client.

## Reporting a problem

Found a problem or have an idea? Open an issue on
[GitHub](https://github.com/Spotnick2/GlassUI/issues) with what you did, what you expected and
what happened instead, plus the line from `/glassui version`. A screenshot helps for anything
visual.

Lua errors are hidden by default on this client. If something seems broken, type
`/console scriptErrors 1` and do it again; the error text is the most useful thing you can send.

## Development

- Tests: `pwsh tests/run.ps1` (Lua 5.1, needs LibGlass and ForeverProbe checkouts at `..\LibGlass`
  and `..\ForeverProbe`, or `$env:LIBGLASS` / `$env:FOREVERPROBE`).
- Deploy a dev copy: `pwsh Tools/deploy.ps1 -Probe`.
- [CLAUDE.md](https://github.com/Spotnick2/GlassUI/blob/main/CLAUDE.md) has the conventions,
  [docs/PLAN.md](https://github.com/Spotnick2/GlassUI/blob/main/docs/PLAN.md) the plan and the skin
  contract, and
  [docs/FOREVER-PROBE.md](https://github.com/Spotnick2/GlassUI/blob/main/docs/FOREVER-PROBE.md)
  what was measured on the live client.

## Licence

MIT, see [LICENSE](https://github.com/Spotnick2/GlassUI/blob/main/LICENSE). The embedded
LibGlass-1.0 is MIT too, under its own licence.
