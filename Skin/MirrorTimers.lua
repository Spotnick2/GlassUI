-- Skin/MirrorTimers.lua: the breath, fatigue and feign death timers (#184,
-- docs/MIRROR-TIMERS.md).
--
-- MirrorTimerContainer (Blizzard_MirrorTimer, Mainline/MirrorTimer.xml;
-- forever 70938) is an Edit Mode system under UIParent, always loaded. It
-- holds three timer frames (mirrorTimers, MirrorTimerTemplate): a StatusBar,
-- TextBorder and an unnamed background behind it, the label (Text) and the
-- castbar Border. Setup re-applies the bar's atlas on every start
-- (MirrorTimer.lua: SetStatusBarTexture), so the fill's tint is re-applied
-- after the container's SetupTimer.
--
-- Glass Unit Frames draws its own timers (#151 there) and hides Blizzard's
-- container while it does: Blizzard's never show then, and there's nothing to
-- skin (the owner, 2026-11-14: no owner, no yield).
--
-- Per frame: a small glass pill under the bar and the label, a recessed track
-- under the bar; the frame's own textures faded; the fill tinted Glass Unit
-- Frames' colours (its Mirror.COLORS) so the timers look the same whichever
-- addon draws them. Kept Blizzard's: the label, the values, the frames' size,
-- points and layout (Edit Mode's). Edit Mode resets nothing, so an idle
-- preview keeps the last timer's tint (Codex r1).

local GUI = GlassUI
local API = GUI.API
local Kit = GUI.Kit

-- Glass Unit Frames' Mirror.COLORS (#151 there), by Blizzard's timer name.
local COLORS = {
    BREATH = { 0.25, 0.55, 1.00 }, EXHAUSTION = { 0.95, 0.74, 0.22 },
    FEIGNDEATH = { 0.95, 0.60, 0.20 }, DEATH = { 0.75, 0.75, 0.75 },
}
-- The pill around the bar and the label box (TextBorder: the bar's top to 14
-- px under it), in px inward: negative, outward. To be tuned in game.
local PAD = { -4, -3, -4, -2 }

local pills = setmetatable({}, { __mode = "k" })   -- a timer frame -> { glass, g, track }

local function tbl(v) return type(v) == "table" and v or nil end

-- The frame's own textures (never its children's): TextBorder, the unnamed
-- background, Border. By structure, never by path.
local function textures(f)
    local out = {}
    local ok, regions = pcall(function() return { f:GetRegions() } end)
    if not ok then return out end
    for _, r in ipairs(regions) do
        local okT, t = pcall(r.GetObjectType, r)
        if okT and API.Plain(t) == "Texture" then out[#out + 1] = r end
    end
    return out
end

local function frames()
    local c = rawget(_G, "MirrorTimerContainer")
    local list = c and tbl(c.mirrorTimers)
    if not list then return end
    return unpack(list)
end

-- The fill in its timer's colour; no timer (Edit Mode) or an unknown name:
-- left as it is. The timer's name is the frame's own field, read only.
local function tint(kit, f)
    local bar = tbl(f.StatusBar)
    local c = COLORS[API.Plain(f.timer)]
    if not bar or not c then return end
    local ok, fill = pcall(bar.GetStatusBarTexture, bar)
    if ok and tbl(fill) then kit:Tint(fill, c[1], c[2], c[3]) end
end

local function build(kit, f)
    local bar = tbl(f.StatusBar)
    local glass, g = kit:Panel(f, "small", PAD, tbl(f.TextBorder) or bar or f)
    -- Under the bar (its OnLoad lowered it to the frame's level) and the
    -- label, the rim too: LibGlass makes it 10 up.
    local level = math.max(0, (bar and bar:GetFrameLevel() or f:GetFrameLevel()) - 1)
    glass:SetFrameLevel(level)
    if g and g.top then g.top:SetFrameLevel(level) end
    local track
    if bar then
        track = kit:Section(glass)
        track.fill:SetAllPoints(bar)
        Kit.ShowSection(track, true)
    end
    pills[f] = { glass = glass, g = g, track = track }
end

GUI.Engine.Register({
    key = "mirror",
    title = "Breath and fatigue timers",
    risk = "plain",
    live = true,
    frames = frames,
    install = function(kit, f)
        build(kit, f)
        -- Once for the skin: every start, a restart while shown (no OnShow)
        -- and PLAYER_ENTERING_WORLD's go through SetupTimer, after Setup's
        -- atlas. A hook on the instance; a missing one is recorded.
        if kit.setupHooked then return end
        kit.setupHooked = true
        local c = rawget(_G, "MirrorTimerContainer")
        if not (c and type(c.SetupTimer) == "function") then
            return API.Fail("missing:mirror:SetupTimer", "no SetupTimer on this build")
        end
        hooksecurefunc(c, "SetupTimer", function()
            if not GUI.Engine.Active("mirror") then return end
            GUI.Engine.Run(kit.skin, "setup", function()
                for _, t in ipairs({ frames() }) do tint(kit, t) end
            end)
        end)
    end,
    style = function(kit, f)
        for _, t in ipairs(textures(f)) do kit:Fade(t) end
        tint(kit, f)
    end,
})

GUI.MirrorTimers = { _test = { pills = pills, COLORS = COLORS, PAD = PAD } }
