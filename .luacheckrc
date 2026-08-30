std = "lua51"
max_line_length = false

globals = {
    "ISC_Config",
    "ISC_Data",
    "ISC_Spell",
    "ISC_AuraDesc",
    "ISC_NpcId",
    "ISC_Ignore",
    "SLASH_ISC1",
    "SlashCmdList",
}

exclude_files = {
    "!InstanceSpellCollector/Libs/",
    ".agents-cache/",
    ".lua/",
    ".luarocks/",
    "lua-*/",
    "luarocks-*/",
}

ignore = {
    "113", -- WoW API and SavedVariables globals
    "211", -- Unused local variable
    "212", -- Unused argument
    "213", -- Unused loop variable
    "42.", -- Shadowing a local or argument
    "43.", -- Shadowing an upvalue
}
