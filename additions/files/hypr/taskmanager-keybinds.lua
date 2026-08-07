-- rebind Task manager
hl.unbind("CTRL + SHIFT + Escape")
hl.bind("CTRL + SHIFT + Escape", hl.dsp.exec_cmd("missioncenter"), { description = "App: Task manager" })
