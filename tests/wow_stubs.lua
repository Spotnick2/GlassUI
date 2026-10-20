-- wow_stubs.lua: a minimal WoW: Forever mock for Lua 5.1 unit tests.
-- dofile("tests/wow_stubs.lua") FIRST in every test; drive it via the WoW table.
-- Glass MiniMap's stubs (themselves Glass MiniMap Bar's, GlassUnitFrames' and
-- GlassPanel's), trimmed to the widgets and the globals this addon reads.
--
-- What it models, on purpose:
-- - STRICT globals: reading any global it does not define is an error. The
--   stub is the allowlist of APIs verified present in the API dump.
-- - EVENT names: RegisterEvent throws on a name the API dump does not declare.
-- - METHOD calls: every widget method called is recorded (WoW.methodsCalled)
--   so test_methods.lua can check each against the dump's widget methods.
-- - The widget METATABLE is a real method table, like the client's.
-- - BLIZZARD objects (WoW.makeMerchant): every method addon code calls on
--   one is recorded (WoW.blizzCalls), with SetTexture/SetAtlas's argument
--   (WoW.textureArgs) and what addon code read from that texture with
--   GetTexture/GetAtlas (WoW.readBack); a Lua method is recorded apart (WoW.luaCalls); a field
--   written is trapped (WoW.fieldChanges). Glass Quest Tracker's contract
--   machinery. WoW.asBlizzard runs code as Blizzard's own.

WoW = {}
WoW.DUMP = os.getenv("GLASSQT_API_DUMP") or "C:/Projects/WoW/References/Forever/api/forever-api-1.60.1.70450.md"

--------------------------------------------------------------------------------
-- Known events (from the dump when present)
--------------------------------------------------------------------------------

WoW.KNOWN_EVENTS = {}
do
    local f = io.open(WoW.DUMP, "r")
    if f then
        local inEvents = false
        for line in f:lines() do
            if line:match("^## Documented events") then inEvents = true
            elseif line:match("^## ") then inEvents = false
            elseif inEvents then
                local name = line:match("^([A-Z][A-Z0-9_]+)%s+%(")
                if name then WoW.KNOWN_EVENTS[name] = true end
            end
        end
        f:close()
    end
    if next(WoW.KNOWN_EVENTS) == nil then
        -- CI has no dump: the events this addon registers, checked locally against it.
        for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD",
                             "EDIT_MODE_LAYOUTS_UPDATED",
                             "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "CVAR_UPDATE",
                             "PLAYER_LOGOUT", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }) do
            WoW.KNOWN_EVENTS[e] = true
        end
    end
end

--------------------------------------------------------------------------------
-- Widgets
--------------------------------------------------------------------------------

local Methods = {}   -- implementations, by method name
WoW.Methods = Methods

local function record(w, name)
    WoW.methodsCalled[(rawget(w, "_type") or "?") .. ":" .. name] = true
    -- A call on a Blizzard object from addon code (not from the simulated
    -- Blizzard side): test_contract checks each against the C-only allowlist.
    if rawget(w, "_blizz") and not WoW.inBlizzard then WoW.blizzCalls[name] = (WoW.blizzCalls[name] or 0) + 1 end
end

-- The shared method table: any Capitalised name is a method (a no-op unless
-- implemented below); anything else reads as nil, like a missing field.
local MethodTable = setmetatable({}, {
    __index = function(_, k)
        if type(k) ~= "string" or not k:match("^%u") then return nil end
        return function(self, ...)
            record(self, k)
            local impl = Methods[k]
            if impl then return impl(self, ...) end
            return nil
        end
    end,
})
local widgetMT = { __index = MethodTable }

local function newWidget(wtype, parent, name)
    local w = setmetatable({ _type = wtype, _parent = parent, _shown = true, _points = {},
                             _scripts = {}, _events = {}, _children = {}, _regions = {},
                             _level = parent and parent._level and (parent._level + 1) or 1,
                             _width = 0, _height = 0, _name = name, _scale = 1, _alpha = 1,
                             _mouse = false }, widgetMT)
    return w
end
WoW.newWidget = newWidget

local function adopt(parent, w)
    if parent and parent._children then table.insert(parent._children, w) end
end

local SCRIPTED = { Frame = true, Button = true, CheckButton = true, StatusBar = true, GameTooltip = true,
                   EditBox = true }

