--# Disable naked Super
--## Disable naked Super search / launcher
hl.unbind("SUPER + SUPER_L")
hl.unbind("SUPER + SUPER_R")
--## Also disable fallback launcher on the same keys
hl.unbind("SUPER + SUPER_L")
hl.unbind("SUPER + SUPER_R")
--## Consume naked Super so it does nothing
hl.bind("SUPER + SUPER_L", hl.dsp.no_op(), { description = "Disabled: Naked Super" })
hl.bind("SUPER + SUPER_R", hl.dsp.no_op())

--# Rebind Toggle right sidebar
hl.unbind("SUPER + N")
hl.bind("SUPER + Backslash", hl.dsp.global("quickshell:sidebarRightToggle"), { description = "Shell: Toggle right sidebar" })

--# Custom vim-style window binds
--## unbind H/J/K/L keys
hl.unbind("SUPER + H")
hl.unbind("SUPER + CTRL + H")
hl.unbind("SUPER + SHIFT + H")
hl.unbind("SUPER + J")         -- Shell: Toggle bar
hl.unbind("SUPER + CTRL + J")
hl.unbind("SUPER + SHIFT + J")
hl.unbind("SUPER + K")         -- Shell: Toggle on-screen keyboard
hl.unbind("SUPER + CTRL + K")
hl.unbind("SUPER + SHIFT + K")
hl.unbind("SUPER + L")         -- Session: Lock
hl.unbind("SUPER + CTRL + L")
hl.unbind("SUPER + SHIFT + L") -- Session: Sleep
--## rebind Focus in direction  
for i = 1, 4 do
    local oldarrowkey = { "Left", "Right", "Up", "Down" }
    local newarrowkey = { "H", "L", "K", "J" }
    local focusdir = { "l", "r", "u", "d" }
    hl.unbind("SUPER +" .. oldarrowkey[i])
    hl.bind("SUPER + " .. newarrowkey[i], hl.dsp.focus({ direction = focusdir[i] }),
        { description = "Window: Focus " .. oldarrowkey[i] })
end
--## rebind Move in direction
for i = 1, 4 do
    local oldarrowkey = { "Left", "Right", "Up", "Down" }
    local newarrowkey = { "H", "L", "K", "J" }
    local focusdir = { "l", "r", "u", "d" }
    hl.unbind("SUPER + SHIFT + " .. oldarrowkey[i])
    hl.bind("SUPER + SHIFT + " .. newarrowkey[i], hl.dsp.window.move({ direction = focusdir[i] }),
        { description = "Window: Move " .. oldarrowkey[i] })
end
--## bind Resize in direction
hl.bind("SUPER + CTRL + H", hl.dsp.window.resize({x = -100, y = 0, relative = true}),
    { description = "Window: Resize Left"})
hl.bind("SUPER + CTRL + L", hl.dsp.window.resize({x = 100, y = 0, relative = true}),
    { description = "Window: Resize Right"})
hl.bind("SUPER + CTRL + K", hl.dsp.window.resize({x = 0, y = -100, relative = true}),
    { description = "Window: Resize Up"})
hl.bind("SUPER + CTRL + J", hl.dsp.window.resize({x = 0, y = 100, relative = true}),
    { description = "Window: Resize Down"})
--## bind lost functions 
hl.bind("SUPER + Up", hl.dsp.global("quickshell:barToggle"), { description = "Shell: Toggle bar" })
hl.bind("SUPER + Down", hl.dsp.global("quickshell:oskToggle"), { description = "Shell: Toggle on-screen keyboard" })
hl.bind("SUPER + ALT + L", hl.dsp.exec_cmd("loginctl lock-session"), { description = "Session: Lock" })

--# bind = SUPER+CTRL, Hash,, -- Send to workspace -- (1, 2, 3,...)
for i = 1, 10 do
    hl.bind("SUPER + CTRL + " .. (i % 10), function()
        hl.dispatch(hl.dsp.window.move({ workspace = workspace_in_group(i)}))
    end, { description = "Window: Send to workspace " .. i })
end
--# We also use raw keycodes because some keyboard layouts register number keys as different chars. The codes can be verified with `wev`
for i = 1, 10 do
    local numberkey = { 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 }
    hl.bind("SUPER + CTRL + code:" .. numberkey[i], function()
        hl.dispatch(hl.dsp.window.move({ workspace = workspace_in_group(i)}))
    end)
end
--# keypad numbers
for i = 1, 10 do
    local numpadkey = { 87, 88, 89, 83, 84, 85, 79, 80, 81, 90 }
    hl.bind("SUPER + CTRL + code:" .. numpadkey[i], function()
        hl.dispatch(hl.dsp.window.move({ workspace = workspace_in_group(i)}))
    end)
end
