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
-- The only writes to Blizzard objects are SetAlpha, always put back at once
-- (`fade`) or by `border restore`, and our own frames parented to the map.
-- Every client call that may be missing or throw goes through Probe:Try or a
-- pcall, so one refusal can't stop the rest.

local ADDON, NS = ...
-- The trees are long (the character sheet alone is ~1800 lines): at 6000 the
-- first run's oldest tenth, the state lines, was trimmed away (70374).
local MAX_LOG = 20000
local MAX_TREE_LINES = 700        -- per target, so one window can't flood the log

local Probe = ForeverProbe:Module("SkinProbe", { api = 1, cmd = "skin" })

local function say(msg) Probe:Say(msg) end
local function show(v) return Probe.Show(v, true) end

-- v, or nil when it is secret (never compared or concatenated then).
local function plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

-- obj:method(...) under pcall: ok, ... (false when the method is absent).
local function call(obj, method, ...)
    local fn = obj and obj[method]
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
}
local ORDER = { "merchant", "popup", "character", "map" }
NS.TARGETS = TARGETS

-- The neighbours the skins must coexist with or step aside for (docs/PLAN.md).
local NEIGHBOURS = { "Leatrix_Maps", "Auctionator", "Skilled", "ElvUI", "EllesmereUI", "Tukui",
                     "GlassMail", "GlassActionBars", "GlassChat", "GlassQuestTracker", "GlassMiniMap",
                     "GlassMiniMapBar", "GlassUnitFrames", "GlassRaidFrames", "GlassPanel", "GlassMaps" }

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

-- Ellesmere's test (EllesmereUI_UICore.lua:1305): the current input interface
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
    if not names then say("unknown target " .. show(key) .. " (merchant, popup, character, map)"); return false end
    for _, name in ipairs(names) do
        local f = frameByName(name)
        if f then fn(f, name) else say(key .. " " .. name .. " MISSING") end
    end
    return true
end

local function tree(key, depth)
    depth = tonumber(depth) or 4
    local lines = 0
    eachTarget(key, function(f, name)
        local budget = { n = 0, max = MAX_TREE_LINES }
        walk(f, name, depth, function(kind, obj, path)
            lines = lines + 1
            if kind == "frame" then frameLine(obj, "W1.2 F " .. path) else say("W1.2 R " .. regionLine(obj, path)) end
        end, budget)
        if budget.n > budget.max then say("W1.2 " .. name .. " TRUNCATED at " .. budget.max .. " lines") end
    end)
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
        end, { n = 0, max = MAX_TREE_LINES })
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
-- Commands
--------------------------------------------------------------------------------

Probe:Command("state", function() state() end, "W1.1/W1.4/W1.5: frames, gamepad style, /gui, neighbours")
Probe:Command("tree", function(args)
    local key, depth = (args or ""):match("^%s*(%S*)%s*(%S*)")
    tree(key, depth)
end, "W1.2: tree <merchant|popup|character|map> [depth]: every frame and region")
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
             panels = panels, faded = faded }
