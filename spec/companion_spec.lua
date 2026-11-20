local Wow = require("spec.support.wow")

local function loadAddon(world)
	for line in io.lines("ForeverMacroManager.toc") do
		if line:match("%.lua$") then world:load(line) end
	end
end

local function scrollFor(panel)
	for _, child in ipairs(panel.children) do
		if child.kind == "ScrollFrame" then return child end
	end
	error("Missing scroll frame")
end

local function intersects(a, b)
	return a:GetLeft() < b:GetRight() and a:GetRight() > b:GetLeft()
		and a:GetBottom() < b:GetTop() and a:GetTop() > b:GetBottom()
end

describe("macro editor companion", function()
	it("waits for the load-on-demand editor and attaches exactly once", function()
		local world = Wow.new()
		loadAddon(world)
		assert.is_nil(world:panel())
		world:event("ADDON_LOADED", "OtherAddon")
		assert.is_nil(world:panel())

		local editor = world:editor(false)
		world:event("ADDON_LOADED", "Blizzard_MacroUI")
		local panel = world:panel()
		assert.equals(editor, panel.parent)
		assert.is_false(panel:IsVisible())
		world:event("ADDON_LOADED", "Blizzard_MacroUI")
		editor:Show()
		editor:Hide()
		editor:Show()
		assert.equals(panel, world:panel())
		local count = 0
		for _, object in ipairs(world.frames) do
			if object.name == "ForeverMacroManagerCheatSheet" then count = count + 1 end
		end
		assert.equals(1, count)
		assert.is_true(panel:IsVisible())
	end)

	it("accompanies an already visible editor without replacing native handlers", function()
		local world = Wow.new()
		local editor, popup = world:editor(true)
		local shows, hides = 0, 0
		local onShow = function() shows = shows + 1 end
		local onHide = function() hides = hides + 1; popup:Hide() end
		editor:SetScript("OnShow", onShow)
		editor:SetScript("OnHide", onHide)
		loadAddon(world)
		assert.is_true(world:panel():IsVisible())
		assert.equals(onShow, editor.scripts.OnShow)
		assert.equals(onHide, editor.scripts.OnHide)
		editor:Hide()
		assert.is_false(world:panel():IsVisible())
		editor:Show()
		assert.is_true(world:panel():IsVisible())
		assert.equals(1, shows)
		assert.equals(1, hides)
	end)

	it("also attaches to an already loaded but hidden editor", function()
		local world = Wow.new()
		local editor = world:editor(false)
		editor.unpositioned = true
		loadAddon(world)
		assert.is_false(world:panel():IsVisible())
		editor.unpositioned = false
		editor:Show()
		assert.is_true(world:panel():IsVisible())
		assert.is_true(world:panel():GetWidth() >= 280)
	end)

	it("keeps the reference clear of the icon popup and restores its position", function()
		local world = Wow.new()
		local editor, popup = world:editor(true)
		loadAddon(world)
		local panel = world:panel()
		local originalLeft = panel:GetLeft()
		assert.is_true(originalLeft > editor:GetRight())
		popup:Show()
		assert.is_true(panel:GetLeft() > popup:GetRight())
		popup:Hide()
		assert.equals(originalLeft, panel:GetLeft())
	end)

	it("uses space below the editor when neither side fits the popup", function()
		local world = Wow.new()
		world.env.UIParent:SetSize(900, 800)
		local editor, popup = world:editor(true)
		loadAddon(world)
		popup:Show()
		local panel = world:panel()
		assert.is_true(panel:GetTop() < editor:GetBottom())
		assert.is_true(panel:GetHeight() >= 160)
		assert.is_true(panel:GetBottom() >= 0)
		assert.is_true(panel:GetRight() <= 900)
		assert.is_false(intersects(panel, editor))
		assert.is_false(intersects(panel, popup))
		assert.is_true(panel:GetTop() < popup:GetBottom(),
			"the entire companion, including its scroll-up control, must clear the popup")
	end)

	it("reflows scrolling content and clamps wheel input after screen resize", function()
		local world = Wow.new()
		world:editor(true)
		loadAddon(world)
		local panel = world:panel()
		local scroll = scrollFor(panel)
		local oldWidth = scroll.scrollChild:GetWidth()
		scroll:Fire("OnMouseWheel", -10000)
		assert.equals(scroll:GetVerticalScrollRange(), scroll:GetVerticalScroll())
		scroll:Fire("OnMouseWheel", 10000)
		assert.equals(0, scroll:GetVerticalScroll())

		world.env.UIParent:SetSize(680, 500)
		world:event("DISPLAY_SIZE_CHANGED")
		assert.is_true(scroll.scrollChild:GetWidth() < oldWidth)
		assert.is_true(panel:GetRight() <= 680)
		assert.is_true(panel:GetTop() <= 500)
		assert.is_true(scroll:GetVerticalScrollRange() > 0)
	end)

	it("uses screen units after an editor scale change", function()
		local world = Wow.new()
		local editor = world:editor(true)
		loadAddon(world)
		editor:SetScale(0.75)
		world:event("UI_SCALE_CHANGED")
		assert.equals(world.env.UIParent:GetEffectiveScale(), world:panel():GetEffectiveScale())
		assert.is_true(world:panel():GetLeft() > editor:GetRight() * 0.75)
	end)

	it("preserves the scroll template handler that updates the scrollbar range", function()
		local world = Wow.new()
		world:editor(true)
		loadAddon(world)
		local scroll = scrollFor(world:panel())
		scroll:Fire("OnScrollRangeChanged")
		assert.equals(1, scroll.nativeRangeCalls)
	end)

	it("follows editor movement without needing a new show or resize event", function()
		local world = Wow.new()
		local editor = world:editor(true)
		loadAddon(world)
		local panel = world:panel()
		local left, bottom = panel:GetLeft(), panel:GetBottom()
		editor.left = editor.left + 100
		editor.bottom = editor.bottom - 50
		assert.equals(left + 100, panel:GetLeft())
		assert.equals(bottom - 50, panel:GetBottom())
	end)
end)
