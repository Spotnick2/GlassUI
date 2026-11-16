-- Skin/RestedXP.lua: RestedXP's guide window and waypoint arrow (#56,
-- docs/RESTEDXP.md), from the owner's mockup ("Smoky Quest Guide and Waypoint
-- UI"). Two switches: rxp (RXPFrame) and rxparrow (RXPG_ARROW), each attached
-- when RXPGuides loads, never a dependency.
--
-- RestedXP v4.11.36 (References\Addons\QuestsLeveling\RXPGuides, behaviour
-- reference only, never copied), its default window ("V1") only. Its objects
-- get the skin contract as Blizzard's do: getters, SetAlpha (held), our
-- texture's colour, HookScript and hooksecurefunc on an instance's own
-- function field. Never a call to its functions, a field written, a frame
-- shown, hidden, moved or resized. Every piece is reached by field: two
-- globals clash (RXPFrameGuideName is the Footer's).
--
-- None of these frames is secure (RestedXP's secure buttons are RXPItemFrame
-- and RXPTargetFrame, never reached), so no defer: a pass may run in combat.
--
-- The guide: the window glass (a child of GuideName, which V1's collapse
-- leaves shown and V2 hides) from the header to the footer; every backdrop
-- piece faded (RestedXP's SetBackdrop reuses them and sets only textures and
-- colours: the pass reasserts the fade, QS.2); a smoky header band and our
-- hairlines; a recessed track round the scroll bar; each list row's pieces
-- faded (never the row's alpha: RestedXP's state) with our hairline under it;
-- each current-step card on its own glass.
--
-- The arrow (the audited exception, docs/PLAN.md): RestedXP's texture faded,
-- our own arrow in the suite accent over it, turned with RestedXP's
-- SetRotation; the distance on a smoky pill.

local GUI = GlassUI
local API = GUI.API
local Kit = GUI.Kit

local ADDON = "RXPGuides"
local ARROW = "Interface\\AddOns\\GlassUI\\Media\\Arrow"
-- The Backdrop mixin's pieces, fields of the frame itself (NineSlice.lua's
-- GetNineSlicePiece on the container).
local PIECES = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "TopEdge",
                 "BottomEdge", "LeftEdge", "RightEdge", "Center" }
-- The pill's padding round the text, px per side.
local PILL_PAD = { 8, 4 }

local wins = setmetatable({}, { __mode = "k" })    -- RXPFrame -> our pieces
local rows = setmetatable({}, { __mode = "k" })    -- a pooled list row -> our hairline's host
local cards = setmetatable({}, { __mode = "k" })   -- a pooled step card -> { glass, g }
local arrows = setmetatable({}, { __mode = "k" })  -- RXPG_ARROW -> our arrow and pill
local pending = setmetatable({}, { __mode = "k" }) -- a kit -> { [what] = the generation it was queued in }

local function tbl(v) return type(v) == "table" and v or nil end

-- fn a frame later, once per frame however many calls come. What's kept is
-- the generation it was queued in, not a flag: Engine.Defer drops a callback
-- whose generation went stale (the switch off before the next frame), and a
-- flag left set would block every later pass.
local function queue(kit, what, fn)
    local q = pending[kit] or {}
    pending[kit] = q
    if q[what] == kit.skin.gen then return end
    q[what] = kit.skin.gen
    GUI.Engine.Defer(kit.skin, what, function()
        q[what] = nil
        fn()
    end)
end

-- hooksecurefunc on an instance's own function field; the hook only queues.
-- A missing field (another RestedXP version) is recorded, not fatal.
local function hook(kit, obj, field, what, fn)
    if type(obj) ~= "table" or type(obj[field]) ~= "function" then
        return API.Fail("missing:" .. kit.key .. ":" .. what, "no " .. field .. " in this RestedXP version")
    end
    hooksecurefunc(obj, field, function()
        if GUI.Engine.Active(kit.key) then queue(kit, what, fn) end
    end)
end

local function fadePieces(kit, f)
    if not f then return end
    for _, k in ipairs(PIECES) do kit:Fade(tbl(f[k])) end
end

-- A 1 px line of ours, SECTION_EDGE white, along `side` ("TOP"/"BOTTOM") of
-- `region`, on `host`'s ARTWORK.
local function hairline(host, region, side)
    local line = host:CreateTexture(nil, "ARTWORK", nil, 2)
    line:SetColorTexture(1, 1, 1, Kit.SECTION_EDGE)
    line:SetPoint(side .. "LEFT", region, side .. "LEFT", 0, 0)
    line:SetPoint(side .. "RIGHT", region, side .. "RIGHT", 0, 0)
    line:SetHeight(1)
    return line
