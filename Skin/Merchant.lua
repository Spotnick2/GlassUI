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
-- The layout (#84, docs/MERCHANT.md section 4): Blizzard's structure the
-- fades took away, given back as recessed sections of ours on the window
-- glass ("sections", the default: the item inset, the bottom band's two
-- boxes, the money and currency boxes), or the owner's mockup ("bar": one
-- footer bar, the buyback slot in a square with a label while empty, an empty
-- state on the Buyback tab, less red). The probe switches them live
-- (SetLayout) until the owner picks. Either way the active tab is marked,
-- the tabs hang from under the window (TAB_TUCK), and the header above the
-- item inset is clear Pearl (SetHeader; ML run 1's ideas).
--
-- Fades, hooks on instances and our own frames only, so the skin is live:
-- off and on without a /reload. None of this window's 405 textures ignores
-- SetAlpha (SkinProbe W1.2, 70374). Blizzard shows and hides the bottom
-- border and the buyback backdrop per tab (MerchantFrame.lua:480-593), and
-- only recolours the plates and slots, never their alpha, so a fade holds; the
-- OnShow pass re-fades anyway.

local GUI = GlassUI
local API = GUI.API
local Kit = GUI.Kit

-- Named art outside the template's parentKeys (MerchantFrame.xml:104-121, 496-522).
local INSETS = { "MerchantMoneyInset", "MerchantExtraCurrencyInset" }
local ART = { "MerchantMoneyBg", "MerchantExtraCurrencyBg", "MerchantFrameBottomLeftBorder", "BuybackBG" }
local TABS = { "MerchantFrameTab1", "MerchantFrameTab2" }
-- Each tab's glass, inside its art's footprint, its top tucked TAB_TUCK
-- under the window: in the strata below the window's, its top and corners
-- hide behind the window's floor, so the tab hangs from the window like
-- Blizzard's instead of floating under it (the owner, ML run 1: "they feel
-- disconnected"). The tab's top is 1 px into the window (CENTER at
-- BOTTOMLEFT 50, -15, height 32: MerchantFrame.xml:585, the template's 932).
local TAB_TUCK = 12
local TAB_INSETS = { 6, -TAB_TUCK, 6, 6 }
local STRATA = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }
-- 12 rows: 10 per merchant page, 12 on the buyback tab (MerchantFrame.lua:1-2).
local ROWS = 12
-- Each row's glass, around its icon and name (outward). To be tuned from MS.2's screenshots.
local ROW_INSETS = { -3, -3, -3, -3 }
-- The disc: ring width around the portrait's mask, and the mask's XML width.
local DISC_RING, MASK_WIDTH = 6, 58
-- The layouts (#84), and each one's red at full red: Blizzard's plate in
-- sections, much less in the bar, where the icon's own red tint carries it.
local LAYOUTS = { sections = true, bar = true }
local RED = { sections = 0.35, bar = 0.12 }
local layoutName = "sections"
-- The header (the owner, ML run 1): the window's backing starts at the item
-- inset's top, so above it (the portrait, the title) is clear Pearl glass,
-- like the portrait's disc; off, the backing covers the whole window.
local headerPearl = true
-- The bottom band's two boxes, inside MerchantFrameBottomLeftBorder (334 x 61),
-- { left, top, right, bottom } inward. Read off MS run 1's skin-off
-- screenshot (70450); to be tuned.
local BOX_LEFT, BOX_RIGHT = { 5, 12, 139, 1 }, { 199, 12, 5, 1 }
-- The bar's top-left inside the band, on the Merchant tab.
local BAR_TOPLEFT = { 5, 12 }
-- The buyback square round its ItemButton, and the empty state's icon (the
-- Buyback tab's own portrait, MerchantFrame.lua:533).
local SQUARE_OUTSET, ICON_OUTSET = 3, 4
local BUYBACK_ICON = "Interface\\MerchantFrame\\UI-BuyBack-Icon"
local EMPTY_TITLE, EMPTY_TEXT = "No items to buy back", "Items you sell will appear here."
-- The active tab's light, over its glass (0.10 didn't show, ML run 1).
local TAB_ACTIVE = 0.2

