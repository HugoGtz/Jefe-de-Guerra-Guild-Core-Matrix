local _, ns = ...
ns.UI = ns.UI or {}

local MAX_SLOTS = 5

local DAY_KEYS = { "DAY_SUN", "DAY_MON", "DAY_TUE", "DAY_WED", "DAY_THU", "DAY_FRI", "DAY_SAT" }

local function DayShort(day)
    return ns.L[DAY_KEYS[day]] or tostring(day)
end

local function FormatTimeShort(hour, minute)
    return string.format("%02d:%02d", hour, minute)
end

function ns.UI:FormatNextSlot(slot)
    if not slot then return ns.L.SCHED_NONE end
    local base = string.format("%s %s", DayShort(slot.day), FormatTimeShort(slot.hour, slot.minute))
    if slot.notes and slot.notes ~= "" then
        return base .. " — " .. slot.notes
    end
    return base
end

function ns.UI:GetSignupButtonLabel(state)
    if state == "yes" then return "|cff4ade80✓|r " .. ns.L.SIGNUP_YES end
    if state == "maybe" then return "|cffffd100?|r " .. ns.L.SIGNUP_MAYBE end
    if state == "no" then return "|cffff5555✗|r " .. ns.L.SIGNUP_NO end
    return ns.L.SIGNUP_PROMPT
end

local SignupDropdown

function ns.UI:ShowSignupMenu(coreKey, slotIdx, anchorBtn)
    if not SignupDropdown then
        SignupDropdown = CreateFrame("Frame", "GCM_SignupDropdown", UIParent, "UIDropDownMenuTemplate")
        SignupDropdown:Hide()
        if UIDropDownMenu_SetDisplayMode then
            UIDropDownMenu_SetDisplayMode(SignupDropdown, "MENU")
        else
            SignupDropdown.displayMode = "MENU"
        end
    end

    local L = ns.L
    local entries = {
        { text = L.SIGNUP_TITLE, isTitle = true, notCheckable = true },
        { text = "|cff4ade80✓|r " .. L.SIGNUP_YES, notCheckable = true,
          func = function() ns.Signups:Set(coreKey, slotIdx, "yes") end },
        { text = "|cffffd100?|r " .. L.SIGNUP_MAYBE, notCheckable = true,
          func = function() ns.Signups:Set(coreKey, slotIdx, "maybe") end },
        { text = "|cffff5555✗|r " .. L.SIGNUP_NO, notCheckable = true,
          func = function() ns.Signups:Set(coreKey, slotIdx, "no") end },
        { text = L.SIGNUP_CLEAR, notCheckable = true,
          func = function() ns.Signups:Set(coreKey, slotIdx, nil) end },
        { text = L.MENU_CANCEL, notCheckable = true, func = function() end },
    }

    if CloseDropDownMenus then CloseDropDownMenus() end
    UIDropDownMenu_Initialize(SignupDropdown, function(_, level, list)
        list = list or entries
        for i, entry in ipairs(list) do
            entry.index = i
            UIDropDownMenu_AddButton(entry, level)
        end
    end, "MENU", nil, entries)
    ToggleDropDownMenu(1, nil, SignupDropdown, anchorBtn or "cursor", 0, 0, entries)
end

local Editor

local function CreateEditor()
    local f = CreateFrame("Frame", "GCM_ScheduleEditor", UIParent, "BackdropTemplate")
    f:SetSize(420, 380)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:Hide()

    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    f.title:SetPoint("TOP", 0, -16)
    f.title:SetText("")

    f.subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.subtitle:SetPoint("TOP", f.title, "BOTTOM", 0, -2)

    f.slotsContainer = CreateFrame("Frame", nil, f)
    f.slotsContainer:SetPoint("TOPLEFT", 18, -64)
    f.slotsContainer:SetPoint("TOPRIGHT", -18, -64)
    f.slotsContainer:SetHeight(220)

    f.slots = {}

    local function BuildSlotRow(idx)
        local row = CreateFrame("Frame", nil, f.slotsContainer)
        row:SetHeight(28)
        if idx == 1 then
            row:SetPoint("TOPLEFT", 0, 0)
            row:SetPoint("TOPRIGHT", 0, 0)
        else
            row:SetPoint("TOPLEFT", f.slots[idx - 1], "BOTTOMLEFT", 0, -6)
            row:SetPoint("TOPRIGHT", f.slots[idx - 1], "BOTTOMRIGHT", 0, -6)
        end

        row.dayBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.dayBtn:SetSize(48, 22)
        row.dayBtn:SetPoint("LEFT", 0, 0)
        row.dayBtn.day = 1
        row.dayBtn:SetScript("OnClick", function(s)
            s.day = (s.day % 7) + 1
            s:SetText(DayShort(s.day))
        end)

        row.hourBox = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        row.hourBox:SetSize(28, 22)
        row.hourBox:SetPoint("LEFT", row.dayBtn, "RIGHT", 16, 0)
        row.hourBox:SetAutoFocus(false)
        row.hourBox:SetNumeric(true)
        row.hourBox:SetMaxLetters(2)

        row.colon = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.colon:SetPoint("LEFT", row.hourBox, "RIGHT", 1, 0)
        row.colon:SetText(":")

        row.minBox = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        row.minBox:SetSize(28, 22)
        row.minBox:SetPoint("LEFT", row.colon, "RIGHT", 2, 0)
        row.minBox:SetAutoFocus(false)
        row.minBox:SetNumeric(true)
        row.minBox:SetMaxLetters(2)

        row.notesBox = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        row.notesBox:SetPoint("LEFT", row.minBox, "RIGHT", 14, 0)
        row.notesBox:SetPoint("RIGHT", row, "RIGHT", -32, 0)
        row.notesBox:SetHeight(22)
        row.notesBox:SetAutoFocus(false)
        row.notesBox:SetMaxLetters(60)

        row.removeBtn = CreateFrame("Button", nil, row, "UIPanelCloseButton")
        row.removeBtn:SetSize(22, 22)
        row.removeBtn:SetPoint("RIGHT", 6, 0)
        row.removeBtn:SetScript("OnClick", function() Editor:RemoveSlot(idx) end)

        return row
    end

    f.GetSlotRow = function(self, idx)
        if not self.slots[idx] then
            self.slots[idx] = BuildSlotRow(idx)
        end
        return self.slots[idx]
    end

    f.addBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.addBtn:SetSize(140, 22)
    f.addBtn:SetPoint("BOTTOMLEFT", 18, 56)
    f.addBtn:SetScript("OnClick", function() Editor:AddSlot() end)

    f.saveBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.saveBtn:SetSize(110, 24)
    f.saveBtn:SetPoint("BOTTOMRIGHT", -18, 18)
    f.saveBtn:SetScript("OnClick", function() Editor:Save() end)

    f.cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.cancelBtn:SetSize(110, 24)
    f.cancelBtn:SetPoint("RIGHT", f.saveBtn, "LEFT", -8, 0)
    f.cancelBtn:SetScript("OnClick", function() f:Hide() end)

    return f
