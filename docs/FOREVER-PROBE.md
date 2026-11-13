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

### The loot window and the loot roll history (#105, docs/LOOT.md)

`/fp steps skin lootglass`. Each check reads:
- the shell (the NineSlice's alpha);
- every shown row: its glass, its plate faded; for loot, its slot faded and its hover stroke
  desaturated; for the history, its glass at the art's level − 1;
- opening and closing in combat;
- blocked and forbidden actions.

A fake history row is built by the probe from Blizzard's template; a `/reload` clears it. Saved as
`SkinProbeDB.results["LT.<label>"]`.

| # | Question | Result |
|---|---|---|
| LT.1 | The first loot of the session in combat, styled a frame later; closed in combat; a second loot in combat through the installed hook, closed another way | **Rows: pass** (run 1, 2026-10-21): first and second loot in combat, every row in glass, closed in combat twice, 0 blocked. **The shell: fail, #109.** `NineSlice` and `Bg` read alpha 1 at every open (see below) |
| LT.2 | The look; taking items one by one; money; an auto-loot sliding out | Taking items and auto-loot: 0 blocked. The look: "it's the blizzard ui", the frame still Blizzard's (#109) |
| LT.3 | "Open Loot Window at Mouse"; Edit Mode save and discard; off and on | At the mouse and Edit Mode saved: rows pass, shell #109. Discarded: read with the window closed (Edit Mode needs "at mouse" off). Off: Blizzard's look; after on, the frame was skinned properly (the owner) |
| LT.4 | `/loot`: empty, resized, reopened; the fake row in glass at 399; real rows, master loot and the roll-100 effect when group content allows (else unverified) | Empty: **pass**, the shell faded ("now we have the right skin"). Resized: read with it closed. **The fake row: not built.** The step ran with `/loot` closed ("type /loot first"); rev 2 makes it a button that says so. Real rows, master loot, roll-100: unverified |

**#109, the loot window's frame (70450).** The loot skin fades `LootFrame.NineSlice` and
`LootFrame.Bg` (frames) in its style pass, a frame after each show.
- `lootshell`: right after a loot, both read alpha 1, with no `fade:` failure and nothing
  protected. After the skin was turned off and on, both read 0 and stayed 0 on the next loot.
- `loottimeline`, sampled every frame from `LOOT_OPENED`:
  - the style pass runs at about frame 2 (0.01-0.02 s), while the window's `ShowAnim` plays
    (`setToFinalAlpha`);
  - inside it, `Fade` returns true, the read-back is 0, and the region counts as faded;
  - every sample after it reads 1.00.

  So the frames' alpha is reset within a frame, without the instance `SetAlpha` hook seeing it.
  The rows' **textures** hold. FrameXML has no such write (Codex, consulted). The mechanism is
  unknown: likely native animation state on the window's children.
- **The fix:** each shell piece (the NineSlice's nine, the Bg's four) is faded as well as the two
  frames, as Ellesmere does ("so a relayout cannot resurrect it"). The probe now reads the shell as
  shown: the frame's alpha times each piece's, the most visible.
- The history window (no `defer`, no open animation) faded normally.
- **lootglass run 2, with the pieces faded too:** the pieces came back as well, and some row plates.
  So it isn't limited to frames.
- **`lootshell` rev 2, run with "Open Loot Window at Mouse" both off and on, the same both ways:**
  - first loot: a piece read 1 while the kit's record said held at 0 (`to 0`, not busy);
  - **"Fade again"** through the same records on the settled window: 0, **and it held on every later
    loot**.

  So it isn't the records, the hook, or the at-mouse path. **A fade applied while the opening
  animations play (the window's `ShowAnim`, each row's, `setToFinalAlpha`) is undone by the time they
  end; a fade applied before them survives them.** That fits the animations restoring the alpha
  they captured at `Play`. The mechanism is still unverified; the behaviour is measured.
- **The fix:** each pass (the style pass, and the rows after an Update) runs again once those
  animations have finished. It reads `IsPlaying` (a getter, no hook) a frame at a time, through
  `Engine.Defer`, bounded by **0.5 s of elapsed time**, not a frame count. Codex on #110: 30 frames
  pass in under 0.1 s at 300 fps.
- **lootglass run 3** (rev 3, account #1, "at mouse" on by default there, then off for Edit Mode):
  **the skin passes.**
  - The shell is at 0 and the rows are right at every read taken after the animations: the second
    loot in combat, closing in combat twice, at the mouse, Edit Mode saved and discarded, `/loot`
    empty and resized.
  - The fake history row is in glass at 399.
  - 0 blocked, and the look: yes. The screenshot of the first loot in combat shows it in glass.
  - **The three failed reads were the probe reading too early:**
    - "first in combat" and "on again" were read before the pass that follows the animations;
    - "look" read no item row, only money.

  Rev 4 waits for the opening animation and 0.3 s before reading, and reads "on again" in its own
  step.

### The world map and quest log (#99, docs/MAP.md)

`/fp steps skin mapglass`. Each check reads:
- the shell (the NineSlice's alpha), the disc against the book's texture, a glyph on every shown
  button;
- every shown crumb's normal texture, and the overflow button kept;
- the quest log's background, its shadow blanked, and every shown zone header (its glass bar,
  its bar faded, its +/- desaturated);
- whether `NavBar.Refresh` and `QuestScrollFrame.UpdateBackground` are instance methods on this
  build;
- `IsProtected` on ours, and blocked and forbidden actions.

Saved as `SkinProbeDB.results["MP.<label>"]`.

| # | Question | Result |
|---|---|---|
| MP.1 | The first opening of the session in combat (M), styled a frame later; the look against the mockup | **Pass** (2026-10-20, run 1): installed a frame after the show in combat. Everything in place: 3/3 crumbs, 2/2 headers, the log's background faded, the shadow blank, one glyph on the shown button, the disc with the portrait. Both hooked methods exist on 70450 (`NavBar.Refresh`, `QuestScrollFrame.UpdateBackground`), nothing of ours protected, 0 blocked. The look: "close enough". **The frame buffer:** the glass shows round the map windowed and maximised on 70450 (screenshots), so W1.3 holds |
| MP.2 | Maximise and minimise (in combat too): the NineSlice through `SetAtlas`, the disc following the portrait texture, the glyph swap; the quest log toggle and L after a map-only opening | **Pass**, except one read. Maximised: the shell still faded, the disc hidden with the portrait, the glyph on the swapped button. The quest-log toggle and L: pass. **The "minimised" read (in combat) found the map still maximised**, without a blocked action. Either Next was pressed early, or minimise does nothing in combat; `maptracker` asks |
| MP.3 | Map changes and a crumb's dropdown: every crumb faded a frame after the overlay refresh, the overflow button visible | **Pass** (3/3 after the changes; no overflow shown on this map). The owner: "just not sure about the scrollbar color" (the quest log's `MinimalScrollBar`, Blizzard's bronze, left stock in v1) |
| MP.4 | The quest log: collapse, an empty search, a scroll, tracking, details and back: every header in glass, the shadow blank, nothing blocked | **Pass** (2/2, shadow blank, 0 blocked). The owner: a header "auto expands after a collapse". That's Blizzard's: `QuestLogMixin:Refresh` runs `QuestMapFrame_ResetFilters`, which expands the current map's headers and collapses the others (`QuestMapFrame.lua:310, 927-940`), and hovering a quest pin expands its header under `scrollToLogQuest` (1251-1256). The skin only fades, tints and adds a child bar. **Confirmed stock:** the owner saw the same with addons turned off |
| MP.5 | The same pass with the taint log on; off while maximised, on in details; the first opening from the objective tracker in combat | **Taint log on: pass.** BugSack held one error only: `SuperTrackedFrame.lua:39`, x2265. That's NodeRadar's instance hook on `UpdateAlpha` (`NodeRadar/Marker.lua:410-427`) under the taint log (PORTING-TBC-TO-FOREVER.md); nothing from the map, quest log or bar. **Off** (maximised): Blizzard's look, nothing of ours. **On** (details): pass. **The tracker case** (`maptracker`, after a redeploy stopped the first run): **pass**. Opened from a tracked quest in combat, styled a frame later, 2/2 headers, 3/3 crumbs, 0 blocked. **Minimise in combat:** the map stays maximised again, with no blocked action. Out of combat it minimises (pass). Blizzard's `SetDisplayState` goes through `ShowUIPanel` and the panel manager (`QuestLogOwnerMixin.lua:108-160`), so it's very likely stock; a check with the skin off is asked. The owner on the scroll bar: keep Blizzard's, which matches the other windows' bars |
| MP.6 | `/fp steps skin mapchecks` (Codex on PR #100): minimise in combat **with the skin off**, which tells whether staying maximised is Blizzard's; Leatrix Maps' simple frame On in game: the skin yields (`Status` names Leatrix_Maps, nothing of ours built); Off again: back in glass | **The Leatrix yield: pass** (2026-10-20). With the simple frame On, `Status` was "skipped: Leatrix_Maps rebuilds this window" and nothing of ours was built. Off again: in glass, all checks pass. **Minimise in combat with the skin off: it works** (the owner: it didn't stay maximised; read windowed). **With the skin on, the owner then minimised and maximised in combat repeatedly without a problem**, checked by hand. The two failed reads were clicks that didn't land while fighting (the owner: "me trying not to die while doing the instructions"), not the skin. **Measured by `mapminimise`:** in combat and out, Blizzard's `MinimizeButton` was under the cursor (nothing of ours), the press was seen, the swap happened, 0 blocked, no "Interface action failed" message. The owner on the glyph buttons: "hover is very subtle if there is one" (the close button's recipe: the glyph from 0.85 to full) |

### The character window (#94, docs/CHARACTER.md)

`/fp steps skin character`. Each check reads the shown slots (their well, their frame faded, and the
**NormalTexture gate**: its alpha still 0 after equips, unequips and recolours), the stats headers (a
header is `Background` + `Title`), the mode and sidebar tabs mirrored, `IsProtected`/`IsForbidden` on the
slots and our wells, and blocked actions (taint log on). Saved as `SkinProbeDB.results["CH.<label>"]`.

| # | Question | Result |
|---|---|---|
| CH.1 | The first opening of the session in combat; an item used from a slot in combat; the look against the mockup | **Pass** (2026-10-20, run 1, a level 7 mage): opened first in combat, 19/19 wells, frames faded, 3/3 headers, 9/9 tabs mirrored, nothing protected, 0 blocked. The item use in combat was skipped. The look: yes |
| CH.2 | Equips, unequips, a weapon swap, the flyout, a link, the model's controls, the stats scrolled: nothing blocked; the NormalTexture gate | **Pass**: the **NormalTexture gate holds on 70450**. `normalBack` stayed 0 on all 19 slots after equips and unequips (`CH.equips`), the flyout, the model and the scroll. `SetItemButtonNormalTextureVertexColor`'s `SetVertexColor` doesn't bring the faded alpha back here, so the fade stays (Codex's P2 on PR #95). The ammo slot isn't read (a mage has none); it takes the same call |
| CH.3 | The sidebar tabs; reputation, skills, PvP, currency (a transfer and its log if available), statistics | **Pass**, 6/6 tabs mirrored on each pane, 0 blocked. The owner: the bronze and yellow list headers (reputation, skills, statistics) should look like the quest tracker's. Done; see CL |
| CH.4 | The right pane collapsed, the window reopened, expanded; the pet tab | **Pass** (19 wells, 3/3 headers after it). The pet tab was skipped (no pet) |
| CH.5 | Off, a tab changed, on | Off: **pass** (Blizzard's look, 19 normal textures back, nothing of ours). On: "wells 0 of 0": the window was still on Reputation, where the slots are hidden. The procedure's fault: rev 2 asks for the Character tab first |

The list headers (`/fp steps skin characterlists`): each shown top header in the reputation,
skills and statistics lists (a `Name` and a `StateIcon`) has its glass bar shown, its bronze
BACKGROUND faded and its +/- desaturated (tinted). The checks also cover a collapse, the
statistics' sub-categories and a scroll, and off and on.

| # | Question | Result |
|---|---|---|
| CL.1 | Every list header in glass on each pane, after a collapse and a scroll; nothing blocked; the look (the tracker's) | **Pass** (2026-10-20, run 1). Reputation after a collapse 2/2, skills 4/4, statistics 1/1 with its sub-categories expanded and scrolled; 0 blocked. The look: yes (gold names and +/-, the glass bar, the sub-categories' squares gold, not red). The first step read the paper doll (Next pressed before the tab): rev 2 waits for the Reputation pane. The grey bars on statistics' sub-categories are Blizzard's hover highlight (`BackgroundHighlight` at 0.10, `StatisticsFrame.lua:281`), not ours |
| CL.2 | Off: Blizzard's headers; on: ours again without a Blizzard update | **Pass**: off, Blizzard's shell and headers (0 of 1 ours); on, 1/1 again |

### Guild & Communities (#92, docs/GUILD.md)

`/fp steps skin guild`. Each check reads each pane against its section, each tab's selection art against
its own checked state, the tenants' panels applied, the shell, and blocked actions (taint log on), with
`IsProtected`/`IsForbidden` on the frames we parent to. Saved as `SkinProbeDB.results["GD.<label>"]`.

| # | Question | Result |
|---|---|---|
| GD.1 | The first opening of the session in combat; the chat mode; the look against the mockup | **Run 1 (70450, 2026-10-20): passes.** The first opening of the session in combat, then the chat mode: the shell faded, the panes with their sections, the tabs mirrored, nothing blocked. The owner: yes, "all but the minimize/maximize button which is yellow on the mockup, but we can follow blizzard". |
| GD.2 | The roster: a sort, a member's details, a note or a rank edited: nothing blocked | **Run 1: passes.** A sort, a member's details, a note or rank: nothing blocked (taint log on; owner: no message). |
| GD.3 | The other modes, minimized; a Shift-click on the chat tab: the selection mirrored | **Run 1: passes, one procedure FAIL.** Minimized, Blizzard hides every side tab, and the check wanted at least one ("tabs mirrored 0 of 0"); rev 2 allows none when minimized. The other modes and the Shift-click pass. |
| GD.4 | With GuildSpy: its tabs and panel handed over and applied | **Run 1: passes** for the tabs and panel as GuildSpy shows them today (not handed over yet: its side waits for the owner's go-ahead). Owner: yes. |
| GD.5 | Off (tenants told), a tab changed, on | **Run 1: passes.** Off: Blizzard's look, tenants told; on again: as before. |

**Run 2 (2026-10-21, run #403, with GuildSpy#64 installed):** every check passed but one.
- **GuildSpy:** every read had "tenants 2 tabs, 1/1 panels applied", the first opening in combat
  included. Off: "0/1 panels applied, tenants told"; on again: 1/1. 0 blocked. The look: yes.
- **Step 11 failed** ("the window not shown"): closing Social settings after the Shift-click had
  closed the guild window. Rev 3 asks to reopen it before Next.
- **The owner, at step 8:** "the edit box for the guild note is not skinned". A note is edited in a
  Blizzard static popup (`StaticPopup_Show("SET_GUILD_COMMUNITIY_NOTE")`, `GuildRoster.xml:150-156`),
  and the static popups' skin (#5) is parked. The member-detail panel it opens from
  (`CommunitiesFrame.GuildMemberDetailFrame`, its note boxes `TooltipBackdropTemplate`) isn't in
  the guild skin either. Left for a follow-up.

### The game menu (#90, docs/GAME-MENU.md)

`/fp steps skin gamemenu`. Each check reads the menu and its shown buttons against what Blizzard shows
(glass on each, the slices faded, the hover glow tinted, the border and header art faded, the title
tab), the menu's size against its first, and blocked actions (taint log on). Saved as
`SkinProbeDB.results["GM.<label>"]`.

| # | Question | Result |
|---|---|---|
| GM.1 | The first opening of the session in combat, then out of combat; the look against the mockup; the hover glow | **Run 1 (70450, 2026-10-20): passes.** The first opening of the session was in combat, after a /reload, then out of combat: every button on glass, faded and tinted, the title tab, nothing blocked. The owner: the look and the white hover glow, yes. The screenshots match the mockup. **Run 2 (70888, 2026-11-13, run #226-#228):** the look and the white hover glow confirmed again (screenshots, off and on); the first opening in combat skipped. **Run 3 (70888, 2026-11-13, run #236/#237):** **the first opening of the session in combat passes:** 9 of 9 on glass, faded, with the glow, 0 blocked (screenshot). The out-of-combat check after it failed on timing only: Next was pressed with the menu closed. The owner: the look, yes. |
| GM.2 | Settings and back (its close button, Esc, in combat); Esc while casting: nothing blocked | **Run 1 doesn't count** (Codex on #91, P2): the three Settings steps' waits were already true when each step began (the menu open, Settings closed), so they passed without a Settings visit. Only Esc while casting was really exercised: nothing blocked. Rev 2's waits accept a return only after seeing Settings open during the step (in combat for the combat one). **Run 2 (70888, 2026-11-13): passes out of combat.** Settings opened from the menu and closed by its close button, then by Esc: back on the menu each time, 9 of 9 buttons on glass, faded and with the white glow, the size held (256 x 466), 0 blocked. Esc while casting: the same. The owner saw no blocked message. **In combat: skipped, still to do.** **Run 3 (70888, 2026-11-13, run #236/#237):** **in combat passes:** Settings opened from the menu and closed in combat, back on the menu with 9 of 9 and 0 blocked; Esc while casting, in combat, the same. Settings by its button and by Esc out of combat passed again. The owner: no blocked message. `Logs\taint.log` during the run: Buffy's and Priestly's entries only, nothing of Glass UI's. **GM.2 complete.** |
| GM.3 | Log Out and Exit Game cancelled, Return to Game; AddOns, Edit Mode, Macros: the size held | **Run 1: passes, one procedure FAIL.** The "exits cancelled" check ran with the menu closed (it reads the open menu), with nothing blocked. Return to Game closed it; after AddOns, Edit Mode and Macros the size matched the first. **Run 2 (70888, 2026-11-13):** AddOns, Edit Mode and Macros: the size held, 9 of 9, 0 blocked. Log Out and Exit Game skipped (in a city). **Run 3 (70888, 2026-11-13, run #236/#237):** **complete:** Log Out and Exit Game cancelled, the menu back with 9 of 9; Return to Game closed it; the size held after AddOns, Edit Mode and Macros. |
| GM.4 | Off with the menu open, then on | **Run 1: passes.** Off with the menu open: Blizzard's red, nothing of ours. On: as before. **Run 2 (70888, 2026-11-13): passes:** off, 0 of ours; on again, 9 of 9. **Run 3 (70888, 2026-11-13, run #236/#237):** the same. |

### The bags (#88, docs/BAGS.md)

`/fp steps skin bags`. Each check reads every open bag window and its shown item buttons against what
Blizzard shows: the shell faded, the header band, glass on every slot, the rims faded, an empty slot
dimmed, the combined window's greyed bag icon faded, a filled one shown. An empty slot is read from
the client (`C_Container.GetContainerItemInfo`); until #170 it was the button's own empty atlas, a key
70707 removed. It also records Glass UI's memory, the framerate and blocked actions. Saved as
`SkinProbeDB.results["BG.<label>"]`.

**On 70888 (2026-11-12, #168), two runs with #170's fix (#175):**
- run #164 on one account: 6 windows, 52 slots, 3 free;
- run #257 on another: 64 slots, 22 free.

Every check passes but the one after `/reload` (BG.6).

| # | Question | Result |
|---|---|---|
| BG.1 | Separate bags, all open: every window and slot as above; the look against the merchant's | **Run 1 (70450, 2026-10-20): every check passes** (4 windows, 34 slots: glass on all, 17 empty dimmed, 17 filled shown). The owner: "apart from the gigantic circles yes". The portrait discs were about four times too big: the bags shrink the portrait to 36 (`SetPortraitTextureSizeAndOffset`, ContainerFrame.lua:789), and the mask read far wider. The disc is now round the portrait itself (`onPortrait`), with a 4 px ring. **70888, run #164: passes** (6 windows with the keyring, 52 slots: glass on all, 7 empty read from the client and 7 dimmed, 45 filled shown; 0 unread). Owner: yes. Run #257's first check counted nothing: the bags were closed when it was passed. Its later checks cover the separate view (64 slots, 24 of 24 empty dimmed). |
| BG.2 | The title band: 20, 26 or 34 | **Run 1: unsure.** The three bands barely differ to the eye: 26 kept. **70888:** "they all read ok", then 26 again: 26 stays. |
| BG.3 | A search, an item moved, a sort: the dims follow | **Run 1: passes** (search, move, sort). **70888: passes in both runs** (7 of 7, then 24 of 24, each time). |
| BG.4 | The backpack opened and an item used in combat, the taint log on: nothing blocked | **Run 1: passes.** Opened and used an item in combat with the taint log on: the item worked (owner: yes), nothing blocked. **70888, run #257: passes.** The backpack was open in combat (20 of 20 slots on glass). The item worked (owner: yes), and nothing was blocked. Run #164 skipped it. |
| BG.5 | The combined window | **Run 1: passes.** Owner: yes. **70888: passes in both runs.** Run #164: 48 slots, 3 empty dimmed, 3 bag icons faded. Run #257: 58 slots, 22 of 22 dimmed and faded. Owner: yes. In #257's screenshots, Blizzard's greyed bag icon fills each empty slot with the skin off, and with it on they're plain glass wells. |
| BG.6 | Off: Blizzard's look; a change; on: re-synced; after a /reload | **Run 1: off and on pass.** The after-`/reload` check FAILed with no bag open: its wait step was moved past by hand before a bag was opened. Not a skin fault. **70888: off and on pass in both runs.** Off: no glass, no dim, every bag icon back. On: all back. The after-`/reload` check FAILed the same way in both runs, Done before a bag was open. Bags opened after a reload are skinned in every run's later checks. |
| BG.7 | The cost: Glass UI's memory before and after, the framerate with every bag open | **Run 1:** Glass UI 394 KB before, 757 KB with 4 windows and 34 slots open (combined, 30 slots: 646 KB); about 150 fps throughout. Acceptable: the Section fallback isn't needed. **70888:** run #164 1092 KB before, 2034 KB with 6 windows and 52 slots, 2489 KB combined (48); run #257 3755 KB before, 3740-4412 KB with 6 windows and 64 slots (the search, move and sort checks: its first separate check ran with no bag open), 5595 KB combined (58). 55-70 fps in both, the runs taken in a crowded capital and in the open world, so not comparable with run 1. |
| BG.8 | 70707 on (#170): an icon set from a file reads no atlas (`BG.atlas`, the empty test's premise); empty slots read from the client (`C_Container.GetContainerItemInfo`), not the skin's key, with free slots in a bag shown but none found a FAIL; the combined window's greyed bag icon faded | **70888: passes in both runs.** `BG.atlas`: `bags-item-slot64`, then nothing after `SetTexture`. Every empty slot the client reports was found (0 unread) and dimmed: 7 and 3 in run #164, 24 and 22 in run #257. Every combined bag icon was faded, and given back when off. |

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
| ML.7 | Run 3 (#86, sections only): each pane against Blizzard's state at an ordinary vendor, a smith (Merchant → Buyback → Merchant, repaired), a currency vendor and back without a /reload; the tabs; the close button (rest, hover, press, it closes, reopened); the page labels; off, a vendor change, on; after a /reload; the taint log on | **Run 3 (70450, 2026-10-20): every pane matched Blizzard** at an ordinary vendor (no repair, no junk, no currency: no left box, no currency box) and at a smith (Repair All and Repair Item shown, no guild repair: the left box). The close button passed at rest, hover, press and close, the page labels matched their buttons, and off, a vendor change, then on passed. The owner: the guide behind "i barely see it"; the look, the close button, the repair and page buttons all yes. Sell All Junk never showed, and `C_MerchantFrame.IsSellAllJunkEnabled` returned nothing readable. The four FAILs were the procedure's: two checks on a `MERCHANT_SHOW` step ran before Blizzard shows the window (those steps check nothing now), and two "Merchant tab" checks were taken on the Buyback tab (the wording is now "only then press Next"). Not run: a currency vendor (skipped), the after-`/reload` check (the run stopped at the reload). **Run 4 (70888, 2026-11-13, run #244/#245): every pane matched Blizzard again,** at an ordinary vendor (Merchant, Buyback empty, one item sold and shown), at a smith (the repair box on glass, its unusable items red), and back at an ordinary vendor; the close button at rest, hover and close, and on the reopened window; off (Blizzard's close art back), a vendor change, on. The owner: the look, the close button and the repair buttons, yes. One FAIL, the procedure's: the smith's "back on the Merchant tab" check was taken on the Buyback tab. **Still not run: a currency vendor** (skipped again). **The after-`/reload` check measured nothing** (Done pressed 6.6 s after the reload, before a vendor was open), but the run's first vendor was the first of a session loaded 100 s earlier, and it matched Blizzard. `Logs\taint.log` was not written during the run (the log on from step 1). |

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

### The trade window (#113, docs/TRADE.md)

`/fp steps skin tradeglass`, between the owner's two accounts, read on the one running it. Each
check reads:
- the shell: the most visible of its pieces;
- the 14 wells: the glass shown at the slot's level − 1, and the socket, plate and slot frame faded;
- Trade and Cancel: their art faded, their glass shown;
- the recipient's red: Blizzard's red plate if and only if our mirror shows;
- the accept highlights and the warning icon, as Blizzard shows them;
- whether a slot's plate, its socket and the recipient's overlay read as forbidden;
- blocked actions.

The money input is never read: it is forbidden. Saved as `SkinProbeDB.results["TD.<label>"]`.

| # | Question | Result |
|---|---|---|
| TD.1 | The first trade of the session, styled a frame after its show; one opened from the other side; the look | **Pass** (70888, run #211/#212, 2026-11-12). The first trade of the session: shell 0, wells 14/14, buttons 2/2; from the other side the same. The owner: it reads as the template. The screenshot shows the dark glass, both portraits on discs, the panes, each slot a well (the 70707 icon mask reads fine), Trade and Cancel on glass, the gold X on its disc |
| TD.2 | Every input route on this side (drag, click-drop, a drop on the background, a move between slots, one taken back; money typed and dropped from the cursor) | **Pass** for the items (3 in, one taken back: 2), 14/14 throughout, 0 blocked. Money typed (1 copper) shows in the input. **Money from the cursor not run:** there's no route to it from the bags on 70888. Their coins open the currency tab, as on Retail (the owner checked): the bag money frames set `showCurrencyTracking` (`ContainerFrame.xml:202`), which `MoneyInputFrame_OpenPopup` checks before the money popup (`MoneyInputFrame.lua:219`), and Forever's `ToggleTokenFrame` does nothing while the character has no currency (`Camelot/CharacterFrame.lua:98-103`). Expected, not a client bug (#178); the step asks for typed money only |
| TD.3 | Their side: an item this character can't use (the red mirrored), a stack, money; the enchant slot and its binding warning when available | **Pass.** A stack (Copper Bar ×3) and money read. Once their unusable item was in: red 1, our mirror matching (0 off) at every check after. The step-9 check itself failed on timing: Next was pressed before that item arrived (the screenshot shows only the usable stack). The enchant slot: no binding warning came up |
| TD.4 | Accepting, an offer changed after it (the highlights, the warning icon), Cancel taking the acceptance back, completing (the secure confirmation when it shows) | **Pass, 0 blocked.** The warning icon showed after their offer changed, as Blizzard shows it; Cancel kept the window open; a confirmation dialog showed before completing (the owner), and the next trade opened normally. The completion check failed on timing (Next 2 s after the step, the window still open). **Not measured:** Blizzard's accept highlights never read shown, at the accept step either; the skin never touches them |
| TD.5 | Off and on with a trade open; closed with the X and with Esc; in combat if a trade can open there (else skipped) | **Pass.** Off: Blizzard's look (wells 0, the shell back), screenshot; on again: 14/14, 2/2. Closed with the X and with Esc: 0 blocked. Opened in combat: 14/14, 2/2, 0 blocked |
| TD.6 | Are a slot's plate and socket, or the recipient's overlay, forbidden like the money input? | **No:** plate, socket and overlay all read `IsForbidden` false at every check |
| TD.7 | Rev 2 (Codex on #154): the taint log on from after the first pass to the end, so after the run's `/reload` (which turns it off). Items in on both sides, Trade and Cancel, off and on, the X, Esc, combat: nothing blocked, and nothing of Glass UI's in `Logs\taint.log` | **Pass.** The log on from step 17 to 26 (about 2.5 minutes, every case listed). `Logs\taint.log` was not written during it: its last entries are another addon's from earlier that day, so the client does write it on taint. ForeverProbe recorded no blocked or forbidden action in the run; the owner saw no error |

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

### RestedXP in glass (#56, docs/RESTEDXP.md)

`/fp steps skin rxpglass`, run after launch (2026-11-04). It turns on RXPGuides for this character
only (its state saved in `SkinProbeDB.rxpWas[GUID]`, put back by its Restore step or
`/fp skin rxpglass restore`). Each check reads `RX.<label>`: our glass shown, the backdrop pieces of
GuideName, BottomFrame and Footer at 0, the header's banner at 0, every shown row's pieces at 0 with
our host (a row at alpha 0 is RestedXP's hidden step), every shown card on our glass with its and
its tab's pieces at 0, the list and track, combat, blocked actions. `RA.<label>`: RestedXP's arrow
texture at 0, ours shown, both angles equal (`GetRotation` on both), ours in the accent, the pill's
width the text's plus its padding.

| # | Question | Result |
|---|---|---|
| RX.1 | The look against the mockup; a new step and its card a frame later; rows hovered; RestedXP's theme changed and back (QS.2's 954) | **Passes (70888, 2026-11-13, run #223/#224).** The window in glass: 114 of 114 rows, 2 of 2 cards, the track, no backdrop piece up, the banner at 0, 0 blocked; the owner: it reads like the mockup (screenshot). Hovering rows and RestedXP's theme changed and back: the same. The new-step check was skipped in the run; the owner had used it daily for 9 days on 70888, through many steps, with nothing off. |
| RX.2 | Resized while scrolling; the list collapsed (the glass shrinks to the header and footer, the track hides) and back | **Passes (70888, 2026-11-13).** Resized and scrolled: 114 of 114. Collapsed: the glass shown, 0 rows, the list and the track hidden (screenshot); shown again: 114 of 114, the track back. |
| RX.3 | The arrow turning with RestedXP's (equal angles), the accent ice and gold, the pill after the arrow text size changes standing still, another continent (both at 0) | **Passes (70888, 2026-11-13), one case skipped.** RestedXP's arrow at alpha 0 and ours shown at its angle at every read (0.52 / 0.52), in the accent in gold and in ice. The pill fits its text: 64.3 for 48.3, then 119.9 for 103.9 after the text size change. The owner: it reads like the mockup and turns smoothly. Another continent: skipped. |
| RX.4 | Both skins off (RestedXP's look) and on; in combat; nothing broken in RestedXP | **Passes (70888, 2026-11-13).** Off: RestedXP's look (its 27 pieces back, the banner at 1, our glass and cards gone, its arrow back and ours hidden). On again: as before. The owner: nothing broken. The combat step was skipped in the run; over 9 days of daily play on 70888, combat included, ForeverProbe recorded no blocked action from Glass UI. |

## The accent on the yellow titles (#71, docs/PLAN.md "The accent on Blizzard's titles")

`/fp steps skin accent`, with the tracker and the meter on screen. Each check reads the tracker's
"All Objectives" and window 1's meter title (`GetTextColor`) against `Suite.Accent()`, saved as
`SkinProbeDB.results["AC.<label>"]`.

| # | Question | Result |
|---|---|---|
| AC.1 | Ice and gold, live: both titles follow at once | **Passes (70888, 2026-11-13, run #225).** Ice: the tracker's and the meter's titles 0.65, 0.84, 0.91 at once; gold: 1, 0.82, 0. The owner: both read well, and prefers gold (the default; run #240, which also passed AC.1 and AC.4 again on rev 1). |
| AC.2 | Edit Mode's Text Size with the skins on: the accent holds | **Not measured (run #225):** the step finished as it began, Edit Mode still closed, so the check read titles nothing had touched. Its wait now needs Edit Mode seen open, then closed (rev 2, #180). Run #235 used the deployed rev 1 again: the same. **Passes (70888, 2026-11-13, run #242, rev 2):** the step went on only once Edit Mode had opened and closed (20 s), and both titles were still ice, 0.65, 0.84, 0.91. |
| AC.3 | Skins off: Blizzard's gold back; Text Size while off keeps it; on again: the current accent | **Passes (70888, 2026-11-13, run #242, rev 2).** Skins off with the accent ice: both titles Blizzard's gold; Text Size changed in Edit Mode while off (the step waited for the visit, 18 s): still gold; on again: ice. Run #225 had the same, without the Text Size visit. |
| AC.4 | Changed in combat: at once, nothing blocked | **Passes (70888, 2026-11-13, run #235):** gold pressed while fighting, both titles gold at once (1, 0.82, 0), nothing blocked. |

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
