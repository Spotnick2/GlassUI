-- The trade skin (#113, docs/TRADE.md): the window styled a frame after its
-- show (never inside it), its shell, both halves, the divider, both discs
-- (the recipient's outside its layout frame, under the portrait), the insets'
-- panes on the window glass, each slot a well under the enchant glyph, the
-- recipient's red mirrored a frame after Blizzard's colour (cleared, read
-- again after the skin was off, unreadable cleared, a queued pass dropped),
-- Trade and Cancel on glass; untouched: the money row (forbidden), the
-- highlights, the names, the items; off and on; no field written.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local GUI = loadAddon()
local T = GUI.Trade._test
local TF = TradeFrame

local function slotOf(side, i) return T.slots[_G["Trade" .. side .. "Item" .. i]] end
local function contains(list, x)
    for _, v in ipairs(list) do if v == x then return true end end
    return false
end

eq(GUI.Engine.Status("trade"), "on", "the trade skin is on by default")

-- The first trade, in combat: nothing inside the show, all of it a frame later.
WoW.combat = true
WoW.trade()
eq(T.wins[TF], nil, "nothing built inside the show (the panel manager's secure delegate)")
eq(TF.NineSlice:GetAlpha(), 1, "nothing faded inside it")
WoW.flushTimers(0)
WoW.combat = false
local h = T.wins[TF]
check(h ~= nil, "built a frame later, in combat too")

-- The shell and the halves.
eq(TF.NineSlice:GetAlpha(), 0, "the NineSlice faded")
eq(TF.Bg:GetAlpha(), 0, "the Bg faded")
eq(TF.TopTileStreaks:GetAlpha(), 0, "the streaks faded")
eq(TF.Inset.Bg:GetAlpha(), 0, "the template's stray inset faded")
for _, n in ipairs(T.HALF_ART) do eq(_G[n]:GetAlpha(), 0, n .. " faded") end
for _, n in ipairs(T.INSETS) do
    eq(_G[n].Bg:GetAlpha(), 0, n .. "'s marble faded")
    eq(_G[n].NineSlice:GetAlpha(), 0, n .. "'s border faded")
end
eq(TradeRecipientMoneyBg:GetAlpha(), 0, "the recipient's money edge faded")
eq(TF.RecipientOverlay.portraitFrame:GetAlpha(), 0, "the recipient's ring faded")
eq(h.backing._color[4], GUI.Theme.WINDOW_BACKING, "the window floor")
local hp
for _, pt in ipairs(h.header._points) do if pt[1] == "BOTTOM" then hp = pt end end
check(hp and hp[2] == TradePlayerInputMoneyInset and hp[3] == "TOP", "the band down to the money row's inset")
check(h.header:IsShown(), "the band shown")
local bp
for _, pt in ipairs(h.backing._points) do if pt[1] == "TOP" then bp = pt end end
check(bp and bp[2] == TradePlayerInputMoneyInset, "the floor from there down")

-- The panes: on the window glass (under TradeFrame's own enchant captions),
-- one per inset, shown.
for _, n in ipairs(T.INSETS) do
    local sec = h.panes[n]
    check(sec ~= nil, n .. ": a pane")
    eq(sec.fill._parent, h.win, n .. ": on the window glass")
    eq(sec.fill._points[1][2], _G[n], n .. ": over its inset")
    check(sec.fill:IsShown(), n .. ": shown")
end
check(h.win:GetFrameLevel() < TF:GetFrameLevel(), "the window glass under the window's regions")

-- The divider.
check(h.separator ~= nil and h.separator:IsShown(), "our divider")
eq(h.separator._points[1][2], TradeRecipientLeftBorder, "along Blizzard's")
eq(h.separator._color[4], GUI.Kit.SECTION_EDGE, "the panes' edge")

-- The discs.
check(h.disc ~= nil, "the player's portrait on its disc")
local rd = h.recipientDisc
check(rd ~= nil, "the recipient's portrait on its disc")
eq(rd._parent, TF, "the recipient's disc is the window's child, out of RecipientOverlay's layout")
check(not contains(TF.RecipientOverlay._children, rd), "nothing of ours in the overlay")
eq(rd:GetFrameLevel(), 549, "just under the overlay (550)")
eq(h.recipientDiscGlass.top:GetFrameLevel(), 549, "its rim too")
eq(rd._points[1][2], TF.RecipientOverlay.portrait, "round the portrait")

-- The slots: 2 x 7 wells, at the slot's level - 1, mouse off.
local n = 0
for _ in pairs(T.slots) do n = n + 1 end
eq(n, 14, "fourteen wells")
for _, side in ipairs({ "Player", "Recipient" }) do
    for i = 1, 7 do
        local name = "Trade" .. side .. "Item" .. i
        local s = slotOf(side, i)
        local item, b = _G[name], _G[name .. "ItemButton"]
        eq(s.glass._parent, b, name .. ": the well is the button's child")
        eq(s.glass:GetFrameLevel(), item:GetFrameLevel() - 1, name .. ": under the slot frame (the glyph)")
        eq(s.g.top:GetFrameLevel(), s.glass:GetFrameLevel(), name .. ": its rim too")
        check(not s.glass._mouse, name .. ": mouse off")
        eq(item.SlotTexture:GetAlpha(), 0, name .. ": the socket faded")
        eq(_G[name .. "NameFrame"]:GetAlpha(), 0, name .. ": the plate faded")
        eq(b._normal:GetAlpha(), 0, name .. ": the slot frame faded")
        eq(b.icon:GetAlpha(), 1, name .. ": the icon untouched")
        eq(s.red ~= nil, side == "Recipient", name .. ": a red mirror on the recipient's side only")
    end
end
eq(TradePlayerItem7._glyph:GetAlpha(), 1, "the enchant slot's glyph kept")

-- The recipient's red: a frame after Blizzard's colour, never inside it.
local s3 = slotOf("Recipient", 3)
check(not s3.red:IsShown(), "no red while the slot is empty")
WoW.tradeOffer.Recipient[3] = { icon = 5500, usable = false }
WoW.tradeSlot("Recipient", 3)
check(not s3.red:IsShown(), "nothing inside Blizzard's SetVertexColor")
WoW.flushTimers(0)
check(s3.red:IsShown(), "a frame later: the red mirrored")
near(s3.red._color[4], T.RED * 0.9, "at the quiet red, by Blizzard's 0.9")
eq(TradeRecipientItem3ItemButton.icon._vertex[2], 0, "the icon keeps Blizzard's red")
WoW.tradeOffer.Recipient[3] = { icon = 5500, usable = true }
WoW.tradeSlot("Recipient", 3)
WoW.flushTimers(0)
check(not s3.red:IsShown(), "usable: cleared")
WoW.tradeOffer.Recipient[3] = { icon = 5500, usable = false }
WoW.tradeSlot("Recipient", 3)
WoW.flushTimers(0)
WoW.tradeOffer.Recipient[3] = nil
WoW.tradeSlot("Recipient", 3)
WoW.flushTimers(0)
check(not s3.red:IsShown(), "taken back: cleared")

-- A pass queued before a switch-off is dropped; the red read again when on.
WoW.tradeOffer.Recipient[3] = { icon = 5500, usable = false }
WoW.tradeSlot("Recipient", 3)
GUI._test.slash("skin trade off")
WoW.flushTimers(0)
check(not s3.red:IsShown(), "the queued pass dropped with the skin off")
eq(TF.NineSlice:GetAlpha(), 1, "off: the shell back")
eq(TradeRecipientMoneyBg:GetAlpha(), 0.6, "off: Blizzard's 0.6 on the money edge")
eq(TradeRecipientItemsInset.Bg:GetAlpha(), 0.1, "off: Blizzard's 0.1 on the items inset")
eq(TradeRecipientMoneyInset.Bg:GetAlpha(), 0, "off: Blizzard's 0 on the money inset")
eq(TradeFrameTradeButton.Left:GetAlpha(), 1, "off: Trade's art back")
check(not h.win:IsShown(), "off: our glass hidden")
GUI._test.slash("skin trade on")
WoW.flushTimers(0)
check(h.win:IsShown(), "on: our glass back")
eq(TF.NineSlice:GetAlpha(), 0, "on: the shell faded again")
check(s3.red:IsShown(), "on: the red read again from the plate")
-- Recoloured while off, then on: read again; nothing scheduled while off.
GUI._test.slash("skin trade off")
WoW.flushTimers(0)
WoW.tradeOffer.Recipient[3] = nil
WoW.tradeSlot("Recipient", 3)
eq(#WoW.timers, 0, "off: Blizzard's colour schedules nothing")
WoW.flushTimers(0)
GUI._test.slash("skin trade on")
WoW.flushTimers(0)
check(not s3.red:IsShown(), "cleared while off: on reads it white")

-- An unreadable colour (a secret value: a number that can't be compared)
-- clears the mirror; the icon still warns.
local SECRET = 0.95
local was = issecretvalue
issecretvalue = function(v) return v == SECRET end
WoW.tradeOffer.Recipient[3] = { icon = 5500, usable = false }
WoW.tradeSlot("Recipient", 3)
WoW.flushTimers(0)
check(s3.red:IsShown(), "(red first)")
WoW.asBlizzard(function() TradeRecipientItem3NameFrame:SetVertexColor(SECRET, 0, 0) end)
WoW.flushTimers(0)
check(not s3.red:IsShown(), "unreadable: cleared")
issecretvalue = was
WoW.tradeOffer.Recipient[3] = nil
WoW.tradeSlot("Recipient", 3)
WoW.flushTimers(0)

-- Trade and Cancel: their art faded through Blizzard's re-sets, our glass
-- and its rim at the button's level - 1, the glow white.
WoW.trade()
WoW.flushTimers(0)
for _, name in ipairs({ "TradeFrameTradeButton", "TradeFrameCancelButton" }) do
    local b = _G[name]
    for _, k in ipairs({ "Left", "Middle", "Right" }) do eq(b[k]:GetAlpha(), 0, name .. "." .. k .. " faded through its SetTexture") end
    local bg = T.buttons[b]
    check(bg ~= nil, name .. ": our glass")
    eq(bg.glass:GetFrameLevel(), b:GetFrameLevel() - 1, name .. ": under the button")
    eq(bg.g.top:GetFrameLevel(), b:GetFrameLevel() - 1, name .. ": its rim too")
    check(not bg.glass._mouse, name .. ": mouse off")
    local v = b._highlight._vertex
    check(v and v[1] == 1 and v[2] == 1 and v[3] == 1 and v[4] == T.HOVER, name .. ": the glow white")
end
eq(TradeFrameTradeButton.WarningIcon:GetAlpha(), 1, "the warning icon untouched")

-- The close button.
eq(TF.CloseButton._normal:GetAlpha(), 0, "the close button's red faded")
check(h.closeX ~= nil and h.closeLight ~= nil, "our X and its hover light")

-- Closed and opened again: the same pieces, nothing built twice.
local function ours(parent)
    local k = 0
    for _, c in ipairs(parent._children) do if not rawget(c, "_blizz") then k = k + 1 end end
    return k
end
local before, beforeB = ours(TF), ours(TradeFrameTradeButton)
WoW.closeTrade()
WoW.trade()
WoW.flushTimers(0)
eq(ours(TF), before, "reopened: nothing built again on the window")
eq(ours(TradeFrameTradeButton), beforeB, "nor on a button")
eq(T.wins[TF], h, "the same window record")

-- Untouched.
for _, n in ipairs({ "TradeHighlightPlayer", "TradeHighlightRecipient", "TradeHighlightPlayerEnchant",
                     "TradeHighlightRecipientEnchant" }) do
    eq(_G[n]:GetAlpha(), 1, n .. " untouched")
end
for _, n in ipairs({ "TradeFramePlayerNameText", "TradeFrameRecipientNameText", "TradeFramePlayerEnchantText",
                     "TradeFrameRecipientEnchantText" }) do
    eq(_G[n]:GetAlpha(), 1, n .. " untouched")
end
eq(TradeRecipientMoneyFrame:GetAlpha(), 1, "the recipient's money display untouched")
for _, n in ipairs({ "TradeFramePlayerNameText", "TradeFrameRecipientNameText", "TradeFramePlayerEnchantText",
                     "TradeFrameRecipientEnchantText", "TradePlayerItem1Name", "TradeRecipientItem1Name" }) do
    check(not contains(WoW.textColorCalls, _G[n]), n .. ": its colour Blizzard's")
end
eq(#WoW.luaCalls, 0, "no Blizzard Lua method called")
eq(next(GUI.failures), nil, "no failures")
for k, v in pairs(GUI.failures) do io.write("    " .. k .. ": " .. v .. "\n") end
eq(table.concat(WoW.fieldChanges(), ","), "", "no field written on a Blizzard object")
WoW.closeTrade()

-- Without a trade window on this build: nothing, no error.
GUI = loadAddon({ noTrade = true })
eq(GUI.Engine.Status("trade") ~= nil, true, "the skin still registered")

done("test_trade")
