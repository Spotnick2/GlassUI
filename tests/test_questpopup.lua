-- The quest details popup (#202, docs/QUEST-POPUP.md): styled a frame after
-- its show (in combat too); the shell and the rock (found by structure, never
-- .Bg) faded, the page kept; the page faded only while it is Blizzard's dark
-- one AND Blizzard's last paint of the text was light (Update's instance
-- hook, on from login); Codex r1's four steps, a contrast change during the
-- show, unknown history after the skin was off, the first-ever opening in
-- Dark; the structure checks; our book; the buttons; nothing of ours
-- on QuestInfo's scroll child, no text colour, field or Lua method.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local CVAR = "questTextContrast"
local GUI = loadAddon()
local T = GUI.GossipQuest._test
local PF = QuestLogPopupDetailFrame
local page, rock = PF.Bg, PF._rock

local function setting(v) WoW.setCVar(CVAR, tostring(v)) end
local function faded() return page:GetAlpha() == 0 end
local function ours(parent)
    local k = 0
    for _, c in ipairs(parent._children) do if not rawget(c, "_blizz") then k = k + 1 end end
    return k
end

eq(GUI.Engine.Status("questpopup"), "on", "the popup skin is on by default")
eq(T.pageOf(PF), page, "the page found by structure: .Bg, BACKGROUND, 7,-62, a parchment atlas")
eq(T.rockOf(PF, page), rock, "the rock found by structure: the one BACKGROUND -6 at 2,-21 and -2,2")
eq(T.bookOf(PF), PF._book, "the book icon: OVERLAY -1, 64 px")

