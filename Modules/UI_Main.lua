local addonName, ns = ...
ns.UI = ns.UI or {}

local Theme = ns.Theme

local UI = {
    SIZE = { MIN_W = 480, MIN_H = 420, MAX_W = 900, MAX_H = 1000, RESIZE = 16 },
    TAB = {
        H = 22,
        GAP = 2,
        PAD_X = 12,
        MIN_W = 50,
        STRIP_H = 28,
        SYNC_GAP = 8,
        BG_OFF = { 0.18, 0.13, 0.13, 1 },
        BG_HOVER = { 0.28, 0.20, 0.20, 1 },
        BG_ON = { 0.40, 0.10, 0.10, 1 },
        TEXT_OFF = { 0.70, 0.68, 0.68, 0.90 },
        TEXT_ON = { 1.00, 0.96, 0.96, 1 },
    },
}

local mainTabOrder = { "cores", "prof", "lfg" }
local mainTabLocaleKey = {
    cores = "LFG_TAB_CORES",
    prof = "PROF_TAB",
    lfg = "LFG_TAB_LOOKING",
}
local mainTabTipKey = {
    cores = "TAB_TIP_CORES",
    prof = "TAB_TIP_PROF",
    lfg = "TAB_TIP_LFG",
}
local mainTabs = {}

local function BringMainTabsToFront()
    for _, id in ipairs(mainTabOrder) do
        local t = mainTabs[id]
        if t and t.Raise then t:Raise() end
    end
end
ns.UI.BringMainTabsToFront = BringMainTabsToFront

local function ApplyOneMainTab(btn, active)
    if not btn then return end
    if active then
        btn.bg:SetVertexColor(unpack(UI.TAB.BG_ON))
        btn.text:SetTextColor(unpack(UI.TAB.TEXT_ON))
        btn.sel:Show()
        if btn.topLine then btn.topLine:Show() end
    else
        btn.bg:SetVertexColor(unpack(UI.TAB.BG_OFF))
        btn.text:SetTextColor(unpack(UI.TAB.TEXT_OFF))
        btn.sel:Hide()
        if btn.topLine then btn.topLine:Hide() end
    end
end

function ns.UI:UpdateMainTabs(mode)
    mode = mode or self.ActivePanel or "cores"
    for _, id in ipairs(mainTabOrder) do
        ApplyOneMainTab(mainTabs[id], id == mode)
    end
end

local function ReflowMainTabs()
    for _, id in ipairs(mainTabOrder) do
        local t = mainTabs[id]
        if t and t.text then
            local w = math.max(UI.TAB.MIN_W, t.text:GetStringWidth() + UI.TAB.PAD_X * 2)
            t:SetWidth(w)
        end
    end
end

local function LayoutMainTabs(strip)
    strip = strip or ns.UI.TabStrip
    local TabCores = mainTabs.cores
    local TabProf = mainTabs.prof
    local TabLFG = mainTabs.lfg
    if not strip or not TabCores or not TabProf or not TabLFG then return end
    TabCores:ClearAllPoints()
    TabCores:SetPoint("TOPLEFT", strip, "TOPLEFT", 8, -3)
    TabProf:ClearAllPoints()
    TabProf:SetPoint("TOPLEFT", TabCores, "TOPRIGHT", UI.TAB.GAP, 0)
    TabLFG:ClearAllPoints()
    TabLFG:SetPoint("TOPLEFT", TabProf, "TOPRIGHT", UI.TAB.GAP, 0)
end

