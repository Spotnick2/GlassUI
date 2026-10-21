-- The loot skins (#105, docs/LOOT.md): the loot window styled a frame after
-- the show and after its list's Update (never inside them), its shell, its
-- rows (plates faded, strokes white, slot faded, content untouched, glass at
-- the row's level - 1, one per pooled row); the history's shell and rows
-- (glass at the art's level - 1, under the roll-100 effect), its passed
-- headers and PerfectAnimFrame untouched; off and on; no field written.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local GUI = loadAddon()
local L = GUI.Loot._test
local LF, HF = LootFrame, GroupLootHistoryFrame

local function ours(parent)
    local list = {}
    for _, c in ipairs(parent._children) do if not rawget(c, "_blizz") then list[#list + 1] = c end end
    return list
end
local function shown(pool, kind)
    local out = {}
    for _, r in ipairs(pool) do if r._kind == kind and r:IsShown() then out[#out + 1] = r end end
    return out
end

eq(GUI.Engine.Status("loot"), "on", "the loot skin is on by default")
eq(GUI.Engine.Status("loothistory"), "on", "and the history's")

-- The first loot, in combat: nothing inside Open (the list, the show), all of it a frame later.
WoW.combat = true
WoW.loot()
eq(L.wins[LF], nil, "nothing built inside Open (a secure call chain)")
eq(LF.NineSlice:GetAlpha(), 1, "nothing faded inside it")
WoW.flushTimers(0)
WoW.combat = false
local h = L.wins[LF]
check(h ~= nil, "built a frame later, in combat too")

-- The shell.
eq(LF.NineSlice:GetAlpha(), 0, "the NineSlice faded")
eq(LF.Bg:GetAlpha(), 0, "the Bg frame faded")
for _, k in ipairs(L.NINE_PIECES) do eq(LF.NineSlice[k]:GetAlpha(), 0, "the NineSlice's " .. k .. " faded") end
for _, k in ipairs(L.BG_PIECES) do eq(LF.Bg[k]:GetAlpha(), 0, "the Bg's " .. k .. " faded") end
-- #109, as measured: what was faded while the window's and the rows' show
-- animations played comes back when they end; the pass runs again then.
local firstRow = shown(WoW.lootPool, "item")[1]
WoW.lootAnimsDone()
eq(LF.NineSlice:GetAlpha(), 1, "(the stub) the animations' end undoes the fades")
eq(firstRow.NameFrame:GetAlpha(), 1, "(the stub) a row's plate too")
WoW.flushTimers(0)
eq(LF.NineSlice:GetAlpha(), 0, "a frame after the animations: the NineSlice faded again")
eq(LF.NineSlice.TopEdge:GetAlpha(), 0, "its pieces")
eq(LF.Bg:GetAlpha(), 0, "the Bg")
eq(LF.Bg.TopSection:GetAlpha(), 0, "its pieces")
eq(firstRow.NameFrame:GetAlpha(), 0, "and the row's plate")
eq(h.backing._color[4], GUI.Theme.WINDOW_BACKING, "the window floor")
local hp
for _, pt in ipairs(h.header._points) do if pt[1] == "BOTTOM" then hp = pt end end
check(hp and hp[2] == LF.ScrollBox and hp[3] == "TOP", "the band down to the list's top")
eq(LF.ClosePanelButton._normal:GetAlpha(), 0, "the close button's red faded")
check(h.closeX ~= nil and h.closeLight ~= nil, "our X and its hover light")
eq(LF.TitleContainer.TitleText:GetAlpha(), 1, "the title Blizzard's")
eq(LF.ScrollBox.Shadows.Upper:GetAlpha(), 1, "the list's shadows Blizzard's")
eq(LF.ScrollBar:GetAlpha(), 1, "and its bar")

-- The rows.
for _, kind in ipairs({ "item", "money" }) do
    for _, r in ipairs(shown(WoW.lootPool, kind)) do
        local s = L.rows[r]
        check(s ~= nil, kind .. ": a glass row")
        eq(s.glass:GetParent(), r, kind .. ": in the row (it fades and slides with it)")
        eq(s.glass:GetFrameLevel(), r:GetFrameLevel() - 1, kind .. ": at the row's level - 1")
        eq(s.g.top:GetFrameLevel(), s.glass:GetFrameLevel(), kind .. ": its rim lowered")
        check(not s.glass._mouse, kind .. ": mouse off")
        eq(r.NameFrame:GetAlpha(), 0, kind .. ": its plate faded")
        eq(r.BorderFrame:GetAlpha(), 0, kind .. ": its edge faded")
        check(r.HighlightNameFrame._desat and r.HighlightNameFrame._vertex[2] == 1, kind .. ": its hover stroke white")
        check(r.PushedNameFrame._desat, kind .. ": its press stroke too")
        eq(r.Item._normal:GetAlpha(), 0, kind .. ": its slot faded")
        eq(r.Item.icon:GetAlpha(), 1, kind .. ": the icon Blizzard's")
        eq(r.Item.IconBorder:GetAlpha(), 1, kind .. ": the quality border Blizzard's")
        eq(r.Text:GetAlpha(), 1, kind .. ": the name Blizzard's")
        eq(r.IconQuestTexture:GetAlpha(), 1, kind .. ": the quest mark Blizzard's")
    end
end
local item = shown(WoW.lootPool, "item")[1]
eq(item.QualityStripe:GetAlpha(), 0, "the rarity tag's frame faded")
eq(item.QualityText:GetAlpha(), 1, "its text Blizzard's")
local base = shown(WoW.lootPool, "base")[1]
eq(L.rows[base], nil, "the empty slot: nothing")
eq(#ours(base), 0, "nothing of ours on it")
eq(MasterLooterFrame:GetAlpha(), 1, "the master looter frame untouched")

-- Init's re-colouring (LOOT_SLOT_CHANGED) keeps the fades.
WoW.asBlizzard(function() item.NameFrame:SetVertexColor(0.6, 0.2, 0.9); item.Item._normal:SetVertexColor(1, 0, 0) end)
eq(item.NameFrame:GetAlpha(), 0, "the plate's re-colour keeps it faded")
eq(item.Item._normal:GetAlpha(), 0, "the slot's too")
-- A slide-out (auto-loot) hides the row: our glass with it.
WoW.asBlizzard(function() item:Hide() end)
check(not L.rows[item].glass:IsVisible(), "a row slid out: its glass gone with it")
WoW.closeLoot()

-- A loot while the window is already open (no OnShow): the rows' pass waits too.
WoW.loot()
WoW.flushTimers(0)
WoW.lootAnimsDone()                                       -- what the opens left waiting, settled
WoW.flushTimers(0)
check(LF:IsShown(), "the window open")
WoW.lootRows = { "money", "money", "item" }               -- new kinds: fresh rows
WoW.loot()
WoW.flushTimers(0)
local late = WoW.lootPool[1]
WoW.lootAnimsDone()
eq(late.NameFrame:GetAlpha(), 1, "(the stub) the new row's plate undone at the animations' end")
WoW.flushTimers(0)
eq(late.NameFrame:GetAlpha(), 0, "the rows' pass ran again after them")
-- Waiting for both: the window's animation alone, then the rows' alone.
local function stopRows() WoW.asBlizzard(function() for _, r in ipairs(WoW.lootPool) do r.ShowAnim:Stop() end end) end
local function stopWindow() WoW.asBlizzard(function() LF.ShowAnim:Stop() end) end
-- Each from scratch: the skin off and on (fresh, unfaded), nothing waiting,
-- then one open whose fades the animations' end undoes.
local function fresh(rowKinds)
    WoW.closeLoot()
    WoW.lootAnimsDone()
    WoW.flushTimers(0)
    GUI._test.slash("skin loot off")
    WoW.lootRows = rowKinds
    WoW.loot()
    GUI._test.slash("skin loot on")
end
fresh({ "item", "money" })
WoW.flushTimers(0)
stopRows()
WoW.flushTimers(0)
WoW.lootAnimsDone()
WoW.flushTimers(0)
eq(LF.NineSlice:GetAlpha(), 0, "the rows done, the window's still playing: waited for it")
fresh({ "money", "item" })
WoW.flushTimers(0)
stopWindow()
WoW.flushTimers(0)
WoW.lootAnimsDone()
WoW.flushTimers(0)
eq(WoW.lootPool[1].NameFrame:GetAlpha(), 0, "the window done, a row's still playing: waited for it")
WoW.closeLoot()
WoW.lootRows = { "item", "item", "money", "base" }
WoW.loot()
WoW.flushTimers(0)
WoW.lootAnimsDone()
WoW.flushTimers(0)
-- No animation playing: no second pass is queued.
WoW.flushTimers(0)
local queued = #WoW.timers
WoW.asBlizzard(function() LF.ScrollBox:Update() end)
WoW.flushTimers(0)
eq(#WoW.timers, queued, "no animation: nothing waits")
-- The skin off while a pass waits for the animations: it's dropped.
WoW.closeLoot()
WoW.loot()
WoW.flushTimers(0)
GUI._test.slash("skin loot off")
WoW.asBlizzard(function()
    LF.ShowAnim:Stop()
    for _, r in ipairs(WoW.lootPool) do r.ShowAnim:Stop() end
end)
WoW.lootSnapshot = nil
WoW.flushTimers(0)
eq(LF.NineSlice:GetAlpha(), 1, "off while waiting: the pass is dropped")
GUI._test.slash("skin loot on")
WoW.flushTimers(0)
eq(LF.NineSlice:GetAlpha(), 0, "on: faded")
WoW.closeLoot()
-- A second loot: new rows through the list's Update, styled a frame later, not inside it.
WoW.lootRows = { "money", "item", "item", "item", "item" }
WoW.combat = true
WoW.loot()
local fresh = WoW.lootPool[1]
eq(L.rows[fresh], nil, "inside the list's Update: nothing styled")
WoW.flushTimers(0)
WoW.combat = false
for _, r in ipairs(WoW.lootPool) do
    if r:IsShown() then
        check(L.rows[r] ~= nil and r.NameFrame:GetAlpha() == 0, "every row a frame later")
        eq(#ours(r), 1, "one glass per pooled row")
    end
end

-- The history: its shell, its rows' glass under the roll-100 effect.
WoW.lootHistory(true)
WoW.flushTimers(0)
local hh = L.wins[HF]
check(hh ~= nil, "the history built at its show")
eq(HF.NineSlice:GetAlpha(), 0, "its NineSlice faded")
eq(HF.Bg:GetAlpha(), 0, "its Bg faded")
eq(HF.NineSlice.Center:GetAlpha(), 0, "its NineSlice's pieces too")
eq(HF.Bg.BottomEdge:GetAlpha(), 0, "and its Bg's")
check(hh.closeX ~= nil, "its close button")
for _, k in ipairs({ "Background", "Fill", "Border" }) do eq(HF.Timer[k]:GetAlpha(), 1, "the timer's " .. k .. " Blizzard's") end
eq(HF.ResizeButton._regions[1]:GetAlpha(), 1, "the resize handle Blizzard's")
eq(HF.NoInfoString:GetAlpha(), 1, "the empty text Blizzard's")
eq(HF.EncounterDropdown:GetAlpha(), 1, "the dropdown Blizzard's")
local glassOn
for _, p in ipairs(hh.win:GetParent() == HF and { hh.win } or {}) do glassOn = p end
check(glassOn ~= nil, "the window glass on the history (anchored to it: it follows a resize)")
local drops = shown(WoW.historyPool, "drop")
eq(#drops, 2, "two drops")
for _, r in ipairs(drops) do
    local s = L.rows[r]
    check(s ~= nil, "a drop on glass")
    eq(s.glass:GetFrameLevel(), r.BackgroundArtFrame:GetFrameLevel() - 1, "at the art's level - 1 (399)")
    check(s.glass:GetFrameLevel() < 450, "under the roll-100 effect")
    eq(s.g.top:GetFrameLevel(), s.glass:GetFrameLevel(), "its rim lowered")
    eq(r.BackgroundArtFrame.NameFrame:GetAlpha(), 0, "its plate faded")
    eq(r.BackgroundArtFrame.BorderFrame:GetAlpha(), 0, "its edge faded")
    eq(r.ItemName:GetAlpha(), 1, "its name Blizzard's")
    eq(r.Item.IconBorder:GetAlpha(), 1, "its quality border Blizzard's")
end
for _, kind in ipairs({ "header", "pad" }) do
    local r = shown(WoW.historyPool, kind)[1]
    eq(L.rows[r], nil, kind .. ": nothing")
    eq(#ours(r), 0, kind .. ": nothing of ours")
end
eq(L.rows[HF.PerfectAnimFrame], nil, "the roll-100 frame untouched (outside the list)")
eq(HF.PerfectAnimFrame.BackgroundArtFrame.NameFrame:GetAlpha(), 1, "its art Blizzard's")
-- New drops through an Update: a frame later.
WoW.historyRows = { "drop", "drop", "drop" }
WoW.asBlizzard(function() HF.ScrollBox:Update() end)
eq(L.rows[WoW.historyPool[2]], nil, "inside the history's Update: nothing styled")
WoW.flushTimers(0)
check(L.rows[WoW.historyPool[2]] ~= nil, "a frame later: styled")

-- Off: Blizzard's look; a pass queued before the switch dropped; an Update while off styles nothing.
WoW.loot()
GUI._test.slash("skin loot off")
WoW.flushTimers(0)
eq(LF.NineSlice:GetAlpha(), 1, "off: the NineSlice back")
eq(LF.NineSlice.TopEdge:GetAlpha(), 1, "its pieces back")
eq(LF.Bg.TopSection:GetAlpha(), 1, "the Bg's pieces back")
local r1 = shown(WoW.lootPool, "item")[1]
eq(r1.NameFrame:GetAlpha(), 1, "the plates back")
eq(r1.Item._normal:GetAlpha(), 1, "the slots back")
check(not r1.HighlightNameFrame._desat, "the strokes gold again")
check(not L.rows[r1].glass:IsShown(), "our glass hidden")
eq(HF.NineSlice:GetAlpha(), 0, "the history stays on: its own switch")
WoW.lootRows = { "item", "money", "money" }
WoW.loot()
WoW.flushTimers(0)
eq(WoW.lootPool[2].NameFrame:GetAlpha(), 1, "off: a new row isn't styled")
GUI._test.slash("skin loot on")
WoW.flushTimers(0)
eq(LF.NineSlice:GetAlpha(), 0, "on: faded again")
eq(WoW.lootPool[2].NameFrame:GetAlpha(), 0, "the rows again, without a Blizzard Update")
GUI._test.slash("skin loothistory off")
eq(HF.NineSlice:GetAlpha(), 1, "the history off")
eq(drops[1].BackgroundArtFrame.NameFrame:GetAlpha(), 1, "its plates back")
GUI._test.slash("skin loothistory on")
WoW.flushTimers(0)
eq(drops[1].BackgroundArtFrame.NameFrame:GetAlpha(), 0, "on again")

eq(next(GUI.failures), nil, "no failures")
for k, v in pairs(GUI.failures) do io.write("    " .. k .. ": " .. v .. "\n") end
done("test_loot")
