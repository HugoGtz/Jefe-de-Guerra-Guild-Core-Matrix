local addonName, ns = ...
ns.RaidFormation = ns.RaidFormation or {}

local pending
local rosterDebounceGen = 0
local pulseGen = 0
local watchCoreKey
local watchUntil = 0

local function NameKey(name)
    return Ambiguate(name or "", "none")
end

local function RaidUnitNameKey(u)
    if not UnitExists(u) then return "" end
    if UnitIsPlayer and UnitIsPlayer(u) == false then return "" end
    local full = UnitFullName(u)
    if full and full ~= "" then
        return Ambiguate(full, "none")
    end
    local n = UnitName(u)
    if not n then return "" end
    return Ambiguate(n, "none")
end

local function PlayerIsLeader()
    if UnitIsGroupLeader and UnitIsGroupLeader("player") then return true end
    if UnitIsPartyLeader and UnitIsPartyLeader("player") then return true end
    return false
end

local function InAnyGroup()
    if IsInGroup and IsInGroup() then return true end
    if IsInRaid and IsInRaid() then return true end
    local pm = GetNumPartyMembers and GetNumPartyMembers() or 0
    return pm > 0
end

local function PartyHasAnotherMember()
    local pm = GetNumPartyMembers and GetNumPartyMembers() or 0
    if pm >= 1 then return true end
    if UnitExists("party1") then return true end
    return false
end

local function GetConvertToRaidFn()
    local cp = C_PartyInfo
    if cp and type(cp.ConvertToRaid) == "function" then return cp.ConvertToRaid end
    if type(ConvertToRaid) == "function" then return ConvertToRaid end
    return nil
end

local function ConvertPartyToRaid()
    if IsInRaid and IsInRaid() then return true end
    if not PlayerIsLeader() then return false end
    if not PartyHasAnotherMember() then return false end
    local fn = GetConvertToRaidFn()
    if fn then
        fn()
        return true
    end
    return false
end

local function GetPromoteToAssistantFn()
    local cp = C_PartyInfo
    if cp and type(cp.PromoteToAssistant) == "function" then return cp.PromoteToAssistant end
    if type(PromoteToAssistant) == "function" then return PromoteToAssistant end
    return nil
end

local function GetSetLootMethodFn()
    if type(SetLootMethod) == "function" then return SetLootMethod end
    return nil
end

local function IsRaidAssistantUnit(unit)
    if UnitIsGroupAssistant and UnitIsGroupAssistant(unit) then return true end
    if UnitIsRaidAssistant and UnitIsRaidAssistant(unit) == true then return true end
    if UnitIsRaidOfficer and UnitIsGroupLeader then
        return UnitIsRaidOfficer(unit) and not UnitIsGroupLeader(unit)
    end
    return false
end

local function IterateRaidUnits(fn)
    if not IsInRaid or not IsInRaid() then return end
    for i = 1, 40 do
        local u = "raid" .. i
        if UnitExists(u) then
            if not UnitIsPlayer or UnitIsPlayer(u) ~= false then
                fn(u)
            end
        end
    end
end

local function RaidUnitForNameKey(nk)
    if not nk or nk == "" then return nil end
    if not IsInRaid or not IsInRaid() then return nil end
    for i = 1, 40 do
        local u = "raid" .. i
        if UnitExists(u) then
            local uk = RaidUnitNameKey(u)
            if uk ~= "" and uk == nk then return u end
        end
    end
    return nil
end

