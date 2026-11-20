# The quest details popup in glass (#202): plan

**Status (2026-11-19):** built (the `questpopup` switch in `Skin/GossipQuest.lua`, `QuestText.LightText`),
tested offline (`tests/test_questpopup.lua`, mutation-tested; `test_contract`, `test_methods`). The
in-game run, `/fp steps skin questpopup`, waits for the owner (docs/FOREVER-PROBE.md, QP).

The objective tracker's quest details popup (right-click a quest > details), split out of #114 by the
owner (2026-11-16, "Later, its own issue"). It follows the gossip window and the quest dialog (#201,
`Skin/GossipQuest.lua`, docs/GOSSIP-QUEST.md) and Light quest text (#204, `QuestText.lua`,
docs/QUEST-TEXT.md).

## The frame (wow-ui-source origin/forever 3d8abb1da, 70959)

`QuestLogPopupDetailFrame` (`Blizzard_UIPanels_Game/Mainline/QuestMapFrame.xml:311`), mixin
`QuestLogPopupDetailMixin` (`QuestMapFrame.lua:2525-2640`):
- **It inherits `ButtonFrameTemplate, QuestFramePanelTemplate`.** Both templates name a texture
  `$parentBg` with `parentKey="Bg"`:
  - the shell's rock: `ButtonFrameTemplate` inherits `ButtonFrameBaseTemplate`
    (`SharedUIPanelTemplates.xml:711`), whose rock is BACKGROUND sublevel -6, TOPLEFT 2,-21 to
    BOTTOMRIGHT -2,2 (`:689-695`);
  - the panel's parchment page: atlas `QuestBG-Parchment`, BACKGROUND, TOPLEFT 7,-62
    (`QuestFrameTemplates.xml:3-13`).

  Blizzard writes the page's atlas through `self.Bg` (`ShowQuest`), so the key should be the page,
  and the rock would have no handle but its structure. The global's identity isn't established by
  the inheritance order, and the skin never uses it. **The probe identifies both positively** (below),
  and so does the skin at install: the page is `.Bg` only if it is BACKGROUND, anchored at 7,-62,
  with a parchment atlas; the rock is the one direct BACKGROUND -6 texture anchored at 2,-21 and
  -2,2. A missing or ambiguous match leaves that piece Blizzard's, recorded as a failure.
