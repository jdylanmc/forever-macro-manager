local _, ns = ...

function ns.CreateIconCatalog(provider, metadata)
	local catalog = { filter = "all", sort = "original", query = "" }
	local categories = {
		all = { IconDataProviderIconType.Spell, IconDataProviderIconType.Item },
		spell = { IconDataProviderIconType.Spell },
		item = { IconDataProviderIconType.Item },
	}

	function catalog:Snapshot()
		self.categories = {}
		for _, category in ipairs({ "all", "spell", "item" }) do
			provider:SetIconTypes(categories[category])
			local textures = {}
			for index = 1, provider:GetNumIcons() do textures[index] = provider:GetIconByIndex(index) end
			self.categories[category] = textures
		end
		provider:SetIconTypes(categories.all)
	end

	function catalog:Rebuild()
		local textures = self.categories[self.filter] or self.categories.all
		local rows, seen = {}, {}
		self.unresolved = 0
		local query = self.query:lower()
		local function add(texture, sequence)
			local key = metadata:Identity(texture)
			seen[key] = true
			if self.filter == "mine" and not metadata.learned[key] then return end
			local names = metadata:Names(key)
			local representative, representativeLower
			local id = type(key) == "number" and key or nil
			if not id then self.unresolved = self.unresolved + 1 end
			local matches = query == "" or (id and tostring(id):find(query, 1, true))
				or (type(key) == "string" and key:find(query, 1, true))
			for name in pairs(names) do
				local lower = name:lower()
				if lower:find(query, 1, true) then matches = true end
				if not representative or lower < representativeLower
					or (lower == representativeLower and name < representative) then
					representative, representativeLower = name, lower
				end
			end
			if matches then
				rows[#rows + 1] = { texture = texture, key = key, id = id, name = representativeLower, sequence = sequence }
			end
		end
		for index, texture in ipairs(textures) do add(texture, index) end
		if self.filter == "mine" then
			-- A learned flyout/passive texture may be absent from the native catalogue.
			for index, texture in ipairs(metadata.spellOrder) do
				if not seen[metadata:Identity(texture)] then add(texture, #textures + index) end
			end
		end
		if self.sort ~= "original" then
			local field = self.sort == "name" and "name" or "id"
			table.sort(rows, function(a, b)
				if a[field] ~= b[field] then
					if a[field] == nil then return false end
					if b[field] == nil then return true end
					return a[field] < b[field]
				end
				return a.sequence < b.sequence
			end)
		end
		self.rows = rows
	end

	function catalog:GetNumIcons() return #self.rows end
	function catalog:GetIconByIndex(index) return self.rows[index] and self.rows[index].texture end
	function catalog:GetIndexOfIcon(texture)
		local key = metadata:Identity(texture)
		if key == nil then return nil end
		for index, row in ipairs(self.rows) do
			if row.key == key then return index end
		end
	end
	function catalog:SetIconTypes(types)
		if #types == 1 then
			self.filter = types[1] == IconDataProviderIconType.Spell and "spell" or "item"
		else
			self.filter = "all"
		end
		self:Rebuild()
	end

	catalog:Snapshot()
	catalog:Rebuild()
	return catalog
end
