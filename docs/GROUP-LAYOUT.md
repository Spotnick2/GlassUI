# Group layout: GRF's continuous grid and GUF beside it (plan)

The suite's second milestone, after the Pearl theme (docs/SUITE.md). The reference is the owner's
`Glass-UI-Group-Layout-Reference` revision 2 (2026-10-18), 12 pages:
- pages 2-6: the geometry;
- page 7: the appearance, today's GRF cells;
- page 8: the layout, Cell in TBC;
- pages 9-12: visual concepts.

The work is in GlassRaidFrames (GRF) and GlassUnitFrames (GUF), one issue each. Glass UI only shows
the state. Nothing here depends on Glass UI.

## What the owner asked for

- **One continuous grid, sized by the group,** with no subgroup labels or boxes and a uniform 6 px
  gap:
  - 2 and 5 players: one row;
  - 10, 20 and 40: 2, 4 and 8 columns of 5.
  - Cells are 96x60, or 80x60 at 40. Names are 15 px and shorten when they need to.
- **Pets:**
  - in a party, a 30-high row under their owners;
  - in a raid, compact 64x28 cells in columns of 10 to the right, with a new column every 10 pets
    and 6 px between columns.
- **Centred:** grid and pets are centred together above the action bars.
- **Heights** (1080 design):
  - the party grid's top is at 800, with the pets under it;
  - the raid grid's top is at 604 and its bottom at the 928 frame limit;
  - player and target are 60 high with their tops at 800, left and right of the footprint, 24
    apart.
- **Cast bars:** two 360x22 cast bars sit above the grid, with their tops at grid top - 84 and - 52.
- **No movement in combat:** the reference says "hold geometry in combat" (what this can mean is in
  section 1).
- **The animation bar:** moves animate at the quality of GUF's combat zoom (owner, 2026-10-18).

