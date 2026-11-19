-- QuestText.lua: "Light quest text on glass" (#203, docs/QUEST-TEXT.md), the
-- one Blizzard setting Glass UI changes: Quest Text Contrast, Dark. Then
-- Blizzard draws its light "Stone" quest text, and the gossip and quest skins
-- fade the dark page (Skin/GossipQuest.lua), so the text sits on the glass.
--
-- An audited exception to "never change a Blizzard setting" (docs/PLAN.md):
-- Write is the only code in Glass UI that writes a CVar, and it writes only
-- this one, never in combat, from three triggers: the player's On, Off's
-- restore, and the login re-apply of a value the client dropped.
--
-- The switch remembers the value it replaced and gives it back when turned
-- off, only while the setting is still Dark. Anyone else changing the setting
-- (Blizzard's settings, another addon) makes it let go: their choice stands.
-- While on, Glass UI only ever writes Dark (On claims the record before its
-- write, Off releases it before its restore), so a change to anything else is
-- someone else's. That rests on CVAR_UPDATE arriving inside the call that
-- caused it (Blizzard documents it as synchronous; the probe measures it).

GlassUI = GlassUI or {}
local GUI = GlassUI
local API = GUI.API
local say = API.Print

local QT = {}
GUI.QuestText = QT

local CVAR = "questTextContrast"
local DARK = "4"
QT.CVAR, QT.DARK = CVAR, DARK

-- decided: the startup decision ran (letting go armed from then on).
-- pending: a login re-apply waiting for combat to end. scope: "account" or
-- "character" (the client stores the CVar per character), with the GUID.
local state = { decided = false, pending = false, scope = nil, guid = nil }
QT.state = state
-- The startup samples, for the probe (SkinProbe loads after us and can't see
-- our ADDON_LOADED). In memory only, never saved.
local trace = {}
QT.trace = trace
local TRACE_MAX = 30
local listeners = {}

local function cvarApi() return rawget(_G, "C_CVar") end

-- A usable string, or nil (a secret, nothing, an empty string).
local function usable(v)
    v = API.Plain(v)
    if type(v) == "number" then v = tostring(v) end
    if type(v) ~= "string" or v == "" then return nil end
    return v
end

local function call(name, ...)
    local cv = cvarApi()
    local fn = cv and cv[name]
    if type(fn) ~= "function" then return false end
    return pcall(fn, ...)
end

local function live()
    local ok, v = call("GetCVar", CVAR)
    return ok and usable(v) or nil
end

local function default()
    local ok, v = call("GetCVarDefault", CVAR)
    return ok and usable(v) or nil
end

local function cvarsLoaded()
    local cv = cvarApi()
    if not (cv and type(cv.AreCVarsLoaded) == "function") then return true end
    local ok, v = pcall(cv.AreCVarsLoaded)
    return ok and API.Plain(v) == true
end

-- Stored per character by the client? (GetCVarInfo's fourth return.)
local function perCharacter()
    local ok, _, _, _, isChar = call("GetCVarInfo", CVAR)
    return ok and API.Plain(isChar) == true
end

--------------------------------------------------------------------------------
-- The record: { was = "<value>" } while on, absent while off (sparse)
--------------------------------------------------------------------------------

local function record()
    local db = GUI.db
    if not db then return nil end
    if state.scope == "character" then
        local all = rawget(db, "questTextChars")
        local r = type(all) == "table" and state.guid and all[state.guid] or nil
        return type(r) == "table" and r or nil
    end
    local r = rawget(db, "questText")
    return type(r) == "table" and r or nil
end

local function setRecord(r)
    local db = GUI.db
    if not db then return end
    if state.scope == "character" then
        local all = rawget(db, "questTextChars")
        if type(all) ~= "table" then all = {} end
        all[state.guid] = r
        db.questTextChars = next(all) and all or nil
    else
        db.questText = r
    end
end

local function changed()
    for _, fn in ipairs(listeners) do API.Try("questtext:listener", fn) end
end

-- A refresh when the switch's state changes (the settings page's checkbox).
function QT.OnChange(fn) listeners[#listeners + 1] = fn end

function QT.IsOn() return record() ~= nil end
function QT.IsPending() return state.pending and record() ~= nil end

function QT.Status()
    if not record() then return "off" end
    if state.pending then return "on, waiting for combat to end" end
    return "on"
end

--------------------------------------------------------------------------------
-- The one writer
--------------------------------------------------------------------------------

-- True only when the client took the value: the call didn't throw, didn't
-- return false, and the setting reads it back (GlassMail's rule). Never in
-- combat. A refusal is recorded; the caller says what happened.
local function write(v)
    if InCombatLockdown() then return false end
    local cv = cvarApi()
    -- The one setter call in Glass UI (test_contract counts it).
    local set = cv and cv.SetCVar
    if type(set) ~= "function" then
        API.Fail("questtext", "the CVar setter is missing on this build")
        return false
    end
    local ok, res = pcall(set, CVAR, v)
    local back = live()
    if not ok then
        API.Fail("questtext", res)
        return false
    end
    if API.Plain(res) == false or back ~= v then
        API.Fail("questtext", "wrote " .. v .. ", the setting reads " .. tostring(back))
        return false
    end
    return true
end
QT.Write = write

--------------------------------------------------------------------------------
-- Letting go: someone else changed the setting
--------------------------------------------------------------------------------

local function letGo(why)
    setRecord(nil)
    state.pending = false
    say("Light quest text is off: " .. (why or "Quest Text Contrast was changed"))
    changed()
end

-- A re-apply that didn't take: the switch never claims what the setting isn't.
local function failedReapply()
    setRecord(nil)
    state.pending = false
    say("Light quest text is off: Glass UI couldn't set Dark again (the setting reads "
        .. tostring(live() or "nothing") .. ")")
    changed()
end

--------------------------------------------------------------------------------
-- On and Off
--------------------------------------------------------------------------------

-- Returns ok and a line for the player.
function QT.On()
    if record() then return true, "already on" end
    if InCombatLockdown() then return false, "not in combat: try again after it" end
    if not state.decided then return false, "a moment after login: try again" end
    local now = live()
    if not now then
        API.Fail("questtext:read", "Quest Text Contrast can't be read")
        return false, "the setting can't be read"
    end
    if now == DARK then
        setRecord({ was = DARK })
        changed()
        return true, "on (Dark was already set)"
    end
    -- Claim before writing: a nested change by another listener during the
    -- write then lets go as usual (Codex on #203, r4).
    setRecord({ was = now })
    local ok = write(DARK)
    if not record() then
        changed()
        return false, "the setting was changed while switching"
    end
    if not ok then
        setRecord(nil)
        changed()
        return false, "the setting didn't take Dark (it reads " .. tostring(live() or "nothing") .. ")"
    end
    changed()
    return true, "on"
end

function QT.Off()
    local r = record()
    if not r then return true, "already off" end
    if InCombatLockdown() then return false, "not in combat: try again after it" end
    if not state.decided then return false, "a moment after login: try again" end
    local now = live()
    if not now then
        API.Fail("questtext:read", "Quest Text Contrast can't be read")
        return false, "the setting can't be read"
    end
    -- Release before restoring: our own restore's event then finds the
    -- switch off (Codex on #203, r2).
    local was = r.was
    setRecord(nil)
    state.pending = false
    changed()
    if now == DARK and was ~= DARK then
        if not write(was) then
            return true, "off, but your setting didn't come back (it reads " .. tostring(live() or "nothing") .. ")"
        end
        return true, "off (your setting is back)"
    end
    return true, "off"
end

--------------------------------------------------------------------------------
-- Startup: one decision, once the stored value is known
--------------------------------------------------------------------------------

local function sample(event)
    if #trace >= TRACE_MAX then return end
    local r = record()
    trace[#trace + 1] = { event = event, db = GUI.db ~= nil, loaded = cvarsLoaded(), value = live(),
                          was = r and r.was, guid = state.guid, decided = state.decided }
end

-- The decision's outcome, after it ran: "off" (the switch off), "kept"
-- (Dark), "letgo", "pending" (a re-apply after combat), "reapplied",
-- "failed". The probe checks a switch-on load by it (Codex on #204).
local function outcome(what)
    if #trace >= TRACE_MAX then return end
    trace[#trace + 1] = { event = "decision", outcome = what, value = live() }
end

local function decide(event)
    if state.decided then return end
    sample(event)
    if not GUI.db or not cvarsLoaded() then return end
    if perCharacter() then
        local ok, g = pcall(UnitGUID, "player")
        local guid = ok and usable(g) or nil
        if not guid then return end
        state.scope, state.guid = "character", guid
    else
        state.scope, state.guid = "account", nil
    end
    local r = record()
    if not r then
        state.decided = true
        outcome("off")
        changed()
        return
    end
    local now, def = live(), default()
    if not (now and def) then return end
    -- Armed from here on, before any write of ours (Codex on #203, r5).
    state.decided = true
    if now == DARK then outcome("kept") changed() return end
    if now ~= def then
        letGo("Quest Text Contrast was changed while Glass UI wasn't running")
        outcome("letgo")
        return
    end
    -- The default: the client dropped it. Re-apply, after combat if need be.
    if InCombatLockdown() then
        state.pending = true
        outcome("pending")
        changed()
        return
    end
    local ok = write(DARK)
    if record() and not ok then failedReapply() outcome("failed") return end
    outcome(record() and "reapplied" or "letgo")
    changed()
end
QT.Decide = decide

-- PLAYER_REGEN_ENABLED with a re-apply waiting: checked again, the wait
-- cleared before the write so our own event meets the ordinary rule.
local function combatEnded()
    if not state.pending then return end
    if not record() then state.pending = false return end
    local now, def = live(), default()
    if not now then
        setRecord(nil)
        state.pending = false
        say("Light quest text is off: Quest Text Contrast couldn't be read")
        changed()
        return
    end
    if now ~= def then
        letGo()
        return
    end
    state.pending = false
    local ok = write(DARK)
    if record() and not ok then failedReapply() return end
    changed()
end

local function onCVar(name, value)
    name = API.Plain(name)
    if type(name) ~= "string" or name:lower() ~= CVAR:lower() then return end
    if not state.decided then
        decide("CVAR_UPDATE")
        return
    end
    if not record() then return end
    local v, now = usable(value), live()
    -- A re-apply waiting: we haven't written Dark yet, so any change is
    -- someone else's, Dark included (Codex on #203, r3).
    if state.pending then
        if v or now then letGo() end
        return
    end
    if (v and v ~= DARK) or (now and now ~= DARK) then letGo() end
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, a, b)
    if event == "CVAR_UPDATE" then
        onCVar(a, b)
    elseif event == "PLAYER_REGEN_ENABLED" then
        combatEnded()
    else
        decide(event)
    end
end)
API.RegisterEvents(events, { "VARIABLES_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "CVAR_UPDATE",
                             "PLAYER_REGEN_ENABLED" }, "questtext")

QT._test = { state = state, record = record, letGo = letGo }
