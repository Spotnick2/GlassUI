-- The character skin (#94, docs/CHARACTER.md): the window pieces, the hosts'
-- own art faded (never their content, never the currency pane), the right
-- pane and the level strip as panes, the model on the glass, each slot a glass
-- well with nothing on its click path (the ammo slot's own anatomy), the stats
-- headers as glass bars and the stat lines stock (style pass and Update), the
-- pet's stats stock, the mode and sidebar tabs through the kit's side tabs;
-- the reputation, skills and statistics headers in the tracker's look.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local GUI = loadAddon()
local C = GUI.Character._test
local CF = CharacterFrame
local Kit = GUI.Kit

local function ours(parent)
    local list = {}
    for _, c in ipairs(parent._children) do if not rawget(c, "_blizz") then list[#list + 1] = c end end
    return list
end
local function at(frame, point, rel, relPoint, x, y, msg)
    local a
    for _, pt in ipairs(frame._points) do if pt[1] == point then a = pt end end
    check(a and a[2] == rel and a[3] == relPoint and a[4] == x and a[5] == y,
          msg .. ": " .. point .. " " .. tostring(a and a[4]) .. "," .. tostring(a and a[5]))
end
local gold = GUI.Suite.ACCENTS.gold

eq(GUI.Engine.Status("character"), "on", "the character skin is on by default")
WoW.combat = true
WoW.showCharacter()
WoW.flushTimers(0)
WoW.combat = false
local h = C.wins[CF]
check(h ~= nil, "built at the first show (in combat)")

-- The window.
eq(CF.NineSlice:GetAlpha(), 0, "the NineSlice faded (no Bg on this template)")
eq(h.backing._color[4], GUI.Theme.WINDOW_BACKING, "the window floor")
at(h.header, "BOTTOM", CF.LeftPaneHost, "TOP", 0, 0, "the smoky band down to the left pane's top")
check(h.disc ~= nil, "the portrait's disc")
at(h.disc, "CENTER", CF.PortraitContainer.CircleMask, "CENTER", 0, 0, "round the template's mask")
eq(CF.CloseButton._normal:GetAlpha(), 0, "the close button's red faded")
check(h.closeX ~= nil, "our X")

-- The hosts: their own regions faded, our right pane and separator.
eq(CF.LeftPaneHost._regions[1]:GetAlpha(), 0, "the left host's art faded")
eq(CF.RightPaneHost._regions[1]:GetAlpha(), 0, "the right host's art faded")
eq(CF.RightPaneHost.StoneBg:GetAlpha(), 0, "its StoneBg faded")
local divider = CF.RightPaneHost._children[1]
eq(divider._regions[1]:GetAlpha(), 0, "its divider's texture faded")
check(h.right and h.right.fill:IsShown(), "the right pane a recessed pane")
eq(h.rightHost:GetParent(), CF.RightPaneHost, "on our host in the right host: it hides with it (collapsed)")
eq(h.separator._width, 1, "a 1 px separator")
at(h.separator, "TOPLEFT", CF.RightPaneHost, "TOPLEFT", 0, 0, "along the right pane's left edge")
eq(CF.RightPaneToggleButton:GetAlpha(), 1, "the toggle arrow Blizzard's")
CF.RightPaneHost:Hide()
check(not h.right.fill:IsVisible(), "collapsed: the pane hides with the host")
CF.RightPaneHost:Show()

-- The level strip and the model.
local strip = PaperDollFrame.TopBackgroundStripHost
eq(strip.TopBackgroundStrip:GetAlpha(), 0, "the strip's rock faded")
eq(strip.TopBackgroundStripBottomEdge:GetAlpha(), 0, "its edge faded")
check(h.strip and h.strip.fill:IsShown(), "a pane on the strip")
for _, k in ipairs({ "BackgroundTopLeft", "BackgroundBotRight", "BackgroundOverlay" }) do
    eq(CharacterModelScene[k]:GetAlpha(), 0, "the model's " .. k .. " faded")
end
eq(CharacterModelScene.ControlFrame:GetAlpha(), 1, "its controls stay")

-- The slots: a well each, BorderFrame and NormalTexture faded, nothing on the click path.
for _, n in ipairs(C.SLOTS) do
    local b = _G["Character" .. n .. "Slot"]
    local s = C.slots[b]
    check(s ~= nil, n .. ": a glass well")
    eq(s.glass:GetParent(), b, n .. ": in the slot")
    eq(s.glass:GetFrameLevel(), b:GetFrameLevel() - 1, n .. ": under it")
    eq(s.g.top:GetFrameLevel(), s.glass:GetFrameLevel(), n .. ": its rim lowered")
    check(not s.glass._mouse, n .. ": mouse off")
    eq(b.BorderFrame:GetAlpha(), 0, n .. ": its frame faded")
    eq(b._normal:GetAlpha(), 0, n .. ": its normal texture faded")
    eq(b.IconBorder:GetAlpha(), 1, n .. ": the quality border Blizzard's")
    eq(b.icon:GetAlpha(), 1, n .. ": the icon Blizzard's")
end
eq(CharacterHeadSlot._scripts.OnClick, nil, "no script of ours on a slot")
-- The ammo slot: its own BACKGROUND ring and normal texture, the arrow kept.
eq(CharacterAmmoSlot._regions[1]:GetAlpha(), 0, "the ammo slot's ring faded")
eq(CharacterAmmoSlot._normal:GetAlpha(), 0, "its normal texture faded")
eq(CharacterAmmoSlot.arrowFrame._regions[1]:GetAlpha(), 1, "its arrow kept")
eq(CharacterAmmoSlot.iconTexture:GetAlpha(), 1, "its icon (BORDER) kept: the BACKGROUND ring only")
check(C.slots[CharacterAmmoSlot] ~= nil, "and a well")

-- The stats: the wrapper's chrome, headers on glass, stat lines stock.
local stats = CharacterStatsPaneScrollBox
eq(stats.Border:GetAlpha(), 0, "the stats border faded")
eq(stats.ClassBackground:GetAlpha(), 0, "the class background faded")
check(h.stats and h.stats.fill:IsShown(), "a pane on the stats")
local function rows(kind)
    local out = {}
    for _, r in ipairs(WoW.statPool) do if r._kind == kind and r:IsShown() then out[#out + 1] = r end end
    return out
end
local heads, lines = rows("header"), rows("stat")
eq(#heads, 2, "two headers")
for _, r in ipairs(heads) do
    check(C.headers[r] ~= nil, "a header on glass")
    eq(r.Background:GetAlpha(), 0, "its background faded")
end
for _, r in ipairs(lines) do
    eq(C.headers[r], nil, "a stat line: no glass")
    eq(r.Background:GetAlpha(), 1, "its stripe Blizzard's")
end
-- Scrolled: new pooled rows through the Update hook, reused rows once.
WoW.statRows = { "header", "stat", "header", "header", "stat" }
WoW.asBlizzard(function() stats.ScrollBox:Update() end)
for _, r in ipairs(rows("header")) do
    check(C.headers[r] ~= nil and r.Background:GetAlpha() == 0, "every header after a scroll")
    eq(#ours(r), 1, "one glass per pooled row")
end
-- The pet's stats: stock.
eq(WoW.petHeader.Background:GetAlpha(), 1, "the pet's stats untouched")
eq(C.headers[WoW.petHeader], nil, "and no glass there")

-- The list panes' headers: a glass bar, the bronze bar faded, the hover glow
-- neutral, the +/- and the name in the accent; entries stock; sub-headers'
-- toggles in the accent.
local function paneRows(name, kind)
    local out = {}
    for _, r in ipairs(WoW.panePools[name]) do if r._kind == kind and r:IsShown() then out[#out + 1] = r end end
    return out
end
local function goldIs(tex) return tex._vertex and tex._vertex[2] == gold[2] and tex._vertex[3] == gold[3] end
for _, name in ipairs(C.PANES) do
    WoW.characterPane(name)
    local hs = paneRows(name, "header")
    check(#hs > 0, name .. ": headers shown")
    for _, r in ipairs(hs) do
        check(C.headers[r] ~= nil and C.headers[r].pane, name .. ": a header on a glass bar")
        eq(r._regions[1]:GetAlpha(), 0, name .. ": its bronze bar faded")
        check(r._regions[2]._desat and r._regions[2]._vertex[2] == 1, name .. ": its hover glow neutral")
        eq(r._regions[2]:GetAlpha(), 1, name .. ": and kept")
        check(goldIs(r.StateIcon) and r.StateIcon._desat, name .. ": its +/- in the accent")
        local cr, cg, cb = r.Name:GetTextColor()
        check(cr == gold[1] and cg == gold[2] and cb == gold[3], name .. ": its name in the accent")
    end
    for _, r in ipairs(paneRows(name, "entry")) do
        eq(C.headers[r], nil, name .. ": an entry: no glass")
        eq(#ours(r), 0, name .. ": nothing of ours on it")
    end
    for _, r in ipairs(paneRows(name, "sub")) do
        check(goldIs(r.ToggleCollapseButton._normal) and goldIs(r.ToggleCollapseButton._pushed),
              name .. ": a sub-header's toggle in the accent")
        eq(C.headers[r], nil, name .. ": and no bar")
    end
end
-- A collapse: new data, a header acquired where an entry was.
WoW.paneRows.SkillsFrame = { "header", "header", "header" }
WoW.asBlizzard(function() SkillsFrame.ScrollBox:Update() end)
for _, r in ipairs(paneRows("SkillsFrame", "header")) do
    check(C.headers[r] ~= nil and r._regions[1]:GetAlpha() == 0, "after a collapse: every header")
    eq(#ours(r), 1, "one bar per pooled row")
end
-- Blizzard's atlas on collapse keeps our tint.
local sh = paneRows("SkillsFrame", "header")[1]
WoW.asBlizzard(function() sh.StateIcon:SetAtlas("common-button-list-plus") end)
check(goldIs(sh.StateIcon), "the +/- keeps the accent through Blizzard's SetAtlas")
WoW.characterPane(nil)

-- The tabs: the six mode tabs (SelectedTexture) and the four sidebar (GetChecked).
local modes = CF.ModeTabs.Tabs
local ts = Kit.sideTabs
for i, t in ipairs(modes) do
    check(ts[t] ~= nil, "mode tab " .. i .. ": glass")
    eq(t.Background:GetAlpha(), 0, "mode tab " .. i .. ": its background faded")
    eq(t.SelectedTexture:GetAlpha(), 0, "mode tab " .. i .. ": its selected art faded")
    eq(t.Icon:GetAlpha(), 1, "mode tab " .. i .. ": its icon kept")
end
check(ts[modes[1]].light:IsShown(), "the first mode lit")
check(ts[modes[1]].g.rim._vertex[2] == gold[2], "its rim in the accent")
check(not ts[modes[2]].light:IsShown(), "the others not")
WoW.characterMode(3)
check(ts[modes[3]].light:IsShown() and not ts[modes[1]].light:IsShown(), "a mode change mirrored (SelectedTexture)")
eq(ts[modes[1]].g.rim._vertex[3], 1, "the old one's rim back to white")
WoW.characterMode(1)
local sb1, sb2 = PaperDollSidebarTab1, PaperDollSidebarTab2
check(ts[sb1] ~= nil and ts[sb1].light:IsShown(), "sidebar tab 1 lit (GetChecked)")
eq(sb1._regions[2]:GetAlpha(), 0, "its BORDER frame faded")
eq(sb1._checkedTex:GetAlpha(), 0, "its checked art faded")
eq(sb1.Icon:GetAlpha(), 1, "its icon kept")
WoW.asBlizzard(function() sb1:SetChecked(false); sb2:SetChecked(true) end)
check(ts[sb2].light:IsShown() and not ts[sb1].light:IsShown(), "a sidebar change mirrored")
-- The accent.
GUI._test.slash("look accent ice")
check(ts[modes[1]].g.rim._vertex[2] == GUI.Suite.ACCENTS.ice[2], "the accent followed")
local ice = GUI.Suite.ACCENTS.ice
check(sh.StateIcon._vertex[2] == ice[2], "a list header's +/- followed")
check(select(2, sh.Name:GetTextColor()) == ice[2], "and its name")
local sub = paneRows("StatisticsFrame", "sub")[1] or WoW.panePools.StatisticsFrame[4]
check(sub.ToggleCollapseButton._normal._vertex[2] == ice[2], "a sub-header's toggle followed")
GUI._test.slash("look accent gold")

-- Off: Blizzard's look, its changes meanwhile untouched; on: re-synced, without a Blizzard Update.
GUI._test.slash("skin character off")
eq(CF.NineSlice:GetAlpha(), 1, "off: the shell back")
eq(CharacterHeadSlot.BorderFrame:GetAlpha(), 1, "the slots' frames back")
eq(heads[1].Background:GetAlpha(), 1, "the headers' backgrounds back")
eq(modes[1].Background:GetAlpha(), 1, "the tabs' art back")
check(not C.slots[CharacterHeadSlot].glass:IsShown(), "our glass hidden")
eq(sh._regions[1]:GetAlpha(), 1, "off: a list header's bar back")
check(not sh.StateIcon._desat and sh.StateIcon._vertex[2] == 1, "its +/- Blizzard's")
local orr, org = sh.Name:GetTextColor()
check(orr == 1 and org == 0.82, "its name Blizzard's gold")
check(not C.headers[sh].glass:IsShown(), "its bar hidden")
WoW.characterPane("ReputationFrame")
local offRep = paneRows("ReputationFrame", "header")[1]
check(not offRep.StateIcon._desat and offRep._regions[1]:GetAlpha() == 1, "off: an Update styles no list header")
GUI._test.slash("look accent ice")
check(not sh.StateIcon._desat and sh.StateIcon._vertex[2] == 1, "off: an accent change tints no list header")
eq(select(2, sh.Name:GetTextColor()), 0.82, "nor colours its name")
GUI._test.slash("look accent gold")
WoW.characterPane(nil)
WoW.characterMode(4)
check(not ts[modes[4]].light:IsShown(), "off: a mode change lights nothing")
WoW.statRows = { "stat", "header" }
WoW.asBlizzard(function() stats.ScrollBox:Update() end)
local offHead = WoW.statPool[2]
eq(offHead.Background:GetAlpha(), 1, "off: a header made by an Update isn't styled")
eq(C.headers[offHead], nil, "nor given glass")
WoW.statRows = { "header", "stat", "stat", "header", "stat", "stat", "stat" }
GUI._test.slash("skin character on")
eq(CF.NineSlice:GetAlpha(), 0, "on: faded")
eq(heads[1].Background:GetAlpha(), 0, "the headers re-styled without a Blizzard Update")
check(ts[modes[4]].light:IsShown(), "the mode read again")
eq(sh._regions[1]:GetAlpha(), 0, "on: the list headers re-styled without a Blizzard Update")
check(goldIs(sh.StateIcon), "in the accent")
WoW.characterMode(1)

-- Hazards: nothing on the currency pane; no anchor on Blizzard's frames.
eq(#WoW.currencyTouches, 0, "the currency pane untouched")
eq(#CF.LeftPaneHost._points, 0, "the hosts not anchored by us")
eq(#CharacterHeadSlot._points, 0, "nor the slots")

-- Another skin's side tabs: a character sync never touches the guild's.
WoW.showGuild()
GUI._test.slash("skin guild off")
WoW.asBlizzard(function() CommunitiesFrame.RosterTab:SetChecked(true) end)
WoW.characterMode(2)
check(not ts[CommunitiesFrame.RosterTab].light:IsShown(), "a character sync leaves the guild's tabs alone (per kit)")
GUI._test.slash("skin guild on")
WoW.hideGuild()

eq(next(GUI.failures), nil, "no failures")
for k, v in pairs(GUI.failures) do io.write("    " .. k .. ": " .. v .. "\n") end
done("test_character")
