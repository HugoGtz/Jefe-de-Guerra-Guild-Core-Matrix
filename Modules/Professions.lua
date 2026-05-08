local addonName, ns = ...
ns.Professions = ns.Professions or {}

local RECIPE_CAP = 6000
ns.Professions.syncCount = 0
ns.Professions._debug = false

local function DBG(fmt, ...)
    if not ns.Professions._debug then return end
    print("|cffffff00[GCM-PROF]|r " .. string.format(fmt, ...))
end

-- Localized Profession Names for TBC (Spanish/English)
local PROF_NAMES = {
    [171] = { "Alquimia", "Alchemy" },
    [164] = { "Herrería", "Blacksmithing" },
    [333] = { "Encantamiento", "Enchanting" },
    [202] = { "Ingeniería", "Engineering" },
    [182] = { "Herboristería", "Herbalism" },
    [165] = { "Peletería", "Leatherworking" },
    [186] = { "Minería", "Mining" },
    [393] = { "Desuello", "Skinning" },
    [197] = { "Sastrería", "Tailoring" },
    [755] = { "Joyería", "Jewelcrafting" },
    [185] = { "Cocina", "Cooking" },
    [356] = { "Pesca", "Fishing" },
    [129] = { "Primeros Auxilios", "First Aid" },
}

local function NameKey(n)
    if not n or n == "" then return "" end
    local name = Ambiguate(n, "none")
    return name:lower():gsub("^%l", string.upper)
end

function ns.Professions:GetLinesForPlayer(nameKey)
    local e = ns.Sync.professions[NameKey(nameKey)]
    return e and e.lines or nil
end

function ns.Professions:GetSpellsForPlayer(nameKey)
    local e = ns.Sync.professions[NameKey(nameKey)]
    return e and e.spells or nil
end

function ns.Professions:PushToCache(nameKey, targetCache)
    nameKey = NameKey(nameKey)
    local syncData = ns.Sync.professions[nameKey]
    if not syncData then
        DBG("PushToCache(%s): sin datos en Sync.professions", nameKey)
        return
    end

    local lineCount = syncData.lines and #syncData.lines or 0
    local spellCount = 0
    if syncData.spells then for _ in pairs(syncData.spells) do spellCount = spellCount + 1 end end

    local function ApplyTo(cache, label)
        if cache and cache[nameKey] then
            cache[nameKey].profLines = syncData.lines
            cache[nameKey].profSpecs = syncData.specs or {}
            cache[nameKey].profSpellCount = spellCount
            DBG("PushToCache(%s) -> %s: %d profs, %d recetas", nameKey, label, lineCount, spellCount)
        else
            DBG("PushToCache(%s) -> %s: entrada no existe en cache", nameKey, label or "?")
        end
    end

    ApplyTo(ns.Cache, "ns.Cache")
    ApplyTo(targetCache, "targetCache")
    if ns.Scanner and ns.Scanner._tempCache then ApplyTo(ns.Scanner._tempCache, "_tempCache") end
end

