

-- Returns the value of the setting with the provided name, or nil if it doesn't exist. 
-- Prefix should not be provided.
function Config(name)
    local convertedName = 'qa_' .. name
    if settings.startup[convertedName] then
        return settings.startup[convertedName].value
    end

    if settings.global and settings.global[convertedName] then
        return settings.global[convertedName].value
    end
    log("Settings " .. name .. " wasn't found")
    return nil
end

local EnableLog = Config("dev-mode")
function CondLog(str)
    if EnableLog then
        log(str)
    end
end
