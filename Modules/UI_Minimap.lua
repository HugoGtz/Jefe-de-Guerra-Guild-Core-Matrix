local addonName, ns = ...
local MainFrame = ns.UI.MainFrame

local MinimapBtn = CreateFrame("Button", "GCM_MinimapButton", Minimap)
MinimapBtn:SetSize(31, 31)
MinimapBtn:SetFrameStrata("MEDIUM")
MinimapBtn:SetFrameLevel(10)
MinimapBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local icon = MinimapBtn:CreateTexture(nil, "BACKGROUND")
icon:SetSize(22, 22)
icon:SetPoint("CENTER", 0, 0)
icon:SetTexture("Interface\\AddOns\\GuildCoreMatrix\\Media\\logo")

local border = MinimapBtn:CreateTexture(nil, "OVERLAY")
border:SetSize(53, 53)
border:SetPoint("TOPLEFT")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

local function UpdateMinimapPos()
    local angle = (GCM_Settings and GCM_Settings.minimapPos) or 45
    MinimapBtn:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 52 - (80 * cos(angle)), (80 * sin(angle)) - 52)
end

MinimapBtn:SetMovable(true)
MinimapBtn:RegisterForDrag("LeftButton")
MinimapBtn:SetScript("OnDragStart", function(self)
    self:LockHighlight()
    self:SetScript("OnUpdate", function()
        local x, y = GetCursorPosition()
        local xScale, yScale = Minimap:GetEffectiveScale()
        local centerX, centerY = Minimap:GetCenter()
        local angle = deg(atan2(y / yScale - centerY, x / xScale - centerX))
        GCM_Settings.minimapPos = angle
        UpdateMinimapPos()
    end)
end)

MinimapBtn:SetScript("OnDragStop", function(self)
    self:UnlockHighlight()
    self:SetScript("OnUpdate", nil)
end)

MinimapBtn:SetScript("OnClick", function()
    if MainFrame:IsShown() then
        MainFrame:Hide()
    else
        ns.Scanner:ParseGuildNotes()
        MainFrame:Show()
    end
end)

MinimapBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(ns.L.TOOLTIP_TITLE)
    GameTooltip:Show()
end)
MinimapBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function() UpdateMinimapPos() end)
