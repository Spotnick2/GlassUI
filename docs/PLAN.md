# Glass UI: plan (v0.1.0 and the waves after it)

> **Scope correction (owner, 2026-10-18):** Glass UI is first the suite orchestrator:
> [docs/SUITE.md](SUITE.md). The skins below are parked (merchant on `main`, popups on branch
> `popups`) and will be revisited.

## Context
WoW: Forever 1.60.1 (Interface 16001, Lua 5.1) is Vanilla content on the Retail (Mainline) client.
The owner has a family of independent Glass addons (GlassActionBars, GlassChat, GlassMail,
GlassMiniMap, GlassMiniMapBar, GlassPanel, GlassQuestTracker, GlassRaidFrames, GlassUnitFrames),
each its own repo and release, all embedding LibGlass-1.0. `C:\Projects\WoW\GlassUI` is empty.

Glass UI is two things:
1. **The skin.** It reskins the rest of Blizzard's UI with LibGlass: tooltips, popups, menus and
   windows. This is the bulk of the work and of the maintenance.
2. **A light, optional hub** over the other Glass addons. It holds one settings tree and a page
   listing the family. It never owns another addon's data.

**Owner decisions (2026-10-15):**
- **No monolith.** The owner has seen ElvUI take people's UI down on patch day, and builds their own
  UI from separate addons (Titan Panel, Prat...). Every Glass addon keeps working without Glass UI,
  and Glass UI works without any of them. No `## Dependencies:` between Glass addons, ever.
- **The skin lives inside Glass UI.** Codex argued for a separate `GlassBlizzardSkin` addon; the
  owner chose one addon. Skins share a lifecycle (patch days, one LibGlass instance, one release),
  and each one is still isolated: a file per window, its own toggle, its own error boundary.
- **Look only, never behaviour.** Glass UI changes how a window looks, never what it does. An
  improvement (a better world map, a better damage meter) is a separate addon, which then **owns**
  that window: Glass UI steps aside (the handover, below). The world map is the pilot: Leatrix
  Maps today, Glass Maps planned.
- **Every skin can be turned off**, one switch per window plus a master switch.
- **LibGlass is embedded** like in every sibling: `.pkgmeta` external pinned to a tag, loaded first.
- **The skin list** (owner, 2026-10-15): tooltips, static popups, menus, the Escape menu, the
  character sheet, the world map, the bag windows, the spellbook, talents, professions, the merchant,
  the auction house, the guild and friends UI, the group finder, the damage meter, the cooldown
  manager, and Forever's Legacy window (its talent tree, challenges and reward track). Mail, chat,
  the minimap, the quest tracker, the action/bag/micro bars and the unit and
  raid frames already belong to sibling addons.
- **Private GitHub repo** (`Spotnick2/GlassUI`) for now, with issues and PRs; only the owner merges.
- **CurseForge:** project id `1745875`, https://www.curseforge.com/wow/addons/glass-ui.

**Workflow:**
- Issue → branch off `main` → PR with `Closes #N`. The owner merges, closes and launches reviews.
  Commit and push only when asked.
- Adversarial review with Codex (`codex-consult`, `gpt-6-astra`, high effort): **consensus in round
  3** (2026-10-15). Round 1 had 2 BLOCKERs (restore vs the allowed methods; callback lifecycle) and 5
  SHOULDs (one-shot styling, menu/tooltip hooks, Leatrix timing, acceptance gating, the contract
  test), all accepted. Round 2 left three gaps (shadow restore, a late owner, dedup across passes),
  closed with the smallest option each. It found nothing wrong with the AddOn-list category or the
  settings tree, and judged the engine not overengineered.

