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

GlassUI = GlassUI or {}
local GUI = GlassUI
local API = GUI.API
local Options = {}
GUI.Options = Options

local panel = CreateFrame("Frame")
panel.name = "Glass UI"
panel:Hide()

local category
local refreshers = {}

-- The states of a member that speaks the suite API (Suite.State).
local SPEAKS = { early = true, silent = true, failed = true, following = true, own = true }
local PAD = 16
local CARD_BACKING = { 0.05, 0.06, 0.08, 0.55 }

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
    region:SetPoint("LEFT", panel, "LEFT", PAD, 0)
    region:SetPoint("RIGHT", panel, "RIGHT", -PAD, 0)
end

-- A glass card `height` tall: the card, and the frame its content goes on
-- (above the glass body).
local function card(height)
    local c = CreateFrame("Frame", nil, panel)
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

local function rule()
    local t = panel:CreateTexture(nil, "ARTWORK")
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
        else s = "Using addon settings" end
        if pending then
            s = s .. " - reload to " .. (Suite.Following(m.name) and ("use " .. theme) or "use its own settings")
        end
        status:SetText(s)
        follow:SetChecked(Suite.Following(m.name))
        open:SetShown(r ~= nil and r.options ~= nil)
        return SPEAKS[state] == true, pending
    end
end

local function build()
    local Suite = GUI.Suite
    local title = label(panel, "Glass UI", "GameFontHighlightHuge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD + 4, -PAD)
    local tagline = label(panel, "One appearance for your Glass addons.")
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
    pcall(pageGlass().Disc, orb, "disc")
    Options._test.presetName = presetName

    local sep1 = rule()
    span(sep1, preset, 14)
    local appearance = label(panel, "Addon appearance", "GameFontHighlightLarge")
    appearance:SetPoint("TOPLEFT", sep1, "BOTTOMLEFT", 4, -12)
    local choose = label(panel, "Choose which addons use the Glass UI appearance.", "GameFontDisable")
    choose:SetPoint("TOPLEFT", appearance, "BOTTOMLEFT", 0, -6)

    -- A card per roster member; only those that speak the API are shown,
    -- stacked in roster order.
    local cards = {}
    for _, m in ipairs(Suite.ROSTER) do
        local c, refresh = memberCard(m)
        cards[#cards + 1] = { c = c, refresh = refresh, m = m }
    end
    local restore = label(panel, "Turn off to restore an addon's saved appearance settings.", "GameFontDisable")

    -- Theme sync unavailable: the rest, folded.
    local fold = CreateFrame("Button", nil, panel)
    fold:SetHeight(28)
    local arrow = label(fold, "", "GameFontHighlight")
    arrow:SetPoint("LEFT", fold, "LEFT", 12, 0)
    local foldText = label(fold, "", "GameFontHighlight")
    foldText:SetPoint("LEFT", fold, "LEFT", 30, 0)
    local hl = fold:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(fold)
    hl:SetColorTexture(1, 1, 1, 0.05)
    local list = label(panel, "", "GameFontDisable")
    list:SetJustifyV("TOP")
    local keepOwn = label(panel, "These addons keep their own appearance settings.", "GameFontDisable")
    Options.expanded = false
    fold:SetScript("OnClick", function()
        Options.expanded = not Options.expanded
        refreshAll()
    end)
    Options._test.fold, Options._test.foldText, Options._test.list = fold, foldText, list

    -- Click-casting.
    local sep2 = rule()
    local cc = label(panel, "Click-casting", "GameFontHighlightLarge")
    cc:SetPoint("TOPLEFT", sep2, "BOTTOMLEFT", 4, -12)
    local ccOwner = label(panel, "", "GameFontHighlight")
    ccOwner:SetPoint("TOPLEFT", cc, "BOTTOMLEFT", 0, -6)
    local ccLine = label(panel, "", "GameFontHighlight")
    ccLine:SetPoint("TOPLEFT", ccOwner, "BOTTOMLEFT", 0, -4)
    local ccOpen = button(panel, "Configure bindings", 170, function()
        local c = Suite.ClickCast()
        if c and c.open then API.Try("suite:clickcast", c.open) end
    end)
    ccOpen:SetPoint("RIGHT", panel, "RIGHT", -PAD, 0)
    ccOpen:SetPoint("TOP", cc, "TOP", 0, -6)
    Options._test.clickCast, Options._test.clickCastOpen = ccLine, ccOpen

    -- The footer: the note, and the spot the Reload UI button sits over.
    local sep3 = rule()
    span(sep3, ccLine, 14)
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
                others[#others + 1] = (Suite.Line(e.m))
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

        local c = Suite.ClickCast()
        if c then
            ccOwner:SetText("Managed by Glass Raid Frames")
            ccLine:SetText("Bindings on other addons' frames: " .. (c.others and "Enabled" or "Disabled"))
        else
            ccOwner:SetText("Managed by Glass Raid Frames, when it is loaded")
            ccLine:SetText("Glass Raid Frames hasn't reported this session.")
        end
        ccOpen:SetShown(c ~= nil and c.open ~= nil)

        if anyPending then
            note:SetText(combat() and "Changes are waiting: type /reload when combat ends."
                or "Changes are waiting: reload to apply them.")
        else
            note:SetText("Appearance changes apply after reloading.")
        end
        Options.pending = anyPending
        credit:SetText((GUI.IsDev() and "Development build" or ("Version " .. GUI.VersionText())) .. " - Spotnick")
        showReload(spot)
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

-- Called once at PLAYER_LOGIN by GlassUI.lua.
function Options.Register()
    if category then return end
    category = API.RegisterSettingsPanel(panel, panel.name)
end

function Options.Open() return API.OpenSettings(category) end

Options._test = { panel = panel, refreshers = refreshers, rows = {} }
