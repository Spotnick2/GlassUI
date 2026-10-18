-- Skin/Popup.lua: the static popups, StaticPopup1..4.
--
-- Blizzard_StaticPopup_Game\GameDialog.xml (wow-ui-source branch forever,
-- 70450): StaticPopupTemplate over DefaultDialogPanelTemplate, which has no
-- NineSlice. Its art is the BG frame's two textures, given their atlases once
-- at OnLoad (GameDialog.lua:24-28) and never touched again: BG.Top, the
-- diamond-metal border ("UI-DiamondDialogBox-Border"), and BG.Bottom, the dark
-- body inside it. Always loaded, not protected (SkinProbe W1.1). The four
-- frames are the whole set: StaticPopup_Show reuses them, never makes more
-- (StaticPopup.lua, StaticPopup_AddDialog).
--
-- Glass under each popup, and those two faded. Shell only: the buttons keep
-- Blizzard's red dialog art and the edit box its dark field, so what can be
-- clicked or typed into still reads as such; the item frame, money frames,
-- alert icon, close button, cover and every text stay stock too.
--
-- Fades only, so the skin is live: off and on without a /reload. None of the
-- popups' textures ignores SetAlpha (SkinProbe W1.2: 680 on 70374, re-measured
-- on 70450 by /fp steps skin popup). A popup is reused for every dialog, so
-- each OnShow re-fades; the fade holds anyway.
--
-- Plain, not deferred: the popup isn't protected, its OnShow runs our hook as
-- its own handler, and we only fade textures and show our own frame
-- (Ellesmere skins it from the same hook). The in-combat dialog is part of the
-- acceptance.

local GUI = GlassUI

local POPUPS = { "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4" }

GUI.Engine.Register({
    key = "popups",
    title = "Popups",
    risk = "plain",
    live = true,
    frames = function()
        local list = {}
        for _, name in ipairs(POPUPS) do list[#list + 1] = rawget(_G, name) end
        return unpack(list)
    end,
    install = function(kit, frame)
        kit:Panel(frame)
    end,
    style = function(kit, frame)
        local bg = kit:Child(frame, "BG")
        if not bg then return end
        kit:Fade(kit:Child(bg, "Top"))
        kit:Fade(kit:Child(bg, "Bottom"))
    end,
})
