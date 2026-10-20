-- Skin/GameMenu.lua: the Escape menu (#90, docs/GAME-MENU.md), from the
-- window template (the merchant #86, the bags #88) and the owner's mockup.
--
-- GameMenuFrame (Blizzard_GameMenu, MainMenuFrameTemplate, wow-ui-source
-- forever 70450): a UI panel Blizzard shows and hides, its buttons rebuilt
-- from a pool on every show (InitButtons), each a ThreeSliceButton whose state
-- changes only swap atlases. The Esc path is taint-sensitive: an addon's call
-- ending in ToggleGameMenu makes Blizzard's Esc handler call the protected
-- SpellStopCasting (porting guide, "Closing the Settings window"). So this
-- skin never shows, hides or toggles the menu and never calls a Blizzard Lua
-- or mixin method; it only reacts to Blizzard showing it, with fades, tints
-- and our own frames.
--
-- The window glass with the floor (the dialog border faded); the title on a
-- glass tab (the header's diamond-metal art faded, its text Blizzard's);
-- each button on small glass, its red slices faded, Blizzard's own hover glow
-- tinted white. Our glass has no layoutIndex, so the menu's vertical layout
-- leaves it out (LayoutFrame.lua:22-39).

local GUI = GlassUI
local API = GUI.API

-- The header's three pieces (DialogTemplates.xml:23-32) and a button's
-- (ThreeSliceButtonTemplate.xml:22-38).
local HEADER_ART = { "LeftBG", "RightBG", "CenterBG" }
local SLICES = { "Left", "Right", "Center" }
-- The title tab's glass round the header frame, and each button's round it.
local HEADER_INSETS = { 0, 0, 0, 0 }
local BUTTON_INSETS = { 0, 0, 0, 0 }
-- Blizzard's additive hover glow, white instead of red, at this alpha.
local HOVER = 0.35

local buttons = setmetatable({}, { __mode = "k" })  -- pooled button -> { glass, g }
local menus = setmetatable({}, { __mode = "k" })    -- the menu -> { header glass }

local function tbl(v) return type(v) == "table" and v or nil end

-- Our small glass behind a Blizzard frame, its rim at its own level (under
-- the frame's text and art), no backing: the window's floor is under it.
local function glassUnder(kit, frame, insets)
    local glass, g = kit:Panel(frame, "small", insets, nil, { backing = false })
    if g and g.top then g.top:SetFrameLevel(glass:GetFrameLevel()) end
    return glass, g
end

-- A pooled menu button (its three slices, read): its glass once, then its
-- touches. Idempotent: the style pass and the InitButtons hook both call it.
local function styleButton(kit, b)
    if not buttons[b] then
        local glass, g = glassUnder(kit, b, BUTTON_INSETS)
        buttons[b] = { glass = glass, g = g }
    end
    for _, key in ipairs(SLICES) do kit:Fade(kit:Child(b, key)) end
    local ok, hl = pcall(b.GetHighlightTexture, b)
    if ok and tbl(hl) then kit:Tint(hl, 1, 1, 1, HOVER) end
end

-- Every button the menu holds now (the pool's parent is the menu,
-- MainMenuFrameTemplates.lua:14).
local function styleButtons(kit, frame)
    for _, child in ipairs({ frame:GetChildren() }) do
        if tbl(child.Left) and tbl(child.Right) and tbl(child.Center) then styleButton(kit, child) end
    end
end

GUI.Engine.Register({
    key = "gamemenu",
    title = "Game menu",
    risk = "plain",
    live = true,
    backing = "window",
    frames = function() return rawget(_G, "GameMenuFrame") end,
    install = function(kit, frame)
        kit:Panel(frame)
        local header = tbl(frame.Header)
        menus[frame] = { header = header and (glassUnder(kit, header, HEADER_INSETS)) or nil }
        -- Blizzard rebuilds the buttons on every show and on a store or trial
        -- event (GameMenuFrame.lua:69-102); the first show's ran before this.
        hooksecurefunc(frame, "InitButtons", function(f)
            if GUI.Engine.Active("gamemenu") then GUI.Engine.Run(kit.skin, "buttons", styleButtons, kit, f) end
        end)
    end,
    style = function(kit, frame)
        -- The dialog border: the NineSlice frame itself, its tiled Bg with it.
        kit:Fade(tbl(frame.Border))
        local header = tbl(frame.Header)
        if header then
            for _, key in ipairs(HEADER_ART) do kit:Fade(kit:Child(header, key)) end
        end
        styleButtons(kit, frame)
    end,
})

GUI.GameMenu = { _test = { buttons = buttons, menus = menus, HOVER = HOVER } }
