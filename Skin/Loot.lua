-- Skin/Loot.lua: the loot window and the loot roll history (#105,
-- docs/LOOT.md), from the window template (merchant #86 ... map #99) and the
-- owner's stock screenshots.
--
-- LootFrame (Blizzard_UIPanels_Game, Mainline/LootFrame.xml:116; forever
-- 70450) is an area-left UI panel: LOOT_OPENED -> Open builds its list, then
-- ShowUIPanel, and the panel manager refuses in combat when the calling code
-- is tainted (UIParentPanelManager.lua:853-858). So, as the map: the show is
-- deferred a frame (defer = true) and the list's hook only schedules. Master
-- loot reads LootFrame.selected* (GroupLootFrame.lua:263-293): never written.
-- GroupLootHistoryFrame (/loot; Blizzard_FrameXML, Mainline/LootHistory.xml
-- :193) is a plain SetShown frame, no protected call.
--
-- Both: the window glass on the floor, a smoky title band down to the list,
-- the close button on its disc; each row on glass, its plates faded. Kept
-- Blizzard's: icons, quality borders and colours, the "Common" tag's text,
-- the quest mark, the roll texts, the dropdown, the timer, the resize handle,
-- the empty text, the scroll bar and the list's shadows.

local GUI = GlassUI
local API = GUI.API
local Kit = GUI.Kit

local ROW_INSETS = { 0, 0, 0, 0 }
-- The shell's own textures (NineSliceLayouts, FlatPanelBackgroundTemplate,
-- SharedUIPanelTemplates.xml:404-433), faded as well as their two frames, as
-- Ellesmere does.
--
-- #109 (SkinProbe lootshell and loottimeline, 70450): a fade applied while
-- the window's or a row's ShowAnim plays (setToFinalAlpha) is undone by the
-- time it ends, past the SetAlpha hook; Fade's read-back was 0 and its record
-- intact. The same Fade on the settled window holds, through every later
-- open too. So each pass runs again once those animations have finished
-- (afterAnims), read through IsPlaying, a getter: no hook on them.
local NINE_PIECES = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "TopEdge",
                      "BottomEdge", "LeftEdge", "RightEdge", "Center" }
local BG_PIECES = { "BottomLeft", "BottomRight", "BottomEdge", "TopSection" }

-- How long to wait for the show animations (0.1 s each, ScrollingFlatPanel.xml
-- :35, LootFrame.xml:58): a time, not a frame count (Codex on #110: 30 frames
-- pass in under 0.1 s at 300 fps).
local SETTLE_SECONDS = 0.5

local wins = setmetatable({}, { __mode = "k" })   -- a window -> our pieces
local rows = setmetatable({}, { __mode = "k" })   -- a pooled row -> { glass, g }

local function tbl(v) return type(v) == "table" and v or nil end

-- hooksecurefunc on an instance method; the hook only schedules `fn` a frame
-- later (Engine.Defer checks the skin's generation). A missing method (another
-- build) is recorded, not fatal.
local function schedule(kit, obj, method, what, fn)
    if type(obj) ~= "table" or type(obj[method]) ~= "function" then
        return API.Fail("missing:" .. kit.key .. ":" .. what, "no " .. method .. " on this build")
    end
    hooksecurefunc(obj, method, function()
        if GUI.Engine.Active(kit.key) then GUI.Engine.Defer(kit.skin, what, fn) end
    end)
end

-- A row's glass once, at `level` (its rim there too: LibGlass makes it 10 up),
-- parented to the row so it shows, hides, fades and slides with it.
local function rowGlass(kit, row, level)
    if rows[row] then return end
    local glass, g = kit:Panel(row, "small", ROW_INSETS, nil, { backing = false })
    glass:SetFrameLevel(math.max(0, level))
    if g and g.top then g.top:SetFrameLevel(glass:GetFrameLevel()) end
    rows[row] = { glass = glass, g = g }
end

-- The list's rows, by structure among its ScrollTarget's children.
local function eachRow(frame, fn)
    local sb = tbl(frame.ScrollBox)
    local target = sb and tbl(sb.ScrollTarget)
    if not target then return end
    for _, row in ipairs({ target:GetChildren() }) do fn(row) end
end

local function playing(anim)
    if type(anim) ~= "table" or type(anim.IsPlaying) ~= "function" then return false end
    local ok, on = pcall(anim.IsPlaying, anim)
    return ok and API.Plain(on) == true
end

-- The window's ShowAnim (ScrollingFlatPanel.xml:35) or a shown row's
-- (LootFrame.xml:58) still playing.
local function animating(frame)
    if playing(frame.ShowAnim) then return true end
    local any = false
    eachRow(frame, function(row) if row:IsShown() and playing(row.ShowAnim) then any = true end end)
    return any
end

