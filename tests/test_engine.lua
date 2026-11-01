-- The skin engine (docs/PLAN.md, "Tests"): Active gates every callback,
-- owners and yields, the late-owner handover, a throwing skin disabled alone,
-- load-on-demand windows, protected windows deferred and held through combat,
-- the gamepad stand-down, the suite check, and the kit's guards. Test skins on
-- plain frames; the merchant's own test is test_merchant.lua.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

-- A window and a skin that counts its passes and fades one texture.
local function window(name)
    local f = CreateFrame("Frame", name, UIParent)
    f:Hide()
    f.Art = f:CreateTexture(nil, "BACKGROUND")
    return f
end
local function skin(key, f, extra)
    local def = { key = key, title = key, live = true, frames = function() return f end, n = { install = 0, style = 0 } }
    def.install = function(kit, frame) def.n.install = def.n.install + 1; kit:Panel(frame) end
    def.style = function(kit, frame) def.n.style = def.n.style + 1; kit:Fade(frame.Art) end
    for k, v in pairs(extra or {}) do def[k] = v end
    return def
end
-- Load with these skins registered (after the files, before login).
local function session(defs, opts)
    opts = opts or {}
    local before = opts.before
    opts.before = function()
        for _, d in ipairs(defs) do GlassUI.Engine.Register(d) end
        if before then before() end
    end
    return loadAddon(opts)
end
local function said(text) return table.concat(WoW.chat, "\n"):find(text, 1, true) ~= nil end

-- Nothing runs before login; then a shown window is styled at once.
local f, d
local active
local GUI = session({}, { before = function()
    f = window("TestA")
    d = skin("a", f)
    GlassUI.Engine.Register(d)
    active = GlassUI.Engine.Active("a")
end })
eq(active, false, "inactive before PLAYER_LOGIN")
eq(d.n.install, 0, "a hidden window isn't touched at login")
f:Show()
eq(d.n.install, 1, "installed at its first OnShow")
eq(d.n.style, 1, "and styled")
f:Hide(); f:Show()
eq(d.n.install, 1, "installed once")
eq(d.n.style, 2, "styled again at every show (Blizzard may have reset a reused region)")
eq(f.Art:GetAlpha(), 0, "the kit's fade")

