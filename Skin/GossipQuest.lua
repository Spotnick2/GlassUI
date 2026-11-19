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

-- Blizzard's three pieces carry the button's state (UIPanelButtonTemplate
-- re-textures them on press and on disable), and they're faded: so the state
-- is on our glass (Codex on #201). Disabled (Accept while the text types,
-- Continue on an incomplete quest): the glass at BUTTON_OFF. Held down: a
-- white light on it.
local BUTTON_OFF, PRESS_LIGHT = 0.4, 0.15

local function enabled(b)
    local ok, on = pcall(b.IsEnabled, b)
    return not ok or API.Plain(on) ~= false
end

local function feedback(st, pressed)
    local on = enabled(st.button)
    st.glass:SetAlpha(on and 1 or BUTTON_OFF)
    st.press:SetShown(on and pressed == true)
end

local function pushedNow(b)
    local ok, state = pcall(b.GetButtonState, b)
    return ok and API.Plain(state) == "PUSHED"
end

-- A button's glass is its child, so it hides with the button (Decline under
-- auto-accept, the gamepad's hidden buttons).
local function installButton(kit, b)
    if buttons[b] then return end
    local glass, g = glassAt(kit, b, b:GetFrameLevel() - 1)
    local press = glass:CreateTexture(nil, "ARTWORK")
    press:SetAllPoints(glass)
    press:SetColorTexture(1, 1, 1, PRESS_LIGHT)
    if g and g.mask then press:AddMaskTexture(g.mask) end
    press:Hide()
    local st = { glass = glass, g = g, kit = kit, button = b, press = press }
    buttons[b] = st
    local function now(pressed)
        if GUI.Engine.Active(kit.key) then GUI.Engine.Run(kit.skin, "button", feedback, st, pressed) end
    end
    -- Enable/Disable come inside a panel's show: read again a frame later.
    local function later()
        if GUI.Engine.Active(kit.key) then
            GUI.Engine.Defer(kit.skin, "button", function() feedback(st, pushedNow(b)) end)
        end
    end
    b:HookScript("OnMouseDown", function() now(true) end)
    b:HookScript("OnMouseUp", function() now(false) end)
    b:HookScript("OnEnable", later)
    b:HookScript("OnDisable", later)
    -- Hidden before its mouse-up (a panel changed while it was held): no
    -- press left over, as UIPanelButton_OnShow resets Blizzard's art
    -- (SecureUIPanelTemplates.lua:60-66; Codex on #201).
    local function released()
        if GUI.Engine.Active(kit.key) then
            GUI.Engine.Defer(kit.skin, "button", function() feedback(st, false) end)
        end
    end
    b:HookScript("OnHide", released)
    b:HookScript("OnShow", released)
end

local function styleButton(kit, b)
    for _, key in ipairs(BUTTON_ART) do kit:Fade(kit:Child(b, key)) end
    local ok, hl = pcall(b.GetHighlightTexture, b)
    if ok and tbl(hl) then kit:Tint(hl, 1, 1, 1, HOVER) end
    feedback(buttons[b], pushedNow(b))
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
        -- The shell's on 70938 (GQ.1: QuestFrame's own ARTWORK texture stays
        -- empty): its container's disc. Should the global move to QuestFrame's
        -- own texture: a disc under the window's regions, the window glass one
        -- lower still.
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

