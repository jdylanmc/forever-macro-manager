local Wow = {}

function Wow.new()
	local world = { frames = {}, named = {}, namespace = {} }
	local methods = {}
	local function frame(kind, name, parent, template)
		local object = setmetatable({
			kind = kind, name = name, parent = parent, children = {}, hooks = {},
			scripts = {}, registered = {}, points = {}, shown = true, scale = 1,
			width = 0, height = 0, left = 0, bottom = 0, verticalScroll = 0,
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
		if self.kind == "ScrollFrame" and self.points.TOPLEFT and self.points.BOTTOMRIGHT then
			return self.parent:GetWidth() - self.points.TOPLEFT[1] + self.points.BOTTOMRIGHT[1]
		end
		return self.width
	end
	function methods:GetHeight()
		if self.kind == "ScrollFrame" and self.points.TOPLEFT and self.points.BOTTOMRIGHT then
			return self.parent:GetHeight() + self.points.TOPLEFT[2] - self.points.BOTTOMRIGHT[2]
		end
		return self.height
	end
	function methods:GetLeft()
		if self.unpositioned then return nil end
		if self.anchorRelative then
			return self.anchorRelative:GetLeft() * self.anchorRelative:GetEffectiveScale() / self:GetEffectiveScale()
				+ self.anchorX
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
			return self.anchorRelative:GetBottom() * self.anchorRelative:GetEffectiveScale() / self:GetEffectiveScale()
				+ self.anchorY
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
		elseif relative then
			assert(point == "BOTTOMLEFT" and relativePoint == "BOTTOMLEFT")
			self.anchorRelative, self.anchorX, self.anchorY = relative, x, y
		end
	end
	function methods:SetScrollChild(child) self.scrollChild = child end
	function methods:GetVerticalScroll() return self.verticalScroll end
	function methods:SetVerticalScroll(value) self.verticalScroll = value end
	function methods:GetVerticalScrollRange()
		return math.max(0, self.scrollChild:GetHeight() - self:GetHeight())
	end
	function methods:CreateFontString() return frame("FontString", nil, self) end
	function methods:SetText(text) self.text = text end
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
	}, { __index = _G })
	world.env.UIParent = frame("Frame")
	world.env.UIParent:SetSize(1280, 800)
	function world:editor(shown, left, bottom)
		local editor = frame("Frame", "MacroFrame", self.env.UIParent)
		editor:SetSize(338, 424)
		editor.left, editor.bottom = left or 16, bottom or 300
		editor.shown = shown
		self.env.MacroFrame = editor
		local popup = frame("Frame", "MacroPopupFrame", editor)
		popup:SetSize(320, 400)
		popup.left, popup.bottom, popup.shown = editor:GetRight(), editor.bottom, false
		self.env.MacroPopupFrame = popup
		return editor, popup
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
	function world:panel() return self.named.ForeverMacroManagerCheatSheet end
	return world
end

return Wow
