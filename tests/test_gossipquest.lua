-- The gossip window and the quest dialog (#115, #114, docs/GOSSIP-QUEST.md):
-- each styled a frame after its show (in combat too), the shell, our glass,
-- the band down to the page's top, the portrait's disc (QuestFramePortrait's
-- two textures), the buttons on glass; the page kept, and faded only while
-- Blizzard shows its dark page (the atlas decides, not the setting): every
-- refresh, with or without an OnShow, both ways; contrast 1-3 and an NPC kit
-- kept; one pane at most; the disabled close button; off and on, the master
-- switch, a queued pass dropped; nothing of ours on a scroll child or an item
-- button; no text colour, field or Lua method.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local GUI = loadAddon()
local T = GUI.GossipQuest._test
local Kit = GUI.Kit
local GF, QF = GossipFrame, QuestFrame

local function bottomOf(tex)
    for _, pt in ipairs(tex._points) do if pt[1] == "BOTTOM" then return pt end end
end
local function topOf(tex)
    for _, pt in ipairs(tex._points) do if pt[1] == "TOP" then return pt end end
end
local function ours(parent)
    local k = 0
    for _, c in ipairs(parent._children) do if not rawget(c, "_blizz") then k = k + 1 end end
    return k
end
local function paneOn(h, page)
    return h.pane.fill:IsShown() and h.pane.fill._points[1] ~= nil and h.pane.fill._points[1][2] == page
end

eq(GUI.Engine.Status("gossip"), "on", "the gossip skin is on by default")
eq(GUI.Engine.Status("quest"), "on", "the quest skin is on by default")

--------------------------------------------------------------------------------
-- The gossip window
--------------------------------------------------------------------------------

WoW.combat = true
WoW.gossip()
eq(T.wins[GF], nil, "gossip: nothing built inside the show (the panel manager's secure delegate)")
eq(GF.NineSlice:GetAlpha(), 1, "gossip: nothing faded inside it")
WoW.flushTimers(0)
WoW.combat = false
local g = T.wins[GF]
check(g ~= nil, "gossip: built a frame later, in combat too")
eq(GF.NineSlice:GetAlpha(), 0, "gossip: the NineSlice faded")
eq(GF.Bg:GetAlpha(), 0, "gossip: the rock faded")
eq(GF.TopTileStreaks:GetAlpha(), 0, "gossip: the streaks faded")
eq(GF.Inset.Bg:GetAlpha(), 0, "gossip: the inset's marble faded")
eq(g.backing._color[4], GUI.Theme.WINDOW_BACKING, "gossip: the window floor")
check(g.header:IsShown(), "gossip: the band shown")
local hp = bottomOf(g.header)
check(hp and hp[2] == g.win and hp[3] == "TOP" and hp[5] == T.PAGE_TOP, "gossip: the band down to the page's top")
local bp = topOf(g.backing)
check(bp and bp[2] == g.win and bp[5] == T.PAGE_TOP, "gossip: the floor from there down")
check(g.win:GetFrameLevel() < GF:GetFrameLevel(), "gossip: the window glass under the window's regions")
check(g.disc ~= nil, "gossip: the portrait on its disc")
eq(g.disc._points[1][2], GF.PortraitContainer.CircleMask, "gossip: round the portrait's mask")
eq(g.disc:GetFrameLevel(), 399, "gossip: under the portrait's container")
eq(GF.Background:GetAtlas(), "QuestBG-Parchment", "gossip: Blizzard's page")
eq(GF.Background:GetAlpha(), 1, "gossip: the page kept (dark text on parchment)")
check(not g.pane.fill:IsShown(), "gossip: our pane hidden")
local bye = GF.GreetingPanel.GoodbyeButton
local bg = T.buttons[bye]
check(bg ~= nil, "gossip: Goodbye on glass")
eq(bg.glass._parent, bye, "gossip: its glass is its child")
eq(bg.glass:GetFrameLevel(), bye:GetFrameLevel() - 1, "gossip: under the button")
eq(bg.g.top:GetFrameLevel(), bye:GetFrameLevel() - 1, "gossip: its rim too")
check(not bg.glass._mouse, "gossip: mouse off")
for _, k in ipairs({ "Left", "Middle", "Right" }) do eq(bye[k]:GetAlpha(), 0, "gossip: Goodbye's " .. k .. " faded") end
local v = bye._highlight._vertex
check(v and v[1] == 1 and v[2] == 1 and v[3] == 1 and v[4] == T.HOVER, "gossip: Goodbye's glow white")
eq(GF.CloseButton._normal:GetAlpha(), 0, "gossip: the close button's red faded")
check(g.closeX ~= nil, "gossip: our X")

-- Dark, in Blizzard's settings, with the window open: its theme re-sets the
-- page at once; a frame later the page faded, the pane under it.
WoW.setContrast(4)
eq(GF.Background:GetAtlas(), T.DARK, "gossip: Blizzard's dark page")
eq(GF.Background:GetAlpha(), 1, "gossip: nothing inside Blizzard's SetAtlas")
WoW.flushTimers(0)
eq(GF.Background:GetAlpha(), 0, "gossip: the dark page faded")
check(paneOn(g, GF.Background), "gossip: our pane on the page")
eq(GF._rows[1]._textColor[1], WoW.STONE_TEXT[1], "gossip: the rows in Blizzard's light text")
-- Blizzard's own alpha while faded: held, and given back later.
WoW.asBlizzard(function() GF.Background:SetAlpha(0.8) end)
eq(GF.Background:GetAlpha(), 0, "gossip: held at 0 against Blizzard's SetAlpha")
WoW.setContrast(0, true)
WoW.flushTimers(0)
eq(GF.Background:GetAtlas(), "QuestBG-Parchment", "gossip: back to the parchment, Blizzard's atlas")
eq(GF.Background:GetAlpha(), 0.8, "gossip: the page at Blizzard's latest alpha")
check(not g.pane.fill:IsShown(), "gossip: the pane hidden")
WoW.asBlizzard(function() GF.Background:SetAlpha(1) end)
-- Contrast 1-3: lighter parchments, dark text: kept.
for c = 1, 3 do
    WoW.setContrast(c, c == 2)
    WoW.flushTimers(0)
    eq(GF.Background:GetAlpha(), 1, "gossip: contrast " .. c .. " kept")
    check(not g.pane.fill:IsShown(), "gossip: contrast " .. c .. ": no pane")
end
-- Re-set while shown with no setting change (a QUEST_LOG_UPDATE's Update).
WoW.contrast = 4
WoW.gossipUpdate()
WoW.flushTimers(0)
eq(GF.Background:GetAlpha(), 0, "gossip: an Update while shown: faded")
WoW.contrast = 0
WoW.gossipUpdate()
WoW.flushTimers(0)
eq(GF.Background:GetAlpha(), 1, "gossip: and back")
-- An NPC's own page at contrast 4: kept (its text follows the contrast, its page isn't the dark one).
WoW.setContrast(4)
WoW.gossipUpdate("Kul")
WoW.flushTimers(0)
eq(GF.Background:GetAtlas(), "QuestBG-Kul", "gossip: the NPC's page")
eq(GF.Background:GetAlpha(), 1, "gossip: an NPC's page kept at contrast 4")
check(not g.pane.fill:IsShown(), "gossip: no pane under it")
-- Closed, the setting changed, opened again (no kit this time).
WoW.closeGossip()
WoW.setContrast(0)
WoW.setContrast(4)
WoW.flushTimers(0)
WoW.gossip()
WoW.flushTimers(0)
eq(GF.Background:GetAlpha(), 0, "gossip: changed while closed, opened: faded")
check(paneOn(g, GF.Background), "gossip: the pane")
local before = ours(GF)
WoW.closeGossip()
WoW.gossip()
WoW.flushTimers(0)
eq(ours(GF), before, "gossip: reopened: nothing built again")
eq(T.wins[GF], g, "gossip: the same window record")

-- Off and on with it open; the setting changed while off.
GUI._test.slash("skin gossip off")
eq(GF.NineSlice:GetAlpha(), 1, "gossip off: the shell back")
eq(GF.Background:GetAlpha(), 1, "gossip off: the page back")
eq(bye.Left:GetAlpha(), 1, "gossip off: Goodbye's art back")
check(not g.win:IsShown(), "gossip off: our glass hidden")
WoW.flushTimers(0)
WoW.setContrast(0)
eq(#WoW.timers, 0, "gossip off: a setting change schedules nothing")
WoW.setContrast(4)
eq(#WoW.timers, 0, "gossip off: nor Blizzard's page")
eq(GF.Background:GetAlpha(), 1, "gossip off: the dark page left alone")
GUI._test.slash("skin gossip on")
WoW.flushTimers(0)
check(g.win:IsShown(), "gossip on: our glass back")
eq(GF.Background:GetAlpha(), 0, "gossip on: the dark page read again, faded")
-- A pass queued, then the skin off and on: nothing stale.
WoW.contrast = 0
WoW.gossipUpdate()
GUI._test.slash("skin gossip off")
WoW.flushTimers(0)
eq(GF.Background:GetAlpha(), 1, "gossip: the queued pass dropped with the skin off")
WoW.contrast = 4
WoW.gossipUpdate()
GUI._test.slash("skin gossip on")
WoW.flushTimers(0)
eq(GF.Background:GetAlpha(), 0, "gossip: on again, the current page decides")
-- The master switch.
GUI._test.slash("off")
eq(GF.Background:GetAlpha(), 1, "master off: the page back")
GUI._test.slash("on")
WoW.flushTimers(0)
eq(GF.Background:GetAlpha(), 0, "master on: faded again")
WoW.closeGossip()
WoW.setContrast(0)
WoW.flushTimers(0)

--------------------------------------------------------------------------------
-- The quest dialog
--------------------------------------------------------------------------------

local GREET, DETAIL, PROG, REWARD = QuestFrameGreetingPanel, QuestFrameDetailPanel, QuestFrameProgressPanel,
                                    QuestFrameRewardPanel
WoW.combat = true
WoW.quest("Greeting")
eq(T.wins[QF], nil, "quest: nothing built inside the show")
WoW.flushTimers(0)
WoW.combat = false
local q = T.wins[QF]
check(q ~= nil, "quest: built a frame later, in combat too")
eq(QF.NineSlice:GetAlpha(), 0, "quest: the NineSlice faded")
eq(QF.Bg:GetAlpha(), 0, "quest: the rock faded")
eq(QF.Inset.NineSlice:GetAlpha(), 0, "quest: the inset faded")
hp = bottomOf(q.header)
check(hp and hp[2] == q.win and hp[5] == T.PAGE_TOP, "quest: the band down to the pages' top")
-- QuestFramePortrait is the shell's portrait (measured, GQ.1 on 70938): its
-- container's disc, the window glass at the usual level.
eq(QuestFramePortrait, QF.PortraitContainer.portrait, "(the stub: the shell's portrait holds the global)")
eq(q.disc._points[1][2], QF.PortraitContainer.CircleMask, "quest: the disc round the portrait's mask")
eq(q.disc:GetFrameLevel(), 399, "quest: under the portrait's container")
eq(q.win:GetFrameLevel(), QF:GetFrameLevel() - 1, "quest: the window glass at the usual level")
eq(GREET.Bg:GetAlpha(), 1, "quest: the greeting's page kept")
check(not q.pane.fill:IsShown(), "quest: no pane")
for _, name in ipairs(T.QUEST_BUTTONS) do
    local b = _G[name]
    local st = T.buttons[b]
    check(st ~= nil and st.glass._parent == b, name .. ": on glass, its child")
    eq(st.glass:GetFrameLevel(), b:GetFrameLevel() - 1, name .. ": under it")
end
for _, k in ipairs({ "Left", "Middle", "Right" }) do
    eq(QuestFrameGreetingGoodbyeButton[k]:GetAlpha(), 0, "quest: Goodbye's " .. k .. " faded through its SetTexture")
end

-- The buttons' state on our glass (their own pieces are faded): disabled
-- (Accept while the text types) dims it a frame later, held down lights it.
WoW.quest("Detail")
WoW.flushTimers(0)
local acc = T.buttons[QuestFrameAcceptButton]
eq(acc.glass:GetAlpha(), 1, "quest: Accept enabled, its glass full")
check(not acc.press:IsShown(), "quest: not pressed")
WoW.asBlizzard(function() QuestFrameAcceptButton:Disable() end)
eq(acc.glass:GetAlpha(), 1, "quest: nothing inside Blizzard's Disable")
WoW.flushTimers(0)
eq(acc.glass:GetAlpha(), T.BUTTON_OFF, "quest: Accept disabled: its glass dimmed")
QuestFrameAcceptButton._scripts.OnMouseDown(QuestFrameAcceptButton)
check(not acc.press:IsShown(), "quest: no press light while disabled")
WoW.asBlizzard(function() QuestFrameAcceptButton:Enable() end)
WoW.flushTimers(0)
eq(acc.glass:GetAlpha(), 1, "quest: enabled again: full")
QuestFrameAcceptButton._scripts.OnMouseDown(QuestFrameAcceptButton)
check(acc.press:IsShown(), "quest: held down: the press light")
eq(acc.press._color[4], T.PRESS_LIGHT, "quest: at its strength")
QuestFrameAcceptButton._scripts.OnMouseUp(QuestFrameAcceptButton)
check(not acc.press:IsShown(), "quest: released: gone")
-- Hidden while held, its mouse-up never comes, shown again under the same
-- window (the client fires the button's OnHide and OnShow with its panel's).
QuestFrameAcceptButton._scripts.OnMouseDown(QuestFrameAcceptButton)
WoW.asBlizzard(function() QuestFrameAcceptButton._scripts.OnHide(QuestFrameAcceptButton) end)
WoW.flushTimers(0)
check(not acc.press:IsShown(), "quest: hidden while held: the press cleared")
QuestFrameAcceptButton._scripts.OnMouseDown(QuestFrameAcceptButton)
WoW.asBlizzard(function() QuestFrameAcceptButton._scripts.OnShow(QuestFrameAcceptButton) end)
check(acc.press:IsShown(), "quest: nothing inside Blizzard's OnShow")
WoW.flushTimers(0)
check(not acc.press:IsShown(), "quest: shown again: no press left over")
-- Disabled while the skin is off: read again when on; nothing scheduled while off.
GUI._test.slash("skin quest off")
WoW.asBlizzard(function() QuestFrameCompleteButton:Disable() end)
eq(#WoW.timers, 0, "quest off: a button's Disable schedules nothing")
GUI._test.slash("skin quest on")
WoW.flushTimers(0)
eq(T.buttons[QuestFrameCompleteButton].glass:GetAlpha(), T.BUTTON_OFF, "quest on: Continue's disabled state read again")
WoW.asBlizzard(function() QuestFrameCompleteButton:Enable() end)
WoW.flushTimers(0)
WoW.quest("Greeting")
WoW.flushTimers(0)

-- The setting changed with the greeting open, no refresh: nothing changes
-- (Blizzard's text is still dark).
WoW.setContrast(4)
WoW.flushTimers(0)
eq(GREET.Bg:GetAtlas(), "QuestBG-Parchment", "quest: the open panel keeps its page")
eq(GREET.Bg:GetAlpha(), 1, "quest: and the skin keeps it")
check(not q.pane.fill:IsShown(), "quest: no pane yet")
-- A quest log update on the greeting: its OnShow handler, no Show, after the
-- setting's work drained: dark, faded.
WoW.questGreetingRefresh()
eq(GREET.Bg:GetAtlas(), T.DARK, "quest: the greeting refreshed dark")
WoW.flushTimers(0)
eq(GREET.Bg:GetAlpha(), 0, "quest: a refresh with no OnShow: faded")
check(paneOn(q, GREET.Bg), "quest: the pane on the greeting's page")
WoW.setContrast(0)
WoW.flushTimers(0)
eq(GREET.Bg:GetAlpha(), 0, "quest: back to the default, no refresh: still Blizzard's dark page, faded")
WoW.questGreetingRefresh()
WoW.flushTimers(0)
eq(GREET.Bg:GetAlpha(), 1, "quest: refreshed: the parchment back")
check(not q.pane.fill:IsShown(), "quest: the pane hidden")

-- Panels in turn with the window shown throughout, dark: one pane, on the
-- shown panel's page; the others given back.
WoW.setContrast(4)
local panes = 0
for _, step in ipairs({ { "Detail", DETAIL }, { "Progress", PROG }, { "Reward", REWARD }, { "Greeting", GREET } }) do
    WoW.quest(step[1])
    WoW.flushTimers(0)
    eq(step[2].Bg:GetAlpha(), 0, "quest: " .. step[1] .. "'s dark page faded")
    check(paneOn(q, step[2].Bg), "quest: the pane on " .. step[1] .. "'s page")
    for _, other in ipairs({ GREET, DETAIL, PROG, REWARD }) do
        if other ~= step[2] then eq(other.Bg:GetAlpha(), 1, "quest: " .. step[1] .. ": another panel's page given back") end
    end
    check(bottomOf(q.header)[2] == q.win, "quest: " .. step[1] .. ": the band in place")
    panes = panes + 1
end
eq(panes, 4, "four panels in turn")
-- Contrast 1-3 on the next panel: kept.
for c = 1, 3 do
    WoW.setContrast(c)
    WoW.quest("Detail")
    WoW.flushTimers(0)
    eq(DETAIL.Bg:GetAlpha(), 1, "quest: contrast " .. c .. " kept")
    check(not q.pane.fill:IsShown(), "quest: contrast " .. c .. ": no pane")
end
-- Changed while closed, then opened.
WoW.closeQuest()
WoW.setContrast(4)
WoW.flushTimers(0)
WoW.quest("Progress")
WoW.flushTimers(0)
eq(PROG.Bg:GetAlpha(), 0, "quest: changed while closed, opened: faded")
check(paneOn(q, PROG.Bg), "quest: its pane")
-- The setting's event before or after Blizzard's re-set: the same.
WoW.setContrast(0, true)
WoW.quest("Reward")
WoW.flushTimers(0)
eq(REWARD.Bg:GetAlpha(), 1, "quest: the default on the next panel")
eq(PROG.Bg:GetAlpha(), 1, "quest: the last panel's page given back")

-- Auto-accept: Decline hidden takes its glass; the close button disabled
-- dims our X, a frame later; enabled again restores it.
WoW.questAutoAccept = true
WoW.quest("Detail")
check(not QuestFrameDeclineButton:IsShown(), "(Blizzard hid Decline)")
eq(T.buttons[QuestFrameDeclineButton].glass._parent, QuestFrameDeclineButton, "quest: Decline's glass hides with it")
eq(q.closeAlpha, Kit.CLOSE_REST, "quest: nothing inside Blizzard's Disable")
WoW.flushTimers(0)
eq(q.closeAlpha, Kit.CLOSE_OFF, "quest: the close button disabled: our X dimmed")
WoW.mouseOver[QF.CloseButton] = true
QF.CloseButton._scripts.OnEnter(QF.CloseButton)
check(not q.closeLight:IsShown(), "quest: no hover light while disabled")
eq(q.closeAlpha, Kit.CLOSE_OFF, "quest: nor a full X")
QF.CloseButton._scripts.OnLeave(QF.CloseButton)
WoW.mouseOver[QF.CloseButton] = nil
WoW.closeQuest()
WoW.flushTimers(0)
eq(q.closeAlpha, Kit.CLOSE_REST, "quest: enabled again: our X back")
WoW.questAutoAccept = false
-- Disabled while the skin is off: read again when on.
WoW.quest("Greeting")
WoW.flushTimers(0)
GUI._test.slash("skin quest off")
WoW.asBlizzard(function() QF.CloseButton:Disable() end)
eq(#WoW.timers, 0, "quest off: Blizzard's Disable schedules nothing")
GUI._test.slash("skin quest on")
WoW.flushTimers(0)
eq(q.closeAlpha, Kit.CLOSE_OFF, "quest on: the disabled close button read again")
WoW.asBlizzard(function() QF.CloseButton:Enable() end)
WoW.flushTimers(0)
eq(q.closeAlpha, Kit.CLOSE_REST, "quest: and enabled")

-- Off and on, the setting changed while off, a queued pass dropped.
WoW.setContrast(4)
WoW.questGreetingRefresh()
WoW.flushTimers(0)
eq(GREET.Bg:GetAlpha(), 0, "(faded)")
GUI._test.slash("skin quest off")
eq(QF.NineSlice:GetAlpha(), 1, "quest off: the shell back")
eq(GREET.Bg:GetAlpha(), 1, "quest off: the page back")
check(not q.win:IsShown(), "quest off: our glass hidden")
WoW.setContrast(0)
WoW.questGreetingRefresh()
eq(#WoW.timers, 0, "quest off: a refresh schedules nothing")
GUI._test.slash("skin quest on")
WoW.flushTimers(0)
eq(GREET.Bg:GetAlpha(), 1, "quest on: the parchment kept")
WoW.setContrast(4)
WoW.questGreetingRefresh()
GUI._test.slash("skin quest off")
WoW.flushTimers(0)
eq(GREET.Bg:GetAlpha(), 1, "quest: the queued pass dropped with the skin off")
GUI._test.slash("skin quest on")
WoW.flushTimers(0)
eq(GREET.Bg:GetAlpha(), 0, "quest on: the dark page read again")
WoW.closeQuest()
WoW.setContrast(0)
WoW.flushTimers(0)

-- Untouched: the scroll children (Blizzard fades them in), the item buttons
-- (their OnEnter reads their alpha), the text.
for _, n in ipairs({ "QuestGreetingScrollChildFrame", "QuestDetailScrollChildFrame", "QuestProgressScrollChildFrame",
                     "QuestRewardScrollChildFrame" }) do
    eq(ours(_G[n]), 0, n .. ": nothing of ours on it")
    eq(_G[n]:GetAlpha(), 1, n .. ": its alpha Blizzard's")
end
eq(ours(QuestProgressItem1), 0, "nothing of ours on an item button")
eq(QuestProgressItem1:GetAlpha(), 1, "an item button's alpha Blizzard's")
eq(QF.FriendshipStatusBar:GetAlpha(), 1, "the friendship bar untouched")
for _, p in ipairs({ GREET, DETAIL, PROG, REWARD }) do
    eq(p.MaterialTopLeft:GetAlpha(), 1, "a material corner untouched")
    eq(p.SealMaterialBG:GetAlpha(), 1, "the seal untouched")
end
-- (WoW.textColorCalls also holds the tracker's audited titles, #71.)
local function inside(w, root)
    while w do
        if w == root then return true end
        w = w._parent
    end
    return false
end
local coloured = 0
for _, fs in ipairs(WoW.textColorCalls) do
    if inside(fs, GF) or inside(fs, QF) then coloured = coloured + 1 end
end
eq(coloured, 0, "no text colour written in either window")
eq(#WoW.luaCalls, 0, "no Blizzard Lua method called")
eq(next(GUI.failures), nil, "no failures")
for k, val in pairs(GUI.failures) do io.write("    " .. k .. ": " .. val .. "\n") end
eq(table.concat(WoW.fieldChanges(), ","), "", "no field written on a Blizzard object")

-- QuestFrame's own ARTWORK texture holding the global (not this build's): the
-- disc under it, the window glass lower still.
GUI = loadAddon({ questOwn = true })
T = GUI.GossipQuest._test
WoW.quest("Detail")
WoW.flushTimers(0)
q = T.wins[QuestFrame]
check(QuestFramePortrait ~= QuestFrame.PortraitContainer.portrait, "(the stub: QuestFrame's own texture)")
eq(q.disc._points[1][2], QuestFramePortrait, "own portrait: the disc round the texture Blizzard fills")
eq(q.disc:GetFrameLevel(), QuestFrame:GetFrameLevel() - 1, "own portrait: the disc under the window's regions")
check(q.win:GetFrameLevel() < q.disc:GetFrameLevel(), "own portrait: the window glass under the disc")

-- Neither window on this build: nothing, no error.
GUI = loadAddon({ noGossip = true, noQuest = true })
check(GUI.Engine.Status("gossip") ~= nil and GUI.Engine.Status("quest") ~= nil, "both skins still registered")
WoW.setContrast(4)
WoW.flushTimers(0)

done("test_gossipquest")