**Owner decisions (2026-10-18):**
1. **Every role** gets the continuous shape. The **healer's** default is the centred layout above
   (the "HUD"). Caster, melee and tank keep the grid at the side, because the middle belongs to the
   Cooldown Manager for DPS (GUF #35). A per-role switch turns the HUD on for any role.
2. **GUF owns the link** that places player and target (and their cast bars) beside the grid. It
   listens to GRF directly, so it works without Glass UI. Glass UI's page shows the link's state.
3. **Dragged positions are set aside and kept,** like the look under Pearl. While the layout places
   a frame, its mover says "placed by the group layout". Turning the layout off brings the saved
   positions back exactly.
4. **On for everyone:** existing profiles move to the new layout at their next /reload, with their
   dragged positions set aside.

## Facts this rests on

**GRF today:**
- It has 8 `SecureGroupHeaderTemplate` headers, one per group (`Header.lua:187-210`), in a fixed
  8x5 container.
- The gap is 4 and the cells 82x58.
- A party is a vertical column.
- The raid-pet header has room for 20 pets, in 4 columns of 5.
- `Header.AllChildren()` is the list click-casting walks (`ClickCast.lua:367`).
- `GlassRaidFrames.LayoutChanged` (role, l, b, w, h) announces the full 8x5 rectangle. It never fires
  in combat, and nothing listens to it yet.

**The client's own header code** (`SecureGroupHeaders.lua`, `origin/forever` `172a387`):
- `configureChildren` (`:133-259`) runs on `GROUP_ROSTER_UPDATE` (in combat too) and on attribute
  changes.
  - It anchors child 1 to the header's own `point` (and `columnAnchorPoint`), and every other child
    to the one before it, using the **signed** `xOffset`/`yOffset`.
  - It then resizes the header from child 1's size, without touching the header's own anchor.
  - It calls `ClearAllPoints` only on unused children (`:229`).
- **The columns:** `numColumns = min(ceil(n / unitsPerColumn), maxColumns)` (`:147`).
- **The grouping:** `groupBy = "GROUP"` with a full `groupingOrder` gives one compact list, with no
  gap where a group is missing.
- **Party order:** a party with `showPlayer` lists the player first, then `party1..4`
  (`:278`, `:364`).
- **Header type:** a raid-only header (`showRaid` and not `showParty`) shows nothing in a party.
  Party tokens stay valid in a raid (GRF FOREVER-PROBE `:380`).
- **Pets:** the pet header lists only pets that exist (`:571`).

**What the lockdown forbids:**
- In combat, secure buttons and the frames that parent them can't move, resize or take attributes,
  and such a request is silently refused (GRF `CLAUDE.md:627-632`, GUF `CLAUDE.md:788-793`).
- Both addons draw their visuals on **insecure children** of the secure buttons. Moving or
  re-anchoring those in combat is allowed (porting guide `:579`). GUF's zoom does it to its cast
  hosts (GUF `CLAUDE.md:235-236`).
- State drivers worked on 70425 and threw on 70009 (GRF `CLAUDE.md:606-612`), so re-measure them on
  70450 before relying on one.

**GUF's zoom** (`Zoom.lua`):
- An OnUpdate glide of 0.3 s, cubic ease-out, in UIParent units through the effective scale.
- It works FLIP style: read where the frame is, place it at its destination, read that, put it back
  at the start, then glide.
- Any canonical `Place` cancels the glide and snaps.
- `Castbar.EffectiveGeometry` (`:660`) already lets the zoom override the saved geometry without
  writing it.

## The design

### 1. What "hold geometry in combat" can mean

**Held until combat ends**, everything the addons place:
- the grid's position and cell size;
- its orientation (row or columns);
- GRF's pet placement;
- GUF's player, target and cast-bar places.
Each waits in its addon's one combat queue and is applied, with a glide, on `PLAYER_REGEN_ENABLED`.

**Not held:** the roster's own reflow.
- When someone joins or leaves mid-fight, the client's header re-lays its cells and resizes itself,
  and no addon can stop that.
- Anchored by its bottom centre, the grid stays centred and grows upward. Existing cells can shift
  by half a column.
- The raid-pet header, anchored to the grid, follows. GUF stays put until combat ends.

**Not held either:** GUF's combat zoom.
- It is a feature of its own, which the owner loves.
- It moves the insecure cast hosts to their zoom spots as combat starts, exactly as today, and back
  afterwards (section 4, precedence).

Validation checks exactly this split: nothing of ours moves in combat (the zoom aside), nothing is
blocked, and after combat everything glides once to the new footprint. The owner sees it in game
(M1).

### 2. GRF: one header, a layout by group size

- **The grid header:** one `SecureGroupHeaderTemplate` replaces the eight, with 40 children
  precreated out of combat. Its attribute sets are complete:
  - **Columns** (more than 5 members):
    - `showRaid`, with `showParty` and `showPlayer` kept on, and `showSolo` as the player set it.
      The client checks RAID first (`SecureGroupHeaders.lua:266-272`), so inside a raid they change
      nothing. Without them, a raid that falls back to a party in combat would show no cells at all,
      not even the player, until combat ends (GRF session, 2026-10-18);
    - `groupBy GROUP`, `groupingOrder "1,2,3,4,5,6,7,8"`;
    - `point TOP`, `yOffset -6`, `xOffset 0`;
    - `unitsPerColumn 5`, `maxColumns 8`, `columnAnchorPoint LEFT`, `columnSpacing 6`.
    That makes `ceil(n/5)` columns: 10, 20 and 40 players give 2, 4 and 8, and 11 give 3.
  - **The row** (5 members or fewer, party or raid):
    - `showParty`, `showPlayer`, `showRaid`, and `showSolo` as the player set it. `showRaid` stays on,
      so a party turned raid in combat lists its raid members;
    - `groupBy` and `groupingOrder` cleared. In a party, the client's INDEX order (player, then
      `party1..4`) is what keeps party pets under their owners; in a small raid, raid-index order;
    - `point LEFT`, `xOffset 6`, `yOffset 0`;
    - `unitsPerColumn 5`, `maxColumns 8`, `columnAnchorPoint BOTTOM`, `columnSpacing 6`.
    That makes one row of up to 5. A group that grows past 5 in combat still fits, in rows of 5
    stacked upward, until combat ends and the column set applies. Nothing is truncated.
  - **Which set:** chosen by **member count**, not by raid or party, out of combat. The owner's
    "2 and 5 players: one row" is about head count, and the raid set alone would make a raid of 2-5
    a column. A raid of 5 or fewer gets the row, with its pets in the raid-pet column: the party-pet
    row is for a party only, since a raid's order isn't `party1..4`.
  - **Changing orientation** (out of combat) is one batch, because each attribute change would
    otherwise re-lay the children at once (`SecureGroupHeaders.lua:66-68`):
    1. set the header's `_ignore`, which makes it skip updates;
    2. set the complete new attribute set;
    3. clear every child's anchors;
    4. clear `_ignore`;
    5. refresh once by re-setting one attribute.
    Without the clear, old `TOP` anchors would stay alongside new `LEFT` ones.
