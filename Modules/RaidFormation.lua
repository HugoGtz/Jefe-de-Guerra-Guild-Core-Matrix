local addonName, ns = ...
ns.RaidFormation = ns.RaidFormation or {}

local pending
local debouncePending

local function NameKey(name)
    return Ambiguate(name or "", "none")
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
    return pm >= 1
end

local function ConvertPartyToRaid()
    if IsInRaid and IsInRaid() then return true end
    if not PlayerIsLeader() then return false end
    if not PartyHasAnotherMember() then return false end
    if C_PartyInfo and C_PartyInfo.ConvertToRaid then
        C_PartyInfo.ConvertToRaid()
        return true
    end
    if ConvertToRaid then
        ConvertToRaid()
        return true
    end
    return false
end

local function IsRaidAssistantUnit(unit)
    if UnitIsRaidAssistant then return UnitIsRaidAssistant(unit) == true end
    if UnitIsRaidOfficer and UnitIsGroupLeader then
        return UnitIsRaidOfficer(unit) and not UnitIsGroupLeader(unit)
    end
    return false
end

local function IterateRaidUnits(fn)
    if not IsInRaid or not IsInRaid() then return end
    local n = GetNumRaidMembers and GetNumRaidMembers() or 0
    for i = 1, n do
        local u = "raid" .. i
        if UnitExists(u) then fn(u) end
    end
end

local function RaidUnitForNameKey(nk)
    if not nk or nk == "" then return nil end
    if not IsInRaid or not IsInRaid() then return nil end
    local n = GetNumRaidMembers and GetNumRaidMembers() or 0
    for i = 1, n do
        local u = "raid" .. i
        if UnitExists(u) and NameKey(UnitName(u)) == nk then return u end
    end
    return nil
end

local function ApplyAssistPromotions(keys)
    if not PromoteToAssistant then return end
    if not IsInRaid or not IsInRaid() then return end
    local slot = 0
    IterateRaidUnits(function(u)
        local nk = NameKey(UnitName(u))
        if not keys[nk] then return end
        if UnitIsGroupLeader and UnitIsGroupLeader(u) then return end
        if IsRaidAssistantUnit(u) then return end
        slot = slot + 1
        local unitCopy = u
        local delay = (slot - 1) * 0.12
        if C_Timer and C_Timer.After then
            C_Timer.After(delay, function()
                if UnitExists(unitCopy) and PromoteToAssistant then
                    PromoteToAssistant(unitCopy)
                end
            end)
        else
            PromoteToAssistant(unitCopy)
        end
    end)
end

local function ApplyLootMaster(nk)
    if not nk or nk == "" then return true end
    if not SetLootMethod then return false end
    if not IsInRaid or not IsInRaid() then return false end
    if not PlayerIsLeader() then return false end
    local u = RaidUnitForNameKey(nk)
    if not u then return false end
    local nm = UnitName(u)
    if not nm or nm == "" then return false end
    SetLootMethod("master", nm)
    return true
end

local formationFrame

local function ClearPending()
    if formationFrame then
        formationFrame:UnregisterEvent("GROUP_ROSTER_UPDATE")
    end
    pending = nil
    debouncePending = nil
end

function ns.RaidFormation:Begin(coreKey, fullMembers)
    self:Init()
    if type(coreKey) ~= "string" or coreKey == "" then return end
    ClearPending()
    local promoteKeys = {}
    for _, m in ipairs(fullMembers or {}) do
        if m.role == "T" or m.lead == true then
            promoteKeys[NameKey(m.name)] = true
        end
    end
    local lootNK = ns.Database and ns.Database.GetCoreLootMaster and ns.Database:GetCoreLootMaster(coreKey)
    if lootNK == "" then lootNK = nil end
    pending = {
        expires = GetTime() + 240,
        promoteKeys = promoteKeys,
        lootMasterNK = lootNK,
        saidRaid = false,
        saidAssist = false,
        saidLoot = false,
    }
    formationFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    if C_Timer and C_Timer.After then
        C_Timer.After(0.4, function() ns.RaidFormation:ProcessTick(true) end)
    else
        self:ProcessTick(true)
    end
end

function ns.RaidFormation:ProcessTick(immediate)
    if not pending then return end
    if GetTime() > pending.expires then
        if ns.L and ns.L.RAID_FORM_EXPIRE then
            print(ns.L.BRAND_YELLOW .. " " .. ns.L.RAID_FORM_EXPIRE)
        end
        ClearPending()
        return
    end
    if immediate ~= true then
        if debouncePending then return end
        debouncePending = true
        if C_Timer and C_Timer.After then
            C_Timer.After(0.45, function()
                debouncePending = nil
                ns.RaidFormation:ProcessTick(true)
            end)
        else
            debouncePending = nil
            self:ProcessTick(true)
        end
        return
    end
    if not PlayerIsLeader() then return end
    if not InAnyGroup() then return end

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

    ApplyAssistPromotions(pending.promoteKeys)

    if not pending.saidAssist then
        pending.saidAssist = true
        if ns.L and ns.L.RAID_FORM_ASSISTS then
            print(ns.L.BRAND_GREEN .. " " .. ns.L.RAID_FORM_ASSISTS)
        end
    end

    if pending.lootMasterNK then
        if ApplyLootMaster(pending.lootMasterNK) then
            if not pending.saidLoot then
                pending.saidLoot = true
                if ns.L and ns.L.RAID_FORM_LOOT then
                    print(ns.L.BRAND_GREEN .. " " .. string.format(ns.L.RAID_FORM_LOOT, pending.lootMasterNK))
                end
            end
        end
    end
end

function ns.RaidFormation:OnGroupRosterUpdate()
    self:ProcessTick(false)
end

function ns.RaidFormation:Init()
    if formationFrame then return end
    formationFrame = CreateFrame("Frame")
    formationFrame:SetScript("OnEvent", function()
        ns.RaidFormation:OnGroupRosterUpdate()
    end)
end
