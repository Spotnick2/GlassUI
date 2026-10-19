# The damage meter skin (#49)

Glass behind Blizzard's damage meter, like the merchant window (#4): the window in glass, the bars
left as they are. Measured on 1.60.1.70450 (docs/FOREVER-PROBE.md, "The damage meter", DM.1-DM.6).
Codex `gpt-6-astra` review: consensus in round 3, 2026-10-19.

## Owner decisions (2026-10-19)

- **The window only.** The bars keep Blizzard's look in v1.
- **Glass bars only as a preview first.** The owner wants to see what they would look like. They
  are a probe procedure (below), not part of the skin. They join the skin later only if the owner
  asks.
- **Size and position stay the player's.** They're set in Edit Mode (frame width 200-600, height
  120-400, bar height 15-40). The skin never moves or resizes the meter.

## What the meter is made of (measured)

- `DamageMeter` is an Edit Mode system. `Blizzard_DamageMeter` loads at startup on Forever.
- It holds up to three windows, `DamageMeterSessionWindow1`-`3`, made on first use by
  `DamageMeter:SetupSessionWindow` (`DamageMeter.lua:284`). A window can appear long after login,
  when the player adds one from the gear menu.
- Per window, the art the skin touches:
  - `Header`: `ui-damagemeters-header-bar`, the top 32 px.
  - `MinimizeContainer.Background`: `damagemeters-background`. Its alpha is the Edit Mode
    Background setting; Blizzard sets it again on every change (`UpdateBackground`).
  - `MinimizeContainer.SourceWindow.Background`: `common-dropdown-bg`, the breakdown, strata HIGH.
- Minimized, a window keeps its size. `MinimizeContainer`, which holds the background and the bars,
  hides; the header stays.
- Nothing is protected or forbidden. All 112 textures fade with `SetAlpha`.
- A bar's value is secret, even out of combat. The skin never reads it.
- Frame points are secret here: ElvUI's skin notes "point is a secret" before re-anchoring. We never
  read or set Blizzard's points anyway.

## The skin: `Skin\DamageMeter.lua`, key `meter`

`risk = "plain"`, `live = true` (fades and panels only: off and on without a /reload), its own switch
"Damage meter".

**Finding the windows.**
- `frames()` returns `DamageMeter`, and the engine attaches at its `OnShow`, as for every skin.
  While Visibility hides the meter (Hidden, In Combat, In Group), the skin waits for its first show,
  as every skin waits for its window.
- **By name, never through the mixin.** Blizzard names each window
  `"DamageMeterSessionWindow" .. index` (`DamageMeter.lua:285`), with at most three
  (`MAX_DAMAGE_METER_SESSION_WINDOWS`, a local there). The skin reads those globals; a missing one
  is normal (not made yet), not a failure. Calling `ForEachSessionWindow` would be a mixin call,
  which the contract forbids (docs/PLAN.md, `test_contract`), `pcall` or not.
- **Discovery runs on every `style` pass, not only at install.** Each pass finds the current
  windows, gives an unseen one its panels (once, in our weak table), and fades all of them. So a
  window made while the skin was off is skinned when it comes back on, through either switch.
- `install` also hooks `DamageMeter.SetupSessionWindow` on the instance (`hooksecurefunc`, the
  contract's allowed hook, and ElvUI's way too, `Skins\DamageMeter.lua`). A window made or reused
  later (a hidden secondary window comes back through it, `DamageMeter.lua:385`) gets a style pass
  at once. The hook checks `Engine.Active("meter")` first; hooks can't be removed.

**Per window, three glass panels of our own** (`kit:Panel`, unnamed, mouse off):
1. **Body:** a child of `MinimizeContainer`, so it hides with the container when the window is
   minimized. `Background` faded.
2. **Header:** a "small" panel over the `Header` region's footprint, so a minimized window keeps a
   glass strip. `Header` faded.
   - `kit:Panel` today anchors to a frame. It gains an optional `anchor` region for this; the
     panel stays a child of the window.
3. **Breakdown:** a child of `SourceWindow`, which inherits its HIGH strata. Its `Background` faded.

**The Background setting.**
- The glass follows the player's Background setting rather than overriding it:
  - Background 0% means no glass;
  - Background 50% (the default) means the full glass;
  - in between, the glass's alpha is `min(1, alpha / 0.5)`, to be tuned in game.
- This is the **body** panel only. The header and breakdown panels keep their full glass: the
  setting is Blizzard's for the window background alone.
- `Kit:Fade` already keeps Blizzard's latest alpha for a faded region (its SetAlpha hook). It gains
  an optional callback, `kit:Fade(region, onAlpha)`. The skin uses it to set the body panel's
  alpha, at once and on every change.