- **Cell size by tier:**
  - 96x60 up to 20 members, 80x60 at 21 or more, applied out of combat;
  - a role's saved size is its 96 cell, and the 21+ tier scales its width by 80/96.
- **Pets in a raid:** the raid-pet header is raid-only, so it shows nothing in a party.
  - Its cells are 64x28, `point TOP` with `yOffset -4`, `unitsPerColumn 10`, `maxColumns 4`,
    `columnAnchorPoint LEFT`, `columnSpacing 6`.
  - All 40 pet children are precreated and dressed out of combat (today: 20).
  - It is anchored out of combat to the grid header's right edge, one secure frame to another, 6
    apart, so it follows the grid's own resize in combat (M2).
- **Pets in a party:** five fixed `SecureUnitButtonTemplate` buttons (the player's `pet` and
  `partypet1..4`).
  - Each has `RegisterUnitWatch` and sits under its owner's cell, by the party order the client
    guarantees.
  - They live in one container shown only out of a raid by a secure visibility driver.
    - **M4 (70450, run #238): `[group:raid] hide; show` does not update in combat.** A party
      converted to a raid mid-fight kept the holder shown until combat ended, so the pet showed
      twice: under `raid1`, and in the raid-pet column. Out of combat the condition is right.
    - **The driver is `[@raid1,exists] hide; show`** (measured, GRF run #240, 70450):
      - in a party out of combat, the holder is shown;
      - converted to a raid **in combat**, it hid within 0.3 s, while `[group:raid]` still parsed
        "show";
      - with the other player gone, still in combat (solo), it was shown again;
      - out of combat afterwards, shown. Nothing was blocked.
    - Should it ever stop holding on a later build, the fallback stays: the fixed party-pet set is
      disabled out of combat **in both modes** rather than risk a pet shown twice.
  - **Only with the row.** The holder is used only while the row set is applied, and that is decided
    out of combat. The driver stays the only owner of its visibility: whenever the set changes, GRF
    re-registers it with `"hide"` while the columns are applied, and with the measured party
    condition while the row is applied.
    - A plain `Hide()` would fight the driver, which would show the holder again.
    - So a raid of 6+ that falls back to a party in combat keeps its columns until combat ends,
      without party pets stacking on the column's cells (GRF session, 2026-10-18).
- **The baseline (HUD mode):** one stable point, the reference's 928 frame limit, at 152/1080 of
  UIParent's height above its bottom edge (M3 measures it against the action bars).
  - **Raid:** the grid's bottom is on the baseline, so its top is at baseline + 5 rows.
  - **The row:** the grid's bottom is at baseline + 68 (top at 800), with a party's pet row under
    it. 68 is raw UIParent units, like the cells, for the reference's row top at 800. Only the
    baseline itself is a fraction of UIParent's height.
  - **Centring:** grid and pets are centred together on the whole union (grid, the 6 gap and every
    pet column), recomputed out of combat. The header's anchor is its bottom centre, shifted left by
    half the pet block's width.
  - **One pet column is reserved in a raid** whenever pets are shown, even with no pets yet. The
    union and the announced rectangle always include it.
    - A raid's first pet, or a conversion, can appear in combat, when nothing of ours may move. It
      then lands in space GUF already keeps clear, instead of over GUF's target frame and its debuffs.
      The owner saw that overlap in the M1 run, where nothing was announced.
    - Further columns (more than 10 pets) can still appear in combat. They are reconciled after
      combat.
  - **Side mode:** the same shapes, with the baseline at the role's side position.
- **The mover** moves the baseline, saved per role as `profiles[role].layoutPos`. While the layout
  is on, Reset clears `layoutPos`. `pos`, `petPos` and the legacy geometry stay set aside,
  untouched.
- **Click-casting and hover keys cover the new frames:**
  - `Header.AllChildren()` includes the 40 grid children, the 40 raid-pet children and the 5
    party-pet buttons;
  - `ClickCast.Apply` and the hover-key wrapping run over them out of combat at build, as they do
    today.
- **New settings:**
  - `profiles[role].layout` = `"hud"` | `"side"`, defaulting to `hud` for the healer and `side` for
    the others;
  - `layoutPos`;
  - the global switch `GlassRaidFramesDB.groupLayout`, on by default.
- **The legacy branch is isolated:**
  - the 8 headers, the 4 gap, the 82x58 cells, the 20 pets, `pos` and `petPos` keep their own
    constants and code path;
  - turning the layout off takes effect at the next /reload and gives back exactly today's geometry;
  - today's tests stay as the legacy coverage.

### 3. The announcement, and the state behind it

- **The event:** `GlassRaidFrames.LayoutChanged` keeps (role, l, b, w, h), now the **actual** union
  of grid and pets, and gains three arguments at the end:

  | Argument | What |
  |---|---|
  | `top` | the grid's top edge |
  | `base` | the baseline's y |
  | `mode` | `"hud"`, `"side"` or `"legacy"` |

  Trailing arguments keep fixed-argument listeners working.
- **The state:** GRF also exposes `GlassRaidFrames.LayoutState()`, which returns the same values
  (a fresh table), or nil before it has built.
- **When it fires:** never in combat. Out of combat, after every change: the tier, the size, the
  roster, a move, the role. After combat it reconciles once and announces the complete state.

### 4. GUF: the link

- **The setting:** `GlassUnitFramesDB.groupLink`, on by default.
- **Synchronising** whichever addon loads first:
  - GUF subscribes at file load and keeps the latest valid payload;
  - after its own (possibly deferred) build, it reads `GlassRaidFrames.LayoutState()` under a
    guard, then applies.
  - It also re-applies when its own player or target width changes (a portrait shown or hidden),
    which GRF doesn't announce.
  - With no valid `hud` state it uses its own positions, exactly as today.
- **Placing** (out of combat, through a session-only **link override**, never saved):
  - **the player:** its right edge 24 left of the union's left edge, using its real width (the
    365-unit button with the portrait tile);
  - **the target:** its left edge 24 right of the union's right edge;
  - **their height: unchanged.** The link sets **only the horizontal position**. Each frame keeps
    the height of its own position (its saved one, or GUF's default), as the reference says: "their
    vertical anchors stay fixed".
    - The owner's M5 glide run (70450) showed why: placed at `base + 98`, the player frame dropped
      onto the chat box's tabs. At its own height it stays clear of the chat, even at 40, where it
      moves far left.
    - Party pets and the grid's size therefore never move it vertically either.
  - **the player and target cast bars**, detached, 360x22, centred on the union: centres at
    `top + 73` and `top + 41`.
    - The override goes into `Castbar.EffectiveGeometry`, covering detached state, size, scale and
      position.
    - Precedence: **the combat zoom first** (the owner loves it; it moves only insecure hosts, as
      today), then the link override, then the saves.
    - One controller writes each host: the zoom while zooming, the link glide otherwise.
- **Set aside, and kept intact:**
  - `db.pos` for player and target, and the two cast bars' saves, are never written while linked;
  - `Frames.NormalizeSaves()` skips frames whose positions are set aside, so it never measures a
    linked rectangle;
  - Reset, nudge, Center X and drag are disabled for them, with "placed by the group layout (Glass
    Raid Frames)";
  - unlinking re-applies each frame's **original validated anchor tuple** through a non-saving path,
    then canonical placement.
- **Followers:** pet, target of target and focus ride their leader when they are anchored to it, as
  by default.
  - A follower the owner saved as absolute on UIParent stays where it was saved. That is their own
    choice, and it is documented.
  - `NormalizeSaves()` also skips an absolute follower save while its leader is linked. Otherwise it
    would measure the follower against the linked leader and turn it into a leader-relative save.
- **In combat:** no announcement comes, since GRF holds. A place refused because combat started
  goes through `GlassUF.WhenOutOfCombat`, the one queue.

### 5. The animation (both addons, the zoom's technique)

- **The idea:** a secure frame snaps to its new place, and its **insecure visuals** glide there.
  **Hitboxes snap at once; visuals glide for 0.3 s.**
- **Before** an out-of-combat layout change, each addon reads its visuals' screen positions (in
  UIParent units, through the effective scale, with finite and non-secret checks on coordinates and
  scales):
  - GRF: each cell's `b.body` (power strip, rims and indicators included) and each pet body;
  - GUF: each moving unit's body, portrait tile and cast hosts, and the decorations anchored
    straight to the button: the right-side raid mark (`Frames.lua:450`), the portraitless timer
    (`Timer.lua:122`) and pet happiness (`placeHappiness`, found by the GUF session). Each is
    re-anchored to the visual on its edge (tile or body), keeping its final geometry.
    The followers that ride along are included.
