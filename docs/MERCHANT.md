# The merchant revisited: a denser window, glass rows, a portrait disc (#80, #48)

The merchant skin (#4, `Skin\Merchant.lua`) has been on `main` since 70425: the window and its
tabs on glass, the shell art faded, the item rows stock. The owner, 2026-10-20, with a vendor open
over RestedXP's guide window: "you will have to adjust the vendor to have the same fill as the
quest tracking I assume, and like I said earlier, probably a glass circle around the headshot
similar to glassminimap's circle". Asked whether "fill" meant a denser background or glass item
rows, the owner answered **both**. So there are three parts:

1. a denser backing for the window (#80);
2. its item rows in glass, Blizzard's red kept (#80);
3. a glass disc around the NPC portrait (#48).

Codex `gpt-6-astra` review: consensus in round 2, 2026-10-20 (round 1: one BLOCKER, the buyback slot's emptiness; one SHOULD, the disc on
the portrait's mask; NITs), revised.

## What's measured or read

Wow-ui-source `forever`, `Blizzard_UIPanels_Game\Mainline\MerchantFrame.xml/.lua`, and SkinProbe
W1.2's tree (70374, account #1's log):
- `MerchantFrame` is in strata MEDIUM at **level 1**. Our body panel sits one under, clamped to 0.
- **The rows:** `MerchantItem1`..`12` (`MerchantItemTemplate`, 153 x 44) are at **level 2**. Each has:
  - `SlotTexture` (`UI-EmptySlot`, 64 x 64 at -13, 13);
  - `<row>NameFrame`, the label plate (`UI-Merchant-LabelSlots`, 128 x 78);
  - both are BACKGROUND textures of the row;
  - the `ItemButton` at its TOPLEFT (37 x 37), `Name`, the money and alt-currency frames.
- **Blizzard colours only the plates and the icon, never their alpha** (`MerchantFrame.lua:369-404`,
  through `SetItemButtonNameFrameVertexColor`, `ItemButtonTemplate.lua:154`, which calls
  `nameFrame:SetVertexColor` on that texture):

  "Red" is Blizzard's `tintRed = not isPurchasable or (not isUsable and not isHeirloom)`, and "sold
  out" is `numAvailable == 0` or a known heirloom (`MerchantFrame.lua:369-373`).

  | The item | NameFrame | Slot | Icon |
  |---|---|---|---|
  | normal | 0.5 grey | white | white |
  | red | 1, 0, 0 | red | 0.9 red |
  | sold out, and red | 0.5, 0, 0 | dark red | dark red |
  | sold out | 0.5 grey | 0.5 grey | 0.5 grey |
  | no item (empty row) | 0.5 grey | 0.4 grey | the `ItemButton` hidden |

  Rows 11 and 12 show on the buyback tab only (12 per page there, 10 on the merchant's).
- **The buyback slot:** `MerchantBuyBackItem` (115 x 37) has the same `SlotTexture`. Its `NameFrame` is
  `hidden="true"` in XML. **Its button is never hidden:** empty, Blizzard clears its name and count and
  sets its icon to `""` (`SetItemButtonTexture`, `MerchantFrame.lua:428-430`, reaching
  `icon:SetTexture` in `ItemButtonTemplate.lua`), and it shows the slot on the merchant tab whatever
  it holds (`:478`).
- **The portrait:** what shows is `MerchantFrame.PortraitContainer.portrait` (global name
  `MerchantFramePortrait`, OVERLAY). Its container is at **level 400**, under the NineSlice (500, faded)
  and the title (510). The 60 x 60 texture in MerchantFrame.xml's BACKGROUND layer shares the global
  name but draws nothing (`tex=nil`). The stock gold portrait ring is part of the NineSlice, already
  faded.
  - **It is masked round:** `PortraitContainer.CircleMask` (`SharedUIPanelTemplates.xml:574-596`) covers
    the 62 x 62 portrait inset by (2, 0) and (-2, 4). That's **58 x 58, centred 2 px above the
    texture's centre**, so the disc centres on the mask, not on the texture.
  - Blizzard changes the portrait's image on the buyback tab.
- **The backing's history** (Theme.lua's header): on this window on 70425, the owner compared 0.85,
  0.6 and 0.35 over the world and chose 0.35, "the most like glass". The new case is a window over
  **other UI** (RestedXP's window, bright text), where 0.35 lets it read through.
- **LibGlass r11** has `Glass.Disc(host, "disc" | "disc_small")`: a square host, `disc_small` under
  ~96 px (GLASS-MATERIAL.md). GlassMiniMap's ring is one such disc behind a round map. Its own rim
  art is only for a disc whose rim sits over the map; ours sits under the portrait (below).

## 1. A denser backing for windows

- **Per skin, not per theme:** `Engine.Register` gains an optional `backing = "window"`. The kit
  passes it to `Theme.Register(g, backing, "window")`.
- **The window floor:** `paint` uses `max(body.backing[4], Theme.WINDOW_BACKING)` (`Suite.Body`'s backing
  is positional RGBA). Clear, class and smoked all rise to it. The tint, the wash and the colour of
  the backing stay the body's; only the alpha rises.
- **The tracker and the meter keep the body's 0.35:** QT.3 found it enough over bright ground, and
  they sit over the world, not over other windows.
- **The floor is opaque, `Theme.WINDOW_BACKING = 1`** (MS.1, 70450, 2026-10-20). Over RestedXP's
  window, its text still read through at 0.6, 0.75 and 0.85, dimmed by exactly the floor: 63, 40 and
  23 levels above the background in the screenshots, which is 0.4 : 0.25 : 0.15. The owner picked
  "0.85 more", then asked to hide what's behind altogether. An opaque backing does that without
  touching RestedXP's frame (another addon's window is never ours to hide or fade). Changing the
  merchant's strata doesn't help either: the merchant already draws over RestedXP, and it was only
  see-through. The glass is the tint, wash and rim over the backing.
- **Then 0.85, `Theme.WINDOW_BACKING = 0.85`** (ML run 1, 2026-10-20): the owner found opaque too
  much and pointed at Blizzard's own bags, where a damage meter behind shows "just a bit". ML run 2
  tries 0.8, 0.85 and 0.9 live (on Glass UI's own table, then `Theme.Refresh`), a screenshot each.
- **The merchant's tabs:** they get the floor too (same skin).
- **The Pearl header** (ML run 1, the owner: "the top of the dialog could be fully pearl (with the
  head and title) until the first bar"): the window's backing, our own texture, starts at the item
  inset's top (`TOP` on `MerchantFrame.Inset`, `LEFT`/`RIGHT`/`BOTTOM` on the window's glass)
  instead of covering the whole window. Above it, the portrait, the title and the close button sit
  on clear Pearl glass (tint, wash, rim), like the portrait's disc. `GUI.Merchant.SetHeader(on)`
  switches it live for the probe (not saved), re-anchoring through `layout()`, gated.

## 2. The item rows in glass

For each `MerchantItem1`..`12` and `MerchantBuyBackItem`, found by global name (`kit:Global`):
- **Faded:** its `SlotTexture` and its `NameFrame` (SetAlpha, held). Blizzard only sets their vertex
  colour, so the fade holds through every update.
- **A glass row of ours:** a new `kit:Panel(row, "small", ROW_INSETS, nil, { backing = false })`.
  - It is the row's child, so it shows and hides with the row (11 and 12 per tab).
  - It sits at the row's level - 1 (1), over the body (0). Its rim (`g.top`, which `Apply` makes at
    +10) goes to the same level, under the row's icon border and text, as the tracker's rims.
  - **No backing:** the window's backing is already under it, and two would stack into a darker
    plate than the window. The row is the material's tint, wash and rim, painted by Theme.
  - `ROW_INSETS` outset the row by a few px around the icon and name. They're set from the
    screenshots.
- **Blizzard's red, mirrored:** a texture of ours in the row's glass, over its tint, masked by its mask,
  coloured red.
  - It shows when the NameFrame's vertex colour is red (r > 0.4, g and b < 0.1), at an alpha that
    follows r: 0.35 for 1, 0.18 for 0.5.
  - The colour is read with `GetVertexColor` at each style pass. Each channel goes through
    `API.Plain` (it takes one value) and must be a number before it's compared. A
    `hooksecurefunc` on **that NameFrame instance's** `SetVertexColor` takes Blizzard's latest
    (args through `API.Plain`). The icon keeps its own red, untouched.
  - Every callback checks `Engine.Active("merchant")`.
- **An empty row shows no glass:** `ItemButton:IsShown()` at each style pass, and `HookScript`
  `OnShow`/`OnHide` on each `ItemButton`, show or hide our row (our own frame), Active-gated. The
  engine's `ShowPanels` runs before `style` when the skin comes back on, so `style` corrects them.
- **The buyback slot:** faded and on glass the same way, with its NameFrame left as Blizzard has it
  (hidden); its red is only its icon's. **Its emptiness is its icon's:** empty when its icon's
  texture is `nil` or `""`. That's read with `GetTexture` at each style pass, and taken from a
  `hooksecurefunc` on **that icon instance's** `SetTexture` (and `SetAtlas`, non-empty), Active-gated.
  Its button never hides, so `OnShow`/`OnHide` can't tell.
- **Kit change:** `K:Panel(window, size, insets, anchor, opts)`. `opts.backing == false` makes no
  backing, and `Theme.Register(g, nil, ...)` already paints a surface without one.
- **Contract:**
  - `SetAlpha` on Blizzard textures;
  - `hooksecurefunc` on a specific texture instance and `HookScript` on the item buttons;
  - getters only otherwise;
  - our frames unnamed.

  No field writes, no Lua method calls. `test_contract`'s session opens the merchant through
  `MerchantFrame_Update`-like stub calls that recolour plates and hide buttons.

## 3. The portrait disc (#48)

- **The host:** our square frame, parented to `MerchantFrame` and centred on the portrait's round mask
  (`PortraitContainer.CircleMask`, by key; else the portrait, `PortraitContainer.portrait`). It is
  the mask's width + 2 x `DISC_RING` (6 px), read with `GetWidth` at install.
  - The mask and portrait are sized in XML and never resized by Blizzard. A width that can't be read
    falls back to 58.
- **The glass:** `GUI.Glass.Disc(host, "disc_small")`: Pearl, painted clear whatever the suite tint
  (`Theme.Register(g, nil, "clear")`), with **no backing**, like GlassMiniMap's ring. With a backing
  at the window's floor it read as a dark ring, and the owner wants it Pearl and clear (MS.3,
  2026-10-20).
- **Levels:** the host and its rim (`g.top`) at the PortraitContainer's level - 1 (399).
  - That's under the portrait, which covers the disc's centre, so only a ring shows, as on
    GlassMiniMap.
  - It's above the body (0) and the rows (1-2).
  - The rim is under the portrait, so LibGlass's own disc rim needs no perimeter-only art.
- **It goes with the skin:** it's in `kit.panels`, hidden by Restore and the handover, and shown by
  ShowPanels.
- **The other portrait windows** (#48 names them): later, through the same kit method
  (`kit:PortraitDisc(frame)`), once each window's skin exists.

## 4. The layout: sections, or the mockup's bar (#84)

Codex `gpt-6-astra` review: consensus in round 1, 2026-10-20 (no BLOCKER or SHOULD; one NIT, the
acceptance's lifecycle cases, taken into `merchantlayout`).

**Why:** the skin fades Blizzard's item inset, the two boxes of its bottom band
(`MerchantFrameBottomLeftBorder`, atlas `UI-Merchant-BotFrame`) and its money and currency insets.
That leaves one flat slab where the buyback arrow (`MerchantBuyBackItemItemButton.UndoFrame.Arrow`,
greyed while nothing is sold) and the money float. The owner's words were "icons seem to be just
there without purpose".

The owner sent a mockup and GPT's critique of it, then said: "make it a bit closer to the original
UI for the moment, but I'd be curious to try both". So there are two layouts, switched live by the
probe:
- **`sections`**, the default: closer to Blizzard's;
- **`bar`**: the mockup's.

Nothing of Blizzard's is moved, resized, retexted or recoloured. Every new piece is our own.

### What's read (wow-ui-source `forever`, 70450)

- **The bottom band** is `MerchantFrameBottomLeftBorder`: 334 × 61 at the frame's BOTTOMLEFT (1, 26),
  so x 1-335 and y 26-87.
  - **Its two boxes**, measured off the skin-off screenshot of MS run 1 (1.79 px per unit) and
    still to be tuned:
    - left: x 6-196;
    - right: x 200-330;
    - both: y 27-75, which is 12 below the band's top and 1 above its bottom.
  - **The left box** holds the repair buttons (repair vendors) and Sell All Junk (when
    `C_MerchantFrame.IsSellAllJunkEnabled`). Otherwise it's empty.
  - **The right box** holds `MerchantBuyBackItem`: 115 × 37, at MerchantItem10's BOTTOMLEFT (+30,
    −53), with its ItemButton at the item's TOPLEFT.
- **The money strip:**
  - `MerchantExtraCurrencyInset`: BOTTOMLEFT (4, 4) to (169, 27);
  - `MerchantMoneyInset`: (−171, 27) to BOTTOMRIGHT (−5, 4);
  - both `useParentLevel`.
- **The Buyback tab** (`MerchantFrame_UpdateBuybackInfo`, MerchantFrame.lua:532-597):
  - it hides the band, `MerchantBuyBackItem`, the repair and junk buttons and the page controls;
  - it shows `BuybackBG` and rows 11-12, which sit where the band was (MerchantItem11 is 15 under
    item 9);
  - the merchant tab (:470-490) shows the band and `MerchantBuyBackItem` again;
  - **so `MerchantBuyBackItem` is shown exactly while the Merchant tab is.**
- **The selected tab** (`PanelTemplates_SelectTab`, SharedUIPanelTemplates.lua:629):
  - it hides `Left`/`Middle`/`Right`, shows `LeftActive`/`MiddleActive`/`RightActive` and
    disables the tab;
  - `PanelTemplates_DeselectTab` does the reverse;
  - the kit fades all six (`K:Tab`), so today only the text colour tells the tabs apart.
- **The Buyback tab's portrait** is `SetPortraitToAsset("Interface\\MerchantFrame\\UI-BuyBack-Icon")`
  (:533). The tab's label is the global string `BUYBACK` (MerchantFrame.xml:599).
- **Levels, measured on 70450:** MerchantFrame 1, rows 2, PortraitContainer 400.
  - Our window glass is at 0 and the rows' glass at 1.
  - LibGlass paints a panel's body in its host's BACKGROUND (−8 to −3), and its rims and gloss on
    `g.top` (OVERLAY).
  - **So a texture in the window glass's host, on BORDER or ARTWORK, draws over the window's body,
    under its rim, and under every row's glass (level 1).** This is where sections go, with no
    frame-level ties: a frame of our own at 0 or 1 would tie with the window's glass or the rows'.

### The pieces

- **A section:** two textures of ours in the window glass's host:
  - a fill: ARTWORK, black at `SECTION_FILL` (0.4; run 1's backing colour at 0.25 didn't show);
  - an edge: four 1 px lines on BORDER (no, ARTWORK 1), white at `SECTION_EDGE` (0.12).
  
  The result is a recessed pane with a restrained edge. That is Pearl's "edge highlight", and not
  another LibGlass panel, which would add a second gloss over the items (the GPT critique: "free of
  added reflection overlays"). Each section is anchored to Blizzard regions by `SetPoint` on our
  texture, which never touches theirs.
  - **The colour** was planned as `Suite.BACKING`, the one backing colour for every tint. Over a
    window floor of that very colour, near opaque, a pane of it was invisible (ML run 1: the owner
    couldn't tell the two layouts apart). It is black now, which darkens any tint and needs no
    repaint either: the planned Theme surface kind was dropped.
- **The tab state:** `HookScript("OnShow"/"OnHide")` on `MerchantBuyBackItem`, gated, calls
  `layout()`. So does the style pass.
- **`sections`:**
  - the item inset: `MerchantFrame.Inset`, all points (the content area under the header);
  - Merchant tab only: the band's two boxes, anchored to `MerchantFrameBottomLeftBorder` with
    `BOX_INSETS`;
  - always: the money inset and the currency inset, all points of each.
- **`bar`:**
  - **The header line:** one 1 px edge along the inset's top.
  - **The footer bar:** one section.
    - Merchant tab: from the band's TOPLEFT (+5, −12) to the money inset's BOTTOMRIGHT.
    - Buyback tab: from the currency inset's TOPLEFT to the money inset's BOTTOMRIGHT, so it stays
      clear of rows 11-12.
    - It's re-anchored by `layout()`, on our own texture.
  - **The buyback square:**
    - a frame of ours parented to `MerchantBuyBackItem`, so it hides with it on the Buyback tab;
    - at that item's level, under its ItemButton (level + 1);
    - a section's fill and edge round the ItemButton (`SQUARE_OUTSET` 3);
    - shown always on the Merchant tab, so the arrow sits in a slot.
  - **The label:**
    - a FontString of ours in that frame, `GameFontHighlight`, text `BUYBACK` (else "Buyback");
    - LEFT on the ItemButton's RIGHT +8;
    - shown while the slot is empty, by the same `filled()` test and the same `SetTexture`/
      `SetAtlas` hooks the slot already has;
    - with an item, Blizzard's own name shows there instead.
  - **The empty state:**
    - a frame of ours, a child of MerchantFrame at its level + 1, centred on `MerchantFrame.Inset`;
    - inside: the buyback icon (that asset, on our texture, 40 px, on a buyback-square-like
      section), "No items to buy back" (`GameFontHighlightLarge`) and "Items you sell will appear
      here." (`GameFontDisable`);
    - shown when the window is shown, `MerchantBuyBackItem` is hidden (the Buyback tab) and
      `GetNumBuybackItems() == 0`;
    - re-checked by `layout()`, which is called from the tab hooks, the style pass and the rows'
      existing ItemButton OnShow/OnHide hooks (the Buyback tab's first row shows or hides when the
      count leaves or reaches 0).
  - **Less red:**
    - the row's red mirror at `RED_BAR` 0.12 instead of 0.35, at full red (half at dark red);
    - Blizzard's own red icon tint carries the warning, untouched;
    - in `sections` the red stays 0.35, as Blizzard's plate.
- **For both, the active tab:**
  - one texture of ours on each tab's glass host: ARTWORK, white at `TAB_ACTIVE` (0.2; run 1's
    0.10 didn't show), masked by its glass;
  - shown while that tab's `MiddleActive` is shown;
  - `hooksecurefunc(tab.MiddleActive, "Show"/"Hide")` on the instance, gated, plus the style
    pass reading `MiddleActive:IsShown()`.

  Blizzard's text colours stay.
- **The tabs hang from the window** (ML run 1, the owner: "the tabs at the bottom need more work,
  they feel disconnected"). Each tab's glass sat inside the tab's footprint, a rounded pill of its
  own under the window. Now its top reaches `TAB_TUCK` (12 px) up under the window, and the glass
  (and its rim frame, `g.top`) sits in the strata below the window's (`MerchantFrame` is a MEDIUM
  panel, so LOW). The window's floor and rim cover the tab's top and corners, so the tab hangs from
  the window's edge as Blizzard's do. Our own frames' strata only; the tab is never touched. Set in
  the style pass, from the window's strata at that time.
- **The switch:**
  - `GUI.Merchant.SetLayout("sections" | "bar")`: live, it repaints through `layout()` and the red
    mirrors;
  - not saved: the probe sets it;
  - after the owner's pick, the other is removed or becomes a setting, the owner's call;
  - an unknown name is refused.
- **Off:**
  - section textures and our frames live under our panels or are added to `kit.panels`, so off
    hides them all;
  - `layout()` runs only while `Engine.Active("merchant")`;
  - on again, the style pass re-runs it.

### Not in this

- **The title's place** (the mockup left-aligns it next to the portrait), the coins' size, and the
  money and buyback slot sharing one line: all three would move Blizzard's regions.
- **The close button as a Pearl control:** that means replacing its art, which is a later step, if
  wanted.
- **Thinner rims on the window glass:** those are LibGlass's material, so it's a LibGlass question
  for all the siblings.

### Tests (planned)

- Both layouts, built and switched live: which sections show on each tab, their anchors on
  Blizzard's regions, and their parent (the window host) and layers.
- The bar re-anchored per tab.
- The square and the label: the label shown only while the slot is empty, and following the hooks.
- The empty state: only on the Buyback tab with 0 items. It hides on the first sale and on the
  Merchant tab.
- The red: 0.35 in sections, 0.12 in bar, and repainted live by the switch.
- The active tab: following MiddleActive's Show/Hide, and gated.
- Off: nothing of ours shown, every hook a no-op. On: re-synced.
- A section's fill is black at `SECTION_FILL`, and its edges are white at `SECTION_EDGE`, 1 px.
- Run 2: the header's backing anchors and its live switch (gated while off); the tabs' glass
  tucked and a strata below; the empty state's icon path whole.

### In game (`/fp steps skin merchantlayout`)

On a vendor with an unusable item, both layouts, live, a screenshot each:
- the Merchant tab, sections then bar;
- after a sale, the buyback slot;
- the Buyback tab with nothing sold (a fresh vendor visit, before selling), in both layouts;
- the tabs' active marking;
- off and on.

The owner picks a layout, and the box insets get tuned from the screenshots.

**Run 1** (2026-10-20, 70450): every check passed, but the owner couldn't tell the layouts apart (the
panes didn't show), the tabs felt disconnected, and the empty state's icon was missing (its path had
lost its backslashes). The box insets match Blizzard's boxes in the skin-off screenshot: no tuning.
**Run 2** asks plainly: the panes, the tabs, the Pearl header (on and off), the floor at 0.8, 0.85
and 0.9, then sections or bar (Yes / No).

## Tests

- **Theme:** a "window" surface gets the floor on clear and class, and keeps smoked's 0.92; a body
  surface keeps 0.35; refresh repaints both.
- **The kit:** a Panel with `backing = false` has no backing texture and is still painted.
- **The merchant**, on the stubbed window:
  - the slots and plates faded;
  - each row's glass parented, levelled and inset;
  - a plate's red mirrored (1 and 0.5), and cleared when Blizzard sets grey;
  - an empty row's glass hidden, and shown again with an item;
  - the buyback slot;
  - every hook gated (off: nothing changes);
  - off gives back the alphas and hides our rows and the disc;
  - on again re-syncs them;
  - the disc centred on the mask, its width + 12, at the PortraitContainer's level - 1, its rim
    there too, and the portrait as the fallback without a mask;
  - the buyback slot: empty, then filled, then empty again (the last item bought back), its button
    shown throughout;
  - rows: a full page, a partial page and a full page again; buyback, merchant and buyback again,
    with 11 and 12 filled;
  - off, Blizzard recolours and empties rows, on: the latest state shown.
- **The contract:** the session drives plate recolours and empty rows. The SetVertexColor hook on
  plates is on the allowlist (hooksecurefunc), and nothing else is called.

All mutation-checked.

## In game: `/fp steps skin merchant`, extended

The existing procedure (buy, sell, buyback, off and on, a /reload), plus, recorded as MS.1-MS.3 in
docs/FOREVER-PROBE.md:
- **MS.1: the window floor.** 0.85, 0.95 and 1 over RestedXP's window or the quest log, a
  screenshot each. 1 is the default; the owner confirms it still reads as glass.
- **MS.2: the rows.** A vendor with an item you can't use (red) and a page with empty rows:
  - the red reads on the glass;
  - empty rows show no glass;
  - the buyback tab's 12 rows and the buyback slot;
  - screenshots.
- **MS.3: the disc.** It sits round the portrait, concentric, and reads as a ring, on the NPC's
  portrait and on the buyback tab's. Its size against the portrait is
  the owner's call (a screenshot).
- **MS.4: off and on.** Off is Blizzard's look exactly, the plates back in their colours; on again, as
  before.

## Not in this

- **Other windows' discs:** their skins come first.
- **Sharing the disc recipe with GlassMiniMap** (#48 suggests it): GlassMiniMap's ring is its
  own (runes, notch). Ours is LibGlass's plain disc, which is already shared through the library.
