EnableCraftingSpeedFunction = false

-- Returns the value of the setting with the provided name. Prefix should not be provided.
local function config(name)
    return settings.startup['qa_' .. name].value
end

-- A list of entity names to be skipped over when creating AMS machines.
local AMSBlocklist = {"awesome-sink-gui"}

function GetCraftingSpeedMultiplier(ModuleSlotDifference)
    -- low2 + (value - low1) * (high2 - low2) / (high1 - low1) Provided by "mmmPI" on the factorio forums. Thank you. (If I ever add a supporters list, you'll be on it!)
    return 0.01 + (ModuleSlotDifference - ( -10 )) * (100 - 0.01) / ( 10 - ( -10 ))
end

local function Localiser(AMS, Machine)
    -- Thank you, A.Freeman (from the mod portal) for providing me with this new localisation system. The function part was my idea though. (If I ever add a supporters list, you'll be on it!)
    if AMS.type == "technology" then
        if Machine.localised_name and not Machine.localised_name == {} and not Machine.localised_name == "" then
            AMS.localised_name = {"ams.tech-name", {Machine.localised_name}}
            AMS.localised_description = {"ams.tech-description", {Machine.localised_name}}
        else
            AMS.localised_name = {"ams.tech-name", {"entity-name."..Machine.name}}
            AMS.localised_description = {"ams.tech-description", {"entity-name."..Machine.name}}
        end
    else
        if Machine.localised_name and not Machine.localised_name == {} and not Machine.localised_name == "" then
            AMS.localised_name = {"ams.name", {Machine.localised_name}}
            AMS.localised_description = {"ams.description", {Machine.localised_name}}
        else
            AMS.localised_name = {"ams.name", {"entity-name."..Machine.name}}
            AMS.localised_description = {"ams.description", {"entity-name."..Machine.name}}
        end
    end
    return AMS
end

-- Thank you, A.Freeman (from the mod portal) for providing me with this new prerequisites system. (If I ever add a supporters list, you'll be on it!)
local function GetMachineTechnology(Machine)
    for i,Technology in pairs(data.raw["technology"]) do
        if Technology.effects then
            for j,Effect in pairs(Technology.effects) do
                if Effect and Effect.type == "unlock-recipe" and Effect.recipe == Machine.name then
                    return Technology.name
                end
            end
        end
    end
    return nil
end


local function AddQuality(Machine)
    -- Increase quality for a machine.
    if not config("base-quality") then
        if config("dev-mode") then
            log("Base Quality setting is disabled. Skipping.")
        end
        return Machine
    end

    if not config("moduleless-quality") then
        if Machine.module_slots == nil then
            if config("dev-mode") then
                log("Moduleless Quality setting is disabled, and this machine doesn't have module slots. Skipping.")
            end
            return Machine
        else
            if Machine.module_slots == 0 then
                if config("dev-mode") then
                    log("Moduleless Quality setting is disabled, and this machine doesn't have module slots. Skipping.")
                end
                return Machine
            end
        end
    end
    local BaseQuality = false
    NormalProbability = data.raw.quality["normal"].next_probability or 1
    while not BaseQuality do
        if Machine.effect_receiver then
            if Machine.effect_receiver.base_effect then
                if Machine.effect_receiver.base_effect.quality then
                    if Machine.effect_receiver.base_effect.quality == 0 then
                        if config("dev-mode") then
                            log("Machine does not contain base quality. Adding base quality.")
                        end
                        Machine.effect_receiver.base_effect.quality = config("base-quality-value") / 100 / NormalProbability
                    else
                        if config("dev-mode") then
                            log("Machine contains base quality of amount " .. Machine.effect_receiver.base_effect.quality or 0 ..". Skipping.")
                        end
                    end
                    BaseQuality = true
                else
                    if config("dev-mode") then
                        log("Machine does not contain base quality. Preparing to add base quality.")
                    end
                    Machine.effect_receiver.base_effect.quality = 0
                end
            else
                Machine.effect_receiver.base_effect = {}
            end
            if Machine.effect_receiver.uses_beacon_effects ~= true then
                Machine.effect_receiver.uses_beacon_effects = true
            end
            if Machine.effect_receiver.uses_module_effects ~= true then
                Machine.effect_receiver.uses_module_effects = true
            end
            if Machine.effect_receiver.uses_surface_effects ~= true then
                Machine.effect_receiver.uses_surface_effects = true
            end
        else
            Machine.effect_receiver = {}
        end
    end
    return Machine
end

local function EnableQuality(Machine)
    -- Allow Qualities in all Machines.
    local qualityadded = false
    local hasquality = false
    while not hasquality do
        if Machine.allowed_effects then
            if type(Machine.allowed_effects) ~= "string" then
                for _, AllowedEffect in pairs(Machine.allowed_effects) do
                    if AllowedEffect == "quality" then
                        hasquality = true
                    end
                end
                if hasquality == false then
                    table.insert(Machine.allowed_effects, "quality")
                    hasquality = true
                end
            else
                Machine.allowed_effects = {Machine.allowed_effects}
            end
        else
            hasquality = true
        end
    end

    while not qualityadded do
        if Machine.effect_receiver then
            if Machine.effect_receiver.uses_beacon_effects ~= true then
                Machine.effect_receiver.uses_beacon_effects = true
            end
            if Machine.effect_receiver.uses_module_effects ~= true then
                Machine.effect_receiver.uses_module_effects = true
            end
            if Machine.effect_receiver.uses_surface_effects ~= true then
                Machine.effect_receiver.uses_surface_effects = true
            end
            qualityadded = true
        else
            Machine.effect_receiver = {}
        end
    end
    return Machine
end

-- Perform operations on automated crafting.
local MachineTypes = {"crafting-machine", "furnace", "assembling-machine", "mining-drill", "rocket-silo"}

if config("dev-mode") then
    log("Performing operations on Automated Crafting.")
end
for _,MachineType in pairs(MachineTypes) do
    if data.raw[MachineType] then
        for j,Machine in pairs(data.raw[MachineType]) do
            if config("dev-mode") then
                log("Scanning Machine \"" .. Machine.name .. "\" now.")
            end
            
            if MachineType ~= "rocket-silo" then
                if ( not config("ams-base-quality-toggle") ) then
                    Machine = AddQuality(Machine)
                end
                Machine = EnableQuality(Machine)
            else
                data.raw[MachineType][j].fixed_recipe = nil
                data.raw[MachineType][j].fixed_quality = nil
            end

            data.raw[MachineType][j] = Machine

            local MachineBanned = false

            for _,EntityName in pairs(AMSBlocklist) do
                if Machine.name == EntityName then
                    MachineBanned = true
                end
            end

            if Machine.no_ams == true then
                MachineBanned = true
            end

            if MachineBanned and config("dev-mode") then
                log("Machine \"" .. Machine.name .. "\" is banned from AMS!")
            end

            -- Create a new version of all machines which don't have additional module slots.
            if ( not string.find(Machine.name, "qa_") ) and config("ams-machines-toggle") and ( not MachineBanned ) then
                if config("dev-mode") then
                    log("Creating AMS version of \"" .. Machine.name .. "\" now.")
                end
                local AMSMachine = table.deepcopy(Machine)
                AMSMachine.name = "qa_" .. AMSMachine.name .. "-ams"
                AMSMachine = Localiser(AMSMachine, Machine)

                if ( config("ams-base-quality-toggle") ) then
                    AMSMachine = AddQuality(AMSMachine)
                end

                local AddedModuleSlots = config("added-module-slots")
                local SpeedMultiplier = 1
                if AMSMachine.module_slots == nil then
                    AMSMachine.module_slots = 0
                end
                if EnableCraftingSpeedFunction == true then
                    if AMSMachine.module_slots + AddedModuleSlots < 0 then
                        SpeedMultiplier = GetCraftingSpeedMultiplier(AMSMachine.module_slots)
                        AMSMachine.module_slots = 0
                    elseif AddedModuleSlots ~= 0 then
                        SpeedMultiplier = GetCraftingSpeedMultiplier(AddedModuleSlots)
                        AMSMachine.module_slots = AMSMachine.module_slots + AddedModuleSlots
                    end
                else
                    AddedModuleSlots = 2
                    AMSMachine.module_slots = AMSMachine.module_slots + AddedModuleSlots
                    SpeedMultiplier = 0.8
                end
                if AMSMachine.crafting_speed then
                    AMSMachine.crafting_speed = AMSMachine.crafting_speed * SpeedMultiplier
                elseif AMSMachine.mining_speed then
                    AMSMachine.mining_speed = AMSMachine.mining_speed * SpeedMultiplier
                end
                AMSMachine["minable"] = AMSMachine["minable"] or {mining_time = 1}
                AMSMachine.minable.results = nil
                AMSMachine.minable.result = AMSMachine.name
                AMSMachine.minable.count = 1

                AMSMachine.allowed_effects = {"speed", "productivity", "consumption", "pollution", "quality"}
                AMSMachine.allowed_module_categories = {}
                for _,ModuleCatergory in pairs(data.raw["module-category"]) do
                    if ModuleCatergory then
                        table.insert(AMSMachine.allowed_module_categories, ModuleCatergory.name)
                    end
                end
                if AMSMachine.effect_receiver == nil then
                    AMSMachine.effect_receiver = {uses_surface_effects = true, uses_beacon_effects = true, uses_module_effects = true}
                else
                    AMSMachine.effect_receiver.uses_beacon_effects = true
                    AMSMachine.effect_receiver.uses_module_effects = true
                    AMSMachine.effect_receiver.uses_surface_effects = true
                end
                AMSMachine.NAMSMachine = Machine.name

                local AMSMachineItem = {}
                if data.raw["item"][Machine.name] then
                    AMSMachineItem = table.deepcopy(data.raw["item"][Machine.name])
                elseif data.raw["item"][Machine.MachineItem] then
                    AMSMachineItem = table.deepcopy(data.raw["item"][Machine.MachineItem])
                else
                    AMSMachineItem = table.deepcopy(data.raw["item"]["assembling-machine-2"])
                end
                AMSMachineItem.name = AMSMachine.name
                AMSMachineItem.type = "item"
                AMSMachineItem = Localiser(AMSMachineItem, Machine)
                AMSMachineItem.stack_size = 50
                AMSMachineItem.place_result = AMSMachine.name
                AMSMachine.MachineItem = AMSMachineItem.name

                local AMSMachineRecipe = {}
                AMSMachineRecipe.name = AMSMachineItem.name
                AMSMachineRecipe.type = "recipe"
                AMSMachineRecipe = Localiser(AMSMachineRecipe, Machine)
                if Machine.MachineItem == nil and Machine.minable then
                    if Machine.minable.result and Machine.minable.result ~= "" then
                        AMSMachineRecipe.ingredients = {{type = "item", name = Machine.minable.result, amount = 1}, {type = "item", name = "steel-plate", amount = 10}, {type = "item", name = "copper-cable", amount = 20}}
                    else
                        AMSMachineRecipe.ingredients = {{type = "item", name = "electronic-circuit", amount = 1}, {type = "item", name = "steel-plate", amount = 10}, {type = "item", name = "copper-cable", amount = 20}}
                    end
                else
                    AMSMachineRecipe.ingredients = {{type = "item", name = Machine.MachineItem, amount = 1}, {type = "item", name = "steel-plate", amount = 10}, {type = "item", name = "copper-cable", amount = 20}}
                end

                if AMSMachineRecipe.ingredients[1]["name"] == nil then
                    AMSMachineRecipe.ingredients[1]["name"] = "electronic-circuit"
                    if config("dev-mode") then
                        log("Had to replace ingredient name for \"" .. AMSMachineRecipe.name .. "\"")
                    end
                end

                AMSMachineRecipe.results = {{type = "item", name = AMSMachineItem.name, amount = 1}}
                AMSMachineRecipe.category = "crafting"
                AMSMachineRecipe.enabled = false
                
                local AMSMachineTechnology = table.deepcopy(data.raw["technology"]["automation-2"])
                AMSMachineTechnology.name = AMSMachine.name
                -- Thank you, A.Freeman (from the mod portal) for providing me this new prerequisites system. (If I ever add a supporters list, you'll be on it!)
                local Prerequisite = GetMachineTechnology(Machine)
                if Prerequisite then
                    AMSMachineTechnology.prerequisites = {Prerequisite, "steel-processing", "electronics"}
                    PrerequisiteTech = data.raw["technology"][Prerequisite]
                    if PrerequisiteTech.icon and PrerequisiteTech.icon ~= "" then
                        AMSMachineTechnology.icon = PrerequisiteTech.icon
                        AMSMachineTechnology.icon_size = PrerequisiteTech.icon_size
                    elseif PrerequisiteTech.icons and PrerequisiteTech.icons ~= {} then
                        AMSMachineTechnology.icons = PrerequisiteTech.icons
                    end
                    if PrerequisiteTech.unit then
                        AMSMachineTechnology.unit = table.deepcopy(PrerequisiteTech.unit)
                        if AMSMachineTechnology.unit.count then
                            AMSMachineTechnology.unit.count = 2 * AMSMachineTechnology.unit.count
                        elseif AMSMachineTechnology.unit.count_formula then
                            AMSMachineTechnology.unit.count_formula = "2 * (" .. AMSMachineTechnology.unit.count_formula .. ")"
                        end
                        AMSMachineTechnology.research_trigger = nil
                    elseif PrerequisiteTech.research_trigger then
                        AMSMachineTechnology.research_trigger = table.deepcopy(PrerequisiteTech.research_trigger)
                        AMSMachineTechnology.unit = nil
                    end
                else
                    AMSMachineTechnology.prerequisites = {"steel-processing", "electronics"}
                    AMSMachineTechnology.research_trigger = {type = "build-entity", entity = {name = Machine.name}}
                    AMSMachineTechnology.unit = nil
                end
                AMSMachineTechnology.effects = {{type = "unlock-recipe", recipe = AMSMachineRecipe.name}}
                AMSMachineTechnology = Localiser(AMSMachineTechnology, Machine)

                if config("dev-mode") then
                    log("Made AMS version of \"" .. Machine.name .. "\".")
                end
                data:extend{AMSMachine, AMSMachineItem, AMSMachineRecipe, AMSMachineTechnology}
            elseif config("dev-mode") then
                log("Machine \"" .. Machine.name .. "\" is an AMS machine, AMS machines are turrend off, or this machine is banned. Skipping the AMS machine making process.")
            end
        end
    end
end

-- Allow Quality Modules in Beacons.
if config("quality-beacons") then
    for _,Beacon in pairs(data.raw["beacon"]) do
        Beacon = EnableQuality(Beacon)
    end
end

-- Improve power of all quality modules.
if config("dev-mode") then
    log("Improving power of all quality modules.")
end
for _,Module in pairs(data.raw["module"]) do
    if config("dev-mode") then
        log("Scanning module \"" .. Module.name .. "\" now.")
    end
    if Module.effect.quality then
        if Module.effect.quality >= 0 then
            if config("dev-mode") then
                log("Module \"" .. Module.name .. "\" contians a Quality increase. Increasing bonus.")
            end
            Module.effect.quality = Module.effect.quality * config("quality-module-multiplier")
        end
    end
end
