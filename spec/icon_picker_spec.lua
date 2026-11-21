local Wow = require("spec.support.wow")

local QUESTION = "INTERFACE\\ICONS\\INV_MISC_QUESTIONMARK"
local PATH = "Interface\\Icons\\Known"
local LOOSE = "Interface\\Icons\\Loose"

local function loadAddon(world)
	for line in io.lines("ForeverMacroManager.toc") do
		if line:match("%.lua$") then world:load(line) end
	end
end

local function fixture()
	local world = Wow.new()
	local _, popup = world:editor(true)
	world.icons = { { 300, 100, 300, PATH, LOOSE, 999 }, { 200, 300, 100 } }
	world.pathIDs = { [QUESTION:lower()] = 134400, [PATH:lower()] = 150 }
	world.skillLines = { { itemIndexOffset = 0, numSpellBookItems = 6, shouldHide = true } }
	world.spellSlots = {
		{ itemType = 1, name = "Zebra", iconID = 300, actionID = 1, spellID = 1, subName = "Rank 1" },
		{ itemType = 1, name = "alpha", iconID = 300, actionID = 2, spellID = 2, subName = "Rank 2" },
		{ itemType = 1, name = "Passive Armor", iconID = 400, actionID = 3, spellID = 3, isPassive = true },
		{ itemType = 2, name = "Future", iconID = 999, spellID = 4 },
		{ itemType = 1, name = "Off Spec", iconID = 999, spellID = 5, isOffSpec = true },
		{ itemType = 3, actionID = 8, name = "Flyout", iconID = 888 },
	}
	world.flyouts = { [8] = { isKnown = true, numSlots = 2, slots = {
		{ isKnown = true, spellID = 11, overrideSpellID = 12 },
		{ isKnown = false, spellID = 13, overrideSpellID = 0 },
	} } }
	world.spells = {
		[1] = { name = "Zebra", iconID = 300 },
		[2] = { name = "alpha", iconID = 300 },
		[3] = { name = "Passive Armor", iconID = 400 },
		[11] = { name = "Flyout Base", iconID = 100 },
		[12] = { name = "Flyout Override", iconID = 150 },
		[13] = { name = "Not Learned", iconID = 999 },
	}
	world.equipment = { [1] = 51 }
	world.bags = { [0] = { 52, 53 } }
	world.items = {
		[51] = { name = "Healing Hat", icon = 200 },
		[52] = { name = "Another Name", icon = 300 },
		[53] = { name = "100% [Potion]", icon = 100 },
	}
	return world, popup
end

local function controls(world, popup)
	local result = { filter = popup.BorderBox.IconTypeDropdown }
	for _, object in ipairs(world.frames) do
		if object.parent and object.parent.parent == popup.BorderBox then
			if object.kind == "EditBox" then result.search = object end
			if object.kind == "DropdownButton" then result.sort = object end
			if object.kind == "FontString" and object.points.TOPLEFT[2] == -43 then result.status = object end
		end
	end
	assert(result.search and result.sort and result.status, "Missing picker controls")
	return result
end

local function choose(dropdown, label)
	for _, option in ipairs(dropdown.menu) do
		if option.label == label then option.action(); return end
	end
	error("Missing menu option: " .. label)
end

local function open(world, popup)
	loadAddon(world)
	popup:Show()
	return controls(world, popup)
end

