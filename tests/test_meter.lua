-- The damage meter skin (#49, docs/DAMAGE-METER.md): what it fades, what it
-- leaves stock, its three panels per window, the body's glass following the
-- Background setting, windows made later or while the skin was off, and its
-- live switch.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local GUI = loadAddon()
local Engine = GUI.Engine

local function win(i) return _G["DamageMeterSessionWindow" .. i] end
local function faded(i)
    local w = win(i)
    return { w.Header, w.MinimizeContainer.Background, w.MinimizeContainer.SourceWindow.Background }
end
local function stock(i)
    local w, bar = win(i), WoW.meterBars[i]
    return { w.SessionTimer, w.MinimizeButton, w.SettingsDropdown, w.SessionDropdown, w.DamageMeterTypeDropdown,
             w.DamageMeterTypeDropdown.TypeName, w.MinimizeContainer.ResizeButton, w.MinimizeContainer.ScrollBox,
             bar, bar.StatusBar, bar.StatusBar.Background, bar.StatusBar.BackgroundEdge, bar.StatusBar.Name,
             w.MinimizeContainer.SourceWindow.CloseButton }
end
-- Stock: the header bar and the breakdown at 1, the background at Blizzard's
-- Background setting (0.5 unless a test sets it).
local function untouched(i, background, msg)
    local w = win(i)
    local ok = w.Header:GetAlpha() == 1 and w.MinimizeContainer.SourceWindow.Background:GetAlpha() == 1
        and w.MinimizeContainer.Background:GetAlpha() == (background or 0.5)
    check(ok, msg)
end
local function all(list, alpha, msg)
    local bad = 0
    for _, r in ipairs(list) do if r:GetAlpha() ~= alpha then bad = bad + 1 end end
    eq(bad, 0, msg .. " (" .. #list .. " regions)")
end
-- Our frames under a Blizzard frame: its children the stub didn't mark as Blizzard's.
local function ours(parent)
    local list = {}
    for _, c in ipairs(parent._children) do if not rawget(c, "_blizz") then list[#list + 1] = c end end
    return list
end
local function mine(i)
    local w = win(i)
    return #ours(w) + #ours(w.MinimizeContainer) + #ours(w.MinimizeContainer.SourceWindow)
end

eq(Engine.Status("meter"), "on", "the meter skin is on by default")
untouched(1, nil, "nothing is touched while Visibility keeps the meter hidden")
eq(mine(1), 0, "and no panel is built yet")

-- First show: every window found by name, three panels each.
WoW.showMeter()
all(faded(1), 0, "the header bar and both backgrounds are faded")
all(stock(1), 1, "the bars, buttons, fonts, resize handle and close button stay stock")
local w1 = win(1)
local header, body, source = ours(w1)[1], ours(w1.MinimizeContainer)[1], ours(w1.MinimizeContainer.SourceWindow)[1]
check(header and body and source, "a header strip, a body and a breakdown panel")
eq(mine(1), 3, "and nothing else")
eq(body:GetFrameLevel(), w1.MinimizeContainer:GetFrameLevel() - 1, "the body sits one level below the bars' container")
eq(header:GetFrameLevel(), w1:GetFrameLevel() - 1, "the header strip one level below the window")
eq(header._points[1][2], w1.Header, "the strip covers the header bar itself")
check(header._name == nil and not header:IsMouseEnabled(), "unnamed, mouse off")
eq(#WoW.luaCalls, 0, "no mixin method called (" .. table.concat(WoW.luaCalls, ", ") .. ")")

-- The body's glass follows the Background setting (full at Blizzard's 50%).
eq(body:GetAlpha(), 1, "Background 50% (the default): full glass")
WoW.meterBackground(1, 0.25)
eq(w1.MinimizeContainer.Background:GetAlpha(), 0, "the background stays faded")
eq(body:GetAlpha(), 0.5, "Background 25%: half the glass")
WoW.meterBackground(1, 0)
eq(body:GetAlpha(), 0, "Background 0%: no glass")
WoW.meterBackground(1, 1)
eq(body:GetAlpha(), 1, "Background 100%: full glass")
eq(header:GetAlpha(), 1, "the header strip keeps its glass")
WoW.meterBackground(1, 0.25)

-- Minimized: the body hides with the bars, the header strip stays.
WoW.meterMinimize(1, true)
check(not body:IsVisible() and header:IsVisible(), "minimized: no body glass, the header strip stays")
WoW.meterMinimize(1, false)
check(body:IsVisible(), "restored: the body is back")

-- The breakdown's panel shows with it.
check(not source:IsVisible(), "no breakdown, no glass for it")
WoW.meterBreakdown(1, true)
check(source:IsVisible(), "the breakdown shows its glass")
WoW.meterBreakdown(1, false)

-- A window added later, then hidden and shown again (reused): skinned once.
WoW.meterWindow(2)
all(faded(2), 0, "a window added later is skinned at once")
eq(mine(2), 3, "with its three panels")
WoW.meterHideWindow(2)
WoW.meterWindow(2)
eq(mine(2), 3, "shown again: no second set of panels")
eq(mine(1), 3, "and window 1 untouched")

-- The titles in the suite accent (#71): live, in combat too, a later window
-- included; gold by default, which is Blizzard's own.
local function title(i) return win(i).DamageMeterTypeDropdown.TypeName end
near(select(2, title(1):GetTextColor()), 0.82, "the title in the accent: gold by default")
GUI.Suite.SetLook("accent", "ice")
near(select(3, title(1):GetTextColor()), 0.905, "'Damage Done' in ice at once")
near(select(3, title(2):GetTextColor()), 0.905, "every window's title")
WoW.combat = true
GUI.Suite.SetLook("accent", "gold")
WoW.combat = false
near(select(3, title(1):GetTextColor()), 0, "in combat: at once")
GUI.Suite.SetLook("accent", "ice")
-- Live off: Blizzard's latest alphas back, our glass hidden, no /reload needed.
WoW.chat = {}
GUI._test.slash("skin meter off")
check(not table.concat(WoW.chat, "\n"):find("/reload", 1, true), "off is live: no /reload asked")
eq(w1.MinimizeContainer.Background:GetAlpha(), 0.25, "the Background Blizzard set while the skin was on comes back")
eq(w1.Header:GetAlpha(), 1, "the header bar comes back")
check(not body:IsShown() and not header:IsShown(), "our panels hide")
local tr, tg, tb, ta = title(1):GetTextColor()
check(tr == 1 and tg == 0.82 and tb == 0 and ta == 1, "the title back in Blizzard's gold, RGBA")
GUI.Suite.SetLook("accent", "gold")
GUI.Suite.SetLook("accent", "ice")
eq(select(1, title(1):GetTextColor()), 1, "off: an accent change touches nothing")
WoW.meterBackground(1, 0.75)
eq(w1.MinimizeContainer.Background:GetAlpha(), 0.75, "while off, Blizzard's Background applies")
-- A window made while the skin is off, and the hook doing nothing meanwhile.
WoW.meterWindow(3)
untouched(3, nil, "while off, a new window is left stock")
eq(mine(3), 0, "and gets no panel")
GUI._test.slash("skin meter on")
near(select(3, title(3):GetTextColor()), 0.905, "on again: a window made while off takes the current accent")
GUI._test.slash("skin meter off")
GUI.Suite.SetLook("accent", "gold")

-- Live on: every window, the one made while off included.
GUI._test.slash("skin meter on")
all(faded(1), 0, "on again: window 1 faded")
all(faded(3), 0, "the window made while off is skinned")
eq(mine(3), 3, "with its panels")
eq(body:GetAlpha(), 1, "the body follows the Background set while off (75%)")
check(body:IsShown() and header:IsShown(), "our panels show again")

-- The master switch, both ways, with a window made while it was off.
GUI._test.slash("off")
eq(w1.MinimizeContainer.Background:GetAlpha(), 0.75, "master off: the latest alpha back")
WoW.meterHideWindow(3)
WoW.meterWindow(3)
GUI._test.slash("on")
all(faded(3), 0, "master on: faded again")
eq(mine(3), 3, "no second set of panels")

eq(next(GUI.failures), nil, "no failures")
for k, v in pairs(GUI.failures) do io.write("    " .. k .. ": " .. v .. "\n") end

-- Visibility keeps the meter hidden past login: nothing until its first show,
-- then the Background set meanwhile is the one followed.
GUI = loadAddon()
WoW.meterBackground(1, 0.3)
eq(win(1).Header:GetAlpha(), 1, "hidden at login: the header untouched")
eq(win(1).MinimizeContainer.Background:GetAlpha(), 0.3, "and the Background is Blizzard's")
WoW.showMeter()
all(faded(1), 0, "first show: faded")
near(ours(win(1).MinimizeContainer)[1]:GetAlpha(), 0.6, "the body follows Background 30%")

-- The switch survives a reload.
GUI = loadAddon({ db = { skins = { meter = false } } })
WoW.showMeter()
untouched(1, nil, "saved off: the meter stays stock after a reload")
eq(GUI.Engine.Status("meter"), "off", "and reads off")

-- No meter on this client: the skin records it and the rest of Glass UI goes on.
GUI = loadAddon({ noMeter = true })
check(GUI.failures["skin:meter:frames"], "no DamageMeter: recorded")
eq(GUI.Engine.Status("merchant"), "on", "the other skins are unaffected")
done("test_meter")
