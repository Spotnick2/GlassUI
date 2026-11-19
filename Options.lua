-- Options.lua: Glass UI's page in Esc > Options > AddOns: the suite theme and
-- the Glass family (docs/SUITE.md, "Glass UI's page"; the owner's mockup,
-- 2026-10-18). Glass Mail's recipe (the porting guide's): a plain Frame with
-- .name, hidden at creation, controls built on the first OnShow, every value
-- re-read on every OnShow, registered once at PLAYER_LOGIN from GlassUI.lua.
--
-- Top to bottom: the suite preset card; one card per addon that speaks the
-- suite API (its state, "Use Glass UI appearance", its Settings); the others
-- folded under "Theme sync unavailable (n)"; click-casting; the reload
-- footer. The cards are our own glass, built with the Pearl recipe, so the
-- page shows what it sells.
--
-- Every change applies at the next /reload. ReloadUI() from addon code is
-- protected on Forever, so the Reload UI button is ForeverProbe's measured
-- one (AltStable's): a SecureActionButtonTemplate running the /reload macro,
-- on a frame of its own parented to nothing (a protected frame inside the
-- Settings panel would make the panel's own show and hide protected in
-- combat), positioned over the footer, never anchored to it, attributes set
-- once out of combat, nothing of ours on its click, hidden as combat starts
-- and shown only outside it. In combat the footer says to type /reload.
--
-- The page scrolls, the footer under it doesn't (owner, 2026-10-19: with four
-- addons following, the page ran past the window). A footer that stays put
-- also keeps the Reload UI button, placed over it, where the footer is.

GlassUI = GlassUI or {}
local GUI = GlassUI
local API = GUI.API
local Options = {}
GUI.Options = Options

