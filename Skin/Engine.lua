-- Skin/Engine.lua: the registry every skin file registers with, and the one
-- place that decides whether a skin runs (docs/PLAN.md, "The skin engine").
--
-- A skin file calls Engine.Register once:
--   key      saved switch key, stable forever
--   title    its name in /glassui skins and on the settings page
--   addon    a load-on-demand window's addon: wait for it to load
--   owners   addons that own this window when loaded: we step aside
--   yields   { [addon] = predicate }: a third-party addon that rebuilds the
--            frame; read once at login, and a true predicate skips the skin
--   risk     "plain", or "protected": deferred a frame, first pass out of combat
--   frames   function returning the window(s)
--   install  function(kit, frame), once per frame: our panels and hooks
--   style    function(kit, frame), repeatable: the touches
--   live     true when it only fades and adds panels: off and on without a /reload
--
-- Everything runs at a window's OnShow (and at once when it's already shown),
-- never before: a ScrollBox window's first layout is Blizzard's to make
-- (Ellesmere WindowPacks:11993), and a yielding addon's login handler may
-- still be running at our PLAYER_LOGIN.
--
-- Hooks can't be removed, so every callback checks Engine.Active first, and
-- work queued for later (a deferred pass, a combat wait) also checks that the
-- generation hasn't changed: any switch, failure or handover bumps it.

GlassUI = GlassUI or {}
local GUI = GlassUI
local API = GUI.API
local Engine = {}
GUI.Engine = Engine

-- Full UI suites with their own skins of these windows: while one is loaded,
-- every skin stays off and says so once.
Engine.SUITES = { "ElvUI", "EllesmereUIBlizzardSkin", "Tukui" }

Engine.list = {}       -- skin states, in registration (TOC) order
Engine.byKey = {}
Engine.gen = 0
Engine.started = false
Engine.standDown = nil -- "gamepad", for the session
Engine.suite = nil     -- the loaded suite's name, for the session

