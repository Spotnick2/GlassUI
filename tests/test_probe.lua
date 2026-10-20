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
meterBar.StatusBar.BackgroundEdge = meterBar.StatusBar:CreateTexture(nil, "OVERLAY")
local meterFill = meterBar.StatusBar:CreateTexture(nil, "ARTWORK")
function meterBar.StatusBar:GetStatusBarTexture() return meterFill end
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

-- #58, Glass Panel in the suite: read as a member, Pearl either way, its edge
-- read and announced; only its Follow switch changes, and it comes back.
WoW.loaded.GlassPanel = true
local panelTop, panelBar = nil, true
rawset(_G, "GlassPanel", { failures = {},
    Glass = setmetatable({}, { __index = { preset = "pearl", STYLE = { gloss = 0.15, frost = 0.06, wash = 0.1,
        innerShadow = 0.15 } } }),
    Bar = { frame = { IsShown = function() return panelBar end } },
    EdgeState = function() return panelTop and { top = panelTop } or nil end })
rawset(_G, "GlassPanelDB", { glass = "clear", glassTint = "neutral", windowGlass = "reflective" })
follow.GlassPanel = true
answers.GlassPanel = { ready = true, preset = "pearl" }
reports.GlassPanel = { built = "pearl", minor = 11 }
states.GlassPanel = "following"
pass, why = T.panelCheck("following", true)
check(not pass and why:find("no EdgeState yet", 1, true), "no edge measured yet fails")
panelTop = 24
pass, why = T.panelCheck("following", true)
check(not pass and why:find("never announced", 1, true), "an edge never announced fails")
EventRegistry:TriggerEvent("GlassPanel.EdgeChanged", 24)
pass, why = T.panelCheck("following", true)
check(pass, "a matching session passes: " .. tostring(why))
eq(SkinProbeDB.results["P.following"].saved.glass, "clear", "with its saved glass kept in the results")
eq(SkinProbeDB.results["P.following"].edge, 24, "and its edge")
reports.GlassPanel.built = nil
pass, why = T.panelCheck("following", true)
check(not pass and why:find("built nil", 1, true), "following without building Pearl fails")
reports.GlassPanel.built = "pearl"
reports.GlassPanel.minor = 10
pass, why = T.panelCheck("following", true)
check(not pass and why:find("Pearl needs 11", 1, true), "a library older than r11 fails")
reports.GlassPanel.minor = 11
pass, why = T.panelCheck("following", false)
check(not pass and why:find("Follow switch true", 1, true), "a Follow switch that doesn't match fails")
GlassPanel.failures.x = "boom"
pass, why = T.panelCheck("following", true)
check(not pass and why:find("failure", 1, true), "a failure of Glass Panel's own fails the session")
GlassPanel.failures.x = nil
-- The edge: the bar's height at least while it shows; the last announcement matches out of combat.
panelTop = 0
pass, why = T.panelCheck("following", true)
check(not pass and why:find("under the bar", 1, true), "an edge under the bar while it shows fails")
panelBar = false
pass, why = T.panelCheck("following", true)
check(not pass and why:find("last announced 24", 1, true), "an edge moved and not announced fails")
WoW.combat = true
pass = T.panelCheck("following", true)
check(pass, "in combat the announcement waits: not a failure")
WoW.combat = false
EventRegistry:TriggerEvent("GlassPanel.EdgeChanged", 0)
pass, why = T.panelCheck("following", true)
check(pass, "the bar hidden, 0 announced, passes: " .. tostring(why))
panelBar, panelTop = true, 60.3
EventRegistry:TriggerEvent("GlassPanel.EdgeChanged", 60)
pass, why = T.panelCheck("following", true)
check(pass, "a value within the slack of the last announcement passes: " .. tostring(why))
-- Its own look: nothing built for Glass UI, Pearl still, the saved glass compared.
follow.GlassPanel = nil
reports.GlassPanel.built = nil
answers.GlassPanel = { ready = true, reason = "not-following" }
states.GlassPanel = "own"
pass, why = T.panelCheck("own", false)
check(pass, "its own look passes: " .. tostring(why))
rawset(_G, "GlassPanel", setmetatable({ Glass = { preset = "clean" } }, { __index = GlassPanel }))
pass, why = T.panelCheck("own", false)
check(not pass and why:find("wanted pearl", 1, true), "its own look on anything but Pearl fails")
rawset(_G, "GlassPanel", getmetatable(GlassPanel).__index)
pass, why = T.panelCheck("own again", false, "own")
check(pass, "the same saved glass again passes: " .. tostring(why))
GlassPanelDB.windowGlass = "smoked"
pass, why = T.panelCheck("own again", false, "own")
check(not pass and why:find("db.windowGlass", 1, true), "a saved glass key that changed fails")
GlassPanelDB.windowGlass = "reflective"
pass, why = T.panelCheck("own again", false, "never")
check(not pass and why:find("no 'never' session", 1, true), "comparing with a session never read fails")
-- The switch: saved once, set and read back, put back.
follow.GlassPanel = true
SkinProbeDB.panelWas = nil
check((T.panelFollow(false)), "Follow off is set and read back")
eq(follow.GlassPanel, nil, "off")
eq(SkinProbeDB.panelWas.follow, true, "the switch as it was is saved")
T.panelFollow(true)
eq(SkinProbeDB.panelWas.follow, true, "a later change keeps the first: it is what to restore")
T.panelFollow(false)
check((T.panelRestore()), "restore reads its change back")
eq(follow.GlassPanel, true, "the switch is back")
eq(SkinProbeDB.panelWas, nil, "and the saved one cleared")
local okNothing, whyNothing = T.panelRestore()
check(okNothing and whyNothing == "nothing to restore", "a second restore finds nothing")
-- Each session is read once Glass Panel has measured, not at once after the reload.
local reads, waited = 0, 0
for _, st in ipairs(FP.procedures["SkinProbe/suitepanel"].steps) do
    if type(st.text) == "string" and st.text:find("^Reads it") then
        reads = reads + 1
        panelTop = nil
        local before = st.wait and st.wait()
        panelTop = 24
        if st.wait and not before and st.wait() then waited = waited + 1 end
    end
