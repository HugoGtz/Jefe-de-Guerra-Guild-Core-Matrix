local addonName, ns = ...
ns.Database = {}

local DEFAULTS = {
    minimapPos = 45,
    locale = nil,
    framePosition = nil,
    frameWidth = 450,
    frameHeight = 550,
    collapsed = {},
    forceCanWrite = false,
}

local SCHEMA_VERSION = 4

local MIGRATE_SLASH_UNIT_NAME = "Rayzorok"

local function ManualMigrateSlashGate()
    if type(MIGRATE_SLASH_UNIT_NAME) ~= "string" or MIGRATE_SLASH_UNIT_NAME == "" then
        return nil
    end
    local n = UnitName("player")
    if not n then return false end
    return n == MIGRATE_SLASH_UNIT_NAME
end

local function DeepCopy(x, seen)
    local ty = type(x)
    if ty ~= "table" then return x end
    seen = seen or {}
    if seen[x] then return seen[x] end
    local out = {}
    seen[x] = out
    for k, v in pairs(x) do
        out[DeepCopy(k, seen)] = DeepCopy(v, seen)
    end
    return out
end

local function SnapshotMigrationState()
    return {
        schedules = DeepCopy(GCM_Sync.schedules),
        signups = DeepCopy(GCM_Sync.signups),
        collapsed = DeepCopy(GCM_Settings.collapsed),
    }
end

local function RestoreMigrationState(snap)
    wipe(GCM_Sync.schedules)
    for k, v in pairs(snap.schedules) do
        GCM_Sync.schedules[k] = DeepCopy(v)
    end
    wipe(GCM_Sync.signups)
    for k, v in pairs(snap.signups) do
        GCM_Sync.signups[k] = DeepCopy(v)
    end
    wipe(GCM_Settings.collapsed)
    for k, v in pairs(snap.collapsed) do
        GCM_Settings.collapsed[k] = v
    end
end

local function LegacyCoreKeyToC(key)
    local prefix, num = key:match("^([kKG])(%d+)$")
    if prefix and num then
        return "C" .. num
    end
    return key
end

local function MergeScheduleEntry(a, b)
    if not a then return b end
    if not b then return a end
    return ((a.updatedAt or 0) >= (b.updatedAt or 0)) and a or b
end

function ns.Database:MigrateLegacyCoreKeys()
    if not GCM_Sync then return end
    local schedules = GCM_Sync.schedules
    if type(schedules) == "table" then
        local snap = {}
        for k, v in pairs(schedules) do snap[k] = v end
        wipe(schedules)
        for k, v in pairs(snap) do
            local nk = LegacyCoreKeyToC(k)
            schedules[nk] = MergeScheduleEntry(schedules[nk], v)
        end
    end
    local signups = GCM_Sync.signups
    if type(signups) == "table" then
        local snap = {}
        for k, v in pairs(signups) do snap[k] = v end
        wipe(signups)
        for k, v in pairs(snap) do
            local corePart, slotIdx = k:match("^(.+)#(%d+)$")
            if corePart and slotIdx then
                local nk = LegacyCoreKeyToC(corePart) .. "#" .. slotIdx
                signups[nk] = v
            else
                signups[k] = v
            end
        end
    end
    local collapsed = GCM_Settings.collapsed
    if type(collapsed) == "table" then
        local nextCollapsed = {}
        for key, val in pairs(collapsed) do
            if val then
                nextCollapsed[LegacyCoreKeyToC(key)] = true
            end
        end
        GCM_Settings.collapsed = nextCollapsed
    end
end

local function MergeSignupBench(a, b)
    if not a then return b end
    if not b then return a end
    local wa = tonumber(a.weekKey) or 0
    local wb = tonumber(b.weekKey) or 0
    local chosen = wa >= wb and a or b
    local other = wa >= wb and b or a
    if other.weekKey ~= chosen.weekKey then return chosen end
    chosen.states = chosen.states or {}
    for name, st in pairs(other.states or {}) do
        if chosen.states[name] == nil then
            chosen.states[name] = st
        end
    end
    return chosen
end

