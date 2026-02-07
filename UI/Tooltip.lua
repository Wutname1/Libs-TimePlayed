---@class LibsTimePlayed
local LibsTimePlayed = LibStub('AceAddon-3.0'):GetAddon('Libs-TimePlayed')

local BAR_WIDTH = 15
local FILL_CHAR = '|'
local DARK_COLOR = '|cff333333'

local GROUPBY_LABELS = {
	class = 'Class',
	realm = 'Realm',
	faction = 'Faction',
}

---Build a text-based bar using colored pipe characters
---@param fillPercent number 0-1
---@param r number
---@param g number
---@param b number
---@return string
local function BuildTextBar(fillPercent, r, g, b)
	local filled = math.floor(fillPercent * BAR_WIDTH + 0.5)
	filled = math.max(0, math.min(BAR_WIDTH, filled))
	local empty = BAR_WIDTH - filled

	local colorHex = string.format('|cff%02x%02x%02x', r * 255, g * 255, b * 255)
	local bar = colorHex .. string.rep(FILL_CHAR, filled) .. '|r'
	if empty > 0 then
		bar = bar .. DARK_COLOR .. string.rep(FILL_CHAR, empty) .. '|r'
	end
	return bar
end

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

	-- Account summary using GetGroupedData
	local sortedGroups, accountTotal = self:GetGroupedData()
	local groupBy = self.db.display.groupBy or 'class'
	local showBars = self.db.display.showBarsInTooltip

	if accountTotal > 0 then
		tooltip:AddLine(' ')
		tooltip:AddDoubleLine('Account Total', self.FormatTime(accountTotal, 'smart'), 1, 0.82, 0, 1, 1, 1)
		tooltip:AddLine(' ')
		tooltip:AddLine('Grouped by: ' .. GROUPBY_LABELS[groupBy], 0.5, 0.5, 0.5)

		-- Find top group total for bar scaling
		local topGroupTotal = sortedGroups[1] and sortedGroups[1].total or 0

		for _, group in ipairs(sortedGroups) do
			local clr = group.color
			local r, g, b = clr.r, clr.g, clr.b

			-- Percentage of account total
			local percent = accountTotal > 0 and (group.total / accountTotal * 100) or 0
			local barPercent = topGroupTotal > 0 and (group.total / topGroupTotal) or 0

			-- Group header with optional bar
			local headerLeft
			if showBars then
				local bar = BuildTextBar(barPercent, r, g, b)
				headerLeft = string.format('%s %s %.0f%%', group.label, bar, percent)
			else
				headerLeft = string.format('%s (%.0f%%)', group.label, percent)
			end
			tooltip:AddDoubleLine(headerLeft, self.FormatTime(group.total, 'smart'), r, g, b, 0.8, 0.8, 0.8)

			-- Individual characters under each group
			for _, char in ipairs(group.chars) do
				local charLabel = string.format('  %s (%d)', char.name, char.level)
				-- When grouping by realm or faction, color character names by class
				local cr, cg, cb = 0.6, 0.6, 0.6
				if groupBy ~= 'class' then
					local charColor = RAID_CLASS_COLORS[char.classFile]
					if charColor then
						cr, cg, cb = charColor.r, charColor.g, charColor.b
					end
				end
				tooltip:AddDoubleLine(charLabel, self.FormatTime(char.totalPlayed, 'smart'), cr, cg, cb, 0.6, 0.6, 0.6)
			end
		end

		-- Milestones
		if self.GetMilestones and self.db.display.showMilestones then
			local milestones = self:GetMilestones(sortedGroups, accountTotal)
			if #milestones > 0 then
				tooltip:AddLine(' ')
				for _, milestone in ipairs(milestones) do
					tooltip:AddLine(milestone, 0.7, 0.7, 0.7)
				end
			end
		end
	end

	-- Click hints
	tooltip:AddLine(' ')
	tooltip:AddLine('|cffffff00Left Click:|r Cycle Format (total/session/level)')
	tooltip:AddLine('|cffffff00Shift+Left:|r Toggle Window | |cffffff00Right:|r Options')
	tooltip:AddLine('|cffffff00Middle Click:|r Refresh /played')

	tooltip:Show()
end
