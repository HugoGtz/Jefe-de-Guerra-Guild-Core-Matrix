local addonName, ns = ...
ns.UI = ns.UI or {}

local MainFrame = ns.UI.MainFrame
local FilterBar = ns.UI.FilterBar

local UI = {
    ROW_H = 22,
    FONT_ROW = "GameFontHighlight",
    FONT_SMALL = "GameFontDisableSmall",
    WHITE = "Interface\\Buttons\\WHITE8X8",
}

ns.UI.ActivePanel = ns.UI.ActivePanel or "cores"

local tagOrder = { "HC", "ND", "QU", "MI" }

local LFGPanel = CreateFrame("Frame", nil, MainFrame)
LFGPanel:SetPoint("TOPLEFT", FilterBar, "BOTTOMLEFT", 0, -6)
LFGPanel:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -10, 10)
LFGPanel:Hide()

local toolbar = CreateFrame("Frame", nil, LFGPanel)
toolbar:SetPoint("TOPLEFT", 0, 0)
toolbar:SetPoint("TOPRIGHT", 0, 0)
toolbar:SetHeight(76)

local toolbarTitle = toolbar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
toolbarTitle:SetPoint("TOPLEFT", 6, -6)
toolbarTitle:SetJustifyH("LEFT")
toolbarTitle:SetTextColor(0.88, 0.88, 0.92, 1)

local hint = toolbar:CreateFontString(nil, "OVERLAY", UI.FONT_SMALL)
hint:SetPoint("TOPLEFT", toolbarTitle, "BOTTOMLEFT", 0, -6)
hint:SetPoint("TOPRIGHT", toolbar, "TOPRIGHT", -6, -6)
hint:SetJustifyH("LEFT")
hint:SetWordWrap(true)
hint:SetTextColor(0.55, 0.55, 0.62, 1)

local tagButtons = {}

local function UpdateTagBtnVisual(btn)
    local on = ns.UI.Filter.lfgPick[btn.code] == true
    if on then
        btn.bg:SetVertexColor(0.22, 0.58, 0.82, 1)
    else
        btn.bg:SetVertexColor(0.13, 0.13, 0.17, 1)
    end
end

local function LayoutTagRow()
    local prev = nil
    local y = -52
    for _, code in ipairs(tagOrder) do
        local btn = tagButtons[code]
        if btn then
            btn:ClearAllPoints()
            if prev then
                btn:SetPoint("TOPLEFT", prev, "TOPRIGHT", 4, 0)
            else
                btn:SetPoint("TOPLEFT", toolbar, "TOPLEFT", 6, y)
            end
            prev = btn
        end
    end
end

local function MakeTagFilter(code)
    local btn = CreateFrame("Button", nil, toolbar)
    btn:SetHeight(22)
    btn:SetWidth(40)
    btn.code = code
    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetTexture(UI.WHITE)
    btn.txt = btn:CreateFontString(nil, "OVERLAY", UI.FONT_SMALL)
    btn.txt:SetPoint("CENTER", 0, -0.5)
    btn.txt:SetText(code)
    btn:SetScript("OnClick", function(self)
        if ns.UI.Filter.lfgPick[self.code] then
            ns.UI.Filter.lfgPick[self.code] = nil
        else
            ns.UI.Filter.lfgPick[self.code] = true
        end
        UpdateTagBtnVisual(self)
        if ns.UI.Refresh then ns.UI:Refresh() end
    end)
    tagButtons[code] = btn
    return btn
end

for _, code in ipairs(tagOrder) do
    MakeTagFilter(code)
end

LayoutTagRow()

local footer = CreateFrame("Frame", nil, LFGPanel)
footer:SetPoint("BOTTOMLEFT", 4, 6)
footer:SetPoint("BOTTOMRIGHT", -4, 6)
footer:SetHeight(102)

local footerLbl = footer:CreateFontString(nil, "OVERLAY", UI.FONT_SMALL)
footerLbl:SetPoint("TOPLEFT", 0, -2)
footerLbl:SetJustifyH("LEFT")
footerLbl:SetTextColor(0.72, 0.72, 0.78, 1)

local detailLbl = footer:CreateFontString(nil, "OVERLAY", UI.FONT_SMALL)
detailLbl:SetPoint("TOPLEFT", footerLbl, "BOTTOMLEFT", 0, -10)
detailLbl:SetJustifyH("LEFT")
detailLbl:SetTextColor(0.62, 0.62, 0.68, 1)

local detailEdit = CreateFrame("EditBox", nil, footer, "InputBoxTemplate")
detailEdit:SetHeight(20)
detailEdit:SetPoint("TOPLEFT", footer, "TOPLEFT", 0, -38)
detailEdit:SetPoint("TOPRIGHT", footer, "TOPRIGHT", -8, -38)
detailEdit:SetAutoFocus(false)
detailEdit:SetMaxLetters(120)
detailEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
detailEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

