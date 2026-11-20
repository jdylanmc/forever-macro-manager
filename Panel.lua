local _, ns = ...

local GAP, MARGIN = 8, 8
local WIDTH, MIN_WIDTH, MIN_HEIGHT = 360, 280, 160

local function rect(frame)
	local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
	if not (left and right and top and bottom) then
		return nil
	end
	local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	return {
		left = left * scale,
		right = right * scale,
		top = top * scale,
		bottom = bottom * scale,
	}
end

local function clamp(value, low, high)
	return math.max(low, math.min(value, high))
end

local function insertExample(editor, sample)
	local box = MacroFrameText
	local message
	if InCombatLockdown() then
		message = "Cannot insert a macro example during combat."
	elseif not box or not editor:GetSelectedIndex() or not box:IsVisible() or not box:IsEnabled()
		or (MacroPopupFrame and MacroPopupFrame:IsShown()) then
		message = "Select an editable macro and close its name/icon picker first."
	elseif box:IsInIMECompositionMode() then
		message = "Finish composing text before inserting a macro example."
	else
		local maxLetters, maxBytes = box:GetMaxLetters(), box:GetMaxBytes()
		-- UTF-8 leading bytes count characters; Lua's length operator counts bytes.
		local _, sampleLetters = sample:gsub("[^\128-\193]", "")
		-- There is no native selection-range getter. Never guess its available space.
		if (maxLetters > 0 and box:GetNumLetters() + sampleLetters > maxLetters)
			or (maxBytes > 0 and #box:GetText() + #sample > maxBytes) then
			message = "Not enough space for this whole example. Shorten the draft first; selection size cannot be checked."
		end
	end
	if message then
		UIErrorsFrame:AddMessage(message, 1, 0.2, 0.2)
		return
	end
	box:Insert(sample)
	box:SetFocus()
end

function ns.CreatePanel(editor)
	local panel = CreateFrame("Frame", "ForeverMacroManagerCheatSheet", editor, "BackdropTemplate")
	panel:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	panel:SetClampedToScreen(true)
	panel:EnableMouse(true)

	local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 14, -14)
	title:SetText("Macro cheat sheet")

	local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 14, -42)
	scroll:SetPoint("BOTTOMRIGHT", -32, 14)
	local content = CreateFrame("Frame", nil, scroll)
	scroll:SetScrollChild(content)
	local rows = {}
	local function addRow(line, heading)
		local frame = CreateFrame("Frame", nil, content)
		local text = frame:CreateFontString(nil, "OVERLAY", heading and "GameFontNormal" or "GameFontHighlight")
		text:SetPoint("TOPLEFT")
		text:SetJustifyH("LEFT")
		text:SetJustifyV("TOP")
		text:SetText(line)
		local row = { frame = frame, text = text, blank = line == "" }
		if heading then
			text:SetTextColor(1, 0.82, 0)
		elseif line:match("^[/#]") then
			text:SetTextColor(0.35, 0.85, 1)
			text:SetNonSpaceWrap(true)
			local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
			button:SetSize(22, 22)
			button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
			button:SetText("+")
			button:SetScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:SetText("Add to current macro")
				GameTooltip:AddLine("Insert this exact line at the cursor. No line break is added.", 1, 1, 1, true)
				GameTooltip:Show()
			end)
			button:SetScript("OnLeave", function() GameTooltip:Hide() end)
			button:SetScript("OnClick", function() insertExample(editor, line) end)
			row.button = button
		end
		rows[#rows + 1] = row
	end
	for index, section in ipairs(ns.REFERENCE) do
		if index > 1 then addRow("") end
		addRow(section.title, true)
		addRow("")
		for line in (section.text .. "\n"):gmatch("(.-)\n") do addRow(line) end
	end

	local function clampScroll()
		scroll:SetVerticalScroll(clamp(scroll:GetVerticalScroll(), 0, scroll:GetVerticalScrollRange()))
	end
	local function resizeContent()
		local width = math.max(1, scroll:GetWidth())
		content:SetWidth(width)
		local offset = 0
		for _, row in ipairs(rows) do
			row.frame:SetWidth(width)
			row.frame:ClearAllPoints()
			row.frame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -offset)
			row.text:SetWidth(math.max(1, width - (row.button and 30 or 0)))
			local height = row.blank and 8 or math.max(row.text:GetStringHeight(), row.button and 22 or 0) + 4
			row.frame:SetHeight(height)
			offset = offset + height
		end
		content:SetHeight(offset + 8)
		clampScroll()
	end
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(_, delta)
		scroll:SetVerticalScroll(clamp(scroll:GetVerticalScroll() - delta * 36, 0, scroll:GetVerticalScrollRange()))
	end)
	scroll:HookScript("OnSizeChanged", resizeContent)
	scroll:HookScript("OnScrollRangeChanged", clampScroll)

	function panel:Layout()
		if not editor:IsShown() then
			return
		end
		local bounds = rect(editor)
		if not bounds then
			return
		end
		-- Use screen units even when another addon changes the editor's scale.
		self:SetScale(UIParent:GetEffectiveScale() / editor:GetEffectiveScale())
		local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
		local leftEdge, rightEdge = bounds.left, bounds.right
		local topEdge, bottomEdge = bounds.top, bounds.bottom
		if MacroPopupFrame and MacroPopupFrame:IsShown() then
			local popupBounds = rect(MacroPopupFrame)
			if popupBounds then
				leftEdge = math.min(leftEdge, popupBounds.left)
				rightEdge = math.max(rightEdge, popupBounds.right)
				topEdge = math.max(topEdge, popupBounds.top)
				bottomEdge = math.min(bottomEdge, popupBounds.bottom)
			end
		end
		local width, height = WIDTH, math.min(424, screenHeight - 2 * MARGIN)
		local left, bottom
		if screenWidth - rightEdge - GAP - MARGIN >= MIN_WIDTH then
			width = math.min(width, screenWidth - rightEdge - GAP - MARGIN)
			left, bottom = rightEdge + GAP, bounds.top - height
		elseif leftEdge - GAP - MARGIN >= MIN_WIDTH then
			width = math.min(width, leftEdge - GAP - MARGIN)
			left, bottom = leftEdge - GAP - width, bounds.top - height
		elseif bottomEdge - GAP - MARGIN >= MIN_HEIGHT then
			height = math.min(height, bottomEdge - GAP - MARGIN)
			left, bottom = bounds.left, bottomEdge - GAP - height
		elseif screenHeight - topEdge - GAP - MARGIN >= MIN_HEIGHT then
			height = math.min(height, screenHeight - topEdge - GAP - MARGIN)
			left, bottom = bounds.left, topEdge + GAP
		else
			-- Extremely small viewports cannot hold both panels without overlap.
			left, bottom = rightEdge + GAP, bounds.top - height
		end
		width = math.min(width, screenWidth - 2 * MARGIN)
		self:SetSize(width, height)
		self:ClearAllPoints()
		self:SetPoint("BOTTOMLEFT", editor, "BOTTOMLEFT",
			clamp(left, MARGIN, screenWidth - width - MARGIN) - bounds.left,
			clamp(bottom, MARGIN, screenHeight - height - MARGIN) - bounds.bottom)
		resizeContent()
	end

	panel:HookScript("OnShow", function() panel:Layout() end)
	panel:Layout()
	return panel
end