- The callback always gets the **saved** Blizzard alpha, never the held 0:
  - on a repeated `Fade` with no change in between;
  - not for the kit's own `SetAlpha(0)` (the busy guard);
  - never while the skin is off or being restored.
- The value is checked to be a plain number (`type(API.Plain(alpha)) == "number"`) before any
  arithmetic.
- The Transparency setting is the window's alpha. Our panels are children of the window, so they
  follow it with no code.

**Left alone:**
- the bars, all of them: the list, the breakdown's, and the floating `LocalPlayerEntry`;
- the header buttons (minimize, gear, session, type) and the resize handle;
- the scroll bars, every font and Blizzard's colours;
- Edit Mode's `Selection` overlay.

The header buttons are gold on glass. Recolouring them in place (desaturate and a light tint)
would need a live-restorable tint in the kit, which doesn't exist yet. The acceptance screenshots
show them stock, and the owner decides then; a tint would be its own change.

**Theme.** Glass UI's own `Theme`, as the merchant: clear, smoked or class. Whether Glass UI's
skins follow the suite look's tint is a separate, later question (docs/SUITE-LOOK.md).

**Who steps aside.**
- The engine's suites (ElvUI, EllesmereUI's Blizzard skin, Tukui) already turn every skin off. Both
  ElvUI and EllesmereUI skin this meter.
- Details, Skada and Recount are separate meters and never touch Blizzard's, so they're not owners.

## Tests (offline)

- A stubbed meter, shaped like 70450's: `DamageMeter` with `ForEachSessionWindow`,
  `SetupSessionWindow`, and windows with the measured parentKeys.
- **The skin:**
  - every window present at login is skinned;
  - a window made later, through `SetupSessionWindow`, is skinned once;
  - the three panels per window;
  - the faded regions;
  - the body's alpha follows `Background:SetAlpha(0 / 0.25 / 0.5 / 1)`.
- **The switch:**
  - off restores every alpha to Blizzard's latest, including one set while the skin was on;
  - on again re-fades;
  - the hook does nothing while the skin is off;
  - a missing piece (another build) is recorded and the rest goes on.
- **The lifecycle:**
  - a window made while the skin is off is skinned when it's switched on again, through its own
    switch and through the master switch;
  - a hidden secondary window that is shown again (reused) gets no second set of panels;
  - with the meter hidden by Visibility at login, the skin waits, then skins it at its first show.
- **The Fade callback:**
  - a repeated `Fade` with no Blizzard change passes the saved alpha, not 0;
  - the kit's own `SetAlpha(0)` doesn't call it;
  - nothing happens while the skin is off or restoring;
  - a secret or non-number alpha is ignored.
- **The contract test:** no forbidden method on any Blizzard object.
- `Kit:Fade`'s callback and `Kit:Panel`'s anchor, each with its own tests.
- Every new test mutation-checked.

## In game

- **Acceptance**, `/fp steps skin meterskin`, with screenshots:
  - the three styles;
  - Background at 0, 50 and 100%;
  - Transparency at 50%;
  - a minimized window;
  - the breakdown (clicked so it stays open);
  - a window added after login, and one added while the skin is off;
  - off and on live, after a /reload, and in combat.
  - `scriptErrors 1` and `taintLog 1` throughout.
- **The glass bars preview**, `/fp steps skin meterbars` (probe only, never shipped). Within the
  contract, so it is what a later version could really ship:
  - each visible bar's `Background` and `BackgroundEdge` faded;
  - a small glass panel of ours behind the bar;
  - Blizzard's fill texture at 0.8 alpha (the texture, not the StatusBar, so the text stays opaque).

  A screenshot per style, then everything put back. Rows change without scrolling (a session
  event refreshes the list, `DamageMeterSessionWindow.lua:193`, 754), and the pooled bars are
  recycled. So the preview records each region it touches with its plain alpha once, then restores
  **every recorded region** (hidden or recycled ones too) and hides every panel of its own. It never
  re-reads the visible rows to restore. The restore is idempotent, and it's also a command,
  `/fp skin meterbars off`, for a procedure stopped half-way.

  Its offline test captures a row, makes that row leave the visible list (hidden and recycled to
  another entry), then runs the cleanup twice. It checks that every captured region has its
  original alpha back and every preview panel is hidden. `LocalPlayerEntry` floats over the
  list and relies on its opaque background (ElvUI forces it back to alpha 1), so the preview leaves
  it alone and the screenshots show why.

## Not in v1

- glass bars, until the owner has seen the preview;
- recoloured header buttons;
- the suite look's tint for Glass UI's skins;
- Edit Mode's settings dialog, which every system shares.
