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

local function exampleButton(world, sample)
	for _, object in ipairs(world.frames) do
		if object.kind == "Button" then
			for _, child in ipairs(object.parent.children) do
				if child.kind == "FontString" and child.text == sample then return object, child end
			end
		end
	end
	error("Missing example control: " .. sample)
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

	it("pairs every standalone example with a cyan label and a labeled Add control", function()
		local world = Wow.new()
		world:editor(true)
		loadAddon(world)
		local count = 0
		for _, object in ipairs(world.frames) do
			if object.kind == "Button" then
				count = count + 1
				local sample
				for _, child in ipairs(object.parent.children) do
					if child.kind == "FontString" then sample = child end
				end
				assert.matches("^[/#]", sample.text)
				assert.same({ 0.35, 0.85, 1 }, sample.color)
				assert.is_nil(sample.text:find("|c", 1, true))
			end
		end
		assert.equals(18, count)
		local button = exampleButton(world, "#showtooltip Rejuvenation")
		button:Fire("OnEnter")
		assert.equals("Add to current macro", world.env.GameTooltip.text)
		button:Fire("OnLeave")
		assert.is_false(world.env.GameTooltip.shown)
	end)

	it("inserts exact plain text at the beginning, middle, and end like native typing", function()
		for _, case in ipairs({
			{ cursor = 0, expected = "/cast Spell NameleftRIGHT" },
			{ cursor = 4, expected = "left/cast Spell NameRIGHT" },
			{ cursor = 9, expected = "leftRIGHT/cast Spell Name" },
		}) do
			local world = Wow.new()
			world:editor(true)
			local edit = world.env.MacroFrameText
			edit:SetText("leftRIGHT")
			edit:SetCursorPosition(case.cursor)
			local native = edit.scripts.OnTextChanged
			loadAddon(world)
			local changes = edit.nativeTextChanges
			exampleButton(world, "/cast Spell Name"):Click()
			assert.equals(case.expected, edit:GetText())
			assert.equals(case.cursor + #"/cast Spell Name", edit:GetCursorPosition())
			assert.equals(changes + 1, edit.nativeTextChanges)
			assert.equals(native, edit.scripts.OnTextChanged)
			assert.equals(1, world.env.MacroFrame.textChanged)
		end
	end)

	it("uses the current selected macro draft at click time and the clicked line's payload", function()
		local world = Wow.new()
		local editor = world:editor(true)
		local edit = world.env.MacroFrameText
		edit:SetText("old draft")
		loadAddon(world)
		local button = exampleButton(world, "/focus")
		editor.selectedIndex = 2
		edit:SetText("second")
		edit:SetCursorPosition(3)
		button:Click()
		assert.equals("sec/focusond", edit:GetText())
		assert.equals(2, editor:GetSelectedIndex())
		assert.equals(1, edit.insertCalls)
	end)

	it("lets native Insert replace highlighted text without replacing the whole draft", function()
		local world = Wow.new()
		world:editor(true)
		local edit = world.env.MacroFrameText
		edit:SetText("one SELECT two")
		edit:SetCursorPosition(10)
		edit:HighlightText(4, 10)
		loadAddon(world)
		exampleButton(world, "/stopcasting"):Click()
		assert.equals("one /stopcasting two", edit:GetText())
		assert.equals(4 + #"/stopcasting", edit:GetCursorPosition())
		assert.is_nil(edit.selectionStart)
		assert.equals(1, edit.insertCalls)
	end)

	it("rejects insufficient headroom without changing the draft, cursor, or selection", function()
		local world = Wow.new()
		world:editor(true)
		local edit = world.env.MacroFrameText
		local original = string.rep("x", 255)
		edit:SetText(original)
		edit:SetCursorPosition(240)
		edit:HighlightText(240, 255)
		loadAddon(world)
		local changes = edit.nativeTextChanges
		exampleButton(world, "/dismount"):Click()
		assert.equals(original, edit:GetText())
		assert.equals(240, edit:GetCursorPosition())
		assert.equals(240, edit.selectionStart)
		assert.equals(255, edit.selectionEnd)
		assert.equals(changes, edit.nativeTextChanges)
		assert.is_nil(edit.insertCalls)
		assert.matches("space", world.errors[1])
	end)

	it("uses native letter counts rather than rejecting a valid multibyte draft by byte length", function()
		local world = Wow.new()
		world:editor(true)
		local edit = world.env.MacroFrameText
		local original = string.rep("é", 130)
		edit:SetText(original)
		loadAddon(world)
		exampleButton(world, "/dismount"):Click()
		assert.equals(original .. "/dismount", edit:GetText())
		assert.equals(139, edit:GetNumLetters())
		assert.equals(0, #world.errors)
	end)

	it("allows an exact-fit insertion at the native letter ceiling", function()
		local world = Wow.new()
		world:editor(true)
		local edit = world.env.MacroFrameText
		local original = string.rep("x", 246)
		edit:SetText(original)
		loadAddon(world)
		exampleButton(world, "/dismount"):Click()
		assert.equals(original .. "/dismount", edit:GetText())
		assert.equals(255, edit:GetNumLetters())
		assert.equals(255, edit:GetCursorPosition())
		assert.equals(0, #world.errors)
	end)

	it("also respects a native byte ceiling without truncating multibyte text", function()
		local world = Wow.new()
		world:editor(true)
		local edit = world.env.MacroFrameText
		edit.maxBytes = 20
		local original = string.rep("é", 8)
		edit:SetText(original)
		edit:SetCursorPosition(2)
		loadAddon(world)
		exampleButton(world, "/dismount"):Click()
		assert.equals(original, edit:GetText())
		assert.equals(2, edit:GetCursorPosition())
		assert.is_nil(edit.insertCalls)
		assert.equals(1, #world.errors)
	end)

	it("reports unavailable, unselected, disabled, composing, and combat targets without modifying them", function()
		for _, state in ipairs({ "unavailable", "unselected", "disabled", "hidden", "popup", "composing", "combat" }) do
			local world = Wow.new()
			local editor = world:editor(true)
			local edit = world.env.MacroFrameText
			edit:SetText("keep this")
			edit:SetCursorPosition(3)
			loadAddon(world)
			if state == "unavailable" then world.env.MacroFrameText = nil
			elseif state == "unselected" then editor.selectedIndex = nil
			elseif state == "disabled" then edit.enabled = false
			elseif state == "hidden" then edit:Hide()
			elseif state == "popup" then world.env.MacroPopupFrame:Show()
			elseif state == "composing" then edit.composing = true
			else world.combat = true end
			exampleButton(world, "/clearfocus"):Click()
			assert.equals("keep this", edit:GetText(), state)
			assert.equals(3, edit:GetCursorPosition(), state)
			assert.is_nil(edit.insertCalls, state)
			assert.equals(1, #world.errors, state)
		end
	end)

	it("reserves the far-right Add gutter while long examples wrap and reflow", function()
		local world = Wow.new()
		world:editor(true)
		loadAddon(world)
		local button, text = exampleButton(world,
			"/cast [@mouseover,help,nodead][help,nodead][@player] Rejuvenation")
		local height = text:GetStringHeight()
		assert.is_true(height > button:GetHeight())
		assert.is_true(text:GetRight() + 8 <= button:GetLeft())
		world.env.UIParent:SetSize(680, 500)
		world:event("DISPLAY_SIZE_CHANGED")
		local scroll = scrollFor(world:panel())
		assert.is_true(text:GetStringHeight() >= height)
		assert.is_true(text:GetRight() + 8 <= button:GetLeft())
		assert.equals(scroll.scrollChild:GetRight(), button:GetRight())
		scroll:Fire("OnMouseWheel", -10000)
		assert.equals(scroll:GetVerticalScrollRange(), scroll:GetVerticalScroll())
	end)
end)
