-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

local ENV = {
    XCURSOR_SIZE = "24",
    HYPRCURSOR_SIZE = "24",
    XDG_CURRENT_DESKTOP = "Hyprland",
    XDG_SESSION_TYPE = "wayland",
    XDG_CURRENT_DESKTOP = "Hyprland"
}

for name, value in pairs(ENV) do
    hl.env(name, value)
end
