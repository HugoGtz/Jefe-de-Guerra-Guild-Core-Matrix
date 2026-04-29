local _, ns = ...
ns.Comms = ns.Comms or {}

local PREFIX = "GCM"
local PROTO_VER = 1
local MAX_BODY = 240
local CHUNK_SIZE = 200
local DEFAULT_THROTTLE = 2.0

ns.Comms.lastSent = {}
ns.Comms.handlers = {}
ns.Comms.pendingReceive = {}

local function SendMsg(prefix, body, channel)
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        return C_ChatInfo.SendAddonMessage(prefix, body, channel)
    elseif _G.SendAddonMessage then
        return _G.SendAddonMessage(prefix, body, channel)
    end
end

local function RegisterPrefix(prefix)
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        return C_ChatInfo.RegisterAddonMessagePrefix(prefix)
    elseif _G.RegisterAddonMessagePrefix then
        return _G.RegisterAddonMessagePrefix(prefix)
    end
end

function ns.Comms:RegisterHandler(msgType, fn)
    self.handlers[msgType] = fn
end

local function NewChunkId()
    return string.format("%x", math.random(0, 0xffffff))
end

function ns.Comms:SendChunked(msgType, payload, channel)
    local id = NewChunkId()
    local total = math.max(1, math.ceil(#payload / CHUNK_SIZE))
    for i = 1, total do
        local chunk = payload:sub((i - 1) * CHUNK_SIZE + 1, i * CHUNK_SIZE)
        local body = string.format("%d|CHUNK|%s|%d|%d|%s|%s", PROTO_VER, id, i, total, msgType, chunk)
        SendMsg(PREFIX, body, channel)
    end
    return true
end

function ns.Comms:Send(msgType, payload, channel, throttleKey)
    payload = payload or ""
    channel = channel or "GUILD"
    throttleKey = throttleKey or msgType

    if channel == "GUILD" and not IsInGuild() then return false end

    local now = GetTime()
    local last = self.lastSent[throttleKey] or 0
    if (now - last) < DEFAULT_THROTTLE then return false end
    self.lastSent[throttleKey] = now

    local body = string.format("%d|%s|%s", PROTO_VER, msgType, payload)
    if #body > MAX_BODY then
        return self:SendChunked(msgType, payload, channel)
    end
    SendMsg(PREFIX, body, channel)
    return true
end

function ns.Comms:Broadcast(msgType, payload)
    return self:Send(msgType, payload, "GUILD", msgType)
end

function ns.Comms:Whisper(msgType, payload, target)
    if not target or target == "" then return false end
    return self:Send(msgType, payload, "WHISPER", msgType .. ":" .. target)
end

local function HandleChunk(self, rest, sender, channel)
    local id, idx, total, innerType, chunk = rest:match("^([^|]+)|(%d+)|(%d+)|([^|]+)|(.*)$")
    if not id then return end
    idx = tonumber(idx)
    total = tonumber(total)
    local key = sender .. ":" .. id
    local slot = self.pendingReceive[key] or { parts = {}, total = total, type = innerType }
    slot.parts[idx] = chunk
    self.pendingReceive[key] = slot

    local complete = true
    for i = 1, total do
        if not slot.parts[i] then complete = false break end
    end
    if complete then
        self.pendingReceive[key] = nil
        local full = table.concat(slot.parts)
        local handler = self.handlers[innerType]
        if handler then handler(full, sender, channel) end
    end
end

function ns.Comms:Receive(message, channel, sender)
    sender = Ambiguate(sender or "", "none")
    if sender == UnitName("player") then return end
    local ver, msgType, rest = message:match("^(%d+)|([^|]+)|(.*)$")
    if tonumber(ver) ~= PROTO_VER then return end

    if msgType == "CHUNK" then
        HandleChunk(self, rest, sender, channel)
        return
    end

    local handler = self.handlers[msgType]
    if handler then handler(rest, sender, channel) end
end

function ns.Comms:Init()
    RegisterPrefix(PREFIX)
    if not self.frame then
        self.frame = CreateFrame("Frame")
        self.frame:RegisterEvent("CHAT_MSG_ADDON")
        self.frame:SetScript("OnEvent", function(_, _, prefix, message, channel, sender)
            if prefix == PREFIX then ns.Comms:Receive(message, channel, sender) end
        end)
    end

    self:RegisterHandler("RESCAN", function()
        if ns.Scanner and ns.Scanner.ResetThrottle then ns.Scanner:ResetThrottle() end
        if ns.Scanner and ns.Scanner.ParseGuildNotes then ns.Scanner:ParseGuildNotes() end
    end)
end
