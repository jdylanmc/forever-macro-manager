local _, ns = ...
local events = CreateFrame("Frame")
local panel

local function layout()
	if panel then
		panel:Layout()
	end
end

local function attach()
	if panel or not MacroFrame then
		return
	end
	panel = ns.CreatePanel(MacroFrame)
	MacroFrame:HookScript("OnShow", layout)
	MacroFrame:HookScript("OnSizeChanged", layout)
	MacroFrame:HookScript("OnDragStop", layout)
	if MacroPopupFrame then
		ns.AttachIconPicker(MacroPopupFrame)
		MacroPopupFrame:HookScript("OnShow", layout)
		MacroPopupFrame:HookScript("OnHide", layout)
		MacroPopupFrame:HookScript("OnDragStop", layout)
	end
	events:UnregisterEvent("ADDON_LOADED")
end

events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("UI_SCALE_CHANGED")
events:RegisterEvent("DISPLAY_SIZE_CHANGED")
events:SetScript("OnEvent", function(_, event, addon)
	if event == "ADDON_LOADED" then
		if addon == "Blizzard_MacroUI" then
			attach()
		end
	else
		layout()
	end
end)

attach()
