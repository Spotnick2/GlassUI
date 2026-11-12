# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Glass UI reskins **World of Warcraft: Forever 1.60.1**'s Blizzard windows in liquid glass
(Interface `16001`, **Lua 5.1**), and is an optional hub for the other Glass addons. It has a single
owner (Spotnick) and uses the same stack and conventions as the sibling Forever addons:
`..\GlassQuestTracker` (the closest template: the in-place restyle rule, Compat, tests, tools),
`..\GlassMail` (a window skin, tooling, CI) and `..\LibGlass` (the material, embedded). When this
file doesn't cover something, check how those handle it before you invent a new idiom.

**The plan** is [docs/PLAN.md](docs/PLAN.md) (Codex `gpt-6-astra`, consensus in round 3,
2026-10-15). Measured client facts go in [docs/FOREVER-PROBE.md](docs/FOREVER-PROBE.md).

**Owner decisions (2026-10-15):**
- **No monolith.** Every Glass addon works without Glass UI, and Glass UI works without any of them.
  No `## Dependencies:` between Glass addons, ever: `OptionalDeps` only.
- **Look only, never behaviour.** A skin changes how a window looks, never what it does. An
  improvement is a separate addon that then **owns** the window, and Glass UI steps aside.
- **Every skin can be turned off**, one switch per window plus a master switch.
- **`## Category: |cff7fd4ffGlass|r`** in every Glass addon's TOC (the AddOn list header), never a
  `Group` under Glass UI: GlassPanel's plugins already group under GlassPanel.
