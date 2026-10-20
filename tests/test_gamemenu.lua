-- The game menu skin (#90, docs/GAME-MENU.md): the window glass, the title
-- tab, each pooled button on glass with its slices faded and Blizzard's hover
-- glow tinted white; styled at the first show (InitButtons ran before our
-- hook), on a refresh while open, across the pool shrinking and growing; never
-- a call into the menu; live off and on.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local GUI = loadAddon()
local Engine = GUI.Engine
local G = GUI.GameMenu._test
local M = GameMenuFrame

local function ours(parent)
    local list = {}
    for _, c in ipairs(parent._children) do if not rawget(c, "_blizz") then list[#list + 1] = c end end
    return list
end
local function shownButtons()
    local list = {}
    for _, b in ipairs(WoW.gameMenuPool) do if b:IsShown() then list[#list + 1] = b end end
    return list
end

eq(Engine.Status("gamemenu"), "on", "the game menu skin is on by default")
eq(#ours(M), 0, "nothing built before the menu first opens")

-- The first opening, in combat: Blizzard's OnShow builds the buttons before our hook exists.
WoW.combat = true
WoW.showGameMenu()
WoW.flushTimers(0)
WoW.combat = false
local win = ours(M)[1]
check(win ~= nil, "the window glass, built at the first show (in combat: a plain panel)")
eq(win:GetFrameLevel(), M:GetFrameLevel() - 1, "under the menu")
eq(rawget(win, "layoutIndex"), nil, "no layoutIndex: the menu's layout leaves it out")
eq(M.Border:GetAlpha(), 0, "the dialog border faded (its tiled Bg with it)")
-- More Pearl than a window (the owner, GM run 1): the body's backing, as the quest tracker.
local function backingOf(host)
    for _, r in ipairs(host._regions) do
        if r._layer == "BACKGROUND" and r._sub == -7 then return r end
    end
end
local wb = backingOf(win)
local body = GUI.Suite.Body("clear").backing
check(wb ~= nil, "the window has a backing")
near(wb._color[4], body[4], "the body's (clear 0.35), not the window floor")
check(wb._color[4] < GUI.Theme.WINDOW_BACKING, "lighter than a window")
for _, k in ipairs({ "LeftBG", "RightBG", "CenterBG" }) do eq(M.Header[k]:GetAlpha(), 0, "the header's " .. k .. " faded") end
eq(M.Header.Text:GetAlpha(), 1, "the title text Blizzard's")
local hg = G.menus[M].header
check(hg ~= nil and hg:GetParent() == M.Header, "the title tab: glass on the header")
eq(hg:GetFrameLevel(), M.Header:GetFrameLevel() - 1, "under it")
eq(ours(M.Header)[1], hg, "one glass on the header")
eq(backingOf(hg), nil, "the title tab: no backing")
eq(M.NewOptionsFrame:GetAlpha(), 1, "the NEW badge left")

-- The buttons: styled at the first show by the style pass.
local first = shownButtons()
eq(#first, #WoW.gameMenuEntries, "every entry built")
for i, b in ipairs(first) do
    local s = G.buttons[b]
    check(s ~= nil, "button " .. i .. ": glass of ours at the first show")
    eq(s.glass:GetParent(), b, "button " .. i .. ": in the button")
    eq(s.glass:GetFrameLevel(), b:GetFrameLevel() - 1, "button " .. i .. ": under it")
    eq(s.g.top:GetFrameLevel(), s.glass:GetFrameLevel(), "button " .. i .. ": its rim under the text")
    local bb = backingOf(s.glass)
    check(bb ~= nil, "button " .. i .. ": a backing of its own")
    near(bb._color[4], GUI.Theme.WINDOW_BACKING, "button " .. i .. ": the window floor's, as dense as before")
    for _, k in ipairs({ "Left", "Right", "Center" }) do eq(b[k]:GetAlpha(), 0, "button " .. i .. ": " .. k .. " faded") end
    eq(b._highlight._desat, true, "button " .. i .. ": the hover glow desaturated")
    local c = b._highlight._vertex
    check(c and c[1] == 1 and c[2] == 1 and c[3] == 1 and c[4] == G.HOVER, "button " .. i .. ": white at HOVER")
    eq(b:GetText(), WoW.gameMenuEntries[i], "button " .. i .. ": its text Blizzard's")
end
eq(G.HOVER, 0.35, "the hover glow at 0.35")
-- Only three-slice buttons: another child with a Left piece alone isn't one.
local odd = WoW.blizzObject("Frame", M)
rawset(odd, "Left", WoW.blizzObject("Texture", odd, nil, "BACKGROUND"))
WoW.gameMenuRefresh()
eq(G.buttons[odd], nil, "a child with only a Left piece is left alone")
eq(odd.Left:GetAlpha(), 1, "and its art")
-- Nothing of ours on a button's scripts or fields: Blizzard replaces them on every show.
eq(rawget(first[1], "glass"), nil, "no field of ours on a button")
eq(#WoW.luaCalls, 0, "no Blizzard Lua or mixin method called from our code (InitButtons included)")

-- Shown again: Blizzard rebuilds, our hook restyles; one glass per pooled button, ever.
WoW.hideGameMenu()
WoW.showGameMenu()
for i, b in ipairs(shownButtons()) do eq(#ours(b), 1, "button " .. i .. ": one glass across shows") end
-- A refresh while open (a store or trial event): restyled.
WoW.gameMenuEntries[#WoW.gameMenuEntries + 1] = "Shop"
WoW.gameMenuRefresh()
local grown = shownButtons()
eq(#grown, 9, "the pool grew")
check(G.buttons[grown[9]] ~= nil, "the new button given its glass by the InitButtons hook")
eq(grown[9].Left:GetAlpha(), 0, "its slices faded")
table.remove(WoW.gameMenuEntries)
WoW.gameMenuRefresh()
eq(#shownButtons(), 8, "and shrank")
check(not grown[9]:IsShown() and not G.buttons[grown[9]].glass:IsVisible(), "the released button's glass hides with it")
-- A disabled entry: Blizzard's state, our glass the same.
WoW.gameMenuSupportOff = true
WoW.gameMenuRefresh()
local support = shownButtons()[4]
eq(support:IsEnabled(), false, "Support disabled by Blizzard")
check(G.buttons[support].glass:IsShown(), "its glass as any other")
WoW.gameMenuSupportOff = nil
WoW.gameMenuRefresh()

-- Off: Blizzard's look; a refresh meanwhile touches nothing of ours; on: re-synced.
GUI._test.slash("skin gamemenu off")
eq(M.Border:GetAlpha(), 1, "off: the border back")
eq(M.Header.CenterBG:GetAlpha(), 1, "the header back")
local b1 = shownButtons()[1]
eq(b1.Left:GetAlpha(), 1, "the slices back")
eq(b1._highlight._desat, false, "the hover glow's colour back")
check(not win:IsShown() and not hg:IsShown() and not G.buttons[b1].glass:IsShown(), "our glass hidden")
WoW.gameMenuEntries[#WoW.gameMenuEntries + 1] = "Shop"
WoW.gameMenuRefresh()
local late = shownButtons()[9]
check(late ~= nil, "a button acquired while off")
eq(late.Left:GetAlpha(), 1, "off: not touched")
GUI._test.slash("skin gamemenu on")
eq(M.Border:GetAlpha(), 0, "on again: faded")
check(G.buttons[late] ~= nil and late.Left:GetAlpha() == 0, "the button made while off styled by the style pass")
eq(b1.Left:GetAlpha(), 0, "the others faded again")
table.remove(WoW.gameMenuEntries)
WoW.hideGameMenu()

eq(next(GUI.failures), nil, "no failures")
for k, v in pairs(GUI.failures) do io.write("    " .. k .. ": " .. v .. "\n") end
done("test_gamemenu")