local checks = {}
local xOff = 4
for _, code in ipairs(tagOrder) do
    local cb = CreateFrame("CheckButton", "GCM_LFG_CB_" .. code, footer, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", footer, "TOPLEFT", xOff, -72)
    cb:SetSize(22, 22)
    cb.code = code
    cb.label = cb:CreateFontString(nil, "OVERLAY", UI.FONT_SMALL)
    cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    cb.label:SetText(code)
    checks[code] = cb
    xOff = xOff + 86
end

local applyBtn = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
applyBtn:SetSize(110, 22)
applyBtn:SetPoint("BOTTOMRIGHT", 0, 2)

applyBtn:SetScript("OnClick", function()
    local codes = {}
    for _, code in ipairs(tagOrder) do
        local cb = checks[code]
        if cb and cb:GetChecked() then
            codes[#codes + 1] = code
        end
    end
    table.sort(codes)
    local det = detailEdit:GetText() or ""
    if ns.LFG and ns.LFG.SetMine then
        ns.LFG:SetMine(codes, det)
    end
end)

local Scroll = CreateFrame("ScrollFrame", "GCM_LFGScroll", LFGPanel, "UIPanelScrollFrameTemplate")
Scroll:SetPoint("TOPLEFT", toolbar, "BOTTOMLEFT", 0, -4)
Scroll:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", -26, 6)

local Content = CreateFrame("Frame", nil, Scroll)
Content:SetSize(1, 1)
Scroll:SetScrollChild(Content)

local EmptyText = LFGPanel:CreateFontString(nil, "OVERLAY", UI.FONT_ROW)
EmptyText:SetPoint("CENTER", Scroll, "CENTER", -8, 0)
EmptyText:SetWidth(340)
EmptyText:SetJustifyH("CENTER")
EmptyText:SetTextColor(0.62, 0.62, 0.68, 1)
EmptyText:Hide()

local rows = {}

local function CacheToMember(name, entry)
    return {
        name = name,
        rosterName = entry.rosterName or name,
        class = entry.class,
        level = entry.level,
        online = entry.online,
        zone = entry.zone,
        publicNote = entry.publicNote,
        lastOnline = entry.lastOnline,
        role = nil,
        lead = false,
        hasConflict = false,
        conflictCount = 0,
        lfg = entry.lfg,
        lfgDetail = entry.lfgDetail or "",
    }
end

local function LfgPickMatches(member)
    local pick = ns.UI.Filter.lfgPick
    local anyPick = false
    for _ in pairs(pick) do
        anyPick = true
        break
    end
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
        local tags = entry.lfg
        local det = entry.lfgDetail or ""
        if (tags and #tags > 0) or (det ~= "") then
            n = n + 1
        end
    end
    return n
end

local function CollectLFGMembers()
    local out = {}
    if not ns.Cache then return out end
    for name, entry in pairs(ns.Cache) do
        local tags = entry.lfg
        local det = entry.lfgDetail or ""
        local has = (tags and #tags > 0) or (det ~= "")
        if has then
            local m = CacheToMember(name, entry)
            if LfgPickMatches(m) then
                if not ns.UI.Filter.onlyOnline or m.online then
                    local s = ns.UI.Filter.search
                    if not s or s == "" then
                        out[#out + 1] = m
                    else
                        local q = s
                        local nm = m.name:lower():find(q, 1, true)
                        local dd = (m.lfgDetail or ""):lower():find(q, 1, true)
                        if nm or dd then
                            out[#out + 1] = m
                        end
                    end
                end
            end
        end
    end
    table.sort(out, function(a, b)
        if a.online ~= b.online then return a.online and not b.online end
        return a.name < b.name
    end)
    return out
end

local function SyncSelfChecksFromCache()
    local me = UnitName("player")
    if not me then return end
    local nk = Ambiguate(me, "none")
    local entry = ns.Cache and ns.Cache[nk]
    local tags = entry and entry.lfg or {}
    local want = {}
    for _, c in ipairs(tags) do
        want[c] = true
    end
    for _, code in ipairs(tagOrder) do
        local cb = checks[code]
        if cb then
            cb:SetChecked(want[code] == true)
        end
    end
    detailEdit:SetText(entry and entry.lfgDetail or "")
end

local function RowTooltip(self)
    local m = self.member
    if not m then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local r, g, b = ns.UI:GetClassColor(m.class)
    GameTooltip:SetText(m.name, r, g, b)
    local tagStr = table.concat(m.lfg or {}, ", ")
    if tagStr ~= "" then
        GameTooltip:AddLine(string.format(ns.L.LFG_ROW_TAGS, tagStr), 0.75, 0.85, 1)
    end
    if m.lfgDetail and m.lfgDetail ~= "" then
        GameTooltip:AddLine(string.format(ns.L.LFG_ROW_DETAIL, m.lfgDetail), 0.8, 0.85, 0.92, true)
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
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetTexture(UI.WHITE)
    f.bg:SetVertexColor(1, 1, 1, 0.06)
    f.bg:Hide()

    f.dot = f:CreateTexture(nil, "OVERLAY")
    f.dot:SetTexture(UI.WHITE)
    f.dot:SetSize(6, 6)
    f.dot:SetPoint("LEFT", 6, 0)

    f.cls = f:CreateFontString(nil, "OVERLAY", UI.FONT_ROW)
    f.cls:SetPoint("LEFT", f.dot, "RIGHT", 6, 0)
    f.cls:SetWidth(18)

    f.tags = f:CreateFontString(nil, "OVERLAY", UI.FONT_SMALL)
    f.tags:SetPoint("RIGHT", -8, 0)
    f.tags:SetJustifyH("RIGHT")
    f.tags:SetWidth(140)

    f.name = f:CreateFontString(nil, "OVERLAY", UI.FONT_ROW)
    f.name:SetPoint("LEFT", f.cls, "RIGHT", 4, 0)
    f.name:SetPoint("RIGHT", f.tags, "LEFT", -8, 0)
    f.name:SetJustifyH("LEFT")

    f:SetScript("OnEnter", function(s)
        s.bg:Show()
        RowTooltip(s)
    end)
    f:SetScript("OnLeave", function(s)
        s.bg:Hide()
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

function ns.UI:RefreshLFGList()
    if not LFGPanel:IsShown() then return end

    toolbarTitle:SetText(ns.L.LFG_PANEL_TITLE)
    hint:SetText(ns.L.LFG_FILTER_HINT)
    footerLbl:SetText(ns.L.LFG_MY_TAGS)
    detailLbl:SetText(ns.L.LFG_DETAIL_LABEL)
    applyBtn:SetText(ns.L.LFG_APPLY_MY_TAGS)

    for _, code in ipairs(tagOrder) do
        local btn = tagButtons[code]
        if btn then
            btn.txt:SetText(ns.L["LFG_TAG_" .. code] or code)
            local w = math.max(36, btn.txt:GetStringWidth() + 16)
            btn:SetWidth(w)
            UpdateTagBtnVisual(btn)
        end
        local cb = checks[code]
        if cb and cb.label then
            cb.label:SetText(ns.L["LFG_TAG_" .. code] or code)
        end
    end
    LayoutTagRow()

    SyncSelfChecksFromCache()

    local members = CollectLFGMembers()
    local panelW = Scroll:GetWidth() - 8

    if #members == 0 then
        EmptyText:Show()
        if CountAnyLFG() == 0 then
            EmptyText:SetText(ns.L.LFG_EMPTY)
        else
            EmptyText:SetText(ns.L.LFG_EMPTY_FILTERED)
        end
        HideRowsFrom(1)
        Content:SetHeight(40)
        Content:SetWidth(math.max(1, panelW))
        return
    end

    EmptyText:Hide()

    local y = 0
    for i, m in ipairs(members) do
        local row = GetRow(i)
        row.member = m
        row:SetHeight(UI.ROW_H)
        row:SetPoint("TOPLEFT", Content, "TOPLEFT", 2, y)
        row:SetPoint("TOPRIGHT", Content, "TOPRIGHT", -2, y)

        local dr, dg, db = ns.UI:GetOnlineColor(m.online)
        row.dot:SetVertexColor(dr, dg, db, 1)
        row.cls:SetText(ns.UI:GetClassIcon(m.class))
        local r, g, b = ns.UI:GetClassColor(m.class)
        if not m.online then
            r, g, b = r * 0.55, g * 0.55, b * 0.55
        end
        row.name:SetText(m.name)
        row.name:SetTextColor(r, g, b)
        local tagPart = table.concat(m.lfg or {}, " ")
        local det = m.lfgDetail or ""
        if det ~= "" then
            row.tags:SetText(tagPart .. " |c888888" .. det:sub(1, 44) .. "|r")
        else
            row.tags:SetText(tagPart)
        end
        row:Show()
        y = y - UI.ROW_H - 2
    end

    HideRowsFrom(#members + 1)
    Content:SetHeight(math.max(1, -y))
    Content:SetWidth(math.max(1, panelW))
end

function ns.UI:SetMainPanel(mode)
    ns.UI.ActivePanel = mode
    local cores = mode == "cores"
    if ns.UI.FilterBar and ns.UI.FilterBar.SetCoreFiltersVisible then
        ns.UI.FilterBar:SetCoreFiltersVisible(cores)
    end
    if ns.UI.CoreListPanel then
        ns.UI.CoreListPanel:SetShown(cores)
    end
    LFGPanel:SetShown(not cores)
    if ns.UI.TabCores then
        ns.UI.TabCores:SetAlpha(cores and 1 or 0.55)
    end
    if ns.UI.TabLFG then
        ns.UI.TabLFG:SetAlpha(cores and 0.55 or 1)
    end
    if ns.UI.Refresh then ns.UI:Refresh() end
end

ns.UI.LFGPanel = LFGPanel

ns.Locale:RegisterCallback(function()
    LayoutTagRow()
    if LFGPanel:IsShown() then ns.UI:RefreshLFGList() end
end)
