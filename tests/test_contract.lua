-- The skin contract (docs/PLAN.md, "The skin contract"): on Blizzard's
-- objects, only C widget methods from the allowlist, a texture argument that
-- is nil (or a value read back from that texture), no Lua (mixin) method, no
-- field written, and every frame we make unnamed.
--
-- Over a whole session, not just the first pass: install, style, every hook
-- callback, a deferred pass and a combat wait, a failure, the switches off and
-- on, the master switch and every theme. A regression guard, not proof of
-- taint safety: that's each skin's in-game acceptance (docs/PLAN.md).
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

-- CLAUDE.md, "The skin contract". Getters (Get*, Is*) too.
local ALLOWED = { SetAlpha = true, SetVertexColor = true, SetDesaturated = true, SetShadowOffset = true,
                  SetShadowColor = true, SetTexture = true, SetAtlas = true, HookScript = true,
                  SetTextColor = true }   -- only on the audited titles: checked below

-- The audited titles (docs/PLAN.md, "The accent on Blizzard's titles", #71),
-- found by structure, never by what a kit registered: the tracker's headers,
-- the quest timers' title (#73), each meter window's title and the character
-- window's list headers (#94: a pooled row with a Name and a StateIcon).
local function audited()
    local set = {}
    local t = rawget(_G, "ObjectiveTrackerFrame")
    if t and t.Header then set[t.Header.Text] = true end
    for _, m in ipairs(t and t.modules or {}) do
        if m.Header then set[m.Header.Text] = true end
    end
    local q = rawget(_G, "QuestTimerFrame")
    if q then set[q.Header.Text] = true end
    for i = 1, 3 do
        local w = rawget(_G, "DamageMeterSessionWindow" .. i)
        if w then set[w.DamageMeterTypeDropdown.TypeName] = true end
    end
    for _, pool in pairs(WoW.panePools or {}) do
        for _, r in ipairs(pool) do if r.StateIcon then set[r.Name] = true end end
    end
    return set
end
local function unaudited()
    local set, out = audited(), {}
    for _, fs in ipairs(WoW.textColorCalls) do
        if not set[fs] then out[#out + 1] = fs end
    end
    return out
end

-- A skin that fails halfway through touching the merchant, and a protected
-- one on it: their callbacks run on Blizzard's objects too.
local GUI = loadAddon({ before = function()
    WoW.makeRestedXP()
    local E = GlassUI.Engine
    E.Register({ key = "failing", title = "failing", live = true, frames = function() return MerchantFrame end,
                 style = function(kit, f) kit:Fade(f.CloseButton); error("halfway") end })
    E.Register({ key = "held", title = "held", live = false, risk = "protected",
                 frames = function() return MerchantFrame end,
                 style = function(kit, f) kit:Blank(MerchantItem1.SlotTexture); kit:Shade(MerchantItem1.Name) end })
end })

-- The session.
WoW.combat = true
WoW.showMerchant()
WoW.flushTimers(0)
WoW.combat = false
WoW.fire("PLAYER_REGEN_ENABLED")
WoW.merchantTab(2)
WoW.asBlizzard(function() MerchantFrame.Bg:SetAlpha(0.5) end)
WoW.merchantTab(1)
-- The rows (#80): recoloured, emptied and filled; the buyback slot's icon.
WoW.merchantRow(1, "red"); WoW.merchantRow(2, "darkred"); WoW.merchantRow(3, "empty")
WoW.buybackSlot(133784); WoW.buybackSlot(nil)
WoW.merchantRow(1, "normal"); WoW.merchantRow(3, "normal")
WoW.hideMerchant()
WoW.showMerchant()
WoW.flushTimers(0)
-- The bags (#88): opened in combat, filled and emptied, combined, off and on
-- with an update while off.
WoW.combat = true
WoW.openBag(ContainerFrame1, { "empty", 133784, "empty" })
WoW.flushTimers(0)
WoW.combat = false
WoW.bagUpdate(ContainerFrame1, { 133784, 133784, "empty", "empty" })
WoW.openBag(ContainerFrameCombinedBags, { "empty", 134400 })
GUI._test.slash("skin bags off")
WoW.bagUpdate(ContainerFrameCombinedBags, { 134400, "empty", "empty" })
GUI._test.slash("skin bags on")
WoW.closeBag(ContainerFrameCombinedBags)
-- The game menu (#90): its first opening in combat, a refresh while open, off and on.
WoW.combat = true
WoW.showGameMenu()
WoW.flushTimers(0)
WoW.combat = false
WoW.gameMenuRefresh()
WoW.hideGameMenu()
GUI._test.slash("skin gamemenu off")
WoW.showGameMenu()
GUI._test.slash("skin gamemenu on")
WoW.hideGameMenu()
-- The guild window (#92): opened in combat, every mode, tabs clicked, a
-- tenant's tab and panel handed over, off and on.
local gsTab = CreateFrame("CheckButton", nil, CommunitiesFrame, "RightSideTabTemplate")
local gsHost = CreateFrame("Frame", nil, CommunitiesFrame)
GUI.Suite.SkinTab("GuildSpy", gsTab)
GUI.Suite.SkinPanel("GuildSpy", gsHost, function() end)
WoW.combat = true
WoW.showGuild()
WoW.flushTimers(0)
WoW.combat = false
for _, mode in ipairs({ "CHAT", "ROSTER", "GUILD_BENEFITS", "GUILD_INFO", "MINIMIZED", "CHAT" }) do WoW.guildMode(mode) end
WoW.clickTab(CommunitiesFrame.RosterTab)
GUI._test.slash("skin guild off")
WoW.guildMode("ROSTER")
GUI._test.slash("skin guild on")
WoW.hideGuild()
eq(#WoW.rosterHooks, 0, "no script hook on any roster frame (#92)")
-- The loot window and history (#105): looted in combat twice, a row
-- re-coloured, /loot, off and on.
WoW.combat = true
WoW.loot()
WoW.flushTimers(0)
WoW.closeLoot()
WoW.loot()
WoW.flushTimers(0)
WoW.combat = false
WoW.lootHistory(true)
WoW.flushTimers(0)
GUI._test.slash("skin loot off")
GUI._test.slash("skin loot on")
GUI._test.slash("skin loothistory off")
GUI._test.slash("skin loothistory on")
WoW.flushTimers(0)
WoW.closeLoot()
WoW.lootHistory(false)
-- The mirror timers: two at once in combat, a restart while shown, a new fill
-- object, Edit Mode, a stop, off and on.
WoW.combat = true
WoW.mirrorStart("BREATH", "Breath")
WoW.mirrorStart("EXHAUSTION", "Fatigue")
WoW.combat = false
WoW.mirrorFill = "swap"
WoW.mirrorStart("BREATH", "Breath")
WoW.mirrorFill = "reset"
WoW.mirrorEditMode(true)
WoW.mirrorStop("BREATH")
WoW.mirrorEditMode(false)
GUI._test.slash("skin mirror off")
GUI._test.slash("skin mirror on")
WoW.flushTimers(0)
WoW.mirrorStop("EXHAUSTION")
-- The trade window (#113): opened in combat, an unusable item offered and
-- taken back, off and on.
WoW.combat = true
WoW.trade()
WoW.flushTimers(0)
WoW.combat = false
WoW.tradeOffer.Recipient[2] = { icon = 5500, usable = false }
WoW.tradeSlot("Recipient", 2)
WoW.flushTimers(0)
WoW.tradeOffer.Recipient[2] = nil
WoW.tradeSlot("Recipient", 2)
WoW.flushTimers(0)
GUI._test.slash("skin trade off")
GUI._test.slash("skin trade on")
WoW.flushTimers(0)
WoW.closeTrade()
-- The gossip window and the quest dialog (#115, #114): opened in combat, the
-- setting to Dark and back, panels in turn, a greeting refresh, auto-accept,
-- off and on.
WoW.combat = true
WoW.gossip()
WoW.quest("Greeting")
WoW.flushTimers(0)
WoW.combat = false
WoW.setContrast(4)
WoW.questGreetingRefresh()
WoW.flushTimers(0)
WoW.questAutoAccept = true
WoW.quest("Detail")
WoW.quest("Progress")
WoW.quest("Reward")
WoW.flushTimers(0)
WoW.setContrast(0)
WoW.gossipUpdate("Kul")
WoW.flushTimers(0)
GUI._test.slash("skin gossip off")
GUI._test.slash("skin quest off")
GUI._test.slash("skin gossip on")
GUI._test.slash("skin quest on")
WoW.flushTimers(0)
WoW.closeQuest()
WoW.questAutoAccept = false
WoW.closeGossip()
WoW.flushTimers(0)
-- The quest details popup (#202): opened in combat, Dark, a quest-log
-- update, the setting changed, off and on.
WoW.combat = true
WoW.popupShow(7)
WoW.flushTimers(0)
WoW.combat = false
WoW.setCVar("questTextContrast", "4")
WoW.popupShow(7)
WoW.popupShow(8)
WoW.popupFullUpdate()
WoW.flushTimers(0)
WoW.setCVar("questTextContrast", "0")
WoW.popupFullUpdate()
WoW.flushTimers(0)
GUI._test.slash("skin questpopup off")
GUI._test.slash("skin questpopup on")
WoW.flushTimers(0)
WoW.closePopup()
-- The world map (#99): opened in combat, maximised, a map change, a quest
-- log update, scrolled, off and on.
WoW.combat = true
WoW.showMap()
WoW.flushTimers(0)
WoW.mapMaximize(true)
WoW.mapRefresh()
WoW.questLogUpdate()
WoW.flushTimers(0)
WoW.combat = false
WoW.questScroll(0.5)
WoW.mapMaximize(false)
WoW.flushTimers(0)
GUI._test.slash("skin map off")
GUI._test.slash("skin map on")
WoW.flushTimers(0)
WoW.hideMap()
-- The character window (#94): opened in combat, modes, the stats scrolled,
-- off and on; nothing touches the currency pane.
WoW.combat = true
WoW.showCharacter()
WoW.flushTimers(0)
WoW.combat = false
WoW.characterMode(5)
WoW.characterMode(1)
WoW.asBlizzard(function() CharacterStatsPaneScrollBox.ScrollBox:Update() end)
WoW.characterPane("ReputationFrame")
WoW.characterPane("SkillsFrame")
WoW.characterPane("StatisticsFrame")
WoW.characterPane(nil)
GUI._test.slash("skin character off")
GUI._test.slash("skin character on")
WoW.hideCharacter()
eq(#WoW.currencyTouches, 0, "nothing touches the currency pane (#94)")
-- RestedXP (#56): themes, a guide, steps with a tip, a hover, the collapse
-- and V2, the arrow turned, its text and font, both switches off and on.
WoW.rxpTheme()
WoW.rxpLoadGuide()
WoW.rxpSetStep({ { title = "Step 13" }, { title = "Tip", tip = true }, { title = "" } })
WoW.flushTimers(0)
WoW.rxpHover(RXPFrame.ScrollChild.framePool[1])
WoW.rxpTheme(0.4, 0.2, 0.1)
WoW.rxpCollapse(true)
WoW.rxpCollapse(false)
WoW.rxpV2(true)
WoW.rxpV2(false)
WoW.rxpTurn(0.7)
WoW.rxpArrowText("Step 13\n(300yd)")
WoW.rxpArrowShow()
WoW.rxpTurn(-1.1)
WoW.rxpArrowFont(14)
WoW.rxpArrowText("Step 13\n(290yd)")
WoW.flushTimers(0)
for _, cmd in ipairs({ "skin rxp off", "skin rxp on", "skin rxparrow off", "skin rxparrow on" }) do GUI._test.slash(cmd) end
WoW.rxpSetStep({ { title = "Step 14" } })
WoW.flushTimers(0)
-- The damage meter (#49): shown, its Background changed, a window added,
-- minimized, its breakdown, and one made while the skin is off.
WoW.showMeter()
WoW.meterBackground(1, 0.2)
WoW.meterWindow(2)
WoW.meterMinimize(1, true)
WoW.meterBreakdown(2, true)
-- The quest tracker (#55): layouts with pooled extras, collapses, Edit Mode,
-- and its switch off and on (blanks given back with the atlas read before).
WoW.layout("QuestObjectiveTracker", { blocks = 2, items = 1, groups = 1, bars = 1 })
WoW.collapseModule("QuestObjectiveTracker", true)
WoW.collapse(true)
WoW.collapse(false)
WoW.editMode(true)
WoW.editMode(false)
WoW.asBlizzard(function() ObjectiveTrackerFrame.NineSlice:SetAlpha(0.6) end)
-- The quest timers (#73): shown, grown, recoloured below, gone.
WoW.questTimers(1)
WoW.questTimers(2)
for _, cmd in ipairs({ "skin tracker off", "skin tracker on" }) do GUI._test.slash(cmd) end
-- The accent and the tint changed live, in combat too (#52, #67).
WoW.combat = true
GUI._test.slash("look accent ice")
GUI._test.slash("look tint smoked")
WoW.combat = false
GUI._test.slash("look accent gold")
GUI._test.slash("look tint clear")
WoW.layout("QuestObjectiveTracker", { blocks = 1, items = 2 })
WoW.questTimers(0)
for _, cmd in ipairs({ "skin merchant off", "skin merchant on", "skin meter off", "off", "on", "theme smoked",
                       "theme class", "theme clear", "skins", "skin held off" }) do
    GUI._test.slash(cmd)
    if cmd == "skin meter off" then WoW.meterWindow(3); WoW.meterBackground(3, 0.7) end
end
GUI._test.slash("skin meter on")
WoW.flushTimers(0)
WoW.hideMerchant()
WoW.showMerchant()
WoW.loadAddOn("SomeAddOn")

-- The record is live: the session did call into Blizzard's objects.
check((WoW.blizzCalls.SetAlpha or 0) > 0 and (WoW.blizzCalls.HookScript or 0) > 0,
      "the session called Blizzard objects (the record works)")
check((WoW.blizzCalls.SetTexture or 0) > 0, "and blanked a texture (the argument rule is exercised)")
local restored = 0
for _, a in ipairs(WoW.textureArgs) do
    if a[2] == "SetAtlas" and a[3] ~= nil then restored = restored + 1 end
end
check(restored > 0, "and gave an atlas back (the read-back rule is exercised)")
for name in pairs(WoW.blizzCalls) do
    check(ALLOWED[name] or name:match("^Get") or name:match("^Is"), "C method on the allowlist: " .. name)
end
-- nil, or a value our code read from that same texture with the matching
-- getter (the kit's restorable Blank, #55): never a value made up, nor one
-- read from another texture.
for _, a in ipairs(WoW.textureArgs) do
    check(a[3] == nil or WoW.readBack(a[1], a[2], a[3]),
          a[2] .. " on a Blizzard texture with nil or its own read-back value (got " .. tostring(a[3]) .. ")")
end
check(#WoW.textColorCalls > 0, "the titles were coloured (the audited-list rule is exercised)")
eq(#unaudited(), 0, "SetTextColor only on the audited titles")
eq(#WoW.luaCalls, 0, "no Lua method of Blizzard's called (" .. table.concat(WoW.luaCalls, ", ") .. ")")
local changes = WoW.fieldChanges()
eq(#changes, 0, "no field written on a Blizzard object (" .. table.concat(changes, ", ") .. ")")
check(GUI.failures["skin:failing:style"], "the failing skin did fail (the failure path ran)")

-- Our frames are unnamed.
local named = {}
for _, w in ipairs(WoW.frames) do
    if w._name then named[#named + 1] = w._name end
end
eq(#named, 0, "every frame the addon made is unnamed (" .. table.concat(named, ", ") .. ")")

-- The guard catches what it guards: a write, a Lua call and a texture made up
-- by addon code.
MerchantFrame.NineSlice.glassy = true
MerchantFrame.selectedTab = 2
MerchantFrame:UpdateMerchant()
MerchantFrame.Bg:SetTexture("Interface\\Buttons\\WHITE8X8")
local caught = table.concat(WoW.fieldChanges(), ",")
check(caught:find("glassy", 1, true) and caught:find("selectedTab", 1, true), "the guard sees new and changed fields")
eq(WoW.luaCalls[1], "UpdateMerchant", "the guard sees a Lua method call")
eq(WoW.textureArgs[#WoW.textureArgs][3], "Interface\\Buttons\\WHITE8X8", "the guard sees a texture argument")
check(not WoW.readBack(MerchantFrame.Bg, "SetTexture", "Interface\\Buttons\\WHITE8X8"), "a value made up is no read-back")
-- Read-back is per texture and per getter: another texture's atlas is refused.
local shine, glow = QuestObjectiveTracker.Header.Shine, QuestObjectiveTracker.Header.Glow
WoW.asBlizzard(function() shine:SetAtlas("UI-QuestTracker-OBJFX-Shine") end)
local read = shine:GetAtlas()
check(WoW.readBack(shine, "SetAtlas", read), "an atlas read from a texture may go back on it")
check(not WoW.readBack(glow, "SetAtlas", read), "but not on another texture")
check(not WoW.readBack(shine, "SetTexture", read), "nor through the other setter")
-- SetTextColor on anything else is caught, called directly or passed through
-- a kit (which would register it).
local line
WoW.asBlizzard(function() line = WoW.blizzObject("FontString", QuestObjectiveTracker) end)
line:SetTextColor(1, 0, 0)
eq(#unaudited(), 1, "the guard sees a quest line coloured directly")
WoW.textColorCalls = {}
local kit = GUI.Engine.byKey.tracker.kit
kit:TextColor(line, 1, 0, 0)
eq(#unaudited(), 1, "and one passed through the kit")
-- A quest timer's countdown is no title.
WoW.textColorCalls = {}
WoW.questTimers(1)
kit:TextColor(QuestTimerFrame.activeElements[1].Name, 1, 0, 0)
eq(#unaudited(), 1, "nor a timer's countdown")

-- One Blizzard setting, one writer (#203, docs/PLAN.md's audited exception):
-- over the shipped files, SetCVar only in QuestText.lua's writer, the CVar's
-- name written once there, and every setter call in a session aimed at it.
local function source(file)
    local f = assert(io.open(file, "rb"))
    local text = f:read("*a")
    f:close()
    return text
end
local writers, names = {}, 0
for _, file in ipairs(tocFiles()) do
    local text = source(file)
    -- Code only: comments dropped (a comment may name the setting).
    local code = text:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
    for _ in code:gmatch("SetCVar") do writers[#writers + 1] = file end
    for _ in code:gmatch('"questTextContrast"') do names = names + 1 end
end
eq(table.concat(writers, ","), "QuestText.lua", "SetCVar once in the shipped code, in QuestText.lua")
eq(names, 1, "the CVar's name written once, as QuestText's constant")
GUI = loadAddon()
GUI._test.slash("questtext on")
GUI._test.slash("questtext off")
WoW.setCVar("questTextContrast", "2")
GUI._test.slash("questtext on")
WoW.setCVar("questTextContrast", "1")
check(#WoW.cvar.sets >= 3, "the switch wrote (the record is exercised)")
for _, set in ipairs(WoW.cvar.sets) do
    eq(set[1], "questTextContrast", "every SetCVar aimed at questTextContrast")
end

done("test_contract")