local rows = setmetatable({}, { __mode = "k" })     -- row -> { glass, g, red, plate, button, icon }
local discs = setmetatable({}, { __mode = "k" })    -- window -> the portrait's disc
local ui = setmetatable({}, { __mode = "k" })       -- window -> our layout's pieces

local function tbl(v) return type(v) == "table" and v or nil end

-- Blizzard's red on a plate, as our mirror's alpha: `peak` (0.35 by
-- default) at full red (1, 0, 0), half that at its dark red (0.5, 0, 0);
-- nil for its greys.
local function redAlpha(r, g, b, peak)
    r, g, b = API.Plain(r), API.Plain(g), API.Plain(b)
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return nil end
    if r > 0.4 and g < 0.1 and b < 0.1 then return (peak or RED.sections) * math.min(1, r) end
    return nil
end

local function paintRed(s, r, g, b)
    local a = redAlpha(r, g, b, RED[layoutName])
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

local function shown(f)
    if not f then return false end
    local ok, v = pcall(f.IsShown, f)
    return ok and API.Plain(v) == true
end

local function buybackCount()
    local ok, n = pcall(GetNumBuybackItems)
    n = ok and API.Plain(n) or nil
    return type(n) == "number" and n or nil
end

-- A section's fill from a's TOPLEFT to b's BOTTOMRIGHT, inward by insets
-- { left, top, right, bottom }. Ours: re-anchoring it touches nothing of
-- Blizzard's.
local function place(sec, a, b, ins)
    if not (sec and a) then return end
    ins = ins or { 0, 0, 0, 0 }
    sec.fill:ClearAllPoints()
    sec.fill:SetPoint("TOPLEFT", a, "TOPLEFT", ins[1], -ins[2])
    sec.fill:SetPoint("BOTTOMRIGHT", b or a, "BOTTOMRIGHT", -ins[3], ins[4])
end

-- What the layout shows now, from what Blizzard shows: MerchantBuyBackItem is
-- shown exactly while the Merchant tab is (MerchantFrame.lua:479, 590).
-- The window's backing (ours): from the item inset's top down, or all of it.
local function header(u)
    local b = u.backing
    if not b then return end
    b:ClearAllPoints()
    if headerPearl and u.insetFrame then
        b:SetPoint("TOP", u.insetFrame, "TOP", 0, 0)
        b:SetPoint("LEFT", u.win, "LEFT", 0, 0)
        b:SetPoint("RIGHT", u.win, "RIGHT", 0, 0)
        b:SetPoint("BOTTOM", u.win, "BOTTOM", 0, 0)
    else
        b:SetAllPoints(u.win)
    end
end

-- Each tab's glass in the strata below the window's (TAB_TUCK). A window in
-- the lowest strata keeps it level, over the window: not met on 70450
-- (MerchantFrame is a MEDIUM UI panel).
local function tuck(u)
    local ok, mine = pcall(u.frame.GetFrameStrata, u.frame)
    if not ok then return end
    local want = mine
    for i, name in ipairs(STRATA) do
        if name == mine then want = STRATA[math.max(1, i - 1)] end
    end
    for _, t in pairs(u.tabGlass) do
        t.glass:SetFrameStrata(want)
        if t.g and t.g.top then t.g.top:SetFrameStrata(want) end
    end
end

local function layout(u)
    local bar = layoutName == "bar"
    header(u)
    local merchantTab = shown(u.bb)
    Kit.ShowSection(u.inset, not bar)
    Kit.ShowSection(u.money, not bar)
    Kit.ShowSection(u.currency, not bar)
    Kit.ShowSection(u.boxLeft, not bar and merchantTab)
    Kit.ShowSection(u.boxRight, not bar and merchantTab)
    local canBar = u.band ~= nil and u.moneyInset ~= nil and u.currencyInset ~= nil
    if bar and canBar then
        if merchantTab then
            u.bar.fill:ClearAllPoints()
            u.bar.fill:SetPoint("TOPLEFT", u.band, "TOPLEFT", BAR_TOPLEFT[1], -BAR_TOPLEFT[2])
            u.bar.fill:SetPoint("BOTTOMRIGHT", u.moneyInset, "BOTTOMRIGHT", 0, 0)
        else
            -- Clear of rows 11-12, which sit where the band was.
            place(u.bar, u.currencyInset, u.moneyInset)
        end
    end
    Kit.ShowSection(u.bar, bar and canBar)
    if u.line then u.line:SetShown(bar) end
    if u.square then
        u.square.host:SetShown(bar)
        Kit.ShowSection(u.square, bar)
        local s = rows[u.bb]
        u.label:SetShown(bar and not (s ~= nil and filled(s)))
    end
    if u.empty then
        u.empty:SetShown(bar and shown(u.frame) and not merchantTab and buybackCount() == 0)
    end
    for tab, hl in pairs(u.tabs) do hl:SetShown(shown(tbl(tab.MiddleActive))) end
