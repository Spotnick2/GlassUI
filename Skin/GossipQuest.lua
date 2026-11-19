-- Skin/GossipQuest.lua: the gossip window (#115) and the NPC quest dialog
-- (#114), docs/GOSSIP-QUEST.md, from the window template (merchant #86 ...
-- trade #113). Two switches, one recipe.
--
-- GossipFrame (Mainline/GossipFrame.xml:34; forever 70938) and QuestFrame
-- (Mainline/QuestFrame.xml:42) are area-left UI panels: shown through the
-- panel manager's secure delegate. So, as the map, loot and trade skins: the
-- show is deferred a frame (defer = true) and every hook only schedules.
--
-- The text is Blizzard's, and so is the page under it (the parchment its dark
-- text is made for), unless Blizzard itself shows its dark page (Settings,
-- Accessibility, Quest Text Contrast: Dark): then its text is light and the
-- page is faded, the text on our glass. The page decides, not the setting:
-- the quest dialog re-colours an open panel only when it next refreshes it,
-- and its page's atlas is set in the same pass as its colours. So every
-- SetAtlas on a page schedules the decision (an instance hook).
--
-- Never: a text colour or font, a field, a Blizzard method, Show/Hide, a
-- point or size on Blizzard's objects; the scroll children's alpha (Blizzard
-- fades them in), the item buttons (QuestItemTemplate's OnEnter reads their
-- alpha), the rows, QuestInfo (shared with the popup and the world map).

local GUI = GlassUI
local API = GUI.API
local Kit = GUI.Kit

-- Blizzard's dark page (QuestTextContrast.lua:22, contrast 4), the one shown
-- with its light "Stone" text. Anything else is kept: the parchments of
-- contrast 0-3 (dark text), an NPC's QuestBG-<kit>, a server material.
local DARK = "QuestBG-Parchment-Accessibility4"
-- Every page starts 62 px under the window's top (gossip's Background, each
-- quest panel's Bg: TOPLEFT 7,-62): the band's bottom.
local PAGE_TOP = -62
local PANELS = { "QuestFrameGreetingPanel", "QuestFrameDetailPanel", "QuestFrameProgressPanel",
                 "QuestFrameRewardPanel" }
local QUEST_BUTTONS = { "QuestFrameAcceptButton", "QuestFrameDeclineButton", "QuestFrameCompleteButton",
                        "QuestFrameGoodbyeButton", "QuestFrameCompleteQuestButton", "QuestFrameGreetingGoodbyeButton" }
local BUTTON_ART = { "Left", "Middle", "Right" }   -- UIPanelButtonTemplate's
local NO_INSETS = { 0, 0, 0, 0 }
-- The portrait's disc, the trade window's.
local DISC_RING, MASK_WIDTH, PORTRAIT_WIDTH = 6, 58, 60
-- Blizzard's additive button glow, white instead of gold (the trade window's).
local HOVER = 0.35

local wins = setmetatable({}, { __mode = "k" })     -- window -> our pieces
local buttons = setmetatable({}, { __mode = "k" })  -- button -> { glass, g, kit }

local function tbl(v) return type(v) == "table" and v or nil end

local function shown(f)
    local ok, v = pcall(f.IsShown, f)
    return ok and API.Plain(v) == true
end

