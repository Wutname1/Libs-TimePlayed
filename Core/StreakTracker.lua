---@class LibsTimePlayed
local LibsTimePlayed = LibStub('AceAddon-3.0'):GetAddon('Libs-TimePlayed')

---@class LibsTimePlayed.StreakTracker : AceModule, AceTimer-3.0
local StreakTracker = LibsTimePlayed:NewModule('StreakTracker', 'AceTimer-3.0')
LibsTimePlayed.StreakTracker = StreakTracker

---Get today's date key in YYYY-MM-DD format
---@return string dateKey
local function GetTodayKey()
	return date('%Y-%m-%d', time())
end

---Get a date key for N days ago
---@param daysAgo number
---@return string dateKey
local function GetDateKey(daysAgo)
	return date('%Y-%m-%d', time() - (daysAgo * 86400))
end

function StreakTracker:OnEnable()
	local streaks = LibsTimePlayed.globaldb.streaks
	if not streaks then
		return
	end

	-- Mark today as played and increment session count
	self:MarkTodayPlayed()
	streaks.totalSessions = (streaks.totalSessions or 0) + 1

	-- Recalculate streaks from daily log
	self:RecalculateStreaks()

	-- Start a repeating timer to update session time every 5 minutes
	self.streakSessionStart = time()
	self:ScheduleRepeatingTimer('UpdateStreakSessionTime', 300)

	LibsTimePlayed:Log('Streak tracker initialized: ' .. (streaks.currentStreak or 0) .. ' day streak', 'debug')
end

function StreakTracker:OnDisable()
	self:CancelAllTimers()
end

---Mark today as a played day and initialize the daily log entry
function StreakTracker:MarkTodayPlayed()
	local streaks = LibsTimePlayed.globaldb.streaks
	if not streaks then
		return
	end

	local today = GetTodayKey()
	if not streaks.dailyLog[today] then
		streaks.dailyLog[today] = {
			totalSeconds = 0,
			sessions = 0,
		}
	end

	streaks.dailyLog[today].sessions = (streaks.dailyLog[today].sessions or 0) + 1
end

---Update the session time for today (called every 5 minutes by timer)
function StreakTracker:UpdateStreakSessionTime()
	local streaks = LibsTimePlayed.globaldb.streaks
	if not streaks then
		return
	end

	local today = GetTodayKey()
	if not streaks.dailyLog[today] then
		self:MarkTodayPlayed()
		self:RecalculateStreaks()
		self.streakSessionStart = time()
	end

	streaks.dailyLog[today].totalSeconds = (streaks.dailyLog[today].totalSeconds or 0) + 300
end

---Recalculate current and longest streaks from the daily log
function StreakTracker:RecalculateStreaks()
	local streaks = LibsTimePlayed.globaldb.streaks
	if not streaks then
		return
	end

	-- Calculate current streak (consecutive days ending today or yesterday)
	local currentStreak = 0
	local today = GetTodayKey()

	if streaks.dailyLog[today] then
		currentStreak = 1
	end

	local i = 1
	while true do
		local dayKey = GetDateKey(i)
		if streaks.dailyLog[dayKey] then
			currentStreak = currentStreak + 1
			i = i + 1
		else
			break
		end
	end

	streaks.currentStreak = currentStreak

	-- Calculate longest streak by sorting all date keys and walking consecutive runs
	local longestStreak = currentStreak
	local longestStart = ''
	local longestEnd = ''

	local dateKeys = {}
	for dateKey in pairs(streaks.dailyLog) do
		table.insert(dateKeys, dateKey)
	end
	table.sort(dateKeys)

	local runLength = 0
	local runStart = ''
	local prevKey = ''
	for _, dateKey in ipairs(dateKeys) do
		if prevKey ~= '' then
			-- Check if this date is exactly 1 day after the previous
			local expectedNext = date('%Y-%m-%d', time({ year = tonumber(prevKey:sub(1, 4)), month = tonumber(prevKey:sub(6, 7)), day = tonumber(prevKey:sub(9, 10)), hour = 12 }) + 86400)
			if dateKey == expectedNext then
				runLength = runLength + 1
			else
				if runLength > longestStreak then
					longestStreak = runLength
					longestStart = runStart
					longestEnd = prevKey
				end
				runLength = 1
				runStart = dateKey
			end
		else
			runLength = 1
			runStart = dateKey
		end
		prevKey = dateKey
	end
	if runLength > longestStreak then
		longestStreak = runLength
		longestStart = runStart
		longestEnd = prevKey
	end

	if (streaks.longestStreak or 0) > longestStreak then
		-- Don't overwrite - historical longest is preserved
	else
		streaks.longestStreak = longestStreak
		if longestStart ~= '' then
			streaks.longestStreakStart = longestStart
			streaks.longestStreakEnd = longestEnd
		end
	end
end

---Get average session duration in minutes
---@return number averageMinutes
function StreakTracker:GetAverageSessionMinutes()
	local streaks = LibsTimePlayed.globaldb.streaks
	if not streaks then
		return 0
	end

	local totalSeconds = 0
	local totalSessions = 0
	for _, day in pairs(streaks.dailyLog) do
		totalSeconds = totalSeconds + (day.totalSeconds or 0)
		totalSessions = totalSessions + (day.sessions or 0)
	end

	if totalSessions == 0 then
		return 0
	end

	return (totalSeconds / totalSessions) / 60
end

