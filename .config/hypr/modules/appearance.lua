-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/

local APPEARANCE = {
    general = {
        gaps_in = 5,
        gaps_out = 20,

        border_size = 2,

        col = {
            active_border = {
                colors = {
                    "rgba(33ccffee)",
                    "rgba(00ff99ee)",
                },
                angle = 45,
            },

            inactive_border = "rgba(595959aa)",
        },

        resize_on_border = false,
        allow_tearing = false,

    },

    decoration = {
        rounding = 10,
        rounding_power = 2,

        active_opacity = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled = true,
            range = 4,
            render_power = 3,
            color = 0xee1a1a1a,
        },

        blur = {
            enabled = true,
            size = 3,
            passes = 1,
            vibrancy = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },
}

local CURVES = {
    {
        name = "easeOutQuint",
        config = {
            type = "bezier",
            points = {
                { 0.23, 1 },
                { 0.32, 1 },
            },
        },
    },

    {
        name = "easeInOutCubic",
        config = {
            type = "bezier",
            points = {
                { 0.65, 0.05 },
                { 0.36, 1 },
            },
        },
    },

    {
        name = "linear",
        config = {
            type = "bezier",
            points = {
                { 0, 0 },
                { 1, 1 },
            },
        },
    },

    {
        name = "almostLinear",
        config = {
            type = "bezier",
            points = {
                { 0.5, 0.5 },
                { 0.75, 1 },
            },
        },
    },

    {
        name = "quick",
        config = {
            type = "bezier",
            points = {
                { 0.15, 0 },
                { 0.1, 1 },
            },
        },
    },

    {
        name = "easy",
        config = {
            type = "spring",
            mass = 1,
            stiffness = 238.1191,
            dampening = 24.21279333,
        },
    },
}

local ANIMATIONS = {
    {
        leaf = "global",
        enabled = true,
        speed = 10,
        bezier = "default",
    },

    {
        leaf = "border",
        enabled = true,
        speed = 5.39,
        bezier = "easeOutQuint",
    },

    {
        leaf = "windows",
        enabled = true,
        speed = 4.79,
        spring = "easy",
    },

    {
        leaf = "windowsIn",
        enabled = true,
        speed = 4.1,
        spring = "easy",
        style = "popin 87%",
    },

    {
        leaf = "windowsOut",
        enabled = true,
        speed = 1.49,
        bezier = "linear",
        style = "popin 87%",
    },

    {
        leaf = "fadeIn",
        enabled = true,
        speed = 1.73,
        bezier = "almostLinear",
    },

    {
        leaf = "fadeOut",
        enabled = true,
        speed = 1.46,
        bezier = "almostLinear",
    },

    {
        leaf = "fade",
        enabled = true,
        speed = 3.03,
        bezier = "quick",
    },

    {
        leaf = "layers",
        enabled = true,
        speed = 3.81,
        bezier = "easeOutQuint",
    },

    {
        leaf = "layersIn",
        enabled = true,
        speed = 4,
        bezier = "easeOutQuint",
        style = "fade",
    },

    {
        leaf = "layersOut",
        enabled = true,
        speed = 1.5,
        bezier = "linear",
        style = "fade",
    },

    {
        leaf = "fadeLayersIn",
        enabled = true,
        speed = 1.79,
        bezier = "almostLinear",
    },

    {
        leaf = "fadeLayersOut",
        enabled = true,
        speed = 1.39,
        bezier = "almostLinear",
    },

    {
        leaf = "workspaces",
        enabled = true,
        speed = 1.94,
        bezier = "almostLinear",
        style = "fade",
    },

    {
        leaf = "workspacesIn",
        enabled = true,
        speed = 1.21,
        bezier = "almostLinear",
        style = "fade",
    },

    {
        leaf = "workspacesOut",
        enabled = true,
        speed = 1.94,
        bezier = "almostLinear",
        style = "fade",
    },

    {
        leaf = "zoomFactor",
        enabled = true,
        speed = 7,
        bezier = "quick",
    },
}

hl.config(APPEARANCE)

for _, curve in ipairs(CURVES) do
    hl.curve(curve.name, curve.config)
end

for _, animation in ipairs(ANIMATIONS) do
    hl.animation(animation)
end
