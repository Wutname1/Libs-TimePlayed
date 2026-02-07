---@class LibsTimePlayed
local LibsTimePlayed = LibStub('AceAddon-3.0'):GetAddon('Libs-TimePlayed')

function LibsTimePlayed:BuildTooltip(tooltip)
	tooltip:SetText("Lib's TimePlayed")

	if not self:HasPlayedData() then
		tooltip:AddLine('Waiting for /played data...', 0.7, 0.7, 0.7)
		tooltip:Show()
		return
	end

	-- Current character info
	local name = UnitName('player')
	local _, classFile = UnitClass('player')
	local color = RAID_CLASS_COLORS[classFile]
	local coloredName = color and string.format('|cff%02x%02x%02x%s|r', color.r * 255, color.g * 255, color.b * 255, name) or name

	tooltip:AddLine(' ')
	tooltip:AddDoubleLine(coloredName .. ' (Lv ' .. UnitLevel('player') .. ')', '', 1, 1, 1)
	tooltip:AddDoubleLine('  Total:', self.FormatTime(self:GetTotalPlayed(), 'full'), 0.8, 0.8, 0.8, 1, 1, 1)
	tooltip:AddDoubleLine('  This Level:', self.FormatTime(self:GetLevelPlayed(), 'full'), 0.8, 0.8, 0.8, 1, 1, 1)
	tooltip:AddDoubleLine('  Session:', self.FormatTime(self:GetSessionTime(), 'full'), 0.8, 0.8, 0.8, 1, 1, 1)

	-- Account summary grouped by class
	local classGroups, accountTotal = self:GetAccountData()

	if accountTotal > 0 then
		tooltip:AddLine(' ')
		tooltip:AddDoubleLine('Account Total', self.FormatTime(accountTotal, 'smart'), 1, 0.82, 0, 1, 1, 1)
		tooltip:AddLine(' ')

		-- Sort classes by total played time descending
		local sortedClasses = {}
		for classFile, chars in pairs(classGroups) do
			local classTotal = 0
			for _, char in ipairs(chars) do
				classTotal = classTotal + char.totalPlayed
			end
			table.insert(sortedClasses, {
				classFile = classFile,
				className = chars[1].class,
				chars = chars,
				total = classTotal,
			})
		end
		table.sort(sortedClasses, function(a, b)
			return a.total > b.total
		end)

		for _, classData in ipairs(sortedClasses) do
			local clr = RAID_CLASS_COLORS[classData.classFile]
			local r, g, b = 1, 1, 1
			if clr then
				r, g, b = clr.r, clr.g, clr.b
			end

			-- Class header with total
			tooltip:AddDoubleLine(classData.className, self.FormatTime(classData.total, 'smart'), r, g, b, 0.8, 0.8, 0.8)

			-- Individual characters under each class
			for _, char in ipairs(classData.chars) do
				local charLabel = string.format('  %s (%d)', char.name, char.level)
				tooltip:AddDoubleLine(charLabel, self.FormatTime(char.totalPlayed, 'smart'), 0.6, 0.6, 0.6, 0.6, 0.6, 0.6)
			end
		end
	end

	-- Click hints
	tooltip:AddLine(' ')
	tooltip:AddLine('|cffffff00Left Click:|r Cycle Format (total/session/level)')
	tooltip:AddLine('|cffffff00Shift+Left:|r Options | |cffffff00Right:|r Options')
	tooltip:AddLine('|cffffff00Middle Click:|r Refresh /played')

	tooltip:Show()
end
