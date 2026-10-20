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
eq(#panels, 3, "one glass panel under the window, the portrait's disc, and the buyback empty state (#84)")
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
eq(#ours(M), 3, "a second show builds nothing new")

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
-- A surface by its glass (the disc has no backing to find it by).
local function glassOf(host)
    for _, x in ipairs(S) do if x.g.tint and x.g.tint._parent == host then return x end end
end
local win = surfaceOf(panels[1])
eq(win.backing._color[4], GUI.Theme.WINDOW_BACKING, "clear: the window at the window floor")
eq(GUI.Theme.WINDOW_BACKING, 0.93, "the item area denser: text behind stops competing (owner, #86)")
-- The disc (#48): Pearl clear, no backing, whatever the tint (owner, MS.3).
local disc = glassOf(panels[2])
check(disc ~= nil, "the disc is painted by the theme")
eq(disc.backing, nil, "with no backing: a dark ring otherwise")
local clearTint = B.clear.tint
local function isClear(msg)
    local dc = disc.g.tint._color
    check(dc and dc[1] == clearTint[1] and dc[4] == clearTint[4], msg)
end
isClear("clear on the clear tint")
GUI._test.slash("theme smoked")
eq(win.backing._color[4], GUI.Theme.WINDOW_BACKING, "smoked's 0.92 rises to the floor too")
isClear("the disc stays clear on smoked")
GUI._test.slash("theme class")
eq(win.backing._color[4], GUI.Theme.WINDOW_BACKING, "class rises to the floor too")
isClear("and on class")
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
near(r1.red._color[4], 0.12, "at 0.12: a burgundy undertone on a charcoal card (#86)")
eq(r1.red._color[1], 1, "in red")
check(r1.red._masks and r1.red._masks[1] == r1.g.mask, "inside the row's glass")
WoW.merchantRow(1, "darkred")
near(r1.red._color[4], 0.06, "sold out and red: Blizzard's dark red, fainter")
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
eq(glassOf(disc).g.top:GetFrameLevel(), disc:GetFrameLevel(), "its rim too")
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

-- The layout (#84, docs/MERCHANT.md section 4): sections (the default) or the
-- mockup's bar, switched live; the active tab marked in both.
GUI = loadAddon()
WoW.showMerchant()
R = GUI.Merchant._test
local u = R.ui[MerchantFrame]
check(u ~= nil, "the layout is built at install")
local win = ours(MerchantFrame)[1]
local L = GUI.Merchant
eq(L.Layout(), "bar", "the bar by default (owner, #86)")
eq(L.Saved(), "bar", "saved: the default")
check(L.SetLayout("sections"), "sections for the next checks (the probe's override)")
local function on(sec) return sec ~= nil and sec.fill:IsShown() and sec.edges[1]:IsShown() and sec.edges[4]:IsShown() end
local function off(sec) return sec == nil or (not sec.fill:IsShown() and not sec.edges[1]:IsShown()) end
local function anchored(tex, point, rel, relPoint, x, y, msg) at(tex, point, rel, relPoint, x, y, msg) end

-- A section: on the window glass's host, over its body, under the rows' glass.
eq(u.inset.fill:GetParent(), win, "a section lives in the window glass's host")
eq(u.inset.fill._layer, "ARTWORK", "its fill on ARTWORK, over the glass body (BACKGROUND)")
eq(u.inset.fill._sub, 0, "sublevel 0")
eq(u.inset.edges[1]._layer, "ARTWORK", "its edges on ARTWORK")
eq(u.inset.edges[1]._sub, 1, "over the fill")
check(win:GetFrameLevel() < R.rows[MerchantItem1].glass:GetFrameLevel(), "under every row's glass")
eq(#u.inset.edges, 4, "four edges")
eq(u.inset.edges[1]:GetHeight(), 1, "1 px")
local B = GUI.Suite.BODY
local fc = u.inset.fill._color
check(fc and fc[1] == 0 and fc[2] == 0 and fc[3] == 0 and fc[4] == GUI.Kit.SECTION_FILL, "the fill: black at SECTION_FILL")
eq(GUI.Kit.SECTION_FILL, 0.4, "dark enough to show on the floor (ML run 1)")
local ec = u.inset.edges[1]._color
check(ec and ec[1] == 1 and ec[4] == GUI.Kit.SECTION_EDGE, "the edge: white at SECTION_EDGE")

-- Sections: Blizzard's structure, where Blizzard draws it.
anchored(u.inset.fill, "TOPLEFT", MerchantFrame.Inset, "TOPLEFT", 0, 0, "the item inset's section on the inset")
anchored(u.inset.fill, "BOTTOMRIGHT", MerchantFrame.Inset, "BOTTOMRIGHT", 0, 0, "to its bottom right")
anchored(u.money.fill, "TOPLEFT", MerchantMoneyInset, "TOPLEFT", 0, 0, "the money box on its inset")
anchored(u.currency.fill, "BOTTOMRIGHT", MerchantExtraCurrencyInset, "BOTTOMRIGHT", 0, 0, "the currency box on its inset")
local BL, BR = R.BOX_LEFT, R.BOX_RIGHT
anchored(u.boxLeft.fill, "TOPLEFT", MerchantFrameBottomLeftBorder, "TOPLEFT", BL[1], -BL[2], "the band's left box")
anchored(u.boxLeft.fill, "BOTTOMRIGHT", MerchantFrameBottomLeftBorder, "BOTTOMRIGHT", -BL[3], BL[4], "inside the band")
anchored(u.boxRight.fill, "TOPLEFT", MerchantFrameBottomLeftBorder, "TOPLEFT", BR[1], -BR[2], "the band's right box")
check(on(u.inset) and on(u.money) and on(u.currency), "sections: the inset, money and currency boxes shown")
check(on(u.boxLeft) and on(u.boxRight), "and the band's two boxes on the Merchant tab")
check(off(u.bar) and not u.line:IsShown(), "no bar, no header line")
check(not u.square.host:IsShown() and not u.label:IsShown(), "no buyback square or label")
check(not u.empty:IsShown(), "no empty state")
WoW.merchantTab(2)
check(off(u.boxLeft) and off(u.boxRight), "the Buyback tab: the band's boxes go with the band")
check(on(u.inset) and on(u.money), "the rest stays")
WoW.merchantTab(1)
check(on(u.boxLeft) and on(u.boxRight), "the Merchant tab: back")

-- The active tab: the stock tab's warm gradient on its glass, the other
-- darker, following Blizzard's MiddleActive.
local hl1, hl2 = u.tabs[MerchantFrameTab1], u.tabs[MerchantFrameTab2]
local dim1, dim2 = u.dims[MerchantFrameTab1], u.dims[MerchantFrameTab2]
check(hl1 and hl2 and dim1 and dim2, "a glow and a dim on each tab")
eq(hl1:GetParent(), ours(MerchantFrameTab1)[1], "on the tab's glass")
check(hl1._masks and hl1._masks[1] == u.tabGlass[MerchantFrameTab1].g.mask, "inside its glass")
check(dim1._masks and dim1._masks[1] == u.tabGlass[MerchantFrameTab1].g.mask, "the dim too")
check(hl1:IsShown() and not hl2:IsShown(), "the Merchant tab lit")
check(dim2:IsShown() and not dim1:IsShown(), "the Buyback tab dimmed")
local gr = hl1._gradient
check(gr and gr[1] == "VERTICAL", "a vertical gradient")
local gold = GUI.Suite.ACCENTS.gold
check(gr and gr[2].r == gold[1] and gr[2].g == gold[2] and gr[2].a == R.TAB_GLOW, "the accent at TAB_GLOW at the bottom")
check(gr and gr[3].r == gold[1] and gr[3].a == 0, "to nothing at the top")
eq(dim1._color[1], 0, "the dim black")
eq(dim1._color[4], R.TAB_DIM, "at TAB_DIM")
WoW.merchantTab(2)
check(hl2:IsShown() and not hl1:IsShown(), "the Buyback tab lit after the switch")
check(dim1:IsShown() and not dim2:IsShown(), "and the Merchant tab dimmed")
WoW.asBlizzard(function() MerchantFrameTab1.MiddleActive:Show() end)
check(hl1:IsShown(), "MiddleActive shown alone lights it (the hook on the instance)")
WoW.asBlizzard(function() MerchantFrameTab1.MiddleActive:Hide() end)
check(not hl1:IsShown(), "and hidden, dims it")
WoW.merchantTab(1)

-- The tabs hang from the window: their glass tucked TAB_TUCK under it, in the strata below.
local tg1 = ours(MerchantFrameTab1)[1]
eq(R.TAB_TUCK, 12, "tucked 12 px")
at(tg1, "TOPLEFT", MerchantFrameTab1, "TOPLEFT", 6, R.TAB_TUCK, "the tab's glass reaches up under the window")
eq(MerchantFrame:GetFrameStrata(), "MEDIUM", "the window: a MEDIUM panel")
eq(tg1:GetFrameStrata(), "LOW", "the tab's glass in the strata below, behind the window's floor")
eq(R.ui[MerchantFrame].tabGlass[MerchantFrameTab1].g.top:GetFrameStrata(), "LOW", "its rim too")
eq(ours(MerchantFrameTab2)[1]:GetFrameStrata(), "LOW", "both tabs")
eq(R.TAB_GLOW, 0.3, "the glow")
eq(R.TAB_DIM, 0.25, "the dim")

-- The header: the window's backing from the item inset's top down, a smoky
-- gradient of ours above, joined at the backing's own RGBA.
local L0 = GUI.Merchant
eq(L0.Header(), true, "the header on by default")
local hd = u.header
check(hd and hd:IsShown(), "the header shown")
eq(hd:GetParent(), u.win, "on the window glass's host")
eq(hd._layer, "BACKGROUND", "on the backing's layer")
eq(hd._sub, -7, "its sublevel: under the tint and wash")
check(hd._masks and hd._masks[1] ~= nil and hd._masks[1] == u.backing._masks[1], "clipped by the window glass's mask, as the backing")
at(hd, "TOPLEFT", u.win, "TOPLEFT", 0, 0, "from the window's top")
at(hd, "RIGHT", u.win, "RIGHT", 0, 0, "its width")
at(hd, "BOTTOM", MerchantFrame.Inset, "TOP", 0, 0, "down to the inset's top, where the backing starts")
local function headerColours()
    local g = hd._gradient
    return g and g[2], g and g[3]
end
local hb, ht = headerColours()
local Br, Bg, Bb, Ba = GUI.Theme.Backing("window")
eq(Ba, 0.93, "the window's backing now: the floor")
check(hb and hb.r == Br and hb.a == Ba, "the bottom: the backing's own RGBA, no seam")
check(ht and ht.r == Br and ht.a == R.HEADER_TOP, "the top: HEADER_TOP, smoky glass")
eq(R.HEADER_TOP, 0.45, "0.45")
-- The floor tried lower with smoked over it: the header follows the backing's real alpha.
GUI.Theme.WINDOW_BACKING = 0.85
GUI._test.slash("theme smoked")
hb = headerColours()
near(hb.a, 0.92, "smoked's 0.92 over a 0.85 floor: the header joins at 0.92 (Theme.Backing)")
near(u.backing._color[4], 0.92, "as the backing is painted")
GUI.Theme.WINDOW_BACKING = 0.93
GUI._test.slash("theme clear")
hb = headerColours()
near(hb.a, 0.93, "back")
local bk = u.backing
eq(#bk._points, 4, "the backing on four points")
at(bk, "TOP", MerchantFrame.Inset, "TOP", 0, 0, "its top at the item inset's")
at(bk, "LEFT", u.win, "LEFT", 0, 0, "the window's width")
at(bk, "RIGHT", u.win, "RIGHT", 0, 0, "to its right")
at(bk, "BOTTOM", u.win, "BOTTOM", 0, 0, "down to the window's bottom")
check(L0.SetHeader(false), "the header switched off")
check(not hd:IsShown(), "no header texture")
eq(#bk._points, 1, "the backing whole again")
eq(bk._points[1][1], "ALL", "on the whole window")
L0.SetHeader(true)
at(bk, "TOP", MerchantFrame.Inset, "TOP", 0, 0, "and back")
check(hd:IsShown(), "the header back")

-- The red: one quiet peak in both layouts (#86).
WoW.merchantRow(2, "red")
local r2 = R.rows[MerchantItem2]
eq(R.RED, 0.12, "0.12")
near(r2.red._color[4], R.RED, "sections: full red at RED")
eq(L.SetLayout("glitter"), false, "an unknown layout is refused")
eq(L.Layout(), "sections", "and changes nothing")

-- The bar, live.
check(L.SetLayout("bar"), "bar")
near(r2.red._color[4], R.RED, "bar: the same")
check(r2.red:IsShown(), "still shown")
WoW.merchantRow(4, "darkred")
near(R.rows[MerchantItem4].red._color[4], R.RED * 0.5, "dark red: half of it")
check(off(u.inset) and off(u.money) and off(u.currency) and off(u.boxLeft) and off(u.boxRight), "bar: no sections")
check(on(u.bar), "one footer bar")
check(u.line:IsShown(), "a header line")
anchored(u.line, "TOPLEFT", MerchantFrame.Inset, "TOPLEFT", 0, 0, "along the inset's top")
anchored(u.bar.fill, "TOPLEFT", MerchantFrameBottomLeftBorder, "TOPLEFT", R.BAR_TOPLEFT[1], -R.BAR_TOPLEFT[2],
    "Merchant tab: from the band's top")
anchored(u.bar.fill, "BOTTOMRIGHT", MerchantMoneyInset, "BOTTOMRIGHT", 0, 0, "to the money's bottom right")
-- The buyback slot: a square always, its label while empty.
eq(u.square.host:GetParent(), MerchantBuyBackItem, "the square's frame is in the buyback slot: it hides with it")
eq(u.square.host:GetFrameLevel(), MerchantBuyBackItem:GetFrameLevel(), "at its level, under its ItemButton")
check(u.square.host:IsShown() and on(u.square), "the square shown")
anchored(u.square.fill, "TOPLEFT", MerchantBuyBackItemItemButton, "TOPLEFT", -R.SQUARE_OUTSET, R.SQUARE_OUTSET,
    "round the ItemButton")
check(u.label:IsShown(), "empty: the label shown")
eq(u.label:GetText(), "Buyback", "Buyback")
eq(u.label._font, "GameFontHighlight", "in a Blizzard font")
anchored(u.label, "LEFT", MerchantBuyBackItemItemButton, "RIGHT", 8, 0, "beside the slot")
WoW.buybackSlot(134400)
check(not u.label:IsShown(), "an item sold: Blizzard's name instead")
check(u.square.host:IsShown(), "the square stays")
WoW.buybackSlot(nil)
check(u.label:IsShown(), "bought back: the label again")
-- The Buyback tab: the bar clear of rows 11-12; the empty state with nothing sold.
-- Nothing sold: Blizzard's Buyback page has every row's button hidden.
WoW.buybackCount = 0
for i = 1, 12 do WoW.merchantRow(i, "empty") end
WoW.merchantTab(2)
anchored(u.bar.fill, "TOPLEFT", MerchantExtraCurrencyInset, "TOPLEFT", 0, 0, "Buyback tab: the money strip only")
anchored(u.bar.fill, "BOTTOMRIGHT", MerchantMoneyInset, "BOTTOMRIGHT", 0, 0, "to the money's bottom right")
eq(#u.bar.fill._points, 2, "two points, the old ones cleared")
check(u.empty:IsShown(), "nothing sold: the empty state")
eq(u.empty:GetParent(), MerchantFrame, "in the window")
eq(u.empty:GetFrameLevel(), MerchantFrame:GetFrameLevel() + 1, "over its glass")
eq(u.emptyTitle:GetText(), R.EMPTY_TITLE, "No items to buy back")
eq(u.emptyText:GetText(), R.EMPTY_TEXT, "Items you sell will appear here.")
eq(u.emptyIcon:GetTexture(), R.BUYBACK_ICON, "the Buyback tab's own icon")
eq(R.BUYBACK_ICON, "Interface\\MerchantFrame\\UI-BuyBack-Icon", "its path whole (run 1 lost the backslashes)")
-- A sale on the Buyback tab: Blizzard's first row shows.
WoW.buybackCount = 1
WoW.merchantRow(1, "normal")
check(not u.empty:IsShown(), "the first sale: gone")
-- The last one bought back.
WoW.buybackCount = 0
WoW.merchantRow(1, "empty")
check(u.empty:IsShown(), "the last bought back: back")
WoW.merchantTab(1)
check(not u.empty:IsShown(), "the Merchant tab: none")
anchored(u.bar.fill, "TOPLEFT", MerchantFrameBottomLeftBorder, "TOPLEFT", R.BAR_TOPLEFT[1], -R.BAR_TOPLEFT[2],
    "back to the band's top")
eq(#u.bar.fill._points, 2, "two points again, the Buyback tab's cleared")
-- Closing on the Buyback tab, and the window shown again.
WoW.merchantTab(2)
check(u.empty:IsShown(), "on the Buyback tab")
WoW.hideMerchant()
WoW.merchantTab(1)
WoW.showMerchant()
check(not u.empty:IsShown(), "reopened on the Merchant tab: none")
-- The empty message in sections too (#86).
L.SetLayout("sections")
WoW.merchantTab(2)
check(u.empty:IsShown(), "sections: the empty message on an empty Buyback page")
WoW.buybackCount = 1
WoW.merchantRow(1, "normal")
check(not u.empty:IsShown(), "and gone with the first sale")
WoW.buybackCount = 0
WoW.merchantRow(1, "empty")
WoW.merchantTab(1)
L.SetLayout("bar")

-- Off: nothing of ours; every hook a no-op; switching meanwhile; on: re-synced.
WoW.merchantTab(2)
GUI._test.slash("skin merchant off")
check(not u.empty:IsShown() or not u.empty:IsVisible(), "off: the empty state hidden")
check(not win:IsShown() and not ours(MerchantFrameTab1)[1]:IsShown(), "the window glass, its sections and the tab lights hidden")
check(not u.square.host:IsShown(), "the square hidden")
local count = 0
for _ in pairs(R.ui) do count = count + 1 end
check(u.label:IsShown(), "the label was shown (slot empty) when the skin went off")
WoW.merchantTab(1)
WoW.buybackSlot(134400)
WoW.merchantRow(2, "red")
check(not u.square.host:IsShown(), "off: Blizzard's changes show nothing of ours")
check(u.label:IsShown(), "and its hooks are no-ops: the label's state untouched by the sale")
check(not hl1:IsShown() or not ours(MerchantFrameTab1)[1]:IsShown(), "nor light a tab")
check(L.SetLayout("sections"), "switching while off is kept")
L.SetHeader(false)
eq(u.backing._points[1][1], "TOP", "the header switched while off moves nothing")
near(r2.red._color[4], R.RED, "the red unchanged while off")
GUI._test.slash("skin merchant on")
check(on(u.inset) and on(u.boxLeft) and off(u.bar), "on again: the layout chosen meanwhile")
check(not u.square.host:IsShown() and not u.empty:IsShown(), "and none of the bar's pieces")
near(r2.red._color[4], R.RED, "its red")
check(hl1:IsShown() and not hl2:IsShown(), "the tab lit as Blizzard shows it now")
eq(u.backing._points[1][1], "ALL", "and the header as set while off")
L.SetHeader(true)
L.SetLayout(nil)
WoW.buybackSlot(nil)
WoW.buybackCount = nil

-- The setting (#86): saved sparsely, the probe's override over it.
eq(L.Layout(), "bar", "no override: the saved bar")
local refreshed = 0
local realRefresh = GUI.Options.Refresh
GUI.Options.Refresh = function() refreshed = refreshed + 1 end
GUI._test.slash("merchant sections")
eq(rawget(GlassUIDB, "merchantLayout"), "sections", "saved")
eq(L.Saved(), "sections", "the saved value")
eq(L.Layout(), "sections", "shown")
check(on(u.inset) and off(u.bar), "applied live")
eq(refreshed, 1, "the settings page redrawn")
check(L.SetLayout("bar"), "the probe's override")
eq(L.Layout(), "bar", "shows the bar")
eq(L.Saved(), "sections", "the saved value untouched")
check(on(u.bar), "laid out")
check(L.SetLayout(nil), "dropped")
eq(L.Layout(), "sections", "back to the saved one")
check(on(u.inset), "laid out again")
GUI._test.slash("merchant bar")
eq(rawget(GlassUIDB, "merchantLayout"), nil, "the default: nothing saved")
eq(L.Layout(), "bar", "the bar")
eq(L.SetSaved("glitter"), false, "an unknown layout is refused")
eq(rawget(GlassUIDB, "merchantLayout"), nil, "nothing saved")
GUI._test.slash("skin merchant off")
GUI._test.slash("merchant sections")
eq(refreshed, 3, "the page redrawn while off too")
check(u.bar.fill:IsShown() and not u.inset.fill:IsShown(), "off: nothing laid out (the bar's pieces as they were)")
GUI._test.slash("skin merchant on")
check(on(u.inset) and off(u.bar), "on: the setting saved while off")
GUI._test.slash("merchant bar")
GUI.Options.Refresh = realRefresh

-- The close button (#86): Blizzard's red art faded, our disc and gold X.
local cb = MerchantFrame.CloseButton
for _, k in ipairs({ "_normal", "_pushed", "_disabled", "_highlight" }) do
    eq(cb[k]:GetAlpha(), 0, "its " .. k:sub(2) .. " texture faded")
end
check(u.closeDisc and u.closeDisc:GetParent() == cb, "a disc of ours in the button: it hides with it")
eq(u.closeDisc:GetWidth(), 24, "the button's size")
eq(u.closeDisc:GetFrameLevel(), cb:GetFrameLevel() - 1, "one under it")
at(u.closeDisc, "CENTER", cb, "CENTER", 0, 0, "centred on it")
local x = u.closeFrame
eq(x:GetParent(), cb, "the X's frame in the button")
eq(x:GetFrameLevel(), cb:GetFrameLevel() + 1, "over the disc's rim and the faded art")
check(not x._mouse, "no mouse: the click stays Blizzard's")
eq(#u.closeX, 2, "two bars")
eq(u.closeX[1]._width, R.CLOSE_X[1], "2 px")
eq(u.closeX[1]._height, R.CLOSE_X[2], "12 px")
near(u.closeX[1]._rotation, math.pi / 4, "one at 45 degrees")
near(u.closeX[2]._rotation, -math.pi / 4, "the other at -45")
local xc = u.closeX[1]._color
check(xc and xc[1] == gold[1] and xc[2] == gold[2] and xc[4] == R.CLOSE_REST, "gold, at CLOSE_REST")
eq(R.CLOSE_REST, 0.85, "0.85")
at(x, "CENTER", cb, "CENTER", 0, 0, "at rest: centred")
-- Feedback: our X only.
WoW.asBlizzard(function() cb._scripts.OnEnter(cb) end)
eq(u.closeX[1]._color[4], 1, "hover: full")
WoW.asBlizzard(function() cb._scripts.OnMouseDown(cb) end)
at(x, "CENTER", cb, "CENTER", 0, -1, "pressed: 1 px down")
eq(u.closeX[2]._color[4], 1, "still full")
WoW.asBlizzard(function() cb._scripts.OnMouseUp(cb) end)
at(x, "CENTER", cb, "CENTER", 0, 0, "released")
-- The accent changes: the X and the tab's glow follow (Theme.OnRefresh).
GUI._test.slash("look accent ice")
local ice = GUI.Suite.ACCENTS.ice
check(u.closeX[1]._color[1] == ice[1] and u.closeX[1]._color[4] == 1, "the X in ice, at its current strength")
check(hl1._gradient[2].r == ice[1] and hl1._gradient[2].a == R.TAB_GLOW, "the glow in ice")
GUI._test.slash("look accent gold")
check(u.closeX[1]._color[1] == gold[1], "and gold again")
-- A hover that ends while off: re-synced when on.
GUI._test.slash("skin merchant off")
for _, k in ipairs({ "_normal", "_pushed", "_disabled", "_highlight" }) do
    eq(cb[k]:GetAlpha(), 1, "off: its " .. k:sub(2) .. " art back")
end
check(not u.closeDisc:IsShown() and not x:IsShown(), "off: our disc and X hidden")
WoW.asBlizzard(function() cb._scripts.OnLeave(cb) end)
eq(u.closeX[1]._color[4], 1, "off: the leave is a no-op")
GUI._test.slash("look accent ice")
check(u.closeX[1]._color[1] == gold[1], "and an accent change paints nothing while off")
WoW.mouseOver[cb] = false
cb._buttonState = "PUSHED"
GUI._test.slash("skin merchant on")
eq(u.closeX[1]._color[4], R.CLOSE_REST, "on: the hover read back, gone")
check(u.closeX[1]._color[1] == ice[1], "the accent set while off")
at(x, "CENTER", cb, "CENTER", 0, -1, "and the press read back")
check(u.closeDisc:IsShown() and x:IsShown(), "our disc and X back")
cb._buttonState = nil
WoW.mouseOver[cb] = true
GUI._test.slash("look accent gold")
GUI._test.slash("skin merchant off")
GUI._test.slash("skin merchant on")
eq(u.closeX[1]._color[4], 1, "on with the mouse over it: full")
at(x, "CENTER", cb, "CENTER", 0, 0, "not pressed")
WoW.mouseOver[cb] = nil
WoW.asBlizzard(function() cb._scripts.OnLeave(cb) end)

-- The saved layout after a reload.
GUI = loadAddon({ db = { merchantLayout = "sections" } })
WoW.showMerchant()
eq(GUI.Merchant.Layout(), "sections", "a saved sections survives a reload")
check(GUI.Merchant._test.ui[MerchantFrame].inset.fill:IsShown(), "and is laid out")

-- The switch survives a reload.
GUI = loadAddon({ db = { skins = { merchant = false } } })
WoW.showMerchant()
eq(MerchantFrame.NineSlice:GetAlpha(), 1, "saved off: the window stays stock after a reload")
eq(GUI.Engine.Status("merchant"), "off", "and reads off")

eq(next(GUI.failures), nil, "no failures")
for k, v in pairs(GUI.failures) do io.write("    " .. k .. ": " .. v .. "\n") end
done("test_merchant")
