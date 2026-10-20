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
eq(O.clickCast:GetText(), "Click-casting: bindings on other addons' frames enabled", "the click-casting line")
O.clickCastOpen:Click()
eq(ccOpened, 1, "Configure bindings opens GRF's editor")
eq(O.note:GetText(), "Appearance changes apply after reloading.", "the footer while nothing is pending")
rows.GlassRaidFrames.follow:SetChecked(true)
rows.GlassRaidFrames.follow:Click()
eq(Suite.Following("GlassRaidFrames"), true, "the checkbox saves the switch")
eq(O.note:GetText(), "Changes are waiting: reload to apply them.", "the footer says a change is waiting")
check(rows.GlassRaidFrames.line:GetText():find("reload to apply", 1, true), "and the card says a reload applies it")
local _, toward = rows.GlassRaidFrames.line:GetPoint(2)
eq(toward, rows.GlassRaidFrames.follow, "the state line stops at the checkbox, never under it")
rows.GlassRaidFrames.follow:SetChecked(false)
rows.GlassRaidFrames.follow:Click()
eq(O.note:GetText(), "Appearance changes apply after reloading.", "switching it back: nothing pending")

-- Live: a new report or a switch set from the command line redraws the open page.
Suite.Report("GlassRaidFrames", { api = 1, clickCast = { open = function() end, others = false } })
eq(O.clickCast:GetText(), "Click-casting: bindings on other addons' frames disabled", "GRF's report again: the open page redraws at once")
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
-- The page scrolls above a footer that doesn't (owner, 2026-10-19: four followers ran past the window).
local P, S = O.page, O.scroll
eq(S:GetParent(), O.panel, "a scroll frame on the panel")
eq(S._template, "UIPanelScrollFrameTemplate", "the client's template, as GlassPanel's options")
eq(P:GetParent(), S, "the page's content is its child")
eq(rows.GlassUnitFrames.card:GetParent(), P, "the cards scroll with it")
eq(O.clickCast:GetParent(), P, "and the raid frames lines")
eq(O.note:GetParent(), O.panel, "the footer stays on the panel")
eq(O.spot:GetParent(), O.panel, "so the Reload UI button's spot never scrolls")
S._width, P._top, O.clickCast._bottom = 600, 900, 300
O.panel:Show()
eq(P:GetWidth(), 600, "the page as wide as the scroll frame")
eq(P:GetHeight(), 616, "and as tall as its content, to the last line plus the margin")
P._top, O.clickCast._bottom = 900, 200
WoW.flushTimers(0)
eq(P:GetHeight(), 716, "measured again once the layout has settled")
S._scripts.OnSizeChanged(S, 640, 400)
eq(P:GetWidth(), 640, "and follows the scroll frame's width when the window resizes")
S._yrange = 0
S._scripts.OnScrollRangeChanged(S, 0, 0)
eq(S.ScrollBar:IsShown(), false, "no scroll bar while it all fits")
S._scripts.OnScrollRangeChanged(S, 0, 120)
eq(S.ScrollBar:IsShown(), true, "a scroll bar once it doesn't")
O.panel:Hide()
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

-- The group layout (docs/GROUP-LAYOUT.md §6): what GRF and GUF report, shown, never acted on.
setup()
eq(Suite.LayoutLine(), nil, "no layout line before GRF reports one")
Suite.Report("GlassRaidFrames", { api = 1, layout = { on = true, mode = "hud", extra = 1 } })
eq(Suite.ReportOf("GlassRaidFrames").layout.extra, nil, "only the known layout fields are copied")
eq(Suite.LayoutLine(), "Group layout: centred above the action bars", "GRF's HUD")
Suite.Report("GlassUnitFrames", { api = 1, layout = { linked = true, placing = true } })
eq(Suite.LayoutLine(), "Group layout: centred above the action bars; player and target beside it", "GUF placing beside it")
Suite.Report("GlassRaidFrames", { api = 1, layout = { on = true, mode = "side" } })
Suite.Report("GlassUnitFrames", { api = 1, layout = { linked = true, placing = false } })
eq(Suite.LayoutLine(), "Group layout: at the side; player and target in their own places", "side: GUF linked, not placing")
Suite.Report("GlassUnitFrames", { api = 1, layout = { linked = false, placing = false } })
eq(Suite.LayoutLine(), "Group layout: at the side; player and target not linked", "GUF not linked")
Suite.Report("GlassRaidFrames", { api = 1, layout = { on = false, mode = "hud" } })
eq(Suite.LayoutLine(), "Group layout: off (the classic grid); player and target not linked", "the layout switched off reads as off, whatever the mode")
Suite.Report("GlassRaidFrames", { api = 1, layout = { on = true, mode = "hud" } })
Suite.Report("GlassUnitFrames", { api = 1, layout = { linked = true, placing = true } })
GUI._test.slash("suite")
check(chat():find("Group layout: centred above the action bars; player and target beside it", 1, true), "/glassui suite prints the layout line")
GUI.Options._test.panel:Show()
eq(GUI.Options._test.layoutLine:GetText(), "Group layout: centred above the action bars; player and target beside it", "the page shows it")
Suite.Report("GlassUnitFrames", { api = 1, layout = { linked = true, placing = false } })
eq(GUI.Options._test.layoutLine:GetText(), "Group layout: centred above the action bars; player and target in their own places", "and redraws when a report changes it")
GUI.Options._test.panel:Hide()

