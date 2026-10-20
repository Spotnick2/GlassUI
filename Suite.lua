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
    -- The suite look as the follower applies it (docs/SUITE-LOOK.md): its
    -- effective values, the keys it overrides, and the addons wearing its skin.
    local look = state.look
    if type(look) == "table" then
        r.look = {}
        for _, k in ipairs(Suite.LOOK_KEYS) do r.look[k] = plain(look[k], "string") end
    end
    local own = state.own
    if type(own) == "table" then
        r.own = {}
        for _, k in ipairs(Suite.LOOK_KEYS) do r.own[k] = own[k] == true or nil end
        -- Its own backing over the body's (#67): not a look key, a marker.
        r.own.backing = own.backing == true or nil
    end
    local tenants = state.tenants
    if type(tenants) == "table" then
        r.tenants = {}
        for i = 1, math.min(#tenants, 20) do
            local t = plain(tenants[i], "string")
            if t and t ~= "" then r.tenants[#r.tenants + 1] = t end
        end
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

--------------------------------------------------------------------------------
-- The suite look (docs/SUITE-LOOK.md): the tint and the button feedback,
-- owned here and changed live. Followers read it once at their start
-- (Look) and then listen to LookChanged; a key they override stays theirs.
-- The vocabulary is GlassActionBars' (its `theme` is our `tint`), and the
-- defaults are its own look, so nothing changes until the player changes it.
--------------------------------------------------------------------------------

Suite.LOOK_EVENT = "GlassUI.Suite.LookChanged"
Suite.LOOK_KEYS = { "tint", "hover", "press", "emptySlots", "accent" }
Suite.LOOK_VALUES = {
    tint = { "clear", "smoked", "class" },
    hover = { "off", "glow", "halo" },
    press = { "off", "flash", "ripple" },
    emptySlots = { "hidden", "faint", "half", "full", "frosted" },
    -- #52: the headers' colour. Gold is Blizzard's, the default (the owner is
    -- unsure of GlassChat's ice blue).
    accent = { "gold", "ice" },
}
Suite.LOOK_DEFAULTS = { tint = "clear", hover = "glow", press = "flash", emptySlots = "frosted", accent = "gold" }
Suite.LOOK_PRESETS = {
    glass = { hover = "glow", press = "flash", emptySlots = "frosted" },
    soft = { hover = "halo", press = "ripple", emptySlots = "frosted" },
    minimal = { hover = "off", press = "flash", emptySlots = "hidden" },
}
Suite.LOOK_PRESET_NAMES = { "glass", "soft", "minimal" }
Suite.LOOK_LABELS = {
    tint = "Tint", hover = "Hover", press = "Press", emptySlots = "Empty slots", accent = "Accent",
    clear = "Clear", smoked = "Smoked", class = "Class colour", gold = "Gold", ice = "Ice",
    off = "Off", glow = "Glow", halo = "Halo", flash = "Flash", ripple = "Ripple",
    hidden = "Hidden", faint = "Faint", half = "Half", full = "Full", frosted = "Frosted",
    glass = "Glass", soft = "Soft", minimal = "Minimal", custom = "Custom",
}

local validLook = {}
for k, list in pairs(Suite.LOOK_VALUES) do
    validLook[k] = {}
    for _, v in ipairs(list) do validLook[k][v] = true end
end

function Suite.LookValid(key, value)
    return validLook[key] ~= nil and validLook[key][value] == true
end

local function savedLook()
    local s = saved()
    return s and type(s.look) == "table" and s.look or nil
end

-- The suite look as a fresh table (the defaults until the player changes
-- them), or nil before we are ready. Never errors.
function Suite.Look()
    if not ready then return nil end
    local l, out = savedLook(), {}
    for _, k in ipairs(Suite.LOOK_KEYS) do
        local v = l and l[k]
        out[k] = Suite.LookValid(k, v) and v or Suite.LOOK_DEFAULTS[k]
    end
    return out
end

--------------------------------------------------------------------------------
-- The body (#67, docs/SUITE-LOOK.md "The body"): the tint, the opaque backing
-- and the wash of each tint, for Glass UI's skins (Theme) and every follower,
-- so the tuning lives here only. The wash is a factor of the material's own
-- STYLE.wash (#54: Pearl's 0.10, clean's 0.18), so on clean the factors give
-- the 0.18 and 0.14 the merchant was judged with. Clear's backing is 0.35, the
-- owner's pick on the merchant (#4) and readable over a bright sky on the
-- tracker (QT.3); smoked stays dense for bright scenery.
--------------------------------------------------------------------------------

Suite.BODY = {
    clear  = { tint = { 0.13, 0.16, 0.22, 0.24 }, wash = 1, backing = 0.35 },
    smoked = { tint = { 0.05, 0.06, 0.08, 0.62 }, wash = 0.14 / 0.18, backing = 0.92 },
    class  = { classShade = 0.6, wash = 1, backing = 0.35 },
}
Suite.BACKING = { 0.04, 0.05, 0.07 }

local function copy(t)
    if type(t) ~= "table" then return nil end
    local out = {}
    for i, v in ipairs(t) do out[i] = v end
    return out
end

-- The body for a tint name, nil meaning the suite look's current one (nil
-- before we are ready), nil for a name we don't know. Fresh all the way down.
-- A follower passes its effective tint (its own when it overrides the key).
function Suite.Body(tint)
    if tint == nil then
        local look = Suite.Look()
        if not look then return nil end
        tint = look.tint
    end
    local b = Suite.BODY[tint]
    if not b then return nil end
    local c = Suite.BACKING
    return { tint = copy(b.tint), classShade = b.classShade, wash = b.wash,
             backing = { c[1], c[2], c[3], b.backing } }
end

-- The accent's colours (#52), here only: followers map nothing themselves.
Suite.ACCENTS = { gold = { 1, 0.82, 0 }, ice = { 0.65, 0.835, 0.905 } }

-- { r, g, b } for an accent name, nil meaning the current one (nil before we
-- are ready), nil for a name we don't know. Fresh.
function Suite.Accent(name)
    if name == nil then
        local look = Suite.Look()
        if not look then return nil end
        name = look.accent
    end
    return copy(Suite.ACCENTS[name])
end

-- The preset the feedback keys match, or "custom".
function Suite.LookPreset()
    local look = Suite.Look() or Suite.LOOK_DEFAULTS
    for _, name in ipairs(Suite.LOOK_PRESET_NAMES) do
        local p, all = Suite.LOOK_PRESETS[name], true
        for k, v in pairs(p) do if look[k] ~= v then all = false end end
        if all then return name end
    end
    return "custom"
end

local function announceLook()
    local look = Suite.Look()
    -- Our own skins wear the suite's tint (#67): repainted first, our own
    -- textures only, so in combat too.
    if GUI.Theme then API.Try("theme:look", GUI.Theme.Refresh) end
    if look then API.TriggerEvent(Suite.LOOK_EVENT, look) end
    changed()
end

local function storeLook(key, value)
    local s = saved() or {}
    s.look = type(s.look) == "table" and s.look or {}
    s.look[key] = (value ~= Suite.LOOK_DEFAULTS[key]) and value or nil
    if next(s.look) == nil then s.look = nil end
    GUI.db.suite = next(s) and s or nil
end

-- Set one key of the suite look; saved sparsely, announced at once (in or
-- out of combat: followers apply it combat-safely).
function Suite.SetLook(key, value)
    if not GUI.db or not Suite.LookValid(key, value) then return false end
    storeLook(key, value)
    announceLook()
    return true
end

-- Set the three feedback keys from a preset, announced once.
function Suite.SetLookPreset(name)
    local p = Suite.LOOK_PRESETS[name]
    if not GUI.db or not p then return false end
    for k, v in pairs(p) do storeLook(k, v) end
    announceLook()
    return true
end

-- What a follower's report says about the look, for the page and
-- /glassui suite: nil when it reported none. The source is the answer it
-- started with, not the saved switch: a follower joins or leaves only at a
-- /reload. The second value is true when the switch says otherwise.
function Suite.LookLine(addon)
    local r = reports[addon]
    if not (r and (r.look or (r.own and r.own.backing))) then return nil end
    local own = {}
    for _, k in ipairs(Suite.LOOK_KEYS) do
        if r.own and r.own[k] and r.look and r.look[k] then
            -- A value of the follower's own (GlassChat's charcoal tint, "chat")
            -- isn't ours to name: just "its own tint".
            local v = Suite.LookValid(k, r.look[k]) and Suite.LOOK_LABELS[r.look[k]] or nil
            own[#own + 1] = Suite.LOOK_LABELS[k]:lower() .. (v and (" " .. v) or "")
        end
    end
    if r.own and r.own.backing then own[#own + 1] = "backing" end
    local a = answers[addon]
    local follows = a ~= nil and a.preset ~= nil
    local text = follows and "suite look" or "its own look"
    if #own > 0 then text = text .. ", its own " .. table.concat(own, ", ") end
    return text, Suite.Following(addon) ~= follows
end

-- The addons wearing a follower's skin ("Apotheca: follows Glass Action Bars").
function Suite.Tenants(addon)
    local r = reports[addon]
    local out = {}
    if r and r.tenants then for i, t in ipairs(r.tenants) do out[i] = t end end
    return out
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
    local look = Suite.LookLine(m.name)
    if look and (state == "following" or state == "own") then text = text .. "; " .. look end
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