-- Our glass under a Blizzard frame at `level`, its rim there too (the trade
-- window's). Mouse off: a plain frame.
local function glassAt(kit, frame, level)
    local glass, g = kit:Panel(frame, "small", NO_INSETS, nil, { backing = false })
    glass:SetFrameLevel(math.max(0, level))
    if g and g.top then g.top:SetFrameLevel(glass:GetFrameLevel()) end
    return glass, g
end

-- A button's glass is its child, so it hides with the button (Decline under
-- auto-accept, the gamepad's hidden buttons).
local function installButton(kit, b)
    if buttons[b] then return end
    local glass, g = glassAt(kit, b, b:GetFrameLevel() - 1)
    buttons[b] = { glass = glass, g = g, kit = kit }
end

local function styleButton(kit, b)
    for _, key in ipairs(BUTTON_ART) do kit:Fade(kit:Child(b, key)) end
    local ok, hl = pcall(b.GetHighlightTexture, b)
    if ok and tbl(hl) then kit:Tint(hl, 1, 1, 1, HOVER) end
end

local function isDark(page)
    local ok, atlas = pcall(page.GetAtlas, page)
    return ok and API.Plain(atlas) == DARK
end

-- The page (a getter only): faded while it is Blizzard's dark one, Blizzard's
-- latest alpha otherwise. Our pane under it while faded.
local function decide(kit, h, page, on)
    if on and page and isDark(page) then
        kit:Fade(page)
        h.pane.fill:ClearAllPoints()
        h.pane.fill:SetAllPoints(page)
        Kit.ShowSection(h.pane, true)
        h.paneOn = page
        return true
    end
    if page then kit:Dim(page, nil) end
    return false
end

local function decideGossip(kit, h)
    if not decide(kit, h, h.page, true) then
        Kit.ShowSection(h.pane, false)
        h.paneOn = nil
    end
end

-- The shown panel's page decides; every other page given back. One pane at
-- most, on the shown panel's page.
local function decideQuest(kit, h)
    local current
    for _, p in ipairs(h.panels) do
        if not current and shown(p.panel) then current = p end
    end
    local any = false
    for _, p in ipairs(h.panels) do
        if decide(kit, h, p.page, p == current) then any = true end
    end
    if not any then
        Kit.ShowSection(h.pane, false)
        h.paneOn = nil
    end
end

-- Each window's shared pieces: the glass and its floor, the band down to the
-- page's top, the portrait's disc, the close button, the pane (hidden).
local function installWindow(kit, frame, portrait)
    local win, wg, backing = kit:Panel(frame)
    local h = { kit = kit, frame = frame }
    wins[frame] = h
    kit:Header(win, wg, backing, win, "TOP", PAGE_TOP, h)
    if portrait == nil then
        h.disc = kit:PortraitDisc(frame, { ring = DISC_RING, width = MASK_WIDTH })
    else
        -- QuestFramePortrait names two textures (QuestFrame.xml:44-53 and the
        -- shell's $parentPortrait); QuestFrame_SetPortrait fills the global.
        -- The shell's: its container's disc. QuestFrame's own ARTWORK
        -- texture: a disc under the window's regions, the window glass one
        -- lower still (the probe measures which, docs/GOSSIP-QUEST.md).
        local pc = tbl(frame.PortraitContainer)
        if pc and portrait == pc.portrait then
            h.disc = kit:PortraitDisc(frame, { ring = DISC_RING, width = MASK_WIDTH })
        else
            local level = frame:GetFrameLevel()
            win:SetFrameLevel(math.max(0, level - 2))
            h.disc = kit:Disc(frame, portrait, { ring = DISC_RING, width = PORTRAIT_WIDTH, level = level - 1 })
        end
    end
    kit:CloseButton(tbl(frame.CloseButton), h)
    -- On the window glass: over its body, under every Blizzard region.
    h.pane = kit:Section(win)
    return h
end

local function styleWindow(kit, frame, h)
    kit:Shell(frame)
    kit:CloseFades(tbl(frame.CloseButton))
    for b, st in pairs(buttons) do
        if st.kit == kit then styleButton(kit, b) end
    end
    Kit.PlaceHeader(h)
    Kit.CloseSync(h)
end

GUI.Engine.Register({
    key = "gossip",
    title = "Gossip window",
    risk = "plain",
    defer = true,
    live = true,
    backing = "window",
    frames = function() return rawget(_G, "GossipFrame") end,
    install = function(kit, frame)
        local h = installWindow(kit, frame, nil)
        h.page = tbl(frame.Background)
        local b = tbl(frame.GreetingPanel) and tbl(frame.GreetingPanel.GoodbyeButton)
        if b then installButton(kit, b) end
        -- Gossip's theme sets the page on every Update, shown or not
        -- (AccessibilityTemplates.lua:77-81): a new texture kit, a contrast
        -- change. The decision a frame later, on the final atlas.
        if h.page then
            hooksecurefunc(h.page, "SetAtlas", function()
                if GUI.Engine.Active("gossip") then
                    GUI.Engine.Defer(kit.skin, "page", function() decideGossip(kit, h) end)
                end
            end)
        end
    end,
    style = function(kit, frame)
        local h = wins[frame]
        if not h then return end
        styleWindow(kit, frame, h)
        decideGossip(kit, h)
    end,
})

GUI.Engine.Register({
    key = "quest",
    title = "Quest dialog",
    risk = "plain",
    defer = true,
    live = true,
    backing = "window",
    frames = function() return rawget(_G, "QuestFrame") end,
    install = function(kit, frame)
        local h = installWindow(kit, frame, tbl(rawget(_G, "QuestFramePortrait")) or false)
        h.panels = {}
        local function schedule()
            if GUI.Engine.Active("quest") then
                GUI.Engine.Defer(kit.skin, "page", function() decideQuest(kit, h) end)
            end
        end
        for _, name in ipairs(PANELS) do
            local panel = kit:Global(name)
            local page = panel and kit:Child(panel, "Bg")
            if panel then
                h.panels[#h.panels + 1] = { panel = panel, page = tbl(page) }
                -- Every page re-set: each panel's OnShow (QuestFrame_SetMaterial
                -- sets the atlas every time, QuestFrame.lua:669), and the
                -- greeting's QUEST_LOG_UPDATE refresh with no OnShow (:86-91).
                -- A panel shown under a shown window comes through here too, so
                -- no OnShow hook and no CVAR_UPDATE of ours: they added nothing
                -- the tests could tell apart (mutation-tested).
                if tbl(page) then hooksecurefunc(page, "SetAtlas", schedule) end
            end
        end
        for _, name in ipairs(QUEST_BUTTONS) do
            local b = kit:Global(name)
            if b then installButton(kit, b) end
        end
    end,
    style = function(kit, frame)
        local h = wins[frame]
        if not h then return end
        styleWindow(kit, frame, h)
        decideQuest(kit, h)
    end,
})

GUI.GossipQuest = { _test = { wins = wins, buttons = buttons, DARK = DARK, HOVER = HOVER, PAGE_TOP = PAGE_TOP,
                              PANELS = PANELS, QUEST_BUTTONS = QUEST_BUTTONS } }
