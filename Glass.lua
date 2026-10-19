-- Glass.lua: this addon's instance of the "liquid glass" material.
--
-- The material lives in the embedded library LibGlass-1.0
-- (Libs\LibGlass-1.0, from github.com/Spotnick2/LibGlass through .pkgmeta
-- externals; the TOC loads it first). Material changes are LibGlass PRs, not
-- edits here.
--
-- An instance, not the library itself: its tuning and font registry are
-- Glass UI's own and never touch another glass addon's surfaces. No textures
-- of our own: Glass.MEDIA is the library's folder.
--
-- Glass UI's skins wear the suite theme (#54, docs/QUEST-TRACKER.md part 1):
-- Pearl by default, like the addons that follow it. The instance is built
-- once, when the saved variables are in (ADDON_LOADED, GlassUI.lua), with the
-- suite theme's preset, so another preset applies at a /reload, as for the
-- followers. No panel exists before PLAYER_LOGIN, where the engine starts.
--
-- Pearl needs r11 (the package pins it, and LibStub keeps the highest copy
-- loaded, so a sibling's older copy can't displace ours). An older or
-- mispackaged development embed builds r6's clean preset instead, the look
-- before #54, and /glassui suite says so.

GlassUI = GlassUI or {}
local GUI = GlassUI

local PEARL_MINOR = 11
local FALLBACK = "clean"

-- What was built: GUI.glassPreset, and GUI.glassWhy when it isn't the
-- theme's ("library-too-old" | "build-failed").
function GUI.BuildGlass()
    if GUI.Glass then return GUI.Glass end
    local lib, minor = LibStub("LibGlass-1.0")
    local want = GUI.Suite.THEMES[GUI.Suite.ThemeName()].preset
    local why
    if type(minor) ~= "number" or minor < PEARL_MINOR then
        why = "library-too-old"
    else
        local ok, made = pcall(lib.New, lib, { preset = want })
        if ok and type(made) == "table" then
            GUI.Glass, GUI.glassPreset = made, want
            return made
        end
        why = tostring(made):find("unknown preset", 1, true) and "library-too-old" or "build-failed"
    end
    GUI.Glass, GUI.glassPreset, GUI.glassWhy = lib:New({ preset = FALLBACK }), FALLBACK, why
    return GUI.Glass
end
