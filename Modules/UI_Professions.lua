local addonName, ns = ...
ns.UI = ns.UI or {}

local MainFrame = ns.UI.MainFrame
local FilterBar  = ns.UI.FilterBar
local Theme      = ns.Theme

local UI = {
    RECIPE_ROW_H = 18,
    HEADER_ROW_H = 18,
    MEMBER_ROW_GAP = 3,
    MEMBER_PROF_SLOTS = 6,
    MEMBER_PROF_LINE_STEP = 19,
    MEMBER_FIRST_PROF_OFFSET = 26,
    MEMBER_PROF_INNER_H = 18,
    MEMBER_ROW_PAD_BOTTOM = 10,
    MEMBER_ROW_EMPTY_H = 50,
}

local PRO_LINE_SORT_RANK = {
    [171] = 1, [164] = 2, [333] = 3, [202] = 4, [165] = 5, [197] = 6, [755] = 7,
    [182] = 10, [186] = 11, [393] = 12,
    [185] = 20, [356] = 21, [129] = 22,
}

local function SortProfLinesForDisplay(lines)
    if not lines then return nil end
    local t = {}
    for i = 1, #lines do
        local l = lines[i]
        if l and type(l.id) == "number" and l.id > 0 then
            t[#t + 1] = l
        end
    end
    if #t < 2 then return t end
    table.sort(t, function(a, b)
        local ra = PRO_LINE_SORT_RANK[a.id] or 99
        local rb = PRO_LINE_SORT_RANK[b.id] or 99
        if ra ~= rb then return ra < rb end
        return (a.id or 0) < (b.id or 0)
    end)
    return t
end

local function MemberRowHeightForProfCount(profCount)
    if not profCount or profCount <= 0 then
        return UI.MEMBER_ROW_EMPTY_H
    end
    return UI.MEMBER_FIRST_PROF_OFFSET
        + (profCount - 1) * UI.MEMBER_PROF_LINE_STEP
        + UI.MEMBER_PROF_INNER_H
        + UI.MEMBER_ROW_PAD_BOTTOM
end

local PROF_DATA = {
    [171] = { n = "Alquimia",          i = "Interface\\Icons\\Trade_Alchemy" },
    [164] = { n = "Herrería",           i = "Interface\\Icons\\Trade_Blacksmithing" },
    [333] = { n = "Encantamiento",      i = "Interface\\Icons\\Trade_Enchanting" },
    [202] = { n = "Ingeniería",         i = "Interface\\Icons\\Trade_Engineering" },
    [182] = { n = "Herboristería",      i = "Interface\\Icons\\Spell_Nature_NatureTouchGrow" },
    [165] = { n = "Peletería",          i = "Interface\\Icons\\Trade_LeatherWorking" },
    [186] = { n = "Minería",            i = "Interface\\Icons\\Trade_Mining" },
    [393] = { n = "Desuello",           i = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01" },
    [197] = { n = "Sastrería",          i = "Interface\\Icons\\Trade_Tailoring" },
    [755] = { n = "Joyería",            i = "Interface\\Icons\\Trade_Jewelcrafting" },
    [185] = { n = "Cocina",             i = "Interface\\Icons\\INV_Misc_Food_15" },
    [356] = { n = "Pesca",             i = "Interface\\Icons\\Trade_Fishing" },
    [129] = { n = "Primeros Auxilios",  i = "Interface\\Icons\\Spell_Holy_SealOfSacrifice" },
    [0]   = { n = "Otras",             i = "Interface\\Icons\\INV_Misc_Note_06" },
}

-- ─── panel ────────────────────────────────────────────────────────────────────

local ProfPanel = CreateFrame("Frame", "GCM_ProfPanel", MainFrame)
ProfPanel:SetPoint("TOPLEFT",     FilterBar, "BOTTOMLEFT",  0, -4)
ProfPanel:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -8, 8)
ProfPanel:Hide()
ns.UI.ProfPanel = ProfPanel

local title = ProfPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 12, -12)
title:SetTextColor(1, 0.82, 0)

