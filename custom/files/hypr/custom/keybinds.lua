-- Disable naked Super search / launcher
hl.unbind("SUPER + SUPER_L")
hl.unbind("SUPER + SUPER_R")

-- Also disable fallback launcher on the same keys
hl.unbind("SUPER + SUPER_L")
hl.unbind("SUPER + SUPER_R")

-- Consume naked Super so it does nothing
hl.bind("SUPER + SUPER_L", hl.dsp.no_op(), { description = "Disabled: naked Super" })
hl.bind("SUPER + SUPER_R", hl.dsp.no_op())
