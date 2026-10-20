# The bags in glass (#88)

The bag windows from the merchant's design (#84/#86, docs/MERCHANT.md sections 4-5), which the
owner set as the template for every dialog and window (2026-10-20). Look only, nothing moved.

Codex `gpt-6-astra` review: round 1 (2026-10-20), one BLOCKER (the header's boundary), two SHOULDs
(the header's anchor point, the EllesmereUIBags owner) and two NITs, taken in below (marked
"(Codex)").

## What's read (wow-ui-source `forever`, 70450)

- **The code.** Forever runs Mainline's `ContainerFrame.lua`/`.xml` and a small Camelot file
  (`Blizzard_UIPanels_Game.toc:118-124`). The Camelot file only re-anchors the portrait's
  `CircleMask` and adds jump-hint labels.
- **The windows.**
  - `ContainerFrame1`..`7` (ContainerFrame.xml:300-306): 1 the backpack, 6 the reagent bag. The
    others are generic: a bag takes the first unused eligible window (ContainerFrame.lua:436, 891),
    so the keyring has no window of its own (Codex). They use `ContainerFrameTemplate`
    (`PortraitFrameFlatTemplate`, :231, strata MEDIUM).
  - `ContainerFrameCombinedBags` (:315, `PortraitFrameFlatTemplate`, parent UIParent).
  - Combined or separate follows the `combinedBags` CVar (ContainerFrame.lua:2382-2443); gamepad
    mode forces combined.
- **The flat shell** (SharedUIPanelTemplates.xml:404-426, 566-674):
  - `NineSlice`, re-cropped on every resize (ContainerFrame.lua:992);
  - `Bg`, a frame holding `BottomLeft`, `BottomRight`, `BottomEdge` and `TopSection`. Blizzard
    recolours them on every open with `SetVertexColor`/`SetColorTexture`, never with an alpha
    (:943).
    - `TopSection` is **not** a header band: it runs from the background's top down to
      `BottomRight`'s top (SharedUIPanelTemplates.xml:426, 647), nearly the whole window (Codex).
  - `PortraitContainer.portrait`/`.CircleMask` (the portrait is re-set on every open, :947),
    `TitleContainer.TitleText`, and `CloseButton` (a parentKey only).
  - `PortraitButton` (the filter dropdown, with its `Highlight`).
- **Shared controls.** `BagItemSearchBox` (`BagSearchBoxTemplate`, :308) and
  `BagItemAutoSortButton` (:358) are reparented and re-anchored onto the backpack or the combined
  window in every `UpdateSearchBox` (ContainerFrame.lua:1124-1147).
- **The money box.** `ContainerFrame1MoneyFrame` / the combined window's `.MoneyFrame`
  (`ContainerMoneyFrameTemplate`, :202), its coin box `.Border` (`Left`/`Middle`/`Right`, :208).
  Its owner is switched by `SetMoneyFrameOwner` (ContainerFrame.lua:2538).
- **The item buttons** (`ContainerFrameItemButtonTemplate`, ContainerFrame.xml:81, 37 × 37,
  pooled: `ReleaseAll` and `Acquire` on every open, ContainerFrame.lua:1048-1080).
  - Regions: `icon`, `Count`, `IconBorder` (quality), the overlays, `NormalTexture` (the
    `UI-Quickslot2` rim), `NewItemTexture`, `JunkIcon`, `ItemContextOverlay` (the search dim),
    `Cooldown`, ….
  - **An empty slot** is the atlas in the button's `emptyBackgroundAtlas` key (`bags-item-slot64`,
    ContainerFrame.xml:84), drawn into `icon` itself (`SetItemButtonTexture(nil)`).
  - In combined mode each button also gets an `ItemSlotBackground` texture, created lazily and
    shown with `SetShown` (ContainerFrame.lua:1846-1853).
  - **Every `UpdateItems`** (ContainerFrame.lua:1191-1239) rewrites the icon (texture or atlas, and
    whether it shows), the IconBorder (show, texture, colour), the overlays, the counts, the
    desaturation and the junk icon.
  - The bag refresh paths read here never reset the rim's or the slot background's alpha, so a fade
    holds. The shared `ItemButtonMixin:SetAlpha` (Blizzard_ItemButton/Shared/ItemButtonTemplate.lua:233)
    can write the icon's and the IconBorder's alpha; it isn't called on the bag update path, and
    we never call it (Codex). `NewItemTexture` and `flash` are alpha-animated: never touched.
  - **Updates:** `BAG_UPDATE` marks a window dirty, and an OnUpdate flush calls `Update`; `UpdateItems`
    runs after a ContinuableContainer, so it's asynchronous (:57-77, :1164).
