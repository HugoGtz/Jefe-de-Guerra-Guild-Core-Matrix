local addonName, ns = ...
ns.UI = ns.UI or {}

local MainFrame = ns.UI.MainFrame
local FilterBar = ns.UI.FilterBar
local Theme = ns.Theme

local UI = {
    ROW_H      = 46, -- Un poco más alto para que quepa todo bien
    RECIPE_CAP = 500,
}

-- Comprehensive data for TBC Professions
local PROF_DATA = {
    [171] = { n = "Alquimia", i = "Interface\\Icons\\Trade_Alchemy" },
    [164] = { n = "Herrería", i = "Interface\\Icons\\Trade_Blacksmithing" },
    [333] = { n = "Encantamiento", i = "Interface\\Icons\\Trade_Enchanting" },
    [202] = { n = "Ingeniería", i = "Interface\\Icons\\Trade_Engineering" },
    [182] = { n = "Herboristería", i = "Interface\\Icons\\Spell_Nature_NatureTouchGrow" },
    [165] = { n = "Peletería", i = "Interface\\Icons\\Trade_Leatherworking" },
    [186] = { n = "Minería", i = "Interface\\Icons\\Trade_Mining" },
    [393] = { n = "Desuello", i = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01" },
    [197] = { n = "Sastrería", i = "Interface\\Icons\\Trade_Tailoring" },
    [755] = { n = "Joyería", i = "Interface\\Icons\\Trade_Jewelcrafting" },
    [185] = { n = "Cocina", i = "Interface\\Icons\\INV_Misc_Food_15" },
    [356] = { n = "Pesca", i = "Interface\\Icons\\Trade_Fishing" },
    [129] = { n = "Vendas", i = "Interface\\Icons\\Spell_Holy_SealOfSacrifice" },
}

local ProfPanel = CreateFrame("Frame", "GCM_ProfPanel", MainFrame)
ProfPanel:SetPoint("TOPLEFT", FilterBar, "BOTTOMLEFT", 0, -4)
ProfPanel:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -8, 8)
ProfPanel:Hide()
ns.UI.ProfPanel = ProfPanel

local title = ProfPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 12, -12)
title:SetTextColor(1, 0.82, 0)

local hint = ProfPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
hint:SetTextColor(0.6, 0.6, 0.6)

local btnReq = CreateFrame("Button", nil, ProfPanel, "UIPanelButtonTemplate")
btnReq:SetSize(120, 24)
btnReq:SetPoint("TOPRIGHT", -12, -12)

local memberPane = CreateFrame("Frame", nil, ProfPanel)
memberPane:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -12)
memberPane:SetWidth(250)
memberPane:SetPoint("BOTTOMLEFT", ProfPanel, "BOTTOMLEFT", 6, 12)

local memberScroll = CreateFrame("ScrollFrame", "GCM_ProfMemberScroll", memberPane, "UIPanelScrollFrameTemplate")
memberScroll:SetAllPoints()

local memberContent = CreateFrame("Frame", nil, memberScroll)
memberContent:SetSize(1, 1)
memberScroll:SetScrollChild(memberContent)

local recipePane = CreateFrame("Frame", nil, ProfPanel)
recipePane:SetPoint("TOPLEFT", memberPane, "TOPRIGHT", 14, 0)
recipePane:SetPoint("BOTTOMRIGHT", ProfPanel, "BOTTOMRIGHT", -12, 12)

local spellSearch = CreateFrame("EditBox", nil, recipePane, "InputBoxTemplate")
spellSearch:SetHeight(26)
spellSearch:SetPoint("TOPLEFT", 5, 0)
spellSearch:SetPoint("TOPRIGHT", -5, 0)
spellSearch:SetAutoFocus(false)

local recipeScroll = CreateFrame("ScrollFrame", "GCM_ProfRecipeScroll", recipePane, "UIPanelScrollFrameTemplate")
recipeScroll:SetPoint("TOPLEFT", spellSearch, "BOTTOMLEFT", -5, -12)
recipeScroll:SetPoint("BOTTOMRIGHT", recipePane, "BOTTOMRIGHT", -24, 0)

