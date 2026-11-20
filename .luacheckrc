std = "lua51"
max_line_length = false
codes = true
self = false
exclude_files = { "node_modules/", ".tools/" }

read_globals = { "CreateFrame", "UIParent", "MacroFrame", "MacroPopupFrame" }

files["spec/"] = {
	std = "+busted",
	globals = { "CreateFrame", "UIParent", "MacroFrame", "MacroPopupFrame" },
}
