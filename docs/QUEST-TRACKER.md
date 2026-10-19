# Glass UI's skins in Pearl, the quest tracker, and the questing addons (#54, #55, #56)

Three parts, in order. Each lands as its own PR.
1. **Glass UI's own skins wear the suite theme** (#54): Pearl by default.
2. **The quest tracker** (#55): GlassQuestTracker's look becomes a Glass UI skin, and GQT retires.
3. **Questie's tracker and RestedXP's guide window and arrow** (#56): optional skins, active only
   while those addons are loaded. Discovery comes first.

Codex `gpt-6-astra` review: consensus in round 2, 2026-10-19.

## Owner decisions (2026-10-19)

- **GQT is dropped as a separate addon:** "it doesn't need to be separate". Its look moves here with
  the Pearl look.
- **GQT's behaviour is parked, not moved.** Glass UI is look only. Auto-tracking (GQT#4) and the
  quest markers (GQT#7) wait for a possible separate behaviour addon.
- **All of Glass UI's skins follow the suite theme:** the tracker, the merchant and the meter.
- **Questie and RestedXP "clearly" are two to support, as optional.** RestedXP includes its arrow.
- The damage meter's look (glass panel, light clear backing) was judged better than GQT's charcoal
  reflective shell and GlassChat's. The tracker takes the meter's recipe, not GQT's shell.

## Part 1: the suite theme for Glass UI's skins (#54)

**Status (2026-10-19):** built (branch `suite-skins`). In game: `/fp steps skin pearl`.

**Today:**
- `Glass.lua` builds `New({ preset = "clean" })` while the file loads, before the saved variables
  are in.
- `Kit.lua` and `Theme.lua` keep `local Glass = GUI.Glass` from that moment.

**The change:**
- **When the instance is built.** At `ADDON_LOADED`, where `GUI.Suite.MarkReady()` already runs (the
  saved variables are in). It is built once, with `Suite.THEMES[Suite.ThemeName()].preset`. No
  panel exists before `PLAYER_LOGIN` (the engine starts there), so nothing needs the instance
  earlier.
- **Kit and Theme** read `GUI.Glass` when they use it, not at file load: `Skin\Kit.lua:27` and
  `Theme.lua:27` today. Theme's painting path (`Theme.lua:63`) reads it too, so a later refresh uses
  the built instance. `Options.lua`'s `pageGlass()` already reads it on call.
- **An older LibGlass.** The embedded copy is pinned at r11 (`.pkgmeta`), and r11 has Pearl. LibStub
  keeps the highest minor loaded, so a sibling's older copy can't displace ours. The check only
  protects against an older or mispackaged development embed.
  - We borrow GlassChat's version check (`GlassChat\Glass.lua:18`, Pearl at minor >= 11), but fall
    back to an explicit `{ preset = "clean" }`, not GlassChat's `nil` (the original material).
  - `/glassui suite` says when that happens.
- **What changes and what doesn't.** Pearl changes the light and the outline only: wash, gloss,
  frost and rim (LibGlass GLASS-MATERIAL.md, "Pearl"). The body stays Glass UI's `Theme` (clear,
  smoked or class, and the backing), so the clear 0.35 the owner liked stays.
- **The wash follows the material** (Codex on PR #57). Today `Theme.lua:70` paints each body theme's
  own absolute wash (`Theme.PRESETS`: clear and class 0.18, smoked 0.14) on every panel, at
  `Theme.Register` and on every live body change. That would overwrite Pearl's 0.10.
  - So a body theme's wash becomes a **factor of the material's own**: clear and class 1, smoked
    0.14 / 0.18.
  - Theme paints `Glass.STYLE.wash × factor`, read from the built instance (Pearl 0.10, or the clean
    fallback 0.18).
  - On clean that gives exactly today's 0.18 and 0.14, so the clean fallback looks the same as now.
  - The tint and the backing stay the body theme's, unchanged.
  - **Tests:** the wash painted on a registered surface is 0.10 under Pearl and 0.18 under the clean
    fallback, both at first paint and after a live body change (clear to smoked to clear). Checking
    the instance's preset alone would miss this.
- **Applying a change.** The suite theme's preset is read once, when the instance is built, so a
  different preset applies at a /reload, as for the followers. Today there is only one preset
  (Pearl), so there's nothing to select yet. The body theme (clear, smoked, class) still repaints
  live (`Theme.lua:95`).
- **Tests:**
  - the instance's preset follows the saved theme;
  - nothing makes a panel before the instance exists (a guard records it, without an error);
  - an older library falls back to clean.
- **In game:** a screenshot each of the merchant and the meter on Pearl. The owner re-judges the
  meter.

## Part 2: the quest tracker (#55), `Skin\QuestTracker.lua`, key `tracker`

**Status (2026-10-19):** built (branch `quest-tracker`). In game: `/fp steps skin tracker`, with Glass
Quest Tracker disabled (while it's loaded, it owns the tracker).

What comes over from GQT is measured: taint passes A and B clean on 70374, the look's checks on 70450
(GQT docs/FOREVER-PROBE.md). The facts it relies on (GQT CLAUDE.md, "Tracker facts"):
- Forever runs the Mainline `Blizzard_ObjectiveTracker`.
- Hooks go on each **module instance's** `EndLayout`. Mixin-table hooks miss everything, and
  `ObjectiveTrackerFrame.Update` hooks miss dirty updates.
- The module headers' `Background`, `Shine` and `Glow` animate with `setToFinalAlpha`, so a fade can't
  hold them: they are blanked.
- The NineSlice's bottom follows the last module only while one is shown. Collapsed, it keeps its
  full size.

**The skin.**
- `frames()` returns `ObjectiveTrackerFrame`, always loaded and not protected (GQT P1).
- `owners = { "GlassQuestTracker" }`: while GQT is still **loaded**, Glass UI steps aside, the
  engine's existing handover. A disabled install claims nothing.
- `install`:
  - our panel, `kit:Panel(tracker)`, re-anchored by the skin (below);
  - hooks on each module instance's `EndLayout` (the module globals, then `tracker.modules`, read only)
    and on each module header's `SetCollapsed`;
  - the container header's `SetCollapsed`;
  - `EditModeManagerFrame`'s `OnHide`.
  - Every hook checks `Engine.Active("tracker")` first.
- **The look,** as GQT's `Blizzard.lua`:
  - faded: the NineSlice, the container header's bar, the item and find-group buttons' frame art
    (pooled `usedRightEdgeFrames`), the progress bars' borders;
  - blanked: the module headers' `Background`, `Shine` and `Glow`;
  - tinted: the minimize and filter buttons.
  - Text keeps Blizzard's colours and fonts; difficulty colours carry information.
  - The tint colour is GQT's cool `{ 0.75, 0.9, 1 }` until the suite accent (#52) exists, then the
    accent.
- **`style` is a full pass over the current state,** as GQT's `Skin.Apply` was:
  - the container;
  - every module, with its pooled extras as they are now (made while the skin was off, too);
  - then the panel placed.

  The engine reruns `style`, not `install`, when the skin comes back on (`Engine.lua:209`). So a
  collapse while the skin was off is still placed right: on while populated, off, collapse, on.
- **Placement by state, never by reading a position** (GQT's `Panel.Place`). After every layout,
  collapse and Edit Mode exit, our panel is cleared and re-anchored:
  - populated: from the NineSlice's top-left (+16) to its bottom-right (-7);
  - collapsed or empty: to the Header's bottom-right (-2, -4).
- **The surface.** The meter's recipe: `kit:Panel`, the suite preset (part 1), Glass UI's Theme and
  backing. GQT's reflective shell (`Glass.Reflect`, the custom surface alphas) is not carried over.
  - Open: a quest list is mostly text, and clear's backing is 0.35, where GQT's default was 0.55. The
    acceptance screenshots over bright ground decide whether the tracker needs a denser backing.
    That would be a per-skin backing in Theme, if needed.
- **Live, thanks to a kit change.** GQT's blank and tint are restorable, and Glass UI's contract
  allows both: "`SetTexture(nil)` and restoring the value we captured", and `SetDesaturated` /
  `SetVertexColor`. So the kit's `Blank` and `Tint` capture what they change and `Restore` gives
  it back, as GQT's `Unblank` and `Untint` do:
  - blank: the atlas, else the file ID read back from the texture;
  - tint: the desaturation and the vertex colour.

  The "live = false only" rule for Blank and Tint goes. A tint survives Blizzard's `SetAtlas` on the
  minimize buttons (GQT pass B, 70374). `Untint` gives back only the desaturation and the vertex
  colour, so the current expand/collapse atlas stays.
  - **Why first capture is safe here:** the blanked header regions get their atlas once, in XML
    (`Blizzard_ObjectiveTrackerModule.xml:22`), and `AddAnim` animates only their alpha and
    translation. The collapse swaps hit the tinted minimize textures, never a blanked region.
  - **This holds for these audited regions only.** A future Blank or Tint target needs the same
    check.
  - **`test_contract` changes with it.** Today it accepts only `nil` as a texture argument
    (`test_contract.lua:56`). It will accept a non-nil value only when it came from the matching
    getter (`GetAtlas`, `GetTexture`) on **that same texture**:
    - the stubs record getter results as provenance;
    - tests cover an atlas restore and a file-ID restore;
    - a negative case uses another texture's value.

    Arbitrary strings or numbers stay refused.
- **Not moved yet:**
  - the POI buttons' glass discs (GQT#11);
  - the mouse-out fade (GQT#5);
  - both look-only, so later Glass UI issues.
- **Tests:**
  - ported from GQT's harness: a stubbed tracker (modules, headers, NineSlice, pooled extras);
  - the placement by state, including on, off, collapse while off, on;
  - every hook gated;
  - live off and on, giving back fades, blanks and tints;
  - the handover to GQT;
  - the tracker in `test_contract`'s session;
  - the kit's restorable Blank and Tint in `test_engine`;
  - mutation-checked.
- **In game,** `/fp steps skin tracker`, from GQT's `look` and `collapse` procedures:
  - each theme;
  - collapsing the tracker and a section (checked against a snapshot, so Next alone fails);
  - Edit Mode move, Height and Text Size;
  - over bright ground;
  - off and on live, after a /reload, in combat;
  - `taintLog 1`, and a full quest routine for the taint pass (accept, progress, turn in, a dungeon).
- **GQT retires** after the acceptance. That's the owner's call in GQT's own repo, and nothing in
  Glass UI depends on it:
  - its README points here;
  - its look issues close as moved;
  - #4 and #7 are marked parked;
  - the repo is archived.

  No settings migrate (the owner is the only user).

## Part 3: Questie's tracker and RestedXP's guide window and arrow (#56)

**Optional by construction.**
- Each skin has `addon = "Questie"` or `"RXPGuides"`, so the engine attaches only once that addon has
  loaded, and never otherwise. Neither is ever a dependency.
- Each has its own switch, and the master switch covers it.
- With neither installed, nothing runs. The engine's status today says "on (waits for ...)" for any
  unloaded addon (`Engine.lua:256`). It gains "not installed" for an absent one (`DoesAddOnExist`,
  as Suite's `presence`).

**The same contract as for Blizzard's windows.** On their frames:
- only the contract's C widget methods: getters, `SetAlpha`, `SetDesaturated` and `SetVertexColor`
  on their textures, `HookScript`, `hooksecurefunc` on an instance;
- never their Lua (Questie's `TrackerBaseFrame.*`, RestedXP's `addon.*` or theme functions), never a
  field write, never their saved variables.
- Found by their global frame names, never by texture path.

Their frames aren't secure, so taint is less of a risk than with Blizzard's. Their own code re-applying
its look is the real risk, which is what discovery measures.

**What's known from their source** (references, not measured):
- **Questie 12.1.0** has a Forever build (`Questie_Camelot.toc`, Interface 16001).
  - Its tracker is `Questie_BaseFrame`, a `BackdropTemplate` frame, with `Questie_Sizer`.
  - It sets its backdrop colours from its options: background on/off, border, a mouse-over fader
    (`TrackerBaseFrame.lua:172-192`).
  - Open: whether Questie's tracker replaces Blizzard's on Forever's Mainline tracker, or sits beside
    it (the owner's screenshots show Blizzard's "All Objectives" with Questie installed).
- **RestedXP v4.11.26** lists Interface 16001.
  - Its guide window is `RXPFrame` (`GuideWindow.lua:24`), with the step frames and the bottom menu.
    It is styled by RestedXP's own themes (`Themes.lua`, `ApplyFrameBackdrop`).
  - Its `RegisterTheme` is private: only `RegisterGuide` is published on `_G.RXPGuides`. So a "Glass"
    theme can't be registered from outside, and we restyle in place.
  - **The arrow** is `RXPG_ARROW` (`map.lua:41`): one texture, re-set by `UpdateVisuals`, rotated as
    the player turns, and a distance text below it.
  - The owner: "the arrow could very well be skinned like our NodeRadar compass" (`NodeRadar\Compass.lua`):
    - a dark lens and a pearl rim;
    - an arrow orbiting outside the rim, with a highlight arc beneath it;
    - the distance in a capsule below;
    - NodeRadar's own art (`Tools/make_media.py`).
  - Two ways, decided after discovery:
    - **In place:** a glass disc of ours behind RestedXP's arrow, its texture desaturated and tinted
      to the suite colour (#52). The rotation, the texture and the text stay RestedXP's.
    - **The compass:** RestedXP's arrow texture faded, and our compass drawn on our own frame at the
      angle RestedXP gives it. The angle is read, never written: its `orientation` field, or a hook
      on the texture's rotation call. RestedXP still places it, moves it and shows the distance.
      - This draws our own indicator in place of RestedXP's art, which the skin contract doesn't
        cover today ("never replace"). It needs the owner's explicit, audited exception in
        docs/PLAN.md, for this third-party arrow only.
      - The art is NodeRadar's. It's shared through LibGlass (a LibGlass issue: the compass layers as
        library media) rather than copied between repos.
  - Other RestedXP frames (`RXPItemFrame`, `RXPTargetFrame`, `RXPLevelSplits`, ...) come after the
    window and the arrow, if the owner wants them.

**Discovery first** (`/fp steps skin questing`, built 2026-10-19; results in docs/FOREVER-PROBE.md, QS):
- the frame trees;
- which textures fade and stay faded through their own refreshes (a guide step change, a quest
  update, Questie's fader, a RestedXP theme change);
- what re-creates regions;
- whether Questie's tracker and Blizzard's coexist;
- **when each target frame first exists.** The engine resolves a skin's frames once, when its addon
  is loaded, and marks the skin failed if none exists (`Engine.lua:136`). An addon that builds its
  frame later (at its own login, or when its feature is first switched on) needs a later attach
  point, chosen from the measurement.

**The arrow's place** (the owner: keep it off GlassPanel and off GlassPanel's maximized XP bar).
- RestedXP anchors the arrow to the top of the screen by default (`SettingsPanel.lua:3931`), which is
  exactly where GlassPanel's bar and its XP bar sit.
- Moving RestedXP's frame from outside is a position change, which the skin contract forbids. It's the
  same question as Blizzard's panels clearing GAB's bars (#47).
- The clean shape is the suite's announce-and-follow pattern: GlassPanel announces the top edge it
  occupies (its bar, plus the XP bar when maximized), and the arrow keeps clear of it. That needs:
  - a GlassPanel change, in its own repo and session: GlassPanel#97. It provides
    `GlassPanel.EdgeState()` returning `{ top }` (UIParent units down from the screen's top: its
    bar, plus the zoomed XP bar while that sits in the top band, MARGIN 40), and
    `"GlassPanel.EdgeChanged"` with `(top)`, fired out of combat. Its own RestedXP plugin goes
    (GlassPanel#98, the owner: "not satisfying"), so `RXPG_ARROW` is the only arrow;
  - the owner's audited exception for moving this one third-party frame, decided with #47;
  - RestedXP's own saved position respected: only its default position is offset, never a place the
    player dragged it to.

Then an addendum to this plan, with Codex review, before code.

## Not in these parts

- the suite accent colour (#52), which the tracker's tint and the arrow's colour adopt when it lands;
- the backing density for the whole suite (GQT and GlassChat each chose their own; to centralize,
  like #52);
- GQT's behaviour (#4, #7);
- the POI discs and the mouse-out fade (later issues).
