-- SkinProbe: the throwaway measurement addon for Glass UI, milestone 2 (#2).
-- It answers what docs/FOREVER-PROBE.md leaves open before the wave-1 skins
-- are built. It is a ForeverProbe module (..\ForeverProbe, docs/GUIDE.md): its
-- lines go to the ForeverProbe console (/fp), never to chat, and to
-- SkinProbeDB.log, read from disk after a /reload.
--
-- It is DISCOVERY only. Each skin's acceptance is on its final implementation.
--
-- What it measures (the W numbers match docs/FOREVER-PROBE.md):
--   W1.1/W1.2  the wave-1 frames and their region trees      /fp skin tree <target>
--   W1.2       which Blizzard textures ignore SetAlpha       /fp skin fade <target>
--   W1.3       glass on the world map's frame buffer         /fp steps skin map
--   W1.4       the gamepad interface style                   /fp skin state
--   W1.5       who else owns /gui                            /fp skin state
--   W1.6       the gradient questions left open              /fp steps skin gradient
-- The guided run for the windows is /fp steps skin wave1.
--
-- Each skin's acceptance, on the real addon, with screenshots:
--   #4 merchant                                              /fp steps skin merchant
--   #24 the suite theme across GUF and GRF (S.1-S.8)          /fp steps skin suite
--   #24 S.7 again, combat only                                 /fp steps skin suitecombat
--   #58 Glass Panel in the suite: Pearl, its options, its edge /fp steps skin suitepanel
--   #54 Glass UI's own skins on Pearl                         /fp steps skin pearl
--   #55 the quest tracker                                      /fp steps skin tracker
--   #71 the accent on the yellow titles                        /fp steps skin accent
--   #73 the quest timers on a pill                             /fp steps skin timer
--       on fake timers, for want of timed quests                /fp steps skin timerfake
--
-- Discovery for #56, Questie and RestedXP:                    /fp steps skin questing
-- And Blizzard's own glass, the login ruleset card beside ours (#17): /fp steps skin card
--
-- Discovery for the next skin:
--   #49 the damage meter: its windows, bars, styles, breakdown     /fp steps skin meter
--                         its state and settings now               /fp skin meter
--   #49 the damage meter skin's acceptance                         /fp steps skin meterskin
--   #49 a glass bars preview (never shipped)                        /fp steps skin meterbars
--
-- The only writes to Blizzard objects are SetAlpha, always put back at once
-- (`fade`) or by `border restore`, and our own frames parented to the map.
-- And one swap: `timerfake` lends C_QuestLog.GetQuestTimers an answer of its
-- own, put back when it ends, and its procedure ends on a /reload.
-- Every client call that may be missing or throw goes through Probe:Try or a
-- pcall, so one refusal can't stop the rest.

local ADDON, NS = ...
-- The trees are long (the character sheet alone is ~1800 lines): at 6000 the
-- first run's oldest tenth, the state lines, was trimmed away (70374).
local MAX_LOG = 20000
local MAX_TREE_LINES = 700        -- per target, so one window can't flood the log
-- The meter holds up to three windows of pooled bars, each bar a few frames deep.
local TREE_MAX = { meter = 2000 }

local Probe = ForeverProbe:Module("SkinProbe", { api = 1, cmd = "skin" })

local function say(msg) Probe:Say(msg) end
local function show(v) return Probe.Show(v, true) end

-- v, or nil when it is secret (never compared or concatenated then).
local function plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

-- obj:method(...) under pcall: ok, ... (false when obj isn't an object or the
-- method is absent).
local function call(obj, method, ...)
    if type(obj) ~= "table" then return false end
    local fn = obj[method]
    if type(fn) ~= "function" then return false end
    return pcall(fn, obj, ...)
end

local function num(v)
    v = plain(v)
    if type(v) ~= "number" then return show(v) end
    return string.format("%.2f", v)
end

--------------------------------------------------------------------------------
-- The targets (wow-ui-source `forever` @70374)
--------------------------------------------------------------------------------

-- Every one of these is always loaded on Forever: Blizzard_TokenUI and
-- Blizzard_Statistics (Forever only) have no LoadOnDemand line.
local TARGETS = {
    merchant  = { "MerchantFrame" },
    popup     = { "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4" },
    character = { "CharacterFrame", "PaperDollFrame", "ReputationFrame", "SkillsFrame", "PVPRankFrame",
                  "TokenFrame", "StatisticsFrame" },
    map       = { "WorldMapFrame", "QuestMapFrame" },
    -- #49: Blizzard_DamageMeter (AllowLoadGameType standard, camelot), not a wave-1 window.
    meter     = { "DamageMeter" },
}
local ORDER = { "merchant", "popup", "character", "map" }
NS.TARGETS = TARGETS

-- The neighbours the skins must coexist with or step aside for (docs/PLAN.md).
local NEIGHBOURS = { "Leatrix_Maps", "Auctionator", "Skilled", "ElvUI", "EllesmereUI", "Tukui",
                     "GlassMail", "GlassActionBars", "GlassChat", "GlassQuestTracker", "GlassMiniMap",
                     "GlassMiniMapBar", "GlassUnitFrames", "GlassRaidFrames", "GlassPanel", "GlassMaps",
                     "Details", "Skada", "Recount" }

local function frameByName(name)
    local f = rawget(_G, name)
    if type(f) == "table" and type(f.GetObjectType) == "function" then return f end
    return nil
end

--------------------------------------------------------------------------------
-- Results: the answers, kept apart from the log so trimming can't lose them
--------------------------------------------------------------------------------

-- SkinProbeDB.results[key] = a plain value (never a secret). The log holds
-- the detail; this holds what docs/FOREVER-PROBE.md records.
local function record(key, value)
    if type(SkinProbeDB) ~= "table" then return end
    if type(SkinProbeDB.results) ~= "table" then SkinProbeDB.results = {} end
    SkinProbeDB.results[key] = value
end

--------------------------------------------------------------------------------
-- State: gamepad style (W1.4), /gui (W1.5), neighbours, frames (W1.1)
--------------------------------------------------------------------------------

-- Ellesmere's test (v9.8.6 EllesmereUI_UICore.lua, "style.GetCurrentStyle() == types.Gamepad",
-- ~1554): the current input interface
-- style against Enum.InputDeviceInterfaceType.Gamepad. Read live, no event.
local function gamepad()
    local style = rawget(_G, "C_InputInterfaceStyle")
    local enum = rawget(_G, "Enum") and Enum.InputDeviceInterfaceType
    if not (style and style.GetCurrentStyle) then say("W1.4 C_InputInterfaceStyle.GetCurrentStyle ABSENT"); return nil end
    local ok, cur = Probe:Try("GetCurrentStyle", style.GetCurrentStyle)
    local pad = enum and enum.Gamepad
    local isPad = ok and plain(cur) ~= nil and pad ~= nil and plain(cur) == pad
    say("W1.4 style=" .. show(ok and cur) .. " Gamepad=" .. show(pad) .. " -> gamepad " .. tostring(isPad))
    if enum then say("W1.4 Enum.InputDeviceInterfaceType " .. Probe.Describe(enum)) end
    local okCvar, padCvar = Probe:Try("GetCVar GamePadEnable", rawget(_G, "GetCVar"), "GamePadEnable")
    say("W1.4 CVar GamePadEnable=" .. show(okCvar and padCvar))
    record("W1.4", { style = ok and plain(cur) or nil, gamepadValue = pad, gamepad = isPad,
                     GamePadEnable = okCvar and plain(padCvar) or nil })
    return isPad
end

-- Every SLASH_* global equal to /gui, ours (SLASH_GLASSUI2) included.
local function slashOwners(word)
    local owners = {}
    for k, v in pairs(_G) do
        if type(k) == "string" and k:sub(1, 6) == "SLASH_" and type(v) == "string" and not (issecretvalue and issecretvalue(v))
            and v:lower() == word then
            owners[#owners + 1] = k
        end
    end
    table.sort(owners)
    return owners
end

local function slash()
    local owners = slashOwners("/gui")
    say("W1.5 /gui is set by: " .. (#owners > 0 and table.concat(owners, ", ") or "nobody"))
    local others = 0
    for _, k in ipairs(owners) do if k ~= "SLASH_GLASSUI2" then others = others + 1 end end
    say("W1.5 owners other than Glass UI: " .. others)
    record("W1.5", { owners = table.concat(owners, ","), others = others })
    return others
end

local function loaded(name)
    local fn = C_AddOns and C_AddOns.IsAddOnLoaded
    if not fn then return false end
    local ok, v = pcall(fn, name)
    return ok and plain(v) == true
end

local function neighbours()
    local on = {}
    for _, name in ipairs(NEIGHBOURS) do if loaded(name) then on[#on + 1] = name end end
    say("loaded neighbours: " .. (#on > 0 and table.concat(on, ", ") or "none"))
    -- Leatrix Maps' effective mode for the session: read once at its
    -- ADDON_LOADED with default On (Leatrix_Maps.lua:2887).
    if loaded("Leatrix_Maps") then
        local db = rawget(_G, "LeaMapsDB")
        local v = type(db) == "table" and db.SimpleMapFrame or nil
        say("Leatrix Maps SimpleMapFrame=" .. show(v) .. " -> simple frame " .. tostring(v ~= "Off"))
        record("leatrixSimpleFrame", v ~= "Off")
    end
    record("neighbours", table.concat(on, ","))
    return on
end

local function frameLine(f, label)
    local okP, prot, explicit = call(f, "IsProtected")
    local _, forbidden = call(f, "IsForbidden")
    local _, strata = call(f, "GetFrameStrata")
    local _, level = call(f, "GetFrameLevel")
    local _, shown = call(f, "IsShown")
    local _, w = call(f, "GetWidth")
    local _, h = call(f, "GetHeight")
    local _, flat = call(f, "GetFlattensRenderLayers")
    local s = show(select(2, call(f, "GetObjectType"))) .. " protected=" .. show(okP and prot)
        .. "/" .. show(okP and explicit) .. " forbidden=" .. show(forbidden) .. " strata=" .. show(strata)
        .. " level=" .. show(level) .. " shown=" .. show(shown) .. " size=" .. num(w) .. "x" .. num(h)
        .. " flattens=" .. show(flat)
    say(label .. " " .. s)
    return s
end

local function frames()
    for _, key in ipairs(ORDER) do
        for _, name in ipairs(TARGETS[key]) do
            local f = frameByName(name)
            if f then
                record("W1.1." .. name, frameLine(f, "W1.1 " .. key .. " " .. name))
            else
                say("W1.1 " .. key .. " " .. name .. " MISSING")
                record("W1.1." .. name, "MISSING")
            end
        end
    end
end

local function state()
    say("client " .. table.concat({ GetBuildInfo() }, " ", 1, 2) .. " combat=" .. show(InCombatLockdown()))
    gamepad()
    slash()
    neighbours()
    frames()
end

--------------------------------------------------------------------------------
-- Region trees (W1.2)
--------------------------------------------------------------------------------

local function regionLine(r, path)
    local _, otype = call(r, "GetObjectType")
    local _, name = call(r, "GetName")
    local _, key = call(r, "GetParentKey")
    local _, layer, sub = call(r, "GetDrawLayer")
    local _, alpha = call(r, "GetAlpha")
    local _, shown = call(r, "IsShown")
    local s = path .. " " .. show(otype) .. " name=" .. show(name) .. " key=" .. show(key)
        .. " layer=" .. show(layer) .. "/" .. show(sub) .. " alpha=" .. num(alpha) .. " shown=" .. show(shown)
    if plain(otype) == "Texture" then
        local _, atlas = call(r, "GetAtlas")
        local _, tex = call(r, "GetTexture")
        s = s .. " atlas=" .. show(atlas) .. " tex=" .. show(tex)
    end
    return s
end

-- A child's label: its parentKey, else its name, else its index.
local function childLabel(c, i)
    local _, key = call(c, "GetParentKey")
    key = plain(key)
    if type(key) == "string" and key ~= "" then return key end
    local _, name = call(c, "GetName")
    name = plain(name)
    if type(name) == "string" and name ~= "" then return name end
    return "#" .. i
end

-- Depth-first over a frame's regions and children. visit(kind, obj, path)
-- gets "frame" or "region"; the walk stops after `budget` visits.
local function walk(f, path, depth, visit, budget)
    budget.n = budget.n + 1
    if budget.n > budget.max then return end
    visit("frame", f, path, f)
    -- call() is ok, ...: everything after the first value is the region list.
    local regions = { select(2, call(f, "GetRegions")) }
    for i, r in ipairs(regions) do
        budget.n = budget.n + 1
        if budget.n > budget.max then return end
        visit("region", r, path .. "." .. childLabel(r, i), f)
    end
    if depth <= 0 then return end
    local kids = { select(2, call(f, "GetChildren")) }
    for i, c in ipairs(kids) do
        walk(c, path .. "." .. childLabel(c, i), depth - 1, visit, budget)
        if budget.n > budget.max then return end
    end
end

local function eachTarget(key, fn)
    local names = TARGETS[key]
    if not names then say("unknown target " .. show(key) .. " (merchant, popup, character, map, meter, questing)"); return false end
    for _, name in ipairs(names) do
        local f = frameByName(name)
        if f then fn(f, name) else say(key .. " " .. name .. " MISSING") end
    end
    return true
end

-- One frame's tree, every frame and region under `name`.
local function treeOf(f, name, depth, max)
    local lines = 0
    local budget = { n = 0, max = max or MAX_TREE_LINES }
    walk(f, name, depth, function(kind, obj, path)
        lines = lines + 1
        if kind == "frame" then frameLine(obj, "W1.2 F " .. path) else say("W1.2 R " .. regionLine(obj, path)) end
    end, budget)
    if budget.n > budget.max then say("W1.2 " .. name .. " TRUNCATED at " .. budget.max .. " lines") end
    return lines
end

local function tree(key, depth)
    depth = tonumber(depth) or 4
    local lines = 0
    eachTarget(key, function(f, name) lines = lines + treeOf(f, name, depth, TREE_MAX[key]) end)
    say("W1.2 tree " .. key .. " depth " .. depth .. ": " .. lines .. " lines")
    return lines
end

--------------------------------------------------------------------------------
-- Fade readback (W1.2): which Blizzard textures ignore SetAlpha
--------------------------------------------------------------------------------

-- kit:Fade's own check, tried on every texture of a target: SetAlpha(0), read
-- it back, put the old alpha back at once. A texture that still reads non-zero
-- carries a gradient (porting guide section 3) and needs Blank instead.
local function fade(key, depth)
    if InCombatLockdown() then say("fade: not in combat"); return nil end
    depth = tonumber(depth) or 4
    local tried, ignored, which = 0, 0, {}
    eachTarget(key, function(f, name)
        walk(f, name, depth, function(kind, obj, path)
            if kind ~= "region" then return end
            local _, otype = call(obj, "GetObjectType")
            if plain(otype) ~= "Texture" then return end
            local okA, before = call(obj, "GetAlpha")
            before = plain(before)
            if not okA or type(before) ~= "number" then return end
            tried = tried + 1
            call(obj, "SetAlpha", 0)
            local _, after = call(obj, "GetAlpha")
            call(obj, "SetAlpha", before)
            after = plain(after)
            if after ~= 0 then
                ignored = ignored + 1
                which[#which + 1] = path
                say("W1.2 IGNORES SetAlpha: " .. path .. " read " .. num(after) .. " after SetAlpha(0)")
            end
        end, { n = 0, max = TREE_MAX[key] or MAX_TREE_LINES })
    end)
    say("W1.2 fade " .. key .. ": " .. tried .. " textures tried, " .. ignored .. " ignore SetAlpha")
    if TARGETS[key] then
        record("W1.2.fade." .. key, { tried = tried, ignored = ignored, which = table.concat(which, " ") })
    end
    return tried, ignored
end

--------------------------------------------------------------------------------
-- Glass on the world map (W1.3)
--------------------------------------------------------------------------------

-- Two of our own frames, children of WorldMapFrame (frameBuffer="true"):
-- "under" fills the window at its own level, behind the map; "over" is a box
-- in the top-left corner, above it. Each is Glass UI's real material when
-- Glass UI is loaded, plus a blue tint so it can't be mistaken.
local panels = {}
local faded = {}            -- texture -> alpha before `border fade`

local function glassPanel(parent, level)
    local f = CreateFrame("Frame", nil, parent)
    f:SetFrameLevel(level)
    f:EnableMouse(false)
    local glass = rawget(_G, "GlassUI") and GlassUI.Glass
    if glass and glass.Apply then
        local ok, err = pcall(glass.Apply, f, "large")
        if not ok then say("W1.3 Glass.Apply ERROR " .. show(err)) end
    end
    local tint = f:CreateTexture(nil, "BACKGROUND", nil, -7)
    tint:SetAllPoints(f)
    tint:SetColorTexture(0.2, 0.5, 1, 0.35)
    return f
end

local function panelsOn()
    if InCombatLockdown() then say("panels: not in combat"); return false end
    local map = frameByName("WorldMapFrame")
    if not map then say("W1.3 WorldMapFrame MISSING"); return false end
    if panels.under then say("W1.3 panels already on"); return true end
    local _, level = call(map, "GetFrameLevel")
    level = plain(level) or 1
    panels.under = glassPanel(map, level)
    panels.under:SetAllPoints(map)
    panels.over = glassPanel(map, level + 50)
    panels.over:SetSize(220, 120)
    panels.over:SetPoint("TOPLEFT", map, "TOPLEFT", 40, -60)
    say("W1.3 panels on: under at level " .. level .. ", over at " .. (level + 50)
        .. ", glass " .. tostring(rawget(_G, "GlassUI") ~= nil))
    return true
end

local function panelsOff()
    for k, f in pairs(panels) do f:Hide(); f:SetParent(nil); panels[k] = nil end
    say("W1.3 panels off")
end

-- The border's own art, faded so "under" shows where it was.
local function borderFade()
    if InCombatLockdown() then say("border: not in combat"); return 0 end
    local map = frameByName("WorldMapFrame")
    local border = map and map.BorderFrame
    if not border then say("W1.3 WorldMapFrame.BorderFrame MISSING"); return 0 end
    local n = 0
    -- The border's art only, never a button's: fading the maximise button's
    -- textures hid it, and the owner couldn't maximise (70374, first run).
    walk(border, "BorderFrame", 2, function(kind, obj, _, owner)
        if kind ~= "region" or faded[obj] then return end
        local _, ownerType = call(owner, "GetObjectType")
        if plain(ownerType) == "Button" then return end
        local _, otype = call(obj, "GetObjectType")
        if plain(otype) ~= "Texture" then return end
        local _, a = call(obj, "GetAlpha")
        a = plain(a)
        if type(a) ~= "number" then return end
        faded[obj] = a
        call(obj, "SetAlpha", 0)
        n = n + 1
    end, { n = 0, max = MAX_TREE_LINES })
    say("W1.3 border fade: " .. n .. " textures")
    return n
end

local function borderRestore()
    local n = 0
    for t, a in pairs(faded) do call(t, "SetAlpha", a); faded[t] = nil; n = n + 1 end
    say("W1.3 border restore: " .. n .. " textures")
    return n
end

--------------------------------------------------------------------------------
-- Gradients (W1.6): the two open questions, on our own textures
--------------------------------------------------------------------------------

-- A: colour texture, gradient, then SetAlpha(0)  -> the measured case (still shows)
-- B: colour texture, SetAlpha(0), then gradient  -> does the earlier alpha survive?
-- C: file texture, gradient, then SetAlpha(0)    -> do file textures ignore it too?
-- D: file texture, no gradient, SetAlpha(0)      -> the control (hidden)
local squares
local FILE = "Interface\\Buttons\\WHITE8X8"

local function gradientOn()
    if squares then return squares.readback end
    local host = CreateFrame("Frame", nil, UIParent)
    host:SetSize(4 * 70, 100)
    host:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    host:SetFrameStrata("DIALOG")
    local readback = {}
    local function square(i, label, build)
        local t = host:CreateTexture(nil, "ARTWORK")
        t:SetSize(50, 50)
        t:SetPoint("TOPLEFT", host, "TOPLEFT", (i - 1) * 70 + 10, -10)
        build(t)
        local _, a = call(t, "GetAlpha")
        readback[label] = plain(a)
        local fs = host:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        fs:SetPoint("TOP", t, "BOTTOM", 0, -6)
        fs:SetText(label)
        say("W1.6 " .. label .. " GetAlpha after the sequence = " .. num(a))
    end
    local top, bottom = CreateColor(1, 1, 1, 1), CreateColor(1, 1, 1, 1)
    square(1, "A", function(t) t:SetColorTexture(1, 1, 1, 1); t:SetGradient("VERTICAL", bottom, top); t:SetAlpha(0) end)
    square(2, "B", function(t) t:SetColorTexture(1, 1, 1, 1); t:SetAlpha(0); t:SetGradient("VERTICAL", bottom, top) end)
    square(3, "C", function(t) t:SetTexture(FILE); t:SetGradient("VERTICAL", bottom, top); t:SetAlpha(0) end)
    square(4, "D", function(t) t:SetTexture(FILE); t:SetAlpha(0) end)
    squares = { host = host, readback = readback }
    record("W1.6.readback", { A = readback.A, B = readback.B, C = readback.C, D = readback.D })
    return readback
end

local function gradientOff()
    if squares then squares.host:Hide(); squares.host:SetParent(nil); squares = nil end
end

--------------------------------------------------------------------------------
-- The damage meter (#49): what the skin's plan needs, before it is written.
-- Blizzard_DamageMeter (origin/forever @70450): DamageMeter, an Edit Mode
-- system, holds up to three session windows, DamageMeterSessionWindow1-3,
-- created on first use. Each has a Header atlas, MinimizeContainer.Background
-- (its alpha is Blizzard's, from the Edit Mode Background setting), pooled
-- bars in a ScrollBox, and a SourceWindow (a bar's breakdown). The Style
-- setting swaps each bar's background atlas and hides or shows its edge.
-- Reads only, plus the fade readback, which puts each alpha back at once.
--------------------------------------------------------------------------------

local MAX_METER_WINDOWS = 3       -- MAX_DAMAGE_METER_SESSION_WINDOWS, a local in DamageMeter.lua

local function meterWindows()
    local out = {}
    for i = 1, MAX_METER_WINDOWS do
        local w = frameByName("DamageMeterSessionWindow" .. i)
        if w then out[#out + 1] = w end
    end
    return out
end

local function meterShownWindows()
    local n = 0
    for _, w in ipairs(meterWindows()) do
        local ok, v = call(w, "IsShown")
        if ok and plain(v) == true then n = n + 1 end
    end
    return n
end

-- A window's bars: its pooled entry frames, through its own enumerator.
local function meterBars(w)
    local bars = {}
    call(w, "ForEachEntryFrame", function(e) bars[#bars + 1] = e end)
    return bars
end

local function meterBarCount()
    local n = 0
    for _, w in ipairs(meterWindows()) do n = n + #meterBars(w) end
    return n
end

-- The Style setting by its enum name (Default, Bordered, Thin), or nil.
local function meterStyle()
    local ok, v = call(frameByName("DamageMeter"), "GetStyle")
    v = ok and plain(v) or nil
    if v == nil then return nil end
    local okE, styles = pcall(function() return Enum.DamageMeterStyle end)
    if okE and type(styles) == "table" then
        for name, n in pairs(styles) do if n == v then return name end end
    end
    return tostring(v)
end

local function editMode()
    local ok, v = call(frameByName("EditModeManagerFrame"), "IsEditModeActive")
    return ok and plain(v) == true
end

-- A wait's own state belongs to one attempt at its step (Codex on #181).
-- ForeverProbe keeps a procedure's step functions across Stop and a restart,
-- and calls a wait with nothing, so a "seen" marker left by a stopped, skipped
-- or timed-out attempt would pass the next one at its first poll. The returned
-- function is true when a poll starts a new attempt: the running record
-- changed (a restart makes a new one), or the wait wasn't polled for longer
-- than ATTEMPT_GAP (ForeverProbe polls every second while waiting, Steps.lua
-- POLL; a step left and reached again misses polls).
local attempt
do
local ATTEMPT_GAP = 2.5
function attempt()
    local lastRec, lastPoll
    return function()
        local fp = rawget(_G, "ForeverProbe")
        local steps = type(fp) == "table" and rawget(fp, "Steps")
        local rec
        if type(steps) == "table" and type(steps.Active) == "function" then
            local ok, _, r = pcall(steps.Active)
            rec = ok and r or nil
        end
        local now = GetTime()
        local fresh = lastPoll == nil or now - lastPoll > ATTEMPT_GAP or rec ~= lastRec
        lastRec, lastPoll = rec, now
        return fresh
    end
end
end

local function shownFrame(f)
    local ok, v = call(f, "IsShown")
    return ok and plain(v) == true
end

-- The breakdown that is open, in whichever window: pinned (Shift-click, its
-- close button shown) when `pinned`. A plain click's breakdown closes at the
-- next mouse press outside it (GLOBAL_MOUSE_DOWN, DamageMeterSourceWindow.lua:45),
-- the Measure button's included.
local function sourceWindow(pinned)
    for _, w in ipairs(meterWindows()) do
        local mc = rawget(w, "MinimizeContainer")
        local src = mc and rawget(mc, "SourceWindow")
        if shownFrame(src) and (not pinned or shownFrame(rawget(src, "CloseButton"))) then return src end
    end
    return nil
end

local function meterShown()
    local ok, v = call(frameByName("DamageMeter"), "IsShown")
    return ok and plain(v) == true
end

local function atlasOf(t)
    local _, a = call(t, "GetAtlas")
    return show(a)
end

local function alphaOf(r)
    local ok, a = call(r, "GetAlpha")
    return ok and num(a) or "?"
end

-- The meter's switches and Edit Mode settings, then one line per window and
-- its first bar: what the style changes, and whether a bar's value and colour
-- are secret (the skin may only restyle what it can read).
local function meterState(label)
    local m = frameByName("DamageMeter")
    local cvar = rawget(_G, "C_CVar")
    local okC, enabled = pcall(function() return cvar.GetCVar("damageMeterEnabled") end)
    local dm = rawget(_G, "C_DamageMeter")
    local okA, available, why = pcall(function() return dm.IsDamageMeterAvailable() end)
    local parts = { "loaded=" .. tostring(loaded("Blizzard_DamageMeter")),
                    "cvar=" .. (okC and show(enabled) or "?"),
                    "available=" .. (okA and show(available) or "?") .. (okA and why and ("/" .. show(why)) or ""),
                    "shown=" .. tostring(meterShown()), "editMode=" .. tostring(editMode()),
                    "style=" .. show(meterStyle()) }
    for _, getter in ipairs({ "GetWindowAlpha", "GetBackgroundAlpha", "GetBarHeight", "GetTextScale" }) do
        local ok, v = call(m, getter)
        parts[#parts + 1] = getter:sub(4) .. "=" .. (ok and num(v) or "?")
    end
    parts[#parts + 1] = "visibility=" .. show(m and rawget(m, "visibility"))
    parts[#parts + 1] = "combat=" .. tostring(InCombatLockdown())
    local lines = { table.concat(parts, " ") }
    say("DM " .. label .. ": " .. lines[1])
    for i, w in ipairs(meterWindows()) do
        local _, wShown = call(w, "IsShown")
        local _, minimized = call(w, "IsMinimized")
        local _, ww = call(w, "GetWidth")
        local _, wh = call(w, "GetHeight")
        local mc = rawget(w, "MinimizeContainer")
        local bars = meterBars(w)
        local s = "window" .. i .. " shown=" .. show(wShown) .. " minimized=" .. show(minimized)
            .. " size=" .. num(ww) .. "x" .. num(wh) .. " alpha=" .. alphaOf(w)
            .. " header=" .. atlasOf(rawget(w, "Header")) .. " background=" .. atlasOf(mc and rawget(mc, "Background"))
            .. "@" .. alphaOf(mc and rawget(mc, "Background")) .. " bars=" .. #bars
        local sb = bars[1] and rawget(bars[1], "StatusBar")
        if sb then
            local _, v = call(sb, "GetValue")
            local _, r, g, b = call(sb, "GetStatusBarColor")
            local _, fill = call(sb, "GetStatusBarTexture")
            local edge = rawget(sb, "BackgroundEdge")
            local _, edgeShown = call(edge, "IsShown")
            local _, bh = call(bars[1], "GetHeight")
            local secret = issecretvalue ~= nil and (issecretvalue(v) or issecretvalue(r)) or false
            s = s .. " bar1 h=" .. num(bh) .. " fill=" .. atlasOf(fill) .. " colour=" .. num(r) .. "," .. num(g)
                .. "," .. num(b) .. " bg=" .. atlasOf(rawget(sb, "Background")) .. "@" .. alphaOf(rawget(sb, "Background"))
                .. " edge=" .. show(edgeShown) .. " secret=" .. tostring(secret)
        end
        lines[#lines + 1] = s
        say("DM " .. label .. " " .. s)
    end
    record("DM." .. label, table.concat(lines, " | "))
    return meterStyle(), #meterWindows()
end

-- The first bar alone, at full depth: the regions a style changes.
local function barTree(label)
    -- The first window with a bar: a solo fight may fill only one of them.
    local bar
    for _, w in ipairs(meterWindows()) do
        bar = bar or meterBars(w)[1]
    end
    if not bar then say("DM " .. label .. ": no bar to walk"); return 0 end
    return treeOf(bar, "DM." .. label .. ".bar1", 4)
end

-- The style the owner started with, so the last style step puts it back, and
-- how many windows were shown then, so "add a window" waits for a new one.
local meterWas, windowsWere

Probe:Steps("meter", {
    title = "Glass UI: the damage meter (#49)",
    { text = "Reads the damage meter's state: loaded, switched on, its Edit Mode settings, its windows.",
      auto = true, run = function()
          meterWas, windowsWere = meterStyle(), meterShownWindows()
          return meterState("start")
      end,
      check = function() return loaded("Blizzard_DamageMeter"), "Blizzard_DamageMeter loaded" end },
    { text = "If the damage meter isn't on screen, turn it on (Options, Advanced) and set its Visibility to "
          .. "Always Visible in Edit Mode. This step goes on by itself once it shows.",
      wait = function() return meterShown() and not editMode(), "the meter isn't shown, or Edit Mode is open" end,
      timeout = 300 },
    { text = "Hit something for a few seconds (a training dummy or any mob) until bars show in the meter. "
          .. "This step goes on by itself.",
      wait = function() local n = meterBarCount(); return n > 0, n .. " bars" end, timeout = 600 },
    { text = "Out of combat, press Measure: every frame and texture of the meter, in your current style.",
      button = "Measure", screenshot = "meter, current style",
      run = function() return meterState("first"), tree("meter", 8), fade("meter", 8) end,
      check = function() return not InCombatLockdown(), "measured out of combat" end },
    { text = "Open Edit Mode, click the damage meter, set Style to Bordered, and close Edit Mode. "
          .. "This step goes on by itself.",
      wait = function() return meterStyle() == "Bordered" and not editMode(), "style " .. show(meterStyle()) end,
      timeout = 600 },
    { text = "Bordered. Press Measure.", button = "Measure", screenshot = "meter, Bordered",
      run = function() return meterState("Bordered"), barTree("Bordered") end },
    { text = "Now the same with Style set to Thin.",
      wait = function() return meterStyle() == "Thin" and not editMode(), "style " .. show(meterStyle()) end,
      timeout = 600 },
    { text = "Thin. Press Measure.", button = "Measure", screenshot = "meter, Thin",
      run = function() return meterState("Thin"), barTree("Thin") end },
    { text = "Put Style back to the one you use, and close Edit Mode.",
      wait = function()
          return meterStyle() == (meterWas or "Default") and not editMode(), "style " .. show(meterStyle())
      end, timeout = 600 },
    { text = "Hold Shift and click a bar in the meter, so its breakdown stays open (it shows a close "
          .. "button). This step goes on by itself.",
      wait = function() return sourceWindow(true) ~= nil, "no pinned breakdown open" end, timeout = 300 },
    { text = "The breakdown. Press Measure.", button = "Measure", screenshot = "meter, breakdown",
      run = function()
          local src = sourceWindow(true)
          return meterState("breakdown"), src and treeOf(src, "DM.breakdown", 6, TREE_MAX.meter) or 0
      end },
    { text = "Close the breakdown with its close button. Then open the gear menu on the meter and add a new window. "
          .. "This step goes on by itself.",
      wait = function()
          local n = meterShownWindows()
          -- Three is Blizzard's maximum: nothing to add then.
          return n > (windowsWere or 1) or n >= MAX_METER_WINDOWS, n .. " windows shown"
      end, timeout = 300 },
    { text = "The new window. Press Measure.", button = "Measure", screenshot = "meter, new window",
      run = function()
          local all = meterWindows()
          local last = all[#all]
          return meterState("new window"), last and treeOf(last, "DM.newWindow", 7, TREE_MAX.meter) or 0
      end },
    { text = "Minimize one window with its button at the top right, then press Next for a screenshot.",
      screenshot = "meter, minimized",
      check = function()
          for _, w in ipairs(meterWindows()) do
              local ok, v = call(w, "IsMinimized")
              if ok and plain(v) == true then return true, meterState("minimized") end
          end
          return false, "no window minimized"
      end },
    { text = "Optional, Skip if it isn't easy: fight something and press Measure while in combat. It records "
          .. "whether the bars' values and colours are hidden (secret) during combat.", button = "Measure",
      run = function() return meterState("combat") end,
      check = function() return InCombatLockdown(), "measured in combat" end },
    { text = "Put the meter back the way you like it (the gear menu hides the extra window, the minimize "
          .. "button brings a window back). Then reload to save the results.", reload = true },
})

--------------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------------

Probe:Command("state", function() state() end, "W1.1/W1.4/W1.5: frames, gamepad style, /gui, neighbours")
Probe:Command("tree", function(args)
    local key, depth = (args or ""):match("^%s*(%S*)%s*(%S*)")
    tree(key, depth)
end, "W1.2: tree <merchant|popup|character|map|meter> [depth]: every frame and region")
Probe:Command("fade", function(args)
    local key, depth = (args or ""):match("^%s*(%S*)%s*(%S*)")
    fade(key, depth)
end, "W1.2: fade <target> [depth]: which textures ignore SetAlpha (each put back at once)")
Probe:Command("panels", function(args)
    if (args or ""):match("off") then panelsOff() else panelsOn() end
end, "W1.3: panels on|off: two test glass panels on the world map")
Probe:Command("border", function(args)
    if (args or ""):match("restore") then borderRestore() else borderFade() end
end, "W1.3: border fade|restore: the world map border's art")
Probe:Command("gradient", function(args)
    if (args or ""):match("off") then gradientOff() else gradientOn() end
end, "W1.6: gradient on|off: the four test squares A-D")
Probe:Command("meter", function() meterState("now") end, "#49: the damage meter's settings, windows and first bars")
Probe:Command("clear", function() Probe:ClearLog(); say("log cleared") end, "empty the saved log")

--------------------------------------------------------------------------------
-- Procedures: the owner's part, one step at a time (ForeverProbe GUIDE §3)
--------------------------------------------------------------------------------

local function shown(name)
    local f = frameByName(name)
    local ok, v = call(f, "IsShown")
    return ok and plain(v) == true
end

local function anyPopup()
    for _, name in ipairs(TARGETS.popup) do if shown(name) then return name end end
    return nil
end

Probe:Steps("wave1", {
    title = "Glass UI wave 1: the windows",
    { text = "Measuring what needs no window: frames, gamepad style, /gui, the addons around us.",
      auto = true, run = function() state(); return true end },
    { text = "Open your character sheet (C) on its Character tab, then press Measure.", button = "Measure",
      run = function() return tree("character"), fade("character") end,
      check = function() return shown("CharacterFrame"), "the character sheet is open" end },
    { text = "Click the Reputation tab and scroll the list a little, then press Measure.", button = "Measure",
      run = function() return tree("character", 6) end,
      check = function() return shown("ReputationFrame"), "the Reputation pane is open" end },
    { text = "Close the character sheet and talk to any vendor to open the merchant window.",
      event = "MERCHANT_SHOW" },
    { text = "With the merchant window open, press Measure.", button = "Measure",
      run = function() return tree("merchant"), fade("merchant") end,
      check = function() return shown("MerchantFrame"), "the merchant window is open" end },
    { text = "Close the merchant. Drag any grey item out of your bags onto the ground, so the 'delete' "
          .. "popup shows. Don't confirm it. Then press Measure.", button = "Measure",
      run = function() return tree("popup"), fade("popup") end,
      check = function() local p = anyPopup(); return p ~= nil, p end },
    { text = "Press Cancel on the popup (your item stays)." },
    { text = "Type /reload to save the results.", reload = true },
})

Probe:Steps("map", {
    title = "Glass UI: glass on the world map",
    { text = "Open the world map (M), not maximised, then press Measure.", button = "Measure",
      run = function() return tree("map"), fade("map") end,
      check = function() return shown("WorldMapFrame"), "the world map is open" end },
    { text = "Adds two blue test panels: one over the map in the top-left corner, one behind the "
          .. "whole window.", button = "Add panels", run = panelsOn },
    { text = "Do you see a blue glass box in the map's top-left corner?", ask = true },
    { text = "Can you see the map through that box (see-through, not solid, not black)?", ask = true },
    { text = "Fades the map's border art (not its buttons), so the panel behind the window shows where it was.",
      button = "Fade border", run = borderFade },
    { text = "Is the gold border gone, with blue glass showing in its place?", ask = true },
    { text = "Maximise the map with its button at the top right, then press Next." },
    { text = "With the map maximised, do the blue box and the blue border area still look right?", ask = true },
    { text = "Removes the test panels and puts the border back.", button = "Clean up",
      run = function() panelsOff(); return borderRestore() end },
    { text = "Type /reload to save the results.", reload = true },
})

Probe:Steps("gradient", {
    title = "Glass UI: textures with a gradient",
    { text = "Shows four white squares, A to D, above the middle of the screen. Every one was told "
          .. "SetAlpha(0), so each should be invisible.", button = "Show squares",
      run = function() local r = gradientOn(); return r.A, r.B, r.C, r.D end },
    { text = "Is square A visible? (gradient, then SetAlpha 0)", ask = true },
    { text = "Is square B visible? (SetAlpha 0, then gradient)", ask = true },
    { text = "Is square C visible? (an image texture, gradient, then SetAlpha 0)", ask = true },
    { text = "Is square D visible? (an image texture, no gradient, SetAlpha 0)", ask = true },
    { text = "Removes the squares.", button = "Remove", run = function() gradientOff(); return true end },
    { text = "Type /reload to save the results.", reload = true },
})

--------------------------------------------------------------------------------
-- Acceptance: the merchant skin (#4), on the real addon (docs/PLAN.md,
-- milestone 3: "the in-game routine for that window with taintLog 1 and
-- scriptErrors 1, a functional check, off and on again, after a /reload, in
-- combat where it applies"). The look is judged from the screenshots.
--------------------------------------------------------------------------------

local function glassUI() return rawget(_G, "GlassUI") end

-- Glass UI's switch for the merchant skin, through its own engine.
local function switch(on)
    local G = glassUI()
    if not (G and G.Engine) then return false, "Glass UI not loaded" end
    return G.Engine.SetEnabled("merchant", on)
end

-- The looks side by side on the open window (#4, after #17 found clear and
-- smoked nearly alike: the opaque backing dominates). A theme, and for clear
-- a trial backing opacity, set through Glass UI's Theme; Restore puts back
-- the player's theme and the shipped backing. Theme.Set saves each trial
-- theme, and the procedure survives a /reload, so the player's theme is
-- saved too (SkinProbeDB.themeWas) until Restore: memory would lose it.

local function themeTry(name, backing)
    local G = glassUI()
    if not (G and G.Theme) then return false, "Glass UI not loaded" end
    local T = G.Theme
    if type(SkinProbeDB) ~= "table" then return false, "no saved table" end
    local was = SkinProbeDB.themeWas
    if type(was) ~= "table" then
        was = { name = T.Name(), backing = G.Suite.BODY.clear.backing }
        SkinProbeDB.themeWas = was
    end
    G.Suite.BODY.clear.backing = backing or was.backing
    T.Set(name)
    local used = G.Suite.BODY[name].backing
    say("THEME " .. name .. " backing " .. num(used))
    return name, used
end

local function themeRestore()
    local G = glassUI()
    local was = type(SkinProbeDB) == "table" and SkinProbeDB.themeWas or nil
    if not (type(was) == "table" and G and G.Theme) then return true end
    G.Suite.BODY.clear.backing = was.backing
    G.Theme.Set(was.name)
    say("THEME restored: " .. tostring(was.name))
    SkinProbeDB.themeWas = nil
    return true
end

-- The merchant skin's switch line, and a few of its regions' alphas.
local function merchantState(label)
    local G = glassUI()
    local status = G and G.Engine and G.Engine.Status("merchant") or "Glass UI not loaded"
    local m = frameByName("MerchantFrame")
    local parts = {}
    for _, key in ipairs({ "NineSlice", "Bg", "TopTileStreaks" }) do
        local ok, a = call(m and m[key], "GetAlpha")
        parts[#parts + 1] = key .. "=" .. (ok and num(a) or "?")
    end
    local ok, a = call(frameByName("MerchantItem1SlotTexture"), "GetAlpha")
    parts[#parts + 1] = "slot1=" .. (ok and num(a) or "?")
    say("M " .. label .. ": " .. status .. "; " .. table.concat(parts, " ") .. " combat=" .. tostring(InCombatLockdown()))
    record("M." .. label, status .. "; " .. table.concat(parts, " "))
    return status, table.concat(parts, " ")
end

local function nineAlpha()
    local m = frameByName("MerchantFrame")
    local ok, a = call(m and m.NineSlice, "GetAlpha")
    return ok and plain(a) or nil
end

local function setCVar(name, value)
    local cvar = rawget(_G, "C_CVar")
    local set = cvar and cvar.SetCVar
    if not set then return false end
    local ok, r = pcall(set, name, value)
    return ok and r
end

-- The taint log on makes Blizzard's own code throw 'attempt to call a nil
-- value' at methods addons hooked (the micro menu every second, the bag bar,
-- tooltips) for as long as it's on (GlassActionBars, 70450; the porting guide,
-- "The taint log makes Blizzard's code call nil methods"). Each step that
-- turns it on says so, and each procedure turns it off at its end.
local TAINT_NOISE = "With the taint log on, Blizzard's own code throws 'attempt to call a nil value' errors (the "
    .. "micro menu every second, the bag bar, tooltips): that's the log itself, not an addon, so ignore them. "
    .. "They stop when it's off: at a /reload, or /console taintLog 0 if you stop early."

local function taintOff()
    return { text = "Turns the taint log off: Blizzard's 'nil value' errors stop with it.", auto = true,
             run = function() return setCVar("taintLog", "0") end }
end

-- The merchant revisited (#80, #48, docs/MERCHANT.md): the window floor
-- tried live, the rows' glass against Blizzard's rows, and the disc against
-- the portrait's mask. Saved as MS.<label>.
local floorWas

local function floorTry(value)
    local G = glassUI()
    if not (G and G.Theme and G.Theme.Refresh) then return false, "Glass UI not loaded" end
    if floorWas == nil then floorWas = G.Theme.WINDOW_BACKING end
    G.Theme.WINDOW_BACKING = value
    G.Theme.Refresh()
    say("MS floor " .. num(value))
    record("MS.floor tried", value)
    return true, value
end

local function floorRestore()
    local G = glassUI()
    if floorWas ~= nil and G and G.Theme then
        G.Theme.WINDOW_BACKING = floorWas
        G.Theme.Refresh()
    end
    floorWas = nil
    return true
end

local function seen(f)
    local ok, v = call(f, "IsVisible")
    return ok and plain(v) == true
end

local function centre(f)
    local ok, x, y = call(f, "GetCenter")
    x, y = ok and plain(x) or nil, ok and plain(y) or nil
    if type(x) == "number" and type(y) == "number" then return x, y end
end

-- Each shown row: our glass seen exactly when Blizzard's button is, and its
-- red mirror; the buyback slot's glass; the disc and its offset from the mask.
local function merchantRows(label)
    local G = glassUI()
    local R = G and G.Merchant and G.Merchant._test
    local rec = { rows = 0, glass = 0, red = 0, mismatch = 0 }
    if R then
        for i = 1, 12 do
            local row = frameByName("MerchantItem" .. i)
            local st = row and R.rows[row]
            if st and seen(row) then
                rec.rows = rec.rows + 1
                local glass, filled = seen(st.glass), seen(st.button)
                if glass then rec.glass = rec.glass + 1 end
                if glass ~= filled then rec.mismatch = rec.mismatch + 1 end
                if seen(st.red) then rec.red = rec.red + 1 end
            end
        end
        local bb = frameByName("MerchantBuyBackItem")
        local sb = bb and R.rows[bb]
        rec.buyback = sb ~= nil and seen(sb.glass)
        local m = frameByName("MerchantFrame")
        local disc = m and R.discs[m]
        local pc = m and rawget(m, "PortraitContainer")
        local mask = pc and (rawget(pc, "CircleMask") or rawget(pc, "portrait"))
        rec.disc = seen(disc)
        local dx, dy = centre(disc)
        local mx, my = centre(mask)
        if dx and mx then rec.offset = math.max(math.abs(dx - mx), math.abs(dy - my)) end
        local okW, w = call(disc, "GetWidth")
        rec.discWidth = okW and plain(w) or nil
    end
    say("MS " .. label .. ": rows " .. rec.rows .. ", glass " .. rec.glass .. ", red " .. rec.red .. ", mismatch "
        .. rec.mismatch .. "; buyback glass " .. tostring(rec.buyback) .. "; disc " .. tostring(rec.disc)
        .. " width " .. num(rec.discWidth) .. " off-centre " .. num(rec.offset))
    record("MS." .. label, rec)
    return rec
end

-- A check: every shown row's glass as Blizzard's button, the disc seen and
-- centred on the mask; `want` adds the buyback slot's glass and a red row.
local function rowsOn(label, want)
    return function()
        local rec = merchantRows(label)
        local bad = {}
        if rec.rows == 0 then bad[#bad + 1] = "no row read (Glass UI not loaded?)" end
        if rec.mismatch > 0 then bad[#bad + 1] = rec.mismatch .. " row(s) whose glass doesn't match the item" end
        if not rec.disc then bad[#bad + 1] = "no disc seen" end
        if not (rec.offset and rec.offset < 0.5) then bad[#bad + 1] = "the disc off the mask's centre" end
        want = want or {}
        if want.buyback ~= nil and rec.buyback ~= want.buyback then
            bad[#bad + 1] = "buyback glass " .. tostring(rec.buyback) .. ", wanted " .. tostring(want.buyback)
        end
        if want.red and rec.red == 0 then bad[#bad + 1] = "no red row seen" end
        return #bad == 0, #bad == 0 and (rec.glass .. " rows on glass, " .. rec.red .. " red") or table.concat(bad, "; ")
    end
end

Probe:Steps("merchant", {
    title = "Glass UI: the merchant skin",
    { text = "Turns on script errors and the taint log (Logs\\taint.log), and reads the skin's switch. "
          .. TAINT_NOISE,
      auto = true, run = function()
          return setCVar("scriptErrors", "1"), setCVar("taintLog", "1"), merchantState("start")
      end,
      check = function() local s = merchantState("check"); return s == "on", s end },
    { text = "Talk to any vendor.", event = "MERCHANT_SHOW" },
    { text = "The merchant window in glass. Press Next for a screenshot.", screenshot = "merchant, skinned",
      check = function() return nineAlpha() == 0, merchantState("shown") end },
    { text = "Can you read every item name and price clearly?", ask = true },
    -- MS.1: the window floor (#80), over other UI.
    { text = "MS.1: have the merchant window over RestedXP's guide window or your quest log (open it beside the "
          .. "vendor), on the clear tint. Then the window floor, one screenshot each. First 0.85 (the last pick).",
      button = "Floor 0.85", run = function() return floorTry(0.85) end, screenshot = "merchant, floor 0.85" },
    { text = "0.95.", button = "Floor 0.95", run = function() return floorTry(0.95) end,
      screenshot = "merchant, floor 0.95" },
    { text = "1: opaque, nothing behind shows (the default now).", button = "Floor 1",
      run = function() return floorTry(1) end, screenshot = "merchant, floor 1" },
    { text = "Does 1 hide what's behind and still look like glass (the tint and rim over it)? If not, say the number "
          .. "you'd keep in the Note.", ask = true },
    { text = "Puts the floor back to the default.", button = "Restore", run = floorRestore },
    -- MS.2: the rows (#80).
    { text = "MS.2: the rows. Our glass under each item, none on an empty slot, and an item you can't use or afford "
          .. "tinted red on its glass (find a vendor with one, or Skip). Press Next for a screenshot.",
      screenshot = "merchant, rows", check = rowsOn("rows", { red = true }) },
    { text = "Do the rows read well: icon, name and price on the glass, the red clear?", ask = true },
    -- MS.3: the disc (#48).
    { text = "MS.3: the portrait's disc, now Pearl clear with no dark backing, like Glass MiniMap's ring. It should "
          .. "sit round the NPC's face as a ring, centred.",
      check = rowsOn("disc"), screenshot = "merchant, disc" },
    { text = "Is the ring centred and the right width? Say what you'd change in the Note.", ask = true },
    { text = "Buy one cheap item. Did it land in your bags, and the money go?", ask = true },
    { text = "Sell an item from your bags (right-click it). Did it sell?", ask = true },
    { text = "Stay on the Merchant tab: the sold item is in the buyback slot at the bottom right (the box with the "
          .. "arrow while it's empty), on its glass. Press Next for a screenshot.", screenshot = "merchant, buyback slot",
      check = rowsOn("buyback slot", { buyback = true }) },
    { text = "Open the Buyback tab, then press Next for a screenshot (its 12 rows, and the portrait's disc).",
      screenshot = "merchant, buyback tab",
      check = function()
          local ok, why = rowsOn("buyback tab")()
          return ok and nineAlpha() == 0, why .. "; " .. tostring(merchantState("buyback"))
      end },
    { text = "Buy back the item you sold. Did it come back?", ask = true },
    { text = "Go back to the Merchant tab. If this vendor repairs and something of yours is damaged, "
          .. "repair it. Did it work? (No if you couldn't test it, and say why in the Note.)", ask = true },
    { text = "Switches the skin off, live.", button = "Skin off", screenshot = "merchant, skin off",
      run = function() return switch(false), merchantState("off") end,
      check = function()
          local rec = merchantRows("off")
          return nineAlpha() == 1 and rec.glass == 0 and not rec.disc, "the border is back, "
              .. rec.glass .. " rows on glass, disc " .. tostring(rec.disc)
      end },
    { text = "Does the window look exactly like Blizzard's own again: the grey and red plates, the slots, the "
          .. "gold portrait ring?", ask = true },
    { text = "Switches the skin on again, live.", button = "Skin on", screenshot = "merchant, skin on again",
      run = function() return switch(true), merchantState("on again") end,
      check = function() return nineAlpha() == 0, "faded again" end },
    { text = "Close the merchant window, then reload.", reload = true },
    { text = "Talk to the vendor again.", event = "MERCHANT_SHOW" },
    { text = "After the reload. Press Next for a screenshot.", screenshot = "merchant, after reload",
      check = function() return nineAlpha() == 0, merchantState("after reload") end },
    { text = "Optional, Skip if it isn't easy: close the window, get into combat next to a vendor (pull "
          .. "something), and talk to the vendor while fighting.", event = "MERCHANT_SHOW",
      check = function() return InCombatLockdown() and nineAlpha() == 0, merchantState("combat") end },
    taintOff(),
    { text = "Type /reload to save the results.", reload = true },
})

--------------------------------------------------------------------------------
-- The merchant's layout (#84, #86; docs/MERCHANT.md sections 4-5): Blizzard's
-- boxes as sections of ours, each shown while Blizzard shows what it holds.
-- Each check records Blizzard's state beside ours. Saved as ML.<label>.
--------------------------------------------------------------------------------

-- The close button (#86): our disc and X shown, Blizzard's four textures
-- faded, the X's strength and offset as our feedback set them.
local CLOSE_GETTERS = { "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }
local function closeState(label)
    local G = glassUI()
    local frame = frameByName("MerchantFrame")
    local u = G and G.Merchant and G.Merchant._test and frame and G.Merchant._test.ui[frame]
    local rec = {}
    if u and u.close then
        rec.disc, rec.x = seen(u.closeDisc), seen(u.closeFrame)
        rec.alpha, rec.hover, rec.pushed = u.closeAlpha, u.hover, u.pushed
        local most = 0
        for _, get in ipairs(CLOSE_GETTERS) do
            local ok, tex = call(u.close, get)
            local okA, a = call(ok and tex or nil, "GetAlpha")
            a = okA and plain(a) or nil
            if type(a) == "number" and a > most then most = a end
        end
        rec.blizzardArt = most
    end
    say("ML " .. label .. ": disc " .. tostring(rec.disc) .. ", X " .. tostring(rec.x) .. " at "
        .. tostring(rec.alpha) .. ", hover " .. tostring(rec.hover) .. ", pushed " .. tostring(rec.pushed)
        .. ", Blizzard's art at " .. tostring(rec.blizzardArt))
    record("ML." .. label, rec)
    return rec
end

local function closeOn(label, hover)
    return function()
        local r = closeState(label)
        local ok = r.disc == true and r.x == true and r.blizzardArt == 0 and r.hover == hover
            and r.alpha == (hover and 1 or 0.85)
        return ok, ok and "disc, X, the art faded" or ("disc " .. tostring(r.disc) .. ", X " .. tostring(r.x)
            .. ", art " .. tostring(r.blizzardArt) .. ", hover " .. tostring(r.hover) .. " at " .. tostring(r.alpha))
    end
end

local function sectionSeen(sec) return sec ~= nil and seen(sec.fill) end

-- The header smoky (on) or the floor whole (off), live.
local function headerTry(on)
    local G = glassUI()
    if not (G and G.Merchant and G.Merchant.SetHeader) then return false, "Glass UI not loaded" end
    local ok = G.Merchant.SetHeader(on)
    say("ML header " .. tostring(on) .. ": " .. tostring(ok))
    record("ML.header", on)
    return ok, on
end

local BAND = { "MerchantRepairAllButton", "MerchantRepairItemButton", "MerchantGuildBankRepairButton",
               "MerchantSellAllJunkButton" }

-- A page button's label alpha and whether the button is enabled.
local function pageState(name)
    local b = frameByName(name)
    if not b then return nil end
    local okE, on = call(b, "IsEnabled")
    local alpha
    local okR, regions = pcall(function() return { b:GetRegions() } end)
    for _, r in ipairs(okR and regions or {}) do
        local okT, t = call(r, "GetObjectType")
        if okT and plain(t) == "FontString" then
            local okA, a = call(r, "GetAlpha")
            alpha = okA and plain(a) or nil
        end
    end
    return { enabled = okE and plain(on) == true, label = alpha }
end

-- What our layout shows now, beside what Blizzard shows.
local function layoutState(label)
    local G = glassUI()
    local u = G and G.Merchant and G.Merchant._test and G.Merchant._test.ui[frameByName("MerchantFrame") or {}]
    local rec = {}
    if u then
        rec.merchantTab = seen(u.bb)
        rec.inset, rec.money, rec.currency = sectionSeen(u.inset), sectionSeen(u.money), sectionSeen(u.currency)
        rec.boxLeft, rec.boxRight = sectionSeen(u.boxLeft), sectionSeen(u.boxRight)
        rec.empty = seen(u.empty)
        local lit = {}
        for tab, light in pairs(u.tabs) do
            if seen(light) then
                local ok, n = call(tab, "GetName")
                lit[#lit + 1] = ok and plain(n) or "?"
            end
        end
        table.sort(lit)
        rec.lit = table.concat(lit, ",")
        local okN, n = pcall(GetNumBuybackItems)
        rec.buyback = okN and plain(n) or nil
        local okW, ws = call(u.frame, "GetFrameStrata")
        rec.windowStrata = okW and plain(ws) or nil
        for _, t in pairs(u.tabGlass or {}) do
            local okS, ts = call(t.glass, "GetFrameStrata")
            rec.tabStrata = okS and plain(ts) or nil
        end
    end
    -- Blizzard's side: the currency box, the band's buttons, the pages.
    rec.blizzCurrency = seen(frameByName("MerchantExtraCurrencyInset"))
    local band = {}
    rec.bandUsed = false
    for _, n in ipairs(BAND) do
        band[n] = seen(frameByName(n))
        if band[n] then rec.bandUsed = true end
    end
    rec.band = band
    local CM = rawget(_G, "C_MerchantFrame")
    if CM and CM.IsSellAllJunkEnabled then
        local okJ, j = pcall(CM.IsSellAllJunkEnabled)
        rec.junkEnabled = okJ and plain(j) or nil
    end
    rec.prev, rec.next = pageState("MerchantPrevPageButton"), pageState("MerchantNextPageButton")
    if G and G.Merchant and G.Merchant.Header then rec.header = G.Merchant.Header() end
    rec.floor = G and G.Theme and G.Theme.WINDOW_BACKING or nil
    say("ML " .. label .. ": merchant tab " .. tostring(rec.merchantTab) .. ", currency " .. tostring(rec.currency)
        .. " (Blizzard " .. tostring(rec.blizzCurrency) .. "), left box " .. tostring(rec.boxLeft) .. " (band used "
        .. tostring(rec.bandUsed) .. "), right box " .. tostring(rec.boxRight) .. ", empty " .. tostring(rec.empty)
        .. ", lit " .. tostring(rec.lit) .. ", buyback " .. tostring(rec.buyback) .. ", header "
        .. tostring(rec.header) .. ", tabs " .. tostring(rec.tabStrata) .. " under " .. tostring(rec.windowStrata))
    record("ML." .. label, rec)
    return rec
end

-- A check: each pane against what Blizzard shows ({ tab = 1 | 2, header,
-- empty }): the inset and the money always; the currency box with Blizzard's;
-- the right box on the Merchant tab; the left box there while a band button
-- shows. The tabs tucked; a page label dimmed exactly while its button is
-- disabled.
local function layoutOn(label, want)
    return function()
        local r = layoutState(label)
        local bad = {}
        local function want_(cond, why) if not cond then bad[#bad + 1] = why end end
        local tab1 = want.tab == 1
        want_(r.merchantTab == tab1, "not on the " .. (tab1 and "Merchant" or "Buyback") .. " tab")
        want_(r.lit == (tab1 and "MerchantFrameTab1" or "MerchantFrameTab2"), "tabs lit: " .. tostring(r.lit))
        if want.header ~= nil then want_(r.header == want.header, "header " .. tostring(r.header)) end
        want_(r.inset and r.money, "the inset or the money box missing")
        want_(r.currency == r.blizzCurrency, "currency box " .. tostring(r.currency) .. ", Blizzard's "
            .. tostring(r.blizzCurrency))
        want_(r.boxRight == tab1, "right box " .. tostring(r.boxRight))
        want_(r.boxLeft == (tab1 and r.bandUsed), "left box " .. tostring(r.boxLeft) .. ", band used "
            .. tostring(r.bandUsed))
        if want.empty ~= nil then want_(r.empty == want.empty, "empty state " .. tostring(r.empty)) end
        if r.tabStrata and r.windowStrata then
            want_(r.tabStrata ~= r.windowStrata, "the tabs not tucked (" .. r.tabStrata .. ")")
        end
        for _, side in ipairs({ "prev", "next" }) do
            local pg = r[side]
            if tab1 and pg and type(pg.label) == "number" then
                local dimmed = math.abs(pg.label - 0.4) < 0.02
                want_(dimmed == not pg.enabled, side .. " label " .. pg.label .. ", enabled " .. tostring(pg.enabled))
            end
        end
        return #bad == 0, #bad == 0 and "as Blizzard shows it" or table.concat(bad, "; ")
    end
end

-- Two checks as one (both must pass).
local function both(a, b)
    return function()
        local okA, whyA = a()
        local okB, whyB = b()
        return okA and okB, tostring(whyA) .. "; " .. tostring(whyB)
    end
end

-- Run 3, amended (#86, docs/MERCHANT.md section 5, "Amendment: sections
-- only"): one layout; the panes follow Blizzard's boxes; the tabs, the close
-- button, the page and repair buttons in glass. A MERCHANT_SHOW step checks
-- nothing: the event comes before Blizzard shows the window (run 3, 70450).
Probe:Steps("merchantlayout", {
    title = "Glass UI: the merchant, run 3: sections following Blizzard, tabs, close, pages, repair (#86)",
    rev = 5,
    { text = "Turns on script errors and the taint log; sets the header smoky and the window 93% opaque.",
      auto = true, run = function()
          return setCVar("scriptErrors", "1"), setCVar("taintLog", "1"), headerTry(true), floorRestore()
      end },
    -- An ordinary vendor.
    { text = "Talk to an ORDINARY vendor (no repair: a food or general goods vendor), with something behind the "
          .. "window if you can (RestedXP's guide).", event = "MERCHANT_SHOW" },
    { text = "What changed: no empty box on the left of the bottom band, no line through the money strip; the "
          .. "selected tab lighter with a thin gold edge; Prev or Next dimmed when it can't be used; the item area "
          .. "denser, the top smoky. Press Next for a screenshot.", screenshot = "run 3, ordinary vendor",
      check = layoutOn("r3 ordinary", { tab = 1, header = true }) },
    { text = "Open the Buyback tab. With nothing sold this session it says 'No items to buy back'. Press Next for "
          .. "a screenshot.", screenshot = "run 3, ordinary buyback",
      check = layoutOn("r3 ordinary buyback", { tab = 2, header = true }) },
    { text = "Sell one item, then press Next: the item on the Buyback page, no message.",
      check = layoutOn("r3 one sold", { tab = 2, empty = false }) },
    { text = "Back on the Merchant tab: the slot shows it. Press Next for a screenshot.",
      screenshot = "run 3, slot filled", check = layoutOn("r3 slot filled", { tab = 1 }) },
    { text = "Is the guide behind hard enough to read, the top smoky glass joined to the item area, and the tabs "
          .. "clear (the selected one lighter with its gold edge)? Anything off: the Note.", ask = true },
    -- The close button.
    { text = "Rest the mouse on the close button (don't click) until this step goes on by itself; a screenshot is "
          .. "taken.", screenshot = "run 3, close hover", timeout = 60,
      wait = function()
          local r = closeState("r3 close hover")
          return r.hover == true, "waiting for the mouse on the close button"
      end, check = closeOn("r3 close hover", true) },
    { text = "Move the mouse away, then press Next: the X back to its resting gold.", check = closeOn("r3 close rest", false) },
    { text = "Does the close button read as glass with a gold X, with clean round edges? Press and hold it a moment "
          .. "(then move away before releasing, so the window stays): the X dips 1 px?", ask = true },
    { text = "Now click the close button: the window closes.", event = "MERCHANT_CLOSED" },
    -- A smith.
    { text = "Talk to a SMITH (a vendor who repairs).", event = "MERCHANT_SHOW" },
    { text = "The repair buttons on the left of the band, in their box, on glass. Press Next for a screenshot.",
      screenshot = "run 3, smith",
      check = both(layoutOn("r3 smith", { tab = 1 }), closeOn("r3 close reopened", false)) },
    { text = "Open the Buyback tab, then come back to the Merchant tab. Only then press Next.",
      check = layoutOn("r3 smith tabs", { tab = 1 }) },
    { text = "If the vendor has 2 pages: press Next (the page arrow) and come back, then press Next here: the label "
          .. "of the arrow you can't use is dimmed. Skip if one page.", screenshot = "run 3, page 2",
      check = layoutOn("r3 pages", { tab = 1 }) },
    { text = "On the Merchant tab, repair one item or everything (if anything needs it; an auto-repair addon may "
          .. "have done it already), then press Next: the repair buttons as Blizzard greys them, the box still there.",
      check = layoutOn("r3 repaired", { tab = 1 }) },
    { text = "Do the repair and page buttons read well on glass (Blizzard's icons and arrows kept, no gold rims)? "
          .. "Anything off: the Note.", ask = true },
    -- A currency vendor, and back.
    { text = "Optional (Skip if none near): talk to a vendor selling for a currency (tokens, honor). Its currency "
          .. "box shows beside the money.", event = "MERCHANT_SHOW" },
    { text = "Press Next for a screenshot; then open the Buyback tab and press Next on the next step.",
      screenshot = "run 3, currency vendor", check = layoutOn("r3 currency", { tab = 1 }) },
    { text = "On the Buyback tab: the currency box as Blizzard shows it.",
      check = layoutOn("r3 currency buyback", { tab = 2 }) },
    { text = "Talk to an ordinary vendor again (no /reload).", event = "MERCHANT_SHOW" },
    { text = "The currency box gone. Press Next.", check = layoutOn("r3 ordinary again", { tab = 1 }) },
    -- Off and on, a change meanwhile.
    { text = "Switches the skin off.", button = "Skin off", run = function() return switch(false) end,
      screenshot = "run 3, skin off",
      check = function()
          local r, c = layoutState("r3 off"), closeState("r3 close off")
          local ok = not r.inset and not r.money and not r.boxLeft and not r.boxRight and not r.empty
              and r.lit == "" and not c.disc and not c.x and c.blizzardArt == 1
          return ok, ok and "nothing of ours shown, Blizzard's close art back" or "something of ours shown while off"
      end },
    { text = "Close the window and talk to a different kind of vendor (a smith if you're at an ordinary one, or the "
          .. "other way round).", event = "MERCHANT_SHOW" },
    { text = "Switches the skin on: the boxes as Blizzard shows them now.", button = "Skin on",
      run = function() return switch(true) end, screenshot = "run 3, on again",
      check = layoutOn("r3 on again", { tab = 1, header = true }) },
    { text = "Type /reload to save the results.", reload = true },
    { text = "Talk to a vendor once more.", event = "MERCHANT_SHOW" },
    { text = "Press Next.", check = layoutOn("r3 after reload", { tab = 1, header = true }) },
    taintOff(),
    { text = "Type /reload to save the results.", reload = true },
})

-- The checks of the blocks below, each in its own scope (Lua 5.1 allows 200
-- locals in the main chunk), for the tests.
local skinChecks = {}

--------------------------------------------------------------------------------
-- The bags (#88, docs/BAGS.md): each open bag window and its slots against
-- what Blizzard shows; the header band tried live; the item use path in
-- combat under the taint log; separate and combined; off and on; the cost.
-- Saved as BG.<label>.
--------------------------------------------------------------------------------

do
local BAG_WINDOWS = { "ContainerFrame1", "ContainerFrame2", "ContainerFrame3", "ContainerFrame4",
                      "ContainerFrame5", "ContainerFrame6", "ContainerFrame7", "ContainerFrameCombinedBags" }

local function bagsUI()
    local G = glassUI()
    return G and G.Bags and G.Bags._test or nil, G
end

-- Glass UI's memory, KB (UpdateAddOnMemoryUsage first).
local function glassMemory()
    local update, usage = rawget(_G, "UpdateAddOnMemoryUsage"), rawget(_G, "GetAddOnMemoryUsage")
    if type(update) ~= "function" or type(usage) ~= "function" then return nil end
    pcall(update)
    local ok, kb = pcall(usage, "GlassUI")
    return ok and plain(kb) or nil
end

-- A button's (bag, slot) as Blizzard's GetBagID reads them (ContainerFrame.lua:1845,
-- 70888): its bagID field, else its parent's ID; the slot is its own ID. Fields and
-- native getters only.
local function bagSlot(b)
    local bag = plain(b.bagID)
    if bag == nil then
        local okP, p = call(b, "GetParent")
        local okI, id = call(okP and p or nil, "GetID")
        bag = okI and plain(id) or nil
    end
    local okS, slot = call(b, "GetID")
    return bag, okS and plain(slot) or nil
end

-- Empty by the client, not by the skin's own reading (#170: a check that read the
-- skin's key passed as 0 of 0 once the key was gone): true, false, or nil unread.
local function slotEmpty(bag, slot)
    local cc = rawget(_G, "C_Container")
    if bag == nil or slot == nil or type(cc) ~= "table" or type(cc.GetContainerItemInfo) ~= "function" then
        return nil
    end
    local ok, info = pcall(cc.GetContainerItemInfo, bag, slot)
    if not ok then return nil end
    return info == nil
end

-- Free slots in the bags seen on visible buttons, the keyring left out (it shows a
-- computed part of its size, MainMenuBarBagButtons.lua:64): closed bags don't count.
local function freeIn(bags)
    local cc = rawget(_G, "C_Container")
    if type(cc) ~= "table" or type(cc.GetContainerNumFreeSlots) ~= "function" then return 0 end
    local index = rawget(_G, "Enum") and Enum.BagIndex
    local keyring = type(index) == "table" and index.Keyring or nil
    local n = 0
    for bag in pairs(bags) do
        if bag ~= keyring then
            local ok, free = pcall(cc.GetContainerNumFreeSlots, bag)
            free = ok and plain(free) or nil
            if type(free) == "number" then n = n + free end
        end
    end
    return n
end

-- An icon set from a file reads no atlas (the bag skin's empty test rests on it,
-- #170): measured on a texture of ours.
local function atlasRoundTrip()
    local f = CreateFrame("Frame")
    local t = f:CreateTexture()
    t:SetAtlas("bags-item-slot64")
    local before = plain(t:GetAtlas())
    t:SetTexture(134400)
    local after = plain(t:GetAtlas())
    f:Hide()
    record("BG.atlas", { before = before, after = after })
    local ok = before ~= nil and after == nil
    say("BG atlas: after SetAtlas " .. tostring(before) .. ", after SetTexture " .. tostring(after))
    return ok, ok and "a file texture reads no atlas" or ("after SetTexture the atlas reads " .. tostring(after))
end

-- Every open window: ours shown, Blizzard's shell faded; each shown item
-- button: our glass seen, its rim faded, an empty slot (empty by the client)
-- dimmed to 0, its greyed bag icon (the combined window's) faded, a filled
-- one shown.
local function bagsState(label)
    local B, G = bagsUI()
    local rec = { windows = 0, slots = 0, glass = 0, rimsFaded = 0, empty = 0, emptyDimmed = 0, filled = 0,
                  filledShown = 0, shellFaded = 0, headers = 0, unread = 0, ghost = 0, ghostFaded = 0, free = 0 }
    local bags = {}
    for _, name in ipairs(BAG_WINDOWS) do
        local f = frameByName(name)
        if f and seen(f) then
            rec.windows = rec.windows + 1
            rec.open = (rec.open and (rec.open .. ",") or "") .. name
            local okA, a = call(f.NineSlice, "GetAlpha")
            if okA and plain(a) == 0 then rec.shellFaded = rec.shellFaded + 1 end
            local h = B and B.wins[f]
            if h and seen(h.header) then rec.headers = rec.headers + 1 end
            for _, b in ipairs({ f:GetChildren() }) do
                if type(b.icon) == "table" and type(b.IconBorder) == "table" and seen(b) then
                    rec.slots = rec.slots + 1
                    local s = B and B.slots[b]
                    if s and seen(s.glass) then rec.glass = rec.glass + 1 end
                    local okN, rim = call(b, "GetNormalTexture")
                    local okR, ra = call(okN and rim or nil, "GetAlpha")
                    if okR and plain(ra) == 0 then rec.rimsFaded = rec.rimsFaded + 1 end
                    local okI, ia = call(b.icon, "GetAlpha")
                    ia = okI and plain(ia) or nil
                    local bag, slot = bagSlot(b)
                    local empty = slotEmpty(bag, slot)
                    if bag ~= nil and empty ~= nil then bags[bag] = true end
                    if empty == nil then
                        rec.unread = rec.unread + 1
                    elseif empty then
                        rec.empty = rec.empty + 1
                        if ia == 0 then rec.emptyDimmed = rec.emptyDimmed + 1 end
                        local okG, gs = call(b.EmptyBagIcon, "IsShown")
                        if okG and plain(gs) == true then
                            rec.ghost = rec.ghost + 1
                            local okGA, ga = call(b.EmptyBagIcon, "GetAlpha")
                            if okGA and plain(ga) == 0 then rec.ghostFaded = rec.ghostFaded + 1 end
                        end
                    else
                        rec.filled = rec.filled + 1
                        if type(ia) == "number" and ia > 0 then rec.filledShown = rec.filledShown + 1 end
                    end
                end
            end
        end
    end
    rec.free = freeIn(bags)
    rec.combined = frameByName("ContainerFrameCombinedBags") ~= nil and seen(frameByName("ContainerFrameCombinedBags"))
    rec.header = G and G.Bags and G.Bags.HeaderHeight and G.Bags.HeaderHeight() or nil
    rec.memoryKB = glassMemory()
    local framerate = rawget(_G, "GetFramerate")
    local okF, fps = pcall(framerate)
    rec.fps = okF and plain(fps) or nil
    rec.blocked = type(SkinProbeDB) == "table" and SkinProbeDB.suiteBlocked or 0
    say("BG " .. label .. ": " .. rec.windows .. " windows (" .. tostring(rec.open) .. "), " .. rec.slots
        .. " slots, glass " .. rec.glass .. ", rims faded " .. rec.rimsFaded .. ", empty " .. rec.empty
        .. " (dimmed " .. rec.emptyDimmed .. "), filled " .. rec.filled .. " (shown " .. rec.filledShown
        .. "), bag icons " .. rec.ghost .. " (faded " .. rec.ghostFaded .. "), free " .. rec.free .. ", unread "
        .. rec.unread .. ", memory " .. tostring(rec.memoryKB) .. " KB, fps " .. tostring(rec.fps) .. ", blocked "
        .. rec.blocked)
    record("BG." .. label, rec)
    return rec
end

-- A check: at least `want.windows` open; every open window and slot as above;
-- `want.combined` if given; free slots in the bags shown but no empty slot
-- found is a FAIL (the check would pass on nothing); nothing blocked. What the
-- step couldn't exercise (no empty slot, no bag icon, unread slots) is said, not
-- failed.
local function bagsOn(label, want)
    return function()
        local r = bagsState(label)
        local bad, notes = {}, {}
        local function want_(cond, why) if not cond then bad[#bad + 1] = why end end
        want_(not (r.free > 0 and r.empty == 0), r.free .. " free slots but no empty slot found")
        want_(r.ghostFaded == r.ghost, "bag icon faded on " .. r.ghostFaded .. " of " .. r.ghost)
        if r.empty == 0 then notes[#notes + 1] = "empty slots not exercised" end
        if want.combined and r.ghost == 0 then notes[#notes + 1] = "the bag icon not exercised (no empty slot)" end
        if r.unread > 0 then notes[#notes + 1] = r.unread .. " slots unread" end
        want_(r.windows >= (want.windows or 1), r.windows .. " windows open")
        if want.combined ~= nil then want_(r.combined == want.combined, "combined " .. tostring(r.combined)) end
        want_(r.shellFaded == r.windows, "shell faded on " .. r.shellFaded .. " of " .. r.windows)
        want_(r.headers == r.windows, "header on " .. r.headers .. " of " .. r.windows)
        want_(r.slots > 0 and r.glass == r.slots, "glass on " .. r.glass .. " of " .. r.slots .. " slots")
        want_(r.rimsFaded == r.slots, "rims faded on " .. r.rimsFaded .. " of " .. r.slots)
        want_(r.emptyDimmed == r.empty, "empty dimmed " .. r.emptyDimmed .. " of " .. r.empty)
        want_(r.filledShown == r.filled, "filled shown " .. r.filledShown .. " of " .. r.filled)
        want_(r.blocked == 0, r.blocked .. " blocked")
        local note = #notes > 0 and (" (" .. table.concat(notes, "; ") .. ")") or ""
        return #bad == 0, (#bad == 0 and "as Blizzard shows them" or table.concat(bad, "; ")) .. note
    end
end

local function bagsSwitch(on)
    local G = glassUI()
    if not (G and G.Engine) then return false, "Glass UI not loaded" end
    return G.Engine.SetEnabled("bags", on)
end

local function headerTryBags(n)
    local G = glassUI()
    if not (G and G.Bags and G.Bags.SetHeaderHeight) then return false, "Glass UI not loaded" end
    record("BG.header tried", n)
    return G.Bags.SetHeaderHeight(n), n
end

local function openWindows()
    local n = 0
    for _, name in ipairs(BAG_WINDOWS) do
        local f = frameByName(name)
        if f and seen(f) then n = n + 1 end
    end
    return n
end

Probe:Steps("bags", {
    title = "Glass UI: the bags in glass (#88)",
    { text = "Turns on script errors and the taint log, and counts blocked actions from now.", auto = true,
      run = function()
          if type(SkinProbeDB) == "table" then SkinProbeDB.suiteBlocked = 0 end
          record("BG.memory before", glassMemory())
          return setCVar("scriptErrors", "1"), setCVar("taintLog", "1")
      end },
    { text = "Checks that an icon set from a file reads no atlas (the empty-slot test rests on it).", auto = true,
      run = function() return true end, check = atlasRoundTrip },
    -- Separate bags.
    { text = "Close every bag. If your bags open as one 'Combined Backpack' window, click its portrait (top left) "
          .. "and untick the combine option first. Then open ALL your bags (Shift+B): this step goes on by itself.",
      timeout = 120, wait = function() return openWindows() >= 2, openWindows() .. " windows open" end },
    { text = "Press Next for a screenshot of the open bags.", screenshot = "bags, separate",
      check = bagsOn("separate", { windows = 2, combined = false }) },
    { text = "Do they read as the merchant's window does: dark glass, a smoky title band, the gold X on a glass "
          .. "disc, each slot a glass well, empty ones plain? Anything off: the Note.", ask = true },
    -- The header band, tried live.
    { text = "The title band, narrower.", button = "Band 20", run = function() return headerTryBags(20) end,
      screenshot = "bags, band 20" },
    { text = "Wider (down to the search row on the backpack).", button = "Band 34",
      run = function() return headerTryBags(34) end, screenshot = "bags, band 34" },
    { text = "The default.", button = "Band 26", run = function() return headerTryBags(26) end,
      screenshot = "bags, band 26" },
    { text = "Which band reads best: 20, 26 or 34? Press Yes and write the number in the Note.", ask = true },
    -- Items moving.
    { text = "Type something in the backpack's search box (Blizzard dims what doesn't match), then press Next.",
      screenshot = "bags, search", check = bagsOn("search", { windows = 1 }) },
    { text = "Clear the search. Drag an item into an empty slot (one slot empties, another fills), then press "
          .. "Next.", check = bagsOn("moved", { windows = 1 }) },
    { text = "Click the sort button (the broom, next to the search box), wait for the bags to settle, then press "
          .. "Next.", check = bagsOn("sorted", { windows = 1 }) },
    -- The use path in combat.
    { text = "Close the bags. Get into combat (a mob or a training dummy), then open the backpack IN combat and "
          .. "use an item from it (a potion, a bandage, a quest item). Press Next while still in combat if you can.",
      screenshot = "bags, combat", check = bagsOn("combat", { windows = 1 }) },
    { text = "Did the item work, with no 'blocked' or 'interface action failed' message?", ask = true },
    -- Combined.
    { text = "Out of combat: click the backpack's portrait and tick the combine option: one window. This step goes "
          .. "on by itself.", timeout = 120,
      wait = function()
          local c = frameByName("ContainerFrameCombinedBags")
          return c ~= nil and seen(c), "waiting for the combined window"
      end },
    { text = "Press Next for a screenshot.", screenshot = "bags, combined",
      check = bagsOn("combined", { windows = 1, combined = true }) },
    { text = "The combined window as glass too, its empty slots plain glass with no greyed bag icon? Back to separate bags afterwards if you prefer them (the portrait's "
          .. "menu).", ask = true },
    -- Off and on.
    { text = "Open your bags. Switches the bags skin off: Blizzard's look.", button = "Skin off",
      run = function() return bagsSwitch(false) end, screenshot = "bags, skin off",
      check = function()
          local r = bagsState("off")
          local ok = r.windows >= 1 and r.glass == 0 and r.shellFaded == 0 and r.rimsFaded == 0 and r.emptyDimmed == 0
              and r.ghostFaded == 0
          return ok, ok and "Blizzard's look, nothing of ours" or "something of ours while off"
      end },
    { text = "Move an item (a slot empties), then switch the skin on.", button = "Skin on",
      run = function() return bagsSwitch(true) end, screenshot = "bags, on again",
      check = bagsOn("on again", { windows = 1 }) },
    { text = "Type /reload.", reload = true },
    { text = "Open your bags (this step goes on by itself).", timeout = 120,
      wait = function() return openWindows() >= 1, openWindows() .. " windows open" end },
    { text = "Press Next.", check = bagsOn("after reload", { windows = 1 }) },
    taintOff(),
    { text = "Type /reload to save the results.", reload = true },
})

skinChecks.bagsState, skinChecks.bagsOn, skinChecks.atlasRoundTrip = bagsState, bagsOn, atlasRoundTrip
end

--------------------------------------------------------------------------------
-- The game menu (#90, docs/GAME-MENU.md): the menu and its buttons against
-- what Blizzard shows, the paths through the taint-sensitive Esc chain under
-- the taint log (its first opening in combat, Settings and back, Esc while
-- casting, Log Out and Exit cancelled), the menu's size held, off and on.
-- Saved as GM.<label>.
--------------------------------------------------------------------------------

do
local function gmState(label)
    local G = glassUI()
    local T = G and G.GameMenu and G.GameMenu._test
    local m = frameByName("GameMenuFrame")
    local rec = { buttons = 0, glass = 0, slicesFaded = 0, glowTinted = 0 }
    rec.shown = m ~= nil and seen(m)
    local okC, c = pcall(InCombatLockdown)
    rec.combat = okC and plain(c) == true
    if m then
        local okW, w = call(m, "GetWidth")
        local okH, h = call(m, "GetHeight")
        rec.width, rec.height = okW and plain(w) or nil, okH and plain(h) or nil
        local okB, ba = call(m.Border, "GetAlpha")
        rec.border = okB and plain(ba) or nil
        local okA, ha = call(m.Header and m.Header.CenterBG, "GetAlpha")
        rec.headerArt = okA and plain(ha) or nil
        rec.headerGlass = T and T.menus[m] and seen(T.menus[m].header) or false
        for _, b in ipairs({ m:GetChildren() }) do
            if type(b.Left) == "table" and type(b.Right) == "table" and type(b.Center) == "table" and seen(b) then
                rec.buttons = rec.buttons + 1
                local s = T and T.buttons[b]
                if s and seen(s.glass) then rec.glass = rec.glass + 1 end
                local okL, la = call(b.Left, "GetAlpha")
                local okR, ra = call(b.Center, "GetAlpha")
                if okL and okR and plain(la) == 0 and plain(ra) == 0 then rec.slicesFaded = rec.slicesFaded + 1 end
                local okG, hl = call(b, "GetHighlightTexture")
                local okD, desat = call(okG and hl or nil, "IsDesaturated")
                if okD and plain(desat) == true then rec.glowTinted = rec.glowTinted + 1 end
            end
        end
    end
    rec.blocked = type(SkinProbeDB) == "table" and SkinProbeDB.suiteBlocked or 0
    say("GM " .. label .. ": shown " .. tostring(rec.shown) .. ", combat " .. tostring(rec.combat) .. ", "
        .. rec.buttons .. " buttons, glass " .. rec.glass .. ", faded " .. rec.slicesFaded .. ", glow "
        .. rec.glowTinted .. ", size " .. tostring(rec.width) .. " x " .. tostring(rec.height) .. ", blocked "
        .. rec.blocked)
    record("GM." .. label, rec)
    return rec
end

-- A check: the menu shown, every button on glass with its slices faded and
-- its glow tinted, the border and header art faded, the header's glass; the
-- size the first check saw (SkinProbeDB.gmSize); nothing blocked.
local function gmOn(label, want)
    want = want or {}
    return function()
        local r = gmState(label)
        local bad = {}
        local function want_(cond, why) if not cond then bad[#bad + 1] = why end end
        want_(r.shown, "the menu not shown")
        if want.combat ~= nil then want_(r.combat == want.combat, "combat " .. tostring(r.combat)) end
        want_(r.buttons > 0 and r.glass == r.buttons, "glass on " .. r.glass .. " of " .. r.buttons .. " buttons")
        want_(r.slicesFaded == r.buttons, "slices faded on " .. r.slicesFaded .. " of " .. r.buttons)
        want_(r.glowTinted == r.buttons, "glow tinted on " .. r.glowTinted .. " of " .. r.buttons)
        want_(r.border == 0 and r.headerArt == 0, "border " .. tostring(r.border) .. ", header art " .. tostring(r.headerArt))
        want_(r.headerGlass, "no title tab glass")
        want_(r.blocked == 0, r.blocked .. " blocked")
        if type(SkinProbeDB) == "table" and r.width and r.height then
            local first = SkinProbeDB.gmSize
            if not first then
                SkinProbeDB.gmSize = { r.width, r.height }
            else
                want_(math.abs(first[1] - r.width) < 0.5 and math.abs(first[2] - r.height) < 0.5,
                    "size " .. r.width .. " x " .. r.height .. ", first " .. first[1] .. " x " .. first[2])
            end
        end
        return #bad == 0, #bad == 0 and "as Blizzard shows it" or table.concat(bad, "; ")
    end
end

local function gmSwitch(on)
    local G = glassUI()
    if not (G and G.Engine) then return false, "Glass UI not loaded" end
    return G.Engine.SetEnabled("gamemenu", on)
end

local function menuShown()
    local m = frameByName("GameMenuFrame")
    return m ~= nil and seen(m)
end

-- Settings and back: a step's wait that accepts the menu shown with Settings
-- hidden only after it has seen Settings open itself. The menu already open
-- with Settings closed when the step starts is no return: run 1 passed all
-- three this way without a Settings visit (Codex on #91, P2). combat: the
-- visit and the return both in combat. The seen state resets once accepted,
-- and with each new attempt (attempt(), above), so a step reached again needs
-- its own visit.
local function settingsReturn(combat)
    local visited = false
    local isNew = attempt()
    return function()
        if isNew() then visited = false end
        local sp = frameByName("SettingsPanel")
        local open = sp ~= nil and seen(sp)
        local okC, c = pcall(InCombatLockdown)
        local fighting = okC and plain(c) == true
        if open and (fighting or not combat) then visited = true end
        if not visited then
            return false, (open and "Settings open, but not in combat") or "waiting for Settings to open"
        end
        if open then return false, "waiting for Settings to close" end
        if combat and not fighting then return false, "waiting for combat" end
        if not menuShown() then return false, "waiting for the menu" end
        visited = false
        return true, "back on the menu after Settings"
    end
end

Probe:Steps("gamemenu", {
    title = "Glass UI: the game menu in glass (#90)",
    rev = 2,
    { text = "Turns on script errors and the taint log, and counts blocked actions from now.", auto = true,
      run = function()
          if type(SkinProbeDB) == "table" then SkinProbeDB.suiteBlocked = 0; SkinProbeDB.gmSize = nil end
          return setCVar("scriptErrors", "1"), setCVar("taintLog", "1")
      end },
    { text = "Type /reload now, WITHOUT opening the game menu before the next step: its first opening this "
          .. "session has to happen in combat.", reload = true },
    { text = "Get into combat (a mob or a training dummy), then press Esc to open the game menu. This step goes on "
          .. "by itself once the menu is open in combat; a screenshot is taken.", timeout = 180,
      screenshot = "game menu, first opening in combat",
      wait = function()
          local okC, c = pcall(InCombatLockdown)
          local fighting = okC and plain(c) == true
          return menuShown() and fighting, fighting and "waiting for the menu" or "waiting for combat"
      end, check = gmOn("first in combat", { combat = true }) },
    { text = "Close the menu (Esc), finish the fight. Out of combat, open it again (Esc), then press Next for a "
          .. "screenshot.", screenshot = "game menu", check = gmOn("out of combat", { combat = false }) },
    { text = "Does it read as the mockup: dark glass, the title on a glass tab, each entry a glass bar, the NEW "
          .. "badge kept? Hover each button: a soft white glow (not red)? Anything off: the Note.", ask = true },
    -- Settings and back: the porting guide's trap is entering ToggleGameMenu from addon code.
    { text = "Click Options, then close Settings with its own close button (top right): you're back on the game "
          .. "menu. This step goes on by itself once it has seen Settings open and close.", timeout = 180,
      wait = settingsReturn(false), check = gmOn("settings closed") },
    { text = "Options again, and this time close Settings with Esc: back on the menu (it waits for Settings to open "
          .. "first).", timeout = 180, wait = settingsReturn(false), check = gmOn("settings esc") },
    { text = "Close the menu. Get into combat, open the menu, Options, then close Settings (its button): back on the "
          .. "menu, in combat. This step goes on by itself once it has seen Settings open and close in combat.",
      timeout = 240, wait = settingsReturn(true), check = gmOn("settings in combat", { combat = true }) },
    { text = "Close the menu. Start a spell with a cast time and press Esc while it casts: Blizzard stops the cast "
          .. "(Esc's first job), then press Esc again to open the menu. Press Next.",
      check = gmOn("esc while casting") },
    { text = "Did every step so far go without a 'blocked' or 'interface action failed' message?", ask = true },
    -- The exits, cancelled.
    { text = "Click Log Out, then Cancel on its countdown. Open the menu again. Click Exit Game, then Cancel. Open the "
          .. "menu again and press Next.", check = gmOn("exits cancelled") },
    { text = "Click Return to Game: the menu closes. This step goes on by itself.", timeout = 120,
      wait = function() return not menuShown(), "waiting for the menu to close" end },
    { text = "Open the menu, then AddOns, close it; the menu again, Edit Mode, close it; the menu again, Macros, "
          .. "close it. Open the menu and press Next: its size as at the start.", check = gmOn("after the panels") },
    -- Off and on, the menu open.
    { text = "With the menu open: switches the skin off (Blizzard's look).", button = "Skin off",
      run = function() return gmSwitch(false) end, screenshot = "game menu, skin off",
      check = function()
          local r = gmState("off")
          local ok = r.shown and r.glass == 0 and r.slicesFaded == 0 and r.glowTinted == 0 and r.border == 1
              and not r.headerGlass
          return ok, ok and "Blizzard's look, nothing of ours" or "something of ours while off"
      end },
    { text = "Close and reopen the menu, then switch the skin on.", button = "Skin on",
      run = function() return gmSwitch(true) end, screenshot = "game menu, on again", check = gmOn("on again") },
    taintOff(),
    { text = "Type /reload to save the results.", reload = true },
})

skinChecks.gmState, skinChecks.gmOn, skinChecks.settingsReturn = gmState, gmOn, settingsReturn
end

--------------------------------------------------------------------------------
-- Guild & Communities (#92, docs/GUILD.md): each pane against its section,
-- each tab's selection art against its own checked state, the roster's taint
-- (a note edited, a sort, a rank) under the taint log, IsProtected/IsForbidden
-- on the frames we parent to, GuildSpy's tabs and panel when it hands them
-- over. Saved as GD.<label>.
--------------------------------------------------------------------------------

do
local function gdState(label)
    local G = glassUI()
    local T = G and G.Guild and G.Guild._test
    local cf = frameByName("CommunitiesFrame")
    local rec = { tabs = 0, mirrored = 0, panes = 0, panesRight = 0 }
    rec.shown = cf ~= nil and seen(cf)
    local okC, c = pcall(InCombatLockdown)
    rec.combat = okC and plain(c) == true
    if cf then
        local okA, a = call(cf.NineSlice, "GetAlpha")
        rec.shell = okA and plain(a) or nil
        local h = T and T.wins[cf]
        -- Each pane shows exactly while its section does.
        local sections = { list = cf.CommunitiesList, chat = cf.Chat, roster = cf.MemberList, edit = cf.ChatEditBox }
        for key, section in pairs(sections) do
            local sec = h and h[key]
            if sec and section then
                rec.panes = rec.panes + 1
                if seen(sec.fill) == seen(section) then rec.panesRight = rec.panesRight + 1 end
            end
        end
        for tab, s in pairs(T and T.tabs or {}) do
            if seen(tab) then
                rec.tabs = rec.tabs + 1
                local okK, k = call(tab, "GetChecked")
                local lit = s.light and s.light:IsShown() == true
                if okK and (plain(k) == true) == lit then rec.mirrored = rec.mirrored + 1 end
            end
        end
        local prot = {}
        for _, f in ipairs({ cf, cf.MemberList, cf.ChatEditBox, cf.Chat, cf.CommunitiesList }) do
            local okP, pr = call(f, "IsProtected")
            local okF, fb = call(f, "IsForbidden")
            if (okP and plain(pr)) or (okF and plain(fb)) then prot[#prot + 1] = tostring(f.GetName and f:GetName() or "?") end
        end
        rec.protected = table.concat(prot, ",")
    end
    local tn = G and G.Tenants
    rec.tenantTabs, rec.tenantPanels, rec.tenantApplied = 0, 0, 0
    for _ in pairs(tn and tn.tabs or {}) do rec.tenantTabs = rec.tenantTabs + 1 end
    for _, pnl in pairs(tn and tn.panels or {}) do
        rec.tenantPanels = rec.tenantPanels + 1
        if pnl.applied then rec.tenantApplied = rec.tenantApplied + 1 end
    end
    rec.blocked = type(SkinProbeDB) == "table" and SkinProbeDB.suiteBlocked or 0
    say("GD " .. label .. ": shown " .. tostring(rec.shown) .. ", combat " .. tostring(rec.combat) .. ", panes "
        .. rec.panesRight .. "/" .. rec.panes .. ", tabs mirrored " .. rec.mirrored .. "/" .. rec.tabs
        .. ", tenants " .. rec.tenantTabs .. " tabs, " .. rec.tenantApplied .. "/" .. rec.tenantPanels
        .. " panels applied, protected '" .. tostring(rec.protected) .. "', blocked " .. rec.blocked)
    record("GD." .. label, rec)
    return rec
end

local function gdOn(label, want)
    want = want or {}
    return function()
        local r = gdState(label)
        local bad = {}
        local function want_(cond, why) if not cond then bad[#bad + 1] = why end end
        want_(r.shown, "the window not shown")
        if want.combat ~= nil then want_(r.combat == want.combat, "combat " .. tostring(r.combat)) end
        want_(r.shell == 0, "shell " .. tostring(r.shell))
        want_(r.panes > 0 and r.panesRight == r.panes, "panes right " .. r.panesRight .. " of " .. r.panes)
        -- Minimized, Blizzard hides every side tab: none to mirror (run 1).
        want_(r.mirrored == r.tabs and (r.tabs > 0 or want.minimized), "tabs mirrored " .. r.mirrored .. " of " .. r.tabs)
        want_(r.tenantApplied == r.tenantPanels, "tenant panels applied " .. r.tenantApplied .. " of " .. r.tenantPanels)
        want_(r.blocked == 0, r.blocked .. " blocked")
        return #bad == 0, #bad == 0 and "as Blizzard shows it" or table.concat(bad, "; ")
    end
end

local function gdSwitch(on)
    local G = glassUI()
    if not (G and G.Engine) then return false, "Glass UI not loaded" end
    return G.Engine.SetEnabled("guild", on)
end

local function guildShown()
    local cf = frameByName("CommunitiesFrame")
    return cf ~= nil and seen(cf)
end

Probe:Steps("guild", {
    title = "Glass UI: Guild & Communities in glass (#92)",
    rev = 3,
    { text = "Turns on script errors and the taint log, and counts blocked actions from now.", auto = true,
      run = function()
          if type(SkinProbeDB) == "table" then SkinProbeDB.suiteBlocked = 0 end
          return setCVar("scriptErrors", "1"), setCVar("taintLog", "1")
      end },
    { text = "Type /reload, then don't open the guild window before the next step: its first opening has to be in "
          .. "combat.", reload = true },
    { text = "Get into combat, then press J to open Guild & Communities. This step goes on by itself once it's open "
          .. "in combat; a screenshot is taken.", timeout = 180, screenshot = "guild, first opening in combat",
      wait = function()
          local okC, c = pcall(InCombatLockdown)
          local fighting = okC and plain(c) == true
          return guildShown() and fighting, fighting and "waiting for the window" or "waiting for combat"
      end, check = gdOn("first in combat", { combat = true }) },
    { text = "Out of combat, on the chat (the first side tab), press Next for a screenshot.",
      screenshot = "guild, chat", check = gdOn("chat", { combat = false }) },
    { text = "Does it read as the mockup: dark glass, the smoky title, the portrait's disc, recessed panes for the "
          .. "list, chat and roster, glass side tabs with the selected one rimmed in gold? Anything off: the Note.",
      ask = true },
    { text = "Click the Roster tab (the second), then press Next.", screenshot = "guild, roster", check = gdOn("roster") },
    { text = "In the roster: sort by a column (click its header), open a member's details, and edit a note (yours or "
          .. "an officer note, if you can) or change a rank if you have the rights. Press Next.",
      check = gdOn("roster actions") },
    { text = "Did all that go without a 'blocked' or 'interface action failed' message?", ask = true },
    { text = "Click the Guild Benefits tab, then Guild Info, then Preferred Play (those that show). Press Next on the "
          .. "last one.", screenshot = "guild, info", check = gdOn("info") },
    { text = "Back on the chat tab, click the minimize button (the arrows, top right): the small chat window. Press "
          .. "Next.", screenshot = "guild, minimized", check = gdOn("minimized", { minimized = true }) },
    { text = "Maximize it again. Shift-click the chat tab (it opens Social settings), close them, then press J to "
          .. "open Guild & Communities again if it closed with them. Press Next with it open: the selected look "
          .. "follows each tab's state.", check = gdOn("shift-click") },
    { text = "If GuildSpy is installed: open its tab (the spyglass under the side tabs), then its professions tab, then "
          .. "back to the chat. Press Next on the chat. Skip if GuildSpy isn't installed.",
      screenshot = "guild, guildspy", check = gdOn("guildspy") },
    { text = "With GuildSpy: do its tabs match Blizzard's, and does its panel read as part of the window? (Its own "
          .. "panel art follows once GuildSpy's side is done.)", ask = true },
    -- Off and on.
    { text = "With the window open: switches the skin off (Blizzard's look).", button = "Skin off",
      run = function() return gdSwitch(false) end, screenshot = "guild, skin off",
      check = function()
          local r = gdState("off")
          local ok = r.shown and r.shell == 1 and r.tenantApplied == 0
          return ok, ok and "Blizzard's look, tenants told" or "something of ours while off"
      end },
    { text = "Click another tab, then switch the skin on.", button = "Skin on",
      run = function() return gdSwitch(true) end, screenshot = "guild, on again", check = gdOn("on again") },
    taintOff(),
    { text = "Type /reload to save the results.", reload = true },
})

skinChecks.gdState, skinChecks.gdOn = gdState, gdOn
end

--------------------------------------------------------------------------------
-- The character window (#94, docs/CHARACTER.md): each slot's well and frame,
-- the NormalTexture fade gate (its alpha after equips, unequips, recolours),
-- the stats headers, the mode and sidebar tabs mirrored, the protected path
-- under the taint log, IsProtected/IsForbidden on the slots and our wells.
-- Saved as CH.<label>.
--------------------------------------------------------------------------------

do
local CH_SLOTS = { "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist", "Hands", "Waist",
                   "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1", "MainHand", "SecondaryHand", "Ranged" }

local function chState(label)
    local G = glassUI()
    local T = G and G.Character and G.Character._test
    local K = G and G.Kit
    local cf = frameByName("CharacterFrame")
    local rec = { slots = 0, wells = 0, framesFaded = 0, normalBack = 0, headers = 0, headersRight = 0,
                  tabs = 0, mirrored = 0, protected = 0 }
    rec.shown = cf ~= nil and seen(cf)
    local okC, c = pcall(InCombatLockdown)
    rec.combat = okC and plain(c) == true
    if cf then
        local okA, a = call(cf.NineSlice, "GetAlpha")
        rec.shell = okA and plain(a) or nil
    end
    local backs = {}
    for _, n in ipairs(CH_SLOTS) do
        local b = frameByName("Character" .. n .. "Slot")
        if b and seen(b) then
            rec.slots = rec.slots + 1
            local s = T and T.slots[b]
            if s and seen(s.glass) then rec.wells = rec.wells + 1 end
            local okF, fa = call(b.BorderFrame, "GetAlpha")
            if okF and plain(fa) == 0 then rec.framesFaded = rec.framesFaded + 1 end
            local okN, normal = call(b, "GetNormalTexture")
            local okNA, na = call(okN and normal or nil, "GetAlpha")
            if okNA and plain(na) ~= 0 then rec.normalBack = rec.normalBack + 1; backs[#backs + 1] = n end
            for _, f in ipairs({ b, s and s.glass }) do
                local okP, pr = call(f, "IsProtected")
                local okX, fb = call(f, "IsForbidden")
                if (okP and plain(pr)) or (okX and plain(fb)) then rec.protected = rec.protected + 1 end
            end
        end
    end
    rec.normalBackSlots = table.concat(backs, ",")
    local stats = frameByName("CharacterStatsPaneScrollBox")
    local target = stats and type(stats.ScrollBox) == "table" and stats.ScrollBox.ScrollTarget
    if target and seen(stats) then
        for _, row in ipairs({ target:GetChildren() }) do
            if type(row.Background) == "table" and type(row.Title) == "table" and seen(row) then
                rec.headers = rec.headers + 1
                local okB, ba = call(row.Background, "GetAlpha")
                if okB and plain(ba) == 0 and T and T.headers[row] and seen(T.headers[row].glass) then
                    rec.headersRight = rec.headersRight + 1
                end
            end
        end
    end
    for tab, st in pairs(K and K.sideTabs or {}) do
        if T and st.kit and st.kit.key == "character" and seen(tab) then
            rec.tabs = rec.tabs + 1
            local okS, on = pcall(st.selected, tab)
            if okS and (plain(on) == true) == (st.light:IsShown() == true) then rec.mirrored = rec.mirrored + 1 end
        end
    end
    -- The list panes' top headers (a Name and a StateIcon): the glass bar
    -- shown, the bronze bar (BACKGROUND) faded, the +/- desaturated (tinted).
    rec.paneHeaders, rec.paneRight = 0, 0
    for _, name in ipairs({ "ReputationFrame", "SkillsFrame", "StatisticsFrame" }) do
        local pane = frameByName(name)
        local pt = pane and seen(pane) and type(pane.ScrollBox) == "table" and pane.ScrollBox.ScrollTarget
        if pt then
            for _, row in ipairs({ pt:GetChildren() }) do
                if type(row.Name) == "table" and type(row.StateIcon) == "table" and seen(row) then
                    rec.paneHeaders = rec.paneHeaders + 1
                    local fadedBar = true
                    for _, r in ipairs({ row:GetRegions() }) do
                        local okL, l = call(r, "GetDrawLayer")
                        local okA, a = call(r, "GetAlpha")
                        if okL and plain(l) == "BACKGROUND" and not (okA and plain(a) == 0) then fadedBar = false end
                    end
                    local okD, d = call(row.StateIcon, "IsDesaturated")
                    if fadedBar and okD and plain(d) == true and T and T.headers[row] and seen(T.headers[row].glass) then
                        rec.paneRight = rec.paneRight + 1
                    end
                end
            end
        end
    end
    rec.blocked = type(SkinProbeDB) == "table" and SkinProbeDB.suiteBlocked or 0
    say("CH " .. label .. ": shown " .. tostring(rec.shown) .. ", combat " .. tostring(rec.combat) .. ", slots "
        .. rec.wells .. "/" .. rec.slots .. " wells, frames faded " .. rec.framesFaded .. ", normal back "
        .. rec.normalBack .. " (" .. rec.normalBackSlots .. "), headers " .. rec.headersRight .. "/" .. rec.headers
        .. ", tabs mirrored " .. rec.mirrored .. "/" .. rec.tabs .. ", list headers " .. rec.paneRight .. "/"
        .. rec.paneHeaders .. ", protected " .. rec.protected .. ", blocked "
        .. rec.blocked)
    record("CH." .. label, rec)
    return rec
end

-- want.paperdoll: the slots, the headers and the NormalTexture gate are read
-- (another pane hides them).
local function chOn(label, want)
    want = want or {}
    return function()
        local r = chState(label)
        local bad = {}
        local function want_(cond, why) if not cond then bad[#bad + 1] = why end end
        want_(r.shown, "the window not shown")
        if want.combat ~= nil then want_(r.combat == want.combat, "combat " .. tostring(r.combat)) end
        want_(r.shell == 0, "shell " .. tostring(r.shell))
        want_(r.mirrored == r.tabs and r.tabs > 0, "tabs mirrored " .. r.mirrored .. " of " .. r.tabs)
        if want.paperdoll then
            want_(r.slots > 0 and r.wells == r.slots, "wells " .. r.wells .. " of " .. r.slots)
            want_(r.framesFaded == r.slots, "slot frames faded " .. r.framesFaded .. " of " .. r.slots)
            want_(r.normalBack == 0, "NormalTexture back on " .. r.normalBack .. " (" .. r.normalBackSlots .. ")")
            want_(r.headersRight == r.headers, "headers " .. r.headersRight .. " of " .. r.headers)
        end
        want_(r.paneRight == r.paneHeaders, "list headers " .. r.paneRight .. " of " .. r.paneHeaders)
        if want.lists then want_(r.paneHeaders > 0, "no list header shown") end
        want_(r.blocked == 0, r.blocked .. " blocked")
        return #bad == 0, #bad == 0 and "as Blizzard shows it" or table.concat(bad, "; ")
    end
end

local function chSwitch(on)
    local G = glassUI()
    if not (G and G.Engine) then return false, "Glass UI not loaded" end
    return G.Engine.SetEnabled("character", on)
end

local function charShown()
    local cf = frameByName("CharacterFrame")
    return cf ~= nil and seen(cf)
end

Probe:Steps("character", {
    title = "Glass UI: the character window in glass (#94)",
    rev = 2,
    { text = "Turns on script errors and the taint log, and counts blocked actions from now.", auto = true,
      run = function()
          if type(SkinProbeDB) == "table" then SkinProbeDB.suiteBlocked = 0 end
          return setCVar("scriptErrors", "1"), setCVar("taintLog", "1")
      end },
    { text = "Type /reload, then don't open the character window before the next step: its first opening has to "
          .. "be in combat.", reload = true },
    { text = "Get into combat, then press C. This step goes on by itself once the window is open in combat; a "
          .. "screenshot is taken.", timeout = 180, screenshot = "character, first opening in combat",
      wait = function()
          local okC, c = pcall(InCombatLockdown)
          local fighting = okC and plain(c) == true
          return charShown() and fighting, fighting and "waiting for the window" or "waiting for combat"
      end, check = chOn("first in combat", { combat = true, paperdoll = true }) },
    { text = "Still in combat if you can, use an item from a slot (a trinket, or a quest item worn), then press "
          .. "Next.", check = chOn("used in combat", { paperdoll = true }) },
    { text = "Out of combat, press Next for a screenshot of the paper doll.", screenshot = "character",
      check = chOn("paper doll", { combat = false, paperdoll = true }) },
    { text = "Does it read as the mockup: dark glass, the smoky title, the portrait's disc, the slots as glass wells "
          .. "round the model, the stats in a recessed pane with glass headers, the side tabs on glass with the "
          .. "selected one rimmed in gold? Anything off: the Note.", ask = true },
    -- The slots and the NormalTexture gate.
    { text = "Unequip an item (drag it to your bags), equip it again, and swap a weapon if you can. Press Next.",
      check = chOn("equips", { paperdoll = true }) },
    { text = "Hold Alt over a slot (the equipment flyout), and Shift-click an item (its link in chat). Press Next.",
      check = chOn("flyout", { paperdoll = true }) },
    { text = "Drag the model to turn it, then use its zoom, rotate and reset buttons. Press Next.",
      check = chOn("model", { paperdoll = true }) },
    { text = "Scroll the stats down and up (if they scroll). Press Next.", check = chOn("stats", { paperdoll = true }) },
    { text = "Did everything so far work, with no 'blocked' or 'interface action failed' message?", ask = true },
    -- The tabs and the other panes.
    { text = "Click each tab at the top of the right pane (stats, equipment manager, titles), then back to the stats. "
          .. "Press Next.", check = chOn("sidebar", { paperdoll = true }) },
    { text = "Click the Reputation side tab (on the right). Press Next.", screenshot = "character, reputation",
      check = chOn("reputation") },
    { text = "The Skills tab, then the PvP tab. Press Next on the PvP tab.", screenshot = "character, pvp",
      check = chOn("pvp") },
    { text = "The Currency tab. If a warband currency transfer is available, open its log and its transfer, then "
          .. "close them. Press Next.", screenshot = "character, currency", check = chOn("currency") },
    { text = "The Statistics tab. Press Next.", screenshot = "character, statistics", check = chOn("statistics") },
    { text = "Back to the character tab. Collapse the right pane (the arrow), close the window, open it again (C), "
          .. "then expand the pane. Press Next.", screenshot = "character, collapsed and back",
      check = chOn("collapse", { paperdoll = true }) },
    { text = "Optional (Skip if no pet): the pet tab at the top of the right pane, then back. Press Next.",
      check = chOn("pet") },
    -- Off and on.
    { text = "With the window open: switches the skin off (Blizzard's look).", button = "Skin off",
      run = function() return chSwitch(false) end, screenshot = "character, skin off",
      check = function()
          local r = chState("off")
          local ok = r.shown and r.shell == 1 and r.wells == 0 and r.framesFaded == 0
          return ok, ok and "Blizzard's look, nothing of ours" or "something of ours while off"
      end },
    { text = "Click another side tab, then the Character tab again (the paper doll: this check reads the slots), "
          .. "then switch the skin on.", button = "Skin on",
      run = function() return chSwitch(true) end, screenshot = "character, on again",
      check = chOn("on again", { paperdoll = true }) },
    taintOff(),
    { text = "Type /reload to save the results.", reload = true },
})

-- The list panes' headers in the tracker's look (the owner, run 1).
Probe:Steps("characterlists", {
    title = "Glass UI: the character window's list headers (#94)",
    rev = 2,
    { text = "Counts blocked actions from now, with the taint log on.", auto = true,
      run = function()
          if type(SkinProbeDB) == "table" then SkinProbeDB.suiteBlocked = 0 end
          return setCVar("scriptErrors", "1"), setCVar("taintLog", "1")
      end },
    { text = "Press C, then the Reputation tab. This step goes on by itself once the pane is open.", timeout = 180,
      screenshot = "character lists, reputation",
      wait = function()
          local rep = frameByName("ReputationFrame")
          return rep ~= nil and seen(rep), "waiting for the Reputation pane"
      end, check = chOn("lists reputation", { lists = true }) },
    { text = "Collapse a header (click it) and expand it again; hover over one. Press Next.",
      check = chOn("lists collapse", { lists = true }) },
    { text = "The Skills tab. Press Next.", screenshot = "character lists, skills",
      check = chOn("lists skills", { lists = true }) },
    { text = "The Statistics tab: expand a category and one of its sub-categories (the small square), scroll down. "
          .. "Press Next.", screenshot = "character lists, statistics", check = chOn("lists statistics", { lists = true }) },
    { text = "Do the headers read like the quest tracker's: a glass bar, the name and the +/- in the accent, no bronze? "
          .. "Anything off: the Note.", ask = true },
    { text = "Still on Statistics: switches the skin off (Blizzard's bronze headers).", button = "Skin off",
      run = function() return chSwitch(false) end,
      check = function()
          local r = chState("lists off")
          local ok = r.shown and r.paneHeaders > 0 and r.paneRight == 0
          return ok, ok and "Blizzard's headers" or ("list headers ours " .. r.paneRight .. " of " .. r.paneHeaders)
      end },
    { text = "Switches the skin on again.", button = "Skin on", run = function() return chSwitch(true) end,
      screenshot = "character lists, on again", check = chOn("lists on again", { lists = true }) },
    taintOff(),
    { text = "Type /reload to save the results.", reload = true },
})

skinChecks.chState, skinChecks.chOn = chState, chOn
end

--------------------------------------------------------------------------------
-- The world map and quest log in glass (#99, docs/MAP.md): styled a frame
-- after the show and after each hooked call; the shell, the disc following
-- the book's texture, the glyph buttons, the crumbs (the overflow kept), the
-- quest log's art, pills and zone headers; the hooks' methods present on
-- 70450; IsProtected on ours; blocked and forbidden actions. Saved as
-- MP.<label>.
--------------------------------------------------------------------------------

do
local function mpState(label)
    local G = glassUI()
    local T = G and G.Map and G.Map._test
    local wm = frameByName("WorldMapFrame")
    local rec = { crumbs = 0, crumbsFaded = 0, headers = 0, headersRight = 0, glyphs = 0, glyphsShown = 0,
                  protected = 0 }
    rec.shown = wm ~= nil and seen(wm)
    local okC, c = pcall(InCombatLockdown)
    rec.combat = okC and plain(c) == true
    local h = T and wm and T.wins[wm]
    rec.installed = h ~= nil
    local bf = wm and type(wm.BorderFrame) == "table" and wm.BorderFrame
    if bf then
        local okA, a = call(bf.NineSlice, "GetAlpha")
        rec.shell = okA and plain(a) or nil
        local pc = type(bf.PortraitContainer) == "table" and bf.PortraitContainer
        local okP, ps = call(pc and pc.portrait, "IsShown")
        rec.portrait = okP and plain(ps) == true
        local okT, title = call(bf.TitleContainer and bf.TitleContainer.TitleText, "GetText")
        rec.title = okT and plain(title) or nil
        local mm = type(bf.MaximizeMinimizeFrame) == "table" and bf.MaximizeMinimizeFrame
        rec.maximized = mm and seen(mm.MinimizeButton) or false
        for _, b in ipairs(mm and { mm.MaximizeButton, mm.MinimizeButton } or {}) do
            if seen(b) then
                rec.glyphs = rec.glyphs + 1
                local st = h and h.glyphs and h.glyphs[b]
                if st and seen(st.frame) then rec.glyphsShown = rec.glyphsShown + 1 end
            end
        end
    end
    rec.disc = h and h.disc and h.disc:IsShown() or false
    local nav = wm and type(wm.NavBar) == "table" and wm.NavBar
    if nav then
        local list = { nav.homeButton }
        for _, b in ipairs(type(nav.navList) == "table" and nav.navList or {}) do list[#list + 1] = b end
        local done = {}
        for _, b in ipairs(list) do
            if type(b) == "table" and not done[b] and seen(b) then
                done[b] = true
                rec.crumbs = rec.crumbs + 1
                local okN, n = call(b, "GetNormalTexture")
                local okA, a = call(okN and n or nil, "GetAlpha")
                if okA and plain(a) == 0 then rec.crumbsFaded = rec.crumbsFaded + 1 end
            end
        end
        local ob = nav.overflowButton
        rec.overflowShown = seen(ob)
        local okN, n = call(ob, "GetNormalTexture")
        local okA, a = call(okN and n or nil, "GetAlpha")
        rec.overflowAlpha = okA and plain(a) or nil
        rec.navRefresh = type(rawget(nav, "Refresh")) == "function"   -- a mixin method: copied onto the frame
    end
    local qsf = frameByName("QuestScrollFrame")
    rec.updateBackground = qsf ~= nil and type(rawget(qsf, "UpdateBackground")) == "function"
    rec.log = qsf ~= nil and seen(qsf)
    if rec.log then
        local okB, b = call(qsf.Background, "GetAlpha")
        rec.logBg = okB and plain(b) or nil
        local sh = type(qsf.BorderFrame) == "table" and qsf.BorderFrame.Shadow
        local okS, atlas = call(sh, "GetAtlas")
        local okX, tex = call(sh, "GetTexture")
        rec.shadowBlank = (not okS or plain(atlas) == nil) and (not okX or plain(tex) == nil)
        local contents = type(qsf.Contents) == "table" and qsf.Contents
        for _, row in ipairs(contents and { contents:GetChildren() } or {}) do
            if T and T.isHeader(row) and seen(row) then
                rec.headers = rec.headers + 1
                local okN, n = call(row, "GetNormalTexture")
                local okA, a = call(okN and n or nil, "GetAlpha")
                local okD, d = call(row.CollapseButton.Icon, "IsDesaturated")
                local st = T.headers[row]
                if okA and plain(a) == 0 and okD and plain(d) == true and st and seen(st.glass) then
                    rec.headersRight = rec.headersRight + 1
                end
            end
        end
    end
    for _, f in ipairs(h and { h.disc, h.navHost, h.logHost } or {}) do
        local okP, pr = call(f, "IsProtected")
        if okP and plain(pr) then rec.protected = rec.protected + 1 end
    end
    rec.blocked = type(SkinProbeDB) == "table" and SkinProbeDB.suiteBlocked or 0
    say("MP " .. label .. ": shown " .. tostring(rec.shown) .. ", combat " .. tostring(rec.combat) .. ", installed "
        .. tostring(rec.installed) .. ", maximized " .. tostring(rec.maximized) .. ", shell " .. tostring(rec.shell)
        .. ", disc " .. tostring(rec.disc) .. "/portrait " .. tostring(rec.portrait) .. ", glyphs " .. rec.glyphsShown
        .. "/" .. rec.glyphs .. ", crumbs " .. rec.crumbsFaded .. "/" .. rec.crumbs .. ", overflow "
        .. tostring(rec.overflowShown) .. " " .. tostring(rec.overflowAlpha) .. ", headers " .. rec.headersRight .. "/"
        .. rec.headers .. ", log bg " .. tostring(rec.logBg) .. ", shadow blank " .. tostring(rec.shadowBlank)
        .. ", hooks " .. tostring(rec.navRefresh) .. "/" .. tostring(rec.updateBackground) .. ", title "
        .. tostring(rec.title) .. ", protected " .. rec.protected .. ", blocked " .. rec.blocked)
    record("MP." .. label, rec)
    return rec
end

-- want.combat, want.max: the state expected; want.log: the quest log read.
local function mpOn(label, want)
    want = want or {}
    return function()
        local r = mpState(label)
        local bad = {}
        local function want_(cond, why) if not cond then bad[#bad + 1] = why end end
        want_(r.shown, "the map not shown")
        want_(r.installed, "not installed")
        if want.combat ~= nil then want_(r.combat == want.combat, "combat " .. tostring(r.combat)) end
        if want.max ~= nil then want_(r.maximized == want.max, "maximized " .. tostring(r.maximized)) end
        want_(r.shell == 0, "shell " .. tostring(r.shell))
        want_(r.disc == r.portrait, "disc " .. tostring(r.disc) .. " with the portrait " .. tostring(r.portrait))
        want_(r.glyphs > 0 and r.glyphsShown == r.glyphs, "glyphs " .. r.glyphsShown .. " of " .. r.glyphs)
        want_(r.crumbs > 0 and r.crumbsFaded == r.crumbs, "crumbs faded " .. r.crumbsFaded .. " of " .. r.crumbs)
        want_(not r.overflowShown or r.overflowAlpha == 1, "the overflow button faded")
        want_(r.navRefresh and r.updateBackground, "a hooked method missing on this build")
        if want.log then
            want_(r.log, "the quest log not shown")
            want_(r.logBg == 0, "log background " .. tostring(r.logBg))
            want_(r.shadowBlank, "the log's shadow back")
            want_(r.headers > 0 and r.headersRight == r.headers, "headers " .. r.headersRight .. " of " .. r.headers)
        end
        want_(r.protected == 0, r.protected .. " of ours protected")
        want_(r.blocked == 0, r.blocked .. " blocked")
        return #bad == 0, #bad == 0 and "as Blizzard shows it" or table.concat(bad, "; ")
    end
end

local function mpSwitch(on)
    local G = glassUI()
    if not (G and G.Engine) then return false, "Glass UI not loaded" end
    return G.Engine.SetEnabled("map", on)
end

-- The map shown, in combat, and the skin's deferred first pass done.
local function mapFirstOpen()
    local G = glassUI()
    local T = G and G.Map and G.Map._test
    local wm = frameByName("WorldMapFrame")
    local okC, c = pcall(InCombatLockdown)
    local fighting = okC and plain(c) == true
    local ready = wm ~= nil and seen(wm) and T and T.wins[wm] ~= nil
    return ready and fighting, fighting and "waiting for the map" or "waiting for combat"
end

Probe:Steps("mapglass", {
    title = "Glass UI: the world map and quest log in glass (#99)",
    rev = 1,
    { text = "Turns on script errors, the taint log OFF for the first pass, and counts blocked actions from now.",
      auto = true,
      run = function()
          if type(SkinProbeDB) == "table" then SkinProbeDB.suiteBlocked = 0 end
          return setCVar("scriptErrors", "1"), setCVar("taintLog", "0")
      end },
    { text = "Type /reload, then don't open the map before the next step: its first opening has to be in combat.",
      reload = true },
    { text = "Get into combat, then press M. This step goes on by itself once the map is open and styled; a "
          .. "screenshot is taken.", timeout = 180, screenshot = "map, first opening in combat",
      wait = mapFirstOpen, check = mpOn("first in combat", { combat = true, log = true }) },
    { text = "Out of combat, press Next for a screenshot of the map and the quest log.", screenshot = "map",
      check = mpOn("windowed", { combat = false, max = false, log = true }) },
    { text = "Does it read as the mockup: dark glass round the map, the smoky title band down to the breadcrumbs, "
          .. "the book's disc, the three buttons on glass with gold glyphs, the breadcrumbs as text on a dark bar, "
          .. "the quest log a recessed pane with its zone headers on glass bars, the search box and the count on "
          .. "glass? Anything off: the Note.", ask = true },
    -- Maximise and minimise.
    { text = "Maximise the map (the arrow button, top right). Press Next.", screenshot = "map, maximised",
      check = mpOn("maximised", { max = true }) },
    { text = "Minimise it again. Then, in combat if you can, maximise and minimise once more. Press Next when it's "
          .. "windowed.", check = mpOn("minimised", { max = false, log = true }) },
    { text = "Close the map. Press M, hide the quest log with its toggle (bottom right of the map), show it "
          .. "again, close the map, then press L. Press Next.", check = mpOn("quest log key", { log = true }) },
    -- The breadcrumbs.
    { text = "Go up to the world (the World crumb), into a continent, into a zone, and use a crumb's dropdown "
          .. "arrow to pick another zone. Press Next.", screenshot = "map, breadcrumbs",
      check = mpOn("map changes", { log = true }) },
    { text = "Does the bar look right: the crumbs as gold text on the dark bar, their chevrons, the selected one "
          .. "marked, and the overflow button (if any) still visible? Anything off: the Note.", ask = true },
    -- The quest log.
    { text = "In the quest log: collapse a zone header and expand it again; search for a word that finds "
          .. "nothing, then clear the search; scroll down and up. Press Next.",
      check = mpOn("log headers", { log = true }) },
    { text = "Track and untrack a quest with its checkbox, click a quest to open its details, then go back. "
          .. "Press Next.", screenshot = "map, quest log",
      check = mpOn("log details", { log = true }) },
    { text = "Is Questie's map button still there, and Leatrix's coordinates at the bottom of the map? Did "
          .. "everything work, with no 'blocked' or 'interface action failed' message?", ask = true },
    -- The same with the taint log on.
    { text = "Turns the taint log ON for a comparison pass.", auto = true,
      run = function() return setCVar("taintLog", "1") end },
    { text = "Maximise and minimise, go into another zone, collapse and expand a header. Press Next. "
          .. TAINT_NOISE .. " (NodeRadar's waypoint hook makes the arrow's one, every frame.)",
      check = mpOn("taint log on", { log = true }) },
    taintOff(),
    -- Off and on.
    { text = "Maximise the map, then: switches the skin off (Blizzard's look).", button = "Skin off",
      run = function() return mpSwitch(false) end, screenshot = "map, skin off",
      check = function()
          local r = mpState("off")
          local ok = r.shown and r.shell == 1 and not r.disc and r.glyphsShown == 0
          return ok, ok and "Blizzard's look, nothing of ours" or "something of ours while off"
      end },
    { text = "Minimise it, open a quest's details, then switch the skin on.", button = "Skin on",
      run = function() return mpSwitch(true) end,
      check = function()
          return true, "read at the next step"
      end },
    { text = "Go back to the quest list. Press Next.", screenshot = "map, on again",
      check = mpOn("on again", { max = false, log = true }) },
    -- The other first opening: from the objective tracker, in combat.
    { text = "Type /reload, then don't open the map before the next step.", reload = true },
    { text = "Get into combat, then click a quest in the objective tracker (it opens the map on that quest). This "
          .. "step goes on by itself once the map is open and styled.", timeout = 180,
      screenshot = "map, first opening from the tracker",
      wait = mapFirstOpen, check = mpOn("first from the tracker", { combat = true }) },
    { text = "Type /reload to save the results.", reload = true },
})

-- The case mapglass run 1 missed (a probe redeploy mid-run stopped it at
-- its reload), and minimising in combat (MP.minimised read it maximised).
Probe:Steps("maptracker", {
    title = "Glass UI: the map opened from the objective tracker in combat (#99)",
    rev = 1,
    { text = "Counts blocked actions from now, with the taint log off.", auto = true,
      run = function()
          if type(SkinProbeDB) == "table" then SkinProbeDB.suiteBlocked = 0 end
          return setCVar("scriptErrors", "1"), setCVar("taintLog", "0")
      end },
    { text = "Type /reload, then don't open the map before the next step.", reload = true },
    { text = "Get into combat, then click a quest in the objective tracker (it opens the map on that quest). This "
          .. "step goes on by itself once the map is open and styled.", timeout = 180,
      screenshot = "map, first opening from the tracker",
      wait = mapFirstOpen, check = mpOn("first from the tracker", { combat = true }) },
    { text = "Still in combat: maximise the map, then minimise it. Press Next once it's windowed. If minimise "
          .. "does nothing in combat, say so in the Note and press Next anyway.",
      check = mpOn("combat minimise", { max = false, log = true }) },
    { text = "Out of combat, the same: maximise, then minimise. Press Next.",
      check = mpOn("minimise", { combat = false, max = false, log = true }) },
    { text = "Type /reload to save the results.", reload = true },
})

-- The two acceptance checks left on PR #100 (Codex): minimise in combat with
-- the skin off (is staying maximised Blizzard's?), and the Leatrix yield in
-- game (its simple frame On: the skin steps aside, nothing of ours built).
local function mpYield(label, want)
    return function()
        local G = glassUI()
        local T = G and G.Map and G.Map._test
        local wm = frameByName("WorldMapFrame")
        local status = G and G.Engine and G.Engine.Status("map") or "?"
        local built = T ~= nil and wm ~= nil and T.wins[wm] ~= nil
        local rec = { status = status, built = built, shown = wm ~= nil and seen(wm) }
        say("MP " .. label .. ": status " .. tostring(status) .. ", built " .. tostring(built))
        record("MP." .. label, rec)
        if want == "yield" then
            local ok = rec.shown and not built and tostring(status):find("Leatrix_Maps", 1, true) ~= nil
            return ok, ok and "the skin yields to Leatrix Maps" or ("status " .. tostring(status) .. ", built "
                .. tostring(built))
        end
        return true, "status " .. tostring(status)
    end
end

Probe:Steps("mapchecks", {
    title = "Glass UI: the map's last two checks (#100)",
    rev = 1,
    { text = "Switches the map skin OFF for the next two steps.", auto = true,
      run = function()
          if type(SkinProbeDB) == "table" then SkinProbeDB.suiteBlocked = 0 end
          return mpSwitch(false)
      end },
    { text = "Get into combat, press M, maximise the map, then minimise it. Press Next (in combat or out).",
      check = function()
          local r = mpState("skin off, combat minimise")
          return true, "maximized " .. tostring(r.maximized) .. ", combat " .. tostring(r.combat)
      end },
    { text = "With the skin off and in combat: did the map stay maximised when you pressed minimise?", ask = true },
    { text = "Switches the map skin back ON.", auto = true, run = function() return mpSwitch(true) end },
    -- The Leatrix yield.
    { text = "Open Leatrix Maps' options (/ltm), turn ON \"Simple map frame\", then type /reload (Leatrix reads "
          .. "it at login).", reload = true },
    { text = "Press M, then press Next: the map should be Leatrix's frame, with no glass of ours.",
      screenshot = "map, Leatrix simple frame", check = mpYield("leatrix on", "yield") },
    { text = "Open /ltm again, turn \"Simple map frame\" back OFF, then type /reload.", reload = true },
    { text = "Press M, then press Next: the map in glass again.",
      check = mpOn("leatrix off again", { log = true }) },
    { text = "Type /reload to save the results.", reload = true },
})

-- Minimise in combat with the skin on (MP.6: it works with the skin off):
-- while the owner clicks, what's under the cursor over the minimise button
-- (Blizzard's button, or a frame of ours), whether the button took the
-- press (PUSHED), and whether it swapped (Minimize ran to SetMaximizedLook).
local watch = { on = false }
local watcher

local function describe(f)
    local G = glassUI()
    local T = G and G.Map and G.Map._test
    local wm = frameByName("WorldMapFrame")
    local h = T and wm and T.wins[wm]
    local mm = wm and type(wm.BorderFrame) == "table" and wm.BorderFrame.MaximizeMinimizeFrame
    if type(mm) == "table" and f == mm.MinimizeButton then return "MinimizeButton" end
    if type(mm) == "table" and f == mm.MaximizeButton then return "MaximizeButton" end
    for _, st in pairs(h and h.glyphs or {}) do
        if f == st.frame then return "our glyph" end
        if f == st.disc then return "our disc" end
    end
    local okN, n = call(f, "GetName")
    local okT, t = call(f, "GetObjectType")
    local okM, m = call(f, "IsMouseEnabled")
    return tostring(okN and plain(n) or "unnamed") .. ":" .. tostring(okT and plain(t) or "?")
        .. ((okM and plain(m)) and ":mouse" or "")
end

local function watchTick()
    if not watch.on then return end
    local wm = frameByName("WorldMapFrame")
    local mm = wm and type(wm.BorderFrame) == "table" and wm.BorderFrame.MaximizeMinimizeFrame
    local b = type(mm) == "table" and mm.MinimizeButton or nil
    if not b then return end
    local shown = seen(b)
    if watch.wasShown and not shown then watch.minimised = true end
    watch.wasShown = shown
    if not shown then return end
    local okS, st = call(b, "GetButtonState")
    if okS and plain(st) == "PUSHED" then watch.pressed = true end
    local okO, over = call(b, "IsMouseOver")
    local getFoci = rawget(_G, "GetMouseFoci")
    if okO and plain(over) and type(getFoci) == "function" then
        local ok, foci = pcall(getFoci)
        if ok and type(foci) == "table" then
            for i = 1, math.min(#foci, 3) do watch.foci[describe(foci[i])] = true end
        end
    end
end

local function startWatch()
    watch = { on = true, pressed = false, minimised = false, foci = {} }
    if not watcher then
        watcher = CreateFrame("Frame")
        watcher:SetScript("OnUpdate", watchTick)
    end
    return true
end

local function readWatch(label)
    return function()
        watch.on = false
        local foci = {}
        for k in pairs(watch.foci) do foci[#foci + 1] = k end
        table.sort(foci)
        local okC, c = pcall(InCombatLockdown)
        local rec = { pressed = watch.pressed, minimised = watch.minimised, foci = table.concat(foci, ", "),
                      combat = okC and plain(c) == true,
                      blocked = type(SkinProbeDB) == "table" and SkinProbeDB.suiteBlocked or 0 }
        say("MP " .. label .. ": pressed " .. tostring(rec.pressed) .. ", minimised " .. tostring(rec.minimised)
            .. ", under the cursor: " .. (rec.foci ~= "" and rec.foci or "nothing read") .. ", blocked " .. rec.blocked)
        record("MP." .. label, rec)
        return true, "pressed " .. tostring(rec.pressed) .. ", minimised " .. tostring(rec.minimised) .. "; "
            .. (rec.foci ~= "" and rec.foci or "nothing read")
    end
end

Probe:Steps("mapminimise", {
    title = "Glass UI: minimise in combat, measured (#100)",
    rev = 1,
    { text = "Turns the map skin on and counts blocked actions from now.", auto = true,
      run = function()
          if type(SkinProbeDB) == "table" then SkinProbeDB.suiteBlocked = 0 end
          return mpSwitch(true)
      end },
    { text = "Starts watching the minimise button.", auto = true, run = startWatch },
    { text = "Out of combat: press M, maximise the map, hover the minimise button for a second, click it once. "
          .. "Press Next.", check = readWatch("minimise watched") },
    { text = "Starts watching again.", auto = true, run = startWatch },
    { text = "Get into combat. Press M if the map is closed, maximise it, hover the minimise button for a second, "
          .. "click it once. Press Next (in combat or out).", check = readWatch("combat minimise watched") },
    { text = "In combat, after clicking minimise: did a red \"Interface action failed because of an AddOn\" "
          .. "message appear? (Yes or No; anything else: the Note.)", ask = true },
    { text = "Type /reload to save the results.", reload = true },
})

skinChecks.mpState, skinChecks.mpOn, skinChecks.mpYield = mpState, mpOn, mpYield
skinChecks.describe, skinChecks.startWatch, skinChecks.readWatch, skinChecks.watchTick = describe, startWatch, readWatch,
    watchTick
end

--------------------------------------------------------------------------------
-- The loot window and the loot roll history (#105, docs/LOOT.md): each
-- window's shell, every shown row on glass (its plate faded, and for loot its
-- slot faded and its strokes desaturated; for the history its glass at the
-- art's level - 1), opened and closed in combat, blocked and forbidden
-- actions; a fake history row the probe builds (the owner: "unless we fake
-- it"). Saved as LT.<label>.
--------------------------------------------------------------------------------

do
local opens, lastOpen = 0, 0
local lootEvents = CreateFrame("Frame")
lootEvents:RegisterEvent("LOOT_OPENED")
lootEvents:SetScript("OnEvent", function() opens = opens + 1; lastOpen = GetTime() end)

-- What shows of a shell (#109): the most visible of its pieces, each its
-- frame's alpha times its own, the frame alone when it has no piece read.
local SHELL_PIECES = {
    NineSlice = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "TopEdge", "BottomEdge",
                  "LeftEdge", "RightEdge", "Center" },
    Bg = { "BottomLeft", "BottomRight", "BottomEdge", "TopSection" },
}
local function shellShown(frame)
    local most
    for host, keys in pairs(SHELL_PIECES) do
        local h = type(frame[host]) == "table" and frame[host]
        local okH, ha = call(h, "GetAlpha")
        ha = okH and plain(ha)
        if type(ha) == "number" then
            local any = false
            for _, k in ipairs(keys) do
                local okP, pa = call(h[k], "GetAlpha")
                pa = okP and plain(pa)
                if type(pa) == "number" then
                    any = true
                    most = math.max(most or 0, ha * pa)
                end
            end
            if not any then most = math.max(most or 0, ha) end
        end
    end
    return most
end

local function ltState(label, which)
    local G = glassUI()
    local T = G and G.Loot and G.Loot._test
    local frame = frameByName(which == "history" and "GroupLootHistoryFrame" or "LootFrame")
    local rec = { rows = 0, rowsRight = 0, opens = opens }
    rec.shown = frame ~= nil and seen(frame)
    local okC, c = pcall(InCombatLockdown)
    rec.combat = okC and plain(c) == true
    rec.installed = T ~= nil and frame ~= nil and T.wins[frame] ~= nil
    if frame then
        rec.shell = shellShown(frame)
        local target = type(frame.ScrollBox) == "table" and frame.ScrollBox.ScrollTarget
        for _, row in ipairs(target and { target:GetChildren() } or {}) do
            local art = which == "history" and type(row.BackgroundArtFrame) == "table" and row.BackgroundArtFrame or nil
            local plate = art and art.NameFrame or (which ~= "history" and row.NameFrame)
            if type(plate) == "table" and seen(row) then
                rec.rows = rec.rows + 1
                local st = T and T.rows[row]
                local okP, pa = call(plate, "GetAlpha")
                local right = st ~= nil and seen(st.glass) and okP and plain(pa) == 0
                if art then
                    local okL, al = call(art, "GetFrameLevel")
                    right = right and okL and st.glass:GetFrameLevel() == plain(al) - 1
                else
                    local okN, normal = call(row.Item, "GetNormalTexture")
                    local okNA, na = call(okN and normal or nil, "GetAlpha")
                    local okD, d = call(row.HighlightNameFrame, "IsDesaturated")
                    right = right and okNA and plain(na) == 0 and okD and plain(d) == true
                end
                if right then rec.rowsRight = rec.rowsRight + 1 end
            end
        end
        if which == "history" then rec.noInfo = seen(frame.NoInfoString) end
    end
    local okM, m = pcall(GetCVar, "lootUnderMouse")
    rec.atMouse = okM and plain(m) or "?"
    rec.blocked = type(SkinProbeDB) == "table" and SkinProbeDB.suiteBlocked or 0
    say("LT " .. label .. ": at mouse " .. tostring(rec.atMouse) .. ", shown " .. tostring(rec.shown) .. ", combat " .. tostring(rec.combat) .. ", installed "
        .. tostring(rec.installed) .. ", shell " .. tostring(rec.shell) .. ", rows " .. rec.rowsRight .. "/"
        .. rec.rows .. ", opens " .. rec.opens .. ", blocked " .. rec.blocked)
    record("LT." .. label, rec)
    return rec
end

-- want.combat; want.rows: at least one row read; want.history.
local function ltOn(label, want)
    want = want or {}
    return function()
        local r = ltState(label, want.history and "history" or "loot")
        local bad = {}
        local function want_(cond, why) if not cond then bad[#bad + 1] = why end end
        want_(r.shown, "the window not shown")
        want_(r.installed, "not installed")
        if want.combat ~= nil then want_(r.combat == want.combat, "combat " .. tostring(r.combat)) end
        want_(r.shell == 0, "shell " .. tostring(r.shell))
        if want.rows then want_(r.rows > 0, "no row read") end
        want_(r.rowsRight == r.rows, "rows " .. r.rowsRight .. " of " .. r.rows)
        want_(r.blocked == 0, r.blocked .. " blocked")
        return #bad == 0, #bad == 0 and "as Blizzard shows it" or table.concat(bad, "; ")
    end
end

-- Closed without a blocked action (in combat when the owner managed it).
local function ltClosed(label)
    return function()
        local r = ltState(label, "loot")
        local ok = not r.shown and r.blocked == 0
        return ok, (r.shown and "still open" or "closed") .. ", combat " .. tostring(r.combat) .. ", " .. r.blocked
            .. " blocked"
    end
end

local function ltSwitch(key, on)
    local G = glassUI()
    if not (G and G.Engine) then return false, "Glass UI not loaded" end
    return G.Engine.SetEnabled(key, on)
end

local function lootWait(n, wantCombat)
    return function()
        local G = glassUI()
        local T = G and G.Loot and G.Loot._test
        local lf = frameByName("LootFrame")
        local okC, c = pcall(InCombatLockdown)
        local fighting = okC and plain(c) == true
        -- Read once the opening animation has ended and the skin's pass after
        -- it has run (#109: 0.1 s, then a frame): not at the first frame.
        local okP, anim = call(lf and lf.ShowAnim, "IsPlaying")
        local settled = not (okP and plain(anim)) and GetTime() - lastOpen > 0.3
        local ready = opens >= n and lf ~= nil and seen(lf) and T and T.wins[lf] ~= nil and settled
        if wantCombat and not fighting then return false, "waiting for combat" end
        return ready, "waiting for the loot window"
    end
end

-- The fake history row: the probe's, never the skin's. Blizzard's own
-- template, a cached item (Hearthstone), a winner and a roll; the list shown
-- (an empty history hides it, LootHistory.lua:461-467); the skin's style pass
-- by off and on. It taints the history: the procedure ends with a /reload.
local HEARTHSTONE = "|cffffffff|Hitem:6948::::::::1:::::::::|h[Hearthstone]|h|r"
local fake

local function fakeRow()
    local hf = frameByName("GroupLootHistoryFrame")
    if not (hf and seen(hf)) then return false, "type /loot first" end
    local sb = hf.ScrollBox
    local ok, err = pcall(function()
        sb:Show()
        hf.NoInfoString:Hide()
        local row = CreateFrame("Frame", nil, sb.ScrollTarget, "LootHistoryElementTemplate")
        row:SetPoint("TOPLEFT", sb.ScrollTarget, "TOPLEFT", 7, -7)
        row:SetPoint("RIGHT", sb.ScrollTarget, "RIGHT", -7, 0)
        row:SetHeight(58)
        local states = Enum and Enum.EncounterLootDropRollState
        local _, class = UnitClass("player")
        row:Init({ itemHyperlink = HEARTHSTONE, playerRollState = states and states.NeedMainSpec or 0,
                   winner = { playerName = UnitName("player"), playerClass = class }, rollInfos = {} })
        row:Show()
        fake = row
    end)
    if not ok then return false, tostring(err) end
    ltSwitch("loothistory", false)
    return ltSwitch("loothistory", true)
end

local function fakeCheck()
    local G = glassUI()
    local T = G and G.Loot and G.Loot._test
    local st = T and fake and T.rows[fake]
    local art = fake and fake.BackgroundArtFrame
    local okP, pa = call(art and art.NameFrame, "GetAlpha")
    local okL, al = call(art, "GetFrameLevel")
    local rec = { styled = st ~= nil, glassShown = st ~= nil and seen(st.glass), plate = okP and plain(pa) or nil,
                  level = st and st.glass:GetFrameLevel() or nil, artLevel = okL and plain(al) or nil }
    record("LT.fake row", rec)
    local ok = rec.styled and rec.glassShown and rec.plate == 0 and rec.level == (rec.artLevel or 0) - 1
    return ok, ok and ("the fake row in glass at " .. tostring(rec.level)) or ("styled " .. tostring(rec.styled)
        .. ", glass " .. tostring(rec.glassShown) .. ", plate " .. tostring(rec.plate) .. ", level "
        .. tostring(rec.level) .. "/" .. tostring(rec.artLevel))
end

Probe:Steps("lootglass", {
    title = "Glass UI: the loot window and /loot in glass (#105)",
    rev = 4,
    { text = "Turns on script errors, the taint log off, and counts blocked actions from now.", auto = true,
      run = function()
          if type(SkinProbeDB) == "table" then SkinProbeDB.suiteBlocked = 0 end
          return setCVar("scriptErrors", "1"), setCVar("taintLog", "0")
      end },
    { text = "Type /reload, then don't loot anything before the next step: its first loot has to be in combat.",
      reload = true },
    { text = "Get into combat (two mobs: kill one while the other hits you), then Shift + right-click the corpse "
          .. "(Shift stops auto-loot). This step goes on by itself once the loot window is open in combat; a "
          .. "screenshot is taken.", timeout = 300, screenshot = "loot, first in combat",
      wait = lootWait(1, true), check = ltOn("first in combat", { combat = true, rows = true }) },
    { text = "Close it, still in combat if you can: take everything, or the X, or Esc. Press Next.",
      check = ltClosed("closed in combat") },
    { text = "Loot a second corpse in combat the same way (Shift + right-click). This step goes on by itself.",
      timeout = 300, wait = lootWait(2, true), check = ltOn("second in combat", { combat = true, rows = true }) },
    { text = "Close it in combat another way than before (the X or Esc). Press Next.",
      check = ltClosed("closed in combat again") },
    -- The look.
    { text = "Out of combat, Shift-loot a corpse and press Next with the window open, for a screenshot.",
      screenshot = "loot", check = ltOn("look", { combat = false, rows = true }) },
    { text = "Does it read as the template: dark glass, the smoky band with the title, the close button on its glass "
          .. "disc, each item on a glass row with no bronze plate, the icons and names in their colours, the "
          .. "hover outline white? Anything off: the Note.", ask = true },
    { text = "Take one item by clicking it, then take the rest (money too if any). Press Next.",
      check = function() local r = ltState("taken", "loot"); return r.blocked == 0, r.blocked .. " blocked" end },
    { text = "Loot a corpse with plain right-click (auto-loot): the window flashes, its rows sliding out. Press "
          .. "Next.", check = function() local r = ltState("auto-loot", "loot"); return r.blocked == 0, r.blocked .. " blocked" end },
    -- The other positioning paths.
    { text = "For this one loot only: in Options > Controls, turn ON \"Open Loot Window at Mouse\" (it's normally "
          .. "off), Shift-loot a corpse, press Next with the window open.", check = ltOn("at mouse", { rows = true }) },
    { text = "Turn \"Open Loot Window at Mouse\" OFF again (Edit Mode can only move the window with it off). Then open Edit Mode, move the Loot Window, Save, close "
          .. "Edit Mode, Shift-loot a corpse. Press Next with the window open.", check = ltOn("edit mode saved", { rows = true }) },
    { text = "Open Edit Mode, move the Loot Window again, then Revert Changes (or close without saving), close "
          .. "Edit Mode, Shift-loot a corpse. Press Next with the window open.", check = ltOn("edit mode discarded", { rows = true }) },
    { text = "With the loot window open: switches the skin off (Blizzard's look).", button = "Skin off",
      run = function() return ltSwitch("loot", false) end, screenshot = "loot, skin off",
      check = function()
          local r = ltState("off", "loot")
          local ok = r.shown and r.shell == 1 and r.rowsRight == 0
          return ok, ok and "Blizzard's look, nothing of ours" or "something of ours while off"
      end },
    { text = "Switches the skin on again.", button = "Skin on", run = function() return ltSwitch("loot", true) end },
    { text = "Wait a second, then press Next (the window still open).", check = ltOn("on again", { rows = true }) },
    { text = "Did every loot open and close, with no 'Interface action failed' message? If a master-looted group "
          .. "loot happened, say how it went in the Note; else answer Unsure.", ask = true },
    -- /loot.
    { text = "Close the loot window and type /loot. Press Next.", screenshot = "loot rolls, empty",
      check = ltOn("history empty", { history = true }) },
    { text = "Drag the handle under the window to make it taller, then close it and type /loot again. Press Next.",
      check = ltOn("history resized", { history = true }) },
    { text = "Type /loot if the history is closed, then: builds a fake roll row in it (the probe's own, from "
          .. "Blizzard's template, a Hearthstone) and switches the skin off and on.", button = "Build the fake row",
      run = fakeRow },
    { text = "Press Next for a screenshot of the fake row.", screenshot = "loot rolls, fake row", check = fakeCheck },
    { text = "Does the fake row read right: a glass row, the Hearthstone and its name, your name as the winner, the "
          .. "roll icon? Anything off: the Note.", ask = true },
    taintOff(),
    { text = "Type /reload: it saves the results and clears the fake row.", reload = true },
})

-- #109: the loot window's NineSlice stayed at alpha 1 until the skin went
-- off and on. Right after a loot (and a frame later, once the deferred style
-- ran): the NineSlice's and Bg's alpha, Glass UI's in-memory failures,
-- IsProtected on the window and its NineSlice.
local function shellRead(label)
    return function()
        local G = glassUI()
        local lf = frameByName("LootFrame")
        local rec = {}
        local okA, a = call(lf and lf.NineSlice, "GetAlpha")
        rec.nine = okA and plain(a) or nil
        local okB, b = call(lf and lf.Bg, "GetAlpha")
        rec.bg = okB and plain(b) or nil
        local okP, p1 = call(lf, "IsProtected")
        rec.protected = okP and tostring(plain(p1)) or "?"
        local okN, p2 = call(lf and lf.NineSlice, "IsProtected")
        rec.ninePro = okN and tostring(plain(p2)) or "?"
        local fails = {}
        for k, v in pairs(G and G.failures or {}) do fails[#fails + 1] = tostring(k) .. "=" .. tostring(v) end
        table.sort(fails)
        rec.failures = table.concat(fails, " | ")
        rec.status = G and G.Engine and G.Engine.Status("loot") or "?"
        rec.shown = lf ~= nil and seen(lf)
        -- The kit's record for the NineSlice and one of its pieces: present,
        -- held at, busy, Blizzard's latest alpha.
        local faded = G and G.Kit and G.Kit._test and G.Kit._test.faded
        local function entry(r)
            local e = faded and r and faded[r]
            if not e then return "none" end
            return "to " .. tostring(e.to) .. " busy " .. tostring(e.busy) .. " blizz " .. tostring(e.alpha)
                .. " kit " .. tostring(e.kit and e.kit.key)
        end
        local okM, m = pcall(GetCVar, "lootUnderMouse")
        rec.atMouse = okM and plain(m) or "?"
        rec.nineEntry = entry(lf and lf.NineSlice)
        rec.edgeEntry = entry(lf and lf.NineSlice and lf.NineSlice.TopEdge)
        local okE, ea = call(lf and lf.NineSlice and lf.NineSlice.TopEdge, "GetAlpha")
        rec.edge = okE and plain(ea) or nil
        record("LT." .. label, rec)
        say("LT " .. label .. ": at mouse " .. tostring(rec.atMouse) .. ", edge " .. tostring(rec.edge) .. " ("
            .. rec.edgeEntry .. "), nine entry "
            .. rec.nineEntry)
        say("LT " .. label .. ": nine " .. tostring(rec.nine) .. ", bg " .. tostring(rec.bg) .. ", protected "
            .. rec.protected .. "/" .. rec.ninePro .. ", status " .. tostring(rec.status) .. ", failures: "
            .. (rec.failures ~= "" and rec.failures or "none"))
        return rec.nine == 0, "nine " .. tostring(rec.nine) .. ", bg " .. tostring(rec.bg) .. "; failures: "
            .. (rec.failures ~= "" and rec.failures or "none")
    end
end

-- The timeline (#109): from LOOT_OPENED, every frame for 0.5 s, the
-- NineSlice's, Bg's and window's alpha, the open animation playing, and the
-- skin's style passes; each change kept with its frame and time.
local timeline, tlStart, tlFrames, tlLast
local sampler = CreateFrame("Frame")
local function tlSample()
    local G = glassUI()
    local T = G and G.Loot and G.Loot._test
    local lf = frameByName("LootFrame")
    local okN, n = call(lf and lf.NineSlice, "GetAlpha")
    local okB, b = call(lf and lf.Bg, "GetAlpha")
    local okW, w = call(lf, "GetAlpha")
    local anim = lf and type(lf.ShowAnim) == "table" and lf.ShowAnim
    local okP, playing = call(anim, "IsPlaying")
    local state = string.format("nine %.2f bg %.2f win %.2f anim %s style %s fade %s",
        okN and plain(n) or -1, okB and plain(b) or -1, okW and plain(w) or -1,
        tostring(okP and plain(playing)), tostring(T and T.passes and T.passes.style),
        tostring(T and T.passes and T.passes.nineFade))
    if state ~= tlLast then
        timeline[#timeline + 1] = string.format("f%d %.3fs: %s", tlFrames, GetTime() - tlStart, state)
        tlLast = state
    end
end
sampler:SetScript("OnUpdate", function()
    if not timeline or not tlStart then return end
    tlFrames = tlFrames + 1
    tlSample()
    if GetTime() - tlStart > 0.5 then tlStart = nil end
end)
local tlEvents = CreateFrame("Frame")
tlEvents:RegisterEvent("LOOT_OPENED")
tlEvents:SetScript("OnEvent", function()
    if not timeline then return end
    tlStart, tlFrames, tlLast = GetTime(), 0, nil
    timeline[#timeline + 1] = "LOOT_OPENED"
    tlSample()
end)
local function tlBegin() timeline = {}; return true end
local function tlRead(label)
    return function()
        local list = timeline or {}
        record("LT." .. label, { timeline = table.concat(list, " ; ") })
        for _, l in ipairs(list) do say("LT " .. label .. ": " .. l) end
        timeline = nil
        return #list > 0, #list .. " changes recorded"
    end
end

Probe:Steps("loottimeline", {
    title = "Glass UI: the loot window's frame, frame by frame (#109)",
    rev = 2,
    { text = "Type /reload, then don't loot before the next step.", reload = true },
    { text = "Starts recording.", auto = true, run = tlBegin },
    { text = "Out of combat, Shift + right-click a corpse. Press Next with the loot window open.",
      check = tlRead("timeline first") },
    { text = "Starts recording again.", auto = true, run = tlBegin },
    { text = "Close it, Shift-loot another corpse. Press Next with the window open.", check = tlRead("timeline second") },
    { text = "Switches the loot skin off, then on, and starts recording again.", auto = true,
      run = function() ltSwitch("loot", false); ltSwitch("loot", true); return tlBegin() end },
    { text = "Close it, Shift-loot another corpse. Press Next with the window open.", check = tlRead("timeline after") },
    { text = "Type /reload to save the results.", reload = true },
})

-- The same kit's Fade again, through its existing records and hooks, on the
-- open, settled window: holds (the first was undone by the opening's timing)
-- or reverts again (the first records are broken; off/on makes fresh ones).
local function fadeAgain()
    local G = glassUI()
    local s = G and G.Engine and G.Engine.byKey and G.Engine.byKey.loot
    local lf = frameByName("LootFrame")
    if not (s and s.kit and lf and seen(lf)) then return false, "open a loot window first" end
    local n = 0
    for _, host in ipairs({ lf.NineSlice, lf.Bg }) do
        if type(host) == "table" then
            s.kit:Fade(host)
            n = n + 1
            for _, k in ipairs({ "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "TopEdge",
                                 "BottomEdge", "LeftEdge", "RightEdge", "Center", "BottomLeft", "BottomRight",
                                 "TopSection" }) do
                if type(host[k]) == "table" then s.kit:Fade(host[k]); n = n + 1 end
            end
        end
    end
    return true, n .. " faded again"
end

Probe:Steps("lootshell", {
    title = "Glass UI: the loot window's frame not faded (#109)",
    rev = 2,
    { text = "Set \"Open Loot Window at Mouse\" (Options > Controls) the way you want to test it: this run is read "
          .. "with it as it is. Then type /reload, and don't loot before the next step.", reload = true },
    { text = "Out of combat, Shift + right-click a corpse. Press Next with the loot window open.",
      screenshot = "loot shell, first", check = shellRead("shell first") },
    { text = "With the window still open, wait a second, then: the skin's own Fade again, through its existing "
          .. "records.", button = "Fade again", run = fadeAgain },
    { text = "Wait a second, then press Next (the window still open).", screenshot = "loot shell, faded again",
      check = shellRead("shell faded again") },
    { text = "Close it, Shift-loot another corpse, press Next with the window open.", check = shellRead("shell second") },
    { text = "Switches the loot skin off.", auto = true, run = function() return ltSwitch("loot", false) end },
    { text = "Switches it on again.", auto = true, run = function() return ltSwitch("loot", true) end },
    { text = "Press Next (the window still open).", check = shellRead("shell after off and on") },
    { text = "Close it, Shift-loot another corpse, press Next with the window open.",
      screenshot = "loot shell, after", check = shellRead("shell next loot") },
    { text = "Type /reload to save the results.", reload = true },
})

skinChecks.ltState, skinChecks.ltOn, skinChecks.ltClosed, skinChecks.fakeCheck = ltState, ltOn, ltClosed, fakeCheck
end

--------------------------------------------------------------------------------
-- The trade window (#113, docs/TRADE.md): between the owner's two accounts,
-- read on the one running it. Each check reads the shell (the most visible
-- of its pieces), the 14 wells (glass shown at the slot's level - 1, socket,
-- plate and slot frame faded), Trade and Cancel (art faded, glass shown), the
-- recipient's red (Blizzard's plate red <=> our mirror shown), the accept
-- highlights and the warning icon as Blizzard shows them, whether the slot
-- pieces and the overlay read as forbidden, blocked actions. The money input
-- is never read: it is forbidden. Saved as TD.<label>.
--------------------------------------------------------------------------------

do
local opens, lastOpen = 0, 0
local tradeEvents = CreateFrame("Frame")
tradeEvents:RegisterEvent("TRADE_SHOW")
tradeEvents:SetScript("OnEvent", function() opens = opens + 1; lastOpen = GetTime() end)

local TD_SHELL = { "TradeRecipientBG", "TradeRecipientLeftBorder", "TradeRecipientBotLeftCorner", "TradeRecipientMoneyBg" }
local TD_INSETS = { "TradePlayerItemsInset", "TradeRecipientItemsInset", "TradePlayerEnchantInset",
                    "TradeRecipientEnchantInset", "TradePlayerInputMoneyInset", "TradeRecipientMoneyInset" }
local TD_HIGHLIGHTS = { "TradeHighlightPlayer", "TradeHighlightRecipient", "TradeHighlightPlayerEnchant",
                        "TradeHighlightRecipientEnchant" }

local function alphaOf(r)
    local ok, a = call(r, "GetAlpha")
    a = ok and plain(a) or nil
    return type(a) == "number" and a or nil
end

-- Blizzard's red on a plate (0.9, 0, 0, TradeFrame.lua:180).
local function plateRed(plate)
    local ok, r, g, b = call(plate, "GetVertexColor")
    r, g, b = plain(r), plain(g), plain(b)
    return ok and type(r) == "number" and type(g) == "number" and type(b) == "number" and r > 0.4 and g < 0.1
        and b < 0.1
end

local function forbiddenOf(obj)
    local ok, f = call(obj, "IsForbidden")
    return ok and tostring(plain(f)) or "?"
end

local function tdState(label)
    local G = glassUI()
    local T = G and G.Trade and G.Trade._test
    local tf = frameByName("TradeFrame")
    local rec = { opens = opens, wells = 0, wellsRight = 0, buttonsRight = 0, red = 0, redMismatch = 0, mine = 0,
                  theirs = 0 }
    rec.shown = tf ~= nil and seen(tf)
    local okC, c = pcall(InCombatLockdown)
    rec.combat = okC and plain(c) == true
    rec.installed = T ~= nil and tf ~= nil and T.wins[tf] ~= nil
    if tf then
        local most = 0
        local function see(r) local a = alphaOf(r); if a then most = math.max(most, a) end end
        see(tf.NineSlice); see(tf.Bg); see(tf.TopTileStreaks)
        for _, n in ipairs(TD_SHELL) do see(frameByName(n)) end
        for _, n in ipairs(TD_INSETS) do
            local i = frameByName(n)
            if i then see(i.Bg); see(i.NineSlice) end
        end
        rec.shell = most
        for _, side in ipairs({ "Player", "Recipient" }) do
            for i = 1, 7 do
                local name = "Trade" .. side .. "Item" .. i
                local item, b = frameByName(name), frameByName(name .. "ItemButton")
                local plate = frameByName(name .. "NameFrame")
                local s = T and item and T.slots[item]
                rec.wells = rec.wells + 1
                local okN, normal = call(b, "GetNormalTexture")
                local okL, il = call(item, "GetFrameLevel")
                local right = s ~= nil and seen(s.glass) and okL and s.glass:GetFrameLevel() == plain(il) - 1
                    and alphaOf(item and item.SlotTexture) == 0 and alphaOf(plate) == 0
                    and alphaOf(okN and normal or nil) == 0
                if right then rec.wellsRight = rec.wellsRight + 1 end
                local okI, tex = call(b and b.icon, "GetTexture")
                if okI and plain(tex) then
                    if side == "Player" then rec.mine = rec.mine + 1 else rec.theirs = rec.theirs + 1 end
                end
                if side == "Recipient" and s and s.red then
                    local red = plateRed(plate)
                    if red then rec.red = rec.red + 1 end
                    if red ~= seen(s.red) then rec.redMismatch = rec.redMismatch + 1 end
                end
            end
        end
        for _, n in ipairs({ "TradeFrameTradeButton", "TradeFrameCancelButton" }) do
            local b = frameByName(n)
            local bg = T and b and T.buttons[b]
            if bg and seen(bg.glass) and alphaOf(b.Left) == 0 and alphaOf(b.Middle) == 0 and alphaOf(b.Right) == 0 then
                rec.buttonsRight = rec.buttonsRight + 1
            end
        end
        local hl = {}
        for _, n in ipairs(TD_HIGHLIGHTS) do
            local f = frameByName(n)
            hl[#hl + 1] = n:gsub("TradeHighlight", "") .. "=" .. tostring(f ~= nil and seen(f))
        end
        rec.highlights = table.concat(hl, " ")
        local tb = frameByName("TradeFrameTradeButton")
        rec.warning = tb ~= nil and tb.WarningIcon ~= nil and seen(tb.WarningIcon)
        rec.forbidden = "plate " .. forbiddenOf(frameByName("TradeRecipientItem1NameFrame")) .. ", socket "
            .. forbiddenOf(frameByName("TradeRecipientItem1") and frameByName("TradeRecipientItem1").SlotTexture)
            .. ", overlay " .. forbiddenOf(tf.RecipientOverlay)
    end
    rec.blocked = type(SkinProbeDB) == "table" and SkinProbeDB.suiteBlocked or 0
    say("TD " .. label .. ": shown " .. tostring(rec.shown) .. ", combat " .. tostring(rec.combat) .. ", installed "
        .. tostring(rec.installed) .. ", shell " .. tostring(rec.shell) .. ", wells " .. rec.wellsRight .. "/"
        .. rec.wells .. ", buttons " .. rec.buttonsRight .. "/2, items " .. rec.mine .. "+" .. rec.theirs
        .. ", red " .. rec.red .. " (" .. rec.redMismatch .. " off), " .. tostring(rec.highlights) .. ", warning "
        .. tostring(rec.warning) .. ", forbidden " .. tostring(rec.forbidden) .. ", opens " .. rec.opens
        .. ", blocked " .. rec.blocked)
    record("TD." .. label, rec)
    return rec
end

-- want.combat; want.red: at least one red slot of theirs; want.mine/theirs: at least that many items.
local function tdOn(label, want)
    want = want or {}
    return function()
        local r = tdState(label)
        local bad = {}
        local function want_(cond, why) if not cond then bad[#bad + 1] = why end end
        want_(r.shown, "the window not shown")
        want_(r.installed, "not installed")
        if want.combat ~= nil then want_(r.combat == want.combat, "combat " .. tostring(r.combat)) end
        want_(r.shell == 0, "shell " .. tostring(r.shell))
        want_(r.wellsRight == r.wells, "wells " .. r.wellsRight .. " of " .. r.wells)
        want_(r.buttonsRight == 2, "buttons " .. r.buttonsRight .. " of 2")
        want_(r.redMismatch == 0, r.redMismatch .. " red mirror(s) off")
        if want.red then want_(r.red > 0, "no red slot of theirs") end
        if want.mine then want_(r.mine >= want.mine, "items of yours " .. r.mine) end
        if want.theirs then want_(r.theirs >= want.theirs, "items of theirs " .. r.theirs) end
        want_(r.blocked == 0, r.blocked .. " blocked")
        return #bad == 0, #bad == 0 and "as Blizzard shows it" or table.concat(bad, "; ")
    end
end

local function tdClosed(label)
    return function()
        local r = tdState(label)
        local ok = not r.shown and r.blocked == 0
        return ok, (r.shown and "still open" or "closed") .. ", " .. r.blocked .. " blocked"
    end
end

local function tdWait(n)
    return function()
        local G = glassUI()
        local T = G and G.Trade and G.Trade._test
        local tf = frameByName("TradeFrame")
        local ready = opens >= n and tf ~= nil and seen(tf) and T and T.wins[tf] ~= nil and GetTime() - lastOpen > 0.3
        return ready, "waiting for the trade window"
    end
end

local function tdSwitch(on)
    local G = glassUI()
    if not (G and G.Engine) then return false, "Glass UI not loaded" end
    return G.Engine.SetEnabled("trade", on)
end

Probe:Steps("tradeglass", {
    title = "Glass UI: the trade window in glass (#113)",
    rev = 2,
    { text = "Turns on script errors, the taint log OFF for the first pass, and counts blocked actions from now.",
      auto = true,
      run = function()
          if type(SkinProbeDB) == "table" then SkinProbeDB.suiteBlocked = 0 end
          return setCVar("scriptErrors", "1"), setCVar("taintLog", "0")
      end },
    { text = "Log your other account's character in next to this one. Then type /reload here, and don't trade before "
          .. "the next step.", reload = true },
    { text = "From THIS character, open a trade with the other one (target it, then /trade, or right-click its "
          .. "portrait > Trade). This step goes on by itself once the window is open; a screenshot is taken.",
      timeout = 300, screenshot = "trade, first", wait = tdWait(1), check = tdOn("first") },
    { text = "Does it read as the template: dark glass, the smoky band with both names and portraits, both portraits on "
          .. "glass discs, the item columns and money rows as recessed panes, each slot a glass well, Trade and "
          .. "Cancel on glass, the close button on its disc, \"Will not be traded\" readable? Anything off: the "
          .. "Note.", ask = true },
    { text = "Press Cancel to close it. Then from the OTHER character, open a trade with this one (accept the "
          .. "request here if one shows). This step goes on by itself.", timeout = 300, wait = tdWait(2),
      check = tdOn("from the other side") },
    -- Every input route on this side.
    { text = "On this character: drag an item from your bags onto your slot 1; click another bag item, then click "
          .. "your slot 2; pick up a third and click the window's empty background (it lands in the first free "
          .. "slot); drag slot 1's item onto slot 4. Press Next.", check = tdOn("items in", { mine = 3 }) },
    { text = "Click one of your items in the window and put it back in your bags. Press Next.",
      check = tdOn("item out") },
    -- Typed only: on 70888 the bags' coins open the currency tab, not a money
    -- pickup (showCurrencyTracking, ContainerFrame.xml:202; #178).
    { text = "Type 1 copper in your money box. Press Next.", check = tdOn("money") },
    -- Their side.
    { text = "On the OTHER character: offer an item THIS character can't use (it shows red here), a stack, and some "
          .. "money. Press Next here; a screenshot is taken.", screenshot = "trade, theirs",
      check = tdOn("theirs", { red = true, theirs = 2 }) },
    { text = "Does their unusable item read red here (its icon, and a faint red on its glass well), their money "
          .. "readable? Anything off: the Note.", ask = true },
    { text = "If either character can put something in the \"Will not be traded\" slot (an enchant or an item to "
          .. "apply something to), try it now: a binding warning may show, cancel it once and accept it the second "
          .. "time. Else just press Next.", check = tdOn("enchant slot") },
    -- Accepting, cancelling, a changed offer.
    { text = "Press Trade on THIS character only (not the other yet). Press Next.", check = tdOn("accepted") },
    { text = "On the OTHER character, change its offer (add or remove an item): your acceptance resets here, and a "
          .. "warning icon shows on Trade. Press Next.", check = tdOn("offer changed") },
    { text = "Press Trade here again, then Cancel: Cancel takes your acceptance back and the window stays open. "
          .. "Press Next.", check = tdOn("acceptance cancelled") },
    { text = "Press Trade on both characters. If a confirmation dialog shows, cancel it the first time, then press "
          .. "Trade again and confirm it. The trade completes. Press Next.", check = tdClosed("completed") },
    { text = "Did a confirmation dialog show before the trade completed?", ask = true },
    -- The rest with the taint log on (rev 2, Codex on #154): the first pass
    -- has it off, and the /reload above would have turned it off anyway.
    { text = "Turns the taint log ON for the rest of the run.", auto = true,
      run = function() return setCVar("taintLog", "1") end },
    { text = "Open a trade again (either side). Put an item in on each side, press Trade on this character, then "
          .. "Cancel. Press Next with the window open. " .. TAINT_NOISE, check = tdOn("taint log on") },
    -- Off and on, closing.
    { text = "With the trade window open: switches the skin off (Blizzard's look).", button = "Skin off",
      run = function() return tdSwitch(false) end, screenshot = "trade, skin off",
      check = function()
          local r = tdState("off")
          local ok = r.shown and r.shell > 0 and r.wellsRight == 0 and r.buttonsRight == 0
          return ok, ok and "Blizzard's look, nothing of ours" or "something of ours while off"
      end },
    { text = "Switches the skin on again.", button = "Skin on", run = function() return tdSwitch(true) end },
    { text = "Wait a second, then press Next (the window still open).", check = tdOn("on again") },
    { text = "Close it with its X. Press Next.", check = tdClosed("closed with X") },
    { text = "Open a trade again, then close it with Esc. Press Next.", check = tdClosed("closed with Esc") },
    { text = "If you can start a trade while in combat (get hit by a mob near the other character, then /trade), "
          .. "do it and press Next with the window open; else press Skip.", check = tdOn("in combat", { combat = true }) },
    { text = "Did every trade open, change and close with no 'Interface action failed' message or Lua error? "
          .. "Anything else: the Note.", ask = true },
    taintOff(),
    { text = "Type /reload to save the results.", reload = true },
})

skinChecks.tdState, skinChecks.tdOn, skinChecks.tdClosed = tdState, tdOn, tdClosed
end

--------------------------------------------------------------------------------
-- The suite theme (#24, docs/SUITE.md "In-game validation", S.1-S.8): Glass
-- UI coordinating Glass Unit Frames and Glass Raid Frames. It reads only
-- public state: Glass UI's Suite record, each addon's glass instance (its
-- STYLE and preset through the addon's own forwarding table), its saved look
-- keys, and LibGlass's MINOR. It switches addon combinations for THIS
-- character only (the GUID: a name changes nothing, porting guide C_AddOns),
-- after saving the three addons' enable states and the follow switches in
-- SkinProbeDB.suiteWas[GUID] (account-wide saved variables, per-character
-- states: a run stopped on one character never restores onto another); its
-- last step, or /fp skin suite restore, puts them
-- back.
--------------------------------------------------------------------------------

local SUITE_ADDONS = { "GlassUI", "GlassUnitFrames", "GlassRaidFrames" }
local MEMBERS = { "GlassUnitFrames", "GlassRaidFrames" }
-- Glass Panel is read the same way, by its own procedure (suitepanel, #58).
local NAMESPACE = { GlassUnitFrames = "GlassUF", GlassRaidFrames = "GlassRaidFrames", GlassPanel = "GlassPanel" }
-- The saved keys following must leave untouched (the plan's suspension list).
local SAVED = {
    GlassUnitFrames = { db = "GlassUnitFramesDB",
                        keys = { "look", "glassBody", "fill", "rim", "track", "fade", "edge", "trackRamp" } },
    GlassRaidFrames = { db = "GlassRaidFramesDB", keys = { "look", "glassBody" } },
    GlassPanel = { db = "GlassPanelDB", keys = { "glass", "glassTint", "windowGlass" } },
}
local STYLE_KEYS = { "gloss", "frost", "wash", "innerShadow" }

local function suite()
    local G = glassUI()
    return G and type(G.Suite) == "table" and G.Suite or nil
end

local function guid()
    local ok, g = pcall(UnitGUID, "player")
    g = ok and plain(g) or nil
    return type(g) == "string" and g or nil
end

local function enableState(name)
    local g = guid()
    if not g then return nil end
    local ok, s = pcall(C_AddOns.GetAddOnEnableState, name, g)
    s = ok and plain(s) or nil
    return type(s) == "number" and s or nil
end

local function setEnabled(name, on)
    local g = guid()
    if not g then return false end
    return (pcall(on and C_AddOns.EnableAddOn or C_AddOns.DisableAddOn, name, g))
end

-- This character's saved states, or nil; the table of them, made on demand.
local function suiteSaved(make)
    if type(SkinProbeDB) ~= "table" then return nil end
    local g = guid()
    if not g then return nil end
    if type(SkinProbeDB.suiteWas) ~= "table" then
        if not make then return nil end
        SkinProbeDB.suiteWas = {}
    end
    return SkinProbeDB.suiteWas[g], SkinProbeDB.suiteWas, g
end

-- Saved once per character, before the first change; kept across the
-- procedure's reloads.
local function suiteSnapshot()
    if type(SkinProbeDB) ~= "table" then return false, "no saved table" end
    local was, all, g = suiteSaved(true)
    if not all then return false, "no character GUID" end
    if type(was) == "table" then return true, "already saved" end
    was = { enabled = {}, follow = {} }
    for _, n in ipairs(SUITE_ADDONS) do was.enabled[n] = enableState(n) end
    local S = suite()
    for _, n in ipairs(MEMBERS) do was.follow[n] = S and S.Following and S.Following(n) or false end
    all[g] = was
    say("SUITE saved: GlassUI=" .. show(was.enabled.GlassUI) .. " GlassUnitFrames=" .. show(was.enabled.GlassUnitFrames)
        .. " GlassRaidFrames=" .. show(was.enabled.GlassRaidFrames))
    return true, "saved"
end

-- Enable exactly the addons in `set` (for this character), reading each back;
-- with `follow` given, also set both members' Follow switch (Glass UI must be
-- loaded now for that).
local function suiteSet(set, follow)
    local saved, why = suiteSnapshot()
    if not saved then return false, why end
    if follow ~= nil then
        local S = suite()
        if not (S and S.SetFollow) then return false, "Glass UI isn't loaded: can't set Follow" end
        for _, n in ipairs(MEMBERS) do S.SetFollow(n, follow) end
    end
    local ok, parts = true, {}
    for _, n in ipairs(SUITE_ADDONS) do
        setEnabled(n, set[n] == true)
        local s = enableState(n)
        ok = ok and s ~= nil and (s > 0) == (set[n] == true)
        parts[#parts + 1] = n .. "=" .. show(s)
    end
    local detail = table.concat(parts, " ") .. (follow == nil and "" or (" follow=" .. tostring(follow)))
    say("SUITE set " .. detail)
    return ok, detail
end

local function suiteRestore()
    local was, all, g = suiteSaved(false)
    if type(was) ~= "table" then return true, "nothing to restore for this character" end
    local S = suite()
    if S and S.SetFollow then
        for _, n in ipairs(MEMBERS) do S.SetFollow(n, was.follow[n] == true) end
    end
    local ok, parts = true, {}
    for _, n in ipairs(SUITE_ADDONS) do
        local want = was.enabled[n]
        if type(want) == "number" then
            setEnabled(n, want > 0)
            local s = enableState(n)
            ok = ok and s ~= nil and (s > 0) == (want > 0)
            parts[#parts + 1] = n .. "=" .. show(s)
        end
    end
    -- The follow switches live in GlassUIDB: kept for when Glass UI is back.
    if S then all[g] = nil end
    local detail = table.concat(parts, " ") .. (S and "" or "; follow not restored (Glass UI not loaded)")
    say("SUITE restored " .. detail)
    return ok, detail
end

local function field(t, k)
    local ok, v = pcall(function() return t[k] end)
    return ok and plain(v) or nil
end

-- One member as this session sees it: loaded, its instance, its saved keys,
-- and what Glass UI recorded.
local function memberState(name)
    local m = { loaded = loaded(name) }
    local ns = rawget(_G, NAMESPACE[name])
    local glass = type(ns) == "table" and field(ns, "Glass") or nil
    if type(glass) == "table" then
        m.preset = field(glass, "preset")
        local st = field(glass, "STYLE")
        if type(st) == "table" then
            for _, k in ipairs(STYLE_KEYS) do m[k] = field(st, k) end
        end
    end
    local db = rawget(_G, SAVED[name].db)
    if type(db) == "table" then
        m.saved = {}
        for _, k in ipairs(SAVED[name].keys) do
            local v = field(db, k)
            m.saved[k] = (type(v) == "number" or type(v) == "string" or type(v) == "boolean") and v or nil
        end
    end
    local S = suite()
    if S then
        m.state = S.State and select(1, S.State(name)) or nil
        local a = S.AnswerOf and S.AnswerOf(name)
        if a then m.answerReady, m.answerPreset, m.answerReason = a.ready, a.preset, a.reason end
        local r = S.ReportOf and S.ReportOf(name)
        if r then m.reported, m.built, m.reason, m.minor = true, r.built, r.reason, r.minor end
    end
    return m
end

local function memberLine(name, m)
    local parts = { name .. ": loaded=" .. tostring(m.loaded) }
    for _, k in ipairs({ "state", "answerReady", "answerPreset", "answerReason", "built", "reason", "minor", "preset" }) do
        if m[k] ~= nil then parts[#parts + 1] = k .. "=" .. show(m[k]) end
    end
    for _, k in ipairs(STYLE_KEYS) do
        if m[k] ~= nil then parts[#parts + 1] = k .. "=" .. num(m[k]) end
    end
    if m.saved then
        for _, k in ipairs(SAVED[name].keys) do
            if m.saved[k] ~= nil then parts[#parts + 1] = "db." .. k .. "=" .. show(m.saved[k]) end
        end
    end
    return table.concat(parts, " ")
end

local function libMinor()
    local LS = rawget(_G, "LibStub")
    if not LS then return nil end
    local ok, _, minor = pcall(LS.GetLibrary, LS, "LibGlass-1.0", true)
    return ok and plain(minor) or nil
end

-- Every member, Glass UI and the library: logged, and saved as S.<label>.
local function suiteState(label)
    local rec = { glassUI = loaded("GlassUI"), minor = libMinor(), combat = InCombatLockdown() == true }
    local G = glassUI()
    local failures = G and type(G.failures) == "table" and G.failures or {}
    rec.failures = 0
    for _ in pairs(failures) do rec.failures = rec.failures + 1 end
    rec.blocked = type(SkinProbeDB) == "table" and SkinProbeDB.suiteBlocked or 0
    say("S " .. label .. ": GlassUI=" .. tostring(rec.glassUI) .. " LibGlass MINOR=" .. show(rec.minor)
        .. " failures=" .. rec.failures .. " blocked=" .. rec.blocked .. " combat=" .. tostring(rec.combat))
    for _, n in ipairs(MEMBERS) do
        rec[n] = memberState(n)
        say("S " .. label .. ": " .. memberLine(n, rec[n]))
    end
    record("S." .. label, rec)
    return rec
end

-- S.1/S.2/S.3: does this session match the combination? `follow` is whether
-- the loaded members should be on Pearl; `same` the label of an earlier
-- session whose own look and saved keys this one must match exactly.
local function suiteCheck(label, set, follow, same)
    local rec = suiteState(label)
    local bad = {}
    local function fail(msg) bad[#bad + 1] = msg end
    if rec.glassUI ~= (set.GlassUI == true) then fail("GlassUI loaded=" .. tostring(rec.glassUI)) end
    if rec.failures > 0 then fail("Glass UI recorded " .. rec.failures .. " failure(s): /glassui failures") end
    local earlier = same and type(SkinProbeDB) == "table" and SkinProbeDB.results and SkinProbeDB.results["S." .. same]
    for _, n in ipairs(MEMBERS) do
        local m = rec[n]
        if m.loaded ~= (set[n] == true) then fail(n .. " loaded=" .. tostring(m.loaded)) end
        if set[n] and set.GlassUI then
            if m.answerReady ~= true then fail(n .. " asked before Glass UI was ready, or never asked (S.2)") end
            if not m.reported then fail(n .. " didn't report") end
            local want = follow and "pearl" or nil
            if m.built ~= want then fail(n .. " built " .. show(m.built) .. ", wanted " .. show(want)) end
            if m.state ~= (follow and "following" or "own") then fail(n .. " state " .. show(m.state)) end
        end
        -- Following builds Pearl; its own look is the saved one, Pearl by default (owner, 2026-10-18).
        local wantPreset = (follow == true and set.GlassUI == true) and "pearl"
            or (m.saved and m.saved.look) or "pearl"
        if set[n] and m.preset ~= nil and m.preset ~= wantPreset then
            fail(n .. " instance preset " .. show(m.preset) .. ", wanted " .. show(wantPreset))
        end
        local e = type(earlier) == "table" and earlier[n] or nil
        if set[n] and type(e) == "table" then
            for _, k in ipairs(STYLE_KEYS) do
                if m[k] ~= e[k] then fail(n .. " " .. k .. " " .. num(m[k]) .. " vs " .. num(e[k]) .. " in " .. same) end
            end
            for _, k in ipairs(SAVED[n].keys) do
                local now, was = m.saved and m.saved[k], e.saved and e.saved[k]
                if now ~= was then fail(n .. " db." .. k .. " " .. show(now) .. " vs " .. show(was) .. " in " .. same) end
            end
        end
    end
    return #bad == 0, #bad == 0 and "as expected" or table.concat(bad, "; ")
end

-- The combinations, in order (S.1; "all, own" and "all, own again" are S.3).
-- `follow`: whether the loaded members should be on Pearl. Both switches are
-- off from the first step on; only "all, following" turns them on, from the
-- "all, own" session, where Glass UI is loaded to take the change.
local ALL = { GlassUI = true, GlassUnitFrames = true, GlassRaidFrames = true }
local COMBOS = {
    { label = "Glass UI alone", set = { GlassUI = true } },
    { label = "Unit Frames alone", set = { GlassUnitFrames = true } },
    { label = "Raid Frames alone", set = { GlassRaidFrames = true } },
    { label = "both, no Glass UI", set = { GlassUnitFrames = true, GlassRaidFrames = true } },
    { label = "Glass UI + Unit Frames", set = { GlassUI = true, GlassUnitFrames = true } },
    { label = "Glass UI + Raid Frames", set = { GlassUI = true, GlassRaidFrames = true } },
    { label = "all, own", set = ALL },
    { label = "all, following", set = ALL, follow = true },
}

-- ADDON_ACTION_BLOCKED / FORBIDDEN this session (S.7), counted, never kept.
local blockedWatch = CreateFrame("Frame")
Probe:RegisterEvents(blockedWatch, { "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" })
blockedWatch:SetScript("OnEvent", function(_, event, who)
    if type(SkinProbeDB) ~= "table" then return end
    SkinProbeDB.suiteBlocked = (SkinProbeDB.suiteBlocked or 0) + 1
    say("S " .. event .. " " .. show(plain(who)))
end)

local suiteSteps = {
    title = "Glass UI: the suite theme (Pearl) across Glass Unit Frames and Glass Raid Frames",
    { text = "Turns on script errors, saves which of Glass UI, Glass Unit Frames and Glass Raid Frames are "
          .. "enabled for this character (and their Follow switches), and reads the suite as it is now. The "
          .. "procedure turns them on and off for this character only, one combination per /reload, and puts "
          .. "everything back at the end.",
      auto = true, run = function()
          if type(SkinProbeDB) == "table" then SkinProbeDB.suiteBlocked = 0 end
          local saved = suiteSnapshot()
          local S = suite()
          if S and S.SetFollow then for _, n in ipairs(MEMBERS) do S.SetFollow(n, false) end end
          return setCVar("scriptErrors", "1"), saved, suiteState("start").glassUI
      end,
      check = function()
          local S = suite()
          return S ~= nil and S.API == 1, S and "Glass UI's suite API is here; both Follow switches off for now"
              or "Glass UI (with its suite API) must be loaded to start: enable it, /reload, and start again"
      end },
    { text = "For the look check later (S.3): in Glass Unit Frames' options, set its Body to Smoked and move "
          .. "one Look slider (say Rim). Type what you changed in the Note box, so you can put it back at the "
          .. "end. Skip if you'd rather not." },
}
for i, c in ipairs(COMBOS) do
    local nextStep = { text = "Next combination: " .. c.label .. ". Sets it for this character.",
                       button = c.label, run = function() return suiteSet(c.set, c.follow) end }
    suiteSteps[#suiteSteps + 1] = nextStep
    suiteSteps[#suiteSteps + 1] = { text = "Reload, to start with " .. c.label .. ".", reload = true }
    suiteSteps[#suiteSteps + 1] = {
        text = "Reads " .. c.label .. ": who loaded, what Glass UI answered and when, what each built.",
        auto = true, run = function() return suiteState(c.label).minor end,
        check = function() return suiteCheck(c.label, c.set, c.follow == true) end }
    if i == 1 then
        suiteSteps[#suiteSteps + 1] = { text = "Type /glassui suite. Does it list Glass Unit Frames and Glass "
            .. "Raid Frames as not loaded, and the other Glass addons as not installed, disabled or not yet "
            .. "integrated?", ask = true }
    end
end
local more = {
    -- All three loaded and following: the looks and the live behaviour.
    { text = "Both are on Pearl now. Open Glass UI's page (/glassui options). Do both cards read 'Glass UI "
          .. "preset: Pearl' with 'Use Glass UI appearance' checked?", ask = true, screenshot = "suite, Glass UI page" },
    { text = "Does the page look like your mockup: the Pearl card with its orb, the two glass cards, and "
          .. "'Theme sync unavailable' folded (click it: does it list the other Glass addons)? Is it all inside "
          .. "the window, nothing cut off at the bottom?", ask = true, screenshot = "suite, page unfolded" },
    { text = "Press Glass Unit Frames' Settings button. Does its Look section say it follows Glass UI, with the "
          .. "look controls greyed out?", ask = true, screenshot = "suite, GUF options" },
    { text = "S.8: back on Glass UI's page, press Configure bindings. Did Glass Raid Frames' editor open, and does "
          .. "it read well on Pearl (its preview health bar included)?", ask = true, screenshot = "suite, click-cast editor" },
    { text = "Does the page's click-casting line (Enabled/Disabled) match Glass Raid Frames' 'other addons' "
          .. "frames' setting?", ask = true },
    { text = "Open Glass UI's page again and press its own Reload UI button, at the bottom right (not this "
          .. "panel's). Did the UI reload, with no 'blocked' message?", reload = true },
    { text = "Reads the session after Glass UI's own reload: still all three on Pearl, nothing blocked.",
      auto = true, run = function() return suiteState("after the page's reload").blocked end,
      check = function() return suiteCheck("after the page's reload", ALL, true) end },
    { text = "S.4: target a player of another class, then a hostile NPC, then a friendly NPC. Did the bars change "
          .. "colour at once each time?", ask = true, screenshot = "suite, a target on Pearl" },
    { text = "Change Glass Unit Frames' font (its options, Font). Did the text change at once?", ask = true },
    { text = "Cast a spell with a cast time. Did the cast bar show its colour?", ask = true,
      screenshot = "suite, cast bar on Pearl" },
    { text = "S.5: stand where the scenery behind the frames is bright (snow, sand, sky). Press Next for a "
          .. "screenshot.", screenshot = "suite, bright scenery" },
    { text = "Now where it is dark (a cave, a forest, night). Press Next for a screenshot.",
      screenshot = "suite, dark scenery" },
    { text = "On both: do the bar fills read right, and the health-loss overlay (take a hit to see it)?", ask = true },
    { text = "S.6: type /glass preview (sample data on every frame), then press Next for a screenshot.",
      screenshot = "suite, preview" },
    { text = "Can you tell remaining from missing health at a glance, on unit frames and raid cells, including "
          .. "the low ones? Type /glass preview again to stop it.", ask = true },
    { text = "Optional, Skip if it isn't easy: get your own health below 30% (a fight, a fall), then press Next "
          .. "for a screenshot.", screenshot = "suite, low health" },
    -- S.7: a toggle in combat waits for the reload; a reload in combat.
    { text = "S.7: turns the taint log on (Logs\\taint.log). " .. TAINT_NOISE,
      auto = true, run = function() return setCVar("taintLog", "1") end },
    { text = "Get into combat (pull something weak) and stay in it.", wait = function() return InCombatLockdown() end,
      timeout = 600 },
    { text = "In combat, type: /glassui suite follow glassraidframes off",
      wait = function()
          local S = suite()
          return S and not S.Following("GlassRaidFrames"), "Raid Frames still set to follow"
      end, timeout = 300,
      check = function()
          local rec = suiteState("toggled in combat")
          local m = rec.GlassRaidFrames
          return m.built == "pearl" and m.state == "following",
              "still Pearl this session: built=" .. show(m.built) .. " state=" .. show(m.state)
      end },
    { text = "Still in combat if you can, type /reload.", reload = true },
    { text = "After the reload: Raid Frames on its own look, Unit Frames still on Pearl, its build waited for "
          .. "combat to end if it was still on.",
      auto = true, run = function() return suiteState("reload in combat").combat end,
      check = function()
          local rec = suiteState("after combat reload")
          local u, r = rec.GlassUnitFrames, rec.GlassRaidFrames
          local ok = u.built == "pearl" and u.state == "following" and r.built == nil and r.state == "own"
              and rec.blocked == 0 and rec.failures == 0
          return ok, "GUF " .. show(u.built) .. "/" .. show(u.state) .. ", GRF " .. show(r.built) .. "/"
              .. show(r.state) .. ", blocked=" .. rec.blocked .. ", failures=" .. rec.failures
      end },
    { text = "Did you see any error, or a 'blocked' or 'interface action failed' message?", ask = true },
    -- S.3: off again, against "all, own".
    { text = "Last combination: all three, both back on their own look.", button = "Own look again",
      run = function() return suiteSet(ALL, false) end },
    { text = "Reload.", reload = true },
    { text = "Reads it, and compares each addon's look and saved settings with the 'all, own' session.",
      auto = true, run = function() return suiteState("all, own again").minor end,
      check = function() return suiteCheck("all, own again", ALL, false, "all, own") end },
    { text = "Do both look exactly as they did before following (the Smoked body and slider you set too)?",
      ask = true, screenshot = "suite, own look again" },
    { text = "Puts back which addons were enabled and their Follow switches.", button = "Restore",
      run = suiteRestore },
    { text = "Put back what you changed in Glass Unit Frames' options at the start (your Note says what), then "
          .. "type /reload to save the results.", reload = true },
}
for _, s in ipairs(more) do suiteSteps[#suiteSteps + 1] = s end
Probe:Steps("suite", suiteSteps)

-- S.7 again, on its own (the first run's in-combat switch never reached Glass
-- UI, and its reload came after combat): both following, Raid Frames switched
-- off on Glass UI's page while fighting, a /reload while still fighting, then
-- Raid Frames back on.
local function bothFollowing()
    local S = suite()
    return S ~= nil and S.Following("GlassUnitFrames") and S.Following("GlassRaidFrames")
end
Probe:Steps("suitecombat", {
    title = "Glass UI: the suite theme in combat (S.7)",
    { text = "Needs Glass UI, Glass Unit Frames and Glass Raid Frames loaded, both following Glass UI. Turns on "
          .. "script errors and the taint log (Logs\\taint.log). " .. TAINT_NOISE,
      auto = true, run = function()
          if type(SkinProbeDB) == "table" then SkinProbeDB.suiteBlocked = 0 end
          return setCVar("scriptErrors", "1"), setCVar("taintLog", "1"), suiteState("combat start").glassUI
      end,
      check = function()
          local rec = suiteState("combat start check")
          local ok = bothFollowing() and rec.GlassUnitFrames.built == "pearl" and rec.GlassRaidFrames.built == "pearl"
          return ok, ok and "both on Pearl" or "both must be loaded and following, on Pearl: tick them on Glass "
              .. "UI's page, /reload, and start again"
      end },
    { text = "Open Glass UI's page now (/glassui options) and leave it open. Then get into combat with something "
          .. "weak and stay in it.", wait = function() return InCombatLockdown() end, timeout = 600 },
    { text = "In combat, on Glass UI's page, untick 'Use Glass UI appearance' for Glass Raid Frames (if the "
          .. "page won't open in combat, type /glassui suite follow glassraidframes off instead).",
      wait = function()
          local S = suite()
          return S and not S.Following("GlassRaidFrames"), "Raid Frames still set to follow"
      end, timeout = 300, screenshot = "combat, switched on the page",
      check = function()
          local rec = suiteState("combat switched")
          local m = rec.GlassRaidFrames
          return rec.combat and m.built == "pearl" and m.state == "following",
              "in combat=" .. tostring(rec.combat) .. ", still Pearl this session: built=" .. show(m.built)
      end },
    { text = "Does the page say a change is waiting, and to type /reload when combat ends (no Reload UI button "
          .. "while fighting)?", ask = true },
    { text = "Still fighting: type /reload now, before combat ends.", reload = true },
    { text = "After the reload: Raid Frames on its own look, Unit Frames still on Pearl.",
      auto = true, run = function() return suiteState("combat reloaded").combat end,
      check = function()
          local rec = suiteState("combat reloaded check")
          local u, r = rec.GlassUnitFrames, rec.GlassRaidFrames
          local ok = u.built == "pearl" and r.built == nil and r.state == "own" and rec.blocked == 0 and rec.failures == 0
          return ok, "reloaded in combat=" .. tostring(rec.combat) .. "; GUF " .. show(u.built) .. ", GRF "
              .. show(r.built) .. "/" .. show(r.state) .. ", blocked=" .. rec.blocked .. ", failures=" .. rec.failures
      end },
    { text = "When combat ends: do your raid frames show (built after combat), on their own look?", ask = true,
      screenshot = "combat, raid frames after" },
    { text = "Any 'blocked' or 'interface action failed' message (Blizzard's 'nil value' errors aside)?", ask = true },
    { text = "Puts Glass Raid Frames back to following Glass UI.", button = "Follow again",
      run = function()
          local S = suite()
          if not (S and S.SetFollow) then return false, "Glass UI isn't loaded" end
          return S.SetFollow("GlassRaidFrames", true)
      end },
    taintOff(),
    { text = "Type /reload to save the results.", reload = true },
})

Probe:Command("suite", function(args)
    if args == "restore" then suiteRestore() else suiteState("now") end
end, "the suite theme: each member's state (restore: put back the enable states the procedure saved)")

--------------------------------------------------------------------------------
-- Glass Panel in the suite (#58; GlassPanel#96 and #97, on its main): its own
-- look and following, each after a /reload, read as the members above are;
-- Glass UI's card and its options; its top edge, GlassPanel.EdgeState() and
-- the GlassPanel.EdgeChanged announcements, with XP+'s bar docked and zoomed.
-- Only its Follow switch changes. That lives in GlassUIDB (account-wide), so
-- it is saved once in SkinProbeDB.panelWas and put back by the last step, or
-- /fp skin suitepanel restore.
--------------------------------------------------------------------------------

local PANEL = "GlassPanel"
local PANEL_BAR = 24           -- GlassPanel's Bar.HEIGHT, UIParent units (#97)
local EDGE_SLACK = 0.5         -- its Edge.TOLERANCE: a smaller move isn't announced

-- Every announcement this session: counted, the last value kept.
local edgeHeard = { count = 0 }
EventRegistry:RegisterCallback("GlassPanel.EdgeChanged", function(_, top)
    edgeHeard.count = edgeHeard.count + 1
    edgeHeard.last = plain(top)
end, edgeHeard)

local function panelEdge()
    local f = field(rawget(_G, PANEL) or {}, "EdgeState")
    if type(f) ~= "function" then return nil end
    local ok, s = pcall(f)
    local top = ok and type(s) == "table" and field(s, "top") or nil
    return type(top) == "number" and top or nil
end

local function panelBarShown()
    local bar = field(rawget(_G, PANEL) or {}, "Bar")
    local f = type(bar) == "table" and field(bar, "frame") or nil
    if type(f) ~= "table" then return false end
    local ok, v = pcall(f.IsShown, f)
    return ok and plain(v) == true
end

local function count(t)
    local n = 0
    if type(t) == "table" then for _ in pairs(t) do n = n + 1 end end
    return n
end

-- Glass Panel as a member, its edge and both addons' failures: logged, and
-- saved as P.<label>.
local function panelState(label)
    local m = memberState(PANEL)
    local S, G = suite(), glassUI()
    m.glassUI = loaded("GlassUI")
    m.following = S ~= nil and S.Following ~= nil and S.Following(PANEL) == true
    m.edge, m.barShown = panelEdge(), panelBarShown()
    m.heard, m.lastHeard = edgeHeard.count, edgeHeard.last
    m.combat = InCombatLockdown() == true
    m.failures = count(G and G.failures) + count(field(rawget(_G, PANEL) or {}, "failures"))
    say("P " .. label .. ": " .. memberLine(PANEL, m) .. " following=" .. tostring(m.following) .. " edge="
        .. num(m.edge) .. " bar=" .. tostring(m.barShown) .. " heard=" .. m.heard .. " last=" .. num(m.lastHeard)
        .. " failures=" .. m.failures)
    record("P." .. label, m)
    return m
end

-- The edge read and announced: a number, the bar's height at least while the
-- bar shows, and (out of combat) the last announcement within the slack.
local function edgeProblem(m)
    if m.edge == nil then return "no EdgeState yet" end
    if m.barShown and m.edge < PANEL_BAR - EDGE_SLACK then
        return "EdgeState top " .. num(m.edge) .. ", under the bar's " .. PANEL_BAR
    end
    if m.heard == 0 then return "EdgeChanged never announced" end
    if not m.combat and (m.lastHeard == nil or math.abs(m.lastHeard - m.edge) > EDGE_SLACK) then
        return "last announced " .. num(m.lastHeard) .. ", EdgeState " .. num(m.edge)
    end
end

-- One session: `follow` is whether it should be on Pearl through Glass UI;
-- `same` the label of an earlier session whose saved glass keys this one must
-- match. Pearl is its own default (#96), so the instance is Pearl either way.
local function panelCheck(label, follow, same)
    local m = panelState(label)
    local bad = {}
    local function fail(msg) bad[#bad + 1] = msg end
    if not m.glassUI then fail("Glass UI isn't loaded") end
    if not m.loaded then fail("Glass Panel isn't loaded") end
    if m.failures > 0 then fail(m.failures .. " failure(s): /glassui failures, /gpanel failures") end
    if m.following ~= follow then fail("Follow switch " .. tostring(m.following)) end
    if m.answerReady ~= true then fail("asked before Glass UI was ready, or never asked") end
    if not m.reported then fail("didn't report") end
    local want = follow and "pearl" or nil
    if m.built ~= want then fail("built " .. show(m.built) .. ", wanted " .. show(want)) end
    if m.reason ~= nil then fail("reason " .. show(m.reason)) end
    if m.state ~= (follow and "following" or "own") then fail("state " .. show(m.state)) end
    if type(m.minor) ~= "number" or m.minor < 11 then fail("LibGlass MINOR " .. show(m.minor) .. ", Pearl needs 11") end
    if m.preset ~= "pearl" then fail("instance preset " .. show(m.preset) .. ", wanted pearl") end
    local edge = edgeProblem(m)
    if edge then fail(edge) end
    local earlier = same and type(SkinProbeDB) == "table" and SkinProbeDB.results and SkinProbeDB.results["P." .. same]
    if type(earlier) == "table" then
        for _, k in ipairs(SAVED[PANEL].keys) do
            local now, was = m.saved and m.saved[k], earlier.saved and earlier.saved[k]
            if now ~= was then fail("db." .. k .. " " .. show(now) .. " vs " .. show(was) .. " in " .. same) end
        end
    elseif same then
        fail("no '" .. same .. "' session to compare with")
    end
    return #bad == 0, #bad == 0 and "as expected" or table.concat(bad, "; ")
end

local function panelSnapshot()
    if type(SkinProbeDB) ~= "table" then return false, "no saved table" end
    if type(SkinProbeDB.panelWas) == "table" then return true, "already saved" end
    local S = suite()
    if not (S and S.Following) then return false, "Glass UI isn't loaded" end
    SkinProbeDB.panelWas = { follow = S.Following(PANEL) == true }
    say("P saved: follow=" .. tostring(SkinProbeDB.panelWas.follow))
    return true, "saved"
end

local function panelFollow(on)
    local saved, why = panelSnapshot()
    if not saved then return false, why end
    local S = suite()
    if not (S and S.SetFollow) then return false, "Glass UI isn't loaded: can't set Follow" end
    S.SetFollow(PANEL, on)
    local now = S.Following(PANEL) == true
    say("P follow set " .. tostring(on) .. ", reads " .. tostring(now))
    return now == on, "follow=" .. tostring(now)
end

local function panelRestore()
    local was = type(SkinProbeDB) == "table" and SkinProbeDB.panelWas
    if type(was) ~= "table" then return true, "nothing to restore" end
    local S = suite()
    if not (S and S.SetFollow) then return false, "Glass UI isn't loaded: kept for when it is" end
    S.SetFollow(PANEL, was.follow == true)
    SkinProbeDB.panelWas = nil
    say("P restored follow=" .. tostring(was.follow == true))
    return S.Following(PANEL) == (was.follow == true), "follow=" .. tostring(was.follow == true)
end

-- A wait on the edge, then the session read: was the move announced?
local function edgeWait(test, why)
    return function()
        local e = panelEdge()
        return e ~= nil and test(e), why .. " (EdgeState top " .. num(e) .. ")"
    end
end
local function edgeCheck(label)
    return function()
        local m = panelState(label)
        local problem = edgeProblem(m)
        return problem == nil, problem or ("top " .. num(m.edge) .. ", announced " .. num(m.lastHeard))
    end
end

-- A session is read once Glass Panel has measured: right after a /reload the
-- step comes first (70450: all three reads found no EdgeState yet).
local function firstMeasure() return panelEdge() ~= nil, "waiting for Glass Panel's first measure" end

Probe:Steps("suitepanel", {
    title = "Glass UI: Glass Panel in the suite (Pearl, its options, its top edge)",
    { text = "Needs Glass UI and Glass Panel loaded (XP+ on the panel for the edge steps). Turns on script errors, "
          .. "saves Glass Panel's Follow switch, and reads it as it is now. Only that switch changes; the last "
          .. "step puts it back.",
      auto = true, run = function()
          return setCVar("scriptErrors", "1"), panelSnapshot(), panelState("start").edge
      end,
      check = function()
          local S = suite()
          if not (S and S.API == 1) then return false, "Glass UI (with its suite API) must be loaded: /reload and start again" end
          return loaded(PANEL), loaded(PANEL) and "both loaded" or "Glass Panel must be loaded: enable it, /reload, start again"
      end },
    { text = "Its own look first.", button = "Own look", run = function() return panelFollow(false) end },
    { text = "Reload.", reload = true },
    { text = "Reads its own look: Pearl (its default), nothing built for Glass UI, its edge announced.",
      wait = firstMeasure, timeout = 30,
      check = function() return panelCheck("own", false) end },
    { text = "Optional, so following shows: type /gpanel glass smoked (the bar's own glass), and type what you "
          .. "changed in the Note box to put it back at the end. Skip if you'd rather not." },
    { text = "Now following Glass UI. Reads its saved glass first, to compare with.", button = "Follow",
      run = function()
          panelState("before following")
          return panelFollow(true)
      end },
    { text = "Reload.", reload = true },
    { text = "Reads it following: built Pearl for Glass UI, its saved glass untouched.",
      wait = firstMeasure, timeout = 30,
      check = function() return panelCheck("following", true, "before following") end },
    { text = "Open Glass UI's page (/glassui options). Does Glass Panel's card read 'Glass UI preset: Pearl' with "
          .. "'Use Glass UI appearance' ticked?", ask = true, screenshot = "suite panel, Glass UI page" },
    { text = "Press Glass Panel's Settings button on that card. Are its bar glass and window glass controls greyed "
          .. "out, with an Open Glass UI button? Press that: does Glass UI's page come back?", ask = true,
      screenshot = "suite panel, its options" },
    { text = "Type /gpanel glass smoked. Does it say the glass is set in Glass UI, and the bar stays as it is?",
      ask = true },
    { text = "Close the windows. Does the bar read as Pearl, like the unit frames when they follow? Press Next for "
          .. "a screenshot.", screenshot = "suite panel, the bar on Pearl" },
    -- #97: the bar alone, XP+'s zoomed bar under it, then docked again.
    { text = "Reads the edge with the bar alone (at least the bar's height, announced).",
      auto = true, run = function() return panelEdge() end, check = edgeCheck("edge, docked") },
    { text = "Double-click XP+'s icon on the panel to zoom its bar. If the bar isn't at the top of the screen, "
          .. "Shift-drag it up under the panel. Skip if XP+ isn't on your panel.",
      wait = edgeWait(function(e) return e > PANEL_BAR + EDGE_SLACK end, "waiting for the edge to grow"),
      timeout = 300, screenshot = "suite panel, the XP bar zoomed",
      check = edgeCheck("edge, zoomed") },
    { text = "Double-click XP+'s icon on the zoomed bar to dock it again.",
      wait = edgeWait(function(e) return e <= PANEL_BAR + EDGE_SLACK end, "waiting for the edge to come back"),
      timeout = 300, check = edgeCheck("edge, docked again") },
    -- Its own look again: the saved glass back as it was.
    { text = "Back to its own look.", button = "Own look again", run = function() return panelFollow(false) end },
    { text = "Reload.", reload = true },
    { text = "Reads its own look again, and compares its saved glass with the session before following.",
      wait = firstMeasure, timeout = 30,
      check = function() return panelCheck("own again", false, "before following") end },
    { text = "Does the bar look as it did before following (Smoked, if you set it)?", ask = true,
      screenshot = "suite panel, own look again" },
    { text = "Puts back Glass Panel's Follow switch.", button = "Restore", run = panelRestore },
    { text = "Put back what you changed at the start (your Note says what; /gpanel glass clear is the default), "
          .. "then type /reload to save the results.", reload = true },
})

Probe:Command("suitepanel", function(args)
    if args == "restore" then panelRestore() else panelState("now") end
end, "Glass Panel in the suite: its state and edge (restore: put back the Follow switch the procedure saved)")

--------------------------------------------------------------------------------
-- Glass UI's own skins on the suite theme (#54, docs/QUEST-TRACKER.md part 1):
-- which glass was built, then the merchant and the meter on it for the owner
-- to judge against the clean glass they had.
--------------------------------------------------------------------------------

local function ownGlass(label)
    local G = glassUI()
    local inst = G and G.Glass
    local st = type(inst) == "table" and field(inst, "STYLE") or nil
    local rec = { preset = G and plain(G.glassPreset), why = G and plain(G.glassWhy), minor = libMinor(),
                  theme = G and G.Theme and G.Theme.Name() }
    if type(st) == "table" then
        for _, k in ipairs(STYLE_KEYS) do rec[k] = field(st, k) end
    end
    say("PEARL " .. label .. ": built " .. show(rec.preset) .. " why=" .. show(rec.why) .. " MINOR=" .. show(rec.minor)
        .. " body=" .. show(rec.theme) .. " wash=" .. num(rec.wash) .. " gloss=" .. num(rec.gloss))
    record("PEARL." .. label, rec)
    return rec
end

Probe:Steps("pearl", {
    title = "Glass UI: its own skins on Pearl (#54)",
    { text = "Reads which glass Glass UI built for its skins: Pearl, the suite theme.",
      auto = true, run = function() return ownGlass("built").preset end,
      check = function()
          local rec = ownGlass("built")
          return rec.preset == "pearl" and rec.why == nil,
              "built " .. show(rec.preset) .. (rec.why and (" (" .. rec.why .. ")") or "")
      end },
    { text = "Talk to a vendor and leave the merchant window open.", wait = function() return shown("MerchantFrame") end,
      timeout = 600, screenshot = "pearl, merchant" },
    { text = "Do the merchant's names and prices read well on Pearl, over the scenery behind it?", ask = true },
    { text = "Close it, and have the damage meter on screen (fight something if its windows are empty). Press "
          .. "Next for a screenshot.", screenshot = "pearl, meter" },
    { text = "Does the meter look at least as good as it did on the clean glass? Put what differs in the Note.",
      ask = true },
    { text = "Type /reload to save the results.", reload = true },
})

--------------------------------------------------------------------------------
-- Acceptance: the quest tracker skin (#55, docs/QUEST-TRACKER.md part 2), on
-- the real addon, from Glass Quest Tracker's look and collapse procedures:
-- each theme, collapsing the tracker and a section, Edit Mode, bright ground,
-- off and on live (a collapse while off), a /reload, combat, and a quest
-- routine under the taint log. The look is judged from the screenshots; the
-- checks read the skin's state (its panel's placement) and a few regions.
--------------------------------------------------------------------------------

local function trackerSwitch(on)
    local G = glassUI()
    if not (G and G.Engine) then return false, "Glass UI not loaded" end
    return G.Engine.SetEnabled("tracker", on)
end

-- The switch, where our panel sits, the NineSlice's alpha, whether the
-- Quests section's header bar is blanked, and the collapses: logged, and
-- saved as QT.<label>.
local function trackerState(label)
    local G = glassUI()
    local t = frameByName("ObjectiveTrackerFrame")
    local q = frameByName("QuestObjectiveTracker")
    local h = q and rawget(q, "Header")
    local okN, nine = call(t and rawget(t, "NineSlice"), "GetAlpha")
    local okB, atlas = call(h and rawget(h, "Background"), "GetAtlas")
    local rec = {
        status = G and G.Engine and G.Engine.Status("tracker") or "Glass UI not loaded",
        panel = G and G.QuestTracker and G.QuestTracker.state,
        nine = okN and plain(nine) or nil,
        blanked = okB and plain(atlas) == nil,
        collapsed = t ~= nil and plain(rawget(t, "isCollapsed")) == true,
        section = q ~= nil and plain(rawget(q, "isCollapsed")) == true,
        combat = InCombatLockdown() == true,
        theme = G and G.Theme and G.Theme.Name(),
    }
    local failures = 0
    for _ in pairs(G and G.failures or {}) do failures = failures + 1 end
    rec.failures = failures
    say("QT " .. label .. ": " .. rec.status .. "; panel=" .. show(rec.panel) .. " nine=" .. num(rec.nine)
        .. " blanked=" .. tostring(rec.blanked) .. " collapsed=" .. tostring(rec.collapsed) .. " section="
        .. tostring(rec.section) .. " theme=" .. show(rec.theme) .. " failures=" .. failures)
    record("QT." .. label, rec)
    return rec
end

-- A check: the skin on and holding (NineSlice faded, a header blanked, no
-- failure), and each field of `want` as asked.
local function trackerOn(label, want)
    return function()
        local rec = trackerState(label)
        local bad = {}
        if rec.status ~= "on" then bad[#bad + 1] = "status " .. rec.status end
        if rec.nine ~= 0 then bad[#bad + 1] = "NineSlice alpha " .. num(rec.nine) end
        if not rec.blanked then bad[#bad + 1] = "Quests header bar not blanked" end
        if rec.failures > 0 then bad[#bad + 1] = rec.failures .. " failure(s): /glassui failures" end
        for k, v in pairs(want or {}) do
            if rec[k] ~= v then bad[#bad + 1] = k .. " " .. show(rec[k]) .. ", wanted " .. show(v) end
        end
        return #bad == 0, #bad == 0 and ("panel " .. show(rec.panel)) or table.concat(bad, "; ")
    end
end

local function trackerWait(field, value, why)
    return function()
        local rec = trackerState("waiting")
        return rec[field] == value, why
    end
end

Probe:Steps("tracker", {
    title = "Glass UI: the quest tracker skin (#55)",
    { text = "Turns on script errors and the taint log (Logs\\taint.log), and reads the skin. Have a few quests "
          .. "tracked and the tracker expanded. " .. TAINT_NOISE,
      auto = true, run = function()
          if type(SkinProbeDB) == "table" then SkinProbeDB.suiteBlocked = 0 end
          return setCVar("scriptErrors", "1"), setCVar("taintLog", "1"), trackerState("start").status
      end,
      check = trackerOn("start check", { panel = "populated" }) },
    { text = "Clear glass, the default. Press Clear for a screenshot.", button = "Clear",
      run = function() return themeTry("clear") end, check = trackerOn("clear", { theme = "clear" }),
      screenshot = "tracker, clear" },
    { text = "Smoked glass.", button = "Smoked", run = function() return themeTry("smoked") end,
      check = trackerOn("smoked", { theme = "smoked" }), screenshot = "tracker, smoked" },
    { text = "Class colour glass.", button = "Class", run = function() return themeTry("class") end,
      check = trackerOn("class", { theme = "class" }), screenshot = "tracker, class" },
    { text = "Back to your own theme.", button = "Restore", run = themeRestore },
    { text = "Can you read every quest line, and is the '-' beside the 'Quests' title fully on the glass?",
      ask = true, screenshot = "tracker, the right edge" },
    { text = "Collapse the whole tracker: click the '-' beside 'All Objectives'.",
      wait = trackerWait("collapsed", true, "not collapsed yet"), timeout = 300,
      check = trackerOn("collapsed", { collapsed = true, panel = "header" }), screenshot = "tracker, collapsed" },
    { text = "Expand it again with the same button.",
      wait = trackerWait("collapsed", false, "still collapsed"), timeout = 300,
      check = trackerOn("expanded", { panel = "populated" }) },
    { text = "Collapse the 'Quests' section: click the '-' at the right of its title.",
      wait = trackerWait("section", true, "the Quests section isn't collapsed yet"), timeout = 300,
      check = trackerOn("section collapsed", { panel = "populated" }), screenshot = "tracker, section collapsed" },
    { text = "Expand the section again.",
      wait = trackerWait("section", false, "the Quests section is still collapsed"), timeout = 300,
      check = trackerOn("section expanded", { panel = "populated" }) },
    { text = "While you did that, did a gold bar or a shine flash behind a section title? Say when in the Note.",
      ask = true },
    { text = "Open Edit Mode.", wait = function() return editMode(), "Edit Mode isn't open" end, timeout = 300 },
    { text = "Click the tracker, drag it a little, change its Height and its Text Size, then close Edit Mode "
          .. "(Save or Revert).", wait = function() return not editMode(), "Edit Mode is still open" end,
      timeout = 600, check = trackerOn("after Edit Mode", { panel = "populated" }),
      screenshot = "tracker, after Edit Mode" },
    { text = "Stand or turn so the tracker is over bright ground or sky. Is every line easy to read?",
      ask = true, screenshot = "tracker, bright ground" },
    -- Off and on live; a collapse while off is placed right when it's back.
    { text = "Switches the skin off, live.", button = "Skin off", screenshot = "tracker, skin off",
      run = function() return trackerSwitch(false), trackerState("off").status end,
      check = function()
          local rec = trackerState("off check")
          return rec.status == "off" and not rec.blanked, "status " .. rec.status .. ", blanked " .. tostring(rec.blanked)
      end },
    { text = "Does the tracker look exactly like Blizzard's own: the gold header bars and gold buttons back, "
          .. "no glass?", ask = true },
    { text = "While the skin is off, collapse the whole tracker.",
      wait = trackerWait("collapsed", true, "not collapsed yet"), timeout = 300 },
    { text = "Switches the skin on again, live: the glass should sit on the collapsed header.", button = "Skin on",
      screenshot = "tracker, on again collapsed",
      run = function() return trackerSwitch(true), trackerState("on again").status end,
      check = trackerOn("on again", { collapsed = true, panel = "header" }) },
    { text = "Expand the tracker.", wait = trackerWait("collapsed", false, "still collapsed"), timeout = 300,
      check = trackerOn("on again, expanded", { panel = "populated" }) },
    { text = "Reload.", reload = true },
    { text = "After the reload. Press Next for a screenshot.", screenshot = "tracker, after reload",
      check = trackerOn("after reload", { panel = "populated" }) },
    { text = "Turns the taint log on again for the quest routine (the reload turned it off). " .. TAINT_NOISE,
      auto = true,
      run = function() return setCVar("taintLog", "1") end },
    { text = "The quest routine, as it comes: accept a quest, make progress on one (kill or loot), and turn one "
          .. "in. A dungeon too if you're near one; Skip what you can't do now. Press Next when done.",
      check = trackerOn("routine", { panel = "populated" }) },
    { text = "Optional, Skip if it isn't easy: fight something and press Measure while in combat.",
      button = "Measure", run = function() return trackerState("combat").combat end,
      check = function()
          local ok, why = trackerOn("combat check")()
          return ok and InCombatLockdown(), why
      end },
    { text = "Reads what was blocked this session (it should be nothing).", auto = true,
      run = function() return type(SkinProbeDB) == "table" and SkinProbeDB.suiteBlocked or 0 end,
      check = function()
          local n = type(SkinProbeDB) == "table" and SkinProbeDB.suiteBlocked or 0
          return n == 0, n .. " blocked"
      end },
    { text = "Did you see any error, or a 'blocked' or 'interface action failed' message (Blizzard's 'nil "
          .. "value' errors aside)?", ask = true },
    taintOff(),
    { text = "Type /reload to save the results.", reload = true },
})

Probe:Command("tracker", function() trackerState("now") end, "the quest tracker skin: its switch, panel and regions")

--------------------------------------------------------------------------------
-- Acceptance: the accent on Blizzard's titles (#71, docs/PLAN.md "The accent
-- on Blizzard's titles"): the tracker's "All Objectives" and the meter's
-- window title, live, through Edit Mode's Text Size, off and on, in combat.
--------------------------------------------------------------------------------

local function titleColour(fs)
    local ok, r, g, b = call(fs, "GetTextColor")
    if not ok then return nil end
    r, g, b = plain(r), plain(g), plain(b)
    return type(r) == "number" and { r, g, b } or nil
end

-- The two titles' colours against the suite's accent: logged, and saved as AC.<label>.
local function accentState(label)
    local G = glassUI()
    local t = frameByName("ObjectiveTrackerFrame")
    local h = t and rawget(t, "Header")
    local w = frameByName("DamageMeterSessionWindow1")
    local dd = w and rawget(w, "DamageMeterTypeDropdown")
    local want = G and G.Suite and G.Suite.Accent and G.Suite.Accent() or nil
    local rec = { accent = G and G.Suite and G.Suite.Look and (G.Suite.Look() or {}).accent,
                  tracker = titleColour(h and rawget(h, "Text")), meter = titleColour(dd and rawget(dd, "TypeName")),
                  want = want, combat = InCombatLockdown() == true }
    local function str(c) return c and (num(c[1]) .. "," .. num(c[2]) .. "," .. num(c[3])) or "?" end
    say("AC " .. label .. ": accent " .. show(rec.accent) .. " (" .. str(want) .. "); tracker title " .. str(rec.tracker)
        .. "; meter title " .. str(rec.meter) .. " combat=" .. tostring(rec.combat))
    record("AC." .. label, rec)
    return rec
end

local function near3(a, b)
    if not (a and b) then return false end
    for i = 1, 3 do if math.abs(a[i] - b[i]) > 0.01 then return false end end
    return true
end
local GOLD = { 1, 0.82, 0 }

-- A check: both titles in `want` (the current accent when nil).
local function titlesAre(label, want)
    return function()
        local rec = accentState(label)
        local w = want or rec.want
        local ok = near3(rec.tracker, w) and near3(rec.meter, w)
        return ok, ok and "both titles as wanted" or "tracker or meter title not in the wanted colour"
    end
end

local function setAccent(name)
    local G = glassUI()
    if not (G and G.Suite and G.Suite.SetLook) then return false, "Glass UI not loaded" end
    return G.Suite.SetLook("accent", name), name
end

-- Edit Mode and back: a step's wait that accepts Edit Mode closed only after
-- it has seen it open during the step. Edit Mode is closed when the step
-- starts, so "not editMode()" alone passed at once on 70888 (run #225, #180)
-- and the Text Size check read the titles untouched. The seen state resets
-- once accepted, and with each new attempt (attempt(), the game menu's), so a
-- step reached again needs its own visit.
function skinChecks.editModeVisit()
    local visited = false
    local isNew = attempt()
    return function()
        if isNew() then visited = false end
        local open = editMode()
        if open then visited = true end
        if not visited then return false, "waiting for Edit Mode to open" end
        if open then return false, "Edit Mode is still open" end
        visited = false
        return true, "Edit Mode opened and closed"
    end
end

Probe:Steps("accent", {
    title = "Glass UI: the accent on the yellow titles (#71)",
    rev = 2,
    { text = "Have the quest tracker and the damage meter on screen. Reads both titles.", auto = true,
      run = function() return accentState("start").accent end },
    { text = "Ice: 'All Objectives', the section titles and 'Damage Done' turn ice blue.", button = "Ice",
      run = function() return setAccent("ice") end, check = titlesAre("ice"), screenshot = "accent, ice" },
    { text = "In Edit Mode, change the tracker's Text Size, then close Edit Mode. This step goes on by itself once "
          .. "it has seen Edit Mode open and close.",
      wait = skinChecks.editModeVisit(), timeout = 600,
      check = titlesAre("ice, after Text Size"), screenshot = "accent, after Text Size" },
    { text = "Gold, Blizzard's own.", button = "Gold", run = function() return setAccent("gold") end,
      check = titlesAre("gold"), screenshot = "accent, gold" },
    { text = "Ice again, then the tracker skin and the meter skin off: both titles back in Blizzard's gold.",
      button = "Skins off", screenshot = "accent, skins off",
      run = function()
          setAccent("ice")
          local G = glassUI()
          if not (G and G.Engine) then return false, "Glass UI not loaded" end
          G.Engine.SetEnabled("tracker", false)
          G.Engine.SetEnabled("meter", false)
          return true
      end, check = titlesAre("skins off", GOLD) },
    { text = "With the skins off, change the tracker's Text Size in Edit Mode again, then close it. This step goes "
          .. "on by itself once it has seen Edit Mode open and close.",
      wait = skinChecks.editModeVisit(), timeout = 600,
      check = titlesAre("off, after Text Size", GOLD) },
    { text = "Both skins on again: the titles take the current accent.", button = "Skins on",
      run = function()
          local G = glassUI()
          if not (G and G.Engine) then return false, "Glass UI not loaded" end
          G.Engine.SetEnabled("tracker", true)
          G.Engine.SetEnabled("meter", true)
          return true
      end, check = titlesAre("skins on") },
    { text = "Optional, Skip if it isn't easy: get into combat, then press Gold while fighting.", button = "Gold",
      run = function() return setAccent("gold") end,
      check = function()
          local ok, why = titlesAre("combat gold")()
          return ok and InCombatLockdown(), why
      end },
    { text = "Do the titles read well in both colours? Which do you prefer? Say it in the Note.", ask = true },
    { text = "Type /reload to save the results.", reload = true },
})

Probe:Command("accent", function() accentState("now") end, "#71: the titles' colours against the suite accent")

--------------------------------------------------------------------------------
-- Acceptance: the quest timers on a pill (#73, docs/QUEST-TRACKER.md "The
-- quest timers"): their dialog art faded, their title in the accent, our pill
-- around them and the band below them; collapse, a row's tooltip and click
-- under the taint log, off and on, and the band back at the top once they go.
--------------------------------------------------------------------------------

local function topOf(f)
    local ok, v = call(f, "GetTop")
    return ok and plain(v) or nil
end
local function bottomOf(f)
    local ok, v = call(f, "GetBottom")
    return ok and plain(v) or nil
end
local function visible(f)
    local ok, v = call(f, "IsVisible")
    return ok and plain(v) == true
end
local function alphaNum(r)
    local ok, a = call(r, "GetAlpha")
    a = ok and plain(a) or nil
    return type(a) == "number" and a or nil
end

-- The timers, our pill and band, read from the client: logged, and saved as TM.<label>.
local function timerState(label)
    local G = glassUI()
    local t = frameByName("ObjectiveTrackerFrame")
    local q = frameByName("QuestTimerFrame")
    local h = t and rawget(t, "Header")
    local qh = q and rawget(q, "Header")
    local QT = G and G.QuestTracker and G.QuestTracker._test
    local pill = QT and t and QT.pills[t]
    local band = QT and t and QT.bands[t]
    local rec = {
        status = G and G.Engine and G.Engine.Status("tracker") or "Glass UI not loaded",
        shown = visible(q),
        timers = q and plain(rawget(q, "numTimers")) or nil,
        border = alphaNum(q and rawget(q, "Border")),
        pieces = 0,
        title = titleColour(qh and rawget(qh, "Text")),
        want = G and G.Suite and G.Suite.Accent and G.Suite.Accent() or nil,
        pill = visible(pill),
        pillTop = topOf(pill), pillBottom = bottomOf(pill),
        timerTop = topOf(q), timerBottom = bottomOf(q),
        bandTop = topOf(band), headerTop = topOf(h), trackerTop = topOf(t),
        collapsed = t ~= nil and plain(rawget(t, "isCollapsed")) == true,
        combat = InCombatLockdown() == true,
    }
    for _, key in ipairs({ "LeftBG", "RightBG", "CenterBG" }) do
        rec.pieces = math.max(rec.pieces, alphaNum(qh and rawget(qh, key)) or 1)
    end
    local failures = 0
    for _ in pairs(G and G.failures or {}) do failures = failures + 1 end
    rec.failures = failures
    local function str(c) return c and (num(c[1]) .. "," .. num(c[2]) .. "," .. num(c[3])) or "?" end
    say("TM " .. label .. ": " .. rec.status .. "; timers " .. (rec.shown and show(rec.timers) or "hidden")
        .. " border=" .. num(rec.border) .. " pieces=" .. num(rec.pieces) .. " title " .. str(rec.title)
        .. " pill=" .. tostring(rec.pill) .. " " .. num(rec.pillTop) .. ".." .. num(rec.pillBottom)
        .. " timer " .. num(rec.timerTop) .. ".." .. num(rec.timerBottom) .. " band top " .. num(rec.bandTop)
        .. " header top " .. num(rec.headerTop) .. " tracker top " .. num(rec.trackerTop)
        .. " collapsed=" .. tostring(rec.collapsed) .. " failures=" .. failures)
    record("TM." .. label, rec)
    return rec
end

local function close(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 0.5 end

-- A check: the skin on, the art faded, the title in the accent, and, with the
-- timers up, the pill around them and the band hanging from the Header below
-- them; `gone`: no timers, the band back at the tracker's top.
local function timerOn(label, gone)
    return function()
        local rec = timerState(label)
        local bad = {}
        if rec.status ~= "on" then bad[#bad + 1] = "status " .. rec.status end
        if rec.border ~= 0 then bad[#bad + 1] = "border alpha " .. num(rec.border) end
        if rec.pieces ~= 0 then bad[#bad + 1] = "header art alpha " .. num(rec.pieces) end
        if not near3(rec.title, rec.want) then bad[#bad + 1] = "title not in the accent" end
        if rec.failures > 0 then bad[#bad + 1] = rec.failures .. " failure(s): /glassui failures" end
        if not close(rec.bandTop, rec.headerTop) then bad[#bad + 1] = "the band's top isn't the Header's" end
        if gone then
            if rec.shown then bad[#bad + 1] = "the timers are still up" end
            if rec.pill then bad[#bad + 1] = "the pill is still seen" end
            if not close(rec.bandTop, rec.trackerTop) then bad[#bad + 1] = "the band isn't back at the top" end
        else
            if not rec.shown then bad[#bad + 1] = "no timers up" end
            if not rec.pill then bad[#bad + 1] = "no pill seen" end
            if not (rec.pillTop and rec.timerTop and rec.pillTop > rec.timerTop) then
                bad[#bad + 1] = "the pill doesn't rise above the timers"
            end
            if not (rec.bandTop and rec.timerBottom and rec.bandTop < rec.timerBottom) then
                bad[#bad + 1] = "the band overlaps the timers"
            end
        end
        return #bad == 0, #bad == 0 and "as wanted" or table.concat(bad, "; ")
    end
end

Probe:Steps("timer", {
    title = "Glass UI: the quest timers on a pill (#73)",
    { text = "Turns on script errors and the taint log (Logs\\taint.log), and reads the timers. Have the tracker "
          .. "expanded and the tracker skin on. " .. TAINT_NOISE, auto = true,
      run = function()
          if type(SkinProbeDB) == "table" then SkinProbeDB.suiteBlocked = 0 end
          return setCVar("scriptErrors", "1"), setCVar("taintLog", "1"), timerState("start").status
      end },
    { text = "Accept a timed quest, or have one up already: the 'Quest Timers' box shows above the tracker.",
      wait = function() return timerState("waiting").shown, "no quest timer up yet" end, timeout = 900,
      check = timerOn("shown"), screenshot = "timer, shown" },
    { text = "Does the timer sit on a glass pill of its own, clear of the 'All Objectives' band, title and "
          .. "countdown easy to read? Say what you'd change in the Note.", ask = true },
    { text = "Collapse the whole tracker: click the '-' beside 'All Objectives'.",
      wait = function() return timerState("waiting").collapsed, "not collapsed yet" end, timeout = 300,
      check = timerOn("collapsed"), screenshot = "timer, collapsed" },
    { text = "Expand the tracker.",
      wait = function() return not timerState("waiting").collapsed, "still collapsed" end, timeout = 300,
      check = timerOn("expanded") },
    { text = "Hover the countdown: does its tooltip show the quest? Then click it: does the quest log open on "
          .. "that quest? Close the log.", ask = true },
    { text = "Optional, Skip if it isn't easy: in combat, hover and click the countdown, then press Measure "
          .. "while still fighting.", button = "Measure", run = function() return timerState("combat").combat end,
      check = function()
          local ok, why = timerOn("combat")()
          return ok and InCombatLockdown(), why
      end },
    { text = "Switches the tracker skin off, live: Blizzard's dialog box back, in gold.", button = "Skin off",
      screenshot = "timer, skin off",
      run = function() return trackerSwitch(false), timerState("off").status end,
      check = function()
          local rec = timerState("off check")
          local ok = rec.status == "off" and (rec.border or 0) > 0.99 and rec.pieces > 0.99 and not rec.pill
              and near3(rec.title, GOLD)
          return ok, ok and "Blizzard's own" or "status " .. rec.status .. ", border " .. num(rec.border)
              .. ", header art " .. num(rec.pieces) .. ", pill " .. tostring(rec.pill)
      end },
    { text = "Switches it on again.", button = "Skin on", screenshot = "timer, on again",
      run = function() return trackerSwitch(true), timerState("on again").status end,
      check = timerOn("on again") },
    { text = "Turn the quest in (or let the timer run out): the box goes and the band goes back to the top.",
      wait = function() return not timerState("waiting").shown, "the timer is still up" end, timeout = 1800,
      check = timerOn("gone", true), screenshot = "timer, gone" },
    { text = "Reads what was blocked this session (it should be nothing).", auto = true,
      run = function() return type(SkinProbeDB) == "table" and SkinProbeDB.suiteBlocked or 0 end,
      check = function()
          local n = type(SkinProbeDB) == "table" and SkinProbeDB.suiteBlocked or 0
          return n == 0, n .. " blocked"
      end },
    { text = "Did you see any error, or a 'blocked' or 'interface action failed' message?", ask = true },
    taintOff(),
    { text = "Type /reload to save the results.", reload = true },
})

Probe:Command("timer", function() timerState("now") end, "#73: the quest timers, their pill and the band")

-- The same on fake timers, for want of timed quests (the owner, 2026-10-20:
-- "there is just not enough timer quests"). C_QuestLog.GetQuestTimers is
-- swapped for ours, lending a quest of the log its ID (so a row's tooltip and
-- click still work), until the procedure ends or a /reload. Everything else is
-- Blizzard's own path: QuestTimerMixin builds the rows and pads the tracker
-- from that answer, as for a real one. The swap taints that path, so this run
-- says nothing on taint (TM.3 needs a real timed quest): no taint log, out of
-- combat only, and a /reload at the end.
local fake = { count = 0, ends = 0, quests = {} }

local function fakeTimers()
    local out, left = {}, math.max(0, math.floor(fake.ends - GetTime()))
    for i = 1, fake.count do
        out[i] = { questID = fake.quests[i] or fake.quests[1], questTimer = left + (i - 1) * 60 }
    end
    return out
end

-- Blizzard picks the answer up at once: the timers redrawn and the tracker
-- laid out again (its Header moves on its next Update).
local function nudge()
    local q, t = frameByName("QuestTimerFrame"), frameByName("ObjectiveTrackerFrame")
    call(q, "UpdateIfNeeded")
    call(t, "MarkDirty")
end

local function fakeOn(n)
    local log = rawget(_G, "C_QuestLog")
    if type(log) ~= "table" or type(log.GetQuestTimers) ~= "function" then return false, "no C_QuestLog.GetQuestTimers" end
    if not fake.real then
        fake.quests = {}
        local ok, shown = pcall(log.GetNumQuestLogEntries)
        for i = 1, (ok and plain(shown)) or 0 do
            local okI, info = pcall(log.GetInfo, i)
            local id = okI and type(info) == "table" and plain(info.questID)
            if id and type(id) == "number" and id > 0 and not plain(info.isHeader) then fake.quests[#fake.quests + 1] = id end
            if #fake.quests >= 2 then break end
        end
        if #fake.quests == 0 then return false, "no quest in the log to lend its ID: accept one first" end
        fake.real = log.GetQuestTimers
        fake.ends = GetTime() + 300
        log.GetQuestTimers = fakeTimers
    end
    fake.count = n
    nudge()
    say("TM fake: " .. n .. " timer(s) on quest " .. tostring(fake.quests[1]))
    return true, n .. " fake timer(s)"
end

local function fakeOff()
    if fake.real then
        C_QuestLog.GetQuestTimers = fake.real
        fake.real = nil
    end
    fake.count = 0
    nudge()
    return true
end

Probe:Steps("timerfake", {
    title = "Glass UI: the quest timers on a pill, on fake timers (#73)",
    { text = "Swaps in one fake 5-minute timer, on a quest of your log. Have a quest in the log, the tracker "
          .. "expanded, the tracker skin on, and stay out of combat. A /reload at the end puts Blizzard's back.",
      button = "Fake timer", run = function() return fakeOn(1) end },
    { text = "The 'Quest Timers' box shows above the tracker, the band under it.",
      wait = timerOn("fake waiting"), timeout = 60, check = timerOn("fake shown"), screenshot = "timer fake, shown" },
    { text = "Does the timer sit on a glass pill of its own, clear of the 'All Objectives' band, title and "
          .. "countdown easy to read? Say what you'd change in the Note.", ask = true },
    { text = "A second timer: the box and its pill grow, the band moves down.", button = "Two timers",
      run = function() return fakeOn(2) end },
    { text = "Two rows, the band below them.", wait = timerOn("fake two waiting"), timeout = 60,
      check = timerOn("fake two"), screenshot = "timer fake, two" },
    { text = "Collapse the whole tracker: click the '-' beside 'All Objectives'.",
      wait = function() return timerState("waiting").collapsed, "not collapsed yet" end, timeout = 300,
      check = timerOn("fake collapsed"), screenshot = "timer fake, collapsed" },
    { text = "Expand the tracker.",
      wait = function() return not timerState("waiting").collapsed, "still collapsed" end, timeout = 300,
      check = timerOn("fake expanded") },
    { text = "Hover a countdown: does its tooltip show the quest's title? Then click it: does the quest log open "
          .. "on that quest? Close the log.", ask = true },
    { text = "Switches the tracker skin off, live: Blizzard's dialog box back, in gold.", button = "Skin off",
      screenshot = "timer fake, skin off",
      run = function() return trackerSwitch(false), timerState("fake off").status end,
      check = function()
          local rec = timerState("fake off check")
          local ok = rec.status == "off" and (rec.border or 0) > 0.99 and rec.pieces > 0.99 and not rec.pill
              and near3(rec.title, GOLD)
          return ok, ok and "Blizzard's own" or "status " .. rec.status .. ", border " .. num(rec.border)
              .. ", header art " .. num(rec.pieces) .. ", pill " .. tostring(rec.pill)
      end },
    { text = "Switches it on again.", button = "Skin on", screenshot = "timer fake, on again",
      run = function() return trackerSwitch(true), timerState("fake on again").status end,
      check = timerOn("fake on again") },
    { text = "Ends the fake timers: the box goes and the band goes back to the top.", button = "End timers",
      run = function() return fakeOff() end },
    { text = "The box gone, the band at the top.", wait = timerOn("fake gone waiting", true), timeout = 60,
      check = timerOn("fake gone", true), screenshot = "timer fake, gone" },
    { text = "Type /reload: Blizzard's code runs clean again, and the results are saved.", reload = true },
})

--------------------------------------------------------------------------------
-- Blizzard's own glass (#17): the ruleset screen's card at login
-- (Blizzard_GlueXML\Mainline\SuperDistrict.xml:8) beside our panels
--------------------------------------------------------------------------------

local CARD = "Mode-Selection-Card-Regular"
local card   -- { host, result }

-- Does the atlas exist in game, and its size: exists, width, height.
local function cardAtlas()
    local T = rawget(_G, "C_Texture")
    if not T then return nil end
    local ok, exists = pcall(T.GetAtlasExists, CARD)
    exists = ok and plain(exists) or nil
    local ok2, info = pcall(T.GetAtlasInfo, CARD)
    local w, h
    if ok2 and type(info) == "table" then w, h = plain(info.width), plain(info.height) end
    say("CARD " .. CARD .. ": exists=" .. show(exists) .. " size=" .. show(w) .. "x" .. show(h))
    record("CARD.atlas", { exists = exists, width = w, height = h })
    return exists, w, h
end

-- A: Blizzard's card. B and C: Glass UI's glass at the same size, painted
-- like its clear and smoked bodies (Suite.BODY: tint, wash, backing).
local function cardOn()
    if card then return card.result end
    local _, w, h = cardAtlas()
    w = type(w) == "number" and w > 0 and w or 260
    h = type(h) == "number" and h > 0 and h or 530
    local host = CreateFrame("Frame", nil, UIParent)
    host:SetSize(3 * w + 80, h + 40)
    host:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    host:SetFrameStrata("DIALOG")
    local function label(anchor, text)
        local fs = host:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        fs:SetPoint("BOTTOM", anchor, "TOP", 0, 6)
        fs:SetText(text)
    end
    local a = host:CreateTexture(nil, "ARTWORK")
    local okAtlas = pcall(a.SetAtlas, a, CARD, true)
    a:SetSize(w, h)
    a:SetPoint("LEFT", host, "LEFT", 20, 0)
    label(a, "A  Blizzard")
    local G = glassUI()
    local painted = 0
    if G and G.Glass and G.Theme then
        for i, name in ipairs({ "clear", "smoked" }) do
            local f = CreateFrame("Frame", nil, host)
            f:SetSize(w, h)
            f:SetPoint("LEFT", host, "LEFT", 20 + i * (w + 20), 0)
            local ok, g = pcall(G.Glass.Apply, f, "large")
            if ok and g then
                local p, c = G.Suite.BODY[name], G.Suite.BACKING
                local backing = f:CreateTexture(nil, "BACKGROUND", nil, -7)
                backing:SetAllPoints(f)
                backing:AddMaskTexture(g.mask)
                backing:SetColorTexture(c[1], c[2], c[3], p.backing)
                pcall(G.Glass.SetSurfaceTint, g, p.tint[1], p.tint[2], p.tint[3], p.tint[4])
                pcall(G.Glass.SetWash, g, G.Glass.STYLE.wash * p.wash)
                painted = painted + 1
            end
            label(f, (i == 1 and "B  " or "C  ") .. name)
        end
    end
    say("CARD shown: atlas set " .. tostring(okAtlas) .. ", our panels " .. painted .. " (" .. w .. "x" .. h .. ")")
    card = { host = host, result = okAtlas }
    return okAtlas, painted
end

local function cardOff()
    if card then card.host:Hide(); card.host:SetParent(nil); card = nil end
end

Probe:Command("card", function(args)
    if (args or ""):match("off") then cardOff() else cardOn() end
end, "#17: card on|off: Blizzard's mode-selection card beside our clear and smoked glass")

Probe:Steps("card", {
    title = "Glass UI: Blizzard's card beside our glass",
    { text = "Checks that the ruleset screen's card exists in game.", auto = true,
      run = cardAtlas, check = function() local e = cardAtlas(); return e == true, "the atlas exists" end },
    { text = "Stand somewhere bright (open ground in daylight), then press Show: A is Blizzard's card, "
          .. "B and C are our clear and smoked glass at the same size.", button = "Show",
      run = cardOn, screenshot = "card beside our glass, bright" },
    { text = "Is A see-through, as on the ruleset screen?", ask = true },
    { text = "Would you like a theme that looks like A? Say why in the Note box.", ask = true },
    { text = "Now stand somewhere dark (indoors, a cave, or night), then press Next for a second screenshot.",
      screenshot = "card beside our glass, dark" },
    { text = "Removes the three cards.", button = "Remove", run = function() cardOff(); return true end },
    { text = "Type /reload to save the results.", reload = true },
})

--------------------------------------------------------------------------------
-- Acceptance: the damage meter skin (#49, docs/DAMAGE-METER.md "In game"), on
-- the real addon. The look is judged from the screenshots; the checks read
-- the faded regions and our panels.
--------------------------------------------------------------------------------

local function meterSwitch(on)
    local G = glassUI()
    if not (G and G.Engine) then return false, "Glass UI not loaded" end
    return G.Engine.SetEnabled("meter", on)
end

-- The setting a step waits for, through the meter's own getters (the probe
-- may call them; the skin never does).
local function meterGet(getter)
    local ok, v = call(frameByName("DamageMeter"), getter)
    return ok and plain(v) or nil
end

-- Every shown window's header bar faded (on) or back (off).
local function headersFaded(on)
    local n = 0
    for _, w in ipairs(meterWindows()) do
        if shownFrame(w) then
            local ok, a = call(rawget(w, "Header"), "GetAlpha")
            a = ok and plain(a) or nil
            if (on and a ~= 0) or (not on and a == 0) then return false, "window header alpha " .. show(a) end
            n = n + 1
        end
    end
    return n > 0, n .. " windows"
end

local function skinState(label)
    local G = glassUI()
    local status = G and G.Engine and G.Engine.Status("meter") or "Glass UI not loaded"
    local ok, faded = headersFaded(true)
    say("DMS " .. label .. ": " .. status .. "; headers faded=" .. tostring(ok) .. " (" .. show(faded) .. ")")
    record("DMS." .. label, status .. "; headers faded=" .. tostring(ok))
    return status, meterState("skin " .. label)
end

local skinWindowsWere

Probe:Steps("meterskin", {
    title = "Glass UI: the damage meter skin (#49)",
    { text = "Turns on script errors and the taint log (Logs\\taint.log), and reads the skin's switch. "
          .. TAINT_NOISE,
      auto = true, run = function()
          skinWindowsWere = meterShownWindows()
          return setCVar("scriptErrors", "1"), setCVar("taintLog", "1"), skinState("start")
      end,
      check = function() local s = skinState("check"); return s == "on", s end },
    { text = "Hit something until bars show in the meter. This step goes on by itself.",
      wait = function() local n = meterBarCount(); return n > 0 and not InCombatLockdown(), n .. " bars" end,
      timeout = 600 },
    { text = "The meter in glass. Press Next for a screenshot.", screenshot = "meter skin",
      check = function() return headersFaded(true) end },
    { text = "Can you read every name and number, and the window titles?", ask = true },
    { text = "In Edit Mode, set the meter's Style to Bordered and close Edit Mode.",
      wait = function() return meterStyle() == "Bordered" and not editMode(), "style " .. show(meterStyle()) end,
      timeout = 600 },
    { text = "Bordered. Press Next for a screenshot.", screenshot = "meter skin, Bordered",
      check = function() return headersFaded(true) end },
    { text = "Now Style Thin.",
      wait = function() return meterStyle() == "Thin" and not editMode(), "style " .. show(meterStyle()) end,
      timeout = 600 },
    { text = "Thin. Press Next for a screenshot.", screenshot = "meter skin, Thin",
      check = function() return headersFaded(true) end },
    { text = "Style back to Default, and Background to 0%.",
      wait = function()
          local bg = meterGet("GetBackgroundAlpha")
          return meterStyle() == "Default" and bg == 0 and not editMode(), "background " .. show(bg)
      end, timeout = 600 },
    { text = "Background 0%: no glass behind the bars. Press Next for a screenshot.",
      screenshot = "meter skin, Background 0" },
    { text = "Background 100%.",
      wait = function() local bg = meterGet("GetBackgroundAlpha"); return bg == 1 and not editMode(), show(bg) end,
      timeout = 600 },
    { text = "Background 100%. Press Next for a screenshot.", screenshot = "meter skin, Background 100" },
    { text = "Background back to 50%, and Transparency to 50%.",
      wait = function()
          local bg, wa = meterGet("GetBackgroundAlpha"), meterGet("GetWindowAlpha")
          return bg == 0.5 and wa == 0.5 and not editMode(), "background " .. show(bg) .. ", window " .. show(wa)
      end, timeout = 600 },
    { text = "Transparency 50%: the whole window, glass included. Press Next for a screenshot.",
      screenshot = "meter skin, Transparency 50" },
    { text = "Transparency back to 100%, then minimize one window with its button.",
      wait = function()
          if meterGet("GetWindowAlpha") ~= 1 or editMode() then return false, "transparency or Edit Mode" end
          for _, w in ipairs(meterWindows()) do
              local ok, v = call(w, "IsMinimized")
              if ok and plain(v) == true then return true end
          end
          return false, "no window minimized"
      end, timeout = 600 },
    { text = "Minimized: only the header strip. Press Next for a screenshot.", screenshot = "meter skin, minimized" },
    { text = "Bring the window back, then Shift-click a bar to pin its breakdown.",
      wait = function() return sourceWindow(true) ~= nil, "no pinned breakdown" end, timeout = 600 },
    { text = "The breakdown. Press Next for a screenshot.", screenshot = "meter skin, breakdown" },
    { text = "Close the breakdown. Switches the skin off, live.", button = "Skin off",
      screenshot = "meter skin off", run = function() return meterSwitch(false), skinState("off") end,
      check = function() return headersFaded(false) end },
    { text = "Does the meter look exactly like Blizzard's own again?", ask = true },
    { text = "While the skin is off, add a window from the meter's gear menu (Skip if you already have three).",
      wait = function()
          local n = meterShownWindows()
          return n > (skinWindowsWere or 1) or n >= MAX_METER_WINDOWS, n .. " windows"
      end, timeout = 600 },
    { text = "Switches the skin on again, live: every window, the new one too.", button = "Skin on",
      screenshot = "meter skin on again", run = function() return meterSwitch(true), skinState("on again") end,
      check = function() return headersFaded(true) end },
    { text = "Reload.", reload = true },
    { text = "After the reload. Press Next for a screenshot.", screenshot = "meter skin, after reload",
      check = function() return headersFaded(true) end },
    { text = "Optional, Skip if it isn't easy: fight something and press Measure while in combat.",
      button = "Measure", run = function() return skinState("combat") end,
      check = function() return InCombatLockdown() and headersFaded(true) end },
    taintOff(),
    { text = "Put the meter back the way you like it (the gear menu hides the extra window). "
          .. "Then reload to save the results.", reload = true },
})

--------------------------------------------------------------------------------
-- The glass bars preview (#49, docs/DAMAGE-METER.md): never shipped. Within
-- the skin contract, so it shows what a later version could really do: each
-- shown bar's Background and BackgroundEdge faded, a small glass panel of ours
-- behind it, Blizzard's fill texture at 0.8. Rows change without scrolling
-- (a session event refreshes the list) and pooled bars are recycled, so every
-- region touched is recorded once with its alpha, and the restore puts back
-- every recorded one, never re-reading the visible rows. Idempotent; also
-- /fp skin meterbars off.
--------------------------------------------------------------------------------

local barsWas = {}        -- region -> its alpha before the preview
local barPanels = {}      -- our panels, by bar
local FILL_ALPHA = 0.8

local function touch(region, alpha)
    local ok, before = call(region, "GetAlpha")
    before = ok and plain(before) or nil
    if type(before) ~= "number" then return false end
    if barsWas[region] == nil then barsWas[region] = before end
    call(region, "SetAlpha", alpha)
    return true
end

local function barsOn()
    local G = glassUI()
    local n = 0
    for _, w in ipairs(meterWindows()) do
        for _, bar in ipairs(meterBars(w)) do
            local sb = rawget(bar, "StatusBar")
            if sb and shownFrame(bar) then
                touch(rawget(sb, "Background"), 0)
                touch(rawget(sb, "BackgroundEdge"), 0)
                local _, fill = call(sb, "GetStatusBarTexture")
                touch(fill, FILL_ALPHA)
                local p = barPanels[bar]
                if not p then
                    p = CreateFrame("Frame", nil, sb)
                    p:SetAllPoints(sb)
                    p:SetFrameLevel(math.max(0, sb:GetFrameLevel() - 1))
                    p:EnableMouse(false)
                    if G and G.Glass and G.Glass.Apply then
                        local ok, err = pcall(G.Glass.Apply, p, "small")
                        if not ok then say("DMB Glass.Apply ERROR " .. show(err)) end
                    end
                    barPanels[bar] = p
                end
                p:Show()
                n = n + 1
            end
        end
    end
    say("DMB on: " .. n .. " bars")
    record("DMB.on", n)
    return n
end

local function barsOff()
    local n = 0
    for region, alpha in pairs(barsWas) do
        call(region, "SetAlpha", alpha)
        n = n + 1
    end
    barsWas = {}
    for _, p in pairs(barPanels) do p:Hide() end
    say("DMB off: " .. n .. " regions put back")
    return n
end

Probe:Steps("meterbars", {
    title = "Glass UI: a glass bars preview for the damage meter",
    { text = "Hit something until bars show in the meter, then stop fighting. This step goes on by itself.",
      wait = function() local n = meterBarCount(); return n > 0 and not InCombatLockdown(), n .. " bars" end,
      timeout = 600 },
    { text = "Puts glass behind each bar shown now (a still picture: new rows stay Blizzard's).",
      button = "Glass bars", run = barsOn, screenshot = "meter, glass bars" },
    { text = "Would you like the meter's bars like this? Say what you'd change in the Note box.", ask = true },
    { text = "Puts every bar back as Blizzard had it.", button = "Put back", run = barsOff,
      screenshot = "meter, bars put back" },
    { text = "Type /reload to save the results.", reload = true },
})
Probe:Command("meterbars", function(args)
    if (args or ""):match("off") then barsOff() else barsOn() end
end, "#49: meterbars on|off: the glass bars preview (off puts every touched bar back)")

--------------------------------------------------------------------------------
-- Discovery: Questie's tracker and RestedXP's guide window and arrow (#56,
-- docs/QUEST-TRACKER.md part 3, "Discovery first"). Measured, never shipped:
--   QS.firstSeen  when each frame first exists, as the procedure's run read
--                 it. SkinProbe loads after both (alphabetical), so "SkinProbe
--                 load" means at their own load or earlier; the engine
--                 attaches at their ADDON_LOADED. The watcher runs every
--                 session and keeps its own QS.seenSession, so a later session
--                 with the addons off again never overwrites the run's result
--                 (Codex, PR #65).
--   QS.hold.<x>   the probe holds every texture of the three at alpha 0 (its
--                 own touch, all put back by Unfade), then after each of their
--                 refreshes reads which came back and which regions are new.
--   QS.coexist    Questie's tracker beside Blizzard's (Questie can hide it).
--   QS.arrow.<x>  RestedXP's arrow: the rotation calls on its texture (a hook
--                 on that instance), its orientation field, its place and
--                 GlassPanel's announced top edge.
-- The three addons are switched on for this character only (the GUID), their
-- enable states saved first in SkinProbeDB.questingWas[GUID] and put back by
-- the last step, or /fp skin questing restore.
--------------------------------------------------------------------------------

TARGETS.questing = { "Questie_BaseFrame", "RXPFrame", "RXPG_ARROW" }
TREE_MAX.questing = 3000
local QUESTING_ADDONS = { "Questie", "QuestieDB", "RXPGuides" }   -- Questie requires QuestieDB
local SEEN_FOR = 120   -- seconds after PLAYER_ENTERING_WORLD to keep looking

-- When each target first exists.
local seen = {}
local seenStart
local function seenCount()
    local n = 0
    for _ in pairs(seen) do n = n + 1 end
    return n
end
local function seenCopy()
    local out = {}
    for k, v in pairs(seen) do out[k] = v end
    return out
end
local function lookFor(where)
    local new = false
    for _, name in ipairs(TARGETS.questing) do
        if not seen[name] and frameByName(name) then seen[name] = where; new = true end
    end
    if new then record("QS.seenSession", seenCopy()) end
    return new
end
lookFor("SkinProbe load")
local seenWatch = CreateFrame("Frame")
Probe:RegisterEvents(seenWatch, { "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD" })
seenWatch:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        lookFor("ADDON_LOADED " .. tostring(name))
        -- Seen before the saved table loaded: kept now, this session's only.
        if name == ADDON and next(seen) then record("QS.seenSession", seenCopy()) end
    elseif event == "PLAYER_LOGIN" then
        lookFor("PLAYER_LOGIN")
    else
        lookFor("PLAYER_ENTERING_WORLD")
        if seenStart then return end
        seenStart = GetTime()
        self:SetScript("OnUpdate", function(f)
            local t = GetTime() - seenStart
            lookFor(string.format("PEW+%.1fs", t))
            if t > SEEN_FOR or seenCount() == #TARGETS.questing then
                f:SetScript("OnUpdate", nil)
            end
        end)
    end
end)

-- Their enable states, for this character only, saved once and put back.
local function questingEnable()
    if type(SkinProbeDB) ~= "table" then return false, "no saved table" end
    local g = guid()
    if not g then return false, "no character GUID" end
    if type(SkinProbeDB.questingWas) ~= "table" then SkinProbeDB.questingWas = {} end
    if type(SkinProbeDB.questingWas[g]) ~= "table" then
        local was = {}
        for _, n in ipairs(QUESTING_ADDONS) do was[n] = enableState(n) end
        SkinProbeDB.questingWas[g] = was
    end
    local ok, parts = true, {}
    for _, n in ipairs(QUESTING_ADDONS) do
        setEnabled(n, true)
        local s = enableState(n)
        ok = ok and s ~= nil and s > 0
        parts[#parts + 1] = n .. "=" .. show(s)
    end
    say("QS enabled " .. table.concat(parts, " "))
    return ok, table.concat(parts, " ")
end

local function questingRestore()
    local g = guid()
    local all = type(SkinProbeDB) == "table" and SkinProbeDB.questingWas
    local was = type(all) == "table" and g and all[g]
    if type(was) ~= "table" then return true, "nothing to restore for this character" end
    local ok, parts = true, {}
    for _, n in ipairs(QUESTING_ADDONS) do
        if type(was[n]) == "number" then
            setEnabled(n, was[n] > 0)
            local s = enableState(n)
            ok = ok and s ~= nil and (s > 0) == (was[n] > 0)
            parts[#parts + 1] = n .. "=" .. show(s)
        end
    end
    all[g] = nil
    say("QS restored " .. table.concat(parts, " "))
    return ok, table.concat(parts, " ")
end

-- The hold test: every texture of the targets at alpha 0, the alpha before
-- kept once per region (with its path) so Unfade puts every one back, however
-- the frames changed meanwhile.
local heldWas = {}       -- region -> { alpha =, path = }
local function eachTexture(fn)
    for _, name in ipairs(TARGETS.questing) do
        local f = frameByName(name)
        if f then
            walk(f, name, 4, function(kind, obj, path)
                if kind ~= "region" then return end
                local _, otype = call(obj, "GetObjectType")
                if plain(otype) == "Texture" then fn(obj, path) end
            end, { n = 0, max = TREE_MAX.questing })
        end
    end
end

local function holdOn()
    if InCombatLockdown() then return false, "not in combat" end
    local n = 0
    eachTexture(function(r, path)
        if not heldWas[r] then
            local ok, a = call(r, "GetAlpha")
            a = ok and plain(a) or nil
            if type(a) ~= "number" then return end
            heldWas[r] = { alpha = a, path = path }
        end
        call(r, "SetAlpha", 0)
        n = n + 1
    end)
    say("QS hold on: " .. n .. " textures at 0")
    return n > 0, n .. " textures"
end

-- Which held textures came back, and which textures are new since the hold.
local function holdCheck(label)
    local back, new = {}, {}
    for r, s in pairs(heldWas) do
        local ok, a = call(r, "GetAlpha")
        a = ok and plain(a) or nil
        if a ~= 0 then back[#back + 1] = s.path .. "=" .. num(a) end
    end
    eachTexture(function(r, path)
        if not heldWas[r] then new[#new + 1] = path end
    end)
    table.sort(back); table.sort(new)
    local rec = { back = #back, new = #new, backList = table.concat(back, ", "), newList = table.concat(new, ", ") }
    say("QS hold " .. label .. ": " .. #back .. " back (" .. rec.backList .. "); " .. #new .. " new ("
        .. rec.newList .. ")")
    record("QS.hold." .. label, rec)
    return #back, #new
end

local function holdOff()
    local n = 0
    for r, s in pairs(heldWas) do
        call(r, "SetAlpha", s.alpha)
        heldWas[r] = nil
        n = n + 1
    end
    say("QS hold off: " .. n .. " textures put back")
    return true, n .. " put back"
end

local function shownName(name) return shownFrame(frameByName(name)) end

-- Questie's tracker beside Blizzard's.
local function coexist()
    local blizz = frameByName("ObjectiveTrackerFrame")
    local okA, a = call(blizz, "GetAlpha")
    local rec = { questie = shownName("Questie_BaseFrame"), blizzard = shownFrame(blizz),
                  blizzardAlpha = okA and plain(a) or nil, rxp = shownName("RXPFrame"), arrow = shownName("RXPG_ARROW") }
    say("QS coexist: Questie " .. tostring(rec.questie) .. ", Blizzard's " .. tostring(rec.blizzard) .. " (alpha "
        .. num(rec.blizzardAlpha) .. "), RestedXP window " .. tostring(rec.rxp) .. ", arrow " .. tostring(rec.arrow))
    record("QS.coexist", rec)
    return rec
end

-- The arrow: its texture's SetRotation calls, counted from a hook on that
-- texture (never on RestedXP's code), its orientation field, its place, and
-- GlassPanel's top edge to compare.
local arrowSeen = { calls = 0 }
local function arrowHook()
    if arrowSeen.hooked then return true end
    local af = frameByName("RXPG_ARROW")
    local tex = af and rawget(af, "texture")
    if type(tex) ~= "table" or type(tex.SetRotation) ~= "function" then return false end
    hooksecurefunc(tex, "SetRotation", function(_, angle)
        arrowSeen.calls = arrowSeen.calls + 1
        arrowSeen.last = plain(angle)
    end)
    arrowSeen.hooked = true
    return true
end

local function arrowState(label)
    arrowHook()
    local af = frameByName("RXPG_ARROW")
    local rec = { calls = arrowSeen.calls, last = arrowSeen.last, shown = shownFrame(af) }
    rec.orientation = af and plain(rawget(af, "orientation")) or nil
    local okP, point, rel, relPoint, x, y = call(af, "GetPoint", 1)
    if okP then
        rec.point = plain(point)
        rec.relPoint = plain(relPoint)
        rec.x, rec.y = plain(x), plain(y)
        local okN, relName = call(rel, "GetName")
        rec.rel = okN and plain(relName) or nil
    end
    local okT, top = call(af, "GetTop")
    local okU, uiTop = call(UIParent, "GetTop")
    top, uiTop = okT and plain(top) or nil, okU and plain(uiTop) or nil
    if type(top) == "number" and type(uiTop) == "number" then rec.fromTop = uiTop - top end
    local GP = rawget(_G, "GlassPanel")
    local okE, edge = pcall(function() return GP.EdgeState() end)
    rec.panelEdge = okE and type(edge) == "table" and plain(edge.top) or nil
    say("QS arrow " .. label .. ": shown=" .. tostring(rec.shown) .. " rotations=" .. rec.calls .. " last="
        .. num(rec.last) .. " orientation=" .. num(rec.orientation) .. " point=" .. show(rec.point) .. " "
        .. show(rec.rel) .. " " .. show(rec.relPoint) .. " " .. num(rec.x) .. "," .. num(rec.y) .. " fromTop="
        .. num(rec.fromTop) .. " GlassPanel edge=" .. num(rec.panelEdge))
    record("QS.arrow." .. label, rec)
    return rec
end

local function allLoaded()
    local missing = {}
    for _, n in ipairs(QUESTING_ADDONS) do
        if not loaded(n) then missing[#missing + 1] = n end
    end
    return #missing == 0, #missing == 0 and "all loaded" or ("not loaded: " .. table.concat(missing, ", "))
end

-- One refresh's result, then the baseline re-armed: every texture at 0 again,
-- the new ones included (their alpha now kept as their first), so the next
-- refresh reports only what it changed itself (Codex, PR #65).
local function holdMeasure(label)
    return function()
        local back, new = holdCheck(label)
        holdOn()
        return back, new
    end
end

Probe:Steps("questing", {
    title = "Glass UI: discovery for Questie's tracker and RestedXP's guide window and arrow (#56)",
    { text = "Turns on script errors and reads which of Questie, QuestieDB and RestedXP are loaded. The procedure "
          .. "turns them on for this character only and puts them back at the end.",
      auto = true, run = function() return setCVar("scriptErrors", "1"), allLoaded() end },
    { text = "Turns on Questie, QuestieDB and RestedXP for this character (their states are saved first).",
      button = "Enable", run = questingEnable },
    { text = "Reload. If Questie or RestedXP open a welcome or setup window, close it or pick the defaults.",
      reload = true },
    { text = "Reads when each frame first appeared, and checks all three loaded.", auto = true,
      run = function()
          lookFor("now")
          record("QS.firstSeen", seenCopy())
          return seenCount()
      end,
      check = allLoaded },
    { text = "Track a quest so Questie's tracker shows (accept one if your log is empty).",
      wait = function() return shownName("Questie_BaseFrame"), "Questie's tracker isn't shown" end, timeout = 600 },
    { text = "Pick a leveling guide in RestedXP so its guide window shows.",
      wait = function() return shownName("RXPFrame"), "RestedXP's window isn't shown" end, timeout = 600 },
    -- Only now: Questie builds its tracker in a staged startup after login, and
    -- RestedXP fills its step frames once a guide is picked (Codex, PR #65).
    { text = "Logs the frame trees of Questie's tracker, RestedXP's window and its arrow, now that they're built, "
          .. "and keeps when each first appeared (Questie's tracker comes late in its startup).",
      auto = true, run = function()
          -- The run's result, final: the waits above let late frames appear
          -- (Codex, PR #65). The step after the reload kept an early copy.
          lookFor("now")
          record("QS.firstSeen", seenCopy())
          return tree("questing", 4)
      end,
      check = function()
          local missing = {}
          for _, name in ipairs(TARGETS.questing) do
              if not frameByName(name) then missing[#missing + 1] = name end
          end
          return #missing == 0, #missing == 0 and "all three" or ("missing: " .. table.concat(missing, ", "))
      end },
    { text = "Reads whether Blizzard's tracker shows beside Questie's.", auto = true,
      run = function() return coexist().blizzard end },
    { text = "Press Next for a screenshot of both as they come.", screenshot = "questing, as it comes" },
    { text = "Do you see both trackers, Questie's and Blizzard's 'All Objectives'? Say which in the Note.", ask = true },
    { text = "Holds every texture of the three at 0 (the probe's own touch; Unfade puts them back).",
      button = "Fade", run = holdOn, screenshot = "questing, held at 0" },
    { text = "Move the mouse over Questie's tracker and away again (its fader), then press Measure.",
      button = "Measure", run = holdMeasure("questie fader") },
    { text = "Make progress on a quest, or accept or abandon one, so Questie's tracker updates. Then Measure.",
      button = "Measure", run = holdMeasure("questie update") },
    { text = "In Questie's options (Tracker), switch its background off and on again, if it has the choice. Then "
          .. "Measure (Skip if there's no such option).", button = "Measure", run = holdMeasure("questie background") },
    { text = "In RestedXP's window, go to the next step (or skip one). Then Measure.", button = "Measure",
      run = holdMeasure("rxp step") },
    { text = "If RestedXP's options have a theme or window style, change it and change it back. Then Measure "
          .. "(Skip if not).", button = "Measure", run = holdMeasure("rxp theme") },
    { text = "Reload the guide view: close RestedXP's window and open it again (its minimize or /rxp). Then "
          .. "Measure.", button = "Measure", run = holdMeasure("rxp reopen"), screenshot = "questing, after refreshes" },
    { text = "Puts every texture back as it was.", button = "Unfade", run = holdOff },
    { text = "Follow a guide step with a destination so RestedXP's arrow shows, and turn around a few times.",
      wait = function()
          local rec = arrowState("waiting")
          return rec.shown and rec.calls >= 5, rec.calls .. " rotations"
      end, timeout = 600, screenshot = "questing, the arrow" },
    { text = "Reads the arrow's place against Glass Panel's top edge.", auto = true,
      run = function() return arrowState("place").fromTop end },
    { text = "Is the arrow over Glass Panel's bar or its zoomed XP bar right now? Say where in the Note.", ask = true },
    { text = "Did anything look broken in Questie or RestedXP during this run (beyond the faded art)?", ask = true },
    { text = "Puts back which of the three were enabled for this character.", button = "Restore",
      run = questingRestore },
    { text = "Type /reload to save the results (and unload them, if they were off before).", reload = true },
})

Probe:Command("questing", function(args)
    args = args or ""
    if args:match("restore") then questingRestore()
    elseif args:match("unfade") then holdOff()
    else
        say("QS first seen this session: " .. (next(seen) and "" or "nothing yet"))
        for name, where in pairs(seen) do say("  " .. name .. ": " .. where) end
        coexist()
        arrowState("now")
    end
end, "#56: Questie and RestedXP: first seen, side by side, the arrow (restore: enable states; unfade: textures)")

--------------------------------------------------------------------------------
-- Acceptance: RestedXP's guide window and arrow in glass (#56,
-- docs/RESTEDXP.md), run after launch (2026-11-04). Saved as RX.<label>
-- (the window) and RA.<label> (the arrow). RestedXP is switched on for this
-- character only, its state saved in SkinProbeDB.rxpWas[GUID] and put back by
-- the last step (/fp skin rxpglass restore).
--------------------------------------------------------------------------------

local RXP_PIECES = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "TopEdge",
                     "BottomEdge", "LeftEdge", "RightEdge", "Center" }

local function rxpEnable(on)
    if type(SkinProbeDB) ~= "table" then return false, "no saved table" end
    local g = guid()
    if not g then return false, "no character GUID" end
    if type(SkinProbeDB.rxpWas) ~= "table" then SkinProbeDB.rxpWas = {} end
    if on then
        if SkinProbeDB.rxpWas[g] == nil then SkinProbeDB.rxpWas[g] = enableState("RXPGuides") or 0 end
        setEnabled("RXPGuides", true)
        local s = enableState("RXPGuides")
        return s ~= nil and s > 0, "RXPGuides=" .. show(s)
    end
    local was = SkinProbeDB.rxpWas[g]
    if type(was) ~= "number" then return true, "nothing to restore for this character" end
    setEnabled("RXPGuides", was > 0)
    SkinProbeDB.rxpWas[g] = nil
    return true, "RXPGuides=" .. show(enableState("RXPGuides"))
end

-- Pieces of a backdrop frame not at alpha 0 (those that exist).
local function piecesUp(f)
    local n = 0
    for _, k in ipairs(RXP_PIECES) do
        local p = f and rawget(f, k)
        local ok, a = call(p, "GetAlpha")
        if ok and plain(a) ~= 0 then n = n + 1 end
    end
    return n
end

-- The guide window: our glass, the three's pieces, the shown rows' fills and
-- hosts, the shown cards' glass and pieces, the track, V2 and the collapse.
local function rxState(label)
    local G = glassUI()
    local T = G and G.RestedXP and G.RestedXP._test
    local f = frameByName("RXPFrame")
    local rec = { shown = visible(f), installed = false, piecesUp = 0, rows = 0, rowsRight = 0, cards = 0,
                  cardsRight = 0 }
    rec.blocked = type(SkinProbeDB) == "table" and SkinProbeDB.suiteBlocked or 0
    local okC, c = pcall(InCombatLockdown)
    rec.combat = okC and plain(c) == true
    local h = T and f and T.wins[f]
    if h then
        rec.installed = true
        rec.glass = visible(h.win)
        rec.track = h.track ~= nil and visible(h.track.fill)
        rec.list = visible(h.list)
        rec.header = visible(h.name)
        for _, p in ipairs({ h.name, h.list, h.footer }) do rec.piecesUp = rec.piecesUp + piecesUp(p) end
        local okB, b = call(h.name.bg, "GetAlpha")
        rec.banner = okB and plain(b) or nil
    end
    local child = f and rawget(f, "ScrollChild")
    for _, row in ipairs(type(child) == "table" and type(rawget(child, "framePool")) == "table" and child.framePool or {}) do
        if visible(row) then
            rec.rows = rec.rows + 1
            local okA, a = call(row, "GetAlpha")
            if piecesUp(row) == 0 and T and T.rows[row] ~= nil and okA and plain(a) ~= 0 then
                rec.rowsRight = rec.rowsRight + 1
            elseif okA and plain(a) == 0 then
                rec.rowsRight = rec.rowsRight + 1                     -- RestedXP's hidden step: its alpha 0
            end
        end
    end
    local steps = f and rawget(f, "CurrentStepFrame")
    for _, card in ipairs(type(steps) == "table" and type(rawget(steps, "framePool")) == "table" and steps.framePool or {}) do
        if visible(card) then
            rec.cards = rec.cards + 1
            local st = T and T.cards[card]
            local number = rawget(card, "number")
            if st and visible(st.glass) and piecesUp(card) == 0 and piecesUp(number) == 0 then
                rec.cardsRight = rec.cardsRight + 1
            end
        end
    end
    say("RX " .. label .. ": shown " .. tostring(rec.shown) .. ", installed " .. tostring(rec.installed) .. ", glass "
        .. tostring(rec.glass) .. ", pieces up " .. rec.piecesUp .. ", banner " .. num(rec.banner) .. ", rows "
        .. rec.rowsRight .. "/" .. rec.rows .. ", cards " .. rec.cardsRight .. "/" .. rec.cards .. ", track "
        .. tostring(rec.track) .. ", list " .. tostring(rec.list) .. ", combat " .. tostring(rec.combat) .. ", "
        .. rec.blocked .. " blocked")
    record("RX." .. label, rec)
    return rec
end

-- want: rows (some read), collapsed (the list hidden: the track with it).
local function rxOn(label, want)
    want = want or {}
    return function()
        local r = rxState(label)
        local bad = {}
        local function want_(cond, why) if not cond then bad[#bad + 1] = why end end
        want_(r.shown, "the window not shown")
        want_(r.installed, "not installed")
        want_(r.glass, "our glass not shown")
        want_(r.piecesUp == 0, r.piecesUp .. " backdrop pieces up")
        want_(r.banner == 0, "the banner " .. num(r.banner))
        if want.rows then want_(r.rows > 0, "no row read") end
        want_(r.rowsRight == r.rows, "rows " .. r.rowsRight .. " of " .. r.rows)
        want_(r.cardsRight == r.cards, "cards " .. r.cardsRight .. " of " .. r.cards)
        if want.collapsed then
            want_(not r.list and not r.track, "the list or track still shown")
        elseif want.collapsed == false then
            want_(r.list and r.track, "the list or track hidden")
        end
        want_(r.blocked == 0, r.blocked .. " blocked")
        return #bad == 0, #bad == 0 and "in glass" or table.concat(bad, "; ")
    end
end

-- The arrow: RestedXP's texture, ours, both angles, our colour against the
-- accent, the pill against the text.
local function raState(label)
    local G = glassUI()
    local T = G and G.RestedXP and G.RestedXP._test
    local af = frameByName("RXPG_ARROW")
    local rec = { shown = visible(af) }
    local okF, fa = call(af, "GetAlpha")
    rec.frameAlpha = okF and plain(fa) or nil
    local tex = af and rawget(af, "texture")
    local okT, ta = call(tex, "GetAlpha")
    rec.theirs = okT and plain(ta) or nil
    local okR, rad = call(tex, "GetRotation")
    rec.theirAngle = okR and plain(rad) or nil
    local st = T and af and T.arrows[af]
    if st then
        rec.ours = visible(st.frame)
        local okO, o = call(st.arrow, "GetRotation")
        rec.ourAngle = okO and plain(o) or nil
        local okV, r, g, b = call(st.arrow, "GetVertexColor")
        local c = G.Suite and G.Suite.Accent and G.Suite.Accent()
        rec.accent = okV and type(c) == "table" and math.abs((plain(r) or -1) - c[1]) < 0.01
            and math.abs((plain(g) or -1) - c[2]) < 0.01 and math.abs((plain(b) or -1) - c[3]) < 0.01
        if st.pill then
            local okW, w = call(st.text, "GetStringWidth")
            local okP, pw = call(st.pill, "GetWidth")
            w, pw = okW and plain(w) or nil, okP and plain(pw) or nil
            rec.textWidth, rec.pillWidth = w, pw
            rec.pillFits = type(w) == "number" and type(pw) == "number" and math.abs(pw - w - 2 * T.PILL_PAD[1]) < 1
        end
    end
    say("RA " .. label .. ": shown " .. tostring(rec.shown) .. " (alpha " .. num(rec.frameAlpha) .. "), theirs "
        .. num(rec.theirs) .. " at " .. num(rec.theirAngle) .. ", ours " .. tostring(rec.ours) .. " at "
        .. num(rec.ourAngle) .. ", accent " .. tostring(rec.accent) .. ", pill " .. num(rec.pillWidth) .. " for "
        .. num(rec.textWidth))
    record("RA." .. label, rec)
    return rec
end

local function raOn(label)
    return function()
        local r = raState(label)
        local bad = {}
        local function want_(cond, why) if not cond then bad[#bad + 1] = why end end
        want_(r.shown, "the arrow not shown")
        want_(r.theirs == 0, "RestedXP's arrow at " .. num(r.theirs))
        want_(r.ours, "ours not shown")
        want_(type(r.ourAngle) == "number" and type(r.theirAngle) == "number"
              and math.abs(r.ourAngle - r.theirAngle) < 0.001, "angles " .. num(r.ourAngle) .. " / " .. num(r.theirAngle))
        want_(r.accent, "not the accent")
        want_(r.pillFits, "the pill " .. num(r.pillWidth) .. " for text " .. num(r.textWidth))
        return #bad == 0, #bad == 0 and "ours, turned with RestedXP's" or table.concat(bad, "; ")
    end
end

local function rxSwitch(key, on)
    local G = glassUI()
    if not (G and G.Engine) then return false, "Glass UI not loaded" end
    G.Engine.SetEnabled(key, on)
    return true, key .. " " .. (on and "on" or "off")
end

local function rxAccent(name)
    return function()
        local G = glassUI()
        if not (G and G.Suite and G.Suite.SetLook) then return false, "Glass UI not loaded" end
        G.Suite.SetLook("accent", name)
        return true, name
    end
end

Probe:Steps("rxpglass", {
    title = "Glass UI: RestedXP's guide window and arrow in glass (#56)",
    rev = 1,
    { text = "Turns on script errors and counts blocked actions from now.", auto = true,
      run = function()
          if type(SkinProbeDB) == "table" then SkinProbeDB.suiteBlocked = 0 end
          return setCVar("scriptErrors", "1")
      end },
    { text = "Turns on RestedXP for this character (its state is saved first, and put back at the end).",
      button = "Enable", run = function() return rxpEnable(true) end },
    { text = "Reload. If RestedXP opens a welcome or setup window, close it or pick the defaults.", reload = true },
    { text = "Pick a leveling guide in RestedXP so its guide window shows (its default window, not the beta "
          .. "\"V2\" one).", timeout = 600,
      wait = function() return shownName("RXPFrame"), "RestedXP's window isn't shown" end },
    { text = "Press Next for a screenshot of the window.", screenshot = "rxp, the window",
      check = rxOn("look", { rows = true }) },
    { text = "Does it read like the mockup: the current step on its own smoky glass, the window in smoky glass with "
          .. "a band under the guide's title and a hairline, a hairline between steps, the scroll bar on a dark "
          .. "track, the footer under a hairline? Anything off: the Note.", ask = true },
    { text = "Complete or skip a step (right-click a step > Go to step, or RestedXP's skip). Then press Next.",
      check = rxOn("new step", { rows = true }) },
    { text = "Move the mouse over a few steps in the list and away. Press Next.", check = rxOn("hovered") },
    { text = "In RestedXP's options, change its theme (or window colour) and change it back. Press Next.",
      check = rxOn("theme") },
    { text = "Resize the window by its bottom-right corner while the list scrolls, then scroll it. Press Next.",
      check = rxOn("resized") },
    { text = "Collapse the list (RestedXP's option to show the step list off, or a guide that hides it). Press "
          .. "Next with only the header and footer showing.", screenshot = "rxp, collapsed",
      check = rxOn("collapsed", { collapsed = true }) },
    { text = "Show the list again. Press Next.", check = rxOn("expanded", { collapsed = false }) },
    -- The arrow.
    { text = "Follow a step with a destination so RestedXP's arrow shows, and turn around a few times.",
      timeout = 600, screenshot = "rxp, the arrow",
      wait = function()
          local r = raState("waiting")
          return r.shown and r.ours == true, "the arrow isn't shown"
      end, check = raOn("turning") },
    { text = "Does the arrow read like the mockup: a glassy arrowhead in the suite accent, the step and distance on "
          .. "a smoky pill under it? Does it turn smoothly with you? The Note.", ask = true },
    { text = "Standing still, change RestedXP's arrow text size in its options. Press Next.",
      check = raOn("text size") },
    { text = "Switches the suite accent to ice.", button = "Ice", run = rxAccent("ice"), check = raOn("ice") },
    { text = "And back to gold.", button = "Gold", run = rxAccent("gold"), check = raOn("gold") },
    { text = "If you can, go to another continent than the step's destination (a portal, a boat): RestedXP sets "
          .. "the arrow straight up. Press Next (Skip if you can't).", check = raOn("other continent") },
    -- Off and on, combat.
    { text = "Switches both skins off (RestedXP's look).", button = "Skins off", screenshot = "rxp, skins off",
      run = function() rxSwitch("rxp", false); return rxSwitch("rxparrow", false) end,
      check = function()
          local w, a = rxState("off"), raState("off")
          local ok = w.piecesUp > 0 and not w.glass and a.theirs ~= 0 and not a.ours
          return ok, ok and "RestedXP's look, nothing of ours" or "something of ours while off"
      end },
    { text = "Switches both on again.", button = "Skins on",
      run = function() rxSwitch("rxp", true); return rxSwitch("rxparrow", true) end },
    { text = "Wait a second, then press Next.", check = function()
          local okW, whyW = rxOn("on again")()
          local okA, whyA = raOn("on again")()
          return okW and okA, whyW .. "; " .. whyA
      end },
    { text = "Get into combat with the window and the arrow up, and complete a step if you can. Press Next while "
          .. "still in combat.", check = rxOn("combat") },
    { text = "Did anything look broken in RestedXP during this run (beyond its look)? The Note.", ask = true },
    { text = "Puts back whether RestedXP was enabled for this character.", button = "Restore",
      run = function() return rxpEnable(false) end },
    { text = "Type /reload to save the results (and unload RestedXP, if it was off before).", reload = true },
})

Probe:Command("rxpglass", function(args)
    if (args or ""):match("restore") then rxpEnable(false) return end
    rxState("now")
    raState("now")
end, "#56: RestedXP in glass: the window and arrow now (restore: RestedXP's enable state)")

--------------------------------------------------------------------------------
-- The mirror timers (docs/MIRROR-TIMERS.md): each shown timer frame against
-- what the skin should have done, with the levels and the fill's colour; a
-- restart while shown, counted by a SetupTimer hook of the probe's own. That
-- hook goes in before Glass UI's (installed at the first timer's show), so it
-- runs first: it reads the fill's colour as Blizzard's Setup left it, before
-- our tint. Saved as MT.<label>. In a function of its own: the main chunk is
-- at Lua 5.1's 200 locals (a do block's count toward them).
--------------------------------------------------------------------------------

;(function()
-- IsVisible, read plain (the file's `seen` is a table by here: the questing
-- watch's).
local function visible(f)
    local ok, v = call(f, "IsVisible")
    return ok and plain(v) == true
end

local mtSetups, mtHooked, mtLastFill = 0, false, {}

local function mtTest()
    local G = glassUI()
    return G and G.MirrorTimers and G.MirrorTimers._test
end

local function mtFrames()
    local c = frameByName("MirrorTimerContainer")
    return c, (c and type(c.mirrorTimers) == "table") and c.mirrorTimers or {}
end

local function mtFill(f)
    local ok, fill = call(f and f.StatusBar, "GetStatusBarTexture")
    return ok and type(fill) == "table" and fill or nil
end

local function mtColour(fill)
    local okD, d = call(fill, "IsDesaturated")
    local okV, r, g, b, a = call(fill, "GetVertexColor")
    return { desat = okD and plain(d) == true or false, r = okV and plain(r) or nil, g = okV and plain(g) or nil,
             b = okV and plain(b) or nil, a = okV and plain(a) or nil }
end

-- The probe's own hooks (a dev tool's, never the skin's): a count of
-- SetupTimer, and each start's fill as Blizzard leaves it, with whether it is
-- a new texture object. The fill is read in a hook on each bar's
-- SetStatusBarTexture: Setup calls it before UpdateShownState, so before the
-- engine's OnShow styling and the skin's SetupTimer hook, whichever was
-- installed first (Codex, PR #186). Installed at the probe's load, so the
-- start a /reload underwater replays is seen too.
local function mtHook()
    if mtHooked then return true end
    local c, list = mtFrames()
    if not (c and type(c.SetupTimer) == "function") then return false end
    mtHooked = true
    hooksecurefunc(c, "SetupTimer", function() mtSetups = mtSetups + 1 end)
    for _, f in ipairs(list) do
        local bar = f.StatusBar
        if type(bar) == "table" and type(bar.SetStatusBarTexture) == "function" then
            hooksecurefunc(bar, "SetStatusBarTexture", function()
                local fill = mtFill(f)
                local id = fill and tostring(fill) or nil
                local rec = mtColour(fill)
                rec.firstSeen = mtLastFill[f] == nil
                rec.newObject = mtLastFill[f] ~= nil and mtLastFill[f] ~= id
                mtLastFill[f] = id
                record("MT.baseline " .. tostring(plain(f.timer)), rec)
            end)
        end
    end
    return true
end
mtHook()

local function mtLayer(r)
    local ok, layer, sub = call(r, "GetDrawLayer")
    return ok and (tostring(plain(layer)) .. " " .. tostring(plain(sub))) or nil
end

local function mtLevel(f)
    local ok, l = call(f, "GetFrameLevel")
    return ok and plain(l) or nil
end

-- One shown frame: its textures' alphas, the fill, our pieces and the levels.
local function mtFrameState(f, T)
    local s = { timer = plain(f.timer), textures = 0, faded = 0 }
    local ok, regions = pcall(function() return { f:GetRegions() } end)
    for _, r in ipairs(ok and regions or {}) do
        local okT, t = call(r, "GetObjectType")
        if okT and plain(t) == "Texture" then
            s.textures = s.textures + 1
            local okA, a = call(r, "GetAlpha")
            if okA and plain(a) == 0 then s.faded = s.faded + 1 end
        end
    end
    local fill = mtFill(f)
    s.fill = mtColour(fill)
    s.fillObject = fill and tostring(fill) or nil
    s.frameLevel, s.barLevel = mtLevel(f), mtLevel(f.StatusBar)
    local okS, strata = call(f, "GetFrameStrata")
    s.strata = okS and plain(strata) or nil
    s.labelLayer = mtLayer(f.Text)
    local p = T and T.pills[f]
    if p then
        s.pill = visible(p.glass)
        s.pillLevel = mtLevel(p.glass)
        s.rimLevel = p.g and p.g.top and mtLevel(p.g.top) or nil
        if p.track then
            local okP, parent = call(p.track.fill, "GetParent")
            s.trackOnPill = okP and parent == p.glass
            s.trackLayer = mtLayer(p.track.fill)
            s.track = visible(p.track.fill)
        end
    end
    local want = T and s.timer and T.COLORS[s.timer]
    if want then
        s.want = want
        s.tinted = s.fill.desat and type(s.fill.r) == "number" and math.abs(s.fill.r - want[1]) < 0.01
            and math.abs(s.fill.g - want[2]) < 0.01 and math.abs(s.fill.b - want[3]) < 0.01
    end
    return s
end

local function mtState(label)
    local c, list = mtFrames()
    local T = mtTest()
    local rec = { blocked = type(SkinProbeDB) == "table" and SkinProbeDB.suiteBlocked or 0, setups = mtSetups,
                  containerShown = visible(c), containerLevel = mtLevel(c), frames = {} }
    local okS, strata = call(c, "GetFrameStrata")
    rec.containerStrata = okS and plain(strata) or nil
    for i, f in ipairs(list) do
        if visible(f) then rec.frames[#rec.frames + 1] = mtFrameState(f, T); rec.frames[#rec.frames].index = i end
    end
    record("MT." .. label, rec)
    say("MT " .. label .. ": " .. #rec.frames .. " shown, " .. rec.setups .. " setups, " .. rec.blocked .. " blocked")
    return rec
end

-- Styled: each shown frame's textures faded, the pill and track shown under
-- the bar, and a running timer's fill in its colour (opts.timer: one must be
-- running; opts.tint = false: the colour not checked, Edit Mode's previews).
local function mtOn(label, opts)
    opts = opts or {}
    return function()
        local r = mtState(label)
        local bad = {}
        local function want_(cond, why) if not cond then bad[#bad + 1] = why end end
        want_(#r.frames > 0, "no timer shown")
        local running = false
        for _, s in ipairs(r.frames) do
            local n = "frame " .. s.index
            running = running or s.timer ~= nil
            want_(s.textures > 0 and s.faded == s.textures, n .. ": " .. s.faded .. "/" .. s.textures .. " faded")
            want_(s.pill, n .. ": the pill not shown")
            want_(s.track and s.trackOnPill, n .. ": the track not on the pill")
            want_(type(s.pillLevel) == "number" and type(s.barLevel) == "number" and s.pillLevel < s.barLevel,
                  n .. ": the pill at " .. num(s.pillLevel) .. ", the bar at " .. num(s.barLevel))
            want_(s.rimLevel == nil or (type(s.barLevel) == "number" and s.rimLevel < s.barLevel),
                  n .. ": the rim at " .. num(s.rimLevel))
            if opts.tint ~= false and s.want then want_(s.tinted, n .. ": the fill not in " .. s.timer .. "'s colour") end
        end
        if opts.timer then want_(running, "no timer running") end
        want_(r.blocked == 0, r.blocked .. " blocked")
        return #bad == 0, #bad == 0 and (#r.frames .. " on glass") or table.concat(bad, "; ")
    end
end

local function mtOff(label)
    return function()
        local r = mtState(label)
        local bad = {}
        for _, s in ipairs(r.frames) do
            if s.faded > 0 then bad[#bad + 1] = "frame " .. s.index .. ": " .. s.faded .. " faded" end
            if s.fill.desat then bad[#bad + 1] = "frame " .. s.index .. ": the fill tinted" end
            if s.pill then bad[#bad + 1] = "frame " .. s.index .. ": the pill shown" end
        end
        if #r.frames == 0 then bad[#bad + 1] = "no timer shown" end
        return #bad == 0, #bad == 0 and "Blizzard's look, nothing of ours" or table.concat(bad, "; ")
    end
end

local function mtShown(timer)
    local _, list = mtFrames()
    for _, f in ipairs(list) do
        if visible(f) and plain(f.timer) == timer then return f end
    end
    return nil
end

local function mtWait(timer)
    return function()
        mtHook()
        return mtShown(timer) ~= nil, "waiting for the " .. timer .. " bar"
    end
end

-- A restart while the bar stays up: a SetupTimer counted after the bar was
-- seen, with the bar seen at every poll since (ForeverProbe polls each
-- second). A poll without it starts over.
local function mtRestartWait()
    local isNew = attempt()
    local base
    return function()
        mtHook()
        if isNew() then base = nil end
        if not mtShown("BREATH") then base = nil return false, "waiting for the breath bar" end
        if base == nil then base = mtSetups return false, "the bar is up: surface briefly and dive again" end
        if mtSetups > base then
            record("MT.restart", { setups = mtSetups - base })
            return true, "restarted while shown"
        end
        return false, "waiting for a restart while the bar stays up"
    end
end

local function mtSwitch(on)
    local G = glassUI()
    if not (G and G.Engine) then return false, "Glass UI not loaded" end
    G.Engine.SetEnabled("mirror", on)
    return true, "mirror " .. (on and "on" or "off")
end

-- Glass Unit Frames' timers on: Blizzard's never show, so none of ours.
local function mtNoneOfOurs(label)
    return function()
        local r = mtState(label)
        local T = mtTest()
        local ours = 0
        local _, list = mtFrames()
        for _, f in ipairs(list) do
            local p = T and T.pills[f]
            if p and visible(p.glass) then ours = ours + 1 end
        end
        local ok = #r.frames == 0 and ours == 0
        return ok, ok and "Blizzard's hidden, none of ours" or (#r.frames .. " of Blizzard's shown, " .. ours .. " of ours")
    end
end

-- Blizzard's container listens for timers: Glass Unit Frames' own timers
-- (its Blizzard.HideFrame at load) unregister its events, and then
-- Blizzard's never show (run #338: every dive measured GUF's bar).
local function mtLive()
    local c = mtFrames()
    local ok, on = call(c, "IsEventRegistered", "MIRROR_TIMER_START")
    return ok and plain(on) == true
end

Probe:Steps("mirrorglass", {
    title = "Glass UI: the breath, fatigue and feign death timers in glass",
    rev = 2,
    { text = "Turns on script errors and counts blocked actions from now. Be near water you can dive into.",
      auto = true,
      run = function()
          if type(SkinProbeDB) == "table" then SkinProbeDB.suiteBlocked = 0 end
          return setCVar("scriptErrors", "1")
      end },
    { text = "If Glass Unit Frames is installed: in its settings, untick \"Glass breath and fatigue bars\" (its own "
          .. "bars hide Blizzard's, which are what this tests). Then press Next." },
    { text = "Type /reload, out of the water.", reload = true },
    { text = "Turns the taint log on (a reload turns it off). " .. TAINT_NOISE, auto = true,
      run = function() mtHook(); return setCVar("taintLog", "1") end },
    { text = "Checks that Blizzard's timers are live. If this doesn't go on by itself, another addon hides them "
          .. "(Glass Unit Frames' bars still on): press Stop, untick them, and start again.", timeout = 15,
      wait = function()
          local on = mtLive()
          record("MT.live", on)
          return on, "Blizzard's timer bars hidden by another addon"
      end },
    { text = "Swim underwater until the breath bar shows. This step goes on by itself; a screenshot is taken.",
      timeout = 600, wait = mtWait("BREATH"), screenshot = "mirror, breath",
      check = mtOn("breath", { timer = true }) },
    { text = "Surface for a moment and dive again before the bar fills back up, so it never goes away. This step "
          .. "goes on by itself once the bar restarted while still shown.", timeout = 600,
      wait = mtRestartWait(), check = mtOn("restart", { timer = true }) },
    { text = "Stay under until the bar is about half down, then press Next (a screenshot: the groove and the fill "
          .. "both show).", screenshot = "mirror, half", check = mtOn("half", { timer = true }) },
    { text = "Does it read right: the bar on a small glass pill, a dark groove under its blue fill, the label "
          .. "\"Breath\" under it on the glass, no castbar frame? Anything off: the Note.", ask = true },
    { text = "Still underwater: switches the skin off (Blizzard's look).", button = "Skin off",
      screenshot = "mirror, skin off", run = function() return mtSwitch(false) end, check = mtOff("off") },
    { text = "Switches it on again.", button = "Skin on", run = function() return mtSwitch(true) end,
      check = mtOn("on again", { timer = true }) },
    { text = "Underwater with the bar up, type /reload.", reload = true },
    { text = "Turns the taint log on again.", auto = true,
      run = function() mtHook(); return setCVar("taintLog", "1") end },
    { text = "Stay under until the bar shows again (or dive again), then press Next.", timeout = 600,
      wait = mtWait("BREATH"), check = mtOn("after reload", { timer = true }) },
    -- Edit Mode, then combat.
    { text = "Surface and wait for the bar to go. Open Edit Mode and tick Duration Bars (Blizzard's name for the "
          .. "timers) if it isn't, so the three bars "
          .. "show. Press Next with Edit Mode open (a screenshot).", screenshot = "mirror, edit mode",
      check = mtOn("edit mode", { tint = false }) },
    { text = "Move the Duration Bars and Save. Move them again, then Revert Changes, and close Edit Mode. Press Next.",
      check = function() local r = mtState("edit mode closed"); return r.blocked == 0, r.blocked .. " blocked" end },
    { text = "Get into combat and use a few abilities from your action bars. Press Next while still in combat.",
      check = function()
          local okC, c = pcall(InCombatLockdown)
          local r = mtState("combat after edit mode")
          return r.blocked == 0 and okC and plain(c) == true,
                 r.blocked .. " blocked, " .. ((okC and plain(c)) and "in combat" or "not in combat")
      end },
    -- The other timers, when you can.
    { text = "Optional: swim far out to sea until the fatigue bar shows (Skip if you can't). Goes on by itself.",
      timeout = 900, wait = mtWait("EXHAUSTION"), screenshot = "mirror, fatigue",
      check = mtOn("fatigue", { timer = true }) },
    { text = "Optional: a hunter, cast Feign Death (Skip otherwise). Goes on by itself.", timeout = 300,
      wait = mtWait("FEIGNDEATH"), screenshot = "mirror, feign death", check = mtOn("feign death", { timer = true }) },
    { text = "Optional: dive while in combat (Skip if you can't). Goes on by itself.", timeout = 600,
      wait = function()
          mtHook()
          local okC, c = pcall(InCombatLockdown)
          return mtShown("BREATH") ~= nil and okC and plain(c) == true, "waiting for the breath bar in combat"
      end, check = mtOn("in combat", { timer = true }) },
    { text = "Did every bar look right, and was there no 'Interface action failed' message? The Note.", ask = true },
    taintOff(),
    -- Glass Unit Frames' bars back: Blizzard's hidden, none of ours.
    { text = "If Glass Unit Frames is installed: tick \"Glass breath and fatigue bars\" again in its settings, then "
          .. "press Next (Skip the next three steps if it isn't installed)." },
    { text = "Type /reload.", reload = true },
    { text = "Dive, and press Next with Glass Unit Frames' breath bar up.",
      check = mtNoneOfOurs("glass unit frames") },
    { text = "Type /reload to save the results.", reload = true },
})

Probe:Command("mirror", function() mtState("now") end, "the mirror timers: each shown frame's state now")
NS.mtHook = mtHook   -- tests/test_probe.lua: its stub's container comes after the probe's load
end)()

--------------------------------------------------------------------------------
-- The gossip window and the quest dialog (#115, #114, docs/GOSSIP-QUEST.md).
-- First what the skin follows: which QuestFramePortrait Blizzard fills
-- (GQ.portrait), the texture kits gossip NPCs send (GQ.kits), the pages'
-- atlases (GQ.atlases), the levels (GQ.levels), and a page's alpha right
-- after Blizzard's SetAtlas, faded and not (GQ.pageAlpha). Then the
-- acceptance: each check reads the shell, the shown page (its atlas, alpha,
-- our pane), the text over it (a faded page must have Blizzard's light text
-- over it: the rule the skin rests on), the buttons, the close button, the
-- failures and blocked actions. Read only: getters, and instance hooks that
-- record. Saved as GQ.<label>.
--------------------------------------------------------------------------------

-- Its own function: the main chunk is near Lua 5.1's 200 locals.
do (function()
local DARK = "QuestBG-Parchment-Accessibility4"
-- (A later chunk-level "seen" is a table: this block's own.)
local function isSeen(f)
    local ok, v = call(f, "IsVisible")
    return ok and plain(v) == true
end
local GQ_ORDER = { "Greeting", "Detail", "Progress", "Reward" }
local GQ_PANELS = { Greeting = "QuestFrameGreetingPanel", Detail = "QuestFrameDetailPanel",
                    Progress = "QuestFrameProgressPanel", Reward = "QuestFrameRewardPanel" }
-- Each panel's main text, coloured in the pass that sets its page
-- (QuestFrame.lua:330-335, 191-216; QuestInfo's title for detail and reward).
local GQ_TEXT = { Greeting = "GreetingText", Detail = "QuestInfoTitleHeader", Progress = "QuestProgressText",
                  Reward = "QuestInfoTitleHeader" }
local GQ_BUTTONS = { "QuestFrameAcceptButton", "QuestFrameDeclineButton", "QuestFrameCompleteButton",
                     "QuestFrameGoodbyeButton", "QuestFrameCompleteQuestButton", "QuestFrameGreetingGoodbyeButton" }

local shows = { gossip = 0, quest = 0 }
local lastShow, kits, atlases = 0, {}, {}
local pageAlpha = { faded = 0, held = 0, lost = 0, kept = 0 }
local gqEvents = CreateFrame("Frame")
Probe:RegisterEvents(gqEvents, { "GOSSIP_SHOW", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE" })
gqEvents:SetScript("OnEvent", function(_, event, kit)
    lastShow = GetTime()
    if event == "GOSSIP_SHOW" then
        shows.gossip = shows.gossip + 1
        local k = plain(kit)
        k = (k == nil or k == "") and "none" or tostring(k)
        kits[k] = (kits[k] or 0) + 1
        record("GQ.kits", kits)
    else
        shows.quest = shows.quest + 1
    end
end)

local function gqTest()
    local G = glassUI()
    return G and G.GossipQuest and G.GossipQuest._test, G
end

local function alphaOf(r)
    local ok, a = call(r, "GetAlpha")
    a = ok and plain(a) or nil
    return type(a) == "number" and a or nil
end

local function atlasOf(t)
    local ok, a = call(t, "GetAtlas")
    a = ok and plain(a) or nil
    return type(a) == "string" and a or nil
end

local function levelOf(f)
    local ok, l = call(f, "GetFrameLevel")
    l = ok and plain(l) or nil
    return type(l) == "number" and l or nil
end

-- Right after Blizzard's SetAtlas, before the skin's decision a frame later:
-- did a faded page stay faded? (Alpha holds across SetAtlas: docs/MAP.md.)
local function onPageAtlas(page)
    local atlas = atlasOf(page) or "?"
    atlases[atlas] = (atlases[atlas] or 0) + 1
    record("GQ.atlases", atlases)
    local G = glassUI()
    local faded = G and G.Kit and G.Kit._test and G.Kit._test.faded[page] ~= nil
    local a = alphaOf(page)
    if faded then
        pageAlpha.faded = pageAlpha.faded + 1
        if a == 0 then pageAlpha.held = pageAlpha.held + 1 else pageAlpha.lost = pageAlpha.lost + 1 end
    else
        pageAlpha.kept = pageAlpha.kept + 1
    end
    record("GQ.pageAlpha", pageAlpha)
end

local hooked = false
local function gqHook()
    if hooked then return true end
    local gf = frameByName("GossipFrame")
    if not gf then return false end
    hooked = true
    if type(gf.Background) == "table" then hooksecurefunc(gf.Background, "SetAtlas", onPageAtlas) end
    for _, kind in ipairs(GQ_ORDER) do
        local p = frameByName(GQ_PANELS[kind])
        if p and type(p.Bg) == "table" then hooksecurefunc(p.Bg, "SetAtlas", onPageAtlas) end
    end
    return true
end

local function shownPanel()
    for _, kind in ipairs(GQ_ORDER) do
        local p = frameByName(GQ_PANELS[kind])
        local ok, s = call(p, "IsShown")
        if ok and plain(s) == true then return kind, p end
    end
    return nil
end

-- A colour reads light when its mean is over a half (Stone's, not Parchment's).
local function lightText(fs)
    local ok, r, g, b = call(fs, "GetTextColor")
    r, g, b = plain(r), plain(g), plain(b)
    if not (ok and type(r) == "number" and type(g) == "number" and type(b) == "number") then return nil end
    return (r + g + b) / 3 > 0.5
end

local function failures(G)
    local n = 0
    for _ in pairs(G and G.failures or {}) do n = n + 1 end
    return n
end

local function winState(T, f, key)
    local w = { shown = f ~= nil and isSeen(f), buttons = 0, buttonsRight = 0 }
    local h = T and f and T.wins[f]
    w.installed = h ~= nil
    if not f then return w end
    local most = 0
    local function see(r) local a = alphaOf(r); if a then most = math.max(most, a) end end
    see(f.NineSlice); see(f.Bg); see(f.TopTileStreaks)
    if type(f.Inset) == "table" then see(f.Inset.Bg); see(f.Inset.NineSlice) end
    w.shell = most
    local page
    if key == "gossip" then
        page = f.Background
    else
        local kind, p = shownPanel()
        w.panel = kind
        page = p and p.Bg
        local fs = kind and frameByName(GQ_TEXT[kind])
        w.light = fs and lightText(fs)
    end
    w.atlas = atlasOf(page)
    w.dark = w.atlas == DARK
    w.pageAlpha = alphaOf(page)
    if h then
        w.header = isSeen(h.header)
        w.disc = h.disc ~= nil and isSeen(h.disc)
        local okP, _, rel = call(h.pane.fill, "GetPoint", 1)
        w.pane = isSeen(h.pane.fill)
        w.paneOnPage = w.pane and okP and rel == page
        w.closeAlpha = h.closeAlpha
        local okE, en = call(f.CloseButton, "IsEnabled")
        w.closeEnabled = not okE or plain(en) ~= false
    end
    local list = key == "gossip" and { type(f.GreetingPanel) == "table" and f.GreetingPanel.GoodbyeButton or nil }
        or (function() local l = {} for _, n in ipairs(GQ_BUTTONS) do l[#l + 1] = frameByName(n) end return l end)()
    for _, b in ipairs(list) do
        if isSeen(b) then
            w.buttons = w.buttons + 1
            local st = T and T.buttons[b]
            if st and isSeen(st.glass) and alphaOf(b.Left) == 0 and alphaOf(b.Middle) == 0 and alphaOf(b.Right) == 0 then
                w.buttonsRight = w.buttonsRight + 1
            end
        end
    end
    return w
end

local function gqState(label)
    local T, G = gqTest()
    local rec = { gossip = winState(T, frameByName("GossipFrame"), "gossip"),
                  quest = winState(T, frameByName("QuestFrame"), "quest"), failures = failures(G) }
    local okC, c = pcall(InCombatLockdown)
    rec.combat = okC and plain(c) == true
    local okV, v = pcall(GetCVar, "questTextContrast")
    rec.contrast = okV and plain(v) or "?"
    rec.blocked = type(SkinProbeDB) == "table" and SkinProbeDB.suiteBlocked or 0
    local function line(n, w)
        return n .. " " .. (w.shown and "shown" or "hidden") .. (w.panel and (" " .. w.panel) or "") .. ", shell "
            .. tostring(w.shell) .. ", page " .. tostring(w.atlas) .. " at " .. tostring(w.pageAlpha) .. ", pane "
            .. tostring(w.pane) .. ", text light " .. tostring(w.light) .. ", buttons " .. w.buttonsRight .. "/"
            .. w.buttons .. ", close " .. tostring(w.closeEnabled) .. " (" .. tostring(w.closeAlpha) .. ")"
    end
    say("GQ " .. label .. ": contrast " .. tostring(rec.contrast) .. "; " .. line("gossip", rec.gossip) .. "; "
        .. line("quest", rec.quest) .. "; combat " .. tostring(rec.combat) .. ", failures " .. rec.failures
        .. ", blocked " .. rec.blocked)
    record("GQ." .. label, rec)
    return rec
end

-- The measurements (the plan's probe, first): the two QuestFramePortrait
-- textures, gossip's, and the levels.
local function texInfo(t)
    if type(t) ~= "table" then return nil end
    local okT, tex = call(t, "GetTexture")
    local okL, layer = call(t, "GetDrawLayer")
    local okW, w = call(t, "GetWidth")
    local okX, x = call(t, "GetLeft")
    local okY, y = call(t, "GetTop")
    local okP, parent = call(t, "GetParent")
    local okN, pn = call(okP and parent or nil, "GetName")
    return { set = okT and plain(tex) ~= nil, layer = okL and plain(layer) or "?", width = okW and plain(w) or nil,
             left = okX and plain(x) or nil, top = okY and plain(y) or nil, parent = okN and plain(pn) or "?",
             parentLevel = levelOf(okP and parent or nil) }
end

local function gqMeasure()
    local T = gqTest()
    local qf, gf = frameByName("QuestFrame"), frameByName("GossipFrame")
    local m = {}
    if qf then
        local global = rawget(_G, "QuestFramePortrait")
        local shell = type(qf.PortraitContainer) == "table" and qf.PortraitContainer.portrait or nil
        local own = global ~= shell and global or nil
        if not own then
            -- The shell's holds the global: QuestFrame's own is the 60 px ARTWORK region.
            local ok, regions = pcall(function() return { qf:GetRegions() } end)
            for _, r in ipairs(ok and regions or {}) do
                local okL, layer = call(r, "GetDrawLayer")
                if r ~= shell and okL and plain(layer) == "ARTWORK" and alphaOf(r) then own = r break end
            end
        end
        m.questGlobalIsShell = global == shell
        m.questShell, m.questOwn = texInfo(shell), texInfo(own)
        m.questLevels = { window = levelOf(qf), nineSlice = levelOf(qf.NineSlice), portraitContainer =
                          levelOf(qf.PortraitContainer), close = levelOf(qf.CloseButton) }
        local h = T and T.wins[qf]
        if h then m.questLevels.glass, m.questLevels.disc = levelOf(h.win), levelOf(h.disc) end
        for _, n in ipairs(GQ_BUTTONS) do m.questLevels[n] = levelOf(frameByName(n)) end
        local _, p = shownPanel()
        m.questLevels.panel = levelOf(p)
    end
    if gf then
        local global = rawget(_G, "GossipFramePortrait")
        local shell = type(gf.PortraitContainer) == "table" and gf.PortraitContainer.portrait or nil
        m.gossipGlobalIsShell = global == shell
        m.gossipShell = texInfo(shell)
        m.gossipLevels = { window = levelOf(gf), portraitContainer = levelOf(gf.PortraitContainer) }
        local h = T and T.wins[gf]
        if h then m.gossipLevels.glass, m.gossipLevels.disc = levelOf(h.win), levelOf(h.disc) end
    end
    say("GQ measure: quest portrait global is the shell's " .. tostring(m.questGlobalIsShell) .. " (shell set "
        .. tostring(m.questShell and m.questShell.set) .. ", own set " .. tostring(m.questOwn and m.questOwn.set)
        .. "), gossip's " .. tostring(m.gossipGlobalIsShell))
    record("GQ.portrait", m)
    return m
end

-- want.window "gossip" or "quest"; want.dark: the page expected dark (true)
-- or not (false); want.closeOff; want.combat.
local function gqOn(label, want)
    return function()
        if want.measure then gqMeasure() end
        local r = gqState(label)
        local w = r[want.window]
        local bad = {}
        local function want_(cond, why) if not cond then bad[#bad + 1] = why end end
        want_(w.shown, "the window not shown")
        want_(w.installed, "not installed")
        want_(w.shell == 0, "shell " .. tostring(w.shell))
        want_(w.header, "the band not shown")
        want_(w.disc, "the portrait's disc not shown")
        want_(w.buttonsRight == w.buttons, "buttons " .. w.buttonsRight .. " of " .. w.buttons)
        if w.dark then
            want_(w.pageAlpha == 0, "the dark page at " .. tostring(w.pageAlpha))
            want_(w.paneOnPage, "no pane on the dark page")
        else
            want_(w.pageAlpha ~= 0, "a page faded that isn't the dark one")
            want_(not w.pane, "a pane over a kept page")
        end
        if want.window == "quest" and w.pageAlpha == 0 then want_(w.light ~= false, "dark text over a faded page") end
        if want.dark ~= nil then want_(w.dark == want.dark, "the page " .. tostring(w.atlas)) end
        if want.atlas then want_(w.atlas == want.atlas, "the page " .. tostring(w.atlas)) end
        if want.closeOff then want_(w.closeEnabled == false and w.closeAlpha == 0.35, "the close button not dimmed") end
        if want.combat ~= nil then want_(r.combat == want.combat, "combat " .. tostring(r.combat)) end
        want_(r.failures == 0, r.failures .. " failure(s): /glassui failures")
        want_(r.blocked == 0, r.blocked .. " blocked")
        return #bad == 0, #bad == 0 and ((w.panel or want.window) .. ": as planned") or table.concat(bad, "; ")
    end
end

local function gqOff(label, which)
    return function()
        local r = gqState(label)
        local w = r[which]
        local ok = w.shown and w.shell > 0 and w.pageAlpha ~= 0 and not w.pane and w.buttonsRight == 0
        return ok, ok and "Blizzard's look, nothing of ours" or "something of ours while off"
    end
end

local function gqFine(label)
    return function()
        local r = gqState(label)
        return r.failures == 0 and r.blocked == 0, r.failures .. " failure(s), " .. r.blocked .. " blocked"
    end
end

local function gqClosed(label, which)
    return function()
        local r = gqState(label)
        local ok = not r[which].shown and r.blocked == 0
        return ok, (r[which].shown and "still open" or "closed") .. ", " .. r.blocked .. " blocked"
    end
end

-- The window shown and styled, a moment after its last show.
local function gqWait(which, opts)
    opts = opts or {}
    local from
    return function()
        gqHook()
        if from == nil then from = shows[which] end
        local T = gqTest()
        local f = frameByName(which == "gossip" and "GossipFrame" or "QuestFrame")
        local ready = (not opts.new or shows[which] > from) and f ~= nil and isSeen(f) and T ~= nil and T.wins[f] ~= nil
            and GetTime() - lastShow > 0.3
        if ready and opts.panel then ready = shownPanel() == opts.panel end
        return ready, "waiting for the " .. (which == "gossip" and "gossip window" or "quest dialog")
    end
end

local function gqSwitch(key, on)
    local G = glassUI()
    if not (G and G.Engine) then return false, "Glass UI not loaded" end
    G.Engine.SetEnabled(key, on)
    return true, key .. " " .. (on and "on" or "off")
end

local function gqMaster(on)
    local G = glassUI()
    if not (G and G.Engine) then return false, "Glass UI not loaded" end
    G.Engine.SetMaster(on)
    return true, "master " .. (on and "on" or "off")
end

-- Never without the player's value saved first (Codex on #204).
local function contrast(v)
    return function()
        if not (type(SkinProbeDB) == "table" and type(SkinProbeDB.gqContrastWas) == "string") then
            error("your setting wasn't saved: press Stop", 0)
        end
        local ok = setCVar("questTextContrast", tostring(v))
        return ok, "questTextContrast " .. tostring(v)
    end
end

-- Your setting, kept across the run's reloads and put back at its end. A
-- snapshot still waiting (a run stopped after the probe changed it) is kept:
-- the value now may be the probe's (Codex on #201). /fp skin gqrestore puts
-- it back by hand.
local function contrastSave()
    if type(SkinProbeDB) == "table" and type(SkinProbeDB.gqContrastWas) == "string" then
        return true, "your Quest Text Contrast, kept from a stopped run: " .. SkinProbeDB.gqContrastWas
    end
    local okV, v = pcall(GetCVar, "questTextContrast")
    v = okV and plain(v) or nil
    record("GQ.contrastWas", v)
    -- Nothing usable saved: the run mustn't write (Codex on #203, r4).
    if type(SkinProbeDB) ~= "table" or type(v) ~= "string" or v == "" then
        return false, "your Quest Text Contrast couldn't be read: press Stop, nothing was changed"
    end
    SkinProbeDB.gqContrastWas = v
    return true, "your Quest Text Contrast: " .. v
end

-- The snapshot is dropped only once the setting reads it back, so the run's
-- last step and /fp skin gqrestore can be tried again (Codex on #203, r4).
local function contrastRestore()
    local was = type(SkinProbeDB) == "table" and SkinProbeDB.gqContrastWas or nil
    if type(was) ~= "string" then return true, "nothing saved" end
    setCVar("questTextContrast", was)
    local okV, now = pcall(GetCVar, "questTextContrast")
    now = okV and plain(now) or nil
    if now ~= was then return false, "questTextContrast reads " .. tostring(now) .. ", not " .. was .. ": try again" end
    SkinProbeDB.gqContrastWas = nil
    return true, "questTextContrast back to " .. was
end

-- The popup and the map's details: Blizzard's, nothing of ours faded there.
local function notInherited(label)
    return function()
        local G = glassUI()
        local faded = G and G.Kit and G.Kit._test and G.Kit._test.faded or {}
        local roots = { frameByName("QuestLogPopupDetailFrame"), frameByName("QuestMapFrame") }
        local n = 0
        -- The dialog skins' fades only: the popup's own skin (#202) fades its
        -- rock there, legitimately (Codex on #202).
        local DIALOG = { gossip = true, quest = true }
        for region, st in pairs(faded) do
            local p = (type(st) == "table" and type(st.kit) == "table" and DIALOG[st.kit.key]) and region or nil
            for _ = 1, p and 30 or 0 do
                local ok, parent = call(p, "GetParent")
                p = ok and parent or nil
                if not p then break end
                if p == roots[1] or p == roots[2] then
                    local okS, vis = call(region, "IsVisible")
                    if okS and plain(vis) == true then n = n + 1 end
                    break
                end
            end
        end
        record("GQ." .. label, { fadedThere = n })
        return n == 0, n == 0 and "Blizzard's" or (n .. " region(s) of ours faded there")
    end
end

local CONTRAST_HOW = "Settings > Accessibility > General > Quest Text Contrast"

-- A step that goes on by itself a moment after it shows, then checks: the
-- skin decides a frame after a change (a switch, the setting).
local function settled(text, check, screenshot)
    local t0
    return { text = text, timeout = 15, screenshot = screenshot, check = check,
             wait = function()
                 t0 = t0 or GetTime()
                 return GetTime() - t0 >= 1, "a moment"
             end,
             leave = function() t0 = nil end }
end

local function setTo(v, text)
    return { text = text, auto = true, run = contrast(v) }
end

Probe:Steps("gossipglass", {
    title = "Glass UI: the gossip window and the quest dialog in glass (#115, #114)",
    rev = 3,
    { text = "Turns on script errors, counts blocked actions from now, and saves your Quest Text Contrast setting "
          .. "(put back at the end; if you stop early, /fp skin gqrestore puts it back).", auto = true,
      run = function()
          if type(SkinProbeDB) == "table" then SkinProbeDB.suiteBlocked = 0 end
          gqHook()
          -- No usable snapshot: the step stays, nothing is written (Codex on #204).
          local ok, why = contrastSave()
          if not ok then error(why, 0) end
          return setCVar("scriptErrors", "1")
      end },
    setTo(0, "Sets Quest Text Contrast to the default (the parchment) for the first part."),
    { text = "Stand near an NPC with gossip options (an innkeeper, a guard, a flight master) and a quest giver. "
          .. "Then type /reload.", reload = true },
    { text = "Turns the taint log on (a reload turns it off). " .. TAINT_NOISE, auto = true,
      run = function() gqHook(); return setCVar("taintLog", "1") end },
    -- The gossip window.
    { text = "Talk to the gossip NPC. This step goes on by itself; a screenshot is taken.", timeout = 600,
      wait = gqWait("gossip", { new = true }), screenshot = "gossip, first",
      check = gqOn("gossip first", { window = "gossip", dark = false, measure = true }) },
    { text = "Does it read as the template: dark glass, the smoky band with the NPC's name, the portrait on a glass "
          .. "disc, the parchment page with Blizzard's text and rows, Goodbye on glass, the close button on its "
          .. "disc? Anything off: the Note.", ask = true },
    { text = "Hover a few rows (Blizzard's highlight), scroll if the list is long, then choose an option or pick "
          .. "a quest. Press Next.", check = gqFine("gossip used") },
    -- The quest dialog through a quest's life.
    { text = "Open a quest's details at the quest giver (not yet accepted). Wait for the text to finish typing. "
          .. "This step goes on by itself; a screenshot is taken.", timeout = 600,
      wait = gqWait("quest", { panel = "Detail" }), screenshot = "quest, details",
      check = gqOn("details", { window = "quest", dark = false, measure = true }) },
    { text = "Hover a reward's icon: its tooltip shows. Then press Next (keep the window open).",
      check = gqOn("details hovered", { window = "quest" }) },
    { text = "Accept the quest. Press Next.", check = gqFine("accepted") },
    { text = "Open the progress of a quest you have at its turn-in NPC (incomplete is fine; one that needs money "
          .. "if you have one). Press Next on it; a screenshot.", screenshot = "quest, progress",
      check = gqOn("progress", { window = "quest" }) },
    { text = "If it can be completed: press Continue for the reward panel, WITHOUT closing the window, and press "
          .. "Next on it (Skip otherwise); a screenshot.", screenshot = "quest, reward",
      check = gqOn("reward", { window = "quest" }) },
    { text = "On each panel there was one dark pane at most and the band stayed in place? Complete the quest if "
          .. "you can (choose a reward). Anything off: the Note.", ask = true },
    { text = "Optional: talk to an NPC with several quests (a greeting list). Press Next on it, Skip otherwise.",
      check = gqOn("greeting", { window = "quest" }) },
    { text = "Open a quest dialog, close it with its X. Open it again, close it with Esc. Open it again, close it "
          .. "with Decline or Goodbye. Press Next.", check = gqClosed("closed three ways", "quest") },
    -- Blizzard's dark page.
    { text = "Talk to the gossip NPC and keep the window open. This step goes on by itself.", timeout = 600,
      wait = gqWait("gossip", { new = true }) },
    { text = "With the gossip window open: sets Quest Text Contrast to Dark (what " .. CONTRAST_HOW .. " does).",
      button = "Dark", run = contrast(4) },
    settled("Its page should go at once, Blizzard's text light on the glass. Goes on by itself; a screenshot.",
            gqOn("gossip dark", { window = "gossip", dark = true }), "gossip, dark"),
    { text = "Is the gossip text readable on the glass? Anything off: the Note.", ask = true },
    { text = "Sets it back to the default.", button = "Default", run = contrast(0) },
    settled("The parchment back at once. Goes on by itself.",
            gqOn("gossip default", { window = "gossip", dark = false })),
    -- Contrast 1-3 (lighter parchments with dark text), each set and checked
    -- on its own atlas (Codex on #201; 1's has no number,
    -- QuestTextContrast.lua:18).
    { text = "Contrast 1.", button = "1", run = contrast(1) },
    settled("Its lighter parchment, kept. Goes on by itself.",
            gqOn("gossip contrast 1", { window = "gossip", atlas = "QuestBG-Parchment-Accessibility" })),
    { text = "Contrast 2.", button = "2", run = contrast(2) },
    settled("Kept. Goes on by itself.",
            gqOn("gossip contrast 2", { window = "gossip", atlas = "QuestBG-Parchment-Accessibility2" })),
    { text = "Contrast 3.", button = "3", run = contrast(3) },
    settled("Kept. Goes on by itself.",
            gqOn("gossip contrast 3", { window = "gossip", atlas = "QuestBG-Parchment-Accessibility3" })),
    setTo(4, "Sets Dark again."),
    { text = "Close the gossip window, then open a quest's details (Dark from the start). Goes on by itself; a "
          .. "screenshot.", timeout = 600, wait = gqWait("quest", { new = true }), screenshot = "quest, dark",
      check = gqOn("quest dark", { window = "quest", dark = true }) },
    { text = "Is the quest text readable on the glass (title, description, objectives, rewards)? Anything off: the "
          .. "Note.", ask = true },
    { text = "With that panel still open: sets the default back.", button = "Default", run = contrast(0) },
    settled("The panel keeps Blizzard's dark page and light text until Blizzard refreshes it. Goes on by itself.",
            gqOn("quest open, set back", { window = "quest", dark = true })),
    { text = "Move to another panel (accept, or close and open the quest again): the parchment and dark text "
          .. "together. Press Next on it.", check = gqOn("quest refreshed", { window = "quest", dark = false }) },
    setTo(4, "Sets Dark for the next step."),
    { text = "Optional: the progress of a quest that needs money. Open it and press Next (a screenshot), Skip if "
          .. "you have none.", screenshot = "quest, money", check = gqOn("money dark", { window = "quest" }) },
    { text = "Were the required-money lines readable (Blizzard writes them black even in its Dark mode)? "
          .. "Anything off: the Note.", ask = true },
    { text = "Close every NPC window, then press the button: sets the default while they're closed.",
      button = "Default", run = contrast(0), check = gqClosed("closed for the change", "quest") },
    setTo(4, "Sets Dark while they're closed."),
    { text = "Open the gossip window: it opens dark. Goes on by itself.", timeout = 600,
      wait = gqWait("gossip", { new = true }), check = gqOn("dark while closed", { window = "gossip", dark = true }) },
    -- Auto-accept.
    { text = "Optional: an auto-accept quest (Skip if none): its details show Accept only, the close button "
          .. "disabled. Press Next on it.", check = gqOn("auto-accept", { window = "quest", closeOff = true }) },
    -- Off and on.
    { text = "Open the gossip window. With it open: switches its skin off (Blizzard's look).", button = "Skin off",
      run = function() return gqSwitch("gossip", false) end, screenshot = "gossip, skin off",
      check = gqOff("gossip off", "gossip") },
    { text = "A setting change while off: sets the default, then Dark again. Blizzard's look stays.",
      button = "Change", run = function() contrast(0)(); return contrast(4)() end },
    settled("Goes on by itself.", gqOff("gossip off, changed", "gossip")),
    { text = "Switches it on again.", button = "Skin on", run = function() return gqSwitch("gossip", true) end },
    settled("Goes on by itself.", gqOn("gossip on again", { window = "gossip", dark = true })),
    { text = "Open a quest dialog. With it open: the quest skin off.", button = "Skin off",
      run = function() return gqSwitch("quest", false) end, check = gqOff("quest off", "quest") },
    { text = "And on again.", button = "Skin on", run = function() return gqSwitch("quest", true) end },
    settled("Goes on by itself.", gqOn("quest on again", { window = "quest" })),
    { text = "The master switch off, with the quest dialog open.", button = "All off",
      run = function() return gqMaster(false) end, check = gqOff("master off", "quest") },
    { text = "And on.", button = "All on", run = function() return gqMaster(true) end },
    settled("Goes on by itself.", gqOn("master on", { window = "quest" })),
    -- A reload, combat.
    { text = "Close the windows and type /reload.", reload = true },
    { text = "Turns the taint log on again.", auto = true,
      run = function() gqHook(); return setCVar("taintLog", "1") end },
    { text = "Talk to the gossip NPC again. Goes on by itself.", timeout = 600,
      wait = gqWait("gossip", { new = true }), check = gqOn("after reload", { window = "gossip" }) },
    { text = "Optional: in combat (a mob hitting you near the NPCs), open a gossip window and accept a quest. Press "
          .. "Next with a window open in combat, Skip if you can't.",
      check = function()
          local r = gqState("in combat")
          local w = r.gossip.shown and r.gossip or r.quest
          local ok = r.combat and w.shown and w.installed and r.blocked == 0
          return ok, "combat " .. tostring(r.combat) .. ", styled " .. tostring(w.installed) .. ", " .. r.blocked
              .. " blocked"
      end },
    -- The other readers of QuestInfo.
    { text = "Open a quest's details from the objective tracker (right-click a quest > details, the popup) and "
          .. "press Next with it open (a screenshot).", screenshot = "quest popup",
      check = notInherited("popup") },
    { text = "Open the world map's quest log and a quest's details there. Press Next with them open (a screenshot).",
      screenshot = "map details", check = notInherited("map details") },
    { text = "Did the popup and the map's details look as before (Blizzard's or the map skin's, nothing new)? "
          .. "Did everything read right, with no 'Interface action failed' message or Lua error? The Note.",
      ask = true },
    { text = "Puts your Quest Text Contrast setting back.", auto = true, run = contrastRestore },
    taintOff(),
    { text = "Type /reload to save the results.", reload = true },
})

Probe:Command("gossipquest", function() gqMeasure(); gqState("now") end,
              "#115/#114: the gossip window and the quest dialog: portraits, levels, pages, buttons now")
Probe:Command("gqrestore", function()
    local ok, why = contrastRestore()
    say("GQ restore: " .. tostring(ok) .. ", " .. tostring(why))
end, "#115/#114: put your Quest Text Contrast back after a stopped gossipglass run")
skinChecks.gqState, skinChecks.gqOn, skinChecks.gqMeasure, skinChecks.gqHook = gqState, gqOn, gqMeasure, gqHook
skinChecks.contrastSave = contrastSave
skinChecks.contrastRestore = contrastRestore
end)() end

--------------------------------------------------------------------------------
-- Light quest text on glass (#203, docs/QUEST-TEXT.md). First, with the
-- switch off, what the design rests on: the CVar's flags (QT.info), Glass
-- UI's own startup trace (QT.trace.<label>: the probe loads after Glass UI and
-- can't see its ADDON_LOADED), persistence across full exits for a value
-- written by addon code and one chosen in Blizzard's settings, and whether
-- CVAR_UPDATE arrives inside the call that caused it (QT.boundary.<label>).
-- Then the switch in use. Its own listener records every CVAR_UPDATE for the
-- CVar with the phase it arrived in. Saved as QT.<label>.
--------------------------------------------------------------------------------

do (function()
local CVAR = "questTextContrast"
local phase = "idle"          -- "inside" while the probe's own call runs
local seen = {}               -- this load's CVAR_UPDATEs for the CVar
local qtEvents = CreateFrame("Frame")
Probe:RegisterEvents(qtEvents, { "CVAR_UPDATE" })
qtEvents:SetScript("OnEvent", function(_, _, name, value)
    name = plain(name)
    if type(name) ~= "string" or name:lower() ~= CVAR:lower() then return end
    local okV, v = pcall(GetCVar, CVAR)
    if #seen < 40 then
        seen[#seen + 1] = { name = name, value = plain(value), live = okV and plain(v) or nil, phase = phase,
                            at = GetTime() }
    end
end)

local function qt()
    local G = glassUI()
    return G and G.QuestText
end

local function liveValue()
    local ok, v = pcall(GetCVar, CVAR)
    v = ok and plain(v) or nil
    return type(v) == "string" and v or nil
end

local function blocked() return type(SkinProbeDB) == "table" and SkinProbeDB.suiteBlocked or 0 end

local function qtState(label)
    local Q = qt()
    local rec = { value = liveValue(), on = Q and Q.IsOn() or false, status = Q and Q.Status() or "?",
                  blocked = blocked(), events = #seen }
    say("QT " .. label .. ": value " .. tostring(rec.value) .. ", switch " .. rec.status .. ", " .. rec.events
        .. " event(s) this load, blocked " .. rec.blocked)
    record("QT." .. label, rec)
    return rec
end

-- The flags. Secure, locked or read-only: the design goes back for review.
local function info()
    local cv = rawget(_G, "C_CVar")
    local ok, value, def, account, char, locked, secure, readOnly = pcall(cv and cv.GetCVarInfo, CVAR)
    local r = { ok = ok, value = plain(value), default = plain(def), account = plain(account), character = plain(char),
                locked = plain(locked), secure = plain(secure), readOnly = plain(readOnly) }
    local okL, loaded = pcall(cv and cv.AreCVarsLoaded)
    r.loaded = okL and plain(loaded) or nil
    record("QT.info", r)
    say("QT info: value " .. tostring(r.value) .. ", default " .. tostring(r.default) .. ", account "
        .. tostring(r.account) .. ", character " .. tostring(r.character) .. ", locked " .. tostring(r.locked)
        .. ", secure " .. tostring(r.secure) .. ", read-only " .. tostring(r.readOnly))
    local stop = r.locked == true or r.secure == true or r.readOnly == true
    return ok and not stop, stop and "locked, secure or read-only: stop, the design goes back for review"
        or "the flags allow the switch"
end

-- Glass UI's startup samples this load, its decision's outcome, and the
-- settled value now. switchOn false (the passive measurement): the value at
-- the decision must be the settled one, and the decision "off". switchOn
-- true: the decision kept Dark or re-applied it, and Dark is settled; a
-- re-apply makes the early read differ from the settled one by design
-- (Codex on #204). No decision recorded fails either way.
local function startup(label, switchOn)
    local Q = qt()
    local list = {}
    for i, t in ipairs(Q and Q.trace or {}) do
        list[i] = { event = t.event, loaded = t.loaded, value = t.value, was = t.was, decided = t.decided,
                    outcome = t.outcome }
    end
    local settled = liveValue()
    local atDecision, decision
    for _, t in ipairs(list) do
        if t.outcome then decision = t.outcome
        elseif t.loaded and t.value and not decision then atDecision = t.value end
    end
    local events = {}
    for i, e in ipairs(seen) do events[i] = { value = e.value, live = e.live, phase = e.phase } end
    record("QT.trace " .. label, { samples = list, events = events, settled = settled, atDecision = atDecision,
                                   decision = decision })
    say("QT trace " .. label .. ": " .. #list .. " sample(s), value at the decision " .. tostring(atDecision)
        .. ", decision " .. tostring(decision) .. ", settled " .. tostring(settled))
    local why = "at the decision " .. tostring(atDecision) .. ", decision " .. tostring(decision) .. ", settled "
        .. tostring(settled)
    if not decision or not atDecision then return false, "no decision recorded: " .. why end
    if switchOn then
        return (decision == "kept" or decision == "reapplied") and settled == "4", why
    end
    return decision == "off" and atDecision == settled, why
end

-- A call of ours, with the events that arrive inside it and in the next
-- frame: inside only means synchronous delivery.
-- One call of ours: the value before and after it, the CVAR_UPDATEs that
-- arrive inside it (and whether one carries the value it ended on), and,
-- half a second on, those that arrived after it (Codex on #204: each call
-- its own window, events matched to its transition).
local function boundary(label, fn)
    local from = #seen + 1
    local before = liveValue()
    phase = label .. ":in"
    local ok, a, b = pcall(fn)
    local final = liveValue()
    local inside, matched = 0, false
    for i = from, #seen do
        if seen[i].phase == label .. ":in" then
            inside = inside + 1
            if seen[i].value == final then matched = true end
        end
    end
    phase = label .. ":after"
    C_Timer.After(0.5, function()
        local after = 0
        for i = from, #seen do
            if seen[i].phase == label .. ":after" then after = after + 1 end
        end
        if phase == label .. ":after" then phase = "idle" end
        record("QT.boundary " .. label, { inside = inside, matched = matched, after = after, ok = ok,
                                          line = plain(b), before = before, final = final })
        say("QT boundary " .. label .. ": " .. tostring(before) .. " to " .. tostring(final) .. ", " .. inside
            .. " event(s) inside the call (its value " .. tostring(matched) .. "), " .. after .. " after it")
    end)
    return ok and a ~= false, tostring(b)
end

-- The value changed, an event arrived inside the call, none after it. No
-- change, or no event, is no evidence: it fails (Codex on #204).
local function lastBoundaryOk(label)
    return function()
        local r = type(SkinProbeDB) == "table" and type(SkinProbeDB.results) == "table"
            and SkinProbeDB.results["QT.boundary " .. label]
        if not r then return false, "not recorded" end
        local why = tostring(r.before) .. " to " .. tostring(r.final) .. ", " .. r.inside .. " inside, " .. r.after
            .. " after"
        if r.before == r.final then return false, "the value didn't change: " .. why end
        return r.inside >= 1 and r.matched == true and r.after == 0, why
    end
end

-- The probe writes only once the player's value is saved and the flags allow
-- it (Codex on #204): a run that couldn't save or that found a lock never
-- writes, even if a step is skipped.
local function ready()
    return type(SkinProbeDB) == "table" and type(SkinProbeDB.gqContrastWas) == "string"
        and SkinProbeDB.qtFlagsOk == true
end

local function write(v)
    return function()
        if not ready() then error("not ready: no saved setting or the flags failed, press Stop", 0) end
        local ok = setCVar(CVAR, v)
        return ok, "questTextContrast " .. v .. " (the probe's write), reads " .. tostring(liveValue())
    end
end

local function want(label, v, on)
    return function()
        local r = qtState(label)
        local bad = {}
        if v and r.value ~= v then bad[#bad + 1] = "reads " .. tostring(r.value) .. ", not " .. v end
        if on ~= nil and r.on ~= on then bad[#bad + 1] = "switch " .. r.status end
        if r.blocked > 0 then bad[#bad + 1] = r.blocked .. " blocked" end
        return #bad == 0, #bad == 0 and (tostring(r.value) .. ", switch " .. r.status) or table.concat(bad, "; ")
    end
end

local function settle(text, check, screenshot)
    local t0
    return { text = text, timeout = 15, screenshot = screenshot, check = check,
             wait = function()
                 t0 = t0 or GetTime()
                 return GetTime() - t0 >= 1, "a moment"
             end,
             leave = function() t0 = nil end }
end

-- The switch's own writes, through the same gate as the probe's.
local function guarded()
    if not ready() then error("not ready: no saved setting or the flags failed, press Stop", 0) end
    local Q = qt()
    if not Q then error("Glass UI not loaded", 0) end
    return Q
end

local function switch(on)
    return function()
        local Q = guarded()
        return (on and Q.On or Q.Off)()
    end
end

local gqOn = skinChecks.gqOn

-- A passive startup check that fails holds the run: the gate closes and the
-- step stays, so no write follows a startup the design doesn't hold for
-- (Codex on #204).
local function passive(ok, why)
    if not ok then
        if type(SkinProbeDB) == "table" then SkinProbeDB.qtFlagsOk = nil end
        error(why, 0)
    end
    return true, why
end

Probe:Steps("questtext", {
    title = "Glass UI: light quest text on glass (#203)",
    rev = 4,
    -- Measured first, the switch off.
    { text = "Turns on script errors, counts blocked actions from now and saves your Quest Text Contrast (put "
          .. "back at the end; if you stop early, /fp skin gqrestore puts it back). If Light quest text is on, "
          .. "this step stays: type /glassui questtext off, then press Retry. If it can't save, press Stop.",
      auto = true,
      run = function()
          if type(SkinProbeDB) == "table" then SkinProbeDB.suiteBlocked = 0; SkinProbeDB.qtFlagsOk = nil end
          setCVar("scriptErrors", "1")
          -- Off by the player first, so the snapshot is their own setting,
          -- not the switch's Dark (Codex on #204).
          local Q = qt()
          if Q and Q.IsOn() then error("Light quest text is on: /glassui questtext off, then Retry", 0) end
          local ok, why = skinChecks.contrastSave()
          if not ok then error(why, 0) end
          return true, why
      end },
    { text = "Reads the setting's flags (account, character, locked, secure, read-only). If this step stays, "
          .. "press Stop and tell Claude: the design goes back for review.", auto = true,
      run = function()
          local ok, why = info()
          if not ok then error(why, 0) end
          SkinProbeDB.qtFlagsOk = true
          return true, why
      end },
    { text = "Records Glass UI's startup trace for this load. If this step stays, press Stop and tell Claude.",
      auto = true, run = function() return passive(startup("load", false)) end },
    -- Persistence: a value written by addon code.
    { text = "Writes 2 (Light 2) as an addon would.", auto = true, run = write("2") },
    { text = "Type /reload (the value written by addon code, read back at login).", reload = true },
    { text = "Records the startup trace and the value after the reload. If this step stays, press Stop and tell "
          .. "Claude.", auto = true,
      run = function()
          local ok, why = startup("reload, addon wrote 2", false)
          record("QT.persist addon", liveValue())
          return passive(ok, why .. "; kept " .. tostring(liveValue() == "2"))
      end },
    -- A value chosen in Blizzard's settings.
    { text = "Open Settings > Accessibility > General, set Quest Text Contrast to Grey "
          .. "(the options: Default, Brown, White, Grey, Black), close "
          .. "the settings. Press Next.", check = want("blizzard set 3", "3") },
    { text = "Type /reload (the value chosen in Blizzard's settings).", reload = true },
    { text = "Records the startup trace and the value after the reload. If this step stays, press Stop and tell "
          .. "Claude.", auto = true,
      run = function()
          local ok, why = startup("reload, Blizzard set 3", false)
          record("QT.persist blizzard", liveValue())
          return passive(ok, why .. "; kept " .. tostring(liveValue() == "3"))
      end },
    { text = "Type /reload (the control: a reload keeps the value in memory).", reload = true },
    { text = "Records the trace after the reload, and turns the taint log on (a reload turns it off). "
          .. TAINT_NOISE, auto = true,
      run = function()
          setCVar("taintLog", "1")
          return passive(startup("reload", false))
      end },
    -- The setter boundary, with the switch.
    { text = "Sets the default (0), then turns the switch on: records whether the event arrives inside the call.",
      button = "Switch on",
      run = function()
          write("0")()
          return boundary("on", switch(true))
      end },
    settle("Goes on by itself.", lastBoundaryOk("on")),
    { text = "Turns it off: the restore's event.", button = "Switch off",
      run = function() return boundary("off", switch(false)) end },
    settle("Goes on by itself.", lastBoundaryOk("off")),
    { text = "Off then on again at once: three calls, each timed on its own.", button = "On, off, on",
      run = function()
          guarded()
          boundary("rapid on", switch(true))
          boundary("rapid off", switch(false))
          return boundary("rapid on again", switch(true))
      end },
    settle("Goes on by itself: the switch on, Dark.", function()
        local bad, why = {}, {}
        for _, l in ipairs({ "rapid on", "rapid off", "rapid on again" }) do
            local ok, w = lastBoundaryOk(l)()
            why[#why + 1] = l .. ": " .. w
            if not ok then bad[#bad + 1] = l end
        end
        local okS, whyS = want("off then on", "4", true)()
        return #bad == 0 and okS, table.concat(why, "; ") .. "; " .. whyS
    end),
    -- The switch in use.
    { text = "Talk to a gossip NPC with the ordinary parchment (an innkeeper, a guard) and keep the window open. "
          .. "Press Next with it open; a screenshot.", screenshot = "questtext, gossip",
      check = gqOn("questtext gossip", { window = "gossip", dark = true }) },
    { text = "Is the gossip text light and readable on the glass?", ask = true },
    { text = "Open a quest's details at a quest giver. Press Next with it open; a screenshot.",
      screenshot = "questtext, quest", check = gqOn("questtext quest", { window = "quest", dark = true }) },
    { text = "Is the quest text readable on the glass?", ask = true },
    { text = "If you have a book or letter to read, open it; else open the quest log's details popup (the "
          .. "objective tracker, right-click a quest). Press Next with it open; a screenshot.",
      screenshot = "questtext, book or popup" },
    { text = "Open the world map's quest details. Press Next with them open; a screenshot.",
      screenshot = "questtext, map details" },
    { text = "Were the book (or popup) and the map's details readable, as Blizzard's Dark mode draws them?",
      ask = true },
    { text = "Open Settings > Accessibility: does Quest Text Contrast show Black (Dark)? Then pick White "
          .. "and close the settings.", ask = true },
    settle("The switch should have turned itself off, with one line in chat, and nothing written back.",
           want("let go", "2", false)),
    { text = "Switch on, then again with /glassui questtext on, then off: White comes back.",
      button = "On, on, off",
      run = function()
          local Q = guarded()
          Q.On()
          Q.On()
          return Q.Off()
      end },
    settle("Goes on by itself.", want("on twice, off", "2", false)),
    { text = "Set Black yourself in Settings (Accessibility > Quest Text Contrast: Black), close it, then press "
          .. "the button: the switch on (Dark already), then off.", button = "On, off",
      run = function()
          local Q = guarded()
          Q.On()
          return Q.Off()
      end },
    settle("Dark stays: it was yours.", want("on while dark, off", "4", false)),
    { text = "Sets the default for the next steps.", auto = true, run = write("0") },
    { text = "Get into combat (a mob hitting you), then press the button while still in combat: the switch "
          .. "refuses.", button = "Switch on", run = switch(true),
      check = function()
          local okC, c = pcall(InCombatLockdown)
          local r = qtState("in combat")
          return okC and plain(c) == true and not r.on, "combat " .. tostring(okC and plain(c)) .. ", switch "
              .. r.status
      end },
    { text = "Out of combat: the switch on.", button = "Switch on", run = switch(true) },
    settle("Goes on by itself.", want("after combat", "4", true)),
    { text = "Open Glass UI's settings (/glassui options): the Quest text section's checkbox is ticked. Hover it: "
          .. "the tooltip says to turn it off before uninstalling. Right?", ask = true },
    { text = "Type /reload with the switch on.", reload = true },
    { text = "Records the startup with the switch on, and turns the taint log on again.", auto = true,
      run = function() return setCVar("taintLog", "1") end,
      check = function()
          local ok, why = startup("reload, switch on", true)
          local r = qtState("after reload")
          return ok and r.on and r.value == "4", why .. "; switch " .. r.status .. ", " .. tostring(r.value)
      end },
    { text = "Type /reload once more with the switch on.", reload = true },
    { text = "Records the startup after the reload (a re-apply only if the value was dropped), and the taint "
          .. "log on again.", auto = true,
      run = function() return setCVar("taintLog", "1") end,
      check = function()
          local ok, why = startup("reload 2, switch on", true)
          local r = qtState("after reload 2")
          return ok and r.on and r.value == "4", why .. "; switch " .. r.status .. ", " .. tostring(r.value)
      end },
    -- Blizzard's side after the writes.
    { text = "Gain some XP or reputation (kill a mob, turn in a quest), open Edit Mode and close it, change "
          .. "another option in Blizzard's settings, then fight using your action bars. Press Next while still in "
          .. "combat.", check = function()
              local okC, c = pcall(InCombatLockdown)
              local r = qtState("bars in combat")
              return r.blocked == 0 and okC and plain(c) == true, r.blocked .. " blocked, combat "
                  .. tostring(okC and plain(c))
          end },
    { text = "Did everything read right, with no 'Interface action failed' message or Lua error? The Note.",
      ask = true },
    { text = "Turns the switch off and puts your own Quest Text Contrast back.", auto = true,
      run = function()
          -- The switch off only if the run got ready (it can then have
          -- written); the player's value back only from a valid snapshot.
          local Q = qt()
          if ready() and Q and Q.IsOn() then Q.Off() end
          SkinProbeDB.qtFlagsOk = nil
          return skinChecks.contrastRestore()
      end },
    taintOff(),
    { text = "Type /reload to save the results. Then tell Claude: the taint log is read from Logs.", reload = true },
})

Probe:Command("questtext", function()
    info()
    startup("now")
    qtState("now")
end, "#203: light quest text: the CVar's flags, Glass UI's startup trace, the switch now")
skinChecks.qtState, skinChecks.qtInfo, skinChecks.qtStartup = qtState, info, startup
skinChecks.qtBoundaryOk = lastBoundaryOk
end)() end

--------------------------------------------------------------------------------
-- The quest details popup (#202, docs/QUEST-POPUP.md). First the structure
-- the skin rests on (QP.structure): .Bg and QuestLogPopupDetailFrameBg each,
-- the rock and the book found by structure, the shown popup's levels. A
-- missing or ambiguous piece stops the run. Then the acceptance: each check
-- reads the shell, the rock, the page (its atlas and alpha), our pane, the
-- last paint the skin recorded, the text over the page (a faded page must
-- have light text over it), the disc, the buttons, failures and blocked
-- actions. Light quest text (#204) sets the contrast; the player's own
-- setting is saved first and put back at the end. Saved as QP.<label>.
--------------------------------------------------------------------------------

do (function()
local DARK = "QuestBG-Parchment-Accessibility4"

local function qpTest()
    local G = glassUI()
    return G and G.GossipQuest and G.GossipQuest._test, G
end

local function isSeen(f)
    local ok, v = call(f, "IsVisible")
    return ok and plain(v) == true
end

local function alphaOf(r)
    local ok, a = call(r, "GetAlpha")
    a = ok and plain(a) or nil
    return type(a) == "number" and a or nil
end

local function levelOf(f)
    local ok, l = call(f, "GetFrameLevel")
    l = ok and plain(l) or nil
    return type(l) == "number" and l or nil
end

local function texShape(t)
    if type(t) ~= "table" then return nil end
    local okL, layer, sub = call(t, "GetDrawLayer")
    local okA, atlas = call(t, "GetAtlas")
    local okN, n = call(t, "GetNumPoints")
    local pts = {}
    for i = 1, (okN and plain(n)) or 0 do
        local ok, p, _, _, x, y = call(t, "GetPoint", i)
        if ok then pts[#pts + 1] = tostring(plain(p)) .. " " .. tostring(plain(x)) .. "," .. tostring(plain(y)) end
    end
    return { layer = okL and plain(layer) or nil, sub = okL and plain(sub) or nil,
             atlas = okA and plain(atlas) or nil, points = table.concat(pts, "; ") }
end

local function lightText()
    local fs = frameByName("QuestInfoTitleHeader")
    local ok, r, g, b = call(fs, "GetTextColor")
    r, g, b = plain(r), plain(g), plain(b)
    if not (ok and type(r) == "number" and type(g) == "number" and type(b) == "number") then return nil end
    return (r + g + b) / 3 > 0.5
end

local function qpMeasure()
    local T = qpTest()
    local f = frameByName("QuestLogPopupDetailFrame")
    local m = { shown = f ~= nil and isSeen(f) }
    if f then
        m.key = texShape(f.Bg)
        local global = rawget(_G, "QuestLogPopupDetailFrameBg")
        m.globalIsKey = global == f.Bg
        m.global = texShape(global)
        m.page = T and T.pageOf(f) ~= nil
        m.rock = T and T.rockOf(f, T.pageOf(f)) ~= nil
        m.book = T and T.bookOf(f) ~= nil
        m.levels = { window = levelOf(f), nineSlice = levelOf(f.NineSlice), portraitContainer = levelOf(f.PortraitContainer),
                     abandon = levelOf(f.AbandonButton) }
        local h = T and T.wins[f]
        if h then m.levels.glass, m.levels.art = levelOf(h.win), levelOf(h.art) end
    end
    say("QP structure: .Bg " .. tostring(m.key and m.key.atlas) .. " " .. tostring(m.key and m.key.points)
        .. ", the global is .Bg " .. tostring(m.globalIsKey) .. ", page " .. tostring(m.page) .. ", rock "
        .. tostring(m.rock) .. ", book " .. tostring(m.book))
    record("QP.structure", m)
    return m
end

local function qpState(label)
    local T, G = qpTest()
    local f = frameByName("QuestLogPopupDetailFrame")
    local h = T and f and T.wins[f]
    local r = { shown = f ~= nil and isSeen(f), installed = h ~= nil, paintLight = T and T.popup.paintLight,
                light = lightText(), buttons = 0, buttonsRight = 0 }
    if f then
        local most = 0
        for _, x in ipairs({ f.NineSlice, f.TopTileStreaks, f.Inset and f.Inset.Bg, h and h.rock }) do
            local a = alphaOf(x)
            if a then most = math.max(most, a) end
        end
        r.shell = most
        local page = h and h.page
        local okA, atlas = call(page, "GetAtlas")
        r.atlas = okA and plain(atlas) or nil
        r.pageAlpha = alphaOf(page)
        if h then
            r.header = isSeen(h.header)
            -- Our book over Blizzard's, faded (#206; no disc since #207).
            r.art = h.art ~= nil and isSeen(h.art)
            r.bookAlpha = alphaOf(h.book)
            local okP, _, rel = call(h.pane.fill, "GetPoint", 1)
            r.pane = isSeen(h.pane.fill)
            r.paneOnPage = r.pane and okP and rel == page
        end
        for _, key in ipairs({ "AbandonButton", "TrackButton", "ShareButton" }) do
            local b = f[key]
            if isSeen(b) then
                r.buttons = r.buttons + 1
                local st = T and T.buttons[b]
                if st and isSeen(st.glass) and alphaOf(b.Left) == 0 then r.buttonsRight = r.buttonsRight + 1 end
            end
        end
    end
    local okC, c = pcall(InCombatLockdown)
    r.combat = okC and plain(c) == true
    local n = 0
    for _ in pairs(G and G.failures or {}) do n = n + 1 end
    r.failures = n
    r.blocked = type(SkinProbeDB) == "table" and SkinProbeDB.suiteBlocked or 0
    say("QP " .. label .. ": shown " .. tostring(r.shown) .. ", shell " .. tostring(r.shell) .. ", page "
        .. tostring(r.atlas) .. " at " .. tostring(r.pageAlpha) .. ", pane " .. tostring(r.pane) .. ", last paint light "
        .. tostring(r.paintLight) .. ", text light " .. tostring(r.light) .. ", buttons " .. r.buttonsRight .. "/"
        .. r.buttons .. ", combat " .. tostring(r.combat) .. ", failures " .. r.failures .. ", blocked " .. r.blocked)
    record("QP." .. label, r)
    return r
end

-- want.faded: the page expected faded (true) or kept (false); want.combat.
local function qpOn(label, want)
    want = want or {}
    return function()
        local r = qpState(label)
        local bad = {}
        local function want_(cond, why) if not cond then bad[#bad + 1] = why end end
        want_(r.shown, "the popup not shown")
        want_(r.installed, "not installed")
        want_(r.shell == 0, "shell " .. tostring(r.shell))
        want_(r.header, "the band not shown")
        want_(r.art, "our book not shown")
        want_(r.bookAlpha == 0, "Blizzard's book at " .. tostring(r.bookAlpha))
        want_(r.buttonsRight == r.buttons, "buttons " .. r.buttonsRight .. " of " .. r.buttons)
        if r.pageAlpha == 0 then
            want_(r.atlas == DARK, "a page faded that isn't the dark one")
            want_(r.light ~= false, "dark text over a faded page")
            want_(r.paneOnPage, "no pane on the faded page")
        else
            want_(not r.pane, "a pane over a kept page")
        end
        if want.faded ~= nil then want_((r.pageAlpha == 0) == want.faded, "the page at " .. tostring(r.pageAlpha)) end
        if want.combat ~= nil then want_(r.combat == want.combat, "combat " .. tostring(r.combat)) end
        want_(r.failures == 0, r.failures .. " failure(s): /glassui failures")
        want_(r.blocked == 0, r.blocked .. " blocked")
        return #bad == 0, #bad == 0 and "as planned" or table.concat(bad, "; ")
    end
end

local function qpOff(label)
    return function()
        local r = qpState(label)
        local ok = r.shown and r.shell > 0 and r.pageAlpha ~= 0 and not r.pane and r.buttonsRight == 0
        return ok, ok and "Blizzard's look, nothing of ours" or "something of ours while off"
    end
end

local function qpWait()
    return function()
        local T = qpTest()
        local f = frameByName("QuestLogPopupDetailFrame")
        return f ~= nil and isSeen(f) and T ~= nil and T.wins[f] ~= nil, "waiting for the quest details popup"
    end
end

local function qpSettle(text, check, screenshot)
    local t0
    return { text = text, timeout = 15, screenshot = screenshot, check = check,
             wait = function()
                 t0 = t0 or GetTime()
                 return GetTime() - t0 >= 1, "a moment"
             end,
             leave = function() t0 = nil end }
end

local function liveContrast()
    local ok, v = pcall(GetCVar, "questTextContrast")
    v = ok and plain(v) or nil
    return type(v) == "string" and v or nil
end

-- Light quest text on or off, only with the player's setting saved, and the
-- step stays until the switch and the setting both read the change: a
-- refusal (combat) or a write that didn't hold throws (Codex on #205).
local function lightSwitch(on)
    return function()
        if not (type(SkinProbeDB) == "table" and type(SkinProbeDB.gqContrastWas) == "string") then
            error("your setting wasn't saved: press Stop", 0)
        end
        local G = glassUI()
        local Q = G and G.QuestText
        if not Q then error("Glass UI not loaded", 0) end
        local _, line = (on and Q.On or Q.Off)()
        local value = liveContrast()
        -- Off releases the switch before its write, so a write that didn't
        -- hold leaves the switch off over Dark and every later Off says
        -- "already off". The run's baseline is Default (its first step):
        -- the probe puts it back itself, out of combat (Codex on #205, r2).
        if not on and not Q.IsOn() and value ~= "0" and not InCombatLockdown() then
            setCVar("questTextContrast", "0")
            value = liveContrast()
            line = tostring(line) .. "; Default put back"
        end
        local want = on and "4" or "0"
        if Q.IsOn() ~= on or value ~= want then
            error("Light quest text didn't turn " .. (on and "on" or "off") .. " (" .. tostring(line) .. ", the setting reads "
                .. tostring(value) .. "): out of combat, press Retry", 0)
        end
        return true, tostring(line) .. ", the setting reads " .. tostring(value)
    end
end

local function skinSwitch(key, on)
    return function()
        local G = glassUI()
        if not (G and G.Engine) then return false, "Glass UI not loaded" end
        if key then G.Engine.SetEnabled(key, on) else G.Engine.SetMaster(on) end
        return true, tostring(key or "master") .. " " .. (on and "on" or "off")
    end
end

-- The same popup open, its page still dark, and a new paint recorded dark:
-- a quest-log update, not a reopening (Codex on #202, r2).
local function repaintWait()
    local first, seenAt
    return function()
        local T = qpTest()
        local f = frameByName("QuestLogPopupDetailFrame")
        local h = T and f and T.wins[f]
        if not (h and isSeen(f)) then first = nil return false, "the popup must stay open" end
        local okA, atlas = call(h.page, "GetAtlas")
        if not (okA and plain(atlas) == DARK) then return false, "its page isn't the dark one: reopen it in Dark" end
        first = first or f
        if first ~= f then return false, "reopened" end
        if T.popup.paintLight ~= false then seenAt = nil return false, "loot a quest item with the popup open" end
        -- The page comes back a frame after the paint: settle before the
        -- check reads it (Codex on #205).
        seenAt = seenAt or GetTime()
        return GetTime() - seenAt >= 1, "the text repainted: a moment"
    end
end

Probe:Steps("questpopup", {
    title = "Glass UI: the quest details popup in glass (#202)",
    rev = 3,
    { text = "Turns on script errors, counts blocked actions, turns the taint log on and saves your Quest Text "
          .. "Contrast (put back at the end; /fp skin gqrestore if you stop early). If Light quest text is on, "
          .. "this step stays: /glassui questtext off, then Retry. " .. TAINT_NOISE, auto = true,
      run = function()
          if type(SkinProbeDB) == "table" then SkinProbeDB.suiteBlocked = 0 end
          setCVar("scriptErrors", "1")
          local G = glassUI()
          if G and G.QuestText and G.QuestText.IsOn() then
              error("Light quest text is on: /glassui questtext off, then Retry", 0)
          end
          local ok, why = skinChecks.contrastSave()
          if not ok then error(why, 0) end
          -- The run starts from Default (Codex on #205): a player's own Dark
          -- would fade the first popup and become Light quest text's
          -- remembered value, so its Off could never bring dark text back.
          setCVar("questTextContrast", "0")
          if liveContrast() ~= "0" then error("Quest Text Contrast didn't go to Default: press Retry", 0) end
          setCVar("taintLog", "1")
          return true, why .. "; Default for the run"
      end },
    { text = "Open a quest's details from the objective tracker (right-click a quest > the details). Goes on by "
          .. "itself; a screenshot.", timeout = 600, wait = qpWait(), screenshot = "popup, first",
      check = qpOn("first", { faded = false }) },
    { text = "Reads the structure: the page, the rock, the book icon, the levels. If this step stays, press Stop and "
          .. "tell Claude.", auto = true,
      run = function()
          local m = qpMeasure()
          if not (m.page and m.rock and m.book) then
              error("the structure isn't as planned (page " .. tostring(m.page) .. ", rock " .. tostring(m.rock)
                  .. ", book " .. tostring(m.book) .. ")", 0)
          end
          return true, "the page, the rock and the book found"
      end },
    { text = "Is the book icon on a glass disc, the window in glass, the parchment page with Blizzard's text, "
          .. "Abandon, Track and Share on glass (Share dimmed outside a group)? Anything off: the Note.", ask = true },
    { text = "Press Track twice (untrack, track), then press Next.", check = qpOn("tracked") },
    -- Dark.
    { text = "Turns Light quest text on (Blizzard's Dark quest text).", button = "Light on", run = lightSwitch(true) },
    { text = "Close the popup and open it again from the tracker. Press Next with it open; a screenshot.",
      screenshot = "popup, dark", check = qpOn("dark", { faded = true }) },
    { text = "Is the light text readable on the glass?", ask = true },
    -- The text repainted without its page.
    { text = "With the popup open: turns Light quest text off.", button = "Light off", run = lightSwitch(false) },
    qpSettle("The page stays faded: the text Blizzard painted is still light. Goes on by itself.",
             qpOn("off, no redraw", { faded = true })),
    { text = "Keep the popup open and loot a quest item (or kill a mob a quest counts) so the quest log updates. "
          .. "This step goes on by itself once Blizzard repaints the text; a screenshot.", timeout = 900,
      wait = repaintWait(), screenshot = "popup, repainted", check = qpOn("repainted", { faded = false }) },
    { text = "Was the dark text on bare glass noticeable for a moment before the page came back?", ask = true },
    { text = "Still open: turns Light quest text on again, no reopening.", button = "Light on",
      run = lightSwitch(true) },
    qpSettle("The page stays: the text is still dark. Goes on by itself.", qpOn("dark again, no redraw", { faded = false })),
    { text = "Close the popup and open it again. Press Next with it open.", check = qpOn("reopened", { faded = true }) },
    { text = "Optional: a quest whose details list required money, in Dark. Open it and press Next (a "
          .. "screenshot), Skip if none.", screenshot = "popup, money", check = qpOn("money") },
    -- Off and on.
    { text = "With it open: the popup skin off.", button = "Skin off",
      run = skinSwitch("questpopup", false), check = qpOff("off") },
    { text = "And on again.", button = "Skin on", run = skinSwitch("questpopup", true) },
    qpSettle("The page stays until Blizzard's next paint (the history is unknown). Goes on by itself.",
             qpOn("on again")),
    { text = "The master switch off.", button = "All off", run = skinSwitch(nil, false), check = qpOff("master off") },
    { text = "And on.", button = "All on", run = skinSwitch(nil, true) },
    qpSettle("Goes on by itself.", qpOn("master on")),
    -- Closing, combat.
    { text = "Press Show Map (the map opens on the quest), close it; open the popup again, press Abandon and "
          .. "cancel the dialog; close the popup with its X, open it again and close it with Esc. Press Next.",
      check = function()
          local r = qpState("closed")
          return not r.shown and r.blocked == 0, (r.shown and "still open" or "closed") .. ", " .. r.blocked .. " blocked"
      end },
    { text = "Optional: in combat, open the popup and press Next with it open (Skip if you can't).",
      check = qpOn("in combat", { combat = true }) },
    { text = "Did it read right, with no 'Interface action failed' message or Lua error? The Note.", ask = true },
    { text = "Turns Light quest text off and puts your own Quest Text Contrast back. Out of combat; if this step "
          .. "stays, leave combat and press Retry.", auto = true,
      run = function()
          -- The switch must really be off before the restore, or its next
          -- login re-applies Dark over the restored value (run #513: an Off
          -- refused, then Dark back at the reload; Codex on #205).
          local G = glassUI()
          local Q = G and G.QuestText
          if type(SkinProbeDB) == "table" and type(SkinProbeDB.gqContrastWas) == "string" and Q and Q.IsOn() then
              Q.Off()
              if Q.IsOn() then error("Light quest text didn't turn off: out of combat, press Retry", 0) end
          end
          local ok, why = skinChecks.contrastRestore()
          if not ok then error(why .. ": press Retry", 0) end
          return true, why
      end },
    taintOff(),
    { text = "Type /reload to save the results.", reload = true },
})

Probe:Command("questpopup", function() qpMeasure(); qpState("now") end,
              "#202: the quest details popup: its structure, levels and state now")
skinChecks.qpState, skinChecks.qpOn, skinChecks.qpMeasure = qpState, qpOn, qpMeasure
end)() end

--------------------------------------------------------------------------------
-- Boot
--------------------------------------------------------------------------------

local boot = CreateFrame("Frame")
Probe:RegisterEvents(boot, { "ADDON_LOADED" })
boot:SetScript("OnEvent", function(_, _, name)
    if name ~= ADDON then return end
    Probe:Ready()
    if type(SkinProbeDB) ~= "table" then SkinProbeDB = {} end
    if type(SkinProbeDB.log) ~= "table" then SkinProbeDB.log = {} end
    Probe:UseLog(SkinProbeDB.log, MAX_LOG)
    SkinProbeDB.loads = (SkinProbeDB.loads or 0) + 1
    say("loaded (" .. SkinProbeDB.loads .. " loads). /fp skin for the commands, /fp steps skin wave1 to start")
end)

NS._test = { ltState = skinChecks.ltState, ltOn = skinChecks.ltOn, ltClosed = skinChecks.ltClosed,
    tdState = skinChecks.tdState, tdOn = skinChecks.tdOn, tdClosed = skinChecks.tdClosed,
    mpState = skinChecks.mpState, mpOn = skinChecks.mpOn, mpYield = skinChecks.mpYield,
    mpDescribe = skinChecks.describe, mpStartWatch = skinChecks.startWatch, mpReadWatch = skinChecks.readWatch,
    mpWatchTick = skinChecks.watchTick, chState = skinChecks.chState, chOn = skinChecks.chOn, gdState = skinChecks.gdState, gdOn = skinChecks.gdOn, gmState = skinChecks.gmState, gmOn = skinChecks.gmOn, settingsReturn = skinChecks.settingsReturn, editModeVisit = skinChecks.editModeVisit, bagsState = skinChecks.bagsState,
    bagsOn = skinChecks.bagsOn, atlasRoundTrip = skinChecks.atlasRoundTrip, both = both, closeState = closeState, closeOn = closeOn, headerTry = headerTry, layoutState = layoutState, layoutOn = layoutOn, Probe = Probe, state = state, tree = tree, fade = fade, slashOwners = slashOwners,
             gamepad = gamepad, panelsOn = panelsOn, panelsOff = panelsOff, borderFade = borderFade,
             borderRestore = borderRestore, gradientOn = gradientOn, gradientOff = gradientOff,
             panels = panels, faded = faded, cardAtlas = cardAtlas, cardOn = cardOn, cardOff = cardOff,
             themeTry = themeTry, themeRestore = themeRestore, suiteSet = suiteSet, suiteRestore = suiteRestore,
             suiteState = suiteState, suiteCheck = suiteCheck, suiteSnapshot = suiteSnapshot,
             meterState = meterState, meterStyle = meterStyle, meterBars = meterBars, treeOf = treeOf,
             barTree = barTree, sourceWindow = sourceWindow, barsOn = barsOn, barsOff = barsOff,
             barPanels = barPanels, headersFaded = headersFaded, panelState = panelState,
             panelCheck = panelCheck, panelFollow = panelFollow, panelRestore = panelRestore, ownGlass = ownGlass,
             trackerState = trackerState, trackerOn = trackerOn, questingEnable = questingEnable,
             questingRestore = questingRestore, holdOn = holdOn, holdCheck = holdCheck, holdOff = holdOff,
             coexist = coexist, arrowState = arrowState, seen = seen, lookFor = lookFor, accentState = accentState,
             timerState = timerState, timerOn = timerOn, fakeOn = fakeOn, fakeOff = fakeOff, fakeTimers = fakeTimers,
             merchantRows = merchantRows, rowsOn = rowsOn, floorTry = floorTry, floorRestore = floorRestore,
             rxState = rxState, rxOn = rxOn, raState = raState, raOn = raOn, rxpEnable = rxpEnable,
             gqState = skinChecks.gqState, gqOn = skinChecks.gqOn, gqMeasure = skinChecks.gqMeasure,
             gqHook = skinChecks.gqHook, contrastRestore = skinChecks.contrastRestore,
             contrastSave = skinChecks.contrastSave, qtState = skinChecks.qtState, qtInfo = skinChecks.qtInfo,
             qtStartup = skinChecks.qtStartup, qtBoundaryOk = skinChecks.qtBoundaryOk,
             qpState = skinChecks.qpState, qpOn = skinChecks.qpOn, qpMeasure = skinChecks.qpMeasure }