-- Off: the OnShow hook stays (it can't be removed) but does nothing.
GUI.Engine.SetEnabled("a", false)
f:Hide(); f:Show()
eq(d.n.style, 2, "a switched-off skin's hook does nothing")
eq(f.Art:GetAlpha(), 1, "and its fade is given back")

-- Owners: one loaded at login wins for the session.
local f2, d2 = window("TestB"), nil
d2 = skin("b", f2, { owners = { "GlassMaps" } })
GUI = session({ d2 }, { before = function() WoW.loaded.GlassMaps = true end })
f2:Show()
eq(d2.n.style, 0, "an owned window isn't styled")
eq(GUI.Engine.Status("b"), "handled by GlassMaps", "the switch says who has it")

-- A late owner (LoadAddOn mid-session): our callbacks stop, our panels hide,
-- nothing is restored over its changes.
local f3 = window("TestC")
local d3 = skin("c", f3, { owners = { "GlassMaps" } })
GUI = session({ d3 })
f3:Show()
local panel = f3._children[1]
check(panel and panel:IsShown(), "our panel is up")
WoW.loadAddOn("GlassMaps")
check(not panel:IsShown(), "a late owner: our panel hides")
eq(f3.Art:GetAlpha(), 0, "and nothing is restored over its changes")
f3.Art:SetAlpha(0.7)
eq(f3.Art:GetAlpha(), 0.7, "the new owner's alphas apply: our fade no longer holds")
check(GUI.Engine.Status("c"):find("reload to finish the handover", 1, true), "the switch says to reload")
f3:Hide(); f3:Show()
eq(d3.n.style, 1, "no more passes")
-- Rechecked at run time too, when no ADDON_LOADED was seen.
local f4 = window("TestD")
local d4 = skin("d", f4, { owners = { "SomeOwner" } })
GUI = session({ d4 })
WoW.loaded.SomeOwner = true
f4:Show()
eq(d4.n.style, 0, "an owner found when the callback runs wins")
eq(GUI.Engine.Status("d"), "handled by SomeOwner", "before anything was styled: no reload needed")

-- Yields, read once at login.
local f5, f6 = window("TestE"), window("TestF")
local d5 = skin("e", f5, { yields = { Leatrix_Maps = function() return true end } })
local d6 = skin("f", f6, { yields = { Leatrix_Maps = function() return false end } })
GUI = session({ d5, d6 }, { before = function() WoW.loaded.Leatrix_Maps = true end })
f5:Show(); f6:Show()
eq(d5.n.style, 0, "a yielding skin skips while the neighbour rebuilds the window")
check(GUI.Engine.Status("e"):find("Leatrix_Maps", 1, true), "and says why")
eq(d6.n.style, 1, "a false predicate: styled as usual")

-- A throwing skin is disabled alone.
local f7, f8 = window("TestG"), window("TestH")
local d7 = skin("g", f7, { style = function() error("boom") end })
local d8 = skin("h", f8)
GUI = session({ d7, d8 })
f7:Show(); f8:Show()
check(GUI.failures["skin:g:style"] and GUI.failures["skin:g:style"]:find("boom", 1, true), "the throw is recorded")
check(GUI.Engine.Status("g"):find("failed", 1, true), "the skin reads failed")
eq(GUI.Engine.Active("g"), false, "and is inactive for the session")
eq(d8.n.style, 1, "the other skin is unaffected")
GUI._test.slash("failures")
check(said("skin:g:style"), "/glassui failures lists it")

-- A protected skin: deferred a frame, and work queued before a switch is dropped.
local f9 = window("TestI")
local d9 = skin("i", f9, { risk = "protected" })
GUI = session({ d9 })
f9:Show()
eq(d9.n.style, 0, "a protected window is styled a frame later, not inside the show")
WoW.flushTimers(0)
eq(d9.n.style, 1, "then styled")
f9:Hide(); f9:Show()
GUI.Engine.SetEnabled("i", false)
WoW.flushTimers(0)
eq(d9.n.style, 1, "a deferred pass queued before a switch went off is dropped")
GUI.Engine.SetEnabled("i", true)
eq(d9.n.style, 1, "switching a protected skin on defers its pass too")
WoW.flushTimers(0)
eq(d9.n.style, 2, "then runs it")
f9:Hide(); f9:Show()
GUI.Engine.SetEnabled("i", false)
GUI.Engine.SetEnabled("i", true)
WoW.flushTimers(0)
eq(d9.n.style, 3, "off and on with a pass queued: only the pass queued after runs (the generation changed)")
-- First shown in combat: held until combat ends, and dropped if switched meanwhile.
local f10, f11 = window("TestJ"), window("TestK")
local d10 = skin("j", f10, { risk = "protected" })
local d11 = skin("k", f11, { risk = "protected" })
GUI = session({ d10, d11 })
WoW.combat = true
f10:Show(); f11:Show()
WoW.flushTimers(0)
eq(d10.n.install + d11.n.install, 0, "nothing installs in combat")
GUI.Engine.SetEnabled("k", false)
GUI.Engine.SetEnabled("k", true)
WoW.flushTimers(0)
WoW.combat = false
WoW.fire("PLAYER_REGEN_ENABLED")
eq(d10.n.style, 1, "combat over: a held pass runs, though another skin was switched meanwhile")
eq(d11.n.style, 1, "the switched skin runs once: its pass held before the off and on was dropped")
WoW.combat = true
local f12 = window("TestL")
WoW.combat = false
local d12 = skin("l", f12, { risk = "protected" })
GUI = session({ d12 })
WoW.combat = true
f12:Show(); WoW.flushTimers(0)
WoW.combat = false
WoW.fire("PLAYER_REGEN_ENABLED")
eq(d12.n.style, 1, "combat over: the held pass runs")

-- The master switch off and on with several windows up (Codex, PR #16): each
-- skin's change must not drop the pass just queued for the one before it.
local f20, f21, f22 = window("TestT"), window("TestU"), window("TestV")
local d20 = skin("t", f20, { risk = "protected" })
local d21 = skin("u", f21)
local d22 = skin("v", f22, { risk = "protected" })
GUI = session({ d20, d21, d22 })
f20:Show(); f21:Show(); f22:Show()
WoW.flushTimers(0)
GUI._test.slash("off")
GUI._test.slash("on")
WoW.flushTimers(0)
eq(d20.n.style, 2, "master on: the first (protected) window is styled again")
eq(d21.n.style, 2, "and the plain one")
eq(d22.n.style, 2, "and the last")
check(f20._children[1]:IsShown(), "the first window's glass is back")
-- Another skin failing doesn't drop a queued pass either.
local f23, f24 = window("TestW"), window("TestX")
local d23 = skin("w", f23, { risk = "protected" })
local d24 = skin("x", f24, { style = function() error("boom") end })
GUI = session({ d23, d24 })
f23:Show(); f24:Show()
WoW.flushTimers(0)
eq(d23.n.style, 1, "a pass queued before another skin threw still runs")

-- Load on demand: nothing until its addon loads.
local f13
local d13 = { key = "m", title = "m", live = true, addon = "Blizzard_Test", n = 0,
              frames = function() return f13 end, style = function() end }
d13.style = function() d13.n = d13.n + 1 end
GUI = session({ d13 })
eq(GUI.Engine.Status("m"), "on (Blizzard_Test not installed)", "its addon not on this client: nothing to wait for")
WoW.installed.Blizzard_Test = 2
eq(GUI.Engine.Status("m"), "on (waits for Blizzard_Test)", "waits for its addon")
f13 = window("TestM")
f13:Show()
WoW.loadAddOn("Blizzard_Test")
eq(d13.n, 1, "attached when its addon loads, and styled since the window is up")

-- Gamepad: no skin installs a hook this session.
local f14 = window("TestN")
local d14 = skin("n", f14)
GUI = session({ d14 }, { before = function() WoW.style = 1 end })
eq(f14._scripts.OnShow, nil, "the gamepad interface: no hook on any window")
f14:Show()
eq(d14.n.style, 0, "and nothing styled")
check(GUI.Engine.Status("n"):find("gamepad", 1, true), "the switch says why")
WoW.style = 0

-- A full UI suite loaded: every skin off, said once.
local f15 = window("TestO")
local d15 = skin("o", f15)
GUI = session({ d15 }, { before = function() WoW.loaded.ElvUI = true end })
f15:Show()
eq(d15.n.style, 0, "ElvUI loaded: no skin runs")
check(said("while ElvUI is loaded"), "and says so")
check(GUI.Engine.Status("o"):find("ElvUI", 1, true), "the switch says why")

-- A skin whose window doesn't exist on this build.
local d16 = { key = "p", title = "p", frames = function() return nil end, style = function() end }
GUI = session({ d16 })
check(GUI.failures["skin:p:frames"], "a missing window is recorded")

-- The kit's guards.
local f17 = window("TestQ")
local grad = f17:CreateTexture(nil, "ARTWORK")
grad:SetColorTexture(1, 1, 1, 1)
grad:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 1))
local result
local d17 = skin("q", f17, { style = function(kit) result = kit:Fade(grad) end })
local f18 = window("TestR")
local d18 = skin("r", f18, { style = function(kit, frame) kit:Shade(frame:CreateFontString()) end })
local f19 = window("TestS")
local d19 = skin("s", f19, { live = false, style = function(kit, frame)
    kit:Blank(frame.Art); kit:Tint(frame.Art, 0.5, 0.6, 0.7); kit:Shade(frame:CreateFontString())
end })
GUI = session({ d17, d18, d19 })
f17:Show(); f18:Show(); f19:Show()
eq(result, false, "a gradient texture: Fade reads the alpha back and says no")
local key
for k in pairs(GUI.failures) do if k:find("^fade:q:") then key = k end end
check(key, "and records it")
check(GUI.failures["skin:r:style"] and GUI.failures["skin:r:style"]:find("live = false", 1, true),
      "Shade on a live skin is refused")
