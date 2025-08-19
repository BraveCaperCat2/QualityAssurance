-- Returns the value of the setting with the provided name, or nil if it doesn't exist. Prefix should not be provided.
local function config(name)
    if settings.startup['qa_' .. name] then
        return settings.startup['qa_' .. name].value
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

local MachineTypes = {"crafting-machine", "furnace", "assembling-machine", "mining-drill", "rocket-silo"}

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