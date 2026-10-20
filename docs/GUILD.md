# Guild & Communities in glass, and GuildSpy as a tenant (#92)

The guild window from the window template (merchant #86, bags #88, game menu #90) and the owner's
mockup (2026-10-20): a dark glass window, a centred gold title, the portrait in its disc, recessed
panes for the community list, the chat and the roster, glass side tabs with the selected one rimmed
in gold. Look only, nothing moved. GuildSpy's two side tabs and its in-guild panel take the same
look through an optional hand-over, agreed with GuildSpy's session. Both addons stay standalone.

Codex `gpt-6-astra` review: round 1 (2026-10-20), one BLOCKER (the panel's draw order), five SHOULDs
and two NITs, taken in below (marked "(Codex)").

## What's read (wow-ui-source `forever`, 70450)

Paths are under `Blizzard_Communities/` unless named.
- **Loading.** The addon loads at startup: no `LoadOnDemand` in the TOC. The only camelot-only file
  overrides `CommunitiesFrame_ShouldDisplayPersonalAchievements` (TOC:56). Nothing visual.
- **The frame.** `CommunitiesFrame` (CommunitiesFrame.xml:303), `ButtonFrameTemplateMinimizable`
  (`ButtonFrameTemplate`, layout `PortraitFrameTemplateMinimizable`): `NineSlice`, `Bg`,
  `TopTileStreaks`, `TitleContainer.TitleText`, `CloseButton` and `Inset`.
  - It's 814 × 426 maximized and 322 × 406 minimized (CommunitiesFrame.lua:1715, 1739).
  - Minimized, it shows only the list dropdown, the chat, the edit box, the stream dropdown and the
    headset (lua:655).
- **The portrait.** `PortraitOverlay` (xml:309, level 300) holds `Portrait` with its `CircleMask`,
  and the guild tabard textures (`SetLargeGuildTabardTextures`, lua:293, 1352-1359). That's not the
  template's `PortraitContainer` (level 400, SharedUIPanelTemplates.xml:574), which the kit's
  `PortraitDisc` targets. Minimized, Blizzard hides `PortraitOverlay` (lua:1751-1752) (Codex).
  `MaximizeMinimizeFrame` sits left of the close button (xml:354).
- **The community list.** `CommunitiesList` (CommunitiesList.xml): `Bg` (`bluemenu-main`, :136),
  `TopFiligree` and `BottomFiligree` on the list itself (:145-158, Codex), `FilligreeOverlay` (:174),
  `InsetFrame` (:247), a `WowScrollBoxList` of
  `CommunitiesListEntryTemplate` rows (Background, Selection, Icon, Name, the tabard pieces, :4-105).
- **The chat.** `Chat` (`CommunitiesChatTemplate`): `MessageFrame`, `ScrollBar` (strata HIGH),
  `InsetFrame` (CommunitiesChatFrame.xml:6-38).
- **The edit box.** `ChatEditBox` (xml:507, level 1200) draws its `UI-ChatInputBorder` edges as
  `Left`/`Right`/`Mid` (ChatFrame.xml:57+).
- **The roster.** `MemberList` (CommunitiesMemberList.xml): `ColumnDisplay` (:298), a ScrollBox of
  `CommunitiesMemberListEntryTemplate` rows, `InsetFrame` (:355). The marble is
  `MemberList.ScrollBar.Background` (:344-353), the scrollbar's own: it stays stock with the
  scrollbar (Codex). `CommunitiesMemberList.lua:591-612` hides and shows the ColumnDisplay during
  layout.
  - **Its taint rules** (Ellesmere WindowPacks:3209-3224):
    - never `HookScript` the ColumnDisplay: its OnShow/OnHide fires inside the protected
      SetNote/SetGuildRankOrder refresh, giving `ADDON_ACTION_FORBIDDEN`;
    - never re-anchor or resize the roster: the rows size from its width, so an addon's width
      taints them for the session;
    - never walk the member ScrollBox's buttons.
- **The side tabs.** `ChatTab`, `RosterTab`, `GuildBenefitsTab`, `GuildInfoTab`,
  `GuildPreferredPlaySettingsTab` (xml:368-435) are `RightSideTabTemplate` CheckButtons, 32 × 32
  (Blizzard_SharedXML/Shared/Tabs/RightSideTab.xml:3-42):
  - an unnamed BORDER texture (`SpellBook-SkillLineTab`, the frame round the icon);
  - `Icon`, and `IconOverlay` (hidden);
  - a `HighlightTexture` (ADD) and a `CheckedTexture` (`CheckButtonHilight`, ADD).
  - **The checked state:** `UpdateCommunitiesTabs` calls `SetChecked(false)` on all five, then
    `SetChecked(true)` on the mode's tab (lua:1119-1133). A click toggles a CheckButton natively;
    `RightSideTabMixin.OnClick` calls `SetChecked(true)` (RightSideTab.lua:7-10), possibly before the
    others are cleared. A Shift-click on the chat tab opens Social settings without a mode change
    (CommunitiesTabs.lua:11-19) (Codex).
- **Buttons.** `InviteButton` and the `CommunitiesControlFrame` buttons (`UIPanelButtonTemplate`),
  and the dropdowns (`WowStyle1DropdownTemplate`).
- **The other modes'** frames (`GuildBenefitsFrame`, `GuildDetailsFrame`,
  `GuildPreferredPlaySettingsFrame`, `GuildMemberDetailFrame`) have Inset borders of their own
  (xml:4-161).
- **References.** Ellesmere fades the NineSlice and the portrait overlay; it shifts non-root tabs,
  which we don't. ElvUI re-stacks the tabs flush, which we don't either: that would break
  GuildSpy's `-20` anchors.

## GuildSpy (main, read only; its session's answers, 2026-10-20)

- **Two side tabs.** `GuildSpy.UI.tab`/`ptab` are `RightSideTabTemplate` CheckButtons, made once in
  `AttachGuild`, at level 510.
  - `UI.PlaceTab` re-anchors them at `-20` under the last Blizzard tab shown, on every
    `UpdateCommunitiesTabs`, showing and hiding them.
  - **When its tab opens, GuildSpy calls `SetChecked(false)` on Blizzard's five**, and again from
    `C_Timer.After(0)`, because Blizzard re-checks one during its layout.
- **The in-guild panel.** `guildHost` is a child of CommunitiesFrame **one strata above it**
  (MEDIUM → HIGH), at level 1300, with an **opaque** background (`{0.04, 0.045, 0.055, 1}`). It's
  needed: even at 0.97, chat text and names showed through.
  - Its panel (level 1301) is built lazily and **reparented** between `guildHost` and the
    standalone window.
  - Its art (marble, stripes on pooled rows, the header pieces) is GuildSpy's to fade, per host.
- **The standalone window** (`GuildSpyLogWindow`) is LibGlass r10, Clean. Joining the suite is
  GuildSpy's own issue.
- **Nothing in GuildSpy sets an alpha** on the tabs or `guildHost.bg`. The row highlights get
  `SetAlpha(0.5)` once, so a restore gives back the captured alpha, never 1.

## The plan

### The skin (`Skin/Guild.lua`, key `guild`)

- **Registration.** `risk = "plain"`, `live = true`, `backing = "window"`,
  `frames = CommunitiesFrame`.
- **The window:**
  - `kit:Panel` (the 0.93 floor) and `kit:Shell` (NineSlice, Bg, TopTileStreaks, Inset);
  - `kit:Header` down to the top of `CommunitiesList`, the title strip: a smoky band;
  - **the portrait's disc:** `kit:Disc`, parented to `PortraitOverlay` (so it hides with it when
    minimized), round its `CircleMask`, at `PortraitOverlay`'s level − 1. The tabard pieces stay.
    It's not `PortraitDisc`, which targets the template's container (Codex);
  - `kit:CloseButton`.
  - `MaximizeMinimizeFrame`'s two buttons: their state textures tinted neutral (`kit:Tint`,
    desaturated), as the quest tracker's minimize buttons, so they're not red.
