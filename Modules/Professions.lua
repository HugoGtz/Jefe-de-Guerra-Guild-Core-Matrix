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

function ns.Professions:GetSpellIconsForPlayer(nameKey)
    local e = ns.Sync.professions[NameKey(nameKey)]
    return e and e.icons or nil
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

    if lines then
        local filtered = {}
        for _, l in ipairs(lines) do
            if l and type(l.id) == "number" and l.id > 0 then
                filtered[#filtered + 1] = l
            end
        end
        lines = filtered
    end

    local lineCount = lines and #lines or 0
    local spellCount = 0
    if spellSet then for _ in pairs(spellSet) do spellCount = spellCount + 1 end end
    DBG("StorePlayerState(%s): %d profs, %d recetas, broadcast=%s", nameKey, lineCount, spellCount, tostring(opts.broadcast))

    ns.Sync.professions[nameKey] = {
        lines     = lines,
        spells    = spellSet,
        specs     = opts.specs or (nameKey == NameKey(UnitName("player")) and self:ScanSpecializations() or {}),
        updatedAt = tonumber(updatedAt) or time(),
        icons     = prev and prev.icons,  -- preserve item textures across updates/broadcasts
    }

    self:PushToCache(nameKey)

    if ns.UI and ns.UI.RefreshProfessions then
        ns.UI:RefreshProfessions()
    end

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
    DBG("PROF_SET recibido de '%s' (%d bytes)", tostring(sender), #payload)

    local parts = {}
    for p in (payload .. "|"):gmatch("([^|]*)|") do parts[#parts + 1] = p end

    DBG(" -> %d partes: [1]='%s' [2]='%s' [3]='%s...' [4]='%s'",
        #parts,
        tostring(parts[1]):sub(1, 20),
        tostring(parts[2]):sub(1, 20),
        tostring(parts[3]):sub(1, 10),
        tostring(parts[4]):sub(1, 15))

    if #parts < 4 then
        DBG(" -> DESCARTADO: menos de 4 partes")
        return
    end

    local nk = NameKey(parts[1])
    local senderKey = NameKey(sender)
    if nk ~= senderKey then
        DBG(" -> DESCARTADO: nameKey='%s' != sender='%s'", nk, senderKey)
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

    DBG(" -> OK: %d profs, %d recetas, %d specs para '%s'", #lines, sCount, #specs, nk)

    self:StorePlayerState(nk, lines, spells, parts[4], { specs = specs, broadcast = false })

    self.syncCount = (self.syncCount or 0) + 1
    DBG("Datos de %s actualizados (%d recetas).", nk, sCount)
end

function ns.Professions:ReadSkillbookPrimaryLines()
    local out = {}
    if not GetNumSkillLines then
        DBG("ReadSkillbookPrimaryLines: GetNumSkillLines no disponible")
        return out
    end

    local function ProfIdForSkillLineName(name)
        if not name or name == "" then return nil end
        local lower = name:lower()
        for id, names in pairs(PROF_NAMES) do
            if lower == names[1]:lower() or lower == names[2]:lower() then
                return id
            end
        end
        for id, names in pairs(PROF_NAMES) do
            if lower:find(names[1]:lower(), 1, true) or lower:find(names[2]:lower(), 1, true) then
                return id
            end
        end
        return nil
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
                foundId = ProfIdForSkillLineName(name)
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

function ns.Professions:AugmentLinesFromSkillbook(lines)
    if not lines then return end
    local byId = {}
    for _, l in ipairs(lines) do
        byId[l.id] = l
    end
    for _, pl in ipairs(self:ReadSkillbookPrimaryLines() or {}) do
        local e = byId[pl.id]
        if e then
            e.c = pl.c
            e.m = pl.m
        else
            local nl = { id = pl.id, c = pl.c, m = pl.m }
            table.insert(lines, nl)
            byId[pl.id] = nl
        end
    end
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

local CRAFTING_FOR_SNAPSHOT = {
    [171] = true, [164] = true, [333] = true, [202] = true,
    [165] = true, [197] = true, [755] = true, [185] = true, [129] = true,
}

function ns.Professions:GetTradeSkillSnapshotLineIds()
    local q = {}
    local seen = {}
    local function push(lineId)
        if lineId and type(lineId) == "number" and lineId > 0 and not seen[lineId] then
            seen[lineId] = true
            q[#q + 1] = lineId
        end
    end
    for _, pl in ipairs(self:ReadSkillbookPrimaryLines() or {}) do
        if CRAFTING_FOR_SNAPSHOT[pl.id] then push(pl.id) end
    end
    if #q > 0 then return q end
    if GetProfessions and GetProfessionInfo then
        local pack = { GetProfessions() }
        for _, idx in ipairs(pack) do
            if idx and type(idx) == "number" and idx > 0 then
                local ok, info = pcall(function()
                    return { GetProfessionInfo(idx) }
                end)
                if ok and info and info[1] then
                    local name = info[1]
                    local skillLineID = info[7]
                    if type(name) == "table" then
                        name = name.name or name.professionName
                        skillLineID = name.skillLineID or skillLineID
                    end
                    if type(name) == "string" and name ~= "" then
                        local lower = name:lower()
                        local pid = nil
                        for id, names in pairs(PROF_NAMES) do
                            if CRAFTING_FOR_SNAPSHOT[id] then
                                if lower == names[1]:lower() or lower == names[2]:lower() then
                                    pid = id
                                    break
                                end
                            end
                        end
                        if not pid then
                            for id, names in pairs(PROF_NAMES) do
                                if CRAFTING_FOR_SNAPSHOT[id] then
                                    if lower:find(names[1]:lower(), 1, true) or lower:find(names[2]:lower(), 1, true) then
                                        pid = id
                                        break
                                    end
                                end
                            end
                        end
                        if pid then
                            if skillLineID and type(skillLineID) == "number" and skillLineID > 0 then
                                push(skillLineID)
                            else
                                push(pid)
                            end
                        end
                    end
                end
            end
        end
    end
    if #q > 0 then return q end
    local nk = NameKey(UnitName("player") or "")
    if nk ~= "" then
        local cacheEntry = ns.Cache and ns.Cache[nk]
        if cacheEntry and cacheEntry.profLines then
            for _, pl in ipairs(cacheEntry.profLines) do
                if CRAFTING_FOR_SNAPSHOT[pl.id] then push(pl.id) end
            end
        end
    end
    if #q > 0 then return q end
    local stored = nk ~= "" and ns.Sync.professions and ns.Sync.professions[nk]
    if stored and stored.lines then
        for _, pl in ipairs(stored.lines) do
            if CRAFTING_FOR_SNAPSHOT[pl.id] then push(pl.id) end
        end
    end
    return q
end

function ns.Professions:_RunOpenTradeSkillSnapshotQueue(queue, gen)
    local n = queue and #queue or 0
    if n < 1 then return end
    local userHadFrame = TradeSkillFrame and TradeSkillFrame:IsShown()
    self:OpenCraftingTradeSkillUI(queue[1])
    local step = 1.25
    if n >= 2 and C_Timer and C_Timer.After then
        for i = 2, n do
            (function(idx)
                local tid = queue[idx]
                C_Timer.After((idx - 1) * step, function()
                    if ns.Professions._snapshotGen ~= gen then return end
                    ns.Professions:OpenCraftingTradeSkillUI(tid)
                end)
            end)(i)
        end
    end
    if not C_Timer or not C_Timer.After then return end
    local closeAfter = 2.0 + math.max(0, n - 1) * step
    C_Timer.After(closeAfter, function()
        if ns.Professions._snapshotGen ~= gen then return end
        if userHadFrame then return end
        if C_TradeSkillUI and C_TradeSkillUI.CloseTradeSkill then
            pcall(C_TradeSkillUI.CloseTradeSkill)
        elseif TradeSkillFrame and TradeSkillFrame.Hide then
            pcall(function() TradeSkillFrame:Hide() end)
        end
    end)
end

function ns.Professions:RequestLocalTradeSkillSnapshot(opts)
    opts = opts or {}
    if not UnitName("player") then return end
    if TradeSkillFrame and TradeSkillFrame:IsShown() then
        self:QueueTradeSkillScan()
        return
    end
    local nk = NameKey(UnitName("player") or "")
    local stored = ns.Sync.professions and ns.Sync.professions[nk]
    local sc = 0
    if stored and stored.spells then
        for _ in pairs(stored.spells) do sc = sc + 1 end
    end
    if not opts.force and sc >= 120 and self._tradeSkillSnapshotLastAt
        and (GetTime() - self._tradeSkillSnapshotLastAt) < 45 then
        self:QueueTradeSkillScan()
        return
    end
    self._tradeSkillSnapshotLastAt = GetTime()
    self._snapshotGen = (self._snapshotGen or 0) + 1
    local gen = self._snapshotGen
    local queue = self:GetTradeSkillSnapshotLineIds()
    if #queue > 0 then
        self:_RunOpenTradeSkillSnapshotQueue(queue, gen)
        return
    end
    if not C_Timer or not C_Timer.After then return end
    C_Timer.After(1.5, function()
        if ns.Professions._snapshotGen ~= gen then return end
        local q2 = ns.Professions:GetTradeSkillSnapshotLineIds()
        if #q2 > 0 then
            ns.Professions:_RunOpenTradeSkillSnapshotQueue(q2, gen)
        end
    end)
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

    -- One-time migration: convert old boolean spell values to numeric profId=0
    for _, entry in pairs(ns.Sync.professions) do
        if entry.spells then
            for id, pid in pairs(entry.spells) do
                if type(pid) ~= "number" then entry.spells[id] = 0 end
            end
        end
    end

    if ns.Comms then
        ns.Comms:RegisterHandler("PROF_SET", function(p, s) self:OnReceivePayload(p, s) end)
        ns.Comms:RegisterHandler("PROF_REQ", function(_, s)
            DBG("PROF_REQ de '%s'", tostring(s))
            local nk = NameKey(UnitName("player") or "")
            local nLeg = (GetNumTradeSkills and GetNumTradeSkills()) or 0
            local nMod = 0
            if C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs then
                local rid = C_TradeSkillUI.GetAllRecipeIDs()
                nMod = rid and #rid or 0
            end
            if TradeSkillFrame and TradeSkillFrame:IsShown() and nLeg == 0 and nMod == 0 then
                DBG("PROF_REQ: frame visible, list pending, queue scan + broadcast stored")
                self:QueueTradeSkillScan()
                self:BroadcastStored(nk)
            elseif nLeg > 0 or nMod > 0 then
                DBG("PROF_REQ: list ready, queue scan")
                self:QueueTradeSkillScan()
            else
                DBG("PROF_REQ: sin ventana, enviando datos almacenados")
                self:BroadcastStored(nk)
            end
        end)
    end

    local f = CreateFrame("Frame")
    f:RegisterEvent("TRADE_SKILL_SHOW")
    f:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
    f:RegisterEvent("SKILL_LINES_CHANGED")
    f:SetScript("OnEvent", function(_, event)
        if event == "TRADE_SKILL_SHOW" then
            ns.Professions._tradeSkillStaleEvents = 0
        end
        ns.Professions:QueueTradeSkillScan()
    end)

    -- At login broadcast stored data to guild (window won't be open yet)
    C_Timer.After(5, function()
        local nk = NameKey(UnitName("player") or "")
        if nk == "" then return end
        local prev = ns.Sync.professions[nk]
        local lines = {}
        if prev and prev.lines then
            for _, l in ipairs(prev.lines) do lines[#lines + 1] = { id = l.id, c = l.c, m = l.m } end
        end
        ns.Professions:AugmentLinesFromSkillbook(lines)
        local spells = prev and prev.spells or {}
        local ua = prev and prev.updatedAt or time()
        ns.Professions:StorePlayerState(nk, lines, spells, ua, { broadcast = true })
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
            print("|cffffff00[GCM-PROF]|r Escaneando profesiones locales...")
            ns.Professions:RequestLocalTradeSkillSnapshot({ force = true })
            ns.Professions:QueueTradeSkillScan()
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
            if C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs then
                local rids = C_TradeSkillUI.GetAllRecipeIDs()
                local rc = rids and #rids or 0
                print(string.format("|cffffff00[GCM-PROF]|r C_TradeSkillUI.GetAllRecipeIDs() count = %d", rc))
                if rc > 0 and C_TradeSkillUI.GetRecipeInfo then
                    local sid0 = rids[1]
                    if sid0 then
                        local inf = C_TradeSkillUI.GetRecipeInfo(sid0)
                        if type(inf) == "table" then
                            print(string.format("|cffffff00[GCM-PROF]|r  sample recipeID=%s name='%s' learned=%s icon=%s cat=%s",
                                tostring(inf.recipeID or sid0),
                                tostring(inf.name),
                                tostring(inf.learned),
                                tostring(inf.icon),
                                tostring(inf.categoryID)))
                        end
                    end
                end
            end
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

function ns.Professions:OpenCraftingTradeSkillUI(token)
    if not token or type(token) ~= "number" or token < 1 then return end
    if C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill then
        pcall(function()
            C_TradeSkillUI.OpenTradeSkill(token)
        end)
    end
    if TradeSkillFrame and TradeSkillFrame:IsShown() then return end
    if OpenTradeSkill then
        pcall(OpenTradeSkill, token)
    end
    if TradeSkillFrame and TradeSkillFrame:IsShown() then return end
    local profId = CRAFTING_FOR_SNAPSHOT[token] and token or nil
    if not profId then return end
    local names = PROF_NAMES[profId]
    if names and CastSpellByName then
        for _, nm in ipairs(names) do
            if type(nm) == "string" and nm ~= "" then
                pcall(CastSpellByName, nm)
                if TradeSkillFrame and TradeSkillFrame:IsShown() then return end
            end
        end
    end
    if TradeSkillFrame and TradeSkillFrame:IsShown() then return end
    local spells = PROF_SPELLS[profId]
    if spells and spells[1] then
        local sid = spells[1]
        if C_Spell and C_Spell.CastSpell then
            pcall(C_Spell.CastSpell, sid)
        elseif CastSpellByID then
            pcall(CastSpellByID, sid)
        end
    end
end

local function FindProfId(name)
    if not name or name == "" then return nil end
    local lower = name:lower()
    for id, names in pairs(PROF_NAMES) do
        if lower == names[1]:lower() or lower == names[2]:lower() then
            return id
        end
    end
    -- Substring fallback for server-specific name variations (e.g. "Alquimia (Maestra)")
    for id, names in pairs(PROF_NAMES) do
        if lower:find(names[1]:lower(), 1, true) or lower:find(names[2]:lower(), 1, true) then
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

    if C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillLine then
        local a, b, c, d, e = C_TradeSkillUI.GetTradeSkillLine()
        local lineName, rank, maxRank = nil, 0, 375
        if type(a) == "table" then
            lineName = a.tradeSkillName or a.name or a.tradeSkillDisplayName or a.skillLineDisplayName
            rank = tonumber(a.skillRank or a.skillLineRank or a.rank or 0) or 0
            maxRank = tonumber(a.skillMaxRank or a.skillLineMaxRank or a.maxRank or 375) or 375
        elseif type(a) == "string" and a ~= "" and a ~= "UNKNOWN" then
            lineName = a
            if type(b) == "number" and type(c) == "number" and c > 1 and (d == nil or type(d) == "number") then
                rank, maxRank = b, c
                if type(d) == "number" and d > 0 then maxRank = d end
            elseif type(c) == "number" and type(d) == "number" then
                rank, maxRank = c, d
            elseif type(b) == "number" and type(c) == "number" then
                rank, maxRank = b, c
            end
        elseif type(a) == "number" and a > 0 then
            if C_TradeSkillUI.GetProfessionBySkillLineID then
                local pinfo = C_TradeSkillUI.GetProfessionBySkillLineID(a)
                if type(pinfo) == "table" then
                    lineName = pinfo.professionName or pinfo.name
                end
            end
            if type(b) == "number" then rank = b end
            if type(c) == "number" and c > 0 then maxRank = c end
            if type(d) == "number" and d > 0 then maxRank = d end
        end
        if lineName and lineName ~= "" then
            local id = FindProfId(lineName)
            return id, lineName, "C_TradeSkillUI.GetTradeSkillLine", rank, maxRank
        end
    end

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

local function SpellIdFromRecipeInfo(info, recipeID)
    if not info or type(info) ~= "table" then return nil end
    local sid = info.recipeSpellID or info.spellID or info.craftSpellID
    if type(sid) == "number" and sid > 0 then return sid end
    local h = info.hyperlink or info.recipeLink or info.recipeHyperlink
    if type(h) == "string" then
        sid = tonumber(h:match("spell:(%d+)") or h:match("enchant:(%d+)"))
        if sid and sid > 0 then return sid end
    end
    local TS = C_TradeSkillUI
    if TS and recipeID then
        if TS.GetRecipeItemLink then
            local il = TS.GetRecipeItemLink(recipeID)
            if type(il) == "string" then
                sid = tonumber(il:match("spell:(%d+)") or il:match("enchant:(%d+)"))
                if sid and sid > 0 then return sid end
            end
        end
        if TS.GetTradeSkillRecipeLink then
            local rl = TS.GetTradeSkillRecipeLink(recipeID)
            if type(rl) == "string" then
                sid = tonumber(rl:match("spell:(%d+)") or rl:match("enchant:(%d+)"))
                if sid and sid > 0 then return sid end
            end
        end
    end
    return nil
end

local function IconFromRecipeInfo(info)
    if not info or type(info) ~= "table" then return nil end
    local tex = info.icon
    if tex and tex ~= 0 and tex ~= "" and tex ~= 136235 and tex ~= 134400 then
        return tex
    end
    return nil
end

local function CollectSpellsModern(profId, spellSet, spellIcons)
    local TS = C_TradeSkillUI
    if not TS or not TS.GetAllRecipeIDs or not TS.GetRecipeInfo then return 0 end
    local ids = TS.GetAllRecipeIDs()
    if not ids or #ids == 0 then return 0 end
    local added = 0
    for _, recipeID in ipairs(ids) do
        local info = TS.GetRecipeInfo(recipeID)
        if type(info) ~= "table" then info = nil end
        if info and info.name and info.name ~= "" and info.isDummyRecipe ~= true then
            if info.learned ~= false then
                local sid = SpellIdFromRecipeInfo(info, recipeID)
                if sid and sid > 0 then
                    spellSet[sid] = profId
                    local ic = IconFromRecipeInfo(info)
                    if ic then spellIcons[sid] = ic end
                    added = added + 1
                end
            end
        end
    end
    return added
end

local function CollectSpellsLegacy(profId, spellSet, spellIcons)
    if not GetNumTradeSkills or not GetTradeSkillRecipeLink then return 0 end
    local n = GetNumTradeSkills()
    if n <= 0 then return 0 end
    local added = 0
    for i = 1, n do
        local skillType
        if GetTradeSkillInfo then
            skillType = select(2, GetTradeSkillInfo(i))
        end
        if skillType ~= "header" and skillType ~= "subheader" then
            local link = GetTradeSkillRecipeLink(i)
            local sid = link and tonumber(link:match("spell:(%d+)") or link:match("enchant:(%d+)"))
            if sid then
                spellSet[sid] = profId
                local tex
                local itemLink = GetTradeSkillItemLink and GetTradeSkillItemLink(i)
                if itemLink then
                    local itemId = tonumber(itemLink:match("|Hitem:(%d+):"))
                    if itemId then tex = select(10, GetItemInfo(itemId)) end
                end
                if not tex or tex == "" then
                    tex = GetTradeSkillItemTexture and GetTradeSkillItemTexture(i)
                end
                if tex and tex ~= 0 and tex ~= "" and tex ~= 136235 and tex ~= 134400 then
                    if not spellIcons[sid] then spellIcons[sid] = tex end
                end
                added = added + 1
            end
        end
    end
    return added
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

function ns.Professions:QueueTradeSkillScan()
    local fr = self._tradeSkillDebounceFrame or CreateFrame("Frame")
    self._tradeSkillDebounceFrame = fr
    fr._gcmTradeScanQueued = true
    if fr._gcmDebounceActive then return end
    fr._gcmDebounceActive = true
    fr:SetScript("OnUpdate", function(f)
        f:SetScript("OnUpdate", nil)
        f._gcmDebounceActive = nil
        local run = f._gcmTradeScanQueued
        f._gcmTradeScanQueued = false
        if run then
            ns.Professions:PerformTradeSkillScan()
        end
        if f._gcmTradeScanQueued then
            ns.Professions:QueueTradeSkillScan()
        end
    end)
end

function ns.Professions:PerformTradeSkillScan()
    local me = UnitName("player")
    if not me then return end

    local nLegacy = (GetNumTradeSkills and GetNumTradeSkills()) or 0
    local nModern = 0
    if C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs then
        local t = C_TradeSkillUI.GetAllRecipeIDs()
        nModern = t and #t or 0
    end

    if nLegacy == 0 and nModern == 0 then
        if TradeSkillFrame and TradeSkillFrame:IsShown() then
            self._tradeSkillStaleEvents = (self._tradeSkillStaleEvents or 0) + 1
            if self._tradeSkillStaleEvents == 15 and C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill and C_TradeSkillUI.GetTradeSkillLine then
                local a = C_TradeSkillUI.GetTradeSkillLine()
                local lid
                if type(a) == "number" and a > 0 then
                    lid = a
                elseif type(a) == "table" then
                    lid = a.skillLineID or a.tradeSkillSkillLineID or a.parentSkillLineID
                end
                if type(lid) == "number" and lid > 0 then
                    C_TradeSkillUI.OpenTradeSkill(lid)
                    self._tradeSkillStaleEvents = 0
                end
            end
            if self._tradeSkillStaleEvents > 100 then
                DBG("PerformTradeSkillScan: gave up waiting for recipe list")
                self._tradeSkillStaleEvents = 0
            end
        end
        DBG("PerformTradeSkillScan: no recipes yet legacy=%d modern=%d", nLegacy, nModern)
        return
    end

    self._tradeSkillStaleEvents = 0

    local profId, detectedName, source, profRank, profMaxRank = DetectOpenProfession()
    DBG("DetectOpenProfession: id=%s name='%s' via=%s rank=%d/%d",
        tostring(profId), tostring(detectedName), tostring(source), profRank, profMaxRank)

    if not profId then
        if source == "none" then
            DBG("Could not identify the open profession. Run /gcmprof tradeskill for details.")
            profId = 0
        else
            DBG("Unknown profession name: '%s'. Storing under Other.", tostring(detectedName))
            profId = 0
        end
    end

    local rank, maxRank = profRank, profMaxRank
    if rank == 0 then
        rank, maxRank = InferRankFromSpells(profId)
        DBG("PerformTradeSkillScan: inferred rank from spells: %d/%d", rank, maxRank)
    end

    local spellSet = {}
    local spellIcons = {}
    if nModern > 0 then
        CollectSpellsModern(profId, spellSet, spellIcons)
    end
    if nLegacy > 0 then
        CollectSpellsLegacy(profId, spellSet, spellIcons)
    end

    local nk = NameKey(me)
    local prev = ns.Sync.professions[nk]
    if prev and prev.spells then
        for id, pid in pairs(prev.spells) do
            if not spellSet[id] then
                spellSet[id] = type(pid) == "number" and pid or 0
            end
        end
    end

    local lines = (prev and prev.lines) and { unpack(prev.lines) } or {}
    ns.Professions:AugmentLinesFromSkillbook(lines)
    local found = false
    if profId and profId ~= 0 then
        for _, l in ipairs(lines) do
            if l.id == profId then
                l.c = rank
                l.m = maxRank
                found = true
                break
            end
        end
        if not found then
            table.insert(lines, { id = profId, c = rank, m = maxRank })
        end
    end

    local sc = 0
    for _ in pairs(spellSet) do sc = sc + 1 end
    DBG("PerformTradeSkillScan(%s): prof=%s %d/%d, %d total recipes", nk, tostring(detectedName), rank, maxRank, sc)
    self:StorePlayerState(nk, lines, spellSet, time(), { broadcast = true })

    local stored = ns.Sync.professions[nk]
    if stored and next(spellIcons) then
        stored.icons = stored.icons or {}
        for id, tex in pairs(spellIcons) do stored.icons[id] = tex end
    end
end

function ns.Professions:OnTradeSkillEvent()
    self:QueueTradeSkillScan()
end
