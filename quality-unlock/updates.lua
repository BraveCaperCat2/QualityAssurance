-- Provides Config, CondLog functions
require("common.utils")
-- Provides Split, ListToString, CleanNils, Empty
require("utils")


local Technologies = data.raw["technology"]
local Qualities = data.raw["quality"]

-- Technology that will unlock qualities
local QualityTechnologyName = Config("quality-unlock")
local QualityTechnology = Technologies[QualityTechnologyName]
-- If not empty, pick a quality with the highest level - all qualities up to that will be unlocked by the abovementioned technology
local EarlyQualityFilter = Split(Config("early-quality-filter"), ",%w*")

-- Add all qualities to the selected Technology, and remove quality technologies with no effect.
-- Thank you, wvlad for providing me with this new effect movement and technology removal system. 
-- (If I ever add a supporters list, you'll be on it!)
-- Updated by A.Freeman

local EarlyQualityLevel = 0
local EarlyQualityName = nil
CondLog("EarlyQualityFilter string: \"" .. Config("early-quality-filter") .. "\" filter: " .. serpent.block(EarlyQualityFilter))
for i,Name in pairs(EarlyQualityFilter) do
    local name = string.lower(Name)
    if Qualities[name] ~= nil and EarlyQualityLevel < Qualities[name].level then
        EarlyQualityLevel = Qualities[name].level
        EarlyQualityName = name
    end
end
-- if no level was determined, move all qualities
-- for that we'll use a very high level
if EarlyQualityLevel == 0 then
    EarlyQualityLevel = 100500 -- aka infinity :D
end

-- Build Successors table so we can do a fast update of tech dependencies:
-- key is a parent (prerequisite) for every tech in value list
local Successors = {}
for i,Technology in pairs(Technologies) do
    -- log("Tech tree " .. i .. " " .. serpent.block(Technology))
    Successors[Technology.name] = {}
end
for i,Technology in pairs(Technologies) do
    if type(Technology) == "table" and type(Technology.prerequisites) == "table" then
        for _,Prerequisite in pairs(Technology.prerequisites) do
            table.insert(Successors[Prerequisite], Technology.name)
        end
    end
end

-- Build Order table with property:
-- if TechA depends on TechB, then Order[TechA] > Order[TechB].
-- It is used in MoveQualities function to check that 
--  we won't move quality unlocks to later technologies.
--  Ex.: quality-module-2 should unlock all qualities
--      but we don't want to move uncommon and rare unlocks
--      from quality-module to later technology
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
        -- Mark as visited to prevent cycling. 
        --  There must be no cycles in tech tree after data stage
        --  but some mods have them during initialization (shout out to planet-muluna)
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

local QualityTechOrder = Order[QualityTechnologyName]

-- Checks that Technology unlocks a quality to be moved to QualityTechnology.
-- If Technology unlocks the next quality of EarlyQualityName, 
--  checks and adds QualityTechnology as prerequisite to Technology.
--  ex.: move "uncommon" unlock to rocket-silo, while quality-module still unclocks "rare".
--      In that case, rocket-silo is added as prerequisite to quality-module
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
                        table.insert(Successors[QualityTechnologyName], Technology.name)
                        CondLog("Skipped quality \"" .. Effect.quality .. "\" with order/level values: " .. Values)
                        CondLog("Added prerequisite \"" .. QualityTechnologyName .. "\" to Technology \"" .. Technology.name .. "\"")
                    end
                elseif TechOrder <= QualityTechOrder and Qualities[Effect.quality] and Qualities[Effect.quality].level < EarlyQualityLevel then
                    -- QualityTechnology will have the next quality of Effect.quality.
                    -- So add Technology as prerequisite to QualityTechnology
                    local Contains = false
                    for _,Prerequisite in pairs(QualityTechnology.prerequisites) do
                        if Prerequisite == Technology.name then
                            Contains = true
                        end
                    end
                    if not Contains then
                        table.insert(QualityTechnology.prerequisites, Technology.name)
                        table.insert(Successors[Technology.name], QualityTechnologyName)
                        CondLog("Skipped quality \"" .. Effect.quality .. "\" with order/level values: " .. Values)
                        CondLog("Added prerequisite \"" .. Technology.name .. "\" to Technology \"" .. QualityTechnologyName .. "\"")
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
for i,Technology in pairs(Technologies) do
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
-- Add Prerequisite.prerequisites to Tech.Successors
-- Remove Prerequisite technology
CondLog("Technologies to be removed: " .. ListToString(TechnologiesToBeRemoved))
for PrerequisiteName,Prerequisite in pairs(TechnologiesToBeRemoved) do
    -- Prerequisite is to be removed
    for _,TechName in pairs(Successors[PrerequisiteName]) do
        -- Tech has Prerequisite in Tech.prerequisites
        Tech = Technologies[TechName]
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
            table.insert(Successors[AddDependency], Tech.name)
            -- Compatibility fix for Infinite Quality Tiers
            Tech.enabled = true
        end
    end
    -- Remove Prerequisite technology
    Technologies[PrerequisiteName] = nil
end
