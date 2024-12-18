local function config(name)
    return settings.startup['qa_' .. name].value
end

-- Add all qualities to the selected Technology, and remove technologies with no effect.
-- Thank you, wvlad for providing me with this new effect movement and technology removal system. (If I ever add a supporters list, you'll be on it!)
local QualityTechnologyName = config("quality-unlock")
log("Adding Qualities to \"".. QualityTechnologyName .."\" Technology.")
local RemovedTechnologies = {}
for i,Technology in pairs(data.raw["technology"]) do
    log("Scanning Technology \"" .. Technology.name .. "\" now.")
    if Technology.name ~= QualityTechnologyName then
        if Technology.effects ~= nil then
            log("Technology has Effects.")
            local moved = false
            for j,Effect in pairs(Technology.effects) do
                log("Scanning Modifier of type \"" .. Effect.type .. "\" now.")
                if Effect.type == "unlock-quality" then
                    log("Effect is a match! Testing for quality forward movement now.")
                    local MoveQuality = true
                    if QualityTechnologyName == "rocket-silo" or QualityTechnologyName == "quality-module-2" or QualityTechnologyName == "quality-module-3" then
                        if Effect.quality == "uncommon" or Effect.quality == "rare" then
                            MoveQuality = false
                            log("Moving this quality to the \"" .. QualityTechnologyName .. "\" technology would cause the \"" .. Effect.quality .. "\" quality to be moved forward instead of backward! Cancelling this effect movement.")
                        end
                    end
                    if MoveQuality then
                        log("Moving quality unlock for quality \"" .. Effect.quality .. "\" to the \"" .. QualityTechnologyName .. "\" technology.")
                        table.insert(data.raw["technology"][QualityTechnologyName].effects, Effect)
                        data.raw["technology"][i].effects[j] = nil
                        moved = true
                        log("Effect moved.")
                    end
                end
            end

            if moved then
                local function CleanNils(t)
                  local ans = {}
                  for _,v in pairs(t) do
                    ans[ #ans+1 ] = v
                  end
                  return ans
                end

                if Technology.effects ~= nil then 
                    Technology.effects = CleanNils(Technology.effects)
                end

                if Technology.effects == nil or #Technology.effects == 0 then
                    log("All effects of Technology \"" .. Technology.name .. "\" have been removed. Removing Technology.")
                    RemovedTechnologies[Technology.name] = Technology
                    data.raw["technology"][i] = nil
                end
            end
        end
    end
end
for i,Technology in pairs(data.raw["technology"]) do
    log("Scanning technology \"" .. Technology.name .. "\" now.")
    if Technology ~= nil then
        for _,RemovedTechnology in pairs(RemovedTechnologies) do
            log("Scanning removed technology \"" .. Technology.name .. "\" now.")
            if Technology.prerequisites ~= nil and Technology.prerequisites ~= {} and Technology.prerequisites ~= "" then
                log("Existing technology has dependencies.")
                for j,TechnologyDependency in pairs(Technology.prerequisites) do
                    log("Scanning dependency \"" .. TechnologyDependency .. "\" now.")
                    if TechnologyDependency == RemovedTechnology.name then
                        log("Dependency is a match! Replacing dependency for removed technology \"" .. RemovedTechnology.name .. "\" with the dependencies of that technology.")
                        table.remove(data.raw["technology"][i].prerequisites, j)
                        if RemovedTechnology.prerequisites ~= nil and RemovedTechnology.prerequisites ~= {} and RemovedTechnology.prerequisites ~= "" then
                            for _,RemovedTechnologyDependency in pairs(RemovedTechnology.prerequisites) do
                                local AddDependency = true
                                for k,OtherTechnologyDependency in pairs(Technology.prerequisites) do
                                    if OtherTechnologyDependency == RemovedTechnologyDependency then
                                        AddDependency = false
                                    end
                                end
                                if AddDependency then
                                    log("Adding dependency \"" .. RemovedTechnologyDependency .. "\" to technology \"" .. Technology.name .. "\" now.")
                                    table.insert(data.raw["technology"][i].prerequisites, RemovedTechnologyDependency)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

local function NAMSModifications(Machine)
    local NAMSMachine = data.raw[Machine.type][Machine.NAMSMachine]
    Machine.category = NAMSMachine.category
    return Machine
end

local MachineTypes = {"crafting-machine", "furnace", "assembling-machine", "mining-drill", "rocket-silo"}

log("Initiating more operations on automated crafting.")
for _,MachineType in pairs(MachineTypes) do
    if data.raw[MachineType] ~= nil then
        for j,Machine in pairs(data.raw[MachineType]) do
            log("Re-scanning Machine \"" .. Machine.name .. "\" now.")

            if string.find(Machine.name, "qa_") then

                -- Update the AMSMachine with certain modifications from the base machine.
                Machine = NAMSModifications(Machine)

                data.raw[MachineType][j] = Machine
            end
        end
    end
end
