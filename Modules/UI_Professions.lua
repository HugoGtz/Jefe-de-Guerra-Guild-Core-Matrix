local addonName, ns = ...
ns.UI = ns.UI or {}

local MainFrame = ns.UI.MainFrame
local FilterBar = ns.UI.FilterBar

local Theme = ns.Theme

local UI = {
    ROW_H      = 22,
    RECIPE_CAP = 500,
}

local LINE_ABBR = {
    [171] = "Alch",
    [164] = "BS",
    [333] = "Ench",
    [202] = "Eng",
    [182] = "Herb",
    [165] = "LW",
    [186] = "Mine",
    [393] = "Skin",
    [197] = "Tail",
    [755] = "JC",
    [773] = "Ins",
    [184] = "Cook",
    [356] = "Fish",
}

local ProfPanel = CreateFrame("Frame", "GCM_ProfPanel", MainFrame)
ProfPanel:SetPoint("TOPLEFT", FilterBar, "BOTTOMLEFT", 0, -4)
ProfPanel:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -8, 8)
ProfPanel:Hide()
ns.UI.ProfPanel = ProfPanel

local title = ProfPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", 6, -6)
title:SetPoint("TOPRIGHT", -6, -6)
title:SetJustifyH("LEFT")
title:SetTextColor(0.88, 0.88, 0.92, 1)

local hint = ProfPanel:CreateFontString(nil, "OVERLAY", Theme.FONT_SMALL)
hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
hint:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", 0, -4)
hint:SetJustifyH("LEFT")
hint:SetWordWrap(true)
hint:SetTextColor(0.52, 0.52, 0.60, 1)

local btnReq = CreateFrame("Button", nil, ProfPanel, "UIPanelButtonTemplate")
btnReq:SetSize(120, 22)
btnReq:SetPoint("TOPRIGHT", -6, -6)

local memberPane = CreateFrame("Frame", nil, ProfPanel)
memberPane:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -10)
memberPane:SetWidth(248)
memberPane:SetPoint("BOTTOMLEFT", ProfPanel, "BOTTOMLEFT", 4, 8)

local memberTitle = memberPane:CreateFontString(nil, "OVERLAY", Theme.FONT_SMALL)
memberTitle:SetPoint("TOPLEFT", 0, 0)
memberTitle:SetJustifyH("LEFT")
memberTitle:SetTextColor(0.72, 0.72, 0.78, 1)

local memberScroll = CreateFrame("ScrollFrame", "GCM_ProfMemberScroll", memberPane, "UIPanelScrollFrameTemplate")
memberScroll:SetPoint("TOPLEFT", memberTitle, "BOTTOMLEFT", 0, -4)
memberScroll:SetPoint("BOTTOMRIGHT", memberPane, "BOTTOMRIGHT", -22, 0)

local memberContent = CreateFrame("Frame", nil, memberScroll)
memberContent:SetSize(1, 1)
memberScroll:SetScrollChild(memberContent)

local recipePane = CreateFrame("Frame", nil, ProfPanel)
recipePane:SetPoint("TOPLEFT", memberPane, "TOPRIGHT", 10, 0)
recipePane:SetPoint("BOTTOMRIGHT", ProfPanel, "BOTTOMRIGHT", -10, 8)

local recipeHeader = recipePane:CreateFontString(nil, "OVERLAY", Theme.FONT_SMALL)
recipeHeader:SetPoint("TOPLEFT", 0, 0)
recipeHeader:SetJustifyH("LEFT")
recipeHeader:SetTextColor(0.72, 0.72, 0.78, 1)

local spellSearch = CreateFrame("EditBox", nil, recipePane, "InputBoxTemplate")
spellSearch:SetHeight(22)
spellSearch:SetPoint("TOPLEFT", recipeHeader, "BOTTOMLEFT", 0, -6)
spellSearch:SetPoint("TOPRIGHT", recipePane, "TOPRIGHT", 0, -22)
spellSearch:SetAutoFocus(false)
spellSearch:SetMaxLetters(48)

local recipeScroll = CreateFrame("ScrollFrame", "GCM_ProfRecipeScroll", recipePane, "UIPanelScrollFrameTemplate")
recipeScroll:SetPoint("TOPLEFT", spellSearch, "BOTTOMLEFT", -5, -10)
recipeScroll:SetPoint("BOTTOMRIGHT", recipePane, "BOTTOMRIGHT", -22, 0)

