-- Skin/Merchant.lua: the merchant window, the kit's window-shell pilot.
--
-- MerchantFrame is ButtonFrameTemplate (Mainline\MerchantFrame.xml on Forever,
-- wow-ui-source branch forever, 70374); always loaded, not protected
-- (SkinProbe W1.1).
--
-- Glass under the window and under each tab, and the stock shell art faded:
-- the border, background and top streaks, the item inset, the money and
-- currency boxes, the bottom border, the buyback backdrop, the tabs' art.
-- Shell only: the item rows keep their slots and name plates, which Blizzard
-- tints red for an item the player can't use or afford
-- (MerchantFrame.lua:370-395). The portrait, title, close button, filter
-- dropdown, page buttons and every text stay stock.
--
-- Fades only, so the skin is live: off and on without a /reload. None of this
-- window's 405 textures ignores SetAlpha (SkinProbe W1.2, 70374). Blizzard
-- shows and hides the bottom border and the buyback backdrop per tab
-- (MerchantFrame.lua:480-593) and never sets their alpha, so a fade holds; the
-- OnShow pass re-fades anyway.

local GUI = GlassUI

-- Named art outside the template's parentKeys (MerchantFrame.xml:104-121, 496-522).
local INSETS = { "MerchantMoneyInset", "MerchantExtraCurrencyInset" }
local ART = { "MerchantMoneyBg", "MerchantExtraCurrencyBg", "MerchantFrameBottomLeftBorder", "BuybackBG" }
local TABS = { "MerchantFrameTab1", "MerchantFrameTab2" }
-- Each tab's glass, inside its art's footprint. To be tuned in game.
local TAB_INSETS = { 6, 2, 6, 6 }

GUI.Engine.Register({
    key = "merchant",
    title = "Merchant",
    risk = "plain",
    live = true,
    frames = function() return rawget(_G, "MerchantFrame") end,
    install = function(kit, frame)
        kit:Panel(frame)
        for _, name in ipairs(TABS) do
            local tab = kit:Global(name)
            if tab then kit:Panel(tab, "small", TAB_INSETS) end
        end
    end,
    style = function(kit, frame)
        kit:Shell(frame)
        for _, name in ipairs(INSETS) do kit:Inset(kit:Global(name)) end
        for _, name in ipairs(ART) do kit:Fade(kit:Global(name)) end
        for _, name in ipairs(TABS) do kit:Tab(kit:Global(name)) end
    end,
})
