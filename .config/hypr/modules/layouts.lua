---@diagnostic disable: undefined-global

local LAYOUTS = {
    general = {
        layout = "dwindle",
    },

    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    scrolling = {
        fullscreen_on_one_column = true,
    },
}

hl.config(LAYOUTS)
