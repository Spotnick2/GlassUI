-- Theme.lua: the looks of the glass, repainted live (Glass Quest Tracker's and
-- Glass MiniMap's Theme.lua).
--
-- clear   GlassMail's clear body: the material's cool tint, a faint wash
-- smoked  AltStable's darker body (its numbers, as GlassPanel and GlassMail use them)
-- class   the clear body tinted by the player's class colour, shaded by
--         classShade. The class colour may be unreadable early in a login; the
--         surfaces then stay clear and PLAYER_ENTERING_WORLD paints them again.
--
-- No "stock" theme: stock is the master switch off (docs/PLAN.md, "Theme").
--
-- A window's glass is a reading surface: item names and prices have to read
-- over bright terrain. GlassMail's lesson (owner's screenshots, 2026-10-11):
-- the body alone let a bright quest tracker read through, so every panel has
-- an opaque backing under the tint, at the theme's opacity. Clear's started at
-- 0.85, which made clear and smoked read alike (#17); on the merchant (#4,
-- 70425) the owner compared 0.85, 0.6 and 0.35: all read well, and 0.35 looks
-- the most like glass. Smoked stays dense for bright scenery.
--
-- Only body regions are repainted (tint, wash, backing); rims are the
-- material's. The wash is a gradient, which ignores SetAlpha on this client
-- (SkinProbe W1.6, 70374): it is painted with LibGlass r7's SetWash.

GlassUI = GlassUI or {}
local GUI = GlassUI
local API = GUI.API
local Glass = GUI.Glass
local Theme = {}
GUI.Theme = Theme

Theme.NAMES = { "clear", "smoked", "class" }
Theme.LABELS = { clear = "Clear glass", smoked = "Smoked glass", class = "Class colour glass" }
Theme.PRESETS = {
    clear  = { tint = { 0.13, 0.16, 0.22, 0.24 }, wash = 0.18, backing = 0.35 },
    smoked = { tint = { 0.05, 0.06, 0.08, 0.62 }, wash = 0.14, backing = 0.92 },
    class  = { classShade = 0.6, wash = 0.18, backing = 0.35 },
}
Theme.BACKING = { 0.04, 0.05, 0.07 }

local surfaces = {}   -- { g = LibGlass regions, backing = our texture }
Theme.pending = false

function Theme.IsValid(name) return Theme.PRESETS[name] ~= nil end

function Theme.Name()
    local name = GUI.db and GUI.db.theme
    return Theme.PRESETS[name] and name or "clear"
end

-- The tint for this theme as { r, g, b[, a] }, or nil for the surface's
-- built tint. Second return: false while the class colour is wanted but
-- unreadable.
local function tintFor(name)
    local p = Theme.PRESETS[name]
    if name == "class" then
        local r, g, b = API.ClassColor()
        if not r then return nil, false end
        return { r * p.classShade, g * p.classShade, b * p.classShade }, true
    end
    return p.tint, true
end

local function paint(s, name, tint)
    local p = Theme.PRESETS[name]
    if tint then
        Glass.SetSurfaceTint(s.g, tint[1], tint[2], tint[3], tint[4])
    else
        Glass.SetSurfaceTint(s.g)
    end
    Glass.SetWash(s.g, p.wash)
    if s.backing then
        local c = Theme.BACKING
        s.backing:SetColorTexture(c[1], c[2], c[3], p.backing)
    end
end

-- Add a surface (and the backing under it) and paint it with the current theme.
function Theme.Register(g, backing)
    if type(g) ~= "table" or not g.tint then return end
    local s = { g = g, backing = backing }
    surfaces[#surfaces + 1] = s
    local name = Theme.Name()
    API.Try("theme:paint", paint, s, name, (tintFor(name)))
end

-- Repaint every surface. Returns false while the class colour is unreadable.
function Theme.Refresh()
    local name = Theme.Name()
    local tint, known = tintFor(name)
    for _, s in ipairs(surfaces) do API.Try("theme:paint", paint, s, name, tint) end
    Theme.pending = not known
    return known
end

function Theme.Set(name)
    if not Theme.IsValid(name) then return false end
    GUI.db.theme = name
    Theme.Refresh()
    return true
end

-- PLAYER_ENTERING_WORLD: the class colour can be read by now.
function Theme.Retry()
    if Theme.pending or Theme.Name() == "class" then Theme.Refresh() end
end

Theme._test = { surfaces = surfaces }