end

local function HideAllSlotRows()
    for _, row in ipairs(Editor.slots) do row:Hide() end
end

local function ApplySlotToRow(row, slot)
    row.dayBtn.day = slot.day
    row.dayBtn:SetText(DayShort(slot.day))
    row.hourBox:SetText(tostring(slot.hour))
    row.minBox:SetText(string.format("%02d", slot.minute))
    row.notesBox:SetText(slot.notes or "")
    row.hourBox:ClearFocus()
    row.minBox:ClearFocus()
    row.notesBox:ClearFocus()
    row:Show()
end

local function ReadSlotFromRow(row)
    return {
        day = row.dayBtn.day,
        hour = tonumber(row.hourBox:GetText()) or 0,
        minute = tonumber(row.minBox:GetText()) or 0,
        notes = row.notesBox:GetText() or "",
    }
end

local function CommitVisibleEdits(editor)
    for i, row in ipairs(editor.slots) do
        if row:IsShown() and editor.workingSlots[i] then
            editor.workingSlots[i] = ReadSlotFromRow(row)
        end
    end
end

local function Render(editor)
    HideAllSlotRows()
    for i, slot in ipairs(editor.workingSlots) do
        local row = editor:GetSlotRow(i)
        ApplySlotToRow(row, slot)
    end
    editor.addBtn:SetEnabled(#editor.workingSlots < MAX_SLOTS)
end

local function InstallMethods(editor)
    function editor:Render() Render(self) end
    function editor:CommitVisibleEdits() CommitVisibleEdits(self) end
    function editor:AddSlot()
        if #self.workingSlots >= MAX_SLOTS then return end
        CommitVisibleEdits(self)
        self.workingSlots[#self.workingSlots + 1] = { day = 1, hour = 21, minute = 0, notes = "" }
        Render(self)
    end
    function editor:RemoveSlot(idx)
        CommitVisibleEdits(self)
        table.remove(self.workingSlots, idx)
        Render(self)
    end
    function editor:Save()
        if not ns.Notes or not ns.Notes:CanEditUI() then return end
        CommitVisibleEdits(self)
        ns.Schedule:SetSlots(self.coreKey, self.workingSlots, { broadcast = true })
        self:Hide()
    end
end

function ns.UI:OpenScheduleEditor(typeCode, coreId)
    if not ns.Notes or not ns.Notes:CanEditUI() then return end
    if not Editor then
        Editor = CreateEditor()
        InstallMethods(Editor)
    end
    Editor.coreKey = ns.Schedule:CoreKey(typeCode, coreId)
    Editor.typeCode = typeCode
    Editor.coreId = coreId

    Editor.title:SetText(string.format(ns.L.SCHED_EDIT_TITLE, coreId))
    Editor.subtitle:SetText(ns.L.SCHED_EDIT_HINT)
    Editor.addBtn:SetText("+ " .. ns.L.SCHED_ADD_SLOT)
    Editor.saveBtn:SetText(ns.L.BTN_SAVE)
    Editor.cancelBtn:SetText(ns.L.BTN_CANCEL)

    HideAllSlotRows()
    Editor.workingSlots = {}
    for _, s in ipairs(ns.Schedule:GetSlots(Editor.coreKey)) do
        Editor.workingSlots[#Editor.workingSlots + 1] = {
            day = s.day, hour = s.hour, minute = s.minute, notes = s.notes,
        }
    end
    Editor:Render()
    Editor:Show()
end
