-- GlassUI.lua: bootstrap, saved settings and the /glassui command.
-- Loads last: every module is defined by now.

local ADDON = ...
GlassUI = GlassUI or {}
local GUI = GlassUI
local API = GUI.API
local say = API.Print

-- GlassUIDB, account-wide. Only what the player SET is saved: the
-- rest falls through to DEFAULTS, so a changed default reaches everyone
-- (GlassMail's rule). The settings themselves arrive with their features.
local DEFAULTS = {}
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
        "/glassui failures - what failed to build or register",
        "/glassui version - client build vs the measured one",
    }
end
GUI.HelpLines = helpLines

local function slash(msg)
    local cmd = (msg or ""):lower():match("^%s*(%S*)")
    if cmd == "failures" then
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
        if arg1 == ADDON then GUI.db = ensureDefaults() end
    elseif event == "PLAYER_LOGIN" then
        -- SavedVariables are read here at the latest (porting guide: not at file scope).
        if not GUI.db then GUI.db = ensureDefaults() end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- arg1 = isInitialLogin. The build warning asks the developer to re-measure.
        if arg1 and GUI.IsDev() and API.ClientBuild() ~= GUI.MEASURED_ON_BUILD then
            say("client build " .. API.ClientBuild() .. " differs from the one this addon was measured on ("
                .. GUI.MEASURED_ON_BUILD .. "). Things may misbehave until it is re-checked.")
        end
    end
end)
API.RegisterEvents(boot, { "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD" }, "boot")

GUI._test = { ensureDefaults = ensureDefaults, DEFAULTS = DEFAULTS, slash = slash }
