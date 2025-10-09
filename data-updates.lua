-- Early quality unlocks
require("quality-unlock.updates")

-- Base quality, quality modules in beacons, multiplier for quality modules
require("base-quality.updates")

-- AMS machines
require("ams.updates")

-- Code to generate relabeler recipes. It'll only work once I can make quality-dependent recipes and results and update the code here.
-- Then I can enable the relabeler setting in settings.lua to make it work.
require("experimental.relabeler.updates")

-- Code to generate upcycler recipes. It'll only work once I can make quality-dependent recipes and results and update the code here.
-- Then I can enable the upcycler setting in settings.lua to make it work.
require("experimental.upcycler.updates")
