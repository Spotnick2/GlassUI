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
   Each ends with `/reload`, which saves the results to disk; nothing needs pasting. The suite
   theme's validation is `/fp steps skin suite` (below).
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
| Merchant (#4) | `/fp steps skin merchant`: the looks side by side (clear at 0.85, 0.6 and 0.35 backing, smoked, class); buy, sell, buyback, repair; skin off and on live; after /reload; in combat (optional) | **70425: passes.** Buy, sell and buyback work; repair not tested (nothing to repair). The screenshots show the gold shell gone, glass under the window and tabs, and the item rows keeping Blizzard's red. Off live: exactly stock (owner: yes); on live: faded again; after /reload: on, faded at the first show. No `ADDON_ACTION_BLOCKED`/`FORBIDDEN` in the three sessions. Combat skipped (a plain, unprotected window). **Looks:** all five read well, and 0.35 looks the most like glass (owner): clear and class now use backing 0.35, smoked keeps 0.92. **Taint pass on 70450 (typed `/console taintLog 1`, buy/sell/buyback, full exit):** the log was on (BugGrabber: the bag-bar error 84 times that session, see the facts below), and `Logs	aint.log` was not rewritten. At level 1 the client writes only when something is blocked, so nothing was. A level-2 pass over every wave-1 skin goes into the v0.1.0 release check (#9). |

## The suite theme (#24, docs/SUITE.md)

`/fp steps skin suite`, once Glass UI (this branch), LibGlass r11 (LibGlass#64), GlassUnitFrames
(#129) and GlassRaidFrames (#67) are deployed.

- **Combinations:** the procedure switches between them itself, for this character only:
  - it calls `C_AddOns.EnableAddOn`/`DisableAddOn` with the GUID;
  - it saves each addon's enable state and the Follow switches first, in `SkinProbeDB.suiteWas`;
  - its Restore step puts them back, and so does `/fp skin suite restore` after a stopped run.
- **Each session:**
  - Glass UI's record of what it answered each addon, and whether it was ready yet (S.2);
  - what each addon reported;
  - its instance's preset and STYLE (gloss, frost, wash, innerShadow);
  - its saved look keys and LibGlass's MINOR.
  These are saved as `SkinProbeDB.results["S.<combination>"]`, and `/fp skin suite` prints the
  same.

| # | Question | Result |
|---|---|---|
| S.1 | Startup: Glass UI alone, GUF alone, GRF alone, both without Glass UI, Glass UI + each, all three (own look, then following) | **70450, LibGlass r11 (MINOR 11): all eight pass** (runs #211-#219). Without Glass UI, or not following, each addon keeps its own look: GUF Clean, GRF Classic + Smoked (both saved). Following, both are Pearl: preset `pearl`, gloss 0.15, frost 0.06, wash 0.10, innerShadow 0.15. No Glass UI failure, nothing blocked. |
| S.2 | Load order: is every addon's `Theme` answered after Glass UI's `ADDON_LOADED` (`OptionalDeps: GlassUI`)? | **70450: yes.** In every combination with Glass UI, every answer was given after `Ready()`: Glass UI's `ADDON_LOADED` runs before an `OptionalDeps` dependent's own. |
| S.3 | Follow on, then off, with a Smoked body and a non-default slider: the local look and saved keys come back unchanged | **70450: passes on the data.** After following, "all, own again" matches "all, own": the same STYLE, and the same saved look keys (GUF `look=clean`; GRF `look=classic`, `glassBody=smoked`). The GUF Smoked/slider step left no trace in its saved keys, so only GRF's Smoked body was exercised. The owner answered "not sure" to "exactly as before" (the screenshot shows the own look back). |
| S.4 | Live repaint under Pearl: target colours, font, cast colours | **70450: yes** to all three (owner, screenshots of a target and a cast bar). |
| S.5 | Gradients: the fill and the health-loss overlay on bright and dark scenery | **70450: yes** (owner). Screenshots over a bright sky and a dark interior: the fills read on both. Priest white is the faintest over bright sky. |
| S.6 | Low health: remaining against missing, on unit frames and raid cells | **70450: yes** (owner, `/glass preview`). A real 91/337 (27%) reads clearly: the remaining part bright, the missing part see-through. |
| S.7 | Combat: Follow switched in combat waits for the reload; a /reload in combat; no blocked action | **70450: not established.** Nothing was blocked and Glass UI recorded no failure. The step that waits for `/glassui suite follow glassraidframes off` in combat was completed by hand with GRF still set to follow. The slash path works offline, so the command most likely never reached Glass UI. The reload after it came out of combat (the record says `combat=false`), so the reload-in-combat case was not exercised either. The one error was Blizzard's `PetActionBar.lua:123` taint-log noise (134 times). To redo, in short. |
| S.8 | The page's click-casting line and buttons; GRF's editor on Pearl | **70450: yes.** The page (after the owner's mockup) fits the window at this UI scale. Both cards read "Glass UI preset: Pearl". GUF's Settings opens its page, showing the look set in Glass UI. Configure bindings opens GRF's editor, which reads well on Pearl. The click-casting line matches GRF's setting. **The page's own Reload UI button reloaded with nothing blocked** (run #219 to #220): the secure macro path works inside Settings. Found: the click-casting line didn't redraw while the page was open when GRF reported again; fixed, the page now redraws on every report and switch. Owner: the orb is "not the pearl artwork" of the mockup. |

## Blizzard's own glass (#17)

The ruleset screen at login (`Blizzard_GlueXML\Mainline\SuperDistrict.xml:8`) draws its cards with
one atlas, `Mode-Selection-Card-Regular` (selected: `...-yellow-glow`): a translucent dark body,
the scene showing through sharp, a gold-metal rim. One fixed size, not sliced.

| # | Question | How | Result |
|---|---|---|---|
| G.1 | Does the atlas exist in game, and at what size? | `/fp steps skin card` step 1 | **70425: yes, 260x530.** |
| G.2 | Beside Glass UI's clear and smoked glass at the same size, over bright and dark scenery: how does it read? | the same procedure, screenshots | **70425: it isn't glass.** In game the card is opaque: dark brown parchment, gold rim (owner: "it does not look like glass", no theme wanted). The see-through look at login is the cards' **disabled** state while the servers are down: `SetAlpha(0.55)` and desaturated (`SuperDistrict.lua:123-127`). Beside it, our clear and smoked glass read almost alike, a dark grey slab with the scene faint behind: the opaque backing (0.85 / 0.92) dominates the tint. Settled on the merchant (#4): clear's backing is now 0.35. |

## Facts already known (don't re-measure)

- **Glass UI is measured on 1.60.1.70450** (`MEASURED_ON_BUILD`). 70450 and 70425 are the same UI:
  the API dumps are identical, and `origin/forever` changed only `version.txt`. The merchant passed on
  70425, and its taint pass ran on 70450. The other wave-1 measurements above are from 70374. From
  70374 to 70425 the popups, the character sheet and the map changed in FrameXML (the popups gained
  `ConfirmText`): re-measure each at its own skin.
- **With `taintLog` at 1 or 2, Blizzard's own code throws "attempt to call a nil value"**, none at 0:
  in tooltips (Glass Quest Tracker, 70374, `TooltipDataHandler.lua:300`), and in the bag bar's
  layout on every bag change (70425, `BagsBar.lua:125`, `self:UpdateDividers()`: 254 errors in the
  merchant session, none after the `/reload` that turned the log off; 84 more in the typed taint
  pass), and in the pet bar (70374, `PetActionBar.lua:123`, a call to a Blizzard global no addon
  touches: 114 times in Glass Quest Tracker's taint session). Every session with the log on had
  them, none without. BugSack fills up with them: ignore those stacks during a taint pass. `/reload` sets `taintLog` back to 0. On 70425 a level-1 session with nothing blocked
  leaves `Logs	aint.log` untouched (it kept its old date after a full exit): an old date means "nothing
  logged", not "logging off". Level 2 also logs every tainted read, so use it to see an addon's taint.
- A colour texture painted with `SetGradient` ignores a later `SetAlpha`, and `GetAlpha()` keeps
  reading 1 (porting guide section 3, measured twice on 70374).
- Leatrix Maps 1.60.23 reads "Simple map frame" once at its `ADDON_LOADED` (default On), applies
  it at `PLAYER_LOGIN`, and writes it back at logout (`Leatrix_Maps.lua:2887, 2956, 2962`).
