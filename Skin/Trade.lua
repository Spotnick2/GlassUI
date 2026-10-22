-- Skin/Trade.lua: the trade window (#113, docs/TRADE.md), from the window
-- template (merchant #86 ... loot #105) and the owner's stock screenshot.
--
-- TradeFrame (Blizzard_UIPanels_Game, Mainline/TradeFrame.xml:179; forever
-- 70450) is an area-left UI panel: TRADE_SHOW -> ShowUIPanel through the
-- panel manager's secure delegate. So, as the map and the loot window: the
-- show is deferred a frame (defer = true) and every hook only schedules.
--
-- The money input is forbidden (TradeFrame.lua:21; every method but
-- IsForbidden throws): never touched, never anchored to, and the window's
-- children are never walked (GetChildren would return it). Every piece is
-- reached by its global or its key. The slots and the window take the drops
-- (ClickTradeButton, TradeFrame_OnMouseUp): no frame of ours takes the
-- mouse, and on an item button only alpha and children of ours.
--
-- The window glass on the floor, a smoky band down to the money row, both
-- portraits on discs, the item, enchant and money insets as recessed panes,
-- each slot a glass well, Trade and Cancel on glass, the close button on its
-- disc. Kept Blizzard's: the names, the money row and display, the items, the
-- recipient's red icon, the accept highlights, "Will not be traded", the
-- enchant slot's glyph, the warning icon.

local GUI = GlassUI
local API = GUI.API
local Kit = GUI.Kit

local SIDES = { "Player", "Recipient" }
local SLOTS = 7                                   -- MAX_TRADE_ITEMS (TradeFrame.lua:1)
-- Each inset (InsetFrameTemplate, useParentLevel): its art faded, a recessed
-- pane over it. Six share parentKey "LeftInset", so by their globals.
local INSETS = { "TradePlayerItemsInset", "TradeRecipientItemsInset", "TradePlayerEnchantInset",
                 "TradeRecipientEnchantInset", "TradePlayerInputMoneyInset", "TradeRecipientMoneyInset" }
-- The recipient half's lighter fill and its divider (TradeFrame.xml:183-202).
local HALF_ART = { "TradeRecipientBG", "TradeRecipientLeftBorder", "TradeRecipientBotLeftCorner" }
local BUTTONS = { "TradeFrameTradeButton", "TradeFrameCancelButton" }
local BUTTON_ART = { "Left", "Middle", "Right" }   -- UIPanelButtonTemplate's
local NO_INSETS = { 0, 0, 0, 0 }
-- The portraits' discs: the player's round its mask (the merchant's), the
-- recipient's round its 60 px portrait (TradeFrame.xml:243).
local DISC_RING, MASK_WIDTH, RECIPIENT_WIDTH = 6, 58, 60
-- Blizzard's additive button glow, white instead of gold (the game menu's).
local HOVER = 0.35
-- The recipient's red plate (can't use: 0.9, 0, 0, TradeFrame.lua:180)
-- mirrored on the well at the merchant's quiet red.
local RED = 0.12

local wins = setmetatable({}, { __mode = "k" })     -- window -> our pieces
local slots = setmetatable({}, { __mode = "k" })    -- slot frame -> { glass, g, red, plate, button }
local buttons = setmetatable({}, { __mode = "k" })  -- Trade/Cancel -> { glass, g }

local function tbl(v) return type(v) == "table" and v or nil end

-- The plate's red as our fill's alpha; nil for white or anything unreadable
-- (a secret value, another build): the icon's own red still says it.
local function redAlpha(r, g, b)
    r, g, b = API.Plain(r), API.Plain(g), API.Plain(b)
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return nil end
    if r > 0.4 and g < 0.1 and b < 0.1 then return RED * math.min(1, r) end
    return nil
end

local function paintRed(s)
    local ok, r, g, b = pcall(s.plate.GetVertexColor, s.plate)
    local a = ok and redAlpha(r, g, b) or nil
    if a then s.red:SetColorTexture(1, 0, 0, a) end
    s.red:SetShown(a ~= nil)
end

-- Our glass under a Blizzard frame at `level`, its rim there too (LibGlass
-- makes it 10 up, over the frame's own art). Mouse off: a plain frame.
local function glassAt(kit, frame, level)
    local glass, g = kit:Panel(frame, "small", NO_INSETS, nil, { backing = false })
    glass:SetFrameLevel(math.max(0, level))
    if g and g.top then g.top:SetFrameLevel(glass:GetFrameLevel()) end
    return glass, g
end

-- A slot (TradeItemTemplate, TradeFrame.xml:31): its well once, round the
-- item button but at the slot frame's level - 1, under the enchant glyph
-- (slot 7's ARTWORK on the slot frame) and the accept highlights. The
-- recipient's plate hook only schedules, then reads the latest colour.
local function installSlot(kit, side, i)
    local name = "Trade" .. side .. "Item" .. i
    local item, button = kit:Global(name), kit:Global(name .. "ItemButton")
    if not (item and button) then return end
    local glass, g = glassAt(kit, button, item:GetFrameLevel() - 1)
    local s = { glass = glass, g = g, button = button, item = item, plate = tbl(rawget(_G, name .. "NameFrame")) }
    slots[item] = s
    if side == "Recipient" and s.plate then
        local red = glass:CreateTexture(nil, "BACKGROUND", nil, -5)
        red:SetAllPoints(glass)
        if g and g.mask then red:AddMaskTexture(g.mask) end
        red:Hide()
        s.red = red
        hooksecurefunc(s.plate, "SetVertexColor", function()
            if GUI.Engine.Active("trade") then GUI.Engine.Defer(kit.skin, "red", function() paintRed(s) end) end
        end)
    end
end

local function styleSlot(kit, s)
    kit:Fade(tbl(s.item.SlotTexture))
    kit:Fade(s.plate)
    local ok, normal = pcall(s.button.GetNormalTexture, s.button)
    if ok then kit:Fade(tbl(normal)) end
    if s.red then paintRed(s) end
end

local function eachSlot(fn)
    for _, side in ipairs(SIDES) do
        for i = 1, SLOTS do
            local s = slots[tbl(rawget(_G, "Trade" .. side .. "Item" .. i)) or false]
            if s then fn(s) end
        end
    end
end

local function installButton(kit, b)
    local glass, g = glassAt(kit, b, b:GetFrameLevel() - 1)
    buttons[b] = { glass = glass, g = g }
end

local function styleButton(kit, b)
    for _, key in ipairs(BUTTON_ART) do kit:Fade(kit:Child(b, key)) end
    local ok, hl = pcall(b.GetHighlightTexture, b)
    if ok and tbl(hl) then kit:Tint(hl, 1, 1, 1, HOVER) end
end

GUI.Engine.Register({
    key = "trade",
    title = "Trade",
    risk = "plain",
    defer = true,
    live = true,
    backing = "window",
    frames = function() return rawget(_G, "TradeFrame") end,
    install = function(kit, frame)
        local win, wg, backing = kit:Panel(frame)
        local h = { kit = kit, frame = frame }
        wins[frame] = h
        -- The band down to the money row's inset (a sibling of the forbidden
        -- input, never the input itself): the names and portraits in it.
        local moneyInset = tbl(rawget(_G, "TradePlayerInputMoneyInset"))
        kit:Header(win, wg, backing, moneyInset or win, "TOP", moneyInset and 0 or -58, h)
        h.disc = kit:PortraitDisc(frame, { ring = DISC_RING, width = MASK_WIDTH, global = "TradeFramePortrait" })
        -- The recipient's portrait sits on RecipientOverlay (level 550, a
        -- ResizeLayoutFrame that sizes to its shown children): our disc is
        -- the window's child, anchored to the portrait, just under the overlay.
        local overlay = tbl(frame.RecipientOverlay)
        local portrait = overlay and tbl(overlay.portrait)
        if portrait then
            h.recipientDisc, h.recipientDiscGlass = kit:Disc(frame, portrait,
                { ring = DISC_RING, width = RECIPIENT_WIDTH, level = overlay:GetFrameLevel() - 1 })
        end
        kit:CloseButton(tbl(frame.CloseButton), h)
        -- The panes on the window glass itself: over its body, under every
        -- Blizzard region (the enchant captions are TradeFrame's own ARTWORK).
        h.panes = {}
        for _, name in ipairs(INSETS) do
            local inset = kit:Global(name)
            if inset then
                local sec = kit:Section(win)
                sec.fill:SetAllPoints(inset)
                Kit.ShowSection(sec, true)
                h.panes[name] = sec
            end
        end
        -- Our divider along Blizzard's (faded), the character window's separator.
        local border = tbl(rawget(_G, "TradeRecipientLeftBorder"))
        if border then
            local line = win:CreateTexture(nil, "ARTWORK", nil, 2)
            line:SetColorTexture(1, 1, 1, Kit.SECTION_EDGE)
            line:SetPoint("TOP", border, "TOP", 0, 0)
            line:SetPoint("BOTTOM", border, "BOTTOM", 0, 0)
            line:SetWidth(1)
            h.separator = line
        end
        for _, side in ipairs(SIDES) do
            for i = 1, SLOTS do installSlot(kit, side, i) end
        end
        for _, name in ipairs(BUTTONS) do
            local b = kit:Global(name)
            if b then installButton(kit, b) end
        end
    end,
    style = function(kit, frame)
        kit:Shell(frame)
        kit:CloseFades(tbl(frame.CloseButton))
        for _, name in ipairs(HALF_ART) do kit:Fade(kit:Global(name)) end
        for _, name in ipairs(INSETS) do kit:Inset(tbl(rawget(_G, name))) end
        -- Its 0.6 (TradeFrame.lua:20) is Blizzard's latest alpha: Restore gives it back.
        kit:Fade(kit:Global("TradeRecipientMoneyBg"))
        local overlay = tbl(frame.RecipientOverlay)
        if overlay then kit:Fade(tbl(overlay.portraitFrame)) end
        eachSlot(function(s) styleSlot(kit, s) end)
        for b in pairs(buttons) do styleButton(kit, b) end
        local h = wins[frame]
        if h then
            Kit.PlaceHeader(h)
            Kit.CloseSync(h)
        end
    end,
})

GUI.Trade = { _test = { wins = wins, slots = slots, buttons = buttons, INSETS = INSETS, HALF_ART = HALF_ART,
                        RED = RED, HOVER = HOVER, DISC_RING = DISC_RING } }
