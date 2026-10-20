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
-- (SetLayout); the owner's pick is a setting (#86, the bar by default). Either
-- way the tabs hang from under the window (TAB_TUCK), the active one with the
-- stock tab's warm gradient, the header above the item inset is smoky glass
-- joined to the item area's floor, and the close button is a glass disc with
-- a gold X over Blizzard's faded red art (#86).
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
-- The layouts (#84): a setting since #86 (GlassUIDB.merchantLayout, the bar
-- by default: the owner), the probe's unsaved override over it.
local LAYOUTS = { sections = true, bar = true }
local LAYOUT_DEFAULT = "bar"
local override
-- The red mirror at full red (#86): one quiet peak in both layouts, a
-- charcoal card with a burgundy undertone. Run 2 showed sections' 0.35 as
-- solid red cards; the icon's own red tint carries the warning.
local RED = 0.12
-- The header (#86): the window's backing starts at the item inset's top, and
-- above it a gradient of ours in the same colour, from the backing's own
-- alpha at the inset line up to HEADER_TOP: smoky glass joined to the item
-- area. Off (the probe), the backing covers the whole window.
local headerOn = true
local HEADER_TOP = 0.45
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
-- The active tab: the stock tab's warm gradient (the owner, run 2: "what's
-- missing is the original gradient from the stock ui"), the accent at
-- TAB_GLOW at its bottom to 0 at its top; the inactive one darker (#86).
local TAB_GLOW, TAB_DIM = 0.3, 0.25
-- The close button's X: two bars, its strength at rest (1 on hover).
local CLOSE_X, CLOSE_REST = { 2, 12 }, 0.85
-- Its four state textures, the X baked into each (SharedUIPanelTemplates.xml:134-140).
local CLOSE_ART = { "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }

local rows = setmetatable({}, { __mode = "k" })     -- row -> { glass, g, red, plate, button, icon }
local discs = setmetatable({}, { __mode = "k" })    -- window -> the portrait's disc
local ui = setmetatable({}, { __mode = "k" })       -- window -> our layout's pieces

local function tbl(v) return type(v) == "table" and v or nil end

-- Blizzard's red on a plate, as our mirror's alpha: `peak` (RED by
-- default) at full red (1, 0, 0), half that at its dark red (0.5, 0, 0);
-- nil for its greys.
local function redAlpha(r, g, b, peak)
    r, g, b = API.Plain(r), API.Plain(g), API.Plain(b)
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return nil end
    if r > 0.4 and g < 0.1 and b < 0.1 then return (peak or RED) * math.min(1, r) end
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
-- The saved layout, read when used (the DB loads after this file).
local function saved()
    local db = rawget(_G, "GlassUIDB")
    local v = type(db) == "table" and db.merchantLayout or nil
    return LAYOUTS[v] and v or LAYOUT_DEFAULT
end

local function current() return override or saved() end

local function accent() return GUI.Suite.Accent() or { 1, 0.82, 0 } end

-- The window's backing (ours): from the item inset's top down, the header's
-- gradient above it joined at the backing's own RGBA (Theme.Backing: smoked's
-- 0.92 too); or the backing all of it. A gradient ignores SetAlpha here
-- (LibGlass #47): painted through its colours only.
local function header(u)
    local b = u.backing
    if not b then return end
    b:ClearAllPoints()
    local on = headerOn and u.insetFrame ~= nil and u.header ~= nil
    if on then
        b:SetPoint("TOP", u.insetFrame, "TOP", 0, 0)
        b:SetPoint("LEFT", u.win, "LEFT", 0, 0)
        b:SetPoint("RIGHT", u.win, "RIGHT", 0, 0)
        b:SetPoint("BOTTOM", u.win, "BOTTOM", 0, 0)
        local r, g, bl, a = GUI.Theme.Backing("window")
        u.header:SetGradient("VERTICAL", CreateColor(r, g, bl, a), CreateColor(r, g, bl, HEADER_TOP))
    else
        b:SetAllPoints(u.win)
    end
    if u.header then u.header:SetShown(on) end
end

-- The accent's pieces: the active tab's glow, the close button's X (at its
-- current strength).
local function paintAccent(u)
    local c = accent()
    for _, glow in pairs(u.tabs) do
        glow:SetGradient("VERTICAL", CreateColor(c[1], c[2], c[3], TAB_GLOW), CreateColor(c[1], c[2], c[3], 0))
    end
    for _, t in ipairs(u.closeX or {}) do t:SetColorTexture(c[1], c[2], c[3], u.closeAlpha) end
end

-- The close button's feedback, on our X only: full on hover, 1 px down while
-- pressed.
local function closeFeedback(u, hover, pushed)
    if not u.closeFrame then return end
    u.hover, u.pushed = hover, pushed
    u.closeAlpha = hover and 1 or CLOSE_REST
    u.closeFrame:ClearAllPoints()
    u.closeFrame:SetPoint("CENTER", u.close, "CENTER", 0, pushed and -1 or 0)
    paintAccent(u)
end

-- From the button's getters: a hover or press that ended while we were off.
local function closeSync(u)
    if not u.close then return end
    local okM, over = pcall(u.close.IsMouseOver, u.close)
    local okS, state = pcall(u.close.GetButtonState, u.close)
    closeFeedback(u, okM and API.Plain(over) == true, okS and API.Plain(state) == "PUSHED")
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
    local bar = current() == "bar"
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
        u.empty:SetShown(shown(u.frame) and not merchantTab and buybackCount() == 0)
    end
    for tab, glow in pairs(u.tabs) do
        local active = shown(tbl(tab.MiddleActive))
        glow:SetShown(active)
        if u.dims[tab] then u.dims[tab]:SetShown(not active) end
    end
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
local function buildLayout(kit, frame, win, wg, backing, tabGlass)
    local u = { frame = frame, tabs = {}, dims = {}, win = win, backing = backing, tabGlass = tabGlass,
                closeAlpha = CLOSE_REST }
    ui[frame] = u
    u.bb = kit:Global("MerchantBuyBackItem")
    u.band = kit:Global("MerchantFrameBottomLeftBorder")
    u.moneyInset, u.currencyInset = kit:Global("MerchantMoneyInset"), kit:Global("MerchantExtraCurrencyInset")
    local inset = tbl(frame.Inset)
    u.insetFrame = inset
    -- The header: on the backing's layer, under the tint and wash, clipped by
    -- the window glass's mask, adjoining the backing at the inset's top.
    if backing and inset then
        local h = win:CreateTexture(nil, "BACKGROUND", nil, -7)
        h:SetPoint("TOPLEFT", win, "TOPLEFT", 0, 0)
        h:SetPoint("RIGHT", win, "RIGHT", 0, 0)
        h:SetPoint("BOTTOM", inset, "TOP", 0, 0)
        h:SetColorTexture(1, 1, 1, 1)
        if wg and wg.mask then h:AddMaskTexture(wg.mask) end
        h:Hide()
        u.header = h
    end
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
        local glow = t.glass:CreateTexture(nil, "ARTWORK")
        glow:SetAllPoints(t.glass)
        glow:SetColorTexture(1, 1, 1, 1)
        local dim = t.glass:CreateTexture(nil, "ARTWORK")
        dim:SetAllPoints(t.glass)
        dim:SetColorTexture(0, 0, 0, TAB_DIM)
        if t.g and t.g.mask then
            glow:AddMaskTexture(t.g.mask)
            dim:AddMaskTexture(t.g.mask)
        end
        glow:Hide()
        dim:Hide()
        u.tabs[tab], u.dims[tab] = glow, dim
        -- PanelTemplates_SelectTab / DeselectTab show and hide it (SharedUIPanelTemplates.lua:611-651).
        local active = tbl(tab.MiddleActive)
        if active then
            hooksecurefunc(active, "Show", relay)
            hooksecurefunc(active, "Hide", relay)
        end
    end
    -- The close button: a glass disc of ours under it (unsliced, clean at
    -- 24 px), our X over it on a frame of ours one up (a plain frame takes no
    -- mouse: the click stays Blizzard's), feedback by gated HookScript on the
    -- instance.
    local close = tbl(frame.CloseButton)
    if close then
        u.close = close
        local level = close:GetFrameLevel()
        local okW, w = pcall(close.GetWidth, close)
        w = okW and API.Plain(w) or nil
        if type(w) ~= "number" or w <= 0 then w = 24 end
        u.closeDisc = kit:Disc(close, close, { ring = 0, width = w, level = level - 1 })
        local x = kit:Adopt(CreateFrame("Frame", nil, close))
        x:SetSize(w, w)
        x:SetFrameLevel(level + 1)
        u.closeX = {}
        for i, rot in ipairs({ math.pi / 4, -math.pi / 4 }) do
            local t = x:CreateTexture(nil, "OVERLAY")
            t:SetSize(CLOSE_X[1], CLOSE_X[2])
            t:SetPoint("CENTER", x, "CENTER", 0, 0)
            t:SetRotation(rot)
            u.closeX[i] = t
        end
        u.closeFrame = x
        local function feedback(hover, pushed)
            if GUI.Engine.Active("merchant") then
                GUI.Engine.Run(kit.skin, "close", closeFeedback, u, hover, pushed)
            end
        end
        close:HookScript("OnEnter", function() feedback(true, u.pushed) end)
        close:HookScript("OnLeave", function() feedback(false, false) end)
        close:HookScript("OnMouseDown", function() feedback(u.hover, true) end)
        close:HookScript("OnMouseUp", function() feedback(u.hover, false) end)
        closeFeedback(u, false, false)
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
        local win, wg, backing = kit:Panel(frame)
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
        buildLayout(kit, frame, win, wg, backing, tabGlass)
    end,
    style = function(kit, frame)
        kit:Shell(frame)
        for _, name in ipairs(INSETS) do kit:Inset(kit:Global(name)) end
        for _, name in ipairs(ART) do kit:Fade(kit:Global(name)) end
        for _, name in ipairs(TABS) do kit:Tab(kit:Global(name)) end
        local close = tbl(frame.CloseButton)
        if close then
            for _, get in ipairs(CLOSE_ART) do
                local ok, tex = pcall(close[get], close)
                if ok then kit:Fade(tex) end
            end
        end
        eachRow(function(row) styleRow(kit, row) end)
        local u = ui[frame]
        if u then
            tuck(u)
            closeSync(u)
            layout(u)
        end
    end,
})

GUI.Merchant = {}

-- The layout shown: the probe's override, else the saved one.
function GUI.Merchant.Layout() return current() end

-- The saved layout (the settings page's and the slash's).
function GUI.Merchant.Saved() return saved() end

-- The probe's live switch (#84): a known layout, or nil to drop back to the
-- saved one; applied now when the skin is on. Not saved.
function GUI.Merchant.SetLayout(name)
    if name ~= nil and not LAYOUTS[name] then return false end
    override = name
    if GUI.Engine.Active("merchant") then API.Try("merchant:layout", layoutAll) end
    return true
end

-- The setting (#86): one setter for the page and the slash. Saved sparsely
-- (the default is nil), applied when the skin is on, the page redrawn either way.
function GUI.Merchant.SetSaved(name)
    if not LAYOUTS[name] then return false end
    local db = rawget(_G, "GlassUIDB")
    if type(db) ~= "table" then return false end
    if name == LAYOUT_DEFAULT then db.merchantLayout = nil else db.merchantLayout = name end
    if GUI.Engine.Active("merchant") then API.Try("merchant:layout", layoutAll) end
    if GUI.Options and GUI.Options.Refresh then GUI.Options.Refresh() end
    return true
end

function GUI.Merchant.Header() return headerOn end

-- The probe's live switch: the smoky header, or the backing whole. Not saved.
function GUI.Merchant.SetHeader(on)
    headerOn = on and true or false
    if GUI.Engine.Active("merchant") then API.Try("merchant:header", layoutAll) end
    return true
end

-- A tint, an accent or a floor changed (Theme.Refresh): the header and the
-- accent's pieces follow; while off, the style pass repaints them.
GUI.Theme.OnRefresh(function()
    if not GUI.Engine.Active("merchant") then return end
    for _, u in pairs(ui) do
        header(u)
        paintAccent(u)
    end
end)

GUI.Merchant._test = { rows = rows, discs = discs, ui = ui, redAlpha = redAlpha, ROW_INSETS = ROW_INSETS,
                       DISC_RING = DISC_RING, MASK_WIDTH = MASK_WIDTH, RED = RED, BOX_LEFT = BOX_LEFT,
                       BOX_RIGHT = BOX_RIGHT, BAR_TOPLEFT = BAR_TOPLEFT, SQUARE_OUTSET = SQUARE_OUTSET,
                       ICON_OUTSET = ICON_OUTSET, TAB_GLOW = TAB_GLOW, TAB_DIM = TAB_DIM, EMPTY_TITLE = EMPTY_TITLE,
                       EMPTY_TEXT = EMPTY_TEXT, BUYBACK_ICON = BUYBACK_ICON,
                       TAB_TUCK = TAB_TUCK, HEADER_TOP = HEADER_TOP, CLOSE_X = CLOSE_X,
                       CLOSE_REST = CLOSE_REST, LAYOUT_DEFAULT = LAYOUT_DEFAULT }
