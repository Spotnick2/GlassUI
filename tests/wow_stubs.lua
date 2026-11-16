-- wow_stubs.lua: Glass UI's WoW: Forever mock for Lua 5.1 unit tests.
-- dofile("tests/wow_stubs.lua") FIRST in every test; drive it via the WoW table.
--
-- The mechanics come from WowTestKit (tests/kit.lua loads the commit
-- tests/kit.pin names; its README is the reference): strict globals, event
-- names checked against the pinned build, widgets that record every method
-- called (WoW.methodsCalled, which test_methods checks with
-- Kit.checkMethods), print (with the stray-"|" check done() fails on),
-- timers, hooksecurefunc, fire / fireAllRegistered / tick. This file adds
-- Glass UI's own:
-- - the client APIs the addon reads, each verified in the dump;
-- - the widget methods the core doesn't have, and the few it replaces (each
--   says why);
-- - BLIZZARD objects (WoW.makeMerchant...): every method addon code calls on
--   one is recorded (WoW.blizzCalls), with SetTexture/SetAtlas's argument
--   (WoW.textureArgs) and what addon code read from that texture with
--   GetTexture/GetAtlas (WoW.readBack); a Lua method is recorded apart
--   (WoW.luaCalls); a field written is trapped (WoW.fieldChanges). Glass
--   Quest Tracker's contract machinery. WoW.asBlizzard runs code as
--   Blizzard's own.

dofile("tests/kit.lua")
local Methods = WoW.Methods
local coreNewWidget = WoW.newWidget
-- The core's method dispatch (record the call, then run WoW.Methods[k]),
-- which Blizzard's objects wrap below to keep the contract record.
local coreDispatch = getmetatable(coreNewWidget("Frame")).__index

-- The stub's own objects (Blizzard's, a template's pieces) start with the
-- fields the tests read directly: their children and regions as lists, alpha
-- and scale 1, the mouse off.
local function newWidget(wtype, parent, name)
    local w = coreNewWidget(wtype, parent, name)
    w._children, w._regions, w._scale, w._alpha, w._mouse = {}, {}, 1, 1, false
    return w
end

-- WowTestKit #38: every frame too. A test lists a frame's children or
-- regions with ipairs(f._children) whether it has any or not, and the core
-- makes those lists only with the first child or region.
local coreCreateFrame = CreateFrame
function CreateFrame(...)
    local w = coreCreateFrame(...)
    w._children, w._regions = w._children or {}, w._regions or {}
    return w
end

local function adopt(parent, w)
    if parent then
        parent._children = parent._children or {}
        table.insert(parent._children, w)
    end
end

--------------------------------------------------------------------------------
-- Templates (WoW.templates: what each adds to the frame CreateFrame makes)
--------------------------------------------------------------------------------

-- The button and checkbox templates' label (parentKey "Text").
local function label(w) w.Text = newWidget("FontString", w) end
WoW.templates.UICheckButtonTemplate = label
WoW.templates.UIPanelButtonTemplate = label
-- RightSideTabTemplate (Blizzard_SharedXML/Shared/Tabs/RightSideTab.xml):
-- its BORDER frame texture, the Icon, the checked and highlight textures.
WoW.templates.RightSideTabTemplate = function(w)
    w._width, w._height = 32, 32
    local border = newWidget("Texture", w)
    border._layer = "BORDER"
    WoW.addRegion(w, border)
    w.Icon = newWidget("Texture", w)
    w.Icon._layer = "ARTWORK"
    WoW.addRegion(w, w.Icon)
    w._checkedTex = newWidget("Texture", w)
    w._highlight = newWidget("Texture", w)
end
WoW.templates.UIRadioButtonTemplate = function(w) w.text = newWidget("FontString", w) end
-- UIPanelScrollFrameTemplate's bar, as its ScrollBar key.
WoW.templates.UIPanelScrollFrameTemplate = function(w) w.ScrollBar = newWidget("Slider", w) end

--------------------------------------------------------------------------------
-- Widget methods the core replaces here
--------------------------------------------------------------------------------

-- Enabled state in _enabled: here _disabled is a button's disabled texture
-- (GetDisabledTexture; the Blizzard buttons below, and the tests read the
-- state textures by their keys _normal, _pushed, _disabled, _highlight).
-- The core's Enable/Disable keep the state in _disabled and would replace it.
-- WowTestKit #41: a frame's ID, 0 by default (the bag windows' bag, an item
-- button's slot; the probe reads them, ContainerFrame.lua:1845).
function Methods.SetID(w, id) w._id = id end
function Methods.GetID(w) return w._id or 0 end
function Methods.SetEnabled(w, v) w._enabled = v and true or false end
function Methods.Enable(w) w._enabled = true end
function Methods.Disable(w) w._enabled = false end
function Methods.IsEnabled(w) return w._enabled ~= false end
-- The tests read a texture's sublevel as _sub (GetDrawLayer below); the
-- core keeps it as _sublevel.
local coreCreateTexture = Methods.CreateTexture
function Methods.CreateTexture(w, name, layer, template, sub)
    local t = coreCreateTexture(w, name, layer, template, sub)
    t._sub = sub
    return t
end
-- The tests read it as _desat (the core: _desaturated).
function Methods.SetDesaturated(t, v) t._desat = v and true or false end
-- A texture painted with SetGradient ignores a later SetAlpha, and GetAlpha
-- keeps reading 1 (porting guide section 3, measured on 70374 twice; an image
-- texture too, SkinProbe W1.6 square C): the core's SetAlpha models that.
-- WowTestKit #37: an alpha set BEFORE the gradient doesn't survive it
-- either, the texture shows and reads 1 (70374, SkinProbe W1.6 square B),
-- and this API takes colour objects; the core's SetGradient does neither.
function Methods.SetGradient(t, orientation, c1, c2)
    assert(type(c1) == "table" and type(c2) == "table", "SetGradient takes color objects on this API")
    t._gradient = { orientation, c1, c2 }
    t._alpha = 1
end
-- The hook is addon code, even when Blizzard's side fired the script (the
-- contract record).
function Methods.HookScript(w, name, fn)
    local old = w._scripts[name]
    w._scripts[name] = function(...)
        if old then old(...) end
        local was = WoW.inBlizzard
        WoW.inBlizzard = false
        fn(...)
        WoW.inBlizzard = was
    end
end
-- RGBA, read back; a call from addon code on a Blizzard string is recorded
-- with its receiver (WoW.textColorCalls) for test_contract's audited list.
local coreSetTextColor = Methods.SetTextColor
function Methods.SetTextColor(w, ...)
    if rawget(w, "_blizz") and not WoW.inBlizzard then table.insert(WoW.textColorCalls, w) end
    return coreSetTextColor(w, ...)
end

-- Textures. On a Blizzard object, addon code's argument is kept: the
-- contract allows only nil, or giving back the value read before.
local function textureArg(t, method, v)
    if rawget(t, "_blizz") and not WoW.inBlizzard then table.insert(WoW.textureArgs, { t, method, v }) end
end
-- What addon code read from a Blizzard texture, per getter: the provenance
-- test_contract asks of a non-nil texture argument.
local function readBy(t, getter, v)
    if v == nil or not rawget(t, "_blizz") or WoW.inBlizzard then return v end
    WoW.reads[t] = WoW.reads[t] or {}
    WoW.reads[t][getter] = WoW.reads[t][getter] or {}
    WoW.reads[t][getter][v] = true
    return v
end
-- Did addon code read v from t with this setter's getter?
function WoW.readBack(t, setter, v)
    local getter = setter == "SetAtlas" and "GetAtlas" or "GetTexture"
    local r = WoW.reads[t]
    return r ~= nil and r[getter] ~= nil and r[getter][v] == true
end
local coreSetTexture, coreSetAtlas = Methods.SetTexture, Methods.SetAtlas
function Methods.SetTexture(t, file) textureArg(t, "SetTexture", file); return coreSetTexture(t, file) end
function Methods.SetAtlas(t, atlas) textureArg(t, "SetAtlas", atlas); return coreSetAtlas(t, atlas) end

--------------------------------------------------------------------------------
-- Widget methods the core doesn't have
--------------------------------------------------------------------------------

function Methods.GetNumPoints(w) return #w._points end
function Methods.GetSize(w) return w._width, w._height end
function Methods.GetCenter(w) return w._cx, w._cy end
-- Rects: what a test sets (nil until laid out, as before the first frame).
function Methods.GetTop(w) return w._top end
function Methods.GetBottom(w) return w._bottom end
-- ScrollFrame: the range a test sets (w._yrange).
function Methods.GetVerticalScrollRange(w) return w._yrange or 0 end
function Methods.GetEffectiveScale(w) return w._effScale or 1 end
function Methods.SetScale(w, s) w._scale = s end
function Methods.GetScale(w) return w._scale or 1 end
function Methods.GetParentKey(w) return w._parentKey end
function Methods.IsObjectType(w, t)
    if w._type == t then return true end
    return t == "Frame" and (w._type == "Button" or w._type == "CheckButton")
end
function Methods.GetDrawLayer(w) return w._layer, w._sub or 0 end
function Methods.IsProtected(w) return w._protected == true end
function Methods.RegisterForClicks(w, ...) w._clicks = { ... } end
function Methods.RegisterForDrag(w, ...) w._drag = { ... } end
function Methods.IsMouseOver(w) return WoW.mouseOver[w] == true end
function Methods.SetHighlightTexture(w, file, blend)
    w._highlight = newWidget("Texture", w)
    w._highlight._file = file
    return true
end
function Methods.GetHighlightTexture(w) return w._highlight end
function Methods.SetNormalTexture(w, file) w._normal = newWidget("Texture", w); w._normal._file = file end
function Methods.GetNormalTexture(w) return w._normal end
function Methods.GetPushedTexture(w) return w._pushed end
function Methods.GetDisabledTexture(w) return w._disabled end
-- "NORMAL" or "PUSHED"; a test sets w._buttonState.
function Methods.GetButtonState(w) return w._buttonState or "NORMAL" end
function Methods.SetCheckedTexture(w, file) w._checkedTex = newWidget("Texture", w) end
function Methods.GetCheckedTexture(w) return w._checkedTex end

-- Scripts. HasScript: every scripted widget type knows these handlers.
local SCRIPTED = { Frame = true, Button = true, CheckButton = true, StatusBar = true, GameTooltip = true,
                   EditBox = true }
local HANDLERS = { OnClick = true, OnMouseUp = true, OnMouseDown = true, OnEnter = true, OnLeave = true,
                   OnShow = true, OnHide = true, OnUpdate = true, OnEvent = true, OnDragStart = true, OnDragStop = true,
                   OnDoubleClick = true, OnMouseWheel = true }
function Methods.HasScript(w, name) return SCRIPTED[w._type] == true and HANDLERS[name] == true end
function Methods.Click(w, mouse)
    if w._scripts.OnClick then w._scripts.OnClick(w, mouse or "LeftButton", false) end
end

-- Textures.
function Methods.GetTexture(t) return readBy(t, "GetTexture", t._file) end
function Methods.GetAtlas(t) return readBy(t, "GetAtlas", t._atlas) end
function Methods.SetTexCoord(t, ...) t._coords = { ... } end
function Methods.GetTexCoord(t)
    local c = t._coords or { 0, 0, 0, 1, 1, 0, 1, 1 }
    return unpack(c)
end
function Methods.GetVertexColor(t)
    local v = t._vertex or { 1, 1, 1, 1 }
    return v[1], v[2], v[3], v[4] or 1
end
function Methods.IsDesaturated(t) return t._desat == true end
function Methods.RemoveMaskTexture(t, m)
    for i, x in ipairs(t._masks or {}) do if x == m then table.remove(t._masks, i); return end end
end
function Methods.SetShadowOffset(fs, x, y) fs._shadowOffset = { x, y } end
function Methods.GetShadowOffset(fs)
    local o = fs._shadowOffset or { 0, 0 }
    return o[1], o[2]
end
function Methods.SetShadowColor(fs, r, g, b, a) fs._shadowColor = { r, g, b, a } end
function Methods.SetRotation(t, r) t._rotation = r end
function Methods.GetRotation(t) return t._rotation or 0 end
-- A string's size: half its font size per character of its longest line, its
-- font size per line (10 until SetFont).
local function textLines(fs)
    local longest, n = 0, 0
    for line in tostring(fs._text or ""):gmatch("[^\n]+") do
        n = n + 1
        if #line > longest then longest = #line end
    end
    return longest, n, (type(fs._font) == "table" and fs._font[2]) or 10
end
function Methods.GetStringWidth(fs)
    local longest, _, size = textLines(fs)
    return longest * size / 2
end
function Methods.GetStringHeight(fs)
    local _, n, size = textLines(fs)
    return n * size
end

-- GameTooltip: records its lines.
function Methods.SetOwner(tt, owner) tt._owner = owner; tt._lines = {} end
function Methods.GetOwner(tt) return tt._owner end
function Methods.ClearLines(tt) tt._lines = {} end
function Methods.AddLine(tt, text, r, g, b)
    table.insert(tt._lines, text)
    tt._colors = tt._colors or {}
    tt._colors[#tt._lines] = { r, g, b }
end
function Methods.AddDoubleLine(tt, l, r) table.insert(tt._lines, tostring(l) .. "|" .. tostring(r)) end

--------------------------------------------------------------------------------
-- Globals
--------------------------------------------------------------------------------

-- A fresh session (the core's WoW.reset clears the frames, chat, method
-- calls, timers and combat first).
table.insert(WoW.onReset, function()
    WoW.mouseOver = {}
    WoW.settingsOpened = nil
    WoW.cvars = {}
    WoW.class = "MAGE"
    WoW.loaded = {}
    -- Installed addons and their enable state for this character
    -- ([name] = 0 none, 1 some, 2 all); the GUID the state was asked for.
    WoW.installed = {}
    WoW.enableAskedFor = nil
    WoW.triggered = {}
    WoW.onLoaded = {}
    WoW.style = 0
    WoW.blizz, WoW.blizzCalls, WoW.luaCalls, WoW.fieldWrites, WoW.textureArgs = {}, {}, {}, {}, {}
    WoW.reads = setmetatable({}, { __mode = "k" })
    WoW.textColorCalls = {}
    -- A fresh session: the last one's callbacks are gone with it (a stale
    -- skin's LookChanged would otherwise touch this session's frames).
    if rawget(_G, "EventRegistry") then EventRegistry.callbacks = {} end
    WoW.hookedKeys = setmetatable({}, { __mode = "k" })
    WoW.snap = setmetatable({}, { __mode = "k" })
    WoW.inBlizzard = false
    for _, name in ipairs(WoW.blizzGlobals or {}) do rawset(_G, name, nil) end
    WoW.blizzGlobals = {}
    UIParent = newWidget("Frame", nil, "UIParent")
    UIParent._level = 0
    UIParent._width, UIParent._height = 1024, 768
    GameTooltip = newWidget("GameTooltip", UIParent, "GameTooltip")
    UISpecialFrames = {}
end)

-- A hook on a Blizzard object is addon code, even when Blizzard's side made
-- the call, and the wrapper it leaves is the client's own field, not an addon
-- write (WoW.hookedKeys: test_contract skips it). The core's hooksecurefunc
-- does the rest.
local coreHooksecurefunc = hooksecurefunc
function hooksecurefunc(t, name, fn)
    if type(t) == "string" then return coreHooksecurefunc(t, name, fn) end
    if rawget(t, "_blizz") then WoW.hookedKeys[t] = WoW.hookedKeys[t] or {}; WoW.hookedKeys[t][name] = true end
    coreHooksecurefunc(t, name, function(...)
        local was = WoW.inBlizzard
        WoW.inBlizzard = false
        fn(...)
        WoW.inBlizzard = was
    end)
end

