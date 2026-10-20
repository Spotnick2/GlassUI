# The suite look: tint and button feedback owned by Glass UI (plan)

Suite theme v1 (docs/SUITE.md) made the **material** suite-wide: Pearl, Clean or Classic, applied at
reload. This plan adds the next layer, the **look**: the glass tint and the button feedback. Glass UI
owns it and it changes live; each addon can override any part of it. GlassActionBars (GAB) is the
first follower. The plan comes from GlassActionBars#39 (sharing GAB's look with Apotheca).

## Owner decisions (2026-10-19)

- **Material:** GAB follows the suite theme like GUF and GRF.
  - GAB speaks `GlassUI.Suite` (Theme/Report) and moves its LibGlass pin from r8 to r11. r9 and r10
    are additive for GAB.
  - **Pearl is GAB's own default.** It was tried first ("Let's try Pearl as GAB's default, we'll
    circle back once I see how it looks"), and kept after the trial: "i'd say I don't see much of a
    difference so yes Pearl can be the default" (owner, 2026-10-19).
  - Its local choice is a new setting, `material` = `pearl` (default) | `clean` | `classic`, applied at
    reload and used only when not following.
  - **When it asks:** at its own `PLAYER_LOGIN`, building its LibGlass instance then rather than at
    file scope. That is a contained refactor: three files capture `GAB.Glass` at load.
    - **Until then, skin requests wait.** A provider can call `SkinButton` after GAB's `ADDON_LOADED`
      and before GAB handles `PLAYER_LOGIN` (another addon's login handler may run first), and
      `Buttons.Build` would then reach `Glass.Apply` with no instance.
    - GAB queues each accepted request, keeping its region snapshot and its owner. It flushes them
      only once it has initialised its DB, frozen participation, chosen the material and created the
      instance, and only out of combat. It re-checks the skin setting at the flush.
    - GAB's TOC names no other addon (its UI contract), so it can't use `OptionalDeps: GlassUI`.
    - By `PLAYER_LOGIN`, every addon's `ADDON_LOADED` has run, Glass UI's included, so `Theme` answers
      ready. SUITE.md's rule is "after Glass UI is ready and before building any glass", which this
      meets.
  - Pearl is clean plus wash 0.10, gloss 0.15, frost 0.06 and rimAlpha 0.6. GAB retextures the rim
    with its own ButtonRim at its own alpha and scales the wash with its tune, so on buttons the
    change may be small. That's for the owner's verdict.
- **The look:** "the suite should have control, and then you can override at addon level". Glass UI
  owns the tint and the button feedback, followers use them, and a key the player sets in an addon
  overrides the suite's for that addon alone. The owner wants to see how it plays on the action bars
  first: GAB is the trial.
- **Apotheca** is a tenant of GAB: it gets the look through GAB's `SkinButton` (Apotheca#68), with
  no Glass UI code of its own. On its own it stays Blizzard's bronze look; Apotheca#41 is parked.
  Glass UI's page says "Apotheca: follows Glass Action Bars".
- **Nothing changes until the player changes it.** The suite look's defaults are GAB's current ones.

This supersedes, for the look layer only, SUITE.md's "layering local appearance settings over the
suite theme is deferred". GUF's and GRF's material rule (suspended, kept, nothing layered) is
unchanged.

## What the look is (GAB's settings today, main 7710d32)

| Key | Values | GAB's default |
|---|---|---|
| `tint` | `clear`, `smoked`, `class` (GAB calls it `theme`) | `clear` |
| `hover` | `off`, `glow`, `halo` | `glow` |
| `press` | `off`, `flash`, `ripple` | `flash` |
| `emptySlots` | `hidden`, `faint`, `half`, `full`, `frosted` | `frosted` |

- **Presets** set the three feedback keys:
  - glass = glow, flash, frosted;
  - soft = halo, ripple, frosted;
  - minimal = off, flash, hidden;
  - "custom" when none matches.
- All of these repaint live in GAB today.
- `emptySlots` only means something to an addon with action slots; the other keys are generic.

## The contract (Glass UI; additive, `Suite.API` stays 1)

- **`Suite.Look()`** returns a fresh `{ tint, hover, press, emptySlots }`. It returns the suite's
  values (its defaults until the player changes them), or nil before Glass UI is ready. It never
  errors.
- **`GlassUI.Suite.LookChanged`**, an `EventRegistry` event with one argument, a fresh copy of the
  same table.
  - It fires when the player changes the suite look, in or out of combat. **Followers must apply it
    combat-safely:**
    - no geometry change (anchor, size, show or hide, attribute) on a protected object or a Blizzard
      region of one;
    - their own unprotected visual regions may change freely (colour, alpha, gradients, show and hide,
      even re-anchoring), as GAB's halo and ripple already do in combat (GAB FOREVER-PROBE).
  - **GAB's change for this:** it splits the pushed texture's setup (Build and after
    `UpdateButtonArt`) from its live alpha update, and drops the unrelated `styleText` call from
    `RefreshFeedback`, so the live path matches the contract.
  - Followers apply the latest values each time; the operation is idempotent.
  - **Every subscriber gets the same table** (EventRegistry forwards the arguments as given, after
    the callback's owner: `function(owner, look)`). The payload is **read-only**: a follower copies
    the fields it knows into its own state, and never keeps or edits the table.
  - **Nothing is replayed** to a follower that registers late. A follower's start is therefore:
    1. freeze participation;
    2. register for `LookChanged`;
    3. pull `Suite.Look()` at once and apply it, before building surfaces.
  - **`Suite.Look` may be absent:** an older API-1 Glass UI lacks it, so followers feature-detect it
    (`type(rawget(Suite, "Look")) == "function"`), and without it they use their own look.
- **The vocabulary is Glass UI's,** taken from GAB's names (`theme` becomes `tint`).
  - A follower ignores a value it doesn't know (from a newer Glass UI) and keeps its own default for
    that key.
  - Adding a value is additive. Renaming or removing one changes `API`.
- **Saved:** `GlassUIDB.suite.look = { [key] = value }`, sparse: only what differs from the
  defaults.
- **Who follows:** an addon follows the look exactly when it follows the suite, through the existing
  "Use Glass UI appearance" switch.
  - That switch is read at the addon's load (`Theme(addon)`), so joining or leaving takes a /reload,
    as for the material.
  - The look **values** then change live.

## Overrides (each follower; GAB first)

- **The effective value of a key:**
  - while following: the addon's own saved value if the player set one (an **override**), else the
    suite's;
  - not following: the addon's own value, else its own default, exactly as today.
- **Overrides live in their own table:** `GlassActionBarsDB.look = { [key] = value }`. It is
  sparse, read with `rawget`, and **never pruned against GAB's defaults**.
  - GAB's `ensureDefaults` drops saved values equal to a default at every load. An override equal to
    GAB's default (say, hover "glow" while the suite says "halo") would otherwise vanish at the next
    /reload, and GAB would follow the suite again.
  - An absent key means the suite's value while following, else GAB's default.
  - **The one-time move** of the existing top-level `theme`, `hover`, `press` and `emptySlots`:
    - it reads the **raw** keys, validated, **before** `ensureDefaults` prunes them and before the
      defaults metatable is attached, so no default gets turned into an override;
    - it fills only keys absent from `look` (an existing `look` entry wins), then deletes the old
      keys, so it is idempotent with no version stamp;
    - a legacy key holding the default value still moves: the player set it, as GAB's setters write
      defaults too until the next prune. That keeps what the player set.
  - **Every look setter writes to `look`** from then on.
  - GAB keeps `theme` as its internal key and maps it to `tint` at the boundary.
- **The addon's settings show the source:**
  - each look control gets a "Glass UI (Smoked)" choice meaning "follow the suite", which clears that
    override, next to the addon's own values;
  - the preset row gets a "Glass UI" choice that clears all three feedback overrides at once, and a
    preset sets the three feedback keys as overrides;
  - the "Glass UI" choices show only while the addon follows the suite; otherwise they mean nothing;
  - **the selection goes by source, not by value:**
    - a control selects "Glass UI" when its override is absent;
    - an explicit override equal to the suite's value still shows as GAB's own;
    - the preset row selects "Glass UI" when the addon follows and all three feedback overrides are
      absent, and otherwise the effective preset's match (or "Custom").
- **Report:** GAB reports `look = { tint, hover, press, emptySlots }` (its effective values), plus
  `own = { [key] = true }` for its overrides. Glass UI's page shows "Glass Action Bars: follows the
  suite look" with the overridden keys named, e.g. "tint: Smoked (its own)".
- **Tenants:** GAB also reports `tenants = { "Apotheca", ... }`, as plain strings. Glass UI shows
  "Apotheca: follows Glass Action Bars".
  - `SkinButton` doesn't know its caller today, so GAB's API v1 gains an optional third argument,
    `SkinButton(button, regions, owner)` (additive).
  - The tenants are the distinct owners of accepted `SkinButton` requests, **only**. A `RegisterBar`
    or `RegisterButton` label names a bar or button, not an addon, and a provider may keep its own
    look (PUBLIC-API.md). Those labels stay in GAB's own provider UI.
  - Apotheca#68 passes "Apotheca".

## Glass UI's page

**Built (GlassUI#44):**
- `Suite.Look`, `SetLook`, `SetLookPreset` and `LookPreset`;
- the `GlassUI.Suite.LookChanged` event through EventRegistry;
- the "Suite look" subpage (radios for the tint, preset, hover, press and empty slots, plus who
  follows), and `/glassui look`;
- the reports' `look`, `own` and `tenants` copied for the page, the GAB card and
  `/glassui suite`.


- **Where:** the suite look gets its own Settings subpage under Glass UI, "Suite look". The main
  page is full.
- **The tint:** a radio, Clear / Smoked / Class.
- **The button feedback:** a preset radio (Glass / Soft / Minimal; "Custom" shown when none
  matches), then hover, press and empty slots each as a radio.
- **Live:** every change saves and fires `LookChanged` at once.
- **The main page's GAB card** says which keys GAB overrides, and the tenants line.
- `/glassui look tint|hover|press|empty <value>` does the same from chat.

Glass UI's own window skins kept their own clear/smoked/class until #67: they now wear the suite
look's tint ("One tint for Glass UI's skins", below).

## Validation

- **Offline:**
  - Glass UI: `Look()`, the event (a fresh table, fired once per change), sparse saving, unknown
    values, the page and the slash command;
  - GAB:
    - the effective value (an override, or the suite's, or its own when not following);
    - an override equal to GAB's default surviving a reload;
    - clearing an override, and the preset's "Glass UI" choice;
    - the one-time move of old saved values;
    - the report, and the tenants from `SkinButton`'s owner;
    - a look change in combat touching no protected anchor;
    - `SkinButton` before GAB's login, and a provider's login handler running first: queued, then
      built with the chosen material;
    - starting after an earlier suite change (pulled, not replayed), and a mutated `Look()` result
      not reaching suite storage;
    - the migration: an empty profile, a legacy non-default, a legacy default, old and new keys in
      conflict, and clearing an override then reloading;
    - the suite absent, an API-1 suite without `Look`, Follow switched either way pending a reload,
      and a combat-deferred build getting the latest look with its original material.
  - Mutation-tested.
- **In game (owner):**
  - GAB on Pearl, following;
  - change the suite tint and feedback live, then override one key in GAB and see the rest still
    follow;
  - stop following and reload: GAB's own look comes back;
  - the Apotheca tenant line (once #68 docks it);
  - nothing blocked when the look is changed in combat, including switching effects while one is
    showing, and the first ripple of the session made in combat.
- **The owner's verdict** on Pearl as GAB's default and on suite control decides what comes next:
  more followers (GUF's and GRF's body/tint) or back to GAB-owned.

## The body (#67) and the accent (#52): addendum, 2026-10-19

**Status:** built (branch `suite-body-build`). GlassChat (GlassChat#121) builds against it once it's merged.

**Why.** GlassChat (its session, for the owner: "try the pearl skin glassui used for the damage meter
and quest tracker ... synced as the glassui sync setting. Same would go for the text colors going
back to original yellow or being set in glassui") wants to wear the glass body Glass UI's skins wear:
- the tint;
- the opaque backing under it;
- the wash.

The owner wants that tuning, backing density included, in one place. Followers must read it, never
copy `Theme.PRESETS`, so it can't drift.

### `Suite.Body(tint)` (additive, `Suite.API` stays 1)

- **Returns** a fresh table for a tint name (`clear`, `smoked`, `class`; nil means the suite look's
  current tint, and is nil before Glass UI is ready, as `Suite.Look`), or nil for a name it doesn't
  know. Every nested table is fresh too, so a follower may keep or change what it gets:
  ```lua
  { tint = { r, g, b, a } or nil, classShade = n or nil,
    backing = { r, g, b, a }, wash = factor }
  ```
  - `tint` is the body's colour. For `class` it's nil and `classShade` is set: the follower
    multiplies its own class colour by it, keeping its surface's **built alpha** (today's Theme:
    `SetSurfaceTint` with three values). The class colour can be unreadable early in a login; the
    follower keeps its built tint until it can read it, and paints again then (Theme's retry at
    PLAYER_ENTERING_WORLD).
  - `backing` is an opaque texture under the tint, clipped by the glass mask (the kit's recipe).
  - `wash` is a factor of the follower's own instance's `STYLE.wash`, never an absolute (#54: Pearl's
    0.10).
- **The numbers move from `Theme.PRESETS` into Suite**, unchanged:
  - clear: tint {0.13, 0.16, 0.22, 0.24}, wash ×1, backing alpha 0.35;
  - smoked: tint {0.05, 0.06, 0.08, 0.62}, wash ×0.14/0.18, backing alpha 0.92;
  - class: classShade 0.6, wash ×1, backing alpha 0.35;
  - backing RGB {0.04, 0.05, 0.07}.

  `Theme` paints from `Suite.Body`, so Glass UI's own skins and every follower share one table.
- **Live:** the body follows the suite look's `tint`, which already fires `LookChanged`. A follower
  calls `Suite.Body(tint)` there with its **effective** tint: the suite's, or its own when it
  overrides that key. No new event.
- **Feature-detected** like `Suite.Look`: `type(rawget(Suite, "Body")) == "function"`. Without it a
  follower uses its own body.
- **Overrides:** a follower may keep a key of its own (GlassChat's `/gchat alpha` over the backing's
  opacity: chat is denser reading). It reports it as `own.backing = true` in its Report.
  - `backing` is **not** a look key (it isn't a choice on the subpage), so it can't ride on
    `LOOK_KEYS`: `copyReport` (Suite.lua:129) copies it separately, and the card's line
    (Options.lua:214) and `LookLine` (Suite.lua:279) add "its own backing" after the look keys.
  - Tested on both displays (the card and `/glassui suite`).

### One tint for Glass UI's skins

Today Glass UI's skins read `GlassUIDB.theme` (`/glassui theme`), and the followers read the suite
look's `tint`: two choices for the same thing. The parked note above ("Glass UI's own window skins
keep their own clear/smoked/class for now") ends here.
- `Theme.Name()` returns the suite look's `tint`.
- `/glassui theme <x>` becomes `/glassui look tint <x>`, kept as an alias.
- **Migration,** in `ensureDefaults` (GlassUI.lua:21) at ADDON_LOADED, before `MarkReady`:
  - a saved `GlassUIDB.theme` that is a valid tint (`Theme.IsValid`) and not the default moves into
    `GlassUIDB.suite.look.tint`, unless a look tint is already saved (read raw: a saved one wins);
  - the other `suite` fields are kept;
  - `theme` is dropped either way.

  A suite Clear chosen explicitly is pruned to absence like the default, so it can't be told from
  never chosen; a saved theme then moves in. The owner is the only user, so this is accepted.
- `LookChanged` repaints the skins (`Theme.Refresh`), so a tint change on the "Suite look" subpage
  shows on the merchant, the meter and the tracker at once.

### The accent (#52)

- **A suite look key, `accent`:** values `"ice"` (Pearl's {0.65, 0.835, 0.905}, GlassChat's today)
  and `"gold"` (Blizzard's {1, 0.82, 0}).
  - It's live, through `LookChanged`, and saved sparse like the other keys.
  - **The default is `gold`:** the owner is unsure about GlassChat's ice blue, and gold is what
    Blizzard's own headers show.
- **`Suite.Accent(name)`** returns a fresh {r, g, b} for an accent name, nil meaning the suite's
  current one (nil before Glass UI is ready), and nil for a name it doesn't know. A follower that
  overrides the key passes its own value, so the colours live only in Glass UI and a follower maps
  nothing. Feature-detected like `Body`.
- **Who uses it:**
  - GlassChat's selected tab;
  - the quest tracker's minimize-button tint (today GQT's cool {0.75, 0.9, 1}), which becomes the
    accent, desaturated as now. Its `LookChanged` subscriber checks `Engine.Active("tracker")`
    first, like every hook, and recolours through `kit:Tint`, which keeps the first snapshot. So any
    number of recolours restores Blizzard's own colour and desaturation, and leaves the current
    atlas.
  - **The damage meter's header titles are not part of this:** colouring Blizzard's text needs
    `SetTextColor`, which the skin contract forbids. That's an owner exception, decided separately.
- The "Suite look" subpage gains an Accent radio (Gold / Ice), and `/glassui look accent gold|ice`.

### Tests

- `Suite.Body` for each name: fresh tables, nested ones included (mutating one leaves the next
  call's untouched), nil for an unknown name, the current tint for nil, nil before ready.
- The class body with the class colour unreadable: the built tint kept, painted at the retry.
- Theme paints the same numbers as before for each tint, under Pearl and clean (test_glass's wash
  cases, unchanged results).
- The migration: a saved `theme = "smoked"` moves once; a saved look tint wins; the default isn't
  saved.
- A `LookChanged` tint change repaints a registered surface. The `theme` command alias works.
- `accent`: the values, `Suite.Accent(name)` (current, a name, unknown, before ready), the default
  gold, saved sparse, the subpage radio.
- The tracker's tint follows the accent live. It doesn't follow while the skin is off, and on again
  uses the current accent. After a handover to GQT, a change touches nothing. After several
  recolours, off restores Blizzard's colour and desaturation, with the current atlas kept.
  - **In combat** (`WoW.combat`): an accent change recolours at once (vertex colour on Blizzard's
    unprotected tracker textures, allowed in combat), nothing is deferred or blocked, and
    test_contract's session includes it.
  - In game: the accent changed on the subpage while fighting, the tracker recoloured, nothing
    blocked (an acceptance step).
- `own.backing` on the card and in `/glassui suite`.
- Mutation-checked.

**Review of the addendum:** Codex (`gpt-6-astra`, high effort), **consensus in round 3**
(2026-10-19). Round 1 found no blocker; three SHOULDs and two NITs, all adopted:
- `Accent(name)` for a follower's override;
- `own.backing` copied and shown apart from `LOOK_KEYS`;
- the tracker's accent path through off, handover and repeated recolours;
- `Body`'s fresh nested tables, readiness and class alpha;
- the migration's placement.

Round 2 left the tracker's accent change in combat untested; round 3 found it resolved.

## Issues

- **Glass UI:** the contract, the subpage and the page lines.
- **GAB** (with GAB#39): follow the material (Pearl default, r11, asked at `PLAYER_LOGIN`) and the
  look (the override table, the report, `SkinButton`'s owner argument, a combat-safe refresh).
- **Apotheca#68:** nothing new; its SkinButton asks stay between GAB and Apotheca.

**Review:** Codex (`gpt-6-astra`, high effort), **consensus in round 2** (2026-10-19). Round 1: One BLOCKER and three SHOULDs,
all adopted:
- `SkinButton` queued until GAB has initialised (the BLOCKER);
- the start sequence and the read-only shared payload;
- the migration from raw keys before the prune;
- tenants only from `SkinButton` owners.
Two NITs, also adopted: the preset selection by source, and the combat wording.

Round 2 found all six resolved and no new defect.