- The rest of the panel template: four `Material*` corners (BORDER) and `SealMaterialBG` (BORDER,
  shown with a quest's details theme only at contrast 0, `QuestInfo.lua:31-50`).
- The shell: `NineSlice`, `TopTileStreaks`, `Inset`, `PortraitContainer`, `CloseButton`, the title.
- Its own pieces:
  - the book icon (an unnamed OVERLAY -1 texture, 64 px at -6,7, `UI-QuestLog-BookIcon`): the
    visible portrait;
  - `ScrollFrame` (`ScrollFrameTemplate`) with its `ScrollChild`, where QuestInfo is displayed;
  - `ShowMapButton` (its own texture, text and highlight);
  - `AbandonButton`, `TrackButton` and `ShareButton` (`UIPanelButtonTemplate`), enabled per quest
    (`QuestMapFrame.lua:1149-1168`; Share is disabled outside a group).
- **Flow:** `ShowQuest` (`QuestMapFrame.lua:2605-2630`, from `QuestUtils.lua:353`, the tracker's
  menu) runs these in order:
  1. `Update(true)`, which is `QuestInfo_Display(QUEST_TEMPLATE_LOG, ScrollChild)`;
  2. `ShowUIPanel(self)` (area left, `UIPanelWindows.lua:22`);
  3. `self.Bg:SetAtlas(QuestTextContrast.GetDefaultBackgroundAtlas())`;
  4. the side portrait (`QuestModelScene`).

  Showing the same quest again hides it.
- **Its text is redrawn without its page.** `QuestMapFrame_DoFullUpdate` (`QuestMapFrame.lua:507-521`)
  calls `QuestLogPopupDetailFrame:Update()` on every full quest-log update while it's open.
  QuestInfo then re-colours by the current contrast (`QuestInfo.lua:68-95`: Stone when
  `UseLightText()`), but the page is only set in `ShowQuest`.

## Hazards

- **Shown from the panel manager** (area left): `defer = true`, every hook only schedules.
- **QuestInfo is shared** with the quest dialog and the world map's details: its regions are never
  touched (#201's rule). The scroll child is QuestInfo's parent while shown: nothing of ours on it.
- **Text redrawn without the page** (above). After a contrast change from Dark while the popup is
  open, the next quest-log update draws dark text, but the page keeps its dark atlas. With stage 1's
  rule alone (fade the dark atlas), that dark text would sit on bare glass. Reading the setting isn't
  enough either (Codex r1): Dark off, a quest-log update (dark text), then Dark on again without a
  redraw leaves dark text under a page that the atlas and the setting both call dark. So the page
  follows **what Blizzard last painted**.
- **The gamepad** hides the close, Show Map and three buttons (`GamepadHideUnneededElements`): our
  glass is their child and hides with them.
- **The side portrait** (`QuestModelScene`, reparented by `QuestFrame_ShowQuestPortrait`): Blizzard's,
  as in #201.

## What the skin does

One key, `questpopup` ("Quest details popup"): `risk = "plain"`, `defer = true`, `live = true`,
`backing = "window"`. In `Skin/GossipQuest.lua`, with its helpers (the buttons' glass and state, the
page decision).

| Piece | Treatment |
|---|---|
| The shell: `NineSlice`, `TopTileStreaks`, `Inset`, **the rock** (found by structure, not `.Bg`) | faded. Not `kit:Shell`, which fades `.Bg`: here that's the page |
| The window glass (`kit:Panel`) | on the floor |
| The title band (`kit:Header`) | down to the window's top - 62 (the page's top) |
| The portrait | a disc under the book icon. QuestFrame's own-texture path from #201: the disc at the window's level - 1, the window glass one lower |
| The close button | on its disc (`kit:CloseButton`), dimmed while disabled |
| **The page** (`.Bg`, positively identified) | kept; faded only while its atlas is `QuestBG-Parchment-Accessibility4` **and** Blizzard's last paint of the text was light (below) |
| A recessed pane (`kit:Section`) | on our glass, anchored to the page, shown only while the page is faded |
| The material corners, `SealMaterialBG` | kept (hidden under Dark anyway) |
| Abandon, Track, Share | on glass at their level - 1, their state mirrored (#201: disabled dims, pressed lights) |
| Show Map, the scroll bar, QuestInfo, the side portrait | Blizzard's |

**What Blizzard last painted.** Two instance hooks on the popup record it, in our own state. Both check
`Engine.Active` first.
- On the popup's `Update` (`hooksecurefunc(QuestLogPopupDetailFrame, "Update", ...)`, an instance
  hook): QuestInfo has just painted by the setting as it is now (`QuestInfo.lua:68-95`), so it
  records `paintLight = QuestText.LightText()`. `LightText` is a new read-only helper on
  `QuestText`'s one name constant (`live() == DARK`), resolved when the hook runs, since
  `GossipQuest.lua` loads before `QuestText.lua`.
- On the page's `SetAtlas`: nothing recorded (Codex r2). `ShowQuest` runs `ShowUIPanel` and its show
  callbacks between its `Update` and this set, and a contrast change there would make the atlas say
  Dark over text painted dark. So `Update` is the only writer of `paintLight`; this hook only
  schedules a decision, which reads the atlas then.

Then each hook schedules the decision, **once the popup's pieces exist** (Codex r2). On the very
first opening, `Update`'s hook runs before `OnShow` queues the install. So a hook before the install
records the paint and schedules nothing. The install's first style pass decides from the recorded
paint, and a decision never runs without the pane. The decision fades the page only while its atlas is dark and
`paintLight` is true; otherwise the page is kept.
- **Unknown history keeps the page.** `paintLight` is nil until a paint is seen, and cleared when the
  skin is turned off (`def.restored`: the hooks can't record while off), so a skin turned on over an
  open popup keeps the page until Blizzard's next display (Codex r1).
- **The hooks go on when the skin attaches** (its `frames` call at login), not at the first show. So
  `ShowQuest`'s first `Update`, which runs before `ShowUIPanel`, is seen. That's a deviation from the
  engine's "everything at OnShow": it styles nothing and touches no layout. It only observes two
  methods of one instance.

**When it's decided:** at the show (the engine) and a frame after either hook. No `CVAR_UPDATE`
frame: a setting change alone changes neither the page nor the text, until Blizzard redraws, and that
is a hook.

**One frame.** A quest-log update that repaints the text dark under a faded page shows it for one
frame, until the deferred pass (`Engine.Defer`, `C_Timer.After(0)`) gives the page back. The hooks
only schedule: the popup is a panel shown through the panel manager. The acceptance asks whether that
frame is noticeable, and the tests assert the state after the queue drains.

Never: a text colour, a field, a Blizzard method, Show/Hide, a point or size on Blizzard's objects;
QuestInfo's regions; the scroll child.

## The probe (`/fp steps skin questpopup`)

**Measured first:**
1. `.Bg` and `QuestLogPopupDetailFrameBg`, measured independently: each one's layer, sublevel,
   points, atlas and file. The page must be `.Bg` (BACKGROUND, 7,-62, a parchment atlas). The rock:
   exactly one direct BACKGROUND -6 texture anchored at 2,-21 and -2,2. A missing or ambiguous match
   stops the run, and the plan goes back for review. A global pointing at the rock is harmless: the
   skin uses the key and the structure.
2. The book icon: found as a direct OVERLAY -1 texture, 64 px. The levels of the **shown** popup:
   window, `NineSlice`, `PortraitContainer`, the buttons, our glass and disc. #201's own-texture
   recipe puts the glass at the window's level - 2 and the disc at - 1, and both clamp to 0 at window
   level 1, which the dialog measured (Codex r1). The acceptance condition is the disc visible
   under the book. If both land at 0 and the disc doesn't show, the plan comes back with a disc whose
   draw order is set on our own glass.

**Acceptance** (script errors on, blocked actions counted, `/reload`s only):
1. A quest's details from the objective tracker's menu: the window in glass, the page kept (default
   contrast), the buttons on glass with Share dimmed outside a group, Abandon's and Track's states.
   Screenshot.
2. Light quest text on (`/glassui questtext on`): reopen the popup. The page faded, the light text on
   glass. Screenshot.
3. With it open, Light quest text off, then a quest-log update **from looting a quest item**, with the
   same popup staying open and its atlas still dark throughout (the probe checks both). Accepting
   or abandoning another quest hides the popup and reopening resets the page, so those don't count
   (Codex r2). The page back, under the dark text, a frame later at most. Then Light
   quest text on again without reopening it: the page stays (the text is still dark). Reopening:
   faded, light. Screenshots.
4. Track and untrack, Show Map, Abandon (cancel the dialog), and close with X, Esc, and the same
   quest again.
5. The skin off and on with it open, and the master switch.
6. In combat: open it. Nothing blocked.
7. The quest dialog and the world map's details still as #201 left them. `gossipglass`'s check that
   nothing of ours is faded in the popup is scoped to fades owned by the `gossip` and `quest` skins,
   since the popup's own skin now fades its rock (Codex r1). A `questpopup` fade passes it; a
   dialog-owned fade carried into the popup still fails it.
8. Optional: a quest whose details show required money, in Dark: those lines (black or 0.2 grey even
   in Blizzard's Dark, `QuestInfo.lua:342`) compared on stock Dark and on glass. Otherwise recorded as
   unverified, as #201.
9. Ask: does it read right?

## Tests (`tests/test_gossipquest.lua`, a popup part)

The stub's popup with both `Bg` claimants (the page holding the key, the rock as a bare region), the
book icon, the buttons, `ShowQuest` and `Update` in Blizzard's order. Checks:
- styled a frame after the show, in combat too;
- the rock faded, the page kept, not faded through `.Bg` by a Shell call;
- a show in Dark (Update light, then the dark atlas): faded, our pane on it. The atlas dark but the
  last paint dark: kept;
- Codex r1's four steps, asserted after the timer queue drains: open in Dark (faded); Dark off, no
  redraw (still faded: the text is still light); a quest-log update (Update, dark text): restored;
  Dark on again, no redraw: still kept; reopen: faded;
- the skin off and on over an open popup: kept until the next display;
- the first show's `Update` seen (the hooks are on from login). The first-ever opening in Dark:
  the skin stays active, installs the pane, and fades the page once the queue drains (Codex r2);
- a contrast change to Dark during `ShowUIPanel` (between the `Update` and the page set): after the
  queue drains, the page visible and the pane hidden (Codex r2);
- the structure: a popup whose `.Bg` isn't the page, or with two rock candidates: that piece left,
  recorded;
- the buttons' states, the close button;
- off and on, the master switch;
- nothing of ours on the scroll child or QuestInfo; no text colour, field or Lua method
  (`test_contract`, `test_methods`).

Mutation-tested.

## Not in this

- Show Map's own art, the scroll bar.
- Our own text colours.

## Review

Codex (`gpt-6.2-astra`, high), round 1: **no consensus**. Taken:
- the BLOCKER: the page follows Blizzard's last paint (two instance hooks), not the setting; unknown
  history keeps it; the hooks are on from login; the one-frame window said plainly;
- the SHOULDs:
  - both regions positively identified (probe and skin), the citation corrected;
  - the shown popup's levels and a visible disc as an acceptance condition;
  - `gossipglass`'s popup check scoped to the dialog's own fades;
- the NIT: the required-money lines, optional.

Round 2: **no consensus**, no BLOCKER. Taken:
- `Update` is the only writer of the last paint (the page-set hook only schedules);
- no decision before the popup's pieces exist (the first style pass uses the recorded paint);
- the NIT: the open-popup step uses a quest item's loot, the same popup open throughout.

Round 3: **consensus**.