end

--------------------------------------------------------------------------------
-- The guide window
--------------------------------------------------------------------------------

-- A list row: its pieces faded, its alpha RestedXP's (0.66 building, 1
-- current, 0.5 done, 0 hidden). Our hairline's host once, a child of the row,
-- so it fades and hides with the row's state.
local function rowPass(kit, row)
    fadePieces(kit, row)
    if rows[row] then return end
    local host = kit:Adopt(CreateFrame("Frame", nil, row))
    host:SetAllPoints(row)
    hairline(host, row, "BOTTOM")
    rows[row] = host
end

-- A current-step card (tips too: still the frame's children, anchored to
-- UIParent): its pieces and its number tab's faded (the tab's own alpha is
-- RestedXP's: 0 for an untitled step), our smoky glass once at the card's
-- level - 1, its rim there too (LibGlass makes it 10 up, over the step text).
local function cardPass(kit, card)
    fadePieces(kit, card)
    fadePieces(kit, tbl(card.number))
    if cards[card] then return end
    local glass, g = kit:Panel(card, "small")
    if g and g.top then g.top:SetFrameLevel(glass:GetFrameLevel()) end
    cards[card] = { glass = glass, g = g }
end

local function windowPass(kit, frame)
    local h = wins[frame]
    if not h then return end
    for _, f in ipairs({ h.name, h.list, h.footer }) do fadePieces(kit, f) end
    kit:Fade(tbl(h.name.bg))
    kit:Fade(tbl(h.footer.bg))
    local child = tbl(frame.ScrollChild)
    for _, row in ipairs(child and tbl(child.framePool) or {}) do
        if tbl(row) then rowPass(kit, row) end
    end
    local steps = tbl(frame.CurrentStepFrame)
    for _, card in ipairs(steps and tbl(steps.framePool) or {}) do
        if tbl(card) then cardPass(kit, card) end
    end
    Kit.ShowSection(h.track, true)
    Kit.PlaceHeader(h)
end

-- The window glass: a child of GuideName (V1's collapse hides BottomFrame and
-- keeps the header and footer; V2 hides all three), below the lowest of the
-- three, its rim there too (over the rows otherwise), from the header's top
-- to the footer's bottom: it follows a resize and shrinks with a collapse.
local function buildWindow(kit, frame)
    local name, list, footer = tbl(frame.GuideName), tbl(frame.BottomFrame), tbl(frame.Footer)
    if not (name and list and footer) then
        return API.Fail("missing:" .. kit.key .. ":window", "no GuideName, BottomFrame or Footer")
    end
    local h = { kit = kit, frame = frame, name = name, list = list, footer = footer }
    local win, wg, backing = kit:Panel(name)
    win:ClearAllPoints()
    win:SetPoint("TOPLEFT", name, "TOPLEFT", 0, 0)
    win:SetPoint("BOTTOMRIGHT", footer, "BOTTOMRIGHT", 0, 0)
    local low = math.min(name:GetFrameLevel(), list:GetFrameLevel(), footer:GetFrameLevel())
    win:SetFrameLevel(math.max(0, low - 1))
    if wg and wg.top then wg.top:SetFrameLevel(win:GetFrameLevel()) end
    h.win, h.wg = win, wg
    -- The band down to the header's own bottom (it overlaps the list by 9 px),
    -- our hairlines there and along the footer's top.
    kit:Header(win, wg, backing, name, "BOTTOM", 0, h)
    h.headerLine = hairline(win, name, "BOTTOM")
    h.footerLine = hairline(win, footer, "TOP")
    -- The scroll bar's track: a recessed pane on a host of ours in BottomFrame,
    -- so it hides with the list, round the bar and its two buttons.
    local scroll = tbl(frame.ScrollFrame)
    local bar = scroll and tbl(scroll.ScrollBar)
    if bar then
        local host = kit:Adopt(CreateFrame("Frame", nil, list))
        host:SetAllPoints(list)
        h.track = kit:Section(host)
        h.track.fill:SetPoint("TOPLEFT", bar, "TOPLEFT", -2, 18)
        h.track.fill:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 2, -18)
        h.trackHost = host
    end
    wins[frame] = h
    return h
end

GUI.Engine.Register({
    key = "rxp",
    title = "RestedXP guide",
    addon = ADDON,
    risk = "plain",
    live = true,
    backing = "window",
    frames = function() return rawget(_G, "RXPFrame") end,
    install = function(kit, frame)
        if not buildWindow(kit, frame) then return end
        local function pass() windowPass(kit, frame) end
        -- A theme applied (its SetBackdrop on the three), the list laid out
        -- (every frame while the window is resized), the cards filled.
        hook(kit, frame, "UpdateVisuals", "visuals", pass)
        hook(kit, tbl(frame.BottomFrame), "UpdateFrame", "list", pass)
        hook(kit, tbl(frame.CurrentStepFrame), "UpdateText", "cards", pass)
    end,
    style = function(kit, frame) windowPass(kit, frame) end,
})

