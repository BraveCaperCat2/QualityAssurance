-- Provides VariableAdditionalSlots, MachineTypes, 
--  AMSBlocklist, UnfixedRSRBlocklist, BaseQualityBlockList
require("common.values")
-- Provides Config, CondLog functions
require("common.utils")
-- Provides contains, CheckBaseQualityEnabled, AddBaseQuality functions
require("base-quality.utils")


-- A new crafting speed function. Equivalent to the square root of 0.8 to the power of the module 
--  slot difference, rounded up to the nearest hundreth.
local function GetCraftingSpeedMultiplier(ModuleSlotDifference)
    return math.ceil(math.pow(0.8, ModuleSlotDifference / 2) * 100) / 100
end

-- Add QA image to icons
local function UpdateIcon(Entity)
    if Entity.icons then
        Entity.icons[#Entity.icons+1] = {
            icon = "__QualityAssurance__/graphics/icons/qa256.png",
            icon_size=256
        }
        
    elseif Entity.icon then
        Entity.icons = {
            {icon = Entity.icon, icon_size = Entity.icon_size},
            {icon = "__QualityAssurance__/graphics/icons/qa256.png", icon_size=256},
        }
        Entity.icon = nil
    end
    return Entity
end

-- Build localised name and description for AMS entity, add QA image to icons
-- Thank you, A.Freeman (from the mod portal) for providing me with this new localisation system. 
-- The function part was my idea though. (If I ever add a supporters list, you'll be on it!)
local function Localiser(AMS, Machine, AMSMachine)
    if ( ( Machine.module_slots and AMSMachine.module_slots > Machine.module_slots )
        or not Machine.module_slots ) then
        -- AMS locales.
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
    else
        -- RMS locales.
        if AMS.type == "technology" then
            if Machine.localised_name and not Machine.localised_name == {} and not Machine.localised_name == "" then
                AMS.localised_name = {"rms.tech-name", {Machine.localised_name}}
                AMS.localised_description = {"rms.tech-description", {Machine.localised_name}}
            else
                AMS.localised_name = {"rms.tech-name", {"entity-name."..Machine.name}}
                AMS.localised_description = {"rms.tech-description", {"entity-name."..Machine.name}}
            end
        else
            if Machine.localised_name and not Machine.localised_name == {} and not Machine.localised_name == "" then
                AMS.localised_name = {"rms.name", {Machine.localised_name}}
                AMS.localised_description = {"rms.description", {Machine.localised_name}}
            else
                AMS.localised_name = {"rms.name", {"entity-name."..Machine.name}}
                AMS.localised_description = {"rms.description", {"entity-name."..Machine.name}}
            end
        end
    end
    UpdateIcon(AMS)
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

local RecyclingLibrary = require("__quality__.prototypes.recycling")

local function CreateAMSMachine(Machine)
    local NewMachine = table.deepcopy(Machine)
    NewMachine.name = "qa_" .. Machine.name .. "-ams"

    if NewMachine.module_slots == nil then
        NewMachine.module_slots = 0
    end

    local AddedModuleSlots = Config("added-module-slots")
    local SpeedMultiplier = 1

    if VariableAdditionalSlots == true then
        -- Check for removing more slots than the machine has.
        -- This would cause the machine to have negative module slots, which is bad.
        -- Instead, remove as many as possible.
        if AddedModuleSlots + NewMachine.module_slots < 0 then
            AddedModuleSlots = -NewMachine.module_slots
        end

        if AddedModuleSlots == 0 then
            CondLog("Cancelling AMS machine creation, as no module slots would be added or removed.")
            return nil
        end

        -- Check for removing any slots at all.
        -- Removing slots will increase the crafting speed of the machine and change locales.
        if AddedModuleSlots < 0 then
            CondLog("Machine will have increased speed due to removing modules.")
        end

        -- Calculate the speed multiplier and add/remove module slots.
        SpeedMultiplier = GetCraftingSpeedMultiplier(AddedModuleSlots)
        NewMachine.module_slots = NewMachine.module_slots + AddedModuleSlots
    else
        AddedModuleSlots = 2
        NewMachine.module_slots = NewMachine.module_slots + AddedModuleSlots
        SpeedMultiplier = 0.8
    end

    -- Decrease/increase crafting speed.
    if NewMachine.crafting_speed then
        NewMachine.crafting_speed = NewMachine.crafting_speed * SpeedMultiplier
    elseif NewMachine.mining_speed then
        NewMachine.mining_speed = NewMachine.mining_speed * SpeedMultiplier
    elseif NewMachine.researching_speed then
        NewMachine.researching_speed = NewMachine.researching_speed * SpeedMultiplier
    end

    NewMachine["minable"] = NewMachine["minable"] or {mining_time = 1}
    NewMachine.minable.results = nil
    NewMachine.minable.result = NewMachine.name
    NewMachine.minable.count = 1

    NewMachine.allowed_effects = {"speed", "productivity", "consumption", "pollution", "quality"}
    NewMachine.allowed_module_categories = {}
    for _,ModuleCatergory in pairs(data.raw["module-category"]) do
        if ModuleCatergory then
            table.insert(NewMachine.allowed_module_categories, ModuleCatergory.name)
        end
    end
    if NewMachine.effect_receiver == nil then
        NewMachine.effect_receiver = {uses_surface_effects = true, uses_beacon_effects = true, uses_module_effects = true}
    else
        NewMachine.effect_receiver.uses_beacon_effects = true
        NewMachine.effect_receiver.uses_module_effects = true
        NewMachine.effect_receiver.uses_surface_effects = true
    end
    -- FIXME: looks like it's unused
    -- NewMachine.NAMSMachine = Machine.name


    if CheckBaseQualityEnabled(NewMachine) then
        NewMachine = AddBaseQuality(NewMachine)
    end

    NewMachine = Localiser(NewMachine, Machine, NewMachine)
    return NewMachine
end

local function CreateAMSMachineItem(Machine, AMSMachine)
    local NewItem = {}
    if data.raw["item"][Machine.name] then
        NewItem = table.deepcopy(data.raw["item"][Machine.name])
    elseif data.raw["item"][Machine.MachineItem] then
        NewItem = table.deepcopy(data.raw["item"][Machine.MachineItem])
    else
        NewItem = table.deepcopy(data.raw["item"]["assembling-machine-2"])
    end
    NewItem.name = AMSMachine.name
    NewItem.type = "item"
    NewItem.stack_size = 50
    NewItem.place_result = AMSMachine.name
    NewItem = Localiser(NewItem, Machine, AMSMachine)

    AMSMachine.MachineItem = NewItem.name
    return NewItem
end

local function CreateAMSMachineRecipe(Machine, AMSMachine)
    -- Get main ingredient
    local MainIngredient = {}
    if Machine.MachineItem == nil and Machine.minable then
        if Machine.minable.result and Machine.minable.result ~= "" then
            MainIngredient = {type = "item", name = Machine.minable.result, amount = 1}
        else
            if data.raw["item"][Machine.name] then
                MainIngredient = {type = "item", name = Machine.name, amount = 1}
            else
                MainIngredient = {type = "item", name = "electronic-circuit", amount = 1}
            end
        end
    else
        MainIngredient = {type = "item", name = Machine.MachineItem, amount = 1}
    end

    if MainIngredient["name"] == nil then
        CondLog("Replacing main ingredient for \"" .. AMSMachine.MachineItem .. "\"")
        MainIngredient["name"] = "electronic-circuit"
    end
    -- Recipe
    local NewRecipe = {
        name = AMSMachine.MachineItem,
        type = "recipe",
        ingredients = {
            MainIngredient,
            {type = "item", name = "steel-plate", amount = 10},
            {type = "item", name = "copper-cable", amount = 20}
        },
        results = {{type = "item", name = AMSMachine.MachineItem, amount = 1}},
        category = "crafting",
        enabled = false
    }
    NewRecipe = Localiser(NewRecipe, Machine, AMSMachine)
    return NewRecipe
end

local function CreateAMSMachineTech(Machine, AMSMachine)
    local NewTech = table.deepcopy(data.raw["technology"]["automation-2"])
    NewTech.name = AMSMachine.name
    -- Thank you, A.Freeman (from the mod portal) for providing me this new prerequisites system. 
    -- (If I ever add a supporters list, you'll be on it!)
    local Prerequisite = GetMachineTechnology(Machine)
    if Prerequisite then
        -- Add prerequisites
        if Prerequisite ~= "steel-processing" and Prerequisite ~= "electronics" then
            NewTech.prerequisites = {Prerequisite, "steel-processing", "electronics"}
        elseif Prerequisite == "steel-processing" and Prerequisite ~= "electronics" then
            NewTech.prerequisites = {Prerequisite, "electronics"}
        elseif Prerequisite ~= "steel-processing" and Prerequisite == "electronics" then
            NewTech.prerequisites = {Prerequisite, "steel-processing"}
        else
            NewTech.prerequisites = {Prerequisite}
        end
        PrerequisiteTech = data.raw["technology"][Prerequisite]
        -- Add icon
        if PrerequisiteTech.icon and PrerequisiteTech.icon ~= "" then
            NewTech.icon = PrerequisiteTech.icon
            NewTech.icon_size = PrerequisiteTech.icon_size
        elseif PrerequisiteTech.icons and PrerequisiteTech.icons ~= {} then
            NewTech.icons = PrerequisiteTech.icons
        end
        -- Add research conditions
        if PrerequisiteTech.unit then
            NewTech.unit = table.deepcopy(PrerequisiteTech.unit)
            if NewTech.unit.count then
                NewTech.unit.count = 2 * NewTech.unit.count
            elseif NewTech.unit.count_formula then
                NewTech.unit.count_formula = "2 * (" .. NewTech.unit.count_formula .. ")"
            end
            NewTech.research_trigger = nil
        elseif PrerequisiteTech.research_trigger then
            NewTech.research_trigger = table.deepcopy(PrerequisiteTech.research_trigger)
            NewTech.unit = nil
        end
    else
        NewTech.prerequisites = {"steel-processing", "electronics"}
        NewTech.research_trigger = {type = "build-entity", entity = {name = Machine.name}}
        NewTech.unit = nil
    end
    -- Add unlocking AMS recipe
    -- Recipe has the same name as AMSMachine
    NewTech.effects = {{type = "unlock-recipe", recipe = AMSMachine.name}}
    NewTech = Localiser(NewTech, Machine, AMSMachine)
    return NewTech
end

-- Check if we want AMS version of Machine
function CheckAMSEnabled(Machine)
    local check = (
        Config("ams-machines-toggle")
        and Config("enable-ams-" .. Machine.type)
        and not contains(AMSBlocklist, Machine.name)
        and Machine.no_ams ~= true
    )
    if not check then
        CondLog("Machine \"" .. Machine.name .. "\" is banned from AMS!")
    end
    return check
end

-- Temporary storage for created entities
local NewEntities = {}
-- Recipies to process through RecyclingLibrary
local NewRecipies = {}

-- Create AMS version of selected machines.
CondLog("Creating AMS machines")
for _,MachineType in pairs(AMSMachineTypes) do
    if not data.raw[MachineType] then
        CondLog("Skipping empty machine type " .. MachineType)
        goto continue_MachineType
    end
    for j,Machine in pairs(data.raw[MachineType]) do
        if not CheckAMSEnabled(Machine) then
            goto continue_Machine
        end

        -- Create a new version of all machines which don't have additional module slots.
        CondLog("Creating AMS version of \"" .. Machine.name .. "\" now.")

        local AMSMachine = CreateAMSMachine(Machine)
        if AMSMachine == nil then
            goto continue_Machine
        end

        local AMSMachineItem = CreateAMSMachineItem(Machine, AMSMachine)
        local AMSMachineRecipe = CreateAMSMachineRecipe(Machine, AMSMachine)
        local AMSMachineTechnology = CreateAMSMachineTech(Machine, AMSMachine)

        table.insert(NewEntities, AMSMachine)
        table.insert(NewEntities, AMSMachineItem)
        table.insert(NewEntities, AMSMachineRecipe)
        table.insert(NewEntities, AMSMachineTechnology)

        table.insert(NewRecipies, AMSMachineRecipe)
        CondLog("Made AMS version of \"" .. Machine.name .. "\".")

        ::continue_Machine::
    end
    ::continue_MachineType::
end

if #NewEntities > 0 then
    data:extend(NewEntities)
end

for _,Recipe in pairs(NewRecipies) do
    RecyclingLibrary.generate_recycling_recipe(Recipe)
end