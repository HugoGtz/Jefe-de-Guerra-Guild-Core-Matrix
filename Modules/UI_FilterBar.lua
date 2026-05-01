local addonName, ns = ...
ns.UI = ns.UI or {}

local CLASS_ORDER = {
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
    "SHAMAN", "MAGE", "WARLOCK", "DRUID",
}

local UI = {
    SIZE = {
        BAR_HEIGHT = 88,
        ROW1_TOP = -8,
        ROW2_TOP = -32,
        ROW3_TOP = -58,
        BTN_HEIGHT = 22,
        CLASS_BTN = 26,
        ROLE_CLASS_GAP = 12,
    },
    FONT = { ROW = "GameFontHighlightSmall" },
    COLOR = {
        BAR_BG = { 0.06, 0.06, 0.09, 0.94 },
        BTN_OFF = { 0.13, 0.13, 0.17, 1.0 },
        BTN_ON = { 0.22, 0.58, 0.82, 1.0 },
        BTN_HOVER = { 0.18, 0.18, 0.24, 1.0 },
        BTN_TEXT = { 0.95, 0.95, 0.98, 1 },
        BTN_CLEAR_OFF = { 0.22, 0.12, 0.12, 1.0 },
        BTN_CLEAR_ON = { 0.42, 0.18, 0.18, 1.0 },
        WHITE_TEX = "Interface\\Buttons\\WHITE8X8",
        SEP = { 0.28, 0.28, 0.36, 0.45 },
        EDGE = { 0.32, 0.32, 0.4, 1 },
    },
}

ns.UI.Filter = {
    search = "",
    onlyOnline = false,
    role = nil,
    noRole = false,
    onlyMine = nil,
    showUnassigned = false,
    classes = {},
    lfgPick = {},
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
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
Bar:SetBackdropColor(unpack(UI.COLOR.BAR_BG))
Bar:SetBackdropBorderColor(unpack(UI.COLOR.EDGE))

ns.UI.FilterBar = Bar

local Sep = Bar:CreateTexture(nil, "ARTWORK")
Sep:SetTexture(UI.COLOR.WHITE_TEX)
Sep:SetVertexColor(unpack(UI.COLOR.SEP))
Sep:SetHeight(1)

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

ns.UI.SearchBox = SearchBox

local function AttachToggleHover(btn)
    btn:SetScript("OnEnter", function(self)
        local F = ns.UI.Filter
        local on = false
        if self.key == "onlyMine" then
            on = ResolveOnlyMineDefault()
        elseif self.valueOn ~= nil then
            on = F[self.key] == self.valueOn
        else
            on = F[self.key] == true
        end
        if not on then
            self.bg:SetVertexColor(unpack(UI.COLOR.BTN_HOVER))
        end
        if self.OnTipEnter then self:OnTipEnter() end
    end)
    btn:SetScript("OnLeave", function(self)
        ns.UI.FilterBar:UpdateVisualState()
        GameTooltip:Hide()
    end)
end

local function MakeToggle(parent, key, valueOn)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetHeight(UI.SIZE.BTN_HEIGHT)

    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetTexture(UI.COLOR.WHITE_TEX)
    btn.bg:SetVertexColor(unpack(UI.COLOR.BTN_OFF))

    btn.text = btn:CreateFontString(nil, "OVERLAY", UI.FONT.ROW)
    btn.text:SetPoint("CENTER", 0, -0.5)
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

    AttachToggleHover(btn)
    return btn
end

local btnOnline = MakeToggle(Bar, "onlyOnline")
local btnMine = MakeToggle(Bar, "onlyMine")
btnMine:SetScript("OnEnter", function(self)
    local F = ns.UI.Filter
    local on = ResolveOnlyMineDefault()
    if not on then self.bg:SetVertexColor(unpack(UI.COLOR.BTN_HOVER)) end
end)
btnMine:SetScript("OnLeave", function()
    ns.UI.FilterBar:UpdateVisualState()
end)
btnMine:SetScript("OnClick", function()
    local resolved = ResolveOnlyMineDefault()
    ns.UI.Filter.onlyMine = not resolved
    ns.UI.FilterBar:UpdateVisualState()
    if ns.UI.Refresh then ns.UI:Refresh() end
end)
local btnUnassigned = MakeToggle(Bar, "showUnassigned")
local btnNoRole = MakeToggle(Bar, "noRole")

local function MakeRoleFilterToggle(roleCode, tipKey)
    local btn = CreateFrame("Button", nil, Bar)
    btn:SetSize(UI.SIZE.CLASS_BTN, UI.SIZE.CLASS_BTN)

    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetTexture(UI.COLOR.WHITE_TEX)
    btn.bg:SetVertexColor(unpack(UI.COLOR.BTN_OFF))

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(20, 20)
    btn.icon:SetPoint("CENTER", 0, 0)
    ns.UI:SetRolePortraitTexture(btn.icon, roleCode)

    btn.key = "role"
    btn.valueOn = roleCode
    btn.tipKey = tipKey

    btn:SetScript("OnClick", function(self)
        local cur = ns.UI.Filter[self.key]
        if cur == self.valueOn then
            ns.UI.Filter[self.key] = nil
        else
            ns.UI.Filter[self.key] = self.valueOn
        end
        ns.UI.FilterBar:UpdateVisualState()
        if ns.UI.Refresh then ns.UI:Refresh() end
    end)

    btn.OnTipEnter = function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ns.L[self.tipKey], 1, 1, 1)
        GameTooltip:AddLine(ns.L.FILTER_ROLE_TIP, 0.65, 0.65, 0.7, true)
        GameTooltip:Show()
    end

    btn:SetScript("OnEnter", function(self)
        local on = ns.UI.Filter.role == roleCode
        if not on then
            self.bg:SetVertexColor(unpack(UI.COLOR.BTN_HOVER))
        end
        self:OnTipEnter()
    end)
    btn:SetScript("OnLeave", function()
        ns.UI.FilterBar:UpdateVisualState()
        GameTooltip:Hide()
    end)

    return btn
