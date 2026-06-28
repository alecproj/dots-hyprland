-- KBLAYOUT CONFIG

hl.config({
    input = {
        kb_layout = "us,ru",
        kb_options = "grp:win_space_toggle",
    },
})

-- AUTOSTART CONFIG

hl.on("hyprland.start", function()
    hl.exec_cmd("systemctl --user start hypr-kdeconnect-portal.service")
    hl.exec_cmd("kdeconnectd")
    hl.exec_cmd("sleep 5; ~/.local/bin/throne-autostart")
end)

-- MONITOR CONFIG

local mainmonitor = "DP-1"
hl.monitor({ output = mainmonitor, mode = "1920x1080", position = "0x0", scale = 1 })
hl.workspace_rule({ workspace = "1", monitor = mainmonitor, default = true })
hl.workspace_rule({ workspace = "2", monitor = mainmonitor })
hl.workspace_rule({ workspace = "3", monitor = mainmonitor })
hl.workspace_rule({ workspace = "4", monitor = mainmonitor })
hl.workspace_rule({ workspace = "5", monitor = mainmonitor })
hl.workspace_rule({ workspace = "6", monitor = mainmonitor })
hl.workspace_rule({ workspace = "7", monitor = mainmonitor })
hl.workspace_rule({ workspace = "8", monitor = mainmonitor })
hl.workspace_rule({ workspace = "9", monitor = mainmonitor })
hl.workspace_rule({ workspace = "10", monitor = mainmonitor })

local secondmonitor = "HDMI-A-1"
hl.monitor({ output = secondmonitor, mode = "1920x1080", position = "-1920x0", scale = 1 })
hl.workspace_rule({ workspace = "11", monitor = secondmonitor, default = true })
hl.workspace_rule({ workspace = "12", monitor = secondmonitor })
hl.workspace_rule({ workspace = "13", monitor = secondmonitor })
hl.workspace_rule({ workspace = "14", monitor = secondmonitor })
hl.workspace_rule({ workspace = "15", monitor = secondmonitor })
hl.workspace_rule({ workspace = "16", monitor = secondmonitor })
hl.workspace_rule({ workspace = "17", monitor = secondmonitor })
hl.workspace_rule({ workspace = "18", monitor = secondmonitor })
hl.workspace_rule({ workspace = "19", monitor = secondmonitor })
hl.workspace_rule({ workspace = "20", monitor = secondmonitor })
