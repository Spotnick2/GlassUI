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
  is positional RGBA). Clear and class
  rise to the floor, and smoked's 0.92 stays. The tint, the wash and the colour of the backing stay
  the body's; only the alpha rises.
- **The tracker and the meter keep the body's 0.35:** QT.3 found it enough over bright ground, and
  they sit over the world, not over other windows.
- **The floor's value is the owner's pick in game:** `Theme.WINDOW_BACKING`, 0.75 until then. The
  acceptance tries 0.6, 0.75 and 0.85 live over another window (RestedXP's, or the quest log). It
  sets the value on Glass UI's own table and calls `Theme.Refresh`, then takes a screenshot each
  time.
- **The merchant's tabs:** they get the floor too (same skin).

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
- **The glass:** `GUI.Glass.Disc(host, "disc_small")`, registered with Theme. Its backing is masked
  by the disc's mask, at the window's floor, so the ring reads as part of the window.
- **Levels:** the host and its rim (`g.top`) at the PortraitContainer's level - 1 (399).
  - That's under the portrait, which covers the disc's centre, so only a ring shows, as on
    GlassMiniMap.
  - It's above the body (0) and the rows (1-2).
  - The rim is under the portrait, so LibGlass's own disc rim needs no perimeter-only art.
- **It goes with the skin:** it's in `kit.panels`, hidden by Restore and the handover, and shown by
  ShowPanels.
- **The other portrait windows** (#48 names them): later, through the same kit method
  (`kit:PortraitDisc(frame)`), once each window's skin exists.

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
- **MS.1: the window floor.** 0.6, 0.75 and 0.85 over RestedXP's window or the quest log, a
  screenshot each. The owner picks one, and that becomes `WINDOW_BACKING`.
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
