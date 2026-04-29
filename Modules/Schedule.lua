local _, ns = ...
ns.Schedule = ns.Schedule or {}

local FIELD_SEP = "~"
local SLOT_SEP = ";"
local SECTION_SEP = "^"
local ENTRY_SEP = "||"

local function SanitizeNotes(s)
    if not s then return "" end
    s = tostring(s)
    s = s:gsub("[%~%;%^|\n\r]", " ")
    if #s > 60 then s = s:sub(1, 60) end
    return s
end

function ns.Schedule:CoreKey(typeCode, coreId)
    return string.format("%s%d", tostring(typeCode), tonumber(coreId) or 0)
end

local function ParseCoreKey(key)
    local typeCode, coreId = key:match("^([kKG])(%d+)$")
    return typeCode, tonumber(coreId)
end

function ns.Schedule:Get(coreKey)
    if not ns.Sync then return nil end
    return ns.Sync.schedules[coreKey]
end

function ns.Schedule:GetSlots(coreKey)
    local entry = self:Get(coreKey)
    return (entry and entry.slots) or {}
end

local function NormalizeSlot(slot)
    return {
        day = math.max(1, math.min(7, tonumber(slot.day) or 1)),
        hour = math.max(0, math.min(23, tonumber(slot.hour) or 21)),
        minute = math.max(0, math.min(59, tonumber(slot.minute) or 0)),
        notes = SanitizeNotes(slot.notes or ""),
    }
end