local recipeContent = CreateFrame("Frame", nil, recipeScroll)
recipeContent:SetSize(1, 1)
recipeScroll:SetScrollChild(recipeContent)

local emptyMembers = ProfPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
emptyMembers:SetPoint("CENTER", memberScroll)
emptyMembers:Hide()

local emptyRecipes = ProfPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
emptyRecipes:SetPoint("CENTER", recipeScroll)
emptyRecipes:Hide()

local selectedNameKey = nil
local spellQuery = ""

local function MeNameKey()
    local me = UnitName("player")
    return me and Ambiguate(me, "none") or ""
end

local memberRows = {}

local function GetMemberRow(i)
    if memberRows[i] then return memberRows[i] end
    
    local f = CreateFrame("Button", nil, memberContent, "BackdropTemplate")
    f:SetHeight(UI.ROW_H)
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0.08, 0.08, 0.1, 0.8)
    f:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    f.name = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.name:SetPoint("TOPLEFT", 12, -8)

    f.spec = f:CreateFontString(nil, "OVERLAY", "GameFontGreenSmall")
    f.spec:SetPoint("LEFT", f.name, "RIGHT", 6, 0)

    f.profItems = {}
    for p = 1, 2 do
        local pi = CreateFrame("Frame", nil, f)
        pi:SetSize(110, 24)
        if p == 1 then pi:SetPoint("TOPLEFT", 12, -22) else pi:SetPoint("TOPLEFT", 125, -22) end
        
        pi.icon = pi:CreateTexture(nil, "OVERLAY")
        pi.icon:SetSize(16, 16)
        pi.icon:SetPoint("LEFT", 0, 0)
        
        pi.txt = pi:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        pi.txt:SetPoint("LEFT", pi.icon, "RIGHT", 4, 0)
        pi.txt:SetTextColor(0.9, 0.9, 0.9)

        pi.val = pi:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        pi.val:SetPoint("TOPLEFT", pi.txt, "BOTTOMLEFT", 0, -1)
        pi.val:SetTextColor(0.6, 0.6, 0.6)

        f.profItems[p] = pi
    end

    f.noData = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.noData:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -4)
    f.noData:SetText("Sin datos")

    f:SetScript("OnClick", function(s)
        selectedNameKey = s.nameKey
        ns.UI:RefreshProfessions()
    end)

    memberRows[i] = f
    return f
end

local function HideMemberRowsFrom(n)
    for i = n, #memberRows do if memberRows[i] then memberRows[i]:Hide() end end
end

local recipeRows = {}
local function GetRecipeRow(i)
    if recipeRows[i] then return recipeRows[i] end
    local f = CreateFrame("Button", nil, recipeContent)
    f:SetHeight(22)
    f.icon = f:CreateTexture(nil, "OVERLAY")
    f.icon:SetSize(18, 18)
    f.icon:SetPoint("LEFT", 5, 0)
    f.txt = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.txt:SetPoint("LEFT", f.icon, "RIGHT", 6, 0)
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

local function HideRecipeRowsFrom(n)
    for i = n, #recipeRows do if recipeRows[i] then recipeRows[i]:Hide() end end
end