--------------------------------------------------------------------------------
-- The quest details popup (#202, docs/QUEST-POPUP.md): QuestLogPopupDetailFrame
-- (QuestMapFrame.xml:311), the objective tracker's details. It inherits both
-- ButtonFrameTemplate and QuestFramePanelTemplate, and both name a texture
-- parentKey "Bg": the shell's rock and the panel's page. So kit:Shell (which
-- fades .Bg) is never called on it, and both are found by structure.
--
-- Its text is repainted without its page: QuestMapFrame_DoFullUpdate calls
-- Update (QuestInfo_Display, by the setting as it is then) while the page is
-- only set in ShowQuest. So the page follows what Blizzard last painted:
-- Update's instance hook records it, and the page fades only while it is the
-- dark one AND that paint was light. Unknown (the skin was off): kept.
--------------------------------------------------------------------------------

local POPUP_BUTTONS = { "AbandonButton", "TrackButton", "ShareButton" }
local popup = { paintLight = nil, hooked = false }   -- what Blizzard last painted

local function near(a, b) return type(a) == "number" and math.abs(a - b) < 0.5 end

-- A texture's draw layer and sublevel, and its points as { point, x, y }.
local function shape(t)
    local okL, layer, sub = pcall(t.GetDrawLayer, t)
    local okN, n = pcall(t.GetNumPoints, t)
    local pts = {}
    for i = 1, (okN and API.Plain(n)) or 0 do
        local ok, p, _, _, x, y = pcall(t.GetPoint, t, i)
        if ok then pts[i] = { API.Plain(p), API.Plain(x), API.Plain(y) } end
    end
    return okL and API.Plain(layer) or nil, okL and API.Plain(sub) or nil, pts
end

-- The page: .Bg, BACKGROUND, at 7,-62, a QuestBG atlas (QuestFrameTemplates.xml:9).
local function pageOf(frame)
    local bg = tbl(frame.Bg)
    if not bg then return nil end
    local layer, _, pts = shape(bg)
    local ok, atlas = pcall(bg.GetAtlas, bg)
    atlas = ok and API.Plain(atlas) or nil
    local p = pts[1]
    if layer == "BACKGROUND" and #pts == 1 and p[1] == "TOPLEFT" and near(p[2], 7) and near(p[3], PAGE_TOP)
        and type(atlas) == "string" and atlas:find("^QuestBG") then
        return bg
    end
    return nil
end

-- The rock: the one direct BACKGROUND -6 texture at 2,-21 and -2,2
-- (SharedUIPanelTemplates.xml:689-695). None, or two: nil.
local function rockOf(frame, page)
    local found
    local ok, regions = pcall(function() return { frame:GetRegions() } end)
    for _, r in ipairs(ok and regions or {}) do
        local okT, objType = pcall(r.GetObjectType, r)
        if r ~= page and okT and API.Plain(objType) == "Texture" then
            local layer, sub, pts = shape(r)
            if layer == "BACKGROUND" and sub == -6 and #pts == 2 then
                local tl, br
                for _, p in ipairs(pts) do
                    if p[1] == "TOPLEFT" and near(p[2], 2) and near(p[3], -21) then tl = true end
                    if p[1] == "BOTTOMRIGHT" and near(p[2], -2) and near(p[3], 2) then br = true end
                end
                if tl and br then
                    if found then return nil end
                    found = r
                end
            end
        end
    end
    return found
end

-- The book icon: the direct OVERLAY -1 texture, 64 px (QuestMapFrame.xml:314).
local function bookOf(frame)
    local ok, regions = pcall(function() return { frame:GetRegions() } end)
    for _, r in ipairs(ok and regions or {}) do
        local okT, objType = pcall(r.GetObjectType, r)
        if okT and API.Plain(objType) == "Texture" then
            local layer, sub = shape(r)
            local okW, w = pcall(r.GetWidth, r)
            if layer == "OVERLAY" and sub == -1 and okW and near(API.Plain(w), 64) then return r end
        end
    end
    return nil
end

local function decidePopup(kit, h)
    if not decide(kit, h, h.page, popup.paintLight == true) then
        Kit.ShowSection(h.pane, false)
        h.paneOn = nil
    end
end

local popupSkin
-- Two instance hooks, on from the skin's attach (its frames call at login),
-- so ShowQuest's first Update, which runs before ShowUIPanel, is seen. They
-- style nothing: they record the paint and schedule a decision, and only
-- once the popup's pieces exist (Codex on #202, r2).
local function hookPopup(frame)
    if popup.hooked then return end
    popup.hooked = true
    if type(frame.Update) == "function" then
        hooksecurefunc(frame, "Update", function()
            if not GUI.Engine.Active("questpopup") then return end
            local QT = GUI.QuestText
            popup.paintLight = QT and QT.LightText() or false
            local h = wins[frame]
            if h then GUI.Engine.Defer(popupSkin, "page", function() decidePopup(h.kit, h) end) end
        end)
    end
    local page = pageOf(frame)
    if page then
        -- The page set (ShowQuest): only a decision, never the paint (Codex r2).
        hooksecurefunc(page, "SetAtlas", function()
            if not GUI.Engine.Active("questpopup") then return end
            local h = wins[frame]
            if h then GUI.Engine.Defer(popupSkin, "page", function() decidePopup(h.kit, h) end) end
        end)
    end
end

popupSkin = GUI.Engine.Register({
    key = "questpopup",
    title = "Quest details popup",
    risk = "plain",
    defer = true,
    live = true,
    backing = "window",
    frames = function()
        local f = rawget(_G, "QuestLogPopupDetailFrame")
        if tbl(f) then hookPopup(f) end
        return f
    end,
    install = function(kit, frame)
        local book = bookOf(frame)
        if not book then API.Fail("missing:questpopup:book", "the book icon not found by structure") end
        -- The book is the popup's own texture: #201's own-texture path, the
        -- disc under the window's regions, the window glass one lower.
        local h = installWindow(kit, frame, book)
        h.page = pageOf(frame)
        if not h.page then API.Fail("missing:questpopup:page", ".Bg isn't the page on this build") end
        h.rock = rockOf(frame, h.page)
        if not h.rock then API.Fail("missing:questpopup:rock", "the rock: none or two by structure") end
        for _, key in ipairs(POPUP_BUTTONS) do
            local b = kit:Child(frame, key)
            if tbl(b) then installButton(kit, b) end
        end
    end,
    style = function(kit, frame)
        local h = wins[frame]
        if not h then return end
        -- Not kit:Shell: its .Bg is the page here.
        kit:Fade(kit:Child(frame, "NineSlice"))
        kit:Fade(kit:Child(frame, "TopTileStreaks"))
        kit:Inset(kit:Child(frame, "Inset"))
        kit:Fade(h.rock)
        kit:CloseFades(tbl(frame.CloseButton))
        for b, st in pairs(buttons) do
            if st.kit == kit then styleButton(kit, b) end
        end
        Kit.PlaceHeader(h)
        Kit.CloseSync(h)
        decidePopup(kit, h)
    end,
    -- Off: the hooks can't record, so the paint is unknown when on again.
    restored = function() popup.paintLight = nil end,
})

GUI.GossipQuest = { _test = { wins = wins, buttons = buttons, DARK = DARK, HOVER = HOVER, PAGE_TOP = PAGE_TOP,
                              BUTTON_OFF = BUTTON_OFF, PRESS_LIGHT = PRESS_LIGHT,
                              PANELS = PANELS, QUEST_BUTTONS = QUEST_BUTTONS, popup = popup,
                              pageOf = pageOf, rockOf = rockOf, bookOf = bookOf } }
