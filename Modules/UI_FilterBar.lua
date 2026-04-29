local addonName, ns = ...
ns.UI = ns.UI or {}

local UI = {
    SIZE = {
        BAR_HEIGHT = 74,
        ROW2_TOP = -30,
        ROW3_TOP = -52,
        BTN_HEIGHT = 18,
    },
    FONT = { ROW = "GameFontHighlightSmall" },
    COLOR = {
        BAR_BG = { 0.05, 0.05, 0.08, 0.9 },
        BTN_OFF = { 0.20, 0.20, 0.25, 1.0 },
        BTN_ON = { 0.45, 0.78, 1.00, 1.0 },
        BTN_TEXT = { 1, 1, 1, 1 },
        WHITE_TEX = "Interface\\Buttons\\WHITE8X8",
    },
}

ns.UI.Filter = {
    search = "",
    onlyOnline = false,
    role = nil,
    noRole = false,
    onlyMine = nil,
    showUnassigned = false,
}

local function ResolveOnlyMineDefault()
    if ns.UI.Filter.onlyMine ~= nil then return ns.UI.Filter.onlyMine end
    if ns.Notes and ns.Notes.CanEditUI and ns.Notes:CanEditUI() then return false end
    return true
end

local MainFrame = ns.UI.MainFrame

