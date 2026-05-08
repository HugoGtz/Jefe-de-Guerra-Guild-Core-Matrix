local addonName, ns = ...
ns.GearAudit = ns.GearAudit or {}

local MIN_QUALITY = 3

local function NameKey(n)
    if not n or n == "" then return "" end
    local name = Ambiguate(n, "none")
    return name:lower():gsub("^%l", string.upper)
end

local SLOTS = {
    { id = INVSLOT_HEAD,      needEnchant = true },
    { id = INVSLOT_NECK,      needEnchant = false },
    { id = INVSLOT_SHOULDER,  needEnchant = true },
    { id = INVSLOT_CHEST,     needEnchant = true },
    { id = INVSLOT_WAIST,     needEnchant = false },
    { id = INVSLOT_LEGS,      needEnchant = true },
    { id = INVSLOT_FEET,      needEnchant = true },
    { id = INVSLOT_WRIST,     needEnchant = true },
    { id = INVSLOT_HAND,      needEnchant = true },
    { id = INVSLOT_FINGER1,   needEnchant = false },
    { id = INVSLOT_FINGER2,   needEnchant = false },
    { id = INVSLOT_TRINKET1,  needEnchant = false },
    { id = INVSLOT_TRINKET2,  needEnchant = false },
    { id = INVSLOT_BACK,      needEnchant = true },
    { id = INVSLOT_MAINHAND,  needEnchant = true },
    { id = INVSLOT_OFFHAND,   needEnchant = true },
    { id = INVSLOT_RANGED,    needEnchant = false },
}

local function ParseLinkEnchant(link)
    if not link then return 0 end
    local itemStr = link:match("|H(item:[^|]+)|h")
    if not itemStr then return 0 end
    itemStr = itemStr:gsub("^item:", "")
    local parts = { strsplit(":", itemStr) }
    return tonumber(parts[2]) or 0
end

local function ItemStatsTable(link)
    if not link or not GetItemStats then return nil end
    local t = {}
    local ok = pcall(function() GetItemStats(link, t) end)
    if ok and next(t) ~= nil then return t end
    return nil
end

local function StatsHaveEmptySocket(stats)
    if not stats then return false end
    for k, v in pairs(stats) do
        if type(k) == "string" and k:find("EMPTY_SOCKET", 1, true) and type(v) == "number" and v > 0 then
            return true
        end
    end
    return false
end

local function MainHandIsTwoHand()
    local link = GetInventoryItemLink("player", INVSLOT_MAINHAND)
    if not link then return false end
    local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(link)
    return equipLoc == "INVTYPE_2HWEAPON"
end

local SLOT_I18N = {
    [INVSLOT_HEAD]     = "AUDIT_SLOT_HEAD",
    [INVSLOT_NECK]     = "AUDIT_SLOT_NECK",
    [INVSLOT_SHOULDER] = "AUDIT_SLOT_SHOULDER",
    [INVSLOT_CHEST]    = "AUDIT_SLOT_CHEST",
    [INVSLOT_WAIST]    = "AUDIT_SLOT_WAIST",
    [INVSLOT_LEGS]     = "AUDIT_SLOT_LEGS",
    [INVSLOT_FEET]     = "AUDIT_SLOT_FEET",
    [INVSLOT_WRIST]    = "AUDIT_SLOT_WRIST",
    [INVSLOT_HAND]     = "AUDIT_SLOT_HAND",
    [INVSLOT_FINGER1]  = "AUDIT_SLOT_FINGER1",
    [INVSLOT_FINGER2]  = "AUDIT_SLOT_FINGER2",
    [INVSLOT_TRINKET1] = "AUDIT_SLOT_TRINKET1",
    [INVSLOT_TRINKET2] = "AUDIT_SLOT_TRINKET2",
    [INVSLOT_BACK]     = "AUDIT_SLOT_BACK",
    [INVSLOT_MAINHAND] = "AUDIT_SLOT_MAINHAND",
    [INVSLOT_OFFHAND]  = "AUDIT_SLOT_OFFHAND",
    [INVSLOT_RANGED]   = "AUDIT_SLOT_RANGED",
}