- **Then** it applies the secure layout and reads the new positions on the next frame.
- **Then** it offsets each visual by old minus new, relative to its secure parent, and eases the
  offset to zero (0.3 s, `1 - (1-k)^3`).
- **Interruptions:** another change retargets from the on-screen point, and any canonical place
  snaps. A cell-size change snaps the size and glides the position.
- **No reverse dependency:** no protected frame ever anchors to an animated visual.
- **In combat:** v1 animates only out-of-combat changes. In combat, the header's own reflow snaps
  (section 1).
- **No shared code yet:** each addon keeps its own small `Glide`. A shared copy becomes a LibGlass
  issue once both have proved it.

### 5b. GlassActionBars: the pet and stance bars follow GUF's frames (owner, 2026-10-18)

The owner's hunter glide run (70450) showed Blizzard's pet action bar staying behind while GUF's
player and pet frames slid. GlassActionBars (GAB) skins that bar, and it sat under the frames. The
owner chose to add GAB to this milestone, by the same pattern: the addon that places announces, and
the addon that owns its frame follows. There is no dependency either way.

- **GUF announces its placement.**
  - The event `GlassUnitFrames.LayoutChanged` carries (`linked`, player l, b, w, h, pet l, b, w, h,
    `dx`, `petDx`):
    - `dx` is how far the link moved the **player** frame from its own position, horizontally;
    - `petDx` is how far it moved the **pet** frame: the same as `dx` when the pet rides the player,
      0 when the pet frame is saved absolute.
  - `GlassUF.LayoutState()` returns the same as a fresh table, or nil before GUF has built.
  - It is announced out of combat after every link place or unplace (both 0 when unlinked), never
    in combat, and once after combat if anything changed.
  - These are trailing-argument rules, like GRF's.
