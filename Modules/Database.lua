local addonName, ns = ...
ns.Database = {}

local DEFAULTS = {
    minimapPos = 45,
    locale = nil,
    framePosition = nil,
    frameWidth = 450,
    frameHeight = 550,
    collapsed = {},
    forceCanWrite = false,
}

local SCHEMA_VERSION = 3

function ns.Database:Initialize()
    GCM_Settings = GCM_Settings or {}
    for k, v in pairs(DEFAULTS) do
        if GCM_Settings[k] == nil then
            GCM_Settings[k] = v
        end
    end
    GCM_Settings.collapsed = GCM_Settings.collapsed or {}

    GCM_Settings.schemaVersion = SCHEMA_VERSION

    GCM_Cache = GCM_Cache or {}
    ns.Cache = GCM_Cache

    GCM_Sync = GCM_Sync or {}
    GCM_Sync.schedules = GCM_Sync.schedules or {}
    GCM_Sync.signups = GCM_Sync.signups or {}
    GCM_Sync.specs = GCM_Sync.specs or {}
    GCM_Sync.meta = GCM_Sync.meta or { version = 1 }
    ns.Sync = GCM_Sync
end

function ns.Database:IsCollapsed(key)
    return GCM_Settings.collapsed[key] == true
end

function ns.Database:SetCollapsed(key, value)
    GCM_Settings.collapsed[key] = value or nil
end

function ns.Database:ResetWindow()
    GCM_Settings.framePosition = nil
    GCM_Settings.frameWidth = DEFAULTS.frameWidth
    GCM_Settings.frameHeight = DEFAULTS.frameHeight
end
