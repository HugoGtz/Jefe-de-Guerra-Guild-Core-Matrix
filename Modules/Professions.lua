local _, ns = ...
ns.Professions = ns.Professions or {}

local RECIPE_CAP = 6000

local lastTradePush = 0
local lastSkillPush = 0

local function NameKey(n)
    if not n or n == "" then return "" end
    return Ambiguate(n, "none")
end

local function SpellSetToSortedList(set)
    local list = {}
    for id in pairs(set or {}) do
        id = tonumber(id)
        if id and id > 0 then list[#list + 1] = id end
    end
    table.sort(list)
    if #list > RECIPE_CAP then
        while #list > RECIPE_CAP do table.remove(list) end
    end
    return list
end

local function EncodeProfs(lines)
    local parts = {}
    for _, e in ipairs(lines or {}) do
        if e.id and e.c and e.m then
            parts[#parts + 1] = string.format("%d:%d/%d", e.id, e.c, e.m)
        end
    end
    return table.concat(parts, "+")
end

local function DecodeProfs(s)
    if not s or s == "" then return {} end
    local out = {}
    for piece in (s .. "+"):gmatch("([^+]*)%+") do
        piece = piece:match("^%s*(.-)%s*$") or ""
        if piece ~= "" then
            local id, c, m = piece:match("^(%d+):(%d+)/(%d+)$")
            id, c, m = tonumber(id), tonumber(c), tonumber(m)
            if id and c and m then out[#out + 1] = { id = id, c = c, m = m } end
        end
    end
    return out
end

local function EncodeSpells(spellSet)
    local list = SpellSetToSortedList(spellSet)
    return table.concat(list, ",")
end

local function DecodeSpells(s)
    local set = {}
    if not s or s == "" then return set end
    for piece in string.gmatch(s, "[^,]+") do
        local id = tonumber(piece)
        if id and id > 0 then set[id] = true end
    end
    return set
end

local function MergeSpellSets(a, b)
    local out = {}
    for k, v in pairs(a or {}) do if v then out[k] = true end end
    for k, v in pairs(b or {}) do if v then out[k] = true end end
    return out
end

function ns.Professions:GetLinesForPlayer(nameKey)
    if not ns.Sync or not ns.Sync.professions then return nil end
    local e = ns.Sync.professions[NameKey(nameKey)]
    if not e then return nil end
    return e.lines
end

function ns.Professions:GetSpellsForPlayer(nameKey)
    if not ns.Sync or not ns.Sync.professions then return nil end
    local e = ns.Sync.professions[NameKey(nameKey)]
    if not e or not e.spells then return nil end
    return e.spells
end

function ns.Professions:CountSpells(spellSet)
    local n = 0
    for _ in pairs(spellSet or {}) do n = n + 1 end
    return n
end

function ns.Professions:ScanTradeSkillWindowInto(spellSet)
    spellSet = spellSet or {}
    if C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs then
        local t = C_TradeSkillUI.GetAllRecipeIDs()
        if type(t) == "table" then
            for i = 1, #t do
                local id = tonumber(t[i])
                if id and id > 0 then spellSet[id] = true end
            end
        end
        return spellSet
    end
    if GetNumTradeSkills then
        local n = GetNumTradeSkills()
        n = tonumber(n) or 0
        for i = 1, n do
            local link = GetTradeSkillRecipeLink and GetTradeSkillRecipeLink(i) or nil
            if type(link) == "string" then
                local sid = tonumber(link:match("spell:(%d+)") or link:match("enchant:(%d+)"))
                if sid then spellSet[sid] = true end
            end
        end
    end
    return spellSet
end

function ns.Professions:ReadSkillbookPrimaryLines()
    local out = {}
    if not GetProfessions or not GetProfessionInfo then return out end
    local p1, p2, p3, p4, p5, p6 = GetProfessions()
    for _, idx in ipairs({ p1, p2, p3, p4, p5, p6 }) do
        if idx then
            local _, _, skillLevel, maxSkillLevel, _, _, skillLine = GetProfessionInfo(idx)
            skillLine = tonumber(skillLine)
            skillLevel = tonumber(skillLevel) or 0
            maxSkillLevel = tonumber(maxSkillLevel) or 0
            if skillLine and skillLine > 0 and maxSkillLevel > 0 then
                out[#out + 1] = { id = skillLine, c = skillLevel, m = maxSkillLevel }
            end
        end
    end
    return out
end

local function MergeLinesById(oldLines, newLines)
    local byId = {}
    for _, e in ipairs(oldLines or {}) do
        if e.id then byId[e.id] = { id = e.id, c = e.c or 0, m = e.m or 0 } end
    end
    for _, e in ipairs(newLines or {}) do
        if e.id then byId[e.id] = { id = e.id, c = e.c or 0, m = e.m or 0 } end
    end
    local list = {}
    for _, e in pairs(byId) do list[#list + 1] = e end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

function ns.Professions:StorePlayerState(nameKey, lines, spellSet, updatedAt, opts)
    opts = opts or {}
    if not ns.Sync then return end
    ns.Sync.professions = ns.Sync.professions or {}
    nameKey = NameKey(nameKey)
    if nameKey == "" then return end
    updatedAt = tonumber(updatedAt) or time()
    local prev = ns.Sync.professions[nameKey]
    local mergedSpells = MergeSpellSets(prev and prev.spells, spellSet)
    self:TrimSpellSet(mergedSpells)
    local mergedLines = MergeLinesById(prev and prev.lines, lines)
    ns.Sync.professions[nameKey] = {
        lines = mergedLines,
        spells = mergedSpells,
        updatedAt = updatedAt,
    }
    self:PushToCache(nameKey)
    if opts.broadcast and ns.Comms and ns.Comms.SendChunked then
        local profStr = EncodeProfs(mergedLines)
        local spellStr = EncodeSpells(mergedSpells)
        local body = string.format("%s|%s|%s|%d", nameKey, profStr, spellStr, updatedAt)
        ns.Comms:SendChunked("PROF_SET", body, "GUILD")
    end
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
end

function ns.Professions:TrimSpellSet(spellSet)
    local list = SpellSetToSortedList(spellSet)
    wipe(spellSet)
    for _, id in ipairs(list) do spellSet[id] = true end
end

function ns.Professions:PushToCache(nameKey)
    nameKey = NameKey(nameKey)
    if not ns.Cache or not ns.Cache[nameKey] then return end
    local e = ns.Sync.professions and ns.Sync.professions[nameKey]
    if e then
        ns.Cache[nameKey].profLines = e.lines
        ns.Cache[nameKey].profSpellCount = self:CountSpells(e.spells)
        ns.Cache[nameKey].profUpdatedAt = e.updatedAt or 0
    else
        ns.Cache[nameKey].profLines = nil
        ns.Cache[nameKey].profSpellCount = 0
        ns.Cache[nameKey].profUpdatedAt = 0
    end
end

function ns.Professions:ApplyIncoming(nameKey, lines, spellSet, updatedAt)
    if not ns.Sync then return end
    ns.Sync.professions = ns.Sync.professions or {}
    nameKey = NameKey(nameKey)
    if nameKey == "" then return end
    updatedAt = tonumber(updatedAt) or 0
    local prev = ns.Sync.professions[nameKey]
    if prev and (prev.updatedAt or 0) > updatedAt then return end
    ns.Sync.professions[nameKey] = {
        lines = lines,
        spells = spellSet,
        updatedAt = updatedAt,
    }
    self:PushToCache(nameKey)
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
end

function ns.Professions:OnTradeSkillEvent()
    local t = GetTime()
    if (t - lastTradePush) < 1.5 then return end
    lastTradePush = t
    local me = UnitName("player")
    if not me then return end
    local nk = NameKey(me)
    local lines = self:ReadSkillbookPrimaryLines()
    local prev = ns.Sync.professions and ns.Sync.professions[nk]
    local spellSet = self:ScanTradeSkillWindowInto({})
    if prev and prev.spells then
        spellSet = MergeSpellSets(prev.spells, spellSet)
    end
    self:TrimSpellSet(spellSet)
    local newLines = MergeLinesById(prev and prev.lines, lines)
    self:StorePlayerState(nk, newLines, spellSet, time(), { broadcast = true })
end

function ns.Professions:OnReceivePayload(payload, sender)
    sender = NameKey(sender or "")
    local nk, profStr, spellStr, upd = payload:match("^([^|]+)|([^|]*)|([^|]*)|(%d+)$")
    if not nk then return end
    nk = NameKey(nk)
    if nk == "" or nk ~= sender then return end
    local lines = DecodeProfs(profStr or "")
    local spells = DecodeSpells(spellStr or "")
    self:ApplyIncoming(nk, lines, spells, tonumber(upd))
end

function ns.Professions:OnRequest(sender)
    sender = NameKey(sender or "")
    if sender == "" then return end
    local me = UnitName("player")
    if not me then return end
    local nk = NameKey(me)
    local e = ns.Sync.professions and ns.Sync.professions[nk]
    if not e then return end
    local profStr = EncodeProfs(e.lines)
    local spellStr = EncodeSpells(e.spells)
    if profStr == "" and spellStr == "" then return end
    local body = string.format("%s|%s|%s|%d", nk, profStr, spellStr, tonumber(e.updatedAt) or time())
    if ns.Comms and ns.Comms.SendChunkedWhisper then
        ns.Comms:SendChunkedWhisper("PROF_SET", body, sender)
    end
end

function ns.Professions:RequestSync()
    if ns.Comms and ns.Comms.Broadcast then
        ns.Comms:Broadcast("PROF_REQ", "")
    end
end

function ns.Professions:Init()
    if not ns.Comms then return end
    ns.Comms:RegisterHandler("PROF_SET", function(p, s) ns.Professions:OnReceivePayload(p, s) end)
    ns.Comms:RegisterHandler("PROF_REQ", function(_, s) ns.Professions:OnRequest(s) end)

    local f = CreateFrame("Frame")
    f:RegisterEvent("TRADE_SKILL_SHOW")
    f:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
    if f.RegisterEvent then pcall(function() f:RegisterEvent("TRADE_SKILL_DATA_SOURCE_CHANGED") end) end
    f:SetScript("OnEvent", function(_, ev)
        if ev == "TRADE_SKILL_SHOW" or ev == "TRADE_SKILL_LIST_UPDATE" or ev == "TRADE_SKILL_DATA_SOURCE_CHANGED" then
            if C_Timer and C_Timer.After then
                C_Timer.After(0.35, function() ns.Professions:OnTradeSkillEvent() end)
            else
                ns.Professions:OnTradeSkillEvent()
            end
        end
    end)

    local g = CreateFrame("Frame")
    g:RegisterEvent("SKILL_LINES_CHANGED")
    g:SetScript("OnEvent", function()
        local now = GetTime()
        if (now - lastSkillPush) < 5 then return end
        lastSkillPush = now
        local me = UnitName("player")
        if not me then return end
        local nk = NameKey(me)
        local lines = ns.Professions:ReadSkillbookPrimaryLines()
        if #lines == 0 then return end
        local prev = ns.Sync.professions and ns.Sync.professions[nk]
        local mergedLines = MergeLinesById(prev and prev.lines, lines)
        local same = false
        if prev and EncodeProfs(prev.lines) == EncodeProfs(mergedLines) then same = true end
        if same then return end
        ns.Professions:StorePlayerState(
            nk,
            mergedLines,
            prev and prev.spells or {},
            time(),
            { broadcast = true }
        )
    end)
end