local function MakeMainTab(tabId, parent)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetHeight(UI.TAB.H)
    b.tabId = tabId
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetTexture(Theme.TEX_WHITE)
    b.bg:SetVertexColor(unpack(UI.TAB.BG_OFF))
    -- top-border highlight line for the active state
    b.topLine = b:CreateTexture(nil, "ARTWORK")
    b.topLine:SetHeight(1)
    b.topLine:SetPoint("TOPLEFT",  b, "TOPLEFT",  2, 0)
    b.topLine:SetPoint("TOPRIGHT", b, "TOPRIGHT", -2, 0)
    b.topLine:SetTexture(Theme.TEX_WHITE)
    b.topLine:SetVertexColor(0.55, 0.14, 0.14, 0.60)
    b.topLine:Hide()
    -- bottom accent bar (gold when active)
    b.sel = b:CreateTexture(nil, "ARTWORK")
    b.sel:SetHeight(2)
    b.sel:SetPoint("BOTTOMLEFT",  b, "BOTTOMLEFT",  2, 0)
    b.sel:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 0)
    b.sel:SetTexture(Theme.TEX_WHITE)
    b.sel:SetVertexColor(unpack(Theme.BRAND_GOLD))
    b.sel:Hide()
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.text:SetPoint("CENTER", 0, 1)
    b:EnableMouse(true)
    b:SetScript("OnClick", function(self)
        if PlaySound then pcall(function() PlaySound(856, "SFX") end) end
        ns.UI:SetMainPanel(self.tabId)
    end)
    b:SetScript("OnEnter", function(self)
        if (ns.UI.ActivePanel or "cores") ~= self.tabId then
            self.bg:SetVertexColor(unpack(UI.TAB.BG_HOVER))
            self.text:SetTextColor(0.94, 0.90, 0.90, 1)
        end
        local tipKey = mainTabTipKey[self.tabId]
        if tipKey and ns.L and ns.L[tipKey] then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(ns.L[tipKey], 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function()
        GameTooltip:Hide()
        ns.UI:UpdateMainTabs(ns.UI.ActivePanel or "cores")
    end)
    return b
end

local MainFrame = CreateFrame("Frame", "GCM_MainFrame", UIParent, "BackdropTemplate")
MainFrame:SetSize(500, 580)
MainFrame:SetPoint("CENTER")
MainFrame:SetMovable(true)
MainFrame:SetResizable(true)
MainFrame:SetClampedToScreen(true)
MainFrame:EnableMouse(true)
MainFrame:RegisterForDrag("LeftButton")
MainFrame:Hide()

if MainFrame.SetResizeBounds then
    MainFrame:SetResizeBounds(UI.SIZE.MIN_W, UI.SIZE.MIN_H, UI.SIZE.MAX_W, UI.SIZE.MAX_H)
else
    if MainFrame.SetMinResize then MainFrame:SetMinResize(UI.SIZE.MIN_W, UI.SIZE.MIN_H) end
    if MainFrame.SetMaxResize then MainFrame:SetMaxResize(UI.SIZE.MAX_W, UI.SIZE.MAX_H) end
end

MainFrame:SetBackdrop({
    bgFile = Theme.TEX_WHITE,
    edgeFile = Theme.TEX_BORDER,
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
MainFrame:SetBackdropColor(unpack(Theme.BG_MAIN))
MainFrame:SetBackdropBorderColor(unpack(Theme.BORDER_MAIN))

MainFrame:SetScript("OnDragStart", MainFrame.StartMoving)
MainFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, x, y = self:GetPoint()
    GCM_Settings.framePosition = { point = point, relativePoint = relativePoint, x = x, y = y }
end)

local function ApplyPersistedLayout()
    if not GCM_Settings then return end
    if GCM_Settings.frameWidth and GCM_Settings.frameHeight then
        local w = math.max(GCM_Settings.frameWidth, UI.SIZE.MIN_W)
        local h = math.max(GCM_Settings.frameHeight, UI.SIZE.MIN_H)
        MainFrame:SetSize(w, h)
    end
    if GCM_Settings.framePosition then
        local p = GCM_Settings.framePosition
        MainFrame:ClearAllPoints()
        MainFrame:SetPoint(p.point or "CENTER", UIParent, p.relativePoint or "CENTER", p.x or 0, p.y or 0)
    end
end

local TitleBar = CreateFrame("Frame", nil, MainFrame, "BackdropTemplate")
TitleBar:SetPoint("TOPLEFT", 4, -4)
TitleBar:SetPoint("TOPRIGHT", -4, -4)
TitleBar:SetHeight(30)
TitleBar:SetBackdrop({ bgFile = Theme.TEX_WHITE })
TitleBar:SetBackdropColor(unpack(Theme.BRAND_RED))

local HeaderLogo = TitleBar:CreateTexture(nil, "OVERLAY")
HeaderLogo:SetSize(20, 20)
HeaderLogo:SetPoint("LEFT", 5, 0)
HeaderLogo:SetTexture("Interface\\AddOns\\GuildCoreMatrix\\Media\\logo")

local CloseBtn = CreateFrame("Button", nil, MainFrame, "UIPanelCloseButton")
CloseBtn:SetPoint("TOPRIGHT", MainFrame, "TOPRIGHT", -2, -2)
CloseBtn:SetScale(0.8)
CloseBtn:SetScript("OnClick", function() MainFrame:Hide() end)

local SyncBtn = CreateFrame("Button", nil, TitleBar, "UIPanelButtonTemplate")
SyncBtn:SetSize(60, 20)
SyncBtn:SetPoint("RIGHT", CloseBtn, "LEFT", 0, -8)

local TabStrip = CreateFrame("Frame", "GCM_MainTabStrip", MainFrame, "BackdropTemplate")
TabStrip:SetPoint("TOPLEFT", TitleBar, "BOTTOMLEFT", 0, -1)
TabStrip:SetPoint("TOPRIGHT", TitleBar, "BOTTOMRIGHT", 0, -1)
TabStrip:SetHeight(UI.TAB.STRIP_H)
TabStrip:SetBackdrop({
    bgFile = Theme.TEX_WHITE,
    edgeFile = Theme.TEX_BORDER,
    tile = true,
    tileSize = 8,
    edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
TabStrip:SetBackdropColor(unpack(Theme.BG_STRIP))
TabStrip:SetBackdropBorderColor(unpack(Theme.BORDER_MAIN))
ns.UI.TabStrip = TabStrip

for _, id in ipairs(mainTabOrder) do
    mainTabs[id] = MakeMainTab(id, TabStrip)
    mainTabs[id].text:SetText(ns.L[mainTabLocaleKey[id]] or id)
end
local tabStripBase = TabStrip.GetFrameLevel and TabStrip:GetFrameLevel() or 0
for _, id in ipairs(mainTabOrder) do
    local t = mainTabs[id]
    if t and t.SetFrameLevel then t:SetFrameLevel(tabStripBase + 10) end
end
ReflowMainTabs()
LayoutMainTabs(TabStrip)

local TabCores = mainTabs.cores
local TabProf = mainTabs.prof
local TabLFG = mainTabs.lfg
ns.UI.TabCores = TabCores
ns.UI.TabProf = TabProf
ns.UI.TabLFG = TabLFG

local Header = TitleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
Header:SetPoint("LEFT", HeaderLogo, "RIGHT", 5, 0)
Header:SetPoint("RIGHT", SyncBtn, "LEFT", -12, 0)
Header:SetJustifyH("LEFT")
if Header.SetMaxLines then Header:SetMaxLines(1) end
if Header.SetWordWrap then Header:SetWordWrap(false) end

BringMainTabsToFront()
ns.UI:UpdateMainTabs(ns.UI.ActivePanel or "cores")

SyncBtn:SetScript("OnClick", function()
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end
    ns.Scanner:ResetThrottle()
    ns.Scanner:ParseGuildNotes({ verbose = true })
end)

local ResizeBtn = CreateFrame("Button", nil, MainFrame)
ResizeBtn:SetSize(UI.SIZE.RESIZE, UI.SIZE.RESIZE)
ResizeBtn:SetPoint("BOTTOMRIGHT", -2, 2)
ResizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
ResizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
ResizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
ResizeBtn:SetScript("OnMouseDown", function() MainFrame:StartSizing("BOTTOMRIGHT") end)
ResizeBtn:SetScript("OnMouseUp", function()
    MainFrame:StopMovingOrSizing()
    GCM_Settings.frameWidth = MainFrame:GetWidth()
    GCM_Settings.frameHeight = MainFrame:GetHeight()
end)

ns.UI.MainFrame = MainFrame
ns.UI.TitleBar = TitleBar
ns.UI.Header = Header
ns.UI.SyncBtn = SyncBtn

local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", function() ApplyPersistedLayout() end)

ns.Locale:RegisterCallback(function()
    Header:SetText(ns.L.HEADER_TITLE)
    SyncBtn:SetText(ns.L.BTN_SYNC)
    for _, id in ipairs(mainTabOrder) do
        local t = mainTabs[id]
        if t and t.text then t.text:SetText(ns.L[mainTabLocaleKey[id]] or id) end
    end
    ReflowMainTabs()
    LayoutMainTabs(ns.UI.TabStrip)
    Header:ClearAllPoints()
    Header:SetPoint("LEFT", HeaderLogo, "RIGHT", 5, 0)
    Header:SetPoint("RIGHT", SyncBtn, "LEFT", -12, 0)
    Header:SetJustifyH("LEFT")
    BringMainTabsToFront()
    ns.UI:UpdateMainTabs(ns.UI.ActivePanel or "cores")
end)

SLASH_GCM1 = "/gcm"
SlashCmdList["GCM"] = function(msg)
    msg = msg or ""
    local lead, tail = msg:match("^%s*(%S+)(.*)$")
    if lead == "officer" then
        local sub = tail:match("^%s*(%S+)") or ""
        sub = string.lower(sub)
        if sub == "" or sub == "help" or sub == "?" then
            local m = GCM_Settings.officerUi
            local modeStr = m == true and ns.L.OFFICER_UI_MODE_ON or (m == false and ns.L.OFFICER_UI_MODE_OFF or ns.L.OFFICER_UI_MODE_AUTO)
            print(ns.L.BRAND .. " " .. string.format(ns.L.OFFICER_UI_CURRENT, modeStr))
            print(ns.L.BRAND .. " " .. ns.L.OFFICER_UI_USAGE)
            return
        elseif sub == "on" then
            GCM_Settings.officerUi = true
            print(ns.L.BRAND_GREEN .. " " .. ns.L.OFFICER_UI_ON)
        elseif sub == "off" then
            GCM_Settings.officerUi = false
            print(ns.L.BRAND_GREEN .. " " .. ns.L.OFFICER_UI_OFF)
        elseif sub == "auto" then
            GCM_Settings.officerUi = nil
            print(ns.L.BRAND_GREEN .. " " .. ns.L.OFFICER_UI_AUTO)
        else
            print(ns.L.BRAND .. " " .. ns.L.OFFICER_UI_USAGE)
            return
        end
        if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
        return
    end
    if lead == "lfg" then
        local rest = tail:match("^%s*(.*)$") or ""
        rest = rest:match("^%s*(.-)%s*$") or ""
        if rest == "" or rest == "?" or string.lower(rest) == "help" then
            print(ns.L.BRAND .. " " .. ns.L.LFG_SLASH_USAGE)
            return
        end
        local low = string.lower(rest)
        if low == "clear" or low == "off" then
            if ns.LFG and ns.LFG.ClearMine then
                ns.LFG:ClearMine()
            end
            return
        end
        if ns.LFG and ns.LFG.CodesFromWhitespace and ns.LFG.SetMine then
            local codes = ns.LFG:CodesFromWhitespace(rest)
            if #codes == 0 then
                print(ns.L.BRAND .. " " .. ns.L.LFG_SLASH_UNKNOWN)
                return
            end
            ns.LFG:SetMine(codes, "")
        end
        return
    end
    local arg = lead
    if arg == "migrate" then
        ns.Database:RunManualLegacyCoreKeysMigration()
        return
    end
    if arg == "reset" then
        ns.Database:ResetWindow()
        MainFrame:ClearAllPoints()
        MainFrame:SetPoint("CENTER")
        MainFrame:SetSize(500, 580)
        print(ns.L.BRAND_GREEN .. " " .. ns.L.RESET_OK)
        return
    end
    if arg == "forcewrite" then
        GCM_Settings.forceCanWrite = not GCM_Settings.forceCanWrite
        local state = GCM_Settings.forceCanWrite and ns.L.FORCEWRITE_ON or ns.L.FORCEWRITE_OFF
        print(ns.L.BRAND_GREEN .. " " .. state)
        if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
        return
    end
    if arg == "perms" then
        local raw = CanEditOfficerNote and CanEditOfficerNote() or false
        local rawPub = CanEditPublicNote and CanEditPublicNote() or false
        local cgiOff = C_GuildInfo and C_GuildInfo.CanEditOfficerNote and C_GuildInfo.CanEditOfficerNote() or nil
        local cgiPub = C_GuildInfo and C_GuildInfo.CanEditPublicNote and C_GuildInfo.CanEditPublicNote() or nil
        local mode = GCM_Settings.officerUi
        local modeStr = mode == true and "on" or (mode == false and "off" or "auto")
        print(ns.L.BRAND .. string.format(
            " officerUi=%s | CanEditUI=%s | CanWrite=%s | forceCanWrite=%s",
            modeStr, tostring(ns.Notes:CanEditUI()), tostring(ns.Notes:CanWrite()),
            tostring(GCM_Settings.forceCanWrite)))
        print(ns.L.BRAND .. string.format(
            " EffectiveOff=%s EffectivePub=%s legacy Off=%s Pub=%s C_GuildInfo Off=%s Pub=%s",
            tostring(ns.Notes:EffectiveCanEditOfficerNote()),
            tostring(ns.Notes:EffectiveCanEditPublicNote()),
            tostring(raw), tostring(rawPub), tostring(cgiOff), tostring(cgiPub)))
        return
    end
    if lead == "pubnote" then
        local sub = tail:match("^%s*(%S+)") or ""
        sub = sub:lower()
        if sub == "" or sub == "?" or sub == "help" then
            print(ns.L.BRAND .. " " .. ns.L.PUBNOTE_SLASH_USAGE)
            return
        end
        if sub == "push" then
            if ns.PublicNote then ns.PublicNote:Push() end
            return
        end
        if sub == "restore" then
            if ns.PublicNote then ns.PublicNote:Restore(false) end
            return
        end
        if sub == "force" then
            if ns.PublicNote then ns.PublicNote:Restore(true) end
            return
        end
        if sub == "status" then
            if ns.PublicNote then ns.PublicNote:Status() end
            return
        end
        print(ns.L.BRAND .. " " .. ns.L.PUBNOTE_SLASH_USAGE)
        return
    end
    if lead == "role" then
        local rest = tail:match("^%s*(%S+)") or ""
        rest = rest:upper()
        if rest == "" or rest == "?" or rest == "HELP" then
            print(ns.L.BRAND .. " " .. ns.L.ROLE_SLASH_USAGE)
            return
        end
        if rest == "CLEAR" or rest == "OFF" then
            if ns.Roles then ns.Roles:SetMine(nil) end
            print(ns.L.BRAND_GREEN .. " " .. ns.L.ROLE_SLASH_CLEARED)
            return
        end
        if rest == "T" or rest == "H" or rest == "D" then
            if ns.Roles then ns.Roles:SetMine(rest) end
            local label = (rest == "T" and ns.L.ROLE_TANK) or (rest == "H" and ns.L.ROLE_HEAL) or ns.L.ROLE_DPS
            print(ns.L.BRAND_GREEN .. " " .. string.format(ns.L.ROLE_SLASH_SET, label))
            return
        end
        print(ns.L.BRAND .. " " .. ns.L.ROLE_SLASH_INVALID)
        return
    end
    if arg == "spec" then
        local rest = msg:match("^%s*spec%s+(%S+)") or ""
        if rest == "" then
            local me = UnitName("player")
            local _, class = UnitClass("player")
            local list = ns.Specs and ns.Specs:GetSpecsForClass(class) or {}
            local current = ns.Specs and ns.Specs:GetSpec(me)
            local options = {}
            for _, s in ipairs(list) do options[#options + 1] = s.short end
            print(ns.L.BRAND .. " " .. string.format(ns.L.SPEC_USAGE, table.concat(options, ", ")))
            print(ns.L.BRAND .. " " .. string.format(ns.L.SPEC_CURRENT, tostring(current or "?")))
            return
        end
        local ok, metaOrList = ns.Specs:SetMine(rest)
        if ok then
            print(ns.L.BRAND_GREEN .. " " .. string.format(ns.L.SPEC_SET, metaOrList.full))
        else
            local opts = {}
            for _, s in ipairs(metaOrList or {}) do opts[#opts + 1] = s.short end
            print(ns.L.BRAND .. " " .. string.format(ns.L.SPEC_INVALID, table.concat(opts, ", ")))
        end
        return
    end
    if arg == "help" or arg == "?" then
        print(ns.L.BRAND .. " " .. ns.L.SLASH_USAGE)
        return
    end
    if MainFrame:IsShown() then
        MainFrame:Hide()
    else
        ns.Scanner:ParseGuildNotes()
        MainFrame:Show()
    end
end

SLASH_GCMLANG1 = "/gcmlang"
SlashCmdList["GCMLANG"] = function(msg)
    local L = ns.L
    local arg = msg and msg:match("^%s*(%S+)") or nil
    local available = table.concat(ns.Locale:GetAvailable(), ", ")

    if not arg or arg == "" then
        print(L.BRAND .. " " .. string.format(L.LANG_CURRENT, ns.Locale.current or "?", available))
        print(L.BRAND .. " " .. L.LANG_USAGE)
        return
    end

    if arg == "reset" then
        GCM_Settings.locale = nil
        ns.Locale:Activate()
        ns.Locale:RunCallbacks()
        print(ns.L.BRAND .. " " .. string.format(ns.L.LANG_RESET, ns.Locale.current or "?"))
        return
    end

    if not ns.Locale:Has(arg) then
        print(L.BRAND .. " " .. string.format(L.LANG_UNKNOWN, arg, available))
        return
    end

    GCM_Settings.locale = arg
    ns.Locale:Activate()
    ns.Locale:RunCallbacks()
    print(ns.L.BRAND .. " " .. string.format(ns.L.LANG_CHANGED, arg))
end
