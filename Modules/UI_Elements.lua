local addonName, ns = ...
ns.UI = ns.UI or {}

function ns.UI:GetClassColor(className)
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[className]
    if color then return color.r, color.g, color.b end
    return 1, 1, 1
end

function ns.UI:SetClassCircleTexture(texture, className)
    local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[className]
    texture:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
    if coords then
        texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        texture:Show()
    else
        texture:Hide()
    end
end

function ns.UI:GetClassIcon(className)
    local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[className]
    if coords then
        return string.format(
            "|TInterface\\TargetingFrame\\UI-Classes-Circles:14:14:0:0:256:256:%d:%d:%d:%d|t",
            coords[1] * 256, coords[2] * 256, coords[3] * 256, coords[4] * 256
        )
    end
    return ""
end

local ROLE_PORTRAIT_TEXCOORD = {
    T = { 0 / 64, 19 / 64, 22 / 64, 41 / 64 },
    H = { 20 / 64, 39 / 64, 1 / 64, 20 / 64 },
    D = { 20 / 64, 39 / 64, 22 / 64, 41 / 64 },
}

function ns.UI:SetRolePortraitTexture(texture, role)
    local c = ROLE_PORTRAIT_TEXCOORD[role]
    texture:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
    if c then
        texture:SetTexCoord(c[1], c[2], c[3], c[4])
        texture:Show()
    else
        texture:Hide()
    end
end

function ns.UI:GetRoleIcon(role)
    if role == "T" then
        return "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:0:19:22:41|t"
    elseif role == "H" then
        return "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:20:39:1:20|t"
    elseif role == "D" then
        return "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:20:39:22:41|t"
    end
    return ""
end

function ns.UI:GetRaidLeadIcon()
    return "|TInterface\\GROUPFRAME\\UI-GROUP-LeaderIcon:14:14:0:0|t"
end

function ns.UI:GetAddonPeerIcon()
    return "|TInterface\\RaidFrame\\ReadyCheck-Ready:14:14:0:0|t"
end

function ns.UI:GetOnlineColor(online)
    if online then
        return 0.3, 0.85, 0.3
    end
    return 0.4, 0.4, 0.45
end

function ns.UI:FormatLastOnline(last, online)
    if online then return ns.L.LAST_SEEN_NOW end
    if not last then return ns.L.STATUS_OFFLINE end
    if last.years and last.years > 0 then
        return string.format(ns.L.LAST_SEEN_YEARS, last.years)
    elseif last.months and last.months > 0 then
        return string.format(ns.L.LAST_SEEN_MONTHS, last.months)
    elseif last.days and last.days > 0 then
        return string.format(ns.L.LAST_SEEN_DAYS, last.days)
    elseif last.hours and last.hours > 0 then
        return string.format(ns.L.LAST_SEEN_HOURS, last.hours)
    end
    return ns.L.STATUS_OFFLINE
end
