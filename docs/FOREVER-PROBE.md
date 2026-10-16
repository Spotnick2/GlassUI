# Forever probe: Glass UI

What has to be measured on the live client before each wave of skins, and what was found.
`Tools/SkinProbe/` is a ForeverProbe module (`..\ForeverProbe\docs\GUIDE.md`). Its lines go to the
`/fp` console and to `WTF\Account\<account>\SavedVariables\SkinProbe.lua`; the procedures' records
go to `ForeverProbe.lua` (`steps.records["SkinProbe/<name>"]`). Record the build with every result.

The probe is discovery. Each skin's acceptance is on its final implementation (docs/PLAN.md,
milestones), not on the probe's copy.

## Running it

1. `pwsh Tools\deploy.ps1 -Probe` (deploys Glass UI, LibGlass, ForeverProbe and SkinProbe), then
   `/console scriptErrors 1` and `/reload` in game.
2. `/fp steps skin wave1`, then `/fp steps skin map`, then `/fp steps skin gradient`. Each is a
   panel of buttons: do what a step says, answer its questions, type anything odd into its Note box.
   Each ends with `/reload`, which saves the results to disk; nothing needs pasting.
3. One-off commands: `/fp skin` lists them (`state`, `tree <target> [depth]`, `fade <target>`,
   `panels on|off`, `border fade|restore`, `gradient on|off`, `clear`). Targets: `merchant`,
   `popup`, `character`, `map`.

