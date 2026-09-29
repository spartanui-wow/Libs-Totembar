local addonName, ns = ...

---@class LibsTotembar : AceAddon, AceEvent-3.0, AceConsole-3.0
local Addon = LibStub('AceAddon-3.0'):NewAddon(addonName, 'AceEvent-3.0', 'AceConsole-3.0')
Addon:SetDefaultModuleLibraries('AceEvent-3.0')
ns.Addon = Addon

local _, _, _, toc = GetBuildInfo()
Addon.toc = toc or 0
-- Flavor is decided by interface number, not WOW_PROJECT_ID: WoW Forever reports a project id
-- that older libraries mistake for Retail, but it plays by Classic rules.
Addon.IsRetail = Addon.toc >= 110000
Addon.IsClassic = not Addon.IsRetail

-- Messages other modules listen for.
Addon.MSG_SPELLS = 'LIBSTOTEMBAR_SPELLS_CHANGED'
Addon.MSG_TIMERS = 'LIBSTOTEMBAR_TIMERS_CHANGED'
Addon.MSG_SETTINGS = 'LIBSTOTEMBAR_SETTINGS_CHANGED'

BINDING_HEADER_LIBSTOTEMBAR = 'Libs - Totembar'
for i = 1, 12 do
	_G['BINDING_NAME_CLICK LibsTotembarButton' .. i .. ':LeftButton'] = 'Totem bar button ' .. i
end

local noop = function(_) end
Addon.logger = { debug = noop, info = noop, warning = noop, error = noop }

local defaults = {
	profile = {
		enabled = true,
		locked = true,
		position = { point = 'CENTER', relativePoint = 'CENTER', x = 0, y = -180 },
		scale = 1,
		buttonSize = 36,
		spacing = 3,
		groupSpacing = 10,
		orientation = 'HORIZONTAL',
		layout = 'auto',
		flyoutDirection = 'auto',
		showTimers = true,
		showAccent = true,
		showKeybinds = true,
		showCooldownNumbers = true,
		hideOutOfCombat = false,
		fadeOutOfCombat = 1,
		hidden = {},
		chosen = {},
	},
}

function Addon:OnInitialize()
	if LibAT and LibAT.Logger and LibAT.Logger.RegisterAddon then
		self.logger = LibAT.Logger.RegisterAddon(addonName)
	end

	-- Before the database exists, so Setup can spot a new install
	self:RegisterSetup()

	self.db = LibStub('AceDB-3.0'):New('LibsTotembarDB', defaults, true)
	self.db.RegisterCallback(self, 'OnProfileChanged', 'OnProfileUpdate')
	self.db.RegisterCallback(self, 'OnProfileCopied', 'OnProfileUpdate')
	self.db.RegisterCallback(self, 'OnProfileReset', 'OnProfileUpdate')

	self.combatQueue = {}
	self.queueOrder = {}

	self:RegisterChatCommand('totembar', 'SlashCommand')
	self:RegisterChatCommand('ltb', 'SlashCommand')
end

function Addon:OnEnable()
	self:RegisterEvent('PLAYER_REGEN_ENABLED', 'FlushCombatQueue')
end

function Addon:OnProfileUpdate()
	self:SendMessage(self.MSG_SETTINGS, 'profile')
end

---@return table
function Addon:Settings()
	return self.db.profile
end

---Runs fn now, or right after combat when protected frames are locked. A later call with the
---same key replaces a waiting one, so repeated requests during a fight collapse into one run.
---@param key string
---@param fn function
function Addon:RunOutOfCombat(key, fn)
	if not InCombatLockdown() then
		fn()
		return
	end
	if not self.combatQueue[key] then
		self.queueOrder[#self.queueOrder + 1] = key
	end
	self.combatQueue[key] = fn
end

function Addon:FlushCombatQueue()
	local order = self.queueOrder
	local queue = self.combatQueue
	self.queueOrder = {}
	self.combatQueue = {}
	for i = 1, #order do
		local fn = queue[order[i]]
		if fn then
			local ok, err = pcall(fn)
			if not ok then
				self.logger.error('Deferred update failed (' .. order[i] .. '): ' .. tostring(err))
			end
		end
	end
end

function Addon:SlashCommand(input)
	local cmd = input and strtrim(input):lower() or ''
	if cmd == 'unlock' or cmd == 'move' then
		self:SetLocked(false)
	elseif cmd == 'lock' then
		self:SetLocked(true)
	elseif cmd == 'reset' then
		self:GetModule('Bar'):ResetPosition()
	else
		self:GetModule('Options'):Open()
	end
end

---@param locked boolean
function Addon:SetLocked(locked)
	if not locked and InCombatLockdown() then
		UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT or "You can't do that while in combat", 1, 0.1, 0.1)
		return
	end
	self.db.profile.locked = locked
	self:SendMessage(self.MSG_SETTINGS, 'locked')
end