- **GAB follows**, horizontally only:
  - the **pet action bar** by `petDx`, from its Edit Mode position;
  - the **stance bar** by `dx`, from its Edit Mode position (the owner, 2026-10-18: it sits by the
    player frame too).
  Each keeps its own height. A bar whose move is 0, or with GUF absent, goes back to its Edit Mode
  position.
  - It acts out of combat, with Edit Mode closed.
  - It never writes the Edit Mode layout: the layout position is the set-aside position. With
    a move of 0, or GUF absent, each bar goes back to it.
- **How GAB moves them is GAB's design.** Both bars are Blizzard Edit Mode systems (`PetActionBar`,
  `StanceBar`), and the porting
  guide calls moving one "a taint minefield" (`PORTING-TBC-TO-FOREVER.md:446-485`). Its measured way
  is the saved base methods, `ClearAllPointsBase`/`SetPointBase`, re-pinned from a deferred
  `ApplySystemAnchor` hook, out of combat, with Edit Mode closed.
  - GAB measures that first (with `taintLog`, and an Edit Mode open and close) before building.
  - If it can't be done cleanly, the fallback is documented, not forced: the bar stays where Edit
    Mode puts it, and GAB says so.
- **The glide:** the bar glides with the zoom's technique (insecure visuals offset to zero) if that
  can be done on the skinned buttons without taint; otherwise it snaps. GAB decides, from its own
  measurement.
