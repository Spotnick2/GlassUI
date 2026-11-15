-- The mirror timers (docs/MIRROR-TIMERS.md): a timer's start styles its frame
-- (its own textures faded, the fill tinted its timer's colour, a pill and a
-- track of ours under the bar); a restart while shown, a stop and another
-- timer re-tint after Setup's atlas; Edit Mode's empty frames get the glass
-- and keep Blizzard's fill; off gives everything back live, on restyles; no
-- field written.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local GUI = loadAddon()
local M = GUI.MirrorTimers._test
local C = MirrorTimerContainer
local F = C.mirrorTimers

local function near3(v, c, what)
    check(v and math.abs(v[1] - c[1]) < 1e-6 and math.abs(v[2] - c[2]) < 1e-6 and math.abs(v[3] - c[3]) < 1e-6, what)
end
local function fill(f) return f.StatusBar:GetStatusBarTexture() end
local function bg(f) return select(2, f:GetRegions()) end

eq(GUI.Engine.Status("mirror"), "on", "the timers' skin is on by default")
eq(M.pills[F[1]], nil, "nothing built before a timer shows")

-- Breath: the first frame.
WoW.mirrorStart("BREATH", "Breath")
local f = F[1]
local p = M.pills[f]
check(p ~= nil, "built at its first show")
eq(f.TextBorder:GetAlpha(), 0, "the label box faded")
eq(bg(f):GetAlpha(), 0, "the unnamed background faded (found by structure)")
eq(f.Border:GetAlpha(), 0, "the castbar border faded")
eq(f.Text:GetAlpha(), 1, "the label kept")
eq(f.StatusBar:GetAlpha(), 1, "the bar kept")
eq(fill(f):GetAlpha(), 1, "the fill kept, not faded")
check(fill(f)._desat, "the fill desaturated")
near3(fill(f)._vertex, M.COLORS.BREATH, "and in breath's colour")
eq(p.glass:GetParent(), f, "the pill is the frame's child: it shows and hides with it")
check(p.glass:GetFrameLevel() < f.StatusBar:GetFrameLevel(), "the pill under the bar")
check(p.glass:GetFrameLevel() < f:GetFrameLevel(), "and under the frame's label")
if p.g and p.g.top then eq(p.g.top:GetFrameLevel(), p.glass:GetFrameLevel(), "its rim lowered with it") end
check(p.track and p.track.fill:IsShown(), "the track shown")
local tp = p.track.fill._points[1]
check(tp and tp[2] == f.StatusBar, "the track on the bar")
local gp = p.glass._points[1]
check(gp and gp[2] == f.TextBorder, "the pill around the bar and the label box")

-- A restart while shown (no OnShow): Setup's atlas resets the fill; the hook re-tints.
WoW.mirrorStart("BREATH", "Breath")
check(fill(f)._desat, "a restart while shown: desaturated again")
near3(fill(f)._vertex, M.COLORS.BREATH, "and breath's colour again")

-- Fatigue beside it: the second frame, its own colour.
WoW.mirrorStart("EXHAUSTION", "Fatigue")
local f2 = F[2]
check(M.pills[f2] ~= nil, "the second frame built")
near3(fill(f2)._vertex, M.COLORS.EXHAUSTION, "fatigue's colour")
near3(fill(f)._vertex, M.COLORS.BREATH, "breath's kept")

-- Breath stops; feign death takes the free first frame: its colour.
WoW.mirrorStop("BREATH")
eq(f:IsShown(), false, "breath's frame hidden")
WoW.mirrorStart("FEIGNDEATH", "Feign Death")
near3(fill(f)._vertex, M.COLORS.FEIGNDEATH, "the reused frame in feign death's colour")

-- A texture object swapped by Setup: tinted too.
WoW.mirrorFill = "swap"
WoW.mirrorStart("EXHAUSTION", "Fatigue")
near3(fill(f2)._vertex, M.COLORS.EXHAUSTION, "a new fill object: tinted")
WoW.mirrorFill = "reset"

