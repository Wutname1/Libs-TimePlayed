---@class LibsTimePlayed : AceAddon
local ADDON_NAME, LibsTimePlayed = ...

LibsTimePlayed = LibStub('AceAddon-3.0'):NewAddon(ADDON_NAME, 'AceEvent-3.0', 'AceTimer-3.0', 'AceConsole-3.0')
_G.LibsTimePlayed = LibsTimePlayed

LibsTimePlayed.version = '1.0.0'
LibsTimePlayed.addonName = "Lib's TimePlayed"

function LibsTimePlayed:OnInitialize()
	-- Initialize logger
	if LibAT and LibAT.Logger then
		self.logger = LibAT.Logger.RegisterAddon('LibsTimePlayed')
	end

	-- Database is initialized in Core/Database.lua
	self:InitializeDatabase()

	-- Register slash commands
	self:RegisterChatCommand('libstp', 'SlashCommand')
	self:RegisterChatCommand('timeplayed', 'SlashCommand')
end

function LibsTimePlayed:OnEnable()
	-- Initialize subsystems
	self:InitializeTracker()
	self:InitializeDataBroker()
	self:InitializeMinimapButton()
	self:InitializeOptions()

	self:Log("Lib's TimePlayed loaded", 'info')
end

function LibsTimePlayed:OnDisable()
	self:UnregisterAllEvents()
	self:CancelAllTimers()
end

function LibsTimePlayed:SlashCommand(input)
	input = input and input:trim():lower() or ''

	if input == '' or input == 'config' or input == 'options' then
		self:OpenOptions()
	elseif input == 'played' then
		RequestTimePlayed()
	else
		self:Print('Commands: /libstp [config|played]')
	end
end

-- Logging helper
function LibsTimePlayed:Log(message, level)
	level = level or 'info'
	if self.logger and self.logger[level] then
		self.logger[level](message)
	end
end
