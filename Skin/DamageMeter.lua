-- Skin/DamageMeter.lua: Blizzard's damage meter (#49, docs/DAMAGE-METER.md).
--
-- Blizzard_DamageMeter loads at startup on Forever. DamageMeter, an Edit Mode
-- system, holds up to three session windows, made on first use by
-- DamageMeter:SetupSessionWindow (DamageMeter.lua:284, wow-ui-source forever,
-- 70450). Nothing in it is protected, and none of its textures ignores
-- SetAlpha (SkinProbe DM.1, 70450).
--
-- Per window, three panels of our own: the body, under MinimizeContainer so it
-- hides with a minimized window; a strip under the header, which a minimized
-- window keeps; and the breakdown, under SourceWindow (strata HIGH). Their
-- art is faded: the header bar, the background, the breakdown's background.
-- The bars, the buttons, the resize handle, the scroll bars and every font stay
-- stock (the owner, 2026-10-19), except each window's title ("Damage Done"),
-- which wears the suite accent: the owner's audited exception (#71,
-- docs/PLAN.md "The accent on Blizzard's titles"). Blizzard only sets its text
-- (DamageMeterSessionWindow.lua:804); its gold is GameFontNormalMed1's.
--
-- Windows are found by the names Blizzard gives them, on every style pass, so
-- one made while the skin was off is skinned when it comes back on. Calling
-- the mixin's ForEachSessionWindow would break the skin contract.
--
-- The body's glass follows the Edit Mode Background setting, which Blizzard
-- applies as the background's alpha (UpdateBackground): Fade hands us its
-- latest value. Transparency is the window's own alpha, and our panels, its
-- children, follow it with no code.

local GUI = GlassUI

-- MAX_DAMAGE_METER_SESSION_WINDOWS, a local in DamageMeter.lua.
local MAX_WINDOWS = 3
-- The Background setting at which the body has its full glass: Blizzard's
-- default, 50%. Below it the glass fades out with the setting. To be tuned in
-- game.
local FULL_AT = 0.5

local panels = setmetatable({}, { __mode = "k" })   -- window -> { body =, header =, source = }

local function windows()
    local out = {}
    for i = 1, MAX_WINDOWS do
        -- Not made yet is normal: no failure recorded.
        local w = rawget(_G, "DamageMeterSessionWindow" .. i)
        if type(w) == "table" then out[#out + 1] = w end
    end
    return out
end

local function build(kit, w)
    local p = {}
    local mc = kit:Child(w, "MinimizeContainer")
    local header = kit:Child(w, "Header")
    local source = mc and kit:Child(mc, "SourceWindow")
    if mc then p.body = kit:Panel(mc) end
    if header then p.header = kit:Panel(w, "small", nil, header) end
    if source then p.source = kit:Panel(source) end
    panels[w] = p
end

-- The window's title in the accent (#71): TypeName only, never a bar's name.
local function title(kit, w)
    local dd = kit:Child(w, "DamageMeterTypeDropdown")
    local fs = dd and kit:Child(dd, "TypeName")
    if not fs then return end
    local c = GUI.Suite.Accent() or { 1, 0.82, 0 }
    kit:TextColor(fs, c[1], c[2], c[3])
end

local function styleWindow(kit, w)
    if not panels[w] then build(kit, w) end
    local body = panels[w].body
    kit:Fade(kit:Child(w, "Header"))
    title(kit, w)
    local mc = kit:Child(w, "MinimizeContainer")
    if not mc then return end
    kit:Fade(kit:Child(mc, "Background"), function(alpha)
        if body then body:SetAlpha(math.min(1, alpha / FULL_AT)) end
    end)
    local source = kit:Child(mc, "SourceWindow")
    if source then kit:Fade(kit:Child(source, "Background")) end
end

local function styleAll(kit)
    for _, w in ipairs(windows()) do styleWindow(kit, w) end
end

GUI.Engine.Register({
    key = "meter",
    title = "Damage meter",
    risk = "plain",
    live = true,
    frames = function() return rawget(_G, "DamageMeter") end,
    install = function(kit, meter)
        -- A window made or shown again later (a hidden secondary window comes
        -- back through it, DamageMeter.lua:385). Hooks can't be removed.
        hooksecurefunc(meter, "SetupSessionWindow", function()
            if GUI.Engine.Active("meter") then GUI.Engine.Run(kit.skin, "window", styleAll, kit) end
        end)
        -- The accent changed (#71): every window's title, live, in combat too
        -- (nothing here is protected, SkinProbe DM.1).
        EventRegistry:RegisterCallback(GUI.Suite.LOOK_EVENT, function()
            if not GUI.Engine.Active("meter") then return end
            GUI.Engine.Run(kit.skin, "accent", function()
                for _, w in ipairs(windows()) do title(kit, w) end
            end)
        end, {})
    end,
    style = function(kit) styleAll(kit) end,
})
