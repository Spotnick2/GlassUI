-- The quest tracker skin (#55, docs/QUEST-TRACKER.md part 2), from Glass
-- Quest Tracker's test_skin and test_panel: the stock art steps aside on the
-- first pass and on every layout and stays aside; the panel is placed by
-- state; live off gives everything back, and on again styles what changed
-- meanwhile; every hook is gated; GQT loaded takes the tracker over.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local function failures(G)
    local keys = {}
    for k, v in pairs(G.failures) do keys[#keys + 1] = k .. "=" .. tostring(v) end
    return table.concat(keys, "; ")
end

-- Blizzard laid out before login: the first pass styles what exists.
local GUI = loadAddon({ before = function() WoW.layout("QuestObjectiveTracker", { blocks = 1, items = 1 }) end })
local QT, E = GUI.QuestTracker, GUI.Engine
local t, m = ObjectiveTrackerFrame, QuestObjectiveTracker
eq(failures(GUI), "", "no failures")
eq(E.Status("tracker"), "on", "on")
eq(m.usedRightEdgeFrames.item1:GetNormalTexture():GetAlpha(), 0, "an item button laid out before login is faded")

-- The container.
eq(t.NineSlice:GetAlpha(), 0, "the NineSlice faded")
eq(t.Header.Background:GetAlpha(), 0, "the container header's gold bar faded")
check(t.Header.Background:GetAtlas() ~= nil, "a fade keeps the art (alpha only)")
local mn = t.Header.MinimizeButton:GetNormalTexture()
check(mn:IsDesaturated(), "the container's minimize desaturated")
near(select(3, mn:GetVertexColor()), 0, "and tinted in the accent, gold by default (#52)")
near(select(2, mn:GetVertexColor()), 0.82, "Blizzard's gold")
check(t.Header.MinimizeButton:GetHighlightTexture():IsDesaturated(), "its red highlight too")
check(t.Header.FilterButton:GetNormalTexture():IsDesaturated(), "the filter button too")

-- Every module header, shown or not: blanked (a fade can't hold against AddAnim).
for _, name in ipairs(WoW.MODULE_NAMES) do
    local h = rawget(_G, name).Header
    check(h.Background:GetAtlas() == nil and h.Background:GetTexture() == nil, name .. " header bar blanked")
    check(h.Shine:GetAtlas() == nil and h.Glow:GetAtlas() == nil, name .. " shine and glow blanked")
    check(h.MinimizeButton:GetNormalTexture():IsDesaturated(), name .. " minimize tinted")
end

-- Our panel: under the modules, moving with the tracker.
local p = QT._test.panels[t]
check(p ~= nil, "the panel is built")
eq(p:GetParent(), t, "parented to the tracker: it shows, hides, moves and scales with it")
eq(p:GetName(), nil, "unnamed")
check(not p:IsMouseEnabled(), "takes no mouse: the tracker's clicks stay Blizzard's")
eq(p:GetFrameLevel(), t:GetFrameLevel() - 1, "one level under the tracker")
eq(QT._test.glass[t].top:GetFrameLevel(), t:GetFrameLevel(), "its rim at the tracker's level")
check(QT._test.glass[t].top:GetFrameLevel() < m:GetFrameLevel(), "under the modules, which draw above the glass")
check(p:IsShown(), "shown")
-- The meter's recipe: a small band over the header, the body under it.
local band = QT._test.bands[t]
check(band ~= nil and band ~= p, "a header band of its own")
eq(band:GetParent(), t, "the band on the tracker too")
eq(band:GetFrameLevel(), t:GetFrameLevel() - 1, "at the body's level, beside it, not over it")
check(band:IsShown(), "the band shown")
eq(QT._test.bandGlass[t].top:GetFrameLevel(), t:GetFrameLevel(), "its rim at the tracker's level too")

-- A layout with every pooled extra.
WoW.layout("QuestObjectiveTracker", { blocks = 2, items = 1, groups = 1, bars = 1 })
local item, group, bar = m.usedRightEdgeFrames.item1, m.usedRightEdgeFrames.group1, m.usedProgressBars.bar1
eq(item:GetNormalTexture():GetAlpha(), 0, "item button frame faded")
eq(item:GetPushedTexture():GetAlpha(), 0, "its pushed art too")
eq(group:GetDisabledTexture():GetAlpha(), 0, "the find-group button's disabled art faded")
for _, key in ipairs({ "BorderLeft", "BorderRight", "BorderMid" }) do
    eq(bar.Bar[key]:GetAlpha(), 0, "progress bar " .. key .. " faded")
end

-- Pool reuse: the same button handed back; Blizzard's alpha is held.
WoW.layout("QuestObjectiveTracker", { blocks = 2, items = 2 })
eq(m.usedRightEdgeFrames.item1, item, "the pool hands back the same button")
eq(m.usedRightEdgeFrames.item2:GetNormalTexture():GetAlpha(), 0, "a new pooled button is faded")
WoW.asBlizzard(function() item:GetNormalTexture():SetAlpha(1) end)
eq(item:GetNormalTexture():GetAlpha(), 0, "Blizzard's SetAlpha is faded again")

-- A section collapsed swaps the minimize atlas; the tint stays.
WoW.collapseModule("QuestObjectiveTracker", true)
local qn = m.Header.MinimizeButton:GetNormalTexture()
eq(qn:GetAtlas(), "ui-questtrackerbutton-secondary-expand", "Blizzard swapped the atlas")
check(qn:IsDesaturated(), "still tinted after the swap")
WoW.collapseModule("QuestObjectiveTracker", false)

-- Edit Mode's Opacity: remembered, still faded.
WoW.asBlizzard(function() t.NineSlice:SetAlpha(0.6) end)
eq(t.NineSlice:GetAlpha(), 0, "Edit Mode's Opacity doesn't bring the NineSlice back")

-- Placement by state: the corner's anchor as { relativeTo, relativePoint, x, y }.
local O = QT._test.offsets
local function at(point, rel, relPoint, x, y, msg, frame)
    local a
    for _, pt in ipairs((frame or p)._points) do
        if pt[1] == point then a = { pt[2], pt[3], pt[4], pt[5] } end
    end
    a = a or {}
    check(a[1] == rel and a[2] == relPoint and a[3] == x and a[4] == y,
          string.format("%s: %s to %s %s (%s, %s), got %s %s (%s, %s)", msg, point, tostring(rel), relPoint,
                        tostring(x), tostring(y), tostring(a[1]), tostring(a[2]), tostring(a[3]), tostring(a[4])))
end
eq(QT.state, "populated", "a shown module: populated")
at("TOPLEFT", t.NineSlice, "TOPLEFT", O.LEFT, 0, "the band from the NineSlice's top", band)
at("BOTTOMRIGHT", t.Header, "BOTTOMRIGHT", O.HEADER_RIGHT, O.HEADER_BOTTOM, "to the header's bottom", band)
at("TOPLEFT", band, "BOTTOMLEFT", 0, -O.GAP, "populated: the body under the band")
at("BOTTOMRIGHT", t.NineSlice, "BOTTOMRIGHT", O.RIGHT, O.BOTTOM, "populated: to the NineSlice's bottom")
eq(#p._points, 2, "two anchors, made afresh each time")
eq(#band._points, 2, "the band's too")
check(p:IsShown(), "populated: the body shown")
eq(O.HEADER_RIGHT - O.RIGHT, 5, "the band's right edge is the body's (the NineSlice runs 5 past the Header)")
WoW.collapse(true)
eq(QT.state, "header", "the container collapsed: the header at once, though the NineSlice keeps its size")
check(not p:IsShown(), "collapsed: no body")
check(band:IsShown(), "the band alone")
at("BOTTOMRIGHT", t.Header, "BOTTOMRIGHT", O.HEADER_RIGHT, O.HEADER_BOTTOM, "collapsed", band)
WoW.layout("QuestObjectiveTracker", { blocks = 2 })
eq(QT.state, "header", "a layout while collapsed stays on the header")
WoW.collapse(false)
WoW.layout("QuestObjectiveTracker", { blocks = 2 })
eq(QT.state, "populated", "expanded and laid out: populated again")
check(p:IsShown(), "and the body back")
WoW.editMode(true)
WoW.layout("QuestObjectiveTracker", { shown = false })
eq(QT.state, "header", "empty in Edit Mode: the header")
WoW.asBlizzard(function() m._shown = true end)
WoW.editMode(false)
eq(QT.state, "populated", "leaving Edit Mode places it again")

-- Live off: everything given back, the latest alpha Blizzard asked for included.
GUI._test.slash("skin tracker off")
eq(E.Status("tracker"), "off", "off without a /reload")
near(t.NineSlice:GetAlpha(), 0.6, "the NineSlice back at Blizzard's latest alpha")
eq(t.Header.Background:GetAlpha(), 1, "the gold bar back")
eq(m.Header.Background:GetAtlas(), "UI-QuestTracker-Secondary-Objective-Header", "the module header's bar back")
eq(m.Header.Shine:GetAtlas(), "UI-QuestTracker-OBJFX-Shine", "its shine back")
eq(item:GetNormalTexture():GetAlpha(), 1, "the item button's frame back")
eq(bar.Bar.BorderMid:GetAlpha(), 1, "the progress bar's border back")
check(not qn:IsDesaturated(), "the minimize untinted")
eq(select(1, qn:GetVertexColor()), 1, "white again")
eq(qn:GetAtlas(), "ui-questtrackerbutton-secondary-collapse", "untint leaves Blizzard's current atlas")
check(not p:IsShown() and not band:IsShown(), "both panels hidden")
WoW.asBlizzard(function() t.NineSlice:SetAlpha(0.3) end)
near(t.NineSlice:GetAlpha(), 0.3, "off: Blizzard's alpha writes stand")

-- Off, every hook does nothing: a layout, a section collapse, Edit Mode.
WoW.layout("QuestObjectiveTracker", { blocks = 1, items = 3 })
eq(m.usedRightEdgeFrames.item3:GetNormalTexture():GetAlpha(), 1, "a layout while off styles nothing")
WoW.collapseModule("QuestObjectiveTracker", true)
check(not qn:IsDesaturated(), "a collapse while off tints nothing")
WoW.collapseModule("QuestObjectiveTracker", false)
-- The container collapsed while off (the plan's case): on again places it right.
WoW.collapse(true)
eq(QT.state, "populated", "off: the panel isn't placed")
WoW.editMode(true)
WoW.editMode(false)
eq(QT.state, "populated", "nor by leaving Edit Mode")

-- On again: a full pass, what changed meanwhile included.
GUI._test.slash("skin tracker on")
eq(E.Status("tracker"), "on", "on again")
check(band:IsShown(), "the band shown again")
check(not p:IsShown(), "collapsed: the body stays hidden")
eq(QT.state, "header", "collapsed while off: placed on the header")
eq(t.NineSlice:GetAlpha(), 0, "the NineSlice faded again")
eq(m.Header.Background:GetAtlas(), nil, "the module header blanked again")
eq(m.usedRightEdgeFrames.item3:GetNormalTexture():GetAlpha(), 0, "the button laid out while off is faded")
check(qn:IsDesaturated(), "the minimize tinted again")
WoW.collapse(false)
WoW.layout("QuestObjectiveTracker", { blocks = 2 })
GUI._test.slash("skin tracker off")
near(t.NineSlice:GetAlpha(), 0.3, "a second off gives back the alpha Blizzard set while off")
eq(m.Header.Background:GetAtlas(), "UI-QuestTracker-Secondary-Objective-Header", "and the header's atlas, not the blank")
GUI._test.slash("skin tracker on")

-- The accent (#52): live through the suite look, in combat too; not while
-- off; not after a handover; Restore gives Blizzard's colour back after any
-- number of recolours, with the current atlas kept.
local qm = QuestObjectiveTracker.Header.MinimizeButton:GetNormalTexture()
local ht, qt = ObjectiveTrackerFrame.Header.Text, QuestObjectiveTracker.Header.Text
near(select(2, ht:GetTextColor()), 0.82, "the titles in the accent, gold by default: Blizzard's own gold")
GUI.Suite.SetLook("accent", "ice")
near(select(3, ht:GetTextColor()), 0.905, "'All Objectives' in ice at once (#71)")
near(select(3, qt:GetTextColor()), 0.905, "a section's title too")
near(select(3, mn:GetVertexColor()), 0.905, "the container's button recoloured to ice at once")
near(select(3, qm:GetVertexColor()), 0.905, "a section's too")
check(mn:IsDesaturated(), "still desaturated")
WoW.combat = true
GUI.Suite.SetLook("accent", "gold")
WoW.combat = false
near(select(3, mn:GetVertexColor()), 0, "in combat: recoloured at once, nothing deferred")
eq(#E._test.waiting(), 0, "nothing held for combat's end")
GUI._test.slash("skin tracker off")
GUI.Suite.SetLook("accent", "ice")
eq(select(1, mn:GetVertexColor()), 1, "off: a change of accent touches nothing")
near(select(3, ht:GetTextColor()), 0, "the title back in Blizzard's gold, and left there")
check(not mn:IsDesaturated(), "Blizzard's own again")
GUI._test.slash("skin tracker on")
near(select(3, mn:GetVertexColor()), 0.905, "on again: the current accent")
near(select(3, ht:GetTextColor()), 0.905, "the title too")
GUI.Suite.SetLook("accent", "gold")
GUI.Suite.SetLook("accent", "ice")
WoW.collapseModule("QuestObjectiveTracker", true)
GUI._test.slash("skin tracker off")
eq(select(1, qm:GetVertexColor()), 1, "after several recolours, off gives Blizzard's colour back")
check(not qm:IsDesaturated(), "and its desaturation")
eq(qm:GetAtlas(), "ui-questtrackerbutton-secondary-expand", "the current atlas stays")
local qr, qg, qb, qa = qt:GetTextColor()
check(qr == 1 and qg == 0.82 and qb == 0 and qa == 1, "the section title back in Blizzard's gold, RGBA")
WoW.collapseModule("QuestObjectiveTracker", false)
GUI._test.slash("skin tracker on")
GUI.Suite.SetLook("accent", "gold")

-- A module without a header (another build): styled, no collapse hook asked for.
GUI = loadAddon({ before = function() rawset(QuestObjectiveTracker, "Header", nil) end })
WoW.layout("QuestObjectiveTracker", { blocks = 1, items = 1 })
eq(QuestObjectiveTracker.usedRightEdgeFrames.item1:GetNormalTexture():GetAlpha(), 0, "a headerless module still styled")
eq(GUI.failures["missing:tracker:collapse:QuestObjectiveTracker"], nil, "no header: no collapse hook wanted")

-- A module only the container lists (a later build's): hooked and styled too.
local extra
GUI = loadAddon({ before = function() extra = WoW.addModule("NewObjectiveTracker") end })
eq(extra.Header.Background:GetAtlas(), nil, "a container-only module's header is blanked")
WoW.layout(extra, { blocks = 1, items = 1 })
eq(extra.usedRightEdgeFrames.item1:GetNormalTexture():GetAlpha(), 0, "and its layouts are hooked")

-- A module the container gains after our first pass: hooked at the next.
GUI = loadAddon()
local late = WoW.addModule("LateObjectiveTracker")
WoW.layout(late, { blocks = 1, items = 1 })
eq(late.usedRightEdgeFrames.item1:GetNormalTexture():GetAlpha(), 1, "not hooked before a pass sees it")
WoW.hideTracker(); WoW.showTracker()
WoW.layout(late, { blocks = 1, items = 2 })
eq(late.usedRightEdgeFrames.item2:GetNormalTexture():GetAlpha(), 0, "hooked by the next pass")

-- Glass Quest Tracker loaded: it owns the tracker, nothing of ours runs.
GUI = loadAddon({ before = function() WoW.loaded.GlassQuestTracker = true end })
check(GUI.Engine.Status("tracker"):find("handled by GlassQuestTracker", 1, true), "GQT loaded: handled by it")
check(ObjectiveTrackerFrame.Header.Background:GetAlpha() == 1, "nothing faded")
eq(QuestObjectiveTracker.Header.Background:GetAtlas(), "UI-QuestTracker-Secondary-Objective-Header", "nothing blanked")
-- And loading after us: handed over, our panel hidden, nothing restored over it.
GUI = loadAddon()
p = GUI.QuestTracker._test.panels[ObjectiveTrackerFrame]
band = GUI.QuestTracker._test.bands[ObjectiveTrackerFrame]
WoW.loaded.GlassQuestTracker = true
WoW.fire("ADDON_LOADED", "GlassQuestTracker")
check(not p:IsShown() and not band:IsShown(), "GQT loading later: our panels hide")
check(GUI.Engine.Status("tracker"):find("/reload to finish", 1, true), "and a /reload finishes the handover")
WoW.layout("QuestObjectiveTracker", { blocks = 1, items = 1 })
eq(QuestObjectiveTracker.usedRightEdgeFrames.item1:GetNormalTexture():GetAlpha(), 1, "our hooks stop")

-- No tracker (another build): recorded, nothing thrown.
GUI = loadAddon({ noTracker = true })
check(GUI.failures["skin:tracker:frames"] ~= nil, "no tracker: recorded")
eq(GUI.Engine.Status("tracker"):sub(1, 6), "failed", "and the switch says so")

done("test_tracker")