local recipeContent = CreateFrame("Frame", nil, recipeScroll)
recipeContent:SetSize(1, 1)
recipeScroll:SetScrollChild(recipeContent)

local emptyMembers = ProfPanel:CreateFontString(nil, "OVERLAY", Theme.FONT_ROW)
emptyMembers:SetPoint("CENTER", memberScroll, "CENTER", 0, 0)
emptyMembers:SetWidth(200)
emptyMembers:SetJustifyH("CENTER")
emptyMembers:SetTextColor(0.55, 0.55, 0.6, 1)
emptyMembers:Hide()

local emptyRecipes = ProfPanel:CreateFontString(nil, "OVERLAY", Theme.FONT_ROW)
emptyRecipes:SetPoint("CENTER", recipeScroll, "CENTER", 0, 0)
emptyRecipes:SetWidth(220)
emptyRecipes:SetJustifyH("CENTER")
emptyRecipes:SetTextColor(0.55, 0.55, 0.6, 1)
emptyRecipes:Hide()

local selectedNameKey = nil
local spellQuery = ""

local function SpellLabel(id)
    if C_Spell and C_Spell.GetSpellInfo then
        local si = C_Spell.GetSpellInfo(id)
        if si and si.name then return si.name end
    end
    if GetSpellInfo then
        local n = GetSpellInfo(id)
        if n then return n end
    end
    return "#" .. tostring(id)
end

local function LinesSummary(lines)
    if not lines or #lines == 0 then return "—" end
    local parts = {}
    for _, e in ipairs(lines) do
        if e and e.id then
            local ab = LINE_ABBR[e.id] or ("#" .. tostring(e.id))
            parts[#parts + 1] = string.format("%s %d/%d", ab, e.c or 0, e.m or 0)
        end
    end
    if #parts == 0 then return "—" end
    return table.concat(parts, ", ")
end

local function MeNameKey()
    local me = UnitName("player")
    if not me then return "" end
    return Ambiguate(me, "none")
end

local memberRows = {}

local function GetMemberRow(i)
    if memberRows[i] then return memberRows[i] end
    local f = CreateFrame("Button", nil, memberContent)
    f:SetHeight(36)
    -- alternating stripe
    f.stripe = f:CreateTexture(nil, "BACKGROUND")
    f.stripe:SetDrawLayer("BACKGROUND", -2)
    f.stripe:SetAllPoints()
    f.stripe:SetTexture(Theme.TEX_WHITE)
    f.stripe:SetVertexColor(unpack(Theme.ROW_STRIPE))
    -- hover/selected bg
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetTexture(Theme.TEX_WHITE)
    f.bg:SetVertexColor(unpack(Theme.ROW_HOVER))
    f.bg:Hide()
    -- online dot
    f.dot = f:CreateTexture(nil, "OVERLAY")
    f.dot:SetTexture(Theme.TEX_WHITE)
    f.dot:SetSize(5, 5)
    f.dot:SetPoint("TOPLEFT", 3, -6)
    f.roleIcon = f:CreateFontString(nil, "OVERLAY", Theme.FONT_ROW)
    f.roleIcon:SetPoint("TOPLEFT", 10, -4)
    f.roleIcon:SetWidth(16)
    f.cls = f:CreateFontString(nil, "OVERLAY", Theme.FONT_ROW)
    f.cls:SetPoint("TOPLEFT", f.roleIcon, "TOPRIGHT", 2, 0)
    f.cls:SetWidth(16)
    f.name = f:CreateFontString(nil, "OVERLAY", Theme.FONT_ROW)
    f.name:SetPoint("TOPLEFT", f.cls, "TOPRIGHT", 4, -2)
    f.name:SetPoint("RIGHT", f, "RIGHT", -4, 0)
    f.name:SetJustifyH("LEFT")
    f.sum = f:CreateFontString(nil, "OVERLAY", Theme.FONT_SMALL)
    f.sum:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -2)
    f.sum:SetPoint("RIGHT", f, "RIGHT", -4, 0)
    f.sum:SetJustifyH("LEFT")
    f.sum:SetTextColor(0.50, 0.52, 0.58, 1)
    f:SetScript("OnEnter", function(s)
        if s.nameKey ~= selectedNameKey and s.nameKey ~= MeNameKey() then
            s.bg:SetVertexColor(unpack(Theme.ROW_HOVER))
            s.bg:Show()
        end
    end)
    f:SetScript("OnLeave", function(s)
        if s.nameKey == selectedNameKey then
            s.bg:SetVertexColor(0.22, 0.45, 0.72, 0.22)
            s.bg:Show()
        elseif s.nameKey == MeNameKey() then
            s.bg:SetVertexColor(0.32, 0.52, 0.26, 0.20)
            s.bg:Show()
        else
            s.bg:Hide()
        end
    end)
    f:SetScript("OnClick", function(s)
        selectedNameKey = s.nameKey
        if ns.UI.RefreshProfessions then ns.UI:RefreshProfessions() end
    end)
    memberRows[i] = f
    return f
