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
eq(r.D, 0, "D (no gradient) reads 0")
T.gradientOff()

-- The procedures are defined and every step's run and check works here.
for _, name in ipairs({ "wave1", "map", "gradient" }) do
    local p = FP.procedures["SkinProbe/" .. name]
    check(p ~= nil, "procedure " .. name .. " is defined")
    if p then
        for i, st in ipairs(p.steps) do
            if st.run then
                local ok, err = pcall(st.run)
                check(ok, name .. " step " .. i .. " runs: " .. tostring(err))
            end
            if st.check then
                local ok, err = pcall(st.check)
                check(ok, name .. " step " .. i .. " check runs: " .. tostring(err))
            end
        end
    end
end
T.panelsOff(); T.borderRestore(); T.gradientOff()
eq(#WoW.chat, 0, "still nothing in chat after every procedure step")

done("test_probe")
