local _, ns = ...
ns.UI = ns.UI or {}

local MainFrame = ns.UI.MainFrame
local Theme = ns.Theme

local UI = {
    HEIGHT = 46,
    FONT = { LABEL = "GameFontNormalSmall", ROW = "GameFontHighlightSmall", BTN = "GameFontHighlightSmall" },
    COLOR = {
        -- File-specific: BTN_AUTO_ON, BTN_HOVER (slightly different blue from theme), PUB_ON, PUB_OFF, DIM, SEP
        BTN_AUTO_ON = { 0.14, 0.48, 0.22, 1.0 },
        BTN_HOVER   = { 0.18, 0.18, 0.26, 1.0 },
        PUB_ON      = { 0.12, 0.42, 0.18, 1.0 },
        PUB_OFF     = { 0.14, 0.14, 0.18, 1.0 },
        DIM         = { 0.58, 0.58, 0.65, 1 },
        SEP         = { 0.28, 0.28, 0.36, 0.55 },
    },
}

local SelfBar = CreateFrame("Frame", "GCM_SelfBar", MainFrame, "BackdropTemplate")
local tabTop = ns.UI.TabStrip or ns.UI.TitleBar
SelfBar:SetPoint("TOPLEFT", tabTop, "BOTTOMLEFT", 0, -2)
SelfBar:SetPoint("TOPRIGHT", tabTop, "BOTTOMRIGHT", 0, -2)
SelfBar:SetHeight(UI.HEIGHT)
SelfBar:SetBackdrop({
    bgFile = Theme.TEX_WHITE,
    edgeFile = Theme.TEX_BORDER,
    tile = true,
    tileSize = 8,
    edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
SelfBar:SetBackdropColor(unpack(Theme.BG_PANEL))
SelfBar:SetBackdropBorderColor(unpack(Theme.BORDER_MAIN))

-- vertical separator between summary text and declare buttons
local declareSep = SelfBar:CreateTexture(nil, "ARTWORK")
declareSep:SetTexture(Theme.TEX_WHITE)
declareSep:SetVertexColor(unpack(UI.COLOR.SEP))
declareSep:SetWidth(1)
declareSep:SetPoint("RIGHT", SelfBar, "RIGHT", -148, 0)
declareSep:SetPoint("TOP",    SelfBar, "TOP",    0,   -8)
declareSep:SetPoint("BOTTOM", SelfBar, "BOTTOM", 0,    8)

local roleIcon = SelfBar:CreateTexture(nil, "ARTWORK")
roleIcon:SetSize(24, 24)
roleIcon:SetPoint("LEFT", 8, 0)
roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")

local labelTitle = SelfBar:CreateFontString(nil, "OVERLAY", UI.FONT.LABEL)
labelTitle:SetPoint("TOPLEFT", roleIcon, "TOPRIGHT", 8, -2)
labelTitle:SetTextColor(unpack(UI.COLOR.DIM))

local summary = SelfBar:CreateFontString(nil, "OVERLAY", UI.FONT.ROW)
summary:SetPoint("BOTTOMLEFT", roleIcon, "BOTTOMRIGHT", 8, 2)
summary:SetJustifyH("LEFT")
summary:SetWordWrap(false)

local pubBtn = CreateFrame("Button", nil, SelfBar, "BackdropTemplate")
pubBtn:SetSize(128, 28)
pubBtn:SetPoint("RIGHT", SelfBar, "RIGHT", -8, 0)
pubBtn:SetBackdrop({
    bgFile = Theme.TEX_WHITE,
    edgeFile = Theme.TEX_BORDER,
    tile = true,
    tileSize = 8,
    edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
pubBtn:SetBackdropBorderColor(0.28, 0.28, 0.36, 0.85)
local pubText = pubBtn:CreateFontString(nil, "OVERLAY", UI.FONT.BTN)
pubText:SetPoint("CENTER", 0, 0)
pubText:SetTextColor(unpack(Theme.BTN_TEXT))

local function MakeRolePick(roleCode, texCoords)
    local b = CreateFrame("Button", nil, SelfBar, "BackdropTemplate")
    b:SetSize(30, 30)
    b.roleCode = roleCode
    b:SetBackdrop({
        edgeFile = Theme.TEX_BORDER,
        tile = true,
        tileSize = 8,
        edgeSize = 8,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    b:SetBackdropBorderColor(0.25, 0.25, 0.32, 0.70)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints(b)
    b.bg:SetTexture(Theme.TEX_WHITE)
    b.bg:SetVertexColor(unpack(Theme.BTN_OFF))
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(22, 22)
    b.icon:SetPoint("CENTER", 0, 0)
    if roleCode == "SPEC" then
        b.icon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Waiting")
    else
        b.icon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
        if texCoords then
            b.icon:SetTexCoord(texCoords[1], texCoords[2], texCoords[3], texCoords[4])
        end
    end
    b:SetScript("OnEnter", function(self)
        if not self.active then
            self.bg:SetVertexColor(unpack(UI.COLOR.BTN_HOVER))  -- file-specific hover shade
            self:SetBackdropBorderColor(0.38, 0.38, 0.50, 0.85)
        end
        GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
        if self.roleCode == "SPEC" then
            GameTooltip:SetText(ns.L.SELF_BAR_BTN_SPEC, 1, 1, 1)
            GameTooltip:AddLine(ns.L.SELF_BAR_TIP_SPEC, 0.75, 0.75, 0.8, true)
        else
            local title = (self.roleCode == "T" and ns.L.ROLE_TANK) or (self.roleCode == "H" and ns.L.ROLE_HEAL) or ns.L.ROLE_DPS
            GameTooltip:SetText(title, 1, 1, 1)
            GameTooltip:AddLine(ns.L.SELF_BAR_TIP_DECLARE, 0.75, 0.75, 0.8, true)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.25, 0.25, 0.32, 0.70)
        if ns.UI.SelfBar and ns.UI.SelfBar._refreshVisuals then
            ns.UI.SelfBar:_refreshVisuals()
        end
        GameTooltip:Hide()
    end)
    return b
end

local TC_T = { 0 / 64, 19 / 64, 22 / 64, 41 / 64 }
local TC_H = { 20 / 64, 39 / 64, 1 / 64, 20 / 64 }
local TC_D = { 20 / 64, 39 / 64, 22 / 64, 41 / 64 }

local btnT = MakeRolePick("T", TC_T)
local btnH = MakeRolePick("H", TC_H)
local btnD = MakeRolePick("D", TC_D)
local btnSpec = MakeRolePick("SPEC", nil)

btnSpec:SetPoint("RIGHT", pubBtn, "LEFT", -10, 0)
btnD:SetPoint("RIGHT", btnSpec, "LEFT", -6, 0)
btnH:SetPoint("RIGHT", btnD, "LEFT", -4, 0)
btnT:SetPoint("RIGHT", btnH, "LEFT", -4, 0)

summary:SetPoint("RIGHT", btnT, "LEFT", -10, 0)

pubBtn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(pubBtn, "ANCHOR_LEFT")
    if ns.PublicNote and ns.PublicNote:IsManaged() then
        GameTooltip:SetText(ns.L.SELF_BAR_PUB_RESTORE_TITLE, 1, 1, 1)
        GameTooltip:AddLine(ns.L.SELF_BAR_PUB_RESTORE_DESC, 0.75, 0.75, 0.8, true)
    else
        GameTooltip:SetText(ns.L.SELF_BAR_PUB_PUSH_TITLE, 1, 1, 1)
        GameTooltip:AddLine(ns.L.SELF_BAR_PUB_PUSH_DESC, 0.75, 0.75, 0.8, true)
    end
    GameTooltip:Show()
end)
pubBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

local function PubAllowed()
    if not IsInGuild() then return false end
    if not ns.Notes or not ns.Notes.EffectiveCanEditPublicNote then return false end
    return ns.Notes:EffectiveCanEditPublicNote()
end

pubBtn:SetScript("OnClick", function()
    if not IsInGuild() then return end
    if not PubAllowed() then
        print(ns.L.BRAND .. " " .. ns.L.PUBNOTE_NO_PERM)
        return
    end
    if not ns.PublicNote then return end
    if ns.PublicNote:IsManaged() then
        ns.PublicNote:Restore(false)
    else
        ns.PublicNote:Push()
    end
    if ns.UI.SelfBar and ns.UI.SelfBar.Refresh then ns.UI.SelfBar:Refresh() end
end)

btnT:SetScript("OnClick", function()
    if ns.Roles then ns.Roles:SetMine("T") end
end)
btnH:SetScript("OnClick", function()
    if ns.Roles then ns.Roles:SetMine("H") end
end)
btnD:SetScript("OnClick", function()
    if ns.Roles then ns.Roles:SetMine("D") end
end)
btnSpec:SetScript("OnClick", function()
    if ns.Roles then ns.Roles:SetMine(nil) end
end)

function SelfBar:_refreshVisuals()
    local me = UnitName("player")
    local declared = ns.Roles and me and ns.Roles:Get(me) or nil
    for _, b in ipairs({ btnT, btnH, btnD, btnSpec }) do
        b.active = false
    end
    if declared then
        if declared == "T" then btnT.active = true
        elseif declared == "H" then btnH.active = true
        elseif declared == "D" then btnD.active = true end
    else
        btnSpec.active = true
    end
    for _, b in ipairs({ btnT, btnH, btnD }) do
        b.bg:SetVertexColor(unpack(b.active and Theme.BTN_ON or Theme.BTN_OFF))
        if b.SetBackdropBorderColor then
            if b.active then
                b:SetBackdropBorderColor(0.22, 0.55, 0.82, 0.90)
            else
                b:SetBackdropBorderColor(0.25, 0.25, 0.32, 0.70)
            end
        end
    end
    btnSpec.bg:SetVertexColor(unpack(btnSpec.active and UI.COLOR.BTN_AUTO_ON or Theme.BTN_OFF))
    if btnSpec.SetBackdropBorderColor then
        if btnSpec.active then
            btnSpec:SetBackdropBorderColor(0.14, 0.45, 0.22, 0.90)
        else
            btnSpec:SetBackdropBorderColor(0.25, 0.25, 0.32, 0.70)
        end
    end
end

function SelfBar:Refresh()
    labelTitle:SetText(ns.L.SELF_BAR_TITLE)
    local me = UnitName("player")
    if not me then return end
    pubBtn:SetShown(IsInGuild())
    local _, class = UnitClass("player")
    local eff = ns.Roles and ns.Roles:GetEffectiveRole(me, class) or nil
    if eff then
        roleIcon:Show()
        ns.UI:SetRolePortraitTexture(roleIcon, eff)
    else
        roleIcon:Hide()
    end

    local roleWord = ""
    if eff == "T" then roleWord = ns.L.ROLE_TANK
    elseif eff == "H" then roleWord = ns.L.ROLE_HEAL
    elseif eff == "D" then roleWord = ns.L.ROLE_DPS
    else roleWord = ns.L.SELF_BAR_UNKNOWN_ROLE end

    local specStr = ""
    if ns.Specs and class then
        local sid = ns.Specs:GetSpec(me)
        local meta = ns.Specs:GetSpecMeta(class, sid)
        if meta then specStr = meta.short end
    end
    local specPart = ""
    if specStr ~= "" then
        specPart = "  |cffaaaaaa· " .. specStr .. "|r"
    end
    local declared = ns.Roles and ns.Roles:Get(me)
    local src = declared and ns.L.SELF_BAR_SOURCE_DECLARED or ns.L.SELF_BAR_SOURCE_SPEC
    summary:SetText(string.format("|cffffffff%s|r%s  |cff778899· %s|r", roleWord, specPart, src))

    if IsInGuild() and not PubAllowed() then
        pubBtn:SetAlpha(0.5)
        pubText:SetText(ns.L.SELF_BAR_PUB_NO_PERM)
        pubBtn:SetBackdropColor(0.12, 0.12, 0.14, 0.9)
    elseif IsInGuild() then
        pubBtn:SetAlpha(1)
        if ns.PublicNote and ns.PublicNote:IsManaged() then
            pubBtn:SetBackdropColor(unpack(UI.COLOR.PUB_ON))   -- file-specific green
            pubText:SetText(ns.L.SELF_BAR_PUB_ON)
        else
            pubBtn:SetBackdropColor(unpack(UI.COLOR.PUB_OFF))  -- file-specific dark
            pubText:SetText(ns.L.SELF_BAR_PUB_OFF)
        end
    end

    self:_refreshVisuals()
end

ns.UI.SelfBar = SelfBar

ns.Locale:RegisterCallback(function()
    if SelfBar.Refresh then SelfBar:Refresh() end
end)
