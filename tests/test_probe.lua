-- SkinProbe: every command and every procedure step runs on the stubbed client
-- without throwing, logs to its saved table and never to chat, puts back every
-- alpha it touches, and reads a gradient texture's ignored SetAlpha as such.
-- It is a ForeverProbe module: the host is loaded first, from its checkout
-- (harness.lua's loadForeverProbe).
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

-- What the probe reads beyond the shared stub (all in the 70374 dump:
-- C_InputInterfaceStyle :2151, INPUT_DEVICE_INTERFACE_TRANSITION :7494).
local style = 0
rawset(_G, "Enum", setmetatable({ InputDeviceInterfaceType = { KeyboardAndMouse = 0, Gamepad = 1 } },
    { __index = Enum }))
rawset(_G, "C_InputInterfaceStyle", { GetCurrentStyle = function() return style end })
rawset(_G, "GetCVar", function(name) return name == "GamePadEnable" and "0" or nil end)
rawset(_G, "GetTime", function() return 12.5 end)
rawset(_G, "time", function() return 1760500000 end)

-- The wave-1 windows, shaped like Forever's FrameXML: a shell with a NineSlice
-- of textures, one of which carries a gradient (it then ignores SetAlpha).
local function window(name, parent)
    local f = CreateFrame("Frame", name, parent or UIParent)
    f.NineSlice = CreateFrame("Frame", nil, f)
    f.NineSlice._parentKey = "NineSlice"
    for _, piece in ipairs({ "TopLeftCorner", "TopEdge", "Center" }) do
        local t = f.NineSlice:CreateTexture(nil, "BORDER")
        t:SetAlpha(0.8)
        f.NineSlice[piece] = t
        t._parentKey = piece
    end
    f.Bg = f:CreateTexture(nil, "BACKGROUND")
    return f
end
local merchant = window("MerchantFrame")
local streak = merchant:CreateTexture(nil, "ARTWORK")
streak:SetColorTexture(1, 1, 1, 1)
streak:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 1))
for i = 1, 4 do window("StaticPopup" .. i) end
StaticPopup1:Hide(); StaticPopup2:Hide(); StaticPopup3:Hide(); StaticPopup4:Hide()
local character = window("CharacterFrame")
for _, pane in ipairs({ "PaperDollFrame", "ReputationFrame", "SkillsFrame", "PVPRankFrame", "TokenFrame",
                        "StatisticsFrame" }) do
    window(pane, character)
end
local map = window("WorldMapFrame")
map.BorderFrame = window(nil, map)
-- The maximise button, as on Forever: a Button two levels into the border.
map.BorderFrame.MaximizeMinimizeFrame = CreateFrame("Frame", nil, map.BorderFrame)
local maximize = CreateFrame("Button", nil, map.BorderFrame.MaximizeMinimizeFrame)
local maximizeArt = maximize:CreateTexture(nil, "ARTWORK")
window("QuestMapFrame", map)