- **Glass UI** shows GAB's state in the "Group layout" line, from an optional `Report` field
  `layout = { following }`, if GAB speaks the suite API by then.

### 6. Glass UI

Glass UI only shows the state. Its page gets a "Group layout" line: GRF's mode for the current role,
and whether GUF's link places player and target, from optional `Report` fields. These are additive,
so `Suite.API` stays 1:
- GRF reports `layout = { on, mode }`, what it applied;
- GUF reports `layout = { linked, placing }`.

`Suite.lua`'s report copier gains these two plain fields. The line also has buttons to each addon's
settings.

## To measure first (70450)

- **M1:** the single header in a real party and in a 2-player raid (a party converted to a raid).
  Check the attribute sets, the orientation change with its anchor clear, `ceil(n/5)` columns, the
  bottom-centre anchor, and a roster change in combat that reflows without anything blocked.
- **M2:** the raid-pet header anchored to the grid: does it follow the grid's own resize in combat?
- **M3:** UIParent's size at the owner's scale, and GlassActionBars' top. Does the baseline clear the
  bars? This is only measured; nothing anchors to GlassActionBars.
  - **Run #238:** UIParent is 2133x1200 (scale 0.64). The main bars' top is at 132.6 and the
    baseline at 168.9: 36 clear.
  - **But the pet action bar** (x 641-896, top 253.1) sits 84 above the baseline. A centred grid
    wider than about 340 (5+ columns, a raid of 21 or more) reaches over a hunter's or warlock's pet
    bar.
  - In the HUD that is solved by GlassActionBars#30 (§5b): the pet bar follows the pet frame, which
    sits left of the grid. If #30 has to take its fallback (the bar stays where Edit Mode puts it),
    the overlap stays at 21+, and is documented.
  - The owner judged the party and small-raid cases clear.
- **M4:** the five party-pet buttons, and their visibility driver on 70450. Do they show under their
  owners, and hide in a raid, in combat too?
  - **Run #238:** `[group:raid]` does not update in combat (above).
  - **Run #240:** `[@raid1,exists] hide; show` holds in combat. It is the driver.
- **M5:** the visual glide on a cell and on GUF's frames, out of combat. Does it read like the zoom
  (owner), with nothing blocked?

## Validation

- **Offline:**
  - a harness that runs the client's own `SecureGroupHeaders.lua` layout code (its
    `configureChildren`, with the restricted-environment calls stubbed) against synthetic rosters:
    1-40 members, groups with holes, uneven columns, party/raid round trips, 0-40 pets, and
    precreation, and the `_ignore` batch;
  - plus pure tests of the baseline and centring maths and of GUF's placement and its set-aside
    saves: normalize, reset and unlink restore the exact tuple, including the sequence "absolute
    follower, then link, unlock, unlink".
  - The legacy tests stay.
