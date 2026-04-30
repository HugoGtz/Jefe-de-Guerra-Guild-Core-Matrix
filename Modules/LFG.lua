local addonName, ns = ...
ns.LFG = {}

local DETAIL_MAX = 120

local KNOWN = { HC = true, ND = true, QU = true, MI = true }
local ALIAS = { H = "HC", N = "ND", Q = "QU", M = "MI" }

local function NormalizeToken(raw)
    local s = (raw or ""):match("^%s*([A-Za-z]+)")
    if not s then return nil end
    s = string.upper(s)
    if ALIAS[s] then s = ALIAS[s] end
    if KNOWN[s] then return s end
    return nil
end

local function DedupeSorted(tags)
    local seen = {}
    local out = {}
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
    if #d > DETAIL_MAX then
        d = d:sub(1, DETAIL_MAX)
    end
    return d
end

function ns.LFG:KnownCodes()
    return { "HC", "ND", "QU", "MI" }
end

function ns.LFG:CodesFromWhitespace(arg)
    local out = {}
    local seen = {}
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

function ns.LFG:ParseWirePayload(payload)
    local nk, tagStr, detail = payload:match("^([^|]+)|([^|]*)|(.*)$")
    if not nk then return nil end
    nk = Ambiguate(nk, "none")
    detail = SanitizeDetail(detail or "")
    local tags = {}
    local seen = {}
    if tagStr and tagStr ~= "" then
        for piece in tagStr:gmatch("[^+]+") do
            local code = NormalizeToken(piece)
            if code and not seen[code] then
                seen[code] = true
                tags[#tags + 1] = code
            end
        end
    end
    table.sort(tags)
    return nk, tags, detail
end

function ns.LFG:EncodeWirePayload(nameKey, tags, detail)
    nameKey = Ambiguate(nameKey or "", "none")
    tags = DedupeSorted(tags or {})
    detail = SanitizeDetail(detail)
    return string.format("%s|%s|%s", nameKey, table.concat(tags, "+"), detail)
end

local function StoreEntry(nameKey, tags, detail)
    if not ns.Sync then return end
    ns.Sync.lfg = ns.Sync.lfg or {}
    nameKey = Ambiguate(nameKey, "none")
    tags = DedupeSorted(tags or {})
    detail = SanitizeDetail(detail or "")
    if #tags == 0 and detail == "" then
        ns.Sync.lfg[nameKey] = nil
    else
        ns.Sync.lfg[nameKey] = { tags = tags, detail = detail }
    end
end

local function PushToCache(nameKey)
    nameKey = Ambiguate(nameKey, "none")
    if not ns.Cache or not ns.Cache[nameKey] then return end
    local e = ns.Sync.lfg and ns.Sync.lfg[nameKey]
    if e then
        local lt = {}
        for _, t in ipairs(e.tags or {}) do
            lt[#lt + 1] = t
        end
        ns.Cache[nameKey].lfg = lt
        ns.Cache[nameKey].lfgDetail = e.detail or ""
    else
        ns.Cache[nameKey].lfg = {}
        ns.Cache[nameKey].lfgDetail = ""
    end
end

function ns.LFG:Set(nameKey, tags, detail, opts)
    opts = opts or {}
    StoreEntry(nameKey, tags, detail)
    PushToCache(nameKey)
    if opts.broadcast and ns.Comms and ns.Comms.Broadcast then
        ns.Comms:Broadcast("LFG_SET", self:EncodeWirePayload(nameKey, tags, detail))
    end
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
    return true
end

function ns.LFG:SetMine(tags, detail)
    local me = UnitName("player")
    if not me then return false end
    local nk = Ambiguate(me, "none")
    tags = DedupeSorted(tags or {})
    detail = SanitizeDetail(detail or "")
    local prev = ns.Sync.lfg and ns.Sync.lfg[nk]
    local prevTags = prev and DedupeSorted(prev.tags or {}) or {}
    local prevDetail = SanitizeDetail(prev and prev.detail or "")
    local same = #tags == #prevTags
    if same then
        for i = 1, #tags do
            if tags[i] ~= prevTags[i] then
                same = false
                break
            end
        end
    end
    if same and detail == prevDetail then
        print(ns.L.BRAND_YELLOW .. " " .. ns.L.NOTE_NO_CHANGE)
        return false
    end
    self:Set(nk, tags, detail, { broadcast = true })
    print(ns.L.BRAND_GREEN .. " " .. ns.L.LFG_BROADCAST_UPDATED)
    return true
end

function ns.LFG:OnReceive(payload, sender)
    sender = Ambiguate(sender or "", "none")
    local nk, tags, detail = self:ParseWirePayload(payload)
    if not nk then return end
    if nk ~= sender then return end
    StoreEntry(nk, tags, detail)
    PushToCache(nk)
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
end

function ns.LFG:SerializeAll()
    if not ns.Sync or not ns.Sync.lfg then return "" end
    local parts = {}
    for nameKey, e in pairs(ns.Sync.lfg) do
        local tags = DedupeSorted(e.tags or {})
        local det = SanitizeDetail(e.detail or "")
        if #tags > 0 or det ~= "" then
            local safeDet = det:gsub("[,=~%+]", " ")
            parts[#parts + 1] = string.format("%s=%s~%s", nameKey, table.concat(tags, "+"), safeDet)
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
            local tagPart, det = body:match("^([^~]*)~(.*)$")
            if tagPart == nil then
                tagPart = body
                det = ""
            end
            local tags = {}
            local seen = {}
            if tagPart ~= "" then
                for piece in tagPart:gmatch("[^+]+") do
                    local code = NormalizeToken(piece)
                    if code and not seen[code] then
                        seen[code] = true
                        tags[#tags + 1] = code
                    end
                end
            end
            table.sort(tags)
            det = SanitizeDetail(det or "")
            if #tags == 0 and det == "" then
                ns.Sync.lfg[nk] = nil
            else
                ns.Sync.lfg[nk] = { tags = tags, detail = det }
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
    end
end

function ns.LFG:Init()
    if not ns.Comms then return end
    ns.Comms:RegisterHandler("LFG_SET", function(p, s) ns.LFG:OnReceive(p, s) end)
    ns.Comms:RegisterHandler("LFG_REQ", function(p, s) ns.LFG:OnReq(p, s) end)
    ns.Comms:RegisterHandler("LFG_FULL", function(p, s) ns.LFG:OnFull(p, s) end)
end
