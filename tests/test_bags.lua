-- The bags skin (#88, docs/BAGS.md): the windows in the merchant's recipe
-- (the kit's window pieces), the money and search panes, the sort button,
-- each item slot a glass well with its empty pattern dimmed, the item use
-- path untouched, live off and on, and the bag replacements it steps aside for.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local GUI = loadAddon()
local Engine = GUI.Engine
local Kit = GUI.Kit
local B = GUI.Bags._test

-- Our frames under a Blizzard frame: its children the stub didn't mark as Blizzard's.
local function ours(parent)
    local list = {}
    for _, c in ipairs(parent._children) do if not rawget(c, "_blizz") then list[#list + 1] = c end end
    return list
end
local function at(frame, point, rel, relPoint, x, y, msg)
    local a
    for _, pt in ipairs(frame._points) do if pt[1] == point then a = pt end end
    check(a and a[2] == rel and a[3] == relPoint and a[4] == x and a[5] == y,
          msg .. ": " .. point .. " " .. tostring(a and a[4]) .. "," .. tostring(a and a[5]))
end
local function on(sec) return sec ~= nil and sec.fill:IsShown() and sec.edges[1]:IsShown() end

local CF1, C = ContainerFrame1, ContainerFrameCombinedBags
eq(Engine.Status("bags"), "on", "the bags skin is on by default")
eq(#ours(CF1), 0, "nothing built before a bag first opens")
eq(CF1.NineSlice:GetAlpha(), 1, "nothing faded either")

-- The backpack opens: three slots, two empty.
WoW.openBag(CF1, { "empty", 133784, "empty" })
local h = B.wins[CF1]
check(h ~= nil, "the window's pieces are built at its first open")

-- The shell.
eq(CF1.NineSlice:GetAlpha(), 0, "the NineSlice faded")
eq(CF1.Bg:GetAlpha(), 0, "the flat background faded (a frame: its four pieces with it)")
eq(CF1.PortraitContainer.portrait:GetAlpha(), 1, "the portrait stays")
eq(CF1.TitleContainer.TitleText:GetAlpha(), 1, "the title stays")

-- The window glass: the floor.
local win = h.win
eq(win:GetParent(), CF1, "our glass in the window")
eq(win:GetFrameLevel(), CF1:GetFrameLevel() - 1, "under it")
local S = GUI.Theme._test and GUI.Theme._test.surfaces
eq(h.backing._color[4], GUI.Theme.WINDOW_BACKING, "the window floor (0.93)")

-- The header band: the kit's, from the window's top down HEADER_H.
eq(B.HEADER_H, 26, "26 to start, tuned in game")
local hd = h.header
check(hd and hd:IsShown(), "the header shown")
eq(hd._layer, "BACKGROUND", "on the backing's layer")
eq(hd._sub, -7, "its sublevel")
at(hd, "TOPLEFT", win, "TOPLEFT", 0, 0, "from the window's top")
at(hd, "BOTTOM", win, "TOP", 0, -26, "down the band")
at(h.backing, "TOP", win, "TOP", 0, -26, "the backing from there")
at(h.backing, "BOTTOM", win, "BOTTOM", 0, 0, "to the bottom")
local g = hd._gradient
local _, _, _, ba = GUI.Theme.Backing("window")
check(g and g[2].a == ba and g[3].a == Kit.HEADER_TOP, "joined at the backing's alpha, smoky at the top")
check(GUI.Bags.SetHeaderHeight(32), "the band tuned live")
at(hd, "BOTTOM", win, "TOP", 0, -32, "the header follows")
at(h.backing, "TOP", win, "TOP", 0, -32, "and the backing")
eq(GUI.Bags.HeaderHeight(), 32, "read back")
eq(GUI.Bags.SetHeaderHeight(-1), false, "a negative band refused")
eq(GUI.Bags.SetHeaderHeight("x"), false, "a non-number refused")
GUI.Bags.SetHeaderHeight(26)

-- The portrait's disc and the close button (the kit's).
local disc = h.disc
check(disc ~= nil, "a disc behind the portrait")
eq(disc:GetWidth(), 62 + 2 * B.DISC_RING, "round the 62 px mask, a ring each side")
at(disc, "CENTER", CF1.PortraitContainer.CircleMask, "CENTER", 0, 0, "centred on the mask")
eq(disc:GetFrameLevel(), CF1.PortraitContainer:GetFrameLevel() - 1, "under the portrait")
local cb = CF1.CloseButton
for _, k in ipairs({ "_normal", "_pushed", "_disabled", "_highlight" }) do
    eq(cb[k]:GetAlpha(), 0, "the close button's " .. k:sub(2) .. " art faded")
end
check(h.closeDisc and h.closeDisc:GetParent() == cb, "its glass disc")
local gold = GUI.Suite.ACCENTS.gold
check(h.closeX[1]._color[1] == gold[1] and h.closeX[1]._color[4] == Kit.CLOSE_REST, "the gold X at rest")
WoW.asBlizzard(function() cb._scripts.OnEnter(cb) end)
eq(h.closeX[1]._color[4], 1, "hover: full")
WoW.asBlizzard(function() cb._scripts.OnLeave(cb) end)
GUI._test.slash("look accent ice")
check(h.closeX[1]._color[1] == GUI.Suite.ACCENTS.ice[1], "the accent followed (the kit's tracked windows)")
GUI._test.slash("look accent gold")

-- The money box: a pane on Blizzard's coin box, its pieces faded.
local M1 = ContainerFrame1MoneyFrame
for _, k in ipairs({ "Left", "Middle", "Right" }) do eq(M1.Border[k]:GetAlpha(), 0, "the coin box's " .. k .. " faded") end
check(on(h.money), "the money pane shown")
eq(h.money.fill:GetParent(), win, "on the window glass's host")
eq(h.money.fill._points[1][1], "ALL", "on the coin box")
eq(h.money.fill._points[1][2], M1.Border, "Blizzard's own box")
WoW.asBlizzard(function() M1:Hide() end)
check(not h.money.fill:IsShown(), "the money frame hidden: the pane with it")
WoW.asBlizzard(function() M1:Show() end)
check(on(h.money), "and back")

-- The search box and the sort button, shared: ours are their children.
for _, k in ipairs({ "Left", "Middle", "Right" }) do eq(BagItemSearchBox[k]:GetAlpha(), 0, "the search box's " .. k .. " faded") end
local host = B.shared.searchHost
eq(host:GetParent(), BagItemSearchBox, "the search pane's frame in the box: it follows Blizzard's moves")
eq(host:GetFrameLevel(), BagItemSearchBox:GetFrameLevel() - 1, "one under the box: never over its text")
check(on(B.shared.search), "the pane shown")
eq(B.shared.sort:GetParent(), BagItemAutoSortButton, "the sort button's glass in it")
eq(B.shared.sort:GetFrameLevel(), BagItemAutoSortButton:GetFrameLevel() - 1, "under it")

-- The slots: a glass well each, the rim faded, an empty slot's pattern dimmed.
local pool = WoW.bagButtons[CF1]
eq(#pool, 3, "three buttons")
for i, b in ipairs(pool) do
    local s = B.slots[b]
    check(s ~= nil, "slot " .. i .. ": glass of ours")
    eq(s.glass:GetParent(), b, "slot " .. i .. ": in the button (the pool hides it with it)")
    eq(s.glass:GetFrameLevel(), b:GetFrameLevel() - 1, "slot " .. i .. ": under it")
    eq(s.g.top:GetFrameLevel(), s.glass:GetFrameLevel(), "slot " .. i .. ": its rim under the icon and border")
    eq(b._normal:GetAlpha(), 0, "slot " .. i .. ": the quick-slot rim faded")
    eq(b.IconBorder:GetAlpha(), 1, "slot " .. i .. ": the quality border Blizzard's")
    eq(b.Count:GetAlpha(), 1, "slot " .. i .. ": the count Blizzard's")
    eq(b.NewItemTexture:GetAlpha(), 1, "slot " .. i .. ": the new-item glow left to its animation")
end
eq(pool[1].icon:GetAlpha(), 0, "empty: the wing pattern dimmed, the well shows")
eq(pool[2].icon:GetAlpha(), 1, "an item: its icon")
eq(pool[3].icon:GetAlpha(), 0, "the other empty one too")
-- An item arrives, one leaves (BAG_UPDATE).
WoW.bagUpdate(CF1, { 134400, "empty", "empty" })
eq(pool[1].icon:GetAlpha(), 1, "filled: Blizzard's alpha back")
eq(pool[2].icon:GetAlpha(), 0, "emptied: dimmed")
-- Blizzard setting the icon's alpha while dimmed (ItemButtonMixin:SetAlpha): held, remembered.
WoW.asBlizzard(function() pool[2].icon:SetAlpha(0.8) end)
eq(pool[2].icon:GetAlpha(), 0, "held while empty")
WoW.bagUpdate(CF1, { 134400, 133784, "empty" })
eq(pool[2].icon:GetAlpha(), 0.8, "filled again: Blizzard's latest alpha, not a forced 1")
-- The icon set outside UpdateItems (its own hooks).
WoW.asBlizzard(function() pool[3].icon:SetTexture(135000) end)
eq(pool[3].icon:GetAlpha(), 1, "an icon set on its own: followed")
WoW.asBlizzard(function() pool[3].icon:SetAtlas("bags-item-slot64") end)
eq(pool[3].icon:GetAlpha(), 0, "and emptied on its own")
WoW.asBlizzard(function() pool[3].icon:SetAtlas("some-item-atlas") end)
eq(pool[3].icon:GetAlpha(), 1, "an item given as an atlas is no empty slot: only the button's own empty atlas is")
WoW.asBlizzard(function() pool[3].icon:SetAtlas("bags-item-slot64") end)
-- Pooled buttons come back: one glass each, ever.
local panels = #ours(pool[1])
WoW.bagUpdate(CF1, { 134400 })
WoW.bagUpdate(CF1, { 134400, "empty", "empty", "empty" })
eq(#ours(pool[1]), panels, "a reused button: no second glass")
eq(#pool, 4, "a new button acquired")
check(B.slots[pool[4]] ~= nil, "and given its glass")
eq(pool[4].icon:GetAlpha(), 0, "empty: dimmed")
-- A button's own state never written: no field, no ID, no script of ours.
eq(rawget(pool[1], "glass"), nil, "no field of ours on the button")

-- The combined window: its own money frame; each button's slot background faded.
WoW.openBag(C, { 133784, "empty" })
local hc = B.wins[C]
check(hc and on(hc.money), "the combined window's money pane")
eq(hc.money.fill._points[1][2], C.MoneyFrame.Border, "on its own coin box")
local cpool = WoW.bagButtons[C]
for i, b in ipairs(cpool) do
    eq(b.ItemSlotBackground:GetAlpha(), 0, "combined slot " .. i .. ": its slot background faded")
end
eq(cpool[2].icon:GetAlpha(), 0, "combined: the empty slot dimmed")

-- A window without a money frame: no pane.
WoW.openBag(ContainerFrame2, { "empty" })
eq(B.wins[ContainerFrame2].money, nil, "a bag without money: no money pane")

-- Off: Blizzard's look back, everything of ours hidden; its updates meanwhile touch nothing of ours.
GUI._test.slash("skin bags off")
eq(CF1.NineSlice:GetAlpha(), 1, "off: the NineSlice back")
eq(cb._normal:GetAlpha(), 1, "the close art back")
eq(M1.Border.Left:GetAlpha(), 1, "the coin box back")
eq(BagItemSearchBox.Left:GetAlpha(), 1, "the search box back")
eq(pool[2].icon:GetAlpha(), 0.8, "an empty slot's pattern back, at Blizzard's latest alpha")
eq(pool[3].icon:GetAlpha(), 1, "another at 1")
eq(pool[1]._normal:GetAlpha(), 1, "the rims back")
check(not win:IsShown() and not B.slots[pool[1]].glass:IsShown(), "our glass hidden")
check(not B.shared.searchHost:IsShown() and not h.closeFrame:IsShown(), "the search pane and the close X too")
GUI._test.slash("look accent ice")
eq(h.closeX[1]._color[1], gold[1], "off: an accent change paints nothing of ours")
WoW.bagUpdate(CF1, { "empty", "empty", 133784, "empty" })
eq(pool[1].icon:GetAlpha(), 1, "off: a slot emptied meanwhile is not dimmed")
GUI._test.slash("skin bags on")
eq(CF1.NineSlice:GetAlpha(), 0, "on again: faded")
eq(pool[1].icon:GetAlpha(), 0, "the slots re-synced: empty dimmed")
eq(pool[3].icon:GetAlpha(), 1, "filled shown")
eq(pool[1]._normal:GetAlpha(), 0, "the rims faded")
check(win:IsShown() and B.slots[pool[1]].glass:IsShown(), "our glass back")
eq(h.closeX[1]._color[1], GUI.Suite.ACCENTS.ice[1], "the accent set while off, on the X")
GUI._test.slash("look accent gold")

eq(next(GUI.failures), nil, "no failures")
for k, v in pairs(GUI.failures) do io.write("    " .. k .. ": " .. v .. "\n") end

-- A bag replacement loaded: Glass UI steps aside.
for _, owner in ipairs({ "Bagnon", "Baganator", "AdiBags", "ArkInventory", "BetterBags", "EllesmereUIBags" }) do
    GUI = loadAddon({ before = function() WoW.loaded[owner] = true end })
    WoW.openBag(ContainerFrame1, { "empty" })
    eq(ContainerFrame1.NineSlice:GetAlpha(), 1, owner .. " loaded: the bags left alone")
    eq(GUI.Engine.Status("bags"), "handled by " .. owner, owner .. ": the status says who")
end

done("test_bags")