-- #49, the damage meter as on Forever (Blizzard_DamageMeter, origin/forever
-- @70450): DamageMeter with its Edit Mode getters, one session window with a
-- header, a background (its alpha Blizzard's), a breakdown and one bar.
Enum.DamageMeterStyle = { Default = 0, Bordered = 1, Thin = 2 }
local meterStyle = 1
local meter = CreateFrame("Frame", "DamageMeter", UIParent)
function meter:GetStyle() return meterStyle end
function meter:GetBackgroundAlpha() return 0.5 end
local meterWin = CreateFrame("Frame", "DamageMeterSessionWindow1", meter)
meterWin.Header = meterWin:CreateTexture(nil, "BACKGROUND")
meterWin.Header:SetAtlas("ui-damagemeters-header-bar")
meterWin.MinimizeContainer = CreateFrame("Frame", nil, meterWin)
meterWin.MinimizeContainer.Background = meterWin.MinimizeContainer:CreateTexture(nil, "BACKGROUND")
meterWin.MinimizeContainer.Background:SetAlpha(0.5)
meterWin.MinimizeContainer.SourceWindow = CreateFrame("Frame", nil, meterWin.MinimizeContainer)
local meterBar = CreateFrame("Button", nil, meterWin.MinimizeContainer)
meterBar.StatusBar = CreateFrame("StatusBar", nil, meterBar)
meterBar.StatusBar.Background = meterBar.StatusBar:CreateTexture(nil, "BACKGROUND")
meterBar.StatusBar.Background:SetAtlas("UI-HUD-CoolDownManager-Bar-BG")
local meterBars = { meterBar }
function meterWin:ForEachEntryFrame(fn) for _, b in ipairs(meterBars) do fn(b) end end
function meterWin:GetSourceWindow() return self.MinimizeContainer.SourceWindow end

local FP = loadForeverProbe()
local function skin(s) SlashCmdList.FOREVERPROBE("skin " .. s) end
local ns = {}
assert(loadfile("Tools/SkinProbe/SkinProbe.lua"))("SkinProbe", ns)
local T = ns._test
WoW.fire("ADDON_LOADED", "SkinProbe")
eq(type(SkinProbeDB.log), "table", "the probe keeps its log in saved variables")
check(T.Probe.log == SkinProbeDB.log, "its ForeverProbe log is SkinProbeDB.log, bound at ADDON_LOADED")
eq(FP.byCmd.skin, T.Probe, "/fp skin is SkinProbe")
eq(SkinProbeDB.loads, 1, "it counts its loads")

local function logHas(text)
    for _, l in ipairs(SkinProbeDB.log) do if l:find(text, 1, true) then return true end end
    return false
end
local function logCount(text)
    local n = 0
    for _, l in ipairs(SkinProbeDB.log) do if l:find(text, 1, true) then n = n + 1 end end
    return n
end

-- Every command, through the host's slash command.
for _, cmd in ipairs({ "", "state", "tree merchant", "tree popup 2", "tree character", "tree map",
                       "tree nothing", "fade merchant", "panels on", "border fade", "border restore",
                       "panels off", "gradient on", "gradient off", "clear" }) do
    skin(cmd)
end
eq(#WoW.chat, 0, "nothing went to chat: every line is in the console and the log")

-- W1.1 / W1.4 / W1.5 / neighbours.
T.Probe:ClearLog()
SLASH_GLASSUI2 = "/gui"
rawset(_G, "SLASH_SOMEONEELSE1", "/GUI")
WoW.loaded.Leatrix_Maps = true
rawset(_G, "LeaMapsDB", {})
T.state()
check(logHas("W1.4 style=0 Gamepad=1 -> gamepad false"), "W1.4 reads the style against Enum's Gamepad")
check(logHas("SLASH_GLASSUI2") and logHas("SLASH_SOMEONEELSE1"), "W1.5 finds every /gui, any case")
check(logHas("W1.5 owners other than Glass UI: 1"), "W1.5 counts the others")
-- The answers are kept apart from the log, so trimming can't lose them.
local R = SkinProbeDB.results
eq(R["W1.5"].others, 1, "W1.5 is in the results table")
eq(R["W1.4"].gamepad, false, "W1.4 is in the results table")
eq(R.leatrixSimpleFrame, true, "Leatrix's mode is in the results table")
check(type(R["W1.1.MerchantFrame"]) == "string" and R["W1.1.MerchantFrame"]:find("protected=", 1, true),
      "each W1.1 frame is in the results table")
check(logHas("Leatrix Maps SimpleMapFrame=nil -> simple frame true"), "Leatrix's unset option is its default On")
check(logHas("W1.1 merchant MerchantFrame Frame protected="), "W1.1 describes each frame")
style = 1
T.gamepad()
check(logHas("-> gamepad true"), "W1.4 sees the gamepad style")
rawset(_G, "SLASH_SOMEONEELSE1", nil)

-- W1.2: the tree reaches the NineSlice pieces, by parentKey or index.
T.Probe:ClearLog()
local lines = T.tree("merchant")
check(lines > 6, "the merchant tree has its frame, NineSlice and textures (" .. lines .. ")")
check(logHas("W1.2 R MerchantFrame.NineSlice.TopEdge Texture"), "regions are listed under their frame's path, by parentKey")
check(logHas("W1.2 R MerchantFrame.#2 Texture"), "a region without a key or name is listed by its index")
eq(T.tree("nothing"), 0, "an unknown target lists nothing")
check(logHas("unknown target"), "and says so")

-- W1.2 fade: the gradient texture is caught, every alpha is put back.
T.Probe:ClearLog()
local tried, ignored = T.fade("merchant")
eq(ignored, 1, "exactly the gradient texture ignores SetAlpha")
eq(SkinProbeDB.results["W1.2.fade.merchant"].ignored, 1, "the fade count is in the results table")
check(SkinProbeDB.results["W1.2.fade.merchant"].which:find("MerchantFrame.#2", 1, true), "with the texture's path")
check(tried >= 5, "every texture of the window was tried (" .. tostring(tried) .. ")")
near(merchant.NineSlice.TopEdge:GetAlpha(), 0.8, "a faded texture gets its alpha back")
check(logHas("IGNORES SetAlpha"), "the ignoring texture is named")
WoW.combat = true
eq(T.fade("merchant"), nil, "no fade in combat")
WoW.combat = false

-- W1.3: two panels of our own on the map, removed again; the border art faded
-- and restored to what it was.
check(T.panelsOn(), "panels go on")
check(T.panels.under and T.panels.over, "both panels exist")
eq(T.panels.under:GetParent(), map, "the panels are the map's children")
check(T.panels.over:GetFrameLevel() > T.panels.under:GetFrameLevel(), "over sits above under")
T.panelsOff()
eq(next(T.panels), nil, "panels off removes both")
local nb = T.borderFade()
eq(maximizeArt:GetAlpha(), 1, "a button's art is never faded (the first run hid the maximise button)")
check(nb >= 4, "the border's textures fade (" .. nb .. ")")
eq(map.BorderFrame.NineSlice.Center:GetAlpha(), 0, "a border texture is at 0 while faded")
eq(T.borderRestore(), nb, "every faded texture is restored")
near(map.BorderFrame.NineSlice.Center:GetAlpha(), 0.8, "to its old alpha")
eq(next(T.faded), nil, "nothing is left recorded")
WoW.combat = true
eq(T.panelsOn(), false, "no panels in combat")
WoW.combat = false

-- W1.6: the squares' readbacks follow the stub's measured behaviour.
local r = T.gradientOn()
eq(r.A, 1, "A (gradient, then SetAlpha 0) reads 1")
eq(r.B, 1, "B (SetAlpha 0, then gradient) reads 1: the gradient undoes the earlier alpha (70374)")
eq(r.C, 1, "C (image texture, gradient, then SetAlpha 0) reads 1 (70374)")
eq(r.D, 0, "D (no gradient) reads 0")
eq(SkinProbeDB.results["W1.6.readback"].B, 1, "the readback is in the results table")
T.gradientOff()

-- #4: the looks compared through Glass UI's Theme (a stand-in here), and put
-- back. The player's theme is saved in SkinProbeDB before the first trial,
-- not kept in memory: the procedure survives a /reload, and Theme.Set saves
-- each trial theme (Codex, PR #19).
eq(T.themeTry("clear", 0.6), false, "without Glass UI, nothing to compare")
local current = "class"
local presets = { clear = { backing = 0.85 }, smoked = { backing = 0.92 }, class = { backing = 0.85 } }
rawset(_G, "GlassUI", { Theme = { PRESETS = presets, Name = function() return current end,
                                  Set = function(n) current = n end } })
local name, used = T.themeTry("clear", 0.6)
check(name == "clear" and used == 0.6 and current == "clear", "a trial: clear at a lighter backing")
eq(SkinProbeDB.themeWas.name, "class", "the player's theme is saved before the first trial")
eq(select(2, T.themeTry("smoked")), 0.92, "smoked keeps its own backing")
T.themeTry("clear", 0.35)
T.themeRestore()
eq(presets.clear.backing, 0.85, "Restore puts the shipped backing back")
eq(current, "class", "and the player's theme")
eq(SkinProbeDB.themeWas, nil, "and forgets it")
-- A /reload mid-comparison: the last session saved "smoked" as the player's
-- theme and left the trial "class" selected; the backing is back to shipped
-- (it lives in code). A trial after resuming keeps the saved original, and
-- Restore gives it back.
SkinProbeDB.themeWas = { name = "smoked", backing = 0.85 }
current = "class"
T.themeTry("clear", 0.6)
eq(SkinProbeDB.themeWas.name, "smoked", "after a reload, a trial keeps the saved original")
T.themeRestore()
eq(current, "smoked", "and Restore gives the player's theme back after a reload")
eq(presets.clear.backing, 0.85, "with the shipped backing")
-- Each look the merchant procedure shows is the one its button names, whatever
-- clear ships with (the stand-in now ships Glass UI's own 0.35; Codex, PR #22:
-- a trial that fell back to the shipped value showed 0.35 under a 0.85 label).
presets.clear.backing = 0.35
SkinProbeDB.themeWas = nil
local shown = 0
for _, st in ipairs(FP.procedures["SkinProbe/merchant"].steps) do
    local label = st.button and st.button:match("^Clear (%d%.%d+)$")
    if label then
        local _, b = st.run()
        eq(b, tonumber(label), "the step labelled " .. st.button .. " shows backing " .. label)
        shown = shown + 1
    end
end
eq(shown, 3, "three clear trials")
T.themeRestore()
eq(presets.clear.backing, 0.35, "and Restore gives the shipped backing back")
rawset(_G, "GlassUI", nil)

-- #17: Blizzard's card. Without C_Texture (another build), nothing to report;
-- with it, the atlas is read and the card shown beside our glass (Glass UI
-- isn't loaded here: only the card), then removed.
eq(T.cardAtlas(), nil, "no C_Texture: the atlas reads as unknown")
rawset(_G, "C_Texture", { GetAtlasExists = function(a) return a == "Mode-Selection-Card-Regular" end,
                          GetAtlasInfo = function() return { width = 200, height = 430 } end })
local exists, w, h = T.cardAtlas()
check(exists == true and w == 200 and h == 430, "the atlas and its size are read")
eq(SkinProbeDB.results["CARD.atlas"].width, 200, "and kept in the results table")
local okAtlas, painted = T.cardOn()
check(okAtlas, "the card is shown")
eq(painted, 0, "without Glass UI, only Blizzard's card")
T.cardOff()
T.Probe:ClearLog()
T.cardOn()
check(logHas("CARD shown"), "after Remove, Show builds the cards again: nothing was left behind")
T.cardOff()

-- #24, the suite procedure: addon combinations for this character only (the
-- GUID), saved first and restored; each session read from Glass UI's record
-- and the addons' own glass; a session that doesn't match is a FAIL.
local calls = {}
rawset(C_AddOns, "EnableAddOn", function(name, character)
    calls[#calls + 1] = { "enable", name, character }
    WoW.installed[name] = 2
end)
rawset(C_AddOns, "DisableAddOn", function(name, character)
    calls[#calls + 1] = { "disable", name, character }
    WoW.installed[name] = 0
end)
WoW.installed = { GlassUI = 2, GlassUnitFrames = 2, GlassRaidFrames = 0 }
local follow, answers, reports, states = {}, {}, {}, {}
local function fakeSuite()
    rawset(_G, "GlassUI", { failures = {}, Suite = {
        API = 1,
        Following = function(n) return follow[n] == true end,
        SetFollow = function(n, on) follow[n] = on or nil; return true end,
        State = function(n) return states[n] end,
        AnswerOf = function(n) return answers[n] end,
        ReportOf = function(n) return reports[n] end,
    } })
end
local function member(ns, db, preset, gloss)
    rawset(_G, ns, { Glass = setmetatable({}, { __index = { preset = preset, STYLE = { gloss = gloss, frost = 0.1,
        wash = 0.18, innerShadow = 0.15 } } }) })
    rawset(_G, db, { look = "clean", glassBody = "smoked", rim = 0.9 })
end
fakeSuite()
follow.GlassUnitFrames = true
eq(T.suiteSnapshot(), true, "the enable states and Follow switches are saved")
eq(SkinProbeDB.suiteWas[WoW.GUID].enabled.GlassRaidFrames, 0, "with each addon's state, under this character's GUID")
eq(SkinProbeDB.suiteWas[WoW.GUID].follow.GlassUnitFrames, true, "and its Follow switch")
WoW.installed.GlassRaidFrames = 2
T.suiteSnapshot()
eq(SkinProbeDB.suiteWas[WoW.GUID].enabled.GlassRaidFrames, 0, "a second snapshot keeps the first: it is what to restore")
-- Another character: its own snapshot, and nothing of the first is restored onto it.
local firstGUID = WoW.GUID
WoW.GUID = "Player-4618-0FFFFFFF"
check(SkinProbeDB.suiteWas[WoW.GUID] == nil, "nothing saved yet for another character")
local before = #calls
local okOther, whyOther = T.suiteRestore()
check(okOther and whyOther:find("nothing to restore", 1, true), "restore on another character finds nothing of the first")
eq(#calls, before, "and changes nothing")
check(SkinProbeDB.suiteWas[firstGUID] ~= nil, "the first character's snapshot is kept")
WoW.GUID = firstGUID
local okSet, detail = T.suiteSet({ GlassUnitFrames = true })
check(okSet, "a combination is set and read back: " .. tostring(detail))
eq(WoW.installed.GlassUI, 0, "Glass UI off for it")
eq(WoW.installed.GlassRaidFrames, 0, "Raid Frames off")
eq(WoW.installed.GlassUnitFrames, 2, "Unit Frames on")
local byGUID = #calls > 0
for _, c in ipairs(calls) do byGUID = byGUID and c[3] == WoW.GUID end
check(byGUID, "every change names this character's GUID (a name changes nothing, none means every character)")
rawset(_G, "GlassUI", nil)
local n = #calls
eq((T.suiteSet({ GlassUI = true }, true)), false, "Follow can't be set without Glass UI")
eq(#calls, n, "and then nothing changes")
-- A session that matches "all, following", and the ways one doesn't.
fakeSuite()
local ALLSET = { GlassUI = true, GlassUnitFrames = true, GlassRaidFrames = true }
WoW.loaded.GlassUI, WoW.loaded.GlassUnitFrames, WoW.loaded.GlassRaidFrames = true, true, true
member("GlassUF", "GlassUnitFramesDB", "pearl", 0.12)
member("GlassRaidFrames", "GlassRaidFramesDB", "pearl", 0.12)
for _, nm in ipairs({ "GlassUnitFrames", "GlassRaidFrames" }) do
    answers[nm] = { ready = true, preset = "pearl" }
    reports[nm] = { built = "pearl", minor = 11 }
    states[nm] = "following"
end
local pass, why = T.suiteCheck("all, following", ALLSET, true)
check(pass, "a matching session passes: " .. tostring(why))
eq(SkinProbeDB.results["S.all, following"].GlassUnitFrames.built, "pearl", "the session is kept in the results")
answers.GlassRaidFrames.ready = false
pass, why = T.suiteCheck("all, following", ALLSET, true)
check(not pass and why:find("before Glass UI was ready", 1, true), "S.2: an answer given before ready fails")
answers.GlassRaidFrames.ready = true
reports.GlassUnitFrames.built = nil
pass, why = T.suiteCheck("all, following", ALLSET, true)
check(not pass and why:find("GlassUnitFrames built", 1, true), "a member that didn't build Pearl fails")
reports.GlassUnitFrames.built = "pearl"
GlassUI.failures.x = "boom"
pass, why = T.suiteCheck("all, following", ALLSET, true)
check(not pass and why:find("failure", 1, true), "a Glass UI failure fails the session")
GlassUI.failures.x = nil
-- Its own look is the saved one, Pearl when none is saved.
for _, nm in ipairs({ "GlassUnitFrames", "GlassRaidFrames" }) do
    reports[nm] = { built = nil }; answers[nm] = { ready = true, reason = "not-following" }; states[nm] = "own"
end
GlassUnitFramesDB.look, GlassRaidFramesDB.look = nil, nil
pass, why = T.suiteCheck("own, default", ALLSET, false)
check(pass, "own look on the default: Pearl is right: " .. tostring(why))
GlassRaidFramesDB.look = "clean"
pass, why = T.suiteCheck("own, saved clean", ALLSET, false)
check(not pass and why:find("wanted clean", 1, true), "a saved Clean built as Pearl fails")
GlassRaidFramesDB.look = nil
for _, nm in ipairs({ "GlassUnitFrames", "GlassRaidFrames" }) do
    reports[nm] = { built = "pearl" }; answers[nm] = { ready = true, preset = "pearl" }; states[nm] = "following"
end
pass = T.suiteCheck("all, following", { GlassUI = true, GlassUnitFrames = true }, true)
eq(pass, false, "a member loaded that shouldn't be fails")
-- S.3: own look again, against an earlier session.
for _, nm in ipairs({ "GlassUnitFrames", "GlassRaidFrames" }) do
    reports[nm] = { built = nil }
    answers[nm] = { ready = true, reason = "not-following" }
    states[nm] = "own"
end
member("GlassUF", "GlassUnitFramesDB", "clean", 0.25)
member("GlassRaidFrames", "GlassRaidFramesDB", "clean", 0.25)
pass, why = T.suiteCheck("all, own", ALLSET, false)
check(pass, "own look passes: " .. tostring(why))
pass, why = T.suiteCheck("all, own again", ALLSET, false, "all, own")
check(pass, "the same look and saved keys again passes: " .. tostring(why))
GlassUnitFramesDB.rim = 0.5
pass, why = T.suiteCheck("all, own again", ALLSET, false, "all, own")
check(not pass and why:find("db.rim", 1, true), "a saved key that changed fails S.3")
GlassUnitFramesDB.rim = 0.9
member("GlassRaidFrames", "GlassRaidFramesDB", "clean", 0.2)
pass, why = T.suiteCheck("all, own again", ALLSET, false, "all, own")
check(not pass and why:find("gloss", 1, true), "a look that differs from the earlier session fails S.3")
-- ADDON_ACTION_BLOCKED is counted.
SkinProbeDB.suiteBlocked = 0
WoW.fire("ADDON_ACTION_BLOCKED", "GlassUI", "CastSpell")
eq(SkinProbeDB.suiteBlocked, 1, "a blocked action is counted for S.7")
SkinProbeDB.suiteBlocked = 0
-- Restore: the saved states and switches come back.
follow.GlassUnitFrames = nil
local okRestore = T.suiteRestore()
check(okRestore, "restore reads its changes back")
eq(WoW.installed.GlassRaidFrames, 0, "Raid Frames back to disabled, as saved")
eq(WoW.installed.GlassUI, 2, "Glass UI back on")
eq(follow.GlassUnitFrames, true, "the Follow switch is back")
eq(SkinProbeDB.suiteWas[WoW.GUID], nil, "and this character's snapshot is cleared")
T.suiteSnapshot()

-- #49: the meter's state names the style and reads each window's bars.
local style, windows = T.meterState("test")
eq(style, "Bordered", "the style by its enum name")
eq(windows, 1, "one session window")
local line = SkinProbeDB.results["DM.test"]
check(line:find("window1 shown=true", 1, true), "the window is read")
check(line:find("header=ui-damagemeters-header-bar", 1, true), "with its header atlas")
check(line:find("bars=1 bar1", 1, true), "and its first bar")
check(line:find("bg=UI-HUD-CoolDownManager-Bar-BG", 1, true), "whose background atlas the style sets")
meterStyle = 7
eq(T.meterStyle(), "7", "an unknown style reads as its number")
meterStyle = 2
eq(T.meterStyle(), "Thin", "Thin")
meterBars = {}
check(T.meterState("no bars") ~= nil, "a window without bars is read too")
check(not SkinProbeDB.results["DM.no bars"]:find("bar1", 1, true), "and has no bar line")
meterBars = { meterBar }
check(T.tree("meter", 8) > 0, "the meter's tree walks")
-- PR #50 review: a solo fight may fill only window 2, and only a pinned
-- breakdown survives the Measure click.
local win2 = CreateFrame("Frame", "DamageMeterSessionWindow2", meter)
win2.MinimizeContainer = CreateFrame("Frame", nil, win2)
local src2 = CreateFrame("Frame", nil, win2.MinimizeContainer)
win2.MinimizeContainer.SourceWindow = src2
src2.CloseButton = CreateFrame("Button", nil, src2)
local bar2 = CreateFrame("Button", nil, win2.MinimizeContainer)
function win2:ForEachEntryFrame(fn) fn(bar2) end
meterBars = {}
local walked = T.barTree("solo")
check(walked > 0, "the bar tree walks the window that has a bar")
meterWin.MinimizeContainer.SourceWindow:Hide()
src2.CloseButton:Hide()
eq(T.sourceWindow(true), nil, "a breakdown that isn't pinned doesn't count")
eq(T.sourceWindow(), src2, "though it is the open one")
src2.CloseButton:Show()
eq(T.sourceWindow(true), src2, "pinned, in window 2")
src2:Hide()
eq(T.sourceWindow(), nil, "no breakdown open")
meterBars = { meterBar }
win2:Hide()

-- The procedures are defined and every step's run, wait and check works here.
for _, name in ipairs({ "wave1", "map", "gradient", "merchant", "card", "suite", "suitecombat", "meter" }) do
    local p = FP.procedures["SkinProbe/" .. name]
    check(p ~= nil, "procedure " .. name .. " is defined")
    if p then
        for i, st in ipairs(p.steps) do
            if st.run then
                local ok, err = pcall(st.run)
                check(ok, name .. " step " .. i .. " runs: " .. tostring(err))
            end
            if st.wait then
                local ok, err = pcall(st.wait)
                check(ok, name .. " step " .. i .. " wait runs: " .. tostring(err))
            end
            if st.check then
                local ok, err = pcall(st.check)
                check(ok, name .. " step " .. i .. " check runs: " .. tostring(err))
            end
        end
    end
end
T.panelsOff(); T.borderRestore(); T.gradientOff()
T.suiteRestore()
rawset(_G, "GlassUI", nil)
eq(#WoW.chat, 0, "still nothing in chat after every procedure step")

done("test_probe")
