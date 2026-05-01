local addonName, ns = ...
ns.InviteTools = ns.InviteTools or {}

local GAP_SEC = 0.35

local function NameKey(name)
    return Ambiguate(name or "", "none")
end

local function UnitGroupNameKey(u)
    if not UnitExists(u) then return "" end
    if UnitIsPlayer and UnitIsPlayer(u) == false then return "" end
    local full = UnitFullName(u)
    if full and full ~= "" then
        return Ambiguate(full, "none")
    end
    local n = UnitName(u)
    if not n then return "" end
    return Ambiguate(n, "none")
end

local function InAnyGroup()
    if IsInGroup and IsInGroup() then return true end
    if IsInRaid and IsInRaid() then return true end
    local pm = GetNumPartyMembers and GetNumPartyMembers() or 0
    return pm > 0
end

function ns.InviteTools:PlayerCanInvite()
    if not InAnyGroup() then return true end
    if UnitIsGroupLeader and UnitIsGroupLeader("player") then return true end
    if UnitIsPartyLeader and UnitIsPartyLeader("player") then return true end
    if IsInRaid and IsInRaid() then
        if UnitIsRaidAssistant and UnitIsRaidAssistant("player") then return true end
        if UnitIsRaidOfficer and UnitIsGroupLeader then
            if UnitIsRaidOfficer("player") and not UnitIsGroupLeader("player") then return true end
        end
    end
    return false
end

local function IsSelfNameKey(nameKey)
    if nameKey == "" then return false end
    local pf = UnitFullName("player")
    if pf and pf ~= "" and nameKey == Ambiguate(pf, "none") then return true end
    local me = UnitName("player")
    return me ~= nil and nameKey == NameKey(me)
end

