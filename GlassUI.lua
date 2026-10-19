-- GlassUI.lua: bootstrap, saved settings and the /glassui command.
-- Loads last: every module is defined by now.

local ADDON = ...
GlassUI = GlassUI or {}
local GUI = GlassUI
local API = GUI.API
local say = API.Print

-- GlassUIDB, account-wide. Only what the player SET is saved: the
-- rest falls through to DEFAULTS, so a changed default reaches everyone
-- (GlassMail's rule).
--   enabled  the master switch (false: every skin off)
--   skins    { [key] = false } for each skin switched off (Engine.SetEnabled)
--   theme    Theme.NAMES
--   suite    { theme = Suite.THEMES key, follow = { [addon] = true } }, or nil
--            when nobody follows (Suite.SetFollow keeps it sparse)
local DEFAULTS = { enabled = true, theme = "clear" }
GUI.DEFAULTS = DEFAULTS

local function ensureDefaults()
    if type(GlassUIDB) ~= "table" then GlassUIDB = {} end
    local db = setmetatable(GlassUIDB, nil)
    for k, v in pairs(DEFAULTS) do
        if db[k] == v then db[k] = nil end
    end
    setmetatable(db, { __index = DEFAULTS })
    return db
end

-- A dev build, by its version: "dev" from the deploy script, or the
-- packager's token left unreplaced (matched as a pattern, never written whole:
-- the packager would replace it here too). Unreadable is NOT dev.
function GUI.IsDev()
    local v = API.AddOnVersion(ADDON or "GlassUI")
    return v ~= nil and (v == "dev" or v:find("@project%-version@") ~= nil)
end

function GUI.VersionText()
    local v = API.AddOnVersion(ADDON or "GlassUI")
    if v == nil or v == "" or GUI.IsDev() then return "dev" end
    return v
end

local function failures()
    local any = false
    for key, err in pairs(GUI.failures) do
        any = true
        say(key .. ": " .. err)
    end
    if not any then say("no failures recorded") end
end

-- The command list: /glassui help prints it.
local function helpLines()
    return {
        "/glassui skins - every skin and whether it is on",
        "/glassui skin <name> on|off - one skin",
        "/glassui on|off - every skin (the master switch)",
        "/glassui theme clear|smoked|class - the glass",
        "/glassui suite - the Glass addons and whether each follows the suite theme",
        "/glassui suite follow <addon> on|off - an addon follows Glass UI (after /reload)",
        "/glassui look - the suite look (tint and button feedback); look tint smoked, look preset soft",
        "/glassui options - the settings page",
        "/glassui failures - what failed to build or register",
        "/glassui version - client build vs the measured one",
    }
end
GUI.HelpLines = helpLines

local function skins()
    local Engine = GUI.Engine
    if #Engine.list == 0 then say("no skins") return end
    if GUI.db and GUI.db.enabled == false then say("every skin is off (/glassui on)") end
    for _, s in ipairs(Engine.list) do
        say(s.def.key .. " (" .. s.def.title .. "): " .. Engine.Status(s.def.key))
    end
end

local function suite(a, b, c)
    local Suite = GUI.Suite
    if a == "follow" then
        local m
        for _, x in ipairs(Suite.ROSTER) do
            if x.name:lower() == b or x.title:lower():gsub(" ", "") == b then m = x end
        end
        if not m or (c ~= "on" and c ~= "off") then
            say("/glassui suite follow <addon> on|off, e.g. GlassUnitFrames")
            return
        end
        Suite.SetFollow(m.name, c == "on")
        say(Suite.Line(m))
        return
    end
    say("suite theme: " .. Suite.THEMES[Suite.ThemeName()].label)
    if GUI.glassWhy then
        say("Glass UI's own skins: " .. GUI.glassPreset .. ", not the suite theme ("
            .. (GUI.glassWhy == "library-too-old" and "LibGlass older than r11" or "it couldn't be built")
            .. "; /reload after updating)")
    end
    for _, m in ipairs(Suite.ROSTER) do say(Suite.Line(m)) end
    for _, m in ipairs(Suite.ROSTER) do
        for _, t in ipairs(Suite.Tenants(m.name)) do say(t .. ": follows " .. m.title) end
    end
    local layout = Suite.LayoutLine()
    if layout then say(layout) end
    local cc = Suite.ClickCast()
    if cc then
        say("click-casting: Glass Raid Frames; its bindings on other addons' frames: "
            .. (cc.others and "on" or "off"))
    end
end

