---@class LibsTimePlayed
local LibsTimePlayed = LibStub('AceAddon-3.0'):GetAddon('Libs-TimePlayed')

function LibsTimePlayed:InitializeOptions()
	local options = {
		name = "Lib's TimePlayed",
		type = 'group',
		args = {
			display = {
				name = 'Display',
				type = 'group',
				order = 1,
				inline = true,
				args = {
					format = {
						name = 'Display Format',
						desc = 'What time to show on the broker text',
						type = 'select',
						order = 1,
						values = {
							total = 'Total Played',
							session = 'Session Time',
							level = 'Level Time',
						},
						get = function()
							return LibsTimePlayed.db.display.format
						end,
						set = function(_, val)
							LibsTimePlayed.db.display.format = val
							LibsTimePlayed:UpdateDisplay()
						end,
					},
					timeFormat = {
						name = 'Time Format',
						desc = 'How to format time values',
						type = 'select',
						order = 2,
						values = {
							smart = 'Smart (2d 5h)',
							full = 'Full (2d 5h 30m)',
							hours = 'Hours (53.5h)',
						},
						get = function()
							return LibsTimePlayed.db.display.timeFormat
						end,
						set = function(_, val)
							LibsTimePlayed.db.display.timeFormat = val
							LibsTimePlayed:UpdateDisplay()
						end,
					},
					groupBy = {
						name = 'Group By',
						desc = 'How to group characters in tooltip and popup window',
						type = 'select',
						order = 3,
						values = {
							class = 'Class',
							realm = 'Realm',
							faction = 'Faction',
						},
						get = function()
							return LibsTimePlayed.db.display.groupBy
						end,
						set = function(_, val)
							LibsTimePlayed.db.display.groupBy = val
							LibsTimePlayed:UpdateDisplay()
						end,
					},
					showBarsInTooltip = {
						name = 'Show Bars in Tooltip',
						desc = 'Display text-based progress bars next to groups in the tooltip',
						type = 'toggle',
						order = 4,
						width = 'full',
						get = function()
							return LibsTimePlayed.db.display.showBarsInTooltip
						end,
						set = function(_, val)
							LibsTimePlayed.db.display.showBarsInTooltip = val
						end,
					},
					showMilestones = {
						name = 'Show Milestones',
						desc = 'Display milestone achievements in tooltip and popup window',
						type = 'toggle',
						order = 5,
						width = 'full',
						get = function()
							return LibsTimePlayed.db.display.showMilestones
						end,
						set = function(_, val)
							LibsTimePlayed.db.display.showMilestones = val
						end,
					},
				},
			},
			data = {
				name = 'Character Data',
				type = 'group',
				order = 2,
				inline = true,
				args = {
					refresh = {
						name = 'Refresh Played Time',
						desc = 'Request updated /played data from the server',
						type = 'execute',
						order = 1,
						func = function()
							RequestTimePlayed()
						end,
					},
					purge = {
						name = 'Purge Old Characters',
						desc = 'Remove characters not updated in over 90 days',
						type = 'execute',
						order = 2,
						confirm = true,
						confirmText = 'Remove characters not updated in 90+ days?',
						func = function()
							LibsTimePlayed:PurgeOldCharacters(90)
						end,
					},
				},
			},
			popup = {
				name = 'Popup Window',
				type = 'group',
				order = 3,
				inline = true,
				args = {
					toggle = {
						name = 'Toggle Popup Window',
						desc = 'Show or hide the standalone popup window',
						type = 'execute',
						order = 1,
						func = function()
							LibsTimePlayed:TogglePopup()
						end,
					},
					resetPosition = {
						name = 'Reset Position',
						desc = 'Reset popup window size and position to defaults',
						type = 'execute',
						order = 2,
						func = function()
							LibsTimePlayed.db.popup.width = 520
							LibsTimePlayed.db.popup.height = 300
							LibsTimePlayed.db.popup.point = 'CENTER'
							LibsTimePlayed.db.popup.x = 0
							LibsTimePlayed.db.popup.y = 0
							local frame = _G['LibsTimePlayedPopup']
							if frame then
								frame:ClearAllPoints()
								frame:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
								frame:SetSize(520, 300)
							end
							LibsTimePlayed:Print('Popup position reset.')
						end,
					},
				},
			},
			profiles = LibStub('AceDBOptions-3.0'):GetOptionsTable(LibsTimePlayed.dbobj),
		},
	}

	-- Move profiles to end
	options.args.profiles.order = 99

	LibStub('AceConfig-3.0'):RegisterOptionsTable('LibsTimePlayed', options)
	LibStub('AceConfigDialog-3.0'):AddToBlizOptions('LibsTimePlayed', "Lib's TimePlayed")
end

function LibsTimePlayed:OpenOptions()
	LibStub('AceConfigDialog-3.0'):Open('LibsTimePlayed')
end

---Remove characters not updated within the given number of days
---@param days number
function LibsTimePlayed:PurgeOldCharacters(days)
	local cutoff = time() - (days * 86400)
	local removed = 0

	for charKey, data in pairs(self.globaldb.characters) do
		if type(data) == 'table' and (data.lastUpdated or 0) < cutoff then
			self.globaldb.characters[charKey] = nil
			removed = removed + 1
		end
	end

	self:Print('Removed ' .. removed .. ' character(s) not updated in ' .. days .. '+ days')
end