function ns.Professions:StorePlayerState(nameKey, lines, spellSet, updatedAt, opts)
    opts = opts or {}
    nameKey = NameKey(nameKey)
    if nameKey == "" then return end

    -- Preserve previously known profession lines if the current scan returned none.
    -- ReadSkillbookPrimaryLines() can return [] at login before skill data is loaded.
    local prev = ns.Sync.professions[nameKey]
    if (not lines or #lines == 0) and prev and prev.lines and #prev.lines > 0 then
        lines = prev.lines
        DBG("StorePlayerState(%s): preservando %d profs anteriores (scan vacío)", nameKey, #lines)
    end

    local lineCount = lines and #lines or 0
    local spellCount = 0
    if spellSet then for _ in pairs(spellSet) do spellCount = spellCount + 1 end end
    DBG("StorePlayerState(%s): %d profs, %d recetas, broadcast=%s", nameKey, lineCount, spellCount, tostring(opts.broadcast))

    ns.Sync.professions[nameKey] = {
        lines = lines,
        spells = spellSet,
        specs = opts.specs or (nameKey == NameKey(UnitName("player")) and self:ScanSpecializations() or {}),
        updatedAt = tonumber(updatedAt) or time(),
    }

    self:PushToCache(nameKey)

    if opts.broadcast and ns.Comms then
        local profStr = ""
        for _, l in ipairs(lines) do profStr = profStr .. string.format("%d:%d/%d+", l.id, l.c, l.m) end
        local sList = {}
        for id, pid in pairs(spellSet) do
            -- Format: "spellId:profId" so the receiver can group by profession
            table.insert(sList, type(pid) == "number" and (id .. ":" .. pid) or tostring(id))
        end
        local body = string.format("%s|%s|%s|%d|%s", nameKey, profStr, table.concat(sList, ","), updatedAt, table.concat(ns.Sync.professions[nameKey].specs, ","))
        DBG("Enviando PROF_SET: %d bytes, profStr='%s', spells=%d", #body, profStr:sub(1,30), #sList)
        ns.Comms:SendChunked("PROF_SET", body, "GUILD")
    end
end

function ns.Professions:OnReceivePayload(payload, sender)
    -- Always log incoming messages (not gated behind _debug)
    print(string.format("|cffffff00[GCM-PROF]|r PROF_SET recibido de '%s' (%d bytes)", tostring(sender), #payload))

    local parts = {}
    for p in (payload .. "|"):gmatch("([^|]*)|") do parts[#parts + 1] = p end

    print(string.format("|cffffff00[GCM-PROF]|r  -> %d partes: [1]='%s' [2]='%s' [3]='%s...' [4]='%s'",
        #parts,
        tostring(parts[1]):sub(1,20),
        tostring(parts[2]):sub(1,20),
        tostring(parts[3]):sub(1,10),
        tostring(parts[4]):sub(1,15)))

    if #parts < 4 then
        print("|cffff4444[GCM-PROF]|r  -> DESCARTADO: menos de 4 partes")
        return
    end

    local nk = NameKey(parts[1])
    local senderKey = NameKey(sender)
    if nk ~= senderKey then
        print(string.format("|cffff4444[GCM-PROF]|r  -> DESCARTADO: nameKey='%s' != sender='%s'", nk, senderKey))
        return
    end

    local lines = {}
    for p in parts[2]:gmatch("([^+]+)") do
        local id, c, m = p:match("^(%d+):(%d+)/(%d+)$")
        if id then table.insert(lines, { id = tonumber(id), c = tonumber(c), m = tonumber(m) }) end
    end

    local spells = {}
    local sCount = 0
    for s in parts[3]:gmatch("([^,]+)") do
        local sid, pid = s:match("^(%d+):(%d+)$")
        if sid then
            spells[tonumber(sid)] = tonumber(pid)
            sCount = sCount + 1
        else
            local id = tonumber(s)
            if id then spells[id] = 0 sCount = sCount + 1 end  -- legacy: profId unknown
        end
    end

    local specs = {}
    if parts[5] and parts[5] ~= "" then
        for s in parts[5]:gmatch("([^,]+)") do table.insert(specs, s) end
    end

    print(string.format("|cff4ade80[GCM-PROF]|r  -> OK: %d profs, %d recetas, %d specs para '%s'",
        #lines, sCount, #specs, nk))

    self:StorePlayerState(nk, lines, spells, parts[4], { specs = specs, broadcast = false })

    self.syncCount = (self.syncCount or 0) + 1
    print(string.format("|cff4ade80GCM:|r Datos de |cffffd100%s|r actualizados (|cffffffff%d|r recetas).", nk, sCount))
    if ns.UI and ns.UI.RefreshProfessions then ns.UI:RefreshProfessions() end
end

function ns.Professions:ReadSkillbookPrimaryLines()
    local out = {}
    if not GetNumSkillLines then
        DBG("ReadSkillbookPrimaryLines: GetNumSkillLines no disponible")
        return out
    end

    local total = GetNumSkillLines()
    DBG("ReadSkillbookPrimaryLines: %d skill lines", total)
    for i = 1, total do
        local name, isHeader, _, rank, _, _, maxRank, _, _, _, _, _, skillLineID = GetSkillLineInfo(i)
        if not isHeader then
            local foundId = nil
            local sid = tonumber(skillLineID)
            if sid and sid > 0 and PROF_NAMES[sid] then
                foundId = sid
            else
                for id, names in pairs(PROF_NAMES) do
                    if name == names[1] or name == names[2] then
                        foundId = id
                        break
                    end
                end
            end
            if foundId then
                table.insert(out, { id = foundId, c = rank or 0, m = maxRank or 0 })
                DBG("  Skill encontrada: id=%d name='%s' rank=%d/%d", foundId, tostring(name), rank or 0, maxRank or 0)
            else
                DBG("  Skill ignorada: name='%s' (no coincide con PROF_NAMES)", tostring(name))
            end
        end
    end
    DBG("ReadSkillbookPrimaryLines: %d profesiones encontradas", #out)
    return out
end

function ns.Professions:ScanSpecializations()
    local specs = {}
    local TBC_SPECS = {
        [28675] = "Potion", [28672] = "Transmute", [28677] = "Elixir",
        [26791] = "Shadoweave", [26797] = "Spellfire", [26798] = "Mooncloth",
    }
    for id, label in pairs(TBC_SPECS) do
        if IsSpellKnown and IsSpellKnown(id) then table.insert(specs, label) end
    end
    return specs
end

function ns.Professions:RequestSync()
    if ns.Comms then ns.Comms:Broadcast("PROF_REQ", "") end
end

function ns.Professions:DumpDebug()
    print("|cffffff00[GCM-PROF DEBUG]|r === Estado actual ===")

    -- Sync.professions
    local syncCount = 0
    for k, v in pairs(ns.Sync.professions or {}) do
        syncCount = syncCount + 1
        local lc = v.lines and #v.lines or 0
        local sc = 0
        if v.spells then for _ in pairs(v.spells) do sc = sc + 1 end end
        print(string.format("  Sync['%s']: %d profs, %d recetas, updatedAt=%s", k, lc, sc, tostring(v.updatedAt)))
    end
    if syncCount == 0 then print("  Sync.professions: VACÍO") end

    -- ns.Cache profLines
    print("|cffffff00[GCM-PROF DEBUG]|r === Cache ===")
    local cacheCount = 0
    for k, v in pairs(ns.Cache or {}) do
        cacheCount = cacheCount + 1
        local lc = v.profLines and #v.profLines or 0
        if lc > 0 then
            print(string.format("  Cache['%s']: %d profs, %d recetas", k, lc, v.profSpellCount or 0))
        end
    end
    print(string.format("  Total en Cache: %d miembros, %d con profs", cacheCount,
        (function() local n=0 for _,v in pairs(ns.Cache or {}) do if v.profLines and #v.profLines>0 then n=n+1 end end return n end)()))
end

function ns.Professions:Init()
    ns.Sync.professions = ns.Sync.professions or {}
    if ns.Comms then
        ns.Comms:RegisterHandler("PROF_SET", function(p, s) self:OnReceivePayload(p, s) end)
        ns.Comms:RegisterHandler("PROF_REQ", function(_, s)
            DBG("PROF_REQ de '%s'", tostring(s))
            local nk = NameKey(UnitName("player") or "")
            if GetNumTradeSkills and GetNumTradeSkills() > 0 then
                -- Profession window is open — scan fresh data and broadcast
                DBG("PROF_REQ: ventana abierta, escaneando")
                self:OnTradeSkillEvent()
            else
                -- No window open — broadcast whatever we have stored
                DBG("PROF_REQ: sin ventana, enviando datos almacenados")
                self:BroadcastStored(nk)
            end
        end)
    end

    local f = CreateFrame("Frame")
    f:RegisterEvent("TRADE_SKILL_SHOW")
    f:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
    f:RegisterEvent("SKILL_LINES_CHANGED")
    f:SetScript("OnEvent", function() self:OnTradeSkillEvent() end)

    -- At login broadcast stored data to guild (window won't be open yet)
    C_Timer.After(5, function()
        local nk = NameKey(UnitName("player") or "")
        self:BroadcastStored(nk)
    end)

    -- Slash commands para debug
    SLASH_GCMPROF1 = "/gcmprof"
    SlashCmdList["GCMPROF"] = function(msg)
        msg = msg and msg:lower():match("^%s*(.-)%s*$") or ""
        if msg == "debug" then
            ns.Professions._debug = not ns.Professions._debug
            print("|cffffff00[GCM-PROF]|r Debug: " .. (ns.Professions._debug and "|cff4ade80ON|r" or "|cffff4444OFF|r"))
        elseif msg == "dump" then
            ns.Professions:DumpDebug()
        elseif msg == "scan" then
            ns.Professions._debug = true
            print("|cffffff00[GCM-PROF]|r Escaneando profesiones locales...")
            ns.Professions:OnTradeSkillEvent()
        elseif msg == "skills" then
            -- Dump raw GetSkillLineInfo output to diagnose name mismatches
            if not GetNumSkillLines then print("GetNumSkillLines no disponible") return end
            local n = GetNumSkillLines()
            print(string.format("|cffffff00[GCM-PROF]|r GetNumSkillLines() = %d", n))
            for i = 1, n do
                local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
                if not isHeader then
                    print(string.format("  [%d] name='%s' rank=%s/%s", i, tostring(name), tostring(rank), tostring(maxRank)))
                end
            end
        elseif msg == "req" then
            print("|cffffff00[GCM-PROF]|r Solicitando sync a hermandad...")
            ns.Professions:RequestSync()
        elseif msg == "tradeskill" then
            -- Dump raw GetTradeSkillInfo output to diagnose what the API actually returns
            if not GetNumTradeSkills then print("GetNumTradeSkills no disponible") return end
            local n = GetNumTradeSkills()
            print(string.format("|cffffff00[GCM-PROF]|r GetNumTradeSkills() = %d", n))
            if GetTradeSkillLine then
                local name, isExp, rank, maxRank = GetTradeSkillLine()
                print(string.format("|cffffff00[GCM-PROF]|r GetTradeSkillLine() = '%s' isExp=%s rank=%s/%s",
                    tostring(name), tostring(isExp), tostring(rank), tostring(maxRank)))
            end
            if TradeSkillFrameTitleText then
                print(string.format("|cffffff00[GCM-PROF]|r TradeSkillFrameTitleText = '%s'",
                    tostring(TradeSkillFrameTitleText:GetText())))
            end
            for i = 1, math.min(n, 15) do
                local name, skillType, numAvail, isExpanded = GetTradeSkillInfo(i)
                print(string.format("  [%d] name='%s' type='%s' avail=%s expanded=%s",
                    i, tostring(name), tostring(skillType), tostring(numAvail), tostring(isExpanded)))
            end
            -- Also dump all spell IDs from current open window
            local sCount = 0
            for i = 1, n do
                local link = GetTradeSkillRecipeLink and GetTradeSkillRecipeLink(i)
                if link then sCount = sCount + 1 end
            end
            print(string.format("|cffffff00[GCM-PROF]|r  Links encontrados: %d/%d", sCount, n))
        else
            print("|cffffff00[GCM-PROF]|r Comandos:")
            print("  /gcmprof debug      - activa/desactiva logs detallados")
            print("  /gcmprof dump       - muestra estado de Sync y Cache")
            print("  /gcmprof scan       - re-escanea tus profesiones locales")
            print("  /gcmprof skills     - vuelca GetSkillLineInfo raw")
            print("  /gcmprof tradeskill - vuelca GetTradeSkillInfo raw (abre una profesion primero)")
            print("  /gcmprof req        - solicita datos a todos en la hermandad")
        end
    end
end

-- Spell IDs for each profession's progression ranks (apprentice → master).
-- Used as last-resort detection when all other APIs fail.
local PROF_SPELLS = {
    [171] = { 2259, 3101, 3464, 11611, 28596 },
    [164] = { 2018, 3100, 3538,  9785, 29844 },
    [333] = { 7411, 7412, 7413, 13920, 28029 },
    [202] = { 4036, 4037, 4038, 12656, 30350 },
    [182] = { 2366, 2368, 3570, 11993, 28695 },
    [165] = { 2108, 2109, 2110, 10662, 32549 },
    [186] = { 2575, 2576, 3564, 10248, 29354 },
    [393] = { 8613, 8617, 8618, 10768, 32678 },
    [197] = { 3908, 3909, 3910, 12180, 26790 },
    [755] = { 25229, 29923 },
    [185] = { 2550, 3102, 3413, 18260, 33359 },
    [356] = { 7620, 7731, 7732, 18249, 34174 },
    [129] = { 3273, 3274, 7923, 10846, 27032 },
}

local function FindProfId(name)
    if not name or name == "" then return nil end
    local lower = name:lower()
    for id, names in pairs(PROF_NAMES) do
        if lower == names[1]:lower() or lower == names[2]:lower() then
            return id
        end
    end
    return nil
end

-- Try every available API to determine which trade skill window is currently open.
-- Returns profId, name, source, rank, maxRank.
local function DetectOpenProfession()
    -- 1. GetTradeSkillLine() — on this server returns (name, rank, maxRank) when window is open,
    --    or 'UNKNOWN' when no window is open.
    if GetTradeSkillLine then
        local name, v2, v3, v4 = GetTradeSkillLine()
        if name and name ~= "" and name ~= "UNKNOWN" then
            local id = FindProfId(name)
            -- Extract rank: some servers return (name, rank, maxRank),
            -- standard TBC returns (name, isExpanded, rank, maxRank).
            local rank, maxRank = 0, 375
            if type(v2) == "number" and v2 > 1 then
                rank = v2
                if type(v3) == "number" and v3 > 0 then maxRank = v3 end
            elseif type(v3) == "number" and v3 > 0 then
                rank = v3
                if type(v4) == "number" and v4 > 0 then maxRank = v4 end
            end
            return id, name, "GetTradeSkillLine", rank, maxRank
        end
    end

    -- 2. GetTradeSkillInfo() — scan first entries for a header row
    if GetTradeSkillInfo and GetNumTradeSkills then
        for i = 1, math.min(GetNumTradeSkills(), 10) do
            local name, skillType = GetTradeSkillInfo(i)
            if skillType == "header" and name and name ~= "" and name ~= "UNKNOWN" then
                local id = FindProfId(name)
                return id, name, "GetTradeSkillInfo(header)", 0, 375
            end
        end
    end

    -- 3. TradeSkillFrame title text (UI string, locale-correct on most servers)
    if TradeSkillFrameTitleText then
        local title = TradeSkillFrameTitleText:GetText()
        if title and title ~= "" and title ~= "UNKNOWN" then
            local clean = title:match("^([^%(]+)") or title
            clean = clean:match("^%s*(.-)%s*$")
            local id = FindProfId(clean)
            return id, clean, "FrameTitle", 0, 375
        end
    end

    return nil, nil, "none", 0, 375
end

-- Infer skill rank/maxRank from known profession spells.
local RANK_BREAKPOINTS = { 75, 150, 225, 300, 375 }
local function InferRankFromSpells(profId)
    local spells = PROF_SPELLS[profId]
    if not spells or not IsSpellKnown then return 0, 375 end
    local rank = 0
    for i = #spells, 1, -1 do
        if IsSpellKnown(spells[i]) then
            rank = RANK_BREAKPOINTS[i] or 375
            break
        end
    end
    return rank, 375
end

function ns.Professions:BroadcastStored(nameKey)
    nameKey = NameKey(nameKey)
    local stored = ns.Sync.professions[nameKey]
    if not stored then
        DBG("BroadcastStored(%s): sin datos almacenados", nameKey)
        return false
    end
    local lines = stored.lines or {}
    local spellSet = stored.spells or {}
    local profStr = ""
    for _, l in ipairs(lines) do profStr = profStr .. string.format("%d:%d/%d+", l.id, l.c, l.m) end
    local sList = {}
    for id, pid in pairs(spellSet) do
        table.insert(sList, type(pid) == "number" and (id .. ":" .. pid) or tostring(id))
    end
    local specStr = table.concat(stored.specs or {}, ",")
    local body = string.format("%s|%s|%s|%d|%s", nameKey, profStr, table.concat(sList, ","), stored.updatedAt or time(), specStr)
    DBG("BroadcastStored(%s): %d profs, %d recetas", nameKey, #lines, #sList)
    ns.Comms:SendChunked("PROF_SET", body, "GUILD")
    return true
end

function ns.Professions:OnTradeSkillEvent()
    local me = UnitName("player")
    if not me then return end

    -- Only run when a trade skill window is actually open
    if not GetNumTradeSkills or GetNumTradeSkills() == 0 then
        DBG("OnTradeSkillEvent: sin ventana abierta, ignorando")
        return
    end

    local profId, detectedName, source, profRank, profMaxRank = DetectOpenProfession()
    DBG("DetectOpenProfession: id=%s name='%s' via=%s rank=%d/%d",
        tostring(profId), tostring(detectedName), tostring(source), profRank, profMaxRank)

    if not profId then
        if source == "none" then
            print("|cffff9900[GCM-PROF]|r No se pudo identificar la profesion abierta.")
            print("|cffff9900[GCM-PROF]|r Ejecuta /gcmprof tradeskill para diagnosticar.")
        end
        return
    end

    -- Use rank from GetTradeSkillLine(); fall back to spell inference if 0
    local rank, maxRank = profRank, profMaxRank
    if rank == 0 then
        rank, maxRank = InferRankFromSpells(profId)
        DBG("OnTradeSkillEvent: rank inferido por spells: %d/%d", rank, maxRank)
    end

    -- Collect recipes from the open window, tagging each with the profession id
    local spellSet = {}
    local n = GetNumTradeSkills()
    for i = 1, n do
        local link = GetTradeSkillRecipeLink(i)
        local sid = link and tonumber(link:match("spell:(%d+)") or link:match("enchant:(%d+)"))
        if sid then spellSet[sid] = profId end
    end

    -- Merge with previously collected recipes (accumulate across all profession windows opened).
    -- Don't overwrite the current profession's freshly scanned recipes.
    local nk = NameKey(me)
    local prev = ns.Sync.professions[nk]
    if prev and prev.spells then
        for id, pid in pairs(prev.spells) do
            if not spellSet[id] then spellSet[id] = pid end
        end
    end

    -- Upsert this profession into the stored lines
    local lines = (prev and prev.lines) and { unpack(prev.lines) } or {}
    local found = false
    for _, l in ipairs(lines) do
        if l.id == profId then l.c = rank; l.m = maxRank; found = true; break end
    end
    if not found then
        table.insert(lines, { id = profId, c = rank, m = maxRank })
    end

    local sc = 0; for _ in pairs(spellSet) do sc = sc + 1 end
    DBG("OnTradeSkillEvent(%s): prof=%s %d/%d, %d recetas total", nk, detectedName, rank, maxRank, sc)
    self:StorePlayerState(nk, lines, spellSet, time(), { broadcast = true })
end