end
eq(reads, 3, "three sessions read")
eq(waited, 3, "each waits for Glass Panel's first measure")

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

-- #49, the glass bars preview: every touched region comes back, even once its
-- row has left the list (recycled), and twice over.
local sb = meterBar.StatusBar
sb.Background:SetAlpha(0.9)
check(T.barsOn() >= 1, "the preview covers the shown bar")
eq(sb.Background:GetAlpha(), 0, "its background faded")
eq(sb.BackgroundEdge:GetAlpha(), 0, "and its edge")
eq(meterFill:GetAlpha(), 0.8, "its fill at 0.8")
local barPanel = T.barPanels[meterBar]
check(barPanel and barPanel:IsShown(), "our glass behind it")
eq(barPanel:GetParent(), sb, "a child of the bar")
T.barsOn()
eq(sb.Background:GetAlpha(), 0, "on twice: still faded")
meterBar:Hide()
meterBars = {}
T.barsOff()
T.barsOff()
eq(sb.Background:GetAlpha(), 0.9, "a recycled row's background comes back to its own alpha")
eq(sb.BackgroundEdge:GetAlpha(), 1, "and its edge")
eq(meterFill:GetAlpha(), 1, "and its fill")
check(not barPanel:IsShown(), "our glass hides")
meterBar:Show()
meterBars = { meterBar }
-- A second preview records afresh: Blizzard's alpha set in between is the one put back.
sb.Background:SetAlpha(0.7)
T.barsOn()
T.barsOff()
eq(sb.Background:GetAlpha(), 0.7, "a second preview puts back the newer alpha")
-- The skin's acceptance reads the headers: faded or back.
meterWin.Header:SetAlpha(0)
check(T.headersFaded(true), "headers faded")
check(not T.headersFaded(false), "not back")
meterWin.Header:SetAlpha(1)
check(T.headersFaded(false), "back")

-- #54: which glass Glass UI built for its own skins.
local savedGUI = rawget(_G, "GlassUI")
rawset(_G, "GlassUI", { glassPreset = "pearl", Glass = { STYLE = { wash = 0.1, gloss = 0.15 } },
                        Theme = { Name = function() return "clear" end } })
local builtStep = FP.procedures["SkinProbe/pearl"].steps[1]
local okBuilt, builtWhy = builtStep.check()
check(okBuilt, "Pearl built passes: " .. tostring(builtWhy))
eq(SkinProbeDB.results["PEARL.built"].wash, 0.1, "its wash is kept in the results")
eq(SkinProbeDB.results["PEARL.built"].theme, "clear", "with the body theme")
GlassUI.glassPreset, GlassUI.glassWhy = "clean", "library-too-old"
okBuilt, builtWhy = builtStep.check()
check(not okBuilt and builtWhy:find("library-too-old", 1, true), "the clean fallback fails, saying why")
GlassUI.glassWhy = nil
check(not builtStep.check(), "anything but Pearl fails, fallback or not")
rawset(_G, "GlassUI", savedGUI)