- **Not protected, but on the use path.** The item buttons are plain Lua buttons whose click calls
  `C_Container.UseContainerItem` (:1507, :1608), allowed only untainted ("Prevent bagID from
  tainting all interaction with items through attributes", :1825). So nothing of ours on a
  button but alpha and our own children: never a field, an ID or a script. Opening is gated only
  by `ContainerFrame_AllowedToOpenBags` (:163); no bag frame is protected.
- **Placement** is Blizzard's: `UpdateContainerFrameAnchors` scales (0.75-1) and stacks the
  windows (:1377; UIParent calls it too). It's never touched.
- **References** (behaviour only):
  - **ElvUI's skin path** strips each window, hides `Bg`, and per button clears every texture but a
    few, fades `IconBorder` and swaps the empty icon. It hooks each window's `UpdateItems`. Its
    Forever note concerns the bank only.
  - **Bagnon** replaces the windows: it reparents them on `SetID`, forces `combinedBags` off, and
    treats Forever as Mainline.
  - **Ellesmere** doesn't skin them (its own Bags addon replaces them).

## The plan

### 1. The merchant's window pieces move into the kit

Both windows need them, and the next ones will too.
- `K:Header(win, wg, backing, boundary, point, y)`: the smoky gradient from the window's top down
  to the boundary (`point` of `boundary`, plus `y`), joined to the backing at its RGBA
  (`Theme.Backing`), with the backing starting there.
  - The merchant passes its `Inset` and `"TOP"`: its seam unchanged (Codex).
  - The bags pass their own window glass and `"TOP"`, `-HEADER_H` (section 2).
  - It returns a handle. The kit keeps the handles per skin and repaints them from the Theme
    listener, gated by each skin's own `Engine.Active` (Codex). `GUI.Merchant.Header`/`SetHeader`
    stay the probe's switch.
- `K:CloseButton(button)`: the disc, the X, the four fades, the gated feedback hooks, and
  `Kit.SyncClose(handle)` for the style pass and the accent repaint.
- `K:PortraitDisc(frame)`: the merchant's `portrait()` and `Disc` call.
- `K:FlatShell(frame)`: `NineSlice` and `Bg` faded. Unlike `Shell`, it records nothing missing for
  the button-frame pieces (`TopTileStreaks`, `Inset`) this template doesn't have.
- **The merchant uses them unchanged.** Its tests stay as they are and must stay green: a pure
  move.

### 2. The windows

- **Registration.**
  - `GUI.Engine.Register({ key = "bags", title = "Bags", risk = "plain", live = true, backing =
    "window", frames = ContainerFrame1..7 and ContainerFrameCombinedBags (those that exist), owners =
    { "Bagnon", "Baganator", "AdiBags", "ArkInventory", "BetterBags", "EllesmereUIBags" } })`.
  - `EllesmereUIBags` reparents the separate and combined windows (EUI_Bags_Start.lua:530) and
    depends on EllesmereUI, not on its Blizzard skin, which the engine already stands down for
    (Codex).
  - An owner loaded means Glass UI steps aside, as for the siblings.
- **Each window:**
  - `kit:Panel(frame)` (the 0.93 floor);
  - `K:FlatShell`;
  - `K:Header` down to `HEADER_H` (first guess 26) from the window's top. That's the title strip;
    the portrait rises above it, and the backpack's search row and the items sit below.
    - It's anchored to our own glass, so it follows Blizzard's scale and every window's height.
    - A fixed band rather than the topmost item row (Codex's alternative): the rows move with the
      search box and the bag's size, and the title strip doesn't.
    - Tuned from the screenshots of a short bag, a tall bag, the backpack and the combined window.
  - `K:PortraitDisc`, and `K:CloseButton(frame.CloseButton)`;
  - the title and `PortraitButton` stay Blizzard's.
- **The money box.** On a window with a `MoneyFrame` (the backpack's `ContainerFrame1MoneyFrame`,
  the combined window's `.MoneyFrame`), its `Border` pieces are faded and a Section (the merchant's
  recessed pane) is anchored to the money frame. The section is a texture on the window glass's
  host, so it shows with that window.
- **The search box and the sort button**, shared and moved between windows by Blizzard:
  - **The search box:** its edge textures (`Left`/`Middle`/`Right`, the `common-search-border-*`
    atlases, InputBoxTemplates.xml:43) are faded. A Section of ours sits on a frame of ours
    parented to the box, so it follows the box wherever Blizzard puts it. That frame is one level
    below the box, so the fill never covers the text, and `kit:Adopt`ed (Codex).
  - **The sort button:** a small glass behind it, parented to it; the atlas stays.

### 3. The item slots

- **Hook:** `hooksecurefunc(frame, "UpdateItems")` on each window instance, gated. Then the
  window's children are walked (`GetChildren`, a C method). A button is one with an `icon` and an
  `IconBorder` (fields read, never written).
- **Built once per button** (a weak table keyed by the button): a small glass of ours, parented to
  the button (the pool hides it with the button), its rim at its own level as the merchant's rows,
  mouse off, no backing (`{ backing = false }`). Pearl's `thinRim` makes it `thin_small`
  (approved on many small buttons, Time Is Money).
  - **The cost** (Codex): nine textures, a mask and a rim frame each. That's about 200 frames and
    1,000 regions at 100 slots, bounded by the pools' high-water marks, with no OnUpdate.
  - The probe measures the first open and frame time with a full inventory. If that's too heavy,
    a Section well is the fallback (five textures, no mask or rim frame).
- **Each pass:**
  - the `NormalTexture` (read by `GetNormalTexture`) faded;
  - `ItemSlotBackground` faded when present (combined mode);
  - **the empty slot:** the `icon` dimmed to 0 (`kit:Dim(icon, 0)`) while its atlas is the
    button's own `emptyBackgroundAtlas` (both read). It's `kit:Dim(icon, nil)` once filled, which
    gives back Blizzard's latest alpha, never a forced 1 (Codex).
    - The stock template sets only the atlas, so an empty slot is `SetAtlas` and an item is
      `SetTexture` (Blizzard_ItemButton/Mainline/ItemButtonTemplate.lua:76).
    - An empty slot shows only its glass well, and an item shows its icon.
    - The icon's `SetAtlas`/`SetTexture` are hooked on the instance, gated, so the dim follows
      Blizzard's every update.
- **Left as Blizzard's:** the `IconBorder` (the item's quality), counts, cooldowns, the new-item
  glow (alpha-animated), junk and quest icons, the search dim.
- Nothing on the click path; no field, ID or script on a button; the position, the size and the
  scale are Blizzard's.

### 4. Not in this

- **The bank** (Forever's Camelot bank panel, a separate window): later.
- **`BackpackTokenFrame`** (the tracked currencies under the backpack, created with
  Blizzard_TokenUI): left stock.
- **A tab bar:** the bag windows have none.
- **Quality borders restyled:** Blizzard's, as information.

### Tests

- **Stubs:** a backpack and a combined window (`NineSlice`, `Bg` with its four pieces, the portrait,
  the close button, `MoneyFrame.Border`), the search box and sort button, and item buttons with their
  regions and `emptyBackgroundAtlas`. `UpdateItems` acquires buttons in Blizzard's order, empty and
  filled.
- **The kit move:** the merchant's tests pass unchanged.
- **Each piece:** fades and restores, the glass's parents and levels, the header's anchors and
  colours, the close button, the money and search panes, and the slot wells. The empty dim follows
  `SetAtlas`/`SetTexture`, and a pooled button is reused without a second glass.
- **Gating and ownership:**
  - off: nothing of ours, every hook a no-op; on: re-synced;
  - an owner addon loaded: steps aside.
- **The contract test:** no write on a Blizzard object outside the allowlist.
- Mutation-tested.

### In game (`/fp steps skin bags`)

- **Separate bags:** the backpack and every bag open, with full, partly full and empty slots,
  quality borders, a new item's glow, a search (the dim), and the sort button.
- **Combined bags** (the bags menu's toggle), the same checks.
- **Use path:** an item used from the bags in combat with the taint log on, plus a bag opened
  for the first time in combat (nothing blocked).
- **Window order:** the keyring opened first, then the bags; the other way round. Reagent bag if
  any (Codex).
- **Size and layout:** Blizzard's automatic downscaling with many bags open; a tracked currency
  shown, then hidden (the money box follows).
- **Cost:** the first open and frame time with a full inventory.
- **The rest:** the money box; off, a change, on; `/reload`; a screenshot beside stock.

## Built (2026-10-20)

Codex `gpt-6-astra` consensus in round 2.

- **Section 1.** The kit's window pieces are in: `Header`, `CloseButton`/`CloseFades`/`CloseSync`/
  `PaintClose`, `PortraitDisc`, `FlatShell`, and a tracked repaint per skin.
  - The merchant uses them, its tests unchanged (`tests/` untouched in that step) and green.
  - `PlaceHeader` now re-anchors the header's bottom too, since the bags' band is tuned live.
- **Sections 2-3:** `Skin/Bags.lua`; `GUI.Bags.SetHeaderHeight` (the probe's live tuning, not
  saved).
- **Tests:**
  - `test_bags` 131: the stubs' bag windows fill their pooled buttons as Blizzard's `UpdateItems`
    does; the contract and method tests open the bags too.
  - 33 mutants of the skin and the kit pieces, all killed but two equivalent ones:
    - the close button tracked a second time (its state table is already tracked through the
      header);
    - the merchant's boundary offset (0 there; the bags' test kills it).
  - The probe's checks: 10 mutants, all killed.
