local flib_locale = require("__flib__.locale")

-- Returns the value of the setting with the provided name, or nil if it doesn't exist. Prefix should not be provided.
-- This function returns the value of a startup setting, but can still be used in control scripts and migrations.
function dataConfig(name)
    if settings.startup['qa_' .. name] then
        return settings.startup['qa_' .. name].value
    end
    return nil
end

-- Returns the value of the setting with the provided name, or nil if it doesn't exist. Prefix should not be provided.
-- This function returns the value of a global map setting and should only be used in control scripts and migrations.
function globalConfig(name)
    if settings.global['qa_' .. name] then
        return settings.global['qa_' .. name].value
    end
    return nil
end

-- Returns the value of the setting with the provided name, or nil if it doesn't exist. Prefix should not be provided.
-- This function returns the value of a player-specific setting and should only be used in control scripts and migrations.
function playerConfig(name, player)
    playerSettings = settings.get_player_settings(player)
    if playerSettings['qa_' .. name] then
        return playerSettings['qa_' .. name].value
    end
    return nil
end

local EnableLog = dataConfig("dev-mode")
-- Logs the input string if the dev-mode startup setting is enabled.
function CondLog(str)
    if EnableLog then
        log(str)
    end
end

-- Checks if a localised string is nil or empty.
function Empty(f)
    return f == nil or f == "" or (type(f) == "table" and not next(f))
end

-- Alias for flib function
---@param prototype {name: string, type: string}
function GetLocaleName(prototype)
    return flib_locale.of(prototype)
end