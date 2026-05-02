local _, ns = ...
ns.Roles = ns.Roles or {}

local function RoleKey(name)
    if not name or name == "" then return "" end
    return Ambiguate(name, "none")
end

function ns.Roles:NormalizeDeclaredRoleKeys()
    if not ns.Sync or not ns.Sync.declaredRoles then return end
    local dr = ns.Sync.declaredRoles
    local merged = {}
    for k, v in pairs(dr) do
        if type(v) == "string" and (v == "T" or v == "H" or v == "D") then
            local nk = RoleKey(k)
            if nk ~= "" then merged[nk] = v end
        end
    end
    wipe(dr)
    for k, v in pairs(merged) do
        dr[k] = v
    end
end

function ns.Roles:GetEffectiveRole(name, class)
    if not ns.Sync then return nil end
    ns.Sync.declaredRoles = ns.Sync.declaredRoles or {}
    local k = RoleKey(name)
    local dr = ns.Sync.declaredRoles[k]
    if not dr and name and k ~= name then
        dr = ns.Sync.declaredRoles[name]
    end
    if dr then return dr end
    if ns.Specs and class then
        local specId = ns.Specs:GetSpec(name)
        local meta = ns.Specs:GetSpecMeta(class, specId)
        if meta then return meta.role end
    end
    return nil
end

function ns.Roles:Get(name)
    if not ns.Sync or not ns.Sync.declaredRoles then return nil end
    local k = RoleKey(name)
    local v = ns.Sync.declaredRoles[k]
    if v then return v end
    if k ~= name and name then
        return ns.Sync.declaredRoles[name]
    end
    return nil
end

function ns.Roles:Set(name, role, opts)
    opts = opts or {}
    if not ns.Sync then return false end
    local me = UnitName("player")
    local nk = RoleKey(name)
    if nk == "" then return false end
    if me and RoleKey(me) ~= nk then
        if not ns.Notes or not ns.Notes:CanEditUI() then return false end
    end
    ns.Sync.declaredRoles = ns.Sync.declaredRoles or {}
    if role then
        ns.Sync.declaredRoles[nk] = role
    else
        ns.Sync.declaredRoles[nk] = nil
    end
    if opts.broadcast and ns.Comms then
        ns.Comms:Broadcast("ROLE_SET", string.format("%s|%s", nk, role or ""))
    end
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
    if ns.PublicNote and ns.PublicNote.IsManaged and ns.PublicNote:IsManaged() and me and RoleKey(me) == nk then
        ns.PublicNote:Reapply(true)
    end
    return true
end

function ns.Roles:SetMine(role)
    local me = UnitName("player")
    if not me then return false end
    if role and role ~= "T" and role ~= "H" and role ~= "D" then return false end
    return self:Set(me, role or nil, { broadcast = true })
end

function ns.Roles:OnReceive(payload, sender)
    local name, role = payload:match("^([^|]+)|(.*)$")
    if not name then return end
    if role == "" then role = nil end
    if not ns.Sync then return end
    local nk = RoleKey(name)
    if nk == "" then return end
    ns.Sync.declaredRoles = ns.Sync.declaredRoles or {}
    ns.Sync.declaredRoles[nk] = role
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
end

function ns.Roles:SerializeAll()
    if not ns.Sync or not ns.Sync.declaredRoles then return "" end
    local parts = {}
    for name, role in pairs(ns.Sync.declaredRoles) do
        if type(role) == "string" and role ~= "" then
            parts[#parts + 1] = name .. "=" .. role
        end
    end
    return table.concat(parts, ",")
end

function ns.Roles:OnRoleFull(payload, sender)
    if not payload or payload == "" then return end
    if not ns.Sync then return end
    ns.Sync.declaredRoles = ns.Sync.declaredRoles or {}
    for entry in payload:gmatch("[^,]+") do
        local name, role = entry:match("^([^=]+)=(.+)$")
        if name and role and role ~= "" then
            local nk = RoleKey(name)
            if nk ~= "" then
                ns.Sync.declaredRoles[nk] = role
            end
        end
    end
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
end

function ns.Roles:OnRoleReq(payload, sender)
    if not ns.Sync or not ns.Sync.declaredRoles or not next(ns.Sync.declaredRoles) then return end
    local serialized = self:SerializeAll()
    if serialized ~= "" and ns.Comms then
        ns.Comms:Whisper("ROLE_FULL", serialized, sender)
    end
end

function ns.Roles:RequestSync()
    if ns.Comms and ns.Comms.Broadcast then
        ns.Comms:Broadcast("ROLE_REQ", "")
    end
end

function ns.Roles:Init()
    if not ns.Comms then return end
    self:NormalizeDeclaredRoleKeys()
    ns.Comms:RegisterHandler("ROLE_SET", function(p, s) ns.Roles:OnReceive(p, s) end)
    ns.Comms:RegisterHandler("ROLE_REQ", function(p, s) ns.Roles:OnRoleReq(p, s) end)
    ns.Comms:RegisterHandler("ROLE_FULL", function(p, s) ns.Roles:OnRoleFull(p, s) end)
end
