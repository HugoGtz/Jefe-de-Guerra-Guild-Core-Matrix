local addonName, ns = ...
ns.UI = ns.UI or {}

local Theme = ns.Theme

local PAD       = 14
local ROW_H     = 18
local ROW_GAP   =  4
local SEC_GAP   = 12
local TARGET_C  = 25

local MainFrame = ns.UI.MainFrame
local FilterBar = ns.UI.FilterBar

local TOOLS_H = 122

local Panel = CreateFrame("ScrollFrame", "GCM_DashPanel", MainFrame, "UIPanelScrollFrameTemplate")
Panel:SetPoint("TOPLEFT",     FilterBar, "BOTTOMLEFT",  0, -4)
Panel:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -8, 8 + TOOLS_H)
Panel:Hide()
ns.UI.DashPanel = Panel

local ToolsBar = CreateFrame("Frame", nil, MainFrame, "BackdropTemplate")
ToolsBar:SetPoint("BOTTOMLEFT",  MainFrame, "BOTTOMLEFT",  8, 8)
ToolsBar:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -8, 8)
ToolsBar:SetHeight(TOOLS_H)
ToolsBar:SetBackdrop({
    bgFile = Theme.TEX_WHITE,
    edgeFile = Theme.TEX_BORDER,
    tile = true,
    tileSize = 8,
    edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
ToolsBar:SetBackdropColor(unpack(Theme.BG_PANEL))
ToolsBar:SetBackdropBorderColor(unpack(Theme.BORDER_MAIN))
ToolsBar:Hide()
ns.UI.DashToolsBar = ToolsBar

local toolsHdr = ToolsBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
toolsHdr:SetPoint("TOPLEFT", 12, -10)

local altStatus = ToolsBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
altStatus:SetPoint("TOPLEFT", toolsHdr, "BOTTOMLEFT", 0, -6)
altStatus:SetPoint("RIGHT", ToolsBar, "RIGHT", -190, 0)
altStatus:SetHeight(40)
altStatus:SetJustifyH("LEFT")
altStatus:SetJustifyV("TOP")
altStatus:SetWordWrap(true)

local btnAltLink = CreateFrame("Button", nil, ToolsBar, "UIPanelButtonTemplate")
btnAltLink:SetSize(92, 22)
btnAltLink:SetPoint("TOPRIGHT", ToolsBar, "TOPRIGHT", -10, -28)

local btnAltClear = CreateFrame("Button", nil, ToolsBar, "UIPanelButtonTemplate")
btnAltClear:SetSize(78, 22)
btnAltClear:SetPoint("RIGHT", btnAltLink, "LEFT", -6, 0)

local btnGearScan = CreateFrame("Button", nil, ToolsBar, "UIPanelButtonTemplate")
btnGearScan:SetSize(108, 22)
btnGearScan:SetPoint("TOPLEFT", altStatus, "BOTTOMLEFT", 0, -8)

local auditBody = ToolsBar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
auditBody:SetPoint("TOPLEFT", btnGearScan, "BOTTOMLEFT", 0, -6)
auditBody:SetPoint("RIGHT", ToolsBar, "RIGHT", -12, 0)
auditBody:SetJustifyH("LEFT")
auditBody:SetJustifyV("TOP")
auditBody:SetWordWrap(true)

StaticPopupDialogs["GCM_ALT_MAIN"] = {
    text = " ",
    button1 = ACCEPT or "OK",
    button2 = CANCEL or "Cancel",
    hasEditBox = true,
    editBoxWidth = 220,
    maxLetters = 48,
    OnShow = function(self)
        self.text:SetText(ns.L.ALT_LINK_POPUP_TEXT)
        local eb = self.editBox or self.EditBox
        if eb then
            eb:SetText("")
            eb:SetFocus()
        end
    end,
    OnAccept = function(self)
        local eb = self.editBox or self.EditBox
        local raw = (eb and eb:GetText()) or ""
        raw = raw:match("^%s*(.-)%s*$") or ""
        if raw == "" then
            if ns.AltLinks and ns.AltLinks.SetMine then
                ns.AltLinks:SetMine("")
            end
            print(ns.L.BRAND_GREEN .. " " .. ns.L.ALT_LINK_CLEARED)
        else
            local nk = Ambiguate(raw, "none")
            if ns.AltLinks and ns.AltLinks.SetMine then
                ns.AltLinks:SetMine(nk)
            end
            if ns.Cache and not ns.Cache[nk] then
                print(ns.L.BRAND_YELLOW .. " " .. ns.L.ALT_LINK_UNKNOWN)
            end
            print(ns.L.BRAND_GREEN .. " " .. string.format(ns.L.ALT_LINK_SET, nk))
        end
        if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function RefreshDashTools()
    if not toolsHdr or not ToolsBar then return end
    toolsHdr:SetText(ns.L.DASH_TOOLS_TITLE)
    btnAltLink:SetText(ns.L.DASH_ALT_SET_BTN)
    btnAltClear:SetText(ns.L.DASH_ALT_CLEAR_BTN)
    btnGearScan:SetText(ns.L.DASH_AUDIT_SCAN_BTN)
    local me = UnitName("player")
    local main = me and ns.AltLinks and ns.AltLinks.GetMain and ns.AltLinks:GetMain(me) or nil
    if main then
        altStatus:SetText(string.format(ns.L.DASH_ALT_STATUS, main))
    else
        altStatus:SetText(ns.L.DASH_ALT_NONE)
    end
    local issues = ns.GearAudit and select(1, ns.GearAudit:GetLastPersisted())
    if issues == nil then
        auditBody:SetText(ns.L.DASH_AUDIT_NEVER)
    else
        local n = #issues
        if n == 0 then
            auditBody:SetText(ns.L.DASH_AUDIT_OK)
        else
            local lines = {}
            for i = 1, math.min(n, 10) do
                lines[#lines + 1] = ns.GearAudit:IssueLabel(issues[i])
            end
            local tail = n > 10 and string.format(ns.L.DASH_AUDIT_MORE, n - 10) or ""
            auditBody:SetText(table.concat(lines, "\n") .. tail)
        end
    end
end

btnAltLink:SetScript("OnClick", function()
    StaticPopup_Show("GCM_ALT_MAIN")
end)

btnAltClear:SetScript("OnClick", function()
    if ns.AltLinks and ns.AltLinks.SetMine then
        ns.AltLinks:SetMine("")
    end
    print(ns.L.BRAND_GREEN .. " " .. ns.L.ALT_LINK_CLEARED)
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
end)

btnGearScan:SetScript("OnClick", function()
    if not ns.GearAudit or not ns.GearAudit.PersistAndReturn then return end
    local issues = ns.GearAudit:PersistAndReturn()
    local n = #issues
    if n == 0 then
        print(ns.L.BRAND_GREEN .. " " .. ns.L.AUDIT_CHAT_OK)
    else
        print(ns.L.BRAND_YELLOW .. " " .. string.format(ns.L.AUDIT_CHAT_FOUND, n))
    end
    RefreshDashTools()
end)

do
    local prev = ns.UI.SetMainPanel
    function ns.UI:SetMainPanel(mode)
        prev(ns.UI, mode)
        if ToolsBar then
            ToolsBar:SetShown(mode == "dashboard")
            if mode == "dashboard" then RefreshDashTools() end
        end
    end
end

local Content = CreateFrame("Frame", nil, Panel)
Content:SetSize(1, 1)
Panel:SetScrollChild(Content)

-- ─── pools (lazily created, reused each refresh) ──────────────────────────────

local textPool = {}
local textUsed = 0
local sepPool  = {}
local sepUsed  = 0

local function ResetPools()
    for i = 1, textUsed do textPool[i]:SetText("") textPool[i]:Hide() end
    for i = 1, sepUsed  do sepPool[i]:Hide() end
    textUsed = 0
    sepUsed  = 0
end

local function AddRow(y, text, r, g, b, indent)
    textUsed = textUsed + 1
    if not textPool[textUsed] then
        textPool[textUsed] = Content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    end
    local fs = textPool[textUsed]
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", Content, "TOPLEFT", indent or PAD, y)
    fs:SetPoint("RIGHT", Content, "RIGHT", -PAD, 0)
    fs:SetHeight(ROW_H)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    local ff, fsize, fflags = GameFontHighlight:GetFont()
    if ff then fs:SetFont(ff, fsize, fflags) end
    fs:SetTextColor(r or 0.85, g or 0.85, b or 0.95, 1)
    fs:SetText(text or "")
    fs:Show()
    return y - ROW_H - ROW_GAP
end

local function AddHeader(y, text)
    textUsed = textUsed + 1
    if not textPool[textUsed] then
        textPool[textUsed] = Content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    end
    local fs = textPool[textUsed]
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", Content, "TOPLEFT", PAD, y)
    fs:SetPoint("RIGHT", Content, "RIGHT", -PAD, 0)
    fs:SetHeight(ROW_H)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    local ff, fsize, fflags = GameFontNormal:GetFont()
    if ff then fs:SetFont(ff, fsize, fflags) end
    fs:SetTextColor(1.00, 0.82, 0.00, 1)
    fs:SetText(text or "")
    fs:Show()
    return y - ROW_H - 2
end

local function AddSep(y)
    sepUsed = sepUsed + 1
    if not sepPool[sepUsed] then
        local s = Content:CreateTexture(nil, "ARTWORK")
        s:SetTexture(Theme.TEX_WHITE)
        s:SetHeight(1)
        sepPool[sepUsed] = s
    end
    local s = sepPool[sepUsed]
    s:ClearAllPoints()
    s:SetPoint("TOPLEFT", Content, "TOPLEFT", PAD, y)
    s:SetPoint("RIGHT", Content, "RIGHT", -PAD, 0)
    s:SetVertexColor(unpack(Theme.SEP))
    s:Show()
    return y - 1 - ROW_GAP
end

local function AddSection(y, text)
    y = AddHeader(y, text)
    return AddSep(y)
end

-- ─── stats ────────────────────────────────────────────────────────────────────

local function ComputeStats()
    local stats = {
        total = 0, tagged = 0, unassigned = 0, online = 0,
        roles = { T = 0, H = 0, D = 0, U = 0 },
        cores = {},
    }

    if not ns.Cache then return stats end

    for _, entry in pairs(ns.Cache) do
        stats.total = stats.total + 1
        if entry.cores and next(entry.cores) then
            stats.tagged = stats.tagged + 1
            if entry.online then stats.online = stats.online + 1 end
        else
            stats.unassigned = stats.unassigned + 1
        end
    end

    local seen = {}
    for _, entry in pairs(ns.Cache) do
        if entry.cores then
            for tc, cids in pairs(entry.cores) do
                for cid in pairs(cids) do
                    local key = tc .. tostring(cid)
                    if not seen[key] then
                        seen[key] = { typeCode = tc, coreId = tonumber(cid) or cid }
                    end
                end
            end
        end
    end

    for _, info in pairs(seen) do
        local members = ns.Scanner:GetMembersForCore(info.typeCode, info.coreId)
        local t, h, d, u, online = 0, 0, 0, 0, 0
        for _, m in ipairs(members) do
            if m.online then online = online + 1 end
            if     m.role == "T" then t = t + 1
            elseif m.role == "H" then h = h + 1
            elseif m.role == "D" then d = d + 1
            else                      u = u + 1 end
        end
        if info.typeCode == "C" then
            stats.roles.T = stats.roles.T + t
            stats.roles.H = stats.roles.H + h
            stats.roles.D = stats.roles.D + d
            stats.roles.U = stats.roles.U + u
        end
        local coreKey = ns.Schedule and ns.Schedule.CoreKey and ns.Schedule:CoreKey(info.typeCode, info.coreId)
        local nextSlot = coreKey and ns.Schedule:GetNextSlot(coreKey)
        stats.cores[#stats.cores + 1] = {
            typeCode = info.typeCode, coreId = info.coreId,
            count = #members, online = online,
            t = t, h = h, d = d, u = u,
            nextSlot = nextSlot,
        }
    end

    table.sort(stats.cores, function(a, b)
        local order = { C = 1, B = 2, U = 3 }
        if a.typeCode ~= b.typeCode then
            return (order[a.typeCode] or 9) < (order[b.typeCode] or 9)
        end
        return (tonumber(a.coreId) or 0) < (tonumber(b.coreId) or 0)
    end)

    return stats
end

-- ─── render ───────────────────────────────────────────────────────────────────

local function RoleStr(t, h, d, u)
    local parts = {
        string.format("|cff73a0ff%dT|r", t),
        string.format("|cff4ade80%dH|r", h),
        string.format("|cffff8270%dD|r", d),
    }
    if u > 0 then parts[#parts + 1] = string.format("|cff999999%d?|r", u) end
    return table.concat(parts, "  ")
end

function ns.UI:RefreshDashboard()
    local panelWidth = Panel:GetWidth() - 26
    Content:SetWidth(math.max(1, panelWidth))

    ResetPools()

    local stats = ComputeStats()
    local y = -PAD

    if stats.total == 0 then
        y = AddRow(y, ns.L.DASH_EMPTY, 0.55, 0.55, 0.62)
        Content:SetHeight(math.max(1, -y + PAD))
        RefreshDashTools()
        return
    end

    -- Overview
    y = AddSection(y, ns.L.DASH_OVERVIEW)
    local onlinePct = stats.tagged > 0 and math.floor(stats.online / stats.tagged * 100) or 0
    y = AddRow(y, string.format("%s  %d  |cff666666·|r  |cff4ade80%d online|r  |cff666666(%d%%)|r",
        ns.L.DASH_ROSTER, stats.tagged, stats.online, onlinePct))
    if stats.unassigned > 0 then
        y = AddRow(y,
            string.format("|cffffcc00%d %s|r", stats.unassigned, ns.L.DASH_UNASSIGNED),
            0.85, 0.85, 0.95, PAD + 8)
    end
    y = y - SEC_GAP

    -- Role distribution (C cores only)
    local r = stats.roles
    if (r.T + r.H + r.D + r.U) > 0 then
        y = AddSection(y, ns.L.DASH_ROLES_HDR)
        y = AddRow(y, RoleStr(r.T, r.H, r.D, r.U))
        y = y - SEC_GAP
    end

    -- C cores
    local hasCores = false
    for _, c in ipairs(stats.cores) do if c.typeCode == "C" then hasCores = true break end end
    if hasCores then
        y = AddSection(y, ns.L.DASH_CORES_HDR)
        for _, c in ipairs(stats.cores) do
            if c.typeCode == "C" then
                local nick = ns.Scanner and ns.Scanner.GetCoreDisplayName
                    and ns.Scanner:GetCoreDisplayName("C", c.coreId)
                local label = (nick and nick ~= "")
                    and string.format("|cffd4af37Core %d|r · %s", c.coreId, nick)
                    or  string.format("|cffd4af37Core %d|r", c.coreId)
                local fillColor = c.count >= TARGET_C and "|cff4ade80" or "|cffffcc00"
                local countStr  = string.format("%s%d/%d|r", fillColor, c.count, TARGET_C)
                local schedStr  = ""
                if c.nextSlot then
                    schedStr = "  |cff888888·|r  " .. ns.UI:FormatNextSlot(c.nextSlot)
                end
                y = AddRow(y, string.format("%s  %s  ·  %s  ·  |cff4ade80%d online|r%s",
                    label, countStr, RoleStr(c.t, c.h, c.d, c.u), c.online, schedStr))
            end
        end
        y = y - SEC_GAP
    end

    -- Bench
    local hasBench = false
    for _, c in ipairs(stats.cores) do if c.typeCode == "B" then hasBench = true break end end
    if hasBench then
        y = AddSection(y, ns.L.DASH_BENCH_HDR)
        for _, c in ipairs(stats.cores) do
            if c.typeCode == "B" then
                local nick = ns.Scanner and ns.Scanner.GetCoreDisplayName
                    and ns.Scanner:GetCoreDisplayName("B", c.coreId)
                local label = (nick and nick ~= "")
                    and string.format("|cffd4af37%s|r · %s", ns.L.LABEL_BENCH, nick)
                    or  string.format("|cffd4af37%s|r", ns.L.LABEL_BENCH)
                y = AddRow(y, string.format("%s  %d  ·  %s  ·  |cff4ade80%d online|r",
                    label, c.count, RoleStr(c.t, c.h, c.d, c.u), c.online))
            end
        end
    end

    Content:SetHeight(math.max(1, -y + PAD))
    RefreshDashTools()
end

ns.Locale:RegisterCallback(function()
    RefreshDashTools()
end)
