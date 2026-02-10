local addonName, root = ...
local AceAddon = LibStub:GetLibrary('AceAddon-3.0', true)
local AceDB = LibStub:GetLibrary('AceDB-3.0', true)
---@class LibsTotembar : AceAddon, AceEvent-3.0, AceTimer-3.0
local LibsTotembar = AceAddon:NewAddon(addonName, 'AceEvent-3.0', 'AceTimer-3.0')

-- Enhanced logging integration with LibAT using new registration system
local logger = nil

-- Initialize LibAT Logger integration
local function InitializeLibATLogger()
	if LibAT and LibAT.Logger then
		logger = LibAT.Logger.RegisterAddon('LibsTotembar')
		return true
	end
	return false
end

-- Logging function
local function Log(message, level)
	if not logger then
		InitializeLibATLogger()
	end

	if not logger then
		return
	end

	-- Use the new logger object API
	if level then
		logger.log(message, level)
	else
		logger.info(message)
	end
end

---@class LibsTotembar.Timer
---@field spellId number
---@field duration number
---@field startTime number
---@field endTime number
---@field category string
---@field slotId number?
---@field timerId string
---@field metadata table

---@class LibsTotembar.SpellData
---@field id number
---@field name string
---@field duration number
---@field category string
---@field slot number?
---@field icon string?
---@field enabled boolean
---@field customAdded boolean?

-- Variables
local playerClass
local updateTimerId

-- Export shared utilities to modules
LibsTotembar.Log = Log
LibsTotembar.activeTimers = {}

-- Enhanced spell definitions - organized but easily extensible
local BASE_SPELLS = {
	SHAMAN = {
		-- Validated retail totems (2024-2025) - many classic totems no longer exist
		[2484] = { id = 2484, name = 'Earthbind Totem', duration = 20, category = 'Earth' },
		[8143] = { id = 8143, name = 'Tremor Totem', duration = 10, category = 'Earth' },
		[5394] = { id = 5394, name = 'Healing Stream Totem', duration = 15, category = 'Water' },
		[8512] = { id = 8512, name = 'Windfury Totem', duration = 120, category = 'Air' },
		-- Note: Many classic totems like Stoneskin, Stoneclaw, Searing, Flametongue, Fire Nova,
		-- Mana Spring, Sentry, Grounding, and Wrath of Air no longer exist in retail
	},
	HUNTER = {
		-- Traps (validated 2024-2025 retail)
		[187650] = { id = 187650, name = 'Freezing Trap', duration = 60, category = 'Trap' },
		[187698] = { id = 187698, name = 'Tar Trap', duration = 30, category = 'Trap' },
		[162488] = { id = 162488, name = 'Steel Trap', duration = 60, category = 'Trap' },
		[236776] = { id = 236776, name = 'High Explosive Trap', duration = 60, category = 'Trap' },
		[462031] = { id = 462031, name = 'Implosive Trap', duration = 60, category = 'Trap' },
		-- Utility
		[1543] = { id = 1543, name = 'Flare', duration = 20, category = 'Utility' },
		[109248] = { id = 109248, name = 'Binding Shot', duration = 8, category = 'Utility' },
	},
	PRIEST = {
		-- Utility spells
		[121536] = { id = 121536, name = 'Angelic Feather', duration = 8, category = 'Mobility' },
		[17] = { id = 17, name = 'Power Word: Shield', duration = 30, category = 'Protection' },
		[139] = { id = 139, name = 'Renew', duration = 15, category = 'Healing' },
	},
}