function CreateFrame(ftype, name, parent, template)
    local w = newWidget(ftype, parent, name)
    w._template = template
    adopt(parent, w)
    table.insert(WoW.frames, w)
    if name then rawset(_G, name, w) end
    if template == "UICheckButtonTemplate" or template == "UIPanelButtonTemplate" then
        w.Text = newWidget("FontString", w)
    end
    if template == "UIRadioButtonTemplate" then w.text = newWidget("FontString", w) end
    -- UIPanelScrollFrameTemplate's bar, as its ScrollBar key.
    if template == "UIPanelScrollFrameTemplate" then w.ScrollBar = newWidget("Slider", w) end
    return w
end

function Methods.Show(w) if not w._shown then w._shown = true; if w._scripts.OnShow then w._scripts.OnShow(w) end end end
function Methods.Hide(w) if w._shown then w._shown = false; if w._scripts.OnHide then w._scripts.OnHide(w) end end end
function Methods.SetShown(w, v) if v then Methods.Show(w) else Methods.Hide(w) end end
function Methods.IsShown(w) return w._shown end
function Methods.IsVisible(w)
    local p = w
    while p do if not p._shown then return false end; p = p._parent end
    return true
end
function Methods.SetPoint(w, ...) table.insert(w._points, { ... }) end
function Methods.ClearAllPoints(w) w._points = {} end
function Methods.GetPoint(w, i)
    local p = w._points[i or 1]
    if p then return p[1], p[2], p[3], p[4], p[5] end
end
function Methods.GetNumPoints(w) return #w._points end
function Methods.SetAllPoints(w, rel) table.insert(w._points, { "ALL", rel }) end
function Methods.SetSize(w, x, y) w._width, w._height = x, y end
function Methods.SetWidth(w, x) w._width = x end
function Methods.SetHeight(w, y) w._height = y end
function Methods.GetWidth(w) return w._width end
function Methods.GetHeight(w) return w._height end
function Methods.GetSize(w) return w._width, w._height end
function Methods.GetCenter(w) return w._cx, w._cy end
-- Rects: what a test sets (nil until laid out, as before the first frame).
function Methods.GetTop(w) return w._top end
function Methods.GetBottom(w) return w._bottom end
-- ScrollFrame: the range a test sets (w._yrange).
function Methods.GetVerticalScrollRange(w) return w._yrange or 0 end
function Methods.GetEffectiveScale(w) return w._effScale or 1 end
function Methods.SetScale(w, s) w._scale = s end
function Methods.GetScale(w) return w._scale end
-- A texture painted with SetGradient ignores a later SetAlpha, and GetAlpha
-- keeps reading 1 (porting guide section 3, measured on 70374 twice; an image
-- texture too, SkinProbe W1.6 square C). Tests passed against that bug until
-- Glass Quest Tracker's stub behaved like this.
function Methods.SetAlpha(w, a)
    if w._gradient then return end
    w._alpha = a
end
function Methods.GetAlpha(w) return w._alpha end
function Methods.GetFrameLevel(w) return w._level end
function Methods.SetFrameLevel(w, l) w._level = l end
function Methods.SetFrameStrata(w, s) w._strata = s end
function Methods.GetFrameStrata(w) return w._strata or "MEDIUM" end
function Methods.GetName(w) return w._name end
function Methods.GetParentKey(w) return w._parentKey end
function Methods.GetParent(w) return w._parent end
function Methods.SetAttribute(w, k, v) w._attrs = w._attrs or {}; w._attrs[k] = v end
function Methods.GetAttribute(w, k) return w._attrs and w._attrs[k] end
function Methods.SetParent(w, p)
    if w._parent and w._parent._children then
        for i, c in ipairs(w._parent._children) do
            if c == w then table.remove(w._parent._children, i); break end
        end
    end
    w._parent = p
    adopt(p, w)
end
function Methods.GetChildren(w) return unpack(w._children) end
function Methods.GetRegions(w) return unpack(w._regions) end
function Methods.IsObjectType(w, t)
    if w._type == t then return true end
    return t == "Frame" and (w._type == "Button" or w._type == "CheckButton")
