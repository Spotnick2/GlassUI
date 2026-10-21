# The loot window and the loot roll history in glass (#105): plan

The owner (2026-10-21), from two stock screenshots: the loot window ("Items", on looting a corpse)
and `/loot` (the "Loot Rolls" history), in the window template (memory: the merchant #86 recipe;
character #94, map #99):
- the window glass on the floor (0.93) and a smoky title band;
- the close button on its glass disc (with the hover light, #103);
- each item row on glass, its bronze plate faded.

Kept Blizzard's: the item icons and their quality borders, the names in their quality colours, the
"Common" tag's text, the quest mark, the winner and roll texts, the dropdown, the timer, the resize
handle, the empty-state text.

The anatomy is from `wow-ui-source` origin/forever (70450). Both windows are always loaded.

## The loot window (`LootFrame`)

`Blizzard_UIPanels_Game` (`Mainline/LootFrame.xml:116`), from these templates:
- `ScrollingFlatPanelTemplate` → `DefaultPanelFlatTemplate` → `DefaultPanelBaseTemplate`;
- `EditModeLootFrameSystemTemplate`.

It is HIGH and `toplevel`, 220 wide and up to 290 tall.

**How it opens:** `LOOT_OPENED` → `Open()` builds the data provider, then `ShowUIPanel(self)`
(`LootFrame.lua:225-270`). It's an area-left UI panel; a plain `Show` with `lootUnderMouse` or
after Edit Mode moved it. You can loot in combat. `ShowUIPanel`/`HideUIPanel` refuse in combat
when the calling code is tainted (`UIParentPanelManager.lua:853-858`).

**So, as for the map:** `defer = true`. The engine installs and styles a frame after the show,
and every hook only schedules (`Engine.Defer`). Nothing of ours runs inside `Open`, the panel
manager or `HideUIPanel`, and nothing writes a field on the frame, its ScrollBox or a row. Master
loot reads `LootFrame.selected*`, written by Blizzard's row OnClick; we never touch them.

| Piece | Art | The skin |
|---|---|---|
| `NineSlice` | the metal frame (`ButtonFrameTemplateNoPortrait`). `Resize()` on every open re-crops the two bottom corners with `SetTexture`/`SetTexCoord` (`ScrollingFlatPanel.lua:35-51`, `NineSlice.lua:237-292`) | the NineSlice **frame** faded (alpha holds; a blank wouldn't) |
| `Bg` (`FlatPanelBackgroundTemplate` frame) | its four pieces in `PANEL_BACKGROUND_COLOR` | the frame faded |
| `TitleContainer.TitleText` ("Items") | GameFontNormal | Blizzard's |
| `ClosePanelButton` | `RedButton-Exit*`, 28x28 on Camelot | `kit:CloseButton` (disc, X, hover light) |
| ScrollBox shadows (`ScrollBox.Shadows.Upper/Lower`, `ScrollBox.xml:33-43`) | `_looting_itemcard_shadow-center` | Blizzard's by design: a soft edge on the list, only while it scrolls |
| `ScrollBar` | `MinimalScrollBar`, only when it scrolls | Blizzard's (the owner: stock bars) |
| The window glass | none | `kit:Panel(LootFrame)` on the floor; `kit:Header` from the top down to the ScrollBox's TOP |

**The rows** (`LootFrameItemElementTemplate`, `LootFrameMoneyElementTemplate`; `LootFrame.xml:7-115`):

| Region | Lua after creation | The skin |
|---|---|---|
| `NameFrame` (the plate, `looting_itemcard_bg`, BACKGROUND) | `SetVertexColor(quality)` on every `Init` (:494) | faded (alpha holds) |
| `BorderFrame` (the bronze edge, BORDER) | never | faded |
| `QualityStripe` (behind "Common", item rows) | never | faded; "Common" stays, white on glass |
| `HighlightNameFrame` / `PushedNameFrame` (gold ADD strokes) | Show/Hide on enter, leave, down and up | tinted white (desaturated): the neutral hover, as the game menu's |
| `Item.NormalTexture` (the slot frame, `UI-Quickslot2`) | its vertex colour on every `Init` (:509, 512) | faded (alpha holds) |
| `Item.icon`, `IconBorder` (quality), `IconOverlay*`, `Count`, `IconQuestTexture`, `Text`, `QualityText` | content | Blizzard's |
| The row | its `ShowAnim` (alpha 0 → 1) and `SlideOutRightAnim` (auto-loot) | a small glass panel of ours on the row (level − 1, rim lowered, mouse off). The row's alpha and slide carry it |

- **Finding the rows:** `hooksecurefunc(LootFrame.ScrollBox, "Update")` (instance), which
  schedules a pass. The pass walks `ScrollBox.ScrollTarget:GetChildren()`. A row is a child with
  a `NameFrame` and a `BorderFrame` (`LootFrameBaseElementTemplate`'s empty slot has neither).
  This is the character stats' idiom (`Character.lua`).
- **Not used:** `ScrollUtil.AddAcquiredFrameCallback`, which registers into Blizzard's callback
  registry.
- **`LOOT_SLOT_CHANGED` re-runs `Init` without an Update** (`LootFrame.lua:178-186`). Alpha holds
  through it, and the glass is ours, so nothing to redo.

## The loot roll history (`GroupLootHistoryFrame`, `/loot`)

`Blizzard_FrameXML` (`Mainline/LootHistory.xml:193`), `DefaultPanelFlatTemplate`. It is HIGH,
`toplevel`, movable, and resizable from 261x300 to 261x800.

**Not a UI panel:** `/loot` is `ToggleLootHistoryFrame` → `SetShown` (`LootHistory.lua:666-668`),
and it makes no protected call. Low risk, so `risk = "plain"`, no `defer`. Its hooks still only
schedule.

| Piece | The skin |
|---|---|
| `NineSlice`, `Bg` | faded |
| `ClosePanelButton` | `kit:CloseButton` |
| The window glass | `kit:Panel` on the floor (anchored to the frame, so it follows the owner's resize); `kit:Header` down to the ScrollBox's TOP |
| `EncounterDropdown`, `Timer` (its own bar), `ResizeButton` (the handle hanging below), `NoInfoString` | Blizzard's |
| Rows (`LootHistoryElementTemplate`, level 500): `BackgroundArtFrame` (level 400) `.NameFrame` and `.BorderFrame` (never re-set) | faded; a glass panel of ours parented to the row **at `BackgroundArtFrame`'s level − 1** (399), its rim lowered there (Codex r1). That keeps it under the roll-100 effect (`PerfectRollFrame` at 450, `LootHistory.xml:283`, anchored over a row, `LootHistory.lua:594-598`) and under the item and text (500) |
| `Item` (its NormalTexture empty), `ItemName` (quality colour), `WinningRollInfo`, `PendingRollInfo`, `AllPassedInfo`, `PlayerRoll` | Blizzard's |
| `LootHistoryPassedHeaderTemplate` (text only) | Blizzard's |
| `PerfectAnimFrame` (a roll-100 glow, an element outside the list) | Blizzard's: the walk covers `ScrollTarget`'s children only |

The rows are found the same way: `hooksecurefunc(GroupLootHistoryFrame.ScrollBox, "Update")`
schedules the walk. A row is a child with a `BackgroundArtFrame` holding a `NameFrame`. Re-inits
on `LOOT_HISTORY_UPDATE_DROP` don't touch the plates.

## The roll popups

Out of scope: `GroupLootFrame1-4` in `GroupLootContainer`, a managed bottom frame that Ellesmere
refuses to touch. They're a later skin.

## Engine and kit

Two skins in `Skin/Loot.lua`, one switch per window:
- **`loot`:** `defer = true`, `live`, `backing = "window"`.
- **`loothistory`:** `live`, `backing = "window"`.

Both use the kit's `Panel`, `Header`, `CloseButton` and `Fade`/`Tint`. Rows share one function:
a row's glass once (in our weak table), at a level given by the window, its plates faded each pass.
- Loot rows: the row's level − 1.
- History rows: `BackgroundArtFrame`'s level − 1.

Both ScrollBox hooks schedule through `Engine.Defer`, as the map's do, not inline as the character
stats' did.

## Neighbours

- Leatrix Plus's loot options (faster auto loot, disable loot warnings) call `LootSlot` and
  `ConfirmLootSlot`, never the frame, and they're Off on the owner's client.
- RXP and NodeRadarProbe only read `LootFrame:IsShown()`.
- No loot replacement (XLoot) is installed. If one ever is, it goes in `owners`.
- ElvUI's own loot frame unregisters `LootFrame`. The engine's suite rule already turns every skin
  off while ElvUI is loaded.

## The probe (`/fp steps skin lootglass`)

1. **The first loot of the session in combat**, from a fresh `/reload`. Shift-loot to defeat
   auto-loot (`autoLootDefault` is 1 on the owner's client). The window installs and styles a
   frame later.
   - It counts BLOCKED and FORBIDDEN, and reads that the window opened in combat (the panel
     manager).
2. **A second loot in combat** (Codex r1). `Open` sets the data provider before showing the
   window (`LootFrame.lua:252`), so this one runs through the installed ScrollBox hook. Close it
   **still in combat**, each way across the runs:
   - by taking everything;
   - with the X;
   - with Esc.
3. **The look** (a screenshot) against the template.
4. **Taking items:**
   - one by click;
   - a money row;
   - an auto-loot (rows sliding out);
   - a corpse with more items than fit, scrolled, so rows are acquired and reused (unverified if
     none comes up).
5. **The other positioning paths:**
   - "Open loot window at mouse" (`lootUnderMouse`) on, a loot, then off (`LootFrame.lua:254-273`);
   - Edit Mode: move the loot window, save, loot; then move it, discard, loot
     (`EditModeSystemTemplates.lua:2325-2342`).
6. **Off and on** with the window open.
7. **Master loot** (`GroupLootFrame.lua:267-293, 985-995`, reading `LootFrame.selected*`): a
   selection, an assignment, a confirmation, when group content allows. Otherwise recorded as
   unverified.
8. **`/loot`:**
   - the empty state (a screenshot);
   - a resize with the handle;
   - closing it;
   - off and on.
9. **A fake history row** (the owner's "unless we fake it"). The probe, not the skin, on the open
   history:
   - shows its ScrollBox and hides `NoInfoString`. With no encounter, `SetInfoShown(false)`
     hides the list (`LootHistory.lua:336-343, 461-467`; Codex r1);
   - builds one `LootHistoryElementTemplate` frame inside the ScrollTarget, anchored at its top;
   - calls its `Init` with a complete fake drop: a cached item link (Hearthstone), a winner
     `{ playerName, playerClass }`, `playerRollState`, and `rollInfos` for its tooltip;
   - turns the skin off and on (the style pass walks the ScrollTarget), reads the row in glass at
     399, and takes a screenshot.

   This checks the template's styling, not the list's acquisition, scrolling or pooling: the
   fake row isn't in the data provider. Blizzard code called from the probe taints, so the step
   ends with a `/reload`. Real rows, and a roll-100 effect over one, need group content. The
   procedure reads them if a group loot happens, and records them as unverified otherwise.

## Tests

`test_loot.lua`, on stubs built from the anatomy above:
- **The loot window:**
  - the deferral (nothing inside the show or the ScrollBox's Update);
  - the shell;
  - the rows: item, money and empty, the plates faded, the strokes white, the slot faded, the
    content untouched, one glass per pooled row;
  - `Init`'s vertex re-set keeps the fades;
  - a slide-out;
  - off and on, and an Update while off.
- **The history:**
  - the shell;
  - rows and passed headers, the `PerfectAnimFrame` untouched, the row glass at
    `BackgroundArtFrame`'s level − 1 (under 450);
  - the resize (the glass anchored).
- **Both:**
  - `test_contract`: opened in combat, rows, off and on, no field written;
  - `test_methods`;
  - every new test mutation-tested.

## Codex round 1 (gpt-6-astra, high): no blocker, three SHOULDs, all taken

1. **The history's row glass** sits at `BackgroundArtFrame`'s level − 1 (399), under the roll-100
   effect (450), not at the row − 1 (499).
2. **The fake history row** shows the hidden ScrollBox first, with complete fake data. It checks
   the template's styling only.
3. **The acceptance matrix gains:**
   - a second loot in combat, through the installed hook, closed in combat (by taking
     everything, the X, Esc);
   - `lootUnderMouse`;
   - Edit Mode save and discard;
   - a scrolled corpse;
   - master loot (unverified without group content).

Nit taken: the ScrollBox shadows stay stock by design. They have keys
(`ScrollBox.Shadows.Upper/Lower`).

## Codex round 2: consensus

Every round-1 finding is resolved, with nothing new:
- 399 sits above the window glass and the faded level-0 `Bg`, and under the effect (450) and the
  content (500);
- showing the empty ScrollBox from the probe runs no Blizzard refresh, and the step's `/reload`
  clears it.

## Built (2026-10-21)

- **`Skin/Loot.lua`:** two skins.
  - Rows are found by one key: a loot row's `NameFrame`, a history row's `BackgroundArtFrame`.
    The `BorderFrame` / `NameFrame` guards survived mutation as redundant, and were removed.
  - Every hook goes through `schedule`: an instance `hooksecurefunc` that only defers.
- **Tests:**
  - **`test_loot` 124:**
    - the deferral (nothing inside `Open` or an Update, in combat);
    - the shell;
    - item, money and empty rows;
    - `Init`'s re-colouring kept faded;
    - a slide-out;
    - a second loot's new rows;
    - the history's rows at 399 under 450, its headers and padding, the `PerfectAnimFrame`;
    - off and on for each, with the other window unaffected.
  - **`test_contract`** loots in combat twice, with `/loot`, off and on.
  - **Mutation:** 22 mutants of the skin. Two survivors were redundant guards, now removed.
  - **The probe's loot checks:** 9 mutants, all killed (two after an added test).
