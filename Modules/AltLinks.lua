local addonName, ns = ...
ns.AltLinks = ns.AltLinks or {}

local function NameKey(name)
    if not name or name == "" then return "" end
    return Ambiguate(name, "none")
end

local function StoreEntry(nameKey, mainKey)
    if not ns.Sync then return end
    ns.Sync.altMain = ns.Sync.altMain or {}
    nameKey = NameKey(nameKey)
    mainKey = NameKey(mainKey or "")
    if nameKey == "" then return end
    if mainKey == "" or mainKey == nameKey then
        ns.Sync.altMain[nameKey] = nil
    else
        ns.Sync.altMain[nameKey] = mainKey
    end
end

function ns.AltLinks:HydrateCacheEntry(nameKey, entry)
    if not entry then return end
    nameKey = NameKey(nameKey)
    local m = ns.Sync and ns.Sync.altMain and ns.Sync.altMain[nameKey]
    if m and m ~= "" and m ~= nameKey then
        entry.linkedMain = m
    else
        entry.linkedMain = nil
    end
end

function ns.AltLinks:GetMain(name)
    if not ns.Sync or not ns.Sync.altMain then return nil end
    local k = NameKey(name)
    if k == "" then return nil end
    local m = ns.Sync.altMain[k]
    if not m or m == "" or m == k then return nil end
    return m
end

function ns.AltLinks:BroadcastMyLinkIfAny()
    if not ns.Comms or not ns.Comms.Broadcast then return end
    local nk = NameKey(UnitName("player") or "")
    if nk == "" then return end
    ns.Sync.altMain = ns.Sync.altMain or {}
    local main = ns.Sync.altMain[nk]
    if main and main ~= "" and main ~= nk then
        ns.Comms:Broadcast("LINK_SET", string.format("%s|%s", nk, main), true)
    end
end

function ns.AltLinks:Set(name, mainName, opts)
    opts = opts or {}
    if not ns.Sync then return false end
    local me = UnitName("player")
    local nk = NameKey(name)
    if nk == "" then return false end
    if me and NameKey(me) ~= nk then return false end
    local mainK = NameKey(mainName or "")
    if mainK ~= "" and mainK == nk then
        mainK = ""
    end
    StoreEntry(nk, mainK)
    if opts.broadcast and ns.Comms and ns.Comms.Broadcast then
        ns.Comms:Broadcast("LINK_SET", string.format("%s|%s", nk, mainK), opts.unthrottled == true)
    end
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
    return true
end

function ns.AltLinks:SetMine(mainName)
    local me = UnitName("player")
    if not me then return false end
    return self:Set(me, mainName, { broadcast = true })
end

function ns.AltLinks:OnReceive(payload, sender)
    local name, main = payload:match("^([^|]+)|(.*)$")
    if not name then return end
    local sk = NameKey(sender)
    local nk = NameKey(name)
    if nk == "" or sk == "" or nk ~= sk then return end
    main = main or ""
    if main == nk then main = "" end
    StoreEntry(nk, main)
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
end

function ns.AltLinks:SerializeAll()
    if not ns.Sync or not ns.Sync.altMain then return "" end
    local parts = {}
    for a, m in pairs(ns.Sync.altMain) do
        if type(a) == "string" and type(m) == "string" and m ~= "" and a ~= m then
            parts[#parts + 1] = a .. "=" .. m
        end
    end
    return table.concat(parts, ",")
end

function ns.AltLinks:OnLinkFull(payload)
    if not payload or payload == "" then return end
    if not ns.Sync then return end
    ns.Sync.altMain = ns.Sync.altMain or {}
    for entry in payload:gmatch("[^,]+") do
        local a, m = entry:match("^([^=]+)=(.+)$")
        if a and m and m ~= "" then
            local na = NameKey(a)
            local nm = NameKey(m)
            if na ~= "" and nm ~= "" and na ~= nm then
                ns.Sync.altMain[na] = nm
            end
        end
    end
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
end

function ns.AltLinks:OnLinkReq()
    self:BroadcastMyLinkIfAny()
end

function ns.AltLinks:RequestSync()
    if ns.Comms and ns.Comms.Broadcast then
        ns.Comms:Broadcast("LINK_REQ", "")
    end
end

function ns.AltLinks:Init()
    if not ns.Comms then return end
    ns.Comms:RegisterHandler("LINK_SET", function(payload, sender)
        ns.AltLinks:OnReceive(payload, sender)
    end)
    ns.Comms:RegisterHandler("LINK_REQ", function()
        ns.AltLinks:OnLinkReq()
    end)
    ns.Comms:RegisterHandler("LINK_FULL", function(payload)
        ns.AltLinks:OnLinkFull(payload)
    end)
    if C_Timer and C_Timer.After then
        C_Timer.After(7, function()
            if ns.AltLinks and ns.AltLinks.BroadcastMyLinkIfAny then
                ns.AltLinks:BroadcastMyLinkIfAny()
            end
        end)
    end
end
