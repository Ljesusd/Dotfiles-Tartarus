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

-- Floating dialogs follow the same centered behavior used by Caelestia and
-- Lyne without changing normal tiled applications.
hl.window_rule({
    name = "center-native-floating-windows",
    match = { float = true, xwayland = false },
    center = true,
})

hl.window_rule({
    name = "picture-in-picture",
    match = { title = "^(Picture[- ]in[- ]Picture|picture-in-picture)$" },
    float = true,
    pin = true,
    keep_aspect_ratio = true,
    no_initial_focus = true,
    no_shadow = true,
})

hl.window_rule({
    name = "common-file-dialogs-floating",
    match = {
        title = "^(Open|Save As|Save|Select a File|Select a Folder|Choose wallpaper|Library)(.*)$",
    },
    float = true,
    center = true,
})

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
    name = "gamescope-gaming-session",

    match = {
        class = "^gamescope$",
    },

    workspace = "special:gaming silent",
    fullscreen = true,
    sync_fullscreen = true,
    no_anim = true,
    no_blur = true,
    no_shadow = true,
    no_shortcuts_inhibit = true,
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

hl.window_rule({
    name = "tartarus-control-center-floating",
    match = {
        initial_title = "^Tartarus — Configuración$",
    },

    float = true,
    center = true,
})

hl.window_rule({
    name = "tartarus-control-center-rounded",
    match = { initial_title = "^Tartarus — Configuración$" },
    rounding = 20,
})

-- Quickshell owns the bar and all of its popup surfaces. This gives those
-- translucent surfaces the same compositor blur as the reference shells.
hl.layer_rule({
    name = "tartarus-quickshell-popups",
    match = { namespace = "quickshell" },
    blur = true,
    blur_popups = true,
    ignore_alpha = 0.45,
    xray = false,
})