-- #55: the tracker skin as the procedure reads it.
local tracker = CreateFrame("Frame", "ObjectiveTrackerFrame", UIParent)
tracker.NineSlice = CreateFrame("Frame", nil, tracker)
tracker.NineSlice:SetAlpha(0)
local quests = CreateFrame("Frame", "QuestObjectiveTracker", tracker)
quests.Header = CreateFrame("Frame", nil, quests)
quests.Header.Background = quests.Header:CreateTexture()
local trackerStatus, trackerPanel = "on", "populated"
local savedGUI2 = rawget(_G, "GlassUI")
rawset(_G, "GlassUI", { failures = {}, Engine = { Status = function() return trackerStatus end },
                        QuestTracker = { state = trackerPanel }, Theme = { Name = function() return "clear" end } })
local okT, whyT = T.trackerOn("t", { panel = "populated" })()
check(okT, "the skin on and holding passes: " .. tostring(whyT))
eq(SkinProbeDB.results["QT.t"].nine, 0, "the NineSlice's alpha is kept in the results")
GlassUI.QuestTracker.state = "header"
okT, whyT = T.trackerOn("t", { panel = "populated" })()
check(not okT and whyT:find("panel header, wanted populated", 1, true), "the panel in the wrong place fails")
GlassUI.QuestTracker.state = "populated"
quests.Header.Background:SetAtlas("UI-QuestTracker-Secondary-Objective-Header")
okT, whyT = T.trackerOn("t")()
check(not okT and whyT:find("not blanked", 1, true), "a header bar back fails")
quests.Header.Background:SetTexture(nil)
tracker.NineSlice:SetAlpha(0.6)
okT, whyT = T.trackerOn("t")()
check(not okT and whyT:find("NineSlice alpha", 1, true), "a NineSlice showing fails")
tracker.NineSlice:SetAlpha(0)
trackerStatus = "off"
okT, whyT = T.trackerOn("t")()
check(not okT and whyT:find("status off", 1, true), "the skin off fails")
trackerStatus = "on"
GlassUI.failures.x = "boom"
okT, whyT = T.trackerOn("t")()
check(not okT and whyT:find("failure", 1, true), "a Glass UI failure fails")
GlassUI.failures.x = nil
rawset(tracker, "isCollapsed", true)
eq(T.trackerState("c").collapsed, true, "the container's collapse is read")
rawset(quests, "isCollapsed", true)
eq(T.trackerState("c").section, true, "and the Quests section's")
rawset(tracker, "isCollapsed", nil); rawset(quests, "isCollapsed", nil)
rawset(_G, "GlassUI", savedGUI2)

