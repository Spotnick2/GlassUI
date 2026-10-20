-- Every widget method the addon calls must exist on this client.
--
-- The stub answers any Capitalised method call (a no-op for ones it does not
-- implement), so a call to a method Forever lacks would otherwise pass
-- silently. This checks each recorded "Type:Method" against the API dump's
-- widget-method walk. Keep it exercising every handler the addon installs.
-- It does NOT prove argument contracts, event behaviour or protection rules:
-- that is the in-game pass (docs/FOREVER-PROBE.md).
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local f = io.open(WoW.DUMP, "r")
if not f then
    io.write("test_methods: SKIPPED (no API dump at " .. WoW.DUMP .. ")\n")
    os.exit(0)
end
local widget, documented = {}, {}
for line in f:lines() do
    local wm = line:match("^(%a+:%a+)%s*$")
    if wm then widget[wm] = true end
    local fn = line:match("^([%a_]+)%(")
    if fn then documented[fn] = true end
end
f:close()

WoW.methodsCalled = {}
local GUI = loadAddon()

-- Every command and every skin's pass; later milestones add theirs here.
WoW.showMerchant()
WoW.merchantTab(2)
WoW.asBlizzard(function() MerchantFrame.Bg:SetAlpha(0.5) end)
WoW.openBag(ContainerFrame1, { "empty", 133784 })
WoW.showGameMenu()
WoW.gameMenuRefresh()
WoW.openBag(ContainerFrameCombinedBags, { 133784, "empty" })
GUI.Bags.SetHeaderHeight(30)
GUI.Suite.Theme("GlassUnitFrames")
GUI.Suite.Report("GlassRaidFrames", { api = 1, options = function() end, clickCast = { open = function() end, others = true } })
GUI.Options._test.panel:Show()
GUI.Options._test.lookPanel:Show()
GUI.Options._test.lookRows["Tint"][2]:Click()
for _, cmd in ipairs({ "failures", "version", "help", "", "skins", "skin merchant off", "skin merchant on",
                       "skin bags off", "skin bags on", "skin gamemenu off", "skin gamemenu on",
                       "off", "on", "theme smoked", "theme class", "theme clear",
                       "suite", "suite follow glassunitframes on", "options",
                       "look", "look tint class", "look preset soft" }) do
    GUI._test.slash(cmd)
end
WoW.flushTimers()

local n = 0
for name in pairs(WoW.methodsCalled) do
    n = n + 1
    local method = name:match(":(%a+)$")
    check(widget[name] or documented[method], "method exists on Forever: " .. name)
end
check(n > 1, "recorded a realistic number of methods (raise it as features land) (" .. n .. ")")
eq(next(GUI.failures), nil, "no failures recorded while exercising everything")
for k, v in pairs(GUI.failures) do io.write("    " .. k .. ": " .. v .. "\n") end
done("test_methods")