end

local function HideMemberRowsFrom(n)
    for i = n, #memberRows do
        if memberRows[i] then memberRows[i]:Hide() end
    end
end

local recipeRows = {}

local function GetRecipeRow(i)
    if recipeRows[i] then return recipeRows[i] end
    local f = CreateFrame("Frame", nil, recipeContent)
    f:SetHeight(UI.ROW_H)
    f.txt = f:CreateFontString(nil, "OVERLAY", Theme.FONT_SMALL)
    f.txt:SetPoint("LEFT", 4, 0)
    f.txt:SetPoint("RIGHT", f, "RIGHT", -4, 0)
    f.txt:SetJustifyH("LEFT")
    recipeRows[i] = f
    return f
end

local function HideRecipeRowsFrom(n)
    for i = n, #recipeRows do
        if recipeRows[i] then recipeRows[i]:Hide() end
    end
end

local function CollectProfMembers()
    local out = {}
    if not ns.Cache then return out end
    for name, entry in pairs(ns.Cache) do
        local m = {
            nameKey = name,
            name = name,
            rosterName = entry.rosterName or name,
            class = entry.class,
            online = entry.online,
            profLines = entry.profLines,
            profSpellCount = entry.profSpellCount or 0,
        }
        if ns.UI.Filter.onlyOnline and not m.online then
        else
            local s = ns.UI.Filter.search
            local pass = not s or s == ""
            if not pass then pass = m.name:lower():find(s, 1, true) end
            if pass then out[#out + 1] = m end
        end
    end
    table.sort(out, function(a, b)
        if a.online ~= b.online then return a.online and not b.online end
        if (a.profSpellCount or 0) ~= (b.profSpellCount or 0) then
            return (a.profSpellCount or 0) > (b.profSpellCount or 0)
        end
        return a.name < b.name
    end)
    return out
end

local function BuildRecipeList(nameKey, q)
    local set = ns.Professions and ns.Professions.GetSpellsForPlayer and ns.Professions:GetSpellsForPlayer(nameKey)
    local list = {}
    if not set then return list end
    q = (q or ""):lower()
    for id in pairs(set) do
        id = tonumber(id)
        if id then
            local label = SpellLabel(id)
            local blob = (label .. " " .. tostring(id)):lower()
            if q == "" or blob:find(q, 1, true) then
                list[#list + 1] = { id = id, label = label }
            end
        end
    end
    table.sort(list, function(a, b)
        if a.label ~= b.label then return a.label < b.label end
        return a.id < b.id
    end)
    while #list > UI.RECIPE_CAP do
        table.remove(list)
    end
    return list
end

function ns.UI:RefreshProfessions()
    if not ProfPanel:IsShown() then return end
    memberTitle:SetText(ns.L.PROF_MEMBERS)
    recipeHeader:SetText(ns.L.PROF_RECIPES_TITLE)
    local members = CollectProfMembers()
    if #members == 0 then
        emptyMembers:SetText(ns.L.PROF_EMPTY_ROSTER)
        emptyMembers:Show()
        memberContent:SetHeight(1)
        memberContent:SetWidth(math.max(1, memberScroll:GetWidth() - 4))
        HideMemberRowsFrom(1)
    else
        emptyMembers:Hide()
        local y = 0
        local meNK = MeNameKey()
        for i, m in ipairs(members) do
            local row = GetMemberRow(i)
            row.nameKey = m.nameKey
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", memberContent, "TOPLEFT", 2, y)
            row:SetWidth(math.max(40, memberScroll:GetWidth() - 12))
            local roleStr = ""
            if ns.Roles then
                local role = ns.Roles:GetEffectiveRole(m.name, m.class)
                if role then roleStr = ns.UI:GetRoleIcon(role) end
            end
            row.roleIcon:SetText(roleStr)
            row.cls:SetText(ns.UI:GetClassIcon(m.class))
            local r, g, b = ns.UI:GetClassColor(m.class)
            if not m.online then
                r, g, b = r * 0.55, g * 0.55, b * 0.55
            end
            row.name:SetText(m.name)
            row.name:SetTextColor(r, g, b)
            row.sum:SetText(LinesSummary(m.profLines) .. "  |cffffffff" .. tostring(m.profSpellCount or 0) .. "|r")
            -- online indicator dot
            if row.dot then
                local dr, dg, db = ns.UI:GetOnlineColor(m.online)
                row.dot:SetVertexColor(dr, dg, db, 1)
            end
            -- zebra stripe
            if row.stripe then
                row.stripe:SetShown(i % 2 == 1 and m.nameKey ~= selectedNameKey and m.nameKey ~= meNK)
            end
            if m.nameKey == selectedNameKey then
                row.bg:SetVertexColor(0.22, 0.45, 0.72, 0.22)
                row.bg:Show()
                if row.stripe then row.stripe:Hide() end
            elseif m.nameKey == meNK then
                row.bg:SetVertexColor(0.32, 0.52, 0.26, 0.20)
                row.bg:Show()
                if row.stripe then row.stripe:Hide() end
            else
                row.bg:Hide()
            end
            row:SetHeight(36)
            row:Show()
            y = y - 38
        end
        HideMemberRowsFrom(#members + 1)
        memberContent:SetHeight(math.max(1, -y))
        memberContent:SetWidth(math.max(1, memberScroll:GetWidth() - 4))
    end

    if not selectedNameKey or not ns.Cache or not ns.Cache[selectedNameKey] then
        selectedNameKey = nil
        if MeNameKey() ~= "" and ns.Cache and ns.Cache[MeNameKey()] then
            selectedNameKey = MeNameKey()
        elseif #members > 0 then
            selectedNameKey = members[1].nameKey
        end
    end

    if not selectedNameKey then
        emptyRecipes:SetText(ns.L.PROF_NO_SELECTION)
        emptyRecipes:Show()
        recipeContent:SetHeight(1)
        recipeContent:SetWidth(math.max(1, recipeScroll:GetWidth() - 4))
        HideRecipeRowsFrom(1)
        return
    end

    local recipes = BuildRecipeList(selectedNameKey, spellQuery)
    if #recipes == 0 then
        emptyRecipes:SetText(ns.L.PROF_EMPTY_RECIPES)
        emptyRecipes:Show()
        HideRecipeRowsFrom(1)
        recipeContent:SetHeight(1)
        recipeContent:SetWidth(math.max(1, recipeScroll:GetWidth() - 4))
    else
        emptyRecipes:Hide()
        local y2 = 0
        for i, r in ipairs(recipes) do
            local row = GetRecipeRow(i)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", recipeContent, "TOPLEFT", 2, y2)
            row:SetWidth(math.max(40, recipeScroll:GetWidth() - 12))
            row.txt:SetText(string.format("[%d] %s", r.id, r.label))
            row.txt:SetTextColor(0.85, 0.86, 0.88, 1)
            row:Show()
            y2 = y2 - UI.ROW_H - 2
        end
        HideRecipeRowsFrom(#recipes + 1)
        recipeContent:SetHeight(math.max(1, -y2))
        recipeContent:SetWidth(math.max(1, recipeScroll:GetWidth() - 4))
    end
end

spellSearch:SetScript("OnTextChanged", function(self)
    spellQuery = (self:GetText() or ""):lower()
    if ns.UI.RefreshProfessions then ns.UI:RefreshProfessions() end
end)
spellSearch:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
spellSearch:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

btnReq:SetScript("OnClick", function()
    if ns.Professions and ns.Professions.RequestSync then ns.Professions:RequestSync() end
end)

ProfPanel:SetScript("OnShow", function()
    if ns.UI.RefreshProfessions then ns.UI:RefreshProfessions() end
end)

ns.Locale:RegisterCallback(function()
    title:SetText(ns.L.PROF_TITLE)
    hint:SetText(ns.L.PROF_HINT)
    btnReq:SetText(ns.L.PROF_REQ_SYNC)
    spellSearch:SetText("")
    spellQuery = ""
    if ProfPanel:IsShown() and ns.UI.RefreshProfessions then ns.UI:RefreshProfessions() end
end)
