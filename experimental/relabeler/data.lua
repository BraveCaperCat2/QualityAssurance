-- Provides Config, CondLog functions
require("common.utils")

-- Will not work until I can make recipe ingredients and results depend on quality.
-- Otherwise, there will be duplicate recipes with the same ingredients, which will cause a crash due to the furnace-like nature of the relabeler.
-- Once that's possible, I can update the code in data-updates.lua to fix that issue, then go to settings.lua and enable the relabeler setting.
if Config("relabeler") then
    -- The relabeler, decreases the quality of an item by 1 tier. Does nothing to normal quality items.
    CondLog("Creating machine \"qa_relabeler\"")
    local RelabelingCategory = {}
    RelabelingCategory.type = "recipe-category"
    RelabelingCategory.name = "relabeling"

    local RelabelerMachine = table.deepcopy(data.raw["furnace"]["recycler"])
    RelabelerMachine.type = "assembling-machine" -- Temporary fix for crash with multiple recipes having the same ingredients, until quality-dependent recipe ingredients/results can be done.
    RelabelerMachine.name = "qa_relabeler"
    RelabelerMachine.crafting_categories = {"relabeling"}
    RelabelerMachine.module_slots = 4
    RelabelerMachine.result_inventory_size = 1
    RelabelerMachine.cant_insert_at_source_message_key = "inventory-restriction.cant-be-relabeled"
    RelabelerMachine["minable"] = RelabelerMachine["minable"] or {mining_time = 1}
    RelabelerMachine.minable.results = nil
    RelabelerMachine.minable.result = RelabelerMachine.name
    RelabelerMachine.minable.count = 1

    local RelabelerItem = table.deepcopy(data.raw["item"]["recycler"])
    RelabelerItem.name = RelabelerMachine.name
    RelabelerItem.stack_size = 50
    RelabelerItem.place_result = RelabelerMachine.name
    RelabelerMachine.MachineItem = RelabelerItem.name

    local RelabelerRecipe = {}
    RelabelerRecipe.name = RelabelerItem.name
    RelabelerRecipe.type = "recipe"
    RelabelerRecipe.ingredients = {{type = "item", name = "electronic-circuit", amount = 25}, {type = "item", name = "advanced-circuit", amount = 10}, {type = "item", name = "steel-plate", amount = 30}, {type = "item", name = "iron-gear-wheel", amount = 15}}
    RelabelerRecipe.results = {{type = "item", name = RelabelerItem.name, amount = 1}}
    RelabelerRecipe.category = "crafting"
    RelabelerRecipe.enabled = false

    local RelabelerTechnology = table.deepcopy(data.raw["technology"]["recycling"])
    RelabelerTechnology.name = RelabelerRecipe.name
    RelabelerTechnology.prerequisites = {"quality-module", "electronics", "advanced-circuit", "steel-processing"}
    RelabelerTechnology.effects = {{type = "unlock-recipe", recipe = RelabelerRecipe.name}}
    RelabelerTechnology.unit = {count = 350, ingredients = {{"automation-science-pack", 2}, {"logistic-science-pack", 2}, {"chemical-science-pack", 1}}, time = 45}
    RelabelerTechnology.research_trigger = nil
    data.extend({RelabelingCategory, RelabelerMachine, RelabelerItem, RelabelerRecipe, RelabelerTechnology})
end
