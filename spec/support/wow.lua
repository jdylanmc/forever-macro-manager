local Wow = {}

function Wow.new()
	local world = { frames = {}, named = {}, namespace = {}, errors = {} }
	local function letters(text)
		local _, count = text:gsub("[^\128-\193]", "")
		return count
	end
	local methods = {}
	local function frame(kind, name, parent, template)
		local object = setmetatable({
			kind = kind, name = name, parent = parent, children = {}, hooks = {},
			scripts = {}, registered = {}, points = {}, shown = true, scale = 1,
			width = 0, height = 0, left = 0, bottom = 0, verticalScroll = 0, enabled = true,
		}, { __index = methods })
		if parent then parent.children[#parent.children + 1] = object end
		world.frames[#world.frames + 1] = object
		if name then world.named[name] = object end
		if template == "UIPanelScrollFrameTemplate" then
			object.scripts.OnScrollRangeChanged = function(self)
				self.nativeRangeCalls = (self.nativeRangeCalls or 0) + 1
			end
		end
		return object
	end
	function methods:Fire(script, ...)
		if self.scripts[script] then self.scripts[script](self, ...) end
		for _, hook in ipairs(self.hooks[script] or {}) do hook(self, ...) end
	end
	function methods:SetScript(script, callback) self.scripts[script] = callback end
	function methods:HookScript(script, callback)
		self.hooks[script] = self.hooks[script] or {}
		table.insert(self.hooks[script], callback)
	end
	function methods:RegisterEvent(event) self.registered[event] = true end
	function methods:UnregisterEvent(event) self.registered[event] = nil end
	function methods:UnregisterAllEvents() self.registered = {} end
	function methods:IsShown() return self.shown end
	function methods:IsVisible()
		return self.shown and (not self.parent or self.parent:IsVisible())
	end
	local function visibility(object, script)
		object:Fire(script)
		for _, child in ipairs(object.children) do
			if child.shown then visibility(child, script) end
		end
	end
	function methods:Show()
		local visible = self:IsVisible()
		self.shown = true
		if not visible and self:IsVisible() then visibility(self, "OnShow") end
	end
	function methods:Hide()
		local visible = self:IsVisible()
		self.shown = false
		if visible then visibility(self, "OnHide") end
	end
	function methods:SetShown(shown)
		if shown then self:Show() else self:Hide() end
	end
	function methods:SetScale(value) self.scale = value end
	function methods:GetEffectiveScale()
		return self.scale * (self.parent and self.parent:GetEffectiveScale() or 1)
	end
	function methods:SetSize(width, height)
		local changed = self.width ~= width or self.height ~= height
		self.width, self.height = width, height
		if changed then self:Fire("OnSizeChanged", width, height) end
	end
	function methods:SetWidth(value) self.width = value end
	function methods:SetHeight(value) self.height = value end
	function methods:GetWidth()
		if self.points.TOPLEFT and self.points.BOTTOMRIGHT then
			return self.parent:GetWidth() - self.points.TOPLEFT[1] + self.points.BOTTOMRIGHT[1]
		end
		return self.width
	end
	function methods:GetHeight()
		if self.points.TOPLEFT and self.points.BOTTOMRIGHT then
			return self.parent:GetHeight() + self.points.TOPLEFT[2] - self.points.BOTTOMRIGHT[2]
		end
		return self.height
	end
	function methods:GetLeft()
		if self.unpositioned then return nil end
		if self.anchorRelative then
			local left = self.anchorRelative:GetLeft()
			if self.anchorRelativePoint:find("RIGHT") then left = self.anchorRelative:GetRight() end
			local ownOffset = self.anchorPoint:find("RIGHT") and self:GetWidth() or 0
			return left * self.anchorRelative:GetEffectiveScale() / self:GetEffectiveScale() + self.anchorX - ownOffset
		end
		return self.left
	end
	function methods:GetRight()
		if self.unpositioned then return nil end
		return self:GetLeft() + self:GetWidth()
	end
	function methods:GetBottom()
		if self.unpositioned then return nil end
		if self.anchorRelative then
			local bottom = self.anchorRelativePoint:find("TOP")
				and self.anchorRelative:GetTop() or self.anchorRelative:GetBottom()
			local ownOffset = self.anchorPoint:find("TOP") and self:GetHeight() or 0
			return bottom * self.anchorRelative:GetEffectiveScale() / self:GetEffectiveScale() + self.anchorY - ownOffset
		end
		return self.bottom
	end
	function methods:GetTop()
		if self.unpositioned then return nil end
		return self:GetBottom() + self:GetHeight()
	end
	function methods:ClearAllPoints()
		self.points = {}
		self.anchorRelative = nil
	end
	function methods:SetPoint(point, relative, relativePoint, x, y)
		if type(relative) == "number" then
			self.points[point] = { relative, relativePoint }
			x, y, relative, relativePoint = relative, relativePoint, self.parent, point
		else
			self.points[point] = { x or 0, y or 0 }
			relative, relativePoint = relative or self.parent, relativePoint or point
		end
		if relative and (not self.anchorRelative or point == "TOPLEFT") then
			self.anchorRelative = relative
			self.anchorX, self.anchorY = x or 0, y or 0
			self.anchorPoint, self.anchorRelativePoint = point, relativePoint
		end
	end
	function methods:SetScrollChild(child) self.scrollChild = child end
	function methods:GetVerticalScroll() return self.verticalScroll end
	function methods:SetVerticalScroll(value) self.verticalScroll = value end
	function methods:GetVerticalScrollRange()
		return math.max(0, self.scrollChild:GetHeight() - self:GetHeight())
	end
	function methods:CreateFontString() return frame("FontString", nil, self) end
	function methods:SetText(text)
		self.text = text
		if self.kind == "EditBox" then
			self.cursor, self.selectionStart, self.selectionEnd = #text, nil, nil
			self:Fire("OnTextChanged", false)
		end
	end
	function methods:GetText() return self.text end
	function methods:SetTextColor(...) self.color = { ... } end
	function methods:SetNonSpaceWrap(value) self.nonSpaceWrap = value end
	function methods:IsEnabled() return self.enabled end
	function methods:GetSelectedIndex() return self.selectedIndex end
	function methods:GetMaxLetters() return self.maxLetters or 0 end
	function methods:GetMaxBytes() return self.maxBytes or 0 end
	function methods:GetNumLetters() return letters(self.text) end
	function methods:IsInIMECompositionMode() return self.composing or false end
	function methods:SetCursorPosition(position)
		self.cursor, self.selectionStart, self.selectionEnd = position, nil, nil
	end
	function methods:GetCursorPosition() return self.cursor end
	function methods:HighlightText(first, last)
		self.selectionStart, self.selectionEnd = first or 0, last or #self.text
	end
	function methods:SetFocus() self.focused = true end
	function methods:ClearFocus() self.focused = false end
	function methods:SetAutoFocus(value) self.autoFocus = value end
	function methods:SetMaxLetters(value) self.maxLetters = value end
	function methods:SetupMenu(callback)
		self.menu = {}
		local root = {}
		function root:CreateRadio(label, selected, action)
			table.insert(self.options, { label = label, selected = selected, action = action })
		end
		root.options = self.menu
		callback(self, root)
	end
	function methods:Insert(text)
		self.insertCalls = (self.insertCalls or 0) + 1
		local first, last = self.selectionStart or self.cursor, self.selectionEnd or self.cursor
		local before, after = self.text:sub(1, first), self.text:sub(last + 1)
		-- Native Insert can truncate at the configured ceilings.
		while #text > 0 and ((self:GetMaxLetters() > 0
			and letters(before .. text .. after) > self:GetMaxLetters())
			or (self:GetMaxBytes() > 0 and #before + #text + #after > self:GetMaxBytes())) do
			text = text:sub(1, -2)
		end
		self.text = before .. text .. after
		self.cursor, self.selectionStart, self.selectionEnd = #before + #text, nil, nil
		self:Fire("OnTextChanged", false)
	end
	function methods:Click() self:Fire("OnClick", "LeftButton") end
	function methods:GetStringHeight()
		local lines = 0
		for line in (self.text .. "\n"):gmatch("(.-)\n") do
			lines = lines + math.max(1, math.ceil(#line * 7 / math.max(self.width, 1)))
		end
		return lines * 14
	end
	function methods:SetBackdrop(value) self.backdrop = value end
	function methods:SetClampedToScreen(value) self.clamped = value end
	function methods:EnableMouse(value) self.mouse = value end
	function methods:EnableMouseWheel(value) self.mouseWheel = value end
	function methods:SetJustifyH() end
	function methods:SetJustifyV() end

	world.env = setmetatable({
		CreateFrame = frame,
		InCombatLockdown = function() return world.combat or false end,
		UIErrorsFrame = {
			AddMessage = function(_, message) world.errors[#world.errors + 1] = message end,
		},
		GameTooltip = {
			SetOwner = function(self, owner) self.owner = owner end,
			SetText = function(self, text) self.text = text end,
			AddLine = function(self, line) self.line = line end,
			Show = function(self) self.shown = true end,
			Hide = function(self) self.shown = false end,
		},
		hooksecurefunc = function(object, method, hook)
			local original = object[method]
			object[method] = function(self, ...)
				local result = original(self, ...)
				hook(self, ...)
				return result
			end
		end,
		Enum = { SpellBookSpellBank = { Player = 0, Pet = 1 },
			SpellBookItemType = { Spell = 1, FutureSpell = 2, Flyout = 3, PetAction = 4 } },
		IconDataProviderIconType = { Spell = 1, Item = 2 },
		INVSLOT_FIRST_EQUIPPED = 1, INVSLOT_LAST_EQUIPPED = 19, NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5,
		C_UIFileAsset = { GetFileID = function(path)
			return world.pathIDs and world.pathIDs[path:lower()]
		end },
		C_SpellBook = {
			GetNumSpellBookSkillLines = function()
				world.spellScans = (world.spellScans or 0) + 1
				return #(world.skillLines or {})
			end,
			GetSpellBookSkillLineInfo = function(index) return world.skillLines[index] end,
			GetSpellBookItemInfo = function(slot, bank)
				assert(bank == 0, "Never enumerate the pet spell bank")
				return world.spellSlots[slot]
			end,
		},
		C_Flyout = {
			GetFlyoutInfo = function(id) return world.flyouts[id] end,
			GetFlyoutSlotInfo = function(id, slot) return world.flyouts[id].slots[slot] end,
		},
		C_Spell = {
			GetSpellInfo = function(id) return world.spells[id] end,
			RequestLoadSpellData = function(id)
				world.spellRequests = world.spellRequests or {}
				world.spellRequests[#world.spellRequests + 1] = id
			end,
		},
		GetInventoryItemID = function(_, slot) return (world.equipment or {})[slot] end,
		C_Container = {
			GetContainerNumSlots = function(bag)
				world.bagScans = (world.bagScans or 0) + 1
				return #((world.bags or {})[bag] or {})
			end,
			GetContainerItemID = function(bag, slot) return world.bags[bag][slot] end,
		},
		C_Item = {
			GetItemInfo = function(id)
				local item = (world.items or {})[id]
				if item then return item.name, nil, nil, nil, nil, nil, nil, nil, nil, item.icon end
			end,
			RequestLoadItemDataByID = function(id)
				world.itemRequests = world.itemRequests or {}
				world.itemRequests[#world.itemRequests + 1] = id
			end,
		},
	}, { __index = _G })
	world.env.UIParent = frame("Frame")
	world.env.UIParent:SetSize(1280, 800)
	function world:editor(shown, left, bottom)
		local editor = frame("Frame", "MacroFrame", self.env.UIParent)
		editor:SetSize(338, 424)
		editor.left, editor.bottom = left or 16, bottom or 300
		editor.shown = shown
		self.env.MacroFrame = editor
		editor.selectedIndex = 1
		local edit = frame("EditBox", "MacroFrameText", editor)
		edit.text, edit.cursor, edit.maxLetters = "", 0, 255
		edit:SetScript("OnTextChanged", function()
			editor.textChanged = 1
			edit.nativeTextChanges = (edit.nativeTextChanges or 0) + 1
		end)
		self.env.MacroFrameText = edit
		local popup = frame("Frame", "MacroPopupFrame", editor)
		popup:SetSize(525, 495)
		popup:SetPoint("TOPLEFT", editor, "TOPRIGHT", 0, 5)
		popup.shown = false
		self.env.MacroPopupFrame = popup
		self:picker(popup)
		return editor, popup
	end
	function world:picker(popup)
		local provider = { filter = { 1, 2 } }
		function provider:SetIconTypes(types) self.filter = types end
		function provider:Textures()
			local source = { "INTERFACE\\ICONS\\INV_MISC_QUESTIONMARK" }
			for _, category in ipairs(self.filter) do
				if category == 1 then
					for _, texture in ipairs(world.extraIcons or {}) do source[#source + 1] = texture end
				end
			end
			for _, category in ipairs(self.filter) do
				for _, texture in ipairs((world.icons or {})[category] or {}) do
					source[#source + 1] = texture
				end
			end
			return source
		end
		function provider:GetNumIcons() return #self:Textures() end
		function provider:GetIconByIndex(index) return self:Textures()[index] end
		function provider:GetIndexOfIcon(texture)
			for index, icon in ipairs(self:Textures()) do
				if icon == texture then return index end
			end
		end
		popup.nativeProvider = provider
		popup.BorderBox = frame("Frame", nil, popup)
		popup.BorderBox:SetSize(525, 495)
		popup.BorderBox:SetPoint("TOPLEFT", popup, "TOPLEFT", 0, 0)
		popup.BorderBox.IconTypeDropdown = frame("DropdownButton", nil, popup.BorderBox)
		popup.BorderBox.IconSelectorEditBox = frame("EditBox", nil, popup.BorderBox)
		popup.BorderBox.SelectedIconArea = { SelectedIconButton = {} }
		local selected = popup.BorderBox.SelectedIconArea.SelectedIconButton
		function selected:SetIconTexture(texture) self.texture = texture end
		function selected:GetIconTexture() return self.texture end
		local selector = frame("Frame", nil, popup)
		selector:SetSize(494, 361)
		popup.IconSelector = selector
		function selector:SetSelectionsDataProvider(getSelection, getCount)
			self.getSelection, self.getCount = getSelection, getCount
			self:UpdateSelections()
		end
		function selector:UpdateSelections()
			self.selections = {}
			if self.getCount then
				for index = 1, self.getCount() do self.selections[index] = self.getSelection(index) end
			end
		end
		function selector:SetSelectedIndex(index) self.selectedIndex = index end
		function selector:SetSelectedCallback(callback) self.selectedCallback = callback end
		function selector:ScrollToSelectedIndex() self.scrolledIndex = self.selectedIndex end
		function selector:OnSelection(index)
			self.selectedCallback(index, self.getSelection(index))
			self:SetSelectedIndex(index)
		end
		function popup:GetIconByIndex(index) return self.iconDataProvider:GetIconByIndex(index) end
		function popup:GetNumIcons() return self.iconDataProvider:GetNumIcons() end
		function popup:GetIndexOfIcon(texture) return self.iconDataProvider:GetIndexOfIcon(texture) end
		function popup:ReevaluateSelectedIcon()
			selector:SetSelectedIndex(self:GetIndexOfIcon(selected:GetIconTexture()))
		end
		function popup:UpdateDropdown() self.nativeDropdownCalls = (self.nativeDropdownCalls or 0) + 1 end
		function popup:UpdateStateFromCursorType()
			selector:SetShown(world.cursorTexture == nil)
			self.BorderBox.IconTypeDropdown:SetShown(world.cursorTexture == nil)
		end
		popup:SetScript("OnShow", function()
			popup.nativeShows = (popup.nativeShows or 0) + 1
			popup.iconDataProvider = provider
			popup:UpdateStateFromCursorType()
			provider:SetIconTypes({ 1, 2 })
			popup:UpdateDropdown()
			popup.BorderBox.IconSelectorEditBox:SetText(world.newMacro and "" or world.macroName or "Test macro")
			selected:SetIconTexture(world.macroTexture or provider:GetIconByIndex(1))
			selector:SetSelectionsDataProvider(function(index) return popup:GetIconByIndex(index) end,
				function() return popup:GetNumIcons() end)
			selector:SetSelectedCallback(function(_, texture) selected:SetIconTexture(texture) end)
			popup:ReevaluateSelectedIcon()
		end)
		function popup:OkayButton_OnClick()
			self:Hide()
			world.savedMacro = { name = self.BorderBox.IconSelectorEditBox:GetText(), texture = selected:GetIconTexture() }
		end
		function popup:CancelButton_OnClick() self:Hide() end
		-- Native drag updates the selected texture even if no grid index matches it.
		function popup:SetIconFromMouse()
			local texture = world.cursorTexture
			selector:SetSelectedIndex(self:GetIndexOfIcon(texture))
			selected:SetIconTexture(texture)
		end
	end
	function world:load(file)
		local chunk = assert(loadfile(file))
		setfenv(chunk, self.env)("ForeverMacroManager", self.namespace)
	end
	function world:event(event, ...)
		for _, object in ipairs(self.frames) do
			if object.registered[event] then object:Fire("OnEvent", event, ...) end
		end
	end
	function world:tick()
		for _, object in ipairs(self.frames) do
			if object:IsVisible() then object:Fire("OnUpdate", 0.016) end
		end
	end
	function world:panel() return self.named.ForeverMacroManagerCheatSheet end
	return world
end

return Wow
