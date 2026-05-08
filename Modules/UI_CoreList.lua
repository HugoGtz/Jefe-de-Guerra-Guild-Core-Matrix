local addonName, ns = ...
ns.UI = ns.UI or {}

local Theme = ns.Theme

local UI = {
    SPACING = { CARD = 12, ROW_GAP = 2, INNER = 10 },
    SIZE = {
        ROW_HEIGHT = 22,
        ACCENT_BAR = 3,
        CARD_PADDING = 14,
        HEADER_OFFSET_FULL = 100,
        HEADER_OFFSET_COMPACT = 70,
        HEADER_OFFSET_WITH_EDITOR = 158,
        TITLE_Y = -14,
        META_Y = -44,
        SCHED_Y = -72,
        INVITE_BTN_W = 84,
        EDIT_BTN_W = 60,
        TITLE_LEADER_MAX_W = 130,
        COMP_MAX_W = 110,
        WARNING_MAX_W = 140,
    },
    FONT = {
        HEADER = "GameFontNormalLarge",
        SUB = "GameFontDisableSmall",
        ROW = "GameFontHighlight",
        SMALL = "GameFontHighlight",
        COUNT = "GameFontNormal",
    },
    COLOR = {
        -- File-specific colors (not shared with other UI files)
        CARD_BG           = { 0.08, 0.08, 0.11, 0.88 },
        CARD_BG_UNASSIGNED = { 0.06, 0.06, 0.08, 0.78 },
        CARD_BORDER_WARN  = { 0.95, 0.55, 0.10, 1.0 },
        CARD_BORDER_CRIT  = { 0.95, 0.20, 0.20, 1.0 },
        TEXT_DIM          = { 0.62, 0.62, 0.66, 1.0 },
        TANK_TXT          = { 0.45, 0.62, 1.0, 1 },
        HEAL_TXT          = { 0.30, 0.85, 0.40, 1 },
        DPS_TXT           = { 0.95, 0.50, 0.40, 1 },
    },
    TYPE_COLOR = {
        C = { 0.45, 0.78, 1.00, 1 },
        B = { 0.82, 0.72, 0.38, 1 },
        U = { 0.55, 0.55, 0.60, 1 },
    },
    TARGET = { C = 25 },
}

local function ApplyMixin(target, mixin)
    for k, v in pairs(mixin) do target[k] = v end
    return target
end

local MainFrame = ns.UI.MainFrame
local FilterBar = ns.UI.FilterBar

local CoreListPanel = CreateFrame("Frame", "GCM_CoreListPanel", MainFrame)
CoreListPanel:SetPoint("TOPLEFT", FilterBar, "BOTTOMLEFT", 0, -4)
CoreListPanel:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -8, 8)
ns.UI.CoreListPanel = CoreListPanel

local Scroll = CreateFrame("ScrollFrame", "GCM_CoreListScroll", CoreListPanel, "UIPanelScrollFrameTemplate")
Scroll:SetPoint("TOPLEFT", 0, 0)
Scroll:SetPoint("BOTTOMRIGHT", -24, 0)

local Content = CreateFrame("Frame", nil, Scroll)
Content:SetSize(1, 1)
Scroll:SetScrollChild(Content)

local EmptyText = CoreListPanel:CreateFontString(nil, "OVERLAY", UI.FONT.ROW)
EmptyText:SetPoint("CENTER")
EmptyText:SetWidth(360)
EmptyText:SetJustifyH("CENTER")
EmptyText:SetTextColor(unpack(UI.COLOR.TEXT_DIM))  -- file-specific dim text
EmptyText:Hide()

local function ComputeComposition(members)
    local t, h, d, u = 0, 0, 0, 0
    for _, m in ipairs(members) do
        if m.role == "T" then t = t + 1
        elseif m.role == "H" then h = h + 1
        elseif m.role == "D" then d = d + 1
        else u = u + 1 end
    end
    return t, h, d, u
end