describe("native macro icon picker enhancement", function()
	it("finds grounded color/object keywords with literal AND terms, including concrete low-confidence tags", function()
		local world, popup = fixture()
		world.icons = { { 236526, 135383, 132806, 3565444, 804461, 4622456 }, { 236526 } }
		local ui = open(world, popup)
		for query, expected in pairs({
			[" GREEN \t shield "] = { 236526, 236526 },
			["blue sword"] = { 135383 },
			["drink"] = { 132806 },
			["lightning"] = { 3565444 },
			["orange paired"] = { 4622456 },
			["green sword drink"] = {},
			[".*"] = {},
			["["] = {},
			["%"] = {},
			["bat-like"] = {},
		}) do
			ui.search:SetText(query)
			assert.same(expected, popup.IconSelector.selections, query)
		end
		assert.equals(1, world.spellScans)
		assert.equals(6, world.bagScans)
	end)

	it("combines terms across live names, keywords and IDs without turning keywords into sort names", function()
		local world, popup = fixture()
		world.icons = { { 236526, 300, 135383, LOOSE }, {} }
		world.spellSlots[1].name = "Ward Slot"
		world.spells[1] = { name = "Zebra Ward", iconID = 236526 }
		local ui = open(world, popup)
		ui.search:SetText("ward green 2365")
		assert.same({ 236526 }, popup.IconSelector.selections)
		ui.search:SetText("alpha 300")
		assert.same({ 300 }, popup.IconSelector.selections)
		ui.search:SetText("icons\\loose")
		assert.same({ LOOSE }, popup.IconSelector.selections)
		ui.search:SetText("")
		choose(ui.sort, "Name A-Z")
		assert.same({ 300, 236526, QUESTION, 135383, LOOSE }, popup.IconSelector.selections)
		world.spells[1].name = "Updated Ward"
		world:event("SPELLS_CHANGED")
		world:tick()
		ui.search:SetText("updated green")
		assert.same({ 236526 }, popup.IconSelector.selections)
		ui.search:SetText("zebra green")
		assert.same({}, popup.IconSelector.selections)
	end)

	it("annotates only native rows and preserves hidden selection and native save after keyword search", function()
		local world, popup = fixture()
		world.icons = { { 236526, 300, 236526 }, { 999 } }
		world.macroTexture, world.macroName = 300, "Original name"
		local ui = open(world, popup)
		ui.search:SetText("blue sword")
		assert.same({}, popup.IconSelector.selections)
		ui.search:SetText("green shield")
		assert.same({ 236526, 236526 }, popup.IconSelector.selections)
		assert.equals(300, popup.BorderBox.SelectedIconArea.SelectedIconButton:GetIconTexture())
		assert.is_nil(world.savedMacro)
		popup.IconSelector:OnSelection(2)
		popup:OkayButton_OnClick()
		assert.same({ name = "Original name", texture = 236526 }, world.savedMacro)
		popup:Show()
		ui.search:SetText("")
		assert.same({ QUESTION, 236526, 300, 236526, 999 }, popup.IconSelector.selections)
		choose(ui.filter, "Item Icons")
		ui.search:SetText("green shield")
		assert.same({}, popup.IconSelector.selections)
		popup:CancelButton_OnClick()
		assert.same({ name = "Original name", texture = 236526 }, world.savedMacro)
	end)

	it("maps the native grid through one ordered provider, retains duplicates and restores it on close", function()
		local world, popup = fixture()
		world.extraIcons = { 700, 300 }
		local nativeShow = popup.scripts.OnShow
		local nativeOkay, nativeCancel = popup.OkayButton_OnClick, popup.CancelButton_OnClick
		open(world, popup)
		assert.same({ QUESTION, 700, 300, 300, 100, 300, PATH, LOOSE, 999, 200, 300, 100 }, popup.IconSelector.selections)
		assert.equals(12, popup:GetNumIcons())
		assert.equals(PATH, popup:GetIconByIndex(7))
		assert.equals(3, popup:GetIndexOfIcon(300))
		assert.equals(1, popup:GetIndexOfIcon(134400))
		assert.equals(nativeShow, popup.scripts.OnShow)
		assert.equals(nativeOkay, popup.OkayButton_OnClick)
		assert.equals(nativeCancel, popup.CancelButton_OnClick)
		popup:Hide()
		assert.equals(popup.nativeProvider, popup.iconDataProvider)
		popup:Show()
		assert.equals(2, popup.nativeShows)
		assert.equals(12, popup:GetNumIcons())
		assert.equals(3, popup:GetIndexOfIcon(300))
	end)

	it("searches every associated character/item name, ranks, numeric IDs and resolved paths literally", function()
		local world, popup = fixture()
		world.bags[5] = { 55 }
		world.items[55] = { name = "Carried Reagent", icon = 999 }
		local ui = open(world, popup)
		for _, query in ipairs({ "ZEB", "alpha", "another NAME", "rank 2", "zebra alpha" }) do
			ui.search:SetText(query)
			assert.same({ 300, 300, 300 }, popup.IconSelector.selections)
		end
		ui.search:SetText("healing h")
		assert.same({ 200 }, popup.IconSelector.selections)
		ui.search:SetText("100% [")
		assert.same({ 100, 100 }, popup.IconSelector.selections)
		ui.search:SetText("150")
		assert.same({ PATH }, popup.IconSelector.selections)
		ui.search:SetText("flyout override")
		assert.same({ PATH }, popup.IconSelector.selections)
		ui.search:SetText("134400")
		assert.same({ QUESTION }, popup.IconSelector.selections)
		ui.search:SetText("carried reagent")
		assert.same({ 999 }, popup.IconSelector.selections)
		assert.equals(1, world.spellScans)
		assert.equals(6, world.bagScans)
	end)

	it("keeps native categories and includes raw learned passives, low ranks and known flyout members in My Spells", function()
		local world, popup = fixture()
		local ui = open(world, popup)
		choose(ui.filter, "Spell Icons")
		assert.same({ QUESTION, 300, 100, 300, PATH, LOOSE, 999 }, popup.IconSelector.selections)
		choose(ui.filter, "Item Icons")
		assert.same({ QUESTION, 200, 300, 100 }, popup.IconSelector.selections)
		choose(ui.filter, "My Character's Spells")
		assert.same({ 300, 100, 300, PATH, 300, 100, 400 }, popup.IconSelector.selections)
		ui.search:SetText("passive")
		assert.same({ 400 }, popup.IconSelector.selections)
		ui.search:SetText("not learned")
		assert.same({}, popup.IconSelector.selections)
		ui.search:SetText("")
		choose(ui.filter, "All Icons")
		assert.equals(10, popup:GetNumIcons())
	end)

	it("associates both a learned spell's base and overriding name/icon without a whole-spell scan", function()
		local world, popup = fixture()
		world.spellSlots[2].actionID = 21
		world.spells[21] = { name = "Base Ability", iconID = 210 }
		local ui = open(world, popup)
		choose(ui.filter, "My Character's Spells")
		ui.search:SetText("base ability")
		assert.same({ 210 }, popup.IconSelector.selections)
		ui.search:SetText("alpha")
		assert.same({ 300, 300, 300 }, popup.IconSelector.selections)
		assert.is_nil(world.spellRequests)
	end)

	it("sorts named before unnamed and numeric before unresolved, with stable native ties", function()
		local world, popup = fixture()
		local ui = open(world, popup)
		choose(ui.sort, "Name A-Z")
		assert.same({ 100, 100, 300, 300, 300, PATH, 200, QUESTION, LOOSE, 999 }, popup.IconSelector.selections)
		choose(ui.sort, "Icon ID")
		assert.same({ 100, 100, PATH, 200, 300, 300, 300, 999, QUESTION, LOOSE }, popup.IconSelector.selections)
		choose(ui.sort, "Blizzard Order")
		assert.same({ QUESTION, 300, 100, 300, PATH, LOOSE, 999, 200, 300, 100 }, popup.IconSelector.selections)
	end)

	it("keeps different textures with the same alphabetical name in their native tie order", function()
		local world, popup = fixture()
		world.items[51].name = "ALPHA"
		local ui = open(world, popup)
		choose(ui.sort, "Name A-Z")
		assert.same({ 100, 100, 300, 300, 200, 300, PATH, QUESTION, LOOSE, 999 }, popup.IconSelector.selections)
	end)

	it("reports empty results, partial names, unavailable IDs and literal unresolved-path search", function()
		local world, popup = fixture()
		local ui = open(world, popup)
		assert.matches("Unresolved paths: 1", ui.status:GetText(), 1, true)
		ui.search:SetText("ICONS\\loose")
		assert.same({ LOOSE }, popup.IconSelector.selections)
		ui.search:SetText(".*")
		assert.same({}, popup.IconSelector.selections)
		assert.matches("No matching icons.", ui.status:GetText(), 1, true)
		assert.matches("Unresolved paths: 1", ui.status:GetText(), 1, true)
	end)

	it("keeps paths honest when file-ID resolution is unavailable rather than guessing IDs or names", function()
		local world, popup = fixture()
		world.env.C_UIFileAsset = nil
		local ui = open(world, popup)
		ui.search:SetText("150")
		assert.same({}, popup.IconSelector.selections)
		ui.search:SetText("icons\\known")
		assert.same({ PATH }, popup.IconSelector.selections)
		assert.matches("Unresolved paths: 3", ui.status:GetText(), 1, true)
	end)

	it("preserves native name and hidden selection, then saves the clicked mapped texture through native Okay", function()
		local world, popup = fixture()
		world.macroTexture, world.macroName = 300, "Original name"
		local ui = open(world, popup)
		popup.BorderBox.IconSelectorEditBox:SetText("Renamed")
		ui.search:SetText("healing")
		assert.is_nil(popup.IconSelector:GetSelectedIndex())
		assert.equals(300, popup.BorderBox.SelectedIconArea.SelectedIconButton:GetIconTexture())
		assert.equals("Renamed", popup.BorderBox.IconSelectorEditBox:GetText())
		assert.is_nil(world.savedMacro)
		popup.IconSelector:OnSelection(1)
		assert.equals(200, popup.BorderBox.SelectedIconArea.SelectedIconButton:GetIconTexture())
		popup:OkayButton_OnClick()
		assert.same({ name = "Renamed", texture = 200 }, world.savedMacro)
	end)

	it("leaves a new macro's name empty until native input, then confirms its filtered texture", function()
		local world, popup = fixture()
		world.newMacro = true
		local ui = open(world, popup)
		assert.equals("", popup.BorderBox.IconSelectorEditBox:GetText())
		assert.is_nil(world.savedMacro)
		popup.BorderBox.IconSelectorEditBox:SetText("New macro")
		choose(ui.sort, "Name A-Z")
		ui.search:SetText("flyout override")
		popup.IconSelector:OnSelection(1)
		popup:OkayButton_OnClick()
		assert.same({ name = "New macro", texture = PATH }, world.savedMacro)
	end)

	it("retains dragged textures outside a filtered view and leaves Cancel native and non-saving", function()
		local world, popup = fixture()
		local ui = open(world, popup)
		ui.search:SetText("no match")
		world.cursorTexture = 876
		popup:UpdateStateFromCursorType()
		assert.is_false(ui.search:IsVisible())
		popup:SetIconFromMouse()
		world.cursorTexture = nil
		popup:UpdateStateFromCursorType()
		assert.is_true(ui.search:IsVisible())
		choose(ui.sort, "Icon ID")
		assert.is_nil(popup.IconSelector:GetSelectedIndex())
		assert.equals(876, popup.BorderBox.SelectedIconArea.SelectedIconButton:GetIconTexture())
		popup:OkayButton_OnClick()
		assert.equals(876, world.savedMacro.texture)
		world.savedMacro = nil
		popup:Show()
		ui.search:SetText("healing")
		popup.IconSelector:OnSelection(1)
		popup:CancelButton_OnClick()
		assert.is_nil(world.savedMacro)
		popup:Show()
		assert.equals("", ui.search:GetText())
		assert.equals(10, popup:GetNumIcons())
	end)

	it("loads only missing carried items, coalesces relevant events and refreshes asynchronous names without retry loops", function()
		local world, popup = fixture()
		world.bags[0] = { 52, 54, 54 }
		local ui = open(world, popup)
		assert.same({ 54 }, world.itemRequests)
		assert.matches("Unavailable item names: 1", ui.status:GetText(), 1, true)
		world:event("ITEM_DATA_LOAD_RESULT", 9999, true)
		world:tick()
		assert.equals(6, world.bagScans)
		world:event("ITEM_DATA_LOAD_RESULT", 54, false)
		world:tick()
		assert.same({ 54 }, world.itemRequests)
		world.items[54] = { name = "Loaded Trinket", icon = 999 }
		world:event("ITEM_DATA_LOAD_RESULT", 54, true)
		world:event("BAG_UPDATE_DELAYED")
		world:tick()
		assert.equals(18, world.bagScans)
		assert.equals(1, world.spellScans)
		ui.search:SetText("loaded trinket")
		assert.same({ 999 }, popup.IconSelector.selections)
		world.bags[0] = {}
		world.equipment = {}
		world:event("PLAYER_EQUIPMENT_CHANGED", 1)
		world:tick()
		assert.same({}, popup.IconSelector.selections)
		popup:Hide()
		local scans = world.bagScans
		world:event("BAG_UPDATE_DELAYED")
		world:tick()
		assert.equals(scans, world.bagScans)
	end)

	it("reindexes learned spell changes without an item rescan or enumerating on each keystroke", function()
		local world, popup = fixture()
		local ui = open(world, popup)
		choose(ui.filter, "My Character's Spells")
		world.spellSlots[3].name = "New Passive"
		world.spellSlots[3].iconID = 401
		world.spells[3] = { name = "New Passive", iconID = 401 }
		world:event("SPELLS_CHANGED")
		world:event("SPELL_TEXT_UPDATE")
		world:tick()
		ui.search:SetText("new passive")
		assert.same({ 401 }, popup.IconSelector.selections)
		assert.equals(2, world.spellScans)
		assert.equals(6, world.bagScans)
	end)

	it("does not lose a synchronous metadata completion raised during an inventory refresh", function()
		local world, popup = fixture()
		local ui = open(world, popup)
		world.bags[0] = { 54 }
		world.env.C_Item.RequestLoadItemDataByID = function(id)
			world.items[id] = { name = "Immediate Cache Fill", icon = 999 }
			world:event("ITEM_DATA_LOAD_RESULT", id, true)
		end
		world:event("BAG_UPDATE_DELAYED")
		world:tick()
		world:tick()
		ui.search:SetText("immediate cache")
		assert.same({ 999 }, popup.IconSelector.selections)
	end)

	it("refreshes missing learned spell names asynchronously, without requesting unlearned or retrying failed data", function()
		local world, popup = fixture()
		world.spellSlots[3].name = ""
		world.spells[3] = nil
		local ui = open(world, popup)
		assert.same({ 3 }, world.spellRequests)
		assert.matches("Unavailable spell names: 1", ui.status:GetText(), 1, true)
		world:event("SPELL_DATA_LOAD_RESULT", 4, true)
		world:tick()
		assert.equals(1, world.spellScans)
		world:event("SPELL_DATA_LOAD_RESULT", 3, false)
		world:tick()
		assert.same({ 3 }, world.spellRequests)
		world.spells[3] = { name = "Loaded Passive", iconID = 400 }
		world:event("SPELL_DATA_LOAD_RESULT", 3, true)
		world:tick()
		choose(ui.filter, "My Character's Spells")
		ui.search:SetText("loaded passive")
		assert.same({ 400 }, popup.IconSelector.selections)
		assert.equals(6, world.bagScans)
	end)

	it("attaches to an already-open native popup and keeps controls within its unchanged footprint", function()
		local world, popup = fixture()
		popup:Show()
		loadAddon(world)
		local ui = controls(world, popup)
		assert.equals(10, popup:GetNumIcons())
		assert.equals(525, popup:GetWidth())
		assert.equals(495, popup:GetHeight())
		assert.is_true(ui.search:GetTop() < popup:GetTop() - 90)
		assert.is_true(ui.status:GetBottom() > popup.IconSelector:GetTop())
		assert.is_true(popup.IconSelector:GetBottom() > popup:GetBottom() + 30)
		assert.is_true(popup.IconSelector:GetHeight() >= 250)
		assert.is_false(ui.search.autoFocus)
	end)
end)
