local _, ns = ...
local Addon = ns.Addon
local Compat = Addon.Compat

-- Turns the static spell table into what this character can actually cast right now, and tells
-- the bar when that changes (level up, new rank, talent swap, spec change).

---@class LibsTotembar.Spells : AceModule, AceEvent-3.0
local Spells = Addon:NewModule('Spells')

---@class LibsTotembar.Spell
---@field key number Base spell ID from the data table; used for saved settings
---@field id number The spell to show and query (highest rank or talent override)
---@field cast number|string Value for the secure button's `spell` attribute
---@field name string
---@field icon number|string
---@field track string 'totem'|'cast'|'none'
---@field duration number|nil
---@field group LibsTotembar.Group

---@class LibsTotembar.Group
---@field key string
---@field name string
---@field color number[]
---@field slot number|nil
---@field all LibsTotembar.Spell[] Every known spell, hidden ones included
---@field spells LibsTotembar.Spell[] Known and not hidden

function Spells:OnInitialize()
	self.groups = {}
	self.byKey = {}
	self.byName = {}
	self.byID = {}
	self.signature = ''
	local _, classFile = UnitClass('player')
	self.classFile = classFile
	self.data = Addon:GetClassGroups(classFile)
end

function Spells:OnEnable()
	if not self.data then
		Addon.logger.info('No totem, trap or statue spells for ' .. tostring(self.classFile) .. ' on this client.')
		return
	end
	local events = {
		'SPELLS_CHANGED',
		'PLAYER_ENTERING_WORLD',
		'LEARNED_SPELL_IN_TAB',
		'LEARNED_SPELL_IN_SKILL_LINE',
		'PLAYER_TALENT_UPDATE',
		'PLAYER_SPECIALIZATION_CHANGED',
		'TRAIT_CONFIG_UPDATED',
	}
	for _, event in ipairs(events) do
		pcall(self.RegisterEvent, self, event, 'QueueRefresh')
	end
	self:RegisterMessage(Addon.MSG_SETTINGS, 'OnSettingsChanged')
	self:Refresh()
end

function Spells:OnSettingsChanged(_, what)
	if what == 'hidden' or what == 'profile' then
		self:Refresh(true)
	end
end

-- SPELLS_CHANGED can fire many times in one frame; rebuild once.
function Spells:QueueRefresh()
	if self.pending then
		return
	end
	self.pending = true
	C_Timer.After(0.1, function()
		self.pending = false
		self:Refresh()
	end)
end

---@param entry table
---@param bookByName table<string, number>
---@return number|nil id
---@return number|string|nil cast
local function Resolve(entry, bookByName)
	local baseName = Compat.SpellName(entry.id)
	if not baseName then
		return nil
	end
	if Addon.IsRetail then
		if not Compat.IsKnown(entry.id) then
			return nil
		end
		local id = Compat.OverrideID(entry.id)
		return id, id
	end
	local best = bookByName[baseName]
	if best then
		return best, baseName
	end
	if IsPlayerSpell and IsPlayerSpell(entry.id) then
		return entry.id, baseName
	end
	return nil
end

local function GroupColor(color)
	if color == 'class' then
		local _, classFile = UnitClass('player')
		local c = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[classFile]
		if c then
			return { c.r, c.g, c.b }
		end
		return { 1, 1, 1 }
	end
	return color
end

---@param force? boolean Announce even if nothing the bar shows changed
function Spells:Refresh(force)
	if not self.data then
		return
	end
	local hidden = Addon:Settings().hidden
	local bookByName = Addon.IsClassic and Compat.ScanSpellBook() or {}
	local groups, byKey, byName, byID = {}, {}, {}, {}
	local seen = {}
	local sig = {}

	for _, def in ipairs(self.data) do
		local group = {
			key = def.key,
			name = def.name,
			color = GroupColor(def.color),
			slot = def.slot,
			all = {},
			spells = {},
		}
		for _, entry in ipairs(def.spells) do
			local id, cast = Resolve(entry, bookByName)
			if id and not seen[id] then
				seen[id] = true
				local spell = {
					key = entry.id,
					id = id,
					cast = cast,
					name = Compat.SpellName(id) or Compat.SpellName(entry.id),
					icon = Compat.SpellIcon(id) or Compat.SpellIcon(entry.id) or 134400,
					track = entry.track or 'totem',
					duration = entry.duration,
					group = group,
				}
				group.all[#group.all + 1] = spell
				byKey[entry.id] = spell
				byID[id] = spell
				byID[entry.id] = spell
				if spell.name then
					byName[spell.name] = spell
				end
				local baseName = Compat.SpellName(entry.id)
				if baseName then
					byName[baseName] = spell
				end
				if not hidden[entry.id] then
					group.spells[#group.spells + 1] = spell
					sig[#sig + 1] = tostring(id) .. ':' .. tostring(cast)
				end
			end
		end
		if #group.all > 0 then
			groups[#groups + 1] = group
			sig[#sig + 1] = '|'
		end
	end

	self.groups = groups
	self.byKey = byKey
	self.byName = byName
	self.byID = byID

	local signature = table.concat(sig, ',')
	if force or signature ~= self.signature then
		self.signature = signature
		Addon.logger.debug('Known spells: ' .. signature)
		self:SendMessage(Addon.MSG_SPELLS)
	end
end

---Finds our spell for any spell ID the game reports: a Classic rank, a talent override or the
---base spell. Classic ranks are matched by name.
---@param spellID number
---@return LibsTotembar.Spell|nil
function Spells:Identify(spellID)
	if not spellID or not Compat.CanAccess(spellID) then
		return nil
	end
	local spell = self.byID[spellID]
	if spell then
		return spell
	end
	local name = Compat.SpellName(spellID)
	return name and self.byName[name] or nil
end

---@return LibsTotembar.Group[]
function Spells:GetGroups()
	return self.groups
end