-- Edit Mode: the third frame shows without a timer: glass, no tint. Its bar
-- one level lower than the template's (a later build): the pill follows the
-- bar's actual level, not the frame's.
local f3 = F[3]
f3.StatusBar._level = f3._level - 1
WoW.mirrorEditMode(true)
check(M.pills[f3] ~= nil, "Edit Mode's empty frame on glass")
eq(f3.Border:GetAlpha(), 0, "its border faded")
check(not fill(f3)._desat, "no timer: no tint")
check(M.pills[f3].glass:GetFrameLevel() < f3.StatusBar:GetFrameLevel(), "the pill under the bar's own level")
near3(fill(f2)._vertex, M.COLORS.EXHAUSTION, "a running timer in Edit Mode keeps its colour")
-- Fatigue stops while Edit Mode keeps its frame up (an idle preview):
-- Blizzard resets nothing, so its last colour stays (docs/MIRROR-TIMERS.md).
WoW.mirrorStop("EXHAUSTION")
check(f2:IsShown(), "(the stub) Edit Mode keeps the stopped frame shown")
near3(fill(f2)._vertex, M.COLORS.EXHAUSTION, "an idle preview keeps its last timer's tint")
eq(f2.Border:GetAlpha(), 0, "and its glass")
WoW.mirrorEditMode(false)
eq(f2:IsShown(), false, "Edit Mode closed: the idle frames hidden")
WoW.mirrorStart("EXHAUSTION", "Fatigue")

-- Off: everything back, live.
GUI._test.slash("skin mirror off")
eq(GUI.Engine.Status("mirror"), "off", "off")
eq(f.Border:GetAlpha(), 1, "off: the border back")
eq(bg(f):GetAlpha(), 1, "the background back")
eq(f.TextBorder:GetAlpha(), 1, "the label box back")
check(not fill(f)._desat, "the fill's saturation back")
near3(fill(f)._vertex, { 1, 1, 1 }, "and its colour")
eq(p.glass:IsShown(), false, "the pill hidden")
eq(fill(f2)._file, WoW.MIRROR_ATLAS.EXHAUSTION, "the swapped fill keeps Blizzard's latest atlas")
check(not fill(f2)._desat, "and its saturation back")
-- A start while off: nothing of ours.
WoW.mirrorStart("BREATH", "Breath")
check(not fill(F[3])._desat and not fill(f)._desat, "a start while off: no tint")

-- On again: the shown frames restyled at once.
GUI._test.slash("skin mirror on")
WoW.flushTimers(0)
eq(f.Border:GetAlpha(), 0, "on: faded again")
near3(fill(f)._vertex, M.COLORS.FEIGNDEATH, "the fill tinted again")
eq(p.glass:IsShown(), true, "the pill shown")

-- The master switch: a restart while all skins are off, then on with it shown.
GUI._test.slash("off")
WoW.mirrorStart("FEIGNDEATH", "Feign Death")
check(not fill(f)._desat, "master off: a restart leaves Blizzard's fill")
eq(f.Border:GetAlpha(), 1, "and Blizzard's border")
GUI._test.slash("on")
WoW.flushTimers(0)
near3(fill(f)._vertex, M.COLORS.FEIGNDEATH, "master on, shown: tinted again")
eq(f.Border:GetAlpha(), 0, "and faded again")

-- Never a field on Blizzard's objects, never a Lua method of theirs.
eq(#WoW.fieldChanges(), 0, "no field written (" .. table.concat(WoW.fieldChanges(), ", ") .. ")")
eq(#WoW.luaCalls, 0, "no Lua method called (" .. table.concat(WoW.luaCalls, ", ") .. ")")
eq(next(GUI.failures), nil, "no failure recorded")

for k, v in pairs(GUI.failures) do io.write("    " .. k .. ": " .. v .. "\n") end
done("test_mirror")
