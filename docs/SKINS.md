# Glass UI's window skins: the inventory

Built on 2026-10-21 from three read-only surveys:
- `wow-ui-source` origin/forever (1.60.1.70450): what loads for the camelot game type, which is in
  the mainline family, `[Family]` = Mainline, `[Game]` = Camelot;
- EllesmereUI's (read at v9.6.1; the passages our docs cite checked against v9.8.6, #183) and ElvUI's
  skins on Forever. These are **behaviour references only**: both write geometry, which our contract
  forbids.

Each window has an issue with its frames, loading, shell, parts, hazards and the references'
warnings. Each skin then gets its own plan (`docs/<WINDOW>.md`, Codex review), tests, mutation
testing and an in-game probe, as in docs/PLAN.md.

**Watch for #109** (the loot window): a fade applied while a `ShowAnim` with `setToFinalAlpha`
plays is undone when it ends. A pass after the animations (`afterAnims`, `Skin/Loot.lua`) fixes it.

## Done

- **merchant**: #3, #4, #80-#86
- **bags**: #88
- **game menu**: #90
- **guild & communities**: #92, plus GuildSpy's tenants
- **character window and its panes**: #94; the reputation, skills and statistics headers
- **world map and quest log**: #99
- **loot window and `/loot`**: #105, #109
- **damage meter**: #49
- **objective tracker**: #55, with the quest timer #73

## Owned by sibling addons (not Glass UI's)

- **GlassMail:** mail.
- **GlassActionBars:** the action, stance, pet and bag bars, and the micro menu.
- **GlassChat:** the chat frames. Whether the channel and chat-settings windows are GlassChat's too
  is #131.
- **GlassMiniMap and GlassMiniMapBar:** the minimap cluster and its buttons.
- **GlassUnitFrames and GlassRaidFrames:** the unit and raid frames.

## To skin

`probe-first` means an in-game check comes before the plan: which window Forever uses, or whether
it can be reached at all.

### NPC interaction

| Issue | Window | Notes |
|---|---|---|
| #113 | Trade (`TradeFrame`) | Built and tested offline (branch `trade-glass`); the in-game probe waits for the beta. The money input is forbidden; the recipient's red is mirrored. |
| #114 | NPC quest dialog (`QuestFrame`) | Accepted on 70938 with #115 (docs/GOSSIP-QUEST.md, `/fp steps skin gossipglass`). The page and text stay Blizzard's unless Blizzard shows its dark page. The quest details popup (`QuestLogPopupDetailFrame`) is its own issue. |
| #115 | Gossip (`GossipFrame`) | Accepted on 70938 with #114, the same file and procedure. |
| #116 | Taxi / flight map | `probe-first`: which one Forever opens. |
| #117 | Bank (character and account) | The use path; `TabContentsChangedAnim` (#109). |
| #118 | Guild bank | `probe-first`: reachability. |
| #119 | Auction house | Commerce paths untouched; uninitialised ScrollBoxes; Auctionator. |
| #120 | Class trainer | Availability colours kept. |
| #121 | Pet stable | Model scene stock. |
| #122 | Tabard, guild registrar, petition, guild rename | Small; one file. |
| #123 | Books and letters (`ItemTextFrame`) | Material backgrounds carry the text. |
| #124 | Transmogrifier | `probe-first`: reachability. |

### The HUD

| Issue | Window | Notes |
|---|---|---|
| #184 | Breath, fatigue and feign death timers (`MirrorTimerContainer`) | Built and tested offline; `/fp steps skin mirrorglass` waits for the owner. An Edit Mode system: size and points never touched. |

### Character and progression

| Issue | Window | Notes |
|---|---|---|
| #125 | Spellbook and talents (`PlayerSpellsFrame`) | **High risk:** casting and talent commits are protected. |
| #126 | Professions | Casting buttons; Skilled; no crafting orders. |
| #127 | Legacy (`LegacySystemFrame`) | Forever-only; the talent tree's taint risk; achievements route here. |
| #128 | Inspect | Mirrors the character window. |
| #129 | Dressing room | Model scene stock. |

### Social and group content

