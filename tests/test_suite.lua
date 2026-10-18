-- The suite contract (docs/SUITE.md): what Glass UI answers each Glass addon,
-- what it records, the states its page shows, and that it never reads or
-- writes another addon's SavedVariables.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local function chat()
    local s = table.concat(WoW.chat, "\n")
    WoW.chat = {}
    return s
end

-- A sibling at its own ADDON_LOADED, the way the contract asks.
local function ask(addon)
    local G = rawget(_G, "GlassUI")
    local ok, t, why = pcall(G.Suite.Theme, addon)
    check(ok, "Theme never errors (" .. tostring(addon) .. ")")
    return t, why
end

-- The API exists before Glass UI's ADDON_LOADED, and answers "not-ready".
local early = {}
local GUI = loadAddon({ before = function()
    local S = GlassUI.Suite
    early.api = S.API
    early.fns = type(S.Theme) == "function" and type(S.Report) == "function" and type(S.Ready) == "function"
    early.ready = S.Ready()
    early.t, early.why = S.Theme("GlassUnitFrames")
end })
local Suite = GUI.Suite
eq(early.api, 1, "Suite.API is 1 at file scope")
check(early.fns, "Theme, Report and Ready exist at file scope")
eq(early.ready, false, "not ready before Glass UI's ADDON_LOADED")
eq(early.t, nil, "no theme before ready")
eq(early.why, "not-ready", "the reason is not-ready")
eq(Suite.Ready(), true, "ready after Glass UI's ADDON_LOADED")
eq(Suite.AnswerOf("GlassUnitFrames").ready, false, "the early answer is recorded as given before ready")

-- Nobody follows by default.
local t, why = ask("GlassRaidFrames")
eq(t, nil, "no theme for an addon that doesn't follow")
eq(why, "not-following", "the reason is not-following")
eq(next(GlassUIDB), nil, "nothing saved by asking")

-- Anything outside the roster, and junk, gets "unknown" and isn't recorded.
for _, name in ipairs({ "Bagnon", "", 42 }) do
    t, why = ask(name)
    eq(why, "unknown", "unknown addon: " .. tostring(name))
end
t, why = ask(nil)
eq(why, "unknown", "a nil addon")
t, why = ask({})
eq(why, "unknown", "a table as addon")
eq(Suite.AnswerOf("Bagnon"), nil, "an unknown addon isn't recorded")

-- Following: a fresh table each call, never ours.
check(Suite.SetFollow("GlassRaidFrames", true), "SetFollow on a roster member")
t = ask("GlassRaidFrames")
check(type(t) == "table" and t.name == "pearl" and t.preset == "pearl", "a follower gets { name = pearl, preset = pearl }")
t.preset = "junk"
local t2 = ask("GlassRaidFrames")
eq(t2.preset, "pearl", "the answer is a fresh table: changing one doesn't change the next")
eq(Suite.AnswerOf("GlassRaidFrames").preset, nil, "the recorded answer is the first one (built with), not a later one")
check(GlassUIDB.suite and GlassUIDB.suite.follow and GlassUIDB.suite.follow.GlassRaidFrames == true,
      "the switch is saved in GlassUIDB.suite.follow")
eq(GlassUIDB.suite.theme, nil, "the default theme isn't saved")
Suite.SetFollow("GlassRaidFrames", false)
eq(GlassUIDB.suite, nil, "unfollowing the last addon leaves nothing saved")
eq(Suite.SetFollow("Bagnon", true), false, "SetFollow refuses an addon outside the roster")
eq(GlassUIDB.suite, nil, "and saves nothing for it")

-- A reload with a saved follower: the answer is Pearl at once.
GUI = loadAddon({ db = { suite = { follow = { GlassUnitFrames = true } } } })
Suite = GUI.Suite
t = ask("GlassUnitFrames")
eq(t and t.preset, "pearl", "a saved follower gets Pearl after a reload")
eq(Suite.AnswerOf("GlassUnitFrames").ready, true, "asked after ready")
eq(Suite.AnswerOf("GlassUnitFrames").preset, "pearl", "the answer it built with is recorded")

