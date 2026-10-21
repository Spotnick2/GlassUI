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
rawset(_G, "GlassUI", { Suite = { BODY = presets }, Theme = { Name = function() return current end,
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
-- Each window floor the merchant procedure shows (#80, MS.1) is the one its
-- button names (Codex, PR #22: a trial must show what its label says).
local floor = { WINDOW_BACKING = 0.75, Refresh = function() end }
rawset(_G, "GlassUI", { Theme = floor })
local shown = 0
for _, st in ipairs(FP.procedures["SkinProbe/merchant"].steps) do
    local label = st.button and st.button:match("^Floor (%d[%.%d]*)$")
    if label then
        st.run()
        eq(floor.WINDOW_BACKING, tonumber(label), "the step labelled " .. st.button .. " shows floor " .. label)
        shown = shown + 1
    end
end
eq(shown, 3, "three floors tried")
T.floorRestore()
eq(floor.WINDOW_BACKING, 0.75, "and Restore gives the default back")
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

-- #71: the titles' colours against the suite accent.
local savedGUI3 = rawget(_G, "GlassUI")
local accentNow = "ice"
rawset(_G, "GlassUI", { Suite = { Accent = function() return { 0.65, 0.835, 0.905 } end,
                                  Look = function() return { accent = accentNow } end } })
quests.Header.Text = quests.Header:CreateFontString()
tracker.Header = CreateFrame("Frame", nil, tracker)
tracker.Header.Text = tracker.Header:CreateFontString()
tracker.Header.Text:SetTextColor(0.65, 0.835, 0.905)
local acRec = T.accentState("t")
eq(acRec.accent, "ice", "the accent read")
check(acRec.tracker and math.abs(acRec.tracker[3] - 0.905) < 0.001, "the tracker title's colour read")
eq(acRec.meter, nil, "no meter window: nothing read, no error")

-- #73: the quest timers, their pill and the band, as the procedure reads them.
local ice = { 0.65, 0.835, 0.905 }
local qtimer = CreateFrame("Frame", "QuestTimerFrame", tracker)
qtimer.Border = CreateFrame("Frame", nil, qtimer)
qtimer.Header = CreateFrame("Frame", nil, qtimer)
for _, k in ipairs({ "LeftBG", "RightBG", "CenterBG" }) do
    qtimer.Header[k] = qtimer.Header:CreateTexture()
    qtimer.Header[k]:SetAlpha(0)
end
qtimer.Header.Text = qtimer.Header:CreateFontString()
qtimer.Header.Text:SetTextColor(ice[1], ice[2], ice[3])
qtimer.Border:SetAlpha(0)
local tpill, tband = CreateFrame("Frame", nil, qtimer), CreateFrame("Frame", nil, tracker)
-- The tracker's top 800, the timers 790..731, the pill 6 above them, the
-- band and Header from 713.
tracker._top, qtimer._top, qtimer._bottom, tpill._top, tpill._bottom = 800, 790, 731, 796, 739
tband._top, tracker.Header._top = 713, 713
rawset(_G, "GlassUI", { failures = {}, Engine = { Status = function() return "on" end },
                        Suite = { Accent = function() return ice end },
                        QuestTracker = { _test = { pills = { [tracker] = tpill }, bands = { [tracker] = tband } } } })
local okTm, whyTm = T.timerOn("t")()
check(okTm, "the timers on their pill, the band below, pass: " .. tostring(whyTm))
eq(SkinProbeDB.results["TM.t"].timerBottom, 731, "the places are kept in the results")
tband._top = 735
okTm, whyTm = T.timerOn("t")()
check(not okTm and whyTm:find("overlaps", 1, true), "a band over the timers fails")
tband._top = 713
tpill._top = 788
okTm, whyTm = T.timerOn("t")()
check(not okTm and whyTm:find("rise above", 1, true), "a pill not above them fails")
tpill._top = 796
qtimer.Header.CenterBG:SetAlpha(1)
okTm, whyTm = T.timerOn("t")()
check(not okTm and whyTm:find("header art", 1, true), "a header piece showing fails")
qtimer.Header.CenterBG:SetAlpha(0)
qtimer.Header.Text:SetTextColor(1, 0.82, 0)
okTm, whyTm = T.timerOn("t")()
check(not okTm and whyTm:find("accent", 1, true), "the title not in the accent fails")
qtimer.Header.Text:SetTextColor(ice[1], ice[2], ice[3])
okTm, whyTm = T.timerOn("t", true)()
check(not okTm and whyTm:find("still up", 1, true), "gone, with the timers still up, fails")
qtimer:Hide()
tband._top, tracker.Header._top = 800, 800
okTm, whyTm = T.timerOn("t", true)()
check(okTm, "gone: no pill seen, the band back at the top: " .. tostring(whyTm))
local strayPill = CreateFrame("Frame", nil, tracker)    -- a pill not on the timers
GlassUI.QuestTracker._test.pills[tracker] = strayPill
okTm, whyTm = T.timerOn("t", true)()
check(not okTm and whyTm:find("pill is still seen", 1, true), "a pill left showing without the timers fails")
GlassUI.QuestTracker._test.pills[tracker] = tpill
tband._top = 713
okTm, whyTm = T.timerOn("t", true)()
check(not okTm and whyTm:find("back at the top", 1, true), "the band left down fails")
-- Fake timers (no timed quests to take): the getter swapped, a quest of the
-- log lending its ID, Blizzard's put back.
check(not T.fakeOn(1), "no C_QuestLog: refused, nothing thrown")
local realTimers = function() return {} end
local entries = { { isHeader = true, questID = 99 }, { questID = 812 }, { questID = 813 } }
rawset(_G, "C_QuestLog", { GetQuestTimers = realTimers, GetNumQuestLogEntries = function() return #entries end,
                           GetInfo = function(i) return entries[i] end })
local nudged = 0
rawset(qtimer, "UpdateIfNeeded", function() nudged = nudged + 1 end)
check((T.fakeOn(1)), "one fake timer on")
check(C_QuestLog.GetQuestTimers ~= realTimers, "the getter swapped")
eq(nudged, 1, "and Blizzard's timers redrawn at once")
local fakeList = C_QuestLog.GetQuestTimers()
eq(#fakeList, 1, "one timer")
eq(fakeList[1].questID, 812, "on the log's first quest, its header skipped")
eq(fakeList[1].questTimer, 300, "five minutes from now")
T.fakeOn(2)
fakeList = C_QuestLog.GetQuestTimers()
eq(#fakeList, 2, "two timers")
eq(fakeList[2].questID, 813, "the second on the next quest")
T.fakeOff()
eq(C_QuestLog.GetQuestTimers, realTimers, "Blizzard's getter back, after two fakes")
eq(nudged, 3, "and the timers redrawn")
entries = { { isHeader = true, questID = 0 } }
local okF, whyF = T.fakeOn(1)
check(not okF and whyF:find("no quest", 1, true), "no quest in the log: refused")
eq(C_QuestLog.GetQuestTimers, realTimers, "and nothing swapped")
rawset(_G, "C_QuestLog", nil)
rawset(_G, "QuestTimerFrame", nil)

-- #80, #48: the merchant's rows, buyback slot and disc as the procedure reads
-- them, and the window floor tried and put back.
local function rowState(row, filled, red)
    local st = { glass = CreateFrame("Frame", nil, row), button = CreateFrame("Button", nil, row),
                 red = row:CreateTexture() }
    st.button:SetShown(filled); st.glass:SetShown(filled); st.red:SetShown(red)
    return st
end
local mrow1 = CreateFrame("Frame", "MerchantItem1", merchant)
local mrow2 = CreateFrame("Frame", "MerchantItem2", merchant)
local mrows = { [mrow1] = rowState(mrow1, true, true), [mrow2] = rowState(mrow2, false, false) }
merchant.PortraitContainer = CreateFrame("Frame", nil, merchant)
merchant.PortraitContainer.CircleMask = merchant.PortraitContainer:CreateTexture()
merchant.PortraitContainer.CircleMask._cx, merchant.PortraitContainer.CircleMask._cy = 40, 500
local mdisc = CreateFrame("Frame", nil, merchant)
mdisc._cx, mdisc._cy, mdisc._width = 40, 500, 70
local refreshed = 0
local theme = { WINDOW_BACKING = 0.75, Refresh = function() refreshed = refreshed + 1 end }
rawset(_G, "GlassUI", { Theme = theme, Merchant = { _test = { rows = mrows, discs = { [merchant] = mdisc } } } })
local okR, whyR = T.rowsOn("t", { red = true })()
check(okR, "rows matching their items, a red one, the disc centred: pass: " .. tostring(whyR))
eq(SkinProbeDB.results["MS.t"].discWidth, 70, "the disc's width kept in the results")
mrows[mrow2].glass:Show()
okR, whyR = T.rowsOn("t")()
check(not okR and whyR:find("doesn't match", 1, true), "glass on an empty row fails")
mrows[mrow2].glass:Hide()
mrows[mrow1].red:Hide()
okR, whyR = T.rowsOn("t", { red = true })()
check(not okR and whyR:find("no red", 1, true), "no red row when one is wanted fails")
mrows[mrow1].red:Show()
mdisc._cx = 42
okR, whyR = T.rowsOn("t")()
check(not okR and whyR:find("centre", 1, true), "a disc off the mask's centre fails")
mdisc._cx = 40
mdisc:Hide()
okR, whyR = T.rowsOn("t")()
check(not okR and whyR:find("no disc", 1, true), "no disc seen fails")
mdisc:Show()
okR, whyR = T.rowsOn("t", { buyback = true })()
check(not okR and whyR:find("buyback glass", 1, true), "the buyback slot's glass missing fails")
local mbb = CreateFrame("Frame", "MerchantBuyBackItem", merchant)
mrows[mbb] = rowState(mbb, true, false)
okR, whyR = T.rowsOn("t", { buyback = true })()
check(okR, "and passes once it's there: " .. tostring(whyR))
T.floorTry(0.6)
eq(theme.WINDOW_BACKING, 0.6, "a floor tried live")
eq(refreshed, 1, "the glass repainted")
T.floorTry(0.85)
T.floorRestore()
eq(theme.WINDOW_BACKING, 0.75, "and the first value back, after two tries")
eq(refreshed, 3, "repainted again")
rawset(_G, "MerchantItem1", nil); rawset(_G, "MerchantItem2", nil); rawset(_G, "MerchantBuyBackItem", nil)
rawset(_G, "GlassUI", savedGUI3)

-- #84, #86: the merchant's layout as the procedure reads it, each pane
-- against Blizzard's state.
local function sec(host, shown)
    local s = { fill = host:CreateTexture(), edges = {} }
    s.fill:SetShown(shown)
    return s
end
local lwin = CreateFrame("Frame", nil, merchant)
local lbb = CreateFrame("Frame", "MerchantBuyBackItem", merchant)
local tab1 = CreateFrame("Button", "MerchantFrameTab1", merchant)
local tab2 = CreateFrame("Button", "MerchantFrameTab2", merchant)
local cur = CreateFrame("Frame", "MerchantExtraCurrencyInset", merchant)
cur:Hide()
local repairAll = CreateFrame("Button", "MerchantRepairAllButton", merchant)
local junk = CreateFrame("Button", "MerchantSellAllJunkButton", merchant)
repairAll:Hide(); junk:Hide()
local prevB = CreateFrame("Button", "MerchantPrevPageButton", merchant)
local prevLabel = prevB:CreateFontString()
local hl1, hl2 = lwin:CreateTexture(), lwin:CreateTexture()
hl2:Hide()
local lu = { frame = merchant, bb = lbb, tabs = { [tab1] = hl1, [tab2] = hl2 },
             inset = sec(lwin, true), money = sec(lwin, true), currency = sec(lwin, false),
             boxLeft = sec(lwin, false), boxRight = sec(lwin, true), empty = CreateFrame("Frame", nil, merchant) }
lu.empty:Hide()
local hdr = true
rawset(_G, "GlassUI", { Merchant = {
    Header = function() return hdr end,
    SetHeader = function(on) hdr = on; return true end,
    _test = { ui = { [merchant] = lu } } } })
local okL, whyL = T.layoutOn("t", { tab = 1, header = true })()
check(okL, "an ordinary vendor: inset, money, the right box: pass: " .. tostring(whyL))
local rec = SkinProbeDB.results["ML.t"]
check(rec.inset and rec.money and rec.boxRight and not rec.boxLeft and not rec.currency, "each pane recorded")
eq(rec.blizzCurrency, false, "Blizzard's currency box recorded")
eq(rec.bandUsed, false, "and the band unused")
-- The currency box follows Blizzard's.
cur:Show()
okL, whyL = T.layoutOn("t", { tab = 1 })()
check(not okL and whyL:find("currency box false, Blizzard's true", 1, true), "Blizzard's currency box without ours fails")
lu.currency.fill:Show()
check(T.layoutOn("t", { tab = 1 })(), "with ours: pass")
cur:Hide()
okL = T.layoutOn("t", { tab = 1 })()
check(not okL, "ours without Blizzard's fails (the run 2 divider)")
lu.currency.fill:Hide()
-- The left box: while a band button shows.
lu.boxLeft.fill:Show()
okL, whyL = T.layoutOn("t", { tab = 1 })()
check(not okL and whyL:find("left box true, band used false", 1, true), "an empty left box fails (the empty rectangle)")
repairAll:Show()
check(T.layoutOn("t", { tab = 1 })(), "a smith: the box with the repair buttons passes")
eq(SkinProbeDB.results["ML.t"].band.MerchantRepairAllButton, true, "which button recorded")
repairAll:Hide(); junk:Show()
check(T.layoutOn("t", { tab = 1 })(), "the junk button alone: the box passes")
junk:Hide()
okL = T.layoutOn("t", { tab = 1 })()
check(not okL, "none shown, the box still there: fails")
lu.boxLeft.fill:Hide()
lu.boxRight.fill:Hide()
okL, whyL = T.layoutOn("t", { tab = 1 })()
check(not okL and whyL:find("right box false", 1, true), "no right box on the Merchant tab fails")
lu.boxRight.fill:Show()
lu.inset.fill:Hide()
okL, whyL = T.layoutOn("t", { tab = 1 })()
check(not okL and whyL:find("inset or the money", 1, true), "no inset fails")
lu.inset.fill:Show()
-- The pages: a label dimmed exactly while its button is disabled.
prevB:Disable(); prevLabel:SetAlpha(0.4)
check(T.layoutOn("t", { tab = 1 })(), "Prev disabled and dimmed: pass")
prevLabel:SetAlpha(1)
okL, whyL = T.layoutOn("t", { tab = 1 })()
check(not okL and whyL:find("prev label 1", 1, true), "disabled but bright fails")
prevB:Enable(); prevLabel:SetAlpha(0.4)
okL = T.layoutOn("t", { tab = 1 })()
check(not okL, "enabled but dimmed fails")
prevLabel:SetAlpha(1)
-- The Buyback tab, the empty state, the tabs.
lbb:Hide(); hl1:Hide(); hl2:Show(); lu.boxRight.fill:Hide(); lu.empty:Show()
check(T.layoutOn("t", { tab = 2, empty = true })(), "the Buyback tab, empty: pass")
okL, whyL = T.layoutOn("t", { tab = 2, empty = false })()
check(not okL and whyL:find("empty state true", 1, true), "the message when items are listed fails")
okL, whyL = T.layoutOn("t", { tab = 1 })()
check(not okL and whyL:find("Merchant tab", 1, true), "the wrong tab fails")
lbb:Show(); hl1:Show(); hl2:Hide(); lu.boxRight.fill:Show(); lu.empty:Hide()
hl2:Show()
okL, whyL = T.layoutOn("t", { tab = 1 })()
check(not okL and whyL:find("tabs lit", 1, true), "both tabs lit fails")
hl2:Hide()
-- The header, and the tabs tucked.
local tglass = CreateFrame("Frame", nil, tab1)
tglass:SetFrameStrata("LOW")
lu.tabGlass = { [tab1] = { glass = tglass } }
check(T.layoutOn("t", { tab = 1, header = true })(), "the header on, the tabs a strata under: pass")
eq(SkinProbeDB.results["ML.t"].tabStrata, "LOW", "the tabs' strata recorded")
eq(select(1, T.headerTry(false)), true, "the header switched through Glass UI")
eq(hdr, false, "off")
okL, whyL = T.layoutOn("t", { tab = 1, header = true })()
check(not okL and whyL:find("header false", 1, true), "the header off when wanted on fails")
T.headerTry(true)
tglass:SetFrameStrata("MEDIUM")
okL, whyL = T.layoutOn("t", { tab = 1 })()
check(not okL and whyL:find("not tucked", 1, true), "the tabs in the window's strata fail")
tglass:SetFrameStrata("LOW")
-- The close button.
local cbtn = CreateFrame("Button", nil, merchant)
for _, k in ipairs({ "_normal", "_pushed", "_disabled", "_highlight" }) do
    cbtn[k] = cbtn:CreateTexture()
    cbtn[k]:SetAlpha(0)
end
lu.close, lu.closeDisc, lu.closeFrame = cbtn, CreateFrame("Frame", nil, cbtn), CreateFrame("Frame", nil, cbtn)
lu.closeAlpha, lu.hover, lu.pushed = 0.85, false, false
local okC, whyC = T.closeOn("c", false)()
check(okC, "the close button at rest: pass: " .. tostring(whyC))
eq(SkinProbeDB.results["ML.c"].blizzardArt, 0, "Blizzard's art recorded faded")
okC = T.closeOn("c", true)()
check(not okC, "not hovered when a hover is wanted fails")
lu.hover, lu.closeAlpha = true, 1
check(T.closeOn("c", true)(), "hovered at full: pass")
lu.closeAlpha = 0.85
check(not T.closeOn("c", true)(), "hovered but not full fails")
check(not T.closeOn("c", false)(), "still hovered when the rest is wanted fails")
lu.hover = false
cbtn._highlight:SetAlpha(1)
okC, whyC = T.closeOn("c", false)()
check(not okC and whyC:find("art 1", 1, true), "Blizzard's art showing fails")
cbtn._highlight:SetAlpha(0)
lu.closeDisc:Hide()
okC, whyC = T.closeOn("c", false)()
check(not okC and whyC:find("disc false", 1, true), "no disc fails")
lu.closeDisc:Show()
-- Two checks as one.
local yes, no = function() return true, "a" end, function() return false, "b" end
check(T.both(yes, yes)(), "both pass: pass")
check(not T.both(yes, no)() and not T.both(no, yes)(), "either failing fails")
eq(select(2, T.both(yes, no)()), "a; b", "both reasons kept")
for _, n in ipairs({ "MerchantBuyBackItem", "MerchantFrameTab1", "MerchantFrameTab2", "MerchantExtraCurrencyInset",
                     "MerchantRepairAllButton", "MerchantSellAllJunkButton", "MerchantPrevPageButton" }) do
    rawset(_G, n, nil)
end
rawset(_G, "GlassUI", savedGUI3)

-- #88: the bags as the procedure reads them.
local savedGUI4 = rawget(_G, "GlassUI")
local bw = CreateFrame("Frame", "ContainerFrame1", UIParent)
bw.NineSlice = CreateFrame("Frame", nil, bw)
bw.NineSlice:SetAlpha(0)
local bslots, bwins = {}, {}
local hdrTex = bw:CreateTexture()
bwins[bw] = { header = hdrTex }
local function bagButton(empty)
    local b = CreateFrame("Button", nil, bw)
    b.icon = b:CreateTexture()
    b.IconBorder = b:CreateTexture()
    b._normal = b:CreateTexture()
    b._normal:SetAlpha(0)
    b.emptyBackgroundAtlas = "bags-item-slot64"
    if empty then b.icon:SetAtlas("bags-item-slot64"); b.icon:SetAlpha(0) else b.icon:SetTexture(1) end
    bslots[b] = { glass = CreateFrame("Frame", nil, b) }
    return b
end
local be, bf = bagButton(true), bagButton(false)
local bandH = 26
rawset(_G, "GlassUI", { Bags = { _test = { wins = bwins, slots = bslots }, HeaderHeight = function() return bandH end } })
SkinProbeDB.suiteBlocked = 0
local okB, whyB = T.bagsOn("t", { windows = 1, combined = false })()
check(okB, "an open backpack, an empty slot dimmed, a filled one shown: pass: " .. tostring(whyB))
local br = SkinProbeDB.results["BG.t"]
eq(br.slots, 2, "two slots counted")
eq(br.empty, 1, "one empty")
eq(br.header, 26, "the band recorded")
okB, whyB = T.bagsOn("t", { windows = 2 })()
check(not okB and whyB:find("1 windows open", 1, true), "too few windows fails")
okB, whyB = T.bagsOn("t", { windows = 1, combined = true })()
check(not okB and whyB:find("combined false", 1, true), "not combined when wanted fails")
be.icon:SetAlpha(1)
okB, whyB = T.bagsOn("t", { windows = 1 })()
check(not okB and whyB:find("empty dimmed 0 of 1", 1, true), "an empty slot not dimmed fails")
be.icon:SetAlpha(0)
bf.icon:SetAlpha(0)
okB, whyB = T.bagsOn("t", { windows = 1 })()
check(not okB and whyB:find("filled shown 0 of 1", 1, true), "a hidden item fails")
bf.icon:SetAlpha(1)
bf._normal:SetAlpha(1)
okB, whyB = T.bagsOn("t", { windows = 1 })()
check(not okB and whyB:find("rims faded on 1 of 2", 1, true), "a rim left fails")
bf._normal:SetAlpha(0)
bslots[bf].glass:Hide()
okB, whyB = T.bagsOn("t", { windows = 1 })()
check(not okB and whyB:find("glass on 1 of 2", 1, true), "a slot without glass fails")
bslots[bf].glass:Show()
bw.NineSlice:SetAlpha(1)
okB, whyB = T.bagsOn("t", { windows = 1 })()
check(not okB and whyB:find("shell faded on 0 of 1", 1, true), "the shell left fails")
bw.NineSlice:SetAlpha(0)
hdrTex:Hide()
okB, whyB = T.bagsOn("t", { windows = 1 })()
check(not okB and whyB:find("header on 0 of 1", 1, true), "no header fails")
hdrTex:Show()
bf.icon:SetAtlas("some-item-atlas")
check(T.bagsOn("t", { windows = 1 })(), "an item given as an atlas is counted filled, not empty")
bf.icon:SetTexture(1)
SkinProbeDB.suiteBlocked = 1
okB, whyB = T.bagsOn("t", { windows = 1 })()
check(not okB and whyB:find("1 blocked", 1, true), "a blocked action fails")
SkinProbeDB.suiteBlocked = 0
rawset(_G, "ContainerFrame1", nil)
rawset(_G, "GlassUI", savedGUI4)

do
-- #90: the game menu as the procedure reads it.
local savedGUI5 = rawget(_G, "GlassUI")
local gm = CreateFrame("Frame", "GameMenuFrame", UIParent)
gm:SetSize(260, 400)
gm.Border = CreateFrame("Frame", nil, gm)
gm.Border:SetAlpha(0)
gm.Header = CreateFrame("Frame", nil, gm)
gm.Header.CenterBG = gm.Header:CreateTexture()
gm.Header.CenterBG:SetAlpha(0)
local gmButtons, gmMenus = {}, {}
gmMenus[gm] = { header = CreateFrame("Frame", nil, gm.Header) }
local function gmButton()
    local b = CreateFrame("Button", nil, gm)
    for _, k in ipairs({ "Left", "Right", "Center" }) do b[k] = b:CreateTexture(); b[k]:SetAlpha(0) end
    b._highlight = b:CreateTexture()
    b._highlight:SetDesaturated(true)
    gmButtons[b] = { glass = CreateFrame("Frame", nil, b) }
    return b
end
local gb1, gb2 = gmButton(), gmButton()
rawset(_G, "GlassUI", { GameMenu = { _test = { buttons = gmButtons, menus = gmMenus } } })
SkinProbeDB.suiteBlocked, SkinProbeDB.gmSize = 0, nil
local okG, whyG = T.gmOn("t")()
check(okG, "the menu on glass, its buttons faded and tinted: pass: " .. tostring(whyG))
eq(SkinProbeDB.results["GM.t"].buttons, 2, "two buttons counted")
check(SkinProbeDB.gmSize and SkinProbeDB.gmSize[1] == 260, "the first size kept")
okG, whyG = T.gmOn("t", { combat = true })()
check(not okG and whyG:find("combat false", 1, true), "combat wanted, not in combat: fails")
gmButtons[gb2].glass:Hide()
okG, whyG = T.gmOn("t")()
check(not okG and whyG:find("glass on 1 of 2", 1, true), "a button without glass fails")
gmButtons[gb2].glass:Show()
gb2.Center:SetAlpha(1)
okG, whyG = T.gmOn("t")()
check(not okG and whyG:find("slices faded on 1 of 2", 1, true), "a slice left fails")
gb2.Center:SetAlpha(0)
gb1._highlight:SetDesaturated(false)
okG, whyG = T.gmOn("t")()
check(not okG and whyG:find("glow tinted on 1 of 2", 1, true), "a red glow left fails")
gb1._highlight:SetDesaturated(true)
gm.Border:SetAlpha(1)
okG, whyG = T.gmOn("t")()
check(not okG and whyG:find("border 1", 1, true), "the border left fails")
gm.Border:SetAlpha(0)
gm.Header.CenterBG:SetAlpha(1)
okG, whyG = T.gmOn("t")()
check(not okG and whyG:find("header art 1", 1, true), "the header art left fails")
gm.Header.CenterBG:SetAlpha(0)
gmMenus[gm].header:Hide()
okG, whyG = T.gmOn("t")()
check(not okG and whyG:find("no title tab", 1, true), "no title tab glass fails")
gmMenus[gm].header:Show()
gm:SetSize(260, 420)
okG, whyG = T.gmOn("t")()
check(not okG and whyG:find("first 260 x 400", 1, true), "the menu's size changed fails")
gm:SetSize(260, 400)
SkinProbeDB.suiteBlocked = 2
okG, whyG = T.gmOn("t")()
check(not okG and whyG:find("2 blocked", 1, true), "a blocked action fails")
SkinProbeDB.suiteBlocked = 0
gm:Hide()
okG, whyG = T.gmOn("t")()
check(not okG and whyG:find("not shown", 1, true), "the menu hidden fails")
-- Settings and back (Codex on #91): the menu already open, Settings closed, at the step's start is no return.
gm:Show()
local sp = CreateFrame("Frame", "SettingsPanel", UIParent)
sp:Hide()
local back = T.settingsReturn(false)
local okS, whyS = back()
check(not okS and whyS:find("waiting for Settings to open", 1, true), "entering with the menu open: not accepted")
sp:Show()
check(not back(), "Settings open: waiting for it to close")
gm:Hide()
sp:Hide()
okS, whyS = back()
check(not okS and whyS:find("waiting for the menu", 1, true), "Settings closed, the menu not back yet: waiting")
gm:Show()
okS, whyS = back()
check(okS, "Settings seen, then the menu back: accepted: " .. tostring(whyS))
check(not back(), "reached again: it needs a visit of its own")
-- In combat: the visit and the return both.
local backC = T.settingsReturn(true)
WoW.combat = false
sp:Show()
okS, whyS = backC()
check(not okS and whyS:find("not in combat", 1, true), "Settings open out of combat doesn't count")
sp:Hide()
check(not backC(), "nor its return")
WoW.combat = true
sp:Show()
check(not backC(), "Settings open in combat: waiting for it to close")
sp:Hide()
WoW.combat = false
okS, whyS = backC()
check(not okS and whyS:find("waiting for combat", 1, true), "the return out of combat: not accepted")
WoW.combat = true
check(backC(), "the return in combat: accepted")
WoW.combat = false
rawset(_G, "SettingsPanel", nil)
rawset(_G, "GameMenuFrame", nil)
rawset(_G, "GlassUI", savedGUI5)
SkinProbeDB.gmSize = nil
end

do
-- #92: the guild window as the procedure reads it.
local savedGUI6 = rawget(_G, "GlassUI")
local gcf = CreateFrame("Frame", "CommunitiesFrame", UIParent)
gcf.NineSlice = CreateFrame("Frame", nil, gcf)
gcf.NineSlice:SetAlpha(0)
gcf.Chat = CreateFrame("Frame", nil, gcf)
gcf.MemberList = CreateFrame("Frame", nil, gcf)
local function gpane(section)
    local host = CreateFrame("Frame", nil, section)
    return { fill = host:CreateTexture() }
end
-- The roster's fake pane is on the window, so it can show without its section (the case to catch).
local gh = { chat = gpane(gcf.Chat), roster = gpane(gcf) }
local gtab = CreateFrame("CheckButton", nil, gcf)
local gtabs = { [gtab] = { light = gtab:CreateTexture() } }
gtabs[gtab].light:Hide()
local tenantsT = { tabs = {}, panels = {} }
rawset(_G, "GlassUI", { Guild = { _test = { wins = { [gcf] = gh }, tabs = gtabs } }, Tenants = tenantsT })
SkinProbeDB.suiteBlocked = 0
local okD, whyD = T.gdOn("t")()
check(okD, "the panes with their sections, the tab mirrored: pass: " .. tostring(whyD))
gcf.MemberList:Hide()
okD, whyD = T.gdOn("t")()
check(not okD and whyD:find("panes right 1 of 2", 1, true), "a pane shown without its section fails")
gcf.MemberList:Show()
gtab:SetChecked(true)
okD, whyD = T.gdOn("t")()
check(not okD and whyD:find("tabs mirrored 0 of 1", 1, true), "a checked tab without its light fails")
gtabs[gtab].light:Show()
check(T.gdOn("t")(), "its light shown: pass")
gcf.NineSlice:SetAlpha(1)
okD, whyD = T.gdOn("t")()
check(not okD and whyD:find("shell 1", 1, true), "the shell left fails")
gcf.NineSlice:SetAlpha(0)
tenantsT.panels[CreateFrame("Frame")] = { applied = false }
okD, whyD = T.gdOn("t")()
check(not okD and whyD:find("tenant panels applied 0 of 1", 1, true), "a tenant panel not applied fails")
for k in pairs(tenantsT.panels) do tenantsT.panels[k].applied = true end
check(T.gdOn("t")(), "applied: pass")
SkinProbeDB.suiteBlocked = 1
okD, whyD = T.gdOn("t")()
check(not okD and whyD:find("1 blocked", 1, true), "a blocked action fails")
SkinProbeDB.suiteBlocked = 0
okD, whyD = T.gdOn("t", { combat = true })()
check(not okD and whyD:find("combat false", 1, true), "combat wanted, not in combat: fails")
-- Minimized: no tab shown, none to mirror; outside minimized, no tab fails.
gtab:Hide()
check(T.gdOn("t", { minimized = true })(), "minimized: no tab shown passes")
okD, whyD = T.gdOn("t")()
check(not okD and whyD:find("tabs mirrored 0 of 0", 1, true), "no tab shown, not minimized: fails")
gtab:Show()
gcf:Hide()
okD, whyD = T.gdOn("t")()
check(not okD and whyD:find("not shown", 1, true), "the window hidden fails")
rawset(_G, "CommunitiesFrame", nil)
rawset(_G, "GlassUI", savedGUI6)
end

do
-- #94: the character window as the procedure reads it.
local savedGUI7 = rawget(_G, "GlassUI")
local ccf = CreateFrame("Frame", "CharacterFrame", UIParent)
ccf.NineSlice = CreateFrame("Frame", nil, ccf)
ccf.NineSlice:SetAlpha(0)
local cslots, cheaders = {}, {}
local function cslot(name)
    local b = CreateFrame("Button", "Character" .. name .. "Slot", ccf)
    b.BorderFrame = CreateFrame("Frame", nil, b)
    b.BorderFrame:SetAlpha(0)
    b._normal = b:CreateTexture()
    b._normal:SetAlpha(0)
    cslots[b] = { glass = CreateFrame("Frame", nil, b) }
    return b
end
local head, chest = cslot("Head"), cslot("Chest")
local cstats = CreateFrame("Frame", "CharacterStatsPaneScrollBox", ccf)
cstats.ScrollBox = CreateFrame("Frame", nil, cstats)
cstats.ScrollBox.ScrollTarget = CreateFrame("Frame", nil, cstats.ScrollBox)
local hrow = CreateFrame("Frame", nil, cstats.ScrollBox.ScrollTarget)
hrow.Background, hrow.Title = hrow:CreateTexture(), hrow:CreateFontString()
hrow.Background:SetAlpha(0)
cheaders[hrow] = { glass = CreateFrame("Frame", nil, hrow) }
local srow = CreateFrame("Frame", nil, cstats.ScrollBox.ScrollTarget)
srow.Background, srow.Label = srow:CreateTexture(), srow:CreateFontString()
local ckit = { key = "character" }
local ctab = CreateFrame("Frame", nil, ccf)
ctab.SelectedTexture = ctab:CreateTexture()
local sideTabs = { [ctab] = { kit = ckit, light = ctab:CreateTexture(), selected = function(t) return t.SelectedTexture:IsShown() end } }
ctab.SelectedTexture:Hide()
sideTabs[ctab].light:Hide()
rawset(_G, "GlassUI", { Character = { _test = { slots = cslots, headers = cheaders } }, Kit = { sideTabs = sideTabs } })
SkinProbeDB.suiteBlocked = 0
local okH, whyH = T.chOn("t", { paperdoll = true })()
check(okH, "the slots, a header, the tab mirrored: pass: " .. tostring(whyH))
eq(SkinProbeDB.results["CH.t"].slots, 2, "two slots counted")
eq(SkinProbeDB.results["CH.t"].headers, 1, "one header: the stat row isn't one")
head._normal:SetAlpha(1)
okH, whyH = T.chOn("t", { paperdoll = true })()
check(not okH and whyH:find("NormalTexture back on 1 (Head)", 1, true), "the NormalTexture gate: a fade that didn't hold fails, named")
check(T.chOn("t")(), "but not read off the paper doll")
head._normal:SetAlpha(0)
chest.BorderFrame:SetAlpha(1)
okH, whyH = T.chOn("t", { paperdoll = true })()
check(not okH and whyH:find("slot frames faded 1 of 2", 1, true), "a slot frame left fails")
chest.BorderFrame:SetAlpha(0)
cslots[chest].glass:Hide()
okH, whyH = T.chOn("t", { paperdoll = true })()
check(not okH and whyH:find("wells 1 of 2", 1, true), "a slot without its well fails")
cslots[chest].glass:Show()
hrow.Background:SetAlpha(1)
okH, whyH = T.chOn("t", { paperdoll = true })()
check(not okH and whyH:find("headers 0 of 1", 1, true), "a header left fails")
hrow.Background:SetAlpha(0)
sideTabs[ctab].light:Show()
okH, whyH = T.chOn("t", { paperdoll = true })()
check(not okH and whyH:find("tabs mirrored 0 of 1", 1, true), "a tab lit but not selected fails")
sideTabs[ctab].light:Hide()
ccf.NineSlice:SetAlpha(1)
okH, whyH = T.chOn("t")()
check(not okH and whyH:find("shell 1", 1, true), "the shell left fails")
ccf.NineSlice:SetAlpha(0)
SkinProbeDB.suiteBlocked = 1
okH, whyH = T.chOn("t")()
check(not okH and whyH:find("1 blocked", 1, true), "a blocked action fails")
SkinProbeDB.suiteBlocked = 0
okH, whyH = T.chOn("t", { combat = true })()
check(not okH and whyH:find("combat false", 1, true), "combat wanted, not in combat: fails")
-- The list panes' headers.
local skills = CreateFrame("Frame", "SkillsFrame", ccf)
skills.ScrollBox = CreateFrame("Frame", nil, skills)
skills.ScrollBox.ScrollTarget = CreateFrame("Frame", nil, skills.ScrollBox)
local lh = CreateFrame("Button", nil, skills.ScrollBox.ScrollTarget)
local lbar = lh:CreateTexture(nil, "BACKGROUND")
lh.StateIcon, lh.Name = lh:CreateTexture(nil, "BORDER"), lh:CreateFontString()
local entry = CreateFrame("Button", nil, skills.ScrollBox.ScrollTarget)
entry.Content = CreateFrame("Frame", nil, entry)
lbar:SetAlpha(0)
lh.StateIcon:SetDesaturated(true)
cheaders[lh] = { glass = CreateFrame("Frame", nil, lh) }
okH, whyH = T.chOn("t", { lists = true })()
check(okH, "a list header in glass: pass: " .. tostring(whyH))
eq(SkinProbeDB.results["CH.t"].paneHeaders, 1, "one list header: the entry isn't one")
lbar:SetAlpha(1)
okH, whyH = T.chOn("t")()
check(not okH and whyH:find("list headers 0 of 1", 1, true), "its bronze bar back fails")
lbar:SetAlpha(0)
lh.StateIcon:SetDesaturated(false)
okH, whyH = T.chOn("t")()
check(not okH and whyH:find("list headers 0 of 1", 1, true), "its +/- untinted fails")
lh.StateIcon:SetDesaturated(true)
cheaders[lh].glass:Hide()
okH, whyH = T.chOn("t")()
check(not okH and whyH:find("list headers 0 of 1", 1, true), "its bar hidden fails")
cheaders[lh].glass:Show()
skills:Hide()
okH, whyH = T.chOn("t", { lists = true })()
check(not okH and whyH:find("no list header shown", 1, true), "lists wanted, none shown: fails")
check(T.chOn("t")(), "but not otherwise")
for _, n in ipairs({ "CharacterFrame", "CharacterHeadSlot", "CharacterChestSlot", "CharacterStatsPaneScrollBox", "SkillsFrame" }) do
    rawset(_G, n, nil)
end
rawset(_G, "GlassUI", savedGUI7)
end

do
-- #99: the world map as the procedure reads it.
local savedGUI8 = rawget(_G, "GlassUI")
local wm = CreateFrame("Frame", "WorldMapFrame", UIParent)
local bf = CreateFrame("Frame", nil, wm)
wm.BorderFrame = bf
bf.NineSlice = CreateFrame("Frame", nil, bf)
bf.NineSlice:SetAlpha(0)
bf.PortraitContainer = CreateFrame("Frame", nil, bf)
bf.PortraitContainer.portrait = bf.PortraitContainer:CreateTexture()
bf.TitleContainer = CreateFrame("Frame", nil, bf)
bf.TitleContainer.TitleText = bf.TitleContainer:CreateFontString()
local mm = CreateFrame("Frame", nil, bf)
mm.MaximizeButton, mm.MinimizeButton = CreateFrame("Button", nil, mm), CreateFrame("Button", nil, mm)
mm.MinimizeButton:Hide()
bf.MaximizeMinimizeFrame = mm
local function texButton(parent, alpha)
    local b = CreateFrame("Button", nil, parent)
    b._normal = b:CreateTexture()
    b._normal:SetAlpha(alpha)
    return b
end
local nav = CreateFrame("Frame", nil, wm)
nav.homeButton = texButton(nav, 0)
local crumb = texButton(nav, 0)
nav.navList = { nav.homeButton, crumb }
nav.overflowButton = texButton(nav, 1)
nav.Refresh = function() end
wm.NavBar = nav
local qsf = CreateFrame("Frame", "QuestScrollFrame", wm)
qsf.UpdateBackground = function() end
qsf.Background = qsf:CreateTexture()
qsf.Background:SetAlpha(0)
qsf.BorderFrame = CreateFrame("Frame", nil, qsf)
qsf.BorderFrame.Shadow = qsf.BorderFrame:CreateTexture()
qsf.Contents = CreateFrame("Frame", nil, qsf)
local hdr = texButton(qsf.Contents, 0)
hdr.ButtonText = hdr:CreateFontString()
hdr.CollapseButton = CreateFrame("Button", nil, hdr)
hdr.CollapseButton.Icon = hdr.CollapseButton:CreateTexture()
hdr.CollapseButton.Icon:SetDesaturated(true)
local disc = CreateFrame("Frame", nil, bf)
local h = { disc = disc, glyphs = { [mm.MaximizeButton] = { frame = CreateFrame("Frame", nil, mm.MaximizeButton) } } }
local mheaders = { [hdr] = { glass = CreateFrame("Frame", nil, hdr) } }
rawset(_G, "GlassUI", { Map = { _test = { wins = { [wm] = h }, headers = mheaders,
    isHeader = function(row) return type(row.ButtonText) == "table" and type(row.CollapseButton) == "table" end } } })
SkinProbeDB.suiteBlocked = 0
local okM, whyM = T.mpOn("t", { log = true, max = false })()
check(okM, "the map as the skin leaves it: pass: " .. tostring(whyM))
local mr = SkinProbeDB.results["MP.t"]
eq(mr.crumbs, 2, "two crumbs read (home once)")
eq(mr.headers, 1, "one header")
crumb._normal:SetAlpha(1)
okM, whyM = T.mpOn("t")()
check(not okM and whyM:find("crumbs faded 1 of 2", 1, true), "a crumb left fails")
crumb._normal:SetAlpha(0)
nav.overflowButton._normal:SetAlpha(0)
okM, whyM = T.mpOn("t")()
check(not okM and whyM:find("overflow button faded", 1, true), "the overflow button faded fails")
nav.overflowButton:Hide()
check(T.mpOn("t")(), "a hidden overflow button isn't read")
nav.overflowButton:Show()
nav.overflowButton._normal:SetAlpha(1)
bf.PortraitContainer.portrait:Hide()
okM, whyM = T.mpOn("t")()
check(not okM and whyM:find("disc true with the portrait false", 1, true), "the disc left over a hidden portrait fails")
disc:Hide()
check(T.mpOn("t")(), "the disc hidden with it: pass")
bf.PortraitContainer.portrait:Show()
disc:Show()
h.glyphs[mm.MaximizeButton].frame:Hide()
okM, whyM = T.mpOn("t")()
check(not okM and whyM:find("glyphs 0 of 1", 1, true), "a shown button without its glyph fails")
h.glyphs[mm.MaximizeButton].frame:Show()
hdr.CollapseButton.Icon:SetDesaturated(false)
okM, whyM = T.mpOn("t", { log = true })()
check(not okM and whyM:find("headers 0 of 1", 1, true), "a header's +/- untinted fails")
check(T.mpOn("t")(), "not read without want.log")
hdr.CollapseButton.Icon:SetDesaturated(true)
hdr._normal:SetAlpha(1)
okM, whyM = T.mpOn("t", { log = true })()
check(not okM and whyM:find("headers 0 of 1", 1, true), "a header's bar back fails")
hdr._normal:SetAlpha(0)
qsf.BorderFrame.Shadow:SetAtlas("questlog-frame-gradient-bottom")
okM, whyM = T.mpOn("t", { log = true })()
check(not okM and whyM:find("shadow back", 1, true), "the log's shadow back fails")
qsf.BorderFrame.Shadow:SetTexture(nil)
qsf.BorderFrame.Shadow._atlas = nil
qsf.Background:SetAlpha(1)
okM, whyM = T.mpOn("t", { log = true })()
check(not okM and whyM:find("log background 1", 1, true), "the log's background back fails")
qsf.Background:SetAlpha(0)
nav.Refresh = nil
okM, whyM = T.mpOn("t")()
check(not okM and whyM:find("hooked method missing", 1, true), "a hooked method missing fails")
nav.Refresh = function() end
bf.NineSlice:SetAlpha(1)
okM, whyM = T.mpOn("t")()
check(not okM and whyM:find("shell 1", 1, true), "the shell left fails")
bf.NineSlice:SetAlpha(0)
okM, whyM = T.mpOn("t", { max = true })()
check(not okM and whyM:find("maximized false", 1, true), "maximised wanted, windowed: fails")
okM, whyM = T.mpOn("t", { combat = true })()
check(not okM and whyM:find("combat false", 1, true), "combat wanted: fails")
SkinProbeDB.suiteBlocked = 2
okM, whyM = T.mpOn("t")()
check(not okM and whyM:find("2 blocked", 1, true), "a blocked action fails")
SkinProbeDB.suiteBlocked = 0
GlassUI.Map._test.wins[wm] = nil
okM, whyM = T.mpOn("t")()
check(not okM and whyM:find("not installed", 1, true), "not installed fails")
-- The Leatrix yield read in game: shown, nothing of ours built, the status naming it.
local mstatus = "skipped: Leatrix_Maps rebuilds this window"
GlassUI.Engine = { Status = function() return mstatus end }
check(T.mpYield("y", "yield")(), "the yield: pass")
GlassUI.Map._test.wins[wm] = h
okM, whyM = T.mpYield("y", "yield")()
check(not okM and whyM:find("built true", 1, true), "our glass built under Leatrix's frame fails")
GlassUI.Map._test.wins[wm] = nil
mstatus = "on"
okM = T.mpYield("y", "yield")()
check(not okM, "a status not naming Leatrix fails")
wm:Hide()
mstatus = "skipped: Leatrix_Maps rebuilds this window"
check(not T.mpYield("y", "yield")(), "the map not shown fails")
wm:Show()
-- The minimise watch: what's under the cursor, the press, the swap.
GlassUI.Map._test.wins[wm] = h
mm.MinimizeButton:Show()
mm.MaximizeButton:Hide()
T.mpStartWatch()
local foci = { mm.MinimizeButton }
rawset(_G, "GetMouseFoci", function() return foci end)
WoW.mouseOver[mm.MinimizeButton] = true
T.mpWatchTick()
mm.MinimizeButton._buttonState = "PUSHED"
T.mpWatchTick()
mm.MinimizeButton._buttonState = nil
mm.MinimizeButton:Hide()
T.mpWatchTick()
local okW, whyW = T.mpReadWatch("w")()
check(okW, "the watch reads")
local wr = SkinProbeDB.results["MP.w"]
eq(wr.pressed, true, "the press seen")
eq(wr.minimised, true, "the swap seen")
eq(wr.foci, "MinimizeButton", "Blizzard's button under the cursor")
check(whyW:find("pressed true, minimised true", 1, true), "said")
-- A frame of ours under the cursor is named; nothing after the watch stops.
mm.MinimizeButton:Show()
T.mpStartWatch()
foci = { h.glyphs[mm.MaximizeButton].frame }
T.mpWatchTick()
T.mpReadWatch("w2")()
eq(SkinProbeDB.results["MP.w2"].foci, "our glyph", "our glyph named")
eq(SkinProbeDB.results["MP.w2"].pressed, false, "no press")
eq(SkinProbeDB.results["MP.w2"].minimised, false, "no swap")
mm.MinimizeButton:Hide()
T.mpWatchTick()
T.mpReadWatch("w3")()
eq(SkinProbeDB.results["MP.w3"].minimised, false, "stopped: nothing recorded after the read")
WoW.mouseOver[mm.MinimizeButton] = nil
rawset(_G, "GetMouseFoci", nil)
rawset(_G, "WorldMapFrame", nil)
rawset(_G, "QuestScrollFrame", nil)
rawset(_G, "GlassUI", savedGUI8)
end

do
-- #105: the loot windows as the procedure reads them.
local savedGUI9 = rawget(_G, "GlassUI")
local lf = CreateFrame("Frame", "LootFrame", UIParent)
lf.NineSlice = CreateFrame("Frame", nil, lf)
lf.NineSlice:SetAlpha(0)
lf.ScrollBox = CreateFrame("Frame", nil, lf)
lf.ScrollBox.ScrollTarget = CreateFrame("Frame", nil, lf.ScrollBox)
local lrow = CreateFrame("Frame", nil, lf.ScrollBox.ScrollTarget)
lrow.NameFrame = lrow:CreateTexture()
lrow.NameFrame:SetAlpha(0)
lrow.HighlightNameFrame = lrow:CreateTexture()
lrow.HighlightNameFrame:SetDesaturated(true)
lrow.Item = CreateFrame("Button", nil, lrow)
lrow.Item._normal = lrow.Item:CreateTexture()
lrow.Item._normal:SetAlpha(0)
local empty = CreateFrame("Frame", nil, lf.ScrollBox.ScrollTarget)
local hf = CreateFrame("Frame", "GroupLootHistoryFrame", UIParent)
hf.NineSlice = CreateFrame("Frame", nil, hf)
hf.NineSlice:SetAlpha(0)
hf.NoInfoString = hf:CreateFontString()
hf.ScrollBox = CreateFrame("Frame", nil, hf)
hf.ScrollBox.ScrollTarget = CreateFrame("Frame", nil, hf.ScrollBox)
local hrow2 = CreateFrame("Frame", nil, hf.ScrollBox.ScrollTarget)
hrow2.BackgroundArtFrame = CreateFrame("Frame", nil, hrow2)
hrow2.BackgroundArtFrame:SetFrameLevel(400)
hrow2.BackgroundArtFrame.NameFrame = hrow2.BackgroundArtFrame:CreateTexture()
hrow2.BackgroundArtFrame.NameFrame:SetAlpha(0)
local lglass, hglass = CreateFrame("Frame", nil, lrow), CreateFrame("Frame", nil, hrow2)
hglass:SetFrameLevel(399)
rawset(_G, "GlassUI", { Loot = { _test = { wins = { [lf] = {}, [hf] = {} },
    rows = { [lrow] = { glass = lglass }, [hrow2] = { glass = hglass } } } } })
SkinProbeDB.suiteBlocked = 0
local okL, whyL = T.ltOn("l", { rows = true })()
check(okL, "the loot window in glass: pass: " .. tostring(whyL))
eq(SkinProbeDB.results["LT.l"].rows, 1, "one row read: the empty slot isn't one")
lrow.Item._normal:SetAlpha(1)
okL, whyL = T.ltOn("l")()
check(not okL and whyL:find("rows 0 of 1", 1, true), "a slot back fails")
lrow.Item._normal:SetAlpha(0)
lrow.HighlightNameFrame:SetDesaturated(false)
okL, whyL = T.ltOn("l")()
check(not okL and whyL:find("rows 0 of 1", 1, true), "a gold stroke fails")
lrow.HighlightNameFrame:SetDesaturated(true)
lrow.NameFrame:SetAlpha(1)
okL, whyL = T.ltOn("l")()
check(not okL and whyL:find("rows 0 of 1", 1, true), "a plate back fails")
lrow.NameFrame:SetAlpha(0)
lglass:Hide()
okL, whyL = T.ltOn("l")()
check(not okL and whyL:find("rows 0 of 1", 1, true), "a row without its glass fails")
lglass:Show()
lf.NineSlice:SetAlpha(1)
okL, whyL = T.ltOn("l")()
check(not okL and whyL:find("shell 1", 1, true), "the shell back fails")
lf.NineSlice:SetAlpha(0)
lrow:Hide()
okL, whyL = T.ltOn("l", { rows = true })()
check(not okL and whyL:find("no row read", 1, true), "rows wanted, none shown: fails")
lrow:Show()
SkinProbeDB.suiteBlocked = 1
okL, whyL = T.ltOn("l")()
check(not okL and whyL:find("1 blocked", 1, true), "a blocked action fails")
okL = T.ltClosed("c")()
check(not okL, "closed: still open, and blocked: fails")
SkinProbeDB.suiteBlocked = 0
okL, whyL = T.ltClosed("c")()
check(not okL and whyL:find("still open", 1, true), "still open, nothing blocked: fails")
lf:Hide()
okL, whyL = T.ltClosed("c")()
check(okL and whyL:find("closed", 1, true), "closed without a block: pass")
lf:Show()
-- The history: its row glass at the art's level - 1.
local okH2, whyH2 = T.ltOn("h", { history = true, rows = true })()
check(okH2, "the history in glass: pass: " .. tostring(whyH2))
hglass:SetFrameLevel(499)
okH2, whyH2 = T.ltOn("h", { history = true })()
check(not okH2 and whyH2:find("rows 0 of 1", 1, true), "history glass over the roll-100 effect fails")
hglass:SetFrameLevel(399)
GlassUI.Loot._test.wins[hf] = nil
okH2, whyH2 = T.ltOn("h", { history = true })()
check(not okH2 and whyH2:find("not installed", 1, true), "not installed fails")
for _, n in ipairs({ "LootFrame", "GroupLootHistoryFrame" }) do rawset(_G, n, nil) end
rawset(_G, "GlassUI", savedGUI9)
end

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
local firstStep, treeStep
for _, st in ipairs(FP.procedures["SkinProbe/questing"].steps) do
    if st.text:find("first appeared", 1, true) and not firstStep then firstStep = st end
    if st.text:find("frame trees", 1, true) then treeStep = st end
end
-- Questie's tracker made late in its startup: absent at the step after the
-- reload, seen by the watcher later, kept by the step after the waits.
local qframe = rawget(_G, "Questie_BaseFrame")
rawset(_G, "Questie_BaseFrame", nil)
T.seen.Questie_BaseFrame = nil
eq(firstStep.run(), 2, "at login, Questie's tracker isn't there yet")
eq(SkinProbeDB.results["QS.firstSeen"].Questie_BaseFrame, nil, "so the early copy lacks it")
rawset(_G, "Questie_BaseFrame", qframe)
T.lookFor("PEW+9.0s")
treeStep.run()
eq(SkinProbeDB.results["QS.firstSeen"].Questie_BaseFrame, "PEW+9.0s", "the step after the waits keeps the late sighting")
eq(SkinProbeDB.results["QS.firstSeen"].RXPG_ARROW, "PEW+3.5s", "with the others")
for k in pairs(T.seen) do T.seen[k] = nil end      -- the next session: nothing loaded
WoW.fire("ADDON_LOADED", "SkinProbe")
WoW.fire("PLAYER_LOGIN")
T.lookFor("PLAYER_ENTERING_WORLD")
eq(SkinProbeDB.results["QS.firstSeen"].RXPG_ARROW, "PEW+3.5s", "a session without them leaves the run's result")
eq(SkinProbeDB.results["QS.firstSeen"].Questie_BaseFrame, "PEW+9.0s", "the late sighting included")
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
                        "meterskin", "meterbars", "suitepanel", "pearl", "tracker", "questing", "accent" }) do
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