end
function Methods.GetObjectType(w) return w._type end
function Methods.GetDrawLayer(w) return w._layer, w._sub or 0 end
function Methods.IsForbidden(w) return false end
function Methods.IsProtected(w) return w._protected == true end
function Methods.EnableMouse(w, v) w._mouse = v and true or false end
function Methods.IsMouseEnabled(w) return w._mouse == true end
function Methods.RegisterForClicks(w, ...) w._clicks = { ... } end
function Methods.RegisterForDrag(w, ...) w._drag = { ... } end
function Methods.IsMouseOver(w) return WoW.mouseOver[w] == true end
function Methods.GetChecked(w) return w._checked == true end
function Methods.SetEnabled(w, v) w._enabled = v and true or false end
function Methods.Enable(w) w._enabled = true end
function Methods.Disable(w) w._enabled = false end
function Methods.IsEnabled(w) return w._enabled ~= false end
function Methods.SetChecked(w, v) w._checked = v and true or false end
function Methods.SetText(w, t) w._text = t end
function Methods.GetText(w) return w._text end
-- RGBA, read back; a call from addon code on a Blizzard string is recorded
-- with its receiver (WoW.textColorCalls) for test_contract's audited list.
function Methods.SetTextColor(w, r, g, b, a)
    if rawget(w, "_blizz") and not WoW.inBlizzard then table.insert(WoW.textColorCalls, w) end
    w._textColor = { r, g, b, a or 1 }
end
function Methods.GetTextColor(w)
    local c = w._textColor or { 1, 1, 1, 1 }
    return c[1], c[2], c[3], c[4]
end
function Methods.GetAnimationGroups(w) return unpack(w._anims or {}) end
function Methods.UnregisterAllEvents(w) w._events = {} end
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

-- Animations: Play marks a group playing; WoW.finishAnimations() completes
-- every playing group (OnFinished), as the client would after its duration.
function Methods.CreateAnimationGroup(w)
    local ag = newWidget("AnimationGroup", w)
    ag._animations = {}
    w._anims = w._anims or {}
    table.insert(w._anims, ag)
    table.insert(WoW.animGroups, ag)
    return ag
end
function Methods.CreateAnimation(ag, atype)
    local a = newWidget(atype or "Animation", ag)
    table.insert(ag._animations, a)
    return a
end
function Methods.GetAnimations(ag) return unpack(ag._animations) end
function Methods.GetTarget(a) return a._parent and a._parent._parent end
function Methods.Play(ag) ag._playing = true; ag._plays = (ag._plays or 0) + 1 end
function Methods.Stop(ag) ag._playing = false end
function Methods.IsPlaying(ag) return ag._playing == true end
function Methods.SetOrigin(a, point) a._origin = point end
function Methods.SetScaleFrom(a, x, y) a._from = { x, y } end
function Methods.SetScaleTo(a, x, y) a._to = { x, y } end
function WoW.finishAnimations()
    for _, ag in ipairs(WoW.animGroups) do
        if ag._playing then
            ag._playing = false
            if ag._scripts.OnFinished then ag._scripts.OnFinished(ag) end
        end
    end
end

-- Scripts. HasScript: every scripted widget type knows these handlers.
local HANDLERS = { OnClick = true, OnMouseUp = true, OnMouseDown = true, OnEnter = true, OnLeave = true,
                   OnShow = true, OnHide = true, OnUpdate = true, OnEvent = true, OnDragStart = true, OnDragStop = true,
                   OnDoubleClick = true, OnMouseWheel = true }
function Methods.HasScript(w, name) return SCRIPTED[w._type] == true and HANDLERS[name] == true end
function Methods.SetScript(w, name, fn) w._scripts[name] = fn end
function Methods.GetScript(w, name) return w._scripts[name] end
function Methods.HookScript(w, name, fn)
    local old = w._scripts[name]
    w._scripts[name] = function(...)
        if old then old(...) end
        -- The hook is addon code, even when Blizzard's side fired the script.
        local was = WoW.inBlizzard
        WoW.inBlizzard = false
        fn(...)
        WoW.inBlizzard = was
    end
end
function Methods.Click(w, mouse)
    if w._scripts.OnClick then w._scripts.OnClick(w, mouse or "LeftButton", false) end
end
function Methods.RegisterEvent(w, e)
    if not WoW.KNOWN_EVENTS[e] then error("Attempt to register unknown event \"" .. e .. "\"", 2) end
    w._events[e] = true
    return true
end
function Methods.UnregisterEvent(w, e) w._events[e] = nil end

-- Regions.
local function region(w, wtype, layer)
    local r = newWidget(wtype, w)
    r._layer = layer
    if wtype ~= "MaskTexture" then table.insert(w._regions, r) end
    return r
end
function Methods.CreateTexture(w, _, layer, _, sub)
    local r = region(w, "Texture", layer)
    r._sub = sub
    return r
