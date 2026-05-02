local addonName, ns = ...
ns.Scanner = {}

local parseDebounceGen = 0
local parseQueuedOpts = {}

function ns.Scanner:ResetThrottle()
    parseDebounceGen = parseDebounceGen + 1
    parseQueuedOpts = {}
end

local function ParseCoresFromNotes(combined)
    if ns.Notes and ns.Notes.ParseCoresFromCombined then
        return ns.Notes:ParseCoresFromCombined(combined)
    end
    return {}, 0
end

local function CoerceGuildOnline(v)
    if v == true then return true end
    if v == false or v == nil then return false end
    if type(v) == "number" then return v > 0 end
    if type(v) == "string" then return v ~= "" and v ~= "0" end
    return false
end

local function EffectiveGuildOnline(onlineRaw, years, months, days, hours, status)
    if CoerceGuildOnline(onlineRaw) then return true end
    local anyPresent = years ~= nil or months ~= nil or days ~= nil or hours ~= nil
    local z = (years or 0) == 0 and (months or 0) == 0 and (days or 0) == 0 and (hours or 0) == 0
    if anyPresent then return z end
    if onlineRaw == false then return false end
    if onlineRaw == nil then
        return type(status) == "number" and status >= 0 and status <= 2
    end
    return false
end

function ns.Scanner:SyncLootMasterPrefsFromCache()
    if not GCM_Sync or not ns.Schedule then return end
    GCM_Sync.coreRaidPrefs = GCM_Sync.coreRaidPrefs or {}
    local holders = {}
    for name, entry in pairs(ns.Cache or {}) do
        if entry.cores then
            for tc, list in pairs(entry.cores) do
                for cid, cell in pairs(list) do
                    if type(cell) == "table" and cell.lootMaster then
                        local key = ns.Schedule:CoreKey(tc, tonumber(cid) or 0)
                        holders[key] = holders[key] or {}
                        holders[key][#holders[key] + 1] = name
                    end
                end
            end
        end
    end
    local discovered = self:GetDiscoveredCores()
    for tc, ids in pairs(discovered) do
        for cid in pairs(ids) do
            local key = ns.Schedule:CoreKey(tc, tonumber(cid) or 0)
            local list = holders[key]
            if list and #list > 0 then
                table.sort(list)
                GCM_Sync.coreRaidPrefs[key] = { lootMasterNameKey = list[1] }
                if #list > 1 and ns.L and ns.L.ML_NOTE_CONFLICT then
                    print(ns.L.BRAND_YELLOW .. " " .. string.format(ns.L.ML_NOTE_CONFLICT, key, table.concat(list, ", "), list[1]))
                end
            else
                GCM_Sync.coreRaidPrefs[key] = nil
            end
        end
    end
end

function ns.Scanner:ParseGuildNotes(opts)
    opts = opts or {}
    if not IsInGuild() then return end
    if opts.verbose then parseQueuedOpts.verbose = true end
    parseDebounceGen = parseDebounceGen + 1
    local gen = parseDebounceGen
    if C_Timer and C_Timer.After then
        C_Timer.After(0.15, function()
            if gen ~= parseDebounceGen then return end
            local q = {}
            if parseQueuedOpts.verbose then q.verbose = true end
            parseQueuedOpts = {}
            ns.Scanner:ParseGuildNotesNow(q)
        end)
    else
        local q = {}
        if opts.verbose then q.verbose = true end
        ns.Scanner:ParseGuildNotesNow(q)
    end
end

function ns.Scanner:ParseGuildNotesNow(opts)
    opts = opts or {}
    if not IsInGuild() then return end

    ns.Cache = ns.Cache or {}
    wipe(ns.Cache)

    local foundCount = 0
    local rosterSize = GetNumGuildMembers()

    for i = 1, rosterSize do
        local name, _, _, level, _, zone, publicNote, officerNote, online, status, classFileName = GetGuildRosterInfo(i)

        if name then
            local cleanName = Ambiguate(name, "none")
            local years, months, days, hours = GetGuildRosterLastOnline(i)
            local combined = officerNote or ""
            local cores, count = ParseCoresFromNotes(combined)
            local lfgTags = {}
            local lfgDetail = ""
            local lfgUpdatedAt = 0
            local lfgMode = "LFG"
            local syncLF = ns.Sync and ns.Sync.lfg and ns.Sync.lfg[cleanName]
            if syncLF then
                for _, t in ipairs(syncLF.tags or {}) do
                    lfgTags[#lfgTags + 1] = t
                end
                lfgDetail    = syncLF.detail    or ""
                lfgUpdatedAt = syncLF.updatedAt or 0
                lfgMode      = syncLF.mode      or "LFG"
            end

            ns.Cache[cleanName] = {
                rosterName   = name,
                class        = classFileName,
                level        = level,
                online       = EffectiveGuildOnline(online, years, months, days, hours, status),
                zone         = zone,
                publicNote   = publicNote,
                lastOnline   = { years = years or 0, months = months or 0, days = days or 0, hours = hours or 0 },
                cores        = cores,
                lfg          = lfgTags,
                lfgDetail    = lfgDetail,
                lfgUpdatedAt = lfgUpdatedAt,
                lfgMode      = lfgMode,
            }

            if ns.Professions and ns.Professions.PushToCache then
                ns.Professions:PushToCache(cleanName)
            end

            foundCount = foundCount + count
        end
    end

    ns.Scanner.lastScanTime = time()

    local prevFound = ns.Scanner._lastFoundCount
    ns.Scanner._lastFoundCount = foundCount

    if rosterSize > 0 then
        local chat = opts.verbose == true or prevFound ~= foundCount
        if chat then
            if foundCount > 0 then
                print(ns.L.BRAND_GREEN .. " " .. string.format(ns.L.SCAN_SUCCESS, foundCount))
            else
                print(ns.L.BRAND_YELLOW .. " " .. ns.L.SCAN_NO_MATCHES)
            end
        end
    end

    self:SyncLootMasterPrefsFromCache()

    if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
end

local function CountKeys(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

local function ReadAssignment(data)
    if type(data) == "table" then
        return data.role, data.lead == true, data.lootMaster == true
    elseif data == true then
        return nil, false, false
    elseif type(data) == "string" then
        return data, false, false
    end
    return nil, false, false
end

function ns.Scanner:GetMembersForCore(typeCode, coreId)
    coreId = tonumber(coreId)
    local out = {}
    if not ns.Cache then return out end
    for name, entry in pairs(ns.Cache) do
        local list = entry.cores and entry.cores[typeCode]
        if list and list[coreId] then
            local role, lead, lootMaster = ReadAssignment(list[coreId])
            out[#out + 1] = {
                name = name,
                rosterName = entry.rosterName or name,
                class = entry.class,
                level = entry.level,
                online = entry.online,
                zone = entry.zone,
                publicNote = entry.publicNote,
                lastOnline = entry.lastOnline,
                role = role,
                lead = lead,
                lootMaster = lootMaster,
                hasConflict = list and CountKeys(list) > 1,
                conflictCount = list and CountKeys(list) or 0,
            }
        end
    end
    table.sort(out, function(a, b)
        if a.lead ~= b.lead then return a.lead and not b.lead end
        return a.name < b.name
    end)
    return out
end

function ns.Scanner:GetCoreLeader(typeCode, coreId)
    if not ns.Cache then return nil end
    coreId = tonumber(coreId)
    for name, entry in pairs(ns.Cache) do
        local list = entry.cores and entry.cores[typeCode]
        if list and list[coreId] then
            local _, lead = ReadAssignment(list[coreId])
            if lead then return name, entry.class end
        end
    end
    return nil
end

function ns.Scanner:GetUnassignedMembers()
    local out = {}
    if not ns.Cache then return out end
    for name, entry in pairs(ns.Cache) do
        if not entry.cores or not next(entry.cores) then
            out[#out + 1] = {
                name = name,
                rosterName = entry.rosterName or name,
                class = entry.class,
                level = entry.level,
                online = entry.online,
                zone = entry.zone,
                publicNote = entry.publicNote,
                lastOnline = entry.lastOnline,
                role = nil,
            }
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

function ns.Scanner:GetDiscoveredCores()
    local out = {}
    if not ns.Cache then return out end
    for _, entry in pairs(ns.Cache) do
        if entry.cores then
            for typeCode, list in pairs(entry.cores) do
                out[typeCode] = out[typeCode] or {}
                for coreId in pairs(list) do
                    out[typeCode][coreId] = true
                end
            end
        end
    end
    return out
end

function ns.Scanner:GetCoreDisplayName(typeCode, coreId)
    coreId = tonumber(coreId)
    typeCode = typeCode or "C"
    if not ns.Cache or not coreId then return nil end
    for _, entry in pairs(ns.Cache) do
        local list = entry.cores and entry.cores[typeCode]
        local cell = list and list[coreId]
        if type(cell) == "table" and cell.displayName and cell.displayName ~= "" then
            return cell.displayName
        end
    end
    return nil
end

function ns.Scanner:HasAnyDiscovered()
    if not ns.Cache then return false end
    for _, entry in pairs(ns.Cache) do
        if entry.cores and next(entry.cores) then
            return true
        end
    end
    return false
end