-- The last click's line under the Quest text checkbox, cleared when the
-- switch changes any other way (Blizzard's settings, the slash command,
-- letting go), shown or not (Codex on #204).
GUI.QuestText.OnChange(function() Options.questTextLine = nil end)

local panel = CreateFrame("Frame")
panel.name = "Glass UI"
panel:Hide()
local scroll, page   -- the scroll frame and its child, the page's content (built on the first show)

local category
local refreshers = {}

-- The states of a member that speaks the suite API (Suite.State).
local SPEAKS = { early = true, silent = true, failed = true, following = true, own = true, chosen = true }
local PAD = 16
local FOOTER = 64    -- the footer's height under the scrolled page: the note, the Reload UI button, the credit
local CARD_BACKING = { 0.05, 0.06, 0.08, 0.55 }
-- The pearl in the preset card: the Iridescent Pearl's own icon (item 5500),
-- read from the client (never a guessed file name), clipped round inside the
-- glass disc. No icon: the bare disc.
local PEARL_ITEM = 5500
local ICON_TRIM = 0.08   -- the icon's square frame, cut away

local function refreshAll()
    for _, refresh in ipairs(refreshers) do refresh() end
end

-- The page's glass: Pearl when the running LibGlass has it (r11), else ours.
local function pageGlass()
    if Options.glass then return Options.glass end
    local ok, inst = pcall(function() return LibStub("LibGlass-1.0"):New({ preset = "pearl" }) end)
    Options.glass = ok and inst or GUI.Glass
    return Options.glass
end

local function label(parent, text, font)
    local fs = parent:CreateFontString(nil, "ARTWORK", font or "GameFontHighlight")
    fs:SetText(text)
    fs:SetJustifyH("LEFT")
    return fs
end

local function button(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 24)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

-- Across the page, under `anchor`.
local function span(region, anchor, gap)
    region:ClearAllPoints()
    region:SetPoint("TOP", anchor, "BOTTOM", 0, -gap)
    region:SetPoint("LEFT", page, "LEFT", PAD, 0)
    region:SetPoint("RIGHT", page, "RIGHT", -PAD, 0)
end

-- A glass card `height` tall: the card, and the frame its content goes on
-- (above the glass body).
local function card(height)
    local c = CreateFrame("Frame", nil, page)
    c:SetHeight(height)
    local Glass = pageGlass()
    local ok, g = pcall(Glass.Apply, c, "small")
    if ok and type(g) == "table" then
        local backing = c:CreateTexture(nil, "BACKGROUND", nil, -7)
        backing:SetAllPoints(c)
        backing:SetColorTexture(CARD_BACKING[1], CARD_BACKING[2], CARD_BACKING[3], CARD_BACKING[4])
        if g.mask then backing:AddMaskTexture(g.mask) end
    end
    local content = CreateFrame("Frame", nil, c)
    content:SetAllPoints(c)
    content:SetFrameLevel(c:GetFrameLevel() + 2)
    return c, content
end

local function rule(parent)
    local t = (parent or page):CreateTexture(nil, "ARTWORK")
    t:SetColorTexture(1, 1, 1, 0.12)
    t:SetHeight(1)
    return t
end

--------------------------------------------------------------------------------
-- The Reload UI button (the header comment says why it is built this way)
--------------------------------------------------------------------------------

local reload   -- { frame, button }
-- From PLAYER_REGEN_DISABLED to PLAYER_REGEN_ENABLED. InCombatLockdown() is
-- still false while PLAYER_REGEN_DISABLED runs, and the page redraws then:
-- without this the redraw would show the button again as combat begins.
local fighting = false

local function combat() return fighting or InCombatLockdown() end

local function buildReload()
    if reload or combat() then return reload end
    local f = CreateFrame("Frame", nil, nil)
    f:SetFrameStrata("DIALOG")
    f:SetSize(150, 26)
    local b = CreateFrame("Button", nil, f, "SecureActionButtonTemplate, UIPanelButtonTemplate")
    b:SetAllPoints(f)
    b:SetText("Reload UI")
    b:SetAttribute("type", "macro")
    b:SetAttribute("macrotext", "/reload")
    b:RegisterForClicks("AnyUp", "AnyDown")
    f:Hide()
    reload = { frame = f, button = b }
    Options._test.reload = reload
    return reload
end

-- Over `spot` (our footer placeholder), at its screen position and scale.
-- Only outside combat; never anchored to it.
local function showReload(spot)
    if combat() then return end
    local r = buildReload()
    if not r then return end
    local cx, cy = spot:GetCenter()
    if not (cx and cy) then r.frame:Hide() return end
    r.frame:SetScale(spot:GetEffectiveScale())
    r.frame:ClearAllPoints()
    r.frame:SetPoint("CENTER", nil, "BOTTOMLEFT", cx, cy)
    r.frame:Show()
end

local function hideReload()
    if reload and not combat() then reload.frame:Hide() end
end

-- Hidden as combat starts (before the lockdown); the footer is redrawn
-- either way, and after combat the button comes back if the page is open.
local combatWatch = CreateFrame("Frame")
API.RegisterEvents(combatWatch, { "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }, "options")
combatWatch:SetScript("OnEvent", function(_, event)
    fighting = event == "PLAYER_REGEN_DISABLED"
    if fighting and reload then reload.frame:Hide() end
    if Options.built and panel:IsShown() then refreshAll() end
end)

--------------------------------------------------------------------------------
-- The page
--------------------------------------------------------------------------------

-- A member's card: its name, its state, "Use Glass UI appearance", Settings.
-- The refresher returns whether it speaks the API, and whether a reload
-- would change what it builds.
local function memberCard(m)
    local Suite = GUI.Suite
    local c, content = card(54)
    local name = label(content, m.title, "GameFontHighlightLarge")
    name:SetPoint("TOPLEFT", content, "TOPLEFT", 14, -10)
    local status = label(content, "", "GameFontDisable")
    status:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -4)
    local open = button(content, "Settings", 110, function()
        local r = Suite.ReportOf(m.name)
        if r and r.options then API.Try("suite:options:" .. m.name, r.options) end
    end)
    open:SetPoint("RIGHT", content, "RIGHT", -12, 0)
    local follow = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    follow:SetSize(26, 26)
    follow:SetPoint("RIGHT", open, "LEFT", -190, 0)
    local text = label(content, "Use Glass UI appearance")
    text:SetPoint("LEFT", follow, "RIGHT", 6, 0)
    -- The name and state stop short of the checkbox (they ran under it in game, 70450).
    for _, fs in ipairs({ name, status }) do
        fs:SetPoint("RIGHT", follow, "LEFT", -10, 0)
        fs:SetWordWrap(false)
    end
    follow:SetScript("OnClick", function()
        Suite.SetFollow(m.name, follow:GetChecked() == true)
        refreshAll()
    end)
    Options._test.rows[m.name] = { card = c, follow = follow, line = status, open = open }
    return c, function()
        local state, pending = Suite.State(m.name)
        local r = Suite.ReportOf(m.name)
        local theme = Suite.THEMES[Suite.ThemeName()].label
        local s
        if state == "following" then s = "Glass UI preset: " .. theme
        elseif state == "failed" then s = theme .. " failed (" .. ((r and r.reason) or "?") .. "): using addon settings"
        elseif state == "early" then s = "Started before Glass UI: using addon settings"
        elseif state == "silent" then s = "No report from it: see its errors"
        elseif state == "chosen" then s = "Its own look by its choice: " .. ((r and r.declined) or "?")
        else s = "Using addon settings" end
        -- The suite look it overrides, and the addons wearing its skin.
        if r and r.own and (state == "following" or state == "own") then
            local own = {}
            for _, k in ipairs(Suite.LOOK_KEYS) do
                if r.own[k] then own[#own + 1] = Suite.LOOK_LABELS[k]:lower() end
            end
            if r.own.backing then own[#own + 1] = "backing" end
            if #own > 0 then s = s .. "; its own " .. table.concat(own, ", ") end
        end
        local tenants = Suite.Tenants(m.name)
        if #tenants > 0 then s = s .. "; " .. table.concat(tenants, ", ") .. " follow it" end
        if pending then s = s .. " - reload to apply" end
        status:SetText(s)
        follow:SetChecked(Suite.Following(m.name))
        open:SetShown(r ~= nil and r.options ~= nil)
        return SPEAKS[state] == true, pending
    end
end

-- The page as tall as its content (from its top to `last`'s bottom), so the
-- scroll range is what overflows. Rects are read, so it waits for the layout.
local function fit(last)
    local top, bottom = page:GetTop(), last:GetBottom()
    if not (top and bottom) then return end
    page:SetHeight(math.max(1, top - bottom + PAD))
end

local function build()
    local Suite = GUI.Suite
    scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -4)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -26, FOOTER + 4)
    page = CreateFrame("Frame", nil, scroll)
    page:SetSize(1, 1)
    scroll:SetScrollChild(page)
    scroll:HookScript("OnSizeChanged", function(_, w) page:SetWidth(w) end)
    API.AutoHideScrollBar(scroll)
    Options._test.scroll, Options._test.page = scroll, page

    local title = label(page, "Glass UI", "GameFontHighlightHuge")
    title:SetPoint("TOPLEFT", page, "TOPLEFT", PAD + 4, -PAD)
    local tagline = label(page, "One appearance for your Glass addons.")
    tagline:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)

    -- The suite preset, with a pearl of our glass beside it.
    local preset, presetContent = card(78)
    span(preset, tagline, 14)
    local kicker = label(presetContent, "SUITE PRESET", "GameFontHighlightSmall")
    kicker:SetPoint("TOPLEFT", presetContent, "TOPLEFT", 16, -12)
    local presetName = label(presetContent, "", "GameFontHighlightHuge")
    presetName:SetPoint("TOPLEFT", kicker, "BOTTOMLEFT", 0, -4)
    local presetNote = label(presetContent, "Used by addons linked to Glass UI.", "GameFontDisable")
    presetNote:SetPoint("TOPLEFT", presetName, "BOTTOMLEFT", 0, -4)
    local orb = CreateFrame("Frame", nil, presetContent)
    orb:SetSize(48, 48)
    orb:SetPoint("RIGHT", presetContent, "RIGHT", -22, 0)
    local okDisc = pcall(pageGlass().Disc, orb, "disc")
    local okIcon, icon = pcall(C_Item.GetItemIconByID, PEARL_ITEM)
    icon = okIcon and API.Plain(icon) or nil
    if okDisc and icon then
        local face = CreateFrame("Frame", nil, orb)
        face:SetAllPoints(orb)
        face:SetFrameLevel(pageGlass().ContentLevel(orb))
        local t = face:CreateTexture(nil, "ARTWORK")
        t:SetPoint("TOPLEFT", orb, "TOPLEFT", 3, -3)
        t:SetPoint("BOTTOMRIGHT", orb, "BOTTOMRIGHT", -3, 3)
        t:SetTexture(icon)
        t:SetTexCoord(ICON_TRIM, 1 - ICON_TRIM, ICON_TRIM, 1 - ICON_TRIM)
        t:AddMaskTexture(pageGlass().Mask(face, "disc_mask", nil, 3, orb))
        Options._test.pearl = t
    end
    Options._test.presetName = presetName

    local sep1 = rule()
    span(sep1, preset, 14)
    local appearance = label(page, "Addon appearance", "GameFontHighlightLarge")
    appearance:SetPoint("TOPLEFT", sep1, "BOTTOMLEFT", 4, -12)
    local choose = label(page, "Choose which addons use the Glass UI appearance.", "GameFontDisable")
    choose:SetPoint("TOPLEFT", appearance, "BOTTOMLEFT", 0, -6)

    -- A card per roster member; only those that speak the API are shown,
    -- stacked in roster order.
    local cards = {}
    for _, m in ipairs(Suite.ROSTER) do
        local c, refresh = memberCard(m)
        cards[#cards + 1] = { c = c, refresh = refresh, m = m }
    end
    local restore = label(page, "Turn off to restore an addon's saved appearance settings.", "GameFontDisable")

    -- Theme sync unavailable: the rest, folded.
    local fold = CreateFrame("Button", nil, page)
    fold:SetHeight(28)
    local arrow = label(fold, "", "GameFontHighlight")
    arrow:SetPoint("LEFT", fold, "LEFT", 12, 0)
    local foldText = label(fold, "", "GameFontHighlight")
    foldText:SetPoint("LEFT", fold, "LEFT", 30, 0)
    local hl = fold:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(fold)
    hl:SetColorTexture(1, 1, 1, 0.05)
    local list = label(page, "", "GameFontDisable")
    list:SetJustifyV("TOP")
    local keepOwn = label(page, "These addons keep their own appearance settings.", "GameFontDisable")
    Options.expanded = false
    fold:SetScript("OnClick", function()
        Options.expanded = not Options.expanded
        refreshAll()
    end)
    Options._test.fold, Options._test.foldText, Options._test.list = fold, foldText, list

    -- Raid frames: the group layout and click-casting, both Glass Raid
    -- Frames' (shown here, set there).
    local sep2 = rule()
    local cc = label(page, "Raid frames", "GameFontHighlightLarge")
    cc:SetPoint("TOPLEFT", sep2, "BOTTOMLEFT", 4, -12)
    local layoutLine = label(page, "", "GameFontHighlight")
    layoutLine:SetPoint("TOPLEFT", cc, "BOTTOMLEFT", 0, -6)
    local ccLine = label(page, "", "GameFontHighlight")
    ccLine:SetPoint("TOPLEFT", layoutLine, "BOTTOMLEFT", 0, -4)
    Options._test.layoutLine = layoutLine
    local ccOpen = button(page, "Configure bindings", 170, function()
        local c = Suite.ClickCast()
        if c and c.open then API.Try("suite:clickcast", c.open) end
    end)
    ccOpen:SetPoint("RIGHT", page, "RIGHT", -PAD, 0)
    ccOpen:SetPoint("TOP", cc, "TOP", 0, -6)
    Options._test.clickCast, Options._test.clickCastOpen = ccLine, ccOpen

    -- Quest text (#203, docs/QUEST-TEXT.md): Light quest text on glass, the
    -- one Blizzard setting Glass UI changes, live (no reload).
    local QT = GUI.QuestText
    local sep4 = rule()
    local qtTitle = label(page, "Quest text", "GameFontHighlightLarge")
    qtTitle:SetPoint("TOPLEFT", sep4, "BOTTOMLEFT", 4, -12)
    local qtCheck = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    qtCheck:SetSize(26, 26)
    qtCheck:SetPoint("TOPLEFT", qtTitle, "BOTTOMLEFT", -4, -4)
    local qtText = label(page, "Light quest text on glass")
    qtText:SetPoint("LEFT", qtCheck, "RIGHT", 6, 0)
    local qtNote = label(page, "", "GameFontDisable")
    qtNote:SetPoint("TOPLEFT", qtCheck, "BOTTOMLEFT", 4, -2)
    qtNote:SetPoint("RIGHT", page, "RIGHT", -PAD, 0)
    qtNote:SetJustifyV("TOP")
    local qtLine = label(page, "", "GameFontHighlightSmall")
    qtLine:SetPoint("TOPLEFT", qtNote, "BOTTOMLEFT", 0, -4)
    qtLine:SetPoint("RIGHT", page, "RIGHT", -PAD, 0)
    qtCheck:SetScript("OnClick", function()
        local _, line = (qtCheck:GetChecked() and QT.On or QT.Off)()
        Options.questTextLine = line
        refreshAll()
    end)
    qtCheck:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Light quest text on glass", 1, 1, 1)
        GameTooltip:AddLine("Turn this off before uninstalling to restore your previous setting.", 1, 0.82, 0)
        GameTooltip:Show()
    end)
    qtCheck:SetScript("OnLeave", function() GameTooltip:Hide() end)
    QT.OnChange(function() if Options.built and panel:IsShown() then refreshAll() end end)
    Options._test.questText = { check = qtCheck, note = qtNote, line = qtLine }

    -- The footer, on the panel under the scrolled page: the note, and the
    -- spot the Reload UI button sits over.
    local sep3 = rule(panel)
    sep3:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", PAD, FOOTER)
    sep3:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -PAD, FOOTER)
    local note = label(panel, "", "GameFontHighlight")
    note:SetPoint("TOPLEFT", sep3, "BOTTOMLEFT", 4, -14)
    local spot = CreateFrame("Frame", nil, panel)
    spot:SetSize(150, 26)
    spot:SetPoint("RIGHT", panel, "RIGHT", -PAD, 0)
    spot:SetPoint("TOP", sep3, "BOTTOM", 0, -8)
    local credit = label(panel, "", "GameFontDisableSmall")
    credit:SetPoint("TOPRIGHT", spot, "BOTTOMRIGHT", 0, -6)
    Options._test.note, Options._test.spot = note, spot

    refreshers[#refreshers + 1] = function()
        presetName:SetText(Suite.THEMES[Suite.ThemeName()].label)
        local prev, anyPending, others = choose, false, {}
        for _, e in ipairs(cards) do
            local speaks, pending = e.refresh()
            anyPending = anyPending or pending
            if speaks then
                span(e.c, prev, prev == choose and 10 or 6)
                e.c:Show()
                prev = e.c
            else
                e.c:Hide()
                if Suite.Listed(e.m) then others[#others + 1] = (Suite.Line(e.m)) end
            end
        end
        restore:ClearAllPoints()
        restore:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", prev == choose and 0 or 4, -8)
        span(fold, restore, 10)
        fold:SetShown(#others > 0)
        foldText:SetText("Theme sync unavailable (" .. #others .. ")")
        arrow:SetText(Options.expanded and "v" or ">")
        list:SetText(table.concat(others, "\n"))
        list:ClearAllPoints()
        list:SetPoint("TOPLEFT", fold, "BOTTOMLEFT", 30, -2)
        list:SetShown(Options.expanded and #others > 0)
        keepOwn:ClearAllPoints()
        local after = Options.expanded and list or fold
        keepOwn:SetPoint("TOPLEFT", after, "BOTTOMLEFT", after == fold and 4 or -26, -6)
        keepOwn:SetShown(#others > 0)
        span(sep2, #others > 0 and keepOwn or restore, 14)

        layoutLine:SetText(Suite.LayoutLine() or "Group layout: Glass Raid Frames hasn't reported one")
        local c = Suite.ClickCast()
        if c then
            ccLine:SetText("Click-casting: bindings on other addons' frames " .. (c.others and "enabled" or "disabled"))
        else
            ccLine:SetText("Click-casting: Glass Raid Frames hasn't reported this session")
        end
        ccOpen:SetShown(c ~= nil and c.open ~= nil)

        span(sep4, ccLine, 14)
        qtCheck:SetChecked(QT.IsOn())
        local base = "Turns on Blizzard's Dark quest text (Settings > Accessibility) and keeps it on until you "
            .. "turn this off. It also changes books, the quest details popup and the map's quest details."
        qtNote:SetText(QT.IsPending() and ("On, waiting for combat to end. " .. base) or base)
        qtLine:SetText(Options.questTextLine or "")

        if anyPending then
            note:SetText(combat() and "Changes are waiting: type /reload when combat ends."
                or "Changes are waiting: reload to apply them.")
        else
            note:SetText("Appearance changes apply after reloading.")
        end
        Options.pending = anyPending
        credit:SetText((GUI.IsDev() and "Development build" or ("Version " .. GUI.VersionText())) .. " - Spotnick")
        showReload(spot)
        page:SetWidth(scroll:GetWidth())
        fit(qtLine)
        C_Timer.After(0, function() fit(qtLine) end)
    end
end

panel:SetScript("OnShow", function()
    if not Options.built then
        Options.built = true
        build()
    end
    refreshAll()
end)
panel:SetScript("OnHide", hideReload)

--------------------------------------------------------------------------------
-- The "Suite look" subpage (docs/SUITE-LOOK.md): the tint and the button
-- feedback every follower uses unless it overrides a key. Each choice is
-- saved and announced at once (Suite.SetLook), live.
--------------------------------------------------------------------------------

local lookPanel = CreateFrame("Frame")
lookPanel.name = "Suite look"
lookPanel:Hide()
local lookRefreshers = {}
local RADIO_ART = "Interface\\Buttons\\UI-RadioButton"   -- 4 cells: normal, checked, highlight, pushed

-- A labelled radio: UIRadioButtonTemplate when the client has it (its own
-- label, rb.text), else the client's radio art and a label of ours (Glass
-- Mail's recipe).
local function radio(parent, text)
    local ok, rb = pcall(CreateFrame, "CheckButton", nil, parent, "UIRadioButtonTemplate")
    if ok and rb and rb.text then
        rb.text:SetFontObject("GameFontHighlight")
        rb.text:SetText(text)
        return rb
    end
    rb = CreateFrame("CheckButton", nil, parent)
    rb:SetSize(16, 16)
    rb:SetNormalTexture(RADIO_ART)
    rb:GetNormalTexture():SetTexCoord(0, 0.25, 0, 1)
    rb:SetCheckedTexture(RADIO_ART)
    rb:GetCheckedTexture():SetTexCoord(0.25, 0.5, 0, 1)
    rb:SetHighlightTexture(RADIO_ART)
    rb:GetHighlightTexture():SetTexCoord(0.5, 0.75, 0, 1)
    rb:GetHighlightTexture():SetBlendMode("ADD")
    local fs = label(parent, text)
    fs:SetPoint("LEFT", rb, "RIGHT", 4, 0)
    rb.text = fs
    return rb
end

local function refreshLook()
    for _, refresh in ipairs(lookRefreshers) do refresh() end
end

-- One row of choices under `anchor`: a heading, then the radios left to
-- right. get() returns the value to check; set(value) applies one.
local function choiceRow(anchor, heading, values, get, set)
    local Suite = GUI.Suite
    local h = label(lookPanel, heading, "GameFontNormal")
    h:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -16)
    local group, prev = {}, nil
    for _, v in ipairs(values) do
        local rb = radio(lookPanel, Suite.LOOK_LABELS[v] or v)
        rb.value = v
        if prev then
            rb:SetPoint("LEFT", prev, "RIGHT", 110, 0)
        else
            rb:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -6)
        end
        -- set() saves and announces; Suite's change notice redraws this page.
        rb:SetScript("OnClick", function() set(v) end)
        group[#group + 1] = rb
        prev = rb
    end
    lookRefreshers[#lookRefreshers + 1] = function()
        local current = get()
        for _, rb in ipairs(group) do rb:SetChecked(rb.value == current) end
    end
    Options._test.lookRows[heading] = group
    return group[1]
end

local function buildLook()
    local Suite = GUI.Suite
    local title = label(lookPanel, "Suite look", "GameFontHighlightHuge")
    title:SetPoint("TOPLEFT", lookPanel, "TOPLEFT", PAD + 4, -PAD)
    local note = label(lookPanel, "The tint, the accent colour and the button feedback of every Glass addon that "
        .. "uses the Glass UI appearance, and of Glass UI's own skins. An addon can keep its own value for any of "
        .. "them in its settings. Changes apply at once.",
        "GameFontDisable")
    note:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    note:SetWidth(560)
    local function lookOf(k) return function() return (Suite.Look() or Suite.LOOK_DEFAULTS)[k] end end
    local function setter(k) return function(v) Suite.SetLook(k, v) end end
    local prev = choiceRow(note, "Tint", Suite.LOOK_VALUES.tint, lookOf("tint"), setter("tint"))
    prev = choiceRow(prev, "Accent", Suite.LOOK_VALUES.accent, lookOf("accent"), setter("accent"))
    local presets = {}
    for i, n in ipairs(Suite.LOOK_PRESET_NAMES) do presets[i] = n end
    prev = choiceRow(prev, "Button feedback", presets, function() return Suite.LookPreset() end,
        function(v) Suite.SetLookPreset(v) end)
    local custom = label(lookPanel, "", "GameFontDisableSmall")
    custom:SetPoint("LEFT", prev, "RIGHT", 380, 0)
    lookRefreshers[#lookRefreshers + 1] = function()
        custom:SetText(Suite.LookPreset() == "custom" and "(custom)" or "")
    end
    prev = choiceRow(prev, "Hover", Suite.LOOK_VALUES.hover, lookOf("hover"), setter("hover"))
    prev = choiceRow(prev, "Press", Suite.LOOK_VALUES.press, lookOf("press"), setter("press"))
    prev = choiceRow(prev, "Empty slots", Suite.LOOK_VALUES.emptySlots, lookOf("emptySlots"), setter("emptySlots"))
    local followers = label(lookPanel, "", "GameFontHighlight")
    followers:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -24)
    followers:SetWidth(560)
    followers:SetJustifyV("TOP")
    lookRefreshers[#lookRefreshers + 1] = function()
        local lines = {}
        for _, m in ipairs(Suite.ROSTER) do
            local l, switching = Suite.LookLine(m.name)
            if l and switching then
                l = l .. "; set to " .. (Suite.Following(m.name) and "follow" or "its own look")
                    .. " - /reload to apply"
            end
            if l then lines[#lines + 1] = m.title .. ": " .. l end
            for _, t in ipairs(Suite.Tenants(m.name)) do lines[#lines + 1] = t .. ": follows " .. m.title end
        end
        followers:SetText(#lines > 0 and table.concat(lines, "\n")
            or "No Glass addon follows the suite look yet.")
    end
    Options._test.lookFollowers, Options._test.lookCustom = followers, custom
end

lookPanel:SetScript("OnShow", function()
    if not Options.lookBuilt then
        Options.lookBuilt = true
        buildLook()
    end
    refreshLook()
end)

-- Called once at PLAYER_LOGIN by GlassUI.lua.
function Options.Register()
    if category then return end
    category = API.RegisterSettingsPanel(panel, panel.name)
    Options.lookCategory = API.RegisterSettingsSubpanel(category, lookPanel, lookPanel.name)
end

function Options.OpenLook() return API.OpenSettings(Options.lookCategory) end

function Options.Open() return API.OpenSettings(category) end

-- Suite's change notice: redraw only while the page is open.
function Options.Refresh()
    if Options.built and panel:IsShown() then refreshAll() end
    if Options.lookBuilt and lookPanel:IsShown() then refreshLook() end
end

Options._test = { panel = panel, refreshers = refreshers, rows = {}, lookPanel = lookPanel, lookRows = {} }
