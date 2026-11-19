# The gossip window and the NPC quest dialog in glass (#115, #114): plan

Two windows every quest giver opens: `GossipFrame` (an NPC's greeting and options) and `QuestFrame`
(a quest's greeting, details, progress and reward). One plan, two skins (two switches), the window
template (merchant #86 ... trade #113).

**Status (2026-11-19):** stage 1 built (`Skin\GossipQuest.lua`, the kit's disabled close button) and
tested offline (`tests/test_gossipquest.lua`, mutation-tested; `test_contract`, `test_methods`).
Accepted in game on 70938 (`/fp steps skin gossipglass`, run #482-#483: 26 checks, none failed;
docs/FOREVER-PROBE.md, GQ). Measured there: `QuestFramePortrait` is the shell's portrait, so the
quest dialog's disc is the kit's `PortraitDisc`. Not seen in game: the reward panel, a greeting
list, the required-money lines, auto-accept.

## Owner decisions (2026-11-16)

- **The text stays Blizzard's, and so does the page under it, unless Blizzard's own setting says
  otherwise.** The quest and gossip text is dark brown, made for the parchment page, and the skin
  contract forbids recolouring it. Blizzard has a dark mode of its own: Settings, Accessibility,
  **Quest Text Contrast: Dark** (`questTextContrast` = 4). With it Blizzard switches the quest and
  gossip text to its light "Stone" colours and the page to a dark parchment
  (`QuestBG-Parchment-Accessibility4`). Not quite every string: the required-money lines are written
  black or 0.2 grey whatever the contrast (`QuestFrame.lua:235-250`, `QuestInfo.lua:342-354`), in
  stock Dark mode too. So:
  - the frame, the title band, the portrait, the close button and the buttons go to glass;
  - the page stays behind the text by default (dark text on parchment, readable);
  - while Blizzard shows its dark page, the skin fades it and the light text sits on the glass.
- **"We can be flexible on that rule with a proper setting to have the option."** An opt-in setting
  for light text on glass without the player finding Blizzard's: stage 2 below, its own audited
  exception, after stage 1 is accepted in game.
- **The quest details popup** (`QuestLogPopupDetailFrame`, the objective tracker's menu): its own
  issue later. It shares QuestInfo with this dialog and the map, and has two `Bg` regions to measure.

## The frames (wow-ui-source origin/forever 70938)

Forever loads the mainline files (`Blizzard_UIPanels_Game.toc:83-109, 200-206`): `[Family]` =
Mainline, `[Game]` = Camelot.

### GossipFrame (`Mainline/GossipFrame.xml:34`)

- A `UIThemeContainerFrame` (intrinsic, `Blizzard_AccessibilityTemplates`) inheriting
  `ButtonFrameTemplate`, 338x496. The shell: `NineSlice` (level 500), `PortraitContainer` (400:
  `.portrait` = `GossipFramePortrait`, `.CircleMask`), `TitleContainer.TitleText`, `Bg` (rock,
  BACKGROUND -6), `TopTileStreaks`, `CloseButton` = `GossipFrameCloseButton`, `Inset` (`Bg` marble
  BACKGROUND -5, its `NineSlice`).
- **The page** is `GossipFrame.Background` (BACKGROUND 0, TOPLEFT 7,-62). On every `Update` the theme
  sets its atlas, `SetAtlas(QuestTextContrast.GetTextureKitBackgroundAtlas(kit), UseAtlasSize)`
  (`AccessibilityTemplates.lua:77-81`): `QuestBG-Parchment`, `-Accessibility`, `-Accessibility2..4` by the contrast, or
  `QuestBG-<textureKit>` when the NPC sends a kit with such an atlas. That is the only per-NPC theme.
- `GreetingPanel` (384x512): four `Material*` BORDER textures that nothing on Forever sets, the
  `GoodbyeButton` (`UIPanelButtonTemplate`, `Left`/`Middle`/`Right`, re-textured per state), the
  `ScrollBox` (WowScrollBoxList) and a `MinimalScrollBar`.
- The rows (`GossipFrameShared.lua:118-167`): the greeting text, spacers, options, active and
  available quests; `QuestFontLeft` (black). Each initialiser registers the row's font string with
  the theme, which sets its colour (and `SetFixedColor`) on every `Update`; `Setup` sets the icon's
  vertex colour.
- **Flow:** `GOSSIP_SHOW` goes to `CustomGossipFrameManager` (`CustomGossipFrameBase.lua:46-55`), then
  `GossipFrame:HandleShow`: `ShowUIPanel` (area left: the panel manager's secure delegate), then the
  background, the friendship bar and `Update`. **OnShow fires before `Update`**: the rows, title,
  portrait and page are set after it. No animation, no alpha anywhere in the gossip files.
- A one-option NPC flagged `selectOptionWhenOnlyOption` never shows the frame.

### QuestFrame (`Mainline/QuestFrame.xml:42`)

- A plain frame inheriting `ButtonFrameTemplate`, 338x496: the same shell. Its own children:
  `QuestNpcNameFrame` (empty on Forever: the NPC's name is the title), `AccountCompletedNotice`
  (always hidden on Camelot), `FriendshipStatusBar`, and `QuestModelScene` (a side portrait, reparented
  and anchored outside the frame at strata HIGH when the server sends a portrait).
- **`QuestFramePortrait` names two textures**: the shell's `PortraitContainer.portrait`
  (`$parentPortrait`) and an ARTWORK texture of QuestFrame's own (`QuestFrame.xml:44-53`), which
  `QuestFrame_SetPortrait` fills. Measured in the probe; the skin reaches the disc's target by key.
- **Four panels** (`QuestFramePanelTemplate`, `QuestFrameTemplates.xml:3-49`): Greeting, Detail,
  Progress, Reward. Each has **the page**, `.Bg` (atlas `QuestBG-Parchment`, BACKGROUND, at 7,-62),
  four `Material*` corners and `SealMaterialBG` (BORDER, hidden unless a server material or a seal
  theme applies). Each panel's OnShow calls `QuestFrame_SetMaterial`: `.Bg:SetAtlas(...)` every time,
  the corners shown only for a material other than Parchment, which any contrast above 0 forces.
- Scroll frames (`QuestScrollFrameTemplate`, a `MinimalScrollBar`); the buttons
  (`UIPanelButtonTemplate`): `QuestFrameAcceptButton`, `QuestFrameDeclineButton`,
  `QuestFrameCompleteButton`, `QuestFrameGoodbyeButton`, `QuestFrameCompleteQuestButton`,
  `QuestFrameGreetingGoodbyeButton`. Plain quest APIs (`AcceptQuest`, `CompleteQuest`,
  `GetQuestReward`), no secure templates.
- **QuestInfo is shared**: the detail and reward panels show `QuestInfo_Display`'s regions, which
  are reparented on every display and also serve the popup and the world map's details.
- **Flow:** QuestFrame registers its own `QUEST_*` events; a panel `Hide(); Show()`, then
  `ShowUIPanel(QuestFrame)` (area left). QUEST_FINISHED hides it.

## Hazards

- **Shown from the panel manager's secure delegate** (both are area-left UI panels): `defer = true`,
  every hook only schedules, as the map, loot and trade skins.
- **Blizzard drives alpha** on the scroll children (`QuestGreeting/Progress/RewardScrollChildFrame`,
  faded in when `instantQuestText` is 0) and on the detail panel's `alphaDependentText`
  (`QuestInfoRewardsFrame` included) during the typewriter. **Never faded, and nothing of ours is
  their child** (our children would inherit the fade).
- **`QuestItemTemplate:OnEnter` reads the button's alpha** (`GetAlpha() > 0`) for its tooltip: the
  item buttons' alpha is never touched (v1 doesn't touch them at all).
- **Text colours are Blizzard's**, set per `Update` (gossip's theme) and per display (QuestInfo). The
  skin never writes one (stage 1).
- **QuestInfo's regions move between windows**: v1 touches none of them, so the popup and the map
  never inherit a treatment.
- **Re-textured per show**: the pages (`SetAtlas`), the buttons' three pieces (`SetTexture` per
  state), the material corners (`SetShown`, `SetTexture`). Alpha holds across `SetAtlas` and
  `SetTexture` (measured: docs/MAP.md, docs/TRADE.md), so a fade stays; the probe re-checks on these
  windows.
- **#109:** no ShowAnim on either window (no AnimationGroup in the gossip or quest files), so a fade
  at the show isn't undone.
- **ScrollBox first layout** (gossip): the engine styles at OnShow, deferred, never at load (Ellesmere
  v9.8.6 WindowPacks, "a skin must NEVER be the thing that triggers a ScrollBox-backed", ~12837). The
  skin never walks or touches the rows.
- **DialogueUI** (`References\Addons\QuestsLeveling\DialogueUI`, 1.0.7c; not installed here)
  replaces both windows by unregistering their events (`CustomGossipFrameManager`'s `GOSSIP_SHOW`,
  `QuestFrame:UnregisterAllEvents()`): they never show, so the skin never runs. Its "Use WoW's
  Default UI In Instance" gives them back inside instances, and then the skin should style them. So
  **no owner and no yield**: the skin runs exactly when Blizzard's windows show. Never re-register
  their events or touch `UIPanelWindows` (that is DialogueUI's switch).
- **The NPE guide and Torghast** custom gossip frames replace GossipFrame for their texture kits;
  GossipFrame doesn't show then. Out of scope.

## What the skin does

Two keys: `gossip` ("Gossip window") and `quest` ("Quest dialog"). Each: `risk = "plain"`,
`defer = true`, `live = true`, `backing = "window"`.

| Piece | Gossip | Quest |
|---|---|---|
| The shell (`kit:Shell`: NineSlice, rock `Bg`, `TopTileStreaks`, `Inset`) | faded | faded |
| The window glass (`kit:Panel`) | on the floor | on the floor |
| The title band (`kit:Header`) | down to the window's top - 62 (the page's top edge) | the same: every panel's page is at 7,-62, so the band never follows a panel |
| The title | Blizzard's | Blizzard's |
| The portrait | a disc (`kit:PortraitDisc`) | a disc under the texture Blizzard actually fills: the probe decides (below) |
| The close button | on its disc (`kit:CloseButton`), our X dimmed while Blizzard's is disabled | the same (auto-accept disables it) |
| **The page** | `Background`: kept; faded while it shows the dark atlas | each panel's `.Bg`: kept; faded while it shows the dark atlas |
| A recessed pane where the page is (`kit:Section`) | on our glass, anchored to the page, shown only while the page is faded | **one** pane, re-anchored to the shown panel's page, shown only while that page is faded |
| The material corners, `SealMaterialBG` | (none set on Forever) | kept: part of the page (hidden under Dark anyway) |
| The buttons (Goodbye; Accept, Decline, Continue, Cancel, Complete Quest, Goodbye) | on glass at the button's level - 1, `Left`/`Middle`/`Right` faded, the highlight white (trade's recipe) | the same |
| The rows, the scroll bars, the friendship bar, QuestInfo, the item and reward buttons, the model scene | Blizzard's | Blizzard's |

- **The page decision follows what Blizzard shows, not the setting** (Codex r1, the blocker). The
  quest dialog doesn't re-colour an open panel when the setting changes: `QuestFrame` registers no
  `CVAR_UPDATE`; its colours come with each panel's show (`QuestFrame_SetMaterial`, the greeting and
  progress OnShows, `QuestInfo_Display`). So fading on the cvar alone would leave dark text on glass
  until Blizzard next refreshes the panel. The page's own atlas says what Blizzard presented: when it is
  `QuestBG-Parchment-Accessibility4`, the same pass made the text light (`QuestTextContrast.lua:17-37`;
  a panel's page and colours are set together, `QuestFrame.lua:130-132, 205-216, 330-335, 579-581`;
  gossip's `UpdateTheme` sets the background and the row colours together). A conservative condition,
  one way only: light text can also come with another page (an NPC's `QuestBG-<kit>` at contrast 4,
  whose text still follows the contrast; a server material), and those pages are kept. So: the page's
  `GetAtlas()` (a getter) is the dark one: `kit:Fade(page)`, the pane shown; anything else (the
  default parchment, contrast 1-3, an NPC's `QuestBG-<kit>`, a server material): `kit:Dim(page, nil)`
  (the kit's per-region restore, Blizzard's latest alpha; no new restore) and the pane hidden.
- **When it's decided: whenever Blizzard sets a page's atlas** (Codex r2). An instance
  `hooksecurefunc(page, "SetAtlas", ...)` on gossip's `Background` and on each quest panel's `.Bg`,
  `Engine.Active` first, only scheduling a deferred style that reads the final atlas and the shown
  panel then. That catches every refresh, including the ones with no OnShow: `QUEST_LOG_UPDATE` calls
  `QuestFrameGreetingPanel_OnShow` directly on a shown greeting (`QuestFrame.lua:86-91`), and a new
  gossip texture kit re-sets the background while the window stays shown (`GossipFrame.lua:61-65`).
  Also at the window's show (the engine). An open quest panel keeps its page until Blizzard re-sets
  it, as its text. *Built:* the plan also had a `HookScript` on each panel's OnShow and a
  `CVAR_UPDATE` frame of ours. Both are dropped: every panel's OnShow re-sets its page
  (`QuestFrame_SetMaterial`, `QuestFrame.lua:669`) and the setting reaches the page only through
  Blizzard's re-set, so the `SetAtlas` hook already runs on every path. Mutation testing showed it:
  removing either changed nothing the tests could see.
- **The band's bottom** is the window's top - 62, where every page starts (gossip's `Background`,
  each panel's `.Bg`: TOPLEFT 7,-62, resized from the atlas, so only the extent moves).
- **The buttons' glass** is a mouse-off child of the button at its level - 1, the rim there too
  (trade's `glassAt`): it hides with Decline under auto-accept, with the buttons under the gamepad
  and with Goodbye in the tutorial.
- **The close button disabled** (auto-accept): the kit's close feedback reads `IsEnabled()` and dims
  our X, no hover light; `OnEnable`/`OnDisable` hooked on the instance, scheduling a sync. A kit
  change, so every window's close button gets it.
- Every hook checks `Engine.Active(key)` first and only schedules. No hook on the rows, the ScrollBox,
  QuestInfo, the panels' scroll children or any global function (`QuestInfo_Display`,
  `QuestFrame_SetTextColor`).

Never: a text colour or font (stage 1), `SetText`, a field, a Blizzard method (mixin or global
utility), `Show`/`Hide`, a point or size, the scroll children's or item buttons' alpha.

## Stage 2 (after stage 1's acceptance): light text on glass, as an option

The owner's opening. Two ways; the plan recommends the first:

1. **A shortcut to Blizzard's own dark mode.** Blizzard then does the colours itself (the rows' fixed
   colours, the objectives' completed colour, the reward texts, inline colour codes; not the
   required-money lines, as in stock Dark mode) and the skin's stage-1 rule fades the page. One cvar
   write, out of combat, only from the player's click: an audited exception to "never change a
   setting", recorded in docs/PLAN.md. Its scope, said by the control: every reader of the setting
   (books and letters, the quest details popup, the world map's quest details), not only the skinned
   windows. Two shapes, the owner's choice at stage 2:
   - **a one-shot action** ("Use Blizzard's dark quest text"): sets 4 once; the player changes it back
     in Blizzard's settings like any other value. Nothing to own or restore;
   - **a reversible switch**: on, it sets 4 and remembers the value it replaced; off, it restores that
     value **only if the setting is still 4**. If the player changed it meanwhile (Blizzard's
     settings, another addon), the switch lets go: it turns itself off, restores nothing, and keeps
     the player's newer choice. Saved in `GlassUIDB`; the skins' switches and the master switch don't
     touch the cvar (it's the player's setting, not the skin's look).
   Measured first: `C_CVar.GetCVarInfo("questTextContrast")` (account or character storage, read-only
   or secure flags) and a write with read-back (`SetCVar` reports success).
2. **Our own colours** (`kit:TextColor`): not today's exception, which covers Blizzard's yellow
   titles, not quest text (docs/PLAN.md, "The accent on Blizzard's titles"); a separate audit with
   heavy obligations. Dozens of strings; gossip's theme re-colours every row on every `Update` with
   `SetFixedColor`; QuestInfo's strings are reparented to the popup and the map and would carry our
   colour there; the greeting rows' inline `|cff000000` codes would need `SetFixedColor` (Blizzard's
   own way, `QuestFrame.lua:355-357`) or `SetText`, neither allowed.

Stage 2 gets its own Codex round and the owner's yes before code.

## The probe (`/fp steps skin gossipglass`)

**Measured first, and the implementation follows it** (a `/fp skin` command and the procedure's
first steps):
1. **The portrait:** for both `QuestFrame.PortraitContainer.portrait` and QuestFrame's own ARTWORK
   texture: identity with `_G.QuestFramePortrait`, parent, frame level, rectangle and whether a
   texture is set, after an NPC opens the dialog. The disc goes under the one Blizzard fills: the
   kit's `PortraitDisc` if it's the shell's, `kit:Disc` under the ARTWORK texture (on QuestFrame, at
   its level - 1) if it's QuestFrame's own. Gossip's the same, measured once.
2. Whether Forever's NPCs send gossip texture kits (`GOSSIP_SHOW`'s argument), and the page atlases
   seen.
3. The levels: window, NineSlice, `PortraitContainer`, the buttons, the pages, our glass.
4. The page's alpha across a `SetAtlas`, faded and not.

**Acceptance** (taint log on after the reload, script errors on, blocked actions counted; at the end
the taint log itself is read for our addon):
1. A gossip NPC with options and quests, ideally a long list: the window in glass, the page kept, the
   rows and their hover Blizzard's; scroll into new rows; choose an option; pick a quest.
   Screenshot.
2. The quest dialog through a quest's life **without closing it**: details (with
   `instantQuestText` off: Accept enabled after the text, the rewards fading in, a reward's tooltip),
   accept or decline; progress, incomplete and complete, one with required money if one is at hand
   (enough and not enough); reward (choose one, complete). A greeting NPC with several quests. Each
   panel change: **one** pane at most, the band in place. Closed by X, by Esc and by the buttons.
   Screenshots.
3. **Contrast:** set Dark in Blizzard's settings with the gossip window open: its page goes at once,
   the text light. With a quest panel open: the page and the text stay as they are until Blizzard
   refreshes the panel (the next panel, or a quest log update on the greeting), then both go dark
   together. Back to the default: the pages return, at once for gossip, at the quest dialog's next
   refresh. Contrast 1-3 (lighter parchments, dark text): the page kept. A change while the windows
   are closed, then reopened. The required-money lines recorded as they read in stock Dark
   mode and on glass (if glass makes them worse than stock, the fallback is keeping the page on a
   progress panel that shows them, decided with the owner). Screenshots.
4. An auto-accept quest if one is at hand: Decline hidden (and its glass), the close button disabled
   (our X dimmed). Recorded as unverified otherwise, as the friendship bar, the model portrait and a
   gossip texture kit when none shows up.
5. Each skin off, then on, with its window open; a contrast change while the skin is off; the master
   switch.
6. A `/reload`, then an NPC again; the windows opened and a quest accepted in combat: nothing blocked.
7. The objective tracker's quest details popup and the world map's details: Blizzard's, after the
   quest dialog was skinned.
8. Ask: does it read right?

DialogueUI's instance fallback and the gamepad stand-down: recorded as unverified unless the owner
runs them (no DialogueUI installed, no controller).

## Tests (`tests/test_gossipquest.lua`)

The stub: both frames with the shell, the page regions, the panels, the buttons and their pieces,
`ShowUIPanel`-style deferred shows, the contrast cvar and `CVAR_UPDATE`. Checks:
- each skin at its window's show (a frame later): the shell faded, our glass, band, disc and buttons;
  the page kept and our pane hidden;
- the dark atlas: the page faded, our pane shown; the default atlas back (gossip's theme, live): the
  page at Blizzard's latest alpha (a non-1 alpha survives), the atlas Blizzard's, our pane hidden;
- the quest dialog: the cvar changed with a panel open, no refresh: nothing changes (the page
  follows the atlas, not the cvar); the next panel shows with the dark atlas: faded. Panels in turn
  (greeting, detail, progress, reward) with QuestFrame shown throughout: one pane at most, on the
  shown panel's page;
- **a refresh without an OnShow**, after the cvar's work has drained: the greeting's
  `QUEST_LOG_UPDATE` path (the page's `SetAtlas` alone), both ways (dark to default restores, default
  to dark fades); gossip's background re-set while shown;
- contrast 1, 2 and 3: the page kept; a change while hidden, then the window shown; an NPC kit's
  atlas at contrast 4: kept;
- the setting's event before and after Blizzard's re-set: the same result; work queued, then the
  skin off and on: nothing stale;
- the auto-accept path: Decline hidden takes its glass; the close button disabled dims our X,
  enabled again restores it;
- off and on live, the master switch; a contrast change while off does nothing;
- nothing of ours parented to a scroll child or an item button; no text colour, field, Lua method or
  geometry on Blizzard's objects (`test_contract`, `test_methods`).
Mutation-tested.

## Review

Codex (`gpt-6-astra`, high), round 1: **no consensus**, one BLOCKER and seven SHOULDs/NITs, all
taken:
- BLOCKER: the quest dialog doesn't re-colour an open panel on a contrast change, so the page follows
  the atlas Blizzard shows, not the cvar;
- the four panels' OnShow hooked (a panel changes under a shown window); one pane at most;
- the band at the window's top - 62, not per panel; the buttons' glass as their child;
- the disabled close button mirrored on our X (a kit change);
- the portrait's target decided by the probe's measurement;
- the required-money lines, which stay dark in Blizzard's own Dark mode;
- stage 2's restore: a one-shot action, or a switch that lets go when the player changes the setting;
  its cvar's flags measured;
- `kit:Dim(region, nil)` instead of a new restore; the acceptance cases above.

Round 2: **no consensus**, one BLOCKER and a SHOULD, both taken: the page decided on every `SetAtlas`
of a page (an instance hook that only schedules), since the greeting refreshes on `QUEST_LOG_UPDATE`
without an OnShow; the atlas condition stated one way only; the tests for contrast 1-3, a change
while hidden, a refresh without an OnShow both ways, and an NPC kit at contrast 4.

Round 3: **consensus** (one NIT, the wording above, taken).

## Not in this

- The quest details popup (`QuestLogPopupDetailFrame`): its own issue.
- The rows, the reward and progress item buttons, the model scene, the scroll bars: Blizzard's in
  v1.
- Stage 2 until stage 1 is accepted.
