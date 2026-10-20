-- Skin/QuestTracker.lua: Blizzard's objective tracker in glass (#55,
-- docs/QUEST-TRACKER.md part 2): Glass Quest Tracker's look, moved into Glass
-- UI with the meter's surface (the kit's panel on the suite theme), not GQT's
-- reflective shell. Its taint passes A and B were clean on 70374, its look's
-- checks on 70450 (GQT docs/FOREVER-PROBE.md).
--
-- Forever runs the Mainline tracker (GQT CLAUDE.md, "Tracker facts"): a
-- container (ObjectiveTrackerFrame, always loaded, not protected) with a
-- NineSlice and a Header, eleven module instances with their headers, and each
-- module's pooled extras. Hooks go on each module INSTANCE's EndLayout:
-- mixin-table hooks miss everything (mixins are copied at creation), and
-- ObjectiveTrackerFrame.Update hooks miss dirty updates.
--
--   faded    the NineSlice (Edit Mode's Opacity), the container header's gold
--            bar, the item and find-group buttons' frame art, the progress
--            bars' borders
--   blanked  the module headers' Background, Shine and Glow: AddAnim animates
--            their alpha with setToFinalAlpha, which a fade can't hold. Their
--            atlas is set once, in XML (Blizzard_ObjectiveTrackerModule.xml:22),
--            so Restore can give it back.
--   tinted   the minimize and filter buttons, in the suite's accent (#52,
--            Suite.Accent: gold by default, or ice), recoloured live when it
--            changes. A tint survives Blizzard's SetAtlas on collapse (GQT
--            pass B, 70374).
--
-- Text keeps Blizzard's colours and fonts (difficulty colours carry
-- information); the POI buttons and auto-quest popups stay stock.
--
-- The glass is the damage meter's recipe (the owner, 2026-10-19: GQT's single
-- panel put the minimize buttons on its rim): a small band over the "All
-- Objectives" header, and the body under it. Both are placed by state, never
-- by reading a position, after every layout, collapse and Edit Mode exit:
--   the band             always, from the NineSlice's top to the Header's bottom
--   populated            the body under the band, to the NineSlice's bottom,
--                        which Blizzard anchors under the last module after
--                        every layout (Container.lua:117)
--   collapsed or empty   the band alone: collapsed, the NineSlice keeps its old
--                        full size (70374), and empty (Edit Mode only) it has
--                        top anchors only.

local GUI = GlassUI
local API = GUI.API

-- The module instances by global name, in Blizzard's order
-- (Blizzard_ObjectiveTrackerManager.lua); the container's own list adds any
-- other a later build has.
local MODULES = { "ScenarioObjectiveTracker", "UIWidgetObjectiveTracker", "CampaignQuestObjectiveTracker",
    "QuestObjectiveTracker", "AdventureObjectiveTracker", "AchievementObjectiveTracker",
    "MonthlyActivitiesObjectiveTracker", "InitiativeTasksObjectiveTracker", "ProfessionsRecipeTracker",
    "BonusObjectiveTracker", "WorldQuestObjectiveTracker" }

-- The accent before Glass UI's suite is ready (never, once a skin runs: the
-- engine starts at PLAYER_LOGIN): Blizzard's gold, the accent's default.
local FALLBACK = { 1, 0.82, 0 }

local function accent() return GUI.Suite.Accent() or FALLBACK end

-- From the NineSlice, whose left runs 30 px past the tracker for the POI
-- buttons and whose right runs 5 px past it. The right edge is the NineSlice's,
-- so the minimize buttons sit inside the glass: GQT stopped 2 px inside the
-- tracker (beside the action bars it merged with their glass), which put them
-- on the rim (70450). The band's right is the Header's, which is the
-- tracker's, plus 5 for the same edge. GAP: between the band and the body.
local LEFT, RIGHT, BOTTOM = 16, 0, 0
local HEADER_RIGHT, HEADER_BOTTOM = 5, -4
local GAP = 2

