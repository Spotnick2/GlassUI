-- Boot: the addon loads at login with no failure, and leaves only its own globals.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local before = {}
for k in pairs(_G) do before[k] = true end

local GUI = loadAddon()
eq(next(GUI.failures), nil, "no failures at login")
for k, v in pairs(GUI.failures) do io.write("    " .. k .. ": " .. v .. "\n") end
check(type(GUI.db) == "table", "saved settings ready")
eq(GUI.db, GlassUIDB, "the settings are GlassUIDB")

-- Our globals, and the library's loader; nothing else.
local ALLOWED = { GlassUI = true, GlassUIDB = true, LibStub = true,
                  SLASH_GLASSUI1 = true, SLASH_GLASSUI2 = true }
for k in pairs(_G) do
    if not before[k] then check(ALLOWED[k], "no stray global: " .. tostring(k)) end
end
eq(SlashCmdList.GLASSUI, GUI._test.slash, "/glassui registered")
eq(SLASH_GLASSUI1, "/glassui", "/glassui is the first name")
eq(SLASH_GLASSUI2, "/gui", "/gui is the short name (/glass is GlassUnitFrames')")

-- The commands answer.
GUI._test.slash("version")
check(table.concat(WoW.chat, "\n"):find("measured on 1.60.1.70374", 1, true), "/glassui version")
WoW.chat = {}
GUI._test.slash("failures")
check(table.concat(WoW.chat, "\n"):find("no failures recorded", 1, true), "/glassui failures")
WoW.chat = {}
GUI._test.slash("")
check(table.concat(WoW.chat, "\n"):find("/glassui version", 1, true), "/glassui with no command prints the help")

-- Only what the player SET is saved.
GUI = loadAddon({ db = { junk = nil } })
eq(next(GlassUIDB), nil, "an untouched profile saves nothing")

done("test_boot")
