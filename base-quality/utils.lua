-- Provides Config, CondLog functions
require("common.utils")

-- Check list contains value
function contains(list, value)
  for _, v in ipairs(list) do
    if v == value then
      return true
    end
  end
  return false
end


local EnableBaseQuality = Config("base-quality")
local EnableAMSBaseQuality = Config("ams-base-quality-toggle")

-- Check if we want to add Base Quality to Machine
function CheckBaseQualityEnabled(Machine)
    local check = (
        EnableBaseQuality
        and not contains(BaseQualityBlockList, Machine.name)
        and not Machine.no_bq
        and Config("enable-base-quality-" .. Machine.type)
        and ( not EnableAMSBaseQuality or Machine.name:match('%-ams$') ~= nil)
    )
    if not check then
        CondLog("Machine \"" .. Machine.name .. "\" is banned from Base Quality Addition!")
    end
    return check
end

-- Allow Machine be affected by quality
function EnableQuality(Machine)
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

-- Add base quality to Machine.
function AddBaseQuality(Machine)
    if not Config("moduleless-quality") then
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
                        Machine.effect_receiver.base_effect.quality = Config("base-quality-value") / 100 / NormalProbability
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