end

local btnTanks = MakeRoleFilterToggle("T", "FILTER_TANKS")
local btnHealers = MakeRoleFilterToggle("H", "FILTER_HEALERS")
local btnDps = MakeRoleFilterToggle("D", "FILTER_DPS")

local classButtons = {}

local function LocalizedClassName(classFile)
    local m = _G.LOCALIZED_CLASS_NAMES_MALE and _G.LOCALIZED_CLASS_NAMES_MALE[classFile]
    if m then return m end
    local u = _G.LOCALIZED_CLASS_NAMES and _G.LOCALIZED_CLASS_NAMES[classFile]
    if u then return u end
    return classFile
end

local function MakeClassToggle(classFile)
    local btn = CreateFrame("Button", nil, Bar)
    btn:SetSize(UI.SIZE.CLASS_BTN, UI.SIZE.CLASS_BTN)

    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetTexture(UI.COLOR.WHITE_TEX)
    btn.bg:SetVertexColor(unpack(UI.COLOR.BTN_OFF))

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(20, 20)
    btn.icon:SetPoint("CENTER", 0, 0)
    ns.UI:SetClassCircleTexture(btn.icon, classFile)

    btn.classFile = classFile

    btn:SetScript("OnClick", function(self)
        local t = ns.UI.Filter.classes
        if t[self.classFile] then
            t[self.classFile] = nil
        else
            t[self.classFile] = true
        end
        ns.UI.FilterBar:UpdateVisualState()
        if ns.UI.Refresh then ns.UI:Refresh() end
    end)

    btn.OnTipEnter = function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(LocalizedClassName(self.classFile), 1, 1, 1)
        GameTooltip:AddLine(ns.L.FILTER_CLASS_TIP, 0.65, 0.65, 0.7, true)
        GameTooltip:Show()
    end

    btn:SetScript("OnEnter", function(self)
        local on = ns.UI.Filter.classes[self.classFile]
        if not on then
            self.bg:SetVertexColor(unpack(UI.COLOR.BTN_HOVER))
        end
        self:OnTipEnter()
    end)
    btn:SetScript("OnLeave", function()
        ns.UI.FilterBar:UpdateVisualState()
        GameTooltip:Hide()
    end)

    classButtons[#classButtons + 1] = btn
    return btn
end

for _, cf in ipairs(CLASS_ORDER) do
    MakeClassToggle(cf)
end

local btnClear = CreateFrame("Button", nil, Bar)
btnClear:SetHeight(UI.SIZE.BTN_HEIGHT)
btnClear.bg = btnClear:CreateTexture(nil, "BACKGROUND")
btnClear.bg:SetAllPoints()
btnClear.bg:SetTexture(UI.COLOR.WHITE_TEX)
btnClear.bg:SetVertexColor(unpack(UI.COLOR.BTN_CLEAR_OFF))
btnClear.text = btnClear:CreateFontString(nil, "OVERLAY", UI.FONT.ROW)
btnClear.text:SetPoint("CENTER", 0, -0.5)
btnClear.text:SetTextColor(unpack(UI.COLOR.BTN_TEXT))
btnClear:SetScript("OnEnter", function(self)
    self.bg:SetVertexColor(unpack(UI.COLOR.BTN_CLEAR_ON))
end)
btnClear:SetScript("OnLeave", function(self)
    self.bg:SetVertexColor(unpack(UI.COLOR.BTN_CLEAR_OFF))
end)
btnClear:SetScript("OnClick", function()
    ns.UI.Filter.search = ""
    ns.UI.Filter.onlyOnline = false
    ns.UI.Filter.noRole = false
    ns.UI.Filter.role = nil
    ns.UI.Filter.onlyMine = nil
    ns.UI.Filter.showUnassigned = false
    for k in pairs(ns.UI.Filter.classes) do
        ns.UI.Filter.classes[k] = nil
    end
    for k in pairs(ns.UI.Filter.lfgPick) do
        ns.UI.Filter.lfgPick[k] = nil
    end
    SearchBox:SetText("")
    ns.UI.FilterBar:UpdateVisualState()
    if ns.UI.Refresh then ns.UI:Refresh() end
end)

local layoutMode = "cores"

local function LayoutTogglesFull()
    btnClear:ClearAllPoints()
    btnClear:SetPoint("TOPRIGHT", Bar, "TOPRIGHT", -10, UI.SIZE.ROW1_TOP)

    SearchBox:ClearAllPoints()
    SearchBox:SetHeight(UI.SIZE.BTN_HEIGHT)
    SearchBox:SetPoint("TOPLEFT", Bar, "TOPLEFT", 14, UI.SIZE.ROW1_TOP)
    SearchBox:SetPoint("RIGHT", btnClear, "LEFT", -10, 0)

    Sep:ClearAllPoints()
    Sep:SetPoint("TOPLEFT", Bar, "TOPLEFT", 12, -52)
    Sep:SetPoint("TOPRIGHT", Bar, "TOPRIGHT", -12, -52)

    btnMine:ClearAllPoints()
    btnMine:SetPoint("TOPLEFT", Bar, "TOPLEFT", 14, UI.SIZE.ROW2_TOP)
    local prev = btnMine
    for _, b in ipairs({ btnUnassigned, btnOnline, btnNoRole }) do
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", prev, "TOPRIGHT", 4, 0)
        prev = b
    end

    btnTanks:ClearAllPoints()
    btnTanks:SetPoint("TOPLEFT", Bar, "TOPLEFT", 14, UI.SIZE.ROW3_TOP)
    prev = btnTanks
    for _, b in ipairs({ btnHealers, btnDps }) do
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", prev, "TOPRIGHT", 4, 0)
        prev = b
    end

    local firstClass = classButtons[1]
    if firstClass then
        firstClass:ClearAllPoints()
        firstClass:SetPoint("LEFT", btnDps, "RIGHT", UI.SIZE.ROLE_CLASS_GAP, 0)
        firstClass:SetPoint("TOP", btnDps, "TOP", 0, 0)
        for i = 2, #classButtons do
            local b = classButtons[i]
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", classButtons[i - 1], "TOPRIGHT", 4, 0)
        end
    end
end

local function FitToggles()
    local pad = 12
    for _, b in ipairs({ btnOnline, btnMine, btnUnassigned, btnNoRole, btnClear }) do
        local w = b.text:GetStringWidth() + pad
        if w < 32 then w = 32 end
        b:SetWidth(w)
    end
end

local function LayoutTogglesLFG()
    btnClear:ClearAllPoints()
    btnClear:SetPoint("TOPRIGHT", Bar, "TOPRIGHT", -10, UI.SIZE.ROW1_TOP)

    SearchBox:ClearAllPoints()
    SearchBox:SetHeight(UI.SIZE.BTN_HEIGHT)
    SearchBox:SetPoint("TOPLEFT", Bar, "TOPLEFT", 14, UI.SIZE.ROW1_TOP)
    SearchBox:SetPoint("RIGHT", btnClear, "LEFT", -10, 0)

    btnOnline:ClearAllPoints()
    btnOnline:SetPoint("TOPLEFT", Bar, "TOPLEFT", 14, UI.SIZE.ROW2_TOP)
end

local function FitLFGBar()
    local pad = 12
    for _, b in ipairs({ btnOnline, btnClear }) do
        local w = b.text:GetStringWidth() + pad
        if w < 32 then w = 32 end
        b:SetWidth(w)
    end
end

local function ApplyBarLayout()
    if layoutMode == "cores" then
        LayoutTogglesFull()
        FitToggles()
    else
        LayoutTogglesLFG()
        FitLFGBar()
    end
end

function ns.UI.FilterBar:SetCoreFiltersVisible(show)
    layoutMode = show and "cores" or "lfg"
    local vis = show and true or false
    btnMine:SetShown(vis)
    btnUnassigned:SetShown(vis)
    btnNoRole:SetShown(vis)
    btnTanks:SetShown(vis)
    btnHealers:SetShown(vis)
    btnDps:SetShown(vis)
    Sep:SetShown(vis)
    for _, b in ipairs(classButtons) do
        b:SetShown(vis)
    end
    Bar:SetHeight(show and UI.SIZE.BAR_HEIGHT or 52)
    ApplyBarLayout()
end

Bar:SetScript("OnSizeChanged", function()
    ApplyBarLayout()
end)

function ns.UI.FilterBar:UpdateVisualState()
    local F = ns.UI.Filter
    btnOnline.bg:SetVertexColor(unpack(F.onlyOnline and UI.COLOR.BTN_ON or UI.COLOR.BTN_OFF))
    btnMine.bg:SetVertexColor(unpack(ResolveOnlyMineDefault() and UI.COLOR.BTN_ON or UI.COLOR.BTN_OFF))
    btnUnassigned.bg:SetVertexColor(unpack(F.showUnassigned and UI.COLOR.BTN_ON or UI.COLOR.BTN_OFF))
    btnNoRole.bg:SetVertexColor(unpack(F.noRole and UI.COLOR.BTN_ON or UI.COLOR.BTN_OFF))
    btnTanks.bg:SetVertexColor(unpack(F.role == "T" and UI.COLOR.BTN_ON or UI.COLOR.BTN_OFF))
    btnHealers.bg:SetVertexColor(unpack(F.role == "H" and UI.COLOR.BTN_ON or UI.COLOR.BTN_OFF))
    btnDps.bg:SetVertexColor(unpack(F.role == "D" and UI.COLOR.BTN_ON or UI.COLOR.BTN_OFF))
    for _, btn in ipairs(classButtons) do
        local on = F.classes[btn.classFile]
        btn.bg:SetVertexColor(unpack(on and UI.COLOR.BTN_ON or UI.COLOR.BTN_OFF))
    end
end

function ns.UI.Filter:IsMineModeActive()
    return ResolveOnlyMineDefault()
end

function ns.UI.Filter:ShouldShowUnassigned()
    return self.showUnassigned == true
end

ns.Locale:RegisterCallback(function()
    SearchBox:SetText("")
    if SearchBox.SetTextInsets then SearchBox:SetTextInsets(4, 6, 0, 0) end
    btnOnline.text:SetText(ns.L.FILTER_ONLY_ONLINE)
    btnMine.text:SetText(ns.L.FILTER_MINE)
    btnUnassigned.text:SetText(ns.L.FILTER_UNASSIGNED)
    btnNoRole.text:SetText(ns.L.FILTER_NO_ROLE)
    btnClear.text:SetText(ns.L.FILTER_CLEAR)
    ns.UI:SetRolePortraitTexture(btnTanks.icon, "T")
    ns.UI:SetRolePortraitTexture(btnHealers.icon, "H")
    ns.UI:SetRolePortraitTexture(btnDps.icon, "D")
    for _, btn in ipairs(classButtons) do
        ns.UI:SetClassCircleTexture(btn.icon, btn.classFile)
    end
    ApplyBarLayout()
    ns.UI.FilterBar:UpdateVisualState()
end)

function ns.UI.Filter:Matches(member)
    if self.search and self.search ~= "" then
        if not member.name:lower():find(self.search, 1, true) then return false end
    end
    if self.onlyOnline and not member.online then return false end
    if self.noRole and member.role ~= nil then return false end
    if self.role and member.role ~= self.role then return false end
    if next(self.classes) then
        if not member.class or not self.classes[member.class] then return false end
    end
    return true
end