- **In game:**
  - solo, a real party, and a 2-player raid (a party converted), out of combat and with a roster
    change in combat;
  - load order: GUF before GRF, GRF absent, a reload in combat (deferred builds);
  - layout off with a /reload: today's grid and the saved positions return.
- **Tiers 10, 20 and 40,** which can't be gathered in the beta:
  - a **GRF layout preview** shows insecure mock cells at each tier's geometry, out of combat,
    announces it, and GUF follows; both glide;
  - it ends on its button, on combat start (before the lockdown) and on any real roster change, and
    then announces the real state again, so GUF returns;
  - real large-roster rendering stays marked unmeasured.
- **Readability:** names at 80 wide (shortened), the cast bars clear of the grid, and the zoom still
  working on the linked cast bars.

## Out of scope (v1)

- Animating the roster reflow in combat.
- Anchoring to GlassActionBars.
- A shared Glide in LibGlass.
- Per-frame vertical offsets beyond moving the whole HUD with GRF's mover.
- Moving GUF's frames vertically. If a later layout ever brings frames lower, it first needs an
  agreement with GlassChat, whose chat box sits below them (owner, 2026-10-18).
- Tier layouts for DPS roles beyond the continuous shape at the side.

**Review:** Codex (`gpt-6-astra`, high effort), **consensus in round 3** (2026-10-18). Round 1: It found two BLOCKERs, both
adopted:
- the roster's own reflow, which section 1 now spells out;
- GUF's normalisation overwriting set-aside saves, now skipped, with an exact restore.

It also found eight SHOULDs, all adopted:
- complete attribute sets and `ceil(n/5)`;
- party-pet visibility;
- the baseline, and centring on the whole union;
- the cast-bar override and its precedence: the zoom keeps working;
- initial synchronisation;
- the decorations anchored straight to the button;
- the legacy branch, the reset, and 40 pets;
- a harness on the client's header code.

Round 2 resolved eight and left four small gaps, all adopted:
- `showRaid` in the party set;
- the `_ignore` batch around the anchor clear;
- absolute follower saves skipped by normalisation;
- the party-pet fallback in both modes.

Round 3 found all four resolved and no new defect. It confirmed the batch: clearing `_ignore` never
re-lays the header, and re-setting an attribute to the same value does.

**Amended after the GRF session's reading of the client code (2026-10-18), before building:**
- the column set keeps the party attributes on, so the grid never empties in combat;
- the set is chosen by member count, so a raid of 2-5 is a row;
- the row set clears `groupBy`;
- the party lift is in raw units.
- the party-pet holder is used only with the row: its driver is re-registered as `"hide"` while the
  columns are applied (GRF session, the column-to-party fallback in combat).

**Amended after the owner's M5 glide run (2026-10-18):** GUF's link sets only the horizontal
position, and the height stays the frames' own. Pet happiness joins the decorations re-anchored for
the glide.

**Extended after the owner's hunter glide run (2026-10-18):** GAB's pet action bar follows GUF's
pet frame, horizontally (section 5b). GUF announces its placement for that.
The stance bar follows the player frame too, so the announcement carries both `dx` (player) and
`petDx` (pet).

**After the M1-M4 run (GRF, 70450, run #238):**
- **M1 holds:**
  - the row is 198x60 at baseline + 68, and the columns 96x126 on the baseline, centred;
  - re-setting the same value re-lays the header every time;
  - without the anchor clear, the swap breaks (2x2 instead of 2x1);
  - the in-combat reflow keeps the grid's bottom fixed, with nothing blocked;
  - a stale column anchor on child 1 (the row's LEFT+BOTTOM pair) didn't stretch the cell. The
    columns' TOP+LEFT pair is still unmeasured.
- **M2 holds.**
- **M3** clears the main bars, with the pet-bar catch above.
- **M4:**
  - `[group:raid]` does not update in combat, so `[@raid1,exists]` is measured next;
  - one pet column is reserved in a raid.

**M4, run #240:** `[@raid1,exists] hide; show` holds in combat, and it is the party-pet driver under
the row (with `"hide"` under the columns).
