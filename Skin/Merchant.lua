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
-- The layout (#84, #86; docs/MERCHANT.md sections 4-5): Blizzard's structure
-- the fades took away, given back as recessed sections of ours on the window
-- glass, each shown while Blizzard shows what it holds: the item inset, the
-- money box, the currency box (while Blizzard shows it), the bottom band's
-- right box (the buyback slot, Merchant tab) and its left box (while a repair
-- or sell-junk button shows). Nothing of Blizzard's moves. The tabs hang from
-- under the window (TAB_TUCK), the selected one lighter with an accent edge;
-- the header above the item inset is smoky glass joined to the item area's
-- floor; the close button is a glass disc with a gold X over Blizzard's faded
-- red art; the page and repair buttons sit on small glass, a disabled page
-- button's label dimmed (#86).
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
-- The red mirror at full red (#86): a charcoal card with a burgundy
-- undertone. Run 2 showed 0.35 as solid red cards; the icon's own red tint
-- carries the warning.
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
-- The empty state's icon (the Buyback tab's own portrait, MerchantFrame.lua:533)
-- in a section this far round it.
local ICON_OUTSET = 4
local BUYBACK_ICON = "Interface\\MerchantFrame\\UI-BuyBack-Icon"
local EMPTY_TITLE, EMPTY_TEXT = "No items to buy back", "Items you sell will appear here."
-- The selected tab (#86, the owner: "retains a recognizable Warcraft
-- selection accent while making the surface fit Pearl"): a lighter neutral
-- glass, TAB_LIGHT white, and a 1 px accent edge along its bottom at
-- TAB_EDGE, TAB_EDGE_INSET in from each side (clear of the rounded corners);
-- the other darker.
local TAB_LIGHT, TAB_EDGE, TAB_EDGE_INSET, TAB_DIM = 0.12, 0.8, 6, 0.25
-- The close button's X: two bars, its strength at rest (1 on hover).
local CLOSE_X, CLOSE_REST = { 2, 12 }, 0.85
-- Its four state textures, the X baked into each (SharedUIPanelTemplates.xml:134-140).
local CLOSE_ART = { "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }
-- The page buttons (MerchantFrame.xml:527-560): their gold-rimmed background
-- faded, our glass under them; a disabled one's label at PAGE_DIM.
local PAGES = { "MerchantPrevPageButton", "MerchantNextPageButton" }
local PAGE_DIM = 0.4
-- What sits in the band's left box (MerchantFrame.lua:482, 987-1020); the
-- repair buttons' slot faded, our glass behind them, as the rows'.
local REPAIRS = { "MerchantRepairAllButton", "MerchantRepairItemButton", "MerchantGuildBankRepairButton" }
local JUNK = "MerchantSellAllJunkButton"
-- Both on small glass round their own size (32 and 36 px: LibGlass's small
-- mask holds at 32, GLASS-MATERIAL.md).
local BUTTON_INSETS = { 0, 0, 0, 0 }

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

-- The accent's pieces: the selected tab's edge, the close button's X (at
-- its current strength).
local function paintAccent(u)
    local c = accent()
    for _, edge in pairs(u.edges) do edge:SetColorTexture(c[1], c[2], c[3], TAB_EDGE) end
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

-- The band's left box holds something: a repair or sell-junk button shown.
local function bandLeftUsed(u)
    for _, b in ipairs(u.bandButtons) do
        if shown(b) then return true end
    end
    return false
end

-- A disabled page button's label dimmed (on page 1, "Prev" no longer bright
-- gold beside a grey arrow); given back when enabled.
local function pages(u)
    for b, label in pairs(u.pageLabels) do
        local ok, on = pcall(b.IsEnabled, b)
        u.kit:Dim(label, not (ok and API.Plain(on) == true) and PAGE_DIM or nil)
    end
end

local function layout(u)
    header(u)
    local merchantTab = shown(u.bb)
    Kit.ShowSection(u.inset, true)
    Kit.ShowSection(u.money, true)
    Kit.ShowSection(u.currency, shown(u.currencyInset))
    Kit.ShowSection(u.boxLeft, merchantTab and bandLeftUsed(u))
    Kit.ShowSection(u.boxRight, merchantTab)
    if u.empty then
        u.empty:SetShown(shown(u.frame) and not merchantTab and buybackCount() == 0)
    end
    for tab, light in pairs(u.tabs) do
        local active = shown(tbl(tab.MiddleActive))
        light:SetShown(active)
        u.edges[tab]:SetShown(active)
        u.dims[tab]:SetShown(not active)
    end
    pages(u)
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
                -- The empty state (the Buyback tab's first row shows or
                -- hides as its count leaves or reaches 0).
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

-- A button's own region of a type, on its BACKGROUND layer for a texture (a
-- page button's gold-rimmed background, a repair button's slot), any for a
-- FontString (a page button's label): never the state textures.
local function regionOf(b, kind)
    local ok, regions = pcall(function() return { b:GetRegions() } end)
    if not ok then return nil end
    for _, r in ipairs(regions) do
        local okT, t = pcall(r.GetObjectType, r)
        if okT and API.Plain(t) == kind then
            if kind ~= "Texture" then return r end
            local okL, layer = pcall(r.GetDrawLayer, r)
            if okL and API.Plain(layer) == "BACKGROUND" then return r end
        end
    end
    return nil
end

-- Our layout's pieces (#84, #86): sections on the window glass's host, the
-- empty state on a frame in the window, each tab's light, edge and dim, the
-- close button's disc and X, the page and repair buttons' glass; hooks gated.
local function buildLayout(kit, frame, win, wg, backing, tabGlass)
    local u = { kit = kit, frame = frame, tabs = {}, edges = {}, dims = {}, win = win, backing = backing,
                tabGlass = tabGlass, closeAlpha = CLOSE_REST, bandButtons = {}, pageLabels = {} }
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
    -- The currency box: Blizzard shows its inset only with extra currencies
    -- (MerchantFrame_UpdateCurrencies, :1029-1039).
    if u.currencyInset then
        hooksecurefunc(u.currencyInset, "Show", relay)
        hooksecurefunc(u.currencyInset, "Hide", relay)
    end
    -- The band's left box: the repair buttons Show/Hide (:987-1020, the
    -- Buyback tab's :588-596), the junk button SetShown (:482), which never
    -- calls the Lua Show or Hide: hooked on its own.
    local names = {}
    for i, n in ipairs(REPAIRS) do names[i] = n end
    names[#names + 1] = JUNK
    for _, n in ipairs(names) do
        local b = kit:Global(n)
        if b then
            u.bandButtons[#u.bandButtons + 1] = b
            hooksecurefunc(b, "Show", relay)
            hooksecurefunc(b, "Hide", relay)
            hooksecurefunc(b, "SetShown", relay)
        end
    end
    -- The repair buttons on small glass, its rim at its own level (under the
    -- icon and state textures), as the rows'.
    u.repairs = {}
    for _, n in ipairs(REPAIRS) do
        local b = tbl(rawget(_G, n))
        if b then
            local glass, g = kit:Panel(b, "small", BUTTON_INSETS, nil, { backing = false })
            if g and g.top then g.top:SetFrameLevel(glass:GetFrameLevel()) end
            u.repairs[b] = glass
        end
    end
    -- The page buttons: glass the same way; the label dimmed while disabled
    -- (Blizzard's Enable/Disable, MerchantFrame.lua:441-458).
    for _, n in ipairs(PAGES) do
        local b = kit:Global(n)
        if b then
            local glass, g = kit:Panel(b, "small", BUTTON_INSETS, nil, { backing = false })
            if g and g.top then g.top:SetFrameLevel(glass:GetFrameLevel()) end
            local label = regionOf(b, "FontString")
            if label then u.pageLabels[b] = label end
            hooksecurefunc(b, "Enable", relay)
            hooksecurefunc(b, "Disable", relay)
        end
    end
    for tab, t in pairs(tabGlass) do
        local light = t.glass:CreateTexture(nil, "ARTWORK")
        light:SetAllPoints(t.glass)
        light:SetColorTexture(1, 1, 1, TAB_LIGHT)
        local edge = t.glass:CreateTexture(nil, "ARTWORK", nil, 1)
        edge:SetPoint("BOTTOMLEFT", t.glass, "BOTTOMLEFT", TAB_EDGE_INSET, 1)
        edge:SetPoint("BOTTOMRIGHT", t.glass, "BOTTOMRIGHT", -TAB_EDGE_INSET, 1)
        edge:SetHeight(1)
        local dim = t.glass:CreateTexture(nil, "ARTWORK")
        dim:SetAllPoints(t.glass)
        dim:SetColorTexture(0, 0, 0, TAB_DIM)
        if t.g and t.g.mask then
            light:AddMaskTexture(t.g.mask)
            edge:AddMaskTexture(t.g.mask)
            dim:AddMaskTexture(t.g.mask)
        end
        light:Hide()
        edge:Hide()
        dim:Hide()
        u.tabs[tab], u.edges[tab], u.dims[tab] = light, edge, dim
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
        for _, n in ipairs(PAGES) do
            local b = tbl(rawget(_G, n))
            if b then kit:Fade(regionOf(b, "Texture")) end
        end
        for _, n in ipairs(REPAIRS) do
            local b = tbl(rawget(_G, n))
            if b then kit:Fade(regionOf(b, "Texture")) end
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
                       BOX_RIGHT = BOX_RIGHT,
                       ICON_OUTSET = ICON_OUTSET, TAB_LIGHT = TAB_LIGHT, TAB_EDGE = TAB_EDGE,
                       TAB_EDGE_INSET = TAB_EDGE_INSET, TAB_DIM = TAB_DIM, EMPTY_TITLE = EMPTY_TITLE,
                       EMPTY_TEXT = EMPTY_TEXT, BUYBACK_ICON = BUYBACK_ICON,
                       TAB_TUCK = TAB_TUCK, HEADER_TOP = HEADER_TOP, CLOSE_X = CLOSE_X,
                       CLOSE_REST = CLOSE_REST, PAGE_DIM = PAGE_DIM, BUTTON_INSETS = BUTTON_INSETS }
