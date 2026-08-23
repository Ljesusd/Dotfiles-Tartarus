------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/

local MONITORS = {
    {
        output = "DP-2",
        mode = "1920x1080@100",
        position = "0x0",
        scale = 1,
    },
    {
        output = "HDMI-A-1",
        mode = "1920x1080@100",
        position = "1920x0",
        scale = 1,
    },
}

for _, monitor in ipairs(MONITORS) do
    hl.monitor(monitor)
end