local hint = ProfPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
hint:SetTextColor(0.55, 0.55, 0.60)

local btnReq = CreateFrame("Button", nil, ProfPanel, "UIPanelButtonTemplate")
btnReq:SetSize(120, 24)
btnReq:SetPoint("TOPRIGHT", -12, -12)

-- ─── member pane ─────────────────────────────────────────────────────────────

local memberPane = CreateFrame("Frame", nil, ProfPanel)
memberPane:SetPoint("TOPLEFT",  hint,     "BOTTOMLEFT", 0, -10)
memberPane:SetWidth(256)
memberPane:SetPoint("BOTTOMLEFT", ProfPanel, "BOTTOMLEFT", 6, 10)

local memberScroll = CreateFrame("ScrollFrame", "GCM_ProfMemberScroll", memberPane, "UIPanelScrollFrameTemplate")
memberScroll:SetAllPoints()

local memberContent = CreateFrame("Frame", nil, memberScroll)
memberContent:SetSize(1, 1)
memberScroll:SetScrollChild(memberContent)

local emptyMembers = memberPane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
emptyMembers:SetPoint("CENTER", memberScroll)
emptyMembers:Hide()

-- ─── recipe pane ─────────────────────────────────────────────────────────────

local recipePane = CreateFrame("Frame", nil, ProfPanel)
recipePane:SetPoint("TOPLEFT",     memberPane, "TOPRIGHT",    12,  0)
recipePane:SetPoint("BOTTOMRIGHT", ProfPanel,  "BOTTOMRIGHT", -10, 10)

local spellSearch = CreateFrame("EditBox", nil, recipePane, "InputBoxTemplate")
spellSearch:SetHeight(24)
spellSearch:SetPoint("TOPLEFT",  recipePane, "TOPLEFT",  4,  0)
spellSearch:SetPoint("TOPRIGHT", recipePane, "TOPRIGHT", -4, 0)
spellSearch:SetAutoFocus(false)
spellSearch:SetMaxLetters(40)
spellSearch:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
spellSearch:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

local recipeScroll = CreateFrame("ScrollFrame", "GCM_ProfRecipeScroll", recipePane, "UIPanelScrollFrameTemplate")
recipeScroll:SetPoint("TOPLEFT",     spellSearch, "BOTTOMLEFT",  -4, -6)
recipeScroll:SetPoint("BOTTOMRIGHT", recipePane,  "BOTTOMRIGHT", -24, 0)

local recipeContent = CreateFrame("Frame", nil, recipeScroll)
recipeContent:SetSize(1, 1)
recipeScroll:SetScrollChild(recipeContent)

local emptyRecipes = recipePane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
emptyRecipes:SetPoint("CENTER", recipeScroll)
emptyRecipes:SetTextColor(0.55, 0.55, 0.60)
emptyRecipes:Hide()

-- ─── state ───────────────────────────────────────────────────────────────────

local selectedNameKey  = nil
local spellQuery       = ""
local lastAutoReq      = 0
local collapsedGroups  = {}  -- profId → true when collapsed

-- ─── member rows ─────────────────────────────────────────────────────────────

local memberRows = {}