function ns.GearAudit:SlotLabel(slotId)
    local key = SLOT_I18N[slotId]
    if key and ns.L and ns.L[key] then return ns.L[key] end
    return tostring(slotId)
end

function ns.GearAudit:EncodeIssues(issues)
    if not issues or #issues == 0 then return "" end
    local parts = {}
    for _, iss in ipairs(issues) do
        if iss and type(iss.slot) == "number" and (iss.kind == "enchant" or iss.kind == "gem") then
            parts[#parts + 1] = string.format("%d%s", iss.slot, iss.kind == "enchant" and "e" or "g")
        end
    end
    return table.concat(parts, "+")
end

function ns.GearAudit:DecodeIssues(s)
    local out = {}
    if not s or s == "" then return out end
    for piece in s:gmatch("[^+]+") do
        local sid, k = piece:match("^(%d+)([eg])$")
        if sid then
            local slot = tonumber(sid)
            if slot then
                out[#out + 1] = { slot = slot, kind = (k == "e") and "enchant" or "gem" }
            end
        end
    end
    return out
end

function ns.GearAudit:ScanPlayer()
    local issues = {}
    local twoH = MainHandIsTwoHand()
    for _, row in ipairs(SLOTS) do
        local sid = row.id
        if not (sid == INVSLOT_OFFHAND and twoH) then
            local link = GetInventoryItemLink("player", sid)
            if link then
                local _, _, quality = GetItemInfo(link)
                quality = tonumber(quality) or 0
                if quality >= MIN_QUALITY then
                    local ench = ParseLinkEnchant(link)
                    if row.needEnchant and (ench or 0) == 0 then
                        issues[#issues + 1] = { slot = sid, kind = "enchant" }
                    end
                    local stats = ItemStatsTable(link)
                    if StatsHaveEmptySocket(stats) then
                        issues[#issues + 1] = { slot = sid, kind = "gem" }
                    end
                end
            end
        end
    end
    return issues
end

function ns.GearAudit:PushToCache(nameKey, cache)
    if not ns.Sync or not ns.Sync.gearAudit or not cache then return end
    nameKey = NameKey(nameKey)
    local row = cache[nameKey]
    if not row then return end
    local e = ns.Sync.gearAudit[nameKey]
    if e and e.issues ~= nil then
        row.gearIssues = e.issues
        row.gearAuditAt = e.updatedAt
        row.gearIssueCount = #(e.issues)
    else
        row.gearIssues = nil
        row.gearAuditAt = nil
        row.gearIssueCount = nil
    end
end

function ns.GearAudit:SendAuditSet(nameKey, issues, updatedAt)
    if not ns.Comms or not ns.Comms.SendChunked then return end
    nameKey = NameKey(nameKey)
    if nameKey == "" then return end
    local enc = self:EncodeIssues(issues)
    local body = string.format("%s|%s|%s", nameKey, tostring(tonumber(updatedAt) or time()), enc)
    ns.Comms:SendChunked("AUDIT_SET", body, "GUILD")
end

function ns.GearAudit:ApplyStored(nameKey, issues, updatedAt, opts)
    opts = opts or {}
    nameKey = NameKey(nameKey)
    if nameKey == "" then return end
    issues = issues or {}
    local ua = tonumber(updatedAt) or time()
    ns.Sync.gearAudit = ns.Sync.gearAudit or {}
    ns.Sync.gearAudit[nameKey] = { issues = issues, updatedAt = ua }
    local me = NameKey(UnitName("player") or "")
    if me == nameKey and GCM_Settings then
        GCM_Settings.gearAuditLast = { t = ua, issues = issues, scanned = true }
    end
    self:PushToCache(nameKey, ns.Cache)
    if ns.Scanner and ns.Scanner._tempCache then
        self:PushToCache(nameKey, ns.Scanner._tempCache)
    end
    if opts.broadcast and ns.Comms then
        self:SendAuditSet(nameKey, issues, ua)
    end
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
end

function ns.GearAudit:OnReceivePayload(payload, sender)
    local a, b, c = payload:match("^([^|]+)|([^|]*)|(.*)$")
    if not a then return end
    local nk = NameKey(a)
    local sk = NameKey(sender or "")
    if nk == "" or sk == "" or nk ~= sk then return end
    ns.Sync.gearAudit = ns.Sync.gearAudit or {}
    local updatedAt = tonumber(b) or 0
    local prev = ns.Sync.gearAudit[nk]
    if prev and (prev.updatedAt or 0) > updatedAt then return end
    local issues = self:DecodeIssues(c or "")
    ns.Sync.gearAudit[nk] = { issues = issues, updatedAt = updatedAt }
    self:PushToCache(nk, ns.Cache)
    if ns.Scanner and ns.Scanner._tempCache then
        self:PushToCache(nk, ns.Scanner._tempCache)
    end
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
end

function ns.GearAudit:OnAuditReq()
    local nk = NameKey(UnitName("player") or "")
    if nk == "" then return end
    local e = ns.Sync.gearAudit and ns.Sync.gearAudit[nk]
    if e and e.issues ~= nil then
        self:SendAuditSet(nk, e.issues, e.updatedAt or time())
    end
end

function ns.GearAudit:LoginBroadcastIfAny()
    local nk = NameKey(UnitName("player") or "")
    if nk == "" then return end
    ns.Sync.gearAudit = ns.Sync.gearAudit or {}
    local e = ns.Sync.gearAudit[nk]
    if e and e.issues ~= nil then
        self:SendAuditSet(nk, e.issues, e.updatedAt or time())
        return
    end
    if GCM_Settings and GCM_Settings.gearAuditLast and GCM_Settings.gearAuditLast.scanned then
        local p = GCM_Settings.gearAuditLast
        local issues = p.issues or {}
        local t = p.t or time()
        ns.Sync.gearAudit[nk] = { issues = issues, updatedAt = t }
        self:PushToCache(nk, ns.Cache)
        self:SendAuditSet(nk, issues, t)
    end
end

function ns.GearAudit:PersistAndReturn()
    local issues = self:ScanPlayer()
    local t = time()
    local nk = NameKey(UnitName("player") or "")
    if nk == "" then return issues, t end
    self:ApplyStored(nk, issues, t, { broadcast = true })
    return issues, t
end

function ns.GearAudit:GetLastPersisted()
    local me = UnitName("player")
    if not me then return nil, nil end
    local nk = NameKey(me)
    local e = ns.Sync.gearAudit and ns.Sync.gearAudit[nk]
    if e and e.issues ~= nil then
        return e.issues, e.updatedAt
    end
    if GCM_Settings and GCM_Settings.gearAuditLast and GCM_Settings.gearAuditLast.scanned then
        return GCM_Settings.gearAuditLast.issues, GCM_Settings.gearAuditLast.t
    end
    return nil, nil
end

function ns.GearAudit:IssueLabel(issue)
    if not issue then return "" end
    local slotName = self:SlotLabel(issue.slot)
    if issue.kind == "enchant" then
        return string.format(ns.L.AUDIT_ISSUE_ENCHANT, slotName)
    end
    if issue.kind == "gem" then
        return string.format(ns.L.AUDIT_ISSUE_SOCKET, slotName)
    end
    return slotName
end

function ns.GearAudit:GetIssuesForMember(nameKey)
    if not ns.Sync or not ns.Sync.gearAudit then return nil end
    local e = ns.Sync.gearAudit[NameKey(nameKey)]
    if not e then return nil end
    return e.issues, e.updatedAt
end

function ns.GearAudit:RequestSync()
    if ns.Comms and ns.Comms.Broadcast then
        ns.Comms:Broadcast("AUDIT_REQ", "")
    end
end

function ns.GearAudit:Init()
    ns.Sync.gearAudit = ns.Sync.gearAudit or {}
    if not ns.Comms then return end
    ns.Comms:RegisterHandler("AUDIT_SET", function(payload, sender)
        ns.GearAudit:OnReceivePayload(payload, sender)
    end)
    ns.Comms:RegisterHandler("AUDIT_REQ", function()
        ns.GearAudit:OnAuditReq()
    end)
    if C_Timer and C_Timer.After then
        C_Timer.After(6, function()
            if ns.GearAudit and ns.GearAudit.LoginBroadcastIfAny then
                ns.GearAudit:LoginBroadcastIfAny()
            end
        end)
    end
end
