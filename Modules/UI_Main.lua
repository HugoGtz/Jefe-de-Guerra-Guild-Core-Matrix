local addonName, ns = ...
ns.UI = ns.UI or {}

local UI = {
    SIZE = { MIN_W = 480, MIN_H = 360, MAX_W = 900, MAX_H = 1000, RESIZE = 16 },
}

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
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
MainFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
MainFrame:SetBackdropBorderColor(0.6, 0, 0, 1)

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
TitleBar:SetHeight(28)
TitleBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
TitleBar:SetBackdropColor(0.4, 0, 0, 1)

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

local TabCores = CreateFrame("Button", nil, TitleBar, "UIPanelButtonTemplate")
TabCores:SetSize(74, 20)
local TabLFG = CreateFrame("Button", nil, TitleBar, "UIPanelButtonTemplate")
TabLFG:SetSize(82, 20)
TabLFG:SetPoint("RIGHT", SyncBtn, "LEFT", -8, 0)
TabCores:SetPoint("RIGHT", TabLFG, "LEFT", -4, 0)
TabCores:SetScript("OnClick", function()
    if ns.UI.SetMainPanel then ns.UI:SetMainPanel("cores") end
end)
TabLFG:SetScript("OnClick", function()
    if ns.UI.SetMainPanel then ns.UI:SetMainPanel("lfg") end
end)
TabCores:SetAlpha(1)
TabLFG:SetAlpha(0.55)
ns.UI.TabCores = TabCores
ns.UI.TabLFG = TabLFG

local Header = TitleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
Header:SetPoint("LEFT", HeaderLogo, "RIGHT", 5, 0)
Header:SetPoint("RIGHT", TabCores, "LEFT", -8, 0)
Header:SetJustifyH("LEFT")

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
    TabCores:SetText(ns.L.LFG_TAB_CORES)
    TabLFG:SetText(ns.L.LFG_TAB_LOOKING)
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
            if ns.LFG and ns.LFG.SetMine then
                ns.LFG:SetMine({}, "")
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
