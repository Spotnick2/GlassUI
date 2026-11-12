-- The RestedXP skins (#56, docs/RESTEDXP.md): attached only with RestedXP;
-- the guide window's glass (a child of GuideName, below all three, from the
-- header to the footer), every backdrop piece faded and held through a theme
-- change (the pass after UpdateVisuals), the band and hairlines, the scroll
-- track; rows' pieces faded, their alpha RestedXP's; cards on glass; each
-- hook queues one pass a frame later, re-queued after a dropped one; the
-- collapse and V2. The arrow: RestedXP's texture faded, ours turned with
-- every SetRotation, its start angle read, the accent, the pill sized after
-- SetText and SetFont; off and on; nothing of RestedXP's called or written.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

-- Not installed: nothing to wait for.
local GUI = loadAddon()
eq(GUI.Engine.Status("rxp"), "on (RXPGuides not installed)", "no RestedXP: says so")
eq(GUI.Engine.Status("rxparrow"), "on (RXPGuides not installed)", "the arrow too")
eq(next(GUI.failures), nil, "no failures without it")

GUI = loadAddon({ before = WoW.makeRestedXP })
local R = GUI.RestedXP._test
local F, AF = RXPFrame, RXPG_ARROW
local GN, BF, FT = F.GuideName, F.BottomFrame, F.Footer
eq(GUI.Engine.Status("rxp"), "on", "with RestedXP: on")