eq(f19.Art:GetTexture(), nil, "Blank drops the image")
check(f19.Art:IsDesaturated(), "Tint desaturates")
eq(GUI.Engine.SetEnabled("s", false), "reload", "turning off a skin that isn't live asks for a /reload")
check(GUI.Engine.Status("s"):find("after a /reload", 1, true), "and says so")

-- Blank and Tint on a live skin (#55): what they changed comes back when it's
-- switched off, and they apply again when it's back on.
local f21 = window("TestU")
f21.Atlas, f21.File, f21.Button = f21:CreateTexture(), f21:CreateTexture(), f21:CreateTexture()
f21.Atlas:SetAtlas("ui-questtracker-objfx-shine")
f21.File:SetTexture(136440)
f21.Button:SetAtlas("ui-questtrackerbutton-collapse")
f21.Button:SetVertexColor(0.9, 0.2, 0.1, 0.8)
local d21 = skin("u", f21, { style = function(kit, frame)
    kit:Blank(frame.Atlas); kit:Blank(frame.File); kit:Tint(frame.Button, 0.75, 0.9, 1)
end })
GUI = session({ d21 })
f21:Show()
eq(f21.Atlas:GetAtlas(), nil, "Blank drops an atlas")
eq(f21.File:GetTexture(), nil, "and a file")
check(f21.Button:IsDesaturated(), "Tint desaturates")
local r, g = f21.Button:GetVertexColor()
near(r, 0.75, "and recolours")
f21.Button:SetAtlas("ui-questtrackerbutton-expand")   -- Blizzard swaps the art meanwhile
f21:Hide(); f21:Show()
eq(GUI.Engine.SetEnabled("u", false), nil, "a live skin with blanks and tints turns off without a /reload")
eq(f21.Atlas:GetAtlas(), "ui-questtracker-objfx-shine", "the atlas is given back")
eq(f21.File:GetTexture(), 136440, "the file too")
eq(f21.Button:IsDesaturated(), false, "the tint's desaturation is given back")
local r2, g2, b2, a2 = f21.Button:GetVertexColor()
check(r2 == 0.9 and g2 == 0.2 and b2 == 0.1 and a2 == 0.8, "and its colour, the one read before the first tint")
eq(f21.Button:GetAtlas(), "ui-questtrackerbutton-expand", "the atlas Blizzard swapped in stays")
GUI.Engine.SetEnabled("u", true)
eq(f21.Atlas:GetAtlas(), nil, "back on: blanked again")
check(f21.Button:IsDesaturated(), "and tinted again")
GUI.Engine.SetEnabled("u", false)
eq(f21.Atlas:GetAtlas(), "ui-questtracker-objfx-shine", "a second off gives back the same atlas, not the blank")
-- TextColor (#71): held like a fade, Blizzard's latest RGBA given back.
local f24 = window("TestX")
f24.Title = f24:CreateFontString()
f24.Title:SetTextColor(1, 0.82, 0, 0.9)
local want24 = { 0.65, 0.835, 0.905 }
local d24 = skin("x", f24, { style = function(kit, frame) kit:TextColor(frame.Title, want24[1], want24[2], want24[3]) end })
GUI = session({ d24 })
f24:Show()
local r24, g24, b24, a24 = f24.Title:GetTextColor()
check(r24 == 0.65 and b24 == 0.905, "the title in our colour")
eq(a24, 0.9, "with Blizzard's alpha")
f24.Title:SetTextColor(0.5, 0.5, 0.5, 1)          -- Blizzard writes its own meanwhile
eq((f24.Title:GetTextColor()), 0.65, "ours put back at once")
want24 = { 1, 0, 0 }
f24:Hide(); f24:Show()                             -- a second pass, another colour
eq((f24.Title:GetTextColor()), 1, "recoloured")
GUI.Engine.SetEnabled("x", false)
local r, g, b, a = f24.Title:GetTextColor()
check(r == 0.5 and g == 0.5 and b == 0.5 and a == 1, "off: Blizzard's latest colour back, RGBA, not the first")
f24.Title:SetTextColor(0.2, 0.3, 0.4, 1)
eq((f24.Title:GetTextColor()), 0.2, "off: Blizzard's writes stand")
GUI.Engine.SetEnabled("x", true)
eq((f24.Title:GetTextColor()), 1, "on again: ours")
GUI.Engine.SetEnabled("x", false)
eq((f24.Title:GetTextColor()), 0.2, "and off gives back the colour captured afresh")

-- Each skin gives back only its own.
local f22, f23 = window("TestV"), window("TestW")
f22.Art:SetAtlas("one"); f23.Art:SetAtlas("two")
f23.Art:SetVertexColor(0.2, 0.2, 0.2, 1)
local d22 = skin("v", f22, { style = function(kit, frame) kit:Blank(frame.Art) end })
local d23 = skin("w", f23, { style = function(kit, frame) kit:Blank(frame.Art); kit:Tint(frame.Art, 1, 0, 0) end })
GUI = session({ d22, d23 })
f22:Show(); f23:Show()
GUI.Engine.SetEnabled("v", false)
eq(f22.Art:GetAtlas(), "one", "turning one skin off gives back its blank")
eq(f23.Art:GetAtlas(), nil, "and leaves another skin's blank")
check(f23.Art:IsDesaturated(), "and its tint")

-- Fade's onAlpha (the damage meter's Background): Blizzard's latest alpha,
-- never the 0 we hold, never while off, never a secret.
local f20 = window("TestT")
local got = {}
local d20 = skin("t", f20, { style = function(kit, frame)
    kit:Fade(frame.Art, function(a) got[#got + 1] = a end)
end })
GUI = session({ d20 })
f20.Art:SetAlpha(0.4)
f20:Show()
eq(got[#got], 0.4, "at once: the alpha Blizzard had set")
local n = #got
f20:Hide(); f20:Show()
eq(#got, n + 1, "a repeated Fade tells it again")
eq(got[#got], 0.4, "the saved alpha, not the held 0")
WoW.asBlizzard(function() f20.Art:SetAlpha(0.8) end)
eq(got[#got], 0.8, "every Blizzard change")
eq(f20.Art:GetAlpha(), 0, "held at 0 meanwhile")
for _, a in ipairs(got) do check(a ~= 0, "never the kit's own 0 (" .. tostring(a) .. ")") end
n = #got
local plainCheck = issecretvalue
issecretvalue = function(v) return v == 0.3 end
WoW.asBlizzard(function() f20.Art:SetAlpha(0.3) end)
issecretvalue = plainCheck
eq(#got, n, "a secret alpha isn't passed on")
GUI.Engine.SetEnabled("t", false)
eq(f20.Art:GetAlpha(), 0.8, "off: the latest plain alpha back")
n = #got
WoW.asBlizzard(function() f20.Art:SetAlpha(0.6) end)
eq(#got, n, "nothing while the skin is off")
-- Secret already at the first Fade: nothing to pass on, and nothing fails.
local f21 = window("TestU")
local got21 = 0
local d21 = skin("u", f21, { style = function(kit, frame)
    kit:Fade(frame.Art, function() got21 = got21 + 1 end)
end })
GUI = session({ d21 })
f21.Art:SetAlpha(0.35)
issecretvalue = function(v) return v == 0.35 end
f21:Show()
issecretvalue = plainCheck
eq(got21, 0, "a secret alpha at the first Fade isn't passed on")
eq(f21.Art:GetAlpha(), 0, "the region is still faded")

done("test_engine")