SlashCmdList = {}
function wipe(t) for k in pairs(t) do t[k] = nil end; return t end
Enum = { UITextureSliceMode = { Stretched = 0, Tiled = 1 } }
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end
WoW.build, WoW.version = "70450", "v0.1.0"
function GetBuildInfo() return "1.60.1", WoW.build, "Oct 13 2026", 16001 end
C_AddOns = {
    GetAddOnMetadata = function(name, variable)
        if name == "GlassUI" and variable == "Version" then return WoW.version end
        return nil
    end,
    IsAddOnLoaded = function(name) return WoW.loaded[name] == true end,
    DoesAddOnExist = function(name) return WoW.installed[name] ~= nil or WoW.loaded[name] == true end,
    GetAddOnEnableState = function(name, character)
        WoW.enableAskedFor = character
        return WoW.installed[name] or (WoW.loaded[name] and 2) or 0
    end,
}
-- EventRegistry (Blizzard_SharedXMLBase): callbacks get (owner, ...); every
-- trigger is recorded in WoW.triggered.
EventRegistry = { callbacks = {} }
function EventRegistry:RegisterCallback(event, fn, owner)
    self.callbacks[event] = self.callbacks[event] or {}
    table.insert(self.callbacks[event], { fn = fn, owner = owner })
end
function EventRegistry:TriggerEvent(event, ...)
    table.insert(WoW.triggered, { event = event, args = { ... } })
    for _, c in ipairs(self.callbacks[event] or {}) do c.fn(c.owner, ...) end
end
WoW.GUID = "Player-4618-0ABCDEF0"
C_Item = { GetItemIconByID = function(id) return WoW.itemIcons[id] end }
WoW.itemIcons = { [5500] = 134122 }
-- The buyback count (MerchantFrame.lua:416, 547): WoW.buybackCount.
function GetNumBuybackItems() return WoW.buybackCount or 0 end
function UnitGUID(unit) return unit == "player" and WoW.GUID or nil end
-- Seconds since the client started (the core's GetTime): what a test sets.
WoW.now = 0

-- EventUtil (Blizzard_SharedXML\EventUtil.lua:67): now if loaded, else at its
-- ADDON_LOADED. WoW.loadAddOn(name) loads one mid-session.
EventUtil = { ContinueOnAddOnLoaded = function(name, fn)
    if WoW.loaded[name] then fn() return end
    WoW.onLoaded[name] = WoW.onLoaded[name] or {}
    table.insert(WoW.onLoaded[name], fn)
end }
function WoW.loadAddOn(name)
    WoW.loaded[name] = true
    WoW.fire("ADDON_LOADED", name)
    local list = WoW.onLoaded[name] or {}
    WoW.onLoaded[name] = nil
    for _, fn in ipairs(list) do fn() end
end

-- The interface style, as read on 70374 (SkinProbe W1.4: {Gamepad=1, Mkb=0}).
Enum.InputDeviceInterfaceType = { Mkb = 0, Gamepad = 1 }
C_InputInterfaceStyle = { GetCurrentStyle = function() return WoW.style end }

-- Settings (Options > AddOns): the canvas category API.
Settings = {
    RegisterCanvasLayoutCategory = function(panel, name)
        return { panel = panel, name = name, GetID = function() return name end }
    end,
    RegisterCanvasLayoutSubcategory = function(parent, panel, name)
        return { panel = panel, name = name, parent = parent, GetID = function() return name end }
    end,
    RegisterAddOnCategory = function(cat) WoW.settingsCategory = cat end,
    OpenToCategory = function(id) WoW.settingsOpened = id end,
}

function GetCVarBool(name) return WoW.cvars[name] == true end
function UnitClass() return "Mage", WoW.class, 8 end
C_ClassColor = { GetClassColor = function(class)
    if class == "MAGE" then return { r = 0.25, g = 0.78, b = 0.92 } end
    return { r = 1, g = 1, b = 1 }
end }

--------------------------------------------------------------------------------
-- Blizzard's objects (wow-ui-source branch forever, 70374)
--------------------------------------------------------------------------------

-- A Blizzard object: a NEW key written from addon code is trapped here;
-- a changed EXISTING key is caught by WoW.fieldChanges() against the
-- snapshot. Keys starting with "_" are the stub's own bookkeeping.
-- Its methods are the core's, and a call from addon code (not from the
-- simulated Blizzard side) is also counted in WoW.blizzCalls, which
-- test_contract checks against the C-only allowlist; RestedXP's objects
-- (WoW.makeRestedXP) in WoW.rxpCalls too.
local blizzMT = {
    __index = function(t, k)
        local method = coreDispatch(t, k)
        if not method then return nil end
        return function(self, ...)
            if not WoW.inBlizzard then
                if rawget(self, "_blizz") then WoW.blizzCalls[k] = (WoW.blizzCalls[k] or 0) + 1 end
                if rawget(self, "_rxp") then WoW.rxpCalls[k] = (WoW.rxpCalls[k] or 0) + 1 end
            end
            return method(self, ...)
        end
    end,
    __newindex = function(t, k, v)
        if type(k) == "string" and k:sub(1, 1) == "_" then return rawset(t, k, v) end
        if not WoW.inBlizzard then table.insert(WoW.fieldWrites, tostring(k)) end
        rawset(t, k, v)
    end,
}

local function blizz(wtype, parent, name, layer)
    local w = setmetatable(newWidget(wtype, parent, name), blizzMT)
    rawset(w, "_blizz", true)
    w._layer = layer
    table.insert(WoW.blizz, w)
    if parent and wtype ~= "Texture" and wtype ~= "FontString" then adopt(parent, w) end
    if name then rawset(_G, name, w); table.insert(WoW.blizzGlobals, name) end
    return w
end
WoW.blizzObject = blizz

-- Run fn as Blizzard's own code.
function WoW.asBlizzard(fn, ...)
    local was = WoW.inBlizzard
    WoW.inBlizzard = true
    fn(...)
    WoW.inBlizzard = was
end

-- The plain fields of every Blizzard object not yet snapshotted, as
-- Blizzard's side built them.
function WoW.snapshot()
    for _, w in ipairs(WoW.blizz) do
        if not WoW.snap[w] then
            local s = {}
            for k, v in pairs(w) do
                if type(k) ~= "string" or k:sub(1, 1) ~= "_" then s[k] = v end
            end
            WoW.snap[w] = s
        end
    end
end

-- Fields an addon changed or added since the snapshot (hooksecurefunc's own
-- wrapper excepted), as "key" strings.
function WoW.fieldChanges()
    local out = {}
    for _, w in ipairs(WoW.blizz) do
        local s, hooked = WoW.snap[w] or {}, WoW.hookedKeys[w] or {}
        for k, v in pairs(w) do
            if (type(k) ~= "string" or k:sub(1, 1) ~= "_") and not hooked[k] and s[k] ~= v then
                out[#out + 1] = tostring(k)
            end
        end
    end
    for _, k in ipairs(WoW.fieldWrites) do out[#out + 1] = k end
    return out
end

-- A Lua method on a Blizzard object (a mixin copy): calling one from addon
-- code is recorded (WoW.luaCalls) as well as run.
local function luaMethod(obj, name, fn)
    rawset(obj, name, function(self, ...)
        if not WoW.inBlizzard then table.insert(WoW.luaCalls, name) end
        local was = WoW.inBlizzard
        WoW.inBlizzard = true
        local r = fn(self, ...)
        WoW.inBlizzard = was
        return r
    end)
end

local NINE = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
               "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center" }
local function nineSlice(parent)
    local n = blizz("Frame", parent)
    for _, k in ipairs(NINE) do n[k] = blizz("Texture", n, nil, "OVERLAY") end
    return n
end
-- InsetFrameTemplate: .Bg and .NineSlice.
local function inset(parent, name)
    local i = blizz("Frame", parent, name)
    i.Bg = blizz("Texture", i, nil, "BACKGROUND")
    i.NineSlice = nineSlice(i)
    return i
end
-- PanelTabButtonTemplate (SharedUIPanelTemplates.xml:932): six base pieces,
-- three highlight pieces, its text; PanelTemplates_SelectTab shows the
-- Active pieces, hides the others and disables the tab (.lua:616).
local TAB_BASE = { "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive" }
local function tab(parent, name)
    local t = blizz("Button", parent, name)
    for _, k in ipairs(TAB_BASE) do t[k] = blizz("Texture", t, nil, "BACKGROUND") end
    for _, k in ipairs({ "LeftHighlight", "MiddleHighlight", "RightHighlight" }) do
        t[k] = blizz("Texture", t, nil, "HIGHLIGHT")
    end
    t.Text = blizz("FontString", t, nil, "ARTWORK")
    return t
end

-- MerchantFrame (Mainline\MerchantFrame.xml, ButtonFrameTemplate), with the
-- regions SkinProbe listed on 70374 (docs/FOREVER-PROBE.md W1.2). Hidden.
function WoW.makeMerchant()
    WoW.asBlizzard(function()
        local f = blizz("Frame", UIParent, "MerchantFrame")
        f._shown = false
        f._level = 1
        f.NineSlice = nineSlice(f)
        f.NineSlice._level = 500
        f.Bg = blizz("Texture", f, "MerchantFrameBg", "BACKGROUND")
        f.TopTileStreaks = blizz("Texture", f, nil, "BORDER")
        -- PortraitFrameTemplate (SharedUIPanelTemplates.xml:574-596): the
        -- container at level 400, a 62 px portrait masked by a 58 px circle.
        f.PortraitContainer = blizz("Frame", f)
        f.PortraitContainer._level = 400
        f.PortraitContainer.portrait = blizz("Texture", f.PortraitContainer, "MerchantFramePortrait", "OVERLAY")
        f.PortraitContainer.portrait._width, f.PortraitContainer.portrait._height = 62, 62
        f.PortraitContainer.CircleMask = blizz("MaskTexture", f.PortraitContainer)
        f.PortraitContainer.CircleMask._width, f.PortraitContainer.CircleMask._height = 58, 58
        f.CloseButton = blizz("Button", f)
        -- UIPanelCloseButton (SharedUIPanelTemplates.xml:134-140): 24 px at
        -- level 510, its X baked into four atlases.
        local cb = f.CloseButton
        cb._level, cb._width, cb._height = 510, 24, 24
        for key, atlas in pairs({ _normal = "RedButton-Exit", _pushed = "RedButton-exit-pressed",
                                  _disabled = "RedButton-Exit-Disabled", _highlight = "RedButton-Highlight" }) do
            cb[key] = blizz("Texture", cb)
            cb[key]._atlas = atlas
        end
        f.Inset = inset(f)
        f.FilterDropdown = blizz("DropdownButton", f)
        inset(f, "MerchantMoneyInset")
        -- The common case: no extra currency, so Blizzard hides its box
        -- (MerchantFrame_UpdateCurrencies, :1029-1035).
        inset(f, "MerchantExtraCurrencyInset")._shown = false
        blizz("Frame", f, "MerchantMoneyBg")
        blizz("Frame", f, "MerchantExtraCurrencyBg")._shown = false
        -- A button's own regions, as GetRegions lists them.
        local function region(parent, wtype, layer)
            local r = blizz(wtype, parent, nil, layer)
            table.insert(parent._regions, r)
            return r
        end
        -- The page buttons (MerchantFrame.xml:527-560): the label and the
        -- gold-rimmed background on BACKGROUND, the arrow in the state
        -- textures (ARTWORK).
        for _, n in ipairs({ "MerchantPrevPageButton", "MerchantNextPageButton" }) do
            local b = blizz("Button", f, n)
            b._width, b._height = 32, 32
            -- A state texture listed first: the background is found by its layer.
            b._normal = region(b, "Texture", "ARTWORK")
            region(b, "FontString", "BACKGROUND")
            region(b, "Texture", "BACKGROUND")._atlas = "UI-PageButton-Background"
            b._disabled = region(b, "Texture", "ARTWORK")
        end
        -- The band's left box (MerchantFrame.xml:200-330): the repair buttons
        -- and the sell-junk button, each a slot on BACKGROUND and its Icon,
        -- hidden until Blizzard's update shows them.
        for _, n in ipairs({ "MerchantRepairAllButton", "MerchantRepairItemButton", "MerchantGuildBankRepairButton",
                             "MerchantSellAllJunkButton" }) do
            local b = blizz("Button", f, n)
            b._width, b._height, b._shown = 36, 36, false
            b.Icon = region(b, "Texture", "BORDER")
            region(b, "Texture", "BACKGROUND")._atlas = "UI-EmptySlot"
        end
        blizz("Texture", f, "MerchantFrameBottomLeftBorder", "OVERLAY")
        blizz("Texture", f, "BuybackBG", "BACKGROUND")._shown = false
        -- MerchantItemTemplate rows (level 2), and the buyback slot, whose
        -- NameFrame is hidden in XML. Each ItemButton has its icon.
        local function itemRow(name)
            local row = blizz("Frame", f, name)
            row.SlotTexture = blizz("Texture", row, name .. "SlotTexture", "BACKGROUND")
            local plate = blizz("Texture", row, name .. "NameFrame", "BACKGROUND")
            plate._vertex = { 0.5, 0.5, 0.5, 1 }
            row.Name = blizz("FontString", row, name .. "Name", "BACKGROUND")
            row.ItemButton = blizz("Button", row, name .. "ItemButton")
            row.ItemButton.icon = blizz("Texture", row.ItemButton, name .. "ItemButtonIconTexture", "BORDER")
            return row
        end
        for i = 1, 12 do itemRow("MerchantItem" .. i) end
        itemRow("MerchantBuyBackItem")
        MerchantBuyBackItemNameFrame._shown = false
        tab(f, "MerchantFrameTab1")
        tab(f, "MerchantFrameTab2")
        -- A mixin method, so a call from addon code shows up in WoW.luaCalls.
        luaMethod(f, "UpdateMerchant", function() end)
        WoW.merchantTab(1)
        WoW.snapshot()
    end)
    return MerchantFrame
end

-- The vendor's band (MerchantFrame.lua:482, 987-1020): repair (and guild bank
-- repair) and sell-junk, applied on the Merchant tab in Blizzard's order.
WoW.merchantVendor = { repair = false, guild = false, junk = false }
local function vendorBand()
    local v = WoW.merchantVendor
    if v.repair then                                        -- MerchantFrame_UpdateRepairButtons, :413
        if v.guild then MerchantGuildBankRepairButton:Show() else MerchantGuildBankRepairButton:Hide() end
        MerchantRepairAllButton:Show()
        MerchantRepairItemButton:Show()
    else
        MerchantRepairAllButton:Hide()
        MerchantRepairItemButton:Hide()
        MerchantGuildBankRepairButton:Hide()
    end
    MerchantBuyBackItem:Show()                              -- :479
    MerchantSellAllJunkButton:SetShown(v.junk)              -- :482, last, never the Lua Show/Hide
end

-- A vendor's band changing (another vendor, or the same one updated).
function WoW.merchantBand(repair, guild, junk)
    WoW.merchantVendor = { repair = repair, guild = guild, junk = junk }
    WoW.asBlizzard(function()
        if MerchantBuyBackItem:IsShown() then vendorBand() end
    end)
end

-- Blizzard's currency box (MerchantFrame_UpdateCurrencies, :1029-1039).
function WoW.merchantCurrencies(n)
    WoW.asBlizzard(function()
        if n == 0 then
            MerchantExtraCurrencyInset:Hide(); MerchantExtraCurrencyBg:Hide()
        else
            MerchantExtraCurrencyInset:Show(); MerchantExtraCurrencyBg:Show()
        end
    end)
end

-- Blizzard's page buttons (MerchantFrame.lua:438-458).
function WoW.merchantPage(page, pages)
    WoW.asBlizzard(function()
        if page == 1 then MerchantPrevPageButton:Disable() else MerchantPrevPageButton:Enable() end
        if page == pages then MerchantNextPageButton:Disable() else MerchantNextPageButton:Enable() end
    end)
