-- The static popup skin: what it fades, what it leaves stock, our glass under
-- each of the four popups, reuse across dialogs, and its live switch (the
-- latest alpha Blizzard set comes back).
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local GUI = loadAddon()
local Engine = GUI.Engine
local function P(i) return _G["StaticPopup" .. i] end

local function faded(i)
    return { P(i).BG.Top, P(i).BG.Bottom }
end
local function stock(i)
    local f = P(i)
    local list = { f.Text, f.ConfirmText, f.SubText, f.AlertIcon, f.Separator, f.CloseButton, f.CoverFrame,
                   f.EditBox, f.EditBox.Instructions, f.MoneyFrame, f.MoneyInputFrame, f.ItemFrame,
                   f.ItemFrame.NameFrame, f.ItemFrame.Text, f.ItemFrame.Item, f.ItemFrame.Item.IconBorder,
                   f.DarkOverlay, f.ButtonContainer }
    for _, k in ipairs({ "TopLeftCorner", "TopEdge", "Center" }) do list[#list + 1] = f.EditBox.NineSlice[k] end
    for _, c in ipairs({ "gold", "silver", "copper" }) do
        for _, k in ipairs({ "Left", "Middle", "Right" }) do list[#list + 1] = f.MoneyInputFrame[c][k] end
    end
    for _, b in ipairs({ f.ButtonContainer.Buttons[1], f.ButtonContainer.Buttons[2], f.ButtonContainer.Buttons[3],
                         f.ButtonContainer.Buttons[4], f.ExtraButton }) do
        list[#list + 1] = b; list[#list + 1] = b.Text
        for _, k in ipairs(WoW.POPUP_BUTTON_ART) do list[#list + 1] = b._art[k] end
    end
    return list
end
local function all(list, alpha, msg)
    local bad = 0
    for _, r in ipairs(list) do if r:GetAlpha() ~= alpha then bad = bad + 1 end end
    eq(bad, 0, msg .. " (" .. #list .. " regions)")
end
local function ours(parent)
    local list = {}
    for _, c in ipairs(parent._children) do if not rawget(c, "_blizz") then list[#list + 1] = c end end
    return list
end

eq(Engine.Status("popups"), "on", "the popup skin is on by default")
for i = 1, 4 do all(faded(i), 1, "popup " .. i .. ": nothing is touched before it first shows") end
eq(#ours(P(1)), 0, "and no panel is built yet")

-- The first dialog: a plain one on popup 1.
WoW.showPopup(1, "DELETE_ITEM")
all(faded(1), 0, "popup 1: the border and the dark body are faded")
all(stock(1), 1, "popup 1: buttons, edit box, money, item frame, texts and icons stay stock")
all(faded(2), 1, "popup 2, never shown, is untouched")
local panels = ours(P(1))
eq(#panels, 1, "one glass panel under the popup")
eq(panels[1]:GetFrameLevel(), 0, "one level below the popup (level 1)")
check(panels[1]._name == nil and not panels[1]:IsMouseEnabled(), "unnamed, mouse off")
eq(#ours(P(2)), 0, "nothing built under a popup that hasn't shown")

-- Two at once: the second popup gets its own glass.
WoW.showPopup(2, "ADD_IGNORE", { editBox = true })
all(faded(2), 0, "popup 2: faded at its first show")
all(stock(2), 1, "popup 2: its edit box stays stock")
eq(#ours(P(2)), 1, "popup 2 has its own panel")

-- Reuse: popup 1 hidden, then shown for another dialog with other parts.
WoW.hidePopup(1)
WoW.showPopup(1, "PICKUP_MONEY", { money = true })
all(faded(1), 0, "reused for a money dialog: still faded")
all(stock(1), 1, "and its money input stays stock")
WoW.hidePopup(1)
WoW.showPopup(1, "CONFIRM_PURCHASE_TOKEN_ITEM", { item = true })
all(stock(1), 1, "an item dialog: the item frame stays stock")
eq(#ours(P(1)), 1, "a reused popup builds nothing new")

-- Blizzard at work: an alpha set while faded is held at 0.
WoW.asBlizzard(function() P(1).BG.Bottom:SetAlpha(0.6) end)
eq(P(1).BG.Bottom:GetAlpha(), 0, "an alpha Blizzard sets while faded is held at 0")

-- Raised in combat: plain, so styled at once, not held for combat's end.
WoW.combat = true
WoW.showPopup(3, "DELETE_ITEM")
all(faded(3), 0, "a popup raised in combat is faded at once")
eq(#ours(P(3)), 1, "with its glass")
WoW.combat = false
WoW.hidePopup(3)

-- Live off: Blizzard's latest alpha back, our glass hidden, no /reload needed.
WoW.chat = {}
GUI._test.slash("skin popups off")
check(not table.concat(WoW.chat, "\n"):find("/reload", 1, true), "off is live: no /reload asked")
eq(P(1).BG.Bottom:GetAlpha(), 0.6, "the alpha Blizzard set while the skin was on comes back")
eq(P(1).BG.Top:GetAlpha(), 1, "the border comes back")
all(faded(2), 1, "on every popup that was styled")
check(not panels[1]:IsShown() and not ours(P(2))[1]:IsShown(), "our panels hide")
eq(GlassUIDB.skins.popups, false, "the switch is saved")
WoW.hidePopup(2)
WoW.showPopup(2, "DELETE_ITEM")
eq(P(2).BG.Top:GetAlpha(), 1, "while off, a show touches nothing")

-- Live on, with popups open: styled at once.
GUI._test.slash("skin popups on")
all(faded(1), 0, "on again: popup 1 faded at once")
all(faded(2), 0, "and popup 2")
check(panels[1]:IsShown(), "our panel shows again")
eq(GlassUIDB.skins.popups, nil, "on is the default: nothing saved")

-- A popup first shown while the skin was off is built when it next shows.
GUI._test.slash("skin popups off")
WoW.showPopup(4, "DELETE_ITEM")
eq(#ours(P(4)), 0, "off: a first show builds nothing")
WoW.hidePopup(4)
GUI._test.slash("skin popups on")
WoW.showPopup(4, "DELETE_ITEM")
all(faded(4), 0, "on: popup 4 is faded at its next show")
eq(#ours(P(4)), 1, "and gets its glass")

-- The master switch, both ways; the merchant's switch leaves the popups alone.
GUI._test.slash("off")
eq(P(1).BG.Bottom:GetAlpha(), 0.6, "master off: the latest alpha back")
eq(Engine.Status("popups"), "off", "master off: the skin reads off")
GUI._test.slash("on")
eq(P(1).BG.Bottom:GetAlpha(), 0, "master on: faded again")
GUI._test.slash("skin merchant off")
eq(P(1).BG.Top:GetAlpha(), 0, "another skin's switch doesn't touch the popups")
GUI._test.slash("skin merchant on")

-- Our glass follows the theme.
local S = GUI.Theme._test.surfaces
eq(#S, 4, "the four popups' surfaces are registered with the theme (the merchant never showed)")
GUI._test.slash("theme smoked")
local dense = 0
for _, s in ipairs(S) do if s.backing._color[4] == GUI.Theme.PRESETS.smoked.backing then dense = dense + 1 end end
eq(dense, #S, "every surface, the popups' included, is repainted with the theme")
GUI._test.slash("theme clear")

-- The switch survives a reload.
GUI = loadAddon({ db = { skins = { popups = false } } })
WoW.showPopup(1, "DELETE_ITEM")
eq(P(1).BG.Top:GetAlpha(), 1, "saved off: the popup stays stock after a reload")
eq(GUI.Engine.Status("popups"), "off", "and reads off")

-- A client without the popups: the skin records why and leaves the rest alone.
GUI = loadAddon({ noPopups = true })
check(GUI.failures["skin:popups:frames"], "no popups: recorded as a failure of this skin")
eq(GUI.Engine.Status("merchant"), "on", "the merchant skin is unaffected")
GUI = loadAddon()

eq(next(GUI.failures), nil, "no failures")
for k, v in pairs(GUI.failures) do io.write("    " .. k .. ": " .. v .. "\n") end
done("test_popup")
