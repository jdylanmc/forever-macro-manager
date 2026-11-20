std = "lua51"
max_line_length = false
codes = true
self = false
exclude_files = { "node_modules/", ".tools/", ".lua/", ".luarocks/", ".install/" }

read_globals = {
	"CreateFrame", "UIParent", "MacroFrame", "MacroPopupFrame", "MacroFrameText",
	"InCombatLockdown", "UIErrorsFrame", "GameTooltip",
	"C_UIFileAsset", "C_SpellBook", "C_Flyout", "C_Spell", "C_Item", "C_Container",
	"Enum", "INVSLOT_FIRST_EQUIPPED", "INVSLOT_LAST_EQUIPPED", "NUM_TOTAL_EQUIPPED_BAG_SLOTS",
	"GetInventoryItemID", "IconDataProviderIconType", "hooksecurefunc",
}

files["spec/"] = {
	std = "+busted",
	globals = { "CreateFrame", "UIParent", "MacroFrame", "MacroPopupFrame" },
}