local function ApplyAssistPromotions(keys)
    local promoteFn = GetPromoteToAssistantFn()
    if not promoteFn then return end
    if not IsInRaid or not IsInRaid() then return end
    local slot = 0
    IterateRaidUnits(function(u)
        local nk = RaidUnitNameKey(u)
        if nk == "" or not keys[nk] then return end
        if UnitIsGroupLeader and UnitIsGroupLeader(u) then return end
        if IsRaidAssistantUnit(u) then return end
        slot = slot + 1
        local unitCopy = u
        local delay = (slot - 1) * 0.12
        if C_Timer and C_Timer.After then
            C_Timer.After(delay, function()
                if UnitExists(unitCopy) then
                    local name = UnitName(unitCopy)
                    if name and name ~= "" then promoteFn(name) end
                end
            end)
        else
            local name = UnitName(u)
            if name and name ~= "" then promoteFn(name) end
        end
    end)
end

local function ApplyLootMaster(nk)
    local sm = GetSetLootMethodFn()
    if not sm then return false end
    if not nk or nk == "" then return true end
    if not IsInRaid or not IsInRaid() then return false end
    if not PlayerIsLeader() then return false end
    local u = RaidUnitForNameKey(nk)
    if not u then return false end
    local nm = UnitName(u)  -- Classic API expects plain name, no realm suffix
    if not nm or nm == "" then return false end
    sm("master", nm)
    return true
end

local function ParseCoreKey(coreKey)
    local tc, sid = coreKey:match("^(%a)(%d+)$")
    if not tc or not sid then return nil, nil end
    return tc, tonumber(sid)
end

local function BuildPromoteKeysAndLootNK(coreKey, fullMembers)
    local promoteKeys = {}
    for _, m in ipairs(fullMembers or {}) do
        if m.role == "T" or m.lead == true or m.lootMaster == true then
            promoteKeys[NameKey(m.name)] = true
            if m.rosterName and m.rosterName ~= "" then
                promoteKeys[NameKey(m.rosterName)] = true
            end
        end
    end
    local lootNK = ns.Database and ns.Database.GetCoreLootMaster and ns.Database:GetCoreLootMaster(coreKey)
    if lootNK == "" then lootNK = nil end
    if not lootNK then
        for _, m in ipairs(fullMembers or {}) do
            if m.lootMaster == true then
                local nk = NameKey(m.name)
                if nk ~= "" then
                    lootNK = nk
                    break
                end
                nk = NameKey(m.rosterName or "")
                if nk ~= "" then
                    lootNK = nk
                    break
                end
            end
        end
    end
    return promoteKeys, lootNK
end

local formationFrame

local function ClearPending()
    rosterDebounceGen = rosterDebounceGen + 1
    pulseGen = pulseGen + 1
    pending = nil
end

local function ScheduleFormationPulses(invitedCount)
    if not C_Timer or not C_Timer.After then
        ns.RaidFormation:RosterTickImmediate()
        return
    end
    local gap = 0.35
    if ns.InviteTools and ns.InviteTools.GetInviteGapSeconds then
        gap = ns.InviteTools:GetInviteGapSeconds()
    end
    local n = tonumber(invitedCount) or 0
    local first = (n <= 0) and 0.75 or math.min(12.0, math.max(0.85, (n - 1) * gap + 1.2))
    local pg = pulseGen
    local delays = { first, first + 2.5, first + 6.5, first + 14.0, first + 25.0, first + 45.0 }
    for i = 1, #delays do
        local d = delays[i]
        C_Timer.After(d, function()
            if pg ~= pulseGen then return end
            if pending then ns.RaidFormation:RosterTickImmediate() end
        end)
    end
end

