local _, ns = ...

function ns.CreateIconMetadata()
	local metadata = {
		spells = {}, items = {}, learned = {}, spellOrder = {}, pending = {}, requested = {},
		pendingSpells = {}, requestedSpells = {},
	}
	local fileIDs = {}

	function metadata:Identity(texture)
		if texture == nil then return nil end
		if type(texture) == "number" then return texture end
		local path = texture:lower()
		if fileIDs[path] == nil then
			fileIDs[path] = C_UIFileAsset and C_UIFileAsset.GetFileID and C_UIFileAsset.GetFileID(texture) or false
		end
		return fileIDs[path] or path
	end

	local function associate(names, key, name)
		if name and name ~= "" then
			names[key] = names[key] or {}
			names[key][name] = true
		end
	end

	function metadata:RefreshSpells()
		self.spells, self.learned, self.spellOrder = {}, {}, {}
		self.pendingSpells, self.missingSpells = {}, 0
		local bank = Enum.SpellBookSpellBank.Player
		local function add(texture, name, subName)
			if not texture then return end
			local key = self:Identity(texture)
			if not self.learned[key] then
				self.learned[key] = true
				self.spellOrder[#self.spellOrder + 1] = texture
			end
			associate(self.spells, key, name)
			if name and subName and subName ~= "" then
				associate(self.spells, key, name .. " (" .. subName .. ")")
			end
		end
		local function addSpell(spellID)
			if not spellID or spellID == 0 then return end
			local info = C_Spell.GetSpellInfo(spellID)
			if info then add(info.iconID, info.name) end
			if not info or not info.name or info.name == "" or not info.iconID then
				if not self.pendingSpells[spellID] then
					self.pendingSpells[spellID] = true
					self.missingSpells = self.missingSpells + 1
				end
				if not self.requestedSpells[spellID] then
					self.requestedSpells[spellID] = true
					C_Spell.RequestLoadSpellData(spellID)
				end
			end
		end
		for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
			local skill = C_SpellBook.GetSpellBookSkillLineInfo(line)
			if skill then
				for slot = skill.itemIndexOffset + 1, skill.itemIndexOffset + skill.numSpellBookItems do
					local info = C_SpellBook.GetSpellBookItemInfo(slot, bank)
					if info and not info.isOffSpec then
						if info.itemType == Enum.SpellBookItemType.Spell then
							-- Enumerate raw player slots, not the display's passive/rank/flyout filters.
							add(info.iconID, info.name, info.subName)
							addSpell(info.actionID)
							addSpell(info.spellID)
						elseif info.itemType == Enum.SpellBookItemType.Flyout then
							local flyout = C_Flyout.GetFlyoutInfo(info.actionID)
							if flyout and flyout.isKnown then
								for index = 1, flyout.numSlots do
									local member = C_Flyout.GetFlyoutSlotInfo(info.actionID, index)
									if member and member.isKnown then
										addSpell(member.spellID)
										addSpell(member.overrideSpellID)
									end
								end
							end
						end
					end
				end
			end
		end
	end

	function metadata:RefreshItems()
		self.items, self.pending, self.missingItems = {}, {}, 0
		local seen = {}
		local function add(itemID)
			if not itemID or seen[itemID] then return end
			seen[itemID] = true
			local name, _, _, _, _, _, _, _, _, texture = C_Item.GetItemInfo(itemID)
			if name and texture then
				associate(self.items, self:Identity(texture), name)
			else
				self.missingItems = self.missingItems + 1
				self.pending[itemID] = true
				if not self.requested[itemID] then
					self.requested[itemID] = true
					C_Item.RequestLoadItemDataByID(itemID)
				end
			end
		end
		for slot = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do add(GetInventoryItemID("player", slot)) end
		for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
			for slot = 1, C_Container.GetContainerNumSlots(bag) do
				add(C_Container.GetContainerItemID(bag, slot))
			end
		end
	end

	function metadata:Names(key)
		local names = {}
		for name in pairs(self.spells[key] or {}) do names[name] = true end
		for name in pairs(self.items[key] or {}) do names[name] = true end
		return names
	end

	return metadata
end