-- Database defaults
---@class LibsTotembar.DBDefaults
local defaults = {
	profile = {
		enabled = true,
		maxButtons = 8,
		hideWhenEmpty = true,
		-- Position settings
		position = {
			anchor = 'CENTER',
			x = 0,
			y = -200,
		},
		-- Layout settings
		layout = {
			scale = 1.0,
			spacing = 2,
		},
		-- Appearance settings
		appearance = {
			showBackground = true,
			backgroundColor = { 0, 0, 0, 0.8 },
			borderColor = { 1, 1, 1, 1 },
			showCooldownText = true,
		},
		-- Behavior settings
		behavior = {
			lockPosition = false,
			showTooltips = true,
			clickToDestroy = true,
		},
		-- Filter settings
		filters = {
			hideInCombat = false,
			hideOutOfCombat = false,
			showUnknownSpells = false,
		},
		-- Spell settings
		spells = {
			enabled = {},
			custom = {},
		},
	},
}

---Get available spells for current class including custom spells
---@return table<number, LibsTotembar.SpellData>
function LibsTotembar:GetAvailableSpells()
	local spells = {}

	-- Add base class spells
	if BASE_SPELLS[playerClass] then
		for spellId, spellData in pairs(BASE_SPELLS[playerClass]) do
			local spellInfo = C_Spell.GetSpellInfo(spellId)
			spells[spellId] = {
				id = spellData.id,
				name = spellData.name or (spellInfo and spellInfo.name) or ('Spell ' .. spellId),
				duration = spellData.duration,
				category = spellData.category,
				slot = spellData.slot,
				icon = spellData.icon or (spellInfo and spellInfo.iconID),
				enabled = self.db.profile.spells.enabled[spellId] ~= false, -- Default true unless explicitly disabled
				customAdded = false,
			}
		end
	end

	-- Add custom spells
	for spellId, spellData in pairs(self.db.profile.spells.custom) do
		local spellInfo = C_Spell.GetSpellInfo(spellId)
		spells[spellId] = {
			id = spellData.id,
			name = spellData.name or (spellInfo and spellInfo.name) or ('Custom Spell ' .. spellId),
			duration = spellData.duration,
			category = spellData.category,
			slot = spellData.slot,
			icon = spellData.icon or (spellInfo and spellInfo.iconID),
			enabled = self.db.profile.spells.enabled[spellId] ~= false, -- Default true unless explicitly disabled
			customAdded = true,
		}
	end

	return spells
end

---Add a custom spell
---@param spellId number
---@param duration number
---@param category string
---@return boolean success
function LibsTotembar:AddCustomSpell(spellId, duration, category)
	local spellInfo = C_Spell.GetSpellInfo(spellId)
	if not spellInfo or not spellInfo.name then
		Log('Spell ID ' .. spellId .. ' not found', 'error')
		return false
	end
	local spellName = spellInfo.name

	self.db.profile.spells.custom[spellId] = {
		id = spellId,
		name = spellName,
		duration = duration,
		category = category or 'Custom',
	}

	-- Enable by default
	self.db.profile.spells.enabled[spellId] = true

	Log('Added custom spell: ' .. spellName, 'info')
	return true
end

---Remove a custom spell
---@param spellId number
---@return boolean success
function LibsTotembar:RemoveCustomSpell(spellId)
	if self.db.profile.spells.custom[spellId] then
		local spellName = self.db.profile.spells.custom[spellId].name
		self.db.profile.spells.custom[spellId] = nil
		self.db.profile.spells.enabled[spellId] = nil
		Log('Removed custom spell: ' .. spellName, 'info')
		return true
	end
	return false
end

---Initialize spell settings
function LibsTotembar:InitializeSpellSettings()
	local availableSpells = self:GetAvailableSpells()

	-- Set default enabled state for new spells
	for spellId, spellData in pairs(availableSpells) do
		if self.db.profile.spells.enabled[spellId] == nil then
			self.db.profile.spells.enabled[spellId] = true -- Default to enabled
		end
	end
end

---Timer callback for spell expiration
---@param buttonIndex number
---@param spellId number
function LibsTotembar:ExpireSpell(buttonIndex, spellId)
	Log('Spell expired: ' .. spellId .. ' from button ' .. buttonIndex, 'debug')
	self.BarManager:ExpireSpell(buttonIndex, spellId)
end