---Build a 14-day visual timeline string
---@return string timeline Visual timeline
function StreakTracker:BuildStreakTimeline()
	local streaks = LibsTimePlayed.globaldb.streaks
	if not streaks then
		return ''
	end

	local parts = {}
	for i = 13, 0, -1 do
		local dayKey = GetDateKey(i)
		if streaks.dailyLog[dayKey] then
			table.insert(parts, '|cff00ff00\226\150\160|r')
		else
			table.insert(parts, '|cff555555\226\150\161|r')
		end
	end

	return table.concat(parts, '')
end

---Get the oldest and newest date keys from the daily log
---@return string|nil oldest Oldest date key (YYYY-MM-DD)
---@return string|nil newest Newest date key (YYYY-MM-DD)
function StreakTracker:GetDailyLogDateRange()
	local streaks = LibsTimePlayed.globaldb.streaks
	if not streaks then
		return nil, nil
	end

	local oldest, newest
	for dateKey in pairs(streaks.dailyLog) do
		if not oldest or dateKey < oldest then
			oldest = dateKey
		end
		if not newest or dateKey > newest then
			newest = dateKey
		end
	end

	return oldest, newest
end

---Get the current week streak (consecutive weeks with at least 1 play day)
---@return number weekStreak Consecutive played weeks
---@return table weekData Array of { weekStartDate, weekEndDate, played, totalSeconds, sessions } (newest first)
function StreakTracker:GetWeekStreak()
	local streaks = LibsTimePlayed.globaldb.streaks
	if not streaks then
		return 0, {}
	end

	local oldest = self:GetDailyLogDateRange()
	if not oldest then
		return 0, {}
	end

	local now = time()
	local today = date('*t', now)
	local daysSinceSunday = today.wday - 1
	local sundayTime = now - (daysSinceSunday * 86400)

	-- Calculate max weeks to scan based on oldest daily log entry
	local oldestTime = time({ year = tonumber(oldest:sub(1, 4)), month = tonumber(oldest:sub(6, 7)), day = tonumber(oldest:sub(9, 10)), hour = 12 })
	local maxWeeks = math.ceil((now - oldestTime) / (7 * 86400)) + 1

	local weekData = {}
	local weekStreak = 0
	local streakBroken = false

	for w = 0, maxWeeks do
		local weekStart = sundayTime - (w * 7 * 86400)
		local weekEnd = weekStart + (6 * 86400)
		local played = false
		local totalSeconds = 0
		local sessions = 0

		for d = 0, 6 do
			local dayTime = weekStart + (d * 86400)
			if dayTime <= now then
				local dayKey = date('%Y-%m-%d', dayTime)
				local dayEntry = streaks.dailyLog[dayKey]
				if dayEntry then
					played = true
					totalSeconds = totalSeconds + (dayEntry.totalSeconds or 0)
					sessions = sessions + (dayEntry.sessions or 0)
				end
			end
		end

		table.insert(weekData, {
			weekStartDate = date('%Y-%m-%d', weekStart),
			weekEndDate = date('%Y-%m-%d', weekEnd),
			played = played,
			totalSeconds = totalSeconds,
			sessions = sessions,
		})

		if not streakBroken then
			if played then
				weekStreak = weekStreak + 1
			else
				streakBroken = true
			end
		end
	end

	if weekStreak > (streaks.longestWeekStreak or 0) then
		streaks.longestWeekStreak = weekStreak
	end

	return weekStreak, weekData
end

---Get daily log entries for a specific month
---@param year number e.g., 2026
---@param month number 1-12
---@return table<number, boolean> dayMap Maps day-of-month (1-31) to true if played
function StreakTracker:GetDailyLogForMonth(year, month)
	local streaks = LibsTimePlayed.globaldb.streaks
	local dayMap = {}
	if not streaks then
		return dayMap
	end

	for day = 1, 31 do
		local t = time({ year = year, month = month, day = day, hour = 12 })
		local parsed = date('*t', t)
		if parsed.month ~= month then
			break
		end
		local dayKey = date('%Y-%m-%d', t)
		dayMap[day] = streaks.dailyLog[dayKey] ~= nil
	end

	return dayMap
end

---Get all streak info as a single table
---@return table info { currentStreak, longestStreak, longestWeekStreak, averageSessionMinutes, totalSessions, timeline }
function StreakTracker:GetStreakInfo()
	local streaks = LibsTimePlayed.globaldb.streaks
	if not streaks then
		return {
			currentStreak = 0,
			longestStreak = 0,
			longestWeekStreak = 0,
			averageSessionMinutes = 0,
			totalSessions = 0,
			timeline = '',
		}
	end

	return {
		currentStreak = streaks.currentStreak or 0,
		longestStreak = streaks.longestStreak or 0,
		longestWeekStreak = streaks.longestWeekStreak or 0,
		averageSessionMinutes = self:GetAverageSessionMinutes(),
		totalSessions = streaks.totalSessions or 0,
		timeline = self:BuildStreakTimeline(),
	}
end

-- Bridge methods on main addon for backward compatibility
function LibsTimePlayed:GetStreakInfo()
	return self.StreakTracker:GetStreakInfo()
end

function LibsTimePlayed:GetWeekStreak()
	return self.StreakTracker:GetWeekStreak()
end

function LibsTimePlayed:GetDailyLogForMonth(year, month)
	return self.StreakTracker:GetDailyLogForMonth(year, month)
end

function LibsTimePlayed:GetAverageSessionMinutes()
	return self.StreakTracker:GetAverageSessionMinutes()
end

function LibsTimePlayed:BuildStreakTimeline()
	return self.StreakTracker:BuildStreakTimeline()
end