function ns.Schedule:SetSlots(coreKey, slots, opts)
    opts = opts or {}
    if not ns.Sync then return false end
    local clean = {}
    for _, s in ipairs(slots or {}) do
        clean[#clean + 1] = NormalizeSlot(s)
    end
    table.sort(clean, function(a, b)
        if a.day ~= b.day then return a.day < b.day end
        if a.hour ~= b.hour then return a.hour < b.hour end
        return a.minute < b.minute
    end)

    ns.Sync.schedules[coreKey] = {
        slots = clean,
        updatedBy = opts.updatedBy or UnitName("player"),
        updatedAt = opts.updatedAt or time(),
    }

    if opts.broadcast and ns.Comms and ns.Comms.Broadcast then
        ns.Comms:Broadcast("SCHED_SET", self:SerializeOne(coreKey))
    end
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
    return true
end

function ns.Schedule:Clear(coreKey, broadcast)
    if not ns.Sync then return end
    ns.Sync.schedules[coreKey] = nil
    if broadcast and ns.Comms and ns.Comms.Broadcast then
        ns.Comms:Broadcast("SCHED_SET", coreKey .. SECTION_SEP .. SECTION_SEP .. (UnitName("player") or "") .. SECTION_SEP .. tostring(time()))
    end
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
end

local function SerializeSlot(slot)
    return table.concat({
        tostring(slot.day),
        tostring(slot.hour),
        tostring(slot.minute),
        SanitizeNotes(slot.notes or ""),
    }, FIELD_SEP)
end

local function ParseSlot(str)
    local d, h, m, notes = str:match("^([^~]*)~([^~]*)~([^~]*)~(.*)$")
    if not d then return nil end
    return NormalizeSlot({ day = d, hour = h, minute = m, notes = notes })
end

function ns.Schedule:SerializeOne(coreKey)
    local entry = self:Get(coreKey)
    if not entry then return "" end
    local slotStrs = {}
    for _, s in ipairs(entry.slots or {}) do
        slotStrs[#slotStrs + 1] = SerializeSlot(s)
    end
    return table.concat({
        coreKey,
        table.concat(slotStrs, SLOT_SEP),
        entry.updatedBy or "",
        tostring(entry.updatedAt or 0),
    }, SECTION_SEP)
end

function ns.Schedule:DeserializeOne(payload)
    local coreKey, slotsStr, updatedBy, updatedAt = payload:match("^([^%^]+)%^([^%^]*)%^([^%^]*)%^(%d+)$")
    if not coreKey then return nil end
    updatedAt = tonumber(updatedAt) or 0
    local slots = {}
    if slotsStr and slotsStr ~= "" then
        for s in slotsStr:gmatch("[^;]+") do
            local slot = ParseSlot(s)
            if slot then slots[#slots + 1] = slot end
        end
    end
    return {
        coreKey = coreKey,
        slots = slots,
        updatedBy = updatedBy ~= "" and updatedBy or nil,
        updatedAt = updatedAt,
    }
end

function ns.Schedule:SerializeAll()
    if not ns.Sync then return "" end
    local parts = {}
    for key in pairs(ns.Sync.schedules) do
        parts[#parts + 1] = self:SerializeOne(key)
    end
    return table.concat(parts, ENTRY_SEP)
end

local function ApplyIncoming(parsed)
    if not parsed or not parsed.coreKey then return false end
    if not ns.Sync then return false end
    local existing = ns.Sync.schedules[parsed.coreKey]
    if existing and (existing.updatedAt or 0) >= parsed.updatedAt then
        return false
    end
    if #parsed.slots == 0 then
        ns.Sync.schedules[parsed.coreKey] = nil
    else
        ns.Sync.schedules[parsed.coreKey] = {
            slots = parsed.slots,
            updatedBy = parsed.updatedBy,
            updatedAt = parsed.updatedAt,
        }
    end
    return true
end

function ns.Schedule:OnSchedSet(payload, sender)
    local parsed = self:DeserializeOne(payload)
    if ApplyIncoming(parsed) and ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
end

function ns.Schedule:OnSchedFull(payload, sender)
    if not payload or payload == "" then return end
    local applied = false
    for entry in (payload .. ENTRY_SEP):gmatch("(.-)" .. ENTRY_SEP:gsub("|", "%%|")) do
        if entry ~= "" then
            local parsed = self:DeserializeOne(entry)
            if ApplyIncoming(parsed) then applied = true end
        end
    end
    if applied and ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
end

function ns.Schedule:OnSchedReq(payload, sender)
    if not ns.Notes or not ns.Notes.CanEditUI or not ns.Notes:CanEditUI() then return end
    if not ns.Sync or not next(ns.Sync.schedules) then return end
    local serialized = self:SerializeAll()
    if serialized ~= "" and ns.Comms then
        ns.Comms:Whisper("SCHED_FULL", serialized, sender)
    end
end

function ns.Schedule:RequestSync()
    if ns.Comms and ns.Comms.Broadcast then
        ns.Comms:Broadcast("SCHED_REQ", "")
    end
end

function ns.Schedule:GetNextSlot(coreKey, fromTime)
    local slots = self:GetSlots(coreKey)
    if #slots == 0 then return nil end
    local now = fromTime or time()
    local d = date("*t", now)
    local todayWday = d.wday
    local nowMin = d.hour * 60 + d.min

    local best, bestDelta = nil, math.huge
    for _, s in ipairs(slots) do
        local slotMin = s.hour * 60 + s.minute
        local dayDelta = (s.day - todayWday) % 7
        local delta = dayDelta * 1440 + (slotMin - nowMin)
        if delta < 0 then delta = delta + 7 * 1440 end
        if delta < bestDelta then
            bestDelta = delta
            best = s
        end
    end
    return best, bestDelta
end

function ns.Schedule:Init()
    if not ns.Comms then return end
    ns.Comms:RegisterHandler("SCHED_SET", function(payload, sender) ns.Schedule:OnSchedSet(payload, sender) end)
    ns.Comms:RegisterHandler("SCHED_FULL", function(payload, sender) ns.Schedule:OnSchedFull(payload, sender) end)
    ns.Comms:RegisterHandler("SCHED_REQ", function(payload, sender) ns.Schedule:OnSchedReq(payload, sender) end)
end