**Non-goals** (each one is a separate decision later, not a "phase 2" of this addon):
- Any behaviour change to a Blizzard window: no auto-sell, no bag sorting, no new map pins.
- A custom options window (Ellesmere's is about 150k lines). Glass UI uses Blizzard's Settings.
  Hosting the other addons' own pages in one window is a different thing (Hub, hosted pages).
- Suite-wide profiles and import/export. Deferred until the adapter boundaries hold (Hub, later).
- A shared mover engine. GlassUnitFrames' and GlassRaidFrames' movers solve different problems.
- Nameplates, a bag replacement, a damage meter of our own, buff reminders, QoL automation.
- Localization, pixel-perfect UI scale.
- Skinning other authors' addons (a skin API for third parties).

## Ground truth (wow-ui-source `forever` @70374, API dump 70374)
Forever's game type is `camelot`, which also counts as `mainline`. The `[AllowLoadGameType camelot]`
lines in each TOC are the authoritative list of Forever-only variants (FV below).

| Target | Frame(s) | Addon / loading | Shell template | Risk and notes |
|---|---|---|---|---|
| Static popups | `StaticPopup1..4` | always | `DefaultDialogPanelTemplate`, `BG.Top`/`BG.Bottom` atlases, no NineSlice | `.Text` (`.text` is nil), `.ButtonContainer.Buttons[n]`, `.EditBox`, `.MoneyInputFrame`, `.ItemFrame` (`GameDialog.xml:51-338`) |
| Merchant | `MerchantFrame` | always | `ButtonFrameTemplate` | plain; the kit's window-shell pilot |
| Character sheet | `CharacterFrame` + `PaperDollFrame`, `ReputationFrame`, `SkillsFrame`, `PVPRankFrame`, `TokenFrame`, `StatisticsFrame` | always; Blizzard_TokenUI, Blizzard_Statistics (Forever only) | FV `PortraitFrameBaseTemplate`, six `LargeSideTabButtonTemplate` side tabs (`Camelot\CharacterFrame.xml:403, 574-599`) | every pane is FV |
| World map | `WorldMapFrame`, `QuestMapFrame` | Blizzard_WorldMap, always | `WorldMapFrameTemplate`, `frameBuffer="true"` | Leatrix Maps rebuilds the border (below); the frame buffer may flatten a child panel (probe) |
| Bags | `ContainerFrame1..N`, `ContainerFrameCombinedBags` | always | `PortraitFrameFlatTemplate` | opened in combat, so first pass may wait; item buttons are on the use path: alpha only |
| Tooltips | `GameTooltip`, `ShoppingTooltip1/2`, `ItemRefTooltip`, `EmbeddedItemTooltip` | always | `SharedTooltipTemplate` + `.NineSlice` | hook `SharedTooltip_SetBackdropStyle`, deferred a frame (it fires from secure code); `GameTooltip.StatusBar` is secure and secret: fade only; skip embedded tooltips; no `OnTooltipSetItem` (porting guide :488, :862) |
| Menus | `Menu.GetManager()` menus | Blizzard_Menu (FV `Camelot\Menu.xml`) | `MenuStyle1Mixin`/`MenuStyle2Mixin` | **never `AddMenuAcquiredCallback`** (Ellesmere: a tainted Whisper entry broke chat, `EllesmereUIBlizzardSkin.lua:1387-1418`); hook `OpenMenu`/`OpenContextMenu` and the style mixins' `Generate` (flyouts), defer; no `CreateTexture` while a menu is open (`:1428`), and menus are reused (`:1359`): **a glass panel on a menu is unproven**, so the fallback is tint-only |
| Escape menu | `GameMenuFrame` | Blizzard_GameMenu, always | `MainMenuFrameTemplate`, buttons from a pool | the Esc path is taint-sensitive (porting guide :1536): taint pass |
| Auction house | `AuctionHouseFrame` | Blizzard_AuctionHouseUI, LoD | `PortraitFrameTemplate` | Auctionator adds tabs |
| Professions | `ProfessionsFrame`, `ProfessionsBookFrame` | Blizzard_Professions, Blizzard_ProfessionsBook, LoD | FV `ProfessionsFrameBase` (side tab, right tabs 1-7); `ButtonFrameTemplate` | recipe rows are protected (Ellesmere WindowPacks:1895); Skilled hooks it |
| Group finder | `LFGParentFrame` | Blizzard_GroupFinder_VanillaStyle, LoD | custom, side tabs | retail `PVEFrame` is excluded on Forever (`Blizzard_GroupFinder.toc:10`) |
| Spellbook + talents | `PlayerSpellsFrame` (`SpellBookFrame`, `TalentsFrame`, `SpecFrame` inside) | Blizzard_PlayerSpells, LoD | FV `PortraitFrameTemplate, TabSystemOwnerTemplate` | spell items call protected `CastSpellBookItem` (`Blizzard_SpellBookItem.lua:610`): alpha only, nothing on the click path; taint pass |
| Legacy (talent tree, challenges, reward track) | `LegacySystemFrame` (`TreePage.LegacyTreeTraitPanel`, challenges page, reward track page) | Blizzard_LegacySystem, LoD, **Forever only** | `PortraitFrameTemplate`, `LargeSideTabButtonTemplate` side tabs | the tree is a `Blizzard_SharedTalentUI` trait panel with pooled talent buttons (`Blizzard_LegacySystem.lua:30-40`): alpha only on the buttons, nothing on the learn path; taint pass |
| Guild | `CommunitiesFrame` | Blizzard_Communities, always (FV overrides) | `ButtonFrameTemplateMinimizable` | never hook the roster's ColumnDisplay or move rows (Ellesmere WindowPacks:3189-3202); taint pass |
| Friends | `FriendsFrame` (FV), or `SocialUIFrame` when `SocialUIControl.IsEnabled()` | always | `ButtonFrameTemplate`, TabSystem header, `PanelTabButtonTemplate` | both must be skinned (`Camelot\FriendsFrame.lua:1262`) |
| Damage meter | `DamageMeter` + session/source windows | Blizzard_DamageMeter (`standard, camelot`) | `EditModeDamageMeterSystemTemplate` | an Edit Mode system with secret values: chrome only |
| Cooldown manager | `EssentialCooldownViewer`, `UtilityCooldownViewer`, `BuffIconCooldownViewer`, `BuffBarCooldownViewer` | Blizzard_CooldownViewer (`standard, camelot`) | `CooldownViewerTemplate`, `BottomManagedFrameTemplate` | managed frames with secret cooldown data: icon borders and bar chrome only |

**Client-wide hazards** (each confirmed in source or by a reference addon):
- The UIParent panel manager's position delegate is forbidden: never move or hide a UI panel.
- ScrollBox windows: never force their first layout from our load pass; skin on the first `OnShow`
  (Ellesmere WindowPacks:11993).
- UI widget trees hold secret values: leave them alone.
- **Gamepad interface style:** hooks on Blizzard windows taint its secure navigation and can loop
  until the client freezes. Ellesmere stands every skin down for the session in that mode
  (`EllesmereUIBlizzardSkin.lua:93-104`). Glass UI does the same.
- Chat bubbles are forbidden in instances (not in scope anyway).

**Who already owns what** (Glass UI skips these whenever the owner is loaded):

| Blizzard UI | Owner |
|---|---|
| MailFrame, OpenMailFrame, SendMail | GlassMail |
| Action, stance and pet buttons; BagsBar and bag slots; MicroMenu | GlassActionBars |
| Chat frames, edit boxes, chat tabs | GlassChat |
| ObjectiveTrackerFrame | GlassQuestTracker |
| Minimap cluster, zone text, tracking, clock, mail indicator | GlassMiniMap |
| Minimap buttons, AddonCompartmentFrame | GlassMiniMapBar |
| Player/target/party/raid frames (hidden, not skinned) | GlassUnitFrames, GlassRaidFrames |

**Third-party addons that change the same windows** (installed on the owner's client):
- **Leatrix Maps 1.60.23** (Forever-native). Its "Simple map frame" fades or hides
  `WorldMapFrame.BorderFrame`'s regions and children, builds its own NineSlice border, resizes and
  re-icons the close and maximise buttons, and moves the title (`Leatrix_Maps.lua:84-330`), all in
  its own `PLAYER_LOGIN` handler (`:2956`). It already special-cases ElvUI (`:37`).
  - The option is read once at its `ADDON_LOADED` with **default On** (`:2887`); a change mid-session
    only takes effect after a reload, and `LeaMapsDB` is written back at logout (`:2962`). So
    `LeaMapsDB.SimpleMapFrame ~= "Off"`, read at our login, is the effective mode for the session.
  - **v0.1: the world map skin skips while Leatrix Maps' simple frame is on** (its default), and
    says so on the toggle. With it off, the stock frame is skinned normally, styled at the map's
    first `OnShow`, after Leatrix's login handler. A reduced variant over Leatrix's frame is left to
    Glass Maps.
- **Auctionator** adds tabs and panels to the auction house. **Skilled** hooks the profession window.
- **ElvUI, EllesmereUI, Tukui:** each has its own skins of the same windows. If one is loaded, Glass
  UI turns off every skin it overlaps and says so once.

## The skin contract (non-negotiable; GlassQuestTracker's rule, generalised)
**Restyle in place; never replace, move, resize or drive a Blizzard window.**

**Only C widget methods on Blizzard objects:**
- **Allowed:** `SetAlpha`, `SetVertexColor`, `SetDesaturated`, `SetShadowOffset`/`SetShadowColor`,
  `SetTexture(nil)` (blanking animated art that a fade can't hold) and restoring **the value we
  captured** with `SetTexture(id)`/`SetAtlas(name)`, getters, `HookScript`, `hooksecurefunc` on a
  **specific instance**.
- **Audited exceptions** (each named in the skin file, with the reason): global or mixin-table
  post-hooks that a target can't be reached without: `SharedTooltip_SetBackdropStyle` (tooltips),
  `MenuStyle1Mixin.Generate`/`MenuStyle2Mixin.Generate` (submenus: `GetOpenMenu()` returns only the
  root, `Blizzard_Menu\Menu.lua:1952`). Inside them we only **collect and schedule**: the styling
  runs a frame later.
- **Never:** `Show`/`Hide`/`SetShown`/`SetPoint`/`SetParent`/`SetSize`/`SetScale`/`SetText`/
  `SetFont*`/`SetTextColor`, mixin methods, `UIFrameFade*`, field writes on Blizzard tables,
  reassigning a Blizzard global or method, opening or closing Blizzard windows from our code.
- **Found by structure, never by texture path** (`GetTexture` returns file IDs here, GlassMail
  `Skin.lua:140`).
- **Our glass is our own unnamed frame**, a child one level under the window (GlassMail's panel),
  or a sibling when the window flattens render layers (GlassActionBars' MicroMenu). Mouse off.
- **Text keeps Blizzard's fonts and colours** (quality and difficulty colours carry information).
  We add shadows only.
- **Our state lives in our own weak tables**, keyed by the Blizzard object.
- **Protected windows** (marked in the table): the first pass waits for
  `PLAYER_REGEN_ENABLED` if the window first appears in combat. Hooks never run our code inside a
  secure call path when it can be deferred one frame (`C_Timer.After(0)`, the porting guide's
  Edit Mode rule).

## Architecture

### File layout (TOC order)
```
Libs\LibGlass-1.0\LibGlass-1.0.xml   (.pkgmeta external, tag r11)
Compat.lua        API.*: Fail/Try, RegisterEvents, IsSecret/Plain, ClassColor, CVarBool,
                  WhenOutOfCombat, Settings helpers (GlassQuestTracker's, plus GUF's whenOutOfCombat)
Glass.lua         our LibGlass instance, preset "clean"
Theme.lua         clear / smoked / class, Refresh, OnChange (GlassMiniMap's)
Skin\Engine.lua   the registry, loading, owners, conflicts, errors, toggles
Skin\Kit.lua      the touch helpers: Fade/Blank/Tint/Shade + their restores, Panel, the widget kinds
Skin\<Window>.lua one file per skin
Hub.lua           the settings tree, the family list, the adapter registry
Options.lua       the settings pages
GlassUI.lua       bootstrap, GlassUIDB, /glassui
```

### The skin engine (`Skin\Engine.lua`)
Each skin file registers one table:

```lua
Engine.Register({
    key     = "merchant",              -- saved toggle key, stable forever
    title   = "Merchant",
    addon   = nil,                      -- or "Blizzard_AuctionHouseUI": wait for it to load
    owners  = nil,                      -- or { "GlassMail" }: step aside when one is loaded
    yields  = nil,                      -- or { Leatrix_Maps = function() return ... end }
    risk    = "plain",                  -- or "protected": first pass out of combat, taint gate
    frames  = function() return MerchantFrame end,
    install = function(kit, frame) ... end,  -- once: our panels and our hooks
    style   = function(kit, frame) ... end,  -- repeatable: the touches, for shell and contents
    live    = true,                     -- false: turning it off needs a /reload
})
```

- **Install once, style often.** `install` builds our panels and installs hooks, once per session.
  `style` is the repeatable pass; the skin's hooks call it again when Blizzard creates or reuses
  content (a ScrollBox row, a reused menu, the Reputation pane's new data provider,
  `Camelot\ReputationFrame.lua:31,209`). Each skin's file says whether it covers only the shell or
  also pooled contents, and which narrow hooks re-style the contents. **Only installation is
  deduplicated.** A later `style` pass always reapplies its properties, because Blizzard can reset a
  reused region without any toggle changing; within one pass a region is touched once. What the kit
  captured for restore stays the first capture.
- **One active check.** `Engine.Active(key)` is true only while the skin is enabled, not failed,
  not owned and not stood down. **Every** callback (hook bodies, timers, combat retries, LoD
  callbacks) checks it first. Hooks can't be removed, so turning a skin off makes them no-ops; a
  generation number drops queued work from before the change.
- **When it runs:** at `PLAYER_LOGIN` (every non-LoD addon, siblings included, is loaded by then),
  each enabled skin installs now, at its window's first `OnShow` (ScrollBox windows: never force
  Blizzard's first layout, Ellesmere WindowPacks:11993), or for a load-on-demand window through
  `EventUtil.ContinueOnAddOnLoaded(addon, ...)`. A window already shown when its skin turns on is
  styled at once.
- **Owners:** resolved at `PLAYER_LOGIN`, before any skin installs (non-LoD siblings are loaded by
  then), and rechecked when each callback runs. A loaded owner wins for the session and the toggle
  reads "Handled by <Owner>". A sibling turning its own skin off inside its settings hands the
  window back only after a /reload (no ownership notifications in v1). Owners are static in the skin
  file: a future Glass Maps is in the world map's list before it ships.
- **An owner that loads after we styled** (a load-on-demand owner, or `LoadAddOn` mid-session): our
  callbacks stop, **our own panels hide**, and we restore nothing over the new owner's changes. The
  toggle reads "Handled by <Owner>, reload to finish the handover".
- **Yields:** a third-party addon that rebuilds the same frame gets a predicate that is **stable for
  the session**, read once at login. Its own login handlers may still be running then, so a skin
  that yields never touches the frame before its first `OnShow`.
- **Errors:** every `install`/`style` and every hook body runs under `API.Try`. A throw marks that
  skin failed for the session (so `Active` is false), records it in `/glassui failures`, and leaves
  every other skin alone. It doesn't try to restore after a failure: the toggle says "reload to
  restore".
- **Toggles:** `GlassUIDB.skins[key] = false` turns one off; `GlassUIDB.enabled = false` turns all
  off. **Live off/on only for skins with `live = true`**: those that only fade and add our own
  panels, or that blank and tint audited regions (#55). The kit restores the alpha Blizzard last
  asked for, gives back what it blanked and tinted, and hides our panels. Anything that shades is
  `live = false`: off means "takes effect after /reload". Universal live restore is a non-goal.
- **Gamepad stand-down:** if the gamepad interface style is active at login, no skin installs a
  hook this session; the settings page says why. (Which CVar or API reports it: probe.)

### The kit (`Skin\Kit.lua`)
The helpers every skin needs; nothing else.
- `kit:Fade(region)` records **the latest alpha Blizzard asks for** (GlassQuestTracker's `Fade`
  fix) and is the only touch a `live` skin restores.
- `kit:Blank(texture)` and `kit:Tint(texture, ...)` capture the **initial** value only (the atlas or
  file; the desaturation and vertex colour), so they are for audited, stable regions, where Blizzard
  sets the image once. `Restore` gives them back, so a live skin may use them (#55,
  docs/QUEST-TRACKER.md). `kit:Shade(fontString)` keeps `live = false`. Most Blizzard fonts already
  carry a shadow; a skin shades only where the glass makes text hard to read.
- `kit:Panel(window, size, insets)`: our glass panel, registered with Theme for repaints.
- The widget kinds the windows share, each a small function over the ones above, only the kinds
  the waves need: the portrait/button frame (NineSlice, portrait, title bg, inset), close button,
  tabs, scroll bars, panel buttons, edit boxes, check boxes, dropdowns, item slots, status bars.
  Forever's template names (`Blizzard_SharedXML\Mainline\SharedUIPanelTemplates.xml` unless noted):
  - shell: `PortraitFrameTemplate`, `PortraitFrameFlatTemplate`, `ButtonFrameTemplate(Minimizable)`
    (`.NineSlice`, `PortraitContainer.portrait`, `.Bg`, `.TopTileStreaks`, `TitleContainer`,
    `.CloseButton`, `.Inset`), `DefaultPanelTemplate`, `DefaultDialogPanelTemplate`; Forever moves the
    NineSlice corners (`Camelot\NineSliceLayoutOverrides.lua`);
  - tabs: `PanelTabButtonTemplate`, `PanelTopTabButtonTemplate`, `TabSystemButtonTemplate`,
    `LargeSideTabButtonTemplate` (Forever uses side tabs a lot);
  - scrolling: `MinimalScrollBar`, `WowTrimScrollBar`, legacy `UIPanelScrollBarTemplate`;
  - buttons `UIPanelButtonTemplate`, `SharedButtonTemplate`; edit boxes `InputBoxTemplate`,
    `SearchBoxTemplate`; check boxes `UICheckButtonTemplate`; dropdowns `WowStyle1DropdownTemplate`
    and its Filter/Arrow variants; item buttons (`IconBorder` keeps the quality colour).
  Each kind is written when the first skin needs it, not ahead.
- Shared code that proves itself in two siblings later becomes a LibGlass issue, not a new library.

### Theme
Clear / smoked / class, the siblings' presets. The wash is repainted with `SetGradient`, not
`SetAlpha` (LibGlass #47). No "stock" theme: stock is the master switch off.

## The hub

### 1. The AddOn list: `## Category: |cff7fd4ffGlass|r`
The client groups addons by two TOC fields (`Blizzard_AddOnList\AddonList.lua:449-521`):
- `## Category:` puts a group's parent under a collapsible header (like "Loot").
- `## Group:` nests an addon under the parent with exactly that name. Nesting is one level, and a
  child whose parent isn't installed falls back to the top level **without** its category
  (`:516-521`).

GlassPanel's 16 plugins already use `## Group: GlassPanel`, so GlassPanel can't also nest under
Glass UI. So: **every Glass addon (Glass UI included) gets `## Category: |cff7fd4ffGlass|r`**, and nothing is
grouped under Glass UI. It works with any subset installed. That is one TOC line per sibling, done
as an issue in each sibling repo, never from this repo's session.

### 2. One settings tree
- Glass UI registers a top-level `Glass UI` category **at file scope**, so it exists before any
  sibling registers.
- A sibling that finds `GlassUI.SettingsCategory` registers its existing page as a subcategory of it
  instead of its own top-level category. Its own subpages become a third level, which the client
  supports (`Blizzard_CategoryList.lua:408-422`). Without Glass UI, nothing changes for it.
- Load order: the sibling's TOC gets `## OptionalDeps: GlassUI`. Never `Dependencies`.
- The sibling's `/slash options` keeps opening its own page.

### 3. The family page
Glass UI's top page lists the known family (a constant roster, not a name-prefix guess): for each,
installed / enabled / loaded, a button to its settings, and enable/disable through
`C_AddOns.EnableAddOn`/`DisableAddOn` with a reload prompt. It can't install anything; a missing
addon shows its CurseForge name. Plus an `AddonCompartmentFunc` entry, which GlassMiniMapBar
already collects.

### 4. The adapter (v1, minimal)
```lua
if GlassUI and GlassUI.Register then
    GlassUI.Register("GlassUnitFrames", { api = 1, open = GlassUF.Options.Open })
end
```
Versioned like GlassMiniMapBar's `PUBLIC_API_VERSION` (`PublicAPI.lua:19`): Glass UI ignores a
higher `api` it doesn't know, pcalls every callback, and never reads a sibling's SavedVariables.
**Later capabilities, each its own decision:** following the Glass UI theme is now the suite
contract (docs/SUITE.md, 2026-10-18), which supersedes copying values into a sibling's DB: Glass
UI saves the switch, the sibling asks once at its own load, and nothing is written to its
settings. Still later: one "unlock
everything" that fans out to each addon's own movers (they keep their combat guards), and settings
bundles (each addon exports an allowlist; Glass UI only packages them).

**Hosted pages (adapter api 2, #20; owner's idea, 2026-10-16).** Glass UI hosts the Glass addons'
configuration pages in one window, a tab per page, for pages too big for Blizzard's Settings (the
pilot: Glass Raid Frames' click-casting window). Each addon builds its page as one frame, from a
function that takes its parent and lays the page out to the parent's size. Without Glass UI it
passes its own standalone window. With Glass UI it also registers
`{ api = 2, pages = { { title = ..., build = fn } } }`, and Glass UI builds the page when its tab
first opens. Glass UI provides only the window and the tabs. It never reads an addon's saved data,
and every addon keeps its own window and slash command. This is not the "custom options window"
non-goal: Glass UI writes none of the controls. The shared look of the controls is a LibGlass
question.

## Milestones (each an issue → PR; waves are ordered by risk, then value)
1. **Scaffold.** TOC, `.pkgmeta`, CI, test harness, `CLAUDE.md`, `README.md`, `CHANGELOG.md`,
   `LICENSE` (MIT), this plan, `docs/FOREVER-PROBE.md`, the `codex-consult` skill copied from
   GlassQuestTracker. Copied from GlassQuestTracker and GlassMail, not invented.
2. **Probe: `Tools/SkinProbe/`**, a ForeverProbe module (`/fp skin ...`, `ForeverProbe\docs\GUIDE.md`).
   It gates each wave, not the whole addon:
   - which frame each target really is on this client, and whether it's protected;
   - each target's region tree (names, parentKeys, layers, templates) for the kit;
   - which load-on-demand addons load when;
   - per wave, a taint pass: the wave's touches applied by the probe, a routine using each window
     (buy/sell, bid, cast from the spellbook, learn a talent, craft, queue, open the guild roster,
     log out from the Escape menu), with `taintLog 1` and `scriptErrors 1`.
   Results in `docs/FOREVER-PROBE.md` with the build. The probe is **discovery**; it never replaces
   the acceptance below.
3. **Engine + kit + wave 1** (always loaded; each skin its own PR and its own gate):
   - merchant first (the window shell: NineSlice, portrait, inset, tabs, close button; proves the
     engine, toggles, live off/on and the contract test);
   - static popups, with representative dialogs (plain, edit box, money input, item; the delete
     confirmation; one raised in combat);
   - character sheet with its six panes (side tabs, FV layouts, the Reputation ScrollBox reuse);
   - world map: **the handover pilot**, owners `{ "GlassMaps" }`, the Leatrix rule above, and the
     frame-buffer question settled by the probe first. It may slip to wave 2 without holding up
     the release.

   **Acceptance for every skin (the final implementation, not the probe's copy):** the in-game
   routine for that window with `taintLog 1` and `scriptErrors 1`, a functional check (Ellesmere's
   ScrollBox failure doesn't show in `taintLog`, WindowPacks:11993), off and on again, after a
   /reload, in combat where it applies, and with its neighbour addon loaded.
4. **Hub v1:** settings tree, family page, compartment entry, adapter v1. Pilot with GlassUnitFrames
   and GlassActionBars (an issue in each). Acceptance: both work unchanged with Glass UI absent.
5. **Release v0.1.0** (`..\References\Docs\RELEASING.md`): wave 1 + hub v1. The repo must be connected to
   CurseForge for the tag webhook; RELEASING.md assumes a public repo, so the owner decides then.
6. **Later waves**, each gated by its probe pass:
   - **Wave 2, everyday surfaces:** bags, tooltips, menus, the Escape menu. Menus are gated on: root
     and flyout rendering, reuse, close and reopen, and the Whisper entry still working in chat;
     glass or the tint-only fallback is decided from that.
   - **Wave 3, load-on-demand windows with neighbours:** auction house (with Auctionator),
     professions (with Skilled), group finder.
   - **Wave 4, protected windows:** spellbook and talents (`PlayerSpellsFrame`), the Legacy window
     (`LegacySystemFrame`, its talent tree on the same shared talent UI), guild
     (`CommunitiesFrame`), friends (`FriendsFrame` and `SocialUIFrame`).
   - **Wave 5, HUD systems with secret data:** damage meter and cooldown manager, chrome only.
   - **Hub v2+**, each its own decision: hosted configuration pages (#20), theme following,
     unlock-all, settings bundles.
   - Candidates the owner hasn't asked for, listed so they aren't forgotten: bank, gossip and quest
     dialogs, loot and loot rolls, trainer, trade, inspect, macros, the AddOn list, ready check.

## Tests (offline, Lua 5.1)
GlassQuestTracker's harness: `wow_stubs.lua` (strict globals from the API dump), `harness.lua`,
`test_methods.lua` (every method we call exists on this client), `test_toc.lua`. Plus:
- **The contract test:** Blizzard-owned stub objects (marked as such; our own frames are exempt)
  record every method called on them and its arguments. A call outside the allowed list fails, so
  does a texture argument that isn't `nil` or the captured value. GlassQuestTracker's field traps
  catch writes (a new-key trap plus a snapshot of existing fields). It runs over install, style,
  every hook callback, timers, a failure and an off/on, not just the first apply. A stub of the
  shapes we touch, not a FrameXML emulator.
- **Live restore:** for `live` skins, off restores the latest alpha Blizzard set, including one set
  while we were active.
- **Engine:** `Active` gates every callback (a queued timer after off does nothing); owners skip,
  rechecked at run time; an owner appearing after the first style hides our panels and restores
  nothing; a yielding skin waits for first show; a throwing skin is disabled alone; new and reused
  content gets styled, and **the same region reset by Blizzard is restyled** with no toggle in
  between; LoD skins wait for their addon.
- **Hub:** a sibling registering with and without Glass UI; an unknown `api` ignored.
- **Mutation-test every new test.** Offline tests can't cover taint or rendering: that's the probe
  and the in-game checklist (each skin with its conflict addon installed, in combat, after /reload).

## Risks
- **Maintenance:** every Blizzard patch can move a region. Mitigation: resolvers that skip missing
  regions and record them, one file per skin, the per-skin switch, and `/glassui failures`.
- **Taint** on protected windows (spellbook, talents, Escape menu, guild/communities, group finder).
  Mitigation: the C-only rule, the probe's taint pass before each wave, those skins last.
- **Overlap** with siblings and third parties: owners, yields, and the overlap check for full UI
  suites.
- **Hooks are forever:** a hook can't be removed, so every callback is gated by `Active` and does
  nothing once its skin is off, failed or owned.

## Decided after the review (owner, 2026-10-15)
- **AddOn-list category:** `## Category: |cff7fd4ffGlass|r`, the Glass title colour. EllesmereUI does
  the same (`## Category: |cff0cd29fEllesmere|rUI` in its 21 TOCs). This is the in-game field, not
  CurseForge's project categories, which the owner picks on the site.
- **Slash commands:** `/glassui` and `/gui` (`/glass` is GlassUnitFrames').
- **v0.1.0 = wave 1 + hub v1.** 1.0.0 ships with Forever's launch.
- **Repo:** `Spotnick2/GlassUI`, private for now. CurseForge's tag webhook needs it connected
  before v0.1.0 (RELEASING.md assumes a public repo): the owner decides then.
