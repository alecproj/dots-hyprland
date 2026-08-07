-- System keybinds
-- disable naked Super search / launcher
hl.unbind("SUPER + SUPER_L")
hl.unbind("SUPER + SUPER_R")
-- also disable fallback launcher on the same keys
hl.unbind("SUPER + SUPER_L")
hl.unbind("SUPER + SUPER_R")
-- consume naked Super so it does nothing
hl.bind("SUPER + SUPER_L", hl.dsp.no_op(), { description = "Disabled: Naked Super" })
hl.bind("SUPER + SUPER_R", hl.dsp.no_op())
-- rebind Toggle right sidebar
hl.unbind("SUPER + N")
hl.bind("SUPER + Backslash", hl.dsp.global("quickshell:sidebarRightToggle"), { description = "Shell: Toggle right sidebar" })
