# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Glass UI reskins **World of Warcraft: Forever 1.60.1**'s Blizzard windows in liquid glass
(Interface `16001`, **Lua 5.1**), and is an optional hub for the other Glass addons. It has a single
owner (Spotnick) and uses the same stack and conventions as the sibling Forever addons:
`..\GlassQuestTracker` (the closest template: the in-place restyle rule, Compat, tests, tools),
`..\GlassMail` (a window skin, tooling, CI) and `..\LibGlass` (the material, embedded). When this
file doesn't cover something, check how those handle it before you invent a new idiom.

**The plan** is [docs/PLAN.md](docs/PLAN.md) (Codex `gpt-6-astra`, consensus in round 3,
2026-10-15). Measured client facts go in [docs/FOREVER-PROBE.md](docs/FOREVER-PROBE.md).

**Owner decisions (2026-10-15):**
- **No monolith.** Every Glass addon works without Glass UI, and Glass UI works without any of them.
  No `## Dependencies:` between Glass addons, ever: `OptionalDeps` only.
- **Look only, never behaviour.** A skin changes how a window looks, never what it does. An
  improvement is a separate addon that then **owns** the window, and Glass UI steps aside.
- **Every skin can be turned off**, one switch per window plus a master switch.
- **`## Category: |cff7fd4ffGlass|r`** in every Glass addon's TOC (the AddOn list header), never a
  `Group` under Glass UI: GlassPanel's plugins already group under GlassPanel.
