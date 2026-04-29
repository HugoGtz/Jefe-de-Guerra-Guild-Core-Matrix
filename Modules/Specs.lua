local _, ns = ...
ns.Specs = ns.Specs or {}

ns.Specs.CLASS_SPECS = {
    WARRIOR = {
        { id = "arms",  short = "Arms",  full = "Arms",        role = "D" },
        { id = "fury",  short = "Fury",  full = "Fury",        role = "D" },
        { id = "prot",  short = "Prot",  full = "Protection",  role = "T" },
    },
    PALADIN = {
        { id = "holy",  short = "Holy",  full = "Holy",        role = "H" },
        { id = "prot",  short = "Prot",  full = "Protection",  role = "T" },
        { id = "ret",   short = "Ret",   full = "Retribution", role = "D" },
    },
    HUNTER = {
        { id = "bm",    short = "BM",    full = "Beast Mastery", role = "D" },
        { id = "mm",    short = "MM",    full = "Marksmanship",  role = "D" },
        { id = "surv",  short = "Surv",  full = "Survival",      role = "D" },
    },
    ROGUE = {
        { id = "assa",  short = "Assa",  full = "Assassination", role = "D" },
        { id = "comb",  short = "Comb",  full = "Combat",        role = "D" },
        { id = "sub",   short = "Sub",   full = "Subtlety",      role = "D" },
    },
    PRIEST = {
        { id = "disc",  short = "Disc",  full = "Discipline",   role = "H" },
        { id = "holy",  short = "Holy",  full = "Holy",         role = "H" },
        { id = "shad",  short = "Shad",  full = "Shadow",       role = "D" },
    },
    SHAMAN = {
        { id = "ele",   short = "Ele",   full = "Elemental",    role = "D" },
        { id = "enh",   short = "Enh",   full = "Enhancement",  role = "D" },
        { id = "rest",  short = "Rest",  full = "Restoration",  role = "H" },
    },
    MAGE = {
        { id = "arc",   short = "Arc",   full = "Arcane",       role = "D" },
        { id = "fire",  short = "Fire",  full = "Fire",         role = "D" },
        { id = "frost", short = "Frost", full = "Frost",        role = "D" },
    },
    WARLOCK = {
        { id = "aff",   short = "Aff",   full = "Affliction",   role = "D" },
        { id = "demo",  short = "Demo",  full = "Demonology",   role = "D" },
        { id = "dest",  short = "Dest",  full = "Destruction",  role = "D" },
    },
    DRUID = {
        { id = "bal",   short = "Bal",   full = "Balance",        role = "D" },
        { id = "feral", short = "Feral", full = "Feral",          role = "D" },
        { id = "rest",  short = "Rest",  full = "Restoration",    role = "H" },
    },
}

function ns.Specs:GetSpecsForClass(class)
    return self.CLASS_SPECS[class] or {}
end

function ns.Specs:GetSpec(name)
    if not ns.Sync or not ns.Sync.specs then return nil end
    return ns.Sync.specs[name]
end

function ns.Specs:GetSpecMeta(class, specId)
    if not class or not specId then return nil end
    local list = self.CLASS_SPECS[class]
    if not list then return nil end
    for _, s in ipairs(list) do
        if s.id == specId then return s end
    end
    return nil
end

function ns.Specs:FindSpecByShort(class, short)
    local list = self.CLASS_SPECS[class]
    if not list then return nil end
    local lower = short:lower()
    for _, s in ipairs(list) do
        if s.id == lower or s.short:lower() == lower then return s end
    end
    return nil
end

function ns.Specs:Set(name, specId, opts)
    opts = opts or {}
    if not ns.Sync then return false end
    local me = UnitName("player")
    if name and me and Ambiguate(name, "none") ~= Ambiguate(me, "none") then
        if not ns.Notes or not ns.Notes:CanEditUI() then return false end
    end
    ns.Sync.specs = ns.Sync.specs or {}
    if specId then
        ns.Sync.specs[name] = specId
    else
        ns.Sync.specs[name] = nil
    end

    if opts.broadcast and ns.Comms and ns.Comms.Broadcast then
        local payload = string.format("%s|%s", name, specId or "")
        ns.Comms:Broadcast("SPEC_SET", payload)
    end
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
    return true
end

function ns.Specs:SetMine(specInput)
    local me = UnitName("player")
    local _, class = UnitClass("player")
    if not class then return false end
    local meta = self:FindSpecByShort(class, specInput)
    if not meta then return false, self:GetSpecsForClass(class) end
    self:Set(me, meta.id, { broadcast = true })
    return true, meta
end

function ns.Specs:OnReceive(payload, sender)
    local name, specId = payload:match("^([^|]+)|(.*)$")
    if not name then return end
    if specId == "" then specId = nil end
    if not ns.Sync then return end
    ns.Sync.specs = ns.Sync.specs or {}
    ns.Sync.specs[name] = specId
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
end

function ns.Specs:SerializeAll()
    if not ns.Sync or not ns.Sync.specs then return "" end
    local parts = {}
    for name, specId in pairs(ns.Sync.specs) do
        parts[#parts + 1] = name .. "=" .. specId
    end
    return table.concat(parts, ",")
end

function ns.Specs:OnSpecFull(payload, sender)
    if not payload or payload == "" then return end
    if not ns.Sync then return end
    ns.Sync.specs = ns.Sync.specs or {}
    for entry in payload:gmatch("[^,]+") do
        local name, specId = entry:match("^([^=]+)=(.+)$")
        if name and specId and specId ~= "" then
            ns.Sync.specs[name] = specId
        end
    end
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
end

function ns.Specs:OnSpecReq(payload, sender)
    if not ns.Sync or not ns.Sync.specs or not next(ns.Sync.specs) then return end
    local serialized = self:SerializeAll()
    if serialized ~= "" and ns.Comms then
        ns.Comms:Whisper("SPEC_FULL", serialized, sender)
    end
end

function ns.Specs:RequestSync()
    if ns.Comms and ns.Comms.Broadcast then
        ns.Comms:Broadcast("SPEC_REQ", "")
    end
end

function ns.Specs:Init()
    if not ns.Comms then return end
    ns.Comms:RegisterHandler("SPEC_SET", function(p, s) ns.Specs:OnReceive(p, s) end)
    ns.Comms:RegisterHandler("SPEC_REQ", function(p, s) ns.Specs:OnSpecReq(p, s) end)
    ns.Comms:RegisterHandler("SPEC_FULL", function(p, s) ns.Specs:OnSpecFull(p, s) end)
end
