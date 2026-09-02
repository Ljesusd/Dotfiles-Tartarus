--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

-- Example window rules that are useful

local suppressMaximizeRule = hl.window_rule({
    -- Ignore maximize requests from all apps. You'll probably like this.
    name = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})

-- suppressMaximizeRule:set_enabled(false)

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name = "fix-xwayland-drags",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },

    no_focus = true,
})

-- Layer rules also return a handle.
-- local overlayLayerRule = hl.layer_rule({
--     name = "no-anim-overlay",
--     match = { namespace = "^my-overlay$" },
--     no_anim = true,
-- })
-- overlayLayerRule:set_enabled(false)

-- Hyprland-run windowrule
hl.window_rule({
    name = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move = "20 monitor_h-120",
    float = true,
})

hl.window_rule({
    name = "steam-to-gaming",

    match = {
        initial_class = "^steam$",
    },

    workspace = "special:gaming silent",
})

hl.window_rule({
    name = "steam-big-picture-fullscreen",

    match = {
        initial_class = "^steam$",
        initial_title = "^Steam Big Picture Mode$",
    },

    fullscreen = true,
})

hl.window_rule({
    name = "steam-games-to-gaming",

    match = {
        initial_class = "^steam_app_[0-9]+$",
    },

    workspace = "special:gaming silent",
})

hl.on("window.active", function(window)
    if window == nil then
        return
    end

    if window.class ~= "steam" then
        return
    end

    if window.initial_title ~= "Steam Big Picture Mode" then
        return
    end

    hl.dispatch(hl.dsp.window.fullscreen({
        window = window,
        action = "set",
        mode = "fullscreen",
    }))
end)
