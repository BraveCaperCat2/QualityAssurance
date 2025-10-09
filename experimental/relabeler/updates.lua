-- Provides Config, CondLog functions
require("common.utils")

-- Code to generate relabeler recipes. It'll only work once I can make quality-dependent recipes and results and update the code here.
-- Then I can enable the relabeler setting in settings.lua to make it work.
if Config("relabeler") then
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