local addonName, ns = ...
ns.InviteTools = ns.InviteTools or {}

local GAP_SEC = 0.35

local function NameKey(name)
    return Ambiguate(name or "", "none")
end

local function UnitGroupNameKey(u)
    if not UnitExists(u) then return "" end
    local full = UnitFullName(u)
    if full and full ~= "" then
        return Ambiguate(full, "none")
    end
    local n = UnitName(u)
    if not n then return "" end
    return Ambiguate(n, "none")
end

local function IsSelfNameKey(nameKey)
    if nameKey == "" then return false end
    local pf = UnitFullName("player")
    if pf and pf ~= "" and nameKey == Ambiguate(pf, "none") then return true end
    local me = UnitName("player")
    return me ~= nil and nameKey == NameKey(me)
end

local function IsInLocalGroupByNameKey(nameKey)
    if nameKey == "" then return false end
    if IsSelfNameKey(nameKey) then return true end
    if IsInRaid() then
        local n = GetNumRaidMembers and GetNumRaidMembers() or 0
        for i = 1, n do
            local u = "raid" .. i
            if UnitGroupNameKey(u) == nameKey then return true end
        end
        return false
    end
    for i = 1, 4 do
        local u = "party" .. i
        if UnitGroupNameKey(u) == nameKey then return true end
    end
    return false
end

function ns.InviteTools:ResolveInviteToken(rosterOrShort)
    if not rosterOrShort or rosterOrShort == "" then return nil end
    if Ambiguate then
        local g = Ambiguate(rosterOrShort, "guild")
        if g and g ~= "" then return g end
    end
    return rosterOrShort
end

function ns.InviteTools:InviteOne(rosterOrShort)
    if not InviteUnit then return false end
    local token = self:ResolveInviteToken(rosterOrShort)
    if not token then return false end
    InviteUnit(token)
    return true
end

function ns.InviteTools:InviteOnlineMembers(members)
    if not InviteUnit then return 0, 0 end
    local tokens = {}
    local onlineCore = 0
    for _, m in ipairs(members or {}) do
        if m.online then
            onlineCore = onlineCore + 1
            local nk = NameKey(m.name)
            if nk ~= "" and not IsSelfNameKey(nk) and not IsInLocalGroupByNameKey(nk) then
                local token = self:ResolveInviteToken(m.rosterName or m.name)
                if token then tokens[#tokens + 1] = token end
            end
        end
    end
    local total = #tokens
    if total == 0 then return 0, onlineCore end
    if C_Timer and C_Timer.After then
        for i = 1, total do
            local tok = tokens[i]
            C_Timer.After((i - 1) * GAP_SEC, function()
                if InviteUnit then InviteUnit(tok) end
            end)
        end
    else
        for i = 1, total do
            InviteUnit(tokens[i])
        end
    end
    return total, onlineCore
end