function ns.UI:RefreshProfessions()
    if not ProfPanel or not ProfPanel:IsShown() then return end
    
    title:SetText("Profesiones de la Hermandad")
    hint:SetText("Abre tu ventana de profesiones para sincronizar tus recetas.")
    btnReq:SetText(ns.Professions.syncCount > 0 and "Sync ("..ns.Professions.syncCount..")" or "Sincronizar")

    -- Access cache correctly
    local cache = ns.Cache or {}
    local out = {}
    local query = (spellQuery or ""):lower()
    local onlyOnline = ns.UI.Filter and ns.UI.Filter.onlyOnline

    for name, entry in pairs(cache) do
        local pass = (query == "")
        if not pass then
            if name:lower():find(query) then pass = true
            else
                local spells = ns.Professions:GetSpellsForPlayer(name)
                if spells then
                    for id in pairs(spells) do
                        local sName = GetSpellInfo(id)
                        if sName and sName:lower():find(query) then pass = true break end
                    end
                end
            end
        end
        if pass and (not onlyOnline or entry.online) then
            table.insert(out, { name = name, data = entry })
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)

    if #out == 0 then
        emptyMembers:SetText("No se encontraron miembros")
        emptyMembers:Show()
        HideMemberRowsFrom(1)
    else
        emptyMembers:Hide()
        local y = 0
        for i, m in ipairs(out) do
            local row = GetMemberRow(i)
            row.nameKey = m.name
            row:SetPoint("TOPLEFT", memberContent, 2, y)
            row:SetWidth(memberScroll:GetWidth() - 20)
            
            local r, g, b = ns.UI:GetClassColor(m.data.class)
            row.name:SetText(m.name)
            row.name:SetTextColor(r, g, b)

            if m.data.profSpecs and #m.data.profSpecs > 0 then
                row.spec:SetText("[" .. table.concat(m.data.profSpecs, "/") .. "]")
                row.spec:Show()
            else
                row.spec:Hide()
            end

            if m.data.profLines and #m.data.profLines > 0 then
                row.noData:Hide()
                for p = 1, 2 do
                    local pi = row.profItems[p]
                    local pData = m.data.profLines[p]
                    if pData then
                        local info = PROF_DATA[pData.id]
                        pi.icon:SetTexture(info and info.i or "Interface\\Icons\\INV_Misc_Bag_07")
                        pi.txt:SetText(info and info.n or "Profesión")
                        if (pData.c or 0) >= (pData.m or 375) then
                            pi.val:SetText("|cffffd100" .. pData.c .. " (Maestro)|r")
                        else
                            pi.val:SetText(pData.c .. "/" .. pData.m)
                        end
                        pi:Show()
                    else
                        pi:Hide()
                    end
                end
            else
                for p = 1, 2 do row.profItems[p]:Hide() end
                row.noData:Show()
            end

            local isSel = (m.name == selectedNameKey)
            row:SetBackdropBorderColor(isSel and 1 or 0.3, isSel and 0.8 or 0.3, 0)
            row:Show()
            y = y - (UI.ROW_H + 2)
        end
        HideMemberRowsFrom(#out + 1)
        memberContent:SetHeight(-y)
    end

    if not selectedNameKey and #out > 0 then selectedNameKey = out[1].name end
    if not selectedNameKey then HideRecipeRowsFrom(1) return end

    local recipes = {}
    local set = ns.Professions:GetSpellsForPlayer(selectedNameKey)
    if set then
        for id in pairs(set) do
            local sName, _, sIcon = GetSpellInfo(id)
            if sName and (query == "" or sName:lower():find(query)) then
                table.insert(recipes, { id = id, name = sName, icon = sIcon })
            end
        end
    end
    table.sort(recipes, function(a, b) return a.name < b.name end)

    if #recipes == 0 then
        emptyRecipes:SetText("Sin recetas")
        emptyRecipes:Show()
        HideRecipeRowsFrom(1)
    else
        emptyRecipes:Hide()
        local y2 = 0
        for i, r in ipairs(recipes) do
            local rRow = GetRecipeRow(i)
            rRow:SetPoint("TOPLEFT", recipeContent, 2, y2)
            rRow:SetWidth(recipeScroll:GetWidth() - 20)
            rRow.spellId = r.id
            rRow.txt:SetText(r.name)
            local icon = r.icon
            if not icon or icon == 136235 or icon == 134400 then icon = "Interface\\Icons\\INV_Misc_Bag_07" end
            rRow.icon:SetTexture(icon)
            rRow:Show()
            y2 = y2 - 22
        end
        HideRecipeRowsFrom(#recipes + 1)
        recipeContent:SetHeight(-y2)
    end
end

spellSearch:SetScript("OnTextChanged", function(self)
    spellQuery = (self:GetText() or ""):lower()
    ns.UI:RefreshProfessions()
end)

btnReq:SetScript("OnClick", function()
    if ns.Professions and ns.Professions.RequestSync then 
        ns.Professions:RequestSync() 
        print("|cff4ade80GCM:|r Solicitando datos a la hermandad...")
    end
end)

ProfPanel:SetScript("OnShow", function() 
    ns.UI:RefreshProfessions()
end)
