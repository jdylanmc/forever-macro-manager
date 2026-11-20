local _, ns = ...

local FILTERS = {
	{ "all", "All Icons" }, { "spell", "Spell Icons" }, { "item", "Item Icons" },
	{ "mine", "My Character's Spells" },
}
local SORTS = { { "original", "Blizzard Order" }, { "name", "Name A-Z" }, { "id", "Icon ID" } }

function ns.AttachIconPicker(popup)
	local controls = CreateFrame("Frame", nil, popup.BorderBox)
	controls:SetPoint("TOPLEFT", 25, -100)
	controls:SetPoint("TOPRIGHT", -35, -100)
	controls:SetHeight(74)

	local search = CreateFrame("EditBox", nil, controls, "InputBoxTemplate")
	search:SetSize(250, 22)
	search:SetPoint("TOPLEFT", 6, 0)
	search:SetAutoFocus(false)
	search:SetMaxLetters(80)
	search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	local sort = CreateFrame("DropdownButton", nil, controls, "WowStyle1DropdownTemplate")
	sort:SetSize(180, 22)
	sort:SetPoint("TOPRIGHT", 0, 0)
	local hint = controls:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hint:SetPoint("TOPLEFT", 0, -26)
	hint:SetWidth(465)
	hint:SetJustifyH("LEFT")
	hint:SetText("Search icon ID / name. Names: learned spells and equipped/bag items only.")
	local status = controls:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	status:SetPoint("TOPLEFT", 0, -43)
	status:SetWidth(465)
	status:SetHeight(28)
	status:SetJustifyH("LEFT")

	-- Reserve space inside the existing popup; name, selected icon and footer stay native.
	popup.IconSelector:ClearAllPoints()
	popup.IconSelector:SetPoint("TOPLEFT", 21, -179)
	popup.IconSelector:SetPoint("BOTTOMRIGHT", -10, 37)
	local events = CreateFrame("Frame")
	local catalog, metadata, source
	local spellDirty, itemDirty

	local function refresh()
		if not catalog then return end
		catalog:Rebuild()
		popup.IconSelector:UpdateSelections()
		popup:ReevaluateSelectedIcon()
		popup.IconSelector:ScrollToSelectedIndex()
		local message = #catalog.rows == 0 and "No matching icons." or (#catalog.rows .. " icons.")
		if catalog.unresolved > 0 then
			message = message .. " Unresolved paths: " .. catalog.unresolved .. " (path search)."
		end
		if metadata.missingItems > 0 then message = message .. " Unavailable item names: " .. metadata.missingItems .. "." end
		if metadata.missingSpells > 0 then message = message .. " Unavailable spell names: " .. metadata.missingSpells .. "." end
		status:SetText(message)
	end

	local function menu(dropdown, options, field)
		dropdown:SetupMenu(function(_, root)
			for _, option in ipairs(options) do
				local value, label = option[1], option[2]
				root:CreateRadio(label, function() return catalog and catalog[field] == value end, function()
					if not catalog then return end
					catalog[field] = value
					refresh()
				end)
			end
		end)
	end

	local function updateMenus()
		if not catalog then return end
		popup.BorderBox.IconTypeDropdown:SetWidth(210)
		menu(popup.BorderBox.IconTypeDropdown, FILTERS, "filter")
		menu(sort, SORTS, "sort")
	end
	hooksecurefunc(popup, "UpdateDropdown", updateMenus)
	local function updateVisibility()
		controls:SetShown(popup.IconSelector:IsShown())
	end
	hooksecurefunc(popup, "UpdateStateFromCursorType", updateVisibility)
	search:SetScript("OnTextChanged", function(self)
		if catalog then
			catalog.query = self:GetText()
			refresh()
		end
	end)

	events:SetScript("OnEvent", function(_, event, dataID)
		if event == "ITEM_DATA_LOAD_RESULT" then
			if not metadata or not metadata.pending[dataID] then return end
			itemDirty = true
		elseif event == "SPELL_DATA_LOAD_RESULT" then
			if not metadata or not metadata.pendingSpells[dataID] then return end
			spellDirty = true
		elseif event == "SPELLS_CHANGED" or event == "SPELL_TEXT_UPDATE" then
			spellDirty = true
		else
			itemDirty = true
		end
		events:SetScript("OnUpdate", function(self)
			self:SetScript("OnUpdate", nil)
			if not catalog then return end
			local refreshSpells, refreshItems = spellDirty, itemDirty
			spellDirty, itemDirty = nil, nil
			if refreshSpells then metadata:RefreshSpells() end
			if refreshItems then metadata:RefreshItems() end
			refresh()
		end)
	end)

	local function show()
		source = popup.iconDataProvider
		metadata = ns.CreateIconMetadata()
		for _, event in ipairs({ "SPELLS_CHANGED", "SPELL_TEXT_UPDATE", "SPELL_DATA_LOAD_RESULT", "PLAYER_EQUIPMENT_CHANGED",
			"BAG_UPDATE_DELAYED", "ITEM_DATA_LOAD_RESULT" }) do events:RegisterEvent(event) end
		metadata:RefreshSpells()
		metadata:RefreshItems()
		catalog = ns.CreateIconCatalog(source, metadata)
		popup.iconDataProvider = catalog
		search:SetText("")
		updateMenus()
		updateVisibility()
		refresh()
	end
	popup:HookScript("OnShow", show)
	popup:HookScript("OnHide", function()
		popup.iconDataProvider = source
		catalog, metadata, source = nil, nil, nil
		spellDirty, itemDirty = nil, nil
		events:UnregisterAllEvents()
		events:SetScript("OnUpdate", nil)
	end)
	if popup:IsShown() then show() end
end
