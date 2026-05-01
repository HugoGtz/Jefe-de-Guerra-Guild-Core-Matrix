local _, ns = ...
local MainFrame = ns.UI.MainFrame

local RADIUS = 5

local minimapShapes = {
    ["ROUND"] = { true, true, true, true },
    ["SQUARE"] = { false, false, false, false },
    ["CORNER-TOPLEFT"] = { false, false, false, true },
    ["CORNER-TOPRIGHT"] = { false, false, true, false },
    ["CORNER-BOTTOMLEFT"] = { false, true, false, false },
    ["CORNER-BOTTOMRIGHT"] = { true, false, false, false },
    ["SIDE-LEFT"] = { false, true, false, true },
    ["SIDE-RIGHT"] = { true, false, true, false },
    ["SIDE-TOP"] = { false, false, true, true },
    ["SIDE-BOTTOM"] = { true, true, false, false },
    ["TRICORNER-TOPLEFT"] = { false, true, true, true },
    ["TRICORNER-TOPRIGHT"] = { true, false, true, true },
    ["TRICORNER-BOTTOMLEFT"] = { true, true, false, true },
    ["TRICORNER-BOTTOMRIGHT"] = { true, true, true, false },
}

local MinimapBtn = CreateFrame("Button", "GCM_MinimapButton", Minimap)
MinimapBtn:SetSize(31, 31)
MinimapBtn:EnableMouse(true)
MinimapBtn:SetFrameStrata("MEDIUM")
MinimapBtn:SetFrameLevel(8)
if MinimapBtn.SetFixedFrameStrata then MinimapBtn:SetFixedFrameStrata(true) end
if MinimapBtn.SetFixedFrameLevel then MinimapBtn:SetFixedFrameLevel(true) end
MinimapBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
MinimapBtn:RegisterForDrag("LeftButton")
MinimapBtn:RegisterForClicks("AnyUp")

local icon = MinimapBtn:CreateTexture(nil, "BACKGROUND")
icon:SetSize(22, 22)
icon:SetPoint("CENTER", 0, 0)
icon:SetTexture("Interface\\AddOns\\GuildCoreMatrix\\Media\\logo")

local border = MinimapBtn:CreateTexture(nil, "OVERLAY")
border:SetSize(53, 53)
border:SetPoint("TOPLEFT")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

local draggingMinimapBtn = false

local sqrt, max, min = math.sqrt, math.max, math.min

local function UpdateMinimapPos()
    local raw = GCM_Settings and GCM_Settings.minimapPos
    local position = raw or 45
    if type(position) ~= "number" or position ~= position then
        position = 45
    end
    position = position % 360
    local angle = math.rad(position)
    local x, y = math.cos(angle), math.sin(angle)
    local q = 1
    if x < 0 then q = q + 1 end
    if y > 0 then q = q + 2 end
    local minimapShape = GetMinimapShape and GetMinimapShape() or "ROUND"
    local quadTable = minimapShapes[minimapShape]
    local w = (Minimap:GetWidth() / 2) + RADIUS
    local h = (Minimap:GetHeight() / 2) + RADIUS
    if quadTable[q] then
        x, y = x * w, y * h
    else
        local diagRadiusW = sqrt(2 * (w ^ 2)) - 10
        local diagRadiusH = sqrt(2 * (h ^ 2)) - 10
        x = max(-w, min(x * diagRadiusW, w))
        y = max(-h, min(y * diagRadiusH, h))
    end
    MinimapBtn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function DragOnUpdate()
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    px, py = px / scale, py / scale
    local pos = math.deg(math.atan2(py - my, px - mx)) % 360
    if GCM_Settings then
        GCM_Settings.minimapPos = pos
    end
    UpdateMinimapPos()
end

MinimapBtn:SetScript("OnDragStart", function(self)
    self.dragMoved = false
    draggingMinimapBtn = true
    local sx, sy = GetCursorPosition()
    self:LockHighlight()
    self:SetScript("OnUpdate", function()
        local cx, cy = GetCursorPosition()
        local dx, dy = cx - sx, cy - sy
        if dx * dx + dy * dy >= 64 then
            self.dragMoved = true
        end
        DragOnUpdate()
    end)
end)

MinimapBtn:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    self:UnlockHighlight()
    draggingMinimapBtn = false
    DragOnUpdate()
end)

MinimapBtn:SetScript("OnClick", function(self)
    if self.dragMoved then
        self.dragMoved = false
        return
    end
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
f:RegisterEvent("MINIMAP_UPDATE_ZOOM")
f:SetScript("OnEvent", function(_, ev)
    if draggingMinimapBtn then return end
    UpdateMinimapPos()
    if ev == "PLAYER_LOGIN" and C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if not draggingMinimapBtn then UpdateMinimapPos() end
        end)
    end
end)

UpdateMinimapPos()
