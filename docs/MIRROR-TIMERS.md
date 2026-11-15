# The breath, fatigue and feign death timers in glass (#184): plan

The owner (2026-11-14), from the EllesmereUI v9.8.6 reference review (wow-ff): Blizzard's mirror
timers in the window template's glass. Two decisions:
- **Glass Unit Frames:** skin Blizzard's timers whenever they show. Glass Unit Frames (#151 there)
  draws its own and hides Blizzard's container while it does, so Blizzard's never show then and
  there is nothing to skin. With its timers off, Blizzard's show and wear the glass. No owner, no
  yield, no change to Glass Unit Frames.
- **The fill:** Blizzard's fill tinted to Glass Unit Frames' colours (its `Mirror.COLORS`), so the
  timers look the same whichever addon draws them. If the tint doesn't hold in game, Blizzard's
  fill stays.

The anatomy is from `wow-ui-source` origin/forever (70938). `MirrorTimerContainer` is a global on
70938 (the API dump, `forever-api-1.60.1.70938.md:32207`).

## Blizzard's timers

`Blizzard_MirrorTimer` (`Mainline/MirrorTimer.xml`, `MirrorTimer.lua`), loaded at startup (no
`LoadOnDemand`).

- **`MirrorTimerContainer`**: an Edit Mode system (`EditModeTimerBarsSystemTemplate`,
  `VerticalLayoutFrame`) under UIParent. It holds three timer frames in `mirrorTimers`, laid out
  top to bottom. Its OnEvent: `MIRROR_TIMER_START` → `SetupTimer` then `SetShown(ShouldShow())`;
  `STOP` → `ClearTimer`; `PAUSE` → `SetPaused`. At `PLAYER_ENTERING_WORLD` it calls `SetupTimer`
  for each running timer (a `/reload` underwater).
- **A timer frame** (`MirrorTimerTemplate`, 206x32, `toplevel`, hidden):
  - `StatusBar` (195x13 at TOP −2): its `OnLoad` lowers its own frame level
    (`LowerFrameLevel(self)`);
  - `TextBorder` (BACKGROUND 0, `ui-castingbar-textbox`): from the bar's top to 14 px under it,
    the box the label sits in;
  - an **unnamed** texture (BACKGROUND 1, `ui-castingbar-background`), around the bar;
  - `Text` (OVERLAY, `GameFontHighlightSmall`): the label ("Breath"), in the 14 px under the bar;
  - `Border` (OVERLAY, `ui-castingbar-frame`), around the bar.
- **`Setup`** (each start) re-applies the fill: `StatusBar:SetStatusBarTexture(MirrorTimerAtlas[timer])`
  (EXHAUSTION and DEATH `ui-castingbar-filling-standard`, BREATH `-applyingcrafting`, FEIGNDEATH
  `-channel`), then the values, `Text:SetText(label)` and `UpdateShownState` (→ `SetShown`).
- **The timer frame's OnShow and OnHide** call `MirrorTimerContainer:Layout()`.
- **Edit Mode** (`EditModeManager.lua`, "Timer Bars"): `SetIsInEditMode` shows all three frames.
  Running timers keep their name, fill and values. `Clear` (a stop) drops the timer and leaves the
  fill as it was: one stopped while Edit Mode shows it stays up as an idle preview.
- **Glass Unit Frames' timers on** (its `Blizzard.HideFrame("MirrorTimerContainer")`): the
  container's events are unregistered and it's hidden. Our hooks never fire in normal play then.
  Its OnShow hook hides the container again only when safe, and that waits while Edit Mode is open:
  Blizzard's frames can stay up through Edit Mode with our glass on them, and go when it closes.
  Glass Unit Frames decides whether Blizzard's are hidden at its load. Its live switch changes only
  its own timers, so Blizzard's follow it after a `/reload` (Codex r1).

## The skin (`Skin\MirrorTimers.lua`, key `mirror`, "Breath and fatigue timers")