| Issue | Window | Notes |
|---|---|---|
| #130 | Friends or the social window, the raid tab, the ignore list | `probe-first`: which window is live. No size hooks. |
| #131 | Chat channels and chat settings | Decision first: GlassChat's or Glass UI's. |
| #132 | Group finder (`LFGParentFrame`, the Who list) | Group-finder taint; a known tainting scroll bar. |
| #133 | Battleground score (`PVPMatchScoreboard`/`Results`) | `FadeInAnim` (#109). |
| #134 | Battlefield minimap | The canvas is content. |
| #135 | Need/greed rolls, master looter, bonus roll | `StartRollAnim` (#109); the managed container untouched. |
| #144 | Group popups (ready check, role poll, invites, PvP ready, guild invite) | Accept and decline: the mouse stays off. |
| #112 | Guild member details, the note popup, administration | **Deferred** by the owner. |

### Collections, system, settings

| Issue | Window | Notes |
|---|---|---|
| #136 | Collections | Summon on click: the grids stay stock; animations (#109). |
| #137 | Calendar | Custom shell and modal dialogs. |
| #138 | Settings, Quick Keybind | Taint-adjacent controls stay stock. |
| #139 | Addon list | — |
| #140 | Macros | The drag path; the icon grid stays stock. |
| #141 | Click bindings | Decision first: overlaps GlassRaidFrames' click-casting. |
| #142 | Clock and stopwatch | Check GlassMiniMap's clock. |
| #143 | Help and report | An embedded browser: the chrome only. |
| #145 | Stack split, colour picker, opacity | Small. |
| #146 | Player choice | Widget trees off limits (secret values). |

### Shared pieces (every window)

| Issue | Piece | Notes |
|---|---|---|
| #5 | Static popups | Protected confirmations go through them (delete, release, Hardcore); the guild note edit. Draft on branch `popups`. |
| #147 | Tooltips | Secret or forbidden anchors: pcall `GetWidth`. An audited hook. |
| #148 | Dropdown and context menus | Never `AddMenuAcquiredCallback`, never assign into the mixins. An audited exception. |
| #149 | Toasts and alerts | Pooled; secret values; the Battle.net toast. |

## Excluded

- **The store and the secure environment:** `CatalogShopFrame`, `StoreFrame`,
  `WowTokenRedemptionFrame`, `SecureTransferDialog` (`## UseSecureEnvironment: 1`: every frame
  forbidden).
- **Edit Mode** (`EditModeManagerFrame` and its dialogs) and the cooldown viewer's settings (tied to
  Edit Mode; the viewers themselves are #13's chrome).
- **The barber shop** (full screen; it hides UIParent), the splash and subscription screens.

## Not on Forever

- **Excluded for camelot:**
  - the retail group finder: `PVEFrame`, `LFGListFrame`, the Dungeon Finder, `LFGDungeonReadyPopup`;
  - the PvP UI (`PVPUIFrame`): battlemasters queue directly;
  - the Adventure Guide (`EncounterJournal`): standard and classic only;
  - Challenges, the Trading Post (perks program), the expansion trial.
- **Classic-only:** `PVPFrame`, `HonorFrame`, the arena frames, `BattlefieldFrame`,
  `WorldStateScoreFrame` (camelot uses `PVPMatchScoreboard`), the classic `SpellBookFrame` and
  `TalentFrame`.
- **Not on this branch:** `TradeSkillFrame` and `CraftFrame` (professions use `ProfessionsFrame`),
  `WardrobeFrame` (transmog is `TransmogFrame`), `WhoFrame` (the Who list is `LFGWhoListFrame`,
  #132), `ProfessionsBookFrame` (camelot opens `ProfessionsFrame`).
- **Loads but is never shown:** `AchievementFrame` (routed to the Legacy challenges, #127).
- **Loads but is probably unreachable:** item socketing, item upgrade, death recap, the delves
  companion, the bonus roll. Each is checked when its issue comes up.

## Order

Your call. A suggestion, by how often each window shows while playing:
1. trade (#113, in progress);
2. quest dialog (#114) and gossip (#115);
3. the shared pieces: static popups (#5), tooltips (#147), menus (#148);
4. bank (#117), trainer (#120), taxi (#116);
5. then the large and risky ones, each with care: spellbook and talents (#125), professions
   (#126), group finder (#132), auction house (#119).
