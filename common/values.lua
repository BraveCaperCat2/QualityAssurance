-- Allows variable number of additional module slots in AMS machines
VariableAdditionalSlots = true
-- Causes a crash if enabled, because the relabeler and upcycler are not functional yet.
EnableRelabelerAndUpcycler = false

-- List of machine types eligible for additional module slots.
MachineTypes = {"assembling-machine", "furnace", "mining-drill", "rocket-silo", "lab"}

-- A list of entity names to be skipped over when creating AMS machines.
AMSBlocklist = {"awesome-sink-gui", "oil_rig_migration", "elevated-pipe", "yir_factory_stuff", "yir_diesel_monument", "yir_future_monument", "energy-void", "passive-energy-void", "fluid-source"}

-- A list of entity names to be skipped over when modifying the fixed_recipe and fixed_quality properties.
UnfixedRSRBlocklist = {"planet-hopper-launcher"}

-- A list of entity names to be skipped over when adding Base Quality.
BaseQualityBlockList = {}