`risk = "plain"`, no `defer`, `live = true` (fades, a tint and panels of ours: all restorable).
This is the precedent of the other Edit Mode systems we skin, the tracker and the damage meter.

- **`frames`**: the three timer frames, read from `MirrorTimerContainer.mirrorTimers` (a field
  read, never a write). The engine hooks each one's OnShow, so a timer showing, and every frame in
  Edit Mode, gets styled.
- **`install(kit, f)`**, once per frame:
  - a small glass pill, `kit:Panel(f, "small", PAD, f.TextBorder)`: the bar and the label box
    together, a few px outside them (`PAD`, inward insets, negative). Tuned in game;
  - the pill at the bar's **actual** level − 1, its rim lowered there too (LibGlass makes the rim 10
    up, which would draw over the bar and the label). This is the loot rows' recipe. A bar at level
    0 would leave the pill level with it (the clamp at 0): the probe records the levels;
  - a recessed track: `kit:Section` **on our pill** (never on the timer frame, whose own textures
    are all faded), its fill anchored to the `StatusBar`. The empty part of the bar reads as a
    groove, like Glass Unit Frames' track. Its textures are the pill's (ARTWORK, over the pill's
    body, under the bar's level), so they hide with it;
  - once, for the skin: `hooksecurefunc(MirrorTimerContainer, "SetupTimer", ...)` (instance). This
    runs after every start, including a restart while the frame is already shown, when OnShow
    doesn't fire. It checks `Engine.Active("mirror")` and, under `Engine.Run`, re-tints all three
    frames' fills.
- **`style(kit, f)`**:
  - every Texture among `f:GetRegions()` faded: `TextBorder`, the unnamed background, `Border`.
    These are found by structure (the frame's own regions), never by path. Nothing on the
    `StatusBar` is faded;
  - the fill tinted (`kit:Tint`, desaturated and recoloured). The fill is
    `f.StatusBar:GetStatusBarTexture()` (a getter), and its colour comes from the frame's `timer`
    field (a read): Glass Unit Frames' `Mirror.COLORS`, BREATH blue, EXHAUSTION gold, FEIGNDEATH
    orange, DEATH grey. No timer, or an unknown name: no new tint;
  - kept Blizzard's: the label (font, colour, text), the bar's values, the frames' size, points and
    layout (Edit Mode's).

Never: `SetStatusBarTexture`, `SetStatusBarColor`, `SetSize`, `SetPoint`, a font, a field write, a
mixin method (`GetActiveTimer` included: the timer name is read from the frame's own field).

**Edit Mode keeps the last tint** (Codex r1). Edit Mode resets nothing, and neither does `Clear`.
So an idle preview that ran a timer keeps that timer's colour, one that never ran shows Blizzard's
fill, and a running timer keeps its own. Giving an idle preview Blizzard's fill back would need a
per-texture untint: not worth it for a preview.

**The tint and `Setup`.** `SetStatusBarTexture(atlas)` on each start may reset the fill texture's
desaturation and vertex colour, or hand over a different texture object. The hook re-tints after
`Setup` either way. The post-hook runs in the same Lua call as `Setup`, so no frame should show
Blizzard's colour between them (Codex r1); rendering is the probe's to confirm. `Tint` captures a
texture's desaturation and RGBA once per object and gives them back on `Restore`. It never captures
the atlas, so Blizzard's latest stays. That restore is right only if Blizzard's baseline
(saturated, white) is the same for every timer type and every new object (docs/PLAN.md: Tint on
stable regions). The probe measures whether the same object comes back, whether the colour survives
`SetStatusBarTexture`, and a new object's colour before our tint. **The fallback** if the
tint can't hold (a flash of Blizzard's fill at each start, or the tint dropped mid-timer): no tint,
Blizzard's fill.

**Off and on.** `Restore` gives back the fades and the tint, and hides our pills and tracks. On
again, the engine styles the frames that are shown.

## Tests (`tests\test_mirror.lua`)

The stub: `MirrorTimerContainer` with its three frames, each with the template's regions, levels
and its `StatusBar`. `WoW.mirrorStart(name, label)` and `WoW.mirrorStop(name)` follow
`MirrorTimer.lua` (`Setup`: `SetStatusBarTexture`, then shown), and `WoW.mirrorEditMode(on)` shows
all three, the running timers kept. A stop in Edit Mode leaves an idle preview. Setup shows a frame
only when it's hidden: the client fires no OnShow on a frame already shown (the kit's `Show`
would). The stub's `SetStatusBarTexture` resets the fill's colour and desaturation, the worst case,
or hands over a new texture object (`WoW.mirrorFill`).

The test covers:
- a start styles: three textures faded, the fill tinted BREATH's colour, the pill under the bar;
- a restart while shown re-tints;
- a stop and another timer type re-tint with its colour; two timers at once;
- a new fill object at a restart is tinted, and on `Restore` keeps Blizzard's latest atlas;
- Edit Mode: an empty frame on glass with no tint, its pill under the bar's actual level; a running
  timer keeps its colour; one stopped while Edit Mode shows it keeps its last tint;
- off restores (alpha 1, the colour back, pills hidden), a start while off stays Blizzard's, on
  again restyles; the master switch the same;
- `test_contract` and `test_methods` exercise the timers.

Every new test is mutation-tested (ten mutants, all caught).

## Acceptance (`/fp steps skin mirrorglass`)

1. Script errors on, the blocked-action count reset; Glass Unit Frames' bars off if it's installed
   (they hide Blizzard's: run #338 measured only theirs); `/reload`, then the taint log on (a
   reload turns it off), and the container checked listening for `MIRROR_TIMER_START`.
2. Swim underwater until the breath bar shows. Screenshot. The check: the frame's three textures
   faded, the fill tinted, the pill shown under the bar. Recorded: strata and levels (container,
   frame, bar, pill, rim), the label's layer, the track's parent and layer, the fill object and its
   colour.
3. A restart while shown: surface briefly and dive again before the bar refills, so the frame never
   hides. The probe counts `SetupTimer` calls (a hook of its own) and checks at each poll that the
   frame stayed shown. The same check. At every start, the fill as Blizzard leaves it (the
   baseline), read in a probe hook on the bar's `SetStatusBarTexture`: Setup calls it before it
   shows the frame, so before both of our tint paths (Codex on #186).
4. With the bar partly down (the groove and the fill both visible): screenshot. Ask: does it read
   right?
5. The skin off (Blizzard's look, screenshot), on again.
6. `/reload` underwater: the bar comes back styled (PLAYER_ENTERING_WORLD's `SetupTimer`).
7. Edit Mode with Timer Bars: screenshot. Move the timers and Save, move them again and Revert,
   close. Then into combat and use an ability: no blocked action.
8. Optional: fatigue (swim far out); feign death (a hunter); a dive while in combat.
9. If Glass Unit Frames is installed: its bars on again, `/reload`, dive: only its bars show, none
   of ours (with them off, steps 2-8 were Blizzard's in our glass).
10. Taint log off, `/reload`.

## Review

Codex (`gpt-6-astra`, high), round 1: **consensus** with small corrections, all taken. It found no
contract or taint defect, and kept `risk = "plain"` without `defer`; taint is not claimed as
measured. The corrections: Edit Mode keeps the last tint; Glass Unit Frames' hide waits through
Edit Mode, and its switch takes a `/reload` to change Blizzard's; the section on our pill;
`Engine.Run` around the hook; the lifecycle tests; the taint log on after the reload, a real
restart while shown, the reload underwater, Edit Mode then combat, Glass Unit Frames on and off.

## Not in this

- Glass Unit Frames' own timers (#151 there).
- A per-type colour setting, the label in the accent (the label is information, not a title).
