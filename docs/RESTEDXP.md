# RestedXP's guide window and waypoint arrow in glass (#56): plan

The owner (2026-11-01): "let's do issue 56", with a mockup ("Smoky Quest Guide and Waypoint UI"),
and "ignore questie for now". So this is the RestedXP half of docs/QUEST-TRACKER.md part 3, which it
completes. Questie's tracker stays in #56 for later.

**The mockup:**
- **The guide:**
  - the current step as its own smoky glass card ("Step 13" in gold, the step's icon and text);
  - the window in smoky glass: a header band (the guide's icon, its gold title and subtitle) over a
    hairline;
  - the step list with a hairline between rows, each step number on the right;
  - a slim scroll bar with gold arrows;
  - a footer band (the gold cog, the version in grey).
- **The waypoint:** a glassy arrowhead, with "Step 13 / 1,344 yd" on a smoky pill below it.

**Owner decisions (2026-11-01):**
- **The arrow is our own:** RestedXP's arrow faded, and our arrow drawn at the angle RestedXP gives
  it. That's an audited exception to "never replace", for this third-party arrow only (below). The
  alternative, tinting RestedXP's texture, can't colour the owner's black arrow theme.
- **Its colour is the suite accent** (gold or ice, `Suite.Accent`), not the mockup's blue.
- **Questie is ignored for now.**

Anatomy from RestedXP v4.11.36 (`References\Addons\QuestsLeveling\RXPGuides`, behaviour reference
only, never copied), `RXPGuides\GuideWindow.lua`, `Themes.lua`, `map.lua`, `UI\V2\Core.lua`.
Measured on 70450 (FOREVER-PROBE QS.1-QS.4):
- `RXPFrame` and `RXPG_ARROW` exist at RestedXP's load;
- a theme change brings back the alpha of every backdrop piece (954);
- a new step makes new step frames;
- the arrow turns by `SetRotation`.

The newest API dump is 70532. It changes no function this plan uses.

## Two skins, each with its switch

| Key | Title | `addon` | Frames |
|---|---|---|---|
| `rxp` | RestedXP guide | `RXPGuides` | `RXPFrame` |
| `rxparrow` | RestedXP arrow | `RXPGuides` | `RXPG_ARROW` |

- **Attaching:** the engine attaches when RestedXP has loaded, never otherwise, and it's never a
  dependency.
- **The engine's status gains "not installed"** for a skin whose addon doesn't exist on this client
  (`C_AddOns.DoesAddOnExist`, as Suite's `presence`): "on (RXPGuides not installed)". Before, it
  said "on (waits for RXPGuides)" forever.
- **Not secure:** none of these frames is secure (no SecureActionButton in the window, the cards or
  the arrow). Secure buttons live in `RXPItemFrame` and `RXPTargetFrame`, which are out of scope and
  never touched. So there's no `defer` and no combat wait: a pass may run in combat, touching only
  alpha, colours and our own frames.
- **The contract, as part 3 states it:** on RestedXP's objects, getters, `SetAlpha` (held, with
  read-back), `SetVertexColor`/`SetDesaturated` on textures, `HookScript`, and `hooksecurefunc` on
  a frame instance's own function field (as on `GameMenuFrame.InitButtons`).
  - Never call RestedXP's functions. Never write its fields or saved variables. Never reach its
    private table (`AceAddon:GetAddon`). Never move, resize, show or hide its frames.
  - **Reading** a field of its frames (`framePool`, `.texture`, `.text`, `orientation`) is a read,
    like Blizzard's `emptyBackgroundAtlas`.

## Only RestedXP's default window ("V1")

RestedXP's beta "V2" interface (`enableBetaFeatures` + `enableV2Interface`, off by default) hides
every V1 child and builds AceGUI windows of its own (`RXPV2GuideWindow`, active-step cards). The
mockup is V1, so this skins V1 only.
- **Under V2, the guide skin shows nothing:** our window glass is a child of `GuideName`, which V2
  hides (with `BottomFrame`, `Footer` and `CurrentStepFrame`, `UI\V2\Core.lua`). V2's frames are
  never touched.
- **The arrow skin still shows under V2:** V2 keeps `RXPG_ARROW` and only sets its texture
  (`map.lua`), which our arrow covers the same way.
- The probe records which interface is on.

## The guide window (`rxp`)

`RXPFrame` (BACKGROUND strata, movable, resizable) holds:
- `GuideName`, the header (level 6): `.bg` banner, `.text`, `.icon`, `.classIcon`;
- `BottomFrame`, the list box, holding the scroll frame. The scroll frame and its child are fields
  of `RXPFrame`: `RXPFrame.ScrollFrame` (UIPanelScrollFrameTemplate) and `RXPFrame.ScrollChild`,
  whose `framePool` holds the rows (its children also include `f1`, RestedXP's measuring frame);
- `Footer` (level 6): `.bg` banner, the version text, the resize grabber;
- the cog (`RXPFrameCogwheel`);
- `CurrentStepFrame`, the current step's cards.

**Placing:** `BottomFrame` fills `RXPFrame` (3 px in, 14 px off its bottom), `GuideName` sits above
it overlapping it by 9 px, and `Footer` is along `RXPFrame`'s bottom. **V1 hides `BottomFrame`**
when the list is collapsed (shorter than 30 px) or the guide has `hidewindow`, while the header and
footer stay.

`GuideName`, `BottomFrame` and `Footer` are `BackdropTemplate` frames. Two global names clash
(`RXPFrameGuideName` is the Footer's), so every piece is reached by **field**, never by global.

| Piece | Art | The skin |
|---|---|---|
| The window glass | none | `kit:Panel` parented to `GuideName`, which survives V1's collapse and is hidden by V2. Its level is set below the lowest of `GuideName`, `BottomFrame` and `Footer` (its rim `g.top` lowered with it), and our own anchors run from `GuideName`'s TOPLEFT to `Footer`'s BOTTOMRIGHT, so it follows a resize and shrinks with a collapse. The window floor (smoked backing) |
| `GuideName`, `BottomFrame`, `Footer` backdrops | the theme's (9 pieces: `TopLeftCorner` … `Center`) | each piece faded and held (`Fade` hooks SetAlpha). Hooks catch RestedXP's re-sets; the theme's re-apply is caught below |
| `GuideName.bg`, `Footer.bg` | banners | faded |
| The header band | none | `kit:Header` from the glass's top down to `GuideName`'s BOTTOM (the header's visible edge; it overlaps the list by 9 px), plus our hairline there (SECTION_EDGE) |
| The footer band | none | our hairline along `Footer`'s TOP |
| The guide's icon, class icon, title, cog, version, resize grabber | | RestedXP's |
| The scroll bar | RestedXP's own textures, re-set by its `UpdateScrollBar` on every theme | RestedXP's, on a recessed track pane of ours (`kit:Section` on a host of ours parented to `BottomFrame`, round the scroll bar, so it hides with the list) |
| List rows (`RXPFrame.ScrollChild.framePool`: one `BackdropTemplate` frame per step, pooled; read from the pool, never `GetChildren`) | a `Center` fill whose colour RestedXP swaps on hover; **the row's own alpha is RestedXP's state** (0.66 building, 1 current, 0.5 done or skipped, 0 hidden) | each row's backdrop pieces faded (texture alpha, never the row's alpha), and a hairline of ours along its bottom on a host frame of ours parented to the row (so it fades with the row's state, and hides with it). The text, icons and step number are RestedXP's |
| Current-step cards (`CurrentStepFrame`'s children, pooled; tip cards stay its children, anchored to UIParent at MEDIUM strata) | each a `BackdropTemplate` card with a `.number` tab (also a backdrop) | each card's pieces and its tab's pieces faded; our smoky glass panel (window floor, small) parented to the card at its level − 1, round it. "Step N", the rows, check buttons and highlight are RestedXP's |

**When the pass runs:**
- the window's OnShow (the engine);
- **a frame after** each of these instance functions, hooked with `hooksecurefunc` on the frame
  that owns the field:
  - `RXPFrame.UpdateVisuals`: a theme applied, which re-runs `SetBackdrop`;
  - `BottomFrame.UpdateFrame`: the list laid out (also every frame while the window is resized);
  - `CurrentStepFrame.UpdateText`: the cards filled.
- **The hook only queues:** one pass per frame at most, however many calls come. It's checked
  against `Engine.Active` and the skin's generation (`Engine.Defer`).
  - **What's queued is a generation,** not a flag: `queued` holds the generation the pass was
    queued in, and a hook queues again when it isn't the current one. `Engine.Defer` drops a
    callback whose generation went stale (the switch turned off, or the master switch, before the
    next frame), so a bare flag would stay set and block every later pass. A stale entry never
    matches the new generation, so the restore has nothing to clear.
- **The pass is idempotent:**
  - it calls `kit:Fade` on every backdrop piece it finds, every pass: the kit captures and hooks a
    region once, and reasserts and reads back its alpha each time. That reassertion is what holds
    the fade after RestedXP's `SetBackdrop`, which reuses the pieces (`NineSlice`) and only sets
    their textures and vertex colours, never their alpha (Blizzard's `Backdrop.lua`); QS.2 measured
    the alpha coming back, so the pass after `UpdateVisuals` covers it whatever the mechanism.
    `ClearBackdrop` sets each piece's texture to nil and neither hides nor releases it;
  - our row hosts and card glass are made once per pooled frame, kept in weak tables;
  - it never walks into RestedXP's item or target frames.

**Restore** (the switch off): the kit's restore gives back every alpha. Our window glass, cards'
glass and row hosts hide.

## The waypoint arrow (`rxparrow`): our own

**The audited exception** goes into docs/PLAN.md, "The skin contract": *for RestedXP's waypoint arrow
only (#56, the owner, 2026-11-01), Glass UI draws its own arrow over RestedXP's faded one, at the
angle RestedXP sets.*
- RestedXP still owns everything else: where the arrow is, whether it shows, its rotation, its
  distance and text, and dragging it.
- Our arrow only mirrors the rotation; nothing of RestedXP's is driven.

`RXPG_ARROW` is a plain frame on UIParent, 32 × 32 × its scale. It holds:
- `.texture`, the arrow, set by RestedXP's `UpdateVisuals` (`SetTexture` only, never its alpha or
  colour);
- `.text`, "title\n(N yd)", below the arrow.

RestedXP turns the arrow from its OnUpdate (`DrawArrow`) through `texture:SetRotation(rad)`, when the
angle moves more than π/64. It hides the arrow with the frame's own alpha when there's no position.

| Piece | The skin |
|---|---|
| `.texture` | faded and held (RestedXP never sets its alpha) |
| Our arrow | a frame of ours parented to `RXPG_ARROW` (one level up), holding our texture set to the arrow texture's points. `Media\Arrow.tga` (white, its shading in the image), tinted by `SetVertexColor` with `Suite.Accent()` (gold {1, 0.82, 0} by default, or ice), repainted on `Theme.OnRefresh` |
| The rotation | `hooksecurefunc(texture, "SetRotation", fn)` copies the angle to our texture, **synchronously**. RestedXP's OnUpdate isn't a secure path, the hook touches only our texture, and a frame's lag would show as a stutter. Gated by `Engine.Active`. At install and each pass it reads the current angle with `texture:GetRotation()` (`SimpleTextureBaseAPI`, in the dump) |
| Hidden / shown | ours is a child of `RXPG_ARROW`: it follows RestedXP's frame alpha and visibility |
| `.text` | RestedXP's (its font and colours) |
| The pill | a frame of ours parented to `RXPG_ARROW`, **one level below it**, its glass rim `g.top` lowered to the pill's level too (LibGlass puts it at +10, `Loot.lua`'s fix), so the text, a region of `RXPG_ARROW`, draws over all of it. Small glass on the window floor, round the text with padding. Sized from `.text:GetStringWidth()`/`GetStringHeight()`: on install and each re-enable, and queued a frame after the text instance's `SetText` and `SetFont` (RestedXP's arrow text size setting calls only `SetFont`, and standing still never calls `SetText`) |

**Our art:** `Tools\make_media.py`, written here (PIL), generates `Media\Arrow.tga` (64 × 64),
never edited by hand:
- the mockup's arrowhead: a chevron with a notched base;
- white with a soft vertical shading in its RGB (lighter at the top), so the accent tint keeps the
  gloss;
- a 1 px darker inner edge, and its shape in alpha.

It's NodeRadar's recipe (`NodeRadar\Tools\make_media.py`), as an idea only: no file is copied.

**Restore:** our arrow and pill hide, and RestedXP's texture alpha comes back. The rotation, text
and font hooks stay, gated.

**What the mockup gets, and doesn't:** the smoky surfaces, the bands, the hairlines, the cards on
glass and our arrow. RestedXP's theme keeps its own colours and art for the titles, the cog, the
scroll bar's arrows and the text formatting, so the mockup's gold titles and typography come only
when the theme has them. The audited exception stays the arrow alone.

## The probe (`/fp steps skin rxpglass`), run after launch (2026-11-04)

The beta is closed, so no in-game run is possible before launch. The procedure is ready for launch
day:
1. RestedXP on for this character (as `questing` does, its state saved and restored); a guide loaded.
2. **The window:**
   - every backdrop piece faded;
   - our glass shown round the header, list and footer;
   - the cards on glass;
   - row hairlines.
   - A screenshot, to judge against the mockup.
   - **The list collapsed and expanded** (RestedXP's list toggle), and a `hidewindow` guide if one
     is at hand: the glass shrinks to the header and footer and grows back; the scroll track hides
     with the list.
3. **A step completed and a new one:**
   - the new row and card styled a frame later;
   - a done row's alpha 0.5 is RestedXP's.
4. **RestedXP's theme changed and back:** every piece faded again (QS.2's 954 brought back
   otherwise). **A row hovered and left:** its pieces still faded.
5. **The window resized while scrolling:** no error, and one pass per frame at most.
6. **The arrow:**
   - RestedXP's texture faded;
   - ours shown, its rotation equal to RestedXP's after turning (read through `GetRotation` on both);
   - accent gold, then ice, then gold;
   - the pill round the text as the distance changes, and after RestedXP's arrow text size is
     changed while standing still;
   - off the waypoint's continent: both rotations 0; with no position: the frame's alpha 0 hides
     ours too.
   - A screenshot.
7. **Off and on for each skin;** a `/reload`; in combat (the window and arrow live).
8. **V2 on** (if the owner wants to try it): nothing of the guide skin shows; our arrow still does.
   Then V2 off again.

## Tests

`test_rxp.lua`, on stubs built from the anatomy above (`WoW.makeRestedXP`). RestedXP's objects
are under the same contract record as Blizzard's: its function fields and the Backdrop mixin's
methods are Lua methods (a call from our code is recorded), a field we write is caught, and the
methods we call on them are recorded apart (`WoW.rxpCalls`). RestedXP's own side re-snapshots its
objects after each of its steps (it makes pieces, rows and cards as it goes), keeping what our code
changed before.
- **Attaching:** only after `RXPGuides` loads; not installed shows "not installed".
- **The window:**
  - every backdrop piece faded and held through a `SetBackdrop`-like reset: the same piece
    regions reused, their texture and vertex colour set, then the pass reasserting the alpha;
  - the glass's parent (`GuideName`), anchors and level, and its rim's level;
  - `BottomFrame` hidden (collapse): the glass still shown, the scroll track hidden;
  - the band and the hairlines;
  - the scroll track pane.
- **Rows:**
  - pieces faded, the row's own alpha untouched;
  - one host each across pool reuse.
- **Cards:** pieces and tab faded, one glass each, across reuse from an ordinary card to a tip
  and back.
- **Hooks:** `UpdateVisuals`, `UpdateFrame`, `UpdateText` each queue one pass a frame later, and
  many calls in a frame make one pass.
  - **Queue, off, on:** a pass queued, the skin (then the master switch) turned off before the next
    frame, the callback dropped, the skin on again: the next step's hook still queues and runs a
    pass.
- **V2:** `GuideName` hidden hides our glass; the arrow skin is unaffected.
- **The arrow:**
  - texture faded, ours rotated with each `SetRotation`;
  - the start angle read;
  - accent repaint;
  - the pill and its rim a level below, sized on install, after `SetText`, and after `SetFont`
    with the text unchanged;
  - restored.
- **Never:** a call to RestedXP's function fields from our code, a field written, a show, hide, move
  or resize of RestedXP's frames.
- `test_contract` and `test_methods` include both skins.

Mutation-tested.