local panels = setmetatable({}, { __mode = "k" })   -- tracker -> the body panel
local bands = setmetatable({}, { __mode = "k" })    -- tracker -> the header band
local glass = setmetatable({}, { __mode = "k" })    -- tracker -> the body's LibGlass regions
local bandGlass = setmetatable({}, { __mode = "k" }) -- tracker -> the band's
local hooked = setmetatable({}, { __mode = "k" })   -- module or header -> true
local QT = { state = nil }                          -- "populated" | "header", after the last place

local function tbl(v) return type(v) == "table" and v or nil end

local function call(obj, getter)
    if type(obj) ~= "table" or type(obj[getter]) ~= "function" then return nil end
    local ok, v = pcall(obj[getter], obj)
    return ok and tbl(v) or nil
end

-- Every module: the known globals, then any other the container holds.
local function modules(t)
    local list, seen = {}, {}
    local function add(m)
        if tbl(m) and not seen[m] then seen[m] = true; list[#list + 1] = m end
    end
    for _, name in ipairs(MODULES) do add(rawget(_G, name)) end
    for _, m in ipairs(tbl(t.modules) or {}) do add(m) end
    return list
end

-- Any module on screen: the container lays out only the shown ones.
local function populated(t)
    for _, m in ipairs(modules(t)) do
        local ok, shown = pcall(m.IsShown, m)
        if ok and API.Plain(shown) == true then return true end
    end
    return false
end

local function place(t)
    local body, band, nine, header = panels[t], bands[t], tbl(t.NineSlice), tbl(t.Header)
    if not (body and band and nine and header) then return end
    band:ClearAllPoints()
    band:SetPoint("TOPLEFT", nine, "TOPLEFT", LEFT, 0)
    band:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", HEADER_RIGHT, HEADER_BOTTOM)
    body:ClearAllPoints()
    body:SetPoint("TOPLEFT", band, "BOTTOMLEFT", 0, -GAP)
    body:SetPoint("BOTTOMRIGHT", nine, "BOTTOMRIGHT", RIGHT, BOTTOM)
    -- Our own frames: Show and Hide are ours to call.
    if API.Plain(t.isCollapsed) == true or not populated(t) then
        body:Hide()
        QT.state = "header"
    else
        body:Show()
        QT.state = "populated"
    end
end

-- A stock button's art in our colour, its red or yellow highlight too.
local function tintButton(kit, b)
    if not tbl(b) then return end
    local c = accent()
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture" }) do
        local tex = call(b, getter)
        if tex then kit:Tint(tex, c[1], c[2], c[3]) end
    end
end

-- Every button in the accent again (the kit keeps Blizzard's colour from the
-- first tint, so Restore gives that back however many times this ran).
local function recolour(kit, t)
    local h = tbl(t.Header)
    if h then
        tintButton(kit, h.MinimizeButton)
        tintButton(kit, h.FilterButton)
    end
    for _, m in ipairs(modules(t)) do
        local mh = tbl(m.Header)
        if mh then tintButton(kit, mh.MinimizeButton) end
    end
end

-- A button's frame art; its icon, count and cooldown are other regions.
local function fadeButtonArt(kit, b)
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
        local tex = call(b, getter)
        if tex then kit:Fade(tex) end
    end
end

local function container(kit, t)
    kit:Fade(kit:Child(t, "NineSlice"))
    local h = kit:Child(t, "Header")
    if not h then return end
    kit:Fade(kit:Child(h, "Background"))
    tintButton(kit, h.MinimizeButton)
    tintButton(kit, h.FilterButton)
end

-- One module: its header, and the pooled extras this layout shows.
local function module(kit, m)
    local h = tbl(m.Header)
    if h then
        for _, key in ipairs({ "Background", "Shine", "Glow" }) do
            if tbl(h[key]) then kit:Blank(h[key]) end
        end
        tintButton(kit, h.MinimizeButton)
    end
    for _, frame in pairs(tbl(m.usedRightEdgeFrames) or {}) do
        if tbl(frame) then fadeButtonArt(kit, frame) end
    end
    for _, p in pairs(tbl(m.usedProgressBars) or {}) do
        local bar = tbl(p) and tbl(p.Bar)
        if bar then
            for _, key in ipairs({ "BorderLeft", "BorderRight", "BorderMid" }) do
                if tbl(bar[key]) then kit:Fade(bar[key]) end
            end
        end
    end
end

-- hooksecurefunc on that instance; a missing hook point (another build) is
-- recorded, not fatal.
local function hook(key, obj, method, fn)
    if hooked[obj] then return end
    if type(obj) ~= "table" or type(obj[method]) ~= "function" then
        return API.Fail("missing:tracker:" .. key, "no " .. method .. " on this build")
    end
    hooked[obj] = true
    hooksecurefunc(obj, method, fn)
end

-- Each module's hooks, once: on every pass, so a module the container gains
-- later is hooked at the next.
local function hookModules(kit, t)
    for i, m in ipairs(modules(t)) do
        local name = API.Plain(m.GetName and m:GetName()) or ("module " .. i)
        hook("layout:" .. name, m, "EndLayout", function(mod)
            if not GUI.Engine.Active("tracker") then return end
            GUI.Engine.Run(kit.skin, "layout", function()
                module(kit, mod)
                place(t)
            end)
        end)
        if tbl(m.Header) then
            hook("collapse:" .. name, m.Header, "SetCollapsed", function()
                if GUI.Engine.Active("tracker") then GUI.Engine.Run(kit.skin, "collapse", module, kit, m) end
            end)
        end
    end
end

GUI.Engine.Register({
    key = "tracker",
    title = "Quest tracker",
    owners = { "GlassQuestTracker" },
    risk = "plain",
    live = true,
    frames = function() return rawget(_G, "ObjectiveTrackerFrame") end,
    install = function(kit, t)
        local band, gb = kit:Panel(t, "small")
        local body, g = kit:Panel(t)
        panels[t], bands[t], glass[t], bandGlass[t] = body, band, g, gb
        -- The rims at the tracker's level, under its modules (GQT, 70374).
        for _, x in ipairs({ g, gb }) do
            if x and x.top then x.top:SetFrameLevel(t:GetFrameLevel()) end
        end
        -- Collapsing the container lays out no module: placed from here.
        hook("collapse:container", tbl(t.Header), "SetCollapsed", function()
            if not GUI.Engine.Active("tracker") then return end
            GUI.Engine.Run(kit.skin, "collapse", function()
                container(kit, t)
                place(t)
            end)
        end)
        -- The accent changed on the "Suite look" subpage (#52): live, in combat
        -- too (vertex colours on the tracker's own unprotected textures).
        EventRegistry:RegisterCallback(GUI.Suite.LOOK_EVENT, function()
            if GUI.Engine.Active("tracker") then GUI.Engine.Run(kit.skin, "accent", recolour, kit, t) end
        end, {})
        -- Leaving Edit Mode with nothing tracked lays out nothing either.
        local em = rawget(_G, "EditModeManagerFrame")
        if tbl(em) and type(em.HookScript) == "function" then
            em:HookScript("OnHide", function()
                if GUI.Engine.Active("tracker") then GUI.Engine.Run(kit.skin, "editmode", place, t) end
            end)
        end
    end,
    -- A full pass over what is there now, pooled extras made while the skin
    -- was off included, then the panel placed: the engine runs it again when
    -- the skin comes back on.
    style = function(kit, t)
        hookModules(kit, t)
        container(kit, t)
        for _, m in ipairs(modules(t)) do module(kit, m) end
        place(t)
    end,
})

GUI.QuestTracker = QT
QT._test = { panels = panels, bands = bands, glass = glass, bandGlass = bandGlass, offsets = { LEFT = LEFT, RIGHT = RIGHT, BOTTOM = BOTTOM,
             HEADER_RIGHT = HEADER_RIGHT, HEADER_BOTTOM = HEADER_BOTTOM, GAP = GAP }, accent = accent }
