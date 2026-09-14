--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

-- Workspaces per monitor
for workspace = 1, 5 do
    hl.workspace_rule({
        workspace = tostring(workspace),
        monitor = "DP-2",
        default = workspace == 1,
    })
end

for workspace = 6, 10 do
    hl.workspace_rule({
        workspace = tostring(workspace),
        monitor = "HDMI-A-1",
        default = workspace == 6,
    })
end

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

hl.window_rule({
    name = "vesktop-to-communication",

    match = {
        initial_class = "^vesktop$",
    },

    workspace = "special:communication silent",
})

hl.window_rule({
    name = "tartarus-imageviewer-floating",

    match = {
        initial_title = "^.* - Tartarus Image Viewer$",
    },

    float = true,
    center = true,
})

hl.window_rule({
    name = "tartarus-imageviewer-opaque",
    match = { initial_title = "^.* - Tartarus Image Viewer$" },
    opaque = true,
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
