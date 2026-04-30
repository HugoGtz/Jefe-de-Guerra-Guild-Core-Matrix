local addonName, ns = ...
ns.UI = ns.UI or {}

local UI = {
    SPACING = { CARD = 14, ROW_GAP = 4, INNER = 10 },
    SIZE = {
        ROW_HEIGHT = 22,
        ACCENT_BAR = 3,
        CARD_PADDING = 14,
        HEADER_OFFSET_FULL = 100,
        HEADER_OFFSET_COMPACT = 70,
        TITLE_Y = -14,
        META_Y = -44,
        SCHED_Y = -72,
        INVITE_BTN_W = 84,
        EDIT_BTN_W = 60,
        SIGNUP_BTN_W = 84,
        TITLE_LEADER_MAX_W = 130,
        COMP_MAX_W = 110,
        WARNING_MAX_W = 140,
        SIGNUP_COUNT_W = 80,
    },
    FONT = {
        HEADER = "GameFontNormalLarge",
        SUB = "GameFontDisableSmall",
        ROW = "GameFontHighlight",
        SMALL = "GameFontHighlight",
        COUNT = "GameFontNormal",
    },
    COLOR = {
        CARD_BG = { 0.08, 0.08, 0.10, 0.85 },
        CARD_BG_UNASSIGNED = { 0.06, 0.06, 0.08, 0.75 },
        CARD_BORDER = { 0.20, 0.20, 0.25, 1.0 },
        CARD_BORDER_WARN = { 0.95, 0.55, 0.10, 1.0 },
        CARD_BORDER_CRIT = { 0.95, 0.20, 0.20, 1.0 },
        TEXT_DIM = { 0.65, 0.65, 0.65, 1.0 },
        TEXT_ACCENT = { 1.0, 0.82, 0.0, 1.0 },
        SEPARATOR = { 0.25, 0.25, 0.30, 0.6 },
        TANK_TXT = { 0.45, 0.62, 1.0, 1 },
        HEAL_TXT = { 0.30, 0.85, 0.40, 1 },
        DPS_TXT = { 0.95, 0.50, 0.40, 1 },
        WHITE_TEX = "Interface\\Buttons\\WHITE8X8",
        TOOLTIP_BORDER = "Interface\\Tooltips\\UI-Tooltip-Border",
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

local CoreListPanel = CreateFrame("Frame", nil, MainFrame)
CoreListPanel:SetPoint("TOPLEFT", FilterBar, "BOTTOMLEFT", 0, -6)
CoreListPanel:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -10, 10)

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
EmptyText:SetTextColor(unpack(UI.COLOR.TEXT_DIM))
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

local CoreCardMixin = {}

function CoreCardMixin:Build()
    self:SetBackdrop({
        bgFile = UI.COLOR.WHITE_TEX,
        edgeFile = UI.COLOR.TOOLTIP_BORDER,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    self:SetBackdropColor(unpack(UI.COLOR.CARD_BG))
    self:SetBackdropBorderColor(unpack(UI.COLOR.CARD_BORDER))

    self.accent = self:CreateTexture(nil, "ARTWORK")
    self.accent:SetTexture(UI.COLOR.WHITE_TEX)
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
    self.count:SetTextColor(unpack(UI.COLOR.TEXT_ACCENT))
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
    self.warning:SetTextColor(unpack(UI.COLOR.CARD_BORDER_WARN))
    self.warning:SetWordWrap(false)
    self.warning:SetText("")

    self.editScheduleBtn = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
    self.editScheduleBtn:SetSize(UI.SIZE.EDIT_BTN_W, 18)
    self.editScheduleBtn:SetPoint("TOPRIGHT", self, "TOPRIGHT", -UI.SIZE.CARD_PADDING, UI.SIZE.SCHED_Y)
    self.editScheduleBtn:Hide()

    self.signupBtn = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
    self.signupBtn:SetSize(UI.SIZE.SIGNUP_BTN_W, 18)
    self.signupBtn:SetPoint("TOPRIGHT", self.editScheduleBtn, "TOPLEFT", -4, 0)
    self.signupBtn:Hide()

    self.signupCount = self:CreateFontString(nil, "OVERLAY", UI.FONT.SMALL)
    self.signupCount:SetPoint("RIGHT", self.signupBtn, "LEFT", -8, 0)
    self.signupCount:SetWidth(UI.SIZE.SIGNUP_COUNT_W)
    self.signupCount:SetJustifyH("RIGHT")
    self.signupCount:SetWordWrap(false)

    self.scheduleText = self:CreateFontString(nil, "OVERLAY", UI.FONT.SMALL)
    self.scheduleText:SetPoint("TOPLEFT", self.accent, "TOPRIGHT", UI.SPACING.INNER + 2, UI.SIZE.SCHED_Y - 2)
    self.scheduleText:SetPoint("RIGHT", self.signupCount, "LEFT", -10, 0)
    self.scheduleText:SetJustifyH("LEFT")
    self.scheduleText:SetWordWrap(false)
    self.scheduleText:SetTextColor(0.85, 0.85, 0.95, 1)

    self.separator = self:CreateTexture(nil, "ARTWORK")
    self.separator:SetTexture(UI.COLOR.WHITE_TEX)
    self.separator:SetVertexColor(unpack(UI.COLOR.SEPARATOR))
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
end

function CoreCardMixin:GetRow(index)
    local row = self.rows[index]
    if not row then
        row = ns.UI:NewMemberRow(self.rowsParent)
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
        self.rows[i]:Hide()
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
        self:SetBackdropBorderColor(unpack(UI.COLOR.CARD_BORDER))
        self.composition:SetText("")
        self.leader:SetText("")
        self.title:ClearAllPoints()
        self.title:SetPoint("LEFT", self.toggle, "RIGHT", 6, 0)
        self.title:SetPoint("RIGHT", self.count, "LEFT", -10, 0)
        self.warning:SetText("")
        self.inviteBtn:Hide()
        self.scheduleText:SetText("")
        self.editScheduleBtn:Hide()
        self.signupBtn:Hide()
        self.signupCount:SetText("")
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
            self:SetBackdropBorderColor(unpack(UI.COLOR.CARD_BORDER))
            self.warning:SetText("")
        elseif warnLevel == "crit" then
            self:SetBackdropBorderColor(unpack(UI.COLOR.CARD_BORDER_CRIT))
            self.warning:SetTextColor(unpack(UI.COLOR.CARD_BORDER_CRIT))
            self.warning:SetText(t == 0 and ns.L.WARN_NO_TANK or ns.L.WARN_NO_HEALER)
        elseif warnLevel == "warn" then
            self:SetBackdropBorderColor(unpack(UI.COLOR.CARD_BORDER_WARN))
            self.warning:SetTextColor(unpack(UI.COLOR.CARD_BORDER_WARN))
            self.warning:SetText(ns.L.WARN_LOW_COUNT)
        else
            self:SetBackdropBorderColor(unpack(UI.COLOR.CARD_BORDER))
            self.warning:SetText("")
        end

        local coreKey = ns.Schedule and ns.Schedule:CoreKey(typeCode, coreId or 0) or nil
        local slots = coreKey and ns.Schedule and ns.Schedule:GetSlots(coreKey) or {}
        local nextSlot, nextSlotIdx = nil, nil
        if coreKey and ns.Schedule then
            local s = ns.Schedule:GetNextSlot(coreKey)
            nextSlot = s
            for i, slot in ipairs(slots) do
                if slot == s then nextSlotIdx = i break end
            end
        end

        local canEditSched = ns.Notes and ns.Notes:CanEditUI() and coreId
        schedLineVisible = (nextSlot ~= nil) or (canEditSched == true)

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
            self.editScheduleBtn:SetText(ns.L.SCHED_EDIT_BTN)
            self.editScheduleBtn:Show()
            self.editScheduleBtn:SetScript("OnClick", function()
                ns.UI:OpenScheduleEditor(typeCode, coreId)
            end)
        else
            self.editScheduleBtn:Hide()
        end

        self.signupBtn:ClearAllPoints()
        if canEditSched then
            self.signupBtn:SetPoint("TOPRIGHT", self.editScheduleBtn, "TOPLEFT", -4, 0)
        else
            self.signupBtn:SetPoint("TOPRIGHT", self, "TOPRIGHT", -UI.SIZE.CARD_PADDING, UI.SIZE.SCHED_Y)
        end

        if nextSlotIdx and ns.Signups then
            local myState = ns.Signups:GetMyState(coreKey, nextSlotIdx)
            self.signupBtn:Show()
            self.signupBtn:SetText(ns.UI:GetSignupButtonLabel(myState))
            self.signupBtn:SetScript("OnClick", function(s)
                ns.UI:ShowSignupMenu(coreKey, nextSlotIdx, s)
            end)
            local counts = ns.Signups:CountForSlot(coreKey, nextSlotIdx)
            self.signupCount:SetText(string.format("|cff4ade80%d|r |cff666666·|r |cffffd100%d|r |cff666666·|r |cffff5555%d|r", counts.yes, counts.maybe, counts.no))
            self.signupCount:Show()
        else
            self.signupBtn:Hide()
            self.signupCount:SetText("")
            self.signupCount:Hide()
        end

        self.scheduleText:ClearAllPoints()
        self.scheduleText:SetPoint("TOPLEFT", self.accent, "TOPRIGHT", UI.SPACING.INNER + 2, UI.SIZE.SCHED_Y - 2)
        if self.signupCount:IsShown() then
            self.scheduleText:SetPoint("RIGHT", self.signupCount, "LEFT", -10, 0)
        elseif self.editScheduleBtn:IsShown() then
            self.scheduleText:SetPoint("RIGHT", self.editScheduleBtn, "LEFT", -10, 0)
        else
            self.scheduleText:SetPoint("RIGHT", self, "RIGHT", -UI.SIZE.CARD_PADDING, 0)
        end

        self.inviteBtn:Show()
        self.inviteBtn:SetText(ns.L.BTN_INVITE_ALL)
        self.inviteBtn:SetScript("OnClick", function()
            local invited = 0
            local me = UnitName("player")
            for _, m in ipairs(members) do
                if m.online and m.name ~= me then
                    InviteUnit(m.name)
                    invited = invited + 1
                end
            end
            if invited > 0 then
                print(ns.L.BRAND_GREEN .. " " .. string.format(ns.L.INVITE_LOG, invited, coreId or 0))
            else
                print(ns.L.BRAND_YELLOW .. " " .. string.format(ns.L.INVITE_NONE, coreId or 0))
            end
        end)
    end

    local headerOffset = schedLineVisible and UI.SIZE.HEADER_OFFSET_FULL or UI.SIZE.HEADER_OFFSET_COMPACT
    self.separator:ClearAllPoints()
    self.separator:SetPoint("TOPLEFT", self.accent, "TOPRIGHT", UI.SPACING.INNER, -headerOffset)
    self.separator:SetPoint("RIGHT", -UI.SIZE.CARD_PADDING, 0)

    self.rowsParent:ClearAllPoints()
    self.rowsParent:SetPoint("TOPLEFT", self, "TOPLEFT", UI.SPACING.INNER + 8, -(headerOffset + 6))
    self.rowsParent:SetPoint("RIGHT", self, "RIGHT", -UI.SIZE.CARD_PADDING, 0)

    local collapsed = self.collapseKey and ns.Database:IsCollapsed(self.collapseKey)
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
            row:SetData(m, rowContext)
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
    if CoreListPanel:IsShown() then
        ns.UI:RefreshCoreList()
    end
end

ns.UI.CoreListPanel = CoreListPanel

MainFrame:HookScript("OnShow", function() ns.UI:RefreshCoreList() end)
MainFrame:HookScript("OnSizeChanged", function() ns.UI:RefreshCoreList() end)

ns.Locale:RegisterCallback(function() ns.UI:RefreshCoreList() end)