--------------------------------------------------------------------------------
-- The waypoint arrow (the audited exception, docs/PLAN.md)
--------------------------------------------------------------------------------

local function paintArrow(st)
    local c = GUI.Suite.Accent() or { 1, 0.82, 0 }
    st.arrow:SetVertexColor(c[1], c[2], c[3], 1)
end

-- RestedXP's angle on ours: from its SetRotation, synchronously (a frame's
-- lag would show as a stutter), or read with GetRotation.
local function turn(st, rad)
    rad = API.Plain(rad)
    if type(rad) == "number" then st.arrow:SetRotation(rad) end
end

-- The pill round the text, from the string's own size; none while it's empty.
local function sizePill(st)
    local okW, w = pcall(st.text.GetStringWidth, st.text)
    local okH, hgt = pcall(st.text.GetStringHeight, st.text)
    w, hgt = okW and API.Plain(w) or nil, okH and API.Plain(hgt) or nil
    local any = type(w) == "number" and type(hgt) == "number" and w > 0 and hgt > 0
    if any then st.pill:SetSize(w + 2 * PILL_PAD[1], hgt + 2 * PILL_PAD[2]) end
    st.pill:SetShown(any)
end

local function buildArrow(kit, af)
    local tex, text = tbl(af.texture), tbl(af.text)
    if not tex then return API.Fail("missing:" .. kit.key .. ":texture", "no arrow texture") end
    local st = { kit = kit, tex = tex, text = text }
    -- Ours a child (one level up), on RestedXP's texture's points (its Arrow
    -- Scale changes the frame's size). A plain frame takes no mouse: the drag
    -- stays RestedXP's.
    local f = kit:Adopt(CreateFrame("Frame", nil, af))
    f:SetAllPoints(tex)
    st.arrow = f:CreateTexture(nil, "ARTWORK")
    st.arrow:SetAllPoints(f)
    st.arrow:SetTexture(ARROW)
    st.frame = f
    paintArrow(st)
    hooksecurefunc(tex, "SetRotation", function(_, rad)
        if GUI.Engine.Active(kit.key) then GUI.Engine.Run(kit.skin, "rotate", turn, st, rad) end
    end)
    -- The pill: one level below RXPG_ARROW, its rim too, so the text (a
    -- region of RXPG_ARROW) draws over all of it.
    if text then
        local pill, g = kit:Panel(af, "small")
        pill:ClearAllPoints()
        pill:SetPoint("CENTER", text, "CENTER", 0, 0)
        if g and g.top then g.top:SetFrameLevel(pill:GetFrameLevel()) end
        st.pill, st.pillGlass = pill, g
        -- Sized a frame after the text or its font changes: RestedXP's arrow
        -- text size setting calls SetFont alone, and standing still never
        -- calls SetText.
        local function resize() sizePill(st) end
        for _, m in ipairs({ "SetText", "SetFont" }) do
            hooksecurefunc(text, m, function()
                if GUI.Engine.Active(kit.key) then queue(kit, "pill", resize) end
            end)
        end
    end
    arrows[af] = st
    return st
end

local function arrowPass(kit, af)
    local st = arrows[af]
    if not st then return end
    kit:Fade(st.tex)
    local ok, rad = pcall(st.tex.GetRotation, st.tex)
    if ok then turn(st, rad) end
    paintArrow(st)
    if st.pill then sizePill(st) end
end

GUI.Engine.Register({
    key = "rxparrow",
    title = "RestedXP arrow",
    addon = ADDON,
    risk = "plain",
    live = true,
    backing = "window",
    frames = function() return rawget(_G, "RXPG_ARROW") end,
    install = function(kit, af) buildArrow(kit, af) end,
    style = function(kit, af) arrowPass(kit, af) end,
})

-- An accent change: our arrow follows while its skin is on; while off, the
-- style pass repaints.
GUI.Theme.OnRefresh(function()
    if not GUI.Engine.Active("rxparrow") then return end
    for _, st in pairs(arrows) do paintArrow(st) end
end)

GUI.RestedXP = { _test = { wins = wins, rows = rows, cards = cards, arrows = arrows, pending = pending,
                           PIECES = PIECES, ARROW = ARROW, PILL_PAD = PILL_PAD } }
