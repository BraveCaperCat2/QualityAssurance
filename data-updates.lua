EnableCraftingSpeedFunction = true

-- Returns the value of the setting with the provided name, or nil if it doesn't exist. Prefix should not be provided.
local function config(name)
    if settings.startup['qa_' .. name] then
        return settings.startup['qa_' .. name].value
    end
    return nil
end

-- A list of entity names to be skipped over when creating AMS machines.
local AMSBlocklist = {"awesome-sink-gui", "oil_rig_migration", "elevated-pipe", "yir_factory_stuff", "yir_diesel_monument", "yir_future_monument", "energy-void", "passive-energy-void", "fluid-source"}

-- A list of entity names to be skipped over when modifying the fixed_recipe and fixed_quality properties.
local UnfixedRSRBlocklist = {"planet-hopper-launcher"}

-- A list of entity names to be skipped over when adding Base Quality.
local BaseQualityBlockList = {}

function GetCraftingSpeedMultiplier(ModuleSlotDifference)
    -- A new crafting speed function. Equivalent to the square root of 0.8 to the power of the module slot difference, rounded up to the nearest hundreth.
    return math.ceil(math.pow(0.8, ModuleSlotDifference / 2) * 100) / 100
end

local function Localiser(AMS, Machine, removedSlots)
    -- Thank you, A.Freeman (from the mod portal) for providing me with this new localisation system. The function part was my idea though. (If I ever add a supporters list, you'll be on it!)
    if not removedSlots then
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

local EnableLog = config("dev-mode")
function CondLog(str)
    if EnableLog then
        log(str)
    end
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

local function Empty(f)
    return f == nil or f == {} or f == ""
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
        for _,Prerequisite in pairs(Technology.prerequisites) do
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
-- Thank you, wvlad for providing me with this new effect movement and technology removal system. (If I ever add a supporters list, you'll be on it!)
-- Updated by A.Freeman

-- Technology that will unlock qualities
local QualityTechnologyName = config("quality-unlock")
local QualityTechOrder = Order[QualityTechnologyName]
-- If not empty, pick a quality with the highest level - all qualities up to that will be unlocked by the abovementioned technology
local EarlyQualityFilter = Split(config("early-quality-filter"), ",%w*")
local EarlyQualityLevel = 0
local EarlyQualityName = nil
CondLog("EarlyQualityFilter string: \"" .. config("early-quality-filter") .. "\" filter: " .. serpent.block(EarlyQualityFilter))
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

local function NAMSModifications(Machine)
    local NAMSMachine = data.raw[Machine.type][Machine.NAMSMachine]
    Machine.category = NAMSMachine.category
    return Machine
end

local MachineTypes = {"crafting-machine", "furnace", "mining-drill", "rocket-silo"}

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

-- Code to generate relabeler recipes. It'll only work once I can make quality-dependent recipes and results and update the code here.
-- Then I can enable the relabeler setting in settings.lua to make it work.
if config("relabeler") then
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
            if LowerQuality.next ~= Quality.name then -- If a lower quality could not be found.
                Recipe.ingredients = {{type = "item", name = Item.name, amount = 1}}
                Recipe.results = {{type = "item", name = Item.name, amount = 1}}
                
                if Item.localised_name and not Item.localised_name == {} and not Item.localised_name == "" then
                    if Quality.localised_name and not Quality.localised_name == {} and not Quality.localised_name == "" then
                        Recipe.localised_name = {"relabeler.relabeling-name-normal", {Item.localised_name}, {Quality.localised_name}}
                        Recipe.localised_description = {"relabeler.relabeling-description-normal", {Item.localised_name}, {Quality.localised_name}}
                    else
                        Recipe.localised_name = {"relabeler.relabeling-name-normal", {Item.localised_name}, {"quality-name." .. Quality.name}}
                        Recipe.localised_description = {"relabeler.relabeling-description-normal", {Item.localised_name}, {"quality-name." .. Quality.name}}
                    end
                else
                    if Quality.localised_name and not Quality.localised_name == {} and not Quality.localised_name == "" then
                        Recipe.localised_name = {"relabeler.relabeling-name-normal", {"item-name." .. Item.name}, {Quality.localised_name}}
                        Recipe.localised_description = {"relabeler.relabeling-description-normal", {"item-name." .. Item.name}, {Quality.localised_name}}
                    else
                        Recipe.localised_name = {"relabeler.relabeling-name-normal", {"item-name." .. Item.name}, {"quality-name." .. Quality.name}}
                        Recipe.localised_description = {"relabeler.relabeling-description-normal", {"item-name." .. Item.name}, {"quality-name." .. Quality.name}}
                    end
                end
            else -- If a lower quality was found.
                Recipe.ingredients = {{type = "item", name = Item.name, amount = 1}}
                Recipe.results = {{type = "item", name = Item.name, amount = 1}}
                
                if Item.localised_name and not Item.localised_name == {} and not Item.localised_name == "" then
                    if Quality.localised_name and not Quality.localised_name == {} and not Quality.localised_name == "" then
                        Recipe.localised_name = {"relabeler.relabeling-name", {Item.localised_name}, {Quality.localised_name}}
                        if LowerQuality.localised_name and not LowerQuality.localised_name == {} and not LowerQuality.localised_name == "" then
                            Recipe.localised_description = {"relabeler.relabeling-description", {Item.localised_name}, {Quality.localised_name}, {LowerQuality.localised_name}}
                        else
                            Recipe.localised_description = {"relabeler.relabeling-description", {Item.localised_name}, {Quality.localised_name}, {"quality-name." .. LowerQuality.name}}
                        end
                    else
                        Recipe.localised_name = {"relabeler.relabeling-name", {Item.localised_name}, {"quality-name." .. Quality.name}}
                        if LowerQuality.localised_name and not LowerQuality.localised_name == {} and not LowerQuality.localised_name == "" then
                            Recipe.localised_description = {"relabeler.relabeling-description", {Item.localised_name}, {"quality-name." .. Quality.name}, {LowerQuality.localised_name}}
                        else
                            Recipe.localised_description = {"relabeler.relabeling-description", {Item.localised_name}, {"quality-name." .. Quality.name}, {"quality-name." .. LowerQuality.name}}
                        end
                    end
                else
                    if Quality.localised_name and not Quality.localised_name == {} and not Quality.localised_name == "" then
                        Recipe.localised_name = {"relabeler.relabeling-name", {"item-name." .. Item.name}, {Quality.localised_name}}
                        if LowerQuality.localised_name and not LowerQuality.localised_name == {} and not LowerQuality.localised_name == "" then
                            Recipe.localised_description = {"relabeler.relabeling-description", {"item-name." .. Item.name}, {Quality.localised_name}, {LowerQuality.localised_name}}
                        else
                            Recipe.localised_description = {"relabeler.relabeling-description", {"item-name." .. Item.name}, {Quality.localised_name}, {"quality-name." .. LowerQuality.name}}
                        end
                    else
                        Recipe.localised_name = {"relabeler.relabeling-name", {"item-name." .. Item.name}, {"quality-name." .. Quality.name}}
                        if LowerQuality.localised_name and not LowerQuality.localised_name == {} and not LowerQuality.localised_name == "" then
                            Recipe.localised_description = {"relabeler.relabeling-description", {"item-name." .. Item.name}, {"quality-name." .. Quality.name}, {LowerQuality.localised_name}}
                        else
                            Recipe.localised_description = {"relabeler.relabeling-description", {"item-name." .. Item.name}, {"quality-name." .. Quality.name}, {"quality-name." .. LowerQuality.name}}
                        end
                    end
                end
            end
            data.extend({Recipe})
            ::QualityContinue::
        end
        ::ItemContinue::
    end
end

-- Code to generate upcycler recipes. It'll only work once I can make quality-dependent recipes and results and update the code here.
-- Then I can enable the upcycler setting in settings.lua to make it work.
if config("upcycler") then
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
                
                if Item.localised_name and not Item.localised_name == {} and not Item.localised_name == "" then
                    if Quality.localised_name and not Quality.localised_name == {} and not Quality.localised_name == "" then
                        Recipe.localised_name = {"upcycler.upcycling-name-legendary", {Item.localised_name}, {Quality.localised_name}}
                        Recipe.localised_description = {"upcycler.upcycling-description-legendary", {Item.localised_name}, {Quality.localised_name}}
                    else
                        Recipe.localised_name = {"upcycler.upcycling-name-legendary", {Item.localised_name}, {"quality-name." .. Quality.name}}
                        Recipe.localised_description = {"upcycler.upcycling-description-legendary", {Item.localised_name}, {"quality-name." .. Quality.name}}
                    end
                else
                    if Quality.localised_name and not Quality.localised_name == {} and not Quality.localised_name == "" then
                        Recipe.localised_name = {"upcycler.upcycling-name-legendary", {"item-name." .. Item.name}, {Quality.localised_name}}
                        Recipe.localised_description = {"upcycler.upcycling-description-legendary", {"item-name." .. Item.name}, {Quality.localised_name}}
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
                
                if Item.localised_name and not Item.localised_name == {} and not Item.localised_name == "" then
                    if Quality.localised_name and not Quality.localised_name == {} and not Quality.localised_name == "" then
                        Recipe.localised_name = {"upcycler.upcycling-name", {Item.localised_name}, {Quality.localised_name}}
                        if HigherQuality.localised_name and not HigherQuality.localised_name == {} and not HigherQuality.localised_name == "" then
                            Recipe.localised_description = {"upcycler.upcycling-description", {Item.localised_name}, {Quality.localised_name}, {HigherQuality.localised_name}}
                        else
                            Recipe.localised_description = {"upcycler.upcycling-description", {Item.localised_name}, {Quality.localised_name}, {"quality-name." .. HigherQuality.name}}
                        end
                    else
                        Recipe.localised_name = {"upcycler.upcycling-name", {Item.localised_name}, {"quality-name." .. Quality.name}}
                        if HigherQuality.localised_name and not HigherQuality.localised_name == {} and not HigherQuality.localised_name == "" then
                            Recipe.localised_description = {"upcycler.upcycling-description", {Item.localised_name}, {"quality-name." .. Quality.name}, {HigherQuality.localised_name}}
                        else
                            Recipe.localised_description = {"upcycler.upcycling-description", {Item.localised_name}, {"quality-name." .. Quality.name}, {"quality-name." .. HigherQuality.name}}
                        end
                    end
                else
                    if Quality.localised_name and not Quality.localised_name == {} and not Quality.localised_name == "" then
                        Recipe.localised_name = {"upcycler.upcycling-name", {"item-name." .. Item.name}, {Quality.localised_name}}
                        if HigherQuality.localised_name and not HigherQuality.localised_name == {} and not HigherQuality.localised_name == "" then
                            Recipe.localised_description = {"upcycler.upcycling-description", {"item-name." .. Item.name}, {Quality.localised_name}, {HigherQuality.localised_name}}
                        else
                            Recipe.localised_description = {"upcycler.upcycling-description", {"item-name." .. Item.name}, {Quality.localised_name}, {"quality-name." .. HigherQuality.name}}
                        end
                    else
                        Recipe.localised_name = {"upcycler.upcycling-name", {"item-name." .. Item.name}, {"quality-name." .. Quality.name}}
                        if HigherQuality.localised_name and not HigherQuality.localised_name == {} and not HigherQuality.localised_name == "" then
                            Recipe.localised_description = {"upcycler.upcycling-description", {"item-name." .. Item.name}, {"quality-name." .. Quality.name}, {HigherQuality.localised_name}}
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

local function AddQuality(Machine)
    -- Increase quality for a machine.
    if not config("base-quality") then
        CondLog("Base Quality setting is disabled. Skipping.")
        return Machine
    end

    if not config("moduleless-quality") then
        if Machine.module_slots == nil then
            CondLog("Moduleless Quality setting is disabled, and this machine doesn't have module slots. Skipping.")
            return Machine
        else
            if Machine.module_slots == 0 then
                CondLog("Moduleless Quality setting is disabled, and this machine doesn't have module slots. Skipping.")
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
                        CondLog("Machine does not contain base quality. Adding base quality.")
                        Machine.effect_receiver.base_effect.quality = config("base-quality-value") / 100 / NormalProbability
                    else
                        CondLog("Machine contains base quality of amount " .. Machine.effect_receiver.base_effect.quality or 0 ..". Skipping.")
                    end
                    BaseQuality = true
                else
                    CondLog("Machine does not contain base quality. Preparing to add base quality.")
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

local RecyclingLibrary = require("__quality__.prototypes.recycling")

-- Perform operations on automated crafting.
local MachineTypes = {"assembling-machine", "furnace", "mining-drill", "rocket-silo"}

CondLog("Performing operations on Automated Crafting.")
for _,MachineType in pairs(MachineTypes) do
    if data.raw[MachineType] then
        for j,Machine in pairs(data.raw[MachineType]) do

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
                if data.raw["recipe"][Machine.fixed_recipe] and data.raw["recipe"][Machine.fixed_recipe].ingredients == {} then
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
                if (not config("ams-base-quality-toggle")) and config("enable-base-quality-" .. MachineType) and (not BaseQualityBanned) then
                    Machine = AddQuality(Machine)
                end
                Machine = EnableQuality(Machine)
            elseif not UnfixedRSRBanned then
                data.raw[MachineType][j].fixed_recipe = nil
                data.raw[MachineType][j].fixed_quality = nil
            end

            data.raw[MachineType][j] = Machine

            -- Create a new version of all machines which don't have additional module slots.
            if ( not string.find(Machine.name, "qa_") ) and config("ams-machines-toggle") and ( not AMSBanned ) and (config("enable-ams-" .. MachineType)) then
                CondLog("Creating AMS version of \"" .. Machine.name .. "\" now.")
                local AMSMachine = table.deepcopy(Machine)
                AMSMachine.name = "qa_" .. AMSMachine.name .. "-ams"

                if config("ams-base-quality-toggle") then
                    AMSMachine = AddQuality(AMSMachine)
                end

                if AMSMachine.module_slots == nil then
                    AMSMachine.module_slots = 0
                end

                local AddedModuleSlots = config("added-module-slots")
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
                -- Thank you, A.Freeman (from the mod portal) for providing me this new prerequisites system. (If I ever add a supporters list, you'll be on it!)
                local Prerequisite = GetMachineTechnology(Machine)
                if Prerequisite then
                    if Prerequisite ~= "steel-processing" and Prerequisite ~= "electronics" then
                        AMSMachineTechnology.prerequisites = {Prerequisite, "steel-processing", "electronics"}
                    elseif Prerequisite == "steel-processing" and Prerequisite ~= "electronics" then
                        AMSMachineTechnology.prerequisites = {Prerequisite, "electronics"}
                    elseif Prerequisite ~= "steel-processing" and Prerequisite == "electronics" then
                        AMSMachineTechnology.prerequisites = {Prerequisite, "steel-processing"}
                    else
                        AMSMachineTechnology.prerequisites = {Prerequisite}
                    end
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
                AMSMachineTechnology = Localiser(AMSMachineTechnology, Machine, RemovingSlots)

                CondLog("Made AMS version of \"" .. Machine.name .. "\".")
                data:extend{AMSMachine, AMSMachineItem, AMSMachineRecipe, AMSMachineTechnology}

                RecyclingLibrary.generate_recycling_recipe(AMSMachineRecipe)
                ::Continue::
            else
                CondLog("Machine \"" .. Machine.name .. "\" is an AMS machine, AMS machines are turrend off, or this machine is banned. Skipping the AMS machine making process.")
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
CondLog("Improving power of all quality modules.")
for _,Module in pairs(data.raw["module"]) do
    CondLog("Scanning module \"" .. Module.name .. "\" now.")
    if Module.effect.quality then
        if Module.effect.quality >= 0 then
            CondLog("Module \"" .. Module.name .. "\" contians a Quality increase. Increasing bonus.")
            Module.effect.quality = Module.effect.quality * config("quality-module-multiplier")
        end
    end
end
