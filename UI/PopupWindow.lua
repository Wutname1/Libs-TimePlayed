---@class LibsTimePlayed
local LibsTimePlayed = LibStub('AceAddon-3.0'):GetAddon('Libs-TimePlayed')

local ROW_HEIGHT = 22
local MAX_ROWS = 30
local GROUPBY_CYCLE = { 'class', 'realm', 'faction' }
local GROUPBY_LABELS = {
	class = 'Class',
	realm = 'Realm',
	faction = 'Faction',
}

-- Row pool
local rows = {}
local popupFrame

---Create a single data row with label, bar, percent, and value
---@param parent Frame
---@param width number
---@return Frame
local function CreateRow(parent, width)
	local row = CreateFrame('Frame', nil, parent)
	row:SetHeight(ROW_HEIGHT)
	row:SetWidth(width)

	-- Group/class label
	local label = row:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	label:SetPoint('LEFT', row, 'LEFT', 4, 0)
	label:SetWidth(100)
	label:SetJustifyH('LEFT')
	row.label = label

	-- Value text (right side)
	local valueText = row:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	valueText:SetPoint('RIGHT', row, 'RIGHT', -4, 0)
	valueText:SetWidth(80)
	valueText:SetJustifyH('RIGHT')
	row.valueText = valueText

	-- Percent text
	local percentText = row:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	percentText:SetPoint('RIGHT', valueText, 'LEFT', -4, 0)
	percentText:SetWidth(45)
	percentText:SetJustifyH('RIGHT')
	row.percentText = percentText

	-- StatusBar between label and percent
	local bar = CreateFrame('StatusBar', nil, row)
	bar:SetPoint('LEFT', label, 'RIGHT', 4, 0)
	bar:SetPoint('RIGHT', percentText, 'LEFT', -4, 0)
	bar:SetHeight(14)
	bar:SetMinMaxValues(0, 1)
	bar:SetStatusBarTexture('Interface\\TargetingFrame\\UI-StatusBar')

	local barBg = bar:CreateTexture(nil, 'BACKGROUND')
	barBg:SetAllPoints()
	barBg:SetColorTexture(0, 0, 0, 0.4)

	row.bar = bar

	return row
end

---Update scrollbar visibility based on content height
---@param frame Frame The scroll frame
local function UpdateScrollBarVisibility(frame)
	if not frame.scrollBar then
		return
	end
	if frame:GetVerticalScrollRange() > 0 then
		frame.scrollBar:Show()
	else
		frame.scrollBar:Hide()
	end
end

---Create the popup window frame
---@return Frame
function LibsTimePlayed:CreatePopup()
	if popupFrame then
		return popupFrame
	end

	local db = self.db.popup

	-- Main frame
	local frame = CreateFrame('Frame', 'LibsTimePlayedPopup', UIParent, 'BackdropTemplate')
	frame:SetFrameStrata('DIALOG')
	frame:SetSize(db.width, db.height)
	frame:SetPoint(db.point, UIParent, db.point, db.x, db.y)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:SetResizable(true)
	frame:SetResizeBounds(420, 200, 800, 600)
	frame:EnableMouse(true)
	frame:SetBackdrop({
		bgFile = 'Interface\\ChatFrame\\ChatFrameBackground',
		edgeFile = 'Interface\\DialogFrame\\UI-DialogBox-Border',
		tile = true,
		tileSize = 16,
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	frame:SetBackdropColor(0, 0, 0, 0.85)
	frame:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)

	-- Dragging
	frame:RegisterForDrag('LeftButton')
	frame:SetScript('OnDragStart', frame.StartMoving)
	frame:SetScript('OnDragStop', function(f)
		f:StopMovingOrSizing()
		local point, _, _, x, y = f:GetPoint()
		self.db.popup.point = point
		self.db.popup.x = x
		self.db.popup.y = y
	end)

	-- Resize grip
	local resizer = CreateFrame('Button', nil, frame)
	resizer:SetSize(16, 16)
	resizer:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -4, 4)
	resizer:SetNormalTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up')
	resizer:SetHighlightTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight')
	resizer:SetPushedTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down')
	resizer:SetScript('OnMouseDown', function()
		frame:StartSizing('BOTTOMRIGHT')
	end)
	resizer:SetScript('OnMouseUp', function()
		frame:StopMovingOrSizing()
		self.db.popup.width = frame:GetWidth()
		self.db.popup.height = frame:GetHeight()
		self:UpdatePopupLayout()
	end)

	-- Title
	local title = frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightLarge')
	title:SetPoint('TOP', frame, 'TOP', 0, -12)
	frame.title = title

	-- Close button
	local closeBtn = CreateFrame('Button', nil, frame, 'UIPanelCloseButton')
	closeBtn:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -2, -2)

	-- Grouping cycle button
	local groupBtn = CreateFrame('Button', nil, frame, 'UIPanelButtonTemplate')
	groupBtn:SetSize(80, 22)
	groupBtn:SetPoint('TOPLEFT', frame, 'TOPLEFT', 12, -10)
	groupBtn:SetText('Class')
	groupBtn:SetScript('OnClick', function()
		self:CycleGroupBy()
	end)
	frame.groupBtn = groupBtn

	-- Scroll frame
	local scrollFrame = CreateFrame('ScrollFrame', 'LibsTimePlayedPopupScroll', frame, 'UIPanelScrollFrameTemplate')
	scrollFrame:SetPoint('TOPLEFT', frame, 'TOPLEFT', 8, -38)
	scrollFrame:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -28, 52)

	local scrollChild = CreateFrame('Frame', nil, scrollFrame)
	scrollChild:SetWidth(scrollFrame:GetWidth())
	scrollChild:SetHeight(1) -- will be set dynamically
	scrollFrame:SetScrollChild(scrollChild)

	-- Store the scrollbar reference
	scrollFrame.scrollBar = _G['LibsTimePlayedPopupScrollScrollBar']

	-- Mouse wheel scrolling
	scrollFrame:EnableMouseWheel(true)
	scrollFrame:SetScript('OnMouseWheel', function(sf, delta)
		local current = sf:GetVerticalScroll()
		local maxScroll = sf:GetVerticalScrollRange()
		local newScroll = current - (delta * 20)
		newScroll = math.max(0, math.min(newScroll, maxScroll))
		sf:SetVerticalScroll(newScroll)
	end)

	frame.scrollFrame = scrollFrame
	frame.scrollChild = scrollChild

	-- Pre-allocate rows
	for i = 1, MAX_ROWS do
		local row = CreateRow(scrollChild, scrollChild:GetWidth())
		row:SetPoint('TOPLEFT', scrollChild, 'TOPLEFT', 0, -((i - 1) * ROW_HEIGHT))
		row:Hide()
		rows[i] = row
	end

	-- Total row at bottom
	local totalText = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	totalText:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', 12, 10)
	totalText:SetTextColor(1, 0.82, 0)
	frame.totalText = totalText

	-- Milestone text above total
	local milestoneText = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	milestoneText:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', 12, 28)
	milestoneText:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -12, 28)
	milestoneText:SetJustifyH('LEFT')
	milestoneText:SetTextColor(0.7, 0.7, 0.7)
	frame.milestoneText = milestoneText

	-- Handle resize
	frame:SetScript('OnSizeChanged', function()
		self:UpdatePopupLayout()
	end)

	frame:Hide()
	popupFrame = frame
	return frame