local function NameKeysForMember(m)
    local seen = {}
    local keys = {}
    local function add(raw)
        local k = NameKey(raw)
        if k ~= "" and not seen[k] then
            seen[k] = true
            keys[#keys + 1] = k
        end
    end
    add(m.rosterName)
    add(m.name)
    return keys
end

local function AnyKeyMatchesGroup(nameKeys)
    if not InAnyGroup() then return false end
    if IsInRaid and IsInRaid() then
        for i = 1, 40 do
            local u = "raid" .. i
            local uk = UnitGroupNameKey(u)
            if uk ~= "" then
                for ki = 1, #nameKeys do
                    if nameKeys[ki] == uk then return true end
                end
            end
        end
        return false
    end
    for i = 1, 4 do
        local u = "party" .. i
        local uk = UnitGroupNameKey(u)
        if uk ~= "" then
            for ki = 1, #nameKeys do
                if nameKeys[ki] == uk then return true end
            end
        end
    end
    return false
end

function ns.InviteTools:GetInviteFn()
    if type(InviteUnit) == "function" then return InviteUnit end
    local cp = C_PartyInfo
    if cp and type(cp.InviteUnit) == "function" then return cp.InviteUnit end
    return nil
end

function ns.InviteTools:HasInviteApi()
    return self:GetInviteFn() ~= nil
end

function ns.InviteTools:DispatchInvite(token)
    local fn = self:GetInviteFn()
    if not fn or not token or token == "" then return false end
    fn(token)
    return true
end

function ns.InviteTools:ResolveInviteToken(rosterOrShort)
    if not rosterOrShort or rosterOrShort == "" then return nil end
    return rosterOrShort
end

function ns.InviteTools:InviteOne(rosterOrShort)
    if not ns.InviteTools:HasInviteApi() then return false end
    if not ns.InviteTools:PlayerCanInvite() then
        if ns.L and ns.L.INVITE_NEED_PERMISSION then
            print(ns.L.BRAND_YELLOW .. " " .. ns.L.INVITE_NEED_PERMISSION)
        end
        return false
    end
    local token = self:ResolveInviteToken(rosterOrShort)
    if not token then return false end
    return self:DispatchInvite(token)
end

function ns.InviteTools:PrintInviteDiagnostics(coreId, diag, permBlocked)
    local L = ns.L
    if not L or type(diag) ~= "table" then return end
    local p = ns.L.BRAND_YELLOW .. " "
    local yn = function(b) return b and L.INVITE_DIAG_YES or L.INVITE_DIAG_NO end
    print(p .. string.format(L.INVITE_DIAG_HEADER, coreId or 0))
    print(p .. string.format(L.INVITE_DIAG_TOTAL, diag.totalInCore or 0))
    print(p .. string.format(L.INVITE_DIAG_OFFLINE, diag.offlineCore or 0))
    print(p .. string.format(L.INVITE_DIAG_ONLINE, diag.onlineCore or 0))
    print(p .. string.format(L.INVITE_DIAG_SKIP_YOU, diag.skipSelf or 0))
    print(p .. string.format(L.INVITE_DIAG_SKIP_GROUP, diag.skipGrouped or 0))
    print(p .. string.format(L.INVITE_DIAG_SKIP_NONAME, diag.skipNoKeys or 0))
    print(p .. string.format(L.INVITE_DIAG_SKIP_NOTOKEN, diag.skipNoToken or 0))
    print(p .. string.format(L.INVITE_DIAG_QUEUE, diag.queued or 0))
    print(p .. string.format(L.INVITE_DIAG_CANINVITE, yn(diag.canInvite)))
    print(p .. string.format(L.INVITE_DIAG_HASAPI, yn(diag.hasInviteUnit)))
    local q = diag.queued or 0
    if q > 0 then
        if permBlocked then print(p .. L.INVITE_DIAG_BLOCK_PERM) end
        if not diag.hasInviteUnit then print(p .. L.INVITE_DIAG_BLOCK_API) end
        if diag.canInvite and diag.hasInviteUnit and not permBlocked then
            print(p .. string.format(L.INVITE_DIAG_BLOCK_UNKNOWN, q))
        end
    else
        print(p .. L.INVITE_DIAG_RESULT_NONE)
    end
end

function ns.InviteTools:InviteOnlineMembers(members)
    local tokens = {}
    local onlineCore = 0
    local offlineCore = 0
    local skipSelf = 0
    local skipGrouped = 0
    local skipNoKeys = 0
    local skipNoToken = 0
    local totalInCore = #(members or {})
    for _, m in ipairs(members or {}) do
        if not m.online then
            offlineCore = offlineCore + 1
        else
            onlineCore = onlineCore + 1
            local keys = NameKeysForMember(m)
            if #keys == 0 then
                skipNoKeys = skipNoKeys + 1
            else
                local selfSkip = false
                for ki = 1, #keys do
                    if IsSelfNameKey(keys[ki]) then selfSkip = true break end
                end
                if selfSkip then
                    skipSelf = skipSelf + 1
                elseif AnyKeyMatchesGroup(keys) then
                    skipGrouped = skipGrouped + 1
                else
                    local token = self:ResolveInviteToken(m.rosterName or m.name)
                    if token then
                        tokens[#tokens + 1] = token
                    else
                        skipNoToken = skipNoToken + 1
                    end
                end
            end
        end
    end
    local total = #tokens
    local permBlocked = false
    local diag = {
        totalInCore = totalInCore,
        offlineCore = offlineCore,
        onlineCore = onlineCore,
        skipSelf = skipSelf,
        skipGrouped = skipGrouped,
        skipNoKeys = skipNoKeys,
        skipNoToken = skipNoToken,
        queued = total,
        canInvite = ns.InviteTools:PlayerCanInvite(),
        hasInviteUnit = ns.InviteTools:HasInviteApi(),
    }
    if total == 0 then return 0, onlineCore, permBlocked, diag end
    if not diag.canInvite then permBlocked = true return 0, onlineCore, permBlocked, diag end
    if not diag.hasInviteUnit then return 0, onlineCore, permBlocked, diag end
    if C_Timer and C_Timer.After then
        for i = 1, total do
            local tok = tokens[i]
            C_Timer.After((i - 1) * GAP_SEC, function()
                ns.InviteTools:DispatchInvite(tok)
            end)
        end
    else
        for i = 1, total do
            ns.InviteTools:DispatchInvite(tokens[i])
        end
    end
    return total, onlineCore, permBlocked, diag
end

function ns.InviteTools:GetInviteGapSeconds()
    return GAP_SEC
end