end

-- Blizzard selecting merchant tab i (PanelTemplates_SelectTab and the buyback
-- page's art, MerchantFrame.lua:480-593): Show/Hide, never an alpha. The
-- Buyback tab hides the band's buttons (:588-596).
function WoW.merchantTab(i)
    WoW.asBlizzard(function()
        for n = 1, 2 do
            local t = _G["MerchantFrameTab" .. n]
            local on = n == i
            t.Left:SetShown(not on); t.Middle:SetShown(not on); t.Right:SetShown(not on)
            t.LeftActive:SetShown(on); t.MiddleActive:SetShown(on); t.RightActive:SetShown(on)
            t:SetEnabled(not on)
        end
        BuybackBG:SetShown(i == 2)
        MerchantFrameBottomLeftBorder:SetShown(i == 1)
        MerchantItem11:SetShown(i == 2); MerchantItem12:SetShown(i == 2)
        if i == 1 then
            vendorBand()
        else
            MerchantRepairAllButton:Hide(); MerchantRepairItemButton:Hide()
            MerchantBuyBackItem:Hide()
            MerchantGuildBankRepairButton:Hide(); MerchantSellAllJunkButton:Hide()
        end
        WoW.bset(MerchantFrame, "selectedTab", i)
    end)
end

-- Blizzard filling merchant row i (MerchantFrame.lua:369-404): "normal",
-- "red" (can't use or afford), "darkred" (that, sold out) or "empty" (no
-- item: its button hidden). The plate takes the vertex colour, never an alpha.
local ROW_PLATE = { normal = { 0.5, 0.5, 0.5 }, red = { 1, 0, 0 }, darkred = { 0.5, 0, 0 }, empty = { 0.5, 0.5, 0.5 } }
function WoW.merchantRow(i, kind)
    WoW.asBlizzard(function()
        local row = _G["MerchantItem" .. i]
        local c = ROW_PLATE[kind]
        row.ItemButton:SetShown(kind ~= "empty")
        _G["MerchantItem" .. i .. "NameFrame"]:SetVertexColor(c[1], c[2], c[3])
    end)
end

-- Blizzard's buyback slot (MerchantFrame.lua:415-430): an item's icon, or ""
-- when empty; its button never hides.
function WoW.buybackSlot(texture)
    WoW.asBlizzard(function() MerchantBuyBackItemItemButton.icon:SetTexture(texture or "") end)
end

-- Blizzard's side writes its own fields through here: the snapshot follows.
function WoW.bset(t, k, v)
    rawset(t, k, v)
    if WoW.snap[t] then WoW.snap[t][k] = v end
end

-- Blizzard_DamageMeter (origin/forever @70450), with the regions SkinProbe
-- listed on 70450 (docs/FOREVER-PROBE.md, DM.1). DamageMeter, then its session
-- windows, each made by its SetupSessionWindow (a mixin method, so an addon
-- call shows in WoW.luaCalls) as "DamageMeterSessionWindow" .. index, reused
-- when it exists. MinimizeContainer uses the window's level (useParentLevel).
-- One bar per window, in WoW.meterBars[index].
WoW.meterBars = {}
local function meterWindow(meter, i)
    local w = blizz("Frame", meter, "DamageMeterSessionWindow" .. i)
    w._level = i
    w.Header = blizz("Texture", w, nil, "BACKGROUND")
    w.SessionTimer = blizz("FontString", w, nil, "OVERLAY")
    w.MinimizeButton = blizz("Button", w)
    w.SettingsDropdown = blizz("DropdownButton", w)
    w.SessionDropdown = blizz("DropdownButton", w)
    w.DamageMeterTypeDropdown = blizz("DropdownButton", w)
    w.DamageMeterTypeDropdown.TypeName = blizz("FontString", w.DamageMeterTypeDropdown, nil, "OVERLAY")
    w.DamageMeterTypeDropdown.TypeName._textColor = { 1, 0.82, 0, 1 }   -- GameFontNormalMed1's gold
    local mc = blizz("Frame", w)
    mc._level = i
    w.MinimizeContainer = mc
    mc.Background = blizz("Texture", mc, nil, "BACKGROUND")
    mc.Background:SetAlpha(0.5)
    mc.ScrollBox = blizz("Frame", mc)
    mc.ResizeButton = blizz("Button", mc)
    local bar = blizz("Button", mc.ScrollBox)
    bar.StatusBar = blizz("StatusBar", bar)
    bar.StatusBar.Background = blizz("Texture", bar.StatusBar, nil, "BACKGROUND")
    bar.StatusBar.BackgroundEdge = blizz("Texture", bar.StatusBar, nil, "OVERLAY")
    bar.StatusBar.Name = blizz("FontString", bar.StatusBar, nil, "OVERLAY")
    WoW.meterBars[i] = bar
    local src = blizz("Frame", mc)
    src._level = 3
    src._shown = false
    mc.SourceWindow = src
    src.Background = blizz("Texture", src, nil, "BACKGROUND")
    src.CloseButton = blizz("Button", src)
    return w
end

function WoW.makeMeter()
    WoW.asBlizzard(function()
        local m = blizz("Frame", UIParent, "DamageMeter")
        m._shown = false
        luaMethod(m, "SetupSessionWindow", function(self, i)
            local w = rawget(_G, "DamageMeterSessionWindow" .. i) or meterWindow(self, i)
            WoW.snapshot()
            w:Show()
            return w
        end)
        luaMethod(m, "ForEachSessionWindow", function() end)
        m:SetupSessionWindow(1)
        WoW.snapshot()
    end)
    return DamageMeter
end

-- Blizzard's side of the meter: shown by its Visibility setting, a window
-- added (or shown again) from the gear menu, hidden, minimized, and the
-- Background setting (UpdateBackground: the background's alpha).
function WoW.showMeter() WoW.asBlizzard(function() DamageMeter:Show() end) end
function WoW.hideMeter() WoW.asBlizzard(function() DamageMeter:Hide() end) end
function WoW.meterWindow(i) WoW.asBlizzard(function() DamageMeter:SetupSessionWindow(i) end) end
function WoW.meterHideWindow(i) WoW.asBlizzard(function() _G["DamageMeterSessionWindow" .. i]:Hide() end) end
function WoW.meterMinimize(i, on)
    WoW.asBlizzard(function() _G["DamageMeterSessionWindow" .. i].MinimizeContainer:SetShown(not on) end)
end
function WoW.meterBackground(i, alpha)
    WoW.asBlizzard(function() _G["DamageMeterSessionWindow" .. i].MinimizeContainer.Background:SetAlpha(alpha) end)
end
function WoW.meterBreakdown(i, on)
    WoW.asBlizzard(function() _G["DamageMeterSessionWindow" .. i].MinimizeContainer.SourceWindow:SetShown(on) end)
end

-- Blizzard's objective tracker (Mainline, as Forever runs it), Glass Quest
-- Tracker's stub (measured on 70374): the container with its NineSlice and
-- Header, the eleven module instances with their headers, each module's pooled
-- extras, and EditModeManagerFrame.
local function blizzTexture(parent, atlas)
    local t = blizz("Texture", parent)
    t._atlas = atlas
    return t
end

local function blizzButton(parent, normal, pushed, highlight, disabled)
    local b = blizz("Button", parent)
    b._normal = blizzTexture(b, normal)
    b._pushed = blizzTexture(b, pushed)
    b._highlight = blizzTexture(b, highlight)
    if disabled then b._disabled = blizzTexture(b, disabled) end
    return b
end

local function makeHeader(parent, bgAtlas, collapse, expand, withAnim)
    local h = blizz("Frame", parent)
    h.Background = blizzTexture(h, bgAtlas)
    h.Text = blizz("FontString", h)
    h.Text._textColor = { 1, 0.82, 0, 1 }   -- ObjectiveTrackerHeaderFont's gold
    h.MinimizeButton = blizzButton(h, collapse, collapse .. "-pressed", "ui-questtrackerbutton-red-highlight")
    if withAnim then
        h.Shine = blizzTexture(h, "UI-QuestTracker-OBJFX-Shine")
        h.Glow = blizzTexture(h, "UI-QuestTracker-OBJFX-BarGlow")
        h.Shine._alpha, h.Glow._alpha = 0, 0
    end
    luaMethod(h, "SetCollapsed", function(self, collapsed)
        local n, p = self.MinimizeButton:GetNormalTexture(), self.MinimizeButton:GetPushedTexture()
        n:SetAtlas(collapsed and expand or collapse)
        p:SetAtlas((collapsed and expand or collapse) .. "-pressed")
    end)
    return h
end

WoW.MODULE_NAMES = { "ScenarioObjectiveTracker", "UIWidgetObjectiveTracker", "CampaignQuestObjectiveTracker",
    "QuestObjectiveTracker", "AdventureObjectiveTracker", "AchievementObjectiveTracker",
    "MonthlyActivitiesObjectiveTracker", "InitiativeTasksObjectiveTracker", "ProfessionsRecipeTracker",
    "BonusObjectiveTracker", "WorldQuestObjectiveTracker" }

-- A module in the container's list. Named, as the client's are; one made
-- with addModule alone has no global: a module a later build added.
function WoW.addModule(name, global)
    local t = ObjectiveTrackerFrame
    local m
    WoW.asBlizzard(function()
        m = blizz("Frame", t, global and name or nil)
        rawset(m, "_name", name)
        m._shown = false
        m.Header = makeHeader(m, "UI-QuestTracker-Secondary-Objective-Header",
            "ui-questtrackerbutton-secondary-collapse", "ui-questtrackerbutton-secondary-expand", true)
        luaMethod(m, "EndLayout", function() end)
        table.insert(t.modules, m)
        WoW.snapshot()
    end)
    return m
end

function WoW.makeTracker()
    WoW.asBlizzard(function()
        local t = blizz("Frame", UIParent, "ObjectiveTrackerFrame")
        t._width, t._height = 260, 800
        t.NineSlice = blizz("Frame", t)
        t.NineSlice._level = t._level
        t.NineSlice._alpha = 0
        t.Header = makeHeader(t, "ui-questtracker-primary-objective-header", "ui-questtrackerbutton-collapse-all",
            "ui-questtrackerbutton-expand-all")
        t.Header.FilterButton = blizzButton(t.Header, "ui-questtrackerbutton-filter",
            "ui-questtrackerbutton-filter-pressed", "ui-questtrackerbutton-red-highlight")
        t.isCollapsed = false
        t.modules = {}
        for _, name in ipairs(WoW.MODULE_NAMES) do WoW.addModule(name, true) end
        local em = blizz("Frame", UIParent, "EditModeManagerFrame")
        em._shown = false
        WoW.snapshot()
    end)
    return ObjectiveTrackerFrame
end

-- Blizzard's quest timers (Blizzard_QuestTimer, Mainline): the tracker's
-- child, hidden until a timed quest. Its Border is a DialogBorderTemplate
-- (a NineSlice at its level, useParentLevel, with a Bg), its Header a
-- DialogHeaderTemplate (three pieces and a Text in GameFontNormal's gold),
-- its rows pooled buttons with a Name.
function WoW.makeQuestTimer()
    WoW.asBlizzard(function()
        local q = blizz("Frame", ObjectiveTrackerFrame, "QuestTimerFrame")
        q._shown = false
        q._width, q._height = 158, 72
        q.Border = nineSlice(q)
        q.Border._level = q._level
        q.Border.Bg = blizz("Texture", q.Border, nil, "BACKGROUND")
        q.Header = blizz("Frame", q)
        for _, k in ipairs({ "LeftBG", "RightBG", "CenterBG" }) do q.Header[k] = blizz("Texture", q.Header, nil, "ARTWORK") end
        q.Header.Text = blizz("FontString", q.Header)
        q.Header.Text._textColor = { 1, 0.82, 0, 1 }
        q.activeElements = {}
        WoW.snapshot()
    end)
    return QuestTimerFrame
end

-- n quest timers (0: none), as UpdateQuestTimers drives them, then the
-- tracker's Header moved down by the timer's padding, its height + 18 while
-- shown (UpdateHeaderPosition).
function WoW.questTimers(n)
    local q, t = QuestTimerFrame, ObjectiveTrackerFrame
    WoW.asBlizzard(function()
        for i = 1, n do
            if not q.activeElements[i] then
                local b = blizz("Button", q)
                b.Name = blizz("FontString", b)
                b.Name._textColor = { 1, 1, 1, 1 }
                q.activeElements[i] = b
            end
        end
        for i = n + 1, #q.activeElements do q.activeElements[i] = nil end
        if n > 0 then
            q:SetHeight(43 + 16 * n)
            q:Show()
        else
            q:Hide()
        end
        t.Header:ClearAllPoints()
        t.Header:SetPoint("TOPLEFT", t, "TOPLEFT", 0, q:IsShown() and -(43 + 16 * n + 18) or 0)
        WoW.snapshot()
    end)
end

-- One layout of module `name` (a global name, or the module), the way the
-- container drives it: the pools this layout uses (spec.items item buttons,
-- spec.groups find-group buttons, spec.bars progress bars), shown when it has
-- anything, then EndLayout. The NineSlice's BOTTOM follows the last shown
-- module (Container.lua:117).
function WoW.layout(name, spec)
    spec = spec or {}
    local t, m = ObjectiveTrackerFrame, type(name) == "table" and name or rawget(_G, name)
    WoW.asBlizzard(function()
        local edge = {}
        for i = 1, spec.items or 0 do
            local key = "item" .. i
            edge[key] = (m.usedRightEdgeFrames or {})[key] or blizzButton(m, "UI-QuestTrackerButton-QuestItem-Frame",
                "UI-QuestTrackerButton-QuestItem-Frame", nil)
        end
        for i = 1, spec.groups or 0 do
            local key = "group" .. i
            edge[key] = (m.usedRightEdgeFrames or {})[key] or blizzButton(m, nil, nil, nil, "disabled")
        end
        WoW.bset(m, "usedRightEdgeFrames", edge)
        local bars = {}
        for i = 1, spec.bars or 0 do
            local key = "bar" .. i
            local p = (m.usedProgressBars or {})[key]
            if not p then
                p = blizz("Frame", m)
                p.Bar = blizz("StatusBar", p)
                p.Bar.BorderLeft = blizz("Texture", p.Bar)
                p.Bar.BorderRight = blizz("Texture", p.Bar)
                p.Bar.BorderMid = blizz("Texture", p.Bar)
            end
            bars[key] = p
        end
        WoW.bset(m, "usedProgressBars", bars)
        local shown = spec.shown
        if shown == nil then shown = (spec.blocks or 0) > 0 or (spec.items or 0) > 0 or (spec.bars or 0) > 0 end
        m._shown = shown and not t.isCollapsed
        if m._shown then
            t.NineSlice:ClearAllPoints()
            t.NineSlice:SetPoint("TOPLEFT", t, "TOPLEFT", -30, 0)
            t.NineSlice:SetPoint("TOPRIGHT", t, "TOPRIGHT", 5, 0)
            t.NineSlice:SetPoint("BOTTOM", m, "BOTTOM", 0, -10)
        end
        WoW.snapshot()
        m:EndLayout()
    end)
end

-- The player clicks the container's collapse button: ContainerMixin:SetCollapsed
-- sets isCollapsed and the Header's button, with the modules still shown;
-- the layouts that follow hide them (drive those with WoW.layout).
function WoW.collapse(collapsed)
    local t = ObjectiveTrackerFrame
    WoW.asBlizzard(function()
        WoW.bset(t, "isCollapsed", collapsed)
        t.Header:SetCollapsed(collapsed)
    end)
end

-- The player collapses one module's section (Blizzard_ObjectiveTrackerModule.lua:479).
function WoW.collapseModule(name, collapsed)
    WoW.asBlizzard(function()
        local m = rawget(_G, name)
        WoW.bset(m, "isCollapsed", collapsed)
        m.Header:SetCollapsed(collapsed)
    end)
end

-- Edit Mode opens or closes (EditModeManagerFrame's OnShow / OnHide).
function WoW.editMode(on)
    WoW.asBlizzard(function() EditModeManagerFrame:SetShown(on) end)
end
function WoW.showTracker() WoW.asBlizzard(function() ObjectiveTrackerFrame:Show() end) end
function WoW.hideTracker() WoW.asBlizzard(function() ObjectiveTrackerFrame:Hide() end) end

function WoW.showMerchant() WoW.asBlizzard(function() MerchantFrame:Show() end) end

-- The bag windows (#88, Mainline ContainerFrame on Forever, origin/forever
-- 70450): ContainerFrame1..7 and ContainerFrameCombinedBags on
-- PortraitFrameFlatTemplate (NineSlice; Bg, a frame of four textures; the
-- portrait and its mask; the close button), the backpack's and the combined
-- window's money frames with their coin box, the shared search box and sort
-- button. Each window's UpdateItems fills its pooled item buttons from
-- WoW.bagContents[frame] ("empty" or an icon file), as Blizzard does
-- (ContainerFrame.lua:1048-1080, 1191-1239). Hidden.
local function flatWindow(name, parent)
    local f = blizz("Frame", parent, name)
    f._shown, f._level, f._strata = false, 2, "MEDIUM"
    f._width, f._height = 178, 200
    f.NineSlice = nineSlice(f)
    f.Bg = blizz("Frame", f)
    for _, k in ipairs({ "BottomLeft", "BottomRight", "BottomEdge", "TopSection" }) do
        f.Bg[k] = blizz("Texture", f.Bg, nil, "BACKGROUND")
    end
    f.PortraitContainer = blizz("Frame", f)
    f.PortraitContainer._level = 400
    -- 36 px (SetPortraitTextureSizeAndOffset, ContainerFrame.lua:789); the mask
    -- read about four times wider in game (BG.1, 70450).
    f.PortraitContainer.portrait = blizz("Texture", f.PortraitContainer, nil, "OVERLAY")
    f.PortraitContainer.portrait._width, f.PortraitContainer.portrait._height = 36, 36
    f.PortraitContainer.CircleMask = blizz("MaskTexture", f.PortraitContainer)
    f.PortraitContainer.CircleMask._width, f.PortraitContainer.CircleMask._height = 140, 140
    f.TitleContainer = blizz("Frame", f)
    f.TitleContainer.TitleText = blizz("FontString", f.TitleContainer, nil, "OVERLAY")
    local cb = blizz("Button", f)
    cb._level, cb._width, cb._height = 510, 24, 24
    for key, atlas in pairs({ _normal = "RedButton-Exit", _pushed = "RedButton-exit-pressed",
                              _disabled = "RedButton-Exit-Disabled", _highlight = "RedButton-Highlight" }) do
        cb[key] = blizz("Texture", cb)
        cb[key]._atlas = atlas
    end
    f.CloseButton = cb
    f.PortraitButton = blizz("DropdownButton", f)
    return f
end

local function moneyFrame(parent, name)
    local m = blizz("Frame", parent, name)
    m.Border = blizz("Frame", m)
    for _, k in ipairs({ "Left", "Middle", "Right" }) do m.Border[k] = blizz("Texture", m.Border, nil, "BACKGROUND") end
    return m
end

-- An item button of ContainerFrameItemButtonTemplate as of 70707
-- (ContainerFrame.xml:77, 70888): its regions, the hidden EmptyBagIcon
-- (:153); no empty atlas key and no slot background any more.
local function itemButton(frame)
    local b = blizz("Button", frame)
    b._width, b._height = 37, 37
    b._level = frame._level + 1
    b.icon = blizz("Texture", b, nil, "BORDER")
    b.IconBorder = blizz("Texture", b, nil, "OVERLAY")
    b.Count = blizz("FontString", b, nil, "ARTWORK")
    b.NewItemTexture = blizz("Texture", b, nil, "OVERLAY")
    b.EmptyBagIcon = blizz("Texture", b, nil, "ARTWORK")
    b.EmptyBagIcon._shown = false
    b._normal = blizz("Texture", b, nil, "ARTWORK")
    b._normal._file = "Interface\\Buttons\\UI-Quickslot2"
    return b
end

WoW.bagContents = setmetatable({}, { __mode = "k" })
WoW.bagButtons = setmetatable({}, { __mode = "k" })

local function isCombined(b) return b:GetParent() == rawget(_G, "ContainerFrameCombinedBags") end

-- SyncAppearanceWithHasItem (:1962) and SetAppearanceToEmptyBagSlot (:1940):
-- the bag's icon greyed in a combined empty slot, then SetItemButtonTexture(nil)
-- puts the empty atlas on the icon (GetItemButtonBackgroundTexture, :1953).
local function syncAppearance(b)
    if rawget(b, "hasItem") then b.EmptyBagIcon:Hide() return end
    local combined = isCombined(b)
    b.EmptyBagIcon:SetShown(combined)
    if combined then
        b.EmptyBagIcon:SetTexture(133633)
        b.EmptyBagIcon:SetVertexColor(1, 1, 1, 0.6)
    end
    b.icon:SetAtlas(combined and "bags-item-slot-blank" or "bags-item-slot64")
end

-- UpdateItems (:1189-1225): SetHasItem first, then the icon, then the sync.
local function updateItems(frame)
    local list = WoW.bagContents[frame] or {}
    local pool = WoW.bagButtons[frame]
    for _, b in ipairs(pool) do b:Hide() end                -- ReleaseAll
    for i, item in ipairs(list) do
        local b = pool[i]
        if not b then b = itemButton(frame); pool[i] = b end   -- Acquire
        b:Show()
        local filled = item ~= "empty"
        rawset(b, "hasItem", filled and 1 or nil)             -- SetHasItem(texture)
        if filled then
            b.icon:SetTexture(item)
            b.IconBorder:Show()
            b.IconBorder:SetVertexColor(0.1, 0.4, 1)
        else
            b.IconBorder:Hide()
        end
        syncAppearance(b)
    end
end

-- UpdateCooldowns (:1249): each button's state from the client, then the sync,
-- without UpdateItems (so none of Glass UI's UpdateItems post-hook either).
local function updateCooldowns(frame)
    local list = WoW.bagContents[frame] or {}
    for i, b in ipairs(WoW.bagButtons[frame]) do
        if b:IsShown() then
            local filled = list[i] ~= nil and list[i] ~= "empty"
            rawset(b, "hasItem", filled and 1 or nil)
            syncAppearance(b)
        end
    end
end

function WoW.makeBags()
    WoW.asBlizzard(function()
        local holder = blizz("Frame", UIParent, "ContainerFrameContainer")
        for i = 1, 7 do
            local f = flatWindow("ContainerFrame" .. i, holder)
            WoW.bagButtons[f] = {}
            luaMethod(f, "UpdateItems", updateItems)
        end
        moneyFrame(ContainerFrame1, "ContainerFrame1MoneyFrame")
        local c = flatWindow("ContainerFrameCombinedBags", UIParent)
        c._width = 430
        c.MoneyFrame = moneyFrame(c)
        WoW.bagButtons[c] = {}
        luaMethod(c, "UpdateItems", updateItems)
        local box = blizz("EditBox", ContainerFrame1, "BagItemSearchBox")
        box._shown, box._level = false, 5
        for _, k in ipairs({ "Left", "Middle", "Right" }) do box[k] = blizz("Texture", box, nil, "BACKGROUND") end
        local sort = blizz("Button", ContainerFrame1, "BagItemAutoSortButton")
        sort._shown, sort._width, sort._height = false, 28, 26
        WoW.snapshot()
    end)
end

-- Blizzard opening a bag window with these contents (ContainerFrame_GenerateFrame,
-- :1292: Show, then the items), or updating it (BAG_UPDATE -> UpdateItems).
function WoW.openBag(frame, contents)
    WoW.bagContents[frame] = contents
    WoW.asBlizzard(function()
        frame:Show()
        frame:UpdateItems()
    end)
end
function WoW.bagUpdate(frame, contents)
    WoW.bagContents[frame] = contents
    WoW.asBlizzard(function() frame:UpdateItems() end)
end
function WoW.closeBag(frame) WoW.asBlizzard(function() frame:Hide() end) end
-- A cooldown update (BAG_UPDATE_COOLDOWN -> UpdateCooldowns) with these contents.
function WoW.bagCooldowns(frame, contents)
    WoW.bagContents[frame] = contents
    WoW.asBlizzard(function() updateCooldowns(frame) end)
end

-- The Escape menu (#90, Blizzard_GameMenu, MainMenuFrameTemplate on Forever,
-- origin/forever 70450): its Border (DialogBorderTemplate: the NineSlice frame
-- itself, its tiled Bg), its Header (three diamond-metal pieces and Text),
-- and a button pool. InitButtons releases every button and acquires one per
-- entry in WoW.gameMenuEntries, calling SetScript on each as Blizzard's
-- AddButton does (MainMenuFrameTemplates.lua:13-60). Hidden.
WoW.gameMenuEntries = { "Options", "AddOns", "Edit Mode", "Support", "Macros", "Log Out", "Exit Game",
                        "Return to Game" }
local function menuButton(menu)
    local b = blizz("Button", menu)
    b._width, b._height = 200, 36
    for _, k in ipairs({ "Left", "Right", "Center" }) do b[k] = blizz("Texture", b, nil, "BACKGROUND") end
    b._highlight = blizz("Texture", b, nil, "HIGHLIGHT")
    b._highlight._atlas = "128-RedButton-Highlight"
    return b
end

function WoW.makeGameMenu()
    WoW.asBlizzard(function()
        local m = blizz("Frame", UIParent, "GameMenuFrame")
        m._shown, m._level, m._strata = false, 1, "DIALOG"
        m._width, m._height = 260, 400
        m.Border = nineSlice(m)
        m.Border.Bg = blizz("Texture", m.Border, nil, "BACKGROUND")
        m.Header = blizz("Frame", m)
        m.Header._level = 2
        for _, k in ipairs({ "LeftBG", "RightBG", "CenterBG" }) do m.Header[k] = blizz("Texture", m.Header, nil, "ARTWORK") end
        m.Header.Text = blizz("FontString", m.Header, nil, "ARTWORK")
        m.NewOptionsFrame = blizz("Frame", m)
        local pool = {}
        WoW.gameMenuPool = pool
        luaMethod(m, "InitButtons", function(self)
            for _, b in ipairs(pool) do b:Hide() end              -- Reset: ReleaseAll
            for i, text in ipairs(WoW.gameMenuEntries) do
                local b = pool[i]
                if not b then b = menuButton(self); pool[i] = b end   -- Acquire
                b:SetText(text)
                b:SetScript("OnClick", function() end)
                b:SetScript("OnEnter", nil)
                b:SetScript("OnLeave", nil)
                b:SetEnabled(text ~= "Support" or not WoW.gameMenuSupportOff)
                b:Show()
            end
        end)
        -- OnShow runs InitButtons first (GameMenuFrame.lua:69-84): the
        -- engine's hook comes after it.
        m:SetScript("OnShow", function(self) self:InitButtons() end)
        WoW.snapshot()
    end)
end

function WoW.showGameMenu() WoW.asBlizzard(function() GameMenuFrame:Show() end) end
function WoW.hideGameMenu() WoW.asBlizzard(function() GameMenuFrame:Hide() end) end
-- A store or trial event while it's open (GameMenuFrame.lua:96-102).
function WoW.gameMenuRefresh() WoW.asBlizzard(function() GameMenuFrame:InitButtons() end) end

-- Guild & Communities (#92, Blizzard_Communities on Forever, origin/forever
-- 70450): ButtonFrameTemplateMinimizable's shell, PortraitOverlay (level 300)
-- with its Portrait and CircleMask, the community list, the chat, the edit
-- box (level 1200), the roster with its ColumnDisplay (every hook on it is
-- recorded in WoW.rosterHooks), the five RightSideTabTemplate tabs, the
-- maximize/minimize buttons, the Invite, log and control buttons. Display
-- modes show and hide the sections as SetDisplayMode does (lua:585-704), and
-- UpdateCommunitiesTabs unchecks the five then checks one (lua:1119-1133).
-- Hidden.
local function sideTab(cf, name)
    local t = blizz("CheckButton", cf, nil)
    t._width, t._height, t._level = 32, 32, 510
    local border = blizz("Texture", t, nil, "BORDER")
    table.insert(t._regions, border)
    t.Icon = blizz("Texture", t, nil, "ARTWORK")
    table.insert(t._regions, t.Icon)
    t._checkedTex = blizz("Texture", t, nil, "OVERLAY")
    t._highlight = blizz("Texture", t, nil, "HIGHLIGHT")
    t._checked = false
    cf[name] = t
    return t
end

local function panelButton(parent)
    local b = blizz("Button", parent)
    for _, k in ipairs({ "Left", "Middle", "Right" }) do b[k] = blizz("Texture", b, nil, "BACKGROUND") end
    return b
end

WoW.guildModes = {
    CHAT = { "CommunitiesList", "Chat", "ChatEditBox", "MemberList" },
    ROSTER = { "CommunitiesList", "MemberList" },
    GUILD_BENEFITS = { "CommunitiesList" },
    GUILD_INFO = { "CommunitiesList" },
    MINIMIZED = { "Chat", "ChatEditBox" },
}
WoW.guildModeTab = { CHAT = "ChatTab", ROSTER = "RosterTab", GUILD_BENEFITS = "GuildBenefitsTab",
                     GUILD_INFO = "GuildInfoTab" }

function WoW.makeCommunities()
    WoW.asBlizzard(function()
        local cf = blizz("Frame", UIParent, "CommunitiesFrame")
        cf._shown, cf._level = false, 1
        cf._width, cf._height = 814, 426
        cf.NineSlice = nineSlice(cf)
        cf.Bg = blizz("Texture", cf, nil, "BACKGROUND")
        cf.TopTileStreaks = blizz("Texture", cf, nil, "BORDER")
        cf.Inset = inset(cf)
        cf.TitleContainer = blizz("Frame", cf)
        cf.TitleContainer.TitleText = blizz("FontString", cf.TitleContainer, nil, "OVERLAY")
        local cb = blizz("Button", cf)
        cb._level, cb._width, cb._height = 510, 24, 24
        for key, atlas in pairs({ _normal = "RedButton-Exit", _pushed = "RedButton-exit-pressed",
                                  _disabled = "RedButton-Exit-Disabled", _highlight = "RedButton-Highlight" }) do
            cb[key] = blizz("Texture", cb)
            cb[key]._atlas = atlas
        end
        cf.CloseButton = cb
        local po = blizz("Frame", cf)
        po._level = 300
        po.Portrait = blizz("Texture", po, nil, "OVERLAY")
        po.Portrait._width, po.Portrait._height = 60, 60
        po.CircleMask = blizz("MaskTexture", po)
        po.CircleMask._width, po.CircleMask._height = 58, 58
        po.TabardEmblem = blizz("Texture", po, nil, "ARTWORK")
        cf.PortraitOverlay = po
        local mm = blizz("Frame", cf)
        mm._level = 510
        for _, k in ipairs({ "MaximizeButton", "MinimizeButton" }) do
            local b = blizz("Button", mm)
            b._normal = blizz("Texture", b)
            b._pushed = blizz("Texture", b)
            b._disabled = blizz("Texture", b)
            mm[k] = b
        end
        cf.MaximizeMinimizeFrame = mm
        local list = blizz("Frame", cf)
        list._level = 3
        for _, k in ipairs({ "Bg", "TopFiligree", "BottomFiligree", "FilligreeOverlay" }) do
            list[k] = blizz("Texture", list, nil, "BACKGROUND")
        end
        list.InsetFrame = inset(list)
        list.ScrollBox = blizz("Frame", list)
        cf.CommunitiesList = list
        local chat = blizz("Frame", cf)
        chat._level = 3
        chat.InsetFrame = inset(chat)
        chat.MessageFrame = blizz("Frame", chat)
        cf.Chat = chat
        local eb = blizz("EditBox", cf)
        eb._level = 1200
        for _, k in ipairs({ "Left", "Right", "Mid" }) do eb[k] = blizz("Texture", eb, nil, "BACKGROUND") end
        cf.ChatEditBox = eb
        local roster = blizz("Frame", cf)
        roster._level = 3
        roster.InsetFrame = inset(roster)
        roster.ColumnDisplay = blizz("Frame", roster)
        roster.ScrollBox = blizz("Frame", roster)
        cf.MemberList = roster
        for _, n in ipairs({ "ChatTab", "RosterTab", "GuildBenefitsTab", "GuildInfoTab",
                             "GuildPreferredPlaySettingsTab" }) do
            sideTab(cf, n)
        end
        cf.InviteButton = panelButton(cf)
        cf.GuildLogButton = panelButton(cf)
        cf.CommunitiesControlFrame = blizz("Frame", cf)
        cf.CommunitiesControlFrame.GuildControlButton = panelButton(cf.CommunitiesControlFrame)
        cf.CommunitiesControlFrame.GuildRecruitmentButton = panelButton(cf.CommunitiesControlFrame)
        -- Any hook on the roster, its ColumnDisplay, InsetFrame or ScrollBox is
        -- recorded (before the snapshot: the stub's own fields).
        WoW.rosterHooks = {}
        for _, f in ipairs({ roster, roster.ColumnDisplay, roster.InsetFrame, roster.ScrollBox }) do
            local real = f.HookScript
            rawset(f, "HookScript", function(self, ...)
                if not WoW.inBlizzard then table.insert(WoW.rosterHooks, (...)) end
                return real(self, ...)
            end)
        end
        WoW.snapshot()
    end)
end

function WoW.guildMode(mode)
    WoW.asBlizzard(function()
        local cf = CommunitiesFrame
        local shown = {}
        for _, n in ipairs(WoW.guildModes[mode]) do shown[n] = true end
        for _, n in ipairs({ "CommunitiesList", "Chat", "ChatEditBox", "MemberList" }) do cf[n]:SetShown(shown[n] == true) end
        if mode == "MINIMIZED" then cf.PortraitOverlay:Hide() else cf.PortraitOverlay:Show() end
        -- UpdateCommunitiesTabs (lua:1119-1133).
        for _, n in ipairs({ "ChatTab", "RosterTab", "GuildBenefitsTab", "GuildInfoTab", "GuildPreferredPlaySettingsTab" }) do
            cf[n]:SetChecked(false)
        end
        local tab = WoW.guildModeTab[mode]
        if tab then cf[tab]:SetChecked(true) end
    end)
end
-- A click on a side tab: the native toggle (no SetChecked), then its OnClick.
function WoW.clickTab(tab)
    WoW.asBlizzard(function()
        rawset(tab, "_checked", not tab._checked)
        local fn = tab._scripts.OnClick
        if fn then fn(tab, "LeftButton") end
    end)
end
function WoW.showGuild() WoW.asBlizzard(function() CommunitiesFrame:Show() end) end
function WoW.hideGuild() WoW.asBlizzard(function() CommunitiesFrame:Hide() end) end

-- Forever's character window (#94, Camelot\CharacterFrame.xml and
-- PaperDollFrame.xml, origin/forever 70450): PortraitFrameBaseTemplate (no Bg
-- or Inset); the two pane hosts with their own art (the right one's StoneBg
-- and its divider child); the six large side tabs (Frames whose mixin
-- SetChecked shows SelectedTexture); the paper doll's level strip, model
-- background, slots (BorderFrame, NormalTexture, IconBorder) and the ammo
-- slot (its own BACKGROUND ring, an arrow child); the stats wrapper and its
-- inner list, whose Update acquires header rows (Background + Title) and stat
-- rows (Background + Label + Value) from WoW.statRows; the pet list; the four
-- sidebar CheckButtons; the currency pane (TokenFrame: its rows and transfer
-- toggle record any addon touch in WoW.currencyTouches). Hidden.
WoW.statRows = { "header", "stat", "stat", "header", "stat", "stat", "stat" }
WoW.paneRows = { ReputationFrame = { "header", "entry", "entry", "header", "sub", "entry" },
                 SkillsFrame = { "header", "entry", "header", "entry" },
                 StatisticsFrame = { "header", "header", "entry", "sub", "entry" } }
local function regionOn(parent, wtype, layer)
    local r = blizz(wtype, parent, nil, layer)
    table.insert(parent._regions, r)
    return r
end

local function largeTab(parent)
    local t = blizz("Frame", parent)
    t._width, t._height, t._level = 43, 55, 20
    t.Background = blizz("Texture", t, nil, "BACKGROUND")
    t.Icon = blizz("Texture", t, nil, "ARTWORK")
    t.SelectedTexture = blizz("Texture", t, nil, "OVERLAY")
    t.SelectedTexture._shown = false
    t.TabGlow = blizz("Texture", t, nil, "OVERLAY")
    -- SidePanelTabButtonMixin:SetChecked (SharedUIPanelTemplates.lua:391-401).
    luaMethod(t, "SetChecked", function(self, checked) self.SelectedTexture:SetShown(checked) end)
    return t
end

local function slotButton(parent, name)
    local b = blizz("Button", parent, name)
    b._width, b._height, b._level = 37, 37, 60
    b.icon = blizz("Texture", b, nil, "BORDER")
    b.IconBorder = blizz("Texture", b, nil, "OVERLAY")
    b._normal = blizz("Texture", b, nil, "ARTWORK")
    b.BorderFrame = blizz("Frame", b)
    regionOn(b.BorderFrame, "Texture", "BACKGROUND")
    return b
end

function WoW.makeCharacter()
    WoW.asBlizzard(function()
        local cf = blizz("Frame", UIParent, "CharacterFrame")
        cf._shown, cf._level, cf._width, cf._height = false, 10, 631, 484
        cf.NineSlice = nineSlice(cf)
        cf.PortraitContainer = blizz("Frame", cf)
        cf.PortraitContainer._level = 400
        cf.PortraitContainer.portrait = blizz("Texture", cf.PortraitContainer, "CharacterFramePortrait", "OVERLAY")
        cf.PortraitContainer.portrait._width = 62
        cf.PortraitContainer.CircleMask = blizz("MaskTexture", cf.PortraitContainer)
        cf.PortraitContainer.CircleMask._width = 58
        cf.TitleContainer = blizz("Frame", cf)
        cf.TitleContainer.TitleText = blizz("FontString", cf.TitleContainer, nil, "OVERLAY")
        local cb = blizz("Button", cf, "CharacterFrameCloseButton")
        cb._level, cb._width, cb._height = 510, 24, 24
        for key, atlas in pairs({ _normal = "RedButton-Exit", _pushed = "RedButton-exit-pressed",
                                  _disabled = "RedButton-Exit-Disabled", _highlight = "RedButton-Highlight" }) do
            cb[key] = blizz("Texture", cb)
            cb[key]._atlas = atlas
        end
        cf.CloseButton = cb
        local left = blizz("Frame", cf, "CharacterFrameLeftPaneHost")
        left._level = 11
        regionOn(left, "Texture", "BACKGROUND")
        cf.LeftPaneHost = left
        local right = blizz("Frame", cf, "CharacterFrameRightPaneHost")
        right._level = 11
        regionOn(right, "Texture", "BACKGROUND")
        right.StoneBg = regionOn(right, "Texture", "BORDER")
        local divider = blizz("Frame", right)
        divider._level = 505
        regionOn(divider, "Texture", "OVERLAY")
        cf.RightPaneHost = right
        cf.RightPaneToggleButton = blizz("Button", cf)
        cf.ModeTabs = blizz("Frame", cf)
        cf.ModeTabs.Tabs = {}
        for i = 1, 6 do cf.ModeTabs.Tabs[i] = largeTab(cf.ModeTabs) end
        -- The paper doll.
        local pd = blizz("Frame", cf, "PaperDollFrame")
        pd._level = 10
        local strip = blizz("Frame", pd)
        strip._level = 50
        strip.TopBackgroundStrip = blizz("Texture", strip, nil, "BACKGROUND")
        strip.TopBackgroundStripBottomEdge = blizz("Texture", strip, nil, "BORDER")
        pd.TopBackgroundStripHost = strip
        local model = blizz("ModelScene", pd, "CharacterModelScene")
        model._level = 50
        for _, k in ipairs({ "BackgroundTopLeft", "BackgroundTopRight", "BackgroundBotLeft", "BackgroundBotRight",
                             "BackgroundOverlay" }) do
            model[k] = blizz("Texture", model, nil, "BACKGROUND")
        end
        model.ControlFrame = blizz("Frame", model)
        for _, n in ipairs({ "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist", "Hands",
                             "Waist", "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1", "MainHand",
                             "SecondaryHand", "Ranged" }) do
            slotButton(pd, "Character" .. n .. "Slot")
        end
        local ammo = blizz("Button", pd, "CharacterAmmoSlot")
        ammo._width, ammo._height, ammo._level = 20, 20, 60
        regionOn(ammo, "Texture", "BACKGROUND")
        ammo.iconTexture = regionOn(ammo, "Texture", "BORDER")      -- $parentIconTexture
        ammo._normal = blizz("Texture", ammo, nil, "ARTWORK")
        local arrow = blizz("Frame", ammo)
        regionOn(arrow, "Texture", "OVERLAY")
        ammo.arrowFrame = arrow
        -- The stats wrapper, its inner list, the pet list.
        local stats = blizz("Frame", cf, "CharacterStatsPaneScrollBox")
        stats._level = 12
        stats.Border = blizz("Texture", stats, nil, "BORDER")
        stats.ClassBackground = blizz("Texture", stats, nil, "BACKGROUND")
        local list = blizz("Frame", stats)
        list._level = 13
        list.ScrollTarget = blizz("Frame", list)
        stats.ScrollBox = list
        stats.ScrollBar = blizz("Frame", stats)
        local pool = {}
        WoW.statPool = pool
        luaMethod(list, "Update", function(self)
            for _, r in ipairs(pool) do r:Hide() end
            for i, kind in ipairs(WoW.statRows) do
                local r = pool[i]
                if not r or r._kind ~= kind then
                    r = blizz("Frame", self.ScrollTarget)
                    r._kind = kind
                    r.Background = blizz("Texture", r, nil, "BACKGROUND")
                    if kind == "header" then
                        r.Title = blizz("FontString", r, nil, "OVERLAY")
                    else
                        r.Label = blizz("FontString", r, nil, "OVERLAY")
                        r.Value = blizz("FontString", r, nil, "OVERLAY")
                    end
                    pool[i] = r
                end
                r:Show()
            end
        end)
        local pet = blizz("Frame", cf, "CharacterStatsPanePetScrollBox")
        pet.Border = blizz("Texture", pet, nil, "BORDER")
        pet.ScrollBox = blizz("Frame", pet)
        pet.ScrollBox.ScrollTarget = blizz("Frame", pet.ScrollBox)
        local prow = blizz("Frame", pet.ScrollBox.ScrollTarget)
        prow.Background = blizz("Texture", prow, nil, "BACKGROUND")
        prow.Title = blizz("FontString", prow, nil, "OVERLAY")
        WoW.petHeader = prow
        for i = 1, 4 do
            local t = blizz("CheckButton", cf, "PaperDollSidebarTab" .. i)
            t._width, t._height, t._level = 33, 35, 20
            t.Icon = regionOn(t, "Texture", "BACKGROUND")
            regionOn(t, "Texture", "BORDER")
            t._checkedTex = blizz("Texture", t, nil, "OVERLAY")
            t._highlight = blizz("Texture", t, nil, "HIGHLIGHT")
        end
        -- The list panes (reputation, skills, statistics): their lists acquire
        -- top headers (an unnamed BACKGROUND bar and HIGHLIGHT copy, StateIcon,
        -- Name), entries (a Content) and sub-headers (a Content and a
        -- ToggleCollapseButton) from WoW.paneRows[pane] at each Update.
        WoW.panePools = {}
        for _, name in ipairs({ "ReputationFrame", "SkillsFrame", "StatisticsFrame" }) do
            local pane = blizz("Frame", cf, name)
            pane._shown = false
            local plist = blizz("Frame", pane)
            plist.ScrollTarget = blizz("Frame", plist)
            pane.ScrollBox = plist
            local ppool = {}
            WoW.panePools[name] = ppool
            luaMethod(plist, "Update", function(self)
                for _, r in ipairs(ppool) do r:Hide() end
                for i, kind in ipairs(WoW.paneRows[name]) do
                    local r = ppool[i]
                    if not r or r._kind ~= kind then
                        r = blizz("Button", self.ScrollTarget)
                        r._kind = kind
                        if kind == "header" then
                            regionOn(r, "Texture", "BACKGROUND")
                            regionOn(r, "Texture", "HIGHLIGHT")
                            r.StateIcon = regionOn(r, "Texture", "BORDER")
                            r.Name = blizz("FontString", r, nil, "OVERLAY")
                            r.Name._textColor = { 1, 0.82, 0, 1 }
                        else
                            r.Content = blizz("Frame", r)
                            r.Content.Name = blizz("FontString", r.Content, nil, "OVERLAY")
                            if kind == "sub" then
                                local t = blizz("Button", r)
                                t._normal = blizz("Texture", t)
                                t._pushed = blizz("Texture", t)
                                r.ToggleCollapseButton = t
                            end
                        end
                        ppool[i] = r
                    end
                    -- Initialize: the text and the icon's atlas only.
                    if kind == "header" then r.StateIcon:SetAtlas("common-button-list-minus") end
                    if kind == "sub" then r.ToggleCollapseButton._normal:SetAtlas("campaign_headericon_open") end
                    r:Show()
                end
            end)
        end
        -- The currency pane: every touch from addon code recorded.
        local token = blizz("Frame", cf, "TokenFrame")
        token._shown = false
        token.ScrollBox = blizz("Frame", token)
        token.Row = blizz("Button", token.ScrollBox)
        token.Row.Background = blizz("Texture", token.Row, nil, "BACKGROUND")
        token.TransferToggle = blizz("Button", token)
        WoW.currencyTouches = {}
        for _, f in ipairs({ token, token.ScrollBox, token.Row, token.Row.Background, token.TransferToggle }) do
            for _, m in ipairs({ "SetAlpha", "HookScript", "SetVertexColor", "Hide", "SetPoint" }) do
                local real = f[m]
                rawset(f, m, function(self, ...)
                    if not WoW.inBlizzard then table.insert(WoW.currencyTouches, m) end
                    return real(self, ...)
                end)
            end
        end
        WoW.snapshot()
    end)
end

function WoW.showCharacter()
    WoW.asBlizzard(function()
        CharacterFrame:Show()
        CharacterFrame.ModeTabs.Tabs[1]:SetChecked(true)
        PaperDollSidebarTab1:SetChecked(true)
        CharacterStatsPaneScrollBox.ScrollBox:Update()
    end)
end
function WoW.hideCharacter() WoW.asBlizzard(function() CharacterFrame:Hide() end) end
-- A list pane shown (CharacterFrame.lua's ShowSubFrame), its list filled.
function WoW.characterPane(name)
    WoW.asBlizzard(function()
        for _, n in ipairs({ "ReputationFrame", "SkillsFrame", "StatisticsFrame" }) do _G[n]:SetShown(n == name) end
        if name then _G[name].ScrollBox:Update() end
    end)
end
-- A mode chosen (CharacterFrame.lua:217-242): each tab's SetChecked.
function WoW.characterMode(i)
    WoW.asBlizzard(function()
        for n, t in ipairs(CharacterFrame.ModeTabs.Tabs) do t:SetChecked(n == i) end
    end)
end
-- The world map and quest log (#99, docs/MAP.md; Blizzard_WorldMap with
-- Camelot's templates, Mainline QuestMapFrame, origin/forever 70450). The
-- shell: BorderFrame (NineSlice, Bg reparented to the window, InsetBorderTop,
-- the portrait, the close and maximise/minimise buttons); OverscrollBG; the
-- NavBar (its tile, insets, overlay, home, overflow, pooled crumbs from
-- WoW.crumbs at each Refresh); other overlay frames, the canvas, Leatrix's
-- strip and hover driver, Questie's button (all must stay untouched); the
-- quest log (QuestScrollFrame, its art, the search box, QuestLogCount, rows
-- from WoW.questRows at each update: header, title, objective, covenant, poi).
-- Maximize/Minimize as the mixin does: the NineSlice's SetAtlas, the portrait
-- texture only, the buttons swapped. Hidden.
WoW.crumbs = 2
WoW.questRows = { "header", "title", "objective", "header", "title", "covenant", "campaign", "poi" }
local function mapRegion(parent, layer)
    local r = blizz("Texture", parent, nil, layer)
    table.insert(parent._regions, r)
    return r
end

function WoW.makeWorldMap()
    WoW.asBlizzard(function()
        local wm = blizz("Frame", UIParent, "WorldMapFrame")
        wm._shown, wm._level, wm._width, wm._height = false, 1, 1035, 570
        local bf = blizz("Frame", wm)
        bf._level, bf._strata = 2, "HIGH"
        bf.NineSlice = nineSlice(bf)
        bf.Bg = blizz("Texture", wm, nil, "BACKGROUND")       -- reparented (Blizzard_WorldMap.lua:27)
        bf.InsetBorderTop = blizz("Texture", bf, nil, "BACKGROUND")
        bf.PortraitContainer = blizz("Frame", bf)
        bf.PortraitContainer._level = 400
        bf.PortraitContainer.portrait = blizz("Texture", bf.PortraitContainer, nil, "OVERLAY")
        bf.PortraitContainer.CircleMask = blizz("MaskTexture", bf.PortraitContainer)
        bf.PortraitContainer.CircleMask._width = 58
        bf.TitleContainer = blizz("Frame", bf)
        bf.TitleContainer.TitleText = blizz("FontString", bf.TitleContainer, nil, "OVERLAY")
        bf.CloseButton = blizzButton(bf, "RedButton-Exit", "RedButton-exit-pressed", "RedButton-Highlight",
                                     "RedButton-Exit-Disabled")
        bf.CloseButton._level, bf.CloseButton._width = 510, 28
        local mm = blizz("Frame", bf)
        mm.MaximizeButton = blizzButton(mm, "RedButton-Expand", "RedButton-Expand-Pressed", "RedButton-Highlight",
                                        "RedButton-Expand-Disabled")
        mm.MinimizeButton = blizzButton(mm, "RedButton-Condense", "RedButton-Condense-Pressed", "RedButton-Highlight",
                                        "RedButton-Condense-Disabled")
        mm.MaximizeButton._level, mm.MaximizeButton._width = 510, 28
        mm.MinimizeButton._level, mm.MinimizeButton._width = 510, 28
        mm.MinimizeButton._shown = false
        bf.MaximizeMinimizeFrame = mm
        wm.BorderFrame = bf
        local over = blizz("Frame", wm)
        mapRegion(over, "BACKGROUND")
        mapRegion(over, "BORDER")
        wm.OverscrollBG = over
        -- The canvas, with Leatrix's coordinates strip on it.
        local sc = blizz("Frame", wm)
        sc._level = 3
        sc.Child = blizz("Frame", sc)
        sc.Child.TiledBackground = blizz("Texture", sc.Child, nil, "BACKGROUND")
        wm.ScrollContainer = sc
        WoW.neighbours = {}
        local strip = blizz("Frame", sc)                    -- Leatrix's cFrame (Leatrix_Maps.lua:841-849)
        table.insert(WoW.neighbours, mapRegion(strip, "BACKGROUND"))
        local driver = blizz("Frame", wm)                   -- its hoverDriver (:1437)
        table.insert(WoW.neighbours, mapRegion(driver, "ARTWORK"))
        local krowi = blizz("Button", wm, "Krowi_WorldMapButtons1")   -- Questie's map button
        krowi.Background = mapRegion(krowi, "BACKGROUND")
        table.insert(WoW.neighbours, krowi.Background)
        table.insert(WoW.neighbours, sc.Child.TiledBackground)
        -- Other overlay frames: the filter button and the pin button.
        local filter = blizz("Button", wm)
        filter.Icon = mapRegion(filter, "ARTWORK")
        wm.WorldMapTrackingOptionsButton = filter
        table.insert(WoW.neighbours, filter.Icon)
        local pin = blizz("Button", wm)
        pin.Background = mapRegion(pin, "BACKGROUND")
        wm.WorldMapTrackingPinButton = pin
        table.insert(WoW.neighbours, pin.Background)
        -- The NavBar.
        local nav = blizz("Frame", wm)
        nav._level = 5
        mapRegion(nav, "BACKGROUND")                         -- the unnamed tile
        for _, k in ipairs({ "InsetBorderBottomLeft", "InsetBorderBottomRight", "InsetBorderBottom", "InsetBorderLeft",
                             "InsetBorderRight" }) do
            nav[k] = mapRegion(nav, "BORDER")
        end
        nav.overlay = blizz("Frame", nav)
        mapRegion(nav.overlay, "OVERLAY")
        local function crumb()
            local b = blizzButton(nav, "CS_HelpTextures_Tile", "CS_HelpTextures_Tile", "CS_HelpTextures")
            b.text = blizz("FontString", b, nil, "OVERLAY")
            b.arrowUp = blizz("Texture", b, nil, "OVERLAY")
            b.selected = blizz("Texture", b, nil, "OVERLAY")
            return b
        end
        nav.homeButton = crumb()
        nav.home = nav.homeButton
        nav.overflowButton = blizzButton(nav, "CS_HelpTextures", "CS_HelpTextures", "CS_HelpTextures")
        nav.overflow = nav.overflowButton
        nav.navList, nav.freeButtons = { nav.homeButton }, {}
        WoW.allCrumbs = {}
        -- WorldMapNavBarMixin:Refresh: the bar rebuilt (pooled crumbs reused, new ones made).
        luaMethod(nav, "Refresh", function(self)
            for i = #self.navList, 2, -1 do
                local b = table.remove(self.navList, i)
                b:Hide()
                table.insert(self.freeButtons, b)
            end
            for _ = 1, WoW.crumbs do
                local b = table.remove(self.freeButtons) or crumb()
                table.insert(WoW.allCrumbs, b)
                b:Show()
                table.insert(self.navList, b)
            end
        end)
        wm.NavBar = nav
        -- WorldMapMixin:Maximize/Minimize (Blizzard_WorldMap.lua:52-80).
        local function display(max)
            for _, k in ipairs({ "TopLeftCorner", "TopEdge", "BottomEdge" }) do
                if bf.NineSlice[k] then bf.NineSlice[k]:SetAtlas(max and "UI-Frame-Metal-NoPortrait" or "UI-Frame-PortraitMetal") end
            end
            bf.PortraitContainer.portrait:SetShown(not max)
            mm.MaximizeButton:SetShown(not max)
            mm.MinimizeButton:SetShown(max)
        end
        luaMethod(wm, "Maximize", function() display(true) end)
        luaMethod(wm, "Minimize", function() display(false) end)
        -- The quest log.
        local qmf = blizz("Frame", wm, "QuestMapFrame")
        qmf._level, qmf._strata = 2, "HIGH"
        qmf.QuestsFrame = blizz("Frame", qmf)
        qmf.QuestsFrame._level = 3
        local qsf = blizz("Frame", qmf.QuestsFrame, "QuestScrollFrame")
        qsf._level = 4
        qmf.QuestsFrame.ScrollFrame = qsf
        qsf.Background = blizz("Texture", qsf, nil, "BACKGROUND")
        qsf.Edge = blizz("Texture", qsf, nil, "ARTWORK")
        qsf.BorderFrame = blizz("Frame", qsf)
        qsf.BorderFrame.Border = blizz("Texture", qsf.BorderFrame, nil, "BORDER")
        qsf.BorderFrame.TopDetail = blizz("Texture", qsf.BorderFrame, nil, "OVERLAY")
        qsf.BorderFrame.Shadow = blizz("Texture", qsf.BorderFrame, nil, "OVERLAY")
        qsf.BorderFrame.Shadow._atlas = "questlog-frame-gradient-bottom"
        qsf.Contents = blizz("Frame", qsf)
        qsf.Contents.Separator = blizz("Frame", qsf.Contents)
        qsf.Contents.Separator.Divider = blizz("Texture", qsf.Contents.Separator, nil, "ARTWORK")
        qsf.Contents.StoryHeader = blizz("Frame", qsf.Contents)
        qsf.Contents.StoryHeader.Background = blizz("Texture", qsf.Contents.StoryHeader, nil, "BACKGROUND")
        qsf.Contents.StoryHeader.Text = blizz("FontString", qsf.Contents.StoryHeader, nil, "OVERLAY")
        local sb = blizz("EditBox", qsf)
        for _, k in ipairs({ "Left", "Right", "Middle" }) do sb[k] = blizz("Texture", sb, nil, "BACKGROUND") end
        sb.searchIcon = blizz("Texture", sb, nil, "OVERLAY")
        qsf.SearchBox = sb
        qsf.SettingsDropdown = blizz("Button", qsf)
        qsf.SettingsDropdown.Icon = blizz("Texture", qsf.SettingsDropdown, nil, "ARTWORK")
        qsf.ScrollBar = blizz("Frame", qsf)
        local count = blizz("Frame", qsf, "QuestLogCount")
        for _, k in ipairs({ "Left", "Right", "Middle" }) do count[k] = blizz("Texture", count, nil, "BACKGROUND") end
        blizz("FontString", count, "QuestLogQuestCount", "OVERLAY")
        luaMethod(qsf, "UpdateBackground", function(self) self.Background:SetAtlas("QuestLog-main-background") end)
        -- The pools (QuestMapFrame.lua:1228-1237), every row parented to Contents.
        local qpool = {}
        WoW.questPool = qpool
        local function row(kind)
            local r
            if kind == "header" or kind == "covenant" then
                r = blizzButton(qsf.Contents, "common-button-list-collapseExpand", nil, "common-button-list-collapseExpand")
                r.ButtonText = blizz("FontString", r, nil, "OVERLAY")
                r.ButtonText._textColor = { 0.5, 0.5, 0.5, 1 }
                r.CollapseButton = blizz("Button", r)
                r.CollapseButton.Icon = blizz("Texture", r.CollapseButton, nil, "ARTWORK")
                if kind == "covenant" then r.SelectedHighlight = blizz("Texture", r, nil, "HIGHLIGHT") end
            elseif kind == "campaign" then
                -- CampaignHeaderTemplate: its name is Text, not ButtonText (WarCampaignTemplates.xml:160-248).
                r = blizzButton(qsf.Contents, "CampaignHeader", nil, "CampaignHeader")
                r.Text = blizz("FontString", r, nil, "OVERLAY")
                r.CollapseButton = blizz("Button", r)
                r.CollapseButton.Icon = blizz("Texture", r.CollapseButton, nil, "ARTWORK")
            elseif kind == "title" then
                r = blizz("Button", qsf.Contents)
                r.Text = blizz("FontString", r, nil, "OVERLAY")
                r.Checkbox = blizz("Frame", r)
                r.Checkbox.CheckMark = mapRegion(r.Checkbox, "ARTWORK")
                r._highlight = blizz("Texture", r, nil, "BORDER")
            elseif kind == "objective" then
                r = blizz("Frame", qsf.Contents)
                r.Text = blizz("FontString", r, nil, "OVERLAY")
            else
                r = blizz("Button", qsf.Contents)                 -- a POI button
                r.Display = blizz("Frame", r)
                r._normal = blizz("Texture", r, nil, "ARTWORK")
            end
            r._kind = kind
            return r
        end
        -- QuestLogQuests_Update: rows released and acquired, then UpdateBackground (2159).
        function WoW.questLogUpdate()
            WoW.asBlizzard(function()
                for _, r in ipairs(qpool) do r:Hide() end
                for i, kind in ipairs(WoW.questRows) do
                    local r = qpool[i]
                    if not r or r._kind ~= kind then
                        r = row(kind)
                        qpool[i] = r
                    end
                    if rawget(r, "CollapseButton") then r.CollapseButton.Icon:SetAtlas("common-button-list-minus") end
                    r:Show()
                end
                qsf:UpdateBackground()
            end)
        end
        WoW.snapshot()
    end)
end

function WoW.showMap()
    WoW.asBlizzard(function() WorldMapFrame:Show() end)
    WoW.questLogUpdate()
end
function WoW.hideMap() WoW.asBlizzard(function() WorldMapFrame:Hide() end) end
function WoW.mapRefresh() WoW.asBlizzard(function() WorldMapFrame.NavBar:Refresh() end) end
function WoW.mapMaximize(max)
    WoW.asBlizzard(function()
        if max then WorldMapFrame:Maximize() else WorldMapFrame:Minimize() end
    end)
end
-- The quest list scrolled (UpdateBottomShadow, QuestMapFrame.lua:1391-1397).
function WoW.questScroll(a)
    WoW.asBlizzard(function() QuestScrollFrame.BorderFrame.Shadow:SetAlpha(a) end)
end
-- The loot window and the loot roll history (#105, docs/LOOT.md; Mainline
-- LootFrame.xml and LootHistory.xml, origin/forever 70450). Each a
-- DefaultPanelFlatTemplate shell (NineSlice, a Bg frame of four pieces, the
-- title, ClosePanelButton) and a ScrollBox whose Update acquires rows from
-- WoW.lootRows (item, money, base) or WoW.historyRows (drop, header, pad).
-- LootFrame:Open as Blizzard's: the list built, then shown. Hidden.
WoW.lootRows = { "item", "item", "money", "base" }
WoW.historyRows = { "drop", "header", "pad", "drop" }
local function lootRegion(parent, layer)
    local r = blizz("Texture", parent, nil, layer)
    table.insert(parent._regions, r)
    return r
end

local function flatShell(name)
    local f = blizz("Frame", UIParent, name)
    f._shown, f._level, f._strata = false, 1, "HIGH"
    f.NineSlice = nineSlice(f)
    local bg = blizz("Frame", f)
    bg._level = 0
    for _, k in ipairs({ "BottomLeft", "BottomRight", "BottomEdge", "TopSection" }) do
        bg[k] = lootRegion(bg, "BACKGROUND")
    end
    f.Bg = bg
    f.TitleContainer = blizz("Frame", f)
    f.TitleContainer._level = 510
    f.TitleContainer.TitleText = blizz("FontString", f.TitleContainer, nil, "OVERLAY")
    f.ClosePanelButton = blizzButton(f, "RedButton-Exit", "RedButton-exit-pressed", "RedButton-Highlight",
                                     "RedButton-Exit-Disabled")
    f.ClosePanelButton._level, f.ClosePanelButton._width = 510, 28
    local sb = blizz("Frame", f)
    sb._level = 2
    sb.ScrollTarget = blizz("Frame", sb)
    sb.ScrollTarget._level = 3
    sb.Shadows = blizz("Frame", sb)
    sb.Shadows.Upper = blizz("Texture", sb.Shadows, nil, "OVERLAY")
    sb.Shadows.Lower = blizz("Texture", sb.Shadows, nil, "OVERLAY")
    f.ScrollBox = sb
    f.ScrollBar = blizz("Frame", f)
    return f, sb
end

function WoW.makeLoot()
    WoW.asBlizzard(function()
        local lf, sb = flatShell("LootFrame")
        local pool = {}
        WoW.lootPool = pool
        local function lootRow(kind)
            local r = blizz("Frame", sb.ScrollTarget)
            r._level, r._kind = 3, kind
            r.ShowAnim = r:CreateAnimationGroup()
            if kind ~= "base" then
                local item = blizz("Button", r)
                item._level = 3                                    -- useParentLevel
                item.icon = blizz("Texture", item, nil, "BORDER")
                item.IconBorder = blizz("Texture", item, nil, "OVERLAY")
                item._normal = blizz("Texture", item, nil, "ARTWORK")
                r.Item = item
                r.NameFrame = blizz("Texture", r, nil, "BACKGROUND")
                r.BorderFrame = blizz("Texture", r, nil, "BORDER")
                r.IconQuestTexture = blizz("Texture", r, nil, "OVERLAY")
                r.HighlightNameFrame = blizz("Texture", r, nil, "OVERLAY")
                r.HighlightNameFrame._shown = false
                r.PushedNameFrame = blizz("Texture", r, nil, "OVERLAY")
                r.PushedNameFrame._shown = false
                r.Text = blizz("FontString", r, nil, "OVERLAY")
                if kind == "item" then
                    r.QualityStripe = blizz("Texture", r, nil, "BACKGROUND")
                    r.QualityText = blizz("FontString", r, nil, "OVERLAY")
                end
            end
            return r
        end
        luaMethod(sb, "Update", function(self)
            for _, r in ipairs(pool) do r:Hide() end
            for i, kind in ipairs(WoW.lootRows) do
                local r = pool[i]
                if not r or r._kind ~= kind then
                    r = lootRow(kind)
                    pool[i] = r
                end
                -- Init (LootFrame.lua:482-519): the plate and the slot re-coloured.
                if rawget(r, "NameFrame") then r.NameFrame:SetVertexColor(1, 1, 1) end
                if rawget(r, "Item") then r.Item._normal:SetVertexColor(1, 1, 1) end
                r:Show()
            end
        end)
        -- The window's ShowAnim and each row's (#109): what a fade did to the
        -- shell and the rows while they play is undone when they end, as
        -- measured on 70450 (WoW.lootAnimsDone).
        lf.ShowAnim = lf:CreateAnimationGroup()
        local function shellRegions()
            local list = { lf.NineSlice, lf.Bg }
            for _, k in ipairs(NINE) do list[#list + 1] = lf.NineSlice[k] end
            for _, k in ipairs({ "BottomLeft", "BottomRight", "BottomEdge", "TopSection" }) do list[#list + 1] = lf.Bg[k] end
            for _, r in ipairs(pool) do
                if r:IsShown() and rawget(r, "NameFrame") then list[#list + 1] = r.NameFrame end
            end
            return list
        end
        luaMethod(lf, "Open", function(self)
            self.ScrollBox:Update()
            self:Show()                                            -- ShowUIPanel
            WoW.lootSnapshot = {}
            for _, r in ipairs(shellRegions()) do WoW.lootSnapshot[r] = r._alpha end
            self.ShowAnim:Play()
            for _, r in ipairs(pool) do if r:IsShown() and rawget(r, "ShowAnim") then r.ShowAnim:Play() end end
        end)
        function WoW.lootAnimsDone()
            WoW.asBlizzard(function()
                lf.ShowAnim:Stop()
                for _, r in ipairs(pool) do if rawget(r, "ShowAnim") then r.ShowAnim:Stop() end end
                for r, a in pairs(WoW.lootSnapshot or {}) do rawset(r, "_alpha", a) end
                WoW.lootSnapshot = nil
            end)
        end
        -- The other overlay-like pieces to keep: the master looter frame.
        local ml = blizz("Frame", lf, "MasterLooterFrame")
        ml._shown = false
        local hf, hsb = flatShell("GroupLootHistoryFrame")
        hf.EncounterDropdown = blizz("Button", hf)
        hf.Timer = blizz("Frame", hf)
        for _, k in ipairs({ "Background", "Fill", "Border" }) do hf.Timer[k] = blizz("Texture", hf.Timer, nil, "ARTWORK") end
        hf.ResizeButton = blizz("Button", hf)
        hf.ResizeButton._level = 600
        lootRegion(hf.ResizeButton, "OVERLAY")
        hf.NoInfoString = blizz("FontString", hf, nil, "OVERLAY")
        local function element(parent)
            local r = blizz("Frame", parent)
            r._level = 500
            r.Item = blizz("Button", r)
            r.Item.icon = blizz("Texture", r.Item, nil, "BORDER")
            r.Item.IconBorder = blizz("Texture", r.Item, nil, "OVERLAY")
            local art = blizz("Frame", r)
            art._level = 400
            art.NameFrame = blizz("Texture", art, nil, "BACKGROUND")
            art.BorderFrame = blizz("Texture", art, nil, "BORDER")
            r.BackgroundArtFrame = art
            r.ItemName = blizz("FontString", r, nil, "OVERLAY")
            r.PlayerRoll = blizz("Frame", r)
            r.PlayerRoll.PlayerRollIcon = blizz("Texture", r.PlayerRoll, nil, "ARTWORK")
            return r
        end
        hf.PerfectAnimFrame = element(hf)                         -- an element outside the list
        hf.PerfectAnimFrame._shown = false
        local hpool = {}
        WoW.historyPool = hpool
        luaMethod(hsb, "Update", function(self)
            for _, r in ipairs(hpool) do r:Hide() end
            for i, kind in ipairs(WoW.historyRows) do
                local r = hpool[i]
                if not r or r._kind ~= kind then
                    if kind == "drop" then
                        r = element(self.ScrollTarget)
                    else
                        r = blizz("Frame", self.ScrollTarget)
                        if kind == "header" then lootRegion(r, "OVERLAY") end
                    end
                    r._kind = kind
                    hpool[i] = r
                end
                r:Show()
            end
        end)
        WoW.snapshot()
    end)
end

-- LOOT_OPENED: Blizzard's Open (the list, then the show).
function WoW.loot() WoW.asBlizzard(function() LootFrame:Open() end) end
function WoW.closeLoot() WoW.asBlizzard(function() LootFrame:Hide() end) end
-- /loot: ToggleLootHistoryFrame's SetShown, the list filled.
function WoW.lootHistory(show)
    WoW.asBlizzard(function()
        GroupLootHistoryFrame:SetShown(show)
        if show then GroupLootHistoryFrame.ScrollBox:Update() end
    end)
end
function WoW.hideMerchant() WoW.asBlizzard(function() MerchantFrame:Hide() end) end

-- TradeFrame (Blizzard_UIPanels_Game, Mainline/TradeFrame.xml; forever 70450,
-- docs/TRADE.md): ButtonFrameTemplate's shell, the names' HIGH frame, the
-- recipient's overlay (550), the highlights, the six insets, the 2 x 7 slots,
-- Trade and Cancel, the forbidden money input (every key but IsForbidden
-- throws), the recipient's money edge and display. TradeFrame:GetChildren
-- from addon code throws: it would hand back the forbidden frame. Hidden.
-- WoW.tradeOffer[side][i] = { icon =, usable = } fills a slot on an update.
WoW.tradeOffer = { Player = {}, Recipient = {} }
local function forbidden(name)
    local f = setmetatable({}, { __index = function(_, k)
        if k == "IsForbidden" then return function() return true end end
        error("forbidden: " .. name .. "." .. tostring(k), 2)
    end })
    rawset(_G, name, f)
    table.insert(WoW.blizzGlobals, name)
    return f
end

function WoW.makeTrade()
    WoW.tradeOffer = { Player = {}, Recipient = {} }
    WoW.asBlizzard(function()
        local f = blizz("Frame", UIParent, "TradeFrame")
        f._shown, f._level, f._strata = false, 5, "MEDIUM"
        f._width, f._height = 344, 446
        f.NineSlice = nineSlice(f)
        f.Bg = blizz("Texture", f, "TradeFrameBg", "BACKGROUND")
        f.TopTileStreaks = blizz("Texture", f, nil, "BORDER")
        f.Inset = inset(f, "TradeFrameInset")
        f.PortraitContainer = blizz("Frame", f)
        f.PortraitContainer._level = 400
        f.PortraitContainer.portrait = blizz("Texture", f.PortraitContainer, "TradeFramePortrait", "OVERLAY")
        f.PortraitContainer.portrait._width = 60
        f.PortraitContainer.CircleMask = blizz("MaskTexture", f.PortraitContainer)
        f.PortraitContainer.CircleMask._width = 58
        f.CloseButton = blizzButton(f, "RedButton-Exit", "RedButton-exit-pressed", "RedButton-Highlight",
                                    "RedButton-Exit-Disabled")
        f.CloseButton._level, f.CloseButton._width = 510, 24
        rawset(_G, "TradeFrameCloseButton", f.CloseButton)
        table.insert(WoW.blizzGlobals, "TradeFrameCloseButton")
        for _, n in ipairs({ "TradeRecipientBG", "TradeRecipientLeftBorder", "TradeRecipientBotLeftCorner" }) do
            blizz("Texture", f, n, n == "TradeRecipientBG" and "BACKGROUND" or "OVERLAY")
        end
        blizz("FontString", f, "TradeFramePlayerEnchantText", "ARTWORK")
        blizz("FontString", f, "TradeFrameRecipientEnchantText", "ARTWORK")
        local names = blizz("Frame", f)
        names._strata = "HIGH"
        blizz("FontString", names, "TradeFrameRecipientNameText", "ARTWORK")
        blizz("FontString", names, "TradeFramePlayerNameText", "ARTWORK")
        local ov = blizz("Frame", f)
        ov._level = 550
        ov.portrait = blizz("Texture", ov, nil, "ARTWORK")
        ov.portrait._width = 60
        ov.portraitFrame = blizz("Texture", ov, nil, "ARTWORK")
        f.RecipientOverlay = ov
        for _, n in ipairs({ "TradeHighlightPlayer", "TradeHighlightRecipient", "TradeHighlightPlayerEnchant",
                             "TradeHighlightRecipientEnchant" }) do
            local hl = blizz("Frame", f, n)
            hl._shown = false
        end
        for _, n in ipairs({ "TradePlayerItemsInset", "TradeRecipientItemsInset", "TradePlayerEnchantInset",
                             "TradeRecipientEnchantInset", "TradePlayerInputMoneyInset", "TradeRecipientMoneyInset" }) do
            local i = inset(f, n)
            i._level = f._level                                    -- useParentLevel
        end
        for _, side in ipairs({ "Player", "Recipient" }) do
            for i = 1, 7 do
                local name = "Trade" .. side .. "Item" .. i
                local item = blizz("Frame", f, name)
                item._level = f._level + 1
                item.SlotTexture = blizz("Texture", item, name .. "SlotTexture", "BACKGROUND")
                blizz("Texture", item, name .. "NameFrame", "BACKGROUND")
                blizz("FontString", item, name .. "Name", "BACKGROUND")
                if i == 7 then item._glyph = blizz("Texture", item, nil, "ARTWORK") end
                local b = blizz("Button", item, name .. "ItemButton")
                b._level = item._level + 2                         -- OnLoad: two up
                b._width = 37
                b.icon = blizz("Texture", b, name .. "ItemButtonIconTexture", "BORDER")
                b.IconBorder = blizz("Texture", b, nil, "OVERLAY")
                b.Count = blizz("FontString", b, nil, "ARTWORK")
                b._normal = blizz("Texture", b, nil, "ARTWORK")
                b.Alert = blizz("Frame", b)
            end
        end
        for _, n in ipairs({ "TradeFrameTradeButton", "TradeFrameCancelButton" }) do
            local b = blizz("Button", f, n)
            b._level = f._level + 1
            for _, k in ipairs({ "Left", "Middle", "Right" }) do b[k] = blizz("Texture", b, nil, "BACKGROUND") end
            b._highlight = blizz("Texture", b, nil, "HIGHLIGHT")
            b.Text = blizz("FontString", b, nil, "OVERLAY")
            if n == "TradeFrameTradeButton" then
                b.WarningIcon = blizz("Texture", b, nil, "ARTWORK")
                b.WarningIcon._shown = false
            end
        end
        local edge = blizz("Frame", f, "TradeRecipientMoneyBg")
        blizz("Frame", f, "TradeRecipientMoneyFrame")
        -- TradeFrame_OnLoad (TradeFrame.lua:16-21).
        TradeRecipientItemsInset.Bg:SetAlpha(0.1)
        TradeRecipientMoneyInset.Bg:SetAlpha(0)
        TradeRecipientEnchantInset.Bg:SetAlpha(0.1)
        edge:SetAlpha(0.6)
        forbidden("TradePlayerInputMoneyFrame")
        forbidden("TradePlayerInputMoneyFrameGold")
        forbidden("TradePlayerInputMoneyFrameGoldMiddle")
        rawset(f, "GetChildren", function(self)
            if not WoW.inBlizzard then error("TradeFrame:GetChildren from addon code: the forbidden money frame", 2) end
            return Methods.GetChildren(self)
        end)
        WoW.snapshot()
    end)
end

-- TradeFrame_UpdatePlayerItem / UpdateTargetItem (TradeFrame.lua:100-194):
-- the icon, and on the recipient's side the red or white on the icon, the
-- plate and the slot.
local function tradeSlot(side, i)
    local name = "Trade" .. side .. "Item" .. i
    local o = WoW.tradeOffer[side][i]
    local b = _G[name .. "ItemButton"]
    b.icon:SetTexture(o and o.icon or nil)
    if side == "Recipient" then
        local red = o and not o.usable
        b.icon:SetVertexColor(red and 0.9 or 1, red and 0 or 1, red and 0 or 1)
        _G[name .. "NameFrame"]:SetVertexColor(red and 0.9 or 1, red and 0 or 1, red and 0 or 1)
        _G[name].SlotTexture:SetVertexColor(1, red and 0 or 1, red and 0 or 1)
    end
end
function WoW.tradeSlot(side, i) WoW.asBlizzard(tradeSlot, side, i) end

-- TRADE_SHOW / TRADE_UPDATE: ShowUIPanel, then TradeFrame_Update; Trade and
-- Cancel re-set their art on show (UIPanelButton's SetTexture).
function WoW.trade()
    WoW.asBlizzard(function()
        TradeFrame:Show()
        TradeFrame.PortraitContainer.portrait:SetTexture(1)
        TradeFrame.RecipientOverlay.portrait:SetTexture(2)
        for _, side in ipairs({ "Player", "Recipient" }) do
            for i = 1, 7 do tradeSlot(side, i) end
        end
        for _, n in ipairs({ "TradeFrameTradeButton", "TradeFrameCancelButton" }) do
            for _, k in ipairs({ "Left", "Middle", "Right" }) do _G[n][k]:SetTexture("Interface\\Buttons\\UI-Panel-Button-Up") end
        end
    end)
end
function WoW.closeTrade() WoW.asBlizzard(function() TradeFrame:Hide() end) end

-- RestedXP v4.11.36 (#56, docs/RESTEDXP.md): RXPFrame (GuideWindow.lua) and
-- RXPG_ARROW (map.lua), its default window ("V1"). A third-party addon's
-- objects, under the same contract record as Blizzard's: its function fields
-- and the Backdrop mixin's methods are Lua methods (a call from addon code is
-- recorded). WoW.makeRestedXP() before the login: installed and loaded.
--
-- A backdrop (Backdrop.lua, NineSlice.lua): SetBackdrop makes its pieces
-- once, fields of the frame, and reuses them, setting only their textures;
-- ClearBackdrop sets each texture to nil; SetBackdropColor the vertex colour.
-- A theme change brings each piece's alpha back (QS.2, 954 on 70450): past
-- the SetAlpha hook, as measured (WoW.rxpTheme).
WoW.rxpSteps = { "done", "current", "building", "building", "hidden" }
WoW.rxpCards = { { title = "Step 13" } }
local RXP_ROW_ALPHA = { done = 0.5, current = 1, building = 0.66, hidden = 0 }
-- RestedXP's side writes fields as it goes (the pieces, the pooled rows and
-- cards): each of its steps first keeps what addon code changed since the
-- last one (WoW.fieldWrites), then takes a new snapshot of its objects.
local function rxpBlizz(...)
    local w = blizz(...)
    rawset(w, "_rxp", true)
    table.insert(WoW.rxpObjs, w)
    return w
end
local function rxpSide(fn)
    for _, w in ipairs(WoW.rxpObjs) do
        local snap, hooked = WoW.snap[w] or {}, WoW.hookedKeys[w] or {}
        for k, v in pairs(w) do
            if (type(k) ~= "string" or k:sub(1, 1) ~= "_") and not hooked[k] and snap[k] ~= v then
                table.insert(WoW.fieldWrites, tostring(k))
            end
        end
    end
    WoW.asBlizzard(fn)
    for _, w in ipairs(WoW.rxpObjs) do WoW.snap[w] = nil end
    WoW.snapshot()
end
local function rxpBackdrop(f, pieces)
    luaMethod(f, "SetBackdrop", function(self)
        for _, k in ipairs(pieces) do
            if not rawget(self, k) then self[k] = rxpBlizz("Texture", self, nil, "BACKGROUND") end
            self[k]:SetTexture("Interface/AddOns/RXPGuides/Textures/rxp-borders")
        end
    end)
    luaMethod(f, "ClearBackdrop", function(self)
        for _, k in ipairs(pieces) do if rawget(self, k) then self[k]:SetTexture(nil) end end
    end)
    luaMethod(f, "SetBackdropColor", function(self, r, g, b, a)
        for _, k in ipairs(pieces) do if rawget(self, k) then self[k]:SetVertexColor(r, g, b, a) end end
    end)
end
local function rxpApply(f, r, g, b)
    f:ClearBackdrop()
    f:SetBackdrop()
    f:SetBackdropColor(r or 0.1, g or 0.1, b or 0.1, 1)
end

function WoW.makeRestedXP()
    WoW.installed.RXPGuides, WoW.loaded.RXPGuides = 2, true
    WoW.rxpObjs, WoW.rxpCalls = {}, {}
    rxpSide(function()
        local rxp = rxpBlizz("Frame", UIParent, "RXPFrame")
        rxp._level, rxp._strata = 1, "BACKGROUND"
        local list = rxpBlizz("Frame", rxp)
        list._level = 2
        local name = rxpBlizz("Frame", rxp)
        name._level = 6
        local footer = rxpBlizz("Frame", rxp)
        footer._level = 6
        for _, f in ipairs({ list, name, footer }) do rxpBackdrop(f, NINE) end
        name.bg = rxpBlizz("Texture", name, nil, "BACKGROUND")
        name.text = rxpBlizz("FontString", name, nil, "OVERLAY")
        name.icon = rxpBlizz("Texture", name, nil, "ARTWORK")
        name.classIcon = rxpBlizz("Texture", name, nil, "OVERLAY")
        footer.bg = rxpBlizz("Texture", footer, nil, "BACKGROUND")
        footer.text = rxpBlizz("FontString", name, nil, "OVERLAY")
        footer.icon = rxpBlizz("Button", footer)
        footer.cog = rxpBlizz("Button", rxp, "RXPFrameCogwheel")
        local scroll = rxpBlizz("ScrollFrame", list)
        scroll.ScrollBar = rxpBlizz("Slider", scroll)
        scroll.ScrollBar.ScrollUpButton = rxpBlizz("Button", scroll.ScrollBar)
        scroll.ScrollBar.ScrollDownButton = rxpBlizz("Button", scroll.ScrollBar)
        local child = rxpBlizz("Frame", list)
        child.framePool = {}
        local steps = rxpBlizz("Frame", rxp)
        steps.framePool = {}
        rxp.BottomFrame, rxp.GuideName, rxp.Footer = list, name, footer
        rxp.CurrentStepFrame, rxp.ScrollFrame, rxp.ScrollChild = steps, scroll, child
        luaMethod(rxp, "UpdateVisuals", function(self)
            for _, f in ipairs({ list, name, footer }) do rxpApply(f) end
            name.bg:SetTexture("Interface/AddOns/RXPGuides/Textures/rxp-banner")
            footer.bg:SetTexture("Interface/AddOns/RXPGuides/Textures/rxp-banner")
        end)
        -- Each row's alpha is RestedXP's state; its backdrop a fill alone
        -- (backdrop.bottom: no edge file).
        luaMethod(list, "UpdateFrame", function()
            for i, state in ipairs(WoW.rxpSteps) do
                child.framePool[i]:SetAlpha(RXP_ROW_ALPHA[state])
            end
        end)
        luaMethod(steps, "UpdateText", function() end)
        -- The arrow: hidden until RestedXP shows it.
        local af = rxpBlizz("Frame", UIParent, "RXPG_ARROW")
        af._shown, af._level, af._width, af._height = false, 1, 32, 32
        af.texture = rxpBlizz("Texture", af, nil, "ARTWORK")
        af.text = rxpBlizz("FontString", af, nil, "OVERLAY")
        luaMethod(af, "UpdateVisuals", function(self)
            self.texture:SetTexture("Interface/AddOns/RXPGuides/Textures/rxp_navigation_arrow-1")
        end)
    end)
end

-- RenderFrame: a theme applied, each piece's alpha back (QS.2).
function WoW.rxpTheme(r, g, b)
    rxpSide(function()
        RXPFrame:UpdateVisuals(true)
        for _, f in ipairs({ RXPFrame.BottomFrame, RXPFrame.GuideName, RXPFrame.Footer }) do
            for _, k in ipairs(NINE) do if rawget(f, k) then rawset(f[k], "_alpha", 1) end end
        end
        if r then for _, f in ipairs({ RXPFrame.GuideName }) do f:SetBackdropColor(r, g, b, 1) end end
    end)
end

-- LoadGuide: the list's rows (pooled), then its UpdateFrame.
function WoW.rxpLoadGuide()
    rxpSide(function()
        local child = RXPFrame.ScrollChild
        for i in ipairs(WoW.rxpSteps) do
            local row = child.framePool[i]
            if not row then
                row = rxpBlizz("Frame", child)
                rxpBackdrop(row, { "Center" })
                row.text = rxpBlizz("FontString", row, nil, "OVERLAY")
                row.number = rxpBlizz("FontString", row, nil, "OVERLAY")
                child.framePool[i] = row
            end
            row:Show()
            row:SetAlpha(0.66)
            rxpApply(row)
        end
        for i = #WoW.rxpSteps + 1, #child.framePool do child.framePool[i]:Hide() end
        child.f1 = child.f1 or rxpBlizz("Frame", child)
        child.f1._shown = false
        RXPFrame.BottomFrame.UpdateFrame()
    end)
end

-- A row hovered and left (its OnEnter/OnLeave): alpha 1 and the highlight
-- colour, then both back.
function WoW.rxpHover(row)
    WoW.asBlizzard(function()
        local was = row:GetAlpha()
        row:SetAlpha(1)
        row:SetBackdropColor(0.3, 0.3, 0.3, 1)
        row:SetBackdropColor(0.1, 0.1, 0.1, 1)
        row:SetAlpha(was)
    end)
end

-- SetStep: the current step's cards (pooled), a tip anchored to UIParent at
-- MEDIUM (still a child), the number tab's alpha 0 when untitled; a card's
-- backdrop set when the theme changed; then UpdateText.
function WoW.rxpSetStep(cards)
    WoW.rxpCards = cards or WoW.rxpCards
    rxpSide(function()
        local steps = RXPFrame.CurrentStepFrame
        for _, card in ipairs(steps.framePool) do card:Hide() end
        for i, spec in ipairs(WoW.rxpCards) do
            local card = steps.framePool[i]
            if not card then
                card = rxpBlizz("Frame", steps)
                rxpBackdrop(card, NINE)
                card.elements = {}
                card.number = rxpBlizz("Frame", card)
                rxpBackdrop(card.number, NINE)
                card.number.text = rxpBlizz("FontString", card.number, nil, "OVERLAY")
                steps.framePool[i] = card
                rxpApply(card)
                rxpApply(card.number)
            end
            card:Show()
            card:SetFrameStrata(spec.tip and "MEDIUM" or "BACKGROUND")
            card:ClearAllPoints()
            card:SetPoint("BOTTOMLEFT", spec.tip and UIParent or steps, 0, 0)
            card.number:SetAlpha(spec.title == "" and 0 or 1)
            card.number.text:SetText(spec.title)
        end
        steps.UpdateText()
    end)
end

-- V1's collapse (or a hidewindow guide): BottomFrame hidden, the header and
-- footer kept. V2 on: the four hidden.
function WoW.rxpCollapse(on) WoW.asBlizzard(function() RXPFrame.BottomFrame:SetShown(not on) end) end
function WoW.rxpV2(on)
    WoW.asBlizzard(function()
        for _, k in ipairs({ "GuideName", "BottomFrame", "Footer", "CurrentStepFrame" }) do RXPFrame[k]:SetShown(not on) end
    end)
end
function WoW.rxpShow() WoW.asBlizzard(function() RXPFrame:Show() end) end

-- DrawArrow: the turn (SetRotation past the pi/64 throttle) and the text
-- when the distance changes; the arrow text size setting: SetFont alone.
function WoW.rxpArrowShow() WoW.asBlizzard(function() RXPG_ARROW:UpdateVisuals(); RXPG_ARROW:Show() end) end
function WoW.rxpTurn(rad) WoW.asBlizzard(function() RXPG_ARROW.texture:SetRotation(rad) end) end
function WoW.rxpArrowText(s) WoW.asBlizzard(function() RXPG_ARROW.text:SetText(s) end) end
function WoW.rxpArrowFont(size) WoW.asBlizzard(function() RXPG_ARROW.text:SetFont("Fonts\\FRIZQT__.TTF", size, "OUTLINE") end) end
function WoW.rxpArrowAlpha(a) WoW.asBlizzard(function() RXPG_ARROW:SetAlpha(a) end) end

-- Blizzard's mirror timers (Blizzard_MirrorTimer, Mainline/MirrorTimer.xml and
-- .lua, origin/forever 70938): MirrorTimerContainer, an Edit Mode system
-- under UIParent, and its three frames in mirrorTimers (MirrorTimerTemplate,
-- toplevel, hidden): the StatusBar (its OnLoad lowers its own level by one),
-- TextBorder and an unnamed background (BACKGROUND), Text and Border
-- (OVERLAY), in that order for GetRegions. The fill is a texture of the bar's
-- own, re-set by Setup on every start.
WoW.MIRROR_ATLAS = { EXHAUSTION = "ui-castingbar-filling-standard", BREATH = "ui-castingbar-filling-applyingcrafting",
                     DEATH = "ui-castingbar-filling-standard", FEIGNDEATH = "ui-castingbar-filling-channel" }
-- How the stub's Setup treats the fill: "keep" (the colour survives
-- SetStatusBarTexture), "reset" (white and saturated again, the worst case
-- for the colour), "swap" (a new texture object).
WoW.mirrorFill = "reset"
function WoW.makeMirrorTimers()
    WoW.asBlizzard(function()
        local c = blizz("Frame", UIParent, "MirrorTimerContainer")
        c._shown, c._level, c._strata = false, 2, "MEDIUM"
        c.mirrorTimers = {}
        c.activeTimers = {}
        for i = 1, 3 do
            local f = blizz("Frame", c)
            f._shown, f._level, f._width, f._height = false, 3, 206, 32
            f.layoutIndex = i
            local bar = blizz("StatusBar", f)
            bar._level = f._level              -- LowerFrameLevel(self) at its OnLoad
            bar._width, bar._height = 195, 13
            bar._fill = blizz("Texture", bar, nil, "ARTWORK")
            bar._fill._atlas = WoW.MIRROR_ATLAS.EXHAUSTION
            f.StatusBar = bar
            local function region(wtype, layer)
                local r = blizz(wtype, f, nil, layer)
                WoW.addRegion(f, r)
                return r
            end
            f.TextBorder = region("Texture", "BACKGROUND")
            region("Texture", "BACKGROUND")    -- ui-castingbar-background, unnamed
            f.Text = region("FontString", "OVERLAY")
            f.Text._textColor = { 1, 1, 1, 1 }
            f.Border = region("Texture", "OVERLAY")
            c.mirrorTimers[i] = f
        end
        -- The container's SetupTimer, as an instance method: what the skin hooks.
        rawset(c, "SetupTimer", function(self, timer, value, maxvalue, paused, label)
            local f = self.activeTimers[timer]
            if not f then
                for _, t in ipairs(self.mirrorTimers) do
                    if not t.timer then f = t break end
                end
            end
            if not f then return end
            -- MirrorTimerMixin:Setup: the atlas first, the label, then shown.
            WoW.bset(f, "timer", timer)
            local bar = f.StatusBar
            -- The reset is the client's SetStatusBarTexture's own (done
            -- before the stub's call, so a hook on it sees it, as in game).
            if WoW.mirrorFill == "swap" then bar._fill = blizz("Texture", bar, nil, "ARTWORK") end
            if WoW.mirrorFill ~= "keep" then
                bar._fill._vertex, bar._fill._desat = { 1, 1, 1, 1 }, false
            end
            bar:SetStatusBarTexture(WoW.MIRROR_ATLAS[timer])
            f.Text:SetText(label)
            -- UpdateShownState's SetShown(true): the client fires no OnShow
            -- on a frame already shown (the core's Show would).
            if not f:IsShown() then f:Show() end
            self.activeTimers[timer] = f
        end)
        WoW.snapshot()
    end)
    return MirrorTimerContainer
end

-- MIRROR_TIMER_START: SetupTimer, then the container shown (OnEvent).
function WoW.mirrorStart(timer, label)
    local c = MirrorTimerContainer
    WoW.asBlizzard(function()
        c:SetupTimer(timer, 60000, 60000, 0, label or timer)
        c:Show()
        WoW.snapshot()
    end)
end

-- MIRROR_TIMER_STOP: Clear (the timer field dropped, the frame hidden).
function WoW.mirrorStop(timer)
    local c = MirrorTimerContainer
    WoW.asBlizzard(function()
        local f = c.activeTimers[timer]
        if not f then return end
        WoW.bset(f, "timer", nil)
        -- UpdateShownState: Edit Mode keeps it shown, an idle preview with
        -- its fill as the timer left it.
        if not c._editMode then f:Hide() end
        c.activeTimers[timer] = nil
        local any = false
        for _, t in ipairs(c.mirrorTimers) do any = any or t:IsShown() end
        c:SetShown(any)
    end)
end

-- Edit Mode's Timer Bars (SetIsInEditMode): all three shown, the running
-- timers kept (names, fills, values: nothing reset); off, only the running
-- ones.
function WoW.mirrorEditMode(on)
    local c = MirrorTimerContainer
    WoW.asBlizzard(function()
        c._editMode = on
        c:SetShown(on or next(c.activeTimers) ~= nil)
        for _, t in ipairs(c.mirrorTimers) do
            local want = on or t.timer ~= nil
            if want ~= t:IsShown() then t:SetShown(want) end
        end
    end)
end

WoW.reset()

-- Strict globals (the core's), as the last line: everything above is built.
-- LibStub: the embedded library's own loader reads _G.LibStub before creating it.
Kit.strict({ GlassUI = true, GlassUIDB = true, SkinProbeDB = true,
             SLASH_GLASSUI1 = true, SLASH_GLASSUI2 = true, LibStub = true })
