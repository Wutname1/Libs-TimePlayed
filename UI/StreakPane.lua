---@class LibsTimePlayed
local LibsTimePlayed = LibStub('AceAddon-3.0'):GetAddon('Libs-TimePlayed')

----------------------------------------------------------------------------------------------------
-- Streak Pane
-- Kindle-style streak display with calendar grids and week streak bars
----------------------------------------------------------------------------------------------------

local MONTH_NAMES = { 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December' }
local DAY_HEADERS = { 'Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa' }

-- Colors
local COLOR_PLAYED = { r = 0.2, g = 0.8, b = 0.2, a = 0.8 }
local COLOR_MISSED = { r = 0.15, g = 0.15, b = 0.15, a = 0.6 }
local COLOR_TODAY_BORDER = { r = 1, g = 0.82, b = 0, a = 1 }
local COLOR_STREAK_ACTIVE = { r = 0, g = 1, b = 0 }
local COLOR_STREAK_ZERO = { r = 0.5, g = 0.5, b = 0.5 }
local COLOR_GOLD = { r = 1, g = 0.82, b = 0 }

local CELL_WIDTH = 22
local CELL_HEIGHT = 16
local GRID_ROWS = 6
local GRID_COLS = 7

-- Persistent frame references
local streakPane

----------------------------------------------------------------------------------------------------
-- Calendar Grid Helpers
----------------------------------------------------------------------------------------------------

---Create a single month calendar grid (title + day headers + 42 cells)
---@param parent Frame
---@param yOffset number Vertical offset from parent top
---@return table grid { titleText, headerTexts[7], cells[42], yBottom }
local function CreateMonthGrid(parent, yOffset)
	local grid = {}

	-- Month title
	grid.titleText = parent:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	grid.titleText:SetPoint('TOPLEFT', parent, 'TOPLEFT', 4, -yOffset)
	grid.titleText:SetTextColor(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b)

	local headerY = yOffset + 16

	-- Day-of-week headers
	grid.headerTexts = {}
	for col = 1, GRID_COLS do
		local header = parent:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
		header:SetPoint('TOPLEFT', parent, 'TOPLEFT', (col - 1) * CELL_WIDTH + 4, -headerY)
		header:SetWidth(CELL_WIDTH)
		header:SetJustifyH('CENTER')
		header:SetText(DAY_HEADERS[col])
		header:SetTextColor(0.6, 0.6, 0.6)
		local fontFile = header:GetFont()
		header:SetFont(fontFile, 9, '')
		grid.headerTexts[col] = header
	end

	local gridY = headerY + 14

	-- 6x7 grid of day cells
	grid.cells = {}
	for i = 1, GRID_ROWS * GRID_COLS do
		local row = math.floor((i - 1) / GRID_COLS)
		local col = (i - 1) % GRID_COLS

		local cell = CreateFrame('Frame', nil, parent)
		cell:SetSize(CELL_WIDTH, CELL_HEIGHT)
		cell:SetPoint('TOPLEFT', parent, 'TOPLEFT', col * CELL_WIDTH + 4, -(gridY + row * CELL_HEIGHT))

		-- Background texture
		local bg = cell:CreateTexture(nil, 'BACKGROUND')
		bg:SetPoint('TOPLEFT', 1, -1)
		bg:SetPoint('BOTTOMRIGHT', -1, 1)
		cell.bg = bg

		-- Today border (gold outline)
		local border = cell:CreateTexture(nil, 'BORDER')
		border:SetAllPoints()
		border:SetColorTexture(COLOR_TODAY_BORDER.r, COLOR_TODAY_BORDER.g, COLOR_TODAY_BORDER.b, COLOR_TODAY_BORDER.a)
		border:Hide()
		cell.border = border

		-- Inner background (on top of border to create outline effect)
		local inner = cell:CreateTexture(nil, 'ARTWORK')
		inner:SetPoint('TOPLEFT', 1.5, -1.5)
		inner:SetPoint('BOTTOMRIGHT', -1.5, 1.5)
		inner:Hide()
		cell.inner = inner

		-- Day number text
		local dayText = cell:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
		dayText:SetAllPoints()
		dayText:SetJustifyH('CENTER')
		dayText:SetJustifyV('MIDDLE')
		local fontFile = dayText:GetFont()
		dayText:SetFont(fontFile, 9, '')
		cell.dayText = dayText

		grid.cells[i] = cell
	end

	grid.yBottom = gridY + GRID_ROWS * CELL_HEIGHT

	return grid
end

---Update a month grid with data for a specific month
---@param grid table Grid created by CreateMonthGrid
---@param year number
---@param month number 1-12
---@param dayMap table<number, boolean> From GetDailyLogForMonth
---@param todayDay number|nil Day of month if this is the current month, nil otherwise
local function UpdateMonthGrid(grid, year, month, dayMap, todayDay)
	-- Update title
	grid.titleText:SetText(MONTH_NAMES[month] .. ' ' .. year)

	-- Find what weekday day 1 falls on (1=Sunday in Lua)
	local firstDayTime = time({ year = year, month = month, day = 1, hour = 12 })
	local firstDayWday = date('*t', firstDayTime).wday -- 1=Sunday

	-- Find number of days in this month
	local daysInMonth = 28
	for d = 29, 31 do
		local t = time({ year = year, month = month, day = d, hour = 12 })
		if date('*t', t).month == month then
			daysInMonth = d
		else
			break
		end
	end

	-- Determine today's date for future-day checking
	local nowTime = time()
	local nowDate = date('*t', nowTime)
	local isCurrentMonth = (year == nowDate.year and month == nowDate.month)
	local isFutureMonth = (year > nowDate.year) or (year == nowDate.year and month > nowDate.month)

	-- Update cells
	for i = 1, GRID_ROWS * GRID_COLS do
		local cell = grid.cells[i]
		local dayNum = i - (firstDayWday - 1)

		if dayNum >= 1 and dayNum <= daysInMonth then
			local isFuture = isFutureMonth or (isCurrentMonth and dayNum > nowDate.day)
			local isToday = isCurrentMonth and dayNum == todayDay

			if isFuture then
				-- Future day: dim empty cell
				cell.bg:SetColorTexture(0.08, 0.08, 0.08, 0.3)
				cell.bg:Show()
				cell.dayText:SetText(dayNum)
				cell.dayText:SetTextColor(0.3, 0.3, 0.3)
				cell.dayText:Show()
				cell.border:Hide()
				cell.inner:Hide()
			elseif dayMap[dayNum] then
				-- Played day
				if isToday then
					cell.border:Show()
					cell.inner:SetColorTexture(COLOR_PLAYED.r, COLOR_PLAYED.g, COLOR_PLAYED.b, COLOR_PLAYED.a)
					cell.inner:Show()
					cell.bg:Hide()
				else
					cell.bg:SetColorTexture(COLOR_PLAYED.r, COLOR_PLAYED.g, COLOR_PLAYED.b, COLOR_PLAYED.a)
					cell.bg:Show()
					cell.border:Hide()
					cell.inner:Hide()
				end
				cell.dayText:SetText(dayNum)
				cell.dayText:SetTextColor(1, 1, 1)
				cell.dayText:Show()
			else
				-- Missed day
				if isToday then
					cell.border:Show()
					cell.inner:SetColorTexture(COLOR_MISSED.r, COLOR_MISSED.g, COLOR_MISSED.b, COLOR_MISSED.a)
					cell.inner:Show()
					cell.bg:Hide()
				else
					cell.bg:SetColorTexture(COLOR_MISSED.r, COLOR_MISSED.g, COLOR_MISSED.b, COLOR_MISSED.a)
					cell.bg:Show()
					cell.border:Hide()
					cell.inner:Hide()
				end
				cell.dayText:SetText(dayNum)
				cell.dayText:SetTextColor(0.4, 0.4, 0.4)
				cell.dayText:Show()
			end
		else
			-- Empty cell (before day 1 or after last day)
			cell.bg:Hide()
			cell.border:Hide()
			cell.inner:Hide()
			cell.dayText:Hide()
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Week Streak Bars
----------------------------------------------------------------------------------------------------

---Create week streak bar frames
---@param parent Frame
---@param yOffset number
---@return table bars { frames[5], yBottom }
local function CreateWeekBars(parent, yOffset)
	local bars = { frames = {} }
	local BAR_HEIGHT = 10
	local BAR_SPACING = 3

	for i = 1, 5 do
		local barFrame = CreateFrame('Frame', nil, parent)
		barFrame:SetHeight(BAR_HEIGHT)
		barFrame:SetPoint('TOPLEFT', parent, 'TOPLEFT', 4, -(yOffset + (i - 1) * (BAR_HEIGHT + BAR_SPACING)))
		barFrame:SetPoint('RIGHT', parent, 'RIGHT', -50, 0)

		local bg = barFrame:CreateTexture(nil, 'BACKGROUND')
		bg:SetAllPoints()
		barFrame.bg = bg

		local label = parent:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
		label:SetPoint('LEFT', barFrame, 'RIGHT', 4, 0)
		label:SetTextColor(0.5, 0.5, 0.5)
		local fontFile = label:GetFont()
		label:SetFont(fontFile, 8, '')
		barFrame.label = label

		bars.frames[i] = barFrame
	end

	bars.yBottom = yOffset + 5 * (BAR_HEIGHT + BAR_SPACING)
	return bars
end

---Update week streak bars with data
---@param bars table Created by CreateWeekBars
---@param weekData table Array of { weekStartDate, weekEndDate, played } (newest first)
local function UpdateWeekBars(bars, weekData)
	for i = 1, 5 do
		local bar = bars.frames[i]
		local data = weekData[i]

		if data then
			if data.played then
				bar.bg:SetColorTexture(COLOR_PLAYED.r, COLOR_PLAYED.g, COLOR_PLAYED.b, COLOR_PLAYED.a)
			else
				bar.bg:SetColorTexture(COLOR_MISSED.r, COLOR_MISSED.g, COLOR_MISSED.b, COLOR_MISSED.a)
			end

			-- Format label as short date range (e.g., "Feb 2-8")
			local startMonth = tonumber(data.weekStartDate:sub(6, 7))
			local startDay = tonumber(data.weekStartDate:sub(9, 10))
			local endDay = tonumber(data.weekEndDate:sub(9, 10))
			local monthAbbrev = MONTH_NAMES[startMonth]:sub(1, 3)
			bar.label:SetText(monthAbbrev .. ' ' .. startDay .. '-' .. endDay)

			bar:Show()
			bar.label:Show()
		else
			bar:Hide()
			bar.label:Hide()
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Main Streak Pane
----------------------------------------------------------------------------------------------------

---Create the streak pane inside the given parent frame
---@param parent Frame Right-side pane frame
function LibsTimePlayed:CreateStreakPane(parent)
	if streakPane then
		return streakPane
	end

	streakPane = CreateFrame('Frame', nil, parent)
	streakPane:SetPoint('TOPLEFT', parent, 'TOPLEFT', 0, 0)
	streakPane:SetPoint('TOPRIGHT', parent, 'TOPRIGHT', 0, 0)

	-- Header: Day Streak (left) and Week Streak (right)
	local yPos = 4

	-- Day Streak number
	local dayStreakNumber = streakPane:CreateFontString(nil, 'OVERLAY', 'GameFontNormalHuge')
	dayStreakNumber:SetPoint('TOP', streakPane, 'TOP', -(streakPane:GetWidth() or 120) * 0.2, -yPos)
	dayStreakNumber:SetText('0')
	dayStreakNumber:SetTextColor(COLOR_STREAK_ACTIVE.r, COLOR_STREAK_ACTIVE.g, COLOR_STREAK_ACTIVE.b)
	streakPane.dayStreakNumber = dayStreakNumber

	-- Day Streak label
	local dayStreakLabel = streakPane:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	dayStreakLabel:SetPoint('TOP', dayStreakNumber, 'BOTTOM', 0, -2)
	dayStreakLabel:SetText('Day Streak')
	dayStreakLabel:SetTextColor(0.7, 0.7, 0.7)
	streakPane.dayStreakLabel = dayStreakLabel

	-- Day Streak best (small text under label)
	local dayStreakBest = streakPane:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	dayStreakBest:SetPoint('TOP', dayStreakLabel, 'BOTTOM', 0, -1)
	dayStreakBest:SetText('Longest: 0')
	dayStreakBest:SetTextColor(0.5, 0.5, 0.5)
	local fontFile = dayStreakBest:GetFont()
	dayStreakBest:SetFont(fontFile, 9, '')
	streakPane.dayStreakBest = dayStreakBest

	-- Week Streak number
	local weekStreakNumber = streakPane:CreateFontString(nil, 'OVERLAY', 'GameFontNormalHuge')
	weekStreakNumber:SetPoint('TOP', streakPane, 'TOP', (streakPane:GetWidth() or 120) * 0.2, -yPos)
	weekStreakNumber:SetText('0')
	weekStreakNumber:SetTextColor(COLOR_STREAK_ACTIVE.r, COLOR_STREAK_ACTIVE.g, COLOR_STREAK_ACTIVE.b)
	streakPane.weekStreakNumber = weekStreakNumber

	-- Week Streak label
	local weekStreakLabel = streakPane:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	weekStreakLabel:SetPoint('TOP', weekStreakNumber, 'BOTTOM', 0, -2)
	weekStreakLabel:SetText('Week Streak')
	weekStreakLabel:SetTextColor(0.7, 0.7, 0.7)
	streakPane.weekStreakLabel = weekStreakLabel

	-- Week Streak best (small text under label)
	local weekStreakBest = streakPane:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	weekStreakBest:SetPoint('TOP', weekStreakLabel, 'BOTTOM', 0, -1)
	weekStreakBest:SetText('Longest: 0')
	weekStreakBest:SetTextColor(0.5, 0.5, 0.5)
	weekStreakBest:SetFont(fontFile, 9, '')
	streakPane.weekStreakBest = weekStreakBest

	-- Divider
	local headerHeight = 62
	local divider = streakPane:CreateTexture(nil, 'OVERLAY')
	divider:SetPoint('TOPLEFT', streakPane, 'TOPLEFT', 4, -headerHeight)
	divider:SetPoint('TOPRIGHT', streakPane, 'TOPRIGHT', -4, -headerHeight)
	divider:SetHeight(1)
	divider:SetColorTexture(0.3, 0.3, 0.3, 0.8)

	-- Current month calendar grid
	local currentMonthGrid = CreateMonthGrid(streakPane, headerHeight + 4)
	streakPane.currentMonthGrid = currentMonthGrid

	-- Previous month calendar grid
	local prevMonthY = currentMonthGrid.yBottom + 6
	local prevMonthGrid = CreateMonthGrid(streakPane, prevMonthY)
	streakPane.prevMonthGrid = prevMonthGrid

	-- Week streak bars
	local weekBarY = prevMonthGrid.yBottom + 6
	local weekBars = CreateWeekBars(streakPane, weekBarY)
	streakPane.weekBars = weekBars

	-- Stats line below week bars
	local statsY = weekBars.yBottom + 6
	local statsText = streakPane:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	statsText:SetPoint('TOPLEFT', streakPane, 'TOPLEFT', 4, -statsY)
	statsText:SetPoint('RIGHT', streakPane, 'RIGHT', -4, 0)
	statsText:SetJustifyH('CENTER')
	statsText:SetTextColor(0.6, 0.6, 0.6)
	streakPane.statsText = statsText

	-- Set total content height for scrolling
	local totalHeight = statsY + 20
	streakPane.totalContentHeight = totalHeight
	streakPane:SetHeight(totalHeight)

	-- Also set the scroll child (parent) height
	parent:SetHeight(totalHeight)

	self.streakPaneFrame = streakPane
	return streakPane
end

---Update streak pane with current data
function LibsTimePlayed:UpdateStreakPane()
	if not streakPane then
		return
	end

	-- Reposition streak numbers based on current pane width
	local paneWidth = streakPane:GetWidth()
	if paneWidth and paneWidth > 0 then
		local quarterWidth = paneWidth * 0.25
		streakPane.dayStreakNumber:ClearAllPoints()
		streakPane.dayStreakNumber:SetPoint('TOP', streakPane, 'TOP', -quarterWidth, -4)
		streakPane.weekStreakNumber:ClearAllPoints()
		streakPane.weekStreakNumber:SetPoint('TOP', streakPane, 'TOP', quarterWidth, -4)
	end

	-- Get streak data
	local streakInfo = self:GetStreakInfo()
	local weekStreak, weekData = self:GetWeekStreak()

	-- Update day streak number
	streakPane.dayStreakNumber:SetText(streakInfo.currentStreak)
	if streakInfo.currentStreak > 0 then
		streakPane.dayStreakNumber:SetTextColor(COLOR_STREAK_ACTIVE.r, COLOR_STREAK_ACTIVE.g, COLOR_STREAK_ACTIVE.b)
	else
		streakPane.dayStreakNumber:SetTextColor(COLOR_STREAK_ZERO.r, COLOR_STREAK_ZERO.g, COLOR_STREAK_ZERO.b)
	end

	-- Update day streak best
	streakPane.dayStreakBest:SetText('Longest: ' .. streakInfo.longestStreak)

	-- Update week streak number
	streakPane.weekStreakNumber:SetText(weekStreak)
	if weekStreak > 0 then
		streakPane.weekStreakNumber:SetTextColor(COLOR_STREAK_ACTIVE.r, COLOR_STREAK_ACTIVE.g, COLOR_STREAK_ACTIVE.b)
	else
		streakPane.weekStreakNumber:SetTextColor(COLOR_STREAK_ZERO.r, COLOR_STREAK_ZERO.g, COLOR_STREAK_ZERO.b)
	end

	-- Update week streak best
	streakPane.weekStreakBest:SetText('Longest: ' .. streakInfo.longestWeekStreak)

	-- Get current date info
	local now = date('*t', time())
	local curYear, curMonth = now.year, now.month

	-- Previous month
	local prevYear, prevMonth = curYear, curMonth - 1
	if prevMonth < 1 then
		prevMonth = 12
		prevYear = prevYear - 1
	end

	-- Update current month grid
	local curDayMap = self:GetDailyLogForMonth(curYear, curMonth)
	UpdateMonthGrid(streakPane.currentMonthGrid, curYear, curMonth, curDayMap, now.day)

	-- Update previous month grid
	local prevDayMap = self:GetDailyLogForMonth(prevYear, prevMonth)
	UpdateMonthGrid(streakPane.prevMonthGrid, prevYear, prevMonth, prevDayMap, nil)

	-- Update week streak bars
	UpdateWeekBars(streakPane.weekBars, weekData)

	-- Update stats line
	local avgText = string.format('%.1fh', streakInfo.averageSessionMinutes / 60)
	streakPane.statsText:SetText('Avg: ' .. avgText .. '/session  |  ' .. streakInfo.totalSessions .. ' sessions')
end
