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

local function NotEmpty(f)
    return f ~= nil and f ~= {} and f ~= ""
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
    if Order[Name] > 0 then
        -- Order was initialized
        return Order[Name]
    end
    if type(Technology.prerequisites) == "table" then
        local max = 0
        for _,Prerequisite in pairs(Technology.prerequisites) do
            local order = UpdateOrder(Prerequisite)
            if order + 1 > max then
                max = order + 1
            end
        end
        Order[Name] = max
    end
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
CondLog("EarlyQualityFilter string: " .. config("early-quality-filter") .. " filter: " .. serpent.block(EarlyQualityFilter))
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
                if NotEmpty(Prerequisite.prerequisites) then
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

            if string.find(Machine.name, "qa_") then

                -- Update the AMSMachine with certain modifications from the base machine.
                Machine = NAMSModifications(Machine)

                data.raw[MachineType][j] = Machine
            end
        end
    end
end
