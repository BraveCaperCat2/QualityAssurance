EnableCraftingSpeedFunction = false

-- Returns the value of the setting with the provided name, or nil if it doesn't exist. Prefix should not be provided.
local function config(name)
    if settings.startup['qa_' .. name] then
        return settings.startup['qa_' .. name].value
    end
    return nil
end

local EnableLog = config("dev-mode")
function CondLog(str)
    if EnableLog then
        log(str)
    end
end

-- Will not work until I can make recipe ingredients and results depend on quality.
-- Otherwise, there will be duplicate recipes with the same ingredients, which will cause a crash due to the furnace-like nature of the relabeler.
-- Once that's possible, I can update the code in data-updates.lua to fix that issue, then go to settings.lua and enable the relabeler setting.
if config("relabeler") then
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

-- Will not work until I can make recipe ingredients and results depend on quality.
-- Otherwise, there will be duplicate recipes with the same ingredients, which will cause a crash due to the furnace-like nature of the upcycler.
-- Once that's possible, I can update the code in data-updates.lua to fix that issue, then go to settings.lua and enable the upcycler setting.
if config("upcycler") then
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
    if config("relabeler") then
        table.insert(UpcyclerTechnology.prerequisites, "qa_relabeler")
    end
    UpcyclerTechnology.effects = {{type = "unlock-recipe", recipe = UpcyclerRecipe.name}}
    UpcyclerTechnology.unit = {count = 1400, ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}}, time = 60}
    UpcyclerTechnology.research_trigger = nil
    data.extend({UpcyclingCategory, UpcyclerMachine, UpcyclerItem, UpcyclerRecipe, UpcyclerTechnology})
end
