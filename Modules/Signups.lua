local _, ns = ...
ns.Signups = ns.Signups or {}

local VALID_STATES = { yes = true, maybe = true, no = true }

function ns.Signups:CurrentWeekKey()
    return tostring(math.floor(time() / 604800))
end

local function SlotKey(coreKey, slotIdx)
    return string.format("%s#%d", coreKey, tonumber(slotIdx) or 1)
end

local function EnsureSlot(slotKey, weekKey)
    if not ns.Sync then return nil end
    local entry = ns.Sync.signups[slotKey]
    if not entry or entry.weekKey ~= weekKey then
        entry = { weekKey = weekKey, states = {} }
        ns.Sync.signups[slotKey] = entry
    end
    return entry
end

function ns.Signups:GetStates(coreKey, slotIdx)
    if not ns.Sync then return {} end
    local entry = ns.Sync.signups[SlotKey(coreKey, slotIdx)]
    if not entry then return {} end
    if entry.weekKey ~= self:CurrentWeekKey() then return {} end
    return entry.states or {}
end

function ns.Signups:GetMyState(coreKey, slotIdx)
    local me = UnitName("player")
    return self:GetStates(coreKey, slotIdx)[me]
end

function ns.Signups:CountForSlot(coreKey, slotIdx)
    local out = { yes = 0, maybe = 0, no = 0, byRole = { T = 0, H = 0, D = 0 } }
    local states = self:GetStates(coreKey, slotIdx)
    if not ns.Cache then return out end

    local typeCode, coreNum = coreKey:match("^([CB])(%d+)$")
    local coreId = tonumber(coreNum)
    if not coreId or not typeCode then
        local _, num = coreKey:match("^([kKG])(%d+)$")
        coreId = tonumber(num)
        typeCode = "C"
    end

    for name, state in pairs(states) do
        if state == "yes" then
            out.yes = out.yes + 1
            local entry = ns.Cache[name]
            local list = entry and entry.cores and entry.cores[typeCode]
            local data = list and coreId and list[coreId]
            local role
            if type(data) == "table" then role = data.role end
            if role and out.byRole[role] then
                out.byRole[role] = out.byRole[role] + 1
            end
        elseif state == "maybe" then
            out.maybe = out.maybe + 1
        elseif state == "no" then
            out.no = out.no + 1
        end
    end
    return out
end

function ns.Signups:Set(coreKey, slotIdx, state)
    if state and not VALID_STATES[state] then return false end
    local me = UnitName("player")
    local weekKey = self:CurrentWeekKey()
    local entry = EnsureSlot(SlotKey(coreKey, slotIdx), weekKey)
    if not entry then return false end

    if state then
        entry.states[me] = state
    else
        entry.states[me] = nil
    end

    if ns.Comms and ns.Comms.Broadcast then
        local payload = string.format("%s|%d|%s|%s", coreKey, slotIdx, weekKey, state or "")
        ns.Comms:Broadcast("SIGNUP", payload)
    end
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
    return true
end

function ns.Signups:OnReceive(payload, sender)
    local coreKey, slotIdxStr, weekKey, state = payload:match("^([^|]+)|(%d+)|([^|]+)|(.*)$")
    if not coreKey then return end
    local slotIdx = tonumber(slotIdxStr) or 1
    if state == "" then state = nil end
    if state and not VALID_STATES[state] then return end
    if weekKey ~= self:CurrentWeekKey() then return end

    local entry = EnsureSlot(SlotKey(coreKey, slotIdx), weekKey)
    if not entry then return end

    if state then
        entry.states[sender] = state
    else
        entry.states[sender] = nil
    end
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
end

function ns.Signups:PruneOldWeeks()
    if not ns.Sync or not ns.Sync.signups then return end
    local current = self:CurrentWeekKey()
    for k, entry in pairs(ns.Sync.signups) do
        if entry.weekKey ~= current then
            ns.Sync.signups[k] = nil
        end
    end
end

function ns.Signups:Init()
    self:PruneOldWeeks()
    if ns.Comms and ns.Comms.RegisterHandler then
        ns.Comms:RegisterHandler("SIGNUP", function(payload, sender) ns.Signups:OnReceive(payload, sender) end)
    end
end
