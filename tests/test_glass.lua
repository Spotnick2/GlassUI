-- Glass UI's own glass on the suite theme (#54, docs/QUEST-TRACKER.md part 1):
-- built once at ADDON_LOADED with the theme's preset, the clean fallback on
-- an older library, the early-panel guard, and the body's wash as a factor of
-- the material's (Pearl 0.10, clean 0.18).
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local function chat() return table.concat(WoW.chat, "\n") end
local function failures(G)
    local keys = {}
    for k in pairs(G.failures) do keys[#keys + 1] = k end
    return table.concat(keys, ",")
end

-- LibStub as the client has it, but answering `minor` for LibGlass, or with
-- a New that throws `err`.
local function fakeLib(minor, err)
    return function()
        local real = LibStub
        LibStub = setmetatable({}, {
            __index = real,
            __call = function(_, name, silent)
                local lib, m = real(name, silent)
                if name ~= "LibGlass-1.0" then return lib, m end
                if err then
                    local proxy = setmetatable({}, { __index = lib })
                    proxy.New = function(self, opts)
                        if opts and opts.preset ~= "clean" then error(err, 2) end
                        return lib:New(opts)
                    end
                    return proxy, m
                end
                return lib, minor
            end,
        })
    end
end

-- The library as checked out: Pearl from r11 on. CI loads the .pkgmeta pin (r11).
local GUI = loadAddon()
local _, minor = LibStub("LibGlass-1.0")
if minor >= 11 then
    eq(GUI.Glass.preset, "pearl", "built on the suite theme: Pearl")
    eq(GUI.glassPreset, "pearl", "and recorded as such")
    eq(GUI.glassWhy, nil, "with nothing to explain")
    near(GUI.Glass.STYLE.wash, 0.10, "Pearl's wash")
else
    io.write("NOTE: LibGlass checkout is r" .. minor .. ", older than the pin: the Pearl case runs in CI\n")
    eq(GUI.glassPreset, "clean", "an older checkout builds clean")
end
check(GUI.Glass ~= LibStub("LibGlass-1.0"), "our own instance, not the library")
local first = GUI.Glass
eq(GUI.BuildGlass(), first, "built once: a second call returns the same instance")
eq(failures(GUI), "", "no failure recorded")

-- An older library: the clean look from before #54, said by /glassui suite.
GUI = loadAddon({ before = fakeLib(10) })
eq(GUI.Glass.preset, "clean", "a library older than r11 builds clean")
eq(GUI.glassWhy, "library-too-old", "and says why")
near(GUI.Glass.STYLE.wash, 0.18, "clean's wash")
WoW.chat = {}
GUI._test.slash("suite")
check(chat():find("Glass UI's own skins: clean, not the suite theme (LibGlass older than r11", 1, true),
      "/glassui suite says so: " .. chat())
GUI = loadAddon()
WoW.chat = {}
GUI._test.slash("suite")
check(not chat():find("own skins", 1, true), "and says nothing when the theme was built")

-- A copy that doesn't know the preset, or fails another way.
GUI = loadAddon({ before = fakeLib(11, 'LibGlass-1.0: unknown preset pearl (use "classic", "clean")') })
eq(GUI.glassPreset, "clean", "an unknown preset falls back to clean")
eq(GUI.glassWhy, "library-too-old", "as a library too old for it")
GUI = loadAddon({ before = fakeLib(11, "LibGlass-1.0: the loaded copy did not finish loading") })
eq(GUI.glassPreset, "clean", "a failed build falls back to clean")
eq(GUI.glassWhy, "build-failed", "and says it failed")

-- The preset is the saved theme's, read when the saved variables are in.
GUI = loadAddon({
    db = { suite = { theme = "plain" } },
    before = function() GlassUI.Suite.THEMES.plain = { label = "Plain", preset = "clean" } end,
})
eq(GUI.glassPreset, "clean", "the saved theme's preset is built")
eq(GUI.glassWhy, nil, "as asked, not as a fallback")

-- A panel before ADDON_LOADED: recorded, and the glass built for it, no error.
local early
GUI = loadAddon({ before = function()
    local kit = GlassUI.Kit.New({ def = { key = "early" } })
    early = { pcall(kit.Panel, kit, CreateFrame("Frame")) }
end })
check(early[1] and early[3] ~= nil, "the early panel is made: " .. tostring(early[2]))
check(GUI.failures["kit:early:early"] ~= nil, "and recorded as a bug of ours")
check(GUI.Glass ~= nil, "the glass was built for it")

-- The body's wash: a factor of the material's, at first paint and live.
local function washes(G)
    local seen, mine = {}, nil
    local real = G.Glass.SetWash
    G.Glass.SetWash = function(g, v)
        if g == mine then seen[#seen + 1] = v end   -- this surface's paints, not the skins' panels'
        return real(g, v)
    end
    local f = CreateFrame("Frame")
    local g = G.Glass.Apply(f, "small")
    mine = g
    G.Theme.Register(g, f:CreateTexture())
    G.Theme.Set("smoked")
    G.Theme.Set("clear")
    G.Glass.SetWash = real
    return seen
end
GUI = loadAddon()
if GUI.glassPreset == "pearl" then
    local w = washes(GUI)
    near(w[1], 0.10, "Pearl: clear's wash is Pearl's own, at first paint")
    near(w[2], 0.10 * 0.14 / 0.18, "smoked's is scaled, as on clean")
    near(w[3], 0.10, "back to clear: Pearl's own again")
end
GUI = loadAddon({ before = fakeLib(10) })
local w = washes(GUI)
near(w[1], 0.18, "clean fallback: clear paints 0.18, as before #54")
near(w[2], 0.14, "smoked paints 0.14, as before #54")
near(w[3], 0.18, "and clear 0.18 again")

done("test_glass")
