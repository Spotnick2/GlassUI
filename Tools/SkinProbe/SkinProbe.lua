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

-- Ellesmere's test (v9.6.1, EllesmereUI_UICore.lua:1308-1312): the current input interface
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
    if not names then say("unknown target " .. show(key) .. " (merchant, popup, character, map, meter)"); return false end
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
        was = { name = T.Name(), backing = T.PRESETS.clear.backing }
        SkinProbeDB.themeWas = was
    end
    T.PRESETS.clear.backing = backing or was.backing
    T.Set(name)
    local used = T.PRESETS[name].backing
    say("THEME " .. name .. " backing " .. num(used))
    return name, used
end

local function themeRestore()
    local G = glassUI()
    local was = type(SkinProbeDB) == "table" and SkinProbeDB.themeWas or nil
    if not (type(was) == "table" and G and G.Theme) then return true end
    G.Theme.PRESETS.clear.backing = was.backing
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

Probe:Steps("merchant", {
    title = "Glass UI: the merchant skin",
    { text = "Turns on script errors and the taint log (Logs\\taint.log), and reads the skin's switch. "
          .. "With the taint log on, Blizzard's own code throws 'attempt to call a nil value' errors "
          .. "(tooltips, the bag bar): ignore those. A /reload turns the log off again.",
      auto = true, run = function()
          return setCVar("scriptErrors", "1"), setCVar("taintLog", "1"), merchantState("start")
      end,
      check = function() local s = merchantState("check"); return s == "on", s end },
    { text = "Talk to any vendor.", event = "MERCHANT_SHOW" },
    { text = "The merchant window in glass. Press Next for a screenshot.", screenshot = "merchant, skinned",
      check = function() return nineAlpha() == 0, merchantState("shown") end },
    { text = "Can you read every item name and price clearly?", ask = true },
    { text = "Now the looks, one screenshot each. First: clear with the dense backing it had before #4 (0.85).",
      button = "Clear 0.85", run = function() return themeTry("clear", 0.85) end, screenshot = "merchant, clear 0.85" },
    { text = "Clear with a lighter backing (0.6).", button = "Clear 0.6",
      run = function() return themeTry("clear", 0.6) end, screenshot = "merchant, clear 0.6" },
    { text = "Clear with a much lighter backing (0.35).", button = "Clear 0.35",
      run = function() return themeTry("clear", 0.35) end, screenshot = "merchant, clear 0.35" },
    { text = "Smoked.", button = "Smoked", run = function() return themeTry("smoked") end,
      screenshot = "merchant, smoked" },
    { text = "Class colour.", button = "Class", run = function() return themeTry("class") end,
      screenshot = "merchant, class" },
    { text = "Did one of the lighter clears (0.6 or 0.35) read well AND look more like glass than 0.85? "
          .. "Say which you liked best in the Note box.", ask = true },
    { text = "Puts your theme back.", button = "Restore", run = themeRestore },
    { text = "Buy one cheap item. Did it land in your bags, and the money go?", ask = true },
    { text = "Sell an item from your bags (right-click it). Did it sell?", ask = true },
    { text = "Open the Buyback tab, then press Next for a screenshot.", screenshot = "merchant, buyback tab",
      check = function() return nineAlpha() == 0, merchantState("buyback") end },
    { text = "Buy back the item you sold. Did it come back?", ask = true },
    { text = "Go back to the Merchant tab. If this vendor repairs and something of yours is damaged, "
          .. "repair it. Did it work? (No if you couldn't test it, and say why in the Note.)", ask = true },
    { text = "Switches the skin off, live.", button = "Skin off", screenshot = "merchant, skin off",
      run = function() return switch(false), merchantState("off") end,
      check = function() return nineAlpha() == 1, "the border is back" end },
    { text = "Does the window look exactly like Blizzard's own again?", ask = true },
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
    { text = "Type /reload to save the results.", reload = true },
})

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
    { text = "S.7: turns the taint log on (Logs\\taint.log). With it on, Blizzard's own code throws 'attempt to "
          .. "call a nil value' errors: ignore those. The next /reload turns it off.",
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
          .. "script errors and the taint log (Blizzard's own 'attempt to call a nil value' errors then are "
          .. "noise: ignore them).",
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
    { text = "Type /reload to save the results (and turn the taint log off).", reload = true },
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
    { text = "Turns on script errors and the taint log (Logs\\taint.log), and reads the skin. With the taint log "
          .. "on, Blizzard's own code throws 'attempt to call a nil value' errors (tooltips, the bag bar): ignore "
          .. "those. A /reload turns the log off. Have a few quests tracked and the tracker expanded.",
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
    { text = "Turns the taint log on again for the quest routine (the reload turned it off).", auto = true,
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
    { text = "Type /reload to save the results (and turn the taint log off).", reload = true },
})

Probe:Command("tracker", function() trackerState("now") end, "the quest tracker skin: its switch, panel and regions")

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
-- like its clear and smoked themes (Theme.PRESETS: tint, wash, backing).
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
                local p, c = G.Theme.PRESETS[name], G.Theme.BACKING
                local backing = f:CreateTexture(nil, "BACKGROUND", nil, -7)
                backing:SetAllPoints(f)
                backing:AddMaskTexture(g.mask)
                backing:SetColorTexture(c[1], c[2], c[3], p.backing)
                pcall(G.Glass.SetSurfaceTint, g, p.tint[1], p.tint[2], p.tint[3], p.tint[4])
                pcall(G.Glass.SetWash, g, p.wash)
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
          .. "With the taint log on, Blizzard's own code throws 'attempt to call a nil value' errors "
          .. "(tooltips, the bag bar): ignore those. A /reload turns the log off again.",
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

NS._test = { Probe = Probe, state = state, tree = tree, fade = fade, slashOwners = slashOwners,
             gamepad = gamepad, panelsOn = panelsOn, panelsOff = panelsOff, borderFade = borderFade,
             borderRestore = borderRestore, gradientOn = gradientOn, gradientOff = gradientOff,
             panels = panels, faded = faded, cardAtlas = cardAtlas, cardOn = cardOn, cardOff = cardOff,
             themeTry = themeTry, themeRestore = themeRestore, suiteSet = suiteSet, suiteRestore = suiteRestore,
             suiteState = suiteState, suiteCheck = suiteCheck, suiteSnapshot = suiteSnapshot,
             meterState = meterState, meterStyle = meterStyle, meterBars = meterBars, treeOf = treeOf,
             barTree = barTree, sourceWindow = sourceWindow, barsOn = barsOn, barsOff = barsOff,
             barPanels = barPanels, headersFaded = headersFaded, panelState = panelState,
             panelCheck = panelCheck, panelFollow = panelFollow, panelRestore = panelRestore, ownGlass = ownGlass,
             trackerState = trackerState, trackerOn = trackerOn }
