-- Provides MachineTypes, UnfixedRSRBlocklist, BaseQualityBlockList
require("common.consts")
-- Provides Config, CondLog functions
require("common.utils")
-- Provides EnableQuality
require("utils")

-- Allow Quality Modules in Beacons.
if Config("quality-beacons") then
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
            Module.effect.quality = Module.effect.quality * Config("quality-module-multiplier")
        end
    end
end

local function CheckURSREnabled(Machine)
    -- Fix for https://mods.factorio.com/mod/QualityAssurance/discussion/67c79d864fb32db58705573b
    local Recipe = data.raw["recipe"][Machine.fixed_recipe]
    local check = (
        not contains(UnfixedRSRBlocklist, Machine.name)
        and not Machine.no_unfixed_rsr
        and not ( Machine.type == "rocket-silo"
            and Recipe
            and Recipe.ingredients == {}
        )
    )
    if not check then
        CondLog("Machine \"" .. Machine.name .. "\" is banned from Unfixed Rocket Silo Recipes!")
    end
    return check
end

-- Add Base Quality
CondLog("Adding base quality modules.")
for _,MachineType in pairs(MachineTypes) do
    if data.raw[MachineType] then
        for j,Machine in pairs(data.raw[MachineType]) do

            CondLog("Scanning Machine \"" .. Machine.name .. "\" now.")

            if MachineType == "rocket-silo" then
                -- Fix for https://mods.factorio.com/mod/QualityAssurance/discussion/67c79d864fb32db58705573b
                local FixedRecipe = data.raw["recipe"][Machine.fixed_recipe]
                if FixedRecipe and FixedRecipe.hidden then
                    FixedRecipe.hidden = false
                    FixedRecipe.hidden_in_factoriopedia = true
                    FixedRecipe.hide_from_player_crafting = true
                end
            end
            
            if MachineType ~= "rocket-silo" then
                if CheckBaseQualityEnabled(Machine) and not Config("ams-base-quality-toggle") then
                    Machine = AddBaseQuality(Machine)
                end
                Machine = EnableQuality(Machine)
            elseif CheckURSREnabled(Machine) then
                data.raw[MachineType][j].fixed_recipe = nil
                data.raw[MachineType][j].fixed_quality = nil
            end

            data.raw[MachineType][j] = Machine
        end
    end
end