# The game menu in glass (#90)

The Escape menu from the window template (the merchant #86, the bags #88) and the owner's mockup
(2026-10-20): a glass window, the title on a glass tab, each button a glass bar. Look only,
nothing moved.

Codex `gpt-6-astra` review: consensus in round 1 (2026-10-20). No BLOCKER; two SHOULDs and a NIT
taken in below (marked "(Codex)"). Its taint reading: the dangerous chains are all Blizzard's
(`ShowUIPanel`/`HideUIPanel`, Settings → `TransitionBackOpeningPanel` → `ToggleGameMenu`, the
casting handler's `SpellStopCasting` before the menu opens). The visual touches never enter them.
Our glass, with no `layoutIndex`, is left out of the menu's layout (LayoutFrame.lua:22-39).

## What's read (wow-ui-source `forever`, 70450)

- **The frame.** `GameMenuFrame` (Blizzard_GameMenu `Shared\GameMenuFrame.xml`, loaded on
  `camelot`, toc:7-9): `MainMenuFrameTemplate`, strata DIALOG, toplevel, a UI panel shown and hidden
  by `ShowUIPanel`/`HideUIPanel` (GameMenuFrame.lua:27-38).
- **The template** (Blizzard_SharedXML `Mainline\Frame\MainMenuFrameTemplates.xml:18-53`):
  - a `VerticalLayoutFrame` that sizes itself to its buttons (padding 48 / 34 / 28 / 28);
  - `Border` (`DialogBorderTemplate`, a NineSlice of layout `Dialog` with a tiled `Bg`, BACKGROUND -5,
    DialogTemplates.xml:53-80);
  - `Header` (`DialogHeaderTemplate`, TOP +11): `LeftBG`, `RightBG`, `CenterBG` (the diamond-metal
    atlases, ARTWORK) and `Text` (DialogTemplates.xml:11-45; the menu sets its font
    `GameFontNormalMed1`).
- **The buttons.** `MainMenuFrameButtonTemplate` is `BigRedThreeSliceButtonTemplate` (200 × 36), i.e.
  `ThreeSliceButtonTemplate` (ThreeSliceButtonTemplate.xml:4-58):
  - `Left`, `Right`, `Center` on BACKGROUND, and a highlight atlas (`128-RedButton-Highlight`,
    `SetHighlightAtlas`).
  - Its `UpdateButton` (on show, enable, disable, mouse down and up) only calls `SetAtlas` on the three
    pieces (ThreeSliceButtonTemplate.lua:83-100). **No alpha, so a fade holds.**
- **Built on every show.** `OnShow` → `InitButtons` → `Reset` (`buttonPool:ReleaseAll`), then
  `AddButton` for each entry (GameMenuFrame.lua:69-84, 190-…; MainMenuFrameTemplates.lua:13-60).
  - The pool's parent is the menu itself.
  - `AddButton` calls `SetScript("OnClick")`, and `SetScript("OnEnter"/"OnLeave")` (a tooltip on a
    disabled entry, else nil) every time. **A `HookScript` on a button would be wiped on the next
    show.**
  - `OnEvent` (store or trial status) calls `InitButtons` again.
- **The badges.** `NewOptionsFrame`/`NewExternalEventFrame` ("NEW") and `EditModeNotification` are
  anchored to the buttons by Blizzard: left as they are.
- **Esc.** `Blizzard_GameMenuEsc` runs registered handlers by priority. The menu's own handler hides
  it (`HideUIPanel`, GameMenuFrame.lua:17-24).
  - **The trap** (porting guide, "Closing the Settings window"): an addon's own call that ends in
    `ToggleGameMenu` makes Blizzard's Esc handler call the protected `SpellStopCasting()`. The
    client then blames the addon (`ADDON_ACTION_FORBIDDEN`, measured by GlassRaidFrames and Glass
    Unit Frames).
  - So **the skin never shows, hides, toggles or closes the menu, and never calls a Blizzard Lua or
    mixin method**. Native getters and the engine's `OnShow` post-hook on the menu are allowed; no
    button script is hooked or replaced (Codex). It only reacts to Blizzard showing it.
- **References** (behaviour only):
  - **Ellesmere** (`EUI_BlizzardSkin_Dialogs.lua:351-430`): `HookScript("OnShow")` on the menu,
    `hooksecurefunc(GameMenuFrame, "InitButtons")`, the NineSlice and the `Border` faded, a
    backdrop. It moves the header, which we don't.
  - **ElvUI** (`Skins/Misc.lua:114-121`): strips and re-anchors the header.

## The plan

- **Registration.** `key = "gamemenu"`, `title = "Game menu"`, `risk = "plain"` (the frame isn't
  protected; it opens in combat), `live = true`, `backing = "window"`, `frames = GameMenuFrame`.
  The engine's OnShow attach, gamepad stand-down and owners work as for every skin.
- **The window:** `kit:Panel(GameMenuFrame)` (the 0.93 floor), and its `Border` faded (a frame:
  its NineSlice and tiled `Bg` with it). There's no portrait, close button or smoky band (a short
  dialog, all body).
- **The title tab** (the mockup's):
  - the header's `LeftBG`, `RightBG` and `CenterBG` faded;
  - our small glass on the header (`kit:Panel(Header, "small", HEADER_INSETS)`), its rim at its
    own level, under the header's text;
  - the title text stays Blizzard's (gold, `GameFontNormalMed1`).
- **The buttons:**
  - One idempotent `styleButtons(kit, frame)`, called **both** by the skin's `style` and by
    `hooksecurefunc(GameMenuFrame, "InitButtons")` (an instance hook, gated, as the bags'
    `UpdateItems`).
    - On the first show, Blizzard's `OnShow` runs `InitButtons` before the engine's hook installs
      the skin. And switching the skin on with the menu open re-styles without a rebuild. So the
      style pass must reach the buttons too (Codex). After Blizzard's pass, the menu's children with `Left`, `Right` and `Center`
    textures (fields read, never written) are walked, `GetChildren` being a C method.
  - **Built once per pooled button** (a weak table): our small glass, parented to the button, its
    rim at its own level, no backing.
  - **Each pass:**
    - `Left`/`Right`/`Center` faded;
    - the highlight texture (`GetHighlightTexture`) tinted neutral, `kit:Tint(tex, 1, 1, 1,
      HOVER)`, desaturated. That's Blizzard's own additive hover glow, now white instead of red,
      and `Restore` gives the colour back. It follows the mouse without any hook of ours on a
      button.
  - **Disabled entries** keep Blizzard's grey font and their tooltip scripts; a pressed button
    keeps Blizzard's text offset.
- **Never:**
  - a `SetScript`, `HookScript`, field, `SetPoint`, `SetSize`, `Show`/`Hide` or text on a button
    or on the menu;
  - a call to `InitButtons`, `Reset` or any mixin method;
  - `ShowUIPanel`/`HideUIPanel`/`ToggleGameMenu`.

### Tests

- **Stubs:** `GameMenuFrame` with its `Border` (the NineSlice frame itself, with its slices and
  `Bg`: no `Border.NineSlice`, Codex), its `Header` (three pieces and `Text`), and a pool whose
  `InitButtons` releases and acquires buttons. It calls `SetScript` on each as Blizzard does, and
  creates a new button when the menu grows.
- **The pool's paths** (Codex):
  - the buttons styled at the **first** show;
  - an `InitButtons` refresh while open (`OnEvent`);
  - the pool shrinking and growing;
  - off, a refresh, then on.
- **Each piece and the pool:**
  - the border and the header's art faded and given back;
  - the header's glass and its level;
  - each button's glass (once per button across shows), the three pieces faded, the highlight
    tinted and restored;
  - a disabled entry left to Blizzard.
- **Gating:** off, then a show, touches nothing of ours; on re-syncs.
- **The contract test** with the menu shown in combat: no forbidden call, and no call to a
  `GameMenuFrame` method from our code.
- Mutation-tested.

### In game (`/fp steps skin gamemenu`)

- **After a fresh `/reload`, the menu's first opening in combat** (the glass built and the hooks
  installed in combat), then out of combat: a screenshot each beside stock (Codex).
- Several opens, closes and Settings returns: the menu's size and button places unchanged.
- Hover over each button; a disabled entry, if any.
- **Options → Settings, then back to the menu** with Settings' own close and with Esc, in combat too:
  nothing blocked or forbidden (the porting guide's `SpellStopCasting` trap, which we must not
  trigger).
- **Log Out**, then cancelled; **Exit Game**, then cancelled; **Return to Game** (Codex). AddOns, Edit
  Mode and Macros, each opened from the menu and closed.
- **Esc with a cast going:** Blizzard stops it, nothing blocked.
- Off and on; `/reload`; the taint log on throughout, with blocked and forbidden actions counted.

## Built (2026-10-20)

- **`Skin/GameMenu.lua`**, as above. `styleButtons` is idempotent, called by the style pass and the
  `InitButtons` hook.
- **Tests:**
  - `test_gamemenu` 126: the first show in combat, re-shows, a refresh while open, the pool growing and
    shrinking, a disabled entry, a non-button child, off/refresh/on, and no Blizzard Lua call from our
    code. The contract and method tests open the menu too.
  - 12 mutants of the skin and 10 of the probe's checks, all killed.
- **The probe:** the bags and game menu blocks are now each in their own `do` scope, since Lua 5.1
  allows 200 locals in a chunk's main function and the file reached it.

## Run 1's tuning (2026-10-20)

The owner, after GM run 1: "a bit more pearl except for the buttons since the stock ui was already
translucent ... maybe more like the quest tracker".
- **The window:** the suite's body backing (clear 0.35, the quest tracker's), no longer the window
  floor. The skin's `backing = "window"` is dropped.
- **The buttons** keep their density: each button's glass gets its own backing at the window floor.
  That's `kit:Panel`'s new `opts.kind`, a panel's backing kind when it isn't its skin's. It stacks
  with the window's to about 0.95 (before: 0.93 under unbacked glass).
- **The title tab:** still no backing.
- Tested and mutation-tested (5 mutants, all killed).