---Initialize the addon
function LibsTotembar:OnInitialize()
	-- Initialize SpartanUI Logger integration first
	if InitializeLibATLogger() then
		Log('LibsTotembar initializing with SpartanUI Logger support', 'info')
	else
		Log('LibsTotembar initializing without SpartanUI Logger', 'info')
	end

	-- Set up database using the library directly
	if AceDB then
		---@type LibsTotembar.DBDefaults
		self.db = AceDB:New('LibsTotembarDB', defaults, true)
	else
		error('LibsTotembar: AceDB-3.0 not available for database initialization')
		return
	end

	-- Get player class
	_, playerClass = UnitClass('player')
	self.playerClass = playerClass

	-- Initialize spell settings for current class
	self:InitializeSpellSettings()

	-- Setup options (only if OptionsManager is available)
	if self.OptionsManager then
		self:SetupOptions()
	else
		Log('Configuration UI not available - Options module missing', 'warning')
	end

	Log('LibsTotembar initialized for ' .. playerClass, 'info')
end

---Enable the addon
function LibsTotembar:OnEnable()
	-- Register events based on class
	if playerClass == 'SHAMAN' then
		self:RegisterEvent('PLAYER_TOTEM_UPDATE')
		self:RegisterEvent('PLAYER_ENTERING_WORLD', 'UpdateAllTotems')
		self:RegisterEvent('PLAYER_LOGIN', 'UpdateAllTotems')
	elseif playerClass == 'HUNTER' then
		-- Hunters need spell cast tracking for traps and flare
		self:RegisterEvent('PLAYER_ENTERING_WORLD')
		self:RegisterEvent('PLAYER_LOGIN')
	end

	-- Register general events
	self:RegisterEvent('UNIT_SPELLCAST_SUCCEEDED')
	self:RegisterEvent('PLAYER_REGEN_DISABLED') -- Combat start
	self:RegisterEvent('PLAYER_REGEN_ENABLED') -- Combat end

	Log('LibsTotembar OnEnable starting...', 'debug')
	Log('Player class detected as: ' .. (playerClass or 'unknown'), 'info')

	-- Create UI (BarManager handles this)
	if self.BarManager then
		Log('Creating bar frame...', 'debug')
		self.BarManager:CreateBarFrame()
		-- Start update timer
		updateTimerId = self:ScheduleRepeatingTimer('UpdateFrame', 0.1)
		Log('Update timer started', 'debug')
	else
		Log('Bar creation failed - Bar module missing', 'error')
	end

	Log('LibsTotembar enabled', 'info')
end

---Update frame on regular timer
function LibsTotembar:UpdateFrame()
	if self.BarManager then
		self.BarManager:UpdateFrame()
	end
end

---Handle events
function LibsTotembar:PLAYER_TOTEM_UPDATE(event, slot)
	if self.BarManager then
		self.BarManager:UpdateTotemSlot(slot)
	end
end

function LibsTotembar:UNIT_SPELLCAST_SUCCEEDED(event, unit, castGUID, spellId)
	local spellInfo = C_Spell.GetSpellInfo(spellId)
	local spellName = spellInfo and spellInfo.name
	if self.BarManager then
		self.BarManager:HandleSpellCast(unit, spellName, spellId)
	end
end

function LibsTotembar:PLAYER_REGEN_DISABLED()
	if self.BarManager then
		self.BarManager:UpdateBarVisibility() -- Check combat filters
	end
end

function LibsTotembar:PLAYER_REGEN_ENABLED()
	if self.BarManager then
		self.BarManager:UpdateBarVisibility() -- Check combat filters
	end
end

function LibsTotembar:PLAYER_ENTERING_WORLD()
	if playerClass == 'HUNTER' and self.BarManager then
		-- Update bar visibility for hunters
		self.BarManager:UpdateBarVisibility()
	end
end

function LibsTotembar:PLAYER_LOGIN()
	if playerClass == 'HUNTER' and self.BarManager then
		-- Update bar visibility for hunters
		self.BarManager:UpdateBarVisibility()
	end
end

