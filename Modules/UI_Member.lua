local addonName, ns = ...
ns.UI = ns.UI or {}

local UI = {
    SIZE = { ROW_HEIGHT = 22, DOT = 6 },
    FONT = { ROW = "GameFontHighlight", SUB = "GameFontDisableSmall" },
    COLOR = {
        ROW_HOVER = { 1.0, 1.0, 1.0, 0.06 },
        TEXT_DIM = { 0.65, 0.65, 0.65, 1.0 },
        CONFLICT = { 1.0, 0.3, 0.3, 1.0 },
        LEAD = { 1.0, 0.82, 0.0, 1.0 },
        WHITE_TEX = "Interface\\Buttons\\WHITE8X8",
    },
}

local function ApplyMixin(target, mixin)
    for k, v in pairs(mixin) do target[k] = v end
    return target
end

local dropdown = CreateFrame("Frame", "GCM_MemberDropdown", UIParent, "UIDropDownMenuTemplate")
dropdown:Hide()
if UIDropDownMenu_SetDisplayMode then
    UIDropDownMenu_SetDisplayMode(dropdown, "MENU")
else
    dropdown.displayMode = "MENU"
end

local function GCM_DropdownInit(frame, level, menuList)
    if not menuList then return end
    for index = 1, #menuList do
        local entry = menuList[index]
        if entry.text then
            entry.index = index
            UIDropDownMenu_AddButton(entry, level)
        end
    end
end

local function ShowDropdown(menuList, frame, anchor, x, y)
    if CloseDropDownMenus then CloseDropDownMenus() end
    UIDropDownMenu_Initialize(frame, GCM_DropdownInit, "MENU", nil, menuList)
    ToggleDropDownMenu(1, nil, frame, anchor, x or 0, y or 0, menuList)
end

local function WhisperPlayer(name)
    local edit = ChatEdit_ChooseBoxForSend and ChatEdit_ChooseBoxForSend()
    if edit then
        ChatEdit_ActivateChat(edit)
        edit:SetText("/w " .. name .. " ")
        edit:HighlightText(0, 0)
        edit:SetCursorPosition(string.len(edit:GetText()))
    end
end