-- The suite look (docs/SUITE-LOOK.md): Look(), the live event, sparse
-- saving, presets, what followers report, and the "Suite look" subpage.
GUI = loadAddon({ before = function() early.look = GlassUI.Suite.Look() end })
Suite = GUI.Suite
eq(early.look, nil, "Look() is nil before Glass UI is ready")
local L = Suite.Look()
check(L and L.tint == "clear" and L.hover == "glow" and L.press == "flash" and L.emptySlots == "frosted",
      "the defaults are GAB's own look: clear, glow, flash, frosted")
L.tint = "smoked"
eq(Suite.Look().tint, "clear", "Look() is a fresh table: changing one doesn't reach the suite")
eq(Suite.LookPreset(), "glass", "the defaults match the Glass preset")
WoW.triggered = {}
check(Suite.SetLook("tint", "smoked"), "SetLook accepts a known value")
eq(GlassUIDB.suite.look.tint, "smoked", "saved")
eq(#WoW.triggered, 1, "and announced once")
eq(WoW.triggered[1].event, "GlassUI.Suite.LookChanged", "on GlassUI.Suite.LookChanged")
eq(WoW.triggered[1].args[1].tint, "smoked", "with the whole look")
eq(WoW.triggered[1].args[1].hover, "glow", "including the unchanged keys")
eq(Suite.SetLook("tint", "gold"), false, "an unknown value is refused")
eq(Suite.SetLook("sparkle", "on"), false, "and an unknown key")
eq(#WoW.triggered, 1, "and neither is announced")
-- A follower that registers late pulls Look() rather than waiting for a replay.
local seen
EventRegistry:RegisterCallback("GlassUI.Suite.LookChanged", function(owner, look) seen = look end, "test")
eq(Suite.Look().tint, "smoked", "a late follower pulls the current look")
WoW.combat = true
check(Suite.SetLookPreset("soft"), "a preset applies, in combat too (textures only, followers' care)")
WoW.combat = false
eq(seen and seen.hover, "halo", "the follower got the preset's hover")
eq(seen and seen.press, "ripple", "and press")
eq(Suite.LookPreset(), "soft", "the preset is recognised")
Suite.SetLook("emptySlots", "full")
eq(Suite.LookPreset(), "custom", "a mixed set reads as custom")
Suite.SetLookPreset("glass")
Suite.SetLook("tint", "clear")
eq(GlassUIDB.suite, nil, "back to the defaults: nothing saved")
eq(Suite.SetLookPreset("sparkly"), false, "an unknown preset is refused")
-- A reload keeps it, and a junk saved value falls back to the default.
GUI = loadAddon({ db = { suite = { look = { tint = "class", hover = "neon" } } } })
Suite = GUI.Suite
eq(Suite.Look().tint, "class", "the saved tint after a reload")
eq(Suite.Look().hover, "glow", "a junk saved value falls back to the default")

-- What a follower reports (GAB): its effective look, its overrides, its tenants.
setup({ suite = { follow = { GlassActionBars = true } } })
WoW.installed.GlassActionBars, WoW.loaded.GlassActionBars = 2, true
ask("GlassActionBars")
Suite.Report("GlassActionBars", { api = 1, built = "pearl",
    look = { tint = "smoked", hover = "glow", press = "flash", emptySlots = "frosted", extra = "x" },
    own = { tint = true, hover = "yes" }, tenants = { "Apotheca", 42, "" }, options = function() end })
local rr = Suite.ReportOf("GlassActionBars")
eq(rr.look.tint, "smoked", "the effective look is copied")
eq(rr.look.extra, nil, "only the known keys")
eq(rr.own.tint, true, "an override is copied")
eq(rr.own.hover, nil, "a non-boolean override is dropped")
eq(#rr.tenants, 1, "only plain, non-empty tenant names")
eq(rr.tenants[1], "Apotheca", "Apotheca is GAB's tenant")
eq(Suite.LookLine("GlassActionBars"), "suite look, its own tint Smoked", "the look line names the override")
local out
GUI._test.slash("suite")
out = chat()
check(out:find("Glass Action Bars: following Glass UI (Pearl); suite look, its own tint Smoked", 1, true),
      "/glassui suite: GAB follows, with its override")
check(out:find("Apotheca: follows Glass Action Bars", 1, true), "/glassui suite: the tenant line")
-- The main page's GAB card says the same, briefly.
GUI.Options._test.panel:Show()
check(GUI.Options._test.rows.GlassActionBars.line:GetText():find("its own tint; Apotheca follow it", 1, true),
      "the GAB card names its overrides and its tenants")
GUI.Options._test.panel:Hide()

-- /glassui look
GUI._test.slash("look tint smoked")
eq(Suite.Look().tint, "smoked", "/glassui look tint smoked")
GUI._test.slash("look empty hidden")
eq(Suite.Look().emptySlots, "hidden", "/glassui look empty <value> sets emptySlots")
GUI._test.slash("look preset minimal")
eq(Suite.LookPreset(), "minimal", "/glassui look preset minimal")
chat()
GUI._test.slash("look tint gold")
check(chat():find("/glassui look tint|accent|hover|press|empty|preset <value>", 1, true), "a bad value prints the usage")
GUI._test.slash("look")
out = chat()
check(out:find("suite look (Minimal): tint Smoked, hover Off, press Flash, empty slots Hidden", 1, true),
      "/glassui look prints the look and its preset")
check(out:find("tint: clear|smoked|class", 1, true) and out:find("tint:", 1, true) < out:find("hover:", 1, true),
      "and the choices, in a fixed order")

-- The "Suite look" subpage: registered under Glass UI, radios that set and show the look.
check(GUI.Options.lookCategory and GUI.Options.lookCategory.parent == WoW.settingsCategory,
      "the subpage is registered under Glass UI's page")
local O = GUI.Options._test
O.lookPanel:Show()
local tintRow = O.lookRows["Tint"]
eq(#tintRow, 3, "three tints")
eq(tintRow[2]:GetChecked(), true, "the current tint (smoked) is checked")
tintRow[3]:Click()
eq(Suite.Look().tint, "class", "a tint radio sets the suite tint")
eq(tintRow[3]:GetChecked(), true, "and the radios follow")
eq(tintRow[2]:GetChecked(), false, "only one checked")
local presetRow = O.lookRows["Button feedback"]
presetRow[2]:Click()
eq(Suite.LookPreset(), "soft", "a preset radio applies the preset")
eq(O.lookRows["Hover"][3]:GetChecked(), true, "and the hover row shows its halo")
O.lookRows["Empty slots"][4]:Click()
eq(Suite.LookPreset(), "custom", "a single key can make it custom")
eq(O.lookCustom:GetText(), "(custom)", "and the page says so")
for _, rb in ipairs(presetRow) do check(not rb:GetChecked(), "no preset checked while custom") end
check(O.lookFollowers:GetText():find("Glass Action Bars: suite look, its own tint Smoked", 1, true),
      "the subpage lists the followers and their overrides")
check(O.lookFollowers:GetText():find("Apotheca: follows Glass Action Bars", 1, true), "and the tenants")
Suite.Report("GlassActionBars", { api = 1, built = "pearl",
    look = { tint = "class", hover = "halo", press = "ripple", emptySlots = "full" }, own = {} })
eq(O.lookFollowers:GetText(), "Glass Action Bars: suite look", "a new report redraws the open subpage")
-- Follow turned off before a /reload: GAB still applies the suite look this
-- session, so the line keeps saying so and names the pending switch.
Suite.SetFollow("GlassActionBars", false)
eq(Suite.LookLine("GlassActionBars"), "suite look", "leaving: the look source is the session's, not the switch")
eq(select(2, Suite.LookLine("GlassActionBars")), true, "and the switch is flagged as pending")
eq(O.lookFollowers:GetText(), "Glass Action Bars: suite look; set to its own look - /reload to apply",
   "the subpage shows the pending switch separately")
GUI._test.slash("suite")
check(chat():find("Glass Action Bars: following Glass UI (Pearl); suite look - /reload to apply", 1, true),
      "/glassui suite agrees with itself while leaving")
O.lookPanel:Hide()
-- Follow turned on before a /reload: GAB keeps its own look until then.
setup()
WoW.installed.GlassActionBars, WoW.loaded.GlassActionBars = 2, true
ask("GlassActionBars")
Suite.Report("GlassActionBars", { api = 1,
    look = { tint = "clear", hover = "glow", press = "flash", emptySlots = "frosted" }, own = {} })
eq(Suite.LookLine("GlassActionBars"), "its own look", "not following: its own look")
eq(select(2, Suite.LookLine("GlassActionBars")), false, "and nothing pending")
Suite.SetFollow("GlassActionBars", true)
eq(Suite.LookLine("GlassActionBars"), "its own look", "joining: still its own look until the /reload")
O = GUI.Options._test
O.lookPanel:Show()
eq(O.lookFollowers:GetText(), "Glass Action Bars: its own look; set to follow - /reload to apply",
   "the subpage shows the pending join")
O.lookPanel:Hide()

-- The body (#67): one recipe for Glass UI's skins and the followers.
setup()
local b = Suite.Body("clear")
eq(b.tint[4], 0.24, "clear's tint")
eq(b.backing[4], 0.35, "its backing's opacity")
eq(b.backing[1], Suite.BACKING[1], "the backing's colour")
eq(b.wash, 1, "the wash, a factor of the material's")
eq(b.classShade, nil, "no class shade")
local cl = Suite.Body("class")
eq(cl.tint, nil, "class: no tint of its own")
eq(cl.classShade, 0.6, "the follower's class colour times this")
near(Suite.Body("smoked").wash, 0.14 / 0.18, "smoked's wash factor")
eq(Suite.Body("sparkly"), nil, "an unknown tint: nil")
b.tint[4], b.backing[4] = 9, 9
eq(Suite.Body("clear").tint[4], 0.24, "fresh down to the tint: a follower's change stays its own")
eq(Suite.Body("clear").backing[4], 0.35, "and the backing")
eq(Suite.Body().tint[4], 0.24, "nil: the suite look's current tint (clear)")
Suite.SetLook("tint", "smoked")
eq(Suite.Body().backing[4], 0.92, "follows the suite look's tint")
-- One tint for Glass UI's own skins: the suite look's, repainted live.
eq(GUI.Theme.Name(), "smoked", "the skins' tint is the suite look's")
local f = CreateFrame("Frame")
local g = GUI.Glass.Apply(f, "small")
local bk = f:CreateTexture()
GUI.Theme.Register(g, bk)
eq(bk._color[4], 0.92, "a registered surface paints smoked's backing")
Suite.SetLook("tint", "clear")
eq(bk._color[4], 0.35, "a tint change on the subpage repaints it at once")
WoW.combat = true
Suite.SetLook("tint", "smoked")
WoW.combat = false
eq(bk._color[4], 0.92, "in combat too (our own textures)")
GUI._test.slash("theme clear")
eq(Suite.Look().tint, "clear", "/glassui theme is the suite look's tint")
eq(rawget(GlassUIDB, "theme"), nil, "nothing saved under the old name")
-- The class body with the class colour unreadable (early in a login): the
-- surface's built tint is kept, and painted at the retry.
WoW.class = nil
eq(GUI.Theme.Set("class"), true, "class chosen while the colour can't be read")
eq(GUI.Theme.pending, true, "the paint waits")
local built = g.tint._color
WoW.class = "MAGE"
GUI.Theme.Retry()
eq(GUI.Theme.pending, false, "painted at the retry")
local mage = g.tint._color
near(mage[1], 0.25 * 0.6, "the mage's colour times the class shade")
eq(mage[4], g.tint.glassColor[4], "keeping the surface's built alpha (three values)")
check(built ~= mage, "a new paint, not the kept one")
Suite.SetLook("tint", "clear")
-- Before Glass UI is ready: nothing to read.
local beforeReady
loadAddon({ before = function()
    beforeReady = { body = GlassUI.Suite.Body(), accent = GlassUI.Suite.Accent(),
                    clear = GlassUI.Suite.Body("clear") }
end })
eq(beforeReady.body, nil, "Body() before ready: nil")
eq(beforeReady.accent, nil, "Accent() before ready: nil")
check(beforeReady.clear ~= nil, "a named body is static: there before ready")

-- The migration of the old saved theme.
setup({ theme = "smoked" })
eq(Suite.Look().tint, "smoked", "a saved theme moves into the suite look's tint")
eq(rawget(GlassUIDB, "theme"), nil, "and is dropped")
setup({ theme = "class", suite = { look = { tint = "smoked" }, follow = { GlassUnitFrames = true } } })
eq(Suite.Look().tint, "smoked", "a saved look tint wins")
eq(rawget(GlassUIDB, "theme"), nil, "the old theme dropped either way")
eq(Suite.Following("GlassUnitFrames"), true, "the rest of the suite is kept")
setup({ theme = "clear" })
eq(rawget(GlassUIDB, "suite"), nil, "the default moves nowhere: nothing saved")
setup({ theme = "sparkly" })
eq(Suite.Look().tint, "clear", "an invalid saved theme is dropped, not moved")
eq(rawget(GlassUIDB, "suite"), nil, "nothing saved for it")

-- The accent (#52).
setup()
eq(Suite.Look().accent, "gold", "gold by default")
local a = Suite.Accent()
check(a[1] == 1 and a[2] == 0.82 and a[3] == 0, "Blizzard's gold")
eq(Suite.Accent("ice")[3], 0.905, "a named accent: ice")
eq(Suite.Accent("teal"), nil, "an unknown name: nil")
a[1] = 0
eq(Suite.Accent()[1], 1, "fresh")
eq(rawget(GlassUIDB, "suite"), nil, "the default isn't saved")
GUI._test.slash("look accent ice")
eq(Suite.Look().accent, "ice", "/glassui look accent ice")
eq(GlassUIDB.suite.look.accent, "ice", "saved, sparse")
local heard
EventRegistry:RegisterCallback(Suite.LOOK_EVENT, function(_, look) heard = look.accent end, {})
Suite.SetLook("accent", "gold")
eq(heard, "gold", "announced live through LookChanged")
eq(rawget(GlassUIDB, "suite"), nil, "back to the default: nothing saved")
O = GUI.Options._test
O.lookPanel:Show()
local accentRow = O.lookRows["Accent"]
eq(#accentRow, 2, "the subpage's Accent radios: gold and ice")
eq(accentRow[1]:GetChecked(), true, "gold checked")
accentRow[2]:Click()
eq(Suite.Look().accent, "ice", "a radio sets it")
O.lookPanel:Hide()
Suite.SetLook("accent", "gold")

-- A follower's own backing (GlassChat's /gchat alpha) on the card and in /glassui suite.
setup({ suite = { follow = { GlassChat = true } } })
ask("GlassChat")
Suite.Report("GlassChat", { api = 1, built = "pearl", own = { backing = true, sparkle = true } })
eq(Suite.ReportOf("GlassChat").own.backing, true, "own.backing is copied")
eq(Suite.ReportOf("GlassChat").own.sparkle, nil, "an unknown key isn't")
eq(Suite.LookLine("GlassChat"), "suite look, its own backing", "the look line names it, with no look keys reported")
Suite.Report("GlassChat", { api = 1, built = "pearl", look = { tint = "chat", accent = "ice" },
                            own = { tint = true, accent = true } })
eq(Suite.LookLine("GlassChat"), "suite look, its own tint, accent Ice",
   "a value of its own (GlassChat's charcoal) reads as its own tint, never the raw name")
Suite.Report("GlassChat", { api = 1, built = "pearl", own = { backing = true } })
GUI._test.slash("suite")
check(chat():find("its own backing", 1, true), "/glassui suite names it")
GUI.Options._test.panel:Show()
check(GUI.Options._test.rows.GlassChat.line:GetText():find("its own backing", 1, true), "and the card")
GUI.Options._test.panel:Hide()

-- Never another addon's SavedVariables: the strict globals would throw on a
-- read, and nothing was written.
for _, name in ipairs({ "GlassUnitFramesDB", "GlassRaidFramesDB", "GlassRaidFramesCharDB" }) do
    eq(rawget(_G, name), nil, "never wrote " .. name)
end
eq(next(GUI.failures), nil, "no failures")
for k, v in pairs(GUI.failures) do io.write("    " .. k .. ": " .. v .. "\n") end

done("test_suite")
