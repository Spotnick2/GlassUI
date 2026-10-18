-- Options.lua: Glass UI's page in Esc > Options > AddOns: the suite theme and
-- the Glass family (docs/SUITE.md, "Glass UI's page"). Glass Mail's recipe
-- (the porting guide's): a plain Frame with .name, hidden at creation,
-- controls built on the first OnShow, every value re-read on every OnShow,
-- registered once at PLAYER_LOGIN from GlassUI.lua.
--
-- Each member's line is Suite.Line, the same as /glassui suite. A member
-- that speaks the suite API gets a Follow checkbox, and an Options button
-- when it reported one. Every change applies at the next /reload: the page
-- only saves it, and offers the reload.

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

local function label(parent, text, font)
    local fs = parent:CreateFontString(nil, "ARTWORK", font or "GameFontHighlight")
    fs:SetText(text)
    return fs
end

local function button(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

-- A family member's row: its line, and the controls its state allows.
local function memberRow(m, anchor)
    local Suite = GUI.Suite
    local row = CreateFrame("Frame", nil, panel)
    row:SetSize(560, 26)
    row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    local follow = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    follow:SetSize(24, 24)
    follow:SetPoint("LEFT", row, "LEFT", 0, 0)
    local line = label(row, "")
    line:SetPoint("LEFT", follow, "RIGHT", 4, 0)
    line:SetJustifyH("LEFT")
    local open = button(row, "Options", 80, function()
        local r = Suite.ReportOf(m.name)
        if r and r.options then API.Try("suite:options:" .. m.name, r.options) end
    end)
    open:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    line:SetPoint("RIGHT", open, "LEFT", -8, 0)
    follow:SetScript("OnClick", function()
        Suite.SetFollow(m.name, follow:GetChecked() == true)
        for _, refresh in ipairs(refreshers) do refresh() end
    end)
    refreshers[#refreshers + 1] = function()
        local text, state = Suite.Line(m)
        line:SetText(text)
        follow:SetShown(SPEAKS[state] == true)
        follow:SetChecked(Suite.Following(m.name))
        local r = Suite.ReportOf(m.name)
        open:SetShown(r ~= nil and r.options ~= nil)
    end
    Options._test.rows[m.name] = { follow = follow, line = line, open = open }
    return row
end

local function build()
    local Suite = GUI.Suite
    local title = label(panel, "Glass UI", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    local version = label(panel, "", "GameFontDisableSmall")
    version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    local theme = label(panel, "", "GameFontNormal")
    theme:SetPoint("TOPLEFT", version, "BOTTOMLEFT", 0, -16)
    local note = label(panel, "An addon that follows Glass UI takes the suite theme, and its own look "
        .. "settings wait, unchanged, until it stops. Changes apply after a /reload.", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", theme, "BOTTOMLEFT", 0, -6)
    note:SetWidth(560)
    note:SetJustifyH("LEFT")
    refreshers[#refreshers + 1] = function()
        version:SetText("Version " .. GUI.VersionText() .. " for World of Warcraft: Forever, by Spotnick")
        theme:SetText("Suite theme: " .. Suite.THEMES[Suite.ThemeName()].label)
    end
    local prev = note
    for _, m in ipairs(Suite.ROSTER) do prev = memberRow(m, prev) end

    local cc = label(panel, "", "GameFontHighlight")
    cc:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -16)
    local ccOpen = button(panel, "Click-casting", 110, function()
        local c = Suite.ClickCast()
        if c and c.open then API.Try("suite:clickcast", c.open) end
    end)
    ccOpen:SetPoint("LEFT", cc, "RIGHT", 8, 0)
    local reload = button(panel, "Reload", 90, function() ReloadUI() end)
    reload:SetPoint("TOPLEFT", cc, "BOTTOMLEFT", 0, -16)
    refreshers[#refreshers + 1] = function()
        local c = Suite.ClickCast()
        cc:SetText(c and ("Click-casting: Glass Raid Frames; its bindings on other addons' frames: "
            .. (c.others and "on" or "off")) or "Click-casting: not reported")
        ccOpen:SetShown(c ~= nil and c.open ~= nil)
        local any = false
        for _, m in ipairs(Suite.ROSTER) do
            local _, _, pending = Suite.Line(m)
            any = any or pending
        end
        reload:SetShown(any)
    end
    Options._test.clickCast, Options._test.clickCastOpen, Options._test.reload = cc, ccOpen, reload
end

panel:SetScript("OnShow", function()
    if not Options.built then
        Options.built = true
        build()
    end
    for _, refresh in ipairs(refreshers) do refresh() end
end)

-- Called once at PLAYER_LOGIN by GlassUI.lua.
function Options.Register()
    if category then return end
    category = API.RegisterSettingsPanel(panel, panel.name)
end

function Options.Open() return API.OpenSettings(category) end

Options._test = { panel = panel, refreshers = refreshers, rows = {} }
