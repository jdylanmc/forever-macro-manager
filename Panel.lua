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
	local text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	text:SetPoint("TOPLEFT")
	text:SetJustifyH("LEFT")
	text:SetJustifyV("TOP")
	local sections = {}
	for _, section in ipairs(ns.REFERENCE) do
		sections[#sections + 1] = "|cffffd100" .. section.title .. "|r\n\n" .. section.text
	end
	text:SetText(table.concat(sections, "\n\n"))

	local function clampScroll()
		scroll:SetVerticalScroll(clamp(scroll:GetVerticalScroll(), 0, scroll:GetVerticalScrollRange()))
	end
	local function resizeContent()
		local width = math.max(1, scroll:GetWidth())
		content:SetWidth(width)
		text:SetWidth(width)
		content:SetHeight(text:GetStringHeight() + 8)
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
		local right = bounds.right
		if MacroPopupFrame and MacroPopupFrame:IsShown() then
			local popupBounds = rect(MacroPopupFrame)
			if popupBounds then right = math.max(right, popupBounds.right) end
		end
		local width, height = WIDTH, math.min(424, screenHeight - 2 * MARGIN)
		local left, bottom
		if screenWidth - right - GAP - MARGIN >= MIN_WIDTH then
			width = math.min(width, screenWidth - right - GAP - MARGIN)
			left, bottom = right + GAP, bounds.top - height
		elseif bounds.left - GAP - MARGIN >= MIN_WIDTH then
			width = math.min(width, bounds.left - GAP - MARGIN)
			left, bottom = bounds.left - GAP - width, bounds.top - height
		elseif bounds.bottom - GAP - MARGIN >= MIN_HEIGHT then
			height = math.min(height, bounds.bottom - GAP - MARGIN)
			left, bottom = bounds.left, bounds.bottom - GAP - height
		elseif screenHeight - bounds.top - GAP - MARGIN >= MIN_HEIGHT then
			height = math.min(height, screenHeight - bounds.top - GAP - MARGIN)
			left, bottom = bounds.left, bounds.top + GAP
		else
			-- Extremely small viewports cannot hold both panels without overlap.
			left, bottom = right + GAP, bounds.top - height
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
