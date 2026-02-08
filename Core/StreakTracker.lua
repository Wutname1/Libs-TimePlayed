---@class LibsTimePlayed
local LibsTimePlayed = LibStub('AceAddon-3.0'):GetAddon('Libs-TimePlayed')

----------------------------------------------------------------------------------------------------
-- Play Streak Tracker
-- Tracks daily login streaks, session counts, and builds a 14-day visual timeline
----------------------------------------------------------------------------------------------------

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

----------------------------------------------------------------------------------------------------
-- Initialization
----------------------------------------------------------------------------------------------------

---Initialize the streak tracking system
function LibsTimePlayed:InitializeStreakTracker()
	local streaks = self.globaldb.streaks
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

	self:Log('Streak tracker initialized: ' .. (streaks.currentStreak or 0) .. ' day streak', 'debug')
end

----------------------------------------------------------------------------------------------------
-- Daily Tracking
----------------------------------------------------------------------------------------------------

---Mark today as a played day and initialize the daily log entry
function LibsTimePlayed:MarkTodayPlayed()
	local streaks = self.globaldb.streaks
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
function LibsTimePlayed:UpdateStreakSessionTime()
	local streaks = self.globaldb.streaks
	if not streaks then
		return
	end

	local today = GetTodayKey()
	if not streaks.dailyLog[today] then
		-- Day changed while playing — mark the new day
		self:MarkTodayPlayed()
		self:RecalculateStreaks()
		-- Reset session start for the new day
		self.streakSessionStart = time()
	end

	-- Add 5 minutes (300 seconds) to today's total
	streaks.dailyLog[today].totalSeconds = (streaks.dailyLog[today].totalSeconds or 0) + 300
end

----------------------------------------------------------------------------------------------------
-- Streak Calculation
----------------------------------------------------------------------------------------------------

---Recalculate current and longest streaks from the daily log
---Also prunes entries older than 30 days
function LibsTimePlayed:RecalculateStreaks()
	local streaks = self.globaldb.streaks
	if not streaks then
		return
	end

	-- Prune entries older than 30 days
	local cutoffKey = GetDateKey(30)
	for dateKey in pairs(streaks.dailyLog) do
		if dateKey < cutoffKey then
			streaks.dailyLog[dateKey] = nil
		end
	end

	-- Calculate current streak (consecutive days ending today or yesterday)
	local currentStreak = 0
	local today = GetTodayKey()

	-- Check if today is played
	if streaks.dailyLog[today] then
		currentStreak = 1
		-- Walk backward from yesterday
		for i = 1, 30 do
			local dayKey = GetDateKey(i)
			if streaks.dailyLog[dayKey] then
				currentStreak = currentStreak + 1
			else
				break
			end
		end
	else
		-- Today not yet counted (edge case: just logged in, timer hasn't fired)
		-- Check starting from yesterday
		for i = 1, 30 do
			local dayKey = GetDateKey(i)
			if streaks.dailyLog[dayKey] then
				currentStreak = currentStreak + 1
			else
				break
			end
		end
	end

	streaks.currentStreak = currentStreak

	-- Calculate longest streak by scanning all consecutive runs
	local longestStreak = currentStreak
	local longestStart = ''
	local longestEnd = ''

	-- Scan the last 30 days for the longest consecutive run
	local runLength = 0
	local runStart = ''
	for i = 30, 0, -1 do
		local dayKey = GetDateKey(i)
		if streaks.dailyLog[dayKey] then
			if runLength == 0 then
				runStart = dayKey
			end
			runLength = runLength + 1
		else
			if runLength > longestStreak then
				longestStreak = runLength
				longestStart = runStart
				longestEnd = GetDateKey(i + 1)
			end
			runLength = 0
		end
	end
	-- Check final run
	if runLength > longestStreak then
		longestStreak = runLength
		longestStart = runStart
		longestEnd = GetTodayKey()
	end

	-- Keep existing longest if it's greater (from before the 30d window)
	if (streaks.longestStreak or 0) > longestStreak then
		-- Don't overwrite — historical longest is preserved
	else
		streaks.longestStreak = longestStreak
		if longestStart ~= '' then
			streaks.longestStreakStart = longestStart
			streaks.longestStreakEnd = longestEnd
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Data Accessors
----------------------------------------------------------------------------------------------------

---Get average session duration in minutes
---@return number averageMinutes
function LibsTimePlayed:GetAverageSessionMinutes()
	local streaks = self.globaldb.streaks
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
---Green block for played days, gray block for missed days
---@return string timeline Visual timeline (e.g., "■■□■■■■□■■■■■■")
function LibsTimePlayed:BuildStreakTimeline()
	local streaks = self.globaldb.streaks
	if not streaks then
		return ''
	end

	local parts = {}
	-- Build from 13 days ago to today (left = oldest, right = newest)
	for i = 13, 0, -1 do
		local dayKey = GetDateKey(i)
		if streaks.dailyLog[dayKey] then
			table.insert(parts, '|cff00ff00\226\150\160|r') -- Green filled square (■ → using ■ U+25A0)
		else
			table.insert(parts, '|cff555555\226\150\161|r') -- Gray empty square (□ → using □ U+25A1)
		end
	end

	return table.concat(parts, '')
end

---Get all streak info as a single table
---@return table info { currentStreak, longestStreak, averageSessionMinutes, totalSessions, timeline }
function LibsTimePlayed:GetStreakInfo()
	local streaks = self.globaldb.streaks
	if not streaks then
		return {
			currentStreak = 0,
			longestStreak = 0,
			averageSessionMinutes = 0,
			totalSessions = 0,
			timeline = '',
		}
	end

	return {
		currentStreak = streaks.currentStreak or 0,
		longestStreak = streaks.longestStreak or 0,
		averageSessionMinutes = self:GetAverageSessionMinutes(),
		totalSessions = streaks.totalSessions or 0,
		timeline = self:BuildStreakTimeline(),
	}
end
