local _, ns = ...
ns.PublicNote = ns.PublicNote or {}

local STAMP_FMT = "[GCM:%s]"
local MAX_NOTE = 31

local function GetCharKey()
    return UnitName("player") or ""
end

local function GetState()
    GCM_Settings.publicNote = GCM_Settings.publicNote or {}
    local k = GetCharKey()
    GCM_Settings.publicNote[k] = GCM_Settings.publicNote[k] or {}
    return GCM_Settings.publicNote[k]
end

local function FindSelfIndex()
    local me = UnitName("player")
    if not me then return nil end
    local count = GetNumGuildMembers and GetNumGuildMembers() or 0
    for i = 1, count do
        local name = GetGuildRosterInfo(i)
        if name and Ambiguate(name, "none") == Ambiguate(me, "none") then
            return i
        end
    end
    return nil
end

function ns.PublicNote:IsManaged()
    local st = GetState()
    return st.mode == "gcm_managed"
end

function ns.PublicNote:ComposeNote(role)
    if not role then return nil end
    return string.format(STAMP_FMT, role)
end

function ns.PublicNote:ExtractStamp(noteText)
    if not noteText then return nil end
    return noteText:match("%[GCM:[THD]%]")
end

function ns.PublicNote:Push()
    if not ns.Notes or not ns.Notes:EffectiveCanEditPublicNote() then
        print(ns.L.BRAND .. " " .. ns.L.PUBNOTE_NO_PERM)
        return false
    end

    local me = UnitName("player")
    if not me then return false end
    local _, class = UnitClass("player")
    local role = ns.Roles and ns.Roles:GetEffectiveRole(me, class)
    if not role then
        print(ns.L.BRAND .. " " .. ns.L.PUBNOTE_NO_ROLE)
        return false
    end

    local idx = FindSelfIndex()
    if not idx then
        print(ns.L.BRAND .. " " .. ns.L.PUBNOTE_NOT_IN_GUILD)
        return false
    end

    local _, _, _, _, _, _, currentNote = GetGuildRosterInfo(idx)
    currentNote = currentNote or ""

    local composed = self:ComposeNote(role)
    if #composed > MAX_NOTE then
        print(ns.L.BRAND .. " " .. string.format(ns.L.PUBNOTE_TOO_LONG, #composed, MAX_NOTE))
        return false
    end

    local st = GetState()
    if st.mode ~= "gcm_managed" then
        st.backup = currentNote
    end
    st.mode = "gcm_managed"
    st.stamp = composed

    GuildRosterSetPublicNote(idx, composed)
    print(ns.L.BRAND_GREEN .. " " .. string.format(ns.L.PUBNOTE_PUSHED, composed))
    return true
end

function ns.PublicNote:Restore(force)
    local st = GetState()
    if not st.mode then
        print(ns.L.BRAND .. " " .. ns.L.PUBNOTE_NOT_MANAGED)
        return false
    end

    if not ns.Notes or not ns.Notes:EffectiveCanEditPublicNote() then
        print(ns.L.BRAND .. " " .. ns.L.PUBNOTE_NO_PERM)
        return false
    end

    local idx = FindSelfIndex()
    if not idx then
        print(ns.L.BRAND .. " " .. ns.L.PUBNOTE_NOT_IN_GUILD)
        return false
    end

    if not force then
        local _, _, _, _, _, _, currentNote = GetGuildRosterInfo(idx)
        currentNote = currentNote or ""
        if not self:ExtractStamp(currentNote) then
            print(ns.L.BRAND .. " " .. ns.L.PUBNOTE_RESTORE_CHANGED)
            print(ns.L.BRAND .. " " .. ns.L.PUBNOTE_RESTORE_FORCE_HINT)
            return false
        end
    end

    local backup = st.backup or ""
    GuildRosterSetPublicNote(idx, backup)
    st.mode = nil
    st.stamp = nil
    local displayBackup = backup ~= "" and ("\"" .. backup .. "\"") or "(empty)"
    print(ns.L.BRAND_GREEN .. " " .. string.format(ns.L.PUBNOTE_RESTORED, displayBackup))
    return true
end

function ns.PublicNote:Reapply(silent)
    if not self:IsManaged() then return end
    if not ns.Notes or not ns.Notes:EffectiveCanEditPublicNote() then return end
    local me = UnitName("player")
    if not me then return end
    local _, class = UnitClass("player")
    local role = ns.Roles and ns.Roles:GetEffectiveRole(me, class)
    if not role then return end
    local idx = FindSelfIndex()
    if not idx then return end
    local composed = self:ComposeNote(role)
    local st = GetState()
    st.stamp = composed
    GuildRosterSetPublicNote(idx, composed)
    if not silent then
        print(ns.L.BRAND_GREEN .. " " .. ns.L.PUBNOTE_REAPPLIED)
    end
end

function ns.PublicNote:Status()
    local st = GetState()
    local me = UnitName("player")
    local _, class = UnitClass("player")
    local role = ns.Roles and ns.Roles:GetEffectiveRole(me, class)
    local roleStr = (role == "T" and ns.L.ROLE_TANK) or (role == "H" and ns.L.ROLE_HEAL) or (role == "D" and ns.L.ROLE_DPS) or "?"
    local modeStr = st.mode == "gcm_managed" and ns.L.PUBNOTE_MODE_MANAGED or ns.L.PUBNOTE_MODE_OFF
    print(ns.L.BRAND .. " " .. string.format(ns.L.PUBNOTE_STATUS, modeStr, roleStr))
    if st.mode == "gcm_managed" and st.backup ~= nil then
        local displayBackup = st.backup ~= "" and ("\"" .. st.backup .. "\"") or "(empty)"
        print(ns.L.BRAND .. " " .. string.format(ns.L.PUBNOTE_BACKUP, displayBackup))
    end
end

function ns.PublicNote:Init()
end