local function FormatComposition(t, h, d, u)
    local parts = {}
    parts[#parts + 1] = string.format("|cff73a0ff%dT|r", t)
    parts[#parts + 1] = string.format("|cff4ade80%dH|r", h)
    parts[#parts + 1] = string.format("|cffff8270%dD|r", d)
    if u > 0 then
        parts[#parts + 1] = string.format("|cff999999%d?|r", u)
    end
    return table.concat(parts, " ")
end

local function GetWarningLevel(typeCode, members, t, h)
    local target = UI.TARGET[typeCode]
    if not target then return nil end
    if t == 0 or h == 0 then return "crit" end
    if #members < math.floor(target * 0.7) then return "warn" end
    return nil
end

local PILL_W, PILL_H   = 34, 20
local SPIN_BTN_W       = 18
local SPIN_VAL_W       = 24
local EDITOR_ROW_GAP   =  6
local EDITOR_TOP_Y     = -96

local function MakeSpinner(parent, minVal, maxVal, step)
    step = step or 1
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(PILL_H)
    f:SetWidth(SPIN_BTN_W * 2 + SPIN_VAL_W + 4)
    f._val = minVal

    f.decBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.decBtn:SetSize(SPIN_BTN_W, PILL_H)
    f.decBtn:SetPoint("LEFT", 0, 0)
    f.decBtn:SetText("-")

    f.label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.label:SetSize(SPIN_VAL_W, PILL_H)
    f.label:SetPoint("LEFT", f.decBtn, "RIGHT", 2, 0)
    f.label:SetJustifyH("CENTER")

    f.incBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.incBtn:SetSize(SPIN_BTN_W, PILL_H)
    f.incBtn:SetPoint("LEFT", f.label, "RIGHT", 2, 0)
    f.incBtn:SetText("+")

    local function refresh() f.label:SetText(string.format("%02d", f._val)) end

    f.decBtn:SetScript("OnClick", function()
        f._val = f._val - step
        if f._val < minVal then f._val = maxVal end
        refresh()
    end)
    f.incBtn:SetScript("OnClick", function()
        f._val = f._val + step
        if f._val > maxVal then f._val = minVal end
        refresh()
    end)

    function f:SetValue(v)
        self._val = math.max(minVal, math.min(maxVal, tonumber(v) or minVal))
        if step > 1 then
            self._val = math.floor(self._val / step + 0.5) * step
            if self._val > maxVal then self._val = minVal end
        end
        refresh()
    end
    function f:GetValue() return self._val end

    refresh()
    return f
end

local function RefreshPill(p)
    if p.active then
        p:SetBackdropColor(0.20, 0.42, 0.80, 0.95)
        p:SetBackdropBorderColor(0.40, 0.65, 1.00, 1.00)
        p.label:SetTextColor(1, 1, 1, 1)
    else
        p:SetBackdropColor(0.10, 0.10, 0.14, 0.70)
        p:SetBackdropBorderColor(0.32, 0.32, 0.38, 0.80)
        p.label:SetTextColor(0.55, 0.55, 0.60, 1)
    end
end

local function BuildCardEditor(card)
    local e = CreateFrame("Frame", nil, card)
    e:SetPoint("TOPLEFT", card, "TOPLEFT", UI.SPACING.INNER + 8, EDITOR_TOP_Y)
    e:SetPoint("RIGHT", card, "RIGHT", -UI.SIZE.CARD_PADDING, 0)
    e:SetHeight(PILL_H + EDITOR_ROW_GAP + PILL_H)
    e:Hide()
    card.inlineEditor = e

    e.pills = {}
    for i = 1, 7 do
        local pill = CreateFrame("Button", nil, e, "BackdropTemplate")
        pill:SetSize(PILL_W, PILL_H)
        pill:SetBackdrop({
            bgFile   = Theme.TEX_WHITE,
            edgeFile = Theme.TEX_BORDER,
            edgeSize = 6,
            insets   = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        if i == 1 then
            pill:SetPoint("TOPLEFT", 0, 0)
        else
            pill:SetPoint("TOPLEFT", e.pills[i - 1], "TOPRIGHT", 3, 0)
        end
        pill.label = pill:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        pill.label:SetAllPoints()
        pill.label:SetJustifyH("CENTER")
        pill.dayIndex = i
        pill.active   = false
        pill:SetScript("OnClick", function(p)
            p.active = not p.active
            RefreshPill(p)
        end)
        RefreshPill(pill)
        e.pills[i] = pill
    end

    local timeRow = CreateFrame("Frame", nil, e)
    timeRow:SetPoint("TOPLEFT", 0, -(PILL_H + EDITOR_ROW_GAP))
    timeRow:SetPoint("RIGHT", 0, 0)
    timeRow:SetHeight(PILL_H)

    e.hourSpin = MakeSpinner(timeRow, 0, 23, 1)
    e.hourSpin:SetPoint("LEFT", 0, 0)

    local colon = timeRow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    colon:SetText(":")
    colon:SetPoint("LEFT", e.hourSpin, "RIGHT", 3, 0)
    colon:SetSize(8, PILL_H)

    e.minSpin = MakeSpinner(timeRow, 0, 55, 5)
    e.minSpin:SetPoint("LEFT", colon, "RIGHT", 3, 0)

    e.saveBtn = CreateFrame("Button", nil, timeRow, "UIPanelButtonTemplate")
    e.saveBtn:SetSize(65, PILL_H)
    e.saveBtn:SetPoint("RIGHT", 0, 0)

    e.cancelBtn = CreateFrame("Button", nil, timeRow, "UIPanelButtonTemplate")
    e.cancelBtn:SetSize(65, PILL_H)
    e.cancelBtn:SetPoint("RIGHT", e.saveBtn, "LEFT", -4, 0)

    e.noteBox = CreateFrame("EditBox", nil, timeRow, "InputBoxTemplate")
    e.noteBox:SetHeight(PILL_H)
    e.noteBox:SetPoint("LEFT",  e.minSpin,    "RIGHT", 8, 0)
    e.noteBox:SetPoint("RIGHT", e.cancelBtn,  "LEFT", -6, 0)
    e.noteBox:SetAutoFocus(false)
    e.noteBox:SetMaxLetters(60)

    e.saveBtn:SetScript("OnClick", function()
        if not ns.Notes or not ns.Notes:CanEditUI() then return end
        local days = {}
        for _, p in ipairs(e.pills) do
            if p.active then days[#days + 1] = p.dayIndex end
        end
        local coreKey = ns.Schedule:CoreKey(e.typeCode, e.coreId)
        if #days == 0 then
            ns.Schedule:Clear(coreKey, true)
        else
            ns.Schedule:Set(coreKey, {
                days   = days,
                hour   = e.hourSpin:GetValue(),
                minute = e.minSpin:GetValue(),
                note   = e.noteBox:GetText(),
            }, { broadcast = true })
        end
        e:Hide()
        card.editorOpen = false
        ns.UI:RefreshCoreList()
    end)

    e.cancelBtn:SetScript("OnClick", function()
        e:Hide()
        card.editorOpen = false
        ns.UI:RefreshCoreList()
    end)
end

local function OpenCardEditor(card, typeCode, coreId)
    local e = card.inlineEditor
    if not e then return end
    e.typeCode = typeCode
    e.coreId   = coreId

    local coreKey  = ns.Schedule:CoreKey(typeCode, coreId)
    local sched    = ns.Schedule:Get(coreKey)
    local activeDays = {}
    if sched and sched.days then
        for _, d in ipairs(sched.days) do activeDays[d] = true end
    end
    for _, p in ipairs(e.pills) do
        p.label:SetText(ns.UI:DayShort(p.dayIndex))
        p.active = activeDays[p.dayIndex] == true
        RefreshPill(p)
    end

    e.hourSpin:SetValue(sched and sched.hour   or 21)
    e.minSpin:SetValue( sched and sched.minute or  0)
    e.noteBox:SetText(  sched and sched.note   or "")
    e.noteBox:ClearFocus()
    e.saveBtn:SetText(ns.L.BTN_SAVE)
    e.cancelBtn:SetText(ns.L.BTN_CANCEL)

    e:Show()
    card.editorOpen = true
end

local CoreCardMixin = {}

function CoreCardMixin:Build()
    self:SetBackdrop({
        bgFile = Theme.TEX_WHITE,
        edgeFile = Theme.TEX_BORDER,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    self:SetBackdropColor(unpack(UI.COLOR.CARD_BG))
    self:SetBackdropBorderColor(unpack(Theme.BORDER_CARD))

    self.accent = self:CreateTexture(nil, "ARTWORK")
    self.accent:SetTexture(Theme.TEX_WHITE)
    self.accent:SetPoint("TOPLEFT", 4, -4)
    self.accent:SetPoint("BOTTOMLEFT", 4, 4)
    self.accent:SetWidth(UI.SIZE.ACCENT_BAR)

    self.toggle = CreateFrame("Button", nil, self)
    self.toggle:SetSize(18, 18)
    self.toggle:SetPoint("TOPLEFT", self.accent, "TOPRIGHT", 2, UI.SIZE.TITLE_Y)
    self.toggle.icon = self.toggle:CreateFontString(nil, "OVERLAY", UI.FONT.ROW)
    self.toggle.icon:SetAllPoints()
    self.toggle.icon:SetText("-")

    self.inviteBtn = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
    self.inviteBtn:SetSize(UI.SIZE.INVITE_BTN_W, 18)
    self.inviteBtn:SetPoint("TOPRIGHT", -UI.SIZE.CARD_PADDING, UI.SIZE.TITLE_Y)
    self.count = self:CreateFontString(nil, "OVERLAY", UI.FONT.COUNT)
    self.count:SetTextColor(unpack(Theme.BRAND_GOLD))
    self.count:SetPoint("RIGHT", self.inviteBtn, "LEFT", -8, 0)

    self.leader = self:CreateFontString(nil, "OVERLAY", UI.FONT.SMALL)
    self.leader:SetPoint("RIGHT", self.count, "LEFT", -10, 0)
    self.leader:SetJustifyH("RIGHT")
    self.leader:SetWordWrap(false)
    self.leader:SetText("")

    self.title = self:CreateFontString(nil, "OVERLAY", UI.FONT.HEADER)
    self.title:SetPoint("LEFT", self.toggle, "RIGHT", 6, 0)
    self.title:SetPoint("RIGHT", self.leader, "LEFT", -10, 0)
    self.title:SetJustifyH("LEFT")
    self.title:SetWordWrap(false)

    self.composition = self:CreateFontString(nil, "OVERLAY", UI.FONT.SMALL)
    self.composition:SetPoint("TOPLEFT", self.accent, "TOPRIGHT", UI.SPACING.INNER + 4, UI.SIZE.META_Y)
    self.composition:SetWidth(UI.SIZE.COMP_MAX_W)
    self.composition:SetJustifyH("LEFT")
    self.composition:SetWordWrap(false)

    self.warning = self:CreateFontString(nil, "OVERLAY", UI.FONT.SMALL)
    self.warning:SetPoint("TOPRIGHT", self, "TOPRIGHT", -UI.SIZE.CARD_PADDING, UI.SIZE.META_Y)
    self.warning:SetWidth(UI.SIZE.WARNING_MAX_W)
    self.warning:SetJustifyH("RIGHT")
    self.warning:SetTextColor(unpack(UI.COLOR.CARD_BORDER_WARN))  -- initial default, overridden in Update
    self.warning:SetWordWrap(false)
    self.warning:SetText("")

    self.editScheduleBtn = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
    self.editScheduleBtn:SetSize(UI.SIZE.EDIT_BTN_W, 18)
    self.editScheduleBtn:SetPoint("TOPRIGHT", self, "TOPRIGHT", -UI.SIZE.CARD_PADDING, UI.SIZE.SCHED_Y)
    self.editScheduleBtn:Hide()

    self.scheduleText = self:CreateFontString(nil, "OVERLAY", UI.FONT.SMALL)
    self.scheduleText:SetPoint("TOPLEFT", self.accent, "TOPRIGHT", UI.SPACING.INNER + 2, UI.SIZE.SCHED_Y - 2)
    self.scheduleText:SetPoint("RIGHT", self.editScheduleBtn, "LEFT", -10, 0)
    self.scheduleText:SetJustifyH("LEFT")
    self.scheduleText:SetWordWrap(false)
    self.scheduleText:SetTextColor(0.85, 0.85, 0.95, 1)

    self.separator = self:CreateTexture(nil, "ARTWORK")
    self.separator:SetTexture(Theme.TEX_WHITE)
    self.separator:SetVertexColor(unpack(Theme.SEP))
    self.separator:SetHeight(1)
    self.separator:SetPoint("TOPLEFT", self.accent, "TOPRIGHT", UI.SPACING.INNER, -UI.SIZE.HEADER_OFFSET_FULL)
    self.separator:SetPoint("RIGHT", -UI.SIZE.CARD_PADDING, 0)

    self.rowsParent = CreateFrame("Frame", nil, self)
    self.rowsParent:SetPoint("TOPLEFT", self.separator, "BOTTOMLEFT", 0, -4)
    self.rowsParent:SetPoint("RIGHT", -UI.SIZE.CARD_PADDING, 0)

    self.rows = {}

    self.toggle:SetScript("OnClick", function()
        if not self.collapseKey then return end
        local now = ns.Database:IsCollapsed(self.collapseKey)
        ns.Database:SetCollapsed(self.collapseKey, not now)
        ns.UI:RefreshCoreList()
    end)

    self.editorOpen = false
    BuildCardEditor(self)
end

function CoreCardMixin:GetRow(index)
    local row = self.rows[index]
    if not row then
        row = ns.UI:GetMemberRow(self.rowsParent)
        if index == 1 then
            row:SetPoint("TOPLEFT", self.rowsParent, "TOPLEFT", 4, 0)
            row:SetPoint("RIGHT", self.rowsParent, "RIGHT", -2, 0)
        else
            row:SetPoint("TOPLEFT", self.rows[index - 1], "BOTTOMLEFT", 0, -UI.SPACING.ROW_GAP)
            row:SetPoint("RIGHT", self.rowsParent, "RIGHT", -2, 0)
        end
        self.rows[index] = row
    end
    return row
end

function CoreCardMixin:HideRowsFrom(index)
    for i = index, #self.rows do
        if self.rows[i] then
            ns.UI:ReleaseRow(self.rows[i])
            self.rows[i] = nil
        end
    end
end

function CoreCardMixin:GetRaidLabel(typeCode)
    if typeCode == "U" then return ns.L.UNASSIGNED_TITLE end
    if typeCode == "B" then return ns.L.LABEL_BENCH end
    return ns.L.LABEL_CORE
end

local function CountOnline(members)
    local n = 0
    for _, m in ipairs(members) do if m.online then n = n + 1 end end
    return n
end

function CoreCardMixin:Update(typeCode, coreId, members, opts)
    opts = opts or {}
    self.collapseKey = opts.collapseKey
    self.accent:SetVertexColor(unpack(UI.TYPE_COLOR[typeCode] or UI.TYPE_COLOR.C))

    if opts.title then
        self.title:SetText(opts.title)
    elseif coreId then
        if typeCode == "B" then
            local nick = ns.Scanner and ns.Scanner.GetCoreDisplayName and ns.Scanner:GetCoreDisplayName(typeCode, coreId)
            if nick and nick ~= "" then
                self.title:SetText(string.format("%s · %s", ns.L.LABEL_BENCH, nick))
            else
                self.title:SetText(ns.L.LABEL_BENCH)
            end
        else
            local nick = ns.Scanner and ns.Scanner.GetCoreDisplayName and ns.Scanner:GetCoreDisplayName(typeCode, coreId)
            if nick and nick ~= "" then
                self.title:SetText(string.format("%s %d · %s", ns.L.LABEL_CORE, coreId, nick))
            else
                self.title:SetText(string.format("%s %d", ns.L.LABEL_CORE, coreId))
            end
        end
    else
        self.title:SetText(self:GetRaidLabel(typeCode))
    end

    local online = CountOnline(members)
    self.count:SetText(string.format("(%d|cff666666/|r%d)", online, #members))

    local schedLineVisible = false

    if typeCode == "U" then
        self:SetBackdropColor(unpack(UI.COLOR.CARD_BG_UNASSIGNED))
        self:SetBackdropBorderColor(unpack(Theme.BORDER_CARD))
        self.composition:SetText("")
        self.leader:SetText("")
        self.title:ClearAllPoints()
        self.title:SetPoint("LEFT", self.toggle, "RIGHT", 6, 0)
        self.title:SetPoint("RIGHT", self.count, "LEFT", -10, 0)
        self.warning:SetText("")
        self.inviteBtn:Hide()
        self.count:SetPoint("RIGHT", self.inviteBtn, "LEFT", -8, 0)
        self.scheduleText:SetText("")
        self.editScheduleBtn:Hide()
    else
        self:SetBackdropColor(unpack(UI.COLOR.CARD_BG))
        local t, h, d, u = ComputeComposition(members)
        self.composition:SetText(FormatComposition(t, h, d, u))

        local leads = {}
        for _, m in ipairs(members) do
            if m.lead then leads[#leads + 1] = m end
        end
        table.sort(leads, function(a, b) return a.name < b.name end)
        if #leads > 0 then
            local maxShow = 4
            local parts = {}
            for i = 1, math.min(#leads, maxShow) do
                local m = leads[i]
                local cr, cg, cb = ns.UI:GetClassColor(m.class)
                local short = m.name
                if #short > 10 then short = short:sub(1, 9) .. "." end
                parts[#parts + 1] = string.format("%s |cff%02x%02x%02x%s|r", ns.UI:GetRaidLeadIcon(), math.floor(cr * 255), math.floor(cg * 255), math.floor(cb * 255), short)
            end
            local extra = #leads - maxShow
            if extra > 0 then
                parts[#parts + 1] = string.format("|cff666666+%d|r", extra)
            end
            self.leader:SetText("|cffffd100" .. ns.L.CARD_LEADS_PREFIX .. "|r " .. table.concat(parts, " "))
            self.title:ClearAllPoints()
            self.title:SetPoint("LEFT", self.toggle, "RIGHT", 6, 0)
            self.title:SetPoint("RIGHT", self.leader, "LEFT", -10, 0)
        else
            self.leader:SetText("")
            self.title:ClearAllPoints()
            self.title:SetPoint("LEFT", self.toggle, "RIGHT", 6, 0)
            self.title:SetPoint("RIGHT", self.count, "LEFT", -10, 0)
        end

        local warnLevel = GetWarningLevel(typeCode, members, t, h)
        if typeCode == "B" then
            self:SetBackdropBorderColor(unpack(Theme.BORDER_CARD))
            self.warning:SetText("")
        elseif warnLevel == "crit" then
            self:SetBackdropBorderColor(unpack(UI.COLOR.CARD_BORDER_CRIT))
            self.warning:SetTextColor(unpack(UI.COLOR.CARD_BORDER_CRIT))  -- file-specific crit red
            self.warning:SetText(t == 0 and ns.L.WARN_NO_TANK or ns.L.WARN_NO_HEALER)
        elseif warnLevel == "warn" then
            self:SetBackdropBorderColor(unpack(UI.COLOR.CARD_BORDER_WARN))
            self.warning:SetTextColor(unpack(UI.COLOR.CARD_BORDER_WARN))  -- file-specific warn orange
            self.warning:SetText(ns.L.WARN_LOW_COUNT)
        else
            self:SetBackdropBorderColor(unpack(Theme.BORDER_CARD))
            self.warning:SetText("")
        end

        local coreKey = ns.Schedule and ns.Schedule:CoreKey(typeCode, coreId or 0) or nil

        self.count:SetPoint("RIGHT", self.inviteBtn, "LEFT", -8, 0)

        local nextSlot = nil
        if coreKey and ns.Schedule then
            nextSlot = ns.Schedule:GetNextSlot(coreKey)
        end

        local canEditSched = ns.Notes and ns.Notes:CanEditUI() and (coreId ~= nil)
        schedLineVisible = (nextSlot ~= nil) or canEditSched

        if schedLineVisible then
            if nextSlot then
                self.scheduleText:SetText("|cffffd100" .. ns.L.SCHED_NEXT .. "|r " .. ns.UI:FormatNextSlot(nextSlot))
            else
                self.scheduleText:SetText("|cff666666" .. ns.L.SCHED_NONE .. "|r")
            end
            self.scheduleText:Show()
        else
            self.scheduleText:SetText("")
            self.scheduleText:Hide()
        end

        if canEditSched then
            self.editScheduleBtn:SetText(self.editorOpen and "X" or ns.L.SCHED_EDIT_BTN)
            self.editScheduleBtn:Show()
            local tc, ci = typeCode, coreId
            self.editScheduleBtn:SetScript("OnClick", function()
                if self.editorOpen then
                    self.inlineEditor:Hide()
                    self.editorOpen = false
                else
                    OpenCardEditor(self, tc, ci)
                end
                ns.UI:RefreshCoreList()
            end)
        else
            self.editScheduleBtn:Hide()
            if self.editorOpen then
                self.inlineEditor:Hide()
                self.editorOpen = false
            end
        end

        self.scheduleText:ClearAllPoints()
        self.scheduleText:SetPoint("TOPLEFT", self.accent, "TOPRIGHT", UI.SPACING.INNER + 2, UI.SIZE.SCHED_Y - 2)
        if self.editScheduleBtn:IsShown() then
            self.scheduleText:SetPoint("RIGHT", self.editScheduleBtn, "LEFT", -10, 0)
        else
            self.scheduleText:SetPoint("RIGHT", self, "RIGHT", -UI.SIZE.CARD_PADDING, 0)
        end

        self.inviteBtn:Show()
        self.inviteBtn:SetText(ns.L.BTN_INVITE_ALL)
        self.inviteBtn:SetScript("OnEnter", function(invBtn)
            GameTooltip:SetOwner(invBtn, "ANCHOR_LEFT")
            GameTooltip:SetText(ns.L.INVITE_CARD_TOOLTIP_TITLE)
            GameTooltip:AddLine(ns.L.INVITE_CARD_TOOLTIP_BODY, 1, 1, 1, true)
            GameTooltip:AddLine(ns.L.INVITE_CARD_TOOLTIP_ML_HINT, 0.75, 0.75, 0.75, true)
            if coreKey and ns.Database and ns.Database.GetCoreLootMaster then
                local cur = ns.Database:GetCoreLootMaster(coreKey)
                if cur then
                    GameTooltip:AddLine(string.format(ns.L.MASTER_LOOT_CURRENT, cur), 0.4, 1, 0.4)
                else
                    GameTooltip:AddLine(ns.L.MASTER_LOOT_CURRENT_NONE, 0.75, 0.75, 0.75)
                end
            end
            GameTooltip:Show()
        end)
        self.inviteBtn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        self.inviteBtn:SetScript("OnClick", function()
            if ns.Scanner and ns.Scanner.ParseGuildNotesNow then
                ns.Scanner:ParseGuildNotesNow({})
            end
            if coreKey and ns.RaidFormation and ns.RaidFormation.SetWatchCore then
                ns.RaidFormation:SetWatchCore(coreKey)
            end
            local fullMembers = ns.Scanner:GetMembersForCore(typeCode, coreId)
            local invited, onlineInCore, permBlocked, diag = 0, 0, false, nil
            if ns.InviteTools and ns.InviteTools.InviteOnlineMembers then
                invited, onlineInCore, permBlocked, diag = ns.InviteTools:InviteOnlineMembers(fullMembers)
            end
            if invited == 0 and diag then
                ns.InviteTools:PrintInviteDiagnostics(coreId, diag, permBlocked)
            end
            if permBlocked then
                print(ns.L.BRAND_YELLOW .. " " .. ns.L.INVITE_NEED_PERMISSION)
            elseif invited > 0 then
                print(ns.L.BRAND_GREEN .. " " .. string.format(ns.L.INVITE_LOG, invited, coreId or 0))
            elseif onlineInCore > 0 then
                print(ns.L.BRAND_YELLOW .. " " .. string.format(ns.L.INVITE_NONE_ALREADY_GROUPED, coreId or 0))
            else
                print(ns.L.BRAND_YELLOW .. " " .. string.format(ns.L.INVITE_NONE, coreId or 0))
            end
            if invited > 0 and ns.RaidFormation and ns.RaidFormation.Begin and coreKey then
                ns.RaidFormation:Begin(coreKey, fullMembers, { invitedCount = invited })
            end
            local btn = self.inviteBtn
            if invited > 0 then
                btn:SetText(string.format(ns.L.INVITE_DONE_BTN, invited))
            end
            C_Timer.After(3, function()
                if btn and btn:IsShown() then
                    btn:SetText(ns.L.BTN_INVITE_ALL)
                end
            end)
        end)
    end

    local collapsed = self.collapseKey and ns.Database:IsCollapsed(self.collapseKey)

    if collapsed and self.editorOpen then
        self.inlineEditor:Hide()
        self.editorOpen = false
    end

    local headerOffset
    if self.editorOpen then
        headerOffset = UI.SIZE.HEADER_OFFSET_WITH_EDITOR
    else
        headerOffset = schedLineVisible and UI.SIZE.HEADER_OFFSET_FULL or UI.SIZE.HEADER_OFFSET_COMPACT
    end

    if self.inlineEditor then
        self.inlineEditor:SetShown(self.editorOpen)
    end

    self.separator:ClearAllPoints()
    self.separator:SetPoint("TOPLEFT", self.accent, "TOPRIGHT", UI.SPACING.INNER, -headerOffset)
    self.separator:SetPoint("RIGHT", -UI.SIZE.CARD_PADDING, 0)

    self.rowsParent:ClearAllPoints()
    self.rowsParent:SetPoint("TOPLEFT", self, "TOPLEFT", UI.SPACING.INNER + 8, -(headerOffset + 6))
    self.rowsParent:SetPoint("RIGHT", self, "RIGHT", -UI.SIZE.CARD_PADDING, 0)

    self.toggle.icon:SetText(collapsed and "+" or "-")

    if collapsed then
        self.rowsParent:Hide()
        self.separator:Hide()
        self:HideRowsFrom(1)
        self:SetHeight(headerOffset + 6)
    else
        self.rowsParent:Show()
        self.separator:Show()

        local rowContext
        if typeCode ~= "U" and coreId then
            rowContext = { typeCode = typeCode, coreId = coreId }
        end

        local visible = 0
        for _, m in ipairs(members) do
            visible = visible + 1
            local row = self:GetRow(visible)
            row:SetData(m, rowContext, visible)
        end
        self:HideRowsFrom(visible + 1)

        local rowHeightWithGap = UI.SIZE.ROW_HEIGHT + UI.SPACING.ROW_GAP
        local rowsHeight = (visible > 0) and (visible * rowHeightWithGap + 4) or 4
        self.rowsParent:SetHeight(rowsHeight)
        self:SetHeight(headerOffset + rowsHeight + UI.SIZE.CARD_PADDING)
    end

    self:Show()
end

local function NewCoreCard(parent)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    ApplyMixin(card, CoreCardMixin)
    card:Build()
    return card
end

local cardPool = {}

local function GetCard(index, parent)
    local card = cardPool[index]
    if not card then
        card = NewCoreCard(parent)
        cardPool[index] = card
    end
    return card
end

local function HideCardsFrom(index)
    for i = index, #cardPool do
        cardPool[i]:Hide()
    end
end

local function SortedKeys(map)
    local out = {}
    for k in pairs(map) do out[#out + 1] = tonumber(k) or k end
    table.sort(out)
    return out
end

local function FilterMembers(list)
    local out = {}
    for _, m in ipairs(list) do
        if ns.UI.Filter:Matches(m) then out[#out + 1] = m end
    end
    return out
end

local function PlayerBelongsToCore(typeCode, coreId, members)
    local me = UnitName("player")
    if not me then return false end
    for _, m in ipairs(members) do
        if m.name == me or Ambiguate(m.name or "", "none") == me then
            return true
        end
    end
    return false
end

function ns.UI:RefreshCoreList()
    if not ns.Scanner:HasAnyDiscovered() and #ns.Scanner:GetUnassignedMembers() == 0 then
        Scroll:Hide()
        HideCardsFrom(1)
        EmptyText:SetText(ns.L.EMPTY_DISCOVERED)
        EmptyText:Show()
        return
    end

    EmptyText:Hide()
    Scroll:Show()

    local discovered = ns.Scanner:GetDiscoveredCores()
    local order = { "C", "B" }
    local idx = 0
    local yOffset = 0
    local panelWidth = Scroll:GetWidth() - 4
    local renderedAny = false

    local onlyMine = ns.UI.Filter.IsMineModeActive and ns.UI.Filter:IsMineModeActive() or false
    local showUnassigned = ns.UI.Filter.ShouldShowUnassigned and ns.UI.Filter:ShouldShowUnassigned() or false

    for _, typeCode in ipairs(order) do
        local list = discovered[typeCode]
        if list and next(list) then
            for _, coreId in ipairs(SortedKeys(list)) do
                local members = ns.Scanner:GetMembersForCore(typeCode, coreId)

                if onlyMine and not PlayerBelongsToCore(typeCode, coreId, members) then
                else
                    local filtered = FilterMembers(members)

                    if #filtered > 0 or (ns.UI.Filter.search == "" and not ns.UI.Filter.onlyOnline and not ns.UI.Filter.noRole and ns.UI.Filter.role == nil) then
                        idx = idx + 1
                        local card = GetCard(idx, Content)
                        card:ClearAllPoints()
                        card:SetPoint("TOPLEFT", Content, "TOPLEFT", 2, yOffset)
                        card:SetPoint("RIGHT", Content, "TOPLEFT", panelWidth, 0)
                        card:Update(typeCode, coreId, filtered, {
                            collapseKey = string.format("%s%d", typeCode, coreId),
                        })
                        yOffset = yOffset - card:GetHeight() - UI.SPACING.CARD
                        renderedAny = true
                    end
                end
            end
        end
    end

    local unassigned = (showUnassigned and not onlyMine) and FilterMembers(ns.Scanner:GetUnassignedMembers()) or {}
    if #unassigned > 0 then
        idx = idx + 1
        local card = GetCard(idx, Content)
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", Content, "TOPLEFT", 2, yOffset)
        card:SetPoint("RIGHT", Content, "TOPLEFT", panelWidth, 0)
        card:Update("U", nil, unassigned, {
            collapseKey = "UNASSIGNED",
            title = ns.L.UNASSIGNED_TITLE,
        })
        yOffset = yOffset - card:GetHeight() - UI.SPACING.CARD
        renderedAny = true
    end

    HideCardsFrom(idx + 1)

    if not renderedAny then
        Scroll:Hide()
        EmptyText:SetText(ns.L.EMPTY_FILTERED)
        EmptyText:Show()
    end

    Content:SetHeight(math.max(1, -yOffset + UI.SPACING.CARD))
    Content:SetWidth(panelWidth)
end

function ns.UI:Refresh()
    if ns.UI.SelfBar and ns.UI.SelfBar.Refresh then ns.UI.SelfBar:Refresh() end
    if ns.UI.ActivePanel == "lfg" then
        if ns.UI.RefreshLFGList then ns.UI:RefreshLFGList() end
    elseif ns.UI.ActivePanel == "prof" then
        if ns.UI.RefreshProfessions then ns.UI:RefreshProfessions() end
    elseif ns.UI.CoreListPanel and ns.UI.CoreListPanel:IsShown() then
        ns.UI:RefreshCoreList()
    end
end

function ns.UI:SetMainPanel(mode)
    ns.UI.ActivePanel = mode
    local isCores = (mode == "cores")
    local isLfg = (mode == "lfg")
    local isProf = (mode == "prof")
    if ns.UI.FilterBar and ns.UI.FilterBar.SetCoreFiltersVisible then
        ns.UI.FilterBar:SetCoreFiltersVisible(isCores and "cores" or "lfg")
    end
    local coresPanel = ns.UI.CoreListPanel or _G.GCM_CoreListPanel
    local lfgPanel = ns.UI.LFGPanel or _G.GCM_LFGPanel
    local profPanel = ns.UI.ProfPanel or _G.GCM_ProfPanel
    if coresPanel then
        coresPanel:SetShown(isCores)
        if isCores then coresPanel:Show() else coresPanel:Hide() end
    end
    if lfgPanel then
        lfgPanel:SetShown(isLfg)
        if isLfg then lfgPanel:Show() else lfgPanel:Hide() end
    end
    if profPanel then
        profPanel:SetShown(isProf)
        if isProf then profPanel:Show() else profPanel:Hide() end
    end
    local mf = ns.UI.MainFrame
    local mainLvl = (mf and mf.GetFrameLevel and mf:GetFrameLevel()) or 0
    if coresPanel and coresPanel.SetFrameLevel then
        coresPanel:SetFrameLevel(mainLvl + (isCores and 50 or 5))
    end
    if lfgPanel and lfgPanel.SetFrameLevel then
        lfgPanel:SetFrameLevel(mainLvl + (isLfg and 50 or 5))
    end
    if profPanel and profPanel.SetFrameLevel then
        profPanel:SetFrameLevel(mainLvl + (isProf and 50 or 5))
    end
    if isCores and coresPanel and coresPanel.Raise then pcall(function() coresPanel:Raise() end) end
    if isLfg and lfgPanel and lfgPanel.Raise then pcall(function() lfgPanel:Raise() end) end
    if isProf and profPanel and profPanel.Raise then pcall(function() profPanel:Raise() end) end
    if ns.UI.UpdateMainTabs then ns.UI:UpdateMainTabs(mode) end
    if ns.UI.BringMainTabsToFront then ns.UI.BringMainTabsToFront() end
    if ns.UI.Refresh then ns.UI:Refresh() end
end

MainFrame:HookScript("OnShow", function()
    if ns.UI.SetMainPanel and ns.UI.ActivePanel then
        ns.UI:SetMainPanel(ns.UI.ActivePanel)
    elseif ns.UI.Refresh then
        ns.UI:Refresh()
    end
end)
MainFrame:HookScript("OnSizeChanged", function() ns.UI:Refresh() end)

ns.Locale:RegisterCallback(function() ns.UI:RefreshCoreList() end)
