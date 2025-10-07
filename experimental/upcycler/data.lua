-- Provides Config, CondLog functions
require("common.utils")

-- Will not work until I can make recipe ingredients and results depend on quality.
-- Otherwise, there will be duplicate recipes with the same ingredients, which will cause a crash due to the furnace-like nature of the upcycler.
-- Once that's possible, I can update the code in data-updates.lua to fix that issue, then go to settings.lua and enable the upcycler setting.
if Config("upcycler") then
    -- The upcycler, has a chance to increase the quality of an item by 1 tier, as well as chances to leave the item as-is and turn the item into scrap.
    CondLog("Creating machine \"qa_upcycler\"")
    local UpcyclingCategory = {}
    UpcyclingCategory.type = "recipe-category"
    UpcyclingCategory.name = "upcycling"

    local UpcyclerMachine = table.deepcopy(data.raw["furnace"]["recycler"])
    UpcyclerMachine.name = "qa_upcycler"
    UpcyclerMachine.crafting_categories = {"upcycling"}
    UpcyclerMachine.module_slots = 4
    UpcyclerMachine.result_inventory_size = data.raw["furnace"]["recycler"].result_inventory_size + 2
    UpcyclerMachine.cant_insert_at_source_message_key = "inventory-restriction.cant-be-upcycled"
    UpcyclerMachine["minable"] = UpcyclerMachine["minable"] or {mining_time = 1}
    UpcyclerMachine.minable.results = nil
    UpcyclerMachine.minable.result = UpcyclerMachine.name
    UpcyclerMachine.minable.count = 1

    local UpcyclerItem = table.deepcopy(data.raw["item"]["recycler"])
    UpcyclerItem.name = UpcyclerMachine.name
    UpcyclerItem.stack_size = 50
    UpcyclerItem.place_result = UpcyclerMachine.name
    UpcyclerMachine.MachineItem = UpcyclerItem.name

    local UpcyclerRecipe = {}
    UpcyclerRecipe.name = UpcyclerItem.name
    UpcyclerRecipe.type = "recipe"
    UpcyclerRecipe.ingredients = {{type = "item", name = "electronic-circuit", amount = 75}, {type = "item", name = "advanced-circuit", amount = 50}, {type = "item", name = "iron-gear-wheel", amount = 35}, {type = "item", name = "assembling-machine-3", amount = 1}}
    UpcyclerRecipe.results = {{type = "item", name = UpcyclerItem.name, amount = 1}}
    UpcyclerRecipe.category = "crafting"
    UpcyclerRecipe.enabled = false

    local UpcyclerTechnology = table.deepcopy(data.raw["technology"]["recycling"])
    UpcyclerTechnology.name = UpcyclerRecipe.name
    UpcyclerTechnology.prerequisites = {"quality-module", "electronics", "advanced-circuit", "automation-3"}
    if Config("relabeler") then
        table.insert(UpcyclerTechnology.prerequisites, "qa_relabeler")
    end
    UpcyclerTechnology.effects = {{type = "unlock-recipe", recipe = UpcyclerRecipe.name}}
    UpcyclerTechnology.unit = {count = 1400, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}}, time = 60}
    UpcyclerTechnology.research_trigger = nil
    data.extend({UpcyclingCategory, UpcyclerMachine, UpcyclerItem, UpcyclerRecipe, UpcyclerTechnology})
end