- **The panes** (the merchant's Section: a black fill and a 1 px edge), each on **a host frame of
  ours parented to Blizzard's section** (`CommunitiesList`, `Chat`, `MemberList`, and `ChatEditBox`
  itself: Blizzard hides the box alone in the non-chat modes, lua:679-704, Codex round 2). The host is
  anchored to the section's `InsetFrame` (the box itself for the edit box), at the section's level
  (under its content, its rows and messages at higher levels; the box's level − 1 for the edit
  box), and `kit:Adopt`ed.
  So each pane shows and hides with its section as the display modes switch them (`SetDisplayMode`,
  lua:585-662), **with no script hook on any Blizzard frame** (Codex):
  - **the community list:** its `Bg`, `TopFiligree`, `BottomFiligree`, `FilligreeOverlay` and
    `InsetFrame` faded. The rows (their Background and Selection) stay Blizzard's: the selection is
    information;
  - **the chat:** `InsetFrame` faded. The messages and scrollbar stay;
  - **the edit box:** `Left`/`Right`/`Mid` faded, its pane one level under the box;
  - **the roster:** `InsetFrame` faded.
- **The roster's rule, precisely** (Codex): no `HookScript` on any roster frame; nothing at all on
  the ColumnDisplay; no walking its rows; no anchor, size or field. The kit's alpha post-hook
  (`Fade`'s `hooksecurefunc` on `SetAlpha`) on the faded `InsetFrame` is allowed: an alpha only.
  The ColumnDisplay's header art and the scrollbar's marble stay stock in v1.
- **The other modes** (Benefits, Info, Preferred play): their `InsetFrameTemplate` borders get
  `kit:Inset` where they are one. Otherwise they stay stock in v1: the probe's screenshots decide.
- **The side tabs** (Blizzard's five, and any `SkinTab`'d one):
  - the BORDER frame texture (found among `GetRegions` by layer) and the `CheckedTexture` (read by
    `GetCheckedTexture`) faded. The `Icon` and the hover highlight stay;
  - our small glass round the button (`kit:Panel(tab, "small", TAB_INSETS)`), its rim at its own
    level;
  - **the selected one:** our light (white, `TAB_LIGHT`), and its glass's rim in the suite accent at
    full strength (`Glass.SetSurfaceRim(g, r, g, b, 1)`, scalar channels: small coloured rims read
    faint otherwise, GLASS-MATERIAL.md:393; Codex). That's the mockup's gold rim. The others get the
    built rim back (`SetSurfaceRim(g)`).
  - **Our selection art mirrors each tab's own `GetChecked()`**, re-read for every registered tab
    after any of them changes: `hooksecurefunc(tab, "SetChecked")` and `tab:HookScript("OnClick")`
    on each instance, gated, plus a read of every tab at install, at a late tab's registration and
    at re-enabling.
    - It mirrors; it never enforces. During GuildSpy's one-frame wait (`C_Timer.After(0)`) two tabs
      can be checked, and so shown: Blizzard's state is the truth (Codex). Nothing polls or writes
      a checked state.
  - Nothing moves: the tabs' anchors, sizes and gaps stay Blizzard's (and GuildSpy's).
- **Buttons:** `InviteButton` and the control frame's buttons get their three pieces faded and a
  small glass with the window floor's backing (the game menu's buttons). The dropdowns stay stock in
  v1 (GuildSpy's panel matches them).
- **Accent repaint:** the selected rim follows `Theme.OnRefresh`, as the kit's tracked pieces do.

### The tenant API (`Suite.lua`, additive: `Suite.API` stays 1)

For an addon whose frames sit in a window Glass UI skins. Feature-detected:
`type(rawget(G.Suite, "SkinTab")) == "function"` with `G.Suite.API == 1`, each call under `pcall`.
Without Glass UI, or with an older one, nothing happens.

- **`Suite.SkinTab(owner, tab) --> bool`**
  - `owner`: the addon's name, a non-empty string. `tab`: a `RightSideTabTemplate` CheckButton
    parented to `CommunitiesFrame`.
  - It returns true when accepted, false for anything else; it never errors.
  - Called once at the tab's creation. A tab handed over before the guild skin installs is
    styled when it does.
  - The tab gets exactly the side-tab treatment above, while the guild skin is on, and it's given
    back (fades restored to the captured alpha, our frames hidden) when the skin is off.
  - Our glass is parented to the tab, so it moves and hides with it.
- **`Suite.SkinPanel(owner, host, onSkin) --> bool`**
  - `host`: the addon's frame inside `CommunitiesFrame` (GuildSpy's `guildHost`, at its own strata
    and level). `onSkin`: a function or nil.
  - **The layering, by distinct levels** (Codex BLOCKER: a child at its parent's very level has no
    guaranteed draw order over the parent's own regions):
    - the host at **L**, with the addon's opaque base on it;
    - our glass (a frame of ours, a child of `host`, its rim lowered to it, no backing of its own)
      at **L + 1**;
    - **the addon's content at L + 2 or higher**: GuildSpy moves its panel from 1301 to 1302 or
      more, in its own issue. Glass UI never moves the addon's frames.
  - **`onSkin(on, look)`**, with `look` a fresh table `{ backing = { r, g, b } }`: the window floor's
    colour, which the addon may paint its opaque base with, keeping its alpha at 1. The addon fades
    its own art in it, per host (lazy panels, pooled rows).
  - **The life cycle** (Codex):
    - **Accepted means registered, not styled.** A valid call returns true even while the guild skin
      is off, or stood down for the session (the gamepad, a suite stand-down, an owner). An invalid
      one returns false. Neither ever errors.
    - At registration, the addon gets `onSkin(false, look)` unless the treatment is applied by then.
    - **`onSkin(true, look)` only after the treatment is applied**: at the guild skin's install and
      style pass, and for a late registration once it's applied. A failed application never
      announces true.
    - **`onSkin(false, look)` once when an applied treatment ends:** the skin switched off, the
      master switch off, or a handover to an owner. That needs a new engine hook: an optional
      `def.restored(kit)`, called after `kit:Restore()` in the switch path (Engine.lua:220) and in
      `handover` (Engine.lua:75). It's not gated by `Engine.Active`, which is already false there,
      and it keeps the handover's rule of never restoring Blizzard art over a late owner.
    - Registrations while stood down install nothing on Blizzard's frames, and wait.
    - Each callback runs under `pcall`, its failure recorded under an owner-specific key
      (`API.Fail("tenant:<owner>:onSkin", ...)`), never through `Engine.Run`, which would fail the
      whole guild skin (Engine.lua:94).
- **Neither side reads the other's tables.** Glass UI keeps the handed-over frames in its own weak
  tables, and never writes a field on them.
- **Detection** (Codex): validate `GlassUI.Suite` as a table and `API == 1` exactly, then
  feature-detect **each** function on its own (`type(rawget(Suite, "SkinTab")) == "function"`, the
  same for `SkinPanel`).
- **docs/SUITE.md's "never asks an addon to restyle"** gains its one exception: the opt-in
  `onSkin` of a tenant that registered a panel. That's tenant styling, governed by the guild skin
  and an explicit registration, and separate from a member's own Theme/Report participation
  (Codex).
- **The roster:** `GuildSpy` joins `Suite.ROSTER`, so `Theme` answers it. Its card stays "not yet
  integrated" until it speaks Theme/Report (Suite.lua:393), which is GuildSpy's issue.

### Not in this

- The community list's rows, the roster's rows and its ColumnDisplay header, the dropdowns, the
  scrollbars: stock in v1.
- Restyling other addons' frames without their hand-over.

### Tests

- **Stubs:** `CommunitiesFrame` with its shell, the portrait, the list, the chat, the edit box, the
  roster (its ColumnDisplay as a frame that records every hook), the five tabs with their checked
  logic as Blizzard's `UpdateCommunitiesTabs`, a click's native toggle, the buttons, and the
  display modes showing and hiding the panes' frames.
- **Each piece:** fades and restores, the panes' anchors and visibility per mode, the header and
  the disc, and the close button.
- **The tabs:**
  - the selected one's light and rim following `SetChecked` and a click;
  - a GuildSpy-like tenant tab with its `SetChecked(false)` on Blizzard's, timer included: the art
    mirrors the state and settles after the timer (Codex);
  - a Shift-click, repeated clicks, two tenant tabs, both registration orders;
  - the accent repaint.
- **The roster:** no `HookScript` on any roster frame, nothing on the ColumnDisplay, no anchor or
  size change; only the kit's alpha hook on the faded inset.
- **The tenant API:**
  - accepted and refused calls;
  - a tab handed over before and after install;
  - off and on restoring the tenant's fades to their captured alpha;
  - `onSkin`: false at registration before install, true once applied, false once on off, master
    off and handover; never true after a failed application; a throwing callback recorded under its
    owner, the skin unharmed;
  - the host glass at the host's level + 1;
  - the engine's `restored` hook;
  - the roster entry.
- **The contract test**, with the window shown in combat.
- Mutation-tested.

### In game (`/fp steps skin guild`)

- **Each mode:** chat, roster, benefits, info, preferred play. Maximized and minimized, in
  screenshots beside stock.
- **The tabs:** each one clicked, a Shift-click on the chat tab, repeated clicks; GuildSpy's tabs
  opened and left (with GuildSpy). The selection art mirrors each tab's checked state, settled after
  GuildSpy's one-frame wait (Codex).
- **The modes:** chat → roster, benefits, info, preferred play and back, and minimized: the edit
  box's pane hides with the box.
- **The roster's taint** (Ellesmere's case), with the taint log on: a member's note edited, a rank
  changed if possible, sorting by a column. Nothing forbidden.
- **The window opened in combat.** `IsProtected()`/`IsForbidden()` recorded for the frames we
  parent to and our own children (Codex).
- **With GuildSpy:** its panel on glass, its art faded by itself, the chat not bleeding through.
  Without GuildSpy, nothing else changes.
- Off and on; `/reload`.

## Built (2026-10-20)

Codex `gpt-6-astra` consensus in round 3.

- **`Skin/Guild.lua`; `Suite.SkinTab`/`SkinPanel` and the roster entry; the engine's
  `def.restored`; docs/SUITE.md's tenant section.**
- **Tests:**
  - `test_guild` 124: the window pieces; the panes per mode and minimized; no hook on the roster;
    the tabs mirroring `SetChecked`, a click, GuildSpy's clearing and its timer, and a Shift-click;
    the tenant API's acceptance and refusals, before and after install and while off; `onSkin`'s
    false/true/false over the switch, the master switch and a handover; a throwing callback; the
    gamepad stand-down.
  - The contract test opens the window in combat with a tenant, and asserts no roster hook.
  - 33 mutants of the skin, the API and the engine hook, all killed (one after fixing a test that
    compared gold's red channel, which is 1 like white's); the probe's checks, 6, all killed.
- **GuildSpy's side** (its own issue, on the owner's go-ahead): call `SkinTab` for its two tabs and
  `SkinPanel` for `guildHost`, move its panels from level 1301 to 1302, and fade its own panel art
  in `onSkin`.
