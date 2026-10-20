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
    -- The rows' slots and plates (#80), and the buyback slot's slot.
    for i = 1, 12 do
        list[#list + 1] = _G["MerchantItem" .. i].SlotTexture
        list[#list + 1] = _G["MerchantItem" .. i .. "NameFrame"]
    end
    list[#list + 1] = MerchantBuyBackItem.SlotTexture
    return list
end
local function stock()
    local list = { M.PortraitContainer.portrait, M.CloseButton, M.FilterDropdown, MerchantBuyBackItemNameFrame }
    for i = 1, 12 do
        local row = _G["MerchantItem" .. i]
        list[#list + 1] = row.Name
        list[#list + 1] = row.ItemButton
        list[#list + 1] = row.ItemButton.icon
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
all(stock(), 1, "the portrait, buttons, icons, texts and tab highlights stay stock")
local panels = ours(M)
eq(#panels, 2, "one glass panel under the window, and the portrait's disc")
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
eq(#ours(M), 2, "a second show builds nothing new")

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
-- The merchant is a window over other UI (#80): its own glass at the floor.
local function surfaceOf(host)
    for _, x in ipairs(S) do if x.backing and x.backing._parent == host then return x end end
end
local win = surfaceOf(panels[1])
eq(win.backing._color[4], GUI.Theme.WINDOW_BACKING, "clear: the window at the window floor")
eq(GUI.Theme.WINDOW_BACKING, 0.75, "0.75 until the owner's pick (MS.1)")
eq(surfaceOf(panels[2]).backing._color[4], GUI.Theme.WINDOW_BACKING, "its disc too")
GUI._test.slash("theme smoked")
eq(win.backing._color[4], B.smoked.backing, "smoked's denser 0.92 stays")
GUI._test.slash("theme class")
eq(win.backing._color[4], GUI.Theme.WINDOW_BACKING, "class rises to the floor too")
eq(S[1].backing._color[4], 0.35, "while a skin over the world keeps the body's")
GUI._test.slash("theme clear")

-- The item rows in glass (#80, docs/MERCHANT.md): ours under each row, no
-- backing (the window's is under it), Blizzard's red mirrored, no glass on
-- an empty row.
local R = GUI.Merchant._test
local function at(frame, point, rel, relPoint, x, y, msg)
    local a
    for _, pt in ipairs(frame._points) do if pt[1] == point then a = pt end end
    check(a and a[2] == rel and a[3] == relPoint and a[4] == x and a[5] == y,
          msg .. ": " .. point .. " " .. tostring(a and a[4]) .. "," .. tostring(a and a[5]))
end
local r1 = R.rows[MerchantItem1]
check(r1 ~= nil, "row 1 has glass of ours")
eq(r1.glass:GetParent(), MerchantItem1, "a child of the row: it hides with it (11 and 12 per tab)")
eq(r1.glass:GetFrameLevel(), MerchantItem1:GetFrameLevel() - 1, "one level under the row")
check(r1.glass:GetFrameLevel() > panels[1]:GetFrameLevel(), "over the window's glass")
eq(r1.g.top:GetFrameLevel(), r1.glass:GetFrameLevel(), "its rim there too, under the icon border and text")
eq(surfaceOf(r1.glass), nil, "no backing of its own")
local painted = false
for _, x in ipairs(S) do if x.g == r1.g then painted = true end end
check(painted, "but painted by the theme")
local I = R.ROW_INSETS
at(r1.glass, "TOPLEFT", MerchantItem1, "TOPLEFT", I[1], -I[2], "the row's glass around the row")
at(r1.glass, "BOTTOMRIGHT", MerchantItem1, "BOTTOMRIGHT", -I[3], I[4], "to its bottom right")
check(r1.glass:IsShown(), "a filled row shows its glass")
eq(_G.MerchantItem1NameFrame:GetAlpha(), 0, "the label plate faded")
eq(MerchantItem1.SlotTexture:GetAlpha(), 0, "the slot faded")
check(not r1.red:IsShown(), "Blizzard's grey plate: no red")
WoW.merchantRow(1, "red")
check(r1.red:IsShown(), "can't use or afford: Blizzard's red mirrored on our glass")
near(r1.red._color[4], 0.35, "at 0.35")
eq(r1.red._color[1], 1, "in red")
check(r1.red._masks and r1.red._masks[1] == r1.g.mask, "inside the row's glass")
WoW.merchantRow(1, "darkred")
near(r1.red._color[4], 0.175, "sold out and red: Blizzard's dark red, fainter")
WoW.merchantRow(1, "normal")
check(not r1.red:IsShown(), "grey again: no red")
eq(_G.MerchantItem1NameFrame:GetAlpha(), 0, "the plate stays faded through Blizzard's recolours")
-- A partial page and back.
for i = 7, 10 do WoW.merchantRow(i, "empty") end
check(not R.rows[MerchantItem7].glass:IsShown() and not R.rows[MerchantItem10].glass:IsShown(),
      "a partial page: the empty rows show no glass")
check(R.rows[MerchantItem6].glass:IsShown(), "the filled ones keep theirs")
for i = 7, 10 do WoW.merchantRow(i, "normal") end
check(R.rows[MerchantItem7].glass:IsShown(), "a full page again: glass back")
-- The buyback tab's rows 11 and 12.
WoW.merchantTab(2)
check(R.rows[MerchantItem11].glass:IsVisible(), "the buyback tab: row 11's glass seen")
WoW.merchantTab(1)
check(not R.rows[MerchantItem11].glass:IsVisible(), "the merchant tab: row 11 hidden, its glass with it")
WoW.merchantTab(2)
check(R.rows[MerchantItem12].glass:IsVisible(), "and back")
WoW.merchantTab(1)
-- The buyback slot: its button never hides, its icon tells.
local bb = R.rows[MerchantBuyBackItem]
check(bb ~= nil, "the buyback slot has glass of ours")
eq(MerchantBuyBackItem.SlotTexture:GetAlpha(), 0, "its slot faded")
eq(MerchantBuyBackItemNameFrame:GetAlpha(), 1, "its plate left as Blizzard has it")
check(not bb.glass:IsShown(), "nothing sold yet: no glass")
WoW.buybackSlot(133784)
check(bb.glass:IsShown(), "an item sold: its glass shows")
WoW.buybackSlot(nil)
check(not bb.glass:IsShown(), "bought back: gone again")
check(MerchantBuyBackItemItemButton:IsShown(), "with its button shown throughout")
WoW.asBlizzard(function() MerchantBuyBackItemItemButton.icon:SetAtlas("common-icon-undo") end)
check(bb.glass:IsShown(), "an icon given as an atlas counts as an item")
WoW.buybackSlot(133784)
-- Off: the plates and slots back, our rows hidden; Blizzard changes rows meanwhile.
WoW.merchantRow(5, "empty")
GUI._test.slash("skin merchant off")
WoW.merchantRow(5, "normal")
check(not R.rows[MerchantItem5].glass:IsShown(), "off: a row filled shows no glass of ours")
eq(_G.MerchantItem1NameFrame:GetAlpha(), 1, "off: the plate back")
eq(MerchantBuyBackItem.SlotTexture:GetAlpha(), 1, "the buyback slot's slot back")
check(not r1.glass:IsShown() and not bb.glass:IsShown(), "our rows hidden")
check(not panels[2]:IsShown(), "and the disc")
WoW.merchantRow(3, "red")
WoW.merchantRow(4, "empty")
WoW.buybackSlot(nil)
local r3, r4 = R.rows[MerchantItem3], R.rows[MerchantItem4]
check(not r3.red:IsShown() and not r3.glass:IsShown(), "off: a recolour touches nothing of ours")
check(not bb.glass:IsShown(), "nor an emptied buyback slot")
GUI._test.slash("skin merchant on")
check(r3.glass:IsShown() and r3.red:IsShown(), "on again: the red set while off shows")
check(not r4.glass:IsShown(), "the row emptied while off shows no glass")
check(not bb.glass:IsShown(), "nor the buyback slot emptied while off")
check(r1.glass:IsShown() and panels[2]:IsShown(), "the rest back")
eq(R.redAlpha(0.5, 0.5, 0.5), nil, "grey is no red")
eq(R.redAlpha(nil, 0, 0), nil, "a colour that can't be read is no red")
WoW.merchantRow(3, "normal"); WoW.merchantRow(4, "normal")

-- The portrait's disc (#48): round its mask, under the portrait, over the glass.
local disc = panels[2]
local mask = M.PortraitContainer.CircleMask
eq(disc:GetWidth(), mask:GetWidth() + 2 * R.DISC_RING, "the mask's width and a 6 px ring each side")
eq(disc:GetWidth(), disc:GetHeight(), "square, as a disc wants")
at(disc, "CENTER", mask, "CENTER", 0, 0, "centred on the round mask, not the portrait's rectangle")
eq(disc:GetFrameLevel(), M.PortraitContainer:GetFrameLevel() - 1, "one level under the portrait")
eq(surfaceOf(disc).g.top:GetFrameLevel(), disc:GetFrameLevel(), "its rim too")
check(disc:GetFrameLevel() > r1.glass:GetFrameLevel(), "over the rows' glass")
eq(disc._name, nil, "unnamed")

-- Without the mask (another build): round the portrait.
GUI = loadAddon({ before = function() rawset(MerchantFrame.PortraitContainer, "CircleMask", nil) end })
WoW.showMerchant()
local disc2 = ours(MerchantFrame)[2]
eq(disc2:GetWidth(), 62 + 2 * GUI.Merchant._test.DISC_RING, "no mask: round the portrait")
at(disc2, "CENTER", MerchantFrame.PortraitContainer.portrait, "CENTER", 0, 0, "centred on it")
-- A size that can't be read: the mask's XML width.
GUI = loadAddon({ before = function()
    MerchantFrame.PortraitContainer.CircleMask._width = 0
end })
WoW.showMerchant()
eq(ours(MerchantFrame)[2]:GetWidth(), 58 + 2 * GUI.Merchant._test.DISC_RING, "unreadable: 58, the XML's")

-- The switch survives a reload.
GUI = loadAddon({ db = { skins = { merchant = false } } })
WoW.showMerchant()
eq(MerchantFrame.NineSlice:GetAlpha(), 1, "saved off: the window stays stock after a reload")
eq(GUI.Engine.Status("merchant"), "off", "and reads off")

eq(next(GUI.failures), nil, "no failures")
for k, v in pairs(GUI.failures) do io.write("    " .. k .. ": " .. v .. "\n") end
done("test_merchant")
