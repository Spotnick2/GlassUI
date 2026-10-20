-- Skin/Merchant.lua: the merchant window, the kit's window-shell pilot.
--
-- MerchantFrame is ButtonFrameTemplate (Mainline\MerchantFrame.xml on Forever,
-- wow-ui-source branch forever, 70374); always loaded, not protected
-- (SkinProbe W1.1).
--
-- Glass under the window and under each tab, and the stock shell art faded:
-- the border, background and top streaks, the item inset, the money and
-- currency boxes, the bottom border, the buyback backdrop, the tabs' art.
-- The title, close button, filter dropdown, page buttons and every text stay
-- stock.
--
-- Revisited (#80, #48, docs/MERCHANT.md; Codex consensus in round 2):
--   the window floor   a window opens over other UI, where clear's 0.35 let
--                      RestedXP's text read through: backing = "window"
--   the item rows      their slot and label plate faded, a glass row of ours
--                      under each (no backing: the window's is under it).
--                      Blizzard's red plate (can't use or afford,
--                      MerchantFrame.lua:369-404) is mirrored on our glass, the
--                      icon keeps its own red. An empty row (its ItemButton
--                      hidden) shows no glass.
--   the buyback slot   the same, but its button never hides: empty is its
--                      icon set to "" (MerchantFrame.lua:428-430)
--   the portrait disc  a LibGlass disc under the portrait, centred on its
--                      round mask (58 x 58, 2 px above the texture's centre,
--                      SharedUIPanelTemplates.xml:574-596): only a ring shows,
--                      as round GlassMiniMap's map
--
-- Fades, hooks on instances and our own frames only, so the skin is live:
-- off and on without a /reload. None of this window's 405 textures ignores
-- SetAlpha (SkinProbe W1.2, 70374). Blizzard shows and hides the bottom
-- border and the buyback backdrop per tab (MerchantFrame.lua:480-593), and
-- only recolours the plates and slots, never their alpha, so a fade holds; the
-- OnShow pass re-fades anyway.

local GUI = GlassUI
local API = GUI.API

-- Named art outside the template's parentKeys (MerchantFrame.xml:104-121, 496-522).
local INSETS = { "MerchantMoneyInset", "MerchantExtraCurrencyInset" }
local ART = { "MerchantMoneyBg", "MerchantExtraCurrencyBg", "MerchantFrameBottomLeftBorder", "BuybackBG" }
local TABS = { "MerchantFrameTab1", "MerchantFrameTab2" }
-- Each tab's glass, inside its art's footprint. To be tuned in game.
local TAB_INSETS = { 6, 2, 6, 6 }
-- 12 rows: 10 per merchant page, 12 on the buyback tab (MerchantFrame.lua:1-2).
local ROWS = 12
-- Each row's glass, around its icon and name (outward). To be tuned from MS.2's screenshots.
local ROW_INSETS = { -3, -3, -3, -3 }
-- The disc: ring width around the portrait's mask, and the mask's XML width.
local DISC_RING, MASK_WIDTH = 6, 58

local rows = setmetatable({}, { __mode = "k" })     -- row -> { glass, g, red, plate, button, icon }
local discs = setmetatable({}, { __mode = "k" })    -- window -> the portrait's disc

local function tbl(v) return type(v) == "table" and v or nil end

-- Blizzard's red on a plate, as our mirror's alpha: 0.35 at full red (1, 0,
-- 0), 0.175 at its dark red (0.5, 0, 0); nil for its greys.
local function redAlpha(r, g, b)
    r, g, b = API.Plain(r), API.Plain(g), API.Plain(b)
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return nil end
    if r > 0.4 and g < 0.1 and b < 0.1 then return 0.35 * math.min(1, r) end
    return nil
end

local function paintRed(s, r, g, b)
    local a = redAlpha(r, g, b)
    if a then s.red:SetColorTexture(1, 0, 0, a) end
    s.red:SetShown(a ~= nil)
end

-- Empty: the row's ItemButton hidden; the buyback slot's icon cleared.
local function iconEmpty(tex)
    tex = API.Plain(tex)
    return tex == nil or tex == ""
end

local function filled(s)
    if s.icon then
        local ok, tex = pcall(s.icon.GetTexture, s.icon)
        local okA, atlas = pcall(s.icon.GetAtlas, s.icon)
        return not ((not ok or iconEmpty(tex)) and (not okA or iconEmpty(atlas)))
    end
    local ok, shown = pcall(s.button.IsShown, s.button)
    return ok and API.Plain(shown) == true
end

-- Our row's glass and its red mirror; hooks on Blizzard's plate and button
-- instances, each gated.
local function installRow(kit, row, buyback)
    local name = API.Plain(row:GetName())
    local glass, g = kit:Panel(row, "small", ROW_INSETS, nil, { backing = false })
    -- Its rim at its own level, under the row's icon border and text (Apply makes it 10 up).
    if g and g.top then g.top:SetFrameLevel(glass:GetFrameLevel()) end
    local red = glass:CreateTexture(nil, "BACKGROUND", nil, -5)
    red:SetAllPoints(glass)
    if g and g.mask then red:AddMaskTexture(g.mask) end
    red:Hide()
    local s = { glass = glass, g = g, red = red, button = tbl(row.ItemButton) }
    rows[row] = s
    local function sync()
        if GUI.Engine.Active("merchant") then GUI.Engine.Run(kit.skin, "row", function() glass:SetShown(filled(s)) end) end
    end
    if buyback then
        local b = s.button
        s.icon = b and (tbl(b.icon) or tbl(b.Icon) or kit:Global(name .. "ItemButtonIconTexture"))
        if s.icon then
            hooksecurefunc(s.icon, "SetTexture", sync)
            hooksecurefunc(s.icon, "SetAtlas", sync)
        end
    else
        s.plate = kit:Global(name .. "NameFrame")
        if s.plate then
            hooksecurefunc(s.plate, "SetVertexColor", function(_, r, gg, b)
                if GUI.Engine.Active("merchant") then GUI.Engine.Run(kit.skin, "red", paintRed, s, r, gg, b) end
            end)
        end
        if s.button then
            s.button:HookScript("OnShow", sync)
            s.button:HookScript("OnHide", sync)
        end
    end
end

-- A row's touches, and our glass synced to what Blizzard shows now.
local function styleRow(kit, row)
    local s = rows[row]
    if not s then return end
    kit:Fade(tbl(row.SlotTexture))
    if s.plate then
        kit:Fade(s.plate)
        local ok, r, g, b = pcall(s.plate.GetVertexColor, s.plate)
        if ok then paintRed(s, r, g, b) end
    end
    s.glass:SetShown(filled(s))
end

local function eachRow(fn)
    for i = 1, ROWS do
        local row = tbl(rawget(_G, "MerchantItem" .. i))
        if row then fn(row, false) end
    end
    local bb = tbl(rawget(_G, "MerchantBuyBackItem"))
    if bb then fn(bb, true) end
end

-- The portrait's round mask, else the portrait (by key, else its global).
local function portrait(kit, frame)
    local pc = tbl(frame.PortraitContainer)
    local around = pc and (tbl(pc.CircleMask) or tbl(pc.portrait)) or kit:Global("MerchantFramePortrait")
    return around, pc
end

GUI.Engine.Register({
    key = "merchant",
    title = "Merchant",
    risk = "plain",
    live = true,
    backing = "window",
    frames = function() return rawget(_G, "MerchantFrame") end,
    install = function(kit, frame)
        kit:Panel(frame)
        for _, name in ipairs(TABS) do
            local tab = kit:Global(name)
            if tab then kit:Panel(tab, "small", TAB_INSETS) end
        end
        for i = 1, ROWS do
            local row = kit:Global("MerchantItem" .. i)
            if row then installRow(kit, row, false) end
        end
        local bb = kit:Global("MerchantBuyBackItem")
        if bb then installRow(kit, bb, true) end
        -- Under the portrait (its container's level - 1): it covers the
        -- disc's centre. Over the window's glass and the rows'.
        local around, pc = portrait(kit, frame)
        if around then
            local level = (pc and pc:GetFrameLevel() or frame:GetFrameLevel()) - 1
            discs[frame] = kit:Disc(frame, around, { ring = DISC_RING, width = MASK_WIDTH, level = level })
        end
    end,
    style = function(kit, frame)
        kit:Shell(frame)
        for _, name in ipairs(INSETS) do kit:Inset(kit:Global(name)) end
        for _, name in ipairs(ART) do kit:Fade(kit:Global(name)) end
        for _, name in ipairs(TABS) do kit:Tab(kit:Global(name)) end
        eachRow(function(row) styleRow(kit, row) end)
    end,
})

GUI.Merchant = { _test = { rows = rows, discs = discs, redAlpha = redAlpha, ROW_INSETS = ROW_INSETS, DISC_RING = DISC_RING,
                           MASK_WIDTH = MASK_WIDTH } }
