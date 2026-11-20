std = "lua51"
max_line_length = false
codes = true
self = false
exclude_files = { "node_modules/", ".tools/", ".lua/", ".luarocks/", ".install/" }

read_globals = {
	"CreateFrame", "UIParent", "MacroFrame", "MacroPopupFrame", "MacroFrameText",
	"InCombatLockdown", "UIErrorsFrame", "GameTooltip",
}

files["spec/"] = {
	std = "+busted",
	globals = { "CreateFrame", "UIParent", "MacroFrame", "MacroPopupFrame" },
}