function ns.Database:NormalizeBenchKeys()
    if not GCM_Sync then return end
    local schedules = GCM_Sync.schedules
    if type(schedules) == "table" then
        local snap = {}
        for k, val in pairs(schedules) do snap[k] = val end
        local extras = {}
        for k, val in pairs(snap) do
            local n = tonumber(k:match("^B(%d+)$"))
            if n and n > 1 then
                extras[#extras + 1] = val
                schedules[k] = nil
            end
        end
        for _, val in ipairs(extras) do
            schedules["B1"] = MergeScheduleEntry(schedules["B1"], val)
        end
    end
    local signups = GCM_Sync.signups
    if type(signups) == "table" then
        local snap = {}
        for k, v in pairs(signups) do snap[k] = v end
        for k, v in pairs(snap) do
            local bn, slotIdx = k:match("^B(%d+)#(%d+)$")
            bn = tonumber(bn)
            slotIdx = tonumber(slotIdx)
            if bn and bn > 1 and slotIdx then
                local nk = "B1#" .. slotIdx
                signups[k] = nil
                signups[nk] = MergeSignupBench(signups[nk], v)
            end
        end
    end
    local collapsed = GCM_Settings.collapsed
    if type(collapsed) == "table" then
        local snap = {}
        for key, val in pairs(collapsed) do snap[key] = val end
        for key, val in pairs(snap) do
            local n = tonumber(key:match("^B(%d+)$"))
            if n and n > 1 and val then
                collapsed["B1"] = true
                collapsed[key] = nil
            end
        end
    end
end

function ns.Database:Initialize()
    GCM_Settings = GCM_Settings or {}
    for k, v in pairs(DEFAULTS) do
        if GCM_Settings[k] == nil then
            GCM_Settings[k] = v
        end
    end
    GCM_Settings.collapsed = GCM_Settings.collapsed or {}

    GCM_Cache = GCM_Cache or {}
    ns.Cache = GCM_Cache

    GCM_Sync = GCM_Sync or {}
    GCM_Sync.schedules = GCM_Sync.schedules or {}
    GCM_Sync.signups = GCM_Sync.signups or {}
    GCM_Sync.specs = GCM_Sync.specs or {}
    GCM_Sync.coreRaidPrefs = GCM_Sync.coreRaidPrefs or {}
    GCM_Sync.meta = GCM_Sync.meta or { version = 1 }
    ns.Sync = GCM_Sync

end

function ns.Database:ApplySchemaUpgrades()
    self:NormalizeBenchKeys()
    local prev = tonumber(GCM_Settings.schemaVersion) or 0
    if prev >= SCHEMA_VERSION then
        GCM_Settings.schemaVersion = SCHEMA_VERSION
    end
end

function ns.Database:NeedsManualMigration()
    return (tonumber(GCM_Settings.schemaVersion) or 0) < SCHEMA_VERSION
end

function ns.Database:RunManualLegacyCoreKeysMigration()
    local gate = ManualMigrateSlashGate()
    if gate == nil then
        print(ns.L.BRAND .. " " .. ns.L.MIGRATE_DENIED_SETUP)
        return false
    end
    if gate == false then
        print(ns.L.BRAND .. " " .. ns.L.MIGRATE_DENIED_CHARACTER)
        return false
    end
    local prev = tonumber(GCM_Settings.schemaVersion) or 0
    if prev >= SCHEMA_VERSION then
        print(ns.L.BRAND .. " " .. string.format(ns.L.MIGRATE_ALREADY, SCHEMA_VERSION))
        return false
    end
    print(ns.L.BRAND_YELLOW .. " " .. ns.L.MIGRATE_BEGIN)
    local snap = SnapshotMigrationState()
    local ok, err = pcall(function()
        self:MigrateLegacyCoreKeys()
    end)
    if not ok then
        RestoreMigrationState(snap)
        if prev > 0 then
            GCM_Settings.schemaVersion = prev
        else
            GCM_Settings.schemaVersion = nil
        end
        print(ns.L.BRAND .. " " .. string.format(ns.L.MIGRATION_FAILED, tostring(err)))
        return false
    end
    GCM_Settings.schemaVersion = SCHEMA_VERSION
    print(ns.L.BRAND_GREEN .. " " .. string.format(ns.L.MIGRATE_SUCCESS, SCHEMA_VERSION))
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
    return true
end

function ns.Database:GetCoreLootMaster(coreKey)
    if not GCM_Sync or not GCM_Sync.coreRaidPrefs then return nil end
    local e = GCM_Sync.coreRaidPrefs[coreKey]
    if type(e) ~= "table" then return nil end
    local v = e.lootMasterNameKey
    if not v or v == "" then return nil end
    return v
end

function ns.Database:SetCoreLootMaster(coreKey, nameKeyOrNil)
    if not GCM_Sync then return end
    GCM_Sync.coreRaidPrefs = GCM_Sync.coreRaidPrefs or {}
    if not coreKey or coreKey == "" then return end
    if not nameKeyOrNil or nameKeyOrNil == "" then
        GCM_Sync.coreRaidPrefs[coreKey] = nil
    else
        GCM_Sync.coreRaidPrefs[coreKey] = { lootMasterNameKey = nameKeyOrNil }
    end
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
end

function ns.Database:IsCollapsed(key)
    return GCM_Settings.collapsed[key] == true
end

function ns.Database:SetCollapsed(key, value)
    GCM_Settings.collapsed[key] = value or nil
end

function ns.Database:ResetWindow()
    GCM_Settings.framePosition = nil
    GCM_Settings.frameWidth = DEFAULTS.frameWidth
    GCM_Settings.frameHeight = DEFAULTS.frameHeight
end