local function PendingFormationApply()
    if not pending then return end
    if not PlayerIsLeader() then return end
    if not InAnyGroup() then return end
    local tc, cid = ParseCoreKey(pending.coreKey)
    if not tc or not cid then return end
    local fullMembers = ns.Scanner and ns.Scanner.GetMembersForCore and ns.Scanner:GetMembersForCore(tc, cid) or {}
    local promoteKeys, lootNK = BuildPromoteKeysAndLootNK(pending.coreKey, fullMembers)

    if not IsInRaid or not IsInRaid() then
        if PartyHasAnotherMember() then
            ConvertPartyToRaid()
        end
        return
    end

    if not pending.saidRaid then
        pending.saidRaid = true
        if ns.L and ns.L.RAID_FORM_CONVERTED then
            print(ns.L.BRAND_GREEN .. " " .. ns.L.RAID_FORM_CONVERTED)
        end
    end

    ApplyAssistPromotions(promoteKeys)

    if not pending.saidAssist then
        pending.saidAssist = true
        if ns.L and ns.L.RAID_FORM_ASSISTS then
            print(ns.L.BRAND_GREEN .. " " .. ns.L.RAID_FORM_ASSISTS)
        end
    end

    if lootNK then
        if ApplyLootMaster(lootNK) then
            if not pending.saidLoot then
                pending.saidLoot = true
                if ns.L and ns.L.RAID_FORM_LOOT then
                    print(ns.L.BRAND_GREEN .. " " .. string.format(ns.L.RAID_FORM_LOOT, lootNK))
                end
            end
        end
    end
end

local function WatchIncrementalApply()
    if pending then return end
    if not watchCoreKey or watchCoreKey == "" then return end
    if GetTime() > watchUntil then return end
    if not PlayerIsLeader() then return end
    if not InAnyGroup() then return end
    local tc, cid = ParseCoreKey(watchCoreKey)
    if not tc or not cid or tc == "U" then return end
    local fullMembers = ns.Scanner and ns.Scanner.GetMembersForCore and ns.Scanner:GetMembersForCore(tc, cid) or {}
    local promoteKeys, lootNK = BuildPromoteKeysAndLootNK(watchCoreKey, fullMembers)

    if not IsInRaid or not IsInRaid() then
        if PartyHasAnotherMember() then
            ConvertPartyToRaid()
        end
        return
    end

    ApplyAssistPromotions(promoteKeys)
    if lootNK then
        ApplyLootMaster(lootNK)
    end
end

function ns.RaidFormation:SetWatchCore(coreKey)
    self:Init()
    if type(coreKey) ~= "string" or coreKey == "" then return end
    if pending and pending.coreKey ~= coreKey then
        ClearPending()
    end
    watchCoreKey = coreKey
    watchUntil = GetTime() + 7200
end

function ns.RaidFormation:Begin(coreKey, fullMembers, opts)
    opts = opts or {}
    self:Init()
    if type(coreKey) ~= "string" or coreKey == "" then return end
    ClearPending()
    pending = {
        expires = GetTime() + 240,
        coreKey = coreKey,
        saidRaid = false,
        saidAssist = false,
        saidLoot = false,
    }
    self:SetWatchCore(coreKey)
    ScheduleFormationPulses(opts.invitedCount or 0)
end

function ns.RaidFormation:RosterTickImmediate()
    if pending then
        if GetTime() > pending.expires then
            if ns.L and ns.L.RAID_FORM_EXPIRE then
                print(ns.L.BRAND_YELLOW .. " " .. ns.L.RAID_FORM_EXPIRE)
            end
            ClearPending()
        else
            PendingFormationApply()
        end
    end
    WatchIncrementalApply()
end

function ns.RaidFormation:ProcessTick(immediate)
    if immediate ~= true then
        rosterDebounceGen = rosterDebounceGen + 1
        local g = rosterDebounceGen
        if C_Timer and C_Timer.After then
            C_Timer.After(0.45, function()
                if g ~= rosterDebounceGen then return end
                ns.RaidFormation:RosterTickImmediate()
            end)
        else
            self:RosterTickImmediate()
        end
        return
    end
    self:RosterTickImmediate()
end

function ns.RaidFormation:OnGroupRosterUpdate()
    self:ProcessTick(false)
end

function ns.RaidFormation:Init()
    if formationFrame then return end
    formationFrame = CreateFrame("Frame")
    formationFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    formationFrame:SetScript("OnEvent", function()
        ns.RaidFormation:OnGroupRosterUpdate()
    end)
end
