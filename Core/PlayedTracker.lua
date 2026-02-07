---@class LibsTimePlayed
local LibsTimePlayed = LibStub('AceAddon-3.0'):GetAddon('Libs-TimePlayed')

-- Local state
local totalTimePlayed = 0
local timePlayedThisLevel = 0
local playedDataReceived = false
local sessionStartTime = 0

function LibsTimePlayed:InitializeTracker()
	sessionStartTime = time()

	-- Register events
	self:RegisterEvent('TIME_PLAYED_MSG', 'OnPlayedTimeReceived')
	self:RegisterEvent('PLAYER_LEVEL_UP', 'OnLevelUp')

	-- Request played time after a short delay (avoid chat spam suppression)
	self:ScheduleTimer('RequestPlayedTime', 2)

	-- Update session time every 60 seconds
	self:ScheduleRepeatingTimer('UpdateSessionDisplay', 60)
end

function LibsTimePlayed:RequestPlayedTime()
	RequestTimePlayed()
end

---@param event string
---@param total number Total time played in seconds
---@param level number Time played at current level in seconds
function LibsTimePlayed:OnPlayedTimeReceived(event, total, level)
	totalTimePlayed = total
	timePlayedThisLevel = level
	playedDataReceived = true

	-- Save to account-wide database
	self:SaveCharacterData()

	-- Update display
	self:UpdateDisplay()

	self:Log('Played time received: ' .. self.FormatTime(total, 'smart') .. ' total', 'debug')
end

function LibsTimePlayed:OnLevelUp()
	-- Request updated played time after level up
	self:ScheduleTimer('RequestPlayedTime', 1)
end

function LibsTimePlayed:UpdateSessionDisplay()
	if playedDataReceived then
		self:UpdateDisplay()
	end
end

---Save current character's played data to global DB
function LibsTimePlayed:SaveCharacterData()
	local name = UnitName('player')
	local realm = GetNormalizedRealmName()
	if not name or not realm then
		return
	end

	local _, classFile = UnitClass('player')
	local className = UnitClass('player')
	local level = UnitLevel('player')

	local charKey = realm .. '-' .. name

	local faction = UnitFactionGroup('player')

	self.globaldb.characters[charKey] = {
		name = name,
		realm = realm,
		class = className,
		classFile = classFile,
		faction = faction,
		level = level,
		totalPlayed = totalTimePlayed,
		levelPlayed = timePlayedThisLevel,
		lastUpdated = time(),
	}
end

---Get current character's total played time
---@return number seconds
function LibsTimePlayed:GetTotalPlayed()
	return totalTimePlayed
end

---Get current character's level played time
---@return number seconds
function LibsTimePlayed:GetLevelPlayed()
	return timePlayedThisLevel
end

---Get session duration
---@return number seconds
function LibsTimePlayed:GetSessionTime()
	return time() - sessionStartTime
end

---Check if played data has been received
---@return boolean
function LibsTimePlayed:HasPlayedData()
	return playedDataReceived
end

---Get all character data from global DB, grouped by class
---@return table<string, table[]> classGroups Characters grouped by classFile
---@return number accountTotal Total played time across all characters
function LibsTimePlayed:GetAccountData()
	local classGroups = {}
	local accountTotal = 0

	for charKey, data in pairs(self.globaldb.characters) do
		if type(data) == 'table' and data.totalPlayed and data.classFile then
			local classFile = data.classFile
			if not classGroups[classFile] then
				classGroups[classFile] = {}
			end
			table.insert(classGroups[classFile], {
				key = charKey,
				name = data.name or charKey,
				realm = data.realm or '',
				class = data.class or classFile,
				classFile = classFile,
				level = data.level or 0,
				totalPlayed = data.totalPlayed,
				levelPlayed = data.levelPlayed or 0,
				lastUpdated = data.lastUpdated or 0,
			})
			accountTotal = accountTotal + data.totalPlayed
		end
	end

	-- Sort each class group by played time descending
	for _, chars in pairs(classGroups) do
		table.sort(chars, function(a, b)
			return a.totalPlayed > b.totalPlayed
		end)
	end

	return classGroups, accountTotal
end

-- Faction colors for grouping display
local FACTION_COLORS = {
	Alliance = { r = 0.2, g = 0.4, b = 1.0 },
	Horde = { r = 0.9, g = 0.2, b = 0.2 },
	Neutral = { r = 0.8, g = 0.8, b = 0.8 },
}

---Get all character data grouped by the specified mode
---@param groupBy? string 'class', 'realm', or 'faction' (defaults to db.display.groupBy)
---@return table[] sortedGroups Array of { key, label, color, chars, total }
---@return number accountTotal Total played time across all characters
function LibsTimePlayed:GetGroupedData(groupBy)
	groupBy = groupBy or self.db.display.groupBy or 'class'

	local groups = {}
	local accountTotal = 0

	for charKey, data in pairs(self.globaldb.characters) do
		if type(data) == 'table' and data.totalPlayed and data.classFile then
			local groupKey, groupLabel, groupColor

			if groupBy == 'realm' then
				groupKey = data.realm or 'Unknown'
				groupLabel = groupKey
				groupColor = { r = 0.8, g = 0.8, b = 0.8 }
			elseif groupBy == 'faction' then
				groupKey = data.faction or 'Neutral'
				groupLabel = groupKey
				groupColor = FACTION_COLORS[groupKey] or FACTION_COLORS.Neutral
			else -- 'class'
				groupKey = data.classFile
				groupLabel = data.class or data.classFile
				local clr = RAID_CLASS_COLORS[data.classFile]
				groupColor = clr and { r = clr.r, g = clr.g, b = clr.b } or { r = 1, g = 1, b = 1 }
			end

			if not groups[groupKey] then
				groups[groupKey] = {
					key = groupKey,
					label = groupLabel,
					color = groupColor,
					chars = {},
					total = 0,
				}
			end

			local char = {
				key = charKey,
				name = data.name or charKey,
				realm = data.realm or '',
				class = data.class or data.classFile,
				classFile = data.classFile,
				faction = data.faction or 'Neutral',
				level = data.level or 0,
				totalPlayed = data.totalPlayed,
				levelPlayed = data.levelPlayed or 0,
				lastUpdated = data.lastUpdated or 0,
			}

			table.insert(groups[groupKey].chars, char)
			groups[groupKey].total = groups[groupKey].total + data.totalPlayed
			accountTotal = accountTotal + data.totalPlayed
		end
	end

	-- Sort chars within each group by totalPlayed descending
	for _, group in pairs(groups) do
		table.sort(group.chars, function(a, b)
			return a.totalPlayed > b.totalPlayed
		end)
	end

	-- Build sorted array of groups by total descending
	local sortedGroups = {}
	for _, group in pairs(groups) do
		table.insert(sortedGroups, group)
	end
	table.sort(sortedGroups, function(a, b)
		return a.total > b.total
	end)

	return sortedGroups, accountTotal
end