- `/glassui` and `/gui` (`/glass` is GlassUnitFrames'). v0.1.0 = wave 1 + hub v1; 1.0.0 at Forever's
  launch. Private repo for now; CurseForge project 1745875.

**Status (2026-10-19):** Glass UI is first the **suite orchestrator**. Done on 70450:
- **suite theme v1** (#24): Pearl, with GlassUnitFrames and GlassRaidFrames following it,
  [docs/SUITE.md](docs/SUITE.md);
- **the group layout** (#28): GRF's continuous grid sized by the group, GUF's player and target
  beside it, GAB's pet and stance bars following, all with the zoom's glide.
  [docs/GROUP-LAYOUT.md](docs/GROUP-LAYOUT.md) records what was measured and what wasn't.

The settings page shows both. The skins are parked: the engine, kit, theme and merchant (#3, #4) are
on `main`, the popups (#5) on branch `popups`, all to be revisited. Measured on 1.60.1.70450.

## The skin contract (non-negotiable)

**Restyle in place; never replace, move, resize or drive a Blizzard window.** The full rule, the
audited exceptions and the reasons are in docs/PLAN.md, "The skin contract". In short:
- **Allowed on Blizzard objects:** `SetAlpha`, `SetVertexColor`, `SetDesaturated`,
  `SetShadowOffset`/`SetShadowColor`, `SetTexture(nil)` and restoring the value we captured,
  getters, `HookScript`, `hooksecurefunc` on a specific instance.
- **Never:** `Show`/`Hide`/`SetShown`/`SetPoint`/`SetParent`/`SetSize`/`SetScale`/`SetText`/
  `SetFont*`/`SetTextColor`, mixin methods, `UIFrameFade*`, field writes on Blizzard tables,
  reassigning a Blizzard global, opening or closing Blizzard windows from our code.
- Art is found by structure, never by texture path (`GetTexture` returns file IDs here).
- Our glass is our own unnamed frame. Our state lives in our own weak tables. Text keeps
  Blizzard's fonts and colours.
- **Every callback checks `Engine.Active(key)` first:** hooks can't be removed.

## Layout

| File | What |
|---|---|
| `Compat.lua` | `API.*`: failures, events, version, `IsSecret`/`Plain`, `CVarBool`, `ClassColor`, Settings registration |
| `Glass.lua` | our LibGlass instance (`preset = "clean"`) |
| `Theme.lua` | clear / smoked / class: tint, wash (`SetWash`) and the opaque backing, repainted live |
| `Skin\Engine.lua` | `Register`, `Active`, owners/yields/handover, the switches, deferral and the combat wait, gamepad and suite stand-downs, `Status` |
| `Skin\Kit.lua` | per-skin touches (`Fade` with read-back, `Blank`/`Tint`/`Shade` for `live = false`), `Panel`, widget kinds (`Shell`, `Inset`, `Tab`) |
| `Skin\Merchant.lua` | the merchant window (live) |
| `Suite.lua` | the suite contract (docs/SUITE.md): `GlassUI.Suite` (`API`, `Ready`, `Theme`, `Report`), the roster, the follow switches, each member's state |
| `Options.lua` | the settings page: the suite theme, the family and its Follow switches, click-casting |
| `GlassUI.lua` | bootstrap, `GlassUIDB`, `/glassui` |

Planned, per docs/PLAN.md: `Skin\<Window>.lua` for the rest, `Hub.lua`.
`Tools\SkinProbe\` is the ForeverProbe module (never shipped): `/fp skin`, the measurements
`/fp steps skin wave1|map|gradient`, each skin's acceptance (`/fp steps skin merchant`) and the
suite's (`/fp steps skin suite`, #24);
docs/FOREVER-PROBE.md says how to run it.

## References

- `..\References\Docs\PORTING-TBC-TO-FOREVER.md`: Edit Mode systems, secure code, secret values,
  options-page recipe, packaging.
- `..\References\Forever\api\forever-api-1.60.1.70450.md`: does an API exist? Presence is not a contract.
- `..\wow-ui-source` (branch `forever`; 70450 is on `origin/forever`, the checkout may lag): the client's own FrameXML. The authority on frame
  names, templates and `[AllowLoadGameType camelot]` variants.
- `..\References\Docs\RELEASING.md`, `..\References\Docs\LIBGLASS-MIGRATION.md`, `..\References\Docs\EMBEDDED-LIBRARIES.md`,
  `..\References\Docs\PROBES.md` and `..\ForeverProbe\docs\GUIDE.md` (probes).
- `..\References\Addons\UISuites\EllesmereUI\EllesmereUIBlizzardSkin`, `..\References\Addons\UISuites\ElvUI`: how two
  suites skin these windows on Forever, and what they found broken. Behaviour references only.
- `..\LibGlass\docs\GLASS-MATERIAL.md`: the material and its region fields.

## Toolchain and commands

Lua 5.1 at `C:\Program Files (x86)\Lua\5.1\` (`lua.exe`, `luac.exe`). No build step.

```powershell
pwsh tests\run.ps1                                                   # luac -p on the TOC files (+ probe), then every tests\test_*.lua (needs ..\LibGlass and ..\ForeverProbe, or $env:LIBGLASS / $env:FOREVERPROBE)
& 'C:\Program Files (x86)\Lua\5.1\lua.exe' tests\test_boot.lua      # one test, from the repo root
pwsh Tools\deploy.ps1                                                # copy the addon into AddOns
pwsh Tools\deploy.ps1 -Probe                                         # ...plus ForeverProbe and SkinProbe
```

- Default AddOns path: `C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns`.
- In game: `/console scriptErrors 1`, `/console taintLog 1`, then `/reload`.
- **Shell heredocs here collapse `\\` to `\`** (and `\n` escapes): write files that contain Lua
  escapes or Windows paths with the Write/Edit tools.

## Testing

Glass Quest Tracker's harness: `tests\wow_stubs.lua` (strict globals as an allowlist of APIs verified
in the dump, event names validated against the dump, every widget method recorded),
`tests\harness.lua` (`check`, `eq`, `near`, `loadAddon`), `test_methods.lua` (every method called
exists on this client). The contract test arrives with the engine (#3). **Mutation-test every new
test.** Offline tests can't cover taint, rendering or the live client: that's the probe and each
skin's in-game acceptance. **`test_probe` runs locally only:** ForeverProbe is private, so CI sets
`FOREVERPROBE_OPTIONAL=1` and it skips there (ForeverProbe GUIDE section 8). Run
`tests\run.ps1` before every PR that touches the probe.

## Workflow and releasing

- Issue → branch off `main` → PR with `Closes #N`. Never commit to `main`; commit or push only
  when asked. `luac -p` clean and tests green before committing.
- **The owner merges and closes PRs and launches reviews.**
- **Plans** get an adversarial review before coding: Codex via the `codex-consult` skill,
  `-m gpt-6-astra` at high effort, looping until consensus, without overengineering.
- **Sibling repos are never edited from this session.** The hub pilot's changes to GlassUnitFrames
  and GlassActionBars are issues and PRs in those repos.
- Releases: `..\References\Docs\RELEASING.md`.

## Conventions

- Comments explain why, in the siblings' plain style. Name the measured build when a fact was
  measured.
- `GlassUI.failures` is the one failure record (`API.Fail`, `API.Try`); `/glassui failures` reads it.
- `GlassUIDB` saves only what differs from `DEFAULTS`.
