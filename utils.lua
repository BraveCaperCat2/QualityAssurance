-- Returns the value of the setting with the provided name, or nil if it doesn't exist. Prefix should not be provided.
function config(name)
    if settings.startup['qa_' .. name] then
        return settings.startup['qa_' .. name].value
    end
    return nil
end

local EnableLog = config("dev-mode")
function CondLog(str)
    if EnableLog then
        log(str)
    end
end