local Bar = CreateFrame("Frame", nil, MainFrame, "BackdropTemplate")
Bar:SetPoint("TOPLEFT", 10, -38)
Bar:SetPoint("TOPRIGHT", -10, -38)
Bar:SetHeight(UI.SIZE.BAR_HEIGHT)
Bar:SetBackdrop({
    bgFile = UI.COLOR.WHITE_TEX,
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
Bar:SetBackdropColor(unpack(UI.COLOR.BAR_BG))
Bar:SetBackdropBorderColor(0.20, 0.20, 0.25, 1)

local SearchBox = CreateFrame("EditBox", nil, Bar, "InputBoxTemplate")
SearchBox:SetHeight(UI.SIZE.BTN_HEIGHT)
SearchBox:SetAutoFocus(false)
SearchBox:SetMaxLetters(32)
SearchBox:SetScript("OnTextChanged", function(self)
    ns.UI.Filter.search = (self:GetText() or ""):lower()
    if ns.UI.Refresh then ns.UI:Refresh() end
end)
SearchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
SearchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

local function MakeToggle(parent, key, valueOn)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetHeight(UI.SIZE.BTN_HEIGHT)

    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetTexture(UI.COLOR.WHITE_TEX)
    btn.bg:SetVertexColor(unpack(UI.COLOR.BTN_OFF))

    btn.text = btn:CreateFontString(nil, "OVERLAY", UI.FONT.ROW)
    btn.text:SetPoint("CENTER")
    btn.text:SetTextColor(unpack(UI.COLOR.BTN_TEXT))

    btn.key = key
    btn.valueOn = valueOn

    btn:SetScript("OnClick", function(self)
        local cur = ns.UI.Filter[self.key]
        if self.valueOn ~= nil then
            if cur == self.valueOn then
                ns.UI.Filter[self.key] = nil
            else
                ns.UI.Filter[self.key] = self.valueOn
            end
        else
            ns.UI.Filter[self.key] = not cur
        end
        ns.UI.FilterBar:UpdateVisualState()
        if ns.UI.Refresh then ns.UI:Refresh() end
    end)

    return btn
end

local btnOnline = MakeToggle(Bar, "onlyOnline")
local btnMine = MakeToggle(Bar, "onlyMine")
btnMine:SetScript("OnClick", function()
    local resolved = ResolveOnlyMineDefault()
    ns.UI.Filter.onlyMine = not resolved
    ns.UI.FilterBar:UpdateVisualState()
    if ns.UI.Refresh then ns.UI:Refresh() end
end)
local btnUnassigned = MakeToggle(Bar, "showUnassigned")
local btnNoRole = MakeToggle(Bar, "noRole")
local btnTanks = MakeToggle(Bar, "role", "T")
local btnHealers = MakeToggle(Bar, "role", "H")
local btnDps = MakeToggle(Bar, "role", "D")
local btnClear = CreateFrame("Button", nil, Bar)
btnClear:SetHeight(UI.SIZE.BTN_HEIGHT)
btnClear.bg = btnClear:CreateTexture(nil, "BACKGROUND")
btnClear.bg:SetAllPoints()
btnClear.bg:SetTexture(UI.COLOR.WHITE_TEX)
btnClear.bg:SetVertexColor(0.30, 0.10, 0.10, 1)
btnClear.text = btnClear:CreateFontString(nil, "OVERLAY", UI.FONT.ROW)
btnClear.text:SetPoint("CENTER")
btnClear:SetScript("OnClick", function()
    ns.UI.Filter.search = ""
    ns.UI.Filter.onlyOnline = false
    ns.UI.Filter.noRole = false
    ns.UI.Filter.role = nil
    ns.UI.Filter.onlyMine = nil
    ns.UI.Filter.showUnassigned = false
    SearchBox:SetText("")
    ns.UI.FilterBar:UpdateVisualState()
    if ns.UI.Refresh then ns.UI:Refresh() end
end)

local function LayoutToggles()
    btnClear:ClearAllPoints()
    btnClear:SetPoint("TOPRIGHT", Bar, "TOPRIGHT", -8, -8)

    SearchBox:ClearAllPoints()
    SearchBox:SetHeight(UI.SIZE.BTN_HEIGHT)
    SearchBox:SetPoint("TOPLEFT", Bar, "TOPLEFT", 14, -8)
    SearchBox:SetPoint("RIGHT", btnClear, "LEFT", -8, 0)

    btnMine:ClearAllPoints()
    btnMine:SetPoint("TOPLEFT", Bar, "TOPLEFT", 14, UI.SIZE.ROW2_TOP)
    local prev = btnMine
    for _, b in ipairs({ btnUnassigned, btnOnline, btnNoRole }) do
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", prev, "TOPRIGHT", 3, 0)
        prev = b
    end

    btnTanks:ClearAllPoints()
    btnTanks:SetPoint("TOPLEFT", Bar, "TOPLEFT", 14, UI.SIZE.ROW3_TOP)
    prev = btnTanks
    for _, b in ipairs({ btnHealers, btnDps }) do
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", prev, "TOPRIGHT", 3, 0)
        prev = b
    end
end

local function FitToggles()
    local pad = 8
    for _, b in ipairs({ btnOnline, btnMine, btnUnassigned, btnNoRole, btnTanks, btnHealers, btnDps, btnClear }) do
        local w = b.text:GetStringWidth() + pad
        if w < 28 then w = 28 end
        b:SetWidth(w)
    end
end

Bar:SetScript("OnSizeChanged", function()
    FitToggles()
    LayoutToggles()
end)

ns.UI.FilterBar = Bar
ns.UI.SearchBox = SearchBox

function ns.UI.FilterBar:UpdateVisualState()
    local F = ns.UI.Filter
    btnOnline.bg:SetVertexColor(unpack(F.onlyOnline and UI.COLOR.BTN_ON or UI.COLOR.BTN_OFF))
    btnMine.bg:SetVertexColor(unpack(ResolveOnlyMineDefault() and UI.COLOR.BTN_ON or UI.COLOR.BTN_OFF))
    btnUnassigned.bg:SetVertexColor(unpack(F.showUnassigned and UI.COLOR.BTN_ON or UI.COLOR.BTN_OFF))
    btnNoRole.bg:SetVertexColor(unpack(F.noRole and UI.COLOR.BTN_ON or UI.COLOR.BTN_OFF))
    btnTanks.bg:SetVertexColor(unpack(F.role == "T" and UI.COLOR.BTN_ON or UI.COLOR.BTN_OFF))
    btnHealers.bg:SetVertexColor(unpack(F.role == "H" and UI.COLOR.BTN_ON or UI.COLOR.BTN_OFF))
    btnDps.bg:SetVertexColor(unpack(F.role == "D" and UI.COLOR.BTN_ON or UI.COLOR.BTN_OFF))
end

function ns.UI.Filter:IsMineModeActive()
    return ResolveOnlyMineDefault()
end

function ns.UI.Filter:ShouldShowUnassigned()
    return self.showUnassigned == true
end

ns.Locale:RegisterCallback(function()
    SearchBox:SetText("")
    if SearchBox.SetTextInsets then SearchBox:SetTextInsets(0, 0, 0, 0) end
    btnOnline.text:SetText(ns.L.FILTER_ONLY_ONLINE)
    btnMine.text:SetText(ns.L.FILTER_MINE)
    btnUnassigned.text:SetText(ns.L.FILTER_UNASSIGNED)
    btnNoRole.text:SetText(ns.L.FILTER_NO_ROLE)
    btnTanks.text:SetText(ns.L.FILTER_TANKS)
    btnHealers.text:SetText(ns.L.FILTER_HEALERS)
    btnDps.text:SetText(ns.L.FILTER_DPS)
    btnClear.text:SetText(ns.L.FILTER_CLEAR)
    FitToggles()
    LayoutToggles()
    ns.UI.FilterBar:UpdateVisualState()
end)

function ns.UI.Filter:Matches(member)
    if self.search and self.search ~= "" then
        if not member.name:lower():find(self.search, 1, true) then return false end
    end
    if self.onlyOnline and not member.online then return false end
    if self.noRole and member.role ~= nil then return false end
    if self.role and member.role ~= self.role then return false end
    return true
end
