-- Skin/Map.lua: the world map and quest log (#99, docs/MAP.md), from the
-- window template (merchant #86 ... character #94) and the owner's mockup.
--
-- WorldMapFrame (Blizzard_WorldMap, Mainline with Camelot's templates;
-- wow-ui-source forever 70450): MEDIUM, frameBuffer="true", its BorderFrame
-- and the attached QuestMapFrame HIGH. The panel manager opens it, maximise
-- and minimise go through SetUIPanelAttribute, and the NavBar is an overlay
-- frame refreshed in secureexecuterange (Blizzard_WorldMap.lua:343, 438-466):
-- so nothing here styles inside those calls. The show is deferred a frame
-- (defer = true), and every hook only schedules (Engine.Defer).
--
-- The window glass on the floor under the canvas (W1.3), a smoky title band
-- down to the breadcrumb bar, the book's disc, the close, maximise and
-- minimise buttons on glass discs; the bar a recessed pane, its crumbs as
-- text on it; the quest log a recessed pane, its zone headers on glass bars
-- (the character lists' look, #94: the +/- in the accent, the text
-- Blizzard's), the search box and the quest count on glass pills.
--
-- Blizzard's: the canvas and its pins, every other overlay frame (one is a
-- secure action button), the overflow button (its art is its glyph), the
-- quest rows (difficulty colours, the tracking checkbox), the details pane
-- (its parchment carries the text), the scroll bar. Never a script on
-- QuestMapFrame, never a global hook, never a field on a row.

local GUI = GlassUI
local API = GUI.API
local Kit = GUI.Kit

-- The bar's own frame (WorldMapNavBarTemplate, Blizzard_WorldMapTemplates.xml
-- :94-121); its tile is an unnamed BACKGROUND texture (NavigationBar.xml:252).
local NAV_ART = { "InsetBorderBottomLeft", "InsetBorderBottomRight", "InsetBorderBottom", "InsetBorderLeft",
                  "InsetBorderRight" }
-- InputBoxVisualTemplate's three pieces (the search box, the quest count).
local BOX_ART = { "Left", "Right", "Middle" }
local PILL_INSETS = { -5, 0, 0, 0 }
local HEADER_INSETS = { 0, 0, 0, 0 }

local wins = setmetatable({}, { __mode = "k" })     -- the window -> our pieces
local headers = setmetatable({}, { __mode = "k" })  -- a pooled zone header -> { glass, g }
local pills = setmetatable({}, { __mode = "k" })    -- the search box, the count -> { glass, g }

local function tbl(v) return type(v) == "table" and v or nil end
local function accent() return GUI.Suite.Accent() or { 1, 0.82, 0 } end

-- A frame's own regions of a type (never its children).
local function regionsOf(f, kind, layer)
    local out = {}
    local ok, regions = pcall(function() return { f:GetRegions() } end)
    if not ok then return out end
    for _, r in ipairs(regions) do
        local okT, t = pcall(r.GetObjectType, r)
        if okT and API.Plain(t) == kind then
            local okL, l = pcall(r.GetDrawLayer, r)
            if not layer or (okL and API.Plain(l) == layer) then out[#out + 1] = r end
        end
    end
    return out
end

local function questLog()
    local qsf = tbl(rawget(_G, "QuestScrollFrame"))
    local qmf = tbl(rawget(_G, "QuestMapFrame"))
    return qsf, qmf and tbl(qmf.QuestsFrame)
end

-- A zone header (ListHeaderVisualTemplate, ListTemplates.xml:22-43): a
-- ButtonText and a CollapseButton with an Icon; the covenant callings' header
-- inherits it and adds a SelectedHighlight (QuestMapFrame.xml:88). Campaign
-- headers use Text; titles, objectives, POI buttons don't match.
local function isHeader(row)
    local cb = tbl(row.CollapseButton)
    return tbl(row.ButtonText) ~= nil and cb ~= nil and tbl(cb.Icon) ~= nil and not tbl(row.SelectedHighlight)
end

-- Every header among the list's rows (the pools parent them to Contents,
-- QuestMapFrame.lua:1226-1237): a glass bar once (parented to the row, so
-- it never joins the layout), its bar faded, its glow white, its +/- in the
-- accent. The text stays Blizzard's (grey, white on hover).
local function styleHeaders(kit)
    local qsf = questLog()
    local contents = qsf and tbl(qsf.Contents)
    if not contents then return end
    local c = accent()
    for _, row in ipairs({ contents:GetChildren() }) do
        if isHeader(row) then
            if not headers[row] then
                local glass, g = kit:Panel(row, "small", HEADER_INSETS, nil, { backing = false })
                if g and g.top then g.top:SetFrameLevel(glass:GetFrameLevel()) end
                headers[row] = { glass = glass, g = g }
            end
            local okN, normal = pcall(row.GetNormalTexture, row)
            if okN then kit:Fade(tbl(normal)) end
            local okH, glow = pcall(row.GetHighlightTexture, row)
            if okH then kit:Tint(tbl(glow), 1, 1, 1) end
            kit:Tint(row.CollapseButton.Icon, c[1], c[2], c[3])
        end
    end
end

-- The bar's art and its crumbs' state textures (home and the pooled crumbs,
-- by their keys, NavigationBar.lua:50-54); the overflow button stays
-- Blizzard's.
local function styleNav(kit, nav)
    for _, key in ipairs(NAV_ART) do kit:Fade(tbl(nav[key])) end
    for _, r in ipairs(regionsOf(nav, "Texture", "BACKGROUND")) do kit:Fade(r) end
    local overlay = tbl(nav.overlay)
    if overlay then for _, r in ipairs(regionsOf(overlay, "Texture")) do kit:Fade(r) end end
    local list = { tbl(nav.homeButton) }
    for _, b in ipairs(tbl(nav.navList) or {}) do list[#list + 1] = tbl(b) end
    for _, b in pairs(list) do
        for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture" }) do
            local ok, tex = pcall(b[getter], b)
            if ok then kit:Fade(tbl(tex)) end
        end
    end
end

-- A recessed pane on a host of ours parented to `parent` (it hides with it),
-- at `level`, anchored to `anchor`.
local function pane(kit, parent, anchor, level)
    local host = kit:Adopt(CreateFrame("Frame", nil, parent))
    host:SetAllPoints(anchor)
    host:SetFrameLevel(math.max(0, level))
    local sec = kit:Section(host)
    sec.fill:SetAllPoints(host)
    Kit.ShowSection(sec, true)
    return sec, host
end

-- A small glass pill under an input box (level - 1, its rim there too).
local function pill(kit, box)
    if not box or pills[box] then return end
    local glass, g = kit:Panel(box, "small", PILL_INSETS, nil, { backing = false })
    if g and g.top then g.top:SetFrameLevel(glass:GetFrameLevel()) end
    pills[box] = { glass = glass, g = g }
end

-- The disc follows the book's texture: maximise hides the texture only
-- (SetPortraitShown, PortraitFrame.lua:92-94), not its container. After
-- ShowPanels, which shows every panel of ours.
local function syncDisc(h)
    if not h.disc then return end
    local bf = tbl(h.frame.BorderFrame)
    local pc = bf and tbl(bf.PortraitContainer)
    local portrait = pc and tbl(pc.portrait)
    local shown = true
    if portrait then
        local ok, s = pcall(portrait.IsShown, portrait)
        shown = ok and API.Plain(s) == true
    end
    h.disc:SetShown(shown)
end

-- After a display change (deferred): the header placed, the disc, the
-- buttons' feedback from their getters (the mixin swapped them).
local function display(h)
    Kit.PlaceHeader(h)
    syncDisc(h)
    Kit.CloseSync(h)
end

-- hooksecurefunc on an instance method; the hook only schedules `fn` a frame
-- later. A missing method (another build) is recorded, not fatal.
local function schedule(kit, obj, method, what, fn)
    if type(obj) ~= "table" or type(obj[method]) ~= "function" then
        return API.Fail("missing:map:" .. what, "no " .. method .. " on this build")
    end
    hooksecurefunc(obj, method, function()
        if GUI.Engine.Active("map") then GUI.Engine.Defer(kit.skin, what, fn) end
    end)
end

-- Leatrix Maps' "Simple map frame" (default On) rebuilds this border: read
-- once at login (Leatrix_Maps.lua:2887, 2956, 2962; docs/PLAN.md).
local function leatrixSimple()
    local db = rawget(_G, "LeaMapsDB")
    return not (type(db) == "table" and db.SimpleMapFrame == "Off")
end

GUI.Engine.Register({
    key = "map",
    title = "World map",
    risk = "plain",
    defer = true,
    live = true,
    backing = "window",
    owners = { "GlassMaps" },
    yields = { Leatrix_Maps = leatrixSimple },
    frames = function() return rawget(_G, "WorldMapFrame") end,
    install = function(kit, frame)
        local win, wg, backing = kit:Panel(frame)
        local h = { kit = kit, frame = frame }
        wins[frame] = h
        local bf, nav = tbl(frame.BorderFrame), tbl(frame.NavBar)
        kit:Header(win, wg, backing, nav or win, "BOTTOM", nav and 0 or -60, h)
        if bf then
            h.disc = kit:PortraitDisc(bf, { ring = 6, width = 58 })
            kit:CloseButton(tbl(bf.CloseButton), h)
            local mm = tbl(bf.MaximizeMinimizeFrame)
            if mm then
                kit:GlyphButton(tbl(mm.MaximizeButton), h, "expand")
                kit:GlyphButton(tbl(mm.MinimizeButton), h, "condense")
            end
        end
        if nav then
            -- At the bar's level: under its crumbs (the last at + 1, NavigationBar.lua:227).
            h.nav, h.navHost = pane(kit, nav, nav, nav:GetFrameLevel())
            schedule(kit, nav, "Refresh", "navbar", function() styleNav(kit, nav) end)
        end
        local qsf, quests = questLog()
        if qsf and quests then
            -- At QuestsFrame's level: under its scroll frame and details.
            h.log, h.logHost = pane(kit, quests, qsf, quests:GetFrameLevel())
            pill(kit, tbl(qsf.SearchBox))
            schedule(kit, qsf, "UpdateBackground", "headers", function() styleHeaders(kit) end)
        end
        pill(kit, tbl(rawget(_G, "QuestLogCount")))
        for _, method in ipairs({ "Maximize", "Minimize" }) do
            schedule(kit, frame, method, "display", function() display(h) end)
        end
    end,
    style = function(kit, frame)
        local bf = tbl(frame.BorderFrame)
        if bf then
            kit:Fade(tbl(bf.NineSlice))
            kit:Fade(tbl(bf.Bg))                -- reparented to the window (Blizzard_WorldMap.lua:27)
            kit:Fade(tbl(bf.InsetBorderTop))
            kit:CloseFades(tbl(bf.CloseButton))
            local mm = tbl(bf.MaximizeMinimizeFrame)
            if mm then
                kit:CloseFades(tbl(mm.MaximizeButton))
                kit:CloseFades(tbl(mm.MinimizeButton))
            end
        end
        local over = tbl(frame.OverscrollBG)
        if over then for _, r in ipairs(regionsOf(over, "Texture")) do kit:Fade(r) end end
        local nav = tbl(frame.NavBar)
        if nav then styleNav(kit, nav) end
        local qsf = questLog()
        if qsf then
            kit:Fade(tbl(qsf.Background))       -- SetAtlas each update: alpha holds
            local border = tbl(qsf.BorderFrame)
            if border then
                kit:Fade(tbl(border.Border))
                kit:Fade(tbl(border.TopDetail))
                kit:Blank(tbl(border.Shadow))   -- its alpha follows the scroll (QuestMapFrame.lua:1391-1397)
            end
            local sep = tbl(qsf.Contents) and tbl(qsf.Contents.Separator)
            if sep then kit:Fade(tbl(sep.Divider)) end
            local search = tbl(qsf.SearchBox)
            if search then for _, key in ipairs(BOX_ART) do kit:Fade(tbl(search[key])) end end
        end
        local count = tbl(rawget(_G, "QuestLogCount"))
        if count then for _, key in ipairs(BOX_ART) do kit:Fade(tbl(count[key])) end end
        styleHeaders(kit)
        local h = wins[frame]
        if h then display(h) end
    end,
})

-- An accent change (Theme.Refresh): the headers' +/- follow while on (the
-- close and glyphs are the kit's).
GUI.Theme.OnRefresh(function()
    if not GUI.Engine.Active("map") then return end
    local c = accent()
    for _, h in pairs(wins) do
        for row in pairs(headers) do h.kit:Tint(row.CollapseButton.Icon, c[1], c[2], c[3]) end
    end
end)

GUI.Map = { _test = { wins = wins, headers = headers, pills = pills, isHeader = isHeader, leatrixSimple = leatrixSimple,
                      NAV_ART = NAV_ART } }
