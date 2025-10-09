-- Provides Config, CondLog functions
require("common.utils")

-- Code to generate upcycler recipes. It'll only work once I can make quality-dependent recipes and results and update the code here.
-- Then I can enable the upcycler setting in settings.lua to make it work.
if Config("upcycler") then
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