StaticPopupDialogs["GCM_COPY_NAME"] = {
    text = "%s",
    button2 = OKAY or "OK",
    hasEditBox = true,
    OnShow = function(self, data)
        self.editBox:SetText(data or "")
        self.editBox:HighlightText()
        self.editBox:SetFocus()
    end,
    EditBoxOnEnterPressed = function(self) self:GetParent():Hide() end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function CopyName(name)
    StaticPopupDialogs["GCM_COPY_NAME"].text = ns.L.COPY_PROMPT
    StaticPopup_Show("GCM_COPY_NAME", nil, nil, name)
end

StaticPopupDialogs["GCM_CUSTOM_CORE"] = {
    text = "%s",
    button1 = ACCEPT or "OK",
    button2 = CANCEL or "Cancel",
    hasEditBox = true,
    maxLetters = 4,
    OnShow = function(self)
        self.editBox:SetNumeric(true)
        self.editBox:SetText("")
        self.editBox:SetFocus()
    end,
    OnAccept = function(self, data)
        local id = tonumber(self.editBox:GetText())
        if id and id >= 1 and data then
            ns.Notes:Assign(data.name, data.typeCode, id)
        else
            print(ns.L.BRAND .. " " .. ns.L.CUSTOM_CORE_INVALID)
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        local id = tonumber(self:GetText())
        local data = parent.data
        if id and id >= 1 and data then
            ns.Notes:Assign(data.name, data.typeCode, id)
        else
            print(ns.L.BRAND .. " " .. ns.L.CUSTOM_CORE_INVALID)
        end
        parent:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function ShowCustomCoreDialog(name, typeCode)
    StaticPopupDialogs["GCM_CUSTOM_CORE"].text = ns.L.CUSTOM_CORE_PROMPT
    StaticPopup_Show("GCM_CUSTOM_CORE", nil, nil, { name = name, typeCode = typeCode })
end

local function BuildAssignSubmenu(name, typeCode)
    local list = {}
    if typeCode == "B" then
        local already = ns.Notes:HasRole(name, typeCode, 1)
        list[#list + 1] = {
            text = string.format("%s%s", ns.L.LABEL_BENCH, already and " |cff666666*|r" or ""),
            notCheckable = true,
            disabled = already,
            func = function() ns.Notes:Assign(name, typeCode, 1) end,
        }
        return list
    end

    local discovered = ns.Scanner:GetDiscoveredCores()
    local existing = {}
    for id in pairs(discovered[typeCode] or {}) do existing[id] = true end

    local ids = {}
    for id in pairs(existing) do ids[#ids + 1] = tonumber(id) or id end
    table.sort(ids)

    for _, id in ipairs(ids) do
        local already = ns.Notes:HasRole(name, typeCode, id)
        local rowText = string.format("Core %d%s", id, already and " |cff666666*|r" or "")
        list[#list + 1] = {
            text = rowText,
            notCheckable = true,
            disabled = already,
            func = function() ns.Notes:Assign(name, typeCode, id) end,
        }
    end

    local nextId = (ids[#ids] or 0) + 1
    list[#list + 1] = {
        text = string.format("|cff4ade80%s Core %d|r", ns.L.MENU_NEW, nextId),
        notCheckable = true,
        func = function() ns.Notes:Assign(name, typeCode, nextId) end,
    }

    list[#list + 1] = {
        text = ns.L.MENU_CUSTOM .. "...",
        notCheckable = true,
        func = function() ShowCustomCoreDialog(name, typeCode) end,
    }

    return list
end

local function BuildRoleSubmenu(name, typeCode, coreId)
    local L = ns.L
    return {
        { text = L.ROLE_TANK, notCheckable = true, func = function() ns.Notes:SetRole(name, typeCode, coreId, "T") end },
        { text = L.ROLE_HEAL, notCheckable = true, func = function() ns.Notes:SetRole(name, typeCode, coreId, "H") end },
        { text = L.ROLE_DPS, notCheckable = true, func = function() ns.Notes:SetRole(name, typeCode, coreId, "D") end },
        { text = L.MENU_NO_ROLE, notCheckable = true, func = function() ns.Notes:SetRole(name, typeCode, coreId, nil) end },
    }
end

local function BuildSpecSubmenu(name, class)
    if not ns.Specs or not class then return {} end
    local list = ns.Specs:GetSpecsForClass(class)
    local out = {}
    for _, s in ipairs(list) do
        out[#out + 1] = {
            text = s.full,
            notCheckable = true,
            func = function() ns.Specs:Set(name, s.id, { broadcast = true }) end,
        }
    end
    out[#out + 1] = {
        text = ns.L.MENU_CLEAR_SPEC,
        notCheckable = true,
        func = function() ns.Specs:Set(name, nil, { broadcast = true }) end,
    }
    return out
end

function ns.UI:ShowMemberMenu(member, anchorFrame, context)
    local L = ns.L
    local name = member.name
    local inviteTarget = member.rosterName or name
    local whisperTarget = inviteTarget
    local selfName = UnitName("player")
    local isSelf = selfName and Ambiguate(name or "", "none") == Ambiguate(selfName, "none")

    local entries = {
        { text = name, isTitle = true, notCheckable = true },
        {
            text = L.MENU_INVITE,
            notCheckable = true,
            func = function()
                if ns.InviteTools and ns.InviteTools.InviteOne then
                    ns.InviteTools:InviteOne(inviteTarget)
                elseif InviteUnit then
                    InviteUnit(inviteTarget)
                end
            end,
        },
        { text = L.MENU_WHISPER, notCheckable = true, func = function() WhisperPlayer(whisperTarget) end },
        { text = L.MENU_COPY, notCheckable = true, func = function() CopyName(name) end },
    }

    if ns.Specs and member.class and (ns.Notes:CanEditUI() or isSelf) then
        entries[#entries + 1] = {
            text = L.MENU_CHANGE_SPEC,
            notCheckable = true,
            hasArrow = true,
            menuList = BuildSpecSubmenu(name, member.class),
        }
    end

    if ns.Notes:CanWrite() then
        if context and context.typeCode and context.coreId then
            entries[#entries + 1] = {
                text = L.MENU_CHANGE_ROLE,
                notCheckable = true,
                hasArrow = true,
                menuList = BuildRoleSubmenu(name, context.typeCode, context.coreId),
            }
            if ns.Notes:IsLead(name, context.typeCode, context.coreId) then
                entries[#entries + 1] = {
                    text = L.MENU_REMOVE_LEAD,
                    notCheckable = true,
                    func = function() ns.Notes:DemoteLead(name, context.typeCode, context.coreId) end,
                }
            else
                entries[#entries + 1] = {
                    text = L.MENU_SET_LEAD,
                    notCheckable = true,
                    func = function() ns.Notes:PromoteLead(name, context.typeCode, context.coreId) end,
                }
            end
            if ns.Notes:IsLootMaster(name, context.typeCode, context.coreId) then
                entries[#entries + 1] = {
                    text = L.MENU_CLEAR_MASTER_LOOTER,
                    notCheckable = true,
                    func = function() ns.Notes:SetLootMasterInNote(name, context.typeCode, context.coreId, false) end,
                }
            else
                entries[#entries + 1] = {
                    text = L.MENU_SET_MASTER_LOOTER,
                    notCheckable = true,
                    func = function() ns.Notes:SetLootMasterInNote(name, context.typeCode, context.coreId, true) end,
                }
            end
            entries[#entries + 1] = {
                text = context.typeCode == "B" and L.MENU_REMOVE_FROM_BENCH or string.format(L.MENU_REMOVE_FROM_CORE, context.coreId),
                notCheckable = true,
                func = function() ns.Notes:Unassign(name, context.typeCode, context.coreId) end,
            }
        end

        entries[#entries + 1] = {
            text = L.MENU_ADD_TO_CORE,
            notCheckable = true,
            hasArrow = true,
            menuList = BuildAssignSubmenu(name, "C"),
        }
        entries[#entries + 1] = {
            text = L.MENU_ADD_TO_BENCH,
            notCheckable = true,
            hasArrow = true,
            menuList = BuildAssignSubmenu(name, "B"),
        }
    end

    entries[#entries + 1] = { text = L.MENU_CANCEL, notCheckable = true, func = function() end }

    ShowDropdown(entries, dropdown, "cursor", 0, 0)
end

local MemberRowMixin = {}

function MemberRowMixin:Build()
    self:SetHeight(UI.SIZE.ROW_HEIGHT)

    self.bg = self:CreateTexture(nil, "BACKGROUND")
    self.bg:SetAllPoints()
    self.bg:SetTexture(UI.COLOR.WHITE_TEX)
    self.bg:SetVertexColor(unpack(UI.COLOR.ROW_HOVER))
    self.bg:Hide()

    self.dot = self:CreateTexture(nil, "OVERLAY")
    self.dot:SetTexture(UI.COLOR.WHITE_TEX)
    self.dot:SetSize(UI.SIZE.DOT, UI.SIZE.DOT)
    self.dot:SetPoint("LEFT", 4, 0)

    self.roleIcon = self:CreateFontString(nil, "OVERLAY", UI.FONT.ROW)
    self.roleIcon:SetPoint("LEFT", self.dot, "RIGHT", 4, 0)
    self.roleIcon:SetWidth(16)

    self.classIcon = self:CreateFontString(nil, "OVERLAY", UI.FONT.ROW)
    self.classIcon:SetPoint("LEFT", self.roleIcon, "RIGHT", 2, 0)
    self.classIcon:SetWidth(16)

    self.conflict = self:CreateFontString(nil, "OVERLAY", UI.FONT.ROW)
    self.conflict:SetPoint("LEFT", self.classIcon, "RIGHT", 2, 0)
    self.conflict:SetTextColor(unpack(UI.COLOR.CONFLICT))
    self.conflict:SetWidth(12)

    self.leadIcon = self:CreateFontString(nil, "OVERLAY", UI.FONT.ROW)
    self.leadIcon:SetPoint("LEFT", self.conflict, "RIGHT", 0, 0)
    self.leadIcon:SetTextColor(unpack(UI.COLOR.LEAD))
    self.leadIcon:SetWidth(16)

    self.addonBadge = self:CreateFontString(nil, "OVERLAY", UI.FONT.ROW)
    self.addonBadge:SetPoint("LEFT", self.leadIcon, "RIGHT", 2, 0)
    self.addonBadge:SetWidth(16)

    self.nameText = self:CreateFontString(nil, "OVERLAY", UI.FONT.ROW)
    self.nameText:SetPoint("LEFT", self.addonBadge, "RIGHT", 2, 0)
    self.nameText:SetPoint("RIGHT", -56, 0)
    self.nameText:SetJustifyH("LEFT")
    self.nameText:SetWordWrap(false)

    self.roleLabel = self:CreateFontString(nil, "OVERLAY", UI.FONT.SUB)
    self.roleLabel:SetPoint("RIGHT", -6, 0)
    self.roleLabel:SetTextColor(unpack(UI.COLOR.TEXT_DIM))

    self:EnableMouse(true)
    self:RegisterForClicks("AnyUp")

    self:SetScript("OnEnter", function(s)
        s.bg:Show()
        s:ShowTooltip()
    end)
    self:SetScript("OnLeave", function(s)
        s.bg:Hide()
        GameTooltip:Hide()
    end)
    self:SetScript("OnClick", function(s, button)
        if button == "RightButton" and s.member then
            ns.UI:ShowMemberMenu(s.member, s, s.context)
        end
    end)
end

function MemberRowMixin:ShowTooltip()
    if not self.member then return end
    local m = self.member
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local r, g, b = ns.UI:GetClassColor(m.class)
    GameTooltip:SetText(m.name, r, g, b)
    if m.level and m.level > 0 then
        GameTooltip:AddLine(string.format(ns.L.LEVEL_CLASS, m.level, m.class or "?"), 1, 1, 1)
    end
    if m.online then
        local zone = (m.zone and m.zone ~= "") and m.zone or "?"
        GameTooltip:AddLine("|cff4ade80" .. ns.L.LAST_SEEN_NOW .. "|r  " .. zone, 0.8, 0.8, 0.8)
    else
        GameTooltip:AddLine("|cff999999" .. ns.UI:FormatLastOnline(m.lastOnline, false) .. "|r", 0.7, 0.7, 0.7)
    end
    if ns.Specs and m.class then
        local specId = ns.Specs:GetSpec(m.name)
        local meta = ns.Specs:GetSpecMeta(m.class, specId)
        if meta then
            GameTooltip:AddLine(string.format("%s: %s", ns.L.SPEC_LABEL, meta.full), 0.85, 0.85, 1.0)
        end
    end
    if m.lead then
        GameTooltip:AddLine(ns.UI:GetRaidLeadIcon() .. " |cffffd100" .. ns.L.LEADER_LABEL .. "|r", 1, 1, 1)
    end
    if ns.Comms and ns.Comms.PeerShowsAddonBadge and ns.Comms:PeerShowsAddonBadge(m.name) then
        local ver = ns.Comms.PeerAddonTooltipVersion and ns.Comms:PeerAddonTooltipVersion(m.name) or "?"
        GameTooltip:AddLine(string.format(ns.L.ADDON_PEER_TOOLTIP, ver or "?"), 0.5, 1.0, 0.5)
    end
    if m.publicNote and m.publicNote ~= "" then
        GameTooltip:AddLine(m.publicNote, 0.7, 0.7, 0.7, true)
    end
    if m.hasConflict then
        GameTooltip:AddLine("|cffff5555" .. string.format(ns.L.CONFLICT_TOOLTIP, m.conflictCount) .. "|r", 1, 0.3, 0.3, true)
    end
    GameTooltip:Show()
end

function MemberRowMixin:SetData(member, context)
    self.member = member
    self.context = context

    local dr, dg, db = ns.UI:GetOnlineColor(member.online)
    self.dot:SetVertexColor(dr, dg, db, 1)

    self.roleIcon:SetText(ns.UI:GetRoleIcon(member.role))
    self.classIcon:SetText(ns.UI:GetClassIcon(member.class))
    self.conflict:SetText(member.hasConflict and "!" or "")
    self.leadIcon:SetText(member.lead and ns.UI:GetRaidLeadIcon() or "")
    local peerAddon = ns.Comms and ns.Comms.PeerShowsAddonBadge and ns.Comms:PeerShowsAddonBadge(member.name)
    self.addonBadge:SetText(peerAddon and ns.UI:GetAddonPeerIcon() or "")

    local r, g, b = ns.UI:GetClassColor(member.class)
    if not member.online then
        r, g, b = r * 0.55, g * 0.55, b * 0.55
    end
    self.nameText:SetText(member.name)
    self.nameText:SetTextColor(r, g, b)

    local roleStr = ""
    if member.role == "T" then roleStr = ns.L.ROLE_TANK
    elseif member.role == "H" then roleStr = ns.L.ROLE_HEAL
    elseif member.role == "D" then roleStr = ns.L.ROLE_DPS end

    local specStr = ""
    if ns.Specs and member.class then
        local specId = ns.Specs:GetSpec(member.name)
        local meta = ns.Specs:GetSpecMeta(member.class, specId)
        if meta then specStr = meta.short end
    end

    if roleStr ~= "" and specStr ~= "" then
        self.roleLabel:SetText(roleStr .. " |cffaaaaaa" .. specStr .. "|r")
    elseif specStr ~= "" then
        self.roleLabel:SetText("|cffaaaaaa" .. specStr .. "|r")
    else
        self.roleLabel:SetText(roleStr)
    end

    self:Show()
end

function ns.UI:NewMemberRow(parent)
    local row = CreateFrame("Button", nil, parent)
    ApplyMixin(row, MemberRowMixin)
    row:Build()
    return row
end
