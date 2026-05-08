local _, ns = ...
ns.UI = ns.UI or {}

local DAY_KEYS = { "DAY_SUN", "DAY_MON", "DAY_TUE", "DAY_WED", "DAY_THU", "DAY_FRI", "DAY_SAT" }

function ns.UI:DayShort(day)
    return ns.L[DAY_KEYS[day]] or tostring(day)
end

function ns.UI:FormatNextSlot(slot)
    if not slot then return ns.L.SCHED_NONE end
    local base = string.format("%s %02d:%02d", self:DayShort(slot.day), slot.hour or 0, slot.minute or 0)
    if slot.note and slot.note ~= "" then
        return base .. " — " .. slot.note
    end
    return base
end
