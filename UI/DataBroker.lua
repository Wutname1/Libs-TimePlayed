---@class LibsTimePlayed
local LibsTimePlayed = LibStub('AceAddon-3.0'):GetAddon('Libs-TimePlayed')

local LDB = LibStub('LibDataBroker-1.1')

local dataObj

function LibsTimePlayed:InitializeDataBroker()
	dataObj = LDB:NewDataObject("Lib's TimePlayed", {
		type = 'data source',
		text = 'Loading...',
		icon = 'Interface\\Icons\\INV_Misc_PocketWatch_01',
		label = 'TimePlayed',
		OnClick = function(frame, button)
			if button == 'LeftButton' then
				if IsShiftKeyDown() then
					LibsTimePlayed:TogglePopup()
				else
					LibsTimePlayed:CycleDisplayFormat()
				end
			elseif button == 'RightButton' then
				LibsTimePlayed:OpenOptions()
			elseif button == 'MiddleButton' then
				RequestTimePlayed()
			end
		end,
		OnTooltipShow = function(tooltip)
			LibsTimePlayed:BuildTooltip(tooltip)
		end,
	})

	self.dataObject = dataObj
	self:UpdateDisplay()
end

function LibsTimePlayed:UpdateDisplay()
	if not dataObj then
		return
	end

	local format = self.db.display.format
	local timeFormat = self.db.display.timeFormat

	if not self:HasPlayedData() then
		dataObj.text = 'Waiting...'
		return
	end

	local text
	if format == 'session' then
		text = self.FormatTime(self:GetSessionTime(), timeFormat)
	elseif format == 'level' then
		text = self.FormatTime(self:GetLevelPlayed(), timeFormat)
	else -- 'total'
		text = self.FormatTime(self:GetTotalPlayed(), timeFormat)
	end

	dataObj.text = text
end

function LibsTimePlayed:CycleDisplayFormat()
	local formats = { 'total', 'session', 'level' }
	local current = self.db.display.format
	local currentIndex = 1

	for i, fmt in ipairs(formats) do
		if fmt == current then
			currentIndex = i
			break
		end
	end

	local nextIndex = currentIndex < #formats and currentIndex + 1 or 1
	self.db.display.format = formats[nextIndex]

	self:Print('Display: ' .. formats[nextIndex])
	self:UpdateDisplay()
end