-- Backward compatibility functions
function LibsTotembar:UpdateAllTotems()
	if self.BarManager then
		self.BarManager:UpdateAllTotems()
	end
end

-- Enhanced slash commands
SLASH_LIBSTOTEMBAR1 = '/totembar'
SLASH_LIBSTOTEMBAR2 = '/ltb'
SlashCmdList['LIBSTOTEMBAR'] = function(msg)
	local args = { strsplit(' ', msg) }
	local command = args[1] and string.lower(args[1]) or ''

	if command == 'config' or command == 'options' or command == '' then
		-- Open settings panel using AceConfigDialog directly
		local AceConfigDialog = LibStub('AceConfigDialog-3.0', true)
		if AceConfigDialog then
			AceConfigDialog:Open('LibsTotembar')
		else
			Log('Configuration panel not accessible - missing AceConfigDialog library', 'warning')
		end
	elseif command == 'toggle' then
		LibsTotembar.db.profile.enabled = not LibsTotembar.db.profile.enabled
		if LibsTotembar.BarManager then
			LibsTotembar.BarManager:UpdateBarVisibility()
		end
		Log('LibsTotembar ' .. (LibsTotembar.db.profile.enabled and 'enabled' or 'disabled'), 'info')
	elseif command == 'add' then
		local spellId = tonumber(args[2])
		local duration = tonumber(args[3]) or 30
		local category = args[4] or 'Custom'

		if spellId then
			if LibsTotembar:AddCustomSpell(spellId, duration, category) then
				Log('Successfully added spell ' .. spellId, 'info')
			else
				Log('Failed to add spell ' .. spellId, 'error')
			end
		else
			Log('Usage: /totembar add <spellID> [duration] [category]', 'info')
		end
	elseif command == 'remove' then
		local spellId = tonumber(args[2])
		if spellId then
			if LibsTotembar:RemoveCustomSpell(spellId) then
				Log('Successfully removed spell ' .. spellId, 'info')
			else
				Log('Spell ' .. spellId .. ' not found in custom spells', 'error')
			end
		else
			Log('Usage: /totembar remove <spellID>', 'info')
		end
	elseif command == 'list' then
		Log('Available spells:', 'info')
		local availableSpells = LibsTotembar:GetAvailableSpells()
		for spellId, spellData in pairs(availableSpells) do
			local status = spellData.enabled and '✓' or '✗'
			local custom = spellData.customAdded and ' (Custom)' or ''
			Log(string.format('%s [%d] %s - %ds%s', status, spellId, spellData.name, spellData.duration, custom), 'info')
		end
	elseif command == 'reset' then
		LibsTotembar.db:ResetProfile()
		Log('LibsTotembar settings reset to defaults', 'info')
	elseif command == 'test' then
		if LibsTotembar.BarManager then
			LibsTotembar.BarManager:EnableTestMode()
		else
			Log('Test mode not available - Bar module missing', 'error')
		end
	elseif command == 'clear' then
		if LibsTotembar.BarManager then
			LibsTotembar.BarManager:ClearAllButtons()
			Log('All buttons cleared', 'info')
		else
			Log('Clear not available - Bar module missing', 'error')
		end
	elseif command == 'help' then
		Log('LibsTotembar Commands:', 'info')
		Log('  /totembar or /ltb - Open configuration panel', 'info')
		Log('  /totembar toggle - Toggle addon on/off', 'info')
		Log('  /totembar add <spellID> [duration] [category] - Add custom spell', 'info')
		Log('  /totembar remove <spellID> - Remove custom spell', 'info')
		Log('  /totembar list - List all available spells', 'info')
		Log('  /totembar reset - Reset settings to defaults', 'info')
		Log('  /totembar test - Show test buttons', 'info')
		Log('  /totembar clear - Clear all buttons', 'info')
		Log('  /totembar help - Show this help', 'info')
	else
		Log('Unknown command. Use /totembar help for available commands.', 'error')
	end
end

-- Initialize when addon loads
Log('LibsTotembar loaded successfully', 'info')
