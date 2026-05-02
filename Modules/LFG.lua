local addonName, ns = ...
ns.LFG = {}

local DETAIL_MAX = 120
local STALE_AGE   = 12 * 3600  -- prune entries older than 12 h on login

local KNOWN = { HC = true, ND = true, RAID = true, PVP = true, CRAFT = true, QU = true, MI = true }
local ALIAS = { H = "HC", N = "ND", R = "RAID", P = "PVP", C = "CRAFT", Q = "QU", M = "MI" }
local MODES = { LFG = true, LFM = true }

local function NormalizeToken(raw)
    local s = (raw or ""):match("^%s*([A-Za-z]+)")
    if not s then return nil end
    s = string.upper(s)
    if ALIAS[s] then s = ALIAS[s] end
    if KNOWN[s] then return s end
    return nil
end

local function NormalizeMode(raw)
    local s = string.upper(tostring(raw or ""))
    return MODES[s] and s or "LFG"
end

local function DedupeSorted(tags)
    local seen, out = {}, {}
    for _, c in ipairs(tags or {}) do
        if type(c) == "string" and not seen[c] then
            seen[c] = true
            out[#out + 1] = c
        end
    end
    table.sort(out)
    return out
end

local function SanitizeDetail(d)
    d = tostring(d or "")
    d = d:gsub("[|\r\n]", "")
    if #d > DETAIL_MAX then d = d:sub(1, DETAIL_MAX) end
    return d
end

function ns.LFG:KnownCodes()
    return { "HC", "ND", "RAID", "PVP", "CRAFT", "QU", "MI" }
end

function ns.LFG:CodesFromWhitespace(arg)
    local out, seen = {}, {}
    for piece in (arg or ""):gmatch("%S+") do
        local code = NormalizeToken(piece)
        if code and not seen[code] then
            seen[code] = true
            out[#out + 1] = code
        end
    end
    table.sort(out)
    return out
end

-- Wire format: nameKey|tags|detail|updatedAt|mode
-- Backward compat: updatedAt and mode are optional (default 0 / "LFG")
function ns.LFG:ParseWirePayload(payload)
    local parts = {}
    for part in (payload .. "|"):gmatch("([^|]*)|") do
        parts[#parts + 1] = part
    end
    local nk = parts[1]
    if not nk or nk == "" then return nil end
    nk = Ambiguate(nk, "none")
    local tagStr    = parts[2] or ""
    local detail    = SanitizeDetail(parts[3] or "")
    local updatedAt = tonumber(parts[4]) or 0
    local mode      = NormalizeMode(parts[5])
    local tags, seen = {}, {}
    if tagStr ~= "" then
        for piece in tagStr:gmatch("[^+]+") do
            local code = NormalizeToken(piece)
            if code and not seen[code] then seen[code] = true; tags[#tags + 1] = code end
        end
    end
    table.sort(tags)
    return nk, tags, detail, updatedAt, mode
end

function ns.LFG:EncodeWirePayload(nameKey, tags, detail, updatedAt, mode)
    nameKey   = Ambiguate(nameKey or "", "none")
    tags      = DedupeSorted(tags or {})
    detail    = SanitizeDetail(detail)
    updatedAt = tostring(tonumber(updatedAt) or time())
    mode      = NormalizeMode(mode)
    return string.format("%s|%s|%s|%s|%s",
        nameKey, table.concat(tags, "+"), detail, updatedAt, mode)
end

local function StoreEntry(nameKey, tags, detail, updatedAt, mode)
    if not ns.Sync then return end
    ns.Sync.lfg = ns.Sync.lfg or {}
    nameKey   = Ambiguate(nameKey, "none")
    tags      = DedupeSorted(tags or {})
    detail    = SanitizeDetail(detail or "")
    updatedAt = tonumber(updatedAt) or time()
    mode      = NormalizeMode(mode)
    if #tags == 0 and detail == "" then
        ns.Sync.lfg[nameKey] = nil
    else
        ns.Sync.lfg[nameKey] = { tags = tags, detail = detail, updatedAt = updatedAt, mode = mode }
    end
end

local function PushToCache(nameKey)
    nameKey = Ambiguate(nameKey, "none")
    if not ns.Cache or not ns.Cache[nameKey] then return end
    local e = ns.Sync.lfg and ns.Sync.lfg[nameKey]
    if e then
        local lt = {}
        for _, t in ipairs(e.tags or {}) do lt[#lt + 1] = t end
        ns.Cache[nameKey].lfg        = lt
        ns.Cache[nameKey].lfgDetail  = e.detail    or ""
        ns.Cache[nameKey].lfgUpdatedAt = e.updatedAt or 0
        ns.Cache[nameKey].lfgMode    = e.mode       or "LFG"
    else
        ns.Cache[nameKey].lfg        = {}
        ns.Cache[nameKey].lfgDetail  = ""
        ns.Cache[nameKey].lfgUpdatedAt = 0
        ns.Cache[nameKey].lfgMode    = "LFG"
    end
end

function ns.LFG:Set(nameKey, tags, detail, mode, opts)
    opts = opts or {}
    local updatedAt = time()
    StoreEntry(nameKey, tags, detail, updatedAt, mode)
    PushToCache(nameKey)
    if opts.broadcast and ns.Comms and ns.Comms.Broadcast then
        ns.Comms:Broadcast("LFG_SET", self:EncodeWirePayload(nameKey, tags, detail, updatedAt, mode), opts.unthrottled == true)
    end
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
    return true
end

function ns.LFG:SetMine(tags, detail, mode)
    local me = UnitName("player")
    if not me then return false end
    local nk  = Ambiguate(me, "none")
    tags      = DedupeSorted(tags or {})
    detail    = SanitizeDetail(detail or "")
    local prev      = ns.Sync.lfg and ns.Sync.lfg[nk]
    local prevTags   = prev and DedupeSorted(prev.tags or {}) or {}
    local prevDetail = SanitizeDetail(prev and prev.detail or "")
    local prevMode   = prev and prev.mode or "LFG"
    -- preserve existing mode when not specified
    mode = mode and NormalizeMode(mode) or prevMode
    local same = #tags == #prevTags
    if same then
        for i = 1, #tags do if tags[i] ~= prevTags[i] then same = false; break end end
    end
    if same and detail == prevDetail and mode == prevMode then
        print(ns.L.BRAND_YELLOW .. " " .. ns.L.NOTE_NO_CHANGE)
        return false
    end
    self:Set(nk, tags, detail, mode, { broadcast = true })
    print(ns.L.BRAND_GREEN .. " " .. ns.L.LFG_BROADCAST_UPDATED)
    return true
end

function ns.LFG:ClearMine()
    local me = UnitName("player")
    if not me then return false end
    local nk = Ambiguate(me, "none")
    if not ns.Sync or not ns.Sync.lfg or not ns.Sync.lfg[nk] then
        print(ns.L.BRAND_YELLOW .. " " .. ns.L.LFG_ALREADY_CLEAR)
        return false
    end
    self:Set(nk, {}, "", "LFG", { broadcast = true })
    print(ns.L.BRAND_GREEN .. " " .. ns.L.LFG_CLEARED)
    return true
end

function ns.LFG:ClearMineOnLogout()
    local me = UnitName("player")
    if not me or not ns.Sync or not ns.Sync.lfg then return end
    local nk = Ambiguate(me, "none")
    if not ns.Sync.lfg[nk] then return end
    self:Set(nk, {}, "", "LFG", { broadcast = true, unthrottled = true })
end

function ns.LFG:PruneExpired(maxAge)
    if not ns.Sync or not ns.Sync.lfg then return 0 end
    maxAge = maxAge or STALE_AGE
    local now, remove = time(), {}
    for nk, e in pairs(ns.Sync.lfg) do
        if now - (e.updatedAt or 0) > maxAge then remove[#remove + 1] = nk end
    end
    for _, nk in ipairs(remove) do ns.Sync.lfg[nk] = nil end
    if #remove > 0 and ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
    return #remove
end

function ns.LFG:GetAge(nameKey)
    nameKey = Ambiguate(nameKey, "none")
    local e = ns.Sync.lfg and ns.Sync.lfg[nameKey]
    if not e or not e.updatedAt or e.updatedAt == 0 then return nil end
    return time() - e.updatedAt
end

function ns.LFG:OnReceive(payload, sender)
    sender = Ambiguate(sender or "", "none")
    local nk, tags, detail, updatedAt, mode = self:ParseWirePayload(payload)
    if not nk then return end
    if nk ~= sender then return end
    if updatedAt == 0 then updatedAt = time() end
    StoreEntry(nk, tags, detail, updatedAt, mode)
    PushToCache(nk)
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
end

-- Bulk format: nameKey=tags~detail~updatedAt~mode,...
-- Backward compat: updatedAt and mode are optional trailing fields
function ns.LFG:SerializeAll()
    if not ns.Sync or not ns.Sync.lfg then return "" end
    local parts = {}
    for nameKey, e in pairs(ns.Sync.lfg) do
        local tags   = DedupeSorted(e.tags or {})
        local det    = SanitizeDetail(e.detail or "")
        if #tags > 0 or det ~= "" then
            local safeDet = det:gsub("[,=~%+]", " ")
            parts[#parts + 1] = string.format("%s=%s~%s~%d~%s",
                nameKey, table.concat(tags, "+"), safeDet,
                e.updatedAt or 0, NormalizeMode(e.mode))
        end
    end
    table.sort(parts)
    return table.concat(parts, ",")
end

function ns.LFG:OnFull(payload)
    if not payload or payload == "" then return end
    if not ns.Sync then return end
    ns.Sync.lfg = ns.Sync.lfg or {}
    for entry in payload:gmatch("[^,]+") do
        local nk, body = entry:match("^([^=]+)=(.+)$")
        if nk and body then
            nk = Ambiguate(nk, "none")
            local fields = {}
            for f in (body .. "~"):gmatch("([^~]*)~") do fields[#fields + 1] = f end
            local tagPart   = fields[1] or ""
            local det       = fields[2] or ""
            local updatedAt = tonumber(fields[3]) or 0
            local mode      = NormalizeMode(fields[4])
            local tags, seen = {}, {}
            if tagPart ~= "" then
                for piece in tagPart:gmatch("[^+]+") do
                    local code = NormalizeToken(piece)
                    if code and not seen[code] then seen[code] = true; tags[#tags + 1] = code end
                end
            end
            table.sort(tags)
            det = SanitizeDetail(det)
            if #tags == 0 and det == "" then
                ns.Sync.lfg[nk] = nil
            else
                ns.Sync.lfg[nk] = { tags = tags, detail = det, updatedAt = updatedAt, mode = mode }
            end
        end
    end
    if ns.Scanner and ns.Scanner.ResetThrottle then ns.Scanner:ResetThrottle() end
    if ns.Scanner and ns.Scanner.ParseGuildNotes then ns.Scanner:ParseGuildNotes() end
end

function ns.LFG:OnReq(payload, sender)
    local serialized = self:SerializeAll()
    if serialized ~= "" and ns.Comms then
        ns.Comms:Whisper("LFG_FULL", serialized, sender)
    end
end

function ns.LFG:RequestSync()
    if ns.Comms and ns.Comms.Broadcast then
        ns.Comms:Broadcast("LFG_REQ", "")
        self:PruneExpired()
    end
end

function ns.LFG:Init()
    if not ns.Comms then return end
    ns.Comms:RegisterHandler("LFG_SET",  function(p, s) ns.LFG:OnReceive(p, s) end)
    ns.Comms:RegisterHandler("LFG_REQ",  function(p, s) ns.LFG:OnReq(p, s) end)
    ns.Comms:RegisterHandler("LFG_FULL", function(p, s) ns.LFG:OnFull(p, s) end)
end
