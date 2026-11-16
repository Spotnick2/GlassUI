-- Skin/Guild.lua: Guild & Communities (#92, docs/GUILD.md), from the window
-- template (merchant #86, bags #88, game menu #90) and the owner's mockup; and
-- the tenants GuildSpy hands over (Suite.SkinTab, Suite.SkinPanel).
--
-- CommunitiesFrame (Blizzard_Communities, ButtonFrameTemplateMinimizable,
-- wow-ui-source forever 70450). The member roster is taint-sensitive
-- (Ellesmere v9.8.6 WindowPacks, "NEVER HookScript the secure ColumnDisplay"
-- and "NEVER re-anchor or resize the roster", ~3214-3226): no script hook on
-- any roster frame, nothing on its ColumnDisplay, no walking its rows, no
-- anchor or size. Its inset gets an alpha only. Our panes sit on host frames of ours parented to
-- each Blizzard section, so they show and hide with it, with no hook.
--
-- The window glass with the floor, a smoky header band, the portrait's disc
-- (on PortraitOverlay, not the template's container), the close button; the
-- community list, the chat, the edit box and the roster as recessed panes;
-- the side tabs on small glass, the selected one lighter with its rim in the
-- accent, mirroring each tab's own checked state (never written); the
-- maximize/minimize buttons tinted neutral; the Invite, control and log
-- buttons on small glass.

local GUI = GlassUI
local API = GUI.API
local Kit = GUI.Kit

local TABS = { "ChatTab", "RosterTab", "GuildBenefitsTab", "GuildInfoTab", "GuildPreferredPlaySettingsTab" }
-- The community list's art (CommunitiesList.xml:136-247).
local LIST_ART = { "Bg", "TopFiligree", "BottomFiligree", "FilligreeOverlay" }
-- A side tab's glass round its 32 px button (the kit's side tabs, #94).
local TAB_INSETS = { -2, -2, -2, -2 }
-- The portrait's disc, round PortraitOverlay's mask (CommunitiesFrame.xml:309-325).
local DISC_RING, MASK_WIDTH = 6, 58
-- A UIPanelButtonTemplate's three pieces.
local BUTTON_ART = { "Left", "Middle", "Right" }
local EDIT_ART = { "Left", "Right", "Mid" }
-- The maximize/minimize buttons' state textures, tinted neutral (the quest
-- tracker's minimize buttons): not red.
local MAXMIN_ART = { "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }
local MAXMIN_TINT = { 0.85, 0.85, 0.85 }

local wins = setmetatable({}, { __mode = "k" })     -- the window -> our pieces

local function tbl(v) return type(v) == "table" and v or nil end

-- The skin's kit (one per skin), once installed.
local theKit

-- A button's own region of a type on a layer (a side tab's BORDER frame).
local function regionOn(b, kind, layer)
    local ok, regions = pcall(function() return { b:GetRegions() } end)
    if not ok then return nil end
    for _, r in ipairs(regions) do
        local okT, t = pcall(r.GetObjectType, r)
        local okL, l = pcall(r.GetDrawLayer, r)
        if okT and okL and API.Plain(t) == kind and API.Plain(l) == layer then return r end
    end
    return nil
end

-- The guild's side tabs (Blizzard's five and the tenants'): CheckButtons, the
-- selection their own GetChecked; a click's native toggle as well as
-- SetChecked followed; their BORDER frame and checked glow faded.
local SIDE_TAB = {
    insets = TAB_INSETS,
    selected = function(tab) return tab:GetChecked() end,
    methods = { "SetChecked" },
    scripts = { "OnClick" },
    art = function(tab)
        local ok, checked = pcall(tab.GetCheckedTexture, tab)
        return { regionOn(tab, "Texture", "BORDER"), ok and tbl(checked) or nil }
    end,
}

-- A recessed pane on a host frame of ours parented to `parent` (so it shows
-- and hides with it), anchored to `anchor`, at `level`.
local function pane(kit, parent, anchor, level)
    if not (parent and anchor) then return nil end
    local host = kit:Adopt(CreateFrame("Frame", nil, parent))
    host:SetAllPoints(anchor)
    host:SetFrameLevel(math.max(0, level))
    local sec = kit:Section(host)
    sec.fill:SetAllPoints(host)
    Kit.ShowSection(sec, true)
    return sec
end

local function buttonGlass(kit, b)
    if not b then return end
    local glass, g = kit:Panel(b, "small", { 0, 0, 0, 0 })
    if g and g.top then g.top:SetFrameLevel(glass:GetFrameLevel()) end
end

-- The window floor's colour, for a tenant's opaque base.
local function look()
    local r, g, b = GUI.Theme.Backing("window")
    return { backing = { r, g, b } }
end

-- A tenant's onSkin, under pcall, its failure under its owner.
local function tellPanel(host, p, on)
    p.applied = on
    if not p.onSkin then return end
    local ok, err = pcall(p.onSkin, on, look())
    if not ok then API.Fail("tenant:" .. p.owner .. ":onSkin", err) end
end

-- A tenant's panel: our glass at the host's level + 1 (its content at + 2
-- or more is the tenant's), its rim there too, no backing; then onSkin(true).
local function applyPanel(kit, host, p)
    if not p.glass then
        local glass, g = kit:Panel(host, "large", nil, nil, { backing = false })
        local level = host:GetFrameLevel() + 1
        glass:SetFrameLevel(level)
        if g and g.top then g.top:SetFrameLevel(level) end
        p.glass = glass
    end
    p.glass:Show()
    if not p.applied then tellPanel(host, p, true) end
end

-- A tint, an accent or a floor changed (Theme.Refresh): each applied tenant
-- panel hears onSkin(true) again with the fresh backing (#96: a repaint; the
-- owner's onSkin is idempotent, docs/SUITE.md). Off, nothing is applied.
GUI.Theme.OnRefresh(function()
    if not GUI.Engine.Active("guild") then return end
    for host, p in pairs(GUI.Tenants.panels) do
        if p.applied then tellPanel(host, p, true) end
    end
end)

-- Handed over by Suite.SkinTab / SkinPanel: applied now if the skin is
-- installed and on; a panel not applied hears onSkin(false) at once.
local tenants = GUI.Tenants
tenants.listener = function(kind, frame)
    local active = GUI.Engine.Active("guild") and theKit ~= nil
    if kind == "tab" then
        if active then
            GUI.Engine.Run(theKit.skin, "tenant tab", function()
                theKit:SideTab(frame, SIDE_TAB)
                theKit:StyleSideTab(frame)
                Kit.SyncSideTabs(theKit)
            end)
        end
    elseif kind == "panel" then
        local p = tenants.panels[frame]
        if active then
            GUI.Engine.Run(theKit.skin, "tenant panel", applyPanel, theKit, frame, p)
        end
        if not p.applied then tellPanel(frame, p, false) end
    end
end

GUI.Engine.Register({
    key = "guild",
    title = "Guild & Communities",
    risk = "plain",
    live = true,
    backing = "window",
    frames = function() return rawget(_G, "CommunitiesFrame") end,
    install = function(kit, frame)
        theKit = kit
        local win, wg, backing = kit:Panel(frame)
        local h = { kit = kit, frame = frame }
        wins[frame] = h
        local list = tbl(frame.CommunitiesList)
        kit:Header(win, wg, backing, list or win, "TOP", list and 0 or -60, h)
        local overlay = tbl(frame.PortraitOverlay)
        local mask = overlay and (tbl(overlay.CircleMask) or tbl(overlay.Portrait))
        if mask then
            h.disc = kit:Disc(overlay, mask, { ring = DISC_RING, width = MASK_WIDTH,
                                               level = overlay:GetFrameLevel() - 1 })
        end
        kit:CloseButton(tbl(frame.CloseButton), h)
        -- The panes, each at its section's level (under its rows and messages).
        local chat, roster = tbl(frame.Chat), tbl(frame.MemberList)
        h.list = list and pane(kit, list, tbl(list.InsetFrame) or list, list:GetFrameLevel())
        h.chat = chat and pane(kit, chat, tbl(chat.InsetFrame) or chat, chat:GetFrameLevel())
        h.roster = roster and pane(kit, roster, tbl(roster.InsetFrame) or roster, roster:GetFrameLevel())
        local edit = tbl(frame.ChatEditBox)
        h.edit = edit and pane(kit, edit, edit, edit:GetFrameLevel() - 1)
        for _, key in ipairs(TABS) do
            local tab = tbl(frame[key])
            if tab then kit:SideTab(tab, SIDE_TAB) end
        end
        for tab in pairs(tenants.tabs) do kit:SideTab(tab, SIDE_TAB) end
        local control = tbl(frame.CommunitiesControlFrame)
        buttonGlass(kit, tbl(frame.InviteButton))
        buttonGlass(kit, tbl(frame.GuildLogButton))
        if control then
            buttonGlass(kit, tbl(control.GuildControlButton))
            buttonGlass(kit, tbl(control.GuildRecruitmentButton))
        end
    end,
    style = function(kit, frame)
        kit:Shell(frame)
        kit:CloseFades(tbl(frame.CloseButton))
        local list = tbl(frame.CommunitiesList)
        if list then
            for _, key in ipairs(LIST_ART) do kit:Fade(tbl(list[key])) end
            kit:Inset(tbl(list.InsetFrame))
        end
        local chat, roster = tbl(frame.Chat), tbl(frame.MemberList)
        if chat then kit:Inset(tbl(chat.InsetFrame)) end
        -- The roster: its inset's alpha only (no script hook, nothing else).
        if roster then kit:Fade(tbl(roster.InsetFrame)) end
        local edit = tbl(frame.ChatEditBox)
        if edit then
            for _, key in ipairs(EDIT_ART) do kit:Fade(tbl(edit[key])) end
        end
        local mm = tbl(frame.MaximizeMinimizeFrame)
        for _, key in ipairs({ "MaximizeButton", "MinimizeButton" }) do
            local b = mm and tbl(mm[key])
            if b then
                for _, get in ipairs(MAXMIN_ART) do
                    local ok, tex = pcall(b[get], b)
                    if ok then kit:Tint(tbl(tex), MAXMIN_TINT[1], MAXMIN_TINT[2], MAXMIN_TINT[3]) end
                end
            end
        end
        local control = tbl(frame.CommunitiesControlFrame)
        local buttons = { tbl(frame.InviteButton), tbl(frame.GuildLogButton),
                          control and tbl(control.GuildControlButton), control and tbl(control.GuildRecruitmentButton) }
        for i = 1, 4 do
            local b = buttons[i]
            if b then for _, key in ipairs(BUTTON_ART) do kit:Fade(tbl(b[key])) end end
        end
        for tab, st in pairs(Kit.sideTabs) do
            if st.kit == kit then kit:StyleSideTab(tab) end
        end
        Kit.SyncSideTabs(kit)
        local h = wins[frame]
        if h then
            Kit.PlaceHeader(h)
            Kit.CloseSync(h)
        end
        for host, p in pairs(tenants.panels) do applyPanel(kit, host, p) end
    end,
    -- The skin switched off, or handed over: each applied tenant panel hears
    -- onSkin(false) once (the engine calls this ungated).
    restored = function()
        for host, p in pairs(tenants.panels) do
            if p.glass then p.glass:Hide() end
            if p.applied then tellPanel(host, p, false) end
        end
    end,
})

GUI.Guild = { _test = { wins = wins, tabs = Kit.sideTabs, TAB_LIGHT = Kit.TAB_LIGHT, TAB_INSETS = TAB_INSETS,
                         DISC_RING = DISC_RING, MAXMIN_TINT = MAXMIN_TINT } }
