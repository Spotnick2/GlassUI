-- Theme.lua: the looks of the glass, repainted live (Glass Quest Tracker's and
-- Glass MiniMap's Theme.lua). The tint is the suite look's (#67): one choice
-- for Glass UI's skins and every follower, on the "Suite look" subpage, and
-- the numbers are Suite.BODY's, which followers read through Suite.Body.
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
-- A window that opens over other UI is another case (#80, docs/MERCHANT.md):
-- over RestedXP's guide window, clear's 0.35 let its bright text read through
-- the merchant (the owner, 2026-10-20). Such a skin (Engine.Register's
-- backing = "window") gets at least WINDOW_BACKING (0.85 now); its tint,
-- wash and the backing's colour stay the body's. The tracker and the meter,
-- over the world, keep the body's.
--
-- Only body regions are repainted (tint, wash, backing); rims are the
-- material's. The wash is a gradient, which ignores SetAlpha on this client
-- (SkinProbe W1.6, 70374): it is painted with LibGlass r7's SetWash, as a
-- factor of the material's own (Suite.BODY).

GlassUI = GlassUI or {}
local GUI = GlassUI
local API = GUI.API
local Theme = {}
GUI.Theme = Theme

Theme.NAMES = { "clear", "smoked", "class" }
Theme.LABELS = { clear = "Clear glass", smoked = "Smoked glass", class = "Class colour glass" }

-- The window floor: at 0.6, 0.75 and 0.85 RestedXP's text still read
-- through the merchant, dimmed exactly by the floor (MS.1, 70450). The owner
-- wanted nothing behind a window, then a bit less than opaque, as Blizzard's
-- own bags, where a damage meter behind shows just a bit (2026-10-20): 0.85,
-- tried against 0.8 and 0.9 in ML run 2. The glass is the tint, wash and rim
-- over it.
Theme.WINDOW_BACKING = 0.85

-- { g = LibGlass regions, backing = our texture, kind = "window" | "clear" | nil }
local surfaces = {}
Theme.pending = false

function Theme.IsValid(name) return GUI.Suite.LookValid("tint", name) end

function Theme.Name()
    local look = GUI.Suite.Look()
    return look and look.tint or GUI.Suite.LOOK_DEFAULTS.tint
end

-- The tint for this theme as { r, g, b[, a] }, or nil for the surface's
-- built tint. Second return: false while the class colour is wanted but
-- unreadable.
local function tintFor(name)
    local p = GUI.Suite.Body(name)
    if p.classShade then
        local r, g, b = API.ClassColor()
        if not r then return nil, false end
        return { r * p.classShade, g * p.classShade, b * p.classShade }, true
    end
    return p.tint, true
end

local function paint(s, name, tint)
    -- A surface that stays clear whatever the suite tint (the merchant's disc, #48).
    if s.kind == "clear" then name, tint = "clear", (tintFor("clear")) end
    local p = GUI.Suite.Body(name)
    local Glass = GUI.Glass
    if tint then
        Glass.SetSurfaceTint(s.g, tint[1], tint[2], tint[3], tint[4])
    else
        Glass.SetSurfaceTint(s.g)
    end
    Glass.SetWash(s.g, Glass.STYLE.wash * p.wash)
    if s.backing then
        local c = p.backing
        local a = c[4]
        if s.kind == "window" then a = math.max(a, Theme.WINDOW_BACKING) end
        s.backing:SetColorTexture(c[1], c[2], c[3], a)
    end
end

-- Add a surface (and the backing under it, if any) and paint it with the
-- current theme. kind: "window" for the window floor, "clear" for a surface
-- painted clear whatever the tint.
function Theme.Register(g, backing, kind)
    if type(g) ~= "table" or not g.tint then return end
    local s = { g = g, backing = backing, kind = kind }
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

-- The suite look's tint: saved there, announced to the followers, and our
-- skins repainted (Suite's announce calls Refresh).
function Theme.Set(name)
    if not Theme.IsValid(name) then return false end
    return GUI.Suite.SetLook("tint", name)
end

-- PLAYER_ENTERING_WORLD: the class colour can be read by now.
function Theme.Retry()
    if Theme.pending or Theme.Name() == "class" then Theme.Refresh() end
end

Theme._test = { surfaces = surfaces }
