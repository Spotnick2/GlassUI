-- The skin contract (docs/PLAN.md, "The skin contract"): on Blizzard's
-- objects, only C widget methods from the allowlist, a texture argument that
-- is nil (or a value read back from that texture), no Lua (mixin) method, no
-- field written, and every frame we make unnamed.
--
-- Over a whole session, not just the first pass: install, style, every hook
-- callback, a deferred pass and a combat wait, a failure, the switches off and
-- on, the master switch and every theme. A regression guard, not proof of
-- taint safety: that's each skin's in-game acceptance (docs/PLAN.md).
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

-- CLAUDE.md, "The skin contract". Getters (Get*, Is*) too.
local ALLOWED = { SetAlpha = true, SetVertexColor = true, SetDesaturated = true, SetShadowOffset = true,
                  SetShadowColor = true, SetTexture = true, SetAtlas = true, HookScript = true }

-- A skin that fails halfway through touching the merchant, and a protected
-- one on it: their callbacks run on Blizzard's objects too.
local GUI = loadAddon({ before = function()
    local E = GlassUI.Engine
    E.Register({ key = "failing", title = "failing", live = true, frames = function() return MerchantFrame end,
                 style = function(kit, f) kit:Fade(f.CloseButton); error("halfway") end })
    E.Register({ key = "held", title = "held", live = false, risk = "protected",
                 frames = function() return MerchantFrame end,
                 style = function(kit, f) kit:Blank(MerchantItem1.SlotTexture); kit:Shade(MerchantItem1.Name) end })
end })

-- The session.
WoW.combat = true
WoW.showMerchant()
WoW.flushTimers(0)
WoW.combat = false
WoW.fire("PLAYER_REGEN_ENABLED")
WoW.merchantTab(2)
WoW.asBlizzard(function() MerchantFrame.Bg:SetAlpha(0.5) end)
WoW.merchantTab(1)
WoW.hideMerchant()
WoW.showMerchant()
WoW.flushTimers(0)
for _, cmd in ipairs({ "skin merchant off", "skin merchant on", "off", "on", "theme smoked", "theme class",
                       "theme clear", "skins", "skin held off" }) do
    GUI._test.slash(cmd)
end
WoW.flushTimers(0)
WoW.hideMerchant()
WoW.showMerchant()
WoW.loadAddOn("SomeAddOn")

-- The record is live: the session did call into Blizzard's objects.
check((WoW.blizzCalls.SetAlpha or 0) > 0 and (WoW.blizzCalls.HookScript or 0) > 0,
      "the session called Blizzard objects (the record works)")
check((WoW.blizzCalls.SetTexture or 0) > 0, "and blanked a texture (the argument rule is exercised)")
for name in pairs(WoW.blizzCalls) do
    check(ALLOWED[name] or name:match("^Get") or name:match("^Is"), "C method on the allowlist: " .. name)
end
for _, a in ipairs(WoW.textureArgs) do
    check(a[3] == nil, a[2] .. " on a Blizzard texture with nil only (got " .. tostring(a[3]) .. ")")
end
eq(#WoW.luaCalls, 0, "no Lua method of Blizzard's called (" .. table.concat(WoW.luaCalls, ", ") .. ")")
local changes = WoW.fieldChanges()
eq(#changes, 0, "no field written on a Blizzard object (" .. table.concat(changes, ", ") .. ")")
check(GUI.failures["skin:failing:style"], "the failing skin did fail (the failure path ran)")

-- Our frames are unnamed.
local named = {}
for _, w in ipairs(WoW.frames) do
    if w._name then named[#named + 1] = w._name end
end
eq(#named, 0, "every frame the addon made is unnamed (" .. table.concat(named, ", ") .. ")")

-- The guard catches what it guards: a write, a Lua call and a texture made up
-- by addon code.
MerchantFrame.NineSlice.glassy = true
MerchantFrame.selectedTab = 2
MerchantFrame:UpdateMerchant()
MerchantFrame.Bg:SetTexture("Interface\\Buttons\\WHITE8X8")
local caught = table.concat(WoW.fieldChanges(), ",")
check(caught:find("glassy", 1, true) and caught:find("selectedTab", 1, true), "the guard sees new and changed fields")
eq(WoW.luaCalls[1], "UpdateMerchant", "the guard sees a Lua method call")
eq(WoW.textureArgs[#WoW.textureArgs][3], "Interface\\Buttons\\WHITE8X8", "the guard sees a texture argument")

done("test_contract")
