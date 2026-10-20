-- Skin/Bags.lua: the bag windows (#88, docs/BAGS.md), from the merchant's
-- design (#86), the owner's template for every dialog and window.
--
-- ContainerFrame1..7 and ContainerFrameCombinedBags (Mainline ContainerFrame
-- on Forever, PortraitFrameFlatTemplate, wow-ui-source forever 70450): not
-- protected, but the item buttons are on the item-use path
-- (C_Container.UseContainerItem, allowed untainted, ContainerFrame.lua:1507,
-- 1825). So on a button only alpha and children of ours: never a field, an
-- ID or a script.
--
-- Each window: our glass with the window floor, the flat shell faded, a
-- smoky header band, the portrait's disc, the close button's disc and X
-- (the kit's window pieces). The money box and the shared search box as
-- recessed panes, the sort button on small glass. Each item slot a small
-- glass well: its quick-slot rim faded, and an empty slot's wing pattern
-- dimmed to nothing, so the well shows. The quality border, counts, the
-- new-item glow, junk and quest icons and the search dim stay Blizzard's.
--
-- Fades, hooks on instances and our own frames only: live, off and on
-- without a /reload. Blizzard places, scales and sizes every window
-- (UpdateContainerFrameAnchors); none of it is touched.

local GUI = GlassUI
local API = GUI.API
local Kit = GUI.Kit

-- ContainerFrame1..WINDOWS (ContainerFrame.xml:300-306).
local WINDOWS = 7
-- The header band from the window's top: the title strip (20 high, 1 down,
-- SharedUIPanelTemplates.xml:600), the search row below it from -37
-- (ContainerFrame.lua:1119). A first guess, tuned from the screenshots.
local HEADER_H = 26
-- The portrait's disc, round the portrait itself: Blizzard sizes it 36
-- (SetPortraitTextureSizeAndOffset, ContainerFrame.lua:789), and its mask read
-- about four times wider (BG.1, 70450: "gigantic circles"). A thinner ring
-- than the merchant's 6, for the smaller portrait.
local DISC_RING, PORTRAIT_WIDTH = 4, 36
-- Each slot's glass round its 37 px button.
local SLOT_INSETS = { 0, 0, 0, 0 }
-- The coin box's and the search box's three pieces (ContainerFrame.xml:208,
-- InputBoxTemplates.xml:43).
local EDGES = { "Left", "Middle", "Right" }

local wins = setmetatable({}, { __mode = "k" })     -- window -> our pieces (the kit's state table)
local slots = setmetatable({}, { __mode = "k" })    -- item button -> { glass, g, icon, button }
local shared = {}                                    -- the search box's pane, the sort button's glass

local function tbl(v) return type(v) == "table" and v or nil end

local function shown(f)
    if not f then return false end
    local ok, v = pcall(f.IsShown, f)
    return ok and API.Plain(v) == true
end

local function windows()
    local list = {}
    for i = 1, WINDOWS do
        local f = tbl(rawget(_G, "ContainerFrame" .. i))
        if f then list[#list + 1] = f end
    end
    local combined = tbl(rawget(_G, "ContainerFrameCombinedBags"))
    if combined then list[#list + 1] = combined end
    return unpack(list)
end

-- A window's money frame: the combined window's own, the backpack's by name.
local function moneyOf(frame)
    local m = tbl(frame.MoneyFrame)
    if m then return m end
    if frame == rawget(_G, "ContainerFrame1") then return tbl(rawget(_G, "ContainerFrame1MoneyFrame")) end
    return nil
end

-- An empty slot: the icon shows the button's own empty atlas (the stock
-- template sets only the atlas: SetItemButtonTexture(nil),
-- Blizzard_ItemButton/Mainline/ItemButtonTemplate.lua:76). Then the icon is
-- dimmed to nothing and the glass well shows; filled, Blizzard's alpha back.
local function emptyDim(kit, s)
    local okA, atlas = pcall(s.icon.GetAtlas, s.icon)
    local want = API.Plain(s.button.emptyBackgroundAtlas)
    local empty = okA and want ~= nil and API.Plain(atlas) == want
    kit:Dim(s.icon, empty and 0 or nil)
end

-- An item button (an `icon` and an `IconBorder`, read): its glass once,
-- then the touches each pass. Pooled buttons come back: one glass each.
local function slot(kit, b)
    local s = slots[b]
    if not s then
        local glass, g = kit:Panel(b, "small", SLOT_INSETS, nil, { backing = false })
        -- Its rim at its own level, under the icon, the quality border and
        -- the counts (LibGlass makes it 10 up), as the merchant's rows.
        if g and g.top then g.top:SetFrameLevel(glass:GetFrameLevel()) end
        s = { glass = glass, g = g, icon = b.icon, button = b }
        slots[b] = s
        local function sync()
            if GUI.Engine.Active("bags") then GUI.Engine.Run(kit.skin, "slot", emptyDim, kit, s) end
        end
        hooksecurefunc(s.icon, "SetAtlas", sync)
        hooksecurefunc(s.icon, "SetTexture", sync)
    end
    local ok, rim = pcall(b.GetNormalTexture, b)
    if ok then kit:Fade(rim) end
    -- Combined bags give each button a slot background, made on demand
    -- (ContainerFrame.lua:1846-1853).
    kit:Fade(tbl(b.ItemSlotBackground))
    emptyDim(kit, s)
end

-- Every item button the window holds now (the pool's parent is the window,
-- ContainerFrame.lua:792).
local function styleItems(kit, frame)
    for _, child in ipairs({ frame:GetChildren() }) do
        if tbl(child.icon) and tbl(child.IconBorder) then slot(kit, child) end
    end
end

-- The money box: a recessed pane on the coin box Blizzard draws, shown with
-- the money frame.
local function money(h)
    if h.money then Kit.ShowSection(h.money, shown(h.moneyFrame)) end
end

-- The shared search box and sort button, moved between the backpack and the
-- combined window by Blizzard (ContainerFrame.lua:1124-1147): our pieces are
-- their children, so they follow.
local function installShared(kit)
    if shared.done then return end
    shared.done = true
    local box = tbl(rawget(_G, "BagItemSearchBox"))
    if box then
        -- One level under the box: the fill never covers its text.
        local host = kit:Adopt(CreateFrame("Frame", nil, box))
        host:SetAllPoints(box)
        host:SetFrameLevel(math.max(0, box:GetFrameLevel() - 1))
        local sec = kit:Section(host)
        sec.fill:SetAllPoints(host)
        Kit.ShowSection(sec, true)
        shared.search, shared.searchHost = sec, host
    end
    local sort = tbl(rawget(_G, "BagItemAutoSortButton"))
    if sort then
        local glass, g = kit:Panel(sort, "small", SLOT_INSETS, nil, { backing = false })
        if g and g.top then g.top:SetFrameLevel(glass:GetFrameLevel()) end
        shared.sort = glass
    end
end

local function styleShared(kit)
    local box = tbl(rawget(_G, "BagItemSearchBox"))
    if box then
        for _, key in ipairs(EDGES) do kit:Fade(kit:Child(box, key)) end
    end
end

GUI.Engine.Register({
    key = "bags",
    title = "Bags",
    risk = "plain",
    live = true,
    backing = "window",
    -- A bag replacement owns the windows: we step aside (EllesmereUIBags
    -- reparents them, EUI_Bags_Start.lua:530; Bagnon on SetID).
    owners = { "Bagnon", "Baganator", "AdiBags", "ArkInventory", "BetterBags", "EllesmereUIBags" },
    frames = windows,
    install = function(kit, frame)
        local win, wg, backing = kit:Panel(frame)
        local h = { kit = kit, frame = frame }
        wins[frame] = h
        kit:Header(win, wg, backing, win, "TOP", -HEADER_H, h)
        h.disc = kit:PortraitDisc(frame, { ring = DISC_RING, width = PORTRAIT_WIDTH, onPortrait = true })
        kit:CloseButton(tbl(frame.CloseButton), h)
        local m = moneyOf(frame)
        local border = m and tbl(m.Border)
        if border then
            h.moneyFrame = m
            h.money = kit:Section(win)
            h.money.fill:SetAllPoints(border)
            local function relay()
                if GUI.Engine.Active("bags") then GUI.Engine.Run(kit.skin, "money", money, h) end
            end
            m:HookScript("OnShow", relay)
            m:HookScript("OnHide", relay)
        end
        installShared(kit)
        -- Blizzard fills the window's buttons here, pooled and asynchronous
        -- (ContainerFrame.lua:1164, 1191); the combined window inherits it.
        hooksecurefunc(frame, "UpdateItems", function(f)
            if GUI.Engine.Active("bags") then GUI.Engine.Run(kit.skin, "items", styleItems, kit, f) end
        end)
    end,
    style = function(kit, frame)
        kit:FlatShell(frame)
        kit:CloseFades(tbl(frame.CloseButton))
        local h = wins[frame]
        local m = moneyOf(frame)
        local border = m and tbl(m.Border)
        if border then
            for _, key in ipairs(EDGES) do kit:Fade(kit:Child(border, key)) end
        end
        styleShared(kit)
        if h then
            Kit.PlaceHeader(h)
            Kit.CloseSync(h)
            money(h)
        end
        styleItems(kit, frame)
    end,
})

GUI.Bags = {}

-- The probe's live tuning of the header band (not saved).
function GUI.Bags.SetHeaderHeight(n)
    if type(n) ~= "number" or n < 0 then return false end
    HEADER_H = n
    for _, h in pairs(wins) do
        h.boundaryY = -n
        if GUI.Engine.Active("bags") then API.Try("bags:header", Kit.PlaceHeader, h) end
    end
    return true
end

function GUI.Bags.HeaderHeight() return HEADER_H end

GUI.Bags._test = { wins = wins, slots = slots, shared = shared, HEADER_H = HEADER_H, DISC_RING = DISC_RING,
                   PORTRAIT_WIDTH = PORTRAIT_WIDTH, SLOT_INSETS = SLOT_INSETS }
