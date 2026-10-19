-- Suite.lua: the suite theme, and which Glass addons follow it (docs/SUITE.md).
--
-- Glass UI is the optional orchestrator: it owns the selected theme and the
-- "Follow Glass UI" switch of each integrated addon. The addon asks once, in
-- its own ADDON_LOADED, before it builds its glass (OptionalDeps loads us
-- first), and builds Pearl or its own look; changes apply at the next /reload.
-- The recipe is LibGlass's (preset "pearl"); we only hand out its name.
--
-- We never read another addon's SavedVariables or tables beyond what Report
-- hands us, and never write to them. Defined at file scope, so the API
-- exists before any dependent's files run; Ready() turns true once GlassUIDB
-- has been read (GlassUI.lua's ADDON_LOADED).
--
-- API changes on any incompatible change (a function's arguments or meaning,
-- a removal); a new function or optional field doesn't change it, and an
-- unknown field is ignored (Glass MiniMap Bar's rule, PublicAPI.lua).

GlassUI = GlassUI or {}
local GUI = GlassUI
local API = GUI.API
local Suite = { API = 1 }
GUI.Suite = Suite

Suite.THEMES = { pearl = { label = "Pearl", preset = "pearl" } }
Suite.THEME_NAMES = { "pearl" }
Suite.DEFAULT_THEME = "pearl"

-- The Glass family (a constant roster, docs/PLAN.md "The hub"). It only
-- names them: a member is integrated when it reports, so the next one to
-- speak this API needs no Glass UI release.
Suite.ROSTER = {
    { name = "GlassUnitFrames", title = "Glass Unit Frames" },
    { name = "GlassRaidFrames", title = "Glass Raid Frames" },
    { name = "GlassActionBars", title = "Glass Action Bars" },
    { name = "GlassChat", title = "Glass Chat" },
    { name = "GlassMail", title = "Glass Mail" },
    { name = "GlassMiniMap", title = "Glass MiniMap" },
    { name = "GlassMiniMapBar", title = "Glass MiniMap Bar" },
    { name = "GlassPanel", title = "Glass Panel" },
    { name = "GlassQuestTracker", title = "Glass Quest Tracker" },
}
local member = {}
for _, m in ipairs(Suite.ROSTER) do member[m.name] = true end

local ready = false
-- [addon] = { ready, preset, reason }: the first answer each addon got this
-- session, which is what it built with. Kept from before ready on, so a
-- broken load order shows.
local answers = {}
-- [addon] = what it reported building (plain values copied, functions kept).
local reports = {}

function Suite.Ready() return ready end

-- GlassUI.lua's ADDON_LOADED, once GUI.db is set.
function Suite.MarkReady() ready = true end

local function saved()
    local s = GUI.db and rawget(GUI.db, "suite")
    return type(s) == "table" and s or nil
end

function Suite.ThemeName()
    local s = saved()
    local name = s and s.theme
    return Suite.THEMES[name] and name or Suite.DEFAULT_THEME
end

function Suite.Following(addon)
    local s = saved()
    return s ~= nil and type(s.follow) == "table" and s.follow[addon] == true
end

-- The answer as it stands now: preset or nil, reason. Records nothing.
local function answer(addon)
    if not member[addon] then return nil, "unknown" end
    if not ready then return nil, "not-ready" end
    if not Suite.Following(addon) then return nil, "not-following" end
    return Suite.THEMES[Suite.ThemeName()].preset
end
Suite.Answer = answer

-- What should `addon` build? { name, preset } (a fresh table), or nil and
-- why. Never errors.
function Suite.Theme(addon)
    local ok, preset, reason = pcall(answer, addon)
    if not ok then preset, reason = nil, "error" end
    if member[addon] and not answers[addon] then
        answers[addon] = { ready = ready, preset = preset, reason = reason }
    end
    if preset then return { name = Suite.ThemeName(), preset = preset } end
    return nil, reason
end

-- v when it is of that kind, else nil (false survives: not and/or).
-- The settings page, redrawn when what it shows changes while it is open
-- (a report, a switch set from /glassui). Never errors.
local function changed()
    local O = GUI.Options
    if type(O) == "table" and type(O.Refresh) == "function" then pcall(O.Refresh) end
end

local function plain(v, kind)
    if type(v) == kind then return v end
    return nil
end

-- What `addon` built this session. Called again when something it reports
-- changes (Glass Raid Frames' click-cast setting). Never errors.
local function copyReport(addon, state)
    local r = {
        api = plain(state.api, "number"),
        built = plain(state.built, "string"),
        reason = plain(state.reason, "string"),
        minor = plain(state.minor, "number"),
        options = plain(state.options, "function"),
    }
    local cc = state.clickCast
    if type(cc) == "table" then
        r.clickCast = { open = plain(cc.open, "function"), others = plain(cc.others, "boolean") }
    end
    -- The group layout's state (docs/GROUP-LAYOUT.md §6): GRF's { on, mode },
    -- GUF's { linked, placing }. What they applied, shown, never acted on.
    local l = state.layout
    if type(l) == "table" then
        r.layout = { on = plain(l.on, "boolean"), mode = plain(l.mode, "string"),
                     linked = plain(l.linked, "boolean"), placing = plain(l.placing, "boolean") }
    end
    reports[addon] = r
end

function Suite.Report(addon, state)
    if not member[addon] or type(state) ~= "table" then return end
    -- The caller's table may be anything (a proxy that throws): never ours to crash on.
    pcall(copyReport, addon, state)
    changed()
end

function Suite.SetFollow(addon, on)
    if not member[addon] or not GUI.db then return false end
    local s = saved() or {}
    s.follow = type(s.follow) == "table" and s.follow or {}
    s.follow[addon] = on and true or nil
    if next(s.follow) == nil then s.follow = nil end
    GUI.db.suite = next(s) and s or nil
    changed()
    return true
end

-- Is the addon there, and loaded? "missing", "disabled", "loaded", or
-- "unloaded" (installed and on for this character, but not loaded: load on
-- demand, or turned on since the last /reload). The enable state takes the
-- character's GUID: a name is accepted and means nothing (porting guide,
-- C_AddOns).
local function presence(addon)
    local ok, there = pcall(C_AddOns.DoesAddOnExist, addon)
    if not ok or API.Plain(there) ~= true then return "missing" end
    if API.IsAddOnLoaded(addon) then return "loaded" end
    local ok2, state = pcall(C_AddOns.GetAddOnEnableState, addon, UnitGUID("player"))
    state = ok2 and API.Plain(state) or nil
    if type(state) == "number" and state > 0 then return "unloaded" end
    return "disabled"
end

-- The member's state (docs/SUITE.md, the states table), and whether a
-- /reload would change what it builds (the answer now differs from the one
-- it built with). The first that applies:
--   missing, disabled, unloaded   not running this session
--   other      loaded, never spoke the API: not yet integrated
--   early      asked before we were ready: the load order failed
--   silent     asked, no report followed: it failed before reporting
--   failed     told Pearl, reported its own look
--   following  built the suite theme;  own  built its own look
function Suite.State(addon)
    local where = presence(addon)
    if where ~= "loaded" then return where, false end
    local a, r = answers[addon], reports[addon]
    if not a and not r then return "other", false end
    local pending = a ~= nil and answer(addon) ~= a.preset
    if a and not a.ready then return "early", pending end
    if not r then return "silent", pending end
    if a and a.preset and r.built ~= a.preset then return "failed", pending end
    return r.built and "following" or "own", pending
end

Suite.STATE_TEXT = {
    missing = "not installed",
    disabled = "disabled",
    unloaded = "not loaded (/reload)",
    other = "not yet integrated",
    early = "started before Glass UI (load order): own look",
    silent = "asked, but no report (an error at its load?)",
    failed = "Pearl failed, own look",
    following = "following Glass UI",
    own = "own look",
}

-- One line per family member, for /glassui suite and the settings page.
function Suite.Line(m)
    local state, pending = Suite.State(m.name)
    local text = Suite.STATE_TEXT[state]
    local r = reports[m.name]
    if state == "following" then
        text = text .. " (" .. Suite.THEMES[Suite.ThemeName()].label .. ")"
    elseif state == "failed" and r and r.reason then
        text = text .. ": " .. r.reason
    end
    if state ~= "missing" and state ~= "other" and Suite.Following(m.name) and state ~= "following" then
        text = text .. "; set to follow"
    end
    if pending then text = text .. " - /reload to apply" end
    return m.title .. ": " .. text, state, pending
end

-- The group layout, as GRF and GUF reported it (docs/GROUP-LAYOUT.md), or
-- nil when GRF reported none.
Suite.LAYOUT_MODE_TEXT = {
    hud = "centred above the action bars",
    side = "at the side",
    legacy = "off (the classic grid)",
}
function Suite.LayoutLine()
    local g = reports.GlassRaidFrames
    local l = g and g.layout
    if not l then return nil end
    local text = "Group layout: "
        .. (Suite.LAYOUT_MODE_TEXT[(l.on == false) and "legacy" or l.mode] or "unknown")
    local u = reports.GlassUnitFrames
    local ul = u and u.layout
    if ul then
        if ul.placing then text = text .. "; player and target beside it"
        elseif ul.linked then text = text .. "; player and target in their own places"
        else text = text .. "; player and target not linked" end
    end
    return text
end

-- Glass Raid Frames' click-casting, as it reported it: nil when it didn't.
function Suite.ClickCast()
    local r = reports.GlassRaidFrames
    return r and r.clickCast
end

-- Open Glass UI's settings page (an addon's "set in Glass UI" button).
-- Added in API 1 (additive: the API number stays). true when it opened;
-- never errors.
function Suite.Open()
    local O = GUI.Options
    if type(O) ~= "table" or type(O.Open) ~= "function" then return false end
    local ok, opened = pcall(O.Open)
    return ok and opened == true
end

function Suite.ReportOf(addon) return reports[addon] end
function Suite.AnswerOf(addon) return answers[addon] end

Suite._test = {
    answers = answers, reports = reports,
    reset = function() ready = false; wipe(answers); wipe(reports) end,
}
