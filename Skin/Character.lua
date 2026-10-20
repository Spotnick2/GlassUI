-- Skin/Character.lua: Forever's character window (#94, docs/CHARACTER.md),
-- from the window template (merchant #86 ... guild #92) and the owner's mockup.
--
-- CharacterFrame (Camelot\CharacterFrame.xml, PortraitFrameBaseTemplate,
-- wow-ui-source forever 70450): no Bg or Inset; its backdrops are the left and
-- right pane hosts. Hazards: the slots' click is the protected equip/use path
-- (alpha and our own children only: no script, field or hook on them); the
-- currency pane and its transfer UI are never touched (Ellesmere: skinning
-- them taints the warband transfer); the UI panel's width and the collapse
-- state are Blizzard's.
--
-- The window glass with the floor, a smoky title band, the portrait's disc,
-- the close button; the hosts' own art faded, the right pane a recessed pane
-- with a separator; the level strip a pane; the model on the glass; each slot
-- a glass well; the stats headers as glass bars (the stat lines stock); the
-- six mode tabs and the four sidebar tabs through the kit's side tabs.

local GUI = GlassUI
local API = GUI.API
local Kit = GUI.Kit

-- The slots (PaperDollFrame.xml:774-866); the ammo slot has its own anatomy.
local SLOTS = { "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist", "Hands", "Waist",
                "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1", "MainHand", "SecondaryHand", "Ranged" }
local SLOT_INSETS = { 0, 0, 0, 0 }
-- The model's background (PaperDollFrame.xml:609-650).
local MODEL_ART = { "BackgroundTopLeft", "BackgroundTopRight", "BackgroundBotLeft", "BackgroundBotRight",
                    "BackgroundOverlay" }
local STRIP_ART = { "TopBackgroundStrip", "TopBackgroundStripBottomEdge" }
-- The large mode tabs and the sidebar tabs on glass.
local MODE_INSETS = { 2, 2, 2, 2 }
local SIDEBAR_INSETS = { -1, -1, -1, -1 }
local SIDEBAR = 4

local wins = setmetatable({}, { __mode = "k" })     -- the window -> our pieces
local slots = setmetatable({}, { __mode = "k" })    -- slot -> { glass, g }
local headers = setmetatable({}, { __mode = "k" })  -- a pooled stats header row -> { glass, g }

local function tbl(v) return type(v) == "table" and v or nil end

-- A frame's own regions of a type, optionally on a layer (never its children).
local function regionsOf(f, kind, layer)
    local out = {}
    local ok, regions = pcall(function() return { f:GetRegions() } end)
    if not ok then return out end
    for _, r in ipairs(regions) do
        local okT, t = pcall(r.GetObjectType, r)
        if okT and API.Plain(t) == kind then
            if not layer then
                out[#out + 1] = r
            else
                local okL, l = pcall(r.GetDrawLayer, r)
                if okL and API.Plain(l) == layer then out[#out + 1] = r end
            end
        end
    end
    return out
end

-- A small glass well under a slot, its rim at its own level, mouse off (the
-- bags' recipe): parented to the slot, nothing on it.
local function well(kit, b)
    if slots[b] then return end
    local glass, g = kit:Panel(b, "small", SLOT_INSETS, nil, { backing = false })
    if g and g.top then g.top:SetFrameLevel(glass:GetFrameLevel()) end
    slots[b] = { glass = glass, g = g }
end

local function styleSlot(kit, b)
    kit:Fade(tbl(b.BorderFrame))
    local ok, normal = pcall(b.GetNormalTexture, b)
    if ok then kit:Fade(tbl(normal)) end
end

-- The ammo slot: its bronze ring is its own BACKGROUND texture, its arrow on
-- a child (PaperDollFrame.xml:868-931).
local function styleAmmo(kit, b)
    for _, r in ipairs(regionsOf(b, "Texture", "BACKGROUND")) do kit:Fade(r) end
    local ok, normal = pcall(b.GetNormalTexture, b)
    if ok then kit:Fade(tbl(normal)) end
end

-- The stats list's rows: a header is a row with a Background and a Title
-- (CharacterFrame.xml:77-94); stat lines (Background, Label, Value) are left
-- to Blizzard. Called by the style pass and the list's Update post-hook.
local function styleHeaders(kit, list)
    local target = tbl(list.ScrollTarget)
    if not target then return end
    for _, row in ipairs({ target:GetChildren() }) do
        if tbl(row.Background) and tbl(row.Title) then
            if not headers[row] then
                local glass, g = kit:Panel(row, "small", { 0, 0, 0, 0 }, nil, { backing = false })
                if g and g.top then g.top:SetFrameLevel(glass:GetFrameLevel()) end
                headers[row] = { glass = glass, g = g }
            end
            kit:Fade(row.Background)
        end
    end
end

-- A recessed pane on a host frame of ours parented to `parent` (it shows and
-- hides with it), anchored to `anchor`.
local function pane(kit, parent, anchor, level)
    if not (parent and anchor) then return nil end
    local host = kit:Adopt(CreateFrame("Frame", nil, parent))
    host:SetAllPoints(anchor)
    host:SetFrameLevel(math.max(0, level))
    local sec = kit:Section(host)
    sec.fill:SetAllPoints(host)
    Kit.ShowSection(sec, true)
    return sec, host
end

-- The six large mode tabs (Frames: SelectedTexture shown is the selection,
-- toggled by their mixin's SetChecked) and the four sidebar CheckButtons.
local MODE_TAB = {
    insets = MODE_INSETS,
    selected = function(tab) return tab.SelectedTexture:IsShown() end,
    methods = { "SetChecked" },
    art = function(tab) return { tbl(tab.Background), tbl(tab.SelectedTexture) } end,
}
local SIDEBAR_TAB = {
    insets = SIDEBAR_INSETS,
    selected = function(tab) return tab:GetChecked() end,
    methods = { "SetChecked" },
    scripts = { "OnClick" },
    art = function(tab)
        local ok, checked = pcall(tab.GetCheckedTexture, tab)
        local out = regionsOf(tab, "Texture", "BORDER")
        out[#out + 1] = ok and tbl(checked) or nil
        return out
    end,
}

local function modeTabs(frame)
    local mt = tbl(frame.ModeTabs)
    return mt and tbl(mt.Tabs) or {}
end

GUI.Engine.Register({
    key = "character",
    title = "Character",
    risk = "plain",
    live = true,
    backing = "window",
    frames = function() return rawget(_G, "CharacterFrame") end,
    install = function(kit, frame)
        local win, wg, backing = kit:Panel(frame)
        local h = { kit = kit, frame = frame }
        wins[frame] = h
        local left, right = tbl(frame.LeftPaneHost), tbl(frame.RightPaneHost)
        kit:Header(win, wg, backing, left or win, "TOP", left and 0 or -60, h)
        h.disc = kit:PortraitDisc(frame, { ring = 6, width = 58, global = "CharacterFramePortrait" })
        kit:CloseButton(tbl(frame.CloseButton), h)
        if right then
            h.right, h.rightHost = pane(kit, right, right, right:GetFrameLevel())
            -- Our separator along the right pane's left edge.
            local line = h.rightHost:CreateTexture(nil, "ARTWORK", nil, 2)
            line:SetColorTexture(1, 1, 1, Kit.SECTION_EDGE)
            line:SetPoint("TOPLEFT", right, "TOPLEFT", 0, 0)
            line:SetPoint("BOTTOMLEFT", right, "BOTTOMLEFT", 0, 0)
            line:SetWidth(1)
            h.separator = line
        end
        local pd = tbl(rawget(_G, "PaperDollFrame"))
        local strip = pd and tbl(pd.TopBackgroundStripHost)
        if strip then h.strip = pane(kit, strip, strip, strip:GetFrameLevel()) end
        for _, name in ipairs(SLOTS) do
            local b = kit:Global("Character" .. name .. "Slot")
            if b then well(kit, b) end
        end
        local ammo = tbl(rawget(_G, "CharacterAmmoSlot"))
        if ammo then well(kit, ammo) end
        local stats = tbl(rawget(_G, "CharacterStatsPaneScrollBox"))
        local list = stats and tbl(stats.ScrollBox)
        if stats then h.stats = pane(kit, stats, stats, stats:GetFrameLevel()) end
        if list then
            h.list = list
            hooksecurefunc(list, "Update", function(l)
                if GUI.Engine.Active("character") then GUI.Engine.Run(kit.skin, "headers", styleHeaders, kit, l) end
            end)
        end
        for _, tab in ipairs(modeTabs(frame)) do kit:SideTab(tab, MODE_TAB) end
        for i = 1, SIDEBAR do
            local tab = tbl(rawget(_G, "PaperDollSidebarTab" .. i))
            if tab then kit:SideTab(tab, SIDEBAR_TAB) end
        end
    end,
    style = function(kit, frame)
        kit:Fade(tbl(frame.NineSlice))
        kit:CloseFades(tbl(frame.CloseButton))
        local left, right = tbl(frame.LeftPaneHost), tbl(frame.RightPaneHost)
        -- The hosts' own regions only (and the right one's divider frame):
        -- never their content, never the currency pane.
        if left then for _, r in ipairs(regionsOf(left, "Texture")) do kit:Fade(r) end end
        if right then
            for _, r in ipairs(regionsOf(right, "Texture")) do kit:Fade(r) end
            for _, child in ipairs({ right:GetChildren() }) do
                if not wins[frame] or child ~= wins[frame].rightHost then
                    for _, r in ipairs(regionsOf(child, "Texture")) do kit:Fade(r) end
                end
            end
        end
        local pd = tbl(rawget(_G, "PaperDollFrame"))
        local strip = pd and tbl(pd.TopBackgroundStripHost)
        if strip then for _, key in ipairs(STRIP_ART) do kit:Fade(tbl(strip[key])) end end
        local model = tbl(rawget(_G, "CharacterModelScene"))
        if model then for _, key in ipairs(MODEL_ART) do kit:Fade(tbl(model[key])) end end
        for _, name in ipairs(SLOTS) do
            local b = tbl(rawget(_G, "Character" .. name .. "Slot"))
            if b then styleSlot(kit, b) end
        end
        local ammo = tbl(rawget(_G, "CharacterAmmoSlot"))
        if ammo then styleAmmo(kit, ammo) end
        local stats = tbl(rawget(_G, "CharacterStatsPaneScrollBox"))
        if stats then
            kit:Fade(tbl(stats.Border))
            kit:Fade(tbl(stats.ClassBackground))
            if tbl(stats.ScrollBox) then styleHeaders(kit, stats.ScrollBox) end
        end
        for tab, st in pairs(Kit.sideTabs) do
            if st.kit == kit then kit:StyleSideTab(tab) end
        end
        Kit.SyncSideTabs(kit)
        local h = wins[frame]
        if h then
            Kit.PlaceHeader(h)
            Kit.CloseSync(h)
        end
    end,
})

GUI.Character = { _test = { wins = wins, slots = slots, headers = headers, SLOTS = SLOTS } }
