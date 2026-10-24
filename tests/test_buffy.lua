dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")
local GUI = loadAddon()
local S = GUI.Suite
local found
for _, entry in ipairs(S.ROSTER) do if entry.name == "Buffy" then found = entry end end
check(found and found.dynamic, "Buffy is a dynamic member")
eq(S.Theme("Buffy").preset, "pearl", "Buffy follows default suite material")
WoW.installed.Buffy, WoW.loaded.Buffy = 2, true
S.Report("Buffy", { api = 1, built = "pearl", live = false, look = { tint = "clear", accent = "gold" } })
eq(S.State("Buffy"), "following", "Buffy report accepted")
S.SetFollow("Buffy", false)
eq(select(2, S.State("Buffy")), true, "follow change waits for reload")
S.SetFollow("Buffy", true)
S.SetLook("tint", "smoked")
eq(select(2, S.State("Buffy")), true, "tint change waits for reload")
done("test_buffy")
