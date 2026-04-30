local addonName, ns = ...
ns.InviteTools = ns.InviteTools or {}

local GAP_SEC = 0.35

local function NameKey(name)
    return Ambiguate(name or "", "none")
end

local function IsSelfNameKey(nameKey)
    local me = UnitName("player")
    if not me then return false end
    if nameKey == "" then return false end
    return nameKey == NameKey(me)
end

local function IsInLocalGroupByNameKey(nameKey)
    if nameKey == "" then return false end
    if IsSelfNameKey(nameKey) then return true end
    if IsInRaid() then
        local n = GetNumRaidMembers and GetNumRaidMembers() or 0
        for i = 1, n do
            local u = "raid" .. i
            if UnitExists(u) then
                local un = NameKey(UnitName(u))
                if un ~= "" and un == nameKey then return true end
            end
        end
        return false
    end
    for i = 1, 4 do
        local u = "party" .. i
        if UnitExists(u) then
            local un = NameKey(UnitName(u))
            if un ~= "" and un == nameKey then return true end
        end
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
    if not InviteUnit then return 0 end
    local tokens = {}
    for _, m in ipairs(members or {}) do
        if m.online then
            local nk = NameKey(m.name)
            if nk ~= "" and not IsSelfNameKey(nk) and not IsInLocalGroupByNameKey(nk) then
                local token = self:ResolveInviteToken(m.rosterName or m.name)
                if token then tokens[#tokens + 1] = token end
            end
        end
    end
    local total = #tokens
    if total == 0 then return 0 end
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
    return total
end
