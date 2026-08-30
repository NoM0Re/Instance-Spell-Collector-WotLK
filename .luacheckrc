std = "lua51"
max_line_length = false

exclude_files = {
    "!InstanceSpellCollector/Libs/",
    ".agents-cache/",
    ".luarocks/",
}

ignore = {
    "113", -- WoW API and SavedVariables globals
    "211", -- Unused local variable
    "212", -- Unused argument
    "213", -- Unused loop variable
    "42.", -- Shadowing a local or argument
    "43.", -- Shadowing an upvalue
}
