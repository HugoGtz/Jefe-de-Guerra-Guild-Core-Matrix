local addonName, ns = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("GUILD_ROSTER_UPDATE")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        ns.Database:Initialize()
        ns.Locale:Activate()
        ns.Locale:RunCallbacks()
        if ns.Comms and ns.Comms.Init then ns.Comms:Init() end
        if ns.Schedule and ns.Schedule.Init then ns.Schedule:Init() end
        if ns.Signups and ns.Signups.Init then ns.Signups:Init() end
        if ns.Specs and ns.Specs.Init then ns.Specs:Init() end
    elseif event == "PLAYER_LOGIN" then
        print(ns.L.BRAND .. " " .. ns.L.LOGIN_READY)
        if GuildRoster then GuildRoster() end
        ns.Scanner:ParseGuildNotes()
        if ns.Schedule and ns.Schedule.RequestSync then ns.Schedule:RequestSync() end
        if ns.Specs and ns.Specs.RequestSync then ns.Specs:RequestSync() end
    elseif event == "GUILD_ROSTER_UPDATE" or event == "GROUP_ROSTER_UPDATE" then
        ns.Scanner:ParseGuildNotes()
    end
end)
