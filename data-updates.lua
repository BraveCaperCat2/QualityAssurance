-- Provides dataConfig, CondLog, Empty functions
require("utils")

EnableCraftingSpeedFunction = true

-- A list of entity names to be skipped over when creating AMS machines.
local AMSBlocklist = {"awesome-sink-gui", "oil_rig_migration", "elevated-pipe", "yir_factory_stuff", "yir_diesel_monument", "yir_future_monument", "energy-void", "passive-energy-void", "fluid-source", "mining-depot"}

-- A list of entity names to be skipped over when modifying the fixed_recipe and fixed_quality properties.
local UnfixedRSRBlocklist = {"planet-hopper-launcher"}

-- A list of entity names to be skipped over when adding Base Quality.
local BaseQualityBlockList = {}

function GetCraftingSpeedMultiplier(ModuleSlotDifference)
    -- A new crafting speed function. Equivalent to the square root of 0.8 to the power of the module slot difference, rounded up to the nearest hundreth.
    return math.ceil(math.pow(0.8, ModuleSlotDifference / 2) * 100) / 100
end

-- Thank you, A.Freeman (from the mod portal) for providing me with this now updated localisation system.
-- The function part was my idea though and I've collapsed most of the indentation.
local function Localiser(AMS, Machine, removedSlots)
    local LocalisationKey = ""
    local LocalisationParameter = {}
    -- RMS vs AMS distinction
    if removedSlots then
        LocalisationKey = LocalisationKey .. "rms."
    else
        LocalisationKey = LocalisationKey .. "ams."
    end

    -- Technology distinction
    if AMS.type == "technology" then
        LocalisationKey = LocalisationKey .. "tech-"
    else
        LocalisationKey = LocalisationKey .. ""
    end

    -- Localised name vs no localised name distinction
    if not Empty(Machine.localised_name) then
        LocalisationParameter = Machine.localised_name
    else
        table.insert(LocalisationParameter, "entity-name."..Machine.name)
    end

    -- Actually add the localisation
    AMS.localised_name = {LocalisationKey .. "name", LocalisationParameter}
    AMS.localised_description = {LocalisationKey .. "description", LocalisationParameter}
    
    return AMS
end

-- Thank you, A.Freeman (from the mod portal) for providing me with this new prerequisites system. 
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

-- Splits a string by a pattern.
function Split(str, delim, maxNb)
    if not str then
        return {}
    end
    if string.find(str, delim) == nil then
        return { str }
    end
    if maxNb == nil or maxNb < 1 then
        maxNb = 0
    end
    local result = {}
    local pat = "(.-)" .. delim .. "()"
    local nb = 0
    local lastPos
    for part, pos in string.gfind(str, pat) do
        nb = nb + 1
        result[nb] = part
        lastPos = pos
        if nb == maxNb then
            break
        end
    end
    if nb ~= maxNb then
        result[nb + 1] = string.sub(str, lastPos)
    end
    return result
end

function ListToString(List)
    local result = {}
    if List ~= nil then
        for _,Effect in pairs(List) do
            if Effect.name ~= nil then
                table.insert(result, Effect.name)
            elseif Effect.type ~= nil then
                if Effect.type == "unlock-quality" then
                    table.insert(result, "quality:" .. Effect.quality)
                elseif Effect.type == "unlock-recipe" then
                    table.insert(result, "recipe:" .. Effect.recipe)
                else
                    table.insert(result, "\"" .. Effect.type .. "\"")
                end
            else
                table.insert(result, serpent.block(Effect))
            end
        end
    end
    return table.concat(result, ", ")
end


