---@class LibsTimePlayed
local LibsTimePlayed = LibStub('AceAddon-3.0'):GetAddon('Libs-TimePlayed')

---Compute milestone strings from grouped data
---@param sortedGroups table[] Array of { key, label, color, chars, total }
---@param accountTotal number Total played time across all characters
---@return string[] milestones Up to 3 milestone strings
function LibsTimePlayed:GetMilestones(sortedGroups, accountTotal)
	local milestones = {}

	if accountTotal <= 0 or #sortedGroups == 0 then
		return milestones
	end

	local totalHours = accountTotal / 3600
	local totalDays = accountTotal / 86400

	-- Total time threshold milestones
	if totalHours >= 10000 then
		table.insert(milestones, string.format('%.0f,000+ hours played!', math.floor(totalHours / 1000)))
	elseif totalHours >= 5000 then
		table.insert(milestones, '5,000+ hours played!')
	elseif totalHours >= 1000 then
		table.insert(milestones, '1,000+ hours played!')
	elseif totalDays >= 365 then
		local years = math.floor(totalDays / 365)
		table.insert(milestones, years .. '+ year(s) of /played time')
	end

	-- Character count across groups
	local totalChars = 0
	for _, group in ipairs(sortedGroups) do
		totalChars = totalChars + #group.chars
	end
	if totalChars > 1 then
		table.insert(milestones, string.format('Tracking %d characters across %d groups', totalChars, #sortedGroups))
	end

	-- Dominant group (if > 50% of total)
	if sortedGroups[1] then
		local topGroup = sortedGroups[1]
		local topPercent = topGroup.total / accountTotal * 100
		if topPercent > 50 then
			table.insert(milestones, string.format('%s has %.0f%% of total time', topGroup.label, topPercent))
		end
	end

	-- Most played single character (if > 30 days)
	local topChar
	local topCharTime = 0
	for _, group in ipairs(sortedGroups) do
		for _, char in ipairs(group.chars) do
			if char.totalPlayed > topCharTime then
				topCharTime = char.totalPlayed
				topChar = char
			end
		end
	end
	if topChar and topCharTime >= (30 * 86400) then
		local charDays = math.floor(topCharTime / 86400)
		table.insert(milestones, string.format('%s: %d days played', topChar.name, charDays))
	end

	-- Cap at 3 milestones
	while #milestones > 3 do
		table.remove(milestones)
	end

	return milestones
end
