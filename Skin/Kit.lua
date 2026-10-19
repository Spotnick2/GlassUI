-- Skin/Kit.lua: the touches every skin makes, and the widget kinds the windows
-- share (docs/PLAN.md, "The kit"). Each skin gets its own kit (Engine.Register),
-- so a skin's switch restores only what that skin touched.
--
-- On Blizzard's objects, C widget methods only (CLAUDE.md, "The skin
-- contract"): SetAlpha, and hooksecurefunc on the region itself to keep it.
-- Never Show/Hide: Blizzard's own Show/Hide logic for the art keeps working.
-- Our state lives in our own weak tables, never in fields on theirs.
--
--   Fade    alpha 0, held when Blizzard sets the alpha again. The alpha
--           Blizzard asks for meanwhile is kept, so Restore gives back the
--           latest one (Glass Quest Tracker's fix: Edit Mode's Opacity sets
--           an alpha whenever the slider moves). The only touch a live skin
--           restores.
--           Fade(region, onAlpha) also hands that latest alpha to onAlpha, at
--           once and whenever Blizzard sets it (the damage meter's glass
--           follows its Background setting).
--   Blank   for art a fade can't hold (an animation's setToFinalAlpha, a
--           gradient): SetTexture(nil), the atlas or file read back first and
--           given back by Restore (Glass Quest Tracker's Unblank, #55). Safe
--           only where Blizzard sets that image once (the tracker's module
--           headers: in XML); a new target needs the same check.
--   Tint    desaturated and recoloured; Restore gives back the desaturation
--           and the vertex colour, never the image, so an atlas Blizzard
--           swapped meanwhile stays (the tracker's minimize buttons).
--   Shade   a shadow under a font string. Not restorable live: a skin using
--           it is live = false, and the kit refuses otherwise.
--   Panel   our glass: an unnamed, mouse-off frame of our own under the window.
--
-- Widget kinds, each written when the first skin needed it: Shell
-- (ButtonFrameTemplate / PortraitFrameTemplate), Inset (InsetFrameTemplate),
-- Tab (PanelTabButtonTemplate).

GlassUI = GlassUI or {}
local GUI = GlassUI
local API = GUI.API
local Kit = {}
GUI.Kit = Kit

local K = {}
K.__index = K

function Kit.New(skin)
    return setmetatable({ skin = skin, key = skin.def.key, live = skin.def.live == true, panels = {} }, K)
end

-- A short name for a region, for the failure record.
local function describe(r)
    local name = API.Plain(r.GetName and r:GetName())
    if type(name) == "string" then return name end
    local key = API.Plain(r.GetParentKey and r:GetParentKey())
    return type(key) == "string" and key or "?"
end

--------------------------------------------------------------------------------
-- Fade
--------------------------------------------------------------------------------

local faded = setmetatable({}, { __mode = "k" })    -- region -> { kit =, alpha = latest Blizzard alpha, busy =, onAlpha = }
local hooked = setmetatable({}, { __mode = "k" })

local function hold(region)
    local s = faded[region]
    if not s or s.busy then return end
    s.busy = true                                     -- our own SetAlpha re-enters the hook
    pcall(region.SetAlpha, region, 0)
    s.busy = false
end

-- Blizzard's latest alpha to the region's onAlpha: a plain number only, never
-- the 0 we hold.
local function tell(region, s)
    if not s.onAlpha or type(API.Plain(s.alpha)) ~= "number" then return end
    local ok, err = pcall(s.onAlpha, s.alpha)
    if not ok then API.Fail("fade:" .. s.kit.key .. ":" .. describe(region) .. ":onAlpha", err) end
end

function K:Fade(region, onAlpha)
    if type(region) ~= "table" or type(region.SetAlpha) ~= "function" then return false end
    if not faded[region] then faded[region] = { kit = self, alpha = API.Plain(region:GetAlpha()) } end
    faded[region].onAlpha = onAlpha
    if not hooked[region] then
        hooked[region] = true
        hooksecurefunc(region, "SetAlpha", function(r, alpha)
            local s = faded[r]
            if not s or s.busy then return end
            local taken = type(API.Plain(alpha)) == "number"
            if taken then s.alpha = alpha end
            if GUI.Engine.Active(s.kit.key) then
                hold(r)
                if taken then tell(r, s) end
            end
        end)
    end
    hold(region)
    -- A texture with a gradient ignores SetAlpha, whatever the order, and
    -- GetAlpha reads 1 (SkinProbe W1.6, 70374). Read it back: such a region
    -- needs Blank, and the skin file needs fixing.
    if API.Plain(region:GetAlpha()) ~= 0 then
        faded[region] = nil
        API.Fail("fade:" .. self.key .. ":" .. describe(region), "ignores SetAlpha (a gradient?): Blank it instead")
        return false
    end
    tell(region, faded[region])
    return true
end

function K:IsFaded(region) return faded[region] ~= nil and faded[region].kit == self end

local function unfade(region, s)
    faded[region] = nil
    pcall(region.SetAlpha, region, s.alpha or 1)
end

--------------------------------------------------------------------------------
-- Blank and Tint (restorable), Shade (live = false skins only)
--------------------------------------------------------------------------------

local blanked = setmetatable({}, { __mode = "k" })  -- texture -> { kit =, atlas = | file = }
local tinted = setmetatable({}, { __mode = "k" })   -- texture -> { kit =, desat =, r, g, b, a }

local function notLive(kit, what)
    if kit.live then error(what .. " can't be undone live: set live = false on skin " .. kit.key, 3) end
end

-- Drop a texture's image. What it showed is read first, once, and kept until
-- Restore: a blank again only drops the image again.
function K:Blank(tex)
    if type(tex) ~= "table" or type(tex.SetTexture) ~= "function" then return false end
    if not blanked[tex] then
        local atlas = API.Plain(tex:GetAtlas())
        blanked[tex] = { kit = self, atlas = atlas, file = not atlas and API.Plain(tex:GetTexture()) or nil }
    end
    tex:SetTexture(nil)
    return true
end

local function unblank(tex, s)
    blanked[tex] = nil
    if s.atlas then pcall(tex.SetAtlas, tex, s.atlas)
    elseif s.file ~= nil then pcall(tex.SetTexture, tex, s.file) end
end

-- Desaturate and recolour a texture. Its desaturation and colour are read
-- first, once, and kept until Restore.
function K:Tint(tex, r, g, b, a)
    if type(tex) ~= "table" or type(tex.SetVertexColor) ~= "function" then return false end
    if not tinted[tex] then
        local s = { kit = self, desat = API.Plain(tex:IsDesaturated()) == true }
        s.r, s.g, s.b, s.a = tex:GetVertexColor()
        tinted[tex] = s
    end
    tex:SetDesaturated(true)
    tex:SetVertexColor(r, g, b, a or 1)
    return true
end

local function untint(tex, s)
    tinted[tex] = nil
    pcall(tex.SetDesaturated, tex, s.desat)
    pcall(tex.SetVertexColor, tex, API.Plain(s.r) or 1, API.Plain(s.g) or 1, API.Plain(s.b) or 1, API.Plain(s.a) or 1)
end

-- A shadow under a font string's text, where glass makes it hard to read.
-- Its font and colour stay Blizzard's.
function K:Shade(fs)
    notLive(self, "Shade")
    if type(fs) ~= "table" or type(fs.SetShadowOffset) ~= "function" then return false end
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 1)
    return true
end

--------------------------------------------------------------------------------
-- Our panels
--------------------------------------------------------------------------------

-- Glass under a window: a child one level below it, so the window's own
-- regions and children draw over it (GlassMail's panel). insets: { left, top,
-- right, bottom } in px, inward. size: LibGlass's, default "large". anchor:
-- the region it covers, when not the whole window (still the window's child).
function K:Panel(window, size, insets, anchor)
    local panel = CreateFrame("Frame", nil, window)
    anchor = anchor or window
    if insets then
        panel:SetPoint("TOPLEFT", anchor, "TOPLEFT", insets[1], -insets[2])
        panel:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -insets[3], insets[4])
    else
        panel:SetAllPoints(anchor)
    end
    panel:SetFrameLevel(math.max(0, window:GetFrameLevel() - 1))
    -- Built at ADDON_LOADED (Glass.lua), before any skin can run. A panel
    -- earlier would be a bug of ours: recorded, and the glass built for it.
    if not GUI.Glass then API.Fail("kit:" .. self.key .. ":early", "a panel before the glass was built") end
    local g = GUI.BuildGlass().Apply(panel, size or "large")
    -- The opaque backing (Glass Quest Tracker's): above the shadow (-8),
    -- under the tint (-6), clipped by the glass's own mask.
    local backing = panel:CreateTexture(nil, "BACKGROUND", nil, -7)
    backing:SetAllPoints(panel)
    backing:AddMaskTexture(g.mask)
    GUI.Theme.Register(g, backing)
    self.panels[#self.panels + 1] = panel
    return panel, g
end

-- Our own frames: Show and Hide are ours to call.
function K:ShowPanels()
    for _, p in ipairs(self.panels) do p:Show() end
end

function K:HidePanels()
    for _, p in ipairs(self.panels) do p:Hide() end
end

-- A live skin turned off: every fade back to Blizzard's latest alpha, every
-- blank and tint given back, our panels hidden.
function K:Restore()
    for region, s in pairs(faded) do
        if s.kit == self then unfade(region, s) end
    end
    for tex, s in pairs(blanked) do
        if s.kit == self then unblank(tex, s) end
    end
    for tex, s in pairs(tinted) do
        if s.kit == self then untint(tex, s) end
    end
    self:HidePanels()
end

--------------------------------------------------------------------------------
-- Finding art (never by texture path: GetTexture returns file IDs here)
--------------------------------------------------------------------------------

-- A global by name, or nil, with the miss recorded: another build may have
-- renamed it, and the skin goes on without that piece.
function K:Global(name)
    local v = rawget(_G, name)
    if v == nil then API.Fail("missing:" .. self.key .. ":" .. name, "not found on this build") end
    return v
end

-- obj[key], or nil with the miss recorded.
function K:Child(obj, key)
    local v = type(obj) == "table" and obj[key] or nil
    if v == nil then API.Fail("missing:" .. self.key .. ":" .. key, "not found on this build") end
    return v
end

--------------------------------------------------------------------------------
-- Widget kinds
--------------------------------------------------------------------------------

-- InsetFrameTemplate: its background and border.
function K:Inset(inset)
    if type(inset) ~= "table" then return end
    self:Fade(self:Child(inset, "Bg"))
    self:Fade(self:Child(inset, "NineSlice"))
end

-- ButtonFrameTemplate / PortraitFrameTemplate (SharedUIPanelTemplates.xml):
-- the NineSlice border (portrait ring included), the background, the top
-- streaks, and the inset. The portrait, title and close button stay.
function K:Shell(frame)
    self:Fade(self:Child(frame, "NineSlice"))
    self:Fade(self:Child(frame, "Bg"))
    self:Fade(self:Child(frame, "TopTileStreaks"))
    self:Inset(self:Child(frame, "Inset"))
end

-- PanelTabButtonTemplate (SharedUIPanelTemplates.xml:932): the six base
-- pieces, active and inactive. Blizzard shows one set or the other
-- (PanelTemplates_SelectTab, .lua:616) and never sets their alpha, so the
-- fade holds. The selected tab keeps Blizzard's sign of it, its white text;
-- the hover highlight stays.
Kit.TAB_ART = { "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive" }
function K:Tab(tab)
    if type(tab) ~= "table" then return end
    for _, key in ipairs(Kit.TAB_ART) do self:Fade(self:Child(tab, key)) end
end

Kit._test = { faded = faded }
