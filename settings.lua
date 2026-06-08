local EnableCraftingSpeedFunction = true
local EnableRelabelerAndUpcycler = false -- Causes a crash if enabled, because the relabeler and upcycler are not functional yet.
MachineTypes = {"assembling-machine", "furnace", "mining-drill", "rocket-silo"}

data:extend{
    -- Quality unlocks section
    -- When to unlock quality
    {
        name = "qa_quality-unlock",
        type = "string-setting",
        setting_type = "startup",
        default_value = "quality-module",
        allowed_values = {
            "automation",
            "automation-2",
            "quality-module",
            "rocket-silo",
            "quality-module-2",
            "quality-module-3"
        },
        order = "aa"
    },
    -- Which qualities will be unlocked
    {
        name = "qa_early-quality-filter",
        type = "string-setting",
        setting_type = "startup",
        default_value = "",
        order = "ab",
        allow_blank = true
    },

    -- Quality modules section
    -- Multiplier for quality module's effeciency
    {
        name = "qa_quality-module-multiplier",
        type = "double-setting",
        setting_type = "startup",
        default_value = 1,
        order = "ba",
        minimum_value = 0.01,
        maximum_value = 500
    },
    -- Allow quality options in beacons
    {
        name = "qa_quality-beacons",
        type = "bool-setting",
        setting_type = "startup",
        default_value = true,
        order = "bb"
    },

    -- Machines with Additional Module Slots (AMS) section
    -- Enable AMS machines
    {
        name = "qa_ams-machines-toggle",
        type = "bool-setting",
        setting_type = "startup",
        default_value = true,
        order = "ca"
    },
    -- Which technology is required to unlock AMS machines
    {
        name = "qa_ams-machines-unlock",
        type = "string-setting",
        setting_type = "startup",
        default_value = "modules",
        order = "caa",
        allowed_values = {
            "none",
            "automation",
            "automation-2",
            "modules",
            "quality-module",
            "rocket-silo",
            "automation-3",
            "quality-module-2",
            "quality-module-3"
        }
    },
    -- Hide technologies that unlock AMS machines until all prerequisites are researched
    {
        name = "qa_hide-ams-technologies",
        type = "bool-setting",
        setting_type = "runtime-global",
        default_value = true,
        order = "cb"
    },
    -- How many module slots are added in AMS machines
    --  option with order cc, see below
    -- Enable AMS machines for specific types
    --  options with orders cd*, see below

    -- Base quality section
    -- Enable base quality
    {
        name = "qa_base-quality",
        type = "bool-setting",
        setting_type = "startup",
        default_value = false,
        order = "da"
    },
    -- Base quality value
    {
        name = "qa_base-quality-value",
        type = "double-setting",
        setting_type = "startup",
        default_value = 10,
        order = "db",
        minimum_value = 1,
        maximum_value = 32766
    },
    -- Add base quality to machines without module slots
    {
        name = "qa_moduleless-quality",
        type = "bool-setting",
        setting_type = "startup",
        default_value = false,
        order = "dc"
    },
    -- Base quality will affect only AMS machines
    {
        name = "qa_ams-base-quality-toggle",
        type = "bool-setting",
        setting_type = "startup",
        default_value = false,
        order = "dd"
    },
    -- Which types of machines will be affected
    --  options with orders de*

    -- Debug option section
    -- Enable debug logging
    {
        name = "qa_dev-mode",
        type = "bool-setting",
        setting_type = "startup",
        default_value = false,
        order = "z"
    },
}

if EnableCraftingSpeedFunction then
    data:extend{
        {
            name = "qa_added-module-slots",
            type = "int-setting",
            setting_type = "startup",
            default_value = 2,
            minimum_value = -10,
            maximum_value = 10,
            order = "cc"
        }
    }
else
    data:extend{
        {
            name = "qa_added-module-slots",
            type = "int-setting",
            setting_type = "startup",
            default_value = 2,
            allowed_values = {2},
            order = "cc",
            hidden = true
        }
    }
end

for _,MachineType in pairs(MachineTypes) do
    data:extend{
        -- Enable AMS machines for specific machine types
        {
            name = "qa_enable-ams-" .. MachineType,
            type = "bool-setting",
            setting_type = "startup",
            default_value = true,
            order = "cd[" .. MachineType .. "]"
        },
        -- Which types of machines will be affected by base quality
        {
            name = "qa_enable-base-quality-" .. MachineType,
            type = "bool-setting",
            setting_type = "startup",
            default_value = true,
            order = "de[" .. MachineType .. "]"
        }
    }
end


if EnableRelabelerAndUpcycler then
    data:extend{
        {   
            name = "qa_relabeler",
            type = "bool-setting",
            setting_type = "startup",
            default_value = true,
            order = "k"
        },
        {   
            name = "qa_upcycler",
            type = "bool-setting",
            setting_type = "startup",
            default_value = true,
            order = "l"
        }
    }
else
    data:extend{
        {
            name = "qa_relabeler",
            type = "bool-setting",
            setting_type = "startup",
            default_value = false,
            forced_value = false,
            order = "k",
            hidden = true
        },
        {   
            name = "qa_upcycler",
            type = "bool-setting",
            setting_type = "startup",
            default_value = false,
            forced_value = false,
            order = "l",
            hidden = true
        }
    }
end