The only writes to Blizzard objects are `SetAlpha` on textures, each put back at once (`fade`) or
by `border restore` (the map procedure's last step does it). `fade` and the map panels refuse in
combat.

## Wave 1 (#2)

| # | Question | How | Result |
|---|---|---|---|
| W1.1 | Merchant, static popups, character sheet (six panes), world map: does each frame exist; protected; strata, level, size; flattens render layers? | `state` (wave1 step 1) | **70374: all 16 exist, none protected (`IsProtected` false/false), none flattens render layers.** Strata: MEDIUM for the merchant, character sheet and panes; DIALOG for a shown popup (MEDIUM/level 0 while hidden); MEDIUM/level 1 for the world map, but HIGH for its `BorderFrame` and `QuestMapFrame`. Confirmed by `state` in the second run. |
| W1.2 | Each target's frame and region tree (type, name, parentKey, layer, atlas or texture, alpha), and **which textures ignore `SetAlpha`** (they carry a gradient, so `kit:Fade` can't hide them) | `tree`, `fade` (wave1 steps 2-6, map step 1) | **70374: of 2850 textures tried, one ignores `SetAlpha`:** `WorldMapFrame.#12.Eye.#1.BG`, inside a hidden 300x300 frame (an eye animation), not border art. Merchant 405, popups 680, character sheet 1175 (all six panes): **none**. So `kit:Fade` works for every wave-1 shell. Trees are in `SkinProbe.lua`'s log (the character sheet and paper doll were cut at 700 lines each, past the shell). |
| W1.3 | World map `frameBuffer="true"`: does a glass panel of our own render as a child of `WorldMapFrame`, see-through, over the map and behind its faded border, windowed and maximised? | map procedure | **70374: yes, windowed and maximised.** A LibGlass panel (Glass UI's instance) as a child of `WorldMapFrame` renders and is see-through, both above the map (level +50) and behind it at the window's level with the border art faded (47 textures once buttons are skipped; fading the 64 including buttons' art hid the maximise button in the first run). Both still look right maximised (second run, with Leatrix Maps' simple frame Off). |
| W1.4 | Is the gamepad interface style detected by `C_InputInterfaceStyle.GetCurrentStyle() == Enum.InputDeviceInterfaceType.Gamepad` (Ellesmere's test)? | `state` | **70374: the API and the enum exist** (`{Gamepad=1, Mkb=0}`); with keyboard and mouse in use it reads 0, so not gamepad, **even with the `GamePadEnable` CVar at 1**. So the CVar is not the test: the style is. Reading 1 with a controller in use isn't measured (no controller); the stand-down follows Ellesmere's test as is. |
| W1.5 | Does any installed addon other than Glass UI set `/gui`? | `state` | **70374: no.** Only `SLASH_GLASSUI2`, with Leatrix Maps, Skilled and nine Glass addons loaded. |
| W1.6 | Gradients: does `SetAlpha(0)` made **before** `SetGradient` survive it (square B)? Does an **image** texture with a gradient ignore `SetAlpha` too (square C)? A is the measured case, D the control. | gradient procedure | **70374: once a texture has a gradient, `SetAlpha` can't hide it, whatever the order or kind.** A, B and C all show and read 1; D hides and reads 0. B: `SetAlpha(0)` before `SetGradient` is undone by it. C: an image texture (`WHITE8X8`) with a gradient ignores `SetAlpha` like a colour texture. So a gradient texture is hidden by `SetTexture(nil)` (Blank) or dimmed through its gradient colours' alpha (LibGlass r7's wash), never by `SetAlpha`. |

## Acceptance (each skin, on the real addon)

Each skin's in-game routine (docs/PLAN.md, milestone 3): the window used for real with
`taintLog 1` and `scriptErrors 1`, off and on live, after a /reload, in combat where it applies.
The look is judged from the procedure's screenshots; `Logs\taint.log` is read after the run.

| Skin | Procedure | Result |
|---|---|---|
| Merchant (#4) | `/fp steps skin merchant`: the looks side by side (clear at 0.85, 0.6 and 0.35 backing, smoked, class); buy, sell, buyback, repair; skin off and on live; after /reload; in combat (optional) | **70425: passes.** Buy, sell and buyback work; repair not tested (nothing to repair). The screenshots show the gold shell gone, glass under the window and tabs, and the item rows keeping Blizzard's red. Off live: exactly stock (owner: yes); on live: faded again; after /reload: on, faded at the first show. No `ADDON_ACTION_BLOCKED`/`FORBIDDEN` in the three sessions. Combat skipped (a plain, unprotected window). **Looks:** all five read well, and 0.35 looks the most like glass (owner): clear and class now use backing 0.35, smoked keeps 0.92. **Taint pass (typed `/console taintLog 1`, buy/sell/buyback, full exit):** the log was on (BugGrabber: the bag-bar error 84 times that session, see the facts below), and `Logs	aint.log` was not rewritten. At level 1 the client writes only when something is blocked, so nothing was. A level-2 pass over every wave-1 skin goes into the v0.1.0 release check (#9). |

## Blizzard's own glass (#17)

The ruleset screen at login (`Blizzard_GlueXML\Mainline\SuperDistrict.xml:8`) draws its cards with
one atlas, `Mode-Selection-Card-Regular` (selected: `...-yellow-glow`): a translucent dark body,
the scene showing through sharp, a gold-metal rim. One fixed size, not sliced.

| # | Question | How | Result |
|---|---|---|---|
| G.1 | Does the atlas exist in game, and at what size? | `/fp steps skin card` step 1 | **70425: yes, 260x530.** |
| G.2 | Beside Glass UI's clear and smoked glass at the same size, over bright and dark scenery: how does it read? | the same procedure, screenshots | **70425: it isn't glass.** In game the card is opaque: dark brown parchment, gold rim (owner: "it does not look like glass", no theme wanted). The see-through look at login is the cards' **disabled** state while the servers are down: `SetAlpha(0.55)` and desaturated (`SuperDistrict.lua:123-127`). Beside it, our clear and smoked glass read almost alike, a dark grey slab with the scene faint behind: the opaque backing (0.85 / 0.92) dominates the tint. Settled on the merchant (#4): clear's backing is now 0.35. |

## Facts already known (don't re-measure)

- wow-ui-source branch `forever` is build 1.60.1.70374, the same as the API dump. The client is now
  70425 (dump `forever-api-1.60.1.70425.md`, and `origin/forever` is 70425). The wave-1 measurements
  above are from 70374 except where a result names 70425. Re-measure the popups, the character
  sheet and the map at their own skins: their FrameXML changed (popups gained `ConfirmText`).
- **With `taintLog` at 1 or 2, Blizzard's own code throws "attempt to call a nil value"**, none at 0:
  in tooltips (Glass Quest Tracker, 70374, `TooltipDataHandler.lua:300`), and in the bag bar's
  layout on every bag change (70425, `BagsBar.lua:125`, `self:UpdateDividers()`: 254 errors in the
  merchant session, none after the `/reload` that turned the log off). Ignore those stacks during a
  taint pass. `/reload` sets `taintLog` back to 0. On 70425 a level-1 session with nothing blocked
  leaves `Logs	aint.log` untouched (it kept its old date after a full exit): an old date means "nothing
  logged", not "logging off". Level 2 also logs every tainted read, so use it to see an addon's taint.
- A colour texture painted with `SetGradient` ignores a later `SetAlpha`, and `GetAlpha()` keeps
  reading 1 (porting guide section 3, measured twice on 70374).
- Leatrix Maps 1.60.23 reads "Simple map frame" once at its `ADDON_LOADED` (default On), applies
  it at `PLAYER_LOGIN`, and writes it back at logout (`Leatrix_Maps.lua:2887, 2956, 2962`).
