-- Every widget method the addon calls must exist on this client, on that
-- widget type.
--
-- The stub answers any Capitalised method call (a no-op for ones it does not
-- implement), so a call to a method Forever lacks would otherwise pass
-- silently. The addon is exercised as widely as is cheap, then WowTestKit's
-- Kit.checkMethods checks each recorded "Type:Method" against the pinned
-- build's widget methods. Keep it exercising every handler the addon installs.
-- It does NOT prove argument contracts, event behaviour or protection rules:
-- that is the in-game pass (docs/FOREVER-PROBE.md).
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local GUI = loadAddon({ before = WoW.makeRestedXP })

-- Every command and every skin's pass; later milestones add theirs here.
WoW.showMerchant()
WoW.merchantTab(2)
WoW.asBlizzard(function() MerchantFrame.Bg:SetAlpha(0.5) end)
WoW.openBag(ContainerFrame1, { "empty", 133784 })
WoW.showGameMenu()
WoW.gameMenuRefresh()
GUI.Suite.SkinTab("GuildSpy", CreateFrame("CheckButton", nil, CommunitiesFrame, "RightSideTabTemplate"))
GUI.Suite.SkinPanel("GuildSpy", CreateFrame("Frame", nil, CommunitiesFrame), function() end)
WoW.showGuild()
WoW.guildMode("ROSTER")
WoW.showCharacter()
WoW.characterMode(2)
WoW.showMap()
WoW.flushTimers(0)
WoW.loot()
WoW.lootHistory(true)
WoW.tradeOffer.Recipient[1] = { icon = 5500, usable = false }
WoW.trade()
WoW.flushTimers(0)
WoW.mapMaximize(true)
WoW.flushTimers(0)
WoW.rxpTheme()
WoW.rxpLoadGuide()
WoW.rxpSetStep()
WoW.rxpTurn(0.5)
WoW.rxpArrowText("Step 13\n(300yd)")
WoW.rxpArrowShow()
WoW.rxpArrowFont(12)
WoW.flushTimers(0)
WoW.mirrorStart("BREATH", "Breath")
WoW.mirrorStart("BREATH", "Breath")
WoW.mirrorEditMode(true)
WoW.mirrorEditMode(false)
WoW.characterPane("StatisticsFrame")
WoW.clickTab(CommunitiesFrame.ChatTab)
WoW.openBag(ContainerFrameCombinedBags, { 133784, "empty" })
GUI.Bags.SetHeaderHeight(30)
GUI.Suite.Theme("GlassUnitFrames")
GUI.Suite.Report("GlassRaidFrames", { api = 1, options = function() end, clickCast = { open = function() end, others = true } })
GUI.Options._test.panel:Show()
GUI.Options._test.lookPanel:Show()
GUI.Options._test.lookRows["Tint"][2]:Click()
for _, cmd in ipairs({ "failures", "version", "help", "", "skins", "skin merchant off", "skin merchant on",
                       "skin bags off", "skin bags on", "skin gamemenu off", "skin gamemenu on",
                       "skin guild off", "skin guild on", "skin character off", "skin character on", "skin map off", "skin map on", "skin loot off", "skin loot on", "skin loothistory off",
                       "skin loothistory on", "skin trade off", "skin trade on", "skin rxp off", "skin rxp on",
                       "skin rxparrow off", "skin rxparrow on", "skin mirror off", "skin mirror on",
                       "off", "on", "theme smoked", "theme class", "theme clear",
                       "suite", "suite follow glassunitframes on", "options",
                       "look", "look tint class", "look preset soft" }) do
    GUI._test.slash(cmd)
end
WoW.flushTimers()

local recorded = Kit.checkMethods()
-- The floor is what this exercise records today, rounded down: it keeps the
-- exercise from quietly shrinking.
check(recorded >= 130, "the exercise reached every skin and command (" .. recorded .. " methods recorded)")
eq(next(GUI.failures), nil, "no failures recorded while exercising everything")
for k, v in pairs(GUI.failures) do io.write("    " .. k .. ": " .. v .. "\n") end
-- FINDING: the help's and the look's bare "|" lines (harness.lua, acceptKnownStrays).
check(acceptKnownStrays() > 0, "the help's known bare-| lines, let through until they're doubled")
done("test_methods")
