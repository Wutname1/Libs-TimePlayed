---@class LibsTimePlayed
local LibsTimePlayed = LibStub('AceAddon-3.0'):GetAddon('Libs-TimePlayed')

function LibsTimePlayed:InitializeMinimapButton()
	local LibDBIcon = LibStub('LibDBIcon-1.0', true)
	if not LibDBIcon or not self.dataObject then
		return
	end

	LibDBIcon:Register("Lib's TimePlayed", self.dataObject, self.db.minimap)
end