-- An unknown saved theme falls back to Pearl; a junk saved suite answers nothing.
GUI = loadAddon({ db = { suite = { theme = "gold", follow = { GlassUnitFrames = true } } } })
t = ask("GlassUnitFrames")
eq(t and t.name, "pearl", "an unknown saved theme falls back to Pearl")
GUI = loadAddon({ db = { suite = "junk" } })
t, why = ask("GlassUnitFrames")
eq(why, "not-following", "a junk saved suite is not following, and no error")
GUI = loadAddon({ db = { suite = { follow = "junk" } } })
t, why = ask("GlassUnitFrames")
eq(why, "not-following", "a junk follow table is not following")

-- Report copies plain values only, and keeps the functions.
GUI = loadAddon()
Suite = GUI.Suite
local opened = 0
local state = { api = 1, built = "pearl", reason = 7, minor = 11, options = function() opened = opened + 1 end,
                clickCast = { open = "nope", others = true }, extra = {} }
Suite.Report("GlassRaidFrames", state)
local r = Suite.ReportOf("GlassRaidFrames")
eq(r.api, 1, "api copied")
eq(r.built, "pearl", "built copied")
eq(r.reason, nil, "a non-string reason dropped")
eq(r.minor, 11, "minor copied")
eq(type(r.options), "function", "options kept as a function")
eq(r.clickCast.open, nil, "a non-function open dropped")
eq(r.clickCast.others, true, "others copied")
eq(r.extra, nil, "an unknown field ignored")
state.built = nil
eq(Suite.ReportOf("GlassRaidFrames").built, "pearl", "the report is a copy: later changes to the caller's table don't reach it")
check(Suite.ReportOf("GlassRaidFrames") ~= state, "never the caller's table")
check(pcall(Suite.Report, "GlassRaidFrames", "junk"), "Report with junk doesn't error")
check(pcall(Suite.Report, nil, {}), "Report with no addon doesn't error")
check(pcall(Suite.Report, "Bagnon", { built = "pearl" }), "Report from outside the roster doesn't error")
eq(Suite.ReportOf("Bagnon"), nil, "and isn't kept")
Suite.Report("GlassRaidFrames", { api = 1 })
eq(Suite.ReportOf("GlassRaidFrames").built, nil, "a second report replaces the first")
Suite.Report("GlassRaidFrames", { api = 1, clickCast = { others = false } })
eq(Suite.ReportOf("GlassRaidFrames").clickCast.others, false, "a false setting is kept as false, not dropped")
local trap = setmetatable({}, { __index = function() error("a proxy that throws") end })
check(pcall(Suite.Report, "GlassRaidFrames", trap), "a report table that throws on read doesn't reach the caller")

-- The states table, first match wins.
local function setup(db)
    GUI = loadAddon({ db = db })
    Suite = GUI.Suite
    WoW.installed = { GlassUnitFrames = 2, GlassRaidFrames = 2, GlassChat = 2, GlassMail = 0, GlassPanel = 2 }
    WoW.loaded.GlassUnitFrames, WoW.loaded.GlassRaidFrames, WoW.loaded.GlassChat = true, true, true
