# The world map and quest log in glass (#99): plan

The owner's mockup (2026-10-20, "Pearl Warcraft Map & Quest Log") on the window template
(memory: the merchant #86 recipe; bags #88, game menu #90, guild #92, character #94):
- the window glass on the floor (0.93), a smoky title band down to the breadcrumb bar's bottom,
  and the portrait's disc (the book);
- the close, maximise and minimise buttons as glass discs with an accent glyph;
- the breadcrumb bar as a recessed pane;
- the map framed by our glass;
- the quest log as a recessed pane on the right, its zone headers on glass bars (the quest
  tracker's look, as for the character window's lists, #94), the search box and the quest counter
  on glass pills.

Everything else stays Blizzard's: the map, its pins and overlay buttons; the quest rows (the
difficulty colours, the tracking checkbox: a click path); the quest details; the scroll bar; text
colours.

Measured facts this rests on are from **70374** (FOREVER-PROBE W1.1-W1.3). The map's FrameXML
changed by 70425, so the probe re-measures them on 70450 (below). The anatomy below is
`wow-ui-source` origin/forever 172a387 (70450).

## What loads on Forever

- **Blizzard_WorldMap:** the Mainline toc. For camelot, Camelot's `Blizzard_WorldMapTemplates.xml`
  and `.lua` and `Blizzard_WorldMapConstants.lua` replace Mainline's. The shared
  `Blizzard_WorldMap.lua` loads, then `Camelot/Blizzard_WorldMap.lua` (`AdjustOverlayFrames`),
  then `Blizzard_WorldMap.xml`.
- **The quest log:** Mainline `QuestMapFrame.xml`/`.lua` with Camelot's
  `QuestMapFrameOverrides.lua` and `QuestMapFrameUtils.lua`. **Camelot hides the three side tabs**
  (`QuestMapFrameOverrides.lua:4-6`), so the Events and Map Legend panes are unreachable.
- **The quest list is an old ScrollFrame with frame pools** (`QuestScrollFrame`,
  `QuestMapFrame.xml:493`; pools at `QuestMapFrame.lua:1228-1237`), not a ScrollBox. It is
  refilled by the **global** `QuestLogQuests_Update` (2103-2164).

## The anatomy, and what the skin does to each piece

### The shell (`WorldMapFrame`, MEDIUM, `frameBuffer="true"`; `BorderFrame` HIGH)

| Piece | Art | The skin |
|---|---|---|
| `BorderFrame.NineSlice` | metal pieces, OVERLAY. Maximise and minimise call `SetBorder`, then `ApplyLayout`, which **`SetAtlas`es every piece** (`NineSlice.lua:92`, `Blizzard_WorldMap.lua:61/76`) | the NineSlice **frame** faded (alpha holds through `SetAtlas`) |
| `BorderFrame.Bg` | `UI-Background-Rock`, **reparented to `WorldMapFrame`** (`Blizzard_WorldMap.lua:27`) | faded through its parentKey (`BorderFrame.Bg` stays set) |
| `BorderFrame.InsetBorderTop` | a 3 px tile under the bar | faded |
| `BorderFrame.TopTileStreaks`, `Underlay` | hidden by Blizzard | left alone |
| `PortraitContainer` (level 400): `.portrait` (book icon), `CircleMask` | maximise hides **the portrait texture only** (`SetPortraitShown` → `GetPortrait():SetShown`, `PortraitFrame.lua:35-36, 92-94`; `Blizzard_WorldMap.lua:77`): the container stays shown | `kit:PortraitDisc` round the mask (Codex r1). **Its visibility follows `portrait:IsShown()`**, set in the style pass after `ShowPanels`, which shows every adopted panel, and in the deferred display refresh |
| `TitleContainer.TitleText` | GameFontNormal; text set on each display change, never a colour | Blizzard's |
| `Tutorial` (the "i" by the portrait) | `MainHelpPlateButton` | Blizzard's |
| `CloseButton` | `RedButton-Exit*`, 28x28 on Camelot | **`kit:CloseButton`**: disc, our X, the four states faded |
| `MaximizeMinimizeFrame.MaximizeButton` / `.MinimizeButton` | `RedButton-Expand*` / `RedButton-Condense*`: the arrow is **baked into** the atlas (W1.3: fading it hid the button) | **new, `kit:GlyphButton`**: the close button's recipe with our own glyph (below), one per button. Each is parented to its button, so the mixin's swap shows one at a time |
| `OverscrollBG` (behind the canvas where the map doesn't fill: a gamepad tile and four vignettes) | static | faded, so our glass shows there |
| `BlackoutFrame` (LOW, full screen, shown maximised) | Leatrix's `HideBlackoutFrame` fades it on the owner's client | Blizzard's |

**The window glass** is `kit:Panel(WorldMapFrame)`, a child at the window's level − 1 (Kit.lua:287):
under the MEDIUM canvas, which covers it where the map is. It shows round the map, under the bar and under
the quest log, whose art is faded. W1.3 measured exactly this on 70374, windowed and maximised.
The header band (`kit:Header`) runs from the window's top to the bar's BOTTOM. Maximise and
minimise re-anchor the bar, and anchors follow.

### The breadcrumb bar (`WorldMapFrame.NavBar`, `WorldMapNavBarTemplate` + `NavBarTemplate`)

- **The bar's own art:**
  - the unnamed BACKGROUND tile;
  - `overlay` (a child frame) and its tile;
  - `InsetBorderBottomLeft/BottomRight/Bottom/Left/Right` (BORDER -5).

  All faded, and a recessed pane (`kit:Section`) on a host of ours parented to the bar, anchored
  to it.
- **The crumbs:**
  - `home`/`homeButton` and the pooled crumbs in `navBar.navList` (`NavButtonTemplate`).
  - Their normal and pushed textures (`CS_HelpTextures_Tile`) are faded, so a crumb reads as text
    on the pane.
  - **The overflow button stays Blizzard's** (Codex r1): it has no text and no chevron of its own,
    so its state textures are its glyph (`NavigationBar.xml:284-300`).
  - Kept: the chevrons (`arrowUp`/`arrowDown`), the `selected` texture, the highlight, the text.
  - The dropdown arrow (`MenuArrowButton`): Blizzard's. Its own OnEnter/OnLeave writes its alpha
    (`NavigationBar.xml:198-205`).
- **New crumbs** are created by the global `NavBar_AddButton`, which is off limits. Instead the
  skin post-hooks the **instance** `WorldMapFrame.NavBar:Refresh` (`WorldMapNavBarMixin:Refresh`,
  `Blizzard_WorldMapTemplates.lua:527-559`). That method rebuilds the whole bar on every map
  change. The hook only **schedules** the styling, through `Engine.Defer`, a frame later.
  - The NavBar is itself an overlay frame (`AddOverlayFrame`, `Blizzard_WorldMap.lua:343,
    455-466`), so its `Refresh` runs inside the overlays' `secureexecuterange` (438-451).
  - The deferred pass walks `navList` and the home button by their keys (`NavigationBar.lua:50-54`),
    never `GetChildren`.
- **Levels:** the bar's pane host sits at the bar's own level, under its buttons (the last crumb
  is at the bar + 1, `NavigationBar.lua:227`). Its LibGlass rim is lowered to that level.
- **The filter button** right of the bar (`WorldMapTrackingOptionsButton`) and the other overlay
  frames (pin, floor dropdown, bounty board, the secure action button, coordinates) stay
  Blizzard's. So do Questie's map button and everything on the canvas.

### The quest log (`QuestMapFrame`, HIGH, reparented by `AttachQuestLog`)

| Piece | Art | The skin |
|---|---|---|
| `QuestScrollFrame.Background` | `QuestLog-main-background`, **`SetAtlas` on every update** (1428) | faded (alpha holds) |
| `QuestScrollFrame.BorderFrame` | `Border` (`questlog-frame`), `TopDetail` (filigree), `Shadow` (**`SetAlpha` driven by scrolling**, 1391-1397) | `Border`, `TopDetail` faded; `Shadow` **blanked** (`kit:Blank`, given back by Restore) |
| `QuestScrollFrame.Contents.Separator.Divider` | `QuestLog-frame-devider` | faded |
| `Contents.StoryHeader` | story zones only | Blizzard's (v1) |
| The pane | none | a recessed pane on a host of ours parented to `QuestMapFrame.QuestsFrame` (it hides with it), **at `QuestsFrame`'s level**, under its ScrollFrame and DetailsFrame children, anchored to `QuestScrollFrame` |
| `QuestScrollFrame.SearchBox` (`SearchBoxTemplate`) | `Left/Right/Middle`; `searchIcon` (re-tinted on focus) | the three faded; a small glass pill of ours under it (level − 1, its rim lowered to its own level, mouse off); the icon Blizzard's |
| `QuestLogCount` (the "Quests: x/y" box, `InputBoxVisualTemplate`) and `QuestLogQuestCount` (its text, a `\|c` colour escape) | `Left/Right/Middle` | the three faded; a pill under it |
| `QuestScrollFrame.SettingsDropdown` (the gear) | its icon | Blizzard's |
| `QuestScrollFrame.ScrollBar` | `MinimalScrollBar` | Blizzard's (v1) |
| The zone headers (`headerFramePool`, `QuestLogHeaderTemplate` = `ListHeaderVisualTemplate`) | `NormalTexture` and `HighlightTexture` (`common-button-list-collapseExpand`), which have no parentKey and are read with `GetNormalTexture`/`GetHighlightTexture` (`ListTemplates.xml:39-40`); `CollapseButton.Icon` (`SetAtlas` plus/minus); `ButtonText` coloured by `CheckHighlightTitle` (grey, white on hover) | **the character lists' look:** a glass bar; the NormalTexture faded; the HighlightTexture tinted white; the +/- tinted in the accent. **The text stays Blizzard's** (the mockup's grey "Durotar": no new audited title) |
| Quest rows (`titleFramePool`), objectives, the tracking `Checkbox` | difficulty colours, the click path | Blizzard's |
| `DetailsFrame` (a quest clicked) | parchment, dark quest text | **Blizzard's in v1**: the parchment carries the text's contrast. A follow-up if the owner wants it |

**Finding the headers.** The skin post-hooks the **instance** method
`QuestScrollFrame:UpdateBackground` (`QuestLogScrollFrameMixin`, `QuestMapFrame.lua:1411`), which
`QuestLogQuests_Update` calls once after every row is acquired (2159).
- The hook is gated, and schedules the pass a frame later (`Engine.Defer`), like the bar.
  `QuestLogQuests_Update` also runs from the objective tracker's clicks in combat.
- The pass walks `QuestScrollFrame.Contents:GetChildren()` (the pools parent every row there,
  1226-1237), filtered by structure:
  - a header has a `ButtonText` and a `CollapseButton` with an `Icon`;
  - and no `SelectedHighlight`, which excludes the covenant-callings header that inherits the same
    template (`QuestMapFrame.xml:88`).

  Campaign headers use `Text`, not `ButtonText`. Titles, objectives, POI buttons, `StoryHeader`
  and `Separator` don't match. The walk never touches the pools' methods.
- A header is styled once and re-faded each pass, so a pooled row that comes back is covered.
- Our glass bar is parented to the row, not to `Contents`, so it never joins the layout.
- A new row may show Blizzard's bar for one frame.

## Owners, yields, neighbours

- **Owners:** `{ "GlassMaps" }` (the handover pilot, PLAN).
- **Yields:** `{ Leatrix_Maps = function() return not (LeaMapsDB and LeaMapsDB.SimpleMapFrame == "Off") end }`.
  The value is read at login, as PLAN says (`Leatrix_Maps.lua:2887, 2956, 2962`). On the owner's
  client it's Off, so the skin runs.
- **Leatrix Maps with the simple frame Off** still adds:
  - the coordinates strip (an unnamed `cFrame` on `ScrollContainer`), with Blizzard's coordinate
    frames reparented and given an outline font;
  - a `hoverDriver` child;
  - the filter's `ResetButton` reparented away;
  - POI hooks.

  The skin never sweeps `WorldMapFrame`'s or `ScrollContainer`'s children, so none of this is
  touched, and a missing ResetButton is normal.
- **Questie** adds:
  - a map button (`Krowi_WorldMapButtons1`, a child of `WorldMapFrame`, HIGH);
  - pins on the canvas;
  - coordinates written into the first text region **directly on** `BorderFrame`
    (`QuestieCoordinates.lua:26, 96`). It doesn't search `TitleContainer`, so the stock title
    isn't one; the probe still reads the title.

  Untouched.

## Hooks and the contract

Every hook checks `Engine.Active("map")`.

**Codex r1:** three of these calls run inside a secure call chain:
- the panel manager opens the window through secure code (`UIParentPanelManager.lua:896-900`);
- `Maximize`/`Minimize` go through `SetUIPanelAttribute`/`UpdateUIPanelPositions`;
- the NavBar's `Refresh` runs in the overlays' `secureexecuterange`.

So no styling runs in those stacks. The hooks only schedule work through `Engine.Defer`, a frame
later, which also checks the skin's generation. `Engine.Run` only contains errors.
- The engine's `HookScript("OnShow")` on `WorldMapFrame`, with a new engine flag, **`defer =
  true`**. Install and style run a frame after the show, **in combat too**. It differs from
  `risk = "protected"`, which also holds the first pass until combat ends.
  - Styling happens at the first show, so Ellesmere's ScrollBox doctrine holds and Leatrix's
    login handler has run.
  - The window shows Blizzard's look for one frame at its first opening.
- `hooksecurefunc(WorldMapFrame, "Maximize")` and `(…, "Minimize")`, instance methods. Each
  schedules the display refresh: the header placed, the disc's visibility, the close and glyph
  synced.
- `hooksecurefunc(WorldMapFrame.NavBar, "Refresh")` schedules the crumbs.
- `hooksecurefunc(QuestScrollFrame, "UpdateBackground")` schedules the headers.
- `kit:CloseButton` / `kit:GlyphButton`: `HookScript` OnEnter/OnLeave/OnMouseDown/OnMouseUp on the
  buttons, as for every window. The buttons call `Maximize`/`Minimize` through Blizzard's own
  OnClick, which stays untouched.

Never:
- `SetScript`, or a script hook on `QuestMapFrame` itself. ElvUI replaces its OnHide with its own
  because, once ElvUI's writes have tainted the frame, Blizzard's handler taints the tracker's
  button (`WorldMap.lua:18, 231`). We write nothing there and hook nothing there;
- a global hook (`QuestLogQuests_Update`, `NavBar_AddButton`, `QuestInfo_Display`);
- a field written on a row (ElvUI's `IsSkinned`);
- anything on the canvas, the quest rows or the Details buttons (abandon, share, track);
- any other overlay frame (one is a secure action button refreshed through `secureexecuterange`,
  `Blizzard_WorldMap.lua:448-453`). The NavBar is the one overlay frame we style: its art, its
  crumbs' state textures, a pane of ours, all a frame after its refresh;
- `Maximize`/`Minimize`/`ShowUIPanel` or any `QuestMapFrame_*` from our code.

`risk = "plain"`, `defer = true`. The window opens in combat and from the objective tracker (in
combat too). The probe opens it both ways, from a fresh reload each.

## `kit:GlyphButton` (new)

The close button's recipe, generalised:
- a glass disc under the button (`kit:Disc`, level − 1);
- a frame of ours one level up holding the glyph, colour textures in the accent at
  `Kit.CLOSE_REST`, full on hover, 1 px down when pressed;
- the button's state textures faded.

Glyphs are drawn with rotated colour textures, like the X:
- "expand" (↗): a 45° shaft and two head strokes at the top-right corner;
- "condense" (↙): the same, mirrored.

`kit:CloseButton` keeps its interface: `h.close`, `h.closeX`, `h.closeDisc`, `h.closeFrame`,
`h.closeAlpha`, `h.hover`, `h.pushed`. The merchant's and other tests read them
(`test_merchant.lua:588`), and so does the probe (`SkinProbe.lua:1079`) (Codex r1).
- The shared internals move into a local `glyph(kit, button, strokes, st)`, used by both.
- `kit:GlyphButton(button, h, kind)` keeps its own state per button in `h.glyphs[button]`
  (`{ disc, frame, strokes, alpha, hover, pushed }`).
- `Kit.PaintClose` and `Kit.CloseSync` also paint and sync `h.glyphs`, and the Theme refresh
  repaints them.
- **Hover and press are per button.** A button hidden while pressed (the mixin's swap on click)
  is synced from its getters when shown again: the deferred display refresh calls `CloseSync`.

## The probe (`/fp steps skin mapglass`; `map` stays the 70374 measurement)

1. **The first opening in combat, from a fresh `/reload`, nothing measured before it:** M in
   combat. The skin installs a frame later. Count `ADDON_ACTION_BLOCKED` and
   `ADDON_ACTION_FORBIDDEN`.
2. **The other first opening, from another fresh `/reload`:** a tracked quest clicked in the
   objective tracker in combat (`QuestMapFrame_OpenToQuestDetails`). The same counts.
   - Then **L after a map-only opening**: the side panel hidden, then shown.
   - Then the 70450 facts the skin rests on: whether `QuestScrollFrame.UpdateBackground` and
     `NavBar.Refresh` are instance methods (else `missing:map:*`); strata and levels;
     `IsProtected` on every frame of ours.
3. **Logging:** the functional pass (maximise and minimise, map changes, the quest log: steps
   5-7) runs with the taint log **off**, then once again with it **on** for comparison.
   - With the log on, `hooksecurefunc` on an instance can make Blizzard call nil methods on 70450
     (PORTING-TBC-TO-FOREVER.md:1289).
   - The run counts both events, reads the log, and ends with the log off.
4. **The look** (screenshots) against the mockup, windowed:
   - the glass shows round the map and under the log (frameBuffer on 70450);
   - the header band;
   - the disc;
   - the three buttons.
5. **Maximise and minimise,** both ways, **in combat too**:
   - the NineSlice still faded;
   - the disc hidden with the portrait;
   - the glyph swap;
   - glass behind the map.
6. **Map changes:** world → continent → zone → back, and the crumbs' dropdown. Every crumb's
   normal texture is faded. **The overflow button shows at rest** and opens its menu.
7. **The quest log:**
   - collapse and expand a header;
   - search, including a search with no result, then cleared (new headers acquired);
   - scroll (the shadow stays blank);
   - track and untrack a quest (the checkbox works);
   - open a quest's details and come back;
   - every visible header on glass, its NormalTexture faded and its icon desaturated.
8. **Questie's button and Leatrix's coordinates** still show; the title text is read for
   coordinates.
9. **Off, then on**, while maximised, and again with a quest's details open. **A `/reload`.**
   **With Leatrix's simple frame On** (a setting change and a reload): the skin yields and says
   so.

## Tests

`test_map.lua`, with stubs (`WoW.makeWorldMap`) built from the anatomy above:
- **The shell:** the shell's pieces; `BorderFrame.Bg` reparented, still faded.
- **Maximise and minimise:**
  - `SetAtlas` on the NineSlice keeps the fade;
  - the stub toggles **the portrait texture only**, and the disc follows it, including maximise →
    off → on → minimise;
  - one glyph shown;
  - per-button hover and press, a button hidden while pressed then shown.
- **The deferral:** nothing styled inside the hooked call; styled a frame later; a pass dropped
  when the skin is turned off or handed over before it runs.
- **The crumbs:** the crumbs across `Refresh`, and new pooled crumbs. The overflow button is
  modelled texture-only and stays stock.
- **The headers:** across `UpdateBackground`, pooled reuse. Untouched: POI buttons, quest rows,
  and a covenant-callings header (a negative fixture).
- **The art:** the shadow blanked against Blizzard's `SetAlpha`; the search and count pills.
- **The neighbours:**
  - the Leatrix yield (On, Off, the DB missing);
  - Questie's button and Leatrix's frames untouched;
  - nothing on the canvas or the other overlay frames;
  - no field written;
  - no global hook.
- **The skin's switches:** off and on; the accent.
- **The kit:** `GlyphButton`'s tests; the close button's unchanged.
- **The engine:** `defer = true` (deferred in and out of combat, unlike `protected`).
- **The other suites:** `test_contract` and `test_methods` exercise the map.

Every new test is mutation-tested.

## Codex round 1 (gpt-6-astra, high): no blocker, five SHOULDs, all taken

1. **Secure call chains:** styling is deferred a frame (`defer = true` on show, and every hook
   schedules through `Engine.Defer`). The NavBar is an overlay frame, so its `Refresh` runs in
   `secureexecuterange`.
2. **The disc** follows the portrait texture's `IsShown()`: maximise hides the texture, not the
   container.
3. **The overflow button** stays stock: its textures are its glyph.
4. **Levels:** stated for every host and rim.
5. **The probe:**
   - a fresh first opening each way (M in combat; the tracker in combat);
   - a pass with the log off, then on, counting BLOCKED and FORBIDDEN;
   - maximise and minimise in combat, and L after a map-only opening;
   - the overflow at rest, an empty search;
   - off and on while maximised or in details;
   - the deferral's cancellation, offline.

Nits taken: the covenant-callings header is excluded and tested; the headers' textures are read
through getters; the close button keeps its state interface; ElvUI's comment is now quoted the
right way round; `Engine.Run` is no longer described as checking the generation.

Noted: `ScrollContainer.Child.TiledBackground` carries a map-specific atlas over twice the canvas
(`MapCanvas_ScrollContainerMixin.lua:238, 472`), so the faded `OverscrollBG` may rarely show. The
probe judges the result, and the canvas stays untouched.

## Codex round 2: consensus

Every round-1 finding is resolved, with no new BLOCKER or SHOULD.
- `defer = true` is implemented as `s.def.defer or s.def.risk == "protected"` in `onShow`. The
  combat gate stays in `apply`, for `protected` only.
- A hide, or a show/hide/show, before the deferred pass is harmless: the passes are repeatable,
  and `installed[frame]` guards the install.
- The `SelectedHighlight` exclusion checks that the field is present.
- The one-frame flash is accepted.
- Blizzard's maximise mixin calls the map before it swaps the buttons, so the deferred sync sees
  the swap done.

Nit taken: the probe's steps are renumbered (the logging pass names the steps it repeats).

## Built (2026-10-21)

- **Engine:** `defer = true` (`onShow` defers on `defer` or `protected`; the combat wait stays
  `protected`'s).
- **Kit:**
  - `GlyphButton` and `Kit.GLYPHS` (expand, condense);
  - `Kit.CloseSync` and `Kit.PaintClose` also cover `h.glyphs`;
  - the close button's interface is unchanged, and its tests passed untouched.
- **`Skin/Map.lua`:**
  - every hook goes through `schedule`, an instance `hooksecurefunc` that only defers;
  - a missing method is recorded as `missing:map:<what>`.
- **Tests:**
  - **`test_map` 144:**
    - the deferral (nothing styled inside the show, a refresh or an update; a queued pass dropped
      by the switch);
    - the shell;
    - the disc through maximise, off, on, minimise;
    - the glyphs' per-button feedback and the hidden-while-pressed sync;
    - the crumbs across a rebuild, the overflow kept;
    - the quest log's art, pane and pills;
    - the headers, with the covenant, campaign, title, objective and POI fixtures untouched;
    - the neighbours untouched;
    - the accent, also while off;
    - off and on;
    - the Leatrix yield: On, no DB, Off.
  - **`test_contract`** opens, maximises, refreshes, updates and scrolls, in combat, with off and on.
  - **Mutation:** 51 mutants of the skin, the glyph buttons and the engine flag. Four survivors
    were fixed:
    - a campaign-header fixture added;
    - a redundant overflow filter removed;
    - two gates tested while off.

    One is equivalent: the hook's `Engine.Active` gate, which `Engine.Defer` checks again at run
    time; it stays per CLAUDE.md.
  - **The probe's map checks:** 12 mutants, all killed.
- **The Leatrix-On case** is covered offline only (`test_map`). In game, it would need a change to
  the owner's Leatrix setting and two reloads.

## Run 1 (2026-10-20)

Every check passed (FOREVER-PROBE MP.1-5), except one "minimised" read in combat that found the
map still maximised. Nothing was blocked, the taint-log pass included. BugSack held only
NodeRadar's `SuperTrackedFrame` noise under the taint log.

**The owner's notes:**
- **The look:** "close enough".
- **The scroll bar's colour:** an open question; the bar is left stock in v1.
- **A header "auto expands after a collapse":** Blizzard's `QuestMapFrame_ResetFilters` on every
  refresh, and pin hovers. The owner confirmed it with addons turned off.

**The tracker case and the in-combat minimise** moved to `/fp steps skin maptracker`. A
mid-run redeploy had stopped `mapglass` at its last reload.
