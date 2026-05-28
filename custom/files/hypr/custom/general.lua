hl.config({
    input = {
        kb_layout = "us,ru",
        kb_options = "grp:win_space_toggle",
    },
})

hl.on("hyprland.start", function()
    hl.exec_cmd("systemctl --user start hypr-kdeconnect-portal.service")
    hl.exec_cmd("kdeconnectd")
end)