end

---Update layout after resize
function LibsTimePlayed:UpdatePopupLayout()
	if not popupFrame then
		return
	end

	local contentWidth = popupFrame.scrollFrame:GetWidth()
	popupFrame.scrollChild:SetWidth(contentWidth)

	for i = 1, MAX_ROWS do
		if rows[i] then
			rows[i]:SetWidth(contentWidth)
		end
	end

	UpdateScrollBarVisibility(popupFrame.scrollFrame)
end

---Populate the popup with current data
function LibsTimePlayed:UpdatePopup()
	if not popupFrame then
		return
	end

	local sortedGroups, accountTotal = self:GetGroupedData()
	local groupBy = self.db.display.groupBy or 'class'

	-- Update title and group button
	popupFrame.title:SetText("Lib's TimePlayed - By " .. GROUPBY_LABELS[groupBy])
	popupFrame.groupBtn:SetText(GROUPBY_LABELS[groupBy])

	-- Find top group total for bar scaling
	local topGroupTotal = 0
	if sortedGroups[1] then
		topGroupTotal = sortedGroups[1].total
	end

	-- Populate rows
	local rowIndex = 0
	for _, group in ipairs(sortedGroups) do
		rowIndex = rowIndex + 1
		if rowIndex > MAX_ROWS then
			break
		end

		local row = rows[rowIndex]
		local color = group.color

		-- Label
		row.label:SetText(group.label)
		row.label:SetTextColor(color.r, color.g, color.b)

		-- Bar: width relative to top group
		local barPercent = topGroupTotal > 0 and (group.total / topGroupTotal) or 0
		row.bar:SetValue(barPercent)
		row.bar:SetStatusBarColor(color.r, color.g, color.b, 0.8)

		-- Percent: relative to account total
		local percent = accountTotal > 0 and (group.total / accountTotal * 100) or 0
		row.percentText:SetText(string.format('%.1f%%', percent))
		row.percentText:SetTextColor(0.8, 0.8, 0.8)

		-- Value
		row.valueText:SetText(self.FormatTime(group.total, 'smart'))
		row.valueText:SetTextColor(1, 1, 1)

		row:Show()
	end

	-- Hide unused rows
	for i = rowIndex + 1, MAX_ROWS do
		rows[i]:Hide()
	end

	-- Set content height
	popupFrame.scrollChild:SetHeight(rowIndex * ROW_HEIGHT)

	-- Total
	popupFrame.totalText:SetText('Account Total: ' .. self.FormatTime(accountTotal, 'full'))

	-- Milestones
	if self.GetMilestones and self.db.display.showMilestones then
		local milestones = self:GetMilestones(sortedGroups, accountTotal)
		popupFrame.milestoneText:SetText(table.concat(milestones, '  |  '))
		popupFrame.milestoneText:Show()
	else
		popupFrame.milestoneText:Hide()
	end

	UpdateScrollBarVisibility(popupFrame.scrollFrame)
end

---Toggle popup visibility
function LibsTimePlayed:TogglePopup()
	local frame = self:CreatePopup()
	if frame:IsShown() then
		frame:Hide()
	else
		self:UpdatePopup()
		frame:Show()
	end
end

---Cycle groupBy mode (class -> realm -> faction)
function LibsTimePlayed:CycleGroupBy()
	local current = self.db.display.groupBy or 'class'
	local nextMode
	for i, mode in ipairs(GROUPBY_CYCLE) do
		if mode == current then
			nextMode = GROUPBY_CYCLE[i < #GROUPBY_CYCLE and i + 1 or 1]
			break
		end
	end
	self.db.display.groupBy = nextMode or 'class'

	-- Refresh popup if visible
	if popupFrame and popupFrame:IsShown() then
		self:UpdatePopup()
	end
end
