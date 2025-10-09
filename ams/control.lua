-- Provides Config, CondLog functions
require("common.utils")

-- Technologies for AMS machines are hidden by default
-- These handlers enable techs when corresponding prerequisites are researched

local function ShowAMSTech()
    return not Config("hide-ams-technologies")
end

local function CheckPrerequisites(Technology)
    -- Check all prerequisites are researched
    Researched = true
    for _, Prerequisite in pairs(Technology.prerequisites) do
        Researched = Researched and Prerequisite.researched
    end
    return Researched
end

local function on_init()
    for _, Force in pairs(game.forces) do
        for _, Technology in pairs(Force.technologies) do
            if Technology.name:match('%-ams$') then
               Technology.enabled = ShowAMSTech() or CheckPrerequisites(Technology)
            end
        end
    end
end

local function on_configuration_changed(ConfigurationChangedData)
    on_init()
end

local function on_research_finished(event)
	local Technology = event.research
    for _, Successor in pairs(Technology.successors) do
        if Successor.name:match('%-ams$') then
            Successor.enabled = ShowAMSTech() or CheckPrerequisites(Successor)
        end
    end
end

-- Register event handlers when AMS machines are enabled

if Config("ams-machines-toggle") then
    script.on_init(on_init)
    script.on_configuration_changed(on_configuration_changed)
    script.on_event(defines.events.on_research_finished, on_research_finished)
    script.on_event(defines.events.on_runtime_mod_setting_changed, on_configuration_changed)
end