end

local function layoutAll()
    for _, u in pairs(ui) do layout(u) end
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
        if GUI.Engine.Active("merchant") then
            GUI.Engine.Run(kit.skin, "row", function()
                glass:SetShown(filled(s))
                -- The buyback label, and the empty state (the Buyback tab's
                -- first row shows or hides as its count leaves or reaches 0).
                layoutAll()
            end)
        end
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

-- Our layout's pieces (#84): sections on the window glass's host, the
-- buyback square and label on a frame of ours in MerchantBuyBackItem, the
-- empty state on one in the window, each tab's light; hooks gated.
local function buildLayout(kit, frame, win, backing, tabGlass)
    local u = { frame = frame, tabs = {}, win = win, backing = backing, tabGlass = tabGlass }
    ui[frame] = u
    u.bb = kit:Global("MerchantBuyBackItem")
    u.band = kit:Global("MerchantFrameBottomLeftBorder")
    u.moneyInset, u.currencyInset = kit:Global("MerchantMoneyInset"), kit:Global("MerchantExtraCurrencyInset")
    local inset = tbl(frame.Inset)
    u.insetFrame = inset
    local function section(a, b, ins)
        if not a then return nil end
        local sec = kit:Section(win)
        place(sec, a, b, ins)
        return sec
    end
    u.inset = section(inset)
    u.money = section(u.moneyInset)
    u.currency = section(u.currencyInset)
    u.boxLeft = section(u.band, nil, BOX_LEFT)
    u.boxRight = section(u.band, nil, BOX_RIGHT)
    u.bar = kit:Section(win)
    if inset then
        u.line = win:CreateTexture(nil, "ARTWORK", nil, 1)
        u.line:SetColorTexture(1, 1, 1, Kit.SECTION_EDGE)
        u.line:SetPoint("TOPLEFT", inset, "TOPLEFT", 0, 0)
        u.line:SetPoint("TOPRIGHT", inset, "TOPRIGHT", 0, 0)
        u.line:SetHeight(1)
        u.line:Hide()
    end
    local button = u.bb and tbl(u.bb.ItemButton)
    if button then
        -- At the slot's level: under its ItemButton (one up), hidden with it on the Buyback tab.
        local host = kit:Adopt(CreateFrame("Frame", nil, u.bb))
        host:SetAllPoints(u.bb)
        host:SetFrameLevel(u.bb:GetFrameLevel())
        u.square = kit:Section(host)
        u.square.host = host
        u.square.fill:SetPoint("TOPLEFT", button, "TOPLEFT", -SQUARE_OUTSET, SQUARE_OUTSET)
        u.square.fill:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", SQUARE_OUTSET, -SQUARE_OUTSET)
        u.label = host:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        u.label:SetPoint("LEFT", button, "RIGHT", 8, 0)
        local text = rawget(_G, "BUYBACK")
        u.label:SetText(type(text) == "string" and text or "Buyback")
        u.label:Hide()
        host:Hide()
    end
    -- Over the window's glass (one up), centred in the item inset; the rows
    -- it would cover are all hidden while it shows (no buyback item).
    local e = kit:Adopt(CreateFrame("Frame", nil, frame))
    e:SetSize(260, 130)
    e:SetPoint("CENTER", inset or frame, "CENTER", 0, 10)
    e:SetFrameLevel(frame:GetFrameLevel() + 1)
    local icon = e:CreateTexture(nil, "ARTWORK", nil, 2)
    icon:SetSize(40, 40)
    icon:SetPoint("TOP", e, "TOP", 0, 0)
    icon:SetTexture(BUYBACK_ICON)
    local box = kit:Section(e)
    box.fill:SetPoint("TOPLEFT", icon, "TOPLEFT", -ICON_OUTSET, ICON_OUTSET)
    box.fill:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", ICON_OUTSET, -ICON_OUTSET)
    Kit.ShowSection(box, true)
    local title = e:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", icon, "BOTTOM", 0, -12)
    title:SetText(EMPTY_TITLE)
    local sub = e:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    sub:SetPoint("TOP", title, "BOTTOM", 0, -6)
    sub:SetText(EMPTY_TEXT)
    e:Hide()
    u.empty, u.emptyTitle, u.emptyText, u.emptyIcon = e, title, sub, icon
    local function relay()
        if GUI.Engine.Active("merchant") then GUI.Engine.Run(kit.skin, "layout", layout, u) end
    end
    -- The tab switch: Blizzard shows the slot on the Merchant tab, hides it on Buyback.
    if u.bb then
        u.bb:HookScript("OnShow", relay)
        u.bb:HookScript("OnHide", relay)
    end
    for tab, t in pairs(tabGlass) do
        local hl = t.glass:CreateTexture(nil, "ARTWORK")
        hl:SetAllPoints(t.glass)
        hl:SetColorTexture(1, 1, 1, TAB_ACTIVE)
        if t.g and t.g.mask then hl:AddMaskTexture(t.g.mask) end
        hl:Hide()
        u.tabs[tab] = hl
        -- PanelTemplates_SelectTab / DeselectTab show and hide it (SharedUIPanelTemplates.lua:611-651).
        local active = tbl(tab.MiddleActive)
        if active then
            hooksecurefunc(active, "Show", relay)
            hooksecurefunc(active, "Hide", relay)
        end
    end
    return u
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
        local win, _, backing = kit:Panel(frame)
        local tabGlass = {}
        for _, name in ipairs(TABS) do
            local tab = kit:Global(name)
            if tab then
                local glass, g = kit:Panel(tab, "small", TAB_INSETS)
                tabGlass[tab] = { glass = glass, g = g }
            end
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
        buildLayout(kit, frame, win, backing, tabGlass)
    end,
    style = function(kit, frame)
        kit:Shell(frame)
        for _, name in ipairs(INSETS) do kit:Inset(kit:Global(name)) end
        for _, name in ipairs(ART) do kit:Fade(kit:Global(name)) end
        for _, name in ipairs(TABS) do kit:Tab(kit:Global(name)) end
        eachRow(function(row) styleRow(kit, row) end)
        if ui[frame] then
            tuck(ui[frame])
            layout(ui[frame])
        end
    end,
})

GUI.Merchant = {}

function GUI.Merchant.Layout() return layoutName end

-- The probe's live switch (#84): a known layout, its sections and red
-- repainted now when the skin is on. Not saved.
function GUI.Merchant.SetLayout(name)
    if not LAYOUTS[name] then return false end
    layoutName = name
    if GUI.Engine.Active("merchant") then
        API.Try("merchant:layout", function()
            for _, s in pairs(rows) do
                if s.plate then
                    local ok, r, g, b = pcall(s.plate.GetVertexColor, s.plate)
                    if ok then paintRed(s, r, g, b) end
                end
            end
            layoutAll()
        end)
    end
    return true
end

function GUI.Merchant.Header() return headerPearl end

-- The probe's live switch: the header clear Pearl, or the backing whole. Not saved.
function GUI.Merchant.SetHeader(on)
    headerPearl = on and true or false
    if GUI.Engine.Active("merchant") then API.Try("merchant:header", layoutAll) end
    return true
end

GUI.Merchant._test = { rows = rows, discs = discs, ui = ui, redAlpha = redAlpha, ROW_INSETS = ROW_INSETS,
                       DISC_RING = DISC_RING, MASK_WIDTH = MASK_WIDTH, RED = RED, BOX_LEFT = BOX_LEFT,
                       BOX_RIGHT = BOX_RIGHT, BAR_TOPLEFT = BAR_TOPLEFT, SQUARE_OUTSET = SQUARE_OUTSET,
                       ICON_OUTSET = ICON_OUTSET, TAB_ACTIVE = TAB_ACTIVE, EMPTY_TITLE = EMPTY_TITLE,
                       EMPTY_TEXT = EMPTY_TEXT, BUYBACK_ICON = BUYBACK_ICON,
                       TAB_TUCK = TAB_TUCK }