-- /glassui look [tint|hover|press|empty|preset <value>]
local LOOK_ALIAS = { tint = "tint", hover = "hover", press = "press", empty = "emptySlots" }
local function look(a, b)
    local Suite = GUI.Suite
    if a == "preset" and Suite.SetLookPreset(b) then
        say("suite look: " .. Suite.LOOK_LABELS[b] .. " feedback")
        return
    end
    local key = LOOK_ALIAS[a]
    if key and Suite.SetLook(key, b) then
        say("suite look: " .. Suite.LOOK_LABELS[key]:lower() .. " " .. Suite.LOOK_LABELS[b])
        return
    end
    if a ~= "" then
        say("/glassui look tint|hover|press|empty|preset <value>")
    end
    local l = Suite.Look() or Suite.LOOK_DEFAULTS
    local parts = {}
    for _, k in ipairs(Suite.LOOK_KEYS) do
        parts[#parts + 1] = Suite.LOOK_LABELS[k]:lower() .. " " .. Suite.LOOK_LABELS[l[k]]
    end
    say("suite look (" .. Suite.LOOK_LABELS[Suite.LookPreset()] .. "): " .. table.concat(parts, ", "))
    for _, k in ipairs(Suite.LOOK_KEYS) do
        local name = k == "emptySlots" and "empty" or k
        say("  " .. name .. ": " .. table.concat(Suite.LOOK_VALUES[k], "|"))
    end
    say("  preset: " .. table.concat(Suite.LOOK_PRESET_NAMES, "|"))
end

local function reloadNote(result)
    if result == "reload" then say("/reload to finish: a skin that isn't live can't be undone in place") end
end

local function slash(msg)
    local cmd, a, b, c = (msg or ""):lower():match("^%s*(%S*)%s*(%S*)%s*(%S*)%s*(%S*)")
    local Engine = GUI.Engine
    if cmd == "skins" then
        skins()
    elseif cmd == "skin" and Engine.byKey[a] and (b == "on" or b == "off") then
        reloadNote(Engine.SetEnabled(a, b == "on"))
        say(a .. ": " .. Engine.Status(a))
    elseif cmd == "skin" then
        say("/glassui skin <name> on|off, where name is one of /glassui skins")
    elseif cmd == "on" or cmd == "off" then
        reloadNote(Engine.SetMaster(cmd == "on"))
        say("every skin " .. cmd)
    elseif cmd == "theme" and GUI.Theme.IsValid(a) then
        GUI.Theme.Set(a)
        say("theme: " .. GUI.Theme.LABELS[a])
    elseif cmd == "theme" then
        say("/glassui theme " .. table.concat(GUI.Theme.NAMES, "|") .. " (now " .. GUI.Theme.Name() .. ")")
    elseif cmd == "options" then
        if not GUI.Options.Open() then say("the settings page isn't available") end
    elseif cmd == "look" then
        look(a, b)
    elseif cmd == "suite" then
        suite(a, b, c)
    elseif cmd == "failures" then
        failures()
    elseif cmd == "version" then
        say("version " .. GUI.VersionText() .. ", client " .. API.ClientBuild()
            .. ", measured on " .. GUI.MEASURED_ON_BUILD)
    else
        for _, line in ipairs(helpLines()) do say(line) end
    end
end

SLASH_GLASSUI1 = "/glassui"
SLASH_GLASSUI2 = "/gui"
SlashCmdList.GLASSUI = slash

local boot = CreateFrame("Frame")
boot:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON then
            GUI.db = ensureDefaults()
            -- The suite's answers are ours to give from here on (docs/SUITE.md).
            GUI.Suite.MarkReady()
            -- Our own glass on the suite theme, now that it can be read (#54).
            GUI.BuildGlass()
        end
    elseif event == "PLAYER_LOGIN" then
        -- SavedVariables are read here at the latest (porting guide: not at file scope).
        if not GUI.db then GUI.db = ensureDefaults(); GUI.Suite.MarkReady(); GUI.BuildGlass() end
        GUI.Theme.Refresh()
        GUI.Options.Register()
        GUI.Engine.Start()
    elseif event == "PLAYER_ENTERING_WORLD" then
        GUI.Theme.Retry()
        -- arg1 = isInitialLogin. The build warning asks the developer to re-measure.
        if arg1 and GUI.IsDev() and API.ClientBuild() ~= GUI.MEASURED_ON_BUILD then
            say("client build " .. API.ClientBuild() .. " differs from the one this addon was measured on ("
                .. GUI.MEASURED_ON_BUILD .. "). Things may misbehave until it is re-checked.")
        end
    end
end)
API.RegisterEvents(boot, { "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD" }, "boot")

GUI._test = { ensureDefaults = ensureDefaults, DEFAULTS = DEFAULTS, slash = slash }
