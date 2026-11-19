# Light quest text on glass: a switch for Blizzard's Dark quest text (#203): plan

**Status (2026-11-19):** built (`QuestText.lua`, the settings page's Quest text section,
`/glassui questtext`), tested offline (`tests/test_questtext.lua`, mutation-tested; `test_contract`,
`test_methods`). The in-game run, `/fp steps skin questtext`, waits for the owner
(docs/FOREVER-PROBE.md, QT). Both scopes are built, chosen at runtime from `GetCVarInfo`: one record
account-wide, or one per character if the client stores the setting per character.

Stage 2 of docs/GOSSIP-QUEST.md. Stage 1 (#201, accepted on 70938) keeps the parchment page and
Blizzard's dark text in the gossip window and the quest dialog. The skins fade the page only while
Blizzard itself shows its dark one: Settings, Accessibility, **Quest Text Contrast: Dark**
(`questTextContrast` = 4), where Blizzard draws its light "Stone" text. Stage 2 gives Glass UI a
switch that turns that setting on for the player.

## Owner decisions

- 2026-11-16: "We can be flexible on that rule with a proper setting to have the option."
- 2026-11-19: **a switch**, not a one-time button. On, it sets Dark and remembers the value it
  replaced. It re-applies Dark at login if the client dropped it. If the player changes the setting
  themselves, it lets go and turns itself off. Off, it restores the previous value, only while the
  setting is still Dark.
- Our own text colours (`kit:TextColor` on quest text) stay rejected: docs/GOSSIP-QUEST.md, stage 2,
  option 2.

## What the setting is (wow-ui-source origin/forever 70938; API dump 70959)

- `questTextContrast`: 0 default parchment, 1-3 lighter parchments (dark text), 4 dark parchment
  with light text (`QuestTextContrast.lua:3-22`). Blizzard's control is a proxy setting
  (`PROXY_QUEST_TEXT_CONTRAST`) whose setter is the plain global `SetCVar(cvarName, value)`
  (`Blizzard_SettingsDefinitions_Shared/Mainline/Text.lua:17-53`). It registers only when
  `C_CVar.GetCVar` knows the CVar.
- Its readers, all Blizzard's:
  - the gossip window (a `UIThemeContainerFrame` that listens to `CVAR_UPDATE` while shown, and
    re-colours at once);
  - the quest dialog and QuestInfo (at each panel's show);
  - books and letters (`ItemTextFrame.lua:57, 143`);
  - the quest details popup (`QuestMapFrame.lua:2622`);
  - the world map's quest details (`QuestMapFrame.lua:971`, its own `QuestDetailsBackgrounds-*`
    atlases);
  - the settings preview.

  So the switch changes all of them, not only what Glass UI skins. The control says so.
- `C_CVar.GetCVar`, `C_CVar.SetCVar` (returns `success`), `C_CVar.GetCVarInfo` (value, default,
  `isStoredServerAccount`, `isStoredServerCharacter`, `isLockedFromUser`, `isSecure`, `isReadOnly`)
  and `CVAR_UPDATE` (`eventName`, `value`) exist on 70959.
- **Persistence is not known.** The porting guide measured that a CVar an addon wrote didn't
  survive a full client exit on 69913 (AltStable #33), and that hasn't been re-measured since
  SavedVariables were fixed (70009). That CVar may have been the addon's own, which the client never
  saves, unlike a Blizzard setting. `GetCVarInfo`'s storage flags and a full exit settle it for this
  one.
- Sibling precedent: GlassChat (`showTimestamps`, remembers and restores only while still its value),
  Glass Unit Frames (`showSwingTimer`), Glass Action Bars (the lock) and GlassMail (`blockTrades`, a
  write that held only on read-back) already write Blizzard CVars from addon code. No taint has been
  reported from them.

## The design

### State (`GlassUIDB`, sparse)

- `questText = { was = "<value>" }` while the switch is on, absent while off (the default). `was` is
  the setting's value when the switch went from off to on, as a string, read through `API.Plain`.
- **If the probe finds the CVar stored per character** (`isStoredServerCharacter`), the record is
  per character instead: `questText[<GUID>] = { was = ... }` (the GUID, as AltStable keys
  per-character state). Then the switch, its `was`, the login check and the restore all belong to the
  character they were made on. Another character starts with the switch off and is never taken over
  (Codex r1: one account-wide `was` can't restore two characters). Account-wide or local storage
  keeps the single record. The probe's first measurement decides which before code.

### One writer

`QuestText.Write(v)` is the only code in Glass UI that writes a CVar, and the only CVar it writes is
`questTextContrast`.
- It never writes in combat (`InCombatLockdown()`).
- Out of combat it calls `pcall(C_CVar.SetCVar, "questTextContrast", v)` and reads back with
  `C_CVar.GetCVar`.
- It succeeds only when the call returned success and the read-back is `v` (GlassMail's rule).
- A failure is recorded (`API.Fail("questtext", ...)`) and returned to the caller, which says what
  happened.

Its triggers are exactly three: the player's On, Off's conditional restore, and the login re-apply
below. Never a hook, a skin pass or a switch of the skins.

### Recognising someone else's change

`CVAR_UPDATE` is a synchronous event in Blizzard's documentation (`ConsoleDocumentation.lua:174-182`),
and Blizzard's own setter guards against re-entry. But the client's dispatch isn't visible in Lua,
so the probe confirms it.

The rule rests on one invariant: **while the switch is on, Glass UI only ever writes 4.** On and the
re-apply write 4, and Off clears the record before it writes `was` back. So, on a `CVAR_UPDATE`
naming the CVar (compared case-insensitively), with the switch on, the startup decision made and no
re-apply pending:
- **the event's value, if usable, isn't 4:** someone else changed it. Let go, even if the live value
  is already back to 4 (another listener answering their write, Codex r3);
- **otherwise the live value, if usable, isn't 4:** let go;
- **otherwise** (both 4, or nothing usable): nothing.

**While a re-apply is pending** (waiting for combat to end), we know we haven't written Dark yet. So
any `CVAR_UPDATE` with a usable value or a usable live read is someone else's choice, Dark included
(Codex r3: 0 to 4 chosen by the player during the wait). Let go and cancel the re-apply.

This holds only if the event arrives during the call that caused it (synchronous delivery). The
probe measures that. If it can arrive late, a late event from Off's restore after a fresh On would
let go wrongly, and the design goes back for review.

### On (the player's click or `/glassui questtext on`)

- Already on: nothing. `was` is captured only on the transition from off to on (Codex r1: a second
  On would otherwise save 4 over the player's value).
- In combat: refused, with a line saying to try again out of combat. No queued write.
- Before the startup decision: refused the same way ("a moment after login"). This is a narrow
  window, and Off has the same rule.
- Read the current value. Nothing usable (nil, a secret): refuse and record it.
- Already 4: save `{ was = "4" }` and write nothing. Off will then restore nothing, since Dark was
  the player's own choice.
- Otherwise, **claim before writing** (Codex r4, the mirror of Off releasing first):
  1. save `{ was = current }`;
  2. write 4. While the write runs, the switch is on, so a nested event from another listener
     changing it (2, then back to 4) lets go as usual and clears the record;
  3. after the write, if the record was cleared meanwhile, keep it cleared and say the setting was
     changed during the switch;
  4. if the write failed, clear the record; the switch stays off and the line says why.

### Off (the click or `/glassui questtext off`)

- Already off: nothing.
- In combat: refused, as on.
- Before the startup decision: refused, with the record kept (Codex r2). Until the stored value is
  known, an early read could be the default and the restore would be skipped and `was` lost.
- Otherwise, read the live value first (Codex r3). Nothing usable: refuse, with the record kept. Then,
  in this order (Codex r2):
  1. capture `was` locally;
  2. clear the record and any pending re-apply, so our own restore's `CVAR_UPDATE` finds the switch
     already off and can't announce an outside change;
  3. if that live value is 4 and `was` isn't 4, write `was` back;
  4. if that write is refused, say what the setting actually reads (Dark, or a third value);
  5. otherwise (the player or another addon changed it), restore nothing.

### Letting go

As above: the switch is on and a `CVAR_UPDATE` says someone else changed it. Then:
- clear the record;
- cancel a pending login re-apply;
- say once: "Light quest text is off: Quest Text Contrast was changed";
- refresh the checkbox.

Nothing is written: their choice stands.

### Startup: one decision, once the setting is known

Server-stored CVars may arrive after `PLAYER_LOGIN`. Blizzard checks `C_CVar.AreCVarsLoaded()` and
otherwise waits for `VARIABLES_LOADED` (`EventUtil.lua:44`; Codex r1). So:
- **The decision** runs once per UI load, as soon as both `GlassUIDB` is loaded (`ADDON_LOADED`) and
  the CVars are (`AreCVarsLoaded()` true, or at `VARIABLES_LOADED`). Letting go is armed only after
  it. An early `CVAR_UPDATE` from the stored value arriving can't clear the switch, and we never
  write before we know the stored value.
- **With the switch on and the live value not 4:**
  - **It reads the CVar's default** (`C_CVar.GetCVarDefault`): what a dropped value reads. The
    client lost it (no persistence), so it is re-applied: write 4. Out of combat, in this order
    (Codex r5): mark the decision made and arm letting go, consuming the event that triggered a
    retry if one did, then write. A nested change by another listener during this write then lets
    go, as during On. In combat (a reload in combat),
    the write waits for `PLAYER_REGEN_ENABLED`. Letting go in between cancels it. At combat's end,
    in this order (Codex r4):
    1. check again that the switch is still on, the live value is still the default and we're out
       of combat. A live value that can't be read ends the wait like a failed re-apply (Codex r5):
       the record cleared, the control refreshed, the line saying the setting couldn't be read;
    2. clear the pending flag, keeping the record, so our own write's event meets the ordinary owned
       rule (4: nothing), not the pending one (anything: let go);
    3. write 4.
  - **Anything else** (1, 2, 3): a choice made while Glass UI wasn't watching. It lets go, writes
    nothing, and says so once.
  - The one case it can't tell apart: the player picked the default itself while Glass UI wasn't
    loaded. The switch re-applies Dark there, and the control's text says the switch keeps Dark on
    until it's turned off.
- **Usable reads first** (Codex r2): `GetCVar` and `GetCVarDefault` may return nothing, and so may
  `UnitGUID` (per-character records). The decision needs all of its reads plain and usable. Until
  they are, it waits: the record is kept, letting go stays unarmed, and it's tried again at the
  next `CVAR_UPDATE` for the CVar and at `PLAYER_ENTERING_WORLD`. Two missing reads never compare
  equal as "the default".
- **A re-apply that fails** clears the record, refreshes the checkbox and says what the setting reads
  (Codex r1). The switch never claims a state the setting doesn't have.
- **The probe settles whether the re-apply happens at all:** if Blizzard's own value survives a full
  exit, a dropped value is rare. The rule stays, and costs nothing then.

### What it doesn't touch

- The skins' switches and the master switch never touch the setting. It's the player's setting, not
  a skin's look. With the gossip and quest skins off, Dark just shows Blizzard's dark parchment.
- No Blizzard function, Settings object or proxy setting is called: `Settings.SetValue` would run
  Blizzard's Lua from our call. Only `C_CVar.SetCVar`, which is what Blizzard's own setter ends in
  (`Text.lua:28-30`).
- Uninstalling can't run a restore. The tooltip says: "Turn this off before uninstalling to restore
  your previous setting."

### The control

- The settings page gets a "Quest text" section after "Raid frames": a checkbox, **Light quest text
  on glass**, with a grey line under it: "Turns on Blizzard's Dark quest text (Settings >
  Accessibility) and keeps it on until you turn this off. It also changes books, the quest details
  popup and the map's quest details." The tooltip carries the uninstall line.
- The checkbox reflects the record. It's refreshed after every click or slash result, refusals
  included, on letting go, and after a failed write (Codex r2).
- A re-apply waiting for combat to end shows as such: the checkbox stays on, and its grey line and
  `/glassui skins` say "on, waiting for combat to end" (Codex r2).
- `/glassui questtext on|off` (the help writes "on or off": the bare-`|` finding). `/glassui skins`
  shows its state on a line of its own.

### Blizzard's side after a write (Codex r1, read in the source)

- **The Settings panel:** its `CVAR_UPDATE` handler looks up a setting named exactly
  `questTextContrast` and finds none, since the dropdown is the proxy `PROXY_QUEST_TEXT_CONTRAST`
  (`Blizzard_SettingsPanel.lua:117-123`). So a dropdown already open may show the old value until it
  is reopened. Its getter reads the live CVar. The gossip `UpdateScrollBox` callback on the proxy
  (`GossipFrame.lua:54-57`) doesn't run from our write. A shown gossip window updates through its own
  `CVAR_UPDATE` handler (fonts, rows' colours, the page).
- **The quest dialog:** an open quest panel keeps its page and colours until Blizzard refreshes it
  (stage 1's finding). Then the light text and the faded dark page come together.
- **Books:** `ParchmentLarge` keeps its `Book-bg` page even when the text turns Stone
  (`ItemTextFrame.lua:55-61, 137-152`). That's Blizzard's own Dark mode, compared against stock in
  the probe.

### Taint

`C_CVar.SetCVar` from addon code fires `CVAR_UPDATE` to every listener, and they may run with our
taint. Read in the source (Codex r1):
- no taint defect shown in the direct setter, the Settings lookup or gossip's recolour;
- **one protected path is reachable:** the status-tracking manager handles every `CVAR_UPDATE`
  (`StatusTrackingManager.lua:17-27, 174-191`). If a displayed bar changes, its show-state path can
  ask Edit Mode to update the bottom action bars, which calls `ClearAllPoints`/`SetPoint` on them
  (`EditModeManager.lua:64-73, 692-706`). This CVar doesn't change which bars show, so that path
  shouldn't run, but that has to be measured.

The guards: writes only out of combat, only from the three triggers. The probe checks afterwards:
- a login (re-apply) and a status-bar change (an XP or reputation gain), then action bars in combat;
- Edit Mode;
- Blizzard's settings;
- `Logs\taint.log` read for Glass UI.

## The audited exception (docs/PLAN.md)

A new item under the skin contract: **Glass UI changes one Blizzard setting, `questTextContrast`,
and only through `QuestText.Write`.**
- Its three triggers: the player's On, Off's conditional restore, and the login re-apply of a dropped
  value.
- Never in combat.
- `test_contract` checks, over the shipped Glass UI code (not the developer probe, which writes
  `taintLog`):
  - no `SetCVar` call outside `QuestText.Write`;
  - the CVar's name written once, as a shared constant (reads and the event comparison use it);
  - every captured setter call in the exercise targets exactly `questTextContrast`. A writer mutated
    to another name fails (Codex r2).

## The probe (`/fp steps skin questtext`)

**Your own setting comes back** (Codex r3): the run saves Quest Text Contrast at its first step with
stage 1's snapshot (`SkinProbeDB.gqContrastWas`, kept across a stopped run), turns the switch off and
restores it at its end, and `/fp skin gqrestore` does the same by hand. The helpers get stricter
(Codex r4), for stage 1's procedure too:
- the snapshot step fails, and the run doesn't go on, unless a usable value was saved;
- the restore drops the snapshot only once the live value reads back as the saved one. Otherwise it
  keeps it, so both the run's last step and `/fp skin gqrestore` can be tried again.

**Measured first, with the switch off** (no writer involved: the startup measurement is passive):
1. `GetCVarInfo("questTextContrast")`: value, default, the storage flags, locked, secure,
   read-only. **Secure, locked or read-only stops the work:** the plan goes back for review. The
   storage flags pick the record's scope (above).
2. At each of `ADDON_LOADED` (ours), `VARIABLES_LOADED`, `PLAYER_LOGIN` and
   `PLAYER_ENTERING_WORLD`: `AreCVarsLoaded()`, the value, and every `CVAR_UPDATE` for the CVar, in
   order, up to the first settled read after login.
   - SkinProbe loads after Glass UI (`OptionalDeps: GlassUI`) and would miss our `ADDON_LOADED`
     (Codex r2). So Glass UI keeps these samples itself: a small in-memory trace,
     `QuestText.trace`, never saved, with the event, the DB's record, `AreCVarsLoaded`, the live
     value, the GUID if relevant, and whether the decision ran. The probe reads it after login.
   - The value at the decision point is compared with the settled read after login. If they differ,
     the startup gate goes back for review before the re-apply is enabled.
3. Persistence, each with a **full client exit** and relaunch (and a `/reload` as the control):
   - a value written by addon code (the probe writes 2);
   - a value chosen in Blizzard's settings (3).

   That tells an early default from a value really dropped.
4. The setter boundary, with the switch: the order of before the call, `CVAR_UPDATE` (its name,
   value, and the live read-back inside it), and after the return. For On, Off's restore, and a
   quick Off then On.
   - If the event can arrive after the call returns (not synchronously), the design goes back for
     review (above).
   - Nested delivery (Codex r3): a probe listener that writes 4 as soon as it sees 2, then the
     player picks 2 in Blizzard's settings. Recorded at Glass UI's handler: the event's value and
     the live value. The switch must let go: the event says 2 even though the live value is 4.

**Acceptance** (taint log on, script errors on, blocked actions counted):
1. The switch on with the gossip window open (an NPC with the ordinary parchment, not a texture kit
   of its own, which keeps its page even in Dark): its text light on glass at once, the page faded. With
   a quest panel open: its page and text unchanged until the next panel, then light on glass
   together. Blizzard's settings dropdown: read while already open, and after reopening it.
   Screenshots.
2. A book or letter, the quest details popup and the map's details: Blizzard's Dark versions,
   compared with stock Dark (the same thing). Screenshots.
3. Changed in Blizzard's settings (to 2): the switch turns itself off, the message once, the
   checkbox clear, nothing written back.
4. On, `/glassui questtext on` again, off: the first value back (Codex r1's sequence). On while
   already Dark, then off: Dark kept.
5. The click in combat: refused, nothing changes. After combat: works.
6. A `/reload`, and a full exit with the switch on (measurement 3 with the switch): the re-apply only
   if the value was dropped.
7. After the writes: an XP or reputation gain (the status bars), Edit Mode, Blizzard's settings
   (another option changed), action bars in combat. Nothing blocked; `taint.log` read for Glass UI.
8. Ask: does it read right?

## Tests (`tests/test_questtext.lua`)

The stub: `C_CVar` with a value, a default, `AreCVarsLoaded`, a `success` result and a refusing mode
(false, or a read-back that differs), and `CVAR_UPDATE` fired on each write, synchronously or a
frame late (both modes). Checks:
- **On and Off:**
  - on from 0: 4 written, `was = "0"`; off: 0 back;
  - on from 2, on again (slash and click), off: 2 back (Codex r1);
  - on while 4: nothing written, `was = "4"`; off: nothing written;
  - off after an outside change (2): nothing written.
- **Letting go:**
  - the setting changed elsewhere to 2: the record cleared, the message once, nothing written;
  - a `CVAR_UPDATE` for another CVar, or with both its value and the live value 4, changes nothing;
  - our own write's event never lets go;
  - Off's own restore: no "was changed" message (the record is cleared first);
  - an event saying 2 while the live value is already back to 4 (another listener answered): lets go
    (Codex r3);
  - an event with nothing usable in it and an unusable live read: nothing;
  - another listener going 2 then 4 inside On's own write: the record cleared, the switch off, the
    line; a later Off writes nothing (Codex r4). The same inside the login re-apply's write
    (Codex r5).
- **Startup:**
  - before the CVars are loaded: no decision and no let-go;
  - an early `CVAR_UPDATE` (the stored value arriving) never clears the switch;
  - the decision at `VARIABLES_LOADED` or at once if already loaded.
  - With the switch on: the default read gives one write of 4; 2 read lets go with no write; 4 read
    does nothing.
  - In combat: written at `PLAYER_REGEN_ENABLED`, checked again just before. Then Off restores `was`
    with no "was changed" message: our own write's event didn't let go (Codex r4). An outside change to 2
    in between: the switch off, no write (Codex r1). The player picking Dark (0 to 4) in between: the
    switch off, no write at combat's end, and a later Off writes nothing; 4 stays (Codex r3).
    Meanwhile the checkbox and `/glassui skins` say it's waiting. A default readable at startup but
    nil at combat's end: no write, the wait ended, the switch off (Codex r5).
  - Ready, but a read not usable yet (nil value, nil default, nil GUID): the record kept, no
    decision, no let-go; decided at the next try once usable (Codex r2).
  - Off and On before the decision: refused, the record kept; Off after it restores `was`
    (Codex r2's sequence: `was = "2"`, an early 0, the stored 4 arriving).
  - A failed re-apply: the record cleared, the checkbox refreshed, the line.
- **Refusals and failures:**
  - in combat, on and off are refused: no write, state unchanged;
  - Off with an unusable live read: refused, the record kept; then a usable 4 and Off restores
    `was` (Codex r3);
  - a refused write on On (false; a read-back that differs): the switch stays off, recorded. On Off:
    the switch off, the setting left, recorded.
- **Per-character records** (if the probe picks them): character B starts off, and nothing is
  written on B's login; B's Off never restores A's value.
- **Elsewhere:**
  - the skins' switches and the master switch: no write;
  - the control and `/glassui questtext`;
  - `test_contract`: the contract above (no `SetCVar` outside `QuestText.Write`, the name as one
    shared constant, every setter call aimed at `questTextContrast`);
  - `test_methods`.

Mutation-tested.

## Not in this

- Our own text colours.
- The required-money lines, which stay black in Blizzard's own Dark mode (#201: not seen in game).
- The popup's skin (#202).

## Review

Codex (`gpt-6.2-astra`, high), round 1: **no consensus**. Taken:
- the BLOCKERs: On captures `was` only from off to on (a second On kept 4 over the player's value);
  the startup decision waits for `AreCVarsLoaded`/`VARIABLES_LOADED` and arms letting go after it,
  re-applying only a dropped (default) value; per-character records if the CVar is stored per
  character;
- the SHOULDs: a failed or combat-deferred re-apply (cleared on failure, re-checked before writing,
  cancelled by letting go); letting go on the live value, not a busy flag; the Settings panel's real
  behaviour (the proxy isn't updated by a raw write); the status-tracking manager's path to the action
  bars, measured; a passive startup measurement, read-only as a stop condition; the open quest
  panel's acceptance; books against stock Dark;
- the NIT: the exception's three triggers, `test_contract` on the literal name over shipped code, the
  uninstall line.

Round 2: **no consensus**. Taken:
- the BLOCKER: Off is refused before the startup decision, with the record kept;
- the SHOULDs:
  - Off releases the claim before its restore;
  - the decision waits for usable reads;
  - a pending combat re-apply shows as waiting;
  - the startup trace is kept by Glass UI itself (the probe loads too late to see our
    `ADDON_LOADED`);
  - `test_contract` asserts the setter's target;
  - the 4, 2, 4 case decides whether a deferred event sends the design back.

Round 3: **no consensus**. Taken:
- the BLOCKER: a pending re-apply lets go on any outside change, Dark included;
- the SHOULDs:
  - letting go also reads the event's own value: the switch on means we only ever write 4, which
    covers nested delivery, and the probe measures it;
  - Off and the event handler need a usable read before dropping `was`;
  - the probe restores the tester's own setting (stage 1's snapshot);
- the NIT: the test checklist points at the revised contract.

Round 4: **no consensus**. Taken:
- the BLOCKER: at combat's end the pending flag is cleared before the write;
- the SHOULDs:
  - On claims the switch before writing, so a nested change during its write lets go;
  - the probe's snapshot must hold a usable value before the run writes, and is dropped only once
    the restore reads back.

Round 5: **no BLOCKER**, two SHOULDs, taken: the login re-apply arms letting go before its write; an
unreadable value at combat's end ends the wait as a failed re-apply.

Round 6: **consensus**.