end
setup()
eq(Suite.State("GlassActionBars"), "missing", "not installed")
eq(Suite.State("GlassMail"), "disabled", "installed, disabled for this character")
eq(WoW.enableAskedFor, WoW.GUID, "the enable state is asked for the character's GUID, never a name")
eq(Suite.State("GlassPanel"), "unloaded", "installed and enabled, not loaded")
eq(Suite.State("GlassChat"), "other", "loaded, never spoke the API: not yet integrated")
eq(Suite.State("GlassUnitFrames"), "other", "an integrated addon that hasn't spoken yet counts the same")
ask("GlassUnitFrames")
eq(Suite.State("GlassUnitFrames"), "silent", "asked, never reported")
Suite.Report("GlassUnitFrames", { api = 1 })
local s, pending = Suite.State("GlassUnitFrames")
eq(s, "own", "asked, not following, reported its own look")
eq(pending, false, "nothing pending")
Suite.SetFollow("GlassUnitFrames", true)
s, pending = Suite.State("GlassUnitFrames")
eq(s, "own", "following switched on: it still has its own look this session")
eq(pending, true, "and a reload is pending")
chat()
GUI._test.slash("suite")
local out = chat()
check(out:find("Glass Unit Frames: own look; set to follow %- /reload to apply"), "/glassui suite: own look, set to follow, reload pending")
check(out:find("Glass Chat: not yet integrated", 1, true), "/glassui suite: not yet integrated")
check(out:find("Glass Action Bars: not installed", 1, true), "/glassui suite: not installed")
check(out:find("suite theme: Pearl", 1, true), "/glassui suite: the theme")
check(not out:find("click-casting", 1, true), "no click-casting line without GRF's report")

-- A follower that built Pearl, and one that failed.
setup({ suite = { follow = { GlassUnitFrames = true, GlassRaidFrames = true } } })
ask("GlassUnitFrames")
Suite.Report("GlassUnitFrames", { api = 1, built = "pearl", minor = 11 })
s, pending = Suite.State("GlassUnitFrames")
eq(s, "following", "told Pearl, built Pearl")
eq(pending, false, "nothing pending")
ask("GlassRaidFrames")
Suite.Report("GlassRaidFrames", { api = 1, reason = "library-too-old", minor = 10,
                                   clickCast = { open = function() end, others = false } })
eq(Suite.State("GlassRaidFrames"), "failed", "told Pearl, reported its own look")
GUI._test.slash("suite")
out = chat()
check(out:find("Glass Unit Frames: following Glass UI (Pearl)", 1, true), "/glassui suite: following (Pearl)")
check(out:find("Glass Raid Frames: Pearl failed, own look: library-too-old", 1, true), "/glassui suite: the failure and its reason")
check(out:find("its bindings on other addons' frames: off", 1, true), "the click-casting line shows GRF's setting")
-- Unfollowing a failed one: the failure stays visible beside the pending reload.
Suite.SetFollow("GlassRaidFrames", false)
s, pending = Suite.State("GlassRaidFrames")
eq(s, "failed", "a failure stays visible after the switch changes")
eq(pending, true, "beside the pending reload")

-- Asked before ready: the load order failed. It wins over everything after it.
GUI = loadAddon({ db = { suite = { follow = { GlassUnitFrames = true } } },
                  before = function() GlassUI.Suite.Theme("GlassUnitFrames") end })
Suite = GUI.Suite
WoW.installed.GlassUnitFrames, WoW.loaded.GlassUnitFrames = 2, true
eq(Suite.State("GlassUnitFrames"), "early", "asked before ready, before any report: still started before Glass UI")
Suite.Report("GlassUnitFrames", { api = 1 })
s, pending = Suite.State("GlassUnitFrames")
eq(s, "early", "asked before ready: started before Glass UI")
eq(pending, true, "a reload would change it")

-- /glassui suite follow.
setup()
GUI._test.slash("suite follow glassunitframes on")
eq(Suite.Following("GlassUnitFrames"), true, "/glassui suite follow <name> on")
check(chat():find("Glass Unit Frames:", 1, true), "it prints the member's line")
GUI._test.slash("suite follow GlassUnitFrames off")
eq(Suite.Following("GlassUnitFrames"), false, "/glassui suite follow <name> off (any case)")
chat()
GUI._test.slash("suite follow glassraidframes maybe")
eq(Suite.Following("GlassRaidFrames"), false, "a bad on/off changes nothing")
check(chat():find("/glassui suite follow <addon> on|off", 1, true), "and prints the usage")
GUI._test.slash("suite follow bagnon on")
check(chat():find("/glassui suite follow <addon> on|off", 1, true), "an addon outside the roster prints the usage")
eq(GlassUIDB.suite, nil, "and saves nothing")

