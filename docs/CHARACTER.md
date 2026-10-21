# The character window in glass (#94)

Forever's own character window from the window template (merchant #86, bags #88, game menu #90,
guild #92) and the owner's mockup (2026-10-20): a dark glass window, the portrait in its disc, the
equipment slots as glass wells round the model, the stats in a recessed right pane with glass
section headers, glass side tabs with the selected one rimmed in gold. Look only, nothing moved.

Codex `gpt-6-astra` review: round 1 (2026-10-20), one BLOCKER (the stats header's identity), four
SHOULDs and four NITs, taken in below (marked "(Codex)").

## What's read (wow-ui-source `forever`, 70450)

Paths are under `Blizzard_UIPanels_Game/` unless named. CF is `Camelot/CharacterFrame`, PD is
`Camelot/PaperDollFrame`.
- **Loading.** Forever loads its own Camelot files (TOC:44-60, 69-72, 213-214): the frame, the paper
  doll, reputation, skills and PvP rank. The currency pane is `Blizzard_TokenUI/Camelot` (the addon
  isn't Forever-only, its Camelot files are), and statistics is `Blizzard_Statistics/Camelot`
  (Forever only). None is LoadOnDemand.
- **The frame.** `CharacterFrame` (CF.xml:403), `PortraitFrameBaseTemplate`
  (Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:566-622): `NineSlice`,
  `PortraitContainer.portrait` with its `CircleMask`, `TitleContainer.TitleText`, `CloseButton`
  (CF.xml:405).
  - **No `Bg`, `Inset` or `InsetRight`:** the backdrops are the pane hosts.
  - It's 631 × 484, or 398 wide with the right pane collapsed (CharacterFrameConstants.lua). The UI
    panel's width attribute is Blizzard's (CF.lua:323-326).
- **The backdrops** (CF.xml:407-459):
  - `LeftPaneHost`, `UI-Character-Info-General-BG`;
  - `RightPaneHost`, `UI-Character-Info-Stat-BG` and its `StoneBg` (shown on the paper doll only,
    `SetShown` in `UpdateRightPaneHeader`, CF.lua:372-374);
  - an unnamed divider child (level 505, `common-framedivider`);
  - `RightPaneToggleButton` (the arrow; the collapsed state is the `characterFrameCollapsed` CVar).
- **The six mode tabs.** `ModeTabs.Tabs[1..6]` (CF.xml:568-605) are `LargeSideTabButtonTemplate`
  (SharedUIPanelTemplates.xml:1008-1065), **Frames, not CheckButtons**:
  - `Background` (`common-sidetab`), `Icon` with its `Mask`, `SelectedTexture`
    (`common-sidetab-selected`), `TabGlow` (animated), `HighlightTexture`;
  - their mixin's `SetChecked` (SharedUIPanelTemplates.lua:391-401) shows or hides `SelectedTexture`
    and sets the icon's atlas. It's called by `SetSelectedModeTabByFrame` and `OnModeTabClicked`
    (CF.lua:217-242). **The selected state is `SelectedTexture:IsShown()`.**
  - `UpdateTabLayout` re-anchors them (CF.lua:197-215).
- **The paper doll** (PD.xml:403):
  - **The model**, `CharacterModelScene`: four `CharacterModelFrameBackground*` corner textures, a
    `UI-Character-Info-RaceBG-Overlay`, and its `ControlFrame` (zoom, rotate and reset buttons).
  - **The level line**, `TopBackgroundStripHost` (a rock tile and `_UI-Frame-InnerTopTile`, PD:556),
    holding `CharacterLevelText`.
  - **The slots**, `PaperDollItemSlotButtonTemplate` (PD:46-89; Left/Right `EquipmentSlots`, Bottom
    `WeaponSlots`): a `BorderFrame` child (`UI-Character-Info-GearSlot`),
    `NormalTexture`, `IconBorder` (quality), `icon` (the item, or the slot's empty silhouette from
    `C_PaperDollInfo.GetInventorySlotInfo`), `Cooldown`, `popoutButton`, `SocketDisplay`.
    - **Their click is the protected path**: `PickupInventoryItem`, `UseInventoryItem`,
      `SocketInventoryItem` (PD.lua:2107-2168).
    - **`CharacterAmmoSlot` is its own anatomy** (PD.xml:868-931): no `BorderFrame`. Its bronze ring
      is an unnamed BACKGROUND texture on the button itself (:875), and an unnamed child holds the
      direction arrow (:903) (Codex).
    - **`NormalTexture`'s alpha is unverified.** Ellesmere hides it, because the client's
      `SetItemButtonNormalTextureVertexColor` (PaperDollFrame.lua:2187-2207, ItemButtonTemplate.lua:146-152)
      also restores its alpha (CharacterSheetForever.lua:863-865). The kit hooks `SetAlpha` only. So
      a fade there is an **acceptance gate** (below), not a fact (Codex).
    - `IconBorder`'s alpha is written by the shared `ItemButtonMixin:SetAlpha`
      (ItemButtonTemplate.lua:233-238): left untouched.
  - **The stats**, `CharacterStatsPaneScrollBox` (CF.xml:131-168, 463): a wrapper with a
    `common-insideframe` border and a `ClassBackground` (`UI-Character-Info-<CLASS>-BG`), holding
    **the real list in `.ScrollBox`** (a `WowScrollBoxList`, Codex), whose pooled rows live under
    its `ScrollTarget` (ScrollBoxListView.lua:25).
    - **The rows:** headers have a `Background` (`UI-Character-Info-Title`) **and a `Title`** (CF.xml:77-94).
      Ordinary stat rows also have a `Background`, the alternating stripe toggled at CF.lua:1261,
      with a `Label` and a `Value` (CF.xml:175-221). So **a header is `Background` plus `Title`**
      (Codex BLOCKER).
    - The list's instance `Update` (ScrollBox.lua:762-798) runs on scroll (:293) and on a refresh
      (:189).
    - The pet tab has its own `CharacterStatsPanePetScrollBox` (CF.xml:479).
  - **The four sidebar tabs**, `PaperDollSidebarTab1-4`, are CheckButtons (`UI-Character-Info-StatTab`,
    a `-Selected` CheckedTexture) at the top of the right pane (PD.xml:372-432).
  - The title and equipment manager panes are ScrollBoxes with `common-insideframe` (PD:436, 474).
- **The other panes** (reputation, skills, PvP, currency, statistics) each fill the frame, with a
  `WowScrollBoxList` on `LeftPaneHost`. Reputation, skills, PvP and currency have a
  `CharacterFrameSidePaneTemplate` right pane (strata HIGH); statistics has none
  (StatisticsFrame.xml:117-171, Codex). The currency list is a child of `TokenFrame`, anchored to
  `CharacterFrameLeftPaneHost` (Blizzard_TokenUI.xml:160-165): anchoring, not parenting.
- **Hazards:**
  - the slots' click path;
  - **the currency pane and its transfer UI stay 100% stock**: its rows and its transfer-log toggle
    (Ellesmere WindowPacks:5331-5375: any skinning taints the warband transfer, the protected
    `RequestCurrencyFromAccountCharacter`) (Codex);
  - the UI panel's width;
  - the gamepad stand-down (the engine's).
- **References.** Ellesmere fades the hosts, the stats chrome, the strip and the model background,
  hooks `PaperDollItemSlotButton_Update`, and re-opens a collapsed pane. ElvUI moves the slots and
  re-styles the list rows from ScrollBox hooks. We do neither: no move, no global hook, no collapse
  change.
- **Siblings:** none hooks or adds to the character window (Glass Panel's gear score and ammo
  plugins read data only).

## The plan

### 1. The side-tab treatment moves into the kit

It's the third window with glass side tabs: the guild's, its tenants', and now the character
window's two sets. So the guild's `installTab`/`styleTab`/`syncTabs` become the kit's.
- **`K:SideTab(tab, opts)`:**
  - our small glass round the tab, parented to it, its rim at its own level;
  - a white light;
  - instance post-hooks that re-read the selection of every side tab of this skin, gated;
  - `opts.selected(tab) --> bool` (`GetChecked` for a CheckButton, `SelectedTexture:IsShown()` for a
    large side tab), `opts.hooks` (the methods to post-hook: `SetChecked`, and `OnClick` by
    `HookScript` for a CheckButton's native toggle), `opts.art` (the regions to fade), and
    `opts.insets`.
- **`Kit.SyncSideTabs(kit)`:** the selected ones lit with their rim in the accent, the others with
  the built rim; repainted on `Theme.Refresh` as the kit's tracked pieces are.
- **The guild uses it unchanged:** its tests stay as they are, a pure move (as the window pieces
  were in #88), `GUI.Guild._test.tabs` kept as the same table (Codex).
- **Its semantics, kept exactly** (Codex):
  - all of a skin's side tabs re-read after any change;
  - native clicks observed as well as `SetChecked`;
  - simultaneous selection allowed (it mirrors, never enforces);
  - per-kit state, active gating, fades re-applied each style pass;
  - late registration synced at once;
  - the accent repaint.
  - Method hooks (`hooksecurefunc`) and script hooks (`HookScript`) are named explicitly in
    `opts.hooks`, never discovered by calling Blizzard methods.

### 2. The skin (`Skin/Character.lua`, key `character`)

- **Registration.** `risk = "plain"`, `live = true`, `backing = "window"`, `frames = CharacterFrame`.
- **The window:**
  - `kit:Panel` (the 0.93 floor); the `NineSlice` faded (`kit:Fade`, since this template has no Bg);
  - `kit:Header` down to `LeftPaneHost`'s top: the title band;
  - `kit:PortraitDisc` (the template's own container: right here);
  - `kit:CloseButton`.
- **The backdrops:**
  - `LeftPaneHost`'s and `RightPaneHost`'s **own regions** (named: their art and `StoneBg`) and the
    divider's texture faded. They're enumerated, never walked recursively into content: the panes'
    lists and the currency pane are never reached (Codex);
  - a recessed pane (Section) on `RightPaneHost`, on a host of ours parented to it (it shows and
    hides with it, collapsed or not);
  - the left pane is the window's glass itself;
  - our separator, a 1 px line along `RightPaneHost`'s left edge.
  - The toggle arrow stays Blizzard's, and the collapse state is never touched.
- **The level line:** `TopBackgroundStripHost`'s two textures faded, a pane on it. The text stays.
- **The model:** its four background corners and the race overlay faded. The model shows on the
  window's glass, as in the mockup. The control buttons stay Blizzard's.
- **The slots** (every `EquipmentSlots` and `WeaponSlots` button, found by name):
  - a small glass well each, parented to the slot, under it, its rim lowered, mouse off (the bags'
    recipe);
  - `BorderFrame` faded;
  - `NormalTexture` faded, **gated by the probe** (Codex): its alpha is read after an equip, an
    unequip, a broken or unusable item's recolour, and a restore. If Blizzard's vertex colour
    brings the alpha back, v1 leaves it stock (a separate issue then); never a hook on the slot's
    update or click path.
  - the item icon, the empty silhouette, `IconBorder` (quality), the cooldown, the sockets and the
    popout stay Blizzard's;
  - **`CharacterAmmoSlot`, its own anatomy** (Codex): its unnamed BACKGROUND texture (the bronze
    ring, found by layer) and its normal texture (`GetNormalTexture`) faded, a well behind it. Its
    arrow child stays;
  - **nothing on the click path:** no script, field, hook or global hook.
- **The stats pane:**
  - its `common-insideframe` border and `ClassBackground` faded, a pane on it;
  - **the headers** ("General", "Primary Attributes", …) as glass bars, through one gated walker
    over `CharacterStatsPaneScrollBox.ScrollBox.ScrollTarget`'s children (a C method, never a mixin
    call) (Codex):
    - it's called **both** by the style pass (rows already there when the skin comes on) and by an
      instance `hooksecurefunc(list, "Update")` on the inner list;
    - **a header is a child with `Background` and `Title`**; its `Background` is faded on every pass
      (fades are dropped by a restore), and our small glass is built once per pooled row;
    - **ordinary stat rows** (`Background` with `Label`/`Value`) get nothing: their alternating
      stripes stay Blizzard's.
  - **The pet's stats** (`CharacterStatsPanePetScrollBox`) stay stock in v1 (Codex).
- **The tabs:**
  - the six mode tabs through `K:SideTab`: `Background` and `SelectedTexture` faded, selected =
    `SelectedTexture:IsShown()`, hooking their `SetChecked`;
  - the four sidebar tabs: their art and `CheckedTexture` faded, selected = `GetChecked()`, hooking
    `SetChecked` and `OnClick`;
  - `TabGlow` and the hover highlight stay.
- **The other panes:** reputation, skills, PvP and statistics show on the faded hosts (the window's
  glass). Their own list and side pane art stays in v1, and the screenshots decide. **Nothing inside
  the currency pane or its transfer UI is touched or hooked.**

### Not in this

- The list rows of the other panes; the model's control buttons; the title and equipment manager
  panes' rows; the toggle arrow.
- Moving a slot, resizing anything, the collapse state.

### Tests

- **The kit move:** the guild's tests pass unchanged.
- **Stubs:** `CharacterFrame` with its shell, hosts, divider, toggle, the six large side tabs
  (Frames with a mixin `SetChecked` toggling `SelectedTexture`), the paper doll's model background,
  strip, the slots (left, right, bottom with `BorderFrame`/`NormalTexture`/`IconBorder`; ammo with
  its own BACKGROUND ring and arrow child), the stats wrapper and its inner list with an `Update`
  that acquires the three row kinds (header: `Background` + `Title`; stat: `Background` + `Label` +
  `Value`), the pet list, the four sidebar CheckButtons, and the currency pane (a `TokenFrame` with
  rows and a transfer toggle, recording any touch).
- **Each piece:**
  - fades and restores;
  - the panes on our hosts;
  - the header, the disc, the close button;
  - the slots' glass, mouse off, no field or script;
  - the stats headers styled across `Update` with pooled reuse, **ordinary rows untouched**;
  - enable → disable → enable while stationary, the rows re-styled without a Blizzard `Update`;
  - the mode tabs' selection from `SelectedTexture`, the sidebar's from `GetChecked`, both mirrored;
  - the accent repaint.
- **Hazards:** no global hook; nothing on the currency pane or its transfer toggle; the pet list
  untouched; no anchor or size on Blizzard's frames.
- **The contract test** with the window opened in combat. Mutation-tested.

### In game (`/fp steps skin character`)

- **The paper doll:** the first opening in combat; the look against the mockup.
- **The slots:** an item equipped, then unequipped (drag), a weapon swapped, an item used from a slot
  (a trinket or a quest item) in combat; the equipment flyout (Alt over a slot), a modified click
  (link, socket) where available. Nothing blocked (taint log on). `IsProtected`/`IsForbidden`
  recorded for the slots and our children at the first opening in combat (Codex).
- **The `NormalTexture` gate:** its alpha read after an equip, an unequip, an unusable item, and off
  and on (Codex).
- **The ammo slot**, on a character using ammo, if any.
- **The model:** drag, zoom, rotate and reset (Codex).
- **The stats headers:** scrolled.
- **The tabs:** each mode tab, and each sidebar tab.
- **The right pane** collapsed, then expanded; the window first opened with it already collapsed;
  collapse while another panel is open (Codex).
- **The pet tab** (a hunter or warlock, if any): player → pet → player, the pet's stats stock.
- **The other panes'** screenshots, the currency pane included; a warband currency transfer and
  its transfer log, if available, with nothing blocked (Codex).
- Off and on; `/reload`.

## Built (2026-10-20)

Codex `gpt-6-astra` consensus in round 2.

- **Section 1.** The side tabs are the kit's (`K:SideTab`, `K:StyleSideTab`, `Kit.SyncSideTabs`,
  `Kit.sideTabs`). The guild uses them with its tests unchanged (`tests/` untouched in that step)
  and green.
- **Section 2:** `Skin/Character.lua`.
- **Tests:**
  - `test_character` 280: the pieces; the hosts' own regions only; the panes; every slot and the
    ammo slot's anatomy; the headers on glass and the stat lines stock across `Update`, and while
    off; the pet list stock; the mode tabs (`SelectedTexture`) and the sidebar (`GetChecked`)
    mirrored; the accent; off and on re-styling without a Blizzard `Update`; another skin's tabs
    left alone.
  - The contract test opens the window in combat and asserts that nothing touches the currency
    pane.
  - 25 mutants of the skin and the kit's side tabs, all killed (three after adding tests: an
    Update while off, the ammo slot's icon layer, another kit's tabs); the probe's checks, 7, all
    killed.
- **Both test files hit Lua 5.1's 200-locals limit;** their newer blocks are each in a `do` scope.

## Run 1 (2026-10-20) and the list headers

**Run 1:** every check passed; FOREVER-PROBE CH.1-5 has the details. The NormalTexture gate held on
all 19 slots after equips, unequips and the flyout, so the fade stays. That answers Codex's P2 on
PR #95, which traced the code but couldn't run it.

**The owner:** "my only problem was the yellow/bronze subsections that should be more like the
quest manager", in reputation, skills and statistics. The three lists share one header template:
an unnamed BACKGROUND bar (`common-button-list-collapseExpand`), its HIGHLIGHT copy, a `StateIcon`
and a `Name` in GameFontNormalLeft. Blizzard only sets the text and the icon's atlas. The tracker's
look on them:
- **a glass bar** (the stats headers' bar), the bronze bar faded;
- **the +/- tinted** in the accent (a tint survives `SetAtlas`, GQT pass B);
- **the name in the accent**: an audited title (docs/PLAN.md, #71);
- **the hover glow** desaturated to white;
- **the sub-headers' red toggle** (`ToggleCollapseButton`'s normal and pushed textures) tinted in
  the accent;
- **entries** are left stock.

Each list's `Update` is post-hooked on the instance, gated (`ScrollBox.lua:762`; a scroll, a
collapse and a data change all reach it through `self:Update()`), and the style pass re-styles
the lists after a switch-on. An accent change repaints them while the skin is on.

**Tests:**
- `test_character` 356: each pane's headers, entries and sub-headers; a collapse; the atlas
  change; the accent, also while off; off and on.
- `test_contract` fills the three lists and audits their header names.
- 18 mutants. Two survived: a redundant `Content` guard (removed) and the refresh while off (a
  test added). All are killed now.
- The probe's list-header checks: 6 mutants, all killed.