- `/glassui` and `/gui` (`/glass` is GlassUnitFrames'). v0.1.0 = wave 1 + hub v1; 1.0.0 at Forever's
  launch. Private repo for now; CurseForge project 1745875.

**Status (2026-10-19):** Glass UI is first the **suite orchestrator**. Done on 70450:
- **suite theme v1** (#24): Pearl, with GlassUnitFrames and GlassRaidFrames following it,
  [docs/SUITE.md](docs/SUITE.md);
- **the group layout** (#28): GRF's continuous grid sized by the group, GUF's player and target
  beside it, GAB's pet and stance bars following, all with the zoom's glide.
  [docs/GROUP-LAYOUT.md](docs/GROUP-LAYOUT.md) records what was measured and what wasn't.

The settings page shows both. The skins are parked: the engine, kit, theme and merchant (#3, #4) are
on `main`, the popups (#5) on branch `popups`, all to be revisited. Measured on 1.60.1.70450.

## The skin contract (non-negotiable)

**Restyle in place; never replace, move, resize or drive a Blizzard window.** The full rule, the
audited exceptions and the reasons are in docs/PLAN.md, "The skin contract". In short:
- **Allowed on Blizzard objects:** `SetAlpha`, `SetVertexColor`, `SetDesaturated`,
  `SetShadowOffset`/`SetShadowColor`, `SetTexture(nil)` and restoring the value we captured,
  getters, `HookScript`, `hooksecurefunc` on a specific instance.
- **Never:** `Show`/`Hide`/`SetShown`/`SetPoint`/`SetParent`/`SetSize`/`SetScale`/`SetText`/
  `SetFont*`/`SetTextColor` (except the audited title accent, docs/PLAN.md, #71), mixin methods,
  `UIFrameFade*`, field writes on Blizzard tables, reassigning a Blizzard global, opening or closing
  Blizzard windows from our code.
- Art is found by structure, never by texture path (`GetTexture` returns file IDs here).
- Our glass is our own unnamed frame. Our state lives in our own weak tables. Text keeps
  Blizzard's fonts and colours, except the audited titles that wear the suite accent (#71).
- **Every callback checks `Engine.Active(key)` first:** hooks can't be removed.

## Layout

| File | What |
|---|---|
| `Compat.lua` | `API.*`: failures, events, version, `IsSecret`/`Plain`, `CVarBool`, `ClassColor`, Settings registration |
| `Glass.lua` | our LibGlass instance, built at `ADDON_LOADED` on the suite theme (Pearl; clean below LibGlass r11, #54) |
| `Theme.lua` | clear / smoked / class, the suite look's tint (#67): paints `Suite.Body`'s tint, wash (`SetWash`, a factor of the material's) and opaque backing, repainted live; a window skin's backing at least `WINDOW_BACKING` (#80); `Backing(kind)`, the RGBA a backing is painted with, and `OnRefresh` listeners for a skin's own textures (#86) |
| `Skin\Engine.lua` | `Register`, `Active`, owners/yields/handover, the switches, deferral and the combat wait, gamepad and suite stand-downs, `Status`, `def.restored` after a skin's treatment ends (#92); a third-party addon not installed says so (#56); `defer`, a window shown from a secure call chain styled a frame later, in combat too (#99) |
| `Skin\Kit.lua` | per-skin touches (`Fade` with read-back, `Dim` at another alpha (#86); `Blank`/`Tint`, given back by `Restore`; `TextColor` for the audited titles only, #71; `Shade` for `live = false`), `Panel` (with or without a backing), `Disc` (a LibGlass disc behind a round region, #48), `Section` (a recessed pane on a glass host, #84), `Adopt`, widget kinds (`Shell`, `FlatShell`, `Inset`, `Tab`); a window's pieces from the merchant (#88): `Header`, `CloseButton`, `PortraitDisc`, repainted on `Theme.Refresh` per skin; `SideTab`, a side tab on glass mirroring a per-window selected reader (#94); `GlyphButton`, the close button's recipe with a glyph of ours (#99); a white light on their discs while hovered (#103) |
| `Skin\Merchant.lua` | the merchant window (live; docs/MERCHANT.md): a window floor, its item rows in glass with Blizzard's red mirrored (quiet, #86), the portrait's disc; Blizzard's boxes as sections, each shown while Blizzard shows what it holds (#84, #86: the currency box, the repair box); a smoky header joined to a denser item area; the tabs tucked under the window, the selected one lighter with an accent edge; the close button a glass disc with a gold X; the page and repair buttons on glass, a disabled page label dimmed |
| `Skin\Bags.lua` | the bag windows (live, #88, docs/BAGS.md): the merchant's recipe on `ContainerFrame1..7` and `ContainerFrameCombinedBags` (floor, a smoky title band, the portrait's disc, the close button); the money and search panes, the sort button on glass; each item slot a glass well, an empty slot's pattern dimmed (Blizzard's `hasItem`, #170) and the combined window's greyed bag icon faded. Item buttons are on the use path: alpha and our children only. Steps aside for bag replacements. Measured on 70888 (#168) |
| `Skin\GameMenu.lua` | the Escape menu (live, #90, docs/GAME-MENU.md): the window glass and floor, the title on a glass tab, each pooled button on small glass with Blizzard's hover glow tinted white. The Esc path is taint-sensitive: never shows, hides or toggles the menu, never calls its methods |
| `Skin\Guild.lua` | Guild & Communities (live, #92, docs/GUILD.md): the window recipe (floor, smoky header, the portrait's disc on PortraitOverlay, the close button); the list, chat, edit box and roster as panes on hosts of ours parented to each section; the side tabs on glass, the selected one lighter with an accent rim mirroring each tab's checked state; GuildSpy's tabs and panel as tenants. The roster is taint-sensitive: its inset's alpha only, no hook on it |
| `Skin\Character.lua` | Forever's character window (live, #94, docs/CHARACTER.md): the window recipe (floor, smoky title band, the portrait's disc, the close button); the pane hosts' own art faded, the right pane and the level strip as panes; the model on the glass; each slot a glass well (the ammo slot's own anatomy); the stats headers as glass bars; the reputation, skills and statistics headers in the quest tracker's look (a glass bar, the +/- and the name in the accent); the six mode tabs and four sidebar tabs through the kit's side tabs. The slots' click is the protected path (alpha and our children only); the currency pane is never touched |
| `Skin\Map.lua` | the world map and quest log (live, #99, docs/MAP.md): the window recipe (floor, smoky title band down to the breadcrumbs, the book's disc following its texture, the close and maximise/minimise buttons on glass discs with our glyphs); the breadcrumb bar a recessed pane, its crumbs as text; the quest log a recessed pane, its zone headers on glass bars (the character lists' look, text Blizzard's), the search box and the quest count on pills. Shown from secure call chains (the panel manager, maximise, the NavBar's overlay refresh): styled a frame later, every hook only schedules. Never a script on QuestMapFrame, a global hook, a row's field, the canvas or another overlay frame. Yields to Leatrix Maps' simple frame; Glass Maps owns it |
| `Skin\Loot.lua` | the loot window and `/loot`'s roll history (live, #105, docs/LOOT.md), two switches (`loot`, `loothistory`): the window recipe (floor, a smoky title band down to the list, the close button on its disc); each row on glass, its plates faded (loot: the slot faded, the hover and press strokes white; history: the glass at the art's level - 1, under the roll-100 effect). The loot window is a UI panel opened in combat: `defer`, every hook only schedules, never a field (master loot reads `LootFrame.selected*`) |
| `Skin\DamageMeter.lua` | Blizzard's damage meter (live, #49, docs/DAMAGE-METER.md): the windows in glass, the bars stock |
| `Skin\QuestTracker.lua` | the objective tracker (live, #55, docs/QUEST-TRACKER.md): Glass Quest Tracker's look on the suite theme, the panel placed by state, the quest timers on a pill (#73); GQT loaded owns it |
| `Skin\RestedXP.lua` | RestedXP's guide window and waypoint arrow (live, #56, docs/RESTEDXP.md), two switches (`rxp`, `rxparrow`), attached when RXPGuides loads, its default window only: the window glass on GuideName (V1's collapse keeps it, V2 hides it), every backdrop piece faded and re-faded a frame after its theme, list and cards update (instance-field hooks that only queue, by generation), the smoky band and hairlines, the scroll track, each card on glass; rows' pieces faded, never their alpha (RestedXP's state). The arrow is the audited exception (docs/PLAN.md): RestedXP's faded, ours (`Media\Arrow.tga`, `Tools\make_media.py`) in the suite accent turned by its `SetRotation`, the distance on a pill |
| `Suite.lua` | the suite contract (docs/SUITE.md): `GlassUI.Suite` (`API`, `Ready`, `Theme`, `Report`, `Open`), the roster, the follow switches, each member's state; the suite look (docs/SUITE-LOOK.md: `Look`, `SetLook`, `LookChanged`, the `accent` key and `Accent`); the body (`BODY`, `Body`, #67); the tenant API (`SkinTab`, `SkinPanel`, #92, GuildSpy); dynamic members, listed only while loaded, and `live = false` followers (#101, AltStable); `declined`, an own look chosen in the addon (#152, Stakeout) |
| `Options.lua` | the settings page: the suite theme, the family and its Follow switches, the raid frames (layout, click-casting); the "Suite look" subpage |
| `GlassUI.lua` | bootstrap, `GlassUIDB`, `/glassui` |

Planned, per docs/PLAN.md: `Skin\<Window>.lua` for the rest, `Hub.lua`.
`Tools\SkinProbe\` is the ForeverProbe module (never shipped): `/fp skin`, the measurements
`/fp steps skin wave1|map|gradient|meter|questing`, each skin's acceptance (`/fp steps skin merchant|merchantlayout|bags|gamemenu|guild|character|characterlists|mapglass|maptracker|lootglass|meterskin|tracker|accent|timer|timerfake|rxpglass`),
the meter's glass bars preview (`/fp steps skin meterbars`), the suite's (`/fp steps skin suite`,
#24) and Glass Panel's place in it (`/fp steps skin suitepanel`, #58), Glass UI's own skins on Pearl
(`/fp steps skin pearl`, #54);
docs/FOREVER-PROBE.md says how to run it.

## References

- `..\References\Docs\PORTING-TBC-TO-FOREVER.md`: Edit Mode systems, secure code, secret values,
  options-page recipe, packaging.
- `..\References\Forever\api\forever-api-1.60.1.70888.md` (the newest build; take the highest there): does an API exist? Presence is not a contract.
- `..\wow-ui-source` (branch `forever`, on 70888; the checkout may lag `origin/forever`): the client's own FrameXML. The authority on frame
  names, templates and `[AllowLoadGameType camelot]` variants.
- `..\References\Docs\RELEASING.md`, `..\References\Docs\LIBGLASS-MIGRATION.md`, `..\References\Docs\EMBEDDED-LIBRARIES.md`,
  `..\References\Docs\PROBES.md` and `..\ForeverProbe\docs\GUIDE.md` (probes).
- `..\References\Addons\UISuites\EllesmereUI\EllesmereUIBlizzardSkin`, `..\References\Addons\UISuites\ElvUI`: how two
  suites skin these windows on Forever, and what they found broken. Behaviour references only.
- `..\LibGlass\docs\GLASS-MATERIAL.md`: the material and its region fields.

## Toolchain and commands

Lua 5.1 at `C:\Program Files (x86)\Lua\5.1\` (`lua.exe`, `luac.exe`). No build step.

```powershell
pwsh tests\run.ps1                                                   # luac -p on the TOC files (+ probe), then every tests\test_*.lua, through WowTestKit at its pin (needs ..\LibGlass and ..\ForeverProbe, or $env:LIBGLASS / $env:FOREVERPROBE)
pwsh tests\run.ps1 -KitDev                                           # the same against the ..\WowTestKit working copy, not the pin
& 'C:\Program Files (x86)\Lua\5.1\lua.exe' tests\test_boot.lua      # one test, from the repo root, once run.ps1 has fetched the kit
pwsh Tools\deploy.ps1                                                # copy the addon into AddOns
pwsh Tools\deploy.ps1 -Probe                                         # ...plus ForeverProbe and SkinProbe
```

- Default AddOns path: `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns`, the live
  client. The beta closed for good on 2026-10-23; Forever launches on 2026-11-04, and no in-game
  testing is possible until then.
- In game: `/console scriptErrors 1`, `/console taintLog 1`, then `/reload`.
- **Shell heredocs here collapse `\\` to `\`** (and `\n` escapes): write files that contain Lua
  escapes or Windows paths with the Write/Edit tools.

## Testing

The test scaffolding is WowTestKit (`C:\Projects\WoW\WowTestKit`; its README is the reference)
at the commit and client build `tests\kit.pin` names. `tests\run.ps1` puts that commit in
`%LOCALAPPDATA%\WowTestKit\<sha>` and hands off to the kit's runner; CI fetches it with
`tests\fetch_kit.sh`. `tests\kit.lua`, `kit.ps1` and `fetch_kit.sh` are the kit's bootstrap
copies: never edit them here. A kit need is an issue on the kit, worked around in
`tests\wow_stubs.lua` with a `-- WowTestKit #N:` comment meanwhile. `tests\run.ps1 -KitDev`
runs against the `..\WowTestKit` working copy instead of the pin.

The kit's core (strict globals as an allowlist of APIs verified in the dump, event names validated
against the pinned build, every widget method recorded, timers, `print` with the stray-`|` check
`done()` fails on), plus Glass UI's own in `tests\wow_stubs.lua`: the client APIs it reads, the
Blizzard windows with Glass Quest Tracker's contract record (`WoW.blizzCalls`, `textureArgs`,
`fieldChanges`, `luaCalls`), and the few `WoW.Methods` entries it replaces, each saying why.
`tests\harness.lua` has `near`, `loadAddon` and `acceptKnownStrays` (the help's known bare-`|`
lines); `check`, `eq` and `done` are the kit's. `test_methods.lua` exercises every skin and command,
then `Kit.checkMethods` fails on any widget method the pinned build lacks on that type: a new skin's
window or command goes in its exercise. The contract test arrives with the engine (#3).
**Mutation-test every new test.** Offline tests can't cover taint, rendering or the live client: that's the probe and each
skin's in-game acceptance. **`test_probe` runs locally only:** ForeverProbe is private, so CI sets
`FOREVERPROBE_OPTIONAL=1` and it skips there (ForeverProbe GUIDE section 8). Run
`tests\run.ps1` before every PR that touches the probe.

## Workflow and releasing

- Issue → branch off `main` → PR with `Closes #N`. Never commit to `main`; commit or push only
  when asked. `luac -p` clean and tests green before committing.
- **The owner merges and closes PRs and launches reviews.**
- **Plans** get an adversarial review before coding: Codex via the `codex-consult` skill,
  `-m gpt-6-astra` at high effort, looping until consensus, without overengineering.
- **Sibling repos are never edited from this session.** The hub pilot's changes to GlassUnitFrames
  and GlassActionBars are issues and PRs in those repos.
- Releases: `..\References\Docs\RELEASING.md`.

## Conventions

- Comments explain why, in the siblings' plain style. Name the measured build when a fact was
  measured.
- `GlassUI.failures` is the one failure record (`API.Fail`, `API.Try`); `/glassui failures` reads it.
- `GlassUIDB` saves only what differs from `DEFAULTS`.

## Consulting Codex

The shared `codex-consult` skill (user level) has the invocation and the gotchas. For this repo:

For Glass UI, good things to hand Codex:
- any skin: the skin contract in `CLAUDE.md` and docs/PLAN.md, whether a hook could run our code
  inside a secure path, whether every callback checks `Engine.Active`, and whether `live` is honest
  (only fades and our own panels);
- the protected windows (spellbook and talents, guild, the Escape menu, the group finder) and the
  audited exceptions (tooltip backdrop, menu style mixins);
- owners and yields: a sibling or a third-party addon (Leatrix Maps, Auctionator, Skilled) touching
  the same window;
- the hub: anything that would make a sibling depend on Glass UI, or Glass UI read a sibling's
  SavedVariables;
- anything that writes to SavedVariables.

**Always hand it `CLAUDE.md` and `docs/PLAN.md` alongside the diff or plan**, plus
`C:/Projects/WoW/References/Docs/PORTING-TBC-TO-FOREVER.md` and `docs/FOREVER-PROBE.md`. Those findings
were measured on the live client. Without them, a cold reviewer argues from Classic-era or Retail
behaviour that doesn't hold here (that Classic's `SpellBookFrame` or `PVEFrame` exist, that a
Blizzard window's own methods are harmless to call).
`C:/Projects/WoW/References/Forever/api/forever-api-<version>.<build>.md` (take the highest build) is the full API surface when a question
turns on whether something exists, and `C:/Projects/WoW/wow-ui-source` (branch `forever`) is the
client's own FrameXML. The design references are
`C:/Projects/WoW/References/Addons/UISuites/EllesmereUI/EllesmereUIBlizzardSkin` and
`C:/Projects/WoW/References/Addons/UISuites/ElvUI`: behaviour references only, their code is never copied.