local function GetMemberRow(i)
    if memberRows[i] then return memberRows[i] end
    local f = CreateFrame("Button", nil, memberContent, "BackdropTemplate")
    f:SetHeight(UI.MEMBER_ROW_EMPTY_H)
    f:SetBackdrop({
        bgFile   = Theme.TEX_WHITE,
        edgeFile = Theme.TEX_BORDER,
        edgeSize = 10,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0.08, 0.08, 0.11, 0.85)
    f:SetBackdropBorderColor(0.28, 0.28, 0.34, 1)

    f.name = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.name:SetPoint("TOPLEFT", 10, -8)

    f.noData = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.noData:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -4)
    f.noData:SetTextColor(0.45, 0.45, 0.50)

    -- Two profession lines stacked vertically, each full-width.
    -- Name on the left, rank right-aligned — no side-by-side clipping.
    f.profItems = {}
    for p = 1, UI.MEMBER_PROF_SLOTS do
        local pi = CreateFrame("Frame", nil, f)
        pi:SetHeight(UI.MEMBER_PROF_INNER_H)
        pi:SetPoint("TOPLEFT",  f, "TOPLEFT",  10, -(UI.MEMBER_FIRST_PROF_OFFSET + (p - 1) * UI.MEMBER_PROF_LINE_STEP))
        pi:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -(UI.MEMBER_FIRST_PROF_OFFSET + (p - 1) * UI.MEMBER_PROF_LINE_STEP))

        pi.icon = pi:CreateTexture(nil, "OVERLAY")
        pi.icon:SetSize(14, 14)
        pi.icon:SetPoint("LEFT", 0, 0)

        pi.txt = pi:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        pi.txt:SetPoint("LEFT", pi.icon, "RIGHT", 4, 0)
        pi.txt:SetTextColor(0.88, 0.88, 0.92)

        pi.val = pi:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        pi.val:SetPoint("RIGHT", pi, "RIGHT", 0, 0)
        pi.val:SetJustifyH("RIGHT")
        pi.val:SetTextColor(0.55, 0.55, 0.60)

        f.profItems[p] = pi
    end

    f:SetScript("OnClick", function(s)
        selectedNameKey = s.nameKey
        ns.UI:RefreshProfessions()
    end)

    memberRows[i] = f
    return f
end

local function HideMemberRowsFrom(n)
    for i = n, #memberRows do
        if memberRows[i] then memberRows[i]:Hide() end
    end
end

-- ─── recipe rows (headers + recipes) ─────────────────────────────────────────

local recipeRows   = {}
local headerRows   = {}

