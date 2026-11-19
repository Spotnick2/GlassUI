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
--   Dim     a fade held at an alpha other than 0 (#86: a disabled page
--           button's label), restored the same way; Dim(region, nil) gives
--           one region back now.
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
--   TextColor  the suite accent on an audited Blizzard title only (#71,
--           docs/PLAN.md "The accent on Blizzard's titles"): held like a
--           fade, Blizzard's latest colour kept and given back by Restore.
--   Panel   our glass: an unnamed, mouse-off frame of our own under the window.
--   Disc    a LibGlass disc of ours behind a round region (a portrait, #48).
--   Section a recessed pane of ours on a host's ARTWORK: a black fill and a
--           1 px edge, no glass (#84).
--   Adopt   a frame of ours outside our panels, hidden and shown with them.
--
-- A window's pieces (#88, from the merchant's #86, docs/BAGS.md section 1):
-- each writes into the caller's own state table `h`, so a skin keeps one
-- table per window.
--   Header       a smoky gradient from the window's top to a boundary,
--                joined to the backing at its RGBA; PlaceHeader re-anchors.
--   CloseButton  Blizzard's red close art faded (CloseFades), a glass disc
--                and an accent X of ours, feedback on our X only.
--   PortraitDisc the disc behind a portrait's round mask.
--   FlatShell    PortraitFrameFlatTemplate's NineSlice and Bg faded.
--   SideTab      a side tab on small glass, the selected one lighter with its
--                rim in the accent, mirroring a per-window selected reader
--                (#92, #94); SyncSideTabs re-reads a skin's tabs.
-- Tracked handles are repainted on Theme.Refresh, gated by their skin.
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
    return setmetatable({ skin = skin, key = skin.def.key, live = skin.def.live == true, backing = skin.def.backing,
                          panels = {} }, K)
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

local faded = setmetatable({}, { __mode = "k" })    -- region -> { kit =, alpha = latest Blizzard alpha, to = held alpha, busy =, onAlpha = }
local hooked = setmetatable({}, { __mode = "k" })

local function hold(region)
    local s = faded[region]
    if not s or s.busy then return end
    s.busy = true                                     -- our own SetAlpha re-enters the hook
    pcall(region.SetAlpha, region, s.to or 0)
    s.busy = false
end

-- Blizzard's latest alpha to the region's onAlpha: a plain number only, never
-- the alpha we hold.
local function tell(region, s)
    if not s.onAlpha or type(API.Plain(s.alpha)) ~= "number" then return end
    local ok, err = pcall(s.onAlpha, s.alpha)
    if not ok then API.Fail("fade:" .. s.kit.key .. ":" .. describe(region) .. ":onAlpha", err) end
end

-- Hold a Blizzard region at `to` (0: faded), against Blizzard's own SetAlpha,
-- remembering Blizzard's latest alpha for the restore.
local function holdAt(kit, region, to, onAlpha)
    if type(region) ~= "table" or type(region.SetAlpha) ~= "function" then return false end
    if not faded[region] then faded[region] = { kit = kit, alpha = API.Plain(region:GetAlpha()) } end
    faded[region].to = to
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
    -- needs Blank, and the skin file needs fixing. Within 0.01: a fractional
    -- alpha may not come back exact (#86).
    local back = API.Plain(region:GetAlpha())
    if type(back) ~= "number" or math.abs(back - to) > 0.01 then
        faded[region] = nil
        API.Fail("fade:" .. kit.key .. ":" .. describe(region), "ignores SetAlpha (a gradient?): Blank it instead")
        return false
    end
    tell(region, faded[region])
    return true
end

function K:Fade(region, onAlpha) return holdAt(self, region, 0, onAlpha) end

function K:IsFaded(region) return faded[region] ~= nil and faded[region].kit == self end

local function unfade(region, s)
    faded[region] = nil
    pcall(region.SetAlpha, region, s.alpha or 1)
end

-- A Blizzard region held at `alpha` (#86: a disabled page button's label), as
-- Fade holds at 0; nil gives it back Blizzard's latest alpha.
function K:Dim(region, alpha)
    if alpha == nil then
        local s = faded[region]
        if s and s.kit == self then unfade(region, s) end
        return true
    end
    return holdAt(self, region, alpha)
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

--------------------------------------------------------------------------------
-- TextColor: the audited titles only (#71). Never a quest line, a bar's name
-- or value, a timer: their colours carry information.
--------------------------------------------------------------------------------

local coloured = setmetatable({}, { __mode = "k" })   -- string -> { kit =, was = Blizzard's RGBA, want = ours, busy = }
local textHooked = setmetatable({}, { __mode = "k" })

-- Ours, with Blizzard's alpha. The busy flag keeps the hook from taking it
-- for Blizzard's colour.
local function paintText(fs, s)
    s.busy = true
    pcall(fs.SetTextColor, fs, s.want[1], s.want[2], s.want[3], s.was[4])
    s.busy = false
end

local function rgba(r, g, b, a)
    r, g, b, a = API.Plain(r), API.Plain(g), API.Plain(b), API.Plain(a)
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return nil end
    return { r, g, b, type(a) == "number" and a or 1 }
end

function K:TextColor(fs, r, g, b)
    if type(fs) ~= "table" or type(fs.SetTextColor) ~= "function" then return false end
    local s = coloured[fs]
    if not s then
        s = { kit = self, was = rgba(fs:GetTextColor()) or { 1, 1, 1, 1 } }
        coloured[fs] = s
    end
    s.want = { r, g, b }
    if not textHooked[fs] then
        textHooked[fs] = true
        hooksecurefunc(fs, "SetTextColor", function(f, ...)
            local st = coloured[f]
            if not st or st.busy then return end
            st.was = rgba(...) or st.was
            if GUI.Engine.Active(st.kit.key) then paintText(f, st) end
        end)
    end
    paintText(fs, s)
    return true
end

-- The capture dropped first, so the hook leaves Blizzard's colour alone.
local function untext(fs, s)
    coloured[fs] = nil
    pcall(fs.SetTextColor, fs, s.was[1], s.was[2], s.was[3], s.was[4])
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
-- opts.backing = false: no backing, for glass that sits on another panel's
-- (two would stack into a darker plate than the window, #80). opts.kind: this
-- panel's backing kind when it isn't the skin's (#90: the game menu's buttons
-- keep the window floor on a lighter Pearl window).
function K:Panel(window, size, insets, anchor, opts)
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
    local backing = (not opts or opts.backing ~= false) and self:Backing(panel, g) or nil
    GUI.Theme.Register(g, backing, (opts and opts.kind) or self.backing)
    self.panels[#self.panels + 1] = panel
    return panel, g, backing
end

-- The opaque backing (Glass Quest Tracker's): above the shadow (-8), under
-- the tint (-6), clipped by the glass's own mask.
function K:Backing(host, g)
    local backing = host:CreateTexture(nil, "BACKGROUND", nil, -7)
    backing:SetAllPoints(host)
    backing:AddMaskTexture(g.mask)
    return backing
end

-- A glass disc of ours behind a round region (a portrait, #48): a square
-- host centred on `around`, its width + 2 x opts.ring (opts.width when the
-- width can't be read), at opts.level, its rim there too: LibGlass makes the
-- rim 10 up, which would draw over what the disc sits behind. A child of
-- `parent`, so it shows and hides with it.
function K:Disc(parent, around, opts)
    local w = API.Plain(around:GetWidth())
    if type(w) ~= "number" or w <= 0 then w = opts.width end
    local side = w + 2 * opts.ring
    local host = CreateFrame("Frame", nil, parent)
    host:SetSize(side, side)
    host:SetPoint("CENTER", around, "CENTER", 0, 0)
    host:SetFrameLevel(math.max(0, opts.level))
    if not GUI.Glass then API.Fail("kit:" .. self.key .. ":early", "a disc before the glass was built") end
    -- LibGlass: "disc" from ~96 px up, "disc_small" below (GLASS-MATERIAL.md).
    local g = GUI.BuildGlass().Disc(host, side >= 96 and "disc" or "disc_small")
    if g.top then g.top:SetFrameLevel(host:GetFrameLevel()) end
    -- Pearl, clear and without a backing, like GlassMiniMap's ring: with the
    -- window's floor it read as a dark ring (the owner, MS.3, 2026-10-20).
    GUI.Theme.Register(g, nil, "clear")
    self.panels[#self.panels + 1] = host
    return host, g
end

-- A recessed pane (#84): a black fill on the host's ARTWORK 0 at
-- SECTION_FILL, and four 1 px edges on ARTWORK 1 at SECTION_EDGE, anchored
-- to the fill. In a glass host that is over its body (BACKGROUND) and under
-- its rim (g.top). Black, not the backing's colour: over a window's
-- near-opaque floor of that colour a pane of it didn't show (ML run 1,
-- 70450). The caller anchors the fill and shows it (Kit.ShowSection); it
-- starts hidden.
Kit.SECTION_FILL, Kit.SECTION_EDGE = 0.4, 0.12
local SIDES = { "TOP", "BOTTOM", "LEFT", "RIGHT" }
function K:Section(host)
    local fill = host:CreateTexture(nil, "ARTWORK", nil, 0)
    fill:SetColorTexture(0, 0, 0, Kit.SECTION_FILL)
    local edges = {}
    for i, side in ipairs(SIDES) do
        local e = host:CreateTexture(nil, "ARTWORK", nil, 1)
        e:SetColorTexture(1, 1, 1, Kit.SECTION_EDGE)
        if i <= 2 then
            e:SetPoint(side .. "LEFT", fill, side .. "LEFT", 0, 0)
            e:SetPoint(side .. "RIGHT", fill, side .. "RIGHT", 0, 0)
            e:SetHeight(1)
        else
            e:SetPoint("TOP" .. side, fill, "TOP" .. side, 0, 0)
            e:SetPoint("BOTTOM" .. side, fill, "BOTTOM" .. side, 0, 0)
            e:SetWidth(1)
        end
        edges[i] = e
    end
    local s = { fill = fill, edges = edges }
    Kit.ShowSection(s, false)
    return s
end

function Kit.ShowSection(s, on)
    if not s then return end
    s.fill:SetShown(on)
    for _, e in ipairs(s.edges) do e:SetShown(on) end
end

-- Our frame parented to a Blizzard one (so it hides with it): hidden by
-- Restore and the handover, shown again by ShowPanels, like our panels.
function K:Adopt(frame)
    self.panels[#self.panels + 1] = frame
    return frame
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
    for fs, s in pairs(coloured) do
        if s.kit == self then untext(fs, s) end
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

-- PortraitFrameFlatTemplate (SharedUIPanelTemplates.xml:566-674): the
-- NineSlice and the flat background (a frame of four textures Blizzard
-- recolours, never fades). Nothing else to miss on this template.
function K:FlatShell(frame)
    self:Fade(self:Child(frame, "NineSlice"))
    self:Fade(self:Child(frame, "Bg"))
end

--------------------------------------------------------------------------------
-- A window's pieces (#86, #88)
--------------------------------------------------------------------------------

Kit.HEADER_TOP = 0.45
Kit.CLOSE_X, Kit.CLOSE_REST = { 2, 12 }, 0.85
Kit.CLOSE_ART = { "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }

local tracked = {}   -- { key =, h = } per window, repainted on Theme.Refresh

local function accent() return GUI.Suite.Accent() or { 1, 0.82, 0 } end

local function track(kit, h)
    if h.tracked then return end
    h.tracked = true
    tracked[#tracked + 1] = { key = kit.key, h = h }
end

-- The header (#86): a texture of ours on the backing's layer (BACKGROUND -7,
-- under the tint and wash), clipped by the window glass's mask, from the
-- window's top down to `point` of `boundary` plus `y`, where the backing
-- then starts. h.headerOn (default on) is the probe's switch.
function K:Header(win, wg, backing, boundary, point, y, h)
    h.win, h.backing, h.boundary, h.boundaryPoint, h.boundaryY = win, backing, boundary, point, y or 0
    if h.headerOn == nil then h.headerOn = true end
    if backing and boundary then
        local t = win:CreateTexture(nil, "BACKGROUND", nil, -7)
        t:SetPoint("TOPLEFT", win, "TOPLEFT", 0, 0)
        t:SetPoint("RIGHT", win, "RIGHT", 0, 0)
        t:SetPoint("BOTTOM", boundary, point, 0, h.boundaryY)
        t:SetColorTexture(1, 1, 1, 1)
        if wg and wg.mask then t:AddMaskTexture(wg.mask) end
        t:Hide()
        h.header = t
    end
    track(self, h)
    return h
end

-- The backing from the boundary down, the header's gradient above it joined
-- at the backing's own RGBA (Theme.Backing: smoked's 0.92 too); or the
-- backing all of it. A gradient ignores SetAlpha here (LibGlass #47):
-- painted through its colours only.
function Kit.PlaceHeader(h)
    local b = h.backing
    if not b then return end
    b:ClearAllPoints()
    local on = h.headerOn and h.header ~= nil
    if on then
        -- The header's bottom too: the boundary can move (the bags' band, tuned live).
        h.header:ClearAllPoints()
        h.header:SetPoint("TOPLEFT", h.win, "TOPLEFT", 0, 0)
        h.header:SetPoint("RIGHT", h.win, "RIGHT", 0, 0)
        h.header:SetPoint("BOTTOM", h.boundary, h.boundaryPoint, 0, h.boundaryY)
        b:SetPoint("TOP", h.boundary, h.boundaryPoint, 0, h.boundaryY)
        b:SetPoint("LEFT", h.win, "LEFT", 0, 0)
        b:SetPoint("RIGHT", h.win, "RIGHT", 0, 0)
        b:SetPoint("BOTTOM", h.win, "BOTTOM", 0, 0)
        local r, g, bl, a = GUI.Theme.Backing("window")
        h.header:SetGradient("VERTICAL", CreateColor(r, g, bl, a), CreateColor(r, g, bl, Kit.HEADER_TOP))
    else
        b:SetAllPoints(h.win)
    end
    if h.header then h.header:SetShown(on) end
end

-- A white light on a button's disc while hovered (#103: the glyph's 0.85 to
-- full alone was "not visible at all"), clipped by the disc's own mask: on
-- the disc host's ARTWORK, over its body, under its rim. The side tabs'.
Kit.HOVER_LIGHT = 0.2
local function discLight(host, g)
    local t = host:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints(host)
    t:SetColorTexture(1, 1, 1, Kit.HOVER_LIGHT)
    if g and g.mask then t:AddMaskTexture(g.mask) end
    return t
end

-- A glyph button's strokes (#99), as the close X.
local function paintGlyph(st)
    local c = accent()
    for _, t in ipairs(st.strokes) do t:SetColorTexture(c[1], c[2], c[3], st.alpha) end
end

-- The close X's colour: the accent, at its current strength.
function Kit.PaintClose(h)
    local c = accent()
    for _, t in ipairs(h.closeX or {}) do t:SetColorTexture(c[1], c[2], c[3], h.closeAlpha) end
    for _, st in pairs(h.glyphs or {}) do paintGlyph(st) end
end

-- Our X while Blizzard's close button is disabled (#114: the quest dialog's
-- auto-accept, QuestFrame.lua:452).
Kit.CLOSE_OFF = 0.35

local function enabled(b)
    local ok, on = pcall(b.IsEnabled, b)
    return not ok or API.Plain(on) ~= false
end

-- The close button's feedback, on our X only: full on hover, 1 px down while
-- pressed; dimmed, without the light, while Blizzard's button is disabled.
function Kit.CloseFeedback(h, hover, pushed)
    if not h.closeFrame then return end
    local on = enabled(h.close)
    if not on then hover, pushed = false, false end
    h.hover, h.pushed = hover, pushed
    h.closeAlpha = (not on and Kit.CLOSE_OFF) or (hover and 1) or Kit.CLOSE_REST
    if h.closeLight then h.closeLight:SetShown(hover) end
    h.closeFrame:ClearAllPoints()
    h.closeFrame:SetPoint("CENTER", h.close, "CENTER", 0, pushed and -1 or 0)
    Kit.PaintClose(h)
end

-- A glyph button's feedback (#99): its own state, the close button's look.
function Kit.GlyphFeedback(st, hover, pushed)
    st.hover, st.pushed = hover, pushed
    st.alpha = hover and 1 or Kit.CLOSE_REST
    st.light:SetShown(hover)
    st.frame:ClearAllPoints()
    st.frame:SetPoint("CENTER", st.button, "CENTER", 0, pushed and -1 or 0)
    paintGlyph(st)
end

local function buttonState(b)
    local okM, over = pcall(b.IsMouseOver, b)
    local okS, state = pcall(b.GetButtonState, b)
    return okM and API.Plain(over) == true, okS and API.Plain(state) == "PUSHED"
end

-- From the buttons' getters: a hover or press that ended while we were off,
-- or while a glyph button was hidden (the maximise mixin's swap on click).
function Kit.CloseSync(h)
    if h.close then Kit.CloseFeedback(h, buttonState(h.close)) end
    for b, st in pairs(h.glyphs or {}) do Kit.GlyphFeedback(st, buttonState(b)) end
end

-- The close button (#86; UIPanelCloseButton, its X baked into four atlases,
-- SharedUIPanelTemplates.xml:134-140): a glass disc of ours under it
-- (unsliced, clean at 24 px), our X over it on a frame of ours one up (a
-- plain frame takes no mouse: the click stays Blizzard's), feedback by gated
-- HookScript on the instance. The fades are CloseFades, in the style pass.
function K:CloseButton(close, h)
    if type(close) ~= "table" then return h end
    h.close = close
    h.closeAlpha = Kit.CLOSE_REST
    local level = close:GetFrameLevel()
    local okW, w = pcall(close.GetWidth, close)
    w = okW and API.Plain(w) or nil
    if type(w) ~= "number" or w <= 0 then w = 24 end
    local disc, dg = self:Disc(close, close, { ring = 0, width = w, level = level - 1 })
    h.closeDisc, h.closeLight = disc, discLight(disc, dg)
    local x = self:Adopt(CreateFrame("Frame", nil, close))
    x:SetSize(w, w)
    x:SetFrameLevel(level + 1)
    h.closeX = {}
    for i, rot in ipairs({ math.pi / 4, -math.pi / 4 }) do
        local t = x:CreateTexture(nil, "OVERLAY")
        t:SetSize(Kit.CLOSE_X[1], Kit.CLOSE_X[2])
        t:SetPoint("CENTER", x, "CENTER", 0, 0)
        t:SetRotation(rot)
        h.closeX[i] = t
    end
    h.closeFrame = x
    local kit = self
    local function feedback(hover, pushed)
        if GUI.Engine.Active(kit.key) then GUI.Engine.Run(kit.skin, "close", Kit.CloseFeedback, h, hover, pushed) end
    end
    close:HookScript("OnEnter", function() feedback(true, h.pushed) end)
    close:HookScript("OnLeave", function() feedback(false, false) end)
    close:HookScript("OnMouseDown", function() feedback(h.hover, true) end)
    close:HookScript("OnMouseUp", function() feedback(h.hover, false) end)
    -- Disabled and enabled again by Blizzard, maybe inside a panel's show:
    -- read again a frame later.
    local function sync()
        if GUI.Engine.Active(kit.key) then GUI.Engine.Defer(kit.skin, "close", function() Kit.CloseSync(h) end) end
    end
    close:HookScript("OnEnable", sync)
    close:HookScript("OnDisable", sync)
    Kit.CloseFeedback(h, false, false)
    track(self, h)
    return h
end

-- Glyphs drawn with colour textures, like the close X: { width, height, x,
-- y, rotation } in a 24 px box. expand (the maximise button's): a 45 degree
-- shaft, its head at the top right; condense: the same, its head at the
-- bottom left.
Kit.GLYPHS = {
    expand = { { 2, 12, 0, 0, -math.pi / 4 }, { 6, 2, 2, 4.5, 0 }, { 2, 6, 4.5, 2, 0 } },
    condense = { { 2, 12, 0, 0, -math.pi / 4 }, { 6, 2, -2, -4.5, 0 }, { 2, 6, -4.5, -2, 0 } },
}

-- A button whose glyph is baked into its art (#99: the maximise and minimise
-- buttons, RedButton-Expand/Condense): the close button's recipe with a glyph
-- of ours, its state per button in h.glyphs[button]. Parented to the
-- button, so it shows and hides with it. The fades are CloseFades.
function K:GlyphButton(button, h, kind)
    if type(button) ~= "table" or not Kit.GLYPHS[kind] then return nil end
    h.glyphs = h.glyphs or {}
    if h.glyphs[button] then return h.glyphs[button] end
    local level = button:GetFrameLevel()
    local okW, w = pcall(button.GetWidth, button)
    w = okW and API.Plain(w) or nil
    if type(w) ~= "number" or w <= 0 then w = 24 end
    local st = { button = button, alpha = Kit.CLOSE_REST, strokes = {} }
    local disc, dg = self:Disc(button, button, { ring = 0, width = w, level = level - 1 })
    st.disc, st.light = disc, discLight(disc, dg)
    local f = self:Adopt(CreateFrame("Frame", nil, button))
    f:SetSize(w, w)
    f:SetFrameLevel(level + 1)
    for i, s in ipairs(Kit.GLYPHS[kind]) do
        local t = f:CreateTexture(nil, "OVERLAY")
        t:SetSize(s[1], s[2])
        t:SetPoint("CENTER", f, "CENTER", s[3], s[4])
        if s[5] ~= 0 then t:SetRotation(s[5]) end
        st.strokes[i] = t
    end
    st.frame = f
    h.glyphs[button] = st
    local kit = self
    local function feedback(hover, pushed)
        if GUI.Engine.Active(kit.key) then GUI.Engine.Run(kit.skin, "glyph", Kit.GlyphFeedback, st, hover, pushed) end
    end
    button:HookScript("OnEnter", function() feedback(true, st.pushed) end)
    button:HookScript("OnLeave", function() feedback(false, false) end)
    button:HookScript("OnMouseDown", function() feedback(st.hover, true) end)
    button:HookScript("OnMouseUp", function() feedback(st.hover, false) end)
    Kit.GlyphFeedback(st, false, false)
    track(self, h)
    return st
end

-- The close button's four state textures faded (the style pass).
function K:CloseFades(close)
    if type(close) ~= "table" then return end
    for _, get in ipairs(Kit.CLOSE_ART) do
        local ok, tex = pcall(close[get], close)
        if ok then self:Fade(tex) end
    end
end

-- The disc behind a portrait (#48): round its mask (PortraitContainer's
-- CircleMask), else the portrait, else the named global; under the portrait
-- (its container's level - 1), over the window's glass. opts: ring, width
-- (the width when it can't be read), global, and onPortrait: round the
-- portrait texture itself, for a window that resizes it (the bags' 36 px,
-- ContainerFrame.lua:789), where the mask read about four times too wide
-- (BG.1, 70450: "gigantic circles").
function K:PortraitDisc(frame, opts)
    local pc = type(frame.PortraitContainer) == "table" and frame.PortraitContainer or nil
    local portrait = pc and type(pc.portrait) == "table" and pc.portrait or nil
    local mask = pc and type(pc.CircleMask) == "table" and pc.CircleMask or nil
    local around = opts.onPortrait and portrait or (mask or portrait)
    if not around and opts.global then around = self:Global(opts.global) end
    if not around then return nil end
    local level = (pc and pc:GetFrameLevel() or frame:GetFrameLevel()) - 1
    return (self:Disc(frame, around, { ring = opts.ring, width = opts.width, level = level }))
end

--------------------------------------------------------------------------------
-- Side tabs (#92 the guild's, moved here for #94 the character window's)
--------------------------------------------------------------------------------

Kit.TAB_LIGHT = 0.12
-- tab -> { kit =, glass =, g =, light =, selected = fn(tab), art = fn(tab) }
local sideTabs = setmetatable({}, { __mode = "k" })
Kit.sideTabs = sideTabs
local sideKits = setmetatable({}, { __mode = "k" })

-- Every side tab of this kit's skin from its own selected reader: the light
-- and the accent rim on the selected ones, the built rim on the others. It
-- mirrors; it never writes a selection (GuildSpy's one-frame wait can leave
-- two checked: both show).
function Kit.SyncSideTabs(kit)
    local c = accent()
    for tab, s in pairs(sideTabs) do
        if s.kit == kit then
            local ok, on = pcall(s.selected, tab)
            on = ok and API.Plain(on) == true
            s.light:SetShown(on)
            if s.g then
                if on then
                    GUI.Glass.SetSurfaceRim(s.g, c[1], c[2], c[3], 1)
                else
                    GUI.Glass.SetSurfaceRim(s.g)
                end
            end
        end
    end
end

-- A side tab: our small glass once (parented to it, so it moves and hides
-- with it), its rim at its own level, a white light; the hooks once.
-- opts: insets, selected(tab) --> bool, art(tab) --> { regions to fade },
-- methods (instance methods to post-hook: SetChecked) and scripts (to
-- HookScript: OnClick, a CheckButton's native toggle), named, never
-- discovered by calling Blizzard's methods.
function K:SideTab(tab, opts)
    if type(tab) ~= "table" then return nil end
    if not sideTabs[tab] then
        local glass, g = self:Panel(tab, "small", opts.insets)
        if g and g.top then g.top:SetFrameLevel(glass:GetFrameLevel()) end
        local light = glass:CreateTexture(nil, "ARTWORK")
        light:SetAllPoints(glass)
        light:SetColorTexture(1, 1, 1, Kit.TAB_LIGHT)
        if g and g.mask then light:AddMaskTexture(g.mask) end
        light:Hide()
        sideTabs[tab] = { kit = self, glass = glass, g = g, light = light, selected = opts.selected, art = opts.art }
        sideKits[self] = true
        local kit = self
        local function relay()
            if GUI.Engine.Active(kit.key) then GUI.Engine.Run(kit.skin, "tabs", Kit.SyncSideTabs, kit) end
        end
        for _, m in ipairs(opts.methods or {}) do hooksecurefunc(tab, m, relay) end
        for _, sc in ipairs(opts.scripts or {}) do tab:HookScript(sc, relay) end
    end
    return sideTabs[tab]
end

-- A side tab's art faded (the style pass: a restore drops the fades).
function K:StyleSideTab(tab)
    local s = sideTabs[tab]
    if not (s and s.art) then return end
    local ok, regions = pcall(s.art, tab)
    if not ok or type(regions) ~= "table" then return end
    for _, r in pairs(regions) do self:Fade(r) end
end

-- A tint, an accent or a floor changed: each tracked window's header and
-- close X follow, and each skin's side tabs, while its skin is on; the style
-- pass repaints the rest.
GUI.Theme.OnRefresh(function()
    for _, t in ipairs(tracked) do
        if GUI.Engine.Active(t.key) then
            Kit.PlaceHeader(t.h)
            Kit.PaintClose(t.h)
        end
    end
    for kit in pairs(sideKits) do
        if GUI.Engine.Active(kit.key) then Kit.SyncSideTabs(kit) end
    end
end)

Kit._test = { faded = faded, tracked = tracked }