-- #56 discovery: Questie's tracker and RestedXP's window and arrow.
-- When each frame first exists: the first place it was seen is kept.
local qbase = CreateFrame("Frame", "Questie_BaseFrame", UIParent)
T.lookFor("PLAYER_LOGIN")
eq(T.seen.Questie_BaseFrame, "PLAYER_LOGIN", "a frame is noted where it was first seen")
T.lookFor("later")
eq(T.seen.Questie_BaseFrame, "PLAYER_LOGIN", "and not overwritten after")
eq(SkinProbeDB.results["QS.seenSession"].Questie_BaseFrame, "PLAYER_LOGIN", "kept as this session's sightings")
local rxp = CreateFrame("Frame", "RXPFrame", UIParent)
local pinnedTime = GetTime
rawset(_G, "GetTime", function() return WoW.now end)
WoW.now = 100
WoW.fire("PLAYER_ENTERING_WORLD")
WoW.now = 103.5
local arrow = CreateFrame("Frame", "RXPG_ARROW", UIParent)
WoW.tick()
rawset(_G, "GetTime", pinnedTime)
eq(T.seen.RXPFrame, "PLAYER_ENTERING_WORLD", "one there at PLAYER_ENTERING_WORLD")
eq(T.seen.RXPG_ARROW, "PEW+3.5s", "one made later, noted with its delay")
-- The run's result is the procedure's: a later session with the addons off
-- again (Restore, then the last /reload) never overwrites it (Codex, PR #65).
local firstStep
for _, st in ipairs(FP.procedures["SkinProbe/questing"].steps) do
    if st.text:find("first appeared", 1, true) then firstStep = st end
end
eq(firstStep.run(), 3, "the run reads all three")
eq(SkinProbeDB.results["QS.firstSeen"].RXPG_ARROW, "PEW+3.5s", "and keeps them as the run's result")
for k in pairs(T.seen) do T.seen[k] = nil end      -- the next session: nothing loaded
WoW.fire("ADDON_LOADED", "SkinProbe")
WoW.fire("PLAYER_LOGIN")
T.lookFor("PLAYER_ENTERING_WORLD")
eq(SkinProbeDB.results["QS.firstSeen"].RXPG_ARROW, "PEW+3.5s", "a session without them leaves the run's result")
eq(SkinProbeDB.results["QS.firstSeen"].Questie_BaseFrame, "PLAYER_LOGIN", "all of it")
-- Their enable states for this character: saved, switched on, put back.
WoW.installed.Questie, WoW.installed.QuestieDB, WoW.installed.RXPGuides = 0, 0, 2
SkinProbeDB.questingWas = nil
check((T.questingEnable()), "all three switched on and read back")
eq(WoW.installed.Questie, 2, "Questie on")
eq(WoW.installed.QuestieDB, 2, "with QuestieDB, which it requires")
eq(SkinProbeDB.questingWas[WoW.GUID].Questie, 0, "each state saved first, under this character's GUID")
T.questingEnable()
eq(SkinProbeDB.questingWas[WoW.GUID].Questie, 0, "a second Enable keeps the first states")
check((T.questingRestore()), "restore reads its changes back")
eq(WoW.installed.Questie, 0, "Questie off again, as saved")
eq(WoW.installed.RXPGuides, 2, "RestedXP on, as saved")
eq(SkinProbeDB.questingWas[WoW.GUID], nil, "and the saved states cleared")
-- The hold test: every texture held, which came back, which are new, all put back.
local bg = qbase:CreateTexture()
bg:SetAlpha(0.7)
local edgeTex = rxp:CreateTexture()
arrow.texture = arrow:CreateTexture()
arrow.orientation = 0.4
check((T.holdOn()), "the hold takes the textures")
eq(bg:GetAlpha(), 0, "held at 0")
bg:SetAlpha(0.7)                               -- the addon re-applies its look
local fresh = rxp:CreateTexture()              -- and makes a texture anew
local back, new = T.holdCheck("test")
eq(back, 1, "the one that came back is counted")
eq(new, 1, "and the new one")
check(SkinProbeDB.results["QS.hold.test"].newList ~= "", "with its path")
-- Each refresh measured on its own: the baseline re-armed after a measure,
-- so a second refresh doesn't report the first one's changes (Codex, PR #65).
local measures = {}
for _, st in ipairs(FP.procedures["SkinProbe/questing"].steps) do
    if st.button == "Measure" then measures[#measures + 1] = st end
end
check(#measures >= 2, "the procedure measures each refresh")
local treeAt, windowAt
for i, st in ipairs(FP.procedures["SkinProbe/questing"].steps) do
    if st.text:find("frame trees", 1, true) then treeAt = i end
    if st.text:find("guide window shows", 1, true) then windowAt = i end
end
check(treeAt and windowAt and treeAt > windowAt, "the trees are logged after the tracker and the guide window show")
measures[1].run()
eq(bg:GetAlpha(), 0, "after a measure, everything is held at 0 again")
eq(fresh:GetAlpha(), 0, "the new texture too")
local back2, new2 = measures[2].run()
eq(back2, 0, "a second refresh that changed nothing reports nothing back")
eq(new2, 0, "and nothing new")
T.holdOff()
near(bg:GetAlpha(), 0.7, "Unfade gives back the alpha before the first hold, not the 0")
eq(edgeTex:GetAlpha(), 1, "every held texture back")
eq(fresh:GetAlpha(), 1, "the new one too, held by the second Fade")
-- Side by side, and the arrow.
local okC = pcall(T.coexist)
check(okC, "the side-by-side read runs")
eq(SkinProbeDB.results["QS.coexist"].questie, true, "Questie's tracker read")
local a = T.arrowState("t")
eq(a.orientation, 0.4, "the arrow's orientation field read")
arrow.texture:SetRotation(1.25)
a = T.arrowState("t")
eq(a.calls, 1, "its texture's rotation calls counted, from a hook on that texture")
eq(a.last, 1.25, "with the angle")

-- The procedures are defined and every step's run, wait and check works here.
for _, name in ipairs({ "wave1", "map", "gradient", "merchant", "card", "suite", "suitecombat", "meter",
                        "meterskin", "meterbars", "suitepanel", "pearl", "tracker", "questing" }) do
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
T.panelsOff(); T.borderRestore(); T.gradientOff(); T.barsOff()
T.suiteRestore(); T.panelRestore()
rawset(_G, "GlassUI", nil)
eq(#WoW.chat, 0, "still nothing in chat after every procedure step")

done("test_probe")