end
function Methods.CreateMaskTexture(w) return region(w, "MaskTexture") end
function Methods.CreateFontString(w, _, layer, template)
    local r = region(w, "FontString", layer)
    r._font = template
    return r
end
-- On a Blizzard object, addon code's argument is kept: the contract allows
-- only nil, or giving back the value read before.
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
function Methods.SetTexture(t, file) textureArg(t, "SetTexture", file); t._file = file; t._atlas = nil; return true end
function Methods.GetTexture(t) return readBy(t, "GetTexture", t._file) end
function Methods.SetAtlas(t, atlas) textureArg(t, "SetAtlas", atlas); t._atlas = atlas; t._file = nil; return true end
function Methods.GetAtlas(t) return readBy(t, "GetAtlas", t._atlas) end
function Methods.SetTexCoord(t, ...) t._coords = { ... } end
function Methods.GetTexCoord(t)
    local c = t._coords or { 0, 0, 0, 1, 1, 0, 1, 1 }
    return unpack(c)
end
function Methods.SetVertexColor(t, r, g, b, a) t._vertex = { r, g, b, a } end
function Methods.GetVertexColor(t)
    local v = t._vertex or { 1, 1, 1, 1 }
    return v[1], v[2], v[3], v[4] or 1
end
function Methods.SetDesaturated(t, v) t._desat = v and true or false end
function Methods.IsDesaturated(t) return t._desat == true end
function Methods.SetShadowOffset(fs, x, y) fs._shadowOffset = { x, y } end
function Methods.GetShadowOffset(fs)
    local o = fs._shadowOffset or { 0, 0 }
    return o[1], o[2]
end
function Methods.SetShadowColor(fs, r, g, b, a) fs._shadowColor = { r, g, b, a } end
function Methods.SetRotation(t, r) t._rotation = r end
function Methods.SetColorTexture(t, r, g, b, a) t._color = { r, g, b, a } end
function Methods.AddMaskTexture(t, m) t._masks = t._masks or {}; table.insert(t._masks, m) end
function Methods.RemoveMaskTexture(t, m)
    for i, x in ipairs(t._masks or {}) do if x == m then table.remove(t._masks, i); return end end
end
function Methods.SetGradient(t, orientation, c1, c2)
    assert(type(c1) == "table" and type(c2) == "table", "SetGradient takes color objects on this API")
    t._gradient = { orientation, c1, c2 }
    -- An alpha set BEFORE the gradient doesn't survive it either: the texture
    -- shows and reads 1 (70374, SkinProbe W1.6 square B).
    t._alpha = 1
end
function Methods.SetFont(fs, file, size, flags) fs._font = { file, size, flags }; return true end

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

function WoW.reset()
    WoW.frames = {}
    WoW.chat = {}
    WoW.methodsCalled = WoW.methodsCalled or {}
    WoW.timers = {}
    WoW.mouseOver = {}
    WoW.animGroups = {}
    WoW.settingsOpened = nil
    WoW.cvars = {}
    WoW.class = "MAGE"
    WoW.combat = false
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
    if EventRegistry then EventRegistry.callbacks = {} end
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
end

