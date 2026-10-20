-- The guild skin (#92, docs/GUILD.md): the window pieces, the panes on our
-- own hosts (each hides with its section, no hook on Blizzard's), the roster
-- left alone but for its inset's alpha, the side tabs mirroring each one's
-- checked state, and the tenant API: GuildSpy's tab and panel, their life
-- cycle (accepted is not styled; onSkin false, true once applied, false once
-- when it ends: off, master off, a handover), failures kept to their owner.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local GUI = loadAddon()
local Engine = GUI.Engine
local G = GUI.Guild._test
local CF = CommunitiesFrame
local Suite = GUI.Suite

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
local function shownSection(sec) return sec ~= nil and sec.fill:IsVisible() end
local gold = Suite.ACCENTS.gold
local function rimOf(tab) return G.tabs[tab].g.rim._vertex end

-- A tenant registered before the window first opens (GuildSpy at AttachGuild).
local early = CreateFrame("CheckButton", nil, CF, "RightSideTabTemplate")
eq(Suite.SkinTab("GuildSpy", early), true, "a tenant tab accepted before install")
local calls = {}
local host = CreateFrame("Frame", nil, CF)
host:SetFrameLevel(1300)
eq(Suite.SkinPanel("GuildSpy", host, function(on, look) calls[#calls + 1] = { on = on, look = look } end), true,
   "a tenant panel accepted before install")
eq(#calls, 1, "told at once")
eq(calls[1].on, false, "not applied yet: onSkin(false)")
check(type(calls[1].look) == "table" and type(calls[1].look.backing) == "table", "with the floor's colour")
eq(#ours(early), 0, "nothing built on the tenant's tab before install")

eq(Engine.Status("guild"), "on", "the guild skin is on by default")
WoW.combat = true
WoW.showGuild()
WoW.guildMode("CHAT")
WoW.flushTimers(0)
WoW.combat = false
local h = G.wins[CF]
check(h ~= nil, "the window's pieces built at the first show (in combat)")

-- The shell, the floor, the header, the disc, the close button.
eq(CF.NineSlice:GetAlpha(), 0, "the NineSlice faded")
eq(CF.Bg:GetAlpha(), 0, "the Bg faded")
eq(CF.TopTileStreaks:GetAlpha(), 0, "the streaks faded")
eq(CF.Inset.Bg:GetAlpha(), 0, "the window's inset faded")
eq(h.backing._color[4], GUI.Theme.WINDOW_BACKING, "the window floor")
check(h.header and h.header:IsShown(), "the smoky header")
at(h.header, "BOTTOM", CF.CommunitiesList, "TOP", 0, 0, "down to the community list's top")
local disc = h.disc
check(disc ~= nil, "the portrait's disc")
eq(disc:GetParent(), CF.PortraitOverlay, "on PortraitOverlay (hides with it when minimized)")
eq(disc:GetFrameLevel(), CF.PortraitOverlay:GetFrameLevel() - 1, "under it")
at(disc, "CENTER", CF.PortraitOverlay.CircleMask, "CENTER", 0, 0, "round its mask")
eq(CF.PortraitOverlay.TabardEmblem:GetAlpha(), 1, "the tabard stays")
check(h.closeDisc ~= nil and h.closeX ~= nil, "the close button's disc and X")
eq(CF.CloseButton._normal:GetAlpha(), 0, "its red art faded")
local mx = CF.MaximizeMinimizeFrame.MinimizeButton._normal
eq(mx._desat, true, "the minimize button desaturated")
check(mx._vertex and mx._vertex[1] == G.MAXMIN_TINT[1], "tinted neutral")
eq(CF.TitleContainer.TitleText:GetAlpha(), 1, "the title Blizzard's")

-- The panes: our hosts parented to each section.
local L = CF.CommunitiesList
for _, k in ipairs({ "Bg", "TopFiligree", "BottomFiligree", "FilligreeOverlay" }) do
    eq(L[k]:GetAlpha(), 0, "the list's " .. k .. " faded")
end
eq(L.InsetFrame.Bg:GetAlpha(), 0, "its inset faded")
eq(h.list.fill:GetParent():GetParent(), L, "the list's pane on our host in the list")
eq(h.chat.fill:GetParent():GetParent(), CF.Chat, "the chat's in the chat")
eq(h.roster.fill:GetParent():GetParent(), CF.MemberList, "the roster's in the roster")
eq(h.edit.fill:GetParent():GetParent(), CF.ChatEditBox, "the edit box's in the box itself")
eq(h.edit.fill:GetParent():GetFrameLevel(), CF.ChatEditBox:GetFrameLevel() - 1, "one under the box")
eq(h.roster.fill:GetParent():GetFrameLevel(), CF.MemberList:GetFrameLevel(), "the roster's at its level")
for _, k in ipairs({ "Left", "Right", "Mid" }) do eq(CF.ChatEditBox[k]:GetAlpha(), 0, "the edit box's " .. k .. " faded") end
eq(CF.Chat.InsetFrame.Bg:GetAlpha(), 0, "the chat's inset faded")
eq(CF.MemberList.InsetFrame:GetAlpha(), 0, "the roster's inset: its alpha only")
check(shownSection(h.list) and shownSection(h.chat) and shownSection(h.edit) and shownSection(h.roster), "chat mode: four panes")
WoW.guildMode("ROSTER")
check(shownSection(h.roster) and shownSection(h.list), "roster mode: the list and roster panes")
check(not shownSection(h.chat) and not shownSection(h.edit), "the chat's and the edit box's hide with them")
WoW.guildMode("GUILD_INFO")
check(not shownSection(h.roster), "info: the roster's pane gone with it")
WoW.guildMode("MINIMIZED")
check(shownSection(h.chat) and shownSection(h.edit), "minimized: the chat and the box")
check(not disc:IsVisible(), "the portrait's disc hides with PortraitOverlay")
WoW.guildMode("CHAT")

-- The roster's rule: no script hook on any roster frame; no anchor or size of ours.
eq(#WoW.rosterHooks, 0, "no HookScript on the roster, its ColumnDisplay, inset or rows")
eq(#CF.MemberList._points, 0, "the roster not anchored by us")
eq(CF.MemberList.ColumnDisplay:GetAlpha(), 1, "the ColumnDisplay untouched")

-- The buttons.
for _, b in ipairs({ CF.InviteButton, CF.GuildLogButton, CF.CommunitiesControlFrame.GuildControlButton }) do
    eq(b.Left:GetAlpha(), 0, "a panel button's pieces faded")
    check(ours(b)[1] ~= nil, "and its glass")
end

-- The side tabs: Blizzard's five and the early tenant.
local chat, rosterTab = CF.ChatTab, CF.RosterTab
for _, t in ipairs({ chat, rosterTab, early }) do
    check(G.tabs[t] ~= nil, "a tab's glass")
    eq(G.tabs[t].glass:GetParent(), t, "parented to the tab: it moves and hides with it")
    eq(t._checkedTex:GetAlpha(), 0, "its checked glow faded")
end
eq(chat._regions[1]:GetAlpha(), 0, "the tab's BORDER frame faded")
eq(chat.Icon:GetAlpha(), 1, "its icon stays")
eq(early._regions[1] and early._regions[1]:GetAlpha() or 0, 0, "the tenant tab's frame too")
check(G.tabs[chat].light:IsShown(), "chat mode: the chat tab lit")
check(rimOf(chat)[2] == gold[2] and rimOf(chat)[3] == gold[3] and rimOf(chat)[4] == 1, "its rim in the accent, full")
check(not G.tabs[rosterTab].light:IsShown() and rimOf(rosterTab)[2] == 1, "the roster tab: built rim")
-- A click: the native toggle, no SetChecked.
WoW.clickTab(rosterTab)
check(G.tabs[rosterTab].light:IsShown(), "a click's toggle followed (OnClick)")
WoW.guildMode("ROSTER")
check(G.tabs[rosterTab].light:IsShown() and not G.tabs[chat].light:IsShown(), "the mode's update followed (SetChecked)")
check(rimOf(chat)[2] == 1 and rimOf(chat)[3] == 1, "the chat tab's rim back to the built white once unselected (gold's red is 1 too: green and blue tell)")
-- GuildSpy opens its tab: its SetChecked(false) on Blizzard's, and Blizzard's re-check before its timer.
WoW.clickTab(early)
WoW.asBlizzard(function() for _, n in ipairs({ "ChatTab", "RosterTab" }) do CF[n]:SetChecked(false) end end)
check(G.tabs[early].light:IsShown() and not G.tabs[rosterTab].light:IsShown(), "the tenant's tab alone")
WoW.asBlizzard(function() CF.RosterTab:SetChecked(true) end)
check(G.tabs[early].light:IsShown() and G.tabs[rosterTab].light:IsShown(), "Blizzard's re-check: both shown, as both are checked (mirrored)")
WoW.asBlizzard(function() CF.RosterTab:SetChecked(false) end)
check(not G.tabs[rosterTab].light:IsShown(), "GuildSpy's timer clears it: settled")
eq(early._checked, true, "and we never wrote a checked state")
-- A Shift-click on the chat tab: a toggle without a mode change.
WoW.clickTab(chat)
check(G.tabs[chat].light:IsShown() == chat:GetChecked(), "a shift-click's toggle mirrored")
WoW.guildMode("CHAT")

-- A tenant tab registered after install: styled at once.
local late = CreateFrame("CheckButton", nil, CF, "RightSideTabTemplate")
eq(Suite.SkinTab("GuildSpy", late), true, "a late tab accepted")
check(G.tabs[late] ~= nil and G.tabs[late].glass:IsShown(), "and given its glass")
-- Refused.
eq(Suite.SkinTab("", late), false, "an empty owner refused")
eq(Suite.SkinTab("GuildSpy", CreateFrame("Button", nil, CF)), false, "not a CheckButton: refused")
eq(Suite.SkinTab("GuildSpy", CreateFrame("CheckButton", nil, UIParent)), false, "not in CommunitiesFrame: refused")
eq(Suite.SkinPanel("GuildSpy", host, "nope"), false, "an onSkin that isn't a function: refused")
eq(Suite.SkinPanel(nil, host), false, "no owner: refused")

-- The tenant panel: applied at install, glass at host level + 1, onSkin(true) once.
eq(#calls, 2, "onSkin once more")
eq(calls[2].on, true, "applied: onSkin(true)")
local pg = ours(host)[1]
check(pg ~= nil, "our glass in the tenant's host")
eq(pg:GetFrameLevel(), 1301, "at the host's level + 1 (its content at + 2 is the tenant's)")
local function backingOf(f)
    for _, r in ipairs(f._regions) do if r._layer == "BACKGROUND" and r._sub == -7 then return r end end
end
eq(backingOf(pg), nil, "no backing: the tenant's opaque base stays its own")
WoW.hideGuild(); WoW.showGuild()
eq(#calls, 2, "a re-show: no second onSkin(true)")

-- Off: Blizzard's look, the tenant told once; a mode change meanwhile; on: back.
GUI._test.slash("skin guild off")
eq(CF.NineSlice:GetAlpha(), 1, "off: the shell back")
eq(chat._checkedTex:GetAlpha(), 1, "the tabs' glow back")
eq(early._checkedTex:GetAlpha(), 1, "the tenant tab's too")
check(not G.tabs[early].glass:IsShown(), "our tab glass hidden")
eq(#calls, 3, "the tenant told")
eq(calls[3].on, false, "onSkin(false) once")
check(not pg:IsShown(), "its glass hidden")
GUI._test.slash("skin guild off")
eq(#calls, 3, "off again: no second false")
WoW.guildMode("ROSTER")
check(not G.tabs[rosterTab].light:IsShown(), "off: a mode change lights nothing (its hooks are no-ops)")
-- A panel registered while off: accepted, told false, nothing built until on.
local offc = {}
local hostOff = CreateFrame("Frame", nil, CF)
hostOff:SetFrameLevel(1300)
eq(Suite.SkinPanel("GuildSpy", hostOff, function(on) offc[#offc + 1] = on end), true, "accepted while off")
eq(offc[1], false, "told false")
eq(#ours(hostOff), 0, "nothing built while off")
GUI._test.slash("skin guild on")
eq(CF.NineSlice:GetAlpha(), 0, "on: faded again")
check(G.tabs[rosterTab].light:IsShown() and not G.tabs[chat].light:IsShown(), "the tabs read again")
eq(#calls, 4, "the tenant told")
eq(calls[4].on, true, "onSkin(true) again")
eq(offc[2], true, "the panel registered while off applied now")
-- The master switch.
GUI._test.slash("off")
eq(calls[5] and calls[5].on, false, "master off: onSkin(false)")
GUI._test.slash("on")
eq(calls[6] and calls[6].on, true, "master on: onSkin(true)")
-- The accent: the selected rim follows.
GUI._test.slash("look accent ice")
check(rimOf(rosterTab)[2] == Suite.ACCENTS.ice[2], "the selected rim in ice")
GUI._test.slash("look accent gold")
-- A throwing onSkin: recorded under its owner, the skin unharmed.
local bad = CreateFrame("Frame", nil, CF)
bad:SetFrameLevel(1300)
eq(Suite.SkinPanel("Thrower", bad, function(on) if on then error("boom") end end), true, "accepted")
check(GUI.failures["tenant:Thrower:onSkin"] ~= nil, "its failure recorded under its owner")
eq(Engine.Status("guild"), "on", "the guild skin unharmed")
GUI.failures["tenant:Thrower:onSkin"] = nil

eq(next(GUI.failures), nil, "no failures")
for k, v in pairs(GUI.failures) do io.write("    " .. k .. ": " .. v .. "\n") end

-- A handover: an owner loaded late; the tenant told false once, nothing restored over the owner.
GUI = loadAddon()
local hc = {}
local host2 = CreateFrame("Frame", nil, CommunitiesFrame)
host2:SetFrameLevel(1300)
GUI.Suite.SkinPanel("GuildSpy", host2, function(on) hc[#hc + 1] = on end)
WoW.showGuild()
eq(hc[#hc], true, "applied")
local def = GUI.Engine.byKey.guild.def
def.owners = { "SomeGuildAddon" }
WoW.loaded.SomeGuildAddon = true
eq(GUI.Engine.Active("guild"), false, "a late owner: we step aside")
eq(hc[#hc], false, "the tenant told false (the engine's restored hook, after HidePanels)")
eq(CommunitiesFrame.NineSlice:GetAlpha(), 0, "nothing of Blizzard's restored over the new owner")

-- Stood down for the session (the gamepad): accepted, nothing installed, false told.
GUI = loadAddon({ before = function() WoW.style = 1 end })
local gc = {}
local host3 = CreateFrame("Frame", nil, CommunitiesFrame)
eq(GUI.Suite.SkinPanel("GuildSpy", host3, function(on) gc[#gc + 1] = on end), true, "accepted while stood down")
eq(gc[1], false, "told false")
WoW.showGuild()
eq(#ours(host3), 0, "nothing built in the tenant's host")
eq(#gc, 1, "and never told true")

done("test_guild")