-- The settings page (the owner's mockup): registered at login, built on the
-- first show; a card per member that speaks the API, the rest folded under
-- "Theme sync unavailable"; click-casting; the reload footer.
setup({ suite = { follow = { GlassUnitFrames = true } } })
check(WoW.settingsCategory and WoW.settingsCategory.name == "Glass UI", "the page is registered at login")
ask("GlassUnitFrames")
local optsOpened, ccOpened = 0, 0
Suite.Report("GlassUnitFrames", { api = 1, built = "pearl", options = function() optsOpened = optsOpened + 1 end })
ask("GlassRaidFrames")
Suite.Report("GlassRaidFrames", { api = 1, options = function() error("its own bug") end,
                                   clickCast = { open = function() ccOpened = ccOpened + 1 end, others = true } })
local O = GUI.Options._test
O.panel:Show()
local rows = O.rows
eq(O.presetName:GetText(), "Pearl", "the suite preset card names the theme")
check(O.pearl ~= nil, "the preset card shows a pearl")
eq(O.pearl:GetTexture(), 134122, "the Iridescent Pearl's own icon, read from the client by item")
eq(rows.GlassUnitFrames.card:IsShown(), true, "a card for a member that speaks the API")
eq(rows.GlassChat.card:IsShown(), false, "no card for one that doesn't")
eq(rows.GlassUnitFrames.line:GetText(), "Glass UI preset: Pearl", "a follower's card: Glass UI preset: Pearl")
eq(rows.GlassRaidFrames.line:GetText(), "Using addon settings", "a non-follower's card: Using addon settings")
eq(rows.GlassUnitFrames.follow:GetChecked(), true, "Use Glass UI appearance is checked when it follows")
eq(rows.GlassUnitFrames.open:IsShown(), true, "a Settings button when it reported one")
eq(O.foldText:GetText(), "Theme sync unavailable (7)", "the other seven are folded")
eq(O.list:IsShown(), false, "folded at first")
O.fold:Click()
eq(O.list:IsShown(), true, "a click unfolds them")
check(O.list:GetText():find("Glass Chat: not yet integrated", 1, true), "each with its state")
check(O.list:GetText():find("Glass Action Bars: not installed", 1, true), "an uninstalled one too")
O.fold:Click()
eq(O.list:IsShown(), false, "and folds them again")
rows.GlassUnitFrames.open:Click()
eq(optsOpened, 1, "Settings calls the member's own function")
rows.GlassRaidFrames.open:Click()
check(GUI.failures["suite:options:GlassRaidFrames"], "a member's failing Settings is caught and recorded, not ours to crash on")
GUI.failures["suite:options:GlassRaidFrames"] = nil
eq(O.clickCast:GetText(), "Bindings on other addons' frames: Enabled", "the click-casting line")
O.clickCastOpen:Click()
eq(ccOpened, 1, "Configure bindings opens GRF's editor")
eq(O.note:GetText(), "Appearance changes apply after reloading.", "the footer while nothing is pending")
rows.GlassRaidFrames.follow:SetChecked(true)
rows.GlassRaidFrames.follow:Click()
eq(Suite.Following("GlassRaidFrames"), true, "the checkbox saves the switch")
eq(O.note:GetText(), "Changes are waiting: reload to apply them.", "the footer says a change is waiting")
check(rows.GlassRaidFrames.line:GetText():find("reload to use Pearl", 1, true), "and the card says what the reload will do")
rows.GlassRaidFrames.follow:SetChecked(false)
rows.GlassRaidFrames.follow:Click()
eq(O.note:GetText(), "Appearance changes apply after reloading.", "switching it back: nothing pending")

-- Live: a new report or a switch set from the command line redraws the open page.
Suite.Report("GlassRaidFrames", { api = 1, clickCast = { open = function() end, others = false } })
eq(O.clickCast:GetText(), "Bindings on other addons' frames: Disabled", "GRF's report again: the open page redraws at once")
GUI._test.slash("suite follow glassraidframes on")
eq(rows.GlassRaidFrames.follow:GetChecked(), true, "a switch set by /glassui suite shows on the open page")
GUI._test.slash("suite follow glassraidframes off")
Suite.Report("GlassRaidFrames", { api = 1, options = function() error("its own bug") end,
                                   clickCast = { open = function() ccOpened = ccOpened + 1 end, others = true } })
-- The Reload UI button: ForeverProbe's measured secure /reload, never ours.
O.spot._cx, O.spot._cy, O.spot._effScale = 640, 120, 0.8
O.panel:Hide(); O.panel:Show()
local R = O.reload
check(R ~= nil, "the Reload UI button is built out of combat")
eq(R.frame:GetParent(), nil, "on a frame parented to nothing, never inside the Settings panel")
eq(R.button:GetAttribute("type"), "macro", "a secure macro button")
eq(R.button:GetAttribute("macrotext"), "/reload", "running /reload")
eq(R.button._scripts.OnClick, nil, "nothing of ours on its click")
eq(R.frame:IsShown(), true, "shown over the footer while the page is open")
local _, rel = R.frame:GetPoint(1)
eq(rel, nil, "positioned on the screen, never anchored to the page")
near(R.frame:GetScale(), 0.8, "at the page's scale")
O.panel:Hide()
eq(R.frame:IsShown(), false, "hidden with the page")
O.panel:Show()
WoW.fire("PLAYER_REGEN_DISABLED")
eq(R.frame:IsShown(), false, "hidden as combat starts, before the lockdown")
WoW.combat = true
O.panel:Hide(); O.panel:Show()
eq(R.frame:IsShown(), false, "not shown in combat")
rows.GlassRaidFrames.follow:SetChecked(true)
rows.GlassRaidFrames.follow:Click()
eq(O.note:GetText(), "Changes are waiting: type /reload when combat ends.", "in combat the footer says to type it")
WoW.combat = false
WoW.fire("PLAYER_REGEN_ENABLED")
eq(R.frame:IsShown(), true, "back after combat while the page is open")
Suite.SetFollow("GlassRaidFrames", false)
O.panel:Hide()
WoW.chat = {}
GUI._test.slash("options")
eq(WoW.settingsOpened, "Glass UI", "/glassui options opens the page")
WoW.settingsOpened = nil
eq(Suite.Open(), true, "Suite.Open() opens Glass UI's page, for an addon's 'set in Glass UI' button")
eq(WoW.settingsOpened, "Glass UI", "the same page")
local realOpen = GUI.Options.Open
GUI.Options.Open = function() error("Settings refused") end
check(pcall(Suite.Open), "Suite.Open never errors")
eq(Suite.Open(), false, "and says false when it couldn't")
GUI.Options.Open = realOpen

-- No icon from the client (not cached, another build): the bare glass disc, no error.
WoW.itemIcons = {}
GUI = loadAddon()
GUI.Options._test.panel:Show()
eq(GUI.Options._test.pearl, nil, "no pearl icon: the bare disc")
eq(next(GUI.failures), nil, "and nothing failed")
GUI.Options._test.panel:Hide()
WoW.itemIcons = { [5500] = 134122 }

-- Never another addon's SavedVariables: the strict globals would throw on a
-- read, and nothing was written.
for _, name in ipairs({ "GlassUnitFramesDB", "GlassRaidFramesDB", "GlassRaidFramesCharDB" }) do
    eq(rawget(_G, name), nil, "never wrote " .. name)
end
eq(next(GUI.failures), nil, "no failures")
for k, v in pairs(GUI.failures) do io.write("    " .. k .. ": " .. v .. "\n") end

done("test_suite")