-- `fn` again once the show animations have finished, checked a frame at a
-- time (Engine.Defer: the skin's generation checked), or after SETTLE_SECONDS
-- if one never stops; nothing when none plays.
local function afterAnims(kit, frame, fn, started)
    if animating(frame) and (not started or GetTime() - started < SETTLE_SECONDS) then
        local t0 = started or GetTime()
        GUI.Engine.Defer(kit.skin, "settle", function() afterAnims(kit, frame, fn, t0) end)
    elseif started then
        fn()
    end
end

-- A loot row (LootFrame.xml:7-115): an item or money element has a NameFrame
-- (and a BorderFrame), the empty slot neither. Its plate (quality-tinted on
-- every Init: alpha holds), edge and rarity tag faded; the gold hover and
-- press strokes white (Show/Hide only); the slot frame faded (its vertex
-- colour re-set on Init: alpha holds). Glass at the row's level - 1, under
-- its Item (useParentLevel).
local function lootRow(kit, row)
    if not tbl(row.NameFrame) then return end
    rowGlass(kit, row, row:GetFrameLevel() - 1)
    kit:Fade(row.NameFrame)
    kit:Fade(tbl(row.BorderFrame))
    kit:Fade(tbl(row.QualityStripe))
    kit:Tint(tbl(row.HighlightNameFrame), 1, 1, 1)
    kit:Tint(tbl(row.PushedNameFrame), 1, 1, 1)
    local item = tbl(row.Item)
    if item then
        local ok, normal = pcall(item.GetNormalTexture, item)
        if ok then kit:Fade(tbl(normal)) end
    end
end

-- A history row (LootHistory.xml:3-145): its BackgroundArtFrame (level 400)
-- holds the plate and the edge, never re-set; passed headers and padding
-- have none. Glass at the art's level - 1 (399): under the roll-100 effect
-- (PerfectRollFrame, 450) and the item and text (500).
local function historyRow(kit, row)
    local art = tbl(row.BackgroundArtFrame)
    if not art then return end
    rowGlass(kit, row, art:GetFrameLevel() - 1)
    kit:Fade(tbl(art.NameFrame))
    kit:Fade(tbl(art.BorderFrame))
end

-- The shell both share (DefaultPanelFlatTemplate): the NineSlice and its
-- pieces (the bottom corners re-cropped with SetTexture on every Resize:
-- alpha holds, a blank wouldn't), the Bg frame and its pieces, the close
-- button's states.
local function fadeAll(kit, host, keys)
    if not host then return end
    kit:Fade(host)
    for _, key in ipairs(keys) do kit:Fade(tbl(host[key])) end
end

local function shell(kit, frame)
    fadeAll(kit, tbl(frame.NineSlice), NINE_PIECES)
    fadeAll(kit, tbl(frame.Bg), BG_PIECES)
    kit:CloseFades(tbl(frame.ClosePanelButton))
end

local function build(kit, frame)
    local win, wg, backing = kit:Panel(frame)
    local h = { kit = kit, frame = frame }
    wins[frame] = h
    local list = tbl(frame.ScrollBox)
    kit:Header(win, wg, backing, list or win, "TOP", list and 0 or -24, h)
    kit:CloseButton(tbl(frame.ClosePanelButton), h)
    return h
end

local function finish(frame)
    local h = wins[frame]
    if h then
        Kit.PlaceHeader(h)
        Kit.CloseSync(h)
    end
end

GUI.Engine.Register({
    key = "loot",
    title = "Loot window",
    risk = "plain",
    defer = true,
    live = true,
    backing = "window",
    frames = function() return rawget(_G, "LootFrame") end,
    install = function(kit, frame)
        build(kit, frame)
        local function rows() eachRow(frame, function(row) lootRow(kit, row) end) end
        schedule(kit, tbl(frame.ScrollBox), "Update", "rows", function()
            rows()
            afterAnims(kit, frame, rows)
        end)
    end,
    style = function(kit, frame)
        local function pass()
            shell(kit, frame)
            eachRow(frame, function(row) lootRow(kit, row) end)
        end
        pass()
        finish(frame)
        afterAnims(kit, frame, pass)
    end,
})

GUI.Engine.Register({
    key = "loothistory",
    title = "Loot rolls (/loot)",
    risk = "plain",
    live = true,
    backing = "window",
    frames = function() return rawget(_G, "GroupLootHistoryFrame") end,
    install = function(kit, frame)
        build(kit, frame)
        schedule(kit, tbl(frame.ScrollBox), "Update", "rows", function()
            eachRow(frame, function(row) historyRow(kit, row) end)
        end)
    end,
    style = function(kit, frame)
        shell(kit, frame)
        eachRow(frame, function(row) historyRow(kit, row) end)
        finish(frame)
    end,
})

GUI.Loot = { _test = { wins = wins, rows = rows, NINE_PIECES = NINE_PIECES, BG_PIECES = BG_PIECES,
                       SETTLE_SECONDS = SETTLE_SECONDS } }
