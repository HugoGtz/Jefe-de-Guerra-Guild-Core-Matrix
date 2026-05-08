local _, ns = ...
ns.Schedule = ns.Schedule or {}

local SECTION_SEP = "^"
local ENTRY_SEP   = "||"

local function SanitizeNote(s)
    if not s then return "" end
    s = tostring(s):gsub("[%^|\n\r]", " ")
    if #s > 60 then s = s:sub(1, 60) end
    return s
end

function ns.Schedule:CoreKey(typeCode, coreId)
    if typeCode == "B" then coreId = 1 end
    return string.format("%s%d", tostring(typeCode), tonumber(coreId) or 0)
end

function ns.Schedule:Get(coreKey)
    if not ns.Sync then return nil end
    return ns.Sync.schedules[coreKey]
end

local function NormalizeEntry(e)
    local seen, days = {}, {}
    for _, d in ipairs(e.days or {}) do
        local n = math.max(1, math.min(7, tonumber(d) or 1))
        if not seen[n] then seen[n] = true; days[#days + 1] = n end
    end
    table.sort(days)
    return {
        days   = days,
        hour   = math.max(0, math.min(23, tonumber(e.hour)   or 21)),
        minute = math.max(0, math.min(59, tonumber(e.minute) or  0)),
        note   = SanitizeNote(e.note or ""),
    }
end

function ns.Schedule:Set(coreKey, entry, opts)
    opts = opts or {}
    if not ns.Sync then return false end
    local clean = NormalizeEntry(entry)
    ns.Sync.schedules[coreKey] = {
        days      = clean.days,
        hour      = clean.hour,
        minute    = clean.minute,
        note      = clean.note,
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
        local payload = table.concat({
            coreKey, "", "21", "0", "",
            UnitName("player") or "",
            tostring(time()),
        }, SECTION_SEP)
        ns.Comms:Broadcast("SCHED_SET", payload)
    end
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
end

function ns.Schedule:SerializeOne(coreKey)
    local e = self:Get(coreKey)
    if not e then return "" end
    return table.concat({
        coreKey,
        table.concat(e.days or {}, ","),
        tostring(e.hour   or 21),
        tostring(e.minute or  0),
        SanitizeNote(e.note or ""),
        e.updatedBy or "",
        tostring(e.updatedAt or 0),
    }, SECTION_SEP)
end

function ns.Schedule:SerializeAll()
    if not ns.Sync then return "" end
    local parts = {}
    for key in pairs(ns.Sync.schedules) do
        parts[#parts + 1] = self:SerializeOne(key)
    end
    return table.concat(parts, ENTRY_SEP)
end

local function ParsePayload(payload)
    local ck, dayStr, hStr, mStr, note, by, atStr =
        payload:match("^([^%^]+)%^([^%^]*)%^([^%^]*)%^([^%^]*)%^([^%^]*)%^([^%^]*)%^(%d*)$")
    if not ck then return nil end
    local days = {}
    for d in dayStr:gmatch("%d+") do days[#days + 1] = tonumber(d) end
    local clean = NormalizeEntry({ days = days, hour = hStr, minute = mStr, note = note })
    clean.coreKey   = ck
    clean.updatedBy = (by and by ~= "") and by or nil
    clean.updatedAt = tonumber(atStr) or 0
    return clean
end

local function ApplyIncoming(parsed)
    if not parsed or not ns.Sync then return false end
    local existing = ns.Sync.schedules[parsed.coreKey]
    if existing and (existing.updatedAt or 0) >= parsed.updatedAt then return false end
    if #parsed.days == 0 then
        ns.Sync.schedules[parsed.coreKey] = nil
    else
        ns.Sync.schedules[parsed.coreKey] = {
            days      = parsed.days,
            hour      = parsed.hour,
            minute    = parsed.minute,
            note      = parsed.note,
            updatedBy = parsed.updatedBy,
            updatedAt = parsed.updatedAt,
        }
    end
    return true
end

function ns.Schedule:OnSchedSet(payload)
    if ApplyIncoming(ParsePayload(payload)) and ns.UI and ns.UI.Refresh then
        ns.UI:Refresh()
    end
end

function ns.Schedule:OnSchedFull(payload)
    if not payload or payload == "" then return end
    local applied = false
    for entry in (payload .. ENTRY_SEP):gmatch("(.-)" .. ENTRY_SEP:gsub("|", "%%|")) do
        if entry ~= "" and ApplyIncoming(ParsePayload(entry)) then applied = true end
    end
    if applied and ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
end

function ns.Schedule:OnSchedReq(payload, sender)
    if not ns.Notes or not ns.Notes:CanEditUI() then return end
    if not ns.Sync or not next(ns.Sync.schedules) then return end
    local s = self:SerializeAll()
    if s ~= "" and ns.Comms then ns.Comms:Whisper("SCHED_FULL", s, sender) end
end

function ns.Schedule:RequestSync()
    if ns.Comms and ns.Comms.Broadcast then ns.Comms:Broadcast("SCHED_REQ", "") end
end

function ns.Schedule:GetNextSlot(coreKey, fromTime)
    local e = self:Get(coreKey)
    if not e or not e.days or #e.days == 0 then return nil end
    local now = fromTime or time()
    local d = date("*t", now)
    local nowMin = d.hour * 60 + d.min
    local slotMin = (e.hour or 21) * 60 + (e.minute or 0)
    local best, bestDelta = nil, math.huge
    for _, day in ipairs(e.days) do
        local dayDelta = (day - d.wday) % 7
        local delta = dayDelta * 1440 + (slotMin - nowMin)
        if delta <= 0 then delta = delta + 7 * 1440 end
        if delta < bestDelta then
            bestDelta = delta
            best = { day = day, hour = e.hour, minute = e.minute, note = e.note }
        end
    end
    return best, bestDelta
end

function ns.Schedule:Init()
    if not ns.Comms then return end
    ns.Comms:RegisterHandler("SCHED_SET",  function(p, s) ns.Schedule:OnSchedSet(p, s) end)
    ns.Comms:RegisterHandler("SCHED_FULL", function(p, s) ns.Schedule:OnSchedFull(p, s) end)
    ns.Comms:RegisterHandler("SCHED_REQ",  function(p, s) ns.Schedule:OnSchedReq(p, s) end)
end
