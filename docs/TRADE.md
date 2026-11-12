# The trade window in glass (#113): plan

The owner (2026-10-21, a stock screenshot of a trade between their two characters): `TradeFrame` in
the window template (memory: the merchant #86 recipe; bags #88, character #94, loot #105):
- the floor and a smoky title band;
- the two portraits on discs;
- the item columns as recessed panes, their slots as glass wells;
- Trade and Cancel on glass;
- the close button on its disc, with the hover light (#103).

Kept Blizzard's:
- the names;
- the money input, which is **forbidden**;
- the recipient's money display;
- item icons, quality borders and names, and the recipient's red;
- the accept highlights (the trade's state);
- "Will not be traded", and the enchant slot's glyph.

The anatomy is from `wow-ui-source` origin/forever (70450). The owner can trade between their own
two accounts, so every case can be probed.

**Re-checked on 70888** (the clone at 70888, 2026-11-12): TradeFrame.xml is unchanged since 70450.
TradeFrame.lua's one change is gamepad-only: `TradeFrame_OnShow` opens all the bags instead of the
backpack when the gamepad UI is on (:29-31). The skin touches neither. Since 70707, the shared
`ItemButton` intrinsic masks the icon, the normal and the pushed texture (`common-iconmask`,
Blizzard_ItemButton/Shared/ItemButtonTemplate.xml:19), as in the bags. The slots' look is judged
in the run (TD.1).

## The frame

`TradeFrame` comes from Blizzard_UIPanels_Game `Mainline/TradeFrame.{xml,lua}` (toc 116-117,
always loaded; there's no Camelot variant).
- **Templates:** `ButtonFrameTemplate` → `ButtonFrameBaseTemplate` → `PortraitFrameBaseTemplate`.
- **Strata and size:** MEDIUM, `toplevel`, movable, 344x446.
- **A UI panel:** area left. `TRADE_SHOW` and `TRADE_UPDATE` → `ShowUIPanel(self, 1)` →
  `TradeFrame_Update` (TF.lua:36-44); `TRADE_CLOSED` → `HideUIPanel`.
- **No `ShowAnim`.** The only animation is each slot's `Alert.ItemIconAlertAnim`, on its own
  flipbook texture. So #109's revert shouldn't apply, but the probe checks the fades hold across
  `TRADE_UPDATE`.

**`defer = true`, as the map and the loot window:** the panel manager opens it through its secure
delegate. Every hook of ours only schedules.

## Hazards

- **The money input is forbidden.** `TradePlayerInputMoneyFrame:SetForbidden()` (TF.lua:21): the
  frame, `…Gold` and `…GoldMiddle` throw on every method but `IsForbidden` (Ellesmere measured,
  WindowPacks.lua:13950-13981). The money calls are `HasRestrictions`.
  - **Never touch that row, never anchor to it.** Only the inset behind it (a separate frame) is
    faded.
  - **Never walk `TradeFrame:GetChildren()`:** it returns the forbidden frame. Every piece is
    reached by its global name or key.
- **The drop paths:** the slots' `ClickTradeButton`/`ClickTargetTradeButton` (OnClick, OnDragStart,
  OnReceiveDrag), and the window's own `OnMouseUp`, which drops cursor money or an item into the
  first free slot (TF.lua:247-258). **No frame of ours takes the mouse.** On item buttons: alpha and
  our own children only, as for the bags (#88).
- **Blizzard's fields** (`acceptState`, `.enabled`, `.warningTooltip`, `.hasItem`) are never
  written.
- **Six insets share `parentKey="LeftInset"`** (the last wins), so they're reached by their globals.
- **Accepting:** `C_SecureTransfer.AcceptTrade` is `HasRestrictions`; the confirm dialog is
  Blizzard_SecureTransferUI, a secure environment, untouched.

## What the skin does

| Piece | Art | The skin |
|---|---|---|
| `TradeFrame.NineSlice` | Metal (`PortraitFrameTemplate` layout; its TopLeftCorner is the player's ring) | faded |
| `TradeFrameBg`, `TopTileStreaks` | rock, streaks | faded |
| The window glass | none | `kit:Panel(TradeFrame)` on the floor (0.93); `kit:Header` from the top down to `TradePlayerInputMoneyInset`'s TOP (the names and portraits in the band) |
| `TradeRecipientBG` (white 0.15: the lighter half) | | faded; one floor for both halves |
| The divider: `TradeRecipientLeftBorder`, `TradeRecipientBotLeftCorner` | `!UI-Frame-LeftTile`, `UI-Frame-BotCornerLeft` | faded; a 1 px line of ours along `TradeRecipientLeftBorder` (SECTION_EDGE), the character window's separator |
| The player's portrait (`PortraitContainer.portrait`, re-set by `SetPortraitToUnit` on every update) | | `kit:PortraitDisc` round its mask |
| The recipient's (`RecipientOverlay.portrait`, 60x60, no mask; `.portraitFrame` its ring, level 550) | | `.portraitFrame` faded; a disc of ours behind the portrait, **parented to `TradeFrame`**, not to `RecipientOverlay` (a `ResizeLayoutFrame` whose layout counts its shown children, `LayoutFrame.lua:12-62`; Codex r1). Anchored to the portrait, at `RecipientOverlay`'s level − 1 (549), its rim there too |
| Item insets (`TradePlayerItemsInset`, `TradeRecipientItemsInset`) and enchant insets (`…EnchantInset`) | `InsetFrameTemplate`: `.Bg` (marble), `.NineSlice` | `.Bg` and `.NineSlice` faded; a recessed pane (`kit:Section`) on the window glass itself, over each inset (as the bags' money box): over the glass's body, under every Blizzard region. The enchant captions ("Will not be traded", `TradeFramePlayerEnchantText`/`…RecipientEnchantText`) are ARTWORK on `TradeFrame` itself (`TradeFrame.xml:204-214`), outside the enchant insets; so a pane on the window glass, a level under `TradeFrame`, never covers them (Codex r1's fallback, taken from the start) |
| Money insets (`TradePlayerInputMoneyInset`, `TradeRecipientMoneyInset`) | the same | the same: a recessed pane behind the money row, which itself is never touched |
| `TradeFrameInset` (the template's, collapsed by the attic: a stray line) | | `.Bg`, `.NineSlice` faded |
| `TradeRecipientMoneyBg` (`ThinGoldEdge`, alpha 0.6 at OnLoad) | | faded. Restore gives back Blizzard's 0.6: `Fade` keeps Blizzard's latest alpha |
| Slots `TradePlayerItem1..7`, `TradeRecipientItem1..7`: `.SlotTexture` (bronze socket), `$parentNameFrame` (the plate) | | both faded |
| Their `$parentItemButton` | `NormalTexture` (the slot frame) | faded; a glass well round the button, the button's child but at the **slot frame's** level − 1, its rim there too, mouse off: under slot 7's enchant glyph (ARTWORK on the slot frame, over the button's area) and the accept highlights |
| The recipient's red (unusable): `SetVertexColor` on the icon, NameFrame, SlotTexture (TF.lua:174-182) | | the icon keeps its red. The faded plate's red is mirrored on the well: a fill of ours at the merchant's quiet red (`RED` 0.12), shown while the NameFrame reads red. An instance `hooksecurefunc(nameFrame, "SetVertexColor")` that only **schedules** (`Engine.Defer`), then reads the latest colour through `API.Plain` and numeric checks (the merchant's guard, `Merchant.lua:117`). An unreadable colour clears our mirror; the icon keeps its warning. Also read once per style pass |
| Slot 7's enchant glyph (anonymous ARTWORK) | | Blizzard's: it says what the slot is |
| Accept highlights (`TradeHighlightPlayer`, `…Recipient`, `…PlayerEnchant`, `…RecipientEnchant`) | shown and hidden by Blizzard | Blizzard's: the trade's state (Ellesmere leaves them too) |
| `TradeFrameTradeButton`, `TradeFrameCancelButton` | red `Left`/`Middle`/`Right` (`SetTexture` again on every show, press and enable: alpha holds, a blank wouldn't); a `HIGHLIGHT` | the three faded; small glass of ours under each (level − 1, **its rim lowered to that level too**: LibGlass makes it host + 10; the game menu's recipe, `GameMenu.lua:45`; Codex r1), mouse off; the highlight tinted white (the game menu's neutral hover, #90) |
| `TradeFrameCloseButton` | `RedButton-Exit*` | `kit:CloseButton` |
| Names, "Will not be traded", the money display, item content, `WarningIcon` | | Blizzard's |

## Engine

- `key = "trade"`, `risk = "plain"`, `defer = true`, `live`, `backing = "window"`, `frames = TradeFrame`.
- **The install** builds the window glass, header, discs, panes, wells and button glass once, and
  the recipient's red hooks.
- **The style pass** (each show) fades, re-reads the red, and places the header.
- **No hook on Blizzard's global update functions.** Nothing else needs one: no art is re-faded by
  Blizzard on an update (the survey), and the red has its instance hook.

## The probe (`/fp steps skin tradeglass`, rev 2)

Between the owner's two accounts, read on the account that runs the probe.
1. **The first trade of the session:** the window built a frame after its show; the shell faded;
   0 blocked and forbidden. Then later trades, **started from either account**, including the
   incoming request's accept/decline popup if the client shows one.
2. **The look,** in a screenshot.
3. **Items both ways, by every input route:** click and remove a slot's item, drag between slots,
   drop an item on the window's background, drop cursor money (the window's `OnMouseUp`,
   `TradeFrame.lua:247-257`). All through the player's actions; the probe calls no trade function.
   - an item **the probing character can't use**, offered by the other (the red mirrored);
   - a stack (the count);
   - the enchant slot;
   - money on both sides (the input works, the display reads).
4. **Accepting** on both sides (the highlights; the trade completes).
   - **Cancel before and after accepting:** once accepted, Cancel calls `CancelTradeAccept()`, else
     it closes (`TradeFrame.lua:230-235`).
   - **An offer changed after accepting:** the highlights, the Trade button's state and its warning
     icon update (`:89-97`, `:210-227`).
   - **The secure confirmation:** confirm and cancel (Blizzard_SecureTransferUI on
     `SECURE_TRANSFER_CONFIRM_TRADE_ACCEPT`). Unverified if normal play doesn't raise it.
   - **The enchant binding confirmation,** if available (`GameDialogDefs.lua:2185-2196`: it disables
     and re-enables Trade, and its cancel calls `ClickTradeButton`); else unverified.
   - Closing with the X and with Esc.
5. **Fades across `TRADE_UPDATE`**, and reading whether `NameFrame`, `SlotTexture` and
   `RecipientOverlay` are forbidden (the survey measured only the money row).
6. **Off and on,** with a trade open. **A `/reload`.** **In combat,** if a trade can open in combat
   (unmeasured); otherwise recorded as unavailable.
7. **Rev 2 (Codex on #154): the taint log on** after the first pass, as `mapglass` does. The
   reload at the start would turn it off, so it's turned on mid-run. Then a trade with items on
   both sides, Trade and Cancel, and everything in 6 except the reload, run with the log on. The
   run ends with it off. The log is read from `Logs\taint.log` after the run (FOREVER-PROBE TD.7).

## Tests

`test_trade.lua`, on stubs built from the anatomy above (the money frame stubbed as forbidden:
every method throws):
- **The window:** the deferral; the shell; the halves; the divider and our line.
- **The portraits:** both discs (the recipient's at 549, under the portrait).
- **The insets:** faded, with their panes.
- **The slots:** both sides, slot 7's glyph kept, the wells (mouse off).
- **The recipient's red:**
  - mirrored a frame after the hook, not inside it;
  - red → white and red → empty clear it;
  - recoloured while the skin is off, then on: re-read;
  - an unreadable colour clears it;
  - a pass queued before a switch-off is dropped.
- **The buttons:** the red re-`SetTexture`d keeps the fade; the glass's **host and rim** both at
  button − 1; the highlight white.
- **The recipient disc:** parented to `TradeFrame`, at 549, its rim too.
- **Restoring:** the recipient money edge's 0.6 given back; off and on.
- **Untouched:** the money row, the highlights, the names, the content. No frame of ours takes the
  mouse. No `GetChildren` on TradeFrame: the stub throws if it's called.
- **The other suites:** `test_contract`, `test_methods`.

Mutation-tested.

## Codex round 1 (gpt-6-astra, high): no blocker, two SHOULDs, all taken

1. **The Trade/Cancel glass's rim** is lowered to its host (button − 1), as the game menu's is.
2. **The probe** covers trades from either side, every input route, cancelling before and after
   accepting, an offer changed after accepting, the secure confirmation and the enchant binding
   confirmation, with what normal play doesn't raise recorded as unverified. The red's lifecycle is
   tested offline.

Also taken:
- the nit: the recipient's disc is parented to `TradeFrame`, out of `RecipientOverlay`'s layout;
- the red hook only schedules, with the merchant's `API.Plain` guard;
- the enchant captions are checked in the screenshot.

## Implemented (branch `trade-glass`)

- `Skin\Trade.lua`, key `trade`; `WoW.makeTrade` in the stubs (the money input as a forbidden
  proxy that throws on any key but `IsForbidden`; `TradeFrame:GetChildren` from addon code throws).
- `test_trade` 254 checks, 36 mutants all killed; the contract and methods tests open a trade.
- `/fp steps skin tradeglass` (docs/FOREVER-PROBE.md, TD): its checks tested in `test_probe`, 13
  mutants all killed.
- In game: not run yet (the beta was down on 2026-10-21).
