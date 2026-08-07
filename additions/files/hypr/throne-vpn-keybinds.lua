-- Throne VPN keybinds
-- replace SUPER + P = Window: Pin -> App: Throne
hl.unbind("SUPER + P")
hl.bind("SUPER + P", hl.dsp.exec_cmd("throne"), { description = "App: Throne (vpn)" })