-- The first opening, in combat: nothing inside the show, all a frame later.
WoW.combat = true
WoW.popupShow(101)
eq(T.wins[PF], nil, "nothing built inside the show")
eq(PF.NineSlice:GetAlpha(), 1, "nothing faded inside it")
WoW.flushTimers(0)
WoW.combat = false
local h = T.wins[PF]
check(h ~= nil, "built a frame later, in combat too")
eq(PF.NineSlice:GetAlpha(), 0, "the NineSlice faded")
eq(PF.TopTileStreaks:GetAlpha(), 0, "the streaks faded")
eq(PF.Inset.Bg:GetAlpha(), 0, "the inset faded")
eq(rock:GetAlpha(), 0, "the rock faded")
eq(page:GetAlpha(), 1, "the page kept (default contrast: dark text)")
check(not h.pane.fill:IsShown(), "no pane")
check(h.header:IsShown(), "the band")
eq(h.disc, nil, "no glass ring round the book: Glass Mail's envelope has none (after #207)")
-- Glass Mail's recipe (the owner, after #205): our glass book over
-- Blizzard's, theirs faded.
eq(h.book, PF._book, "the book recorded")
eq(PF._book:GetAlpha(), 0, "Blizzard's book faded")
check(h.art ~= nil and h.art._parent == PF and h.art:IsShown(), "our book: our frame on the popup, shown")
eq(h.art._points[1][2], PF._book, "on the book icon's place")
check(h.art:GetFrameLevel() > PF:GetFrameLevel(), "over the popup's regions")
eq(h.artTex:GetTexture(), T.BOOK_ART, "the owner's glass book")
eq(T.BOOK_ART, "Interface\\AddOns\\GlassUI\\Media\\QuestBook", "the art's path: Media\\QuestBook.tga, as deployed")
check(h.win:GetFrameLevel() < PF:GetFrameLevel(), "the window glass under the window's regions")
check(h.closeX ~= nil, "the close button on its disc")
for _, key in ipairs({ "AbandonButton", "TrackButton", "ShareButton" }) do
    local st = T.buttons[PF[key]]
    check(st ~= nil and st.glass._parent == PF[key], key .. ": on glass, its child")
    eq(PF[key].Left:GetAlpha(), 0, key .. ": its art faded")
    -- 2 px in on each side: neighbours 4 px apart (the owner, after #205).
    local tl, br = st.glass._points[1], st.glass._points[2]
    check(tl[1] == "TOPLEFT" and tl[4] == 2 and tl[5] == 0, key .. ": its glass 2 px in from the left")
    check(br[1] == "BOTTOMRIGHT" and br[4] == -2 and br[5] == 0, key .. ": and from the right")
end
WoW.asBlizzard(function() PF.ShareButton:Disable() end)
WoW.flushTimers(0)
eq(T.buttons[PF.ShareButton].glass:GetAlpha(), T.BUTTON_OFF, "Share disabled (no group): its glass dimmed")
eq(PF.ShowMapButton.Texture:GetAlpha(), 1, "Show Map: Blizzard's")

-- Codex r1's four steps, each asserted after the queue drains.
WoW.closePopup()
setting(4)
WoW.popupShow(102)
WoW.flushTimers(0)
check(faded(), "1. opened in Dark: the page faded")
check(h.pane.fill:IsShown() and h.pane.fill._points[1][2] == page, "our pane on it")
eq(PF._text._textColor[1], WoW.STONE_TEXT[1], "Blizzard's light text")
setting(0)
WoW.flushTimers(0)
check(faded(), "2. Dark off, no redraw: still faded (the text is still light)")
WoW.popupFullUpdate()
eq(PF._text._textColor[1], WoW.PARCHMENT_TEXT[1], "3. a quest-log update repaints the text dark")
check(faded(), "(nothing inside Blizzard's Update)")
WoW.flushTimers(0)
check(not faded(), "3. a frame later: the page back under the dark text")
check(not h.pane.fill:IsShown(), "the pane hidden")
setting(4)
WoW.flushTimers(0)
check(not faded(), "4. Dark on again, no redraw: kept (the text is still dark)")
WoW.popupFullUpdate()
WoW.flushTimers(0)
check(faded(), "a quest-log update in Dark: light text painted over the still-dark page: faded again")
WoW.closePopup()
WoW.popupShow(103)
WoW.flushTimers(0)
check(faded(), "5. reopened: faded, light")

-- A contrast change during ShowUIPanel, between the Update and the page set
-- (Codex r2): the atlas says Dark, the text was painted dark: kept.
WoW.closePopup()
setting(0)
WoW.popupShow(104, function() WoW.setCVar(CVAR, "4") end)
WoW.flushTimers(0)
eq(page:GetAtlas(), T.DARK, "(the page set dark)")
check(not faded(), "painted dark, the atlas dark: the page kept")
check(not h.pane.fill:IsShown(), "no pane")

-- The same quest again hides it (ShowQuest's toggle).
WoW.popupShow(104)
check(not PF:IsShown(), "the same quest again: hidden")

-- The skin off and on over an open popup: the history unknown, kept until
-- Blizzard's next paint.
setting(4)
WoW.popupShow(105)
WoW.flushTimers(0)
check(faded(), "(faded)")
GUI._test.slash("skin questpopup off")
eq(page:GetAlpha(), 1, "off: the page back")
eq(rock:GetAlpha(), 1, "off: the rock back")
check(not h.win:IsShown(), "off: our glass hidden")
eq(PF._book:GetAlpha(), 1, "off: Blizzard's book back")
check(not h.art:IsShown(), "off: our book hidden")
WoW.popupFullUpdate()
eq(#WoW.timers, 0, "off: Blizzard's Update schedules nothing")
GUI._test.slash("skin questpopup on")
WoW.flushTimers(0)
check(not faded(), "on over an open popup: the paint unknown, kept")
eq(rock:GetAlpha(), 0, "the rock faded again")
eq(PF._book:GetAlpha(), 0, "on: Blizzard's book faded again")
check(h.art:IsShown(), "on: our book shown")
WoW.popupFullUpdate()
WoW.flushTimers(0)
check(faded(), "Blizzard's next paint, light: faded")
GUI._test.slash("off")
eq(page:GetAlpha(), 1, "master off: the page back")
GUI._test.slash("on")
WoW.flushTimers(0)
check(not faded(), "master on: unknown again, kept")
WoW.closePopup()
setting(0)
WoW.flushTimers(0)

-- Untouched: QuestInfo's scroll child, the text, Blizzard's methods.
eq(ours(PF.ScrollFrame.ScrollChild), 0, "nothing of ours on QuestInfo's scroll child")
eq(PF.SealMaterialBG:GetAlpha(), 1, "the seal untouched")
eq(PF.MaterialTopLeft:GetAlpha(), 1, "a material corner untouched")
local coloured = 0
for _, fs in ipairs(WoW.textColorCalls) do
    local w = fs
    while w do
        if w == PF then coloured = coloured + 1 break end
        w = w._parent
    end
end
eq(coloured, 0, "no text colour written in the popup")
eq(#WoW.luaCalls, 0, "no Blizzard Lua method called (never Update)")
eq(next(GUI.failures), nil, "no failures")
for k, v in pairs(GUI.failures) do io.write("    " .. k .. ": " .. v .. "\n") end
eq(table.concat(WoW.fieldChanges(), ","), "", "no field written on a Blizzard object")

-- The first-ever opening in Dark (Codex r2): Update's hook records the paint
-- before the install; the first style pass uses it.
GUI = loadAddon({ before = function() WoW.cvar.values[CVAR] = "4"; WoW.contrast = 4 end })
T = GUI.GossipQuest._test
PF, page = QuestLogPopupDetailFrame, QuestLogPopupDetailFrame.Bg
WoW.popupShow(201)
WoW.flushTimers(0)
check(GUI.Engine.Active("questpopup"), "the skin still active")
h = T.wins[PF]
check(h ~= nil and h.pane ~= nil, "installed, its pane built")
check(faded(), "faded on the very first opening")
check(h.pane.fill:IsShown(), "the pane shown")

-- The structure checks: .Bg not the page, or two rock candidates: that piece
-- left Blizzard's and recorded, the skin running.
WoW.popupPage = "rock"
GUI = loadAddon()
T = GUI.GossipQuest._test
WoW.popupShow(301)
WoW.flushTimers(0)
check(GUI.failures["missing:questpopup:page"] ~= nil, ".Bg on the rock: the page not found, recorded")
check(GUI.Engine.Active("questpopup"), "the skin still runs")
eq(QuestLogPopupDetailFrameBg:GetAlpha(), 1, "the real page kept")
check(not T.wins[QuestLogPopupDetailFrame].pane.fill:IsShown(), "no pane without a page")
WoW.popupPage = nil
WoW.popupRock = "two"
GUI = loadAddon()
T = GUI.GossipQuest._test
WoW.popupShow(302)
WoW.flushTimers(0)
check(GUI.failures["missing:questpopup:rock"] ~= nil, "two rock candidates: none taken, recorded")
eq(QuestLogPopupDetailFrame._rock:GetAlpha(), 1, "the rock left")
eq(QuestLogPopupDetailFrame.Bg:GetAlpha(), 1, "the page kept")
WoW.popupRock = nil

done("test_questpopup")
