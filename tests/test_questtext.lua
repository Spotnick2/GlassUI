-- Light quest text on glass (#203, docs/QUEST-TEXT.md): the switch that sets
-- Blizzard's Dark quest text. On and Off (the value remembered once, given
-- back only while still Dark), letting go when someone else changes it (the
-- event's value or the live one; a nested change inside our own write), the
-- startup decision (after the CVars load, usable reads first, a dropped value
-- re-applied, after combat if need be), refusals and failed writes,
-- per-character records, the control and the slash command, and the gossip
-- window's page on glass with the switch on.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local CVAR = "questTextContrast"

local function load(opts)
    opts = opts or {}
    return loadAddon({ db = opts.db, before = function()
        if opts.cvar then opts.cvar(WoW.cvar) end
        if opts.combat then WoW.combat = true end
    end })
end
local function value() return C_CVar.GetCVar(CVAR) end
local function writes() return #WoW.cvar.sets end
local function said(text)
    local n = 0
    for _, l in ipairs(WoW.chat) do if l:find(text, 1, true) then n = n + 1 end end
    return n
end
local OFF_LINE = "Light quest text is off"

--------------------------------------------------------------------------------
-- On and Off
--------------------------------------------------------------------------------

local GUI = load()
local QT = GUI.QuestText
eq(QT.Status(), "off", "off by default")
check(QT.state.decided, "decided at ADDON_LOADED (the CVars already loaded)")
eq(rawget(GlassUIDB, "questText"), nil, "nothing saved while off")

local ok = QT.On()
check(ok, "on")
eq(value(), "4", "Dark written")
eq(writes(), 1, "one write")
eq(WoW.cvar.sets[1][1], CVAR, "to questTextContrast")
eq(GlassUIDB.questText.was, "0", "the value it replaced remembered")
eq(said(OFF_LINE), 0, "our own write's event doesn't let go")
check(QT.IsOn(), "on")
QT.Off()
eq(value(), "0", "off: the default back")
eq(writes(), 2, "one restore")
eq(rawget(GlassUIDB, "questText"), nil, "off: the record gone")
eq(said(OFF_LINE), 0, "Off's own restore: no 'was changed' line")

-- From 2, On twice (Codex r1), then Off: 2 back.
WoW.setCVar(CVAR, "2")
QT.On()
GUI._test.slash("questtext on")
eq(GlassUIDB.questText.was, "2", "a second On keeps the first value")
QT.Off()
eq(value(), "2", "off: 2 back")

-- Already Dark: nothing written, nothing restored.
WoW.setCVar(CVAR, "4")
local before = writes()
QT.On()
eq(writes(), before, "on while Dark: nothing written")
eq(GlassUIDB.questText.was, "4", "Dark remembered")
QT.Off()
eq(writes(), before, "off: nothing written")
eq(value(), "4", "Dark kept")

--------------------------------------------------------------------------------
-- Letting go
--------------------------------------------------------------------------------

WoW.setCVar(CVAR, "0")
QT.On()
WoW.chat = {}
WoW.setCVar(CVAR, "2")
check(not QT.IsOn(), "changed elsewhere to 2: let go")
eq(said(OFF_LINE), 1, "the line, once")
before = writes()
QT.Off()
eq(writes(), before, "off after letting go: nothing written")
eq(value(), "2", "their choice stands")

QT.On()
WoW.chat = {}
WoW.setCVar("someOtherCVar", "1")
WoW.setCVar(CVAR, "4")
check(QT.IsOn(), "another CVar, or Dark kept: nothing")
-- Another listener answering a change with Dark (nested delivery, Codex r3):
-- the event says 2, the live value is already 4.
WoW.cvar.onUpdate = function(name, v)
    if name == CVAR and v == "2" then WoW.cvar.onUpdate = nil; WoW.setCVar(CVAR, "4") end
end
WoW.setCVar(CVAR, "2")
check(not QT.IsOn(), "an event saying 2, the live value back to 4: let go")
before = writes()
QT.Off()
eq(writes(), before, "and Off writes nothing over that 4")
eq(value(), "4", "4 stays")
-- Nothing usable in the event and an unreadable live value: nothing.
WoW.setCVar(CVAR, "0")
QT.On()
WoW.cvar.unreadable = true
WoW.fire("CVAR_UPDATE", CVAR, nil)
check(QT.IsOn(), "nothing usable: the switch kept")
-- Off with an unreadable live value: refused, the record kept (Codex r3).
local okOff = QT.Off()
check(not okOff and QT.IsOn(), "off with nothing readable: refused, kept")
WoW.cvar.unreadable = nil
QT.Off()
eq(value(), "0", "readable again: off restores 0")

-- An event with no value, the live value changed: the live read lets go.
QT.On()
WoW.cvar.values[CVAR] = "2"
WoW.fire("CVAR_UPDATE", CVAR, nil)
check(not QT.IsOn(), "no value in the event, live 2: let go")
-- Changed with no event at all, then Off: restores nothing over it.
WoW.setCVar(CVAR, "0")
QT.On()
WoW.cvar.values[CVAR] = "3"
before = writes()
QT.Off()
eq(writes(), before, "off, the setting changed unseen: nothing written")
eq(value(), "3", "3 stays")
-- The writer itself never writes in combat.
WoW.combat = true
before = writes()
check(not QT.Write("4"), "Write in combat: refused")
eq(writes(), before, "nothing written")
WoW.combat = false

-- A nested change inside On's own write (Codex r4): another listener goes 2
-- then 4 as our 4 lands.
WoW.setCVar(CVAR, "1")
WoW.cvar.onUpdate = function(name, v)
    if name == CVAR and v == "4" then
        WoW.cvar.onUpdate = nil
        WoW.setCVar(CVAR, "2")
        WoW.setCVar(CVAR, "4")
    end
end
local okOn = QT.On()
check(not okOn and not QT.IsOn(), "a change inside On's write: not claimed")
before = writes()
QT.Off()
eq(writes(), before, "and Off writes nothing")
eq(value(), "4", "the other writer's 4 stays")

--------------------------------------------------------------------------------
-- Refusals and failed writes
--------------------------------------------------------------------------------

WoW.setCVar(CVAR, "0")
WoW.combat = true
before = writes()
check(not QT.On(), "on in combat: refused")
eq(writes(), before, "nothing written")
check(not QT.IsOn(), "still off")
WoW.combat = false
QT.On()
WoW.combat = true
check(not QT.Off(), "off in combat: refused")
check(QT.IsOn(), "still on")
WoW.combat = false
QT.Off()

for _, mode in ipairs({ "false", "ignore", "throw" }) do
    GUI.failures.questtext = nil
    WoW.cvar.refuse = mode
    check(not QT.On(), "on, a refused write (" .. mode .. "): not on")
    check(not QT.IsOn(), mode .. ": the switch stays off")
    check(GUI.failures.questtext ~= nil, mode .. ": recorded")
    WoW.cvar.refuse = nil
end
QT.On()
WoW.cvar.refuse = "false"
local okR, line = QT.Off()
check(okR and not QT.IsOn(), "off, a refused restore: the switch off anyway")
check(line:find("didn't come back", 1, true) ~= nil, "and the line says so")
eq(value(), "4", "the setting left Dark")
WoW.cvar.refuse = nil
WoW.setCVar(CVAR, "0")

-- The skins' switches and the master switch never touch it.
before = writes()
for _, cmd in ipairs({ "skin gossip off", "skin gossip on", "skin quest off", "skin quest on", "off", "on" }) do
    GUI._test.slash(cmd)
end
eq(writes(), before, "the skins' switches: no write")

-- Late delivery (not this build's, Blizzard documents it synchronous): our own
-- write's event, a frame late, still doesn't let go.
WoW.cvar.late = true
QT.On()
WoW.flushTimers(0)
check(QT.IsOn(), "our own event, late: no let-go")
WoW.cvar.late = nil
QT.Off()

--------------------------------------------------------------------------------
-- The control and the command
--------------------------------------------------------------------------------

local O = GUI.Options._test
O.panel:Show()
local Q = O.questText
check(not Q.check:GetChecked(), "the checkbox off")
Q.check:SetChecked(true)
Q.check._scripts.OnClick(Q.check)
check(QT.IsOn() and Q.check:GetChecked(), "clicked: on, checked")
eq(value(), "4", "Dark")
WoW.setCVar(CVAR, "3")
check(not Q.check:GetChecked(), "let go: the checkbox refreshed")
WoW.combat = true
Q.check:SetChecked(true)
Q.check._scripts.OnClick(Q.check)
check(not Q.check:GetChecked(), "a click refused in combat: the checkbox back off")
check(Q.line:GetText():find("combat", 1, true) ~= nil, "with the reason")
WoW.combat = false
check(Q.note:GetText():find("books", 1, true) ~= nil, "the note names the other readers")
Q.check._scripts.OnEnter(Q.check)
check(table.concat(GameTooltip._lines, " "):find("before uninstalling", 1, true) ~= nil, "the tooltip: turn it off before uninstalling")
O.panel:Hide()
WoW.chat = {}
GUI._test.slash("questtext on")
check(QT.IsOn(), "/glassui questtext on")
GUI._test.slash("skins")
eq(said("questtext (Light quest text on glass): on"), 1, "/glassui skins says it")
GUI._test.slash("questtext off")
eq(value(), "3", "/glassui questtext off: 3 back")

--------------------------------------------------------------------------------
-- The gossip window with the switch on: Blizzard's light text on the glass
--------------------------------------------------------------------------------

WoW.gossip()
WoW.flushTimers(0)
eq(GossipFrame.Background:GetAlpha(), 1, "the switch off: the parchment kept")
QT.On()
WoW.flushTimers(0)
eq(GossipFrame.Background:GetAtlas(), "QuestBG-Parchment-Accessibility4", "on: Blizzard's dark page")
eq(GossipFrame.Background:GetAlpha(), 0, "faded: the text on the glass")
eq(GossipFrame._rows[1]._textColor[1], WoW.STONE_TEXT[1], "in Blizzard's light text")
QT.Off()
WoW.flushTimers(0)
eq(GossipFrame.Background:GetAlpha(), 1, "off: the page back")
WoW.closeGossip()

--------------------------------------------------------------------------------
-- Startup
--------------------------------------------------------------------------------

-- On, the client dropped it (the default read): re-applied once.
GUI = load({ db = { questText = { was = "2" } } })
QT = GUI.QuestText
eq(value(), "4", "dropped: Dark re-applied")
eq(writes(), 1, "once")
check(QT.IsOn(), "still on")
eq(GlassUIDB.questText.was, "2", "the remembered value kept")
QT.Off()
eq(value(), "2", "off: 2 back")

-- Kept (4): nothing. Another value (a choice made while we weren't running): let go.
GUI = load({ db = { questText = { was = "2" } }, cvar = function(c) c.values[CVAR] = "4" end })
eq(writes(), 0, "kept: nothing written")
check(GUI.QuestText.IsOn(), "on")
GUI = load({ db = { questText = { was = "2" } }, cvar = function(c) c.values[CVAR] = "1" end })
eq(writes(), 0, "1 at login: nothing written")
check(not GUI.QuestText.IsOn(), "let go")
eq(said(OFF_LINE), 1, "the line, once")

-- The CVars not loaded yet: no decision; an early CVAR_UPDATE (the stored
-- value arriving) never clears the switch; Off and On refused meanwhile.
GUI = load({ db = { questText = { was = "2" } }, cvar = function(c) c.loaded = false end })
QT = GUI.QuestText
check(not QT.state.decided, "not loaded: no decision")
WoW.setCVar(CVAR, "0")
check(QT.IsOn() and not QT.state.decided, "an early event: the switch kept, still undecided")
local okEarly = QT.Off()
check(not okEarly and QT.IsOn(), "Off before the decision: refused, the record kept (Codex r2)")
eq(writes(), 0, "nothing written")
WoW.cvar.values[CVAR] = "4"
WoW.cvar.loaded = true
WoW.fire("VARIABLES_LOADED")
check(QT.state.decided, "decided at VARIABLES_LOADED")
eq(writes(), 0, "the stored 4: nothing written")
QT.Off()
eq(value(), "2", "Off after the decision restores 2")

-- Loaded, but a read not usable yet: wait, then decide.
GUI = load({ db = { questText = { was = "2" } }, cvar = function(c) c.noDefault = true end })
QT = GUI.QuestText
check(not QT.state.decided and QT.IsOn(), "no default yet: no decision, the record kept")
WoW.cvar.noDefault = nil
WoW.fire("PLAYER_ENTERING_WORLD", true, false)
check(QT.state.decided, "decided at the next try")
eq(value(), "4", "and re-applied")

-- A nested change inside the login re-apply's write (Codex r5).
GUI = load({ db = { questText = { was = "1" } }, cvar = function(c)
    c.onUpdate = function(name, v)
        if name == CVAR and v == "4" then
            c.onUpdate = nil
            WoW.setCVar(CVAR, "2")
            WoW.setCVar(CVAR, "4")
        end
    end
end })
QT = GUI.QuestText
check(not QT.IsOn(), "a change inside the re-apply: let go")
local w = writes()
QT.Off()
eq(writes(), w, "and Off writes nothing")
eq(value(), "4", "the other writer's 4 stays")

-- A failed re-apply: the switch never claims what the setting isn't.
GUI = load({ db = { questText = { was = "2" } }, cvar = function(c) c.refuse = "ignore" end })
check(not GUI.QuestText.IsOn(), "a failed re-apply: the record cleared")
eq(value(), "0", "the setting as it was")
eq(said("couldn't set Dark again"), 1, "the line")

-- A reload in combat: the re-apply waits, shown as waiting; then written.
GUI = load({ db = { questText = { was = "2" } }, combat = true })
QT = GUI.QuestText
eq(writes(), 0, "in combat: nothing written yet")
eq(QT.Status(), "on, waiting for combat to end", "the status says it's waiting")
GUI._test.slash("skins")
eq(said("on, waiting for combat to end"), 1, "/glassui skins too")
WoW.combat = false
WoW.fire("PLAYER_REGEN_ENABLED")
eq(value(), "4", "written as combat ends")
eq(QT.Status(), "on", "no longer waiting")
QT.Off()
eq(value(), "2", "then Off restores 2, no 'was changed' line (Codex r4)")
eq(said(OFF_LINE), 0, "the line not said")

-- In combat, the player changes it meanwhile: to 2, or to Dark (Codex r3).
for _, v in ipairs({ "2", "4" }) do
    GUI = load({ db = { questText = { was = "1" } }, combat = true })
    QT = GUI.QuestText
    WoW.setCVar(CVAR, v)
    check(not QT.IsOn(), "changed to " .. v .. " during the wait: let go")
    WoW.combat = false
    WoW.fire("PLAYER_REGEN_ENABLED")
    eq(writes(), 0, v .. ": nothing written as combat ends")
    QT.Off()
    eq(value(), v, v .. ": a later Off leaves it")
end

-- The default readable at startup, nothing readable at combat's end (Codex r5).
GUI = load({ db = { questText = { was = "2" } }, combat = true })
QT = GUI.QuestText
WoW.cvar.unreadable = true
WoW.combat = false
WoW.fire("PLAYER_REGEN_ENABLED")
eq(writes(), 0, "unreadable at combat's end: no write")
check(not QT.IsOn() and QT.Status() == "off", "the wait ended, the switch off")
WoW.cvar.unreadable = nil

-- Switch off at login: nothing at all.
GUI = load({ cvar = function(c) c.values[CVAR] = "1" end })
eq(writes(), 0, "off: nothing written at login")

--------------------------------------------------------------------------------
-- Per-character records (if the client stores the setting per character)
--------------------------------------------------------------------------------

GUI = load({ cvar = function(c) c.perChar = true end })
QT = GUI.QuestText
WoW.setCVar(CVAR, "1")
QT.On()
eq(GlassUIDB.questTextChars[WoW.GUID].was, "1", "the record under this character")
eq(rawget(GlassUIDB, "questText"), nil, "not account-wide")
-- Character B logs in with 3: its own switch is off, never taken over.
local saved = GlassUIDB
WoW.GUID = "Player-4618-0BBBBBB0"
GUI = load({ db = saved, cvar = function(c) c.perChar = true; c.values[CVAR] = "3" end })
QT = GUI.QuestText
check(not QT.IsOn(), "character B: off")
eq(writes(), 0, "nothing written on B's login")
local okB = QT.Off()
check(okB and value() == "3", "B's Off restores nothing of A's")
QT.On()
QT.Off()
eq(value(), "3", "B's own On and Off: its own 3")
WoW.GUID = "Player-4618-0ABCDEF0"
-- No GUID yet: no decision.
local realGUID = UnitGUID
UnitGUID = function() return nil end
GUI = load({ cvar = function(c) c.perChar = true end })
check(not GUI.QuestText.state.decided, "per character, no GUID: no decision")
UnitGUID = realGUID

eq(next(GUI.failures), nil, "no failures")
done("test_questtext")