local function CleanNils(t)
    local ans = {}
    for _,v in pairs(t) do
      ans[ #ans+1 ] = v
    end
    return ans
end


local Technologies = data.raw["technology"]
local Qualities = data.raw["quality"]

-- Build Prerequisites table so we can do a fast update of tech dependencies:
-- key is a prerequisite for every tech in value list
local Prerequisites = {}
for i,Technology in pairs(Technologies) do
    -- log("Tech tree " .. i .. " " .. serpent.block(Technology))
    Prerequisites[Technology.name] = {}
end
for i,Technology in pairs(Technologies) do
    if type(Technology) == "table" and type(Technology.prerequisites) == "table" then
        for j,Prerequisite in pairs(Technology.prerequisites) do
            -- Sometimes, this issue randomly occurs where Prerequisites[Prerequisite] is nil. I have no idea how it occurs just yet, this is intended to help find out.
            if Prerequisites[Prerequisite] == nil then
                error("Cannot find prerequisite " .. Prerequisite .. " of technology " .. Technology.name .. ". This is NOT an issue with QA!")
            end

            table.insert(Prerequisites[Prerequisite], Technology.name)
        end
    end
end

-- Build Order table with property:
-- if TechA depends on TechB, then Order[TechA] > Order[TechB]
-- It is used in MoveQualities function to check that 
--  we won't move quality unlocks to later technologies
local Order = {}
function UpdateOrder(Tech)
    local Technology, Name
    if type(Tech) == "table" then
        Technology = Tech
        Name = Tech.name
    else
        Technology = Technologies[Tech]
        Name = Tech
    end
    if Order[Name] > 0 or Empty(Technology.prerequisites) then
        -- Order was initialized
        return Order[Name]
    end
    if Order[Name] == -1 then
        CondLog("Found dependency cycle for tech " .. Name)
        return 0
    end
    if type(Technology.prerequisites) == "table" then
        -- CondLog(Name .. " prerequisites: " .. ListToString(Technology.prerequisites))
        local max = 0
        -- Mark as visited to prevent cycling
        Order[Name] = -1
        for _,Prerequisite in pairs(Technology.prerequisites) do
            local order = UpdateOrder(Prerequisite)
            if order + 1 > max then
                max = order + 1
            end
        end
        Order[Name] = max
    end
    -- CondLog(Name .. " has order " .. tostring(Order[Name]))
    return Order[Name]
end

for i,Technology in pairs(Technologies) do
    Order[Technology.name] = 0
end
for Name,Val in pairs(Order) do
    if Val == 0 then
        UpdateOrder(Name)
    end
end

-- Add all qualities to the selected Technology, and remove quality technologies with no effect.
-- Thank you, wvlad for providing me with this new effect movement and technology removal system. 
-- Updated by A.Freeman

-- Technology that will unlock qualities
local QualityTechnologyName = dataConfig("quality-unlock")
local QualityTechOrder = Order[QualityTechnologyName]
-- If not empty, pick a quality with the highest level - all qualities up to that will be unlocked by the abovementioned technology
local EarlyQualityFilter = Split(dataConfig("early-quality-filter"), ",%w*")
local EarlyQualityLevel = 0
local EarlyQualityName = nil
CondLog("EarlyQualityFilter string: \"" .. dataConfig("early-quality-filter") .. "\" filter: " .. serpent.block(EarlyQualityFilter))
for i,Name in pairs(EarlyQualityFilter) do
    local name = string.lower(Name)
    if Qualities[name] ~= nil and EarlyQualityLevel < Qualities[name].level then
        EarlyQualityLevel = Qualities[name].level
        EarlyQualityName = name
    end
end
if EarlyQualityLevel == 0 then
    EarlyQualityLevel = 100500 -- aka infinity :D
end

function MoveQualities(Technology)
    if type(Technology) ~= "table" or type(Technology.effects) ~= "table" then
        return false
    end
    if Technology.name == QualityTechnologyName then
        return false
    end
    local Moved = false
    TechOrder = Order[Technology.name]
    for j,Effect in pairs(Technology.effects) do
        -- Effect unlocks quality
        -- Quality Technology order is lower than the current technology's 
        -- Check if the current quality level is <= EarlyQualityLevel
        if Effect.type == "unlock-quality" then
            if QualityTechOrder <= TechOrder and Qualities[Effect.quality].level <= EarlyQualityLevel then
                table.insert(Technologies[QualityTechnologyName].effects, Effect)
                Technology.effects[j] = nil
                Moved = true
                CondLog("Moved quality \"" .. Effect.quality .. "\" to Technology \"" .. QualityTechnologyName .. "\"")
            else
                local Values = table.concat({tostring(QualityTechOrder), tostring(TechOrder), tostring(Qualities[Effect.quality].level), tostring(EarlyQualityLevel)}, " ")
                if QualityTechOrder <= TechOrder and Qualities[EarlyQualityName] and Qualities[EarlyQualityName].next == Effect.quality then
                    -- QualityTechnology unlocks all qualities up to EarlyQuality 
                    -- But Technology unlocks the next quality of EarlyQuality 
                    -- So add QualityTechnology as prerequisite to Technology
                    local Contains = false
                    for _,Prerequisite in pairs(Technology.prerequisites) do
                        if Prerequisite == QualityTechnologyName then
                            Contains = true
                        end
                    end
                    if not Contains then
                        table.insert(Technology.prerequisites, QualityTechnologyName)
                        table.insert(Prerequisites[QualityTechnologyName], Technology.name)
                        CondLog("Skipped quality \"" .. Effect.quality .. "\" with order/level values: " .. Values)
                        CondLog("Added prerequisite \"" .. QualityTechnologyName .. "\" to Technology \"" .. Technology.name .. "\"")
                    end
                else
                    CondLog("Skipped quality \"" .. Effect.quality .. "\" because of wrong order/level values: " .. Values)
                end
            end
        end
    end
    if Moved and Technology.effects ~= nil then
        Technology.effects = CleanNils(Technology.effects)
    end
    return Moved
end

CondLog("Adding Quality unlocks to \"".. QualityTechnologyName .."\" technology.")
-- TechnologiesToBeRemoved is a table that will contain TechName:Tech pairs
local TechnologiesToBeRemoved = {}
for i,Technology in pairs(data.raw["technology"]) do
    if Technology.name ~= QualityTechnologyName then
        CondLog("Technology \"" .. Technology.name .. "\" has effects: " .. ListToString(Technology.effects))
        if MoveQualities(Technology) then
            if Technology.effects == nil or #Technology.effects == 0 then
                CondLog("All effects of Technology \"" .. Technology.name .. "\" have been moved.")
                TechnologiesToBeRemoved[Technology.name] = Technology
            end
        end
    
    end
end

-- Update technology dependencies
--
-- Prerequisite is to be removed
-- Tech has Prerequisite in Tech.prerequisites
-- Remove Prerequisite from Tech.prerequisites
-- Add Prerequisite.prerequisites to Tech.Prerequisites
-- Remove Prerequisite technology
CondLog("Technologies to be removed: " .. ListToString(TechnologiesToBeRemoved))
for PrerequisiteName,Prerequisite in pairs(TechnologiesToBeRemoved) do
    -- Prerequisite is to be removed
    for _,TechName in pairs(Prerequisites[PrerequisiteName]) do
        -- Tech has Prerequisite in Tech.prerequisites
        Tech = data.raw["technology"][TechName]
        local AddDependencies = {}
        for p,TechPrerequisiteName in pairs(Tech.prerequisites) do
            if TechPrerequisiteName == PrerequisiteName then
                -- Remove Prerequisite from Tech.prerequisites
                table.remove(Tech.prerequisites, p)
                -- Add dependencies from Prerequisite to Tech
                if not Empty(Prerequisite.prerequisites) then
                    for _,AddDependencyName in pairs(Prerequisite.prerequisites) do
                        table.insert(AddDependencies, AddDependencyName)
                    end
                end
            end
        end
        -- Add dependencies from Prerequisite to Tech
        for _, AddDependency in pairs(AddDependencies) do
            table.insert(Tech.prerequisites, AddDependency)
            table.insert(Prerequisites[AddDependency], Tech.name)
            -- Compatibility fix for Infinite Quality Tiers
            Tech.enabled = true
        end
    end
    -- Remove Prerequisite technology
    data.raw["technology"][PrerequisiteName] = nil
end

--[[ -- No longer needed as of 1.4.1. Try returning this code if something breaks.
local function NAMSModifications(Machine)
    local NAMSMachine = data.raw[Machine.type][Machine.NAMSMachine]
    Machine.category = NAMSMachine.category
    return Machine
end

local MachineTypes = {"assembling-machine", "furnace", "mining-drill", "rocket-silo"}

CondLog("Initiating more operations on automated crafting.")
for _,MachineType in pairs(MachineTypes) do
    if data.raw[MachineType] ~= nil then
        for j,Machine in pairs(data.raw[MachineType]) do
            CondLog("Re-scanning Machine \"" .. Machine.name .. "\" now.")

            if string.find(Machine.name, "qa_") and string.find(Machine.name, "-ams") then

                -- Update the AMSMachine with certain modifications from the base machine.
                Machine = NAMSModifications(Machine)

                data.raw[MachineType][j] = Machine
            end
        end
    end
end
]]

-- Code to generate relabeler recipes. It'll only work once I can make quality-dependent recipes and results and update the code here.
-- Then I can enable the relabeler setting in settings.lua to make it work.
if dataConfig("relabeler") then
    -- The relabeler, decreases the quality of an item by 1 tier. Does nothing to normal quality items.
    CondLog("Creating relabeler recipes.")
    local function GetLowerQuality(HigherQuality)
        local LowerQuality
        local LowestQuality
        for _,Quality in pairs(data.raw["quality"]) do
            if not LowestQuality or Quality.level < LowestQuality.level then
                LowestQuality = Quality
            end
            if Quality.next == HigherQuality.name then
                LowerQuality = Quality
                break
            end
        end
        if not LowerQuality then
            LowerQuality = LowestQuality
        end
        return LowerQuality
    end
    for _,Item in pairs(data.raw["item"]) do
        if Item.hidden or Item.parameter then
            goto ItemContinue
        end
        for _,Quality in pairs(data.raw["quality"]) do
            if Quality.hidden or Quality.parameter then
                goto QualityContinue
            end
            local Recipe = {}
            Recipe.name = Item.name .. "-relabeling-" .. Quality.name
            Recipe.type = "recipe"
            Recipe.category = "relabeling"
            Recipe.subgroup = Item.subgroup
            Recipe.enabled = true
            local LowerQuality = GetLowerQuality(Quality)
            
            local Key
            local Param1
            local Param2
            local Param3

            if Empty(Item.localised_name) then
                Param1 = {"item-name." .. Item.name}
            else
                Param1 = Item.localised_name
            end

            if Empty(Quality.localised_name) then
                Param2 = {"quality-name." .. Quality.name}
            else
                Param2 = Quality.localised_name
            end

            if LowerQuality.next ~= Quality.name then
                -- Fallback case, input is of lowest quality
                -- Need 2.1 features in order to specify recipe quality
                Recipe.ingredients = {{type = "item", name = Item.name, amount = 1}}
                Recipe.results = {{type = "item", name = Item.name, amount = 1}}

                Key = "-normal"

            else -- If a lower quality was found.
                -- Normal case, LowerQuality represents the previous quality
                -- Need 2.1 features in order to specify recipe quality
                Recipe.ingredients = {{type = "item", name = Item.name, amount = 1}}
                Recipe.results = {{type = "item", name = Item.name, amount = 1}}

                if Empty(LowerQuality) then
                    Param3 = {"quality-name." .. LowerQuality.name}
                else
                    Param3 = LowerQuality.localised_name
                end

                Key = ""
            end

            if Param3 then
                Recipe.localised_name = {"relabeler.relabeling-name" .. Key, Param1, Param2, Param3}
                Recipe.localised_description = {"relabeler.relabeling-description" .. Key, Param1, Param2, Param3}
            else
                Recipe.localised_name = {"relabeler.relabeling-name" .. Key, Param1, Param2}
                Recipe.localised_description = {"relabeler.relabeling-description" .. Key, Param1, Param2}
            end
            data.extend({Recipe})
            ::QualityContinue::
        end
        ::ItemContinue::
    end
end

-- Code to generate upcycler recipes. It'll only work once I can make quality-dependent recipes and results and update the code here.
-- Then I can enable the upcycler setting in settings.lua to make it work.
if dataConfig("upcycler") then
    -- The upcycler, has a chance to increase the quality of an item by 1 tier, as well as chances to leave the item as-is and turn the item into scrap.
    CondLog("Creating upcycler recipes.")
    local function GetHigherQuality(LowerQuality)
        local HigherQuality
        local HighestQuality
        for _,Quality in pairs(data.raw["quality"]) do
            if not HighestQuality or Quality.level > HighestQuality.level then
                HighestQuality = Quality
            end
            if LowerQuality.next == Quality.name then
                HigherQuality = Quality
                break
            end
        end
        if not HigherQuality then
            HigherQuality = HighestQuality
        end
        return HigherQuality
    end
    local function QualityLevelToProbability(QualityLevel)
        local HighestQuality
        for _,Quality in pairs(data.raw["quality"]) do
            if not HighestQuality or Quality.level > HighestQuality.level then
                HighestQuality = Quality
            end
        end

        -- Provided by "mmmPI" on the factorio forums. Just not for this specific purpose. Thank you!
        -- Maps low1 onto low2, high1 onto high2 and values between low1 and high1 onto values between low2 and high2.
        -- low2 + (value - low1) * (high2 - low2) / (high1 - low1)
        return 30 + (QualityLevel - 0) * (49 - 30) / (HighestQuality.level - 0)

    end
    for _,Item in pairs(data.raw["item"]) do
        if Item.hidden or Item.parameter then
            goto ItemContinue
        end
        for _,Quality in pairs(data.raw["quality"]) do
            if Quality.hidden or Quality.parameter then
                goto QualityContinue
            end
            local Recipe = {}
            Recipe.name = Item.name .. "-upcycling-" .. Quality.name
            Recipe.type = "recipe"
            Recipe.category = "upcycling"
            Recipe.subgroup = Item.subgroup
            Recipe.enabled = true
            local HigherQuality = GetHigherQuality(Quality)
            if Quality.next ~= HigherQuality.name then -- If a higher quality could not be found.
                Recipe.ingredients = {{type = "item", name = Item.name, amount = 1}}
                Recipe.results = {{type = "item", name = Item.name, amount = 1}}
                Recipe.icon = Item.icon
                Recipe.icon_size = Item.icon_size
                Recipe.icons = Item.icons
                
                if not Empty(Item.localised_name) then
                    if not Empty(Quality.localised_name) then
                        Recipe.localised_name = {"upcycler.upcycling-name-legendary", Item.localised_name, Quality.localised_name}
                        Recipe.localised_description = {"upcycler.upcycling-description-legendary", Item.localised_name, Quality.localised_name}
                    else
                        Recipe.localised_name = {"upcycler.upcycling-name-legendary", Item.localised_name, {"quality-name." .. Quality.name}}
                        Recipe.localised_description = {"upcycler.upcycling-description-legendary", Item.localised_name, {"quality-name." .. Quality.name}}
                    end
                else
                    if not Empty(Quality.localised_name) then
                        Recipe.localised_name = {"upcycler.upcycling-name-legendary", {"item-name." .. Item.name}, Quality.localised_name}
                        Recipe.localised_description = {"upcycler.upcycling-description-legendary", {"item-name." .. Item.name}, Quality.localised_name}
                    else
                        Recipe.localised_name = {"upcycler.upcycling-name-legendary", {"item-name." .. Item.name}, {"quality-name." .. Quality.name}}
                        Recipe.localised_description = {"upcycler.upcycling-description-legendary", {"item-name." .. Item.name}, {"quality-name." .. Quality.name}}
                    end
                end
            else -- If a higher quality was found.
                Recipe.ingredients = {{type = "item", name = Item.name, amount = 1}}
                Recipe.results = {
                    {type = "item", name = Item.name, probability = (50 - QualityLevelToProbability(Quality.level)) / 100, amount = 1}, -- Increase Quality
                    {type = "item", name = Item.name, probability = 0.5, amount = 1} -- Fail softly
                    -- Fail hardly (results in nothing)
                }
                Recipe.icon = Item.icon
                Recipe.icon_size = Item.icon_size
                Recipe.icons = Item.icons
                
                if not Empty(Item.localised_name) then
                    if not Empty(Quality.localised_name) then
                        Recipe.localised_name = {"upcycler.upcycling-name", Item.localised_name, Quality.localised_name}
                        if not Empty(HigherQuality.localised_name) then
                            Recipe.localised_description = {"upcycler.upcycling-description", Item.localised_name, Quality.localised_name, HigherQuality.localised_name}
                        else
                            Recipe.localised_description = {"upcycler.upcycling-description", Item.localised_name, Quality.localised_name, {"quality-name." .. HigherQuality.name}}
                        end
                    else
                        Recipe.localised_name = {"upcycler.upcycling-name", Item.localised_name, {"quality-name." .. Quality.name}}
                        if not Empty(HigherQuality.localised_name) then
                            Recipe.localised_description = {"upcycler.upcycling-description", Item.localised_name, {"quality-name." .. Quality.name}, HigherQuality.localised_name}
                        else
                            Recipe.localised_description = {"upcycler.upcycling-description", Item.localised_name, {"quality-name." .. Quality.name}, {"quality-name." .. HigherQuality.name}}
                        end
                    end
                else
                    if not Empty(Quality.localised_name) then
                        Recipe.localised_name = {"upcycler.upcycling-name", {"item-name." .. Item.name}, Quality.localised_name}
                        if not Empty(HigherQuality.localised_name) then
                            Recipe.localised_description = {"upcycler.upcycling-description", {"item-name." .. Item.name}, Quality.localised_name, HigherQuality.localised_name}
                        else
                            Recipe.localised_description = {"upcycler.upcycling-description", {"item-name." .. Item.name}, Quality.localised_name, {"quality-name." .. HigherQuality.name}}
                        end
                    else
                        Recipe.localised_name = {"upcycler.upcycling-name", {"item-name." .. Item.name}, {"quality-name." .. Quality.name}}
                        if not Empty(HigherQuality.localised_name) then
                            Recipe.localised_description = {"upcycler.upcycling-description", {"item-name." .. Item.name}, {"quality-name." .. Quality.name}, HigherQuality.localised_name}
                        else
                            Recipe.localised_description = {"upcycler.upcycling-description", {"item-name." .. Item.name}, {"quality-name." .. Quality.name}, {"quality-name." .. HigherQuality.name}}
                        end
                    end
                end
            end
            CondLog(serpent.block(Recipe))
            data.extend({Recipe})
            ::QualityContinue::
        end
        ::ItemContinue::
    end
end

-- Add base quality for a machine
local function AddQuality(Machine)
    if not dataConfig("base-quality") then
        CondLog("Base Quality setting is disabled. Skipping.")
        return Machine
    end

    if not dataConfig("moduleless-quality") then
        if Machine.module_slots == nil or Machine.module_slots == 0 then
            CondLog("Moduleless Quality setting is disabled, and this machine doesn't have module slots. Skipping.")
            return
        end
    end
    local BaseQuality = false
    NormalProbability = data.raw.quality["normal"].next_probability or 1

    Machine.effect_receiver = Machine.effect_receiver or {}
    Machine.effect_receiver.base_effect = Machine.effect_receiver.base_effect or {}
    Machine.effect_receiver.base_effect.quality = Machine.effect_receiver.base_effect.quality or 0
    if Machine.effect_receiver.base_effect.quality == 0 then
        CondLog("Machine does not contain base quality. Adding base quality.")
        Machine.effect_receiver.base_effect.quality = dataConfig("base-quality-value") / 100 / NormalProbability
    else
        CondLog("Machine contains base quality of amount " .. Machine.effect_receiver.base_effect.quality or 0 ..". Skipping.")
    end
end

-- Enables quality effects for a machine
local function EnableQuality(Machine)
    if Machine.allowed_effects then
        if type(Machine.allowed_effects) == "string" then
            Machine.allowed_effects = {Machine.allowed_effects}
        end
        local hasquality = false
        for _, AllowedEffect in pairs(Machine.allowed_effects) do
            if AllowedEffect == "quality" then
                hasquality = true
            end
        end
        if hasquality == false then
            table.insert(Machine.allowed_effects, "quality")
        end
    end
    
end

-- Enables all effect sources for a machine
-- Do NOT call this function on beacon prototypes
local function EnableEffectSources(Machine)
    -- Enable beacon/module/surface effects
    Machine.effect_receiver = Machine.effect_receiver or {}
    Machine.effect_receiver.uses_beacon_effects = true
    Machine.effect_receiver.uses_module_effects = true
    Machine.effect_receiver.uses_surface_effects = true
end

local RecyclingLibrary = require("__quality__.prototypes.recycling")

-- Perform operations on automated crafting.
local MachineTypes = {"assembling-machine", "furnace", "mining-drill", "rocket-silo"}

CondLog("Performing operations on Automated Crafting.")
for _,MachineType in pairs(MachineTypes) do
    if data.raw[MachineType] then
        for j,Machine in pairs(data.raw[MachineType]) do
            if Machine == nil then
                error("Invalid prototype \"nil\" in data.raw[" .. MachineType .. "]. This is NOT an issue with QA!")
            end

            local AMSBanned = false
            local UnfixedRSRBanned = false
            local BaseQualityBanned = false

            for _,EntityName in pairs(AMSBlocklist) do
                if Machine.name == EntityName then
                    AMSBanned = true
                end
            end

            for _,EntityName in pairs(UnfixedRSRBlocklist) do
                if Machine.name == EntityName then
                    UnfixedRSRBanned = true
                end
            end

            for _,EntityName in pairs(BaseQualityBlockList) do
                if Machine.name == EntityName then
                    BaseQualityBanned = true
                end
            end

            if Machine.no_ams == true then
                AMSBanned = true
            end

            if Machine.no_unfixed_rsr == true then
                UnfixedRSRBanned = true
            end

            if Machine.no_bq == true then
                BaseQualityBanned = true
            end

            if MachineType == "rocket-silo" then
                CondLog("Checking for rocket silo \"" .. Machine.name .. "\" for being banned from Unfixed Rocket Silo Recipes.")
                if data.raw["recipe"][Machine.fixed_recipe] and not next(data.raw["recipe"][Machine.fixed_recipe].ingredients) then
                    UnfixedRSRBanned = true
                end
                if data.raw["recipe"][Machine.fixed_recipe] and data.raw["recipe"][Machine.fixed_recipe].hidden then
                    data.raw["recipe"][Machine.fixed_recipe].hidden = false
                    data.raw["recipe"][Machine.fixed_recipe].hidden_in_factoriopedia = true
                    data.raw["recipe"][Machine.fixed_recipe].hide_from_player_crafting = true
                end
            end

            if AMSBanned then
                CondLog("Machine \"" .. Machine.name .. "\" is banned from AMS!")
            end
            
            if UnfixedRSRBanned then
                CondLog("Machine \"" .. Machine.name .. "\" is banned from Unfixed Rocket Silo Recipes!")
            end

            if BaseQualityBanned then
                CondLog("Machine \"" .. Machine.name .. "\" is banned from Base Quality Addition!")
            end

            CondLog("Scanning Machine \"" .. Machine.name .. "\" now.")
            
            if MachineType ~= "rocket-silo" then
                if (not dataConfig("ams-base-quality-toggle")) and dataConfig("enable-base-quality-" .. MachineType) and (not BaseQualityBanned) then
                    AddQuality(Machine)
                end
                EnableQuality(Machine)
                EnableEffectSources(Machine)
            elseif not UnfixedRSRBanned then
                data.raw[MachineType][j].fixed_recipe = nil
                data.raw[MachineType][j].fixed_quality = nil
            end

            -- Create a new version of all machines which don't have additional module slots.
            if ( not string.find(Machine.name, "qa_") ) and dataConfig("ams-machines-toggle") and ( not AMSBanned ) and (dataConfig("enable-ams-" .. MachineType)) then
                CondLog("Creating AMS version of \"" .. Machine.name .. "\" now.")
                local AMSMachine = table.deepcopy(Machine)
                AMSMachine.name = "qa_" .. AMSMachine.name .. "-ams"

                if dataConfig("ams-base-quality-toggle") then
                    AddQuality(AMSMachine)
                end

                if AMSMachine.module_slots == nil then
                    AMSMachine.module_slots = 0
                end

                local AddedModuleSlots = dataConfig("added-module-slots")
                local SpeedMultiplier = 1

                local RemovingSlots = false

                if EnableCraftingSpeedFunction == true then
                    -- Check for removing more slots than the machine has.
                    -- This would cause the machine to have negative module slots, which is bad.
                    -- Instead, remove as many as possible.
                    if AddedModuleSlots + AMSMachine.module_slots < 0 then
                        AddedModuleSlots = -AMSMachine.module_slots
                    end

                    if AddedModuleSlots == 0 then
                        CondLog("Cancelling AMS machine creation, as no module slots would be added or removed.")
                        goto Continue
                    end

                    -- Check for removing any slots at all.
                    -- Removing slots will increase the crafting speed of the machine and change locales.
                    if AddedModuleSlots < 0 then
                        CondLog("Machine will have increased speed due to removing modules.")
                        RemovingSlots = true
                    end

                    -- Calculate the speed multiplier and add/remove module slots.
                    SpeedMultiplier = GetCraftingSpeedMultiplier(AddedModuleSlots)
                    AMSMachine.module_slots = AMSMachine.module_slots + AddedModuleSlots
                else
                    AddedModuleSlots = 2
                    AMSMachine.module_slots = AMSMachine.module_slots + AddedModuleSlots
                    SpeedMultiplier = 0.8
                end

                -- Decrease/increase crafting speed.
                if AMSMachine.crafting_speed then
                    AMSMachine.crafting_speed = AMSMachine.crafting_speed * SpeedMultiplier
                elseif AMSMachine.mining_speed then
                    AMSMachine.mining_speed = AMSMachine.mining_speed * SpeedMultiplier
                elseif AMSMachine.researching_speed then
                    AMSMachine.researching_speed = AMSMachine.researching_speed * SpeedMultiplier
                end

                AMSMachine = Localiser(AMSMachine, Machine, RemovingSlots)

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
                AMSMachineItem = Localiser(AMSMachineItem, Machine, RemovingSlots)
                AMSMachineItem.stack_size = 50
                AMSMachineItem.place_result = AMSMachine.name
                AMSMachine.MachineItem = AMSMachineItem.name

                local AMSMachineRecipe = {}
                AMSMachineRecipe.name = AMSMachineItem.name
                AMSMachineRecipe.type = "recipe"
                AMSMachineRecipe = Localiser(AMSMachineRecipe, Machine, RemovingSlots)
                if Machine.MachineItem == nil and Machine.minable then
                    if Machine.minable.result and Machine.minable.result ~= "" then
                        AMSMachineRecipe.ingredients = {{type = "item", name = Machine.minable.result, amount = 1}, {type = "item", name = "steel-plate", amount = 10}, {type = "item", name = "copper-cable", amount = 20}}
                    else
                        if data.raw["item"][Machine.name] then
                            AMSMachineRecipe.ingredients = {{type = "item", name = Machine.name, amount = 1}, {type = "item", name = "steel-plate", amount = 10}, {type = "item", name = "copper-cable", amount = 20}}
                        else
                            AMSMachineRecipe.ingredients = {{type = "item", name = "electronic-circuit", amount = 1}, {type = "item", name = "steel-plate", amount = 10}, {type = "item", name = "copper-cable", amount = 20}}
                        end
                    end
                else
                    AMSMachineRecipe.ingredients = {{type = "item", name = Machine.MachineItem, amount = 1}, {type = "item", name = "steel-plate", amount = 10}, {type = "item", name = "copper-cable", amount = 20}}
                end

                if AMSMachineRecipe.ingredients[1]["name"] == nil then
                    AMSMachineRecipe.ingredients[1]["name"] = "electronic-circuit"
                    CondLog("Had to replace ingredient name for \"" .. AMSMachineRecipe.name .. "\"")
                end

                AMSMachineRecipe.results = {{type = "item", name = AMSMachineItem.name, amount = 1}}
                AMSMachineRecipe.category = "crafting"
                AMSMachineRecipe.enabled = false
                
                local AMSMachineTechnology = table.deepcopy(data.raw["technology"]["automation-2"])
                AMSMachineTechnology.name = AMSMachine.name
                -- Thank you, A.Freeman (from the mod portal) for providing me this new prerequisites system. 
                local Prerequisite = GetMachineTechnology(Machine)
                local AMSPrerequisiteTechs = {"steel-processing", "electronics"}
                if Prerequisite then
                    -- Check if the prerequisite is one of the defaults
                    if Prerequisite ~= "steel-processing" and Prerequisite ~= "electronics" then
                        table.insert(AMSMachineTechnology.prerequisites, Prerequisite)
                    end

                    -- Get the tech corrosponding to the prerequisite
                    PrerequisiteTech = data.raw["technology"][Prerequisite]

                    -- Copy prerequisite icon
                    if PrerequisiteTech.icon and PrerequisiteTech.icon ~= "" then
                        AMSMachineTechnology.icon = PrerequisiteTech.icon
                        AMSMachineTechnology.icon_size = PrerequisiteTech.icon_size
                    elseif PrerequisiteTech.icons and PrerequisiteTech.icons ~= {} then
                        AMSMachineTechnology.icons = PrerequisiteTech.icons
                    end

                    -- Copy prerequisite unit/research trigger
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
                    AMSMachineTechnology.research_trigger = {type = "build-entity", entity = {name = Machine.name}}
                    AMSMachineTechnology.unit = nil
                end

                if dataConfig("ams-machines-unlock") ~= "none" then
                    table.insert(AMSPrerequisiteTechs, dataConfig("ams-machines-unlock"))
                end

                AMSMachineTechnology.prerequisites = AMSPrerequisiteTechs
                AMSMachineTechnology.effects = {{type = "unlock-recipe", recipe = AMSMachineRecipe.name}}
                AMSMachineTechnology = Localiser(AMSMachineTechnology, Machine, RemovingSlots)

                CondLog("Made AMS version of \"" .. Machine.name .. "\".")
                data:extend{AMSMachine, AMSMachineItem, AMSMachineRecipe, AMSMachineTechnology}

                RecyclingLibrary.generate_recycling_recipe(AMSMachineRecipe)
                ::Continue::
            elseif (not string.find(Machine.name, "qa_")) then
                CondLog("Skipping AMS for machine \"" .. Machine.name .. "\" because AMS machines are turned off, or this machine is banned.")
            end
        end
    end
end

-- Allow Quality Modules in Beacons.
if dataConfig("quality-beacons") then
    for _,Beacon in pairs(data.raw["beacon"]) do
        EnableQuality(Beacon)
    end
end

-- Improve power of all quality modules.
CondLog("Improving power of all quality modules.")
for _,Module in pairs(data.raw["module"]) do
    CondLog("Scanning module \"" .. Module.name .. "\" now.")
    if Module.effect.quality then
        if Module.effect.quality >= 0 then
            CondLog("Module \"" .. Module.name .. "\" contians a Quality increase. Increasing bonus.")
            Module.effect.quality = Module.effect.quality * dataConfig("quality-module-multiplier")
        end
    end
end

