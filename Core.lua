local addonName, ns = ...

local logoutReloadSkip = false
if hooksecurefunc and ReloadUI then
    hooksecurefunc("ReloadUI", function()
        logoutReloadSkip = true
    end)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("GUILD_ROSTER_UPDATE")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        do
            local v
            if C_AddOns and C_AddOns.GetAddOnMetadata then
                v = C_AddOns.GetAddOnMetadata(addonName, "Version")
            end
            if (not v or v == "") and GetAddOnMetadata then
                v = GetAddOnMetadata(addonName, "Version")
            end
            ns.addonVersion = (v and v ~= "") and v:gsub("|", "") or "?"
        end
        ns.Database:Initialize()
        ns.Locale:Activate()
        ns.Database:ApplySchemaUpgrades()
        ns.Locale:RunCallbacks()
        if ns.Comms and ns.Comms.Init then ns.Comms:Init() end
        if ns.Schedule and ns.Schedule.Init then ns.Schedule:Init() end
        if ns.Signups and ns.Signups.Init then ns.Signups:Init() end
        if ns.Specs and ns.Specs.Init then ns.Specs:Init() end
        if ns.Roles and ns.Roles.Init then ns.Roles:Init() end
        if ns.PublicNote and ns.PublicNote.Init then ns.PublicNote:Init() end
        if ns.LFG and ns.LFG.Init then ns.LFG:Init() end
        if ns.Professions and ns.Professions.Init then ns.Professions:Init() end
        if ns.RaidFormation and ns.RaidFormation.Init then ns.RaidFormation:Init() end
    elseif event == "PLAYER_LOGIN" then
        print(ns.L.BRAND .. " " .. string.format(ns.L.LOGIN_READY, ns.addonVersion or "?"))
        if GuildRoster then GuildRoster() end
        ns.Scanner:ParseGuildNotes()
        if ns.Schedule and ns.Schedule.RequestSync then ns.Schedule:RequestSync() end
        if ns.Specs and ns.Specs.RequestSync then ns.Specs:RequestSync() end
        if ns.Roles and ns.Roles.RequestSync then ns.Roles:RequestSync() end
        if ns.LFG and ns.LFG.RequestSync then ns.LFG:RequestSync() end
        if ns.Professions and ns.Professions.RequestSync then ns.Professions:RequestSync() end
        if C_Timer and C_Timer.After then
            C_Timer.After(3, function()
                if ns.PublicNote and ns.PublicNote.Reapply then ns.PublicNote:Reapply() end
            end)
            C_Timer.After(5, function()
                if ns.Comms and ns.Comms.PushHello then ns.Comms:PushHello() end
            end)
        else
            if ns.Comms and ns.Comms.PushHello then ns.Comms:PushHello() end
        end
    elseif event == "PLAYER_LOGOUT" then
        if logoutReloadSkip then
            logoutReloadSkip = false
        elseif ns.LFG and ns.LFG.ClearMineOnLogout then
            ns.LFG:ClearMineOnLogout()
        end
    elseif event == "GUILD_ROSTER_UPDATE" or event == "GROUP_ROSTER_UPDATE" then
        ns.Scanner:ParseGuildNotes()
    end
end)