local function ours(parent)
    local list = {}
    for _, c in ipairs(parent._children) do if not rawget(c, "_blizz") then list[#list + 1] = c end end
    return list
end
local function allFaded(f, msg)
    for _, k in ipairs(R.PIECES) do
        if rawget(f, k) then eq(f[k]:GetAlpha(), 0, msg .. ": " .. k .. " faded") end
    end
end

-- The window, shown at login: built and styled at once.
local h = R.wins[F]
check(h ~= nil, "the window built at its show")
eq(h.win:GetParent(), GN, "the glass a child of GuideName (V1's collapse keeps it, V2 hides it)")
eq(h.win:GetFrameLevel(), BF:GetFrameLevel() - 1, "below the lowest of the three")
check(h.win:GetFrameLevel() < GN:GetFrameLevel() and h.win:GetFrameLevel() < FT:GetFrameLevel(), "below the header and footer")
eq(h.wg.top:GetFrameLevel(), h.win:GetFrameLevel(), "its rim lowered too")
local tl, br
for _, pt in ipairs(h.win._points) do
    if pt[1] == "TOPLEFT" then tl = pt elseif pt[1] == "BOTTOMRIGHT" then br = pt end
end
check(tl and tl[2] == GN and tl[3] == "TOPLEFT", "from the header's top left")
check(br and br[2] == FT and br[3] == "BOTTOMRIGHT", "to the footer's bottom right")
eq(h.backing._color[4], GUI.Theme.WINDOW_BACKING, "the window floor")
local hp
for _, pt in ipairs(h.header._points) do if pt[1] == "BOTTOM" then hp = pt end end
check(hp and hp[2] == GN and hp[3] == "BOTTOM", "the band down to the header's own bottom")
check(h.header:IsShown(), "the band shown")
check(h.headerLine ~= nil and h.footerLine ~= nil, "our hairlines under the header and over the footer")
check(h.track ~= nil and h.track.fill:IsShown(), "the scroll track shown")
eq(h.trackHost:GetParent(), BF, "on a host in the list (it hides with it)")
eq(h.track.fill._points[1][2], F.ScrollFrame.ScrollBar, "round the scroll bar")

-- RestedXP's first theme: its SetBackdrop makes the pieces; the pass a frame later fades them.
WoW.rxpTheme()
eq(GN.TopEdge:GetAlpha(), 1, "inside UpdateVisuals: nothing faded yet")
WoW.flushTimers(0)
for _, f in ipairs({ GN, BF, FT }) do allFaded(f, "a frame later") end
eq(GN.bg:GetAlpha(), 0, "the header's banner faded")
eq(FT.bg:GetAlpha(), 0, "the footer's banner faded")
eq(GN.text:GetAlpha(), 1, "the title RestedXP's")
eq(GN.icon:GetAlpha(), 1, "the guide's icon RestedXP's")
eq(FT.cog:GetAlpha(), 1, "the cog RestedXP's")
eq(F.ScrollFrame.ScrollBar:GetAlpha(), 1, "the scroll bar RestedXP's")
-- A theme change: the same pieces reused, re-textured and re-coloured, their
-- alpha back as QS.2 measured; the pass after UpdateVisuals fades them again.
local piece = GN.TopEdge
WoW.rxpTheme(0.5, 0.2, 0.1)
eq(GN.TopEdge, piece, "(the stub) the pieces reused")
eq(piece:GetAlpha(), 1, "(the stub) the theme brought the alpha back")
eq(piece._vertex[1], 0.5, "(the stub) and re-coloured it")
WoW.flushTimers(0)
for _, f in ipairs({ GN, BF, FT }) do allFaded(f, "after a theme change") end

-- A guide loaded: its rows, a frame after UpdateFrame.
WoW.rxpLoadGuide()
local pool = F.ScrollChild.framePool
eq(R.rows[pool[1]], nil, "inside UpdateFrame: nothing styled")
WoW.flushTimers(0)
local STATE = { 0.5, 1, 0.66, 0.66, 0 }
for i, row in ipairs(pool) do
    eq(row.Center:GetAlpha(), 0, "row " .. i .. ": its fill faded")
    near(row:GetAlpha(), STATE[i], "row " .. i .. ": its alpha RestedXP's state")
    check(R.rows[row] ~= nil, "row " .. i .. ": our hairline's host")
    eq(R.rows[row]:GetParent(), row, "row " .. i .. ": in the row (fades and hides with it)")
    check(not R.rows[row]._mouse, "row " .. i .. ": mouse off")
    eq(row.text:GetAlpha(), 1, "row " .. i .. ": its text RestedXP's")
end
eq(#ours(F.ScrollChild.f1), 0, "the measuring frame untouched")
eq(R.rows[F.ScrollChild.f1], nil, "and not taken for a row")
-- A hover and leave: the fill re-coloured, the row's alpha 1 and back; the fade holds.
WoW.rxpHover(pool[1])
eq(pool[1].Center:GetAlpha(), 0, "hovered and left: still faded")
near(pool[1]:GetAlpha(), 0.5, "its alpha back to RestedXP's")
-- Reused across a reload of the guide: one host per pooled row.
WoW.rxpSteps = { "current", "building", "building" }
WoW.rxpLoadGuide()
WoW.flushTimers(0)
for _, row in ipairs(pool) do eq(#ours(row), 1, "one host per pooled row, reused") end

-- The cards: each on glass, its pieces and tab faded, a tip too, reused.
WoW.rxpSetStep({ { title = "Step 13" }, { title = "" } })
local cards = F.CurrentStepFrame.framePool
eq(R.cards[cards[1]], nil, "inside UpdateText: nothing styled")
WoW.flushTimers(0)
for i, card in ipairs(cards) do
    local c = R.cards[card]
    check(c ~= nil, "card " .. i .. ": on glass")
    eq(c.glass:GetParent(), card, "card " .. i .. ": a child of the card")
    eq(c.glass:GetFrameLevel(), card:GetFrameLevel() - 1, "card " .. i .. ": at its level - 1")
    eq(c.g.top:GetFrameLevel(), c.glass:GetFrameLevel(), "card " .. i .. ": its rim lowered")
    allFaded(card, "card " .. i)
    allFaded(card.number, "card " .. i .. "'s tab")
    eq(card.number.text:GetAlpha(), 1, "card " .. i .. ": the step's title RestedXP's")
end
eq(cards[2].number:GetAlpha(), 0, "an untitled step's tab: RestedXP's alpha 0 kept")
eq(cards[1].number:GetAlpha(), 1, "a titled one's 1")
WoW.rxpSetStep({ { title = "Tip", tip = true }, { title = "Step 14" } })
WoW.flushTimers(0)
WoW.rxpSetStep({ { title = "Step 15" } })
WoW.flushTimers(0)
for i, card in ipairs(cards) do eq(#ours(card), 1, "card " .. i .. ": one glass across card, tip and card") end

-- The hooks: many calls in a frame, one pass.
local before = #WoW.timers
WoW.asBlizzard(function()
    for _ = 1, 5 do BF.UpdateFrame(); F.CurrentStepFrame.UpdateText(); F:UpdateVisuals() end
end)
eq(#WoW.timers - before, 3, "fifteen calls in a frame: one pass per hook queued")
WoW.flushTimers(0)
WoW.asBlizzard(function() BF.UpdateFrame() end)
eq(#WoW.timers - before, 1, "after the pass: the next call queues again")
WoW.flushTimers(0)
-- Queued, then the skin off before the next frame: the pass dropped; on
-- again, the next hook still queues and runs.
for _, off in ipairs({ "skin rxp off", "off" }) do
    local on = off == "off" and "on" or "skin rxp on"
    WoW.asBlizzard(function() F:UpdateVisuals() end)
    GUI._test.slash(off)
    WoW.flushTimers(0)
    GUI._test.slash(on)
    WoW.flushTimers(0)
    WoW.rxpTheme()
    WoW.flushTimers(0)
    eq(GN.TopEdge:GetAlpha(), 0, off .. " with a pass queued, then on: the next theme's pass ran")
end

-- The collapse: the list hidden, the header and footer kept: our glass stays, the track goes.
WoW.rxpCollapse(true)
check(h.win:IsVisible(), "collapsed: the glass still there")
check(not h.track.fill:IsVisible(), "the scroll track hidden with the list")
WoW.rxpCollapse(false)
check(h.track.fill:IsVisible(), "expanded: the track back")
-- V2: GuideName and the rest hidden: nothing of the guide skin shows.
WoW.rxpV2(true)
check(not h.win:IsVisible(), "V2: our glass hidden with GuideName")
check(not R.cards[cards[1]].glass:IsVisible(), "the cards' glass too")
WoW.rxpV2(false)

-- The arrow: built at its first show, RestedXP's texture faded, ours in the accent.
WoW.rxpTurn(1.2)
WoW.rxpArrowText("Step 13\n(1344yd)")
WoW.rxpArrowShow()
local a = R.arrows[AF]
check(a ~= nil, "the arrow built at its show")
eq(AF.texture:GetAlpha(), 0, "RestedXP's arrow faded")
eq(a.arrow._file, R.ARROW, "ours drawn")
eq(a.frame:GetParent(), AF, "a child of RXPG_ARROW: its alpha and visibility RestedXP's")
eq(a.frame:GetFrameLevel(), AF:GetFrameLevel() + 1, "one level up")
check(not a.frame._mouse, "mouse off: the drag stays RestedXP's")
eq(a.frame._points[1][2], AF.texture, "on RestedXP's texture's points")
eq(a.arrow._rotation, 1.2, "the start angle read")
local c = GUI.Suite.Accent()
eq(a.arrow._vertex[1], c[1], "the suite accent")
eq(AF.text:GetAlpha(), 1, "the text RestedXP's")
WoW.rxpTurn(-0.4)
eq(a.arrow._rotation, -0.4, "turned with RestedXP's SetRotation, at once")
WoW.rxpTurn(0)
eq(a.arrow._rotation, 0, "off the continent: 0 too")
-- The pill: a level below, its rim too, sized round the text.
eq(a.pill:GetParent(), AF, "the pill on RXPG_ARROW")
eq(a.pill:GetFrameLevel(), AF:GetFrameLevel() - 1, "one level below it (the text draws over it)")
eq(a.pillGlass.top:GetFrameLevel(), a.pill:GetFrameLevel(), "its rim too")
local function pillFits()
    return a.pill._width == AF.text:GetStringWidth() + 2 * R.PILL_PAD[1]
       and a.pill._height == AF.text:GetStringHeight() + 2 * R.PILL_PAD[2]
end
check(pillFits() and a.pill:IsShown(), "sized round the text at the show")
WoW.rxpArrowText("Step 13\n(12yd)")
WoW.rxpArrowText("Step 13\n(12345yd)")
check(not pillFits(), "inside SetText: not yet")
WoW.flushTimers(0)
check(pillFits(), "a frame after SetText: resized")
WoW.rxpArrowFont(14)
WoW.flushTimers(0)
check(pillFits(), "a frame after SetFont alone, the text unchanged: resized")
WoW.rxpArrowText("")
WoW.flushTimers(0)
check(not a.pill:IsShown(), "no text: no pill")
WoW.rxpArrowText("Step 14\n(80yd)")
WoW.flushTimers(0)
check(a.pill:IsShown(), "text again: the pill back")
-- No position: RestedXP's frame alpha 0 hides ours with it (a child).
WoW.rxpArrowAlpha(0)
eq(AF:GetAlpha(), 0, "the frame's alpha RestedXP's")
WoW.rxpArrowAlpha(1)
-- The accent: ice, then gold, live.
GUI._test.slash("look accent ice")
local ice = GUI.Suite.Accent()
eq(a.arrow._vertex[1], ice[1], "the accent changed: ours follows")
GUI._test.slash("look accent gold")
eq(a.arrow._vertex[1], GUI.Suite.Accent()[1], "and back")

-- Off: RestedXP's look back; turns while off don't move ours; on again reads the angle.
GUI._test.slash("skin rxparrow off")
eq(AF.texture:GetAlpha(), 1, "off: RestedXP's arrow back")
check(not a.frame:IsShown() and not a.pill:IsShown(), "ours and the pill hidden")
WoW.rxpTurn(2)
eq(a.arrow._rotation, 0, "off: a turn leaves ours alone")
GUI._test.slash("look accent ice")
eq(a.arrow._vertex[1], c[1], "off: the accent changed, ours left alone (gold)")
GUI._test.slash("skin rxparrow on")
WoW.flushTimers(0)
eq(a.arrow._vertex[1], ice[1], "on: the accent changed while off, painted")
GUI._test.slash("look accent gold")
eq(AF.texture:GetAlpha(), 0, "on: faded again")
eq(a.arrow._rotation, 2, "on: the angle read again")
check(a.frame:IsShown() and a.pill:IsShown(), "ours and the pill back")
GUI._test.slash("skin rxp off")
for _, f in ipairs({ GN, BF, FT }) do eq(f.TopEdge:GetAlpha(), 1, "the guide off: its pieces back") end
eq(pool[1].Center:GetAlpha(), 1, "the rows' fills back")
near(pool[1]:GetAlpha(), 1, "a row's alpha still RestedXP's")
check(not h.win:IsShown() and not R.rows[pool[1]]:IsShown(), "our glass and hosts hidden")
eq(AF.texture:GetAlpha(), 0, "the arrow stays on: its own switch")
GUI._test.slash("skin rxp on")
WoW.flushTimers(0)
eq(GN.TopEdge:GetAlpha(), 0, "on again")

-- Our arrow's file ships (Tools/make_media.py): a 64 x 64, 32-bit TGA.
eq(R.ARROW, "Interface\\AddOns\\GlassUI\\Media\\Arrow", "the arrow's path in the addon")
local tga = io.open("Media/Arrow.tga", "rb")
check(tga ~= nil, "Media/Arrow.tga is there")
if tga then
    local head = tga:read(18)
    tga:close()
    eq(head:byte(3), 2, "uncompressed true colour")
    eq(head:byte(13) + 256 * head:byte(14), 64, "64 wide")
    eq(head:byte(15) + 256 * head:byte(16), 64, "64 high")
    eq(head:byte(17), 32, "32 bits, its alpha the shape")
end

-- Nothing of RestedXP's called or written by us.
eq(#WoW.luaCalls, 0, "no RestedXP function called (" .. table.concat(WoW.luaCalls, ", ") .. ")")
local changes = WoW.fieldChanges()
eq(#changes, 0, "no RestedXP field written (" .. table.concat(changes, ", ") .. ")")
check((WoW.rxpCalls.SetAlpha or 0) > 0, "(the record works) alpha set on RestedXP's objects")
for name in pairs(WoW.rxpCalls) do
    check(name == "SetAlpha" or name == "HookScript" or name:match("^Get") or name:match("^Is"),
          "only alpha, hooks and getters on RestedXP's objects: " .. name)
end

eq(next(GUI.failures), nil, "no failures")
for k, v in pairs(GUI.failures) do io.write("    " .. k .. ": " .. v .. "\n") end
done("test_rxp")
