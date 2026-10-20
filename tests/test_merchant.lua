-- The merchant skin: what it fades, what it leaves stock, our glass, and its
-- live switch (the latest alpha Blizzard set comes back, including one set
-- while the skin was on).
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local GUI = loadAddon()
local M = MerchantFrame
local Engine = GUI.Engine

local function faded()
    local list = { M.NineSlice, M.Bg, M.TopTileStreaks, M.Inset.Bg, M.Inset.NineSlice,
                   MerchantMoneyInset.Bg, MerchantMoneyInset.NineSlice,
                   MerchantExtraCurrencyInset.Bg, MerchantExtraCurrencyInset.NineSlice,
                   MerchantMoneyBg, MerchantExtraCurrencyBg, MerchantFrameBottomLeftBorder, BuybackBG }
    for i = 1, 2 do
        for _, key in ipairs(GUI.Kit.TAB_ART) do list[#list + 1] = _G["MerchantFrameTab" .. i][key] end
    end
    return list
end
local function stock()
    local list = { M.PortraitContainer.portrait, M.CloseButton, M.FilterDropdown }
    for i = 1, 12 do
        local row = _G["MerchantItem" .. i]
        list[#list + 1] = row.SlotTexture
        list[#list + 1] = _G["MerchantItem" .. i .. "NameFrame"]
        list[#list + 1] = row.Name
        list[#list + 1] = row.ItemButton
    end
    for i = 1, 2 do
        local t = _G["MerchantFrameTab" .. i]
        list[#list + 1] = t.LeftHighlight; list[#list + 1] = t.MiddleHighlight; list[#list + 1] = t.RightHighlight
        list[#list + 1] = t.Text
    end
    return list
end
local function all(list, alpha, msg)
    local bad = 0
    for _, r in ipairs(list) do if r:GetAlpha() ~= alpha then bad = bad + 1 end end
    eq(bad, 0, msg .. " (" .. #list .. " regions)")
end
-- Our frames under a Blizzard frame: its children the stub didn't mark as Blizzard's.
local function ours(parent)
    local list = {}
    for _, c in ipairs(parent._children) do if not rawget(c, "_blizz") then list[#list + 1] = c end end
    return list
end

eq(Engine.Status("merchant"), "on", "the merchant skin is on by default")
all(faded(), 1, "nothing is touched before the window first shows")
eq(#ours(M), 0, "and no panel is built yet")

-- First show: install and style.
WoW.showMerchant()
all(faded(), 0, "the shell art is faded")
all(stock(), 1, "the portrait, buttons, item rows, texts and tab highlights stay stock")
local panels = ours(M)
eq(#panels, 1, "one glass panel under the window")
eq(panels[1]:GetFrameLevel(), M:GetFrameLevel() - 1, "one level below the window")
check(panels[1]._name == nil and not panels[1]:IsMouseEnabled(), "unnamed, mouse off")
eq(#ours(MerchantFrameTab1) + #ours(MerchantFrameTab2), 2, "one glass panel under each tab")

-- Blizzard at work: an alpha set while faded is held at 0; tabs switch with Show/Hide.
WoW.asBlizzard(function() M.Bg:SetAlpha(0.6) end)
eq(M.Bg:GetAlpha(), 0, "an alpha Blizzard sets while faded is held at 0")
WoW.merchantTab(2)
check(BuybackBG:IsShown() and not MerchantFrameBottomLeftBorder:IsShown(), "the buyback tab shows its backdrop")
all(faded(), 0, "everything stays faded across tabs")
WoW.merchantTab(1)

-- Hidden and shown again: styled again, installed once.
WoW.hideMerchant()
WoW.showMerchant()
eq(#ours(M), 1, "a second show builds nothing new")

-- Live off: Blizzard's latest alpha back, our glass hidden, no /reload needed.
WoW.chat = {}
GUI._test.slash("skin merchant off")
check(not table.concat(WoW.chat, "\n"):find("/reload", 1, true), "off is live: no /reload asked")
eq(M.Bg:GetAlpha(), 0.6, "the alpha Blizzard set while the skin was on comes back")
eq(M.NineSlice:GetAlpha(), 1, "the rest come back to theirs")
check(not panels[1]:IsShown(), "our panel hides")
eq(GlassUIDB.skins.merchant, false, "the switch is saved")
WoW.asBlizzard(function() M.Bg:SetAlpha(0.9) end)
eq(M.Bg:GetAlpha(), 0.9, "while off, Blizzard's alphas apply")
WoW.hideMerchant()
WoW.showMerchant()
eq(M.NineSlice:GetAlpha(), 1, "while off, a show touches nothing")

-- Live on, with the window open: styled at once.
GUI._test.slash("skin merchant on")
eq(M.NineSlice:GetAlpha(), 0, "on again: faded at once")
check(panels[1]:IsShown(), "our panel shows again")
eq(GlassUIDB.skins.merchant, nil, "on is the default: nothing saved")

-- The master switch, both ways.
GUI._test.slash("off")
eq(M.Bg:GetAlpha(), 0.9, "master off: the latest alpha back")
check(Engine.Status("merchant") == "off", "master off: the skin reads off")
GUI._test.slash("on")
eq(M.Bg:GetAlpha(), 0, "master on: faded again")
eq(rawget(GlassUIDB, "enabled"), nil, "master on is the default: nothing saved")

-- Off while hidden, then shown: nothing touched until switched on.
WoW.hideMerchant()
GUI._test.slash("skin merchant off")
WoW.showMerchant()
eq(M.NineSlice:GetAlpha(), 1, "off: shown stock")
GUI._test.slash("skin merchant on")

-- The theme repaints our glass live.
local S = GUI.Theme._test.surfaces
check(#S >= 3, "the window's and tabs' surfaces are registered with the theme (" .. #S .. ")")
GUI._test.slash("theme smoked")
local c = S[1].g.tint._color
local B = GUI.Suite.BODY
local want = B.smoked.tint
check(c and c[1] == want[1] and c[4] == want[4], "smoked repaints the tint")
eq(S[1].backing._color[4], B.smoked.backing, "and the backing's opacity")
-- The looks the owner picked on the merchant (#4, 70425): clear and class light,
-- smoked dense, so the two glass looks differ.
eq(B.clear.backing, 0.35, "clear's backing is light (0.35)")
eq(B.class.backing, B.clear.backing, "class is clear's body, tinted")
check(B.smoked.backing - B.clear.backing >= 0.4, "smoked stays much denser")
eq(GlassUIDB.suite.look.tint, "smoked", "the tint is saved as the suite look's (#67)")
eq(rawget(GlassUIDB, "theme"), nil, "not as the old theme")
GUI._test.slash("theme clear")
eq(S[1].backing._color[4], 0.35, "clear repaints the backing light")

-- The switch survives a reload.
GUI = loadAddon({ db = { skins = { merchant = false } } })
WoW.showMerchant()
eq(MerchantFrame.NineSlice:GetAlpha(), 1, "saved off: the window stays stock after a reload")
eq(GUI.Engine.Status("merchant"), "off", "and reads off")

eq(next(GUI.failures), nil, "no failures")
for k, v in pairs(GUI.failures) do io.write("    " .. k .. ": " .. v .. "\n") end
done("test_merchant")
