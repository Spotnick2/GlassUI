-- The world map skin (#99, docs/MAP.md): styled a frame after the show and
-- after every hooked call (never inside it); the shell (the NineSlice through
-- Blizzard's SetAtlas, Bg reparented, the disc following the portrait
-- texture, the close and maximise/minimise glyph buttons); the bar and its
-- pooled crumbs (the overflow kept); the quest log's art, pane, pills and its
-- zone headers (the covenant header, titles, objectives and POI buttons
-- untouched); the neighbours untouched; off and on; the Leatrix yield.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local GUI = loadAddon()
local M = GUI.Map._test
local WM = WorldMapFrame
local BF = WM.BorderFrame
local MM = BF.MaximizeMinimizeFrame
local NAV = WM.NavBar
local QSF = QuestScrollFrame
local Kit = GUI.Kit
local gold, ice = GUI.Suite.ACCENTS.gold, GUI.Suite.ACCENTS.ice

local function ours(parent)
    local list = {}
    for _, c in ipairs(parent._children) do if not rawget(c, "_blizz") then list[#list + 1] = c end end
    return list
end
local function rows(kind)
    local out = {}
    for _, r in ipairs(WoW.questPool) do if r._kind == kind and r:IsShown() then out[#out + 1] = r end end
    return out
end
local function goldIs(tex, c) c = c or gold; return tex._vertex and tex._vertex[2] == c[2] and tex._vertex[3] == c[3] end

eq(GUI.Engine.Status("map"), "on", "the map skin is on by default")
-- The first opening, in combat: nothing inside the show, all of it a frame later.
WoW.combat = true
WoW.showMap()
eq(M.wins[WM], nil, "nothing built inside the show (a secure call chain)")
eq(BF.NineSlice:GetAlpha(), 1, "nothing faded inside it")
WoW.flushTimers(0)
WoW.combat = false
local h = M.wins[WM]
check(h ~= nil, "built a frame later, in combat too")

-- The shell.
eq(BF.NineSlice:GetAlpha(), 0, "the NineSlice faded")
eq(BF.Bg:GetAlpha(), 0, "Bg faded, reparented to the window")
eq(BF.InsetBorderTop:GetAlpha(), 0, "the top inset faded")
eq(h.backing._color[4], GUI.Theme.WINDOW_BACKING, "the window floor")
check(h.header ~= nil, "a header band")
local hp
for _, pt in ipairs(h.header._points) do if pt[1] == "BOTTOM" then hp = pt end end
check(hp and hp[2] == NAV and hp[3] == "BOTTOM", "down to the bar's bottom")
eq(BF.TitleContainer.TitleText:GetAlpha(), 1, "the title Blizzard's")
for _, r in ipairs(WM.OverscrollBG._regions) do eq(r:GetAlpha(), 0, "the overscroll art faded") end
check(h.disc ~= nil and h.disc:IsShown(), "the book's disc")
eq(BF.CloseButton._normal:GetAlpha(), 0, "the close button's red faded")
check(h.closeX ~= nil, "our X")
local gmax, gmin = h.glyphs[MM.MaximizeButton], h.glyphs[MM.MinimizeButton]
check(gmax ~= nil and gmin ~= nil, "a glyph on each of the maximise and minimise buttons")
eq(MM.MaximizeButton._normal:GetAlpha(), 0, "the maximise button's red faded")
eq(MM.MinimizeButton._pushed:GetAlpha(), 0, "the minimise button's too")
eq(gmax.disc:GetParent(), MM.MaximizeButton, "its disc in the button: it hides with it")
eq(gmax.frame:GetFrameLevel(), MM.MaximizeButton:GetFrameLevel() + 1, "the glyph over it")
eq(#gmax.strokes, 3, "a shaft and a head")
check(goldIs(gmax.strokes[1]) or (gmax.strokes[1]._color and gmax.strokes[1]._color[2] == gold[2]), "in the accent")

-- Glyph feedback: per button, the close X untouched.
WoW.asBlizzard(function() MM.MaximizeButton._scripts.OnEnter(MM.MaximizeButton) end)
eq(gmax.alpha, 1, "hover: the glyph full")
eq(h.closeAlpha, Kit.CLOSE_REST, "the close X not")
WoW.asBlizzard(function() MM.MaximizeButton._scripts.OnMouseDown(MM.MaximizeButton) end)
check(gmax.pushed, "pressed")

-- Maximise: the swap and the NineSlice's SetAtlas; the display synced a frame later.
WoW.mapMaximize(true)
eq(BF.NineSlice:GetAlpha(), 0, "the NineSlice still faded through SetAtlas")
check(h.disc:IsShown(), "inside the call: nothing of ours changed yet")
WoW.flushTimers(0)
check(not h.disc:IsShown(), "a frame later: the disc follows the hidden portrait")
check(not MM.MaximizeButton:IsShown() and MM.MinimizeButton:IsShown(), "Blizzard swapped the buttons")
check(not gmax.pushed, "the button hidden while pressed: synced from its getters")
WoW.mapMaximize(false)
WoW.flushTimers(0)
check(h.disc:IsShown(), "minimised: the disc back")

-- The bar: its art faded, a pane, the crumbs' state textures (overflow kept).
for _, k in ipairs(M.NAV_ART) do eq(NAV[k]:GetAlpha(), 0, "the bar's " .. k .. " faded") end
eq(NAV._regions[1]:GetAlpha(), 0, "its tile faded")
eq(NAV.overlay._regions[1]:GetAlpha(), 0, "its overlay's tile faded")
check(h.nav and h.nav.fill:IsShown(), "a recessed pane")
eq(h.navHost:GetFrameLevel(), NAV:GetFrameLevel(), "at the bar's level, under its crumbs")
eq(NAV.homeButton._normal:GetAlpha(), 0, "home's tile faded")
eq(NAV.homeButton._pushed:GetAlpha(), 0, "and pushed")
eq(NAV.overflowButton._normal:GetAlpha(), 1, "the overflow button kept (its art is its glyph)")
eq(NAV.homeButton.arrowUp:GetAlpha(), 1, "the chevrons kept")
-- A map change: the bar rebuilt, new crumbs styled a frame later, never inside Refresh.
WoW.crumbs = 3
WoW.mapRefresh()
local newest = NAV.navList[#NAV.navList]
eq(newest._normal:GetAlpha(), 1, "inside Refresh (secureexecuterange): nothing styled")
WoW.flushTimers(0)
for i, b in ipairs(NAV.navList) do eq(b._normal:GetAlpha(), 0, "crumb " .. i .. " faded a frame later") end
check(newest.text:GetAlpha() == 1 and newest.selected:GetAlpha() == 1, "its text and selection kept")

-- The quest log.
eq(QSF.Background:GetAlpha(), 0, "the log's background faded (through its SetAtlas)")
eq(QSF.BorderFrame.Border:GetAlpha(), 0, "its frame faded")
eq(QSF.BorderFrame.TopDetail:GetAlpha(), 0, "its filigree faded")
eq(QSF.BorderFrame.Shadow._atlas, nil, "its shadow blanked")
WoW.questScroll(0.6)
eq(QSF.BorderFrame.Shadow._atlas, nil, "a scroll's SetAlpha brings no shadow back")
eq(QSF.Contents.Separator.Divider:GetAlpha(), 0, "the divider faded")
eq(QSF.Contents.StoryHeader.Background:GetAlpha(), 1, "the story header Blizzard's")
check(h.log and h.log.fill:IsShown(), "a recessed pane")
eq(h.logHost:GetParent(), QuestMapFrame.QuestsFrame, "on a host in QuestsFrame: it hides with it")
eq(h.logHost:GetFrameLevel(), QuestMapFrame.QuestsFrame:GetFrameLevel(), "at its level, under the list")
for _, k in ipairs({ "Left", "Right", "Middle" }) do
    eq(QSF.SearchBox[k]:GetAlpha(), 0, "the search box's " .. k .. " faded")
    eq(QuestLogCount[k]:GetAlpha(), 0, "the count's " .. k .. " faded")
end
local sp = M.pills[QSF.SearchBox]
check(sp ~= nil, "a pill under the search box")
eq(sp.glass:GetFrameLevel(), QSF.SearchBox:GetFrameLevel() - 1, "under it")
eq(sp.g.top:GetFrameLevel(), sp.glass:GetFrameLevel(), "its rim lowered")
check(M.pills[QuestLogCount] ~= nil, "and under the count")
eq(QSF.SearchBox.searchIcon:GetAlpha(), 1, "the magnifier Blizzard's")
eq(QSF.ScrollBar:GetAlpha(), 1, "the scroll bar Blizzard's")
eq(#ours(QuestMapFrame), 0, "nothing of ours on QuestMapFrame itself")

-- The headers.
local hs = rows("header")
eq(#hs, 2, "two zone headers")
for _, r in ipairs(hs) do
    check(M.headers[r] ~= nil, "a header on a glass bar")
    eq(M.headers[r].glass:GetParent(), r, "parented to the row: out of the layout")
    eq(r._normal:GetAlpha(), 0, "its bar faded")
    check(r._highlight._desat and r._highlight._vertex[2] == 1, "its glow white")
    check(goldIs(r.CollapseButton.Icon) and r.CollapseButton.Icon._desat, "its +/- in the accent")
    eq(r.ButtonText._textColor[1], 0.5, "its text Blizzard's grey")
end
local camp = rows("campaign")[1]
eq(M.headers[camp], nil, "a campaign header (Text, not ButtonText): no bar")
eq(camp._normal:GetAlpha(), 1, "nor faded")
local cov = rows("covenant")[1]
eq(M.headers[cov], nil, "the covenant callings' header: no bar (SelectedHighlight)")
eq(cov._normal:GetAlpha(), 1, "nor faded")
for _, kind in ipairs({ "title", "objective", "poi" }) do
    for _, r in ipairs(rows(kind)) do
        eq(M.headers[r], nil, kind .. ": no bar")
        eq(#ours(r), 0, kind .. ": nothing of ours")
    end
end
eq(rows("title")[1].Checkbox.CheckMark:GetAlpha(), 1, "the tracking checkbox Blizzard's")
-- An update: new rows, pooled reuse; styled a frame later, not inside the update.
WoW.questRows = { "header", "header", "title", "header" }
WoW.questLogUpdate()
local fresh = WoW.questPool[2]
eq(M.headers[fresh], nil, "inside QuestLogQuests_Update: nothing styled")
WoW.flushTimers(0)
for _, r in ipairs(rows("header")) do
    check(M.headers[r] ~= nil and r._normal:GetAlpha() == 0, "every header a frame later")
    eq(#ours(r), 1, "one bar per pooled row")
end
check(goldIs(fresh.CollapseButton.Icon), "Blizzard's SetAtlas on the +/- keeps our tint")

-- The neighbours, the canvas, the other overlay frames: untouched.
for i, r in ipairs(WoW.neighbours) do
    eq(r:GetAlpha(), 1, "neighbour " .. i .. " untouched")
    eq(r._vertex, nil, "neighbour " .. i .. " not tinted")
end

-- The accent.
GUI._test.slash("look accent ice")
check(goldIs(hs[1].CollapseButton.Icon, ice), "the headers' +/- followed")
check(gmax.strokes[1]._color and gmax.strokes[1]._color[2] == ice[2], "the glyphs followed")
GUI._test.slash("look accent gold")

-- Off: Blizzard's look; a pass queued before the switch is dropped. On: back without a Blizzard call.
WoW.mapMaximize(true)
GUI._test.slash("skin map off")
WoW.flushTimers(0)
eq(BF.NineSlice:GetAlpha(), 1, "off: the NineSlice back")
eq(QSF.Background:GetAlpha(), 1, "the log's background back")
check(QSF.BorderFrame.Shadow._atlas ~= nil, "its shadow given back")
eq(hs[1]._normal:GetAlpha(), 1, "the headers' bars back")
check(not hs[1].CollapseButton.Icon._desat, "their +/- Blizzard's")
eq(NAV.homeButton._normal:GetAlpha(), 1, "the crumbs back")
check(not h.disc:IsShown() and not h.nav.fill:IsVisible(), "our pieces hidden")
eq(MM.MinimizeButton._normal:GetAlpha(), 1, "the buttons' red back")
WoW.questLogUpdate()
WoW.mapRefresh()
WoW.flushTimers(0)
GUI._test.slash("look accent ice")
local offIcon = hs[1].CollapseButton.Icon
check(not offIcon._desat and (offIcon._vertex == nil or offIcon._vertex[2] == 1), "off: an accent change tints no header")
GUI._test.slash("look accent gold")
local offAlpha = gmax.alpha
WoW.asBlizzard(function() MM.MaximizeButton._scripts.OnEnter(MM.MaximizeButton) end)
eq(gmax.alpha, offAlpha, "off: a hover drives no glyph")
WoW.asBlizzard(function() MM.MaximizeButton._scripts.OnLeave(MM.MaximizeButton) end)
eq(WoW.questPool[1]._normal:GetAlpha(), 1, "off: an update styles nothing")
eq(NAV.navList[2]._normal:GetAlpha(), 1, "nor a map change")
GUI._test.slash("skin map on")
WoW.flushTimers(0)
eq(BF.NineSlice:GetAlpha(), 0, "on: faded again (maximised)")
check(not h.disc:IsShown(), "the disc follows the portrait (hidden, maximised)")
eq(WoW.questPool[1]._normal:GetAlpha(), 0, "the headers again")
WoW.mapMaximize(false)
WoW.flushTimers(0)
check(h.disc:IsShown(), "minimised after off and on: the disc back")
WoW.hideMap()

eq(next(GUI.failures), nil, "no failures")
for k, v in pairs(GUI.failures) do io.write("    " .. k .. ": " .. v .. "\n") end

-- Leatrix Maps' simple frame: the skin yields when it's On or unknown (its default), runs when Off.
local function withLeatrix(db)
    local G = loadAddon({ before = function()
        WoW.loaded.Leatrix_Maps = true
        rawset(_G, "LeaMapsDB", db)
    end })
    WoW.showMap()
    WoW.flushTimers(0)
    local styled = WorldMapFrame.BorderFrame.NineSlice:GetAlpha() == 0
    rawset(_G, "LeaMapsDB", nil)
    return G, styled
end
local G1, s1 = withLeatrix({ SimpleMapFrame = "On" })
check(not s1, "Leatrix's simple frame On: the skin yields")
check(G1.Engine.Status("map"):find("Leatrix_Maps", 1, true), "and says why")
local _, s2 = withLeatrix(nil)
check(not s2, "its saved variables missing (its default is On): yields")
local _, s3 = withLeatrix({ SimpleMapFrame = "Off" })
check(s3, "Off (the owner's): styled")
check(GUI.Map._test.leatrixSimple() == true, "the predicate: no DB reads as On")

done("test_map")
