# Glass UI: the suite orchestrator (v1, the beta's last four days)

## Scope correction (owner, 2026-10-18)

Glass UI is first the **optional orchestrator** of the Glass addons and their suite theme. The skin
work (wave 1) is parked: the merchant is on `main`, the popups on branch `popups` (#5), and both
are to be revisited. Four days of beta access remain, so this is the smallest end-to-end
foundation, validated in the client, with the results recorded so work can go on after beta.

**Who owns what:**
- **LibGlass** owns rendering and the shared material recipes, Pearl included.
- **Glass UI** owns the selected suite theme and which addons follow it (the participation).
- **Each addon** keeps its layout, behaviour, standalone settings and local appearance settings.

**v1 covers two addons:** GlassUnitFrames (GUF) and GlassRaidFrames (GRF). The other Glass addons
are untouched and listed as "not yet integrated".

**Deferred:**
- the preset catalogue, Reflective everywhere, an advanced customisation UI, import/export and
  suite-wide migration;
- a Reflective look for the bars (a new LibGlass recipe; today `Glass.Reflect` is a window layer,
  used only by GRF's click-cast editor);
- layering local appearance settings over the suite theme;
- hosted pages (#20) and moving the click-cast bindings (GUF #116).

**Owner decisions, 2026-10-18:**
- The "Follow Glass UI" switch lives on Glass UI's page; each addon shows only its status.
- Click-casting is a status line plus a button that opens GRF's editor.
- The LibGlass, GUF and GRF work is issues done in those repos' own sessions.
- Recorded in the LibGlass session's plan: while an addon follows, **its own appearance settings
  (look, body, tunables, ramp) are suspended but kept**, and come back unchanged when it stops.
  Layering them over the suite theme is deferred. Font, cast colours and aggro red are not
  appearance in this sense: they stay local.
- **Pearl is each addon's own default look** (owner, later the same day). GUF and GRF offer **Look:
  Pearl (default), Clean, Classic** and, separately as today, **Body: Clear, Smoked**.
  - **Everyone moves to Pearl:** both addons save only what differs from the default, so a
    profile that never chose a look switches to Pearl at its next /reload, and one that saved
    Clean or Classic keeps it. No migration step, no version stamp.
  - This supersedes "preserve existing appearances until the player opts in" for the default
    look only. Following Glass UI stays opt-in, and still suspends the local settings.
  - Reflective for the bars is later (above).

**Review:** Codex (`gpt-6-astra`, high effort), **consensus in round 3** (2026-10-18). Round 1
had one BLOCKER, that following suppresses a local body. It was set aside by the owner's decision
above, and Codex accepted that as consistent. It also had seven SHOULDs and NITs, all adopted:
- failed builds kept apart from pending reloads;
- the namespace guard;
- the LibGlass version recorded at build time, with Glass UI embedding r11;
- the versioning rule;
- the click-cast setting labelled as a setting;
- GUID-scoped probe toggling with a restore step;
- the extra validation cases.

Round 2 added the "asked but never reported" state, and round 3 left two wording nits, both fixed.
The LibGlass session's own review is folded in: `API == 1` exactly, integration meaning a member
that speaks the API, `library-too-old`, every write path suspended, and the readiness fallback.

**Next milestone after this one:** the group layout (owner's reference,
`Glass-UI-Group-Layout-Reference` rev. 2, 2026-10-18). It is one continuous GRF grid sized by group
size (2/5/10/20/40), with GUF's player and target anchored beside its footprint. GRF already
announces its footprint (`GlassRaidFrames.LayoutChanged`: role, left, bottom, w, h). It gets its own
plan.

When the frames move to a new layout, they animate with the same quality as GUF's combat zoom on the
cast bars, which the owner is very pleased with (2026-10-18). The layout holds still in combat (the
reference: "hold geometry in combat").

## Pearl

Pearl is the intended suite default. It is **probe A's glass, the clean look as both addons build
it, with softer highlights**:
- less gloss, frost and wash;
- the same depth (inner shadow, rims, the fill texture with its mask);
- the original class colours.

It is not experiment C (C added B's flat fill and a pearl tint on priest white). The Pearl probe
run #186 (2026-10-18) had the owner preferring C to A, but the owner has since ruled C out.

It is a LibGlass preset: r11 adds `lib:New({ preset = "pearl" })`, plus `"classic"` as an accepted
name. The numbers are tuned in game in LibGlass's probe, under its own issue. Until a tag ships, the
deploy scripts copy the `..\LibGlass` checkout, so the beta runs on it.

**Glass UI embeds the Pearl-capable LibGlass** (r11 or later) in any build that offers the theme. So
whenever an addon can be told to follow, the newest loaded LibGlass knows Pearl.

An addon whose build still fails (an older copy won the LibStub race when it built) falls back to
its local look and reports that, along with the MINOR at the attempt. LibGlass upgrades never
restyle a built instance (`LibGlass.lua:1142`), so there is no retry.

## The contract

### Glass UI (`Suite.lua`, defined at file scope)

```lua
GlassUI.Suite = { API = 1 }
GlassUI.Suite.Ready()               --> bool
GlassUI.Suite.Theme(addon)          --> { name = "pearl", preset = "pearl" } | nil, reason
GlassUI.Suite.Report(addon, state)  --> nothing
GlassUI.Suite.Open()                --> bool   (added within API 1)
```

- **Versioning** (GlassMiniMapBar's rule, `PublicAPI.lua:7`):
  - `API` changes on any incompatible change to a function's arguments or meaning, or a removal;
  - adding a function or an optional field doesn't change it;
  - an unknown field is ignored.
- **`Ready()`** is true once Glass UI's own `ADDON_LOADED` has finished `ensureDefaults()`.
- **`Theme(addon)`**:
  - when `addon` follows, it returns a fresh table every call (never a live one of ours);
  - otherwise it returns `nil` and a reason: `"not-ready"`, `"not-following"` or `"unknown"`
    (not in the roster);
  - it reads only Glass UI's own state and never errors;
  - **it records the answer it gave**, per addon: ready or not, and the preset or the reason.
    That record is the session's truth for the page and for the probe's load-order check, and it
    is kept from before ready onwards.
- **`Report(addon, state)`** is what the addon actually built this session. It may be called again
  (GRF's click-cast setting can change), and only plain values are copied:
  - `api = 1`;
  - `built`: the preset built, or `nil` for the local look;
  - `reason`: why, when it was told Pearl and didn't build it (`"library-too-old"`: the winning
    LibGlass is older than r11; `"build-failed"`: `New` errored);
  - `minor`: LibGlass's MINOR at the build attempt;
  - `options`: a function opening its options, called under `pcall`;
  - GRF only, `clickCast = { open = fn, others = bool }`.
- **Saved:** `GlassUIDB.suite = { theme = "pearl", follow = { [addon] = false } }`. **Every member
  follows by default** (owner, 2026-10-20, #82: "by default, the integration should be activated for
  every addon"), so only an opt-out is saved, as `false`. Saved only when it differs from the
  default (the existing rule). A `true` saved before #82 is the default now and reads the same; any
  other junk value is the default too. Without Glass UI loaded nothing changes: each addon keeps
  its own look.
- **`Open()`** opens Glass UI's settings page and returns true when it did. It never errors. It is
  for an addon's "set in Glass UI" button next to its suspended look controls (the owner, for GRF and
  GUF). It was added after the first version, which is additive, so `API` stays 1. An addon checks
  `type(rawget(Suite, "Open")) == "function"` before showing the button, and calls it under
  `pcall`. It never reaches into `GlassUI.Options`: `Suite` is the contract.
- Glass UI **never reads** another addon's SavedVariables or tables beyond what `Report` handed it,
  and **never writes** to them. It never asks an addon to restyle.

### Each member's state on Glass UI's page

The roster is a constant (docs/PLAN.md, the hub), and it only names the family. **A member is
integrated when it speaks the API**, so the next addon to adopt it needs no Glass UI release. `Theme`
answers any roster member, and anything else gets `"unknown"`. Each member shows the first state
that applies:

| State | When |
|---|---|
| Not installed / disabled / not loaded | `C_AddOns.DoesAddOnExist`, the enable state for this character, `IsAddOnLoaded` |
| Not yet integrated | loaded, and it never called `Theme` or `Report` |
| Started before Glass UI | its `Theme` answer was `"not-ready"`: the load order failed (the probe's S.2) |
| No report | it called `Theme`, and no valid report followed (it failed before reporting) |
| Pearl failed: <reason> | it was told Pearl and reported `built = nil` |
| Following (Pearl) / Own look | it reported, and what it built matches the answer it was given |

Separately, **"Reload to apply"** shows whenever what `Theme(addon)` would answer now differs from
the answer the addon got this session. A failure stays visible alongside it: a reload doesn't hide
a failed build.

### Each addon (GUF and GRF, one issue each)

1. **TOC:** `## OptionalDeps: GlassUI`, so Glass UI loads first when it's enabled.
2. **After Glass UI is ready and before it builds any glass,** at its own `ADDON_LOADED` (with
   `OptionalDeps: GlassUI`) or at `PLAYER_LOGIN` (every `ADDON_LOADED` has run by then, so no TOC
   line is needed: GlassActionBars, docs/SUITE-LOOK.md):
   - `local G = rawget(_G, "GlassUI")`, then require `type(G) == "table"`,
     `type(G.Suite) == "table"`, `G.Suite.API == 1` (exactly, not `>= 1`), and that `Theme` and
     `Report` are functions. Anything else counts as absent: the released Glass UI has no `Suite`
     at all.
   - Then `pcall(G.Suite.Theme, ADDON)`.
   - The decision is made here, once per session. The combat-deferred build uses the instance chosen
     here, so a Follow toggled during the combat wait waits for the reload too.
3. **If the answer has `preset = "pearl"`:**
   - build with `{ preset = "pearl" }` under `pcall`;
   - don't apply its own look, body, tunables or ramp;
   - keep them saved, untouched;
   - apply its font, cast colours and aggro red as usual.

   **The suspension covers every write path**, not only the radios, and each one answers "set in
   Glass UI" instead of writing:
   - GUF: the tunables applied in `ensureDefaults` (`GlassUnitFrames.lua:29`) and the ramp
     (`:669`); `/glass fill|rim|track|fade|edge|ramp|look|body`; the sliders; Reset Look;
   - GRF: `/grf look|body` and its radios.
4. **Otherwise:** the local look, whose default is now Pearl (owner decision above). `LOOKS` gains
   `pearl`, and `UseLook` maps a look name straight to `preset = look` (r11 accepts `"classic"`,
   `"clean"` and `"pearl"`). If the build fails (a winning LibGlass older than r11), the local
   look falls back to Clean and says so; a followed Pearl reports `"library-too-old"` as before.
5. **Report**, under `pcall`.
6. **Its options page and its `/glass look` or `/grf look`:**
   - while following: "Look: following Glass UI (Pearl), set in Glass UI", with the look, body,
     tunable and ramp controls disabled;
   - after a failed build: "own look: <reason>".
   The addon also never reads `GlassUIDB`.
7. **Tests:**
   - Glass UI absent, `Suite` missing or not a table, a wrong `API`, `Theme` throwing, `Theme`
     returning junk, and "not-ready";
   - an old LibGlass without `pearl`, including a newer copy arriving after the build;
   - each must fall back to the local look and never touch the saved appearance keys;
   - following, then not following, restores the local look and its keys after a reload, including
     a saved smoked body and non-default tunables;
   - the default: an empty profile builds Pearl, a saved Clean or Classic keeps it, and the
     Look choice offers Pearl, Clean and Classic.
   Mutation-tested.

### Click-casting (status only)

GRF keeps owning the bindings (`GlassRaidFramesCharDB`, per character and role). Its report adds
`clickCast = { open = fn, others = bool }`, where `others` is **its setting** (`Everywhere()`,
`ClickCast.lua:330`), not proof of coverage.

Glass UI's page shows "Click-casting: Glass Raid Frames; its bindings on other addons' frames:
on/off", and a button that calls `open` (GRF's editor, standalone). Nothing moves; GUF #116 stays
open.

## Glass UI's page

Glass UI gets its first Settings page (`Options.lua`, Blizzard's Settings through
`API.RegisterSettingsPanel`, built at its first `OnShow`). It follows the owner's mockup
(2026-10-18). From top to bottom:
- **The suite preset card:** "Pearl", with an orb of our glass. One choice for now; the field is a
  name, so the catalogue can grow.
- **Addon appearance:** one glass card per member that speaks the API. Each shows the member's
  state ("Glass UI preset: Pearl", "Using addon settings", a failure, "reload to ..."), a "Use Glass
  UI appearance" checkbox (its Follow switch) and a Settings button when it reported one.
- **"Theme sync unavailable (n)":** the rest of the roster, folded, each with its state.
- **Click-casting:** "Managed by Glass Raid Frames", its setting for other addons' frames, and
  "Configure bindings".
- **The footer:** "Appearance changes apply after reloading" (or that changes are waiting), and
  a **Reload UI** button.
  - The button is ForeverProbe's measured secure `/reload` macro button, on a frame parented to
    nothing, positioned over the footer and never anchored to it. Its attributes are set once, out
    of combat, and none of our code runs on its click. A protected frame inside Blizzard's
    Settings panel would make the panel's own show and hide protected in combat.
  - It hides as combat starts and comes back after; in combat the footer says to type `/reload`.

The cards use the Pearl recipe, so the page shows the theme it offers.

`/glassui suite` prints the same, and `/glassui suite follow <addon> on|off` sets the switch.

The skins page and the hub's settings tree (siblings as subcategories) are not part of v1.

## Load order, and what it rests on

- `OptionalDeps` makes the client load Glass UI first when it is enabled. `Ready()` turns true in
  Glass UI's own `ADDON_LOADED`, which is assumed to fire before the next addon's files run.
  **That is not measured on Forever:** S.2 measures it, and it is an acceptance gate. The fallback
  keeps each addon working, but if the load order fails, the orchestration doesn't work. A
  permanent "not ready, so own look" is a bug.

  If S.2 shows `Ready()` false at an addon's `ADDON_LOADED` even with `OptionalDeps`, the addons
  move their one decision to the earliest point measured to be safe. It still comes before any
  surface is built: a preset is never retrofitted onto built surfaces.
- A load-on-demand or late-enabled Glass UI counts as absent for that session.
- Nothing is polled and nothing is applied after the build: one answer per session.

## In-game validation (SkinProbe, `/fp steps skin suite`)

The probe reads only public state:
- `GlassUI.Suite`'s answer record and reports;
- each addon's instance `STYLE` (gloss, frost, wash, innerShadow) and its `look`;
- LibGlass's `MINOR`.

It switches addon combinations itself, for this character only:
- it uses `C_AddOns.EnableAddOn`/`DisableAddOn` with `UnitGUID("player")`, never a name or no
  character (porting guide, `C_AddOns`: a name changes nothing);
- first it saves the three addons' enable states in its own SavedVariables;
- it reads each change back;
- its last step, and `/fp skin suite restore` after an interrupted run, puts the saved states back.

| # | What | Pass |
|---|---|---|
| S.1 | Startup: Glass UI alone, GUF alone, GRF alone, both without Glass UI, Glass UI + GUF, Glass UI + GRF, all three (following off, then on) | without Glass UI, its own look (Pearl by default, or the saved one); with it and following, Pearl in both; no errors; the page's states match |
| S.2 | Load order | every addon's `Theme` answer was given after `Ready()`, in every combination |
| S.3 | With a saved smoked body and non-default GUF tunables: follow on, reload, off, reload | Pearl, then exactly the local look again; its saved keys unchanged |
| S.4 | Live repaint under Pearl: target changes (class and reaction colours), font, cast colours | each repaints live as with the local look |
| S.5 | Gradients | the fill gradient and the health-loss overlay read right under Pearl (screenshots, bright and dark terrain) |
| S.6 | Low health: 30% and 5% on unit frames and raid cells | remaining and missing health clearly told apart (screenshots) |
| S.7 | Combat: follow toggled in combat; a /reload in combat | saved, unchanged this session, applied after the reload; the deferred build still gets the session's answer; no `ADDON_ACTION_BLOCKED`, `scriptErrors 1` clean |
| S.8 | The click-casting line and the Options buttons; GRF's editor under Pearl | they open GRF's editor and each addon's page; the line matches GRF's setting; the editor opens and stays readable on the Pearl instance (its own Reflective treatment stays layered over it, `ClickCastOptions.lua:20, 56`), and its preview health bar inherits Pearl (`:772`) |

The full visual and combat pass (S.4-S.7) runs once, with all three loaded. The results go in
`docs/FOREVER-PROBE.md` with the build. Screenshots are removed with `screenshots.ps1 -Remove`
once written down.

## Issues and order (four days)

1. **LibGlass** (that session): r11, `preset = "pearl"`, tuned in its probe; a tag when accepted.
2. **Glass UI** (this repo):
   - `Suite.lua`, `Options.lua`, `/glassui suite`, the embedded LibGlass at r11;
   - tests: the contract, the states table, the pending/failed split, never reading or writing
     others' SavedVariables;
   - the probe procedure.
3. **GUF**, 4. **GRF:** the per-addon contract above.
5. The in-game run (S.1-S.8), the fixes, the results recorded.

Glass UI's side and LibGlass's preset can go in parallel. The addons need only the contract,
which is fixed here, and their fallback can be tested before Pearl exists.