function print(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    table.insert(WoW.chat, table.concat(parts, " "))
end

SlashCmdList = {}
strmatch = string.match
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
-- Seconds since the client started: what a test sets.
WoW.now = 0
function GetTime() return WoW.now end
function issecretvalue(v) return false end
function InCombatLockdown() return WoW.combat end
-- hooksecurefunc(table, name, fn) or hooksecurefunc(globalName, fn).
function hooksecurefunc(t, name, fn)
    if type(t) == "string" then
        local gname, f = t, name
        local orig = rawget(_G, gname)
        rawset(_G, gname, function(...) local r = orig(...); f(...); return r end)
        return
    end
    local orig = t[name]
    -- The client's own field: not an addon write (test_contract skips it).
    if rawget(t, "_blizz") then WoW.hookedKeys[t] = WoW.hookedKeys[t] or {}; WoW.hookedKeys[t][name] = true end
    rawset(t, name, function(self, ...)
        local r = orig(self, ...)
        -- The hook is addon code, even when Blizzard's side made the call.
        local was = WoW.inBlizzard
        WoW.inBlizzard = false
        fn(self, ...)
        WoW.inBlizzard = was
        return r
    end)
end

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

-- Timers keep their delay: WoW.flushTimers(upTo) runs those due within upTo.
C_Timer = { After = function(s, fn) table.insert(WoW.timers, { s = s, fn = fn }) end }
function WoW.flushTimers(upTo)
    for _ = 1, 10 do   -- timers may schedule timers; settle them
        local run, keep = {}, {}
        for _, t in ipairs(WoW.timers) do
            if upTo == nil or t.s <= upTo then run[#run + 1] = t else keep[#keep + 1] = t end
        end
        WoW.timers = keep
        if #run == 0 then return end
        for _, t in ipairs(run) do t.fn() end
    end
end

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
local blizzMT = {
    __index = MethodTable,
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
    f.PortraitContainer.portrait = blizz("Texture", f.PortraitContainer, nil, "OVERLAY")
    f.PortraitContainer.portrait._width, f.PortraitContainer.portrait._height = 62, 62
    f.PortraitContainer.CircleMask = blizz("MaskTexture", f.PortraitContainer)
    f.PortraitContainer.CircleMask._width, f.PortraitContainer.CircleMask._height = 62, 62
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

-- An item button of ContainerFrameItemButtonTemplate (ContainerFrame.xml:81):
-- its regions, the empty atlas key; in combined mode a slot background made
-- on demand (ContainerFrame.lua:1846).
local function itemButton(frame)
    local b = blizz("Button", frame)
    b._width, b._height = 37, 37
    b._level = frame._level + 1
    b.icon = blizz("Texture", b, nil, "BORDER")
    b.IconBorder = blizz("Texture", b, nil, "OVERLAY")
    b.Count = blizz("FontString", b, nil, "ARTWORK")
    b.NewItemTexture = blizz("Texture", b, nil, "OVERLAY")
    b._normal = blizz("Texture", b, nil, "ARTWORK")
    b._normal._file = "Interface\\Buttons\\UI-Quickslot2"
    rawset(b, "emptyBackgroundAtlas", "bags-item-slot64")
    return b
end

WoW.bagContents = setmetatable({}, { __mode = "k" })
WoW.bagButtons = setmetatable({}, { __mode = "k" })

local function updateItems(frame)
    local list = WoW.bagContents[frame] or {}
    local pool = WoW.bagButtons[frame]
    for _, b in ipairs(pool) do b:Hide() end                -- ReleaseAll
    local combined = frame == rawget(_G, "ContainerFrameCombinedBags")
    for i, item in ipairs(list) do
        local b = pool[i]
        if not b then b = itemButton(frame); pool[i] = b end   -- Acquire
        b:Show()
        if combined and not rawget(b, "ItemSlotBackground") then
            rawset(b, "ItemSlotBackground", blizz("Texture", b, nil, "BACKGROUND"))
        end
        if rawget(b, "ItemSlotBackground") then b.ItemSlotBackground:SetShown(combined) end
        if item == "empty" then
            b.icon:SetAtlas(b.emptyBackgroundAtlas)          -- SetItemButtonTexture(nil)
            b.IconBorder:Hide()
        else
            b.icon:SetTexture(item)
            b.IconBorder:Show()
            b.IconBorder:SetVertexColor(0.1, 0.4, 1)
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
function WoW.hideMerchant() WoW.asBlizzard(function() MerchantFrame:Hide() end) end

--------------------------------------------------------------------------------
-- Driving
--------------------------------------------------------------------------------

-- Fire an event at every frame registered for it. Errors are NOT caught.
function WoW.fire(event, ...)
    local list = {}
    for _, w in ipairs(WoW.frames) do list[#list + 1] = w end
    for _, w in ipairs(list) do
        local handler = w._scripts.OnEvent
        if handler and w._events[event] then handler(w, event, ...) end
    end
end

-- One rendered frame: OnUpdate on every visible frame.
function WoW.tick(elapsed)
    elapsed = elapsed or 0.02
    local list = {}
    for _, w in ipairs(WoW.frames) do list[#list + 1] = w end
    for _, w in ipairs(list) do
        local fn = w._scripts.OnUpdate
        if fn and Methods.IsVisible(w) then fn(w, elapsed) end
    end
end

WoW.reset()

-- Strict globals.
-- LibStub: the embedded library's own loader reads _G.LibStub before creating it.
local allowNil = { GlassUI = true, GlassUIDB = true, SkinProbeDB = true,
                   SLASH_GLASSUI1 = true, SLASH_GLASSUI2 = true, LibStub = true }
setmetatable(_G, { __index = function(_, k)
    if allowNil[k] then return nil end
    error("read of undefined global '" .. tostring(k) .. "' (not stubbed: is it in the API dump?)", 2)
end })
