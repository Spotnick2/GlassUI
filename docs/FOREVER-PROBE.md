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
| Merchant (#4) | `/fp steps skin merchant`: the looks side by side (clear at 0.85, 0.6 and 0.35 backing, smoked, class); buy, sell, buyback, repair; skin off and on live; after /reload; in combat (optional) | **70425: passes.** Buy, sell and buyback work; repair not tested (nothing to repair). The screenshots show the gold shell gone, glass under the window and tabs, and the item rows keeping Blizzard's red. Off live: exactly stock (owner: yes); on live: faded again; after /reload: on, faded at the first show. No `ADDON_ACTION_BLOCKED`/`FORBIDDEN` in the three sessions. Combat skipped (a plain, unprotected window). **Looks:** all five read well, and 0.35 looks the most like glass (owner): clear and class now use backing 0.35, smoked keeps 0.92. **Taint pass on 70450 (typed `/console taintLog 1`, buy/sell/buyback, full exit):** the log was on (BugGrabber: the bag-bar error 84 times that session, see the facts below), and `Logs\taint.log` was not rewritten. At level 1 the client writes only when something is blocked, so nothing was. A level-2 pass over every wave-1 skin goes into the v0.1.0 release check (#9). |

### The merchant's layout (#84, docs/MERCHANT.md section 4)

`/fp steps skin merchantlayout`: sections (closer to Blizzard's) against the mockup's bar, switched
live. Each check reads our pieces against Blizzard's tab state. The results are saved as
`SkinProbeDB.results["ML.<label>"]`: the panes shown, the bar, the square, the label, the empty
state, the lit tab, the buyback count, and the bar's top against row 11's bottom.

| # | Question | Result |
|---|---|---|
| ML.1 | Sections: 5 panes on the Merchant tab, 3 on Buyback, where Blizzard's boxes are; the box insets right? | **Run 1 (70450, 2026-10-20): 5 and 3, placed right** (the bottom boxes and the money boxes line up with Blizzard's in the skin-off screenshot), **but invisible:** the fill was the backing's colour over a floor of that colour at 1. Black at 0.4 now. |
| ML.2 | Bar: the empty state on an empty Buyback page; the square and label on the Merchant tab; the label gone after a sale, back after buying it back on Buyback; reopened on the Merchant tab; rows 11-12 clear of the bar | **Run 1: all pass.** Bar top 667 against row 11's bottom 676 on a full Buyback page. The empty state's icon didn't draw: `"Interface\MerchantFrame\..."` had been written through a shell heredoc, which ate the backslashes (Lua 5.1 read `\M` as `M`). Fixed, and the path is tested literally. |
| ML.3 | The active tab lit, in both | **Run 1: lit as Blizzard shows it, but not visible at 0.10.** And the owner: "the tabs at the bottom need more work, they feel disconnected". Run 2: 0.2, and the tabs tucked under the window. |
| ML.4 | Off: nothing of ours; the layout switched while off applies when on again | **Run 1: passes.** |
| ML.5 | The owner's pick: sections or bar | **Run 1: unsure** ("i honestly have no idea what you are talking about": with the panes invisible, the two looked alike). The owner's ideas then: the top fully Pearl down to the first bar, and the window a bit less than opaque, like the stock bags. Run 2 asks again. |
| ML.6 | Run 2: the panes visible; the tabs attached; the Pearl header kept; the floor 0.8, 0.85 or 0.9 | **Run 2 (70450, 2026-10-20): every check passes.** Panes: yes. Tabs: yes, "but i think what's missing is the original gradient from the stock ui". Pearl header: kept. Floor: "85 is fine". Layout: Yes (sections). The screenshots still show RestedXP's guide readable through the rows at 0.85. Then the owner's mockup and an outside critique: #86 (docs/MERCHANT.md section 5), the layout a setting (the bar by default), the item area denser. |
| ML.7 | Run 3 (#86): the guide behind hard to read at 0.93, the header smoky and joined; the red quieter; the tabs' gradient; the close button (rest, hover, press, it closes, reopened); the setting through the slash and across a /reload; off and on | not run yet |

### The merchant revisited (#80, #48, docs/MERCHANT.md)

`/fp steps skin merchant`, extended. The checks read our rows' glass against Blizzard's item buttons,
the red mirrors, the buyback slot's glass, and the disc's centre against the portrait's mask. These
are saved as `SkinProbeDB.results["MS.<label>"]`.

| # | Question | Result |
|---|---|---|
| MS.1 | The window floor over other UI (RestedXP's window or the quest log): 0.6, 0.75 or 0.85, the owner's pick | **Run 1 (70450, 2026-10-20):** RestedXP's text read through all three, dimmed by exactly the floor (63, 40, 23 levels above the background, 0.4 : 0.25 : 0.15). The owner: "0.85 more", then asked to hide what's behind altogether. The floor is now 1 (opaque). Run 2 tries 0.85, 0.95 and 1. |
| MS.2 | The rows: glass under each item, none on an empty slot, Blizzard's red on the glass; the buyback slot after a sale; the buyback tab's 12 rows | **Run 1:** PASS: 10 rows on the merchant tab, 6 on glass, 4 red, 0 mismatched; the buyback tab's 12 rows, 1 on glass, 0 mismatched; the owner: rows read well. **The buyback slot: not shown.** Its check ran with the Buyback tab open (12 rows read), where Blizzard hides the slot. The step said "under the rows", but the slot is at the bottom right. Run 2 says to stay on the Merchant tab. |
| MS.3 | The portrait's disc: a ring round the face, centred on the mask, on the NPC's portrait and the buyback tab's | **Run 1:** PASS: seen on both tabs, 70 px (58 + 2 x 6), off-centre 0.00001 px; centred and the right width (the owner). "The ring should probably be pearl/clear": it was dark, with a backing at the window's floor. Now Pearl, clear and without a backing. |
| MS.4 | Off live: Blizzard's plates, slots and portrait ring back, no glass of ours; on again | **Run 1:** PASS: the border back, 0 rows on glass, no disc; the owner: exactly Blizzard's; on again, faded; after a /reload, still on. The "too many errors" warnings in the screenshots were the taint log's micro menu noise (BugGrabber: `MainMenuBarMicroButtons.lua:2008`, x301), not Glass UI. |

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
| S.7 | Combat: Follow switched in combat waits for the reload; a /reload in combat; no blocked action | **70450: passes** (`/fp steps skin suitecombat`, second account, runs #148-#150). GRF was switched off on Glass UI's page while fighting: it was saved, and GRF stayed on Pearl for that session. The page said a change was waiting and to type /reload, with no Reload UI button while fighting (owner: yes). After the reload, GRF built its own look (here Pearl, its default: nothing saved on that account) as "own" and not-following, and GUF stayed on Pearl. Nothing was blocked, and Glass UI recorded no failure. The only error was Blizzard's `PetActionBar.lua:123` taint-log noise (189 times). In both runs the session after a /reload typed in combat started out of combat, so the combat-deferred build after a reload was not exercised here. That path is each addon's own combat queue, unchanged by this work. The first run (#220-#221) is superseded: its switch never reached Glass UI. |
| S.8 | The page's click-casting line and buttons; GRF's editor on Pearl | **70450: yes.** The page (after the owner's mockup) fits the window at this UI scale. Both cards read "Glass UI preset: Pearl". GUF's Settings opens its page, showing the look set in Glass UI. Configure bindings opens GRF's editor, which reads well on Pearl. The click-casting line matches GRF's setting. **The page's own Reload UI button reloaded with nothing blocked** (run #219 to #220): the secure macro path works inside Settings. Found: the click-casting line didn't redraw while the page was open when GRF reported again; fixed, the page now redraws on every report and switch. Owner: the orb was "not the pearl artwork" of the mockup, so it now shows the Iridescent Pearl's own icon (item 5500, #26), seen in the S.7 run. That run's screenshot also showed a card's long state line running under its checkbox: the line now stops short of the checkbox and reads "... - reload to apply". |

### Glass Panel in the suite (#58)

`/fp steps skin suitepanel`, with Glass UI and Glass Panel loaded (GlassPanel#96 and #97, on its
main since 2026-10-19), and XP+ on the panel for the edge steps. It changes only Glass Panel's
Follow switch. The switch is saved first in `SkinProbeDB.panelWas`, since it lives in `GlassUIDB`
(account-wide). The Restore step puts it back, and so does `/fp skin suitepanel restore`.

- **Each session** (its own look, following, its own look again), saved as
  `SkinProbeDB.results["P.<label>"]`:
  - the member reading above;
  - the Follow switch;
  - `GlassPanel.EdgeState().top`, and whether the bar shows;
  - how many `GlassPanel.EdgeChanged` announcements this session heard, and the last one;
  - Glass UI's and Glass Panel's failures.
- **Pearl either way:** Pearl is Glass Panel's own default, so the instance is `pearl` in every
  session. What following changes is the report (`built = "pearl"`) and the state. The saved
  `glass`, `glassTint` and `windowGlass` must match the session read just before following.
- **The edge:**
  - at least the bar's 24 while it shows, and announced;
  - out of combat, the last announcement within 0.5 of `EdgeState` (its tolerance);
  - then XP+'s zoomed bar under the panel, where the edge must grow;
  - then docked again, where it must come back.

| # | Question | Result |
|---|---|---|
| P.1 | Its own look and following, after a /reload each: answered once Glass UI is ready, reported, Pearl, its saved glass untouched | **70450, LibGlass r11: passes on the data** (second account, runs #233-#237). In each session the instance was Pearl (gloss 0.15, frost 0.06, wash 0.10, innerShadow 0.15), and every answer was given once Glass UI was ready. There were no failures and MINOR was 11. In its own look, nothing was built for Glass UI and the state was `own`. Following, it built `pearl` and the state was `following`. The saved glass (`glass=smoked` set for the test, `glassTint=neutral`, `windowGlass=reflective`) was the same before following, while following, and after. All three session checks FAILed only on "no EdgeState yet": the read ran at once after the /reload, before Glass Panel's first measure. That was the probe, and now each read waits for the measure. |
| P.2 | Glass UI's card ("Glass UI preset: Pearl"); its options greyed, with Open Glass UI; `/gpanel glass` refused while following; the bar on Pearl | **70450: yes, with two findings for Glass Panel.** The card reads "Glass UI preset: Pearl" with Use Glass UI appearance ticked. Glass and Windows are greyed, and Open Glass UI brings Glass UI's page back. `/gpanel glass smoked` says "set in Glass UI (following the suite's Pearl; yours stay saved)". Back in its own look, the bar was Smoked again (owner: yes). **Found:** (1) the Tint choice (Neutral / Class colour) stays live while following. The owner answered "yes, but not the tint". (2) The two notes under Windows overlap ("Share, Setup and the other dialogs..." and "Following Glass UI (Pearl): ..."). Both were sent to Glass Panel. The owner decided the tint is Glass UI's while following, and GlassPanel#102 (PR #103) did that. **Re-run on 70450** (runs #246-#250): the Tint choices are greyed, and the two notes sit apart (screenshot). Every session's read passed on the data, its edge included. |
| P.3 | `EdgeState` and `EdgeChanged`: the bar alone, XP+ zoomed, docked again | **70450: passes.** XP+'s bar was already zoomed under the panel at login. The first measure was 109.0, announced once, the same value. Docking it brought the edge to 24.0 (the bar alone), announced: a second `EdgeChanged`. Zooming in while playing was not exercised, since the zoom step passed at once. |

### Glass UI's own skins on Pearl (#54)

`/fp steps skin pearl`. It reads which glass Glass UI built (`GlassUI.glassPreset`, and
`glassWhy` for a fallback), with the LibGlass MINOR, the body theme and the instance's STYLE, saved
as `SkinProbeDB.results["PEARL.built"]`. Then it takes a screenshot each of the merchant and the
meter, for the owner to judge against the clean glass they had.

| # | Question | Result |
|---|---|---|
| PL.1 | Glass UI's own glass is Pearl (MINOR 11, wash 0.10), not the clean fallback | **70450: passes** (second account, run #251). Built `pearl`, with no fallback: MINOR 11, wash 0.10, gloss 0.15, frost 0.06, innerShadow 0.15, body `clear`. |
| PL.2 | The merchant reads well on Pearl; the meter looks at least as good as on clean | **70450: yes to both** (owner, screenshots of the merchant at Razor Hill's inn and of the meter). |

## Blizzard's own glass (#17)

The ruleset screen at login (`Blizzard_GlueXML\Mainline\SuperDistrict.xml:8`) draws its cards with
one atlas, `Mode-Selection-Card-Regular` (selected: `...-yellow-glow`): a translucent dark body,
the scene showing through sharp, a gold-metal rim. One fixed size, not sliced.

| # | Question | How | Result |
|---|---|---|---|
| G.1 | Does the atlas exist in game, and at what size? | `/fp steps skin card` step 1 | **70425: yes, 260x530.** |
| G.2 | Beside Glass UI's clear and smoked glass at the same size, over bright and dark scenery: how does it read? | the same procedure, screenshots | **70425: it isn't glass.** In game the card is opaque: dark brown parchment, gold rim (owner: "it does not look like glass", no theme wanted). The see-through look at login is the cards' **disabled** state while the servers are down: `SetAlpha(0.55)` and desaturated (`SuperDistrict.lua:123-127`). Beside it, our clear and smoked glass read almost alike, a dark grey slab with the scene faint behind: the opaque backing (0.85 / 0.92) dominates the tint. Settled on the merchant (#4): clear's backing is now 0.35. |

## Questie and RestedXP: discovery (#56, docs/QUEST-TRACKER.md part 3)

`/fp steps skin questing`. It turns on Questie, QuestieDB (which Questie requires) and RXPGuides
for this character only, after saving their enable states in `SkinProbeDB.questingWas[GUID]`.
Its Restore step puts them back, and so does `/fp skin questing restore`. Installed on 70450:
Questie 12.1.0 (`Questie_Camelot.toc`) and RestedXP v4.11.26, the versions the plan read.

- **First seen** (`QS.firstSeen`): where each of `Questie_BaseFrame`, `RXPFrame` and `RXPG_ARROW`
  first existed, kept by the run once its tracker and guide window show (Questie builds its tracker
  late in its startup). SkinProbe loads after both addons, so "SkinProbe load"
  means at their own load or earlier. The watcher runs every session into `QS.seenSession`, so the
  last reload, with the addons off again, keeps the run's result.
- **The hold** (`QS.hold.<refresh>`): the probe holds every texture of the three at 0, its own
  touch. After each of their refreshes it reads which came back and which textures are new, then
  holds them all at 0 again, the new ones included, so each refresh reports only its own changes.
  Unfade puts every one back at the alpha it had when first held. The refreshes are:
  - Questie's fader, a quest update, and its background option;
  - a RestedXP step, its theme, and its window reopened.
- **Side by side** (`QS.coexist`): Questie's tracker and Blizzard's.
- **The arrow** (`QS.arrow.<x>`): its texture's `SetRotation` calls, from a hook on that texture,
  and its `orientation` field. Also its anchor and distance from the screen's top, against Glass
  Panel's `EdgeState().top`.

| # | Question | Result |
|---|---|---|
| QS.1 | When does each frame first exist (the engine attaches at their ADDON_LOADED)? | **70450 (run #285, second account):** `RXPFrame` and `RXPG_ARROW` exist when SkinProbe loads, so at RestedXP's own load or earlier. **`Questie_BaseFrame` comes 2.8 s after PLAYER_ENTERING_WORLD** (2.7 s in the next session), late in Questie's startup. Questie's tracker can't be styled at its ADDON_LOADED: the skin has to wait for the frame. |
| QS.2 | Which textures stay faded through their own refreshes, and what's re-created? | **70450:** 1074 textures held at 0, 1110 after RestedXP made more. **Questie:** its fader and a quest update brought nothing back and made nothing new. Its tracker is a backdrop (nine pieces plus `Center`) that Questie itself keeps at alpha 0 (tree dump, before the hold), with a sizer and a minimal-atlas scroll bar. There was no background option to try (skipped). **RestedXP:** a new step brought back 4 (the step frames' `Center`) and made 36 (a new step frame's backdrop, check buttons and highlight). Its theme changed and back brought back **954**: every backdrop piece of the window (106 backdrops, 9 pieces each). Closing and reopening it: 0 and 0. So RestedXP re-sets its backdrops' alpha on a theme change and builds frames per step: a skin needs hook-and-hold on each piece and a fresh pass after each step. |
| QS.3 | Questie's tracker and Blizzard's: both shown, or does Questie hide Blizzard's? | **70450: Questie hides Blizzard's** (`ObjectiveTrackerFrame` not shown, alpha 1, so hidden, not faded; the owner: "only questie's"). Glass UI's tracker skin and a Questie skin never share the screen. |
| QS.4 | The arrow: rotated by `SetRotation`, angle in `orientation`; where it sits against Glass Panel | **70450:** turned by its texture's `SetRotation` (7 calls while the owner turned), and `orientation` holds the last angle (-0.06 both). It is anchored `TOP` to the screen's `TOP` at (-9.4, -127.8): 128 px from the top. Glass Panel's bar edge is at 109, so it clears the bar by 19 px; the owner: not over it. Its black colour is the owner's own RestedXP arrow skin, not a fault. Nothing else looked broken (the owner). |

## The accent on the yellow titles (#71, docs/PLAN.md "The accent on Blizzard's titles")

`/fp steps skin accent`, with the tracker and the meter on screen. Each check reads the tracker's
"All Objectives" and window 1's meter title (`GetTextColor`) against `Suite.Accent()`, saved as
`SkinProbeDB.results["AC.<label>"]`.

| # | Question | Result |
|---|---|---|
| AC.1 | Ice and gold, live: both titles follow at once | not run yet |
| AC.2 | Edit Mode's Text Size with the skins on: the accent holds | not run yet |
| AC.3 | Skins off: Blizzard's gold back; Text Size while off keeps it; on again: the current accent | not run yet |
| AC.4 | Changed in combat: at once, nothing blocked | not run yet |

## The quest tracker (#55, docs/QUEST-TRACKER.md part 2)

`/fp steps skin tracker`, with Glass Quest Tracker **disabled**: while it's loaded, it owns the
tracker and Glass UI steps aside. Each check reads the skin's switch, where our panel sits
(`populated` or `header`), the NineSlice's alpha, whether the Quests section's header bar is
blanked, the collapses and Glass UI's failures. These are saved as `SkinProbeDB.results["QT.<label>"]`,
and `/fp skin tracker` prints the same. The collapse and Edit Mode steps wait for the owner's hands,
so Next alone can't pass them.

| # | Question | Result |
|---|---|---|
| QT.1 | Each theme on the tracker (clear, smoked, class): readable, the right edge on the glass | **70450: passes** (second account, runs #259-#260). Clear (backing 0.35), smoked (0.92) and class: each faded, blanked, panel `populated`, no failure. Every line readable, and the '-' on the glass (owner: yes). |
| QT.2 | The tracker and a section collapsed and expanded; Edit Mode move, Height, Text Size: the panel follows; no gold bar or shine flashes | **70450: passes.** Collapsed: on the header. Expanded and the Quests section collapsed and expanded: `populated`. After an Edit Mode move with a new Height: `populated`, and the glass followed (screenshot). No gold bar or shine flashed (owner). |
| QT.3 | Over bright ground: every line readable at clear's 0.35 backing (else a denser per-skin backing) | **70450: yes** (owner, over a bright pink sky): clear's 0.35 is enough, so no per-skin backing. |
| QT.4 | Off live: exactly Blizzard's; collapsed while off, on again: placed on the header | **70450: off passes** (Quests header bar back, the owner: exactly Blizzard's). Collapsed while off, then on: not exercised. The tracker was collapsed while off (logged), but expanded again before Skin on was pressed (the screenshot shows it expanded and glassed), so the check FAILed on `collapsed`. The skin never collapses or expands it. The offline test covers the case (test_tracker). |
| QT.5 | After a /reload; in combat; a quest routine under `taintLog 1`: nothing blocked, no error | **70450: partly.** After the /reload and in combat: on, `populated`. Nothing blocked, and no Glass UI failure. BugSack's only error was Blizzard's `BagsBar.lua:125` taint-log noise (50 times), as on the merchant's pass. **The quest routine (accept, progress, turn in) is still to do** (owner: later). |

### The quest timers on a pill (#73)

`/fp steps skin timer`, with a timed quest to take (or one up). Each check reads `QuestTimerFrame`:
- its Border's and Header pieces' alpha;
- its title's colour against `Suite.Accent()`;
- our pill (seen, and rising above the timers);
- the band's top against the Header's (below the timers' bottom), and against the tracker's once
  they're gone.

These are saved as `SkinProbeDB.results["TM.<label>"]`, and `/fp skin timer` prints the same.

Timed quests are too rare to wait for (the owner, 2026-10-20), so **`/fp steps skin timerfake`** runs
the same checks on fake timers:
- **How:** it swaps `C_QuestLog.GetQuestTimers` for an answer of its own (one 5-minute timer, then two),
  lending a quest of the log its ID so a row's tooltip and click still work. Blizzard's own code
  builds the box, the rows and the tracker's padding from that answer.
- **What it covers:** TM.1, TM.2, TM.4 and TM.5, and the hover and click out of combat.
- **What it doesn't:** the swap taints that path, so it says nothing on taint. TM.3 still needs a real
  timed quest. It runs without the taint log, out of combat, and ends on a /reload.

| # | Question | Result |
|---|---|---|
| TM.1 | A timer up: its dialog art faded, its title in the accent, on a pill of its own, the band below it, readable | **70450: passes** (`timerfake`, second account, 2026-10-20). One timer: the timer box 875..816, the pill 881..824 (6 above, 8 off its bottom), the band and Header from 808 (77 below the tracker's top, the box's 59 + 18). Two timers: the box down to 800, the pill to 808, the band from 792. Border and header art at 0, the title in the accent (gold). The owner: on a pill of its own, readable. |
| TM.2 | The tracker collapsed and expanded with a timer up: the same | **70450: passes** (`timerfake`): collapsed and expanded, the same places, the band alone under the pill when collapsed. |
| TM.3 | A row's tooltip and click (the quest log), out of combat and in, under `taintLog 1`: nothing blocked | **70450: out of combat, on fake timers, the tooltip and the click work** (the owner). The taint part still needs a real timed quest: the fake taints that path. |
| TM.4 | Off live: Blizzard's dialog box and gold title back, no pill; on again: the same as TM.1 | **70450: passes** (`timerfake`): off, the border and header art at 1, the title in Blizzard's gold (1, 0.8235, 0), no pill, and the diamond-metal box back (screenshot). On again: as TM.1. |
| TM.5 | The timer gone (turned in or expired): no pill, the band back at the tracker's top | **70450: passes** (`timerfake`, End timers): no timers, no pill, the band and Header back at the tracker's top (885). |

## The damage meter (#49)

Discovery before the skin's plan. `Blizzard_DamageMeter` (`origin/forever` @70450) loads on Forever.
`DamageMeter` is an Edit Mode system that holds up to three session windows,
`DamageMeterSessionWindow1`-`3`, created on first use. Each window has:
- a `Header` atlas;
- `MinimizeContainer.Background`, whose alpha Blizzard sets from the Edit Mode Background setting;
- pooled bars in a `ScrollBox`;
- a `SourceWindow`, the breakdown of one bar.

Style (Default, Bordered, Thin) swaps each bar's background atlas and its edge.
`/fp steps skin meter` measures all of this; `/fp skin meter` reads the state at any time.
The results are in `SkinProbeDB.results["DM.<label>"]` and the log.

| # | Question | How | Result |
|---|---|---|---|
| DM.1 | The full tree in the current style: frames, regions, atlases, protection, and which textures ignore `SetAlpha`. | steps 1-4 | **70450:** see "What it's made of" below. Nothing in the tree is protected or forbidden. Of 112 textures, none ignores `SetAlpha`. |
| DM.2 | What Bordered and Thin change on a bar, and how each style looks. | steps 5-9, screenshots | **70450:** only the bar's background. **Bordered** swaps it to `UI-HUD-CoolDownManager-Bar-BG` and hides `BackgroundEdge`. **Thin** keeps Default's atlases and edge, and only re-anchors the bar. The header, the window background and the buttons don't change with the style. At 16 px bars, the three styles look almost the same on screen. |
| DM.3 | The breakdown window's tree. | steps 10-11 (Shift-click) | **70450:** `SourceWindow` is strata HIGH, with one `Background` (`common-dropdown-bg`) and its bars from the same entry template, 358 wide. Its `CloseButton` (`RedButton-Exit`) stays hidden. A plain click's breakdown closes at the next mouse press outside it (`GLOBAL_MOUSE_DOWN`), so pressing Measure closed it: the first run read its tree hidden but filled (two bars), with no screenshot. Shift-click pins it, and shows its close button (`InitEntry`, `SetSticky`). The procedure now waits for a pinned breakdown; **the pinned capture is still to run.** |
| DM.4 | A second window: its name, and that it repeats window 1's tree. | steps 12-13 | **70450:** `DamageMeterSessionWindow2`, the same template and the same tree, one level higher. The owner already ran two windows (Healing Done, Damage Done), so no third was made. |
| DM.5 | The minimized window. | step 14, screenshot | **70450:** the window stays shown with `IsMinimized()` true. Only the header and its buttons remain; the minimize button turns to "+". `IsMinimized()` reads nil until a window has been minimized once. |
| DM.6 | In combat, are a bar's value and colour secret? | step 15 (optional) | **70450:** `StatusBar:GetValue()` is **secret in and out of combat**. `GetStatusBarColor()` reads plain white, because the class colour is a vertex colour on the fill texture (`DamageMeterEntry.lua:360`). The skin never needs to read the values; it restyles only textures. |

**What it's made of** (70450, the owner's setup: style Default, Background 50%, window alpha 1, bars 16 px, windows 266x165 and 266x176):
- `DamageMeter`: the Edit Mode system. It holds `Selection` (Edit Mode's highlight, shared by every system: not ours) and `EditModeResizeButton`, plus the windows as its children.
- Each `DamageMeterSessionWindowN`:
  - `Header`, BACKGROUND, `ui-damagemeters-header-bar`. `SessionTimer` and the dropdowns' text are fonts, left alone.
  - Buttons:
    - `MinimizeButton`: `UI-QuestTrackerButton-Collapse-All`, `-Pressed`, `-Red-Highlight`; the expand atlases when minimized.
    - `SettingsDropdown.Icon`: `common-dropdown-a-button-settings-shadowless`.
    - `SessionDropdown.Background`: `common-dropdown-c-button`, plus a hover `Arrow`; its `ResetButton` uses `auctionhouse-ui-filter-redx`.
    - `DamageMeterTypeDropdown.Arrow`: `common-dropdown-a-button-shadowless`.
  - `MinimizeContainer.Background`, BACKGROUND, `damagemeters-background`. Its alpha is the Edit Mode Background setting (0.50 here), set by Blizzard's `UpdateBackground` on every change.
  - `MinimizeContainer.ResizeButton`: `damagemeters-scalehandle`, `-hover`, `-pressed`. Alpha 0 until hovered (Blizzard's animation).
  - Bars (pooled, `ScrollBox.ScrollTarget.#n`) and the hidden `LocalPlayerEntry`, one template:
    - an `Icon` frame (spec icon file);
    - a `StatusBar` with its fill (unnamed, `UI-HUD-CoolDownManager-Bar`), `Background` (`ui-damagemeters-bar-shadowbg`) and `BackgroundEdge` (`ui-damagemeters-bar-shadowedge`);
    - the `Name` and `Value` fonts.
  - `ScrollBox.Shadows.Upper/Lower`: no art. `ScrollBar` is a MinimalScrollBar.

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
  leaves `Logs\taint.log` untouched (it kept its old date after a full exit): an old date means "nothing
  logged", not "logging off". Level 2 also logs every tainted read, so use it to see an addon's taint.
- A colour texture painted with `SetGradient` ignores a later `SetAlpha`, and `GetAlpha()` keeps
  reading 1 (porting guide section 3, measured twice on 70374).
- Leatrix Maps 1.60.23 reads "Simple map frame" once at its `ADDON_LOADED` (default On), applies
  it at `PLAYER_LOGIN`, and writes it back at logout (`Leatrix_Maps.lua:2887, 2956, 2962`).
