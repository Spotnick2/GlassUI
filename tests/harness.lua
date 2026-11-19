-- harness.lua: the addon loader. dofile it after wow_stubs.lua.
-- check, eq and done are WowTestKit's (done() also fails on a stray "|" in
-- any printed line); near is Glass UI's own.

function near(actual, expected, msg)
    check(type(actual) == "number" and math.abs(actual - expected) < 1e-6,
        string.format("%s: expected %s, got %s", msg, tostring(expected), tostring(actual)))
end

-- FINDING: Glass UI's help and usage lines join their choices with a bare
-- "|" ("on|off"), which the client reads as an escape (GlassChat #55):
-- GlassUI.lua:75-79, 105, 145, 155-157 (and 173, 181, which no test prints).
-- The kit's done() fails on a stray "|"; until they're doubled ("||"), in
-- their own issue, acceptKnownStrays() lets exactly these lines through and
-- returns how many it took out, so any other stray still fails.
local KNOWN_STRAYS = {}
for _, rest in ipairs({
    "/glassui skin <name> on|off - one skin",
    "/glassui on|off - every skin (the master switch)",
    "/glassui theme clear|smoked|class - the glass (the suite look's tint)",
    "/glassui suite follow <addon> on|off - an addon follows Glass UI (after /reload)",
    "/glassui suite follow <addon> on|off, e.g. GlassUnitFrames",
    "/glassui look tint|accent|hover|press|empty|preset <value>",
    "  tint: clear|smoked|class",
    "  hover: off|glow|halo",
    "  press: off|flash|ripple",
    "  empty: hidden|faint|half|full|frosted",
    "  accent: gold|ice",
    "  preset: glass|soft|minimal",
}) do KNOWN_STRAYS["|cff7fd4ffGlassUI|r " .. rest] = true end
function acceptKnownStrays()
    local keep, known = {}, 0
    for _, line in ipairs(WoW.strays) do
        if KNOWN_STRAYS[line] then known = known + 1 else keep[#keep + 1] = line end
    end
    WoW.strays = keep
    return known
end

TOC = "GlassUI.toc"
-- Every file line of the TOC, in load order, as written; its Lua files as paths.
function tocLines() return Kit.tocLines(TOC) end
function tocFiles() return Kit.tocFiles(TOC) end

-- The embedded LibGlass-1.0 comes from a checkout, not from Libs\ (gitignored,
-- filled by the packager): $LIBGLASS, else ../LibGlass. No checkout fails the
-- run loudly; a silently skipped library would test nothing.
LIBGLASS_XML = "Libs\\LibGlass-1.0\\LibGlass-1.0.xml"
function libGlassRoot()
    local root = (os.getenv("LIBGLASS") or "../LibGlass"):gsub("\\", "/"):gsub("/$", "")
    local f = io.open(root .. "/LibGlass-1.0.xml", "rb")
    if not f then
        error("LibGlass checkout not found at " .. root .. " (no LibGlass-1.0.xml): clone "
              .. "github.com/Spotnick2/LibGlass there or set LIBGLASS", 0)
    end
    f:close()
    return root
end

-- The Lua files the library's XML loads, as paths, in order.
function libGlassScripts()
    local root = libGlassRoot()
    local f = assert(io.open(root .. "/LibGlass-1.0.xml", "rb"))
    local xml = f:read("*a"):gsub("<!%-%-.-%-%->", "")   -- listed in a comment is not loaded
    f:close()
    local files = {}
    for file in xml:gmatch('<Script%s+file="([^"]+)"') do
        local path = root .. "/" .. file:gsub("\\", "/")
        local src = io.open(path, "rb")
        if not src then error("LibGlass checkout at " .. root .. " is missing " .. file, 0) end
        src:close()
        files[#files + 1] = path
    end
    if #files == 0 then error("LibGlass-1.0.xml at " .. root .. " lists no Script files", 0) end
    return files
end

-- Load the addon the way the client does, in a fresh session: every TOC line
-- with (name, ns), the library's XML expanded in place, then ADDON_LOADED,
-- PLAYER_LOGIN and PLAYER_ENTERING_WORLD.
-- Blizzard's always-loaded windows exist before any addon, as FrameXML loads
-- first: the merchant (opts.noMerchant: a client without it) and the damage
-- meter (opts.noMeter) and the objective tracker (opts.noTracker); the quest
-- dialog's portrait QuestFrame's own texture with opts.questOwn.
-- opts.db: saved variables. opts.before(): runs after the files load and
-- before ADDON_LOADED.
function loadAddon(opts)
    opts = opts or {}
    GlassUI, GlassUIDB, LibStub = nil, nil, nil
    WoW.reset()
    if not opts.noMerchant then WoW.makeMerchant() end
    if not opts.noMeter then WoW.makeMeter() end
    if not opts.noBags then WoW.makeBags() end
    if not opts.noGameMenu then WoW.makeGameMenu() end
    if not opts.noGuild then WoW.makeCommunities() end
    if not opts.noCharacter then WoW.makeCharacter() end
    if not opts.noMap then WoW.makeWorldMap() end
    if not opts.noLoot then WoW.makeLoot() end
    if not opts.noTrade then WoW.makeTrade() end
    if not opts.noGossip then WoW.makeGossip() end
    if not opts.noQuest then WoW.makeQuest(opts.questOwn) end
    if not opts.noMirror then WoW.makeMirrorTimers() end
    if not opts.noTracker then WoW.makeTracker() end
    if not (opts.noTracker or opts.noTimer) then WoW.makeQuestTimer() end
    local ns = {}
    for _, line in ipairs(tocLines()) do
        local files
        if line == LIBGLASS_XML then
            files = libGlassScripts()
        elseif line:match("%.lua$") then
            files = { (line:gsub("\\", "/")) }
        else
            error("the harness can't load TOC line " .. line, 0)
        end
        for _, file in ipairs(files) do
            local chunk = assert(loadfile(file))
            chunk("GlassUI", ns)
        end
    end
    if opts.db then GlassUIDB = opts.db end
    if opts.before then opts.before() end
    WoW.fire("ADDON_LOADED", "GlassUI")
    WoW.fire("PLAYER_LOGIN")
    WoW.fire("PLAYER_ENTERING_WORLD", true, false)
    WoW.flushTimers(0)
    return GlassUI
end

-- ForeverProbe, the host SkinProbe depends on, from its checkout
-- ($FOREVERPROBE, else ..\ForeverProbe). Loaded into THIS stub environment,
-- the way the client loads a dependency: its files, then its ADDON_LOADED
-- (GlassChat's loadForeverProbe, ForeverProbe GUIDE section 8).
-- ForeverProbe is private and lives on the owner's disk, so the probe's tests
-- run locally only: CI sets FOREVERPROBE_OPTIONAL=1 and the probe's test file
-- exits cleanly. Locally, without it, a missing checkout is an error, never a
-- silent skip.
function loadForeverProbe()
    local root = (os.getenv("FOREVERPROBE") or "../ForeverProbe"):gsub("\\", "/"):gsub("/$", "")
    local toc = io.open(root .. "/ForeverProbe.toc", "rb")
    if not toc then
        if os.getenv("FOREVERPROBE_OPTIONAL") == "1" then
            io.write("SKIPPED: ForeverProbe isn't here (private, local only); the probe tests run locally\n")
            os.exit(0)
        end
        error("ForeverProbe checkout not found at " .. root .. ": clone it there or set FOREVERPROBE", 0)
    end
    local files = {}
    for line in toc:read("*a"):gmatch("[^\r\n]+") do
        if line:match("%.lua$") and not line:match("^#") then files[#files + 1] = root .. "/" .. line end
    end
    toc:close()
    for _, file in ipairs(files) do assert(loadfile(file))("ForeverProbe", {}) end
    WoW.fire("ADDON_LOADED", "ForeverProbe")
    return ForeverProbe
end