-- A skin's state: def, kit, frames (after attach), installed[frame],
-- failed (what threw), owner (and late: it arrived after we styled), yieldTo.
function Engine.Register(def)
    assert(type(def) == "table" and type(def.key) == "string", "Engine.Register: a key")
    assert(not Engine.byKey[def.key], "Engine.Register: key taken: " .. def.key)
    assert(type(def.frames) == "function" and type(def.style) == "function", "Engine.Register: frames and style")
    local s = { def = def, installed = setmetatable({}, { __mode = "k" }) }
    s.kit = GUI.Kit.New(s)
    Engine.list[#Engine.list + 1] = s
    Engine.byKey[def.key] = s
    return s
end

-- The switches alone: the master and this skin's.
function Engine.Enabled(key)
    local db = GUI.db
    if not db or db.enabled == false then return false end
    return not (type(db.skins) == "table" and db.skins[key] == false)
end

local function loadedOwner(def)
    for _, name in ipairs(def.owners or {}) do
        if API.IsAddOnLoaded(name) then return name end
    end
    return nil
end

-- An owner turned up while we run: our callbacks stop and our panels hide.
-- Nothing is restored over the new owner's changes (plan: the handover).
local function handover(s, owner)
    s.owner = owner
    s.late = next(s.installed) ~= nil
    Engine.gen = Engine.gen + 1
    s.kit:HidePanels()
end

function Engine.Active(key)
    local s = Engine.byKey[key]
    if not s or not Engine.started or Engine.standDown or Engine.suite then return false end
    if s.failed or s.owner or s.yieldTo or not Engine.Enabled(key) then return false end
    local owner = loadedOwner(s.def)
    if owner then handover(s, owner) return false end
    return true
end

-- fn under pcall. A throw marks the skin failed for the session (Active is
-- then false), records it for /glassui failures and leaves the others alone.
-- Nothing is restored: the switch says to reload.
local function run(s, what, fn, ...)
    local ok, err = pcall(fn, ...)
    if ok then return true end
    s.failed = what
    Engine.gen = Engine.gen + 1
    API.Fail("skin:" .. s.def.key .. ":" .. what, err)
    return false
end
Engine.Run = run

-- fn a frame later, if nothing changed meanwhile.
function Engine.Defer(s, what, fn)
    local gen = Engine.gen
    C_Timer.After(0, function()
        if gen == Engine.gen and Engine.Active(s.def.key) then run(s, what, fn) end
    end)
end

local waiting = {}   -- { s, frame, gen }: protected first passes held for combat's end

local function apply(s, frame)
    if not Engine.Active(s.def.key) then return end
    if s.def.risk == "protected" and InCombatLockdown() then
        waiting[#waiting + 1] = { s = s, frame = frame, gen = Engine.gen }
        return
    end
    if not s.installed[frame] then
        if s.def.install and not run(s, "install", s.def.install, s.kit, frame) then return end
        s.installed[frame] = true
    end
    s.kit:ShowPanels()
    run(s, "style", s.def.style, s.kit, frame)
end

local function onShow(s, frame)
    if not Engine.Active(s.def.key) then return end
    if s.def.risk == "protected" then
        Engine.Defer(s, "show", function() apply(s, frame) end)
    else
        apply(s, frame)
    end
end

-- Find the skin's windows and hook their OnShow, once per session.
local function attach(s)
    if s.frames then return end
    local frames
    if not run(s, "frames", function() frames = { s.def.frames() } end) then return end
    s.frames = {}
    for _, frame in ipairs(frames) do
        if type(frame) == "table" and type(frame.HookScript) == "function" then
            s.frames[#s.frames + 1] = frame
        end
    end
    if #s.frames == 0 then
        s.failed = "frames"
        API.Fail("skin:" .. s.def.key .. ":frames", "no window found")
        return
    end
    for _, frame in ipairs(s.frames) do
        if not run(s, "hook", frame.HookScript, frame, "OnShow", function(f) onShow(s, f) end) then return end
        if frame:IsShown() then onShow(s, frame) end
    end
end

-- Attach now, or when its load-on-demand addon loads.
local function load(s)
    local addon = s.def.addon
    if addon and not API.IsAddOnLoaded(addon) then
        if s.waitingForAddon then return end
        s.waitingForAddon = true
        EventUtil.ContinueOnAddOnLoaded(addon, function()
            if Engine.Active(s.def.key) then attach(s) end
        end)
        return
    end
    attach(s)
end

local function gamepad()
    local ok, style = pcall(C_InputInterfaceStyle.GetCurrentStyle)
    local types = Enum.InputDeviceInterfaceType
    return ok and types ~= nil and API.Plain(style) == types.Gamepad
end

-- PLAYER_LOGIN: every non-load-on-demand addon (siblings included) is loaded.
function Engine.Start()
    if Engine.started then return end
    Engine.started = true
    -- Hooks on Blizzard windows break the gamepad's secure navigation
    -- (Ellesmere, EllesmereUIBlizzardSkin.lua:93-104): none this session.
    if gamepad() then Engine.standDown = "gamepad" return end
    for _, name in ipairs(Engine.SUITES) do
        if API.IsAddOnLoaded(name) then
            Engine.suite = name
            API.Print("skins are off while " .. name .. " is loaded: it skins these windows too.")
            return
        end
    end
    for _, s in ipairs(Engine.list) do
        s.owner = loadedOwner(s.def)
        for addon, predicate in pairs(s.def.yields or {}) do
            if API.IsAddOnLoaded(addon) and API.Try("skin:" .. s.def.key .. ":yield", predicate) then
                s.yieldTo = addon
            end
        end
    end
    for _, s in ipairs(Engine.list) do
        if Engine.Active(s.def.key) then load(s) end
    end
end

-- A switch changed. Returns "reload" when it takes a /reload to finish:
-- turning off a skin that isn't live, or a failed or handed-over one.
local function changed(s)
    Engine.gen = Engine.gen + 1
    if not Engine.started or Engine.standDown or Engine.suite then return nil end
    if Engine.Active(s.def.key) then
        if not s.frames then load(s) return nil end
        for _, frame in ipairs(s.frames) do
            if frame:IsShown() then onShow(s, frame) end
        end
        return nil
    end
    if s.failed or s.owner or s.yieldTo then return nil end
    if not s.def.live then return next(s.installed) and "reload" or nil end
    s.kit:Restore()
    return nil
end

function Engine.SetEnabled(key, on)
    local s = Engine.byKey[key]
    if not s or not GUI.db then return nil end
    GUI.db.skins = GUI.db.skins or {}
    if on then GUI.db.skins[key] = nil else GUI.db.skins[key] = false end
    return changed(s)
end

-- The master switch. "reload" when any skin needs one.
function Engine.SetMaster(on)
    if not GUI.db then return nil end
    if on then GUI.db.enabled = nil else GUI.db.enabled = false end
    local any
    for _, s in ipairs(Engine.list) do
        if Engine.Enabled(s.def.key) or not on then any = changed(s) or any end
    end
    return any
end

-- One line for /glassui skins and the settings page.
function Engine.Status(key)
    local s = Engine.byKey[key]
    if not s then return "unknown" end
    if Engine.standDown == "gamepad" then return "off: the gamepad interface is on" end
    if Engine.suite then return "off: " .. Engine.suite .. " is loaded" end
    if s.failed then return "failed (" .. s.failed .. "): /reload to restore, /glassui failures for why" end
    if s.owner then
        return "handled by " .. s.owner .. (s.late and ", /reload to finish the handover" or "")
    end
    if s.yieldTo then return "skipped: " .. s.yieldTo .. " rebuilds this window" end
    if not Engine.Enabled(key) then
        if next(s.installed) and not s.def.live then return "off after a /reload" end
        return "off"
    end
    if s.def.addon and not API.IsAddOnLoaded(s.def.addon) then return "on (waits for " .. s.def.addon .. ")" end
    return "on"
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_REGEN_ENABLED" then
        local list = waiting
        waiting = {}
        for _, w in ipairs(list) do
            if w.gen == Engine.gen then apply(w.s, w.frame) end
        end
    elseif event == "ADDON_LOADED" then
        -- An owner loading after us: hand over now, not at the next callback.
        for _, s in ipairs(Engine.list) do
            if not s.owner then
                for _, name in ipairs(s.def.owners or {}) do
                    if name == arg1 then handover(s, name) break end
                end
            end
        end
    end
end)
API.RegisterEvents(events, { "PLAYER_REGEN_ENABLED", "ADDON_LOADED" }, "engine")

Engine._test = { waiting = function() return waiting end, apply = apply }