local function GetRecipeRow(i)
    if recipeRows[i] then return recipeRows[i] end
    local f = CreateFrame("Button", nil, recipeContent)
    f:SetHeight(UI.RECIPE_ROW_H)

    f.icon = f:CreateTexture(nil, "OVERLAY")
    f.icon:SetSize(16, 16)
    f.icon:SetPoint("LEFT", 8, 0)

    f.txt = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.txt:SetPoint("LEFT", f.icon, "RIGHT", 6, 0)
    f.txt:SetTextColor(0.88, 0.88, 0.92)

    f:SetScript("OnEnter", function(s)
        if s.spellId then
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(s.spellId)
            GameTooltip:Show()
        end
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    recipeRows[i] = f
    return f
end

local function GetHeaderRow(i)
    if headerRows[i] then return headerRows[i] end
    local f = CreateFrame("Button", nil, recipeContent)
    f:SetHeight(UI.HEADER_ROW_H)

    f.icon = f:CreateTexture(nil, "OVERLAY")
    f.icon:SetSize(14, 14)
    f.icon:SetPoint("LEFT", 4, 0)

    f.txt = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.txt:SetPoint("LEFT", f.icon, "RIGHT", 5, 0)
    f.txt:SetTextColor(1.00, 0.82, 0.00)

    f.count = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.count:SetPoint("LEFT", f.txt, "RIGHT", 4, 0)
    f.count:SetTextColor(0.55, 0.55, 0.60)

    f.toggle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.toggle:SetPoint("RIGHT", f, "RIGHT", -6, 0)
    f.toggle:SetTextColor(0.60, 0.60, 0.65)

    f.line = f:CreateTexture(nil, "ARTWORK")
    f.line:SetHeight(1)
    f.line:SetPoint("LEFT",  f.count, "RIGHT", 8, 0)
    f.line:SetPoint("RIGHT", f,       "RIGHT", -24, 0)
    f.line:SetTexture(Theme.TEX_WHITE)
    f.line:SetVertexColor(unpack(Theme.SEP))

    f:SetScript("OnClick", function(self)
        collapsedGroups[self.profId] = not collapsedGroups[self.profId]
        ns.UI:RefreshProfessions()
    end)
    f:SetScript("OnEnter", function(self)
        self.txt:SetTextColor(1, 0.95, 0.50)
    end)
    f:SetScript("OnLeave", function(self)
        self.txt:SetTextColor(1.00, 0.82, 0.00)
    end)

    headerRows[i] = f
    return f
end

local function HideRowsFrom(pool, n)
    for i = n, #pool do
        if pool[i] then pool[i]:Hide() end
    end
end

-- ─── helpers ─────────────────────────────────────────────────────────────────

local function SafeIcon(icon, profId)
    -- icon can be nil, a path string, or a file-ID integer
    if not icon or icon == 136235 or icon == 134400 or icon == 0 then
        local pd = PROF_DATA[profId or 0]
        return pd and pd.i or "Interface\\Icons\\INV_Misc_Note_06"
    end
    return icon
end

local BAG_PATH = "Interface\\Icons\\INV_Misc_Bag_07"
local function IsBagIcon(icon)
    if not icon then return true end
    if type(icon) == "number" then return icon == 136235 or icon == 134400 end
    return icon == BAG_PATH or icon:find("INV_Misc_Bag_07") ~= nil
end

-- ─── refresh ─────────────────────────────────────────────────────────────────

function ns.UI:RefreshProfessions()
    if not ProfPanel or not ProfPanel:IsShown() then return end

    title:SetText(ns.L.PROF_TITLE or "Profesiones de la Hermandad")
    hint:SetText(ns.L.PROF_HINT  or "Abre tu ventana de profesiones para sincronizar tus recetas.")

    local cnt = ns.Professions and ns.Professions.syncCount or 0
    btnReq:SetText(cnt > 0 and ("Sync (" .. cnt .. ")") or (ns.L.PROF_REQ_SYNC or "Sincronizar"))

    -- Build member list from full cache (show everyone, mark those without data)
    local cache = ns.Cache or {}
    local query = (spellQuery or ""):lower()
    local onlyOnline = ns.UI.Filter and ns.UI.Filter.onlyOnline

    local out = {}
    for name, entry in pairs(cache) do
        local passName = (query == "") or name:lower():find(query, 1, true)
        local passSpell = false
        if not passName and query ~= "" then
            local spells = ns.Professions and ns.Professions.GetSpellsForPlayer
                and ns.Professions:GetSpellsForPlayer(name)
            if spells then
                for id in pairs(spells) do
                    local sName = GetSpellInfo(id)
                    if sName and sName:lower():find(query, 1, true) then
                        passSpell = true
                        break
                    end
                end
            end
        end
        if (passName or passSpell) and (not onlyOnline or entry.online) then
            out[#out + 1] = { name = name, data = entry }
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)

    if #out == 0 then
        emptyMembers:SetText(ns.L.PROF_EMPTY_ROSTER or "Sin datos de hermandad aún.")
        emptyMembers:Show()
        HideMemberRowsFrom(1)
    else
        emptyMembers:Hide()
        local y = 0
        for i, m in ipairs(out) do
            local row = GetMemberRow(i)
            row.nameKey = m.name

            local r, g, b = ns.UI:GetClassColor(m.data.class)
            row.name:SetText(m.name)
            row.name:SetTextColor(r, g, b)

            local lines = m.data.profLines
            local profCount = 0
            if lines and #lines > 0 then
                local ordered = SortProfLinesForDisplay(lines)
                profCount = ordered and #ordered or 0
                if profCount == 0 then
                    for p = 1, UI.MEMBER_PROF_SLOTS do row.profItems[p]:Hide() end
                    row.noData:SetText(ns.L.PROF_NO_PROF_DATA)
                    row.noData:Show()
                else
                    row.noData:Hide()
                    for p = 1, UI.MEMBER_PROF_SLOTS do
                        local pi  = row.profItems[p]
                        local pd  = ordered[p]
                        if pd then
                            local info = PROF_DATA[pd.id]
                            pi.icon:SetTexture(info and info.i or SafeIcon(nil, pd.id))
                            pi.txt:SetText(info and info.n or "Prof")
                            if (pd.c or 0) >= (pd.m or 375) and pd.m and pd.m > 0 then
                                pi.val:SetText("|cffffd100" .. pd.c .. " (Maestro)|r")
                            else
                                pi.val:SetText((pd.c or 0) .. "/" .. (pd.m or "?"))
                            end
                            pi:Show()
                        else
                            pi:Hide()
                        end
                    end
                end
            else
                for p = 1, UI.MEMBER_PROF_SLOTS do row.profItems[p]:Hide() end
                row.noData:SetText(ns.L.PROF_NO_PROF_DATA)
                row.noData:Show()
            end

            local rowH = MemberRowHeightForProfCount(profCount)
            row:SetHeight(rowH)

            row:SetPoint("TOPLEFT", memberContent, "TOPLEFT", 2, y)
            row:SetWidth(memberScroll:GetWidth() - 22)

            local isSel = (m.name == selectedNameKey)
            row:SetBackdropBorderColor(
                isSel and 0.85 or 0.28,
                isSel and 0.70 or 0.28,
                isSel and 0.00 or 0.34,
                1)
            row:Show()
            y = y - (rowH + UI.MEMBER_ROW_GAP)
        end
        HideMemberRowsFrom(#out + 1)
        memberContent:SetHeight(math.max(1, -y))
    end

    if not selectedNameKey and #out > 0 then selectedNameKey = out[1].name end
    if not selectedNameKey then
        HideRowsFrom(recipeRows, 1)
        HideRowsFrom(headerRows, 1)
        return
    end

    -- Build grouped recipe list
    local spells = ns.Professions and ns.Professions.GetSpellsForPlayer
        and ns.Professions:GetSpellsForPlayer(selectedNameKey)
    local storedIcons = ns.Professions and ns.Professions.GetSpellIconsForPlayer
        and ns.Professions:GetSpellIconsForPlayer(selectedNameKey)

    -- grouped[profId] = { { id, name, icon } ... }
    local grouped  = {}
    local profOrder = {}

    if spells then
        for id, profId in pairs(spells) do
            if type(profId) ~= "number" then profId = 0 end  -- normalize legacy boolean format
            local sName, _, sIcon = GetSpellInfo(id)
            if IsBagIcon(sIcon) then sIcon = nil end
            if sName and (query == "" or sName:lower():find(query, 1, true)) then
                if not grouped[profId] then
                    grouped[profId] = {}
                    profOrder[#profOrder + 1] = profId
                end
                grouped[profId][#grouped[profId] + 1] = {
                    id   = id,
                    name = sName,
                    icon = (storedIcons and storedIcons[id])
                        or (not IsBagIcon(sIcon) and sIcon)
                        or SafeIcon(nil, profId),
                }
            end
        end
    end

    -- Heuristic: profId=0 means "unknown profession" (old data format).
    -- If the member has exactly one crafting profession, all their untagged recipes
    -- must belong to it. Gathering professions (Herbalism, Mining, Skinning, Fishing)
    -- produce no crafted recipes so they're excluded from this count.
    if grouped[0] then
        local cacheEntry = ns.Cache and ns.Cache[selectedNameKey]
        local lines = cacheEntry and cacheEntry.profLines
        if (not lines or #lines == 0) and ns.Professions and ns.Professions.GetLinesForPlayer then
            lines = ns.Professions:GetLinesForPlayer(selectedNameKey)
        end
        if lines then
            local CRAFTING = {
                [171]=true, [164]=true, [333]=true, [202]=true,
                [165]=true, [197]=true, [755]=true, [185]=true, [129]=true,
            }
            local crafters = {}
            for _, pl in ipairs(lines) do
                if CRAFTING[pl.id] then crafters[#crafters+1] = pl.id end
            end
            if #crafters == 1 then
                local pid = crafters[1]
                if not grouped[pid] then
                    grouped[pid] = grouped[0]
                    profOrder[#profOrder+1] = pid
                else
                    for _, r in ipairs(grouped[0]) do
                        grouped[pid][#grouped[pid]+1] = r
                    end
                end
                grouped[0] = nil
                for i = #profOrder, 1, -1 do
                    if profOrder[i] == 0 then table.remove(profOrder, i) end
                end
            end
        end
    end

    -- Sort profIds by profession name, putting 0 last
    table.sort(profOrder, function(a, b)
        if a == 0 then return false end
        if b == 0 then return true end
        local na = PROF_DATA[a] and PROF_DATA[a].n or ""
        local nb = PROF_DATA[b] and PROF_DATA[b].n or ""
        return na < nb
    end)
    -- Sort recipes within each group
    for _, pid in ipairs(profOrder) do
        table.sort(grouped[pid], function(a, b) return a.name < b.name end)
    end

    local totalRecipes = 0
    for _, pid in ipairs(profOrder) do totalRecipes = totalRecipes + #grouped[pid] end

    if totalRecipes == 0 then
        local msg = spells
            and (ns.L.PROF_EMPTY_RECIPES or "Sin recetas registradas.")
            or  (ns.L.PROF_NO_SELECTION  or "Selecciona un miembro.")
        emptyRecipes:SetText(msg)
        emptyRecipes:Show()
        HideRowsFrom(recipeRows, 1)
        HideRowsFrom(headerRows, 1)
    else
        emptyRecipes:Hide()
        local y2     = 0
        local rIdx   = 0  -- recipe rows used
        local hIdx   = 0  -- header rows used

        for _, profId in ipairs(profOrder) do
            local group = grouped[profId]
            if #group > 0 then
                local isCollapsed = collapsedGroups[profId]

                -- Header row
                hIdx = hIdx + 1
                local hRow = GetHeaderRow(hIdx)
                local pd   = PROF_DATA[profId]
                hRow.profId = profId
                hRow.icon:SetTexture(pd and pd.i or "Interface\\Icons\\INV_Misc_Note_06")
                hRow.txt:SetText(pd and pd.n or "Otras")
                hRow.count:SetText("(" .. #group .. ")")
                hRow.toggle:SetText(isCollapsed and "[+]" or "[-]")
                hRow:ClearAllPoints()
                hRow:SetPoint("TOPLEFT", recipeContent, "TOPLEFT", 0, y2)
                hRow:SetWidth(recipeScroll:GetWidth() - 20)
                hRow:Show()
                y2 = y2 - UI.HEADER_ROW_H

                -- Recipe rows (hidden when collapsed)
                if not isCollapsed then
                    for _, recipe in ipairs(group) do
                        rIdx = rIdx + 1
                        local rRow = GetRecipeRow(rIdx)
                        rRow:ClearAllPoints()
                        rRow:SetPoint("TOPLEFT", recipeContent, "TOPLEFT", 0, y2)
                        rRow:SetWidth(recipeScroll:GetWidth() - 20)
                        rRow.spellId = recipe.id
                        rRow.txt:SetText(recipe.name)
                        rRow.icon:SetTexture(recipe.icon)
                        rRow:Show()
                        y2 = y2 - UI.RECIPE_ROW_H
                    end
                end
            end
        end

        HideRowsFrom(recipeRows, rIdx + 1)
        HideRowsFrom(headerRows, hIdx + 1)
        recipeContent:SetHeight(math.max(1, -y2))
    end
end

-- ─── events ───────────────────────────────────────────────────────────────────

spellSearch:SetScript("OnTextChanged", function(self)
    spellQuery = (self:GetText() or ""):lower()
    ns.UI:RefreshProfessions()
end)

btnReq:SetScript("OnClick", function()
    if ns.Professions and ns.Professions.RequestSync then
        ns.Professions:RequestSync()
        print(ns.L.BRAND_GREEN .. " " .. ns.L.PROF_SYNC_CHAT)
    end
end)

ProfPanel:SetScript("OnShow", function()
    -- Auto-request once per session on open (max once every 30s)
    local now = time()
    if ns.Professions and ns.Professions.RequestSync and (now - lastAutoReq) > 30 then
        lastAutoReq = now
        ns.Professions:RequestSync()
    end
    if ns.Professions and ns.Professions.RequestLocalTradeSkillSnapshot then
        ns.Professions:RequestLocalTradeSkillSnapshot()
    end
    ns.UI:RefreshProfessions()
end)
