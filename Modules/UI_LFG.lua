local addonName, ns = ...
ns.UI = ns.UI or {}

local MainFrame = ns.UI.MainFrame
local FilterBar  = ns.UI.FilterBar

local Theme = ns.Theme

local UI = {
    ROW_H       = 36,
    ROW_H_DETAIL = 50,
    STALE_AGE   = 4 * 3600,
    HEADER_H    = 54,
    HEADER_H_GROUP = 72,
    FOOTER_H    = 110,
}

local TAG_COLOR = {
    HC    = { 0.75, 0.20, 0.20, 1.0 },
    ND    = { 0.16, 0.52, 0.22, 1.0 },
    RAID  = { 0.70, 0.42, 0.06, 1.0 },
    PVP   = { 0.48, 0.22, 0.70, 1.0 },
    CRAFT = { 0.62, 0.56, 0.08, 1.0 },
    QU    = { 0.18, 0.38, 0.70, 1.0 },
    MI    = { 0.32, 0.32, 0.38, 1.0 },
}

local MODE_BG = {
    LFG = { 0.12, 0.48, 0.18, 1.0 },
    LFM = { 0.52, 0.42, 0.06, 1.0 },
}

local tagOrder = { "HC", "ND", "RAID", "PVP", "CRAFT", "QU", "MI" }

ns.UI.ActivePanel = ns.UI.ActivePanel or "cores"

local myTagSelection = {}
local myMode = "LFG"
local filterHideStale = false

local function FormatAge(seconds)
    if not seconds or seconds <= 0 then return "" end
    if seconds < 120   then return ns.L.LFG_AGE_NOW end
    if seconds < 3600  then return string.format(ns.L.LFG_AGE_MIN,  math.floor(seconds / 60)) end
    if seconds < 86400 then return string.format(ns.L.LFG_AGE_HOUR, math.floor(seconds / 3600)) end
    return string.format(ns.L.LFG_AGE_DAY, math.floor(seconds / 86400))
end

local function MakePillBackdrop()
    return {
        edgeFile = Theme.TEX_BORDER,
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    }
end

-- ─── Panel ───────────────────────────────────────────────────────────────────

local LFGPanel = CreateFrame("Frame", "GCM_LFGPanel", MainFrame)
LFGPanel:SetPoint("TOPLEFT",     FilterBar, "BOTTOMLEFT",  0,  -4)
LFGPanel:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -8,  8)
LFGPanel:Hide()
ns.UI.LFGPanel = LFGPanel

LFGPanel:SetScript("OnShow", function()
    if ns.UI.RefreshLFGList then ns.UI:RefreshLFGList() end
    local _once = CreateFrame("Frame", nil, UIParent)
    _once:SetScript("OnUpdate", function(self)
        self:SetScript("OnUpdate", nil)
        if LFGPanel:IsShown() and ns.UI.RefreshLFGList then
            ns.UI:RefreshLFGList()
        end
    end)
end)

-- ─── Header bar ──────────────────────────────────────────────────────────────

