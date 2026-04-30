local addonName, ns = ...
ns.Notes = {}

local MAX_NOTE_LENGTH = 31
local MAX_CORE_NAME_LEN = 6

local TYPE_ORDER = { C = 1, B = 2 }

local function TrimSegment(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function ClampCoreName(raw)
    if not raw or raw == "" then return nil end
    local only = raw:match("^([A-Za-z0-9]+)") or ""
    if #only > MAX_CORE_NAME_LEN then only = only:sub(1, MAX_CORE_NAME_LEN) end
    if only == "" then return nil end
    return only
end

function ns.Notes:ParseCoreSegment(seg)
    seg = TrimSegment(seg or "")
    if seg == "" then return nil end

    local lootMaster = seg:match(":ML%s*$") ~= nil
    if lootMaster then seg = seg:gsub(":ML%s*$", "") end

    local lead = seg:match("%*%s*$") ~= nil
    if lead then seg = seg:gsub("%*%s*$", "") end

    local bWhole = seg:match("^[Bb]%s*(.*)$")
    if bWhole ~= nil then
        local rest = bWhole
        local digits, afterDigits = rest:match("^(%d+)(.*)$")
        if digits then
            rest = afterDigits or ""
        end
        rest = rest or ""
        if rest ~= "" and rest:sub(1, 1) == ":" then rest = rest:sub(2) end
        local role, displayName = nil, nil
        if rest ~= "" then
            local parts = {}
            for piece in rest:gmatch("[^:]+") do parts[#parts + 1] = piece end
            if #parts == 1 then
                local p = parts[1]
                if p == "T" or p == "H" or p == "D" then
                    role = p
                else
                    displayName = ClampCoreName(p)
                end
            elseif #parts >= 2 then
                displayName = ClampCoreName(parts[1])
                local last = parts[#parts]
                if last == "T" or last == "H" or last == "D" then role = last end
            end
        end
        return { typeCode = "B", coreId = 1, role = role, lead = lead, displayName = displayName, lootMaster = lootMaster }
    end

    local lt, lid, lrole = seg:match("^([kKgG])%s*(%d+):?([THD]?)$")
    if lt and lid then
        return {
            typeCode = "C",
            coreId = tonumber(lid),
            role = (lrole and lrole ~= "") and lrole or nil,
            lead = lead,
            displayName = nil,
            lootMaster = lootMaster,
        }
    end

    lt, lid, lrole = seg:match("^([kKgG])%s*(%d+)([THD])$")
    if lt and lid and lrole then
        return { typeCode = "C", coreId = tonumber(lid), role = lrole, lead = lead, displayName = nil, lootMaster = lootMaster }
    end

    local coreId, tail = seg:match("^[Cc]%s*(%d+)(.*)$")
    if not coreId then return nil end
    coreId = tonumber(coreId)
    tail = tail or ""

    local role, displayName = nil, nil
    if tail ~= "" then
        if tail:sub(1, 1) == ":" then tail = tail:sub(2) end
        local parts = {}
        for piece in tail:gmatch("[^:]+") do parts[#parts + 1] = piece end
        if #parts == 1 then
            local p = parts[1]
            if p == "T" or p == "H" or p == "D" then
                role = p
            else
                displayName = ClampCoreName(p)
            end
        elseif #parts >= 2 then
            displayName = ClampCoreName(parts[1])
            local last = parts[#parts]
            if last == "T" or last == "H" or last == "D" then role = last end
        end
    end

    return { typeCode = "C", coreId = coreId, role = role, lead = lead, displayName = displayName, lootMaster = lootMaster }
end

function ns.Notes:ParseCoresFromCombined(combined)
    local cores = {}
    local count = 0
    if not combined or combined == "" then return cores, count end
    for bracket in combined:gmatch("%[([^%]]+)%]") do
        for rawSeg in bracket:gmatch("[^,]+") do
            local entry = self:ParseCoreSegment(rawSeg)
            if entry then
                if entry.typeCode == "B" then entry.coreId = 1 end
                cores[entry.typeCode] = cores[entry.typeCode] or {}
                cores[entry.typeCode][entry.coreId] = {
                    role = entry.role,
                    lead = entry.lead == true,
                    displayName = entry.displayName,
                    lootMaster = entry.lootMaster == true,
                }
                count = count + 1
            end
        end
    end
    return cores, count
end

local function GuildControlRankAllowsOfficer()
    if not IsInGuild() then return false end
    if not GuildControlSetRank or not GuildControlGetRankFlags then return false end
    local _, _, rankIndex = GetGuildInfo("player")
    if rankIndex == nil then return false end
    GuildControlSetRank(rankIndex + 1)
    local _, _, _, _, _, _, _, _, _, _, _, edit_officer_note = GuildControlGetRankFlags()
    return edit_officer_note ~= nil and edit_officer_note ~= false
end

local function GuildControlRankAllowsPublic()
    if not IsInGuild() then return false end
    if not GuildControlSetRank or not GuildControlGetRankFlags then return false end
    local _, _, rankIndex = GetGuildInfo("player")
    if rankIndex == nil then return false end
    GuildControlSetRank(rankIndex + 1)
    local _, _, _, _, _, _, _, _, _, edit_public_note = GuildControlGetRankFlags()
    return edit_public_note ~= nil and edit_public_note ~= false
end

function ns.Notes:EffectiveCanEditOfficerNote()
    if C_GuildInfo and C_GuildInfo.CanEditOfficerNote then
        if C_GuildInfo.CanEditOfficerNote() then return true end
    end
    if CanEditOfficerNote and CanEditOfficerNote() then return true end
    if GuildControlRankAllowsOfficer() then return true end
    return false
end

function ns.Notes:EffectiveCanEditPublicNote()
    if C_GuildInfo and C_GuildInfo.CanEditPublicNote then
        if C_GuildInfo.CanEditPublicNote() then return true end
    end
    if CanEditPublicNote and CanEditPublicNote() then return true end
    if GuildControlRankAllowsPublic() then return true end
    return false
end

function ns.Notes:CanEditUI()
    if GCM_Settings and GCM_Settings.officerUi == false then return false end
    if GCM_Settings and GCM_Settings.officerUi == true then return true end
    if GCM_Settings and GCM_Settings.forceCanWrite then return true end
    if self:EffectiveCanEditOfficerNote() then return true end
    if self:EffectiveCanEditPublicNote() then return true end
    return false
end

function ns.Notes:CanWrite()
    if not self:CanEditUI() then return false end
    if GCM_Settings and GCM_Settings.forceCanWrite then return true end
    if self:EffectiveCanEditOfficerNote() then return true end
    return false
end

function ns.Notes:ParseEntries(text)
    local entries = {}
    if not text or text == "" then return entries end
    for bracket in text:gmatch("%[([^%]]+)%]") do
        for rawSeg in bracket:gmatch("[^,]+") do
            local entry = self:ParseCoreSegment(rawSeg)
            if entry then
                entries[#entries + 1] = {
                    typeCode = entry.typeCode,
                    coreId = entry.coreId,
                    role = entry.role,
                    lead = entry.lead == true,
                    displayName = entry.displayName,
                    lootMaster = entry.lootMaster == true,
                }
            end
        end
    end
    return entries
end

function ns.Notes:StripBrackets(text)
    if not text then return "" end
    local cleaned = text:gsub("%[[^%]]*%]", "")
    cleaned = cleaned:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
    return cleaned
end

local function EntryToString(e)
    if e.typeCode == "B" then
        local s = "B"
        if e.displayName and e.displayName ~= "" then
            s = s .. ":" .. e.displayName
            if e.role then
                s = s .. ":" .. e.role
            end
        elseif e.role then
            s = s .. ":" .. e.role
        end
        if e.lead then
            s = s .. "*"
        end
        if e.lootMaster then
            s = s .. ":ML"
        end
        return s
    end
    local s = string.format("%s%d", e.typeCode, e.coreId)
    if e.displayName and e.displayName ~= "" then
        s = s .. ":" .. e.displayName
    end
    if e.role then
        s = s .. ":" .. e.role
    end
    if e.lead then
        s = s .. "*"
    end
    if e.lootMaster then
        s = s .. ":ML"
    end
    return s
end

local function SortEntries(entries)
    table.sort(entries, function(a, b)
        local oa, ob = TYPE_ORDER[a.typeCode] or 99, TYPE_ORDER[b.typeCode] or 99
        if oa ~= ob then return oa < ob end
        return a.coreId < b.coreId
    end)
end

local function DedupeEntries(entries)
    local byKey = {}
    local order = {}
    for _, e in ipairs(entries) do
        local key = e.typeCode .. tostring(e.coreId)
        local prev = byKey[key]
        if prev then
            if e.lootMaster then prev.lootMaster = true end
            if e.lead then prev.lead = true end
            if e.role then prev.role = e.role end
            if e.displayName and e.displayName ~= "" then prev.displayName = e.displayName end
        else
            byKey[key] = {
                typeCode = e.typeCode,
                coreId = e.coreId,
                role = e.role,
                lead = e.lead and true or false,
                displayName = e.displayName,
                lootMaster = e.lootMaster and true or false,
            }
            order[#order + 1] = key
        end
    end
    local out = {}
    for _, key in ipairs(order) do
        out[#out + 1] = byKey[key]
    end
    return out
end

function ns.Notes:Compose(originalText, entries)
    local prefix = self:StripBrackets(originalText)
    entries = DedupeEntries(entries)
    SortEntries(entries)

    if #entries == 0 then
        return prefix
    end

    local parts = {}
    for _, e in ipairs(entries) do parts[#parts + 1] = EntryToString(e) end
    local bracket = "[" .. table.concat(parts, ",") .. "]"

    if prefix == "" then return bracket end
    return prefix .. " " .. bracket
end

function ns.Notes:GetIndexByName(targetName)
    if not IsInGuild() then return nil end
    for i = 1, GetNumGuildMembers() do
        local rosterName = GetGuildRosterInfo(i)
        if rosterName and Ambiguate(rosterName, "none") == targetName then
            return i
        end
    end
    return nil
end

local function OptimisticUpdate(name, entries)
    if not ns.Cache or not ns.Cache[name] then return end
    ns.Cache[name].cores = {}
    for _, e in ipairs(entries) do
        ns.Cache[name].cores[e.typeCode] = ns.Cache[name].cores[e.typeCode] or {}
        ns.Cache[name].cores[e.typeCode][e.coreId] = {
            role = e.role,
            lead = e.lead and true or false,
            displayName = e.displayName,
            lootMaster = e.lootMaster and true or false,
        }
    end
end

local function ApplyAndWrite(name, mutator)
    local idx = ns.Notes:GetIndexByName(name)
    if not idx then
        print(ns.L.BRAND .. " " .. string.format(ns.L.NOTE_NOT_FOUND, name))
        return false
    end

    local _, _, _, _, _, _, _, officerNote = GetGuildRosterInfo(idx)
    officerNote = officerNote or ""

    local officerEntries = ns.Notes:ParseEntries(officerNote)
    local combined = {}
    for _, e in ipairs(officerEntries) do combined[#combined + 1] = e end

    local mutated = mutator(combined) or combined

    local newOfficerNote = ns.Notes:Compose(officerNote, mutated)

    if #newOfficerNote > MAX_NOTE_LENGTH then
        print(ns.L.BRAND .. " " .. string.format(ns.L.NOTE_TOO_LONG, #newOfficerNote, MAX_NOTE_LENGTH))
        return false
    end

    local wroteOfficer = false

    if newOfficerNote ~= officerNote then
        if not ns.Notes:CanWrite() then
            print(ns.L.BRAND .. " " .. ns.L.NOTE_NO_PERM)
            print(ns.L.BRAND_YELLOW .. " " .. ns.L.NOTE_NO_PERM_HINT)
        else
            print(ns.L.BRAND_YELLOW .. " " .. string.format("Diff officer: \"%s\" -> \"%s\"", officerNote, newOfficerNote))
            GuildRosterSetOfficerNote(idx, newOfficerNote)
            wroteOfficer = true
        end
    end

    if not wroteOfficer then
        print(ns.L.BRAND_YELLOW .. " " .. ns.L.NOTE_NO_CHANGE)
        return false
    end

    OptimisticUpdate(name, mutated)

    if ns.Scanner and ns.Scanner.SyncLootMasterPrefsFromCache then ns.Scanner:SyncLootMasterPrefsFromCache() end

    if ns.Scanner.ResetThrottle then ns.Scanner:ResetThrottle() end
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
    if ns.Comms and ns.Comms.Broadcast then ns.Comms:Broadcast("RESCAN", "") end

    print(ns.L.BRAND_GREEN .. " " .. string.format(ns.L.NOTE_OK, name))

    if C_Timer and C_Timer.After then
        C_Timer.After(2.5, function()
            if GuildRoster then GuildRoster() end
            C_Timer.After(0.8, function()
                local verifyIdx = ns.Notes:GetIndexByName(name)
                if not verifyIdx then return end
                local _, _, _, _, _, _, _, curOfficer = GetGuildRosterInfo(verifyIdx)
                curOfficer = curOfficer or ""

                local officerRejected = wroteOfficer and curOfficer ~= newOfficerNote

                if officerRejected then
                    print(ns.L.BRAND .. " " .. string.format(ns.L.NOTE_REJECTED, name))
                    print(ns.L.BRAND_YELLOW .. " " .. string.format(ns.L.NOTE_DIFF, newOfficerNote, curOfficer))
                    print(ns.L.BRAND_YELLOW .. " " .. ns.L.NOTE_REJECTED_HINT)
                    if ns.Scanner.ResetThrottle then ns.Scanner:ResetThrottle() end
                    if ns.Scanner.ParseGuildNotes then ns.Scanner:ParseGuildNotes() end
                else
                    print(ns.L.BRAND_GREEN .. " " .. string.format(ns.L.NOTE_VERIFIED, name))
                end
            end)
        end)
    end

    return true
end

function ns.Notes:IsLootMaster(name, typeCode, coreId)
    if typeCode == "B" then coreId = 1 end
    if not ns.Cache or not ns.Cache[name] then return false end
    local list = ns.Cache[name].cores and ns.Cache[name].cores[typeCode]
    if not list then return false end
    local r = list[tonumber(coreId)]
    return type(r) == "table" and r.lootMaster == true
end

function ns.Notes:SetLootMasterInNote(name, typeCode, coreId, enabled)
    if typeCode == "B" then coreId = 1 end
    coreId = tonumber(coreId)
    print(ns.L.BRAND_YELLOW .. " " .. string.format("Action: LOOTMASTER %s %s%d -> %s", name, typeCode, coreId, tostring(enabled)))
    return ApplyAndWrite(name, function(entries)
        for _, e in ipairs(entries) do
            if e.typeCode == typeCode and e.coreId == coreId then
                e.lootMaster = enabled and true or nil
                return entries
            end
        end
        return entries
    end)
end

function ns.Notes:Assign(name, typeCode, coreId)
    if typeCode == "B" then coreId = 1 end
    coreId = tonumber(coreId)
    print(ns.L.BRAND_YELLOW .. " " .. string.format("Action: ASSIGN %s -> %s%d", name, typeCode, coreId))
    return ApplyAndWrite(name, function(entries)
        for _, e in ipairs(entries) do
            if e.typeCode == typeCode and e.coreId == coreId then
                return entries
            end
        end
        entries[#entries + 1] = { typeCode = typeCode, coreId = coreId, role = nil, displayName = nil }
        return entries
    end)
end

function ns.Notes:Unassign(name, typeCode, coreId)
    if typeCode == "B" then coreId = 1 end
    coreId = tonumber(coreId)
    print(ns.L.BRAND_YELLOW .. " " .. string.format("Action: UNASSIGN %s from %s%d", name, typeCode, coreId))
    return ApplyAndWrite(name, function(entries)
        local out = {}
        for _, e in ipairs(entries) do
            if not (e.typeCode == typeCode and e.coreId == coreId) then
                out[#out + 1] = e
            end
        end
        return out
    end)
end

function ns.Notes:SetRole(name, typeCode, coreId, role)
    if typeCode == "B" then coreId = 1 end
    coreId = tonumber(coreId)
    print(ns.L.BRAND_YELLOW .. " " .. string.format("Action: SETROLE %s %s%d -> %s", name, typeCode, coreId, tostring(role)))
    return ApplyAndWrite(name, function(entries)
        for _, e in ipairs(entries) do
            if e.typeCode == typeCode and e.coreId == coreId then
                e.role = role
                return entries
            end
        end
        entries[#entries + 1] = { typeCode = typeCode, coreId = coreId, role = role, displayName = nil }
        return entries
    end)
end

function ns.Notes:HasRole(name, typeCode, coreId)
    if not ns.Cache or not ns.Cache[name] then return false, nil end
    local list = ns.Cache[name].cores and ns.Cache[name].cores[typeCode]
    if not list then return false, nil end
    local r = list[tonumber(coreId)]
    if r == nil then return false, nil end
    if type(r) == "table" then return true, r.role end
    if r == true then return true, nil end
    return true, r
end

function ns.Notes:IsLead(name, typeCode, coreId)
    if not ns.Cache or not ns.Cache[name] then return false end
    local list = ns.Cache[name].cores and ns.Cache[name].cores[typeCode]
    if not list then return false end
    local r = list[tonumber(coreId)]
    return type(r) == "table" and r.lead == true
end

function ns.Notes:DemoteLead(name, typeCode, coreId)
    if typeCode == "B" then coreId = 1 end
    coreId = tonumber(coreId)
    print(ns.L.BRAND_YELLOW .. " " .. string.format("Action: DEMOTE_LEAD %s %s%d", name, typeCode, coreId))
    return ApplyAndWrite(name, function(entries)
        for _, e in ipairs(entries) do
            if e.typeCode == typeCode and e.coreId == coreId then
                e.lead = false
                return entries
            end
        end
        return entries
    end)
end

function ns.Notes:PromoteLead(name, typeCode, coreId)
    if typeCode == "B" then coreId = 1 end
    coreId = tonumber(coreId)
    print(ns.L.BRAND_YELLOW .. " " .. string.format("Action: PROMOTE_LEAD %s %s%d", name, typeCode, coreId))
    return ApplyAndWrite(name, function(entries)
        for _, e in ipairs(entries) do
            if e.typeCode == typeCode and e.coreId == coreId then
                e.lead = true
                return entries
            end
        end
        entries[#entries + 1] = { typeCode = typeCode, coreId = coreId, role = nil, lead = true, displayName = nil }
        return entries
    end)
end
