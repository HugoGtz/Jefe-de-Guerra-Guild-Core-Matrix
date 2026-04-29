local addonName, ns = ...
ns.Locale = ns.Locale or {}

local L = {}
ns.L = setmetatable(L, { __index = function(_, key) return key end })

local registry = {}
local callbacks = {}

function ns.Locale:Register(code, strings)
    registry[code] = strings
end

function ns.Locale:RegisterAlias(code, sourceCode)
    registry[code] = registry[sourceCode]
end

function ns.Locale:Has(code)
    return registry[code] ~= nil
end

function ns.Locale:GetAvailable()
    local out = {}
    for code in pairs(registry) do
        out[#out + 1] = code
    end
    table.sort(out)
    return out
end

function ns.Locale:Activate()
    local override = GCM_Settings and GCM_Settings.locale or nil
    local detected = (GetLocale and GetLocale()) or "enUS"
    local target = override or detected
    if not registry[target] then target = "enUS" end

    for k in pairs(L) do L[k] = nil end

    local base = registry.enUS or {}
    for k, v in pairs(base) do L[k] = v end

    if target ~= "enUS" then
        local active = registry[target] or {}
        for k, v in pairs(active) do L[k] = v end
    end

    self.current = target
end

function ns.Locale:RegisterCallback(fn)
    callbacks[#callbacks + 1] = fn
end

function ns.Locale:RunCallbacks()
    for _, fn in ipairs(callbacks) do
        local ok, err = pcall(fn)
        if not ok then
            print("|cffff0000[GCM]|r Locale callback error: " .. tostring(err))
        end
    end
end