local header = CreateFrame("Frame", nil, LFGPanel, "BackdropTemplate")
header:SetPoint("TOPLEFT",  0, 0)
header:SetPoint("TOPRIGHT", 0, 0)
header:SetHeight(UI.HEADER_H)
header:SetBackdrop({
    bgFile = Theme.TEX_WHITE,
    edgeFile = Theme.TEX_BORDER,
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
header:SetBackdropColor(0.07, 0.06, 0.09, 0.96)
header:SetBackdropBorderColor(unpack(Theme.BORDER_MAIN))

local headerTitle = header:CreateFontString(nil, "OVERLAY", Theme.FONT_NORMAL)
headerTitle:SetPoint("TOPLEFT", 10, -9)
headerTitle:SetJustifyH("LEFT")
headerTitle:SetTextColor(1.0, 0.88, 0.22, 1)

local headerCount = header:CreateFontString(nil, "OVERLAY", Theme.FONT_SMALL)
headerCount:SetPoint("TOPRIGHT", -10, -9)
headerCount:SetJustifyH("RIGHT")
headerCount:SetTextColor(0.55, 0.55, 0.62, 1)

-- group strip line (shown only when in a group, expands header)
local groupStrip = header:CreateFontString(nil, "OVERLAY", Theme.FONT_SMALL)
groupStrip:SetPoint("TOPLEFT",  header, "TOPLEFT",  10, -44)
groupStrip:SetPoint("TOPRIGHT", header, "TOPRIGHT", -10, -44)
groupStrip:SetJustifyH("LEFT")
groupStrip:SetTextColor(0.58, 0.58, 0.65, 1)
groupStrip:Hide()

-- tag filter pill row (y = -28 from header top)
local tagFilterButtons = {}

local function UpdateFilterTagVisual(btn)
    local on = ns.UI.Filter.lfgPick[btn.code] == true
    btn.bg:SetVertexColor(unpack(on and Theme.BTN_ON or Theme.BTN_OFF))
    if btn.SetBackdropBorderColor then
        if on then
            btn:SetBackdropBorderColor(0.22, 0.52, 0.82, 0.85)
        else
            btn:SetBackdropBorderColor(0.22, 0.22, 0.30, 0.55)
        end
    end
end

local function MakeFilterTagBtn(code)
    local btn = CreateFrame("Button", nil, header, "BackdropTemplate")
    btn:SetHeight(18)
    btn:SetWidth(40)
    btn.code = code
    btn:SetBackdrop(MakePillBackdrop())
    btn:SetBackdropBorderColor(0.22, 0.22, 0.30, 0.55)
    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints(btn)
    btn.bg:SetTexture(Theme.TEX_WHITE)
    btn.bg:SetVertexColor(unpack(Theme.BTN_OFF))
    btn.txt = btn:CreateFontString(nil, "OVERLAY", Theme.FONT_SMALL)
    btn.txt:SetPoint("CENTER", 0, -0.5)
    btn.txt:SetTextColor(unpack(Theme.BTN_TEXT))
    btn:SetScript("OnClick", function(self)
        if ns.UI.Filter.lfgPick[self.code] then
            ns.UI.Filter.lfgPick[self.code] = nil
        else
            ns.UI.Filter.lfgPick[self.code] = true
        end
        UpdateFilterTagVisual(self)
        if ns.UI.Refresh then ns.UI:Refresh() end
    end)
    btn:SetScript("OnEnter", function(self)
        if not ns.UI.Filter.lfgPick[self.code] then
            self.bg:SetVertexColor(unpack(Theme.BTN_HOVER))
            self:SetBackdropBorderColor(0.32, 0.32, 0.44, 0.80)
        end
    end)
    btn:SetScript("OnLeave", function(self)
        UpdateFilterTagVisual(self)
    end)
    tagFilterButtons[code] = btn
    return btn
end

for _, code in ipairs(tagOrder) do MakeFilterTagBtn(code) end

-- hide-stale toggle pill
local btnHideStale = CreateFrame("Button", nil, header, "BackdropTemplate")
btnHideStale:SetHeight(18)
btnHideStale:SetWidth(58)
btnHideStale:SetBackdrop(MakePillBackdrop())
btnHideStale:SetBackdropBorderColor(0.22, 0.22, 0.30, 0.55)
btnHideStale.bg = btnHideStale:CreateTexture(nil, "BACKGROUND")
btnHideStale.bg:SetAllPoints(btnHideStale)
btnHideStale.bg:SetTexture(Theme.TEX_WHITE)
btnHideStale.bg:SetVertexColor(unpack(Theme.BTN_OFF))
btnHideStale.txt = btnHideStale:CreateFontString(nil, "OVERLAY", Theme.FONT_SMALL)
btnHideStale.txt:SetPoint("CENTER", 0, -0.5)
btnHideStale.txt:SetTextColor(unpack(Theme.BTN_TEXT))
btnHideStale:SetScript("OnClick", function()
    filterHideStale = not filterHideStale
    btnHideStale.bg:SetVertexColor(unpack(filterHideStale and Theme.BTN_ON or Theme.BTN_OFF))
    if ns.UI.Refresh then ns.UI:Refresh() end
end)
btnHideStale:SetScript("OnEnter", function(self)
    if not filterHideStale then self.bg:SetVertexColor(unpack(Theme.BTN_HOVER)) end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(ns.L.LFG_STALE_FILTER_TIP, 0.75, 0.75, 0.8, true)
    GameTooltip:Show()
end)
btnHideStale:SetScript("OnLeave", function(self)
    self.bg:SetVertexColor(unpack(filterHideStale and Theme.BTN_ON or Theme.BTN_OFF))
    GameTooltip:Hide()
end)

local headerSep = header:CreateTexture(nil, "ARTWORK")
headerSep:SetTexture(Theme.TEX_WHITE)
headerSep:SetVertexColor(unpack(Theme.SEP))
headerSep:SetHeight(1)
headerSep:SetPoint("BOTTOMLEFT",  header, "BOTTOMLEFT",  4, 0)
headerSep:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -4, 0)

local function LayoutHeaderTagRow()
    local tagRowY = -28
    local prev = nil
    for _, code in ipairs(tagOrder) do
        local btn = tagFilterButtons[code]
        if btn then
            btn:ClearAllPoints()
            if prev then
                btn:SetPoint("TOPLEFT", prev, "TOPRIGHT", 4, 0)
            else
                btn:SetPoint("TOPLEFT", header, "TOPLEFT", 10, tagRowY)
            end
            prev = btn
        end
    end
    btnHideStale:ClearAllPoints()
    if prev then
        btnHideStale:SetPoint("TOPLEFT", prev, "TOPRIGHT", 10, 0)
    else
        btnHideStale:SetPoint("TOPLEFT", header, "TOPLEFT", 10, -28)
    end
end

-- ─── Group helpers ────────────────────────────────────────────────────────────

local function LfgInAnyGroup()
    if IsInGroup and IsInGroup() then return true end
    if IsInRaid  and IsInRaid()  then return true end
    local pm = GetNumPartyMembers and GetNumPartyMembers() or 0
    return (tonumber(pm) or 0) > 0
end

local function LfgBuildGroupUnits()
    local units = {}
    if not LfgInAnyGroup() then return units, nil end
    if IsInRaid and IsInRaid() then
        local n = tonumber(GetNumRaidMembers and GetNumRaidMembers() or 0) or 0
        for i = 1, n do
            local u = "raid" .. i
            if UnitExists(u) and (not UnitIsPlayer or UnitIsPlayer(u)) then
                units[#units + 1] = u
            end
        end
        return units, "raid"
    end
    if UnitExists("player") then units[#units + 1] = "player" end
    local pm = tonumber(GetNumPartyMembers and GetNumPartyMembers() or 0) or 0
    for i = 1, pm do
        local u = "party" .. i
        if UnitExists(u) and (not UnitIsPlayer or UnitIsPlayer(u)) then
            units[#units + 1] = u
        end
    end
    return units, "party"
end

local function LfgUnitNameKey(u)
    if not UnitExists(u) then return "" end
    local full = UnitFullName and UnitFullName(u) or nil
    if full and full ~= "" then
        return Ambiguate and Ambiguate(full, "none") or full:match("^([^%-]+)") or full
    end
    local n = UnitName(u)
    if not n then return "" end
    return Ambiguate and Ambiguate(n, "none") or n:match("^([^%-]+)") or n
end

local function LfgUnitIsLeader(u)
    if UnitIsGroupLeader and UnitIsGroupLeader(u) then return true end
    if UnitIsPartyLeader and UnitIsPartyLeader(u) then return true end
    return false
end

local function RefreshGroupStrip()
    local units, kind = LfgBuildGroupUnits()
    if not kind then
        groupStrip:Hide()
        header:SetHeight(UI.HEADER_H)
        return
    end
    local parts = {}
    if kind == "raid" then
        groupStrip:SetText(string.format(ns.L.LFG_GROUP_RAID, #units))
    else
        local cap = 6
        for i, u in ipairs(units) do
            if i > cap then
                parts[#parts + 1] = string.format(ns.L.LFG_GROUP_MORE, #units - cap)
                break
            end
            local nm = UnitName(u) or "?"
            local _, cf = UnitClass(u)
            if type(cf) ~= "string" or cf == "" then cf = "WARRIOR" end
            local r, g, b = ns.UI:GetClassColor(cf)
            local col = string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
            local entry = col .. nm .. "|r"
            if LfgUnitIsLeader(u) then
                entry = ns.UI:GetRaidLeadIcon() .. entry
            end
            parts[#parts + 1] = entry
        end
        local label = (kind == "raid") and ns.L.LFG_GROUP_RAID or ns.L.LFG_GROUP_PARTY
        label = string.format(label, #units)
        groupStrip:SetText(label .. ": " .. table.concat(parts, ", "))
    end
    groupStrip:Show()
    header:SetHeight(UI.HEADER_H_GROUP)
end

-- ─── Footer ──────────────────────────────────────────────────────────────────

local footer = CreateFrame("Frame", nil, LFGPanel, "BackdropTemplate")
footer:SetPoint("BOTTOMLEFT",  4,  6)
footer:SetPoint("BOTTOMRIGHT", -4, 6)
footer:SetHeight(UI.FOOTER_H)
footer:SetBackdrop({
    bgFile = Theme.TEX_WHITE,
    edgeFile = Theme.TEX_BORDER,
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
footer:SetBackdropColor(0.09, 0.08, 0.11, 0.97)
footer:SetBackdropBorderColor(unpack(Theme.BORDER_MAIN))

local footerSep = footer:CreateTexture(nil, "ARTWORK")
footerSep:SetTexture(Theme.TEX_WHITE)
footerSep:SetVertexColor(unpack(Theme.SEP))
footerSep:SetHeight(1)
footerSep:SetPoint("TOPLEFT",  footer, "TOPLEFT",  4, 0)
footerSep:SetPoint("TOPRIGHT", footer, "TOPRIGHT", -4, 0)

-- Row 1: "My Status" label + mode toggle pills + clear button
local footerStatusLbl = footer:CreateFontString(nil, "OVERLAY", Theme.FONT_NORMAL)
footerStatusLbl:SetPoint("TOPLEFT", 10, -10)
footerStatusLbl:SetJustifyH("LEFT")
footerStatusLbl:SetTextColor(0.88, 0.88, 0.94, 1)

local footerTagButtons = {}

local function UpdateFooterTagVisual(btn)
    local on = myTagSelection[btn.code] == true
    btn.bg:SetVertexColor(unpack(on and Theme.BTN_ON or Theme.BTN_OFF))
    if btn.SetBackdropBorderColor then
        if on then
            btn:SetBackdropBorderColor(0.22, 0.52, 0.82, 0.85)
        else
            btn:SetBackdropBorderColor(0.22, 0.22, 0.30, 0.55)
        end
    end
end

local function MakeFooterTagBtn(code)
    local btn = CreateFrame("Button", nil, footer, "BackdropTemplate")
    btn:SetHeight(18)
    btn:SetWidth(40)
    btn.code = code
    btn:SetBackdrop(MakePillBackdrop())
    btn:SetBackdropBorderColor(0.22, 0.22, 0.30, 0.55)
    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints(btn)
    btn.bg:SetTexture(Theme.TEX_WHITE)
    btn.bg:SetVertexColor(unpack(Theme.BTN_OFF))
    btn.txt = btn:CreateFontString(nil, "OVERLAY", Theme.FONT_SMALL)
    btn.txt:SetPoint("CENTER", 0, -0.5)
    btn.txt:SetTextColor(unpack(Theme.BTN_TEXT))
    btn:SetScript("OnClick", function(self)
        if myTagSelection[self.code] then
            myTagSelection[self.code] = nil
        else
            myTagSelection[self.code] = true
        end
        UpdateFooterTagVisual(self)
    end)
    btn:SetScript("OnEnter", function(self)
        if not myTagSelection[self.code] then
            self.bg:SetVertexColor(unpack(Theme.BTN_HOVER))
            self:SetBackdropBorderColor(0.32, 0.32, 0.44, 0.80)
        end
    end)
    btn:SetScript("OnLeave", function(self)
        UpdateFooterTagVisual(self)
    end)
    footerTagButtons[code] = btn
    return btn
end

for _, code in ipairs(tagOrder) do MakeFooterTagBtn(code) end

local function MakeModeBtn(label, modeValue)
    local btn = CreateFrame("Button", nil, footer, "BackdropTemplate")
    btn:SetHeight(20)
    btn:SetWidth(48)
    btn.modeValue = modeValue
    btn:SetBackdrop(MakePillBackdrop())
    btn:SetBackdropBorderColor(0.25, 0.25, 0.32, 0.70)
    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints(btn)
    btn.bg:SetTexture(Theme.TEX_WHITE)
    btn.bg:SetVertexColor(unpack(Theme.BTN_OFF))
    btn.txt = btn:CreateFontString(nil, "OVERLAY", Theme.FONT_SMALL)
    btn.txt:SetPoint("CENTER", 1, -0.5)
    btn.txt:SetText(label)
    btn.txt:SetTextColor(unpack(Theme.BTN_TEXT))
    return btn
end

local btnModeLFG = MakeModeBtn("LFG", "LFG")
local btnModeLFM = MakeModeBtn("LFM", "LFM")

local function UpdateModeVisual()
    if myMode == "LFM" then
        btnModeLFG.bg:SetVertexColor(unpack(Theme.BTN_OFF))
        if btnModeLFG.SetBackdropBorderColor then
            btnModeLFG:SetBackdropBorderColor(0.25, 0.25, 0.32, 0.70)
        end
        btnModeLFM.bg:SetVertexColor(unpack(Theme.BTN_LFM_ON))
        if btnModeLFM.SetBackdropBorderColor then
            btnModeLFM:SetBackdropBorderColor(0.58, 0.48, 0.12, 0.90)
        end
    else
        btnModeLFG.bg:SetVertexColor(unpack(Theme.BTN_LFG_ON))
        if btnModeLFG.SetBackdropBorderColor then
            btnModeLFG:SetBackdropBorderColor(0.14, 0.52, 0.22, 0.90)
        end
        btnModeLFM.bg:SetVertexColor(unpack(Theme.BTN_OFF))
        if btnModeLFM.SetBackdropBorderColor then
            btnModeLFM:SetBackdropBorderColor(0.25, 0.25, 0.32, 0.70)
        end
    end
end

btnModeLFG:SetScript("OnClick", function() myMode = "LFG"; UpdateModeVisual() end)
btnModeLFM:SetScript("OnClick", function() myMode = "LFM"; UpdateModeVisual() end)
for _, btn in ipairs({ btnModeLFG, btnModeLFM }) do
    btn:SetScript("OnEnter", function(self)
        if myMode ~= self.modeValue then self.bg:SetVertexColor(unpack(Theme.BTN_HOVER)) end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local key = self.modeValue == "LFM" and "LFG_MODE_LFM_TIP" or "LFG_MODE_LFG_TIP"
        GameTooltip:SetText(ns.L[key] or self.modeValue, 0.85, 0.85, 0.9, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        UpdateModeVisual()
        GameTooltip:Hide()
    end)
end

local clearBtn = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
clearBtn:SetSize(58, 20)
clearBtn:SetScript("OnClick", function()
    if ns.LFG and ns.LFG.ClearMine then ns.LFG:ClearMine() end
    wipe(myTagSelection)
    myMode = "LFG"
    UpdateModeVisual()
    for _, code in ipairs(tagOrder) do
        local btn = footerTagButtons[code]
        if btn then
            btn.bg:SetVertexColor(unpack(Theme.BTN_OFF))
            if btn.SetBackdropBorderColor then
                btn:SetBackdropBorderColor(0.22, 0.22, 0.30, 0.55)
            end
        end
    end
end)

-- Row 2: tag selection pills (y=-36)
local function LayoutFooterTagRow()
    local prev = nil
    for _, code in ipairs(tagOrder) do
        local btn = footerTagButtons[code]
        if btn then
            btn:ClearAllPoints()
            if prev then
                btn:SetPoint("TOPLEFT", prev, "TOPRIGHT", 4, 0)
            else
                btn:SetPoint("TOPLEFT", footer, "TOPLEFT", 10, -36)
            end
            prev = btn
        end
    end
end

-- Row 3: detail label + editbox + broadcast button (y=-62)
local detailLbl = footer:CreateFontString(nil, "OVERLAY", Theme.FONT_SMALL)
detailLbl:SetPoint("TOPLEFT", 10, -64)
detailLbl:SetJustifyH("LEFT")
detailLbl:SetTextColor(0.55, 0.55, 0.62, 1)

local detailEdit = CreateFrame("EditBox", nil, footer, "InputBoxTemplate")
detailEdit:SetHeight(20)
detailEdit:SetPoint("TOPLEFT",  footer, "TOPLEFT",   10,   -82)
detailEdit:SetPoint("TOPRIGHT", footer, "TOPRIGHT", -124,  -82)
detailEdit:SetAutoFocus(false)
detailEdit:SetMaxLetters(120)
detailEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
detailEdit:SetScript("OnEnterPressed",  function(self) self:ClearFocus() end)

local detailFocusGlow = footer:CreateTexture(nil, "BACKGROUND")
detailFocusGlow:SetPoint("TOPLEFT",     detailEdit, "TOPLEFT",     -2,  2)
detailFocusGlow:SetPoint("BOTTOMRIGHT", detailEdit, "BOTTOMRIGHT",  2, -2)
detailFocusGlow:SetTexture(Theme.TEX_WHITE)
detailFocusGlow:SetVertexColor(0.22, 0.50, 0.82, 0.12)
detailFocusGlow:Hide()
detailEdit:SetScript("OnEditFocusGained", function() detailFocusGlow:Show() end)
detailEdit:SetScript("OnEditFocusLost",   function() detailFocusGlow:Hide() end)

local applyBtn = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
applyBtn:SetSize(110, 20)
applyBtn:SetPoint("TOPRIGHT", footer, "TOPRIGHT", -8, -82)
applyBtn:SetScript("OnClick", function()
    local codes = {}
    for _, code in ipairs(tagOrder) do
        if myTagSelection[code] then codes[#codes + 1] = code end
    end
    table.sort(codes)
    local det = detailEdit:GetText() or ""
    if ns.LFG and ns.LFG.SetMine then
        ns.LFG:SetMine(codes, det, myMode)
    end
end)

-- ─── Group roster watch ───────────────────────────────────────────────────────

local lfgGroupWatch = CreateFrame("Frame")
lfgGroupWatch:RegisterEvent("GROUP_ROSTER_UPDATE")
lfgGroupWatch:RegisterEvent("RAID_ROSTER_UPDATE")
lfgGroupWatch:SetScript("OnEvent", function()
    if LFGPanel:IsShown() and ns.UI.RefreshLFGList then
        ns.UI:RefreshLFGList()
    end
end)

-- ─── Scroll + content ────────────────────────────────────────────────────────

local Scroll = CreateFrame("ScrollFrame", "GCM_LFGScroll", LFGPanel, "UIPanelScrollFrameTemplate")
Scroll:SetPoint("TOPLEFT",     header, "BOTTOMLEFT",  0,  -2)
Scroll:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT",   -26,  4)

local Content = CreateFrame("Frame", nil, Scroll)
Content:SetSize(1, 1)
Scroll:SetScrollChild(Content)

local EmptyText = LFGPanel:CreateFontString(nil, "OVERLAY", Theme.FONT_ROW)
EmptyText:SetPoint("CENTER", Scroll, "CENTER", -8, 0)
EmptyText:SetWidth(340)
EmptyText:SetJustifyH("CENTER")
EmptyText:SetTextColor(0.50, 0.50, 0.58, 1)
EmptyText:Hide()

local function LfgLayoutZOrder()
    if not LFGPanel.GetFrameLevel then return end
    local pl = LFGPanel:GetFrameLevel() or 0
    if header.SetFrameLevel  then header:SetFrameLevel(pl + 55) end
    if footer.SetFrameLevel  then footer:SetFrameLevel(pl + 50) end
    if Scroll.SetFrameLevel  then Scroll:SetFrameLevel(pl + 12) end
    if EmptyText.SetFrameLevel then EmptyText:SetFrameLevel(pl + 65) end
end

-- ─── Row pool ─────────────────────────────────────────────────────────────────

local rows = {}

-- Per-row tag pill pool: each row stores a list of pill frames
local function GetRowTagPills(row, count)
    row._pills = row._pills or {}
    for i = #row._pills + 1, count do
        local pill = CreateFrame("Frame", nil, row)
        pill:SetHeight(14)
        pill.bg = pill:CreateTexture(nil, "BACKGROUND")
        pill.bg:SetAllPoints()
        pill.bg:SetTexture(Theme.TEX_WHITE)
        pill.bg:SetVertexColor(0.25, 0.25, 0.32, 1)
        pill.txt = pill:CreateFontString(nil, "OVERLAY", Theme.FONT_SMALL)
        pill.txt:SetPoint("CENTER", 0, -0.5)
        pill.txt:SetTextColor(0.92, 0.92, 0.96, 1)
        row._pills[i] = pill
    end
    for i = count + 1, #row._pills do
        row._pills[i]:Hide()
    end
    return row._pills
end

local function RowTooltip(self)
    local m = self.member
    if not m then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local r, g, b = ns.UI:GetClassColor(m.class)
    GameTooltip:SetText(m.name, r, g, b)
    local modeLabel = ns.L["LFG_MODE_" .. (m.lfgMode or "LFG")] or (m.lfgMode or "LFG")
    local mc = MODE_BG[m.lfgMode] or { 0.7, 0.7, 0.7, 1 }
    GameTooltip:AddLine(modeLabel, mc[1] + 0.2, mc[2] + 0.2, mc[3] + 0.2)
    if ns.Roles then
        local role = ns.Roles:GetEffectiveRole(m.name, m.class)
        if role then
            local roleStr = (role == "T" and ns.L.ROLE_TANK) or (role == "H" and ns.L.ROLE_HEAL) or ns.L.ROLE_DPS
            GameTooltip:AddLine(ns.UI:GetRoleIcon(role) .. " " .. roleStr, 0.8, 0.85, 1)
        end
    end
    local tagStr = table.concat(m.lfg or {}, ", ")
    if tagStr ~= "" then
        GameTooltip:AddLine(string.format(ns.L.LFG_ROW_TAGS, tagStr), 0.75, 0.85, 1)
    end
    if m.lfgDetail and m.lfgDetail ~= "" then
        GameTooltip:AddLine(m.lfgDetail, 0.8, 0.85, 0.92, true)
    end
    if m.lfgAge and m.lfgAge > 0 then
        GameTooltip:AddLine(FormatAge(m.lfgAge), 0.55, 0.55, 0.6)
    end
    if m.publicNote and m.publicNote ~= "" then
        GameTooltip:AddLine(m.publicNote, 0.65, 0.65, 0.7, true)
    end
    GameTooltip:Show()
end

local function GetRow(i)
    if rows[i] then return rows[i] end
    local f = CreateFrame("Button", nil, Content)
    f:SetHeight(UI.ROW_H)

    -- zebra stripe
    f.stripe = f:CreateTexture(nil, "BACKGROUND")
    f.stripe:SetDrawLayer("BACKGROUND", -2)
    f.stripe:SetAllPoints()
    f.stripe:SetTexture(Theme.TEX_WHITE)
    f.stripe:SetVertexColor(unpack(Theme.ROW_STRIPE))

    -- hover highlight
    f.hoverBg = f:CreateTexture(nil, "BACKGROUND")
    f.hoverBg:SetDrawLayer("BACKGROUND", -1)
    f.hoverBg:SetAllPoints()
    f.hoverBg:SetTexture(Theme.TEX_WHITE)
    f.hoverBg:SetVertexColor(unpack(Theme.ROW_HOVER))
    f.hoverBg:Hide()

    -- bottom separator line
    f.sep = f:CreateTexture(nil, "ARTWORK")
    f.sep:SetTexture(Theme.TEX_WHITE)
    f.sep:SetVertexColor(unpack(Theme.SEP))
    f.sep:SetHeight(1)
    f.sep:SetPoint("BOTTOMLEFT",  f, "BOTTOMLEFT",  0, 0)
    f.sep:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)

    -- online dot (6x6)
    f.dot = f:CreateTexture(nil, "OVERLAY")
    f.dot:SetTexture(Theme.TEX_WHITE)
    f.dot:SetSize(6, 6)
    f.dot:SetPoint("LEFT", 8, 2)

    -- role icon (text glyph)
    f.roleIcon = f:CreateFontString(nil, "OVERLAY", Theme.FONT_ROW)
    f.roleIcon:SetPoint("LEFT", f.dot, "RIGHT", 6, 0)
    f.roleIcon:SetWidth(16)
    f.roleIcon:SetJustifyH("LEFT")

    -- class icon (text glyph)
    f.clsIcon = f:CreateFontString(nil, "OVERLAY", Theme.FONT_ROW)
    f.clsIcon:SetPoint("LEFT", f.roleIcon, "RIGHT", 2, 0)
    f.clsIcon:SetWidth(16)
    f.clsIcon:SetJustifyH("LEFT")

    -- age label (rightmost, fixed width)
    f.age = f:CreateFontString(nil, "OVERLAY", Theme.FONT_SMALL)
    f.age:SetPoint("RIGHT", -8, 2)
    f.age:SetWidth(28)
    f.age:SetJustifyH("RIGHT")
    f.age:SetTextColor(0.42, 0.42, 0.50, 1)

    -- mode badge pill (right of age)
    f.modePill = CreateFrame("Frame", nil, f)
    f.modePill:SetSize(36, 14)
    f.modePill:SetPoint("RIGHT", f.age, "LEFT", -4, 0)
    f.modePill.bg = f.modePill:CreateTexture(nil, "BACKGROUND")
    f.modePill.bg:SetAllPoints()
    f.modePill.bg:SetTexture(Theme.TEX_WHITE)
    f.modePill.bg:SetVertexColor(unpack(Theme.BTN_LFG_ON))
    f.modePill.txt = f.modePill:CreateFontString(nil, "OVERLAY", Theme.FONT_SMALL)
    f.modePill.txt:SetPoint("CENTER", 0, -0.5)
    f.modePill.txt:SetTextColor(0.92, 0.98, 0.92, 1)

    -- tag pills container anchor (right of modePill)
    f.tagAnchor = f.modePill

    -- name (main, fills middle)
    f.name = f:CreateFontString(nil, "OVERLAY", Theme.FONT_ROW)
    f.name:SetPoint("LEFT",  f.clsIcon, "RIGHT", 6, 2)
    f.name:SetJustifyH("LEFT")

    -- detail sub-line (optional second line, smaller)
    f.detail = f:CreateFontString(nil, "OVERLAY", Theme.FONT_SMALL)
    f.detail:SetPoint("BOTTOMLEFT", f.name, "BOTTOMLEFT", 0, -14)
    f.detail:SetJustifyH("LEFT")
    f.detail:SetTextColor(0.52, 0.52, 0.60, 1)
    f.detail:Hide()

    f:SetScript("OnEnter", function(s)
        s.hoverBg:Show()
        RowTooltip(s)
    end)
    f:SetScript("OnLeave", function(s)
        s.hoverBg:Hide()
        GameTooltip:Hide()
    end)
    f:RegisterForClicks("AnyUp")
    f:SetScript("OnClick", function(s, btn)
        if btn == "RightButton" and s.member and ns.UI.ShowMemberMenu then
            ns.UI:ShowMemberMenu(s.member, s, { lfgQuick = true })
        end
    end)

    rows[i] = f
    return f
end

local function HideRowsFrom(start)
    for i = start, #rows do
        rows[i]:Hide()
    end
end

-- ─── Data collection ──────────────────────────────────────────────────────────

local function CacheToMember(name, entry)
    local age = (entry.lfgUpdatedAt and entry.lfgUpdatedAt > 0)
        and (time() - entry.lfgUpdatedAt) or nil
    return {
        name         = name,
        rosterName   = entry.rosterName or name,
        class        = entry.class,
        level        = entry.level,
        online       = entry.online,
        zone         = entry.zone,
        publicNote   = entry.publicNote,
        lastOnline   = entry.lastOnline,
        role         = nil,
        lead         = false,
        hasConflict  = false,
        conflictCount = 0,
        lfg          = entry.lfg,
        lfgDetail    = entry.lfgDetail or "",
        lfgMode      = entry.lfgMode   or "LFG",
        lfgAge       = age,
    }
end

local function LfgPickMatches(member)
    local pick, anyPick = ns.UI.Filter.lfgPick, false
    for _ in pairs(pick) do anyPick = true; break end
    if not anyPick then return true end
    for _, code in ipairs(member.lfg or {}) do
        if pick[code] then return true end
    end
    return false
end

local function CountAnyLFG()
    local n = 0
    if not ns.Cache then return 0 end
    for _, entry in pairs(ns.Cache) do
        if (entry.lfg and #entry.lfg > 0) or (entry.lfgDetail or "") ~= "" then n = n + 1 end
    end
    return n
end

local function CollectLFGMembers()
    local out = {}
    if not ns.Cache then return out end
    for name, entry in pairs(ns.Cache) do
        local tags = entry.lfg
        local det  = entry.lfgDetail or ""
        if (tags and #tags > 0) or det ~= "" then
            local m = CacheToMember(name, entry)
            if not (filterHideStale and m.lfgAge and m.lfgAge > UI.STALE_AGE) then
                if LfgPickMatches(m) then
                    if not ns.UI.Filter.onlyOnline or m.online then
                        local s = ns.UI.Filter.search
                        local pass = not s or s == ""
                        if not pass then
                            pass = m.name:lower():find(s, 1, true)
                               or (m.lfgDetail or ""):lower():find(s, 1, true)
                        end
                        if pass then out[#out + 1] = m end
                    end
                end
            end
        end
    end
    table.sort(out, function(a, b)
        if a.online ~= b.online then return a.online and not b.online end
        local aa = a.lfgAge or math.huge
        local bb = b.lfgAge or math.huge
        if aa ~= bb then return aa < bb end
        return a.name < b.name
    end)
    return out
end

-- ─── Sync self from cache ─────────────────────────────────────────────────────

local function SyncSelfFromCache()
    local me = UnitName("player")
    if not me then return end
    local nk = Ambiguate and Ambiguate(me, "none") or me:match("^([^%-]+)") or me
    local entry = ns.Cache and ns.Cache[nk]
    wipe(myTagSelection)
    for _, c in ipairs(entry and entry.lfg or {}) do myTagSelection[c] = true end
    myMode = (entry and entry.lfgMode) or "LFG"
    detailEdit:SetText(entry and entry.lfgDetail or "")
    UpdateModeVisual()
    for _, code in ipairs(tagOrder) do
        local btn = footerTagButtons[code]
        if btn then UpdateFooterTagVisual(btn) end
    end
end

-- ─── Width helper ─────────────────────────────────────────────────────────────

local function ScrollInteriorWidth()
    local w = Scroll:GetWidth()
    if w and w >= 48 then return w - 8 end
    local pw = LFGPanel:GetWidth()
    if pw and pw >= 80 then return pw - 48 end
    local mw = MainFrame:GetWidth()
    if mw and mw >= 80 then return mw - 56 end
    return 400
end

-- ─── Main refresh ─────────────────────────────────────────────────────────────

function ns.UI:RefreshLFGList()
    if not LFGPanel:IsShown() then return end

    header:Show()
    footer:Show()
    Scroll:Show()

    -- Group strip (may expand header height)
    RefreshGroupStrip()

    -- Reanchor scroll below current header height
    Scroll:ClearAllPoints()
    Scroll:SetPoint("TOPLEFT",     header, "BOTTOMLEFT",  0,  -2)
    Scroll:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT",   -26,  4)

    -- Update header labels
    headerTitle:SetText(ns.L.LFG_PANEL_TITLE)

    local totalLFG = CountAnyLFG()
    if totalLFG > 0 then
        headerCount:SetText(string.format("%d listed", totalLFG))
    else
        headerCount:SetText("")
    end

    -- Update filter tag pill labels and widths
    for _, code in ipairs(tagOrder) do
        local btn = tagFilterButtons[code]
        if btn then
            local lbl = ns.L["LFG_TAG_" .. code] or code
            btn.txt:SetText(lbl)
            local w = math.max(32, btn.txt:GetStringWidth() + 12)
            btn:SetWidth(w)
            UpdateFilterTagVisual(btn)
        end
    end
    btnHideStale.txt:SetText(ns.L.LFG_STALE_FILTER)
    do
        local w = math.max(48, btnHideStale.txt:GetStringWidth() + 14)
        btnHideStale:SetWidth(w)
    end
    btnHideStale.bg:SetVertexColor(unpack(filterHideStale and Theme.BTN_ON or Theme.BTN_OFF))
    LayoutHeaderTagRow()

    -- Update footer labels and layout
    footerStatusLbl:SetText(ns.L.LFG_MODE_LABEL)

    -- Mode buttons anchored after status label
    btnModeLFG:ClearAllPoints()
    btnModeLFG:SetPoint("LEFT", footerStatusLbl, "RIGHT", 10, 0)
    btnModeLFM:ClearAllPoints()
    btnModeLFM:SetPoint("LEFT", btnModeLFG, "RIGHT", 4, 0)

    clearBtn:ClearAllPoints()
    clearBtn:SetPoint("TOPRIGHT", footer, "TOPRIGHT", -8, -8)
    clearBtn:SetHeight(20)
    clearBtn:SetText(ns.L.LFG_CLEAR_BTN)

    -- Footer tag pill labels
    for _, code in ipairs(tagOrder) do
        local btn = footerTagButtons[code]
        if btn then
            local lbl = ns.L["LFG_TAG_" .. code] or code
            btn.txt:SetText(lbl)
            local w = math.max(32, btn.txt:GetStringWidth() + 12)
            btn:SetWidth(w)
        end
    end
    LayoutFooterTagRow()

    detailLbl:SetText(ns.L.LFG_DETAIL_LABEL)
    applyBtn:SetText(ns.L.LFG_APPLY_MY_TAGS)

    SyncSelfFromCache()

    -- Populate member rows
    local members = CollectLFGMembers()
    local panelW  = math.max(40, ScrollInteriorWidth())

    if #members == 0 then
        EmptyText:Show()
        EmptyText:SetText(CountAnyLFG() == 0 and ns.L.LFG_EMPTY or ns.L.LFG_EMPTY_FILTERED)
        HideRowsFrom(1)
        Content:SetHeight(40)
        Content:SetWidth(math.max(1, panelW))
    else
        EmptyText:Hide()
        local y = 0
        for i, m in ipairs(members) do
            local hasDetail = m.lfgDetail and m.lfgDetail ~= ""
            local rowH = hasDetail and UI.ROW_H_DETAIL or UI.ROW_H
            local isStale = m.lfgAge and m.lfgAge > UI.STALE_AGE

            local row = GetRow(i)
            row.member = m
            row:SetHeight(rowH)
            row:SetPoint("TOPLEFT",  Content, "TOPLEFT",  2,      y)
            row:SetPoint("TOPRIGHT", Content, "TOPLEFT",  panelW, y)

            row.stripe:SetShown(i % 2 == 1)

            local alpha = isStale and 0.5 or 1.0

            -- online dot color
            local dr, dg, db = ns.UI:GetOnlineColor(m.online)
            row.dot:SetVertexColor(dr, dg, db, alpha)
            row.dot:SetPoint("LEFT", 8, hasDetail and 8 or 2)

            -- role icon
            local roleStr = ""
            if ns.Roles then
                local role = ns.Roles:GetEffectiveRole(m.name, m.class)
                if role then roleStr = ns.UI:GetRoleIcon(role) end
            end
            row.roleIcon:SetText(roleStr)
            row.roleIcon:SetAlpha(alpha)

            -- class icon
            row.clsIcon:SetText(ns.UI:GetClassIcon(m.class))
            row.clsIcon:SetAlpha(alpha)

            -- name (class colored)
            local r, g, b = ns.UI:GetClassColor(m.class)
            if not m.online then
                r, g, b = r * 0.55, g * 0.55, b * 0.55
            elseif isStale then
                r, g, b = r * 0.60, g * 0.60, b * 0.60
            end
            row.name:SetText(m.name)
            row.name:SetTextColor(r, g, b)
            row.name:SetAlpha(alpha)

            -- detail sub-line
            if hasDetail then
                row.detail:SetText(m.lfgDetail)
                row.detail:SetAlpha(alpha)
                row.detail:Show()
                row.name:SetPoint("LEFT", row.clsIcon, "RIGHT", 6, 6)
            else
                row.detail:Hide()
                row.name:SetPoint("LEFT", row.clsIcon, "RIGHT", 6, 0)
            end

            -- mode badge
            local mbc = MODE_BG[m.lfgMode] or MODE_BG.LFG
            row.modePill.bg:SetVertexColor(mbc[1], mbc[2], mbc[3], alpha)
            local modeLabel = ns.L["LFG_MODE_" .. (m.lfgMode or "LFG")] or (m.lfgMode or "LFG")
            row.modePill.txt:SetText(modeLabel)
            row.modePill:SetAlpha(alpha)

            -- age
            local ageStr = m.lfgAge and FormatAge(m.lfgAge) or ""
            row.age:SetText(ageStr)
            row.age:SetAlpha(alpha)

            -- tag pills
            local tagList = m.lfg or {}
            local pillCount = #tagList
            local pills = GetRowTagPills(row, pillCount)
            local pillRight = row.modePill
            for ti = pillCount, 1, -1 do
                local code = tagList[ti]
                local pill = pills[ti]
                local tc = TAG_COLOR[code] or { 0.30, 0.30, 0.36, 1 }
                pill.bg:SetVertexColor(tc[1], tc[2], tc[3], 0.88)
                pill.txt:SetText(code)
                local pw2 = math.max(24, pill.txt:GetStringWidth() + 8)
                pill:SetWidth(pw2)
                pill:ClearAllPoints()
                pill:SetPoint("RIGHT",  pillRight, "LEFT",  -4, 0)
                pill:SetPoint("TOP",    row,       "TOP",    0, hasDetail and -8 or -11)
                pill:SetAlpha(alpha)
                pill:Show()
                pillRight = pill
            end

            -- name right edge: stop before leftmost tag pill or modePill
            row.name:SetPoint("RIGHT", pillRight, "LEFT", -6, 0)

            row:Show()
            y = y - rowH - 1
        end

        HideRowsFrom(#members + 1)
        Content:SetHeight(math.max(1, -y))
        Content:SetWidth(math.max(1, panelW))
    end

    LfgLayoutZOrder()
end

ns.Locale:RegisterCallback(function()
    LayoutHeaderTagRow()
    if LFGPanel:IsShown() then ns.UI:RefreshLFGList() end
end)
