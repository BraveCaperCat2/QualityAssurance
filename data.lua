-- Will not work until I can make recipe ingredients and results depend on quality.
-- Otherwise, there will be duplicate recipes with the same ingredients, which will cause a crash due to the furnace-like nature of the relabeler.
-- Once that's possible, I can update the code in data-updates.lua to fix that issue, then go to settings.lua and enable the relabeler setting.
require("experimental.relabeler.data")

-- Will not work until I can make recipe ingredients and results depend on quality.
-- Otherwise, there will be duplicate recipes with the same ingredients, which will cause a crash due to the furnace-like nature of the upcycler.
-- Once that's possible, I can update the code in data-updates.lua to fix that issue, then go to settings.lua and enable the upcycler setting.
require("experimental.upcycler.data")
