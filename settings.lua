EnableCraftingSpeedFunction = false

data:extend{
    {   name = "qa_base-quality",
        type = "bool-setting",
        setting_type = "startup",
        default_value = false,
        order = "a"
    },
    {   name = "qa_quality-unlock",
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
        order = "b"
    },
    {   name = "qa_moduleless-quality",
        type = "bool-setting",
        setting_type = "startup",
        default_value = false,
        order = "c"
    },
    {   name = "qa_base-quality-value",
        type = "double-setting",
        setting_type = "startup",
        default_value = 10,
        order = "d",
        minimum_value = 1,
        maximum_value = 32766
    },
    {   name = "qa_quality-beacons",
        type = "bool-setting",
        setting_type = "startup",
        default_value = true,
        order = "e"
    },
    {   name = "qa_quality-module-multiplier",
        type = "double-setting",
        setting_type = "startup",
        default_value = 1,
        order = "f",
        minimum_value = 0.01,
        maximum_value = 500
    },
    {   name = "qa_ams-machines-toggle",
        type = "bool-setting",
        setting_type = "startup",
        default_value = true,
        order = "g"
    },
    {   name = "qa_dev-mode",
        type = "bool-setting",
        setting_type = "startup",
        default_value = false,
        order = "i"
    },
    {   name = "qa_ams-base-quality-toggle",
        type = "bool-setting",
        setting_type = "startup",
        default_value = false,
        order = "j"
    }
}
if EnableCraftingSpeedFunction then
    data:extend{
    {   name = "qa_added-module-slots",
        type = "int-setting",
        setting_type = "startup",
        default_value = 2,
        minimum_value = -10,
        maximum_value = 10,
        order = "h"

    }
}
else
    data:extend{
    {   name = "qa_added-module-slots",
        type = "int-setting",
        setting_type = "startup",
        default_value = 2,
        allowed_values = {2},
        order = "h",
        hidden = true
    }
}
end
