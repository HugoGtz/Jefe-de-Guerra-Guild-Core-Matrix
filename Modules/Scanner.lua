local addonName, ns = ...
ns.Scanner = {}

local lastScan = 0

function ns.Scanner:ResetThrottle()
    lastScan = 0
end

local function ParseCoresFromNotes(combined)
    local cores = {}
    local count = 0
    if not combined or combined == "" then return cores, count end
    for bracket in combined:gmatch("%[([^%]]+)%]") do
        for typeCode, coreId, role, lead in bracket:gmatch("([KkG])%s*(%d+):?([THD]?)(%*?)") do
            cores[typeCode] = cores[typeCode] or {}
            cores[typeCode][tonumber(coreId)] = {
                role = (role ~= "" and role) or nil,
                lead = lead == "*",
            }
            count = count + 1
        end
    end
    return cores, count
end

function ns.Scanner:ParseGuildNotes()
    if not IsInGuild() then return end

    local now = GetTime()
    if (now - lastScan) < 2 then return end
    lastScan = now

    ns.Cache = ns.Cache or {}
    wipe(ns.Cache)

    local foundCount = 0
    local rosterSize = GetNumGuildMembers()

    for i = 1, rosterSize do
        local name, _, _, level, _, zone, publicNote, officerNote, online, _, classFileName = GetGuildRosterInfo(i)

        if name then
            local cleanName = Ambiguate(name, "none")
            local years, months, days, hours = GetGuildRosterLastOnline(i)
            local combined = (publicNote or "") .. " " .. (officerNote or "")
            local cores, count = ParseCoresFromNotes(combined)

            ns.Cache[cleanName] = {
                class = classFileName,
                level = level,
                online = online and true or false,
                zone = zone,
                publicNote = publicNote,
                lastOnline = { years = years or 0, months = months or 0, days = days or 0, hours = hours or 0 },
                cores = cores,
            }

            foundCount = foundCount + count
        end
    end

    ns.Scanner.lastScanTime = time()

    if foundCount > 0 then
        print(ns.L.BRAND_GREEN .. " " .. string.format(ns.L.SCAN_SUCCESS, foundCount))
    elseif rosterSize > 0 then
        print(ns.L.BRAND_YELLOW .. " " .. ns.L.SCAN_NO_MATCHES)
    end

    if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
end

local function CountKeys(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

local function ReadAssignment(data)
    if type(data) == "table" then
        return data.role, data.lead == true
    elseif data == true then
        return nil, false
    elseif type(data) == "string" then
        return data, false
    end
    return nil, false
end

function ns.Scanner:GetMembersForCore(typeCode, coreId)
    coreId = tonumber(coreId)
    local out = {}
    if not ns.Cache then return out end
    for name, entry in pairs(ns.Cache) do
        local list = entry.cores and entry.cores[typeCode]
        if list and list[coreId] then
            local role, lead = ReadAssignment(list[coreId])
            out[#out + 1] = {
                name = name,
                class = entry.class,
                level = entry.level,
                online = entry.online,
                zone = entry.zone,
                publicNote = entry.publicNote,
                lastOnline = entry.lastOnline,
                role = role,
                lead = lead,
                hasConflict = list and CountKeys(list) > 1,
                conflictType = typeCode,
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
    local out = { k = {}, K = {}, G = {} }
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

function ns.Scanner:HasAnyDiscovered()
    if not ns.Cache then return false end
    for _, entry in pairs(ns.Cache) do
        if entry.cores and next(entry.cores) then
            return true
        end
    end
    return false
end
