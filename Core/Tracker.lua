local _, ns = ...
local Addon = ns.Addon
local Compat = Addon.Compat

-- Knows which of our spells is currently placed and for how long.
--
-- Totems, statues and similar objects live in the game's totem slots. On Retail those slots are
-- secret during combat, so a slot cannot always be read to learn which spell filled it. The
-- player's own casts are never secret, though, so a slot that changes right after we saw one of
-- our spells cast belongs to that spell. The countdown itself is drawn by the engine from the
-- slot's duration object, which works whether or not the slot is secret.
--
-- Traps and other ground effects that do not use totem slots run a timer from the cast.

---@class LibsTotembar.Tracker : AceModule, AceEvent-3.0
local Tracker = Addon:NewModule('Tracker')

local PAIR_WINDOW = 1 -- seconds between a cast and its slot update for them to belong together

---@class LibsTotembar.Timer
---@field key number Spell key
---@field slot number|nil Totem slot, for totem timers
---@field start number|nil Known when not secret
---@field duration number|nil Known when not secret
---@field secret boolean|nil Slot could not be read; draw through engine-side durations only
---@field seq number Higher is more recent

function Tracker:OnInitialize()
	self.slots = {} -- slot -> { key, start, duration, secret, seq }
	self.casts = {} -- spell key -> { key, start, duration, seq }
	self.active = {} -- spell key -> timer
	self.groupActive = {} -- group key -> timer
	self.seq = 0
end

function Tracker:OnEnable()
	self.Spells = Addon:GetModule('Spells')
	if not self.Spells.data then
		return
	end
	self:RegisterEvent('PLAYER_TOTEM_UPDATE', 'OnTotemUpdate')
	self:RegisterEvent('PLAYER_ENTERING_WORLD', 'ScanSlots')
	self:RegisterEvent('PLAYER_REGEN_ENABLED', 'ScanSlots')
	-- A unit event bound to the player only: other units' cast events can carry secret unit
	-- tokens on Retail, which cannot even be compared.
	self.castFrame = CreateFrame('Frame')
	self.castFrame:RegisterUnitEvent('UNIT_SPELLCAST_SUCCEEDED', 'player')
	self.castFrame:SetScript('OnEvent', function(_, _, _, _, spellID)
		self:OnSpellCast(spellID)
	end)
	self:RegisterMessage(Addon.MSG_SPELLS, 'ScanSlots')
	-- The combat log is closed to addons on Retail; on Classic it tells us when a trap springs.
	if Addon.IsClassic and self.Spells.classFile == 'HUNTER' then
		self:RegisterEvent('COMBAT_LOG_EVENT_UNFILTERED', 'OnCombatLog')
	end
	self.playerGUID = UnitGUID('player')
	self:ScanSlots()
end

local function Now()
	return GetTime()
end

function Tracker:NextSeq()
	self.seq = self.seq + 1
	return self.seq
end

----------------------------------------------------------------------------------------------------
-- Totem slots
----------------------------------------------------------------------------------------------------

---Which of our spells a readable slot holds.
---@param slot number
---@param info LibsTotembar.TotemInfo
---@return LibsTotembar.Spell|nil
function Tracker:IdentifySlot(slot, info)
	local Spells = self.Spells
	local spell = info.spellID and Spells:Identify(info.spellID)
	if spell then
		return spell
	end

	local candidates = {}
	for _, group in ipairs(Spells:GetGroups()) do
		if not group.slot or group.slot == slot then
			for _, s in ipairs(group.all) do
				if s.track == 'totem' then
					candidates[#candidates + 1] = s
				end
			end
		end
	end
	if info.icon then
		for _, s in ipairs(candidates) do
			if s.icon == info.icon then
				return s
			end
		end
	end
	if info.name then
		for _, s in ipairs(candidates) do
			if s.name and info.name:find(s.name, 1, true) == 1 then
				return s
			end
		end
	end
	local last = self.lastCast
	if last and Now() - last.time <= PAIR_WINDOW then
		return Spells.byKey[last.key]
	end
	return nil
end

---@param slot number
---@return boolean changed
function Tracker:ReadSlot(slot)
	local info = Compat.ReadTotem(slot)
	local current = self.slots[slot]

	if not info.secret then
		if not info.have then
			self.slots[slot] = nil
			return current ~= nil
		end
		if current and not current.secret and current.start == info.start and current.duration == info.duration then
			return false
		end
		local spell = self:IdentifySlot(slot, info)
		self.slots[slot] = {
			key = spell and spell.key,
			slot = slot,
			start = info.start,
			duration = info.duration,
			time = Now(),
			seq = self:NextSeq(),
		}
		if spell and self.lastCast and self.lastCast.key == spell.key then
			self.lastCast = nil
		end
		return true
	end

	-- Secret slot: pair it with a cast we just saw, or keep what we already knew. A totem that
	-- died stays paired, but its duration object is empty, so nothing is drawn for it.
	self.lastSecretSlot = { slot = slot, time = Now() }
	local last = self.lastCast
	if last and Now() - last.time <= PAIR_WINDOW then
		self.slots[slot] = { key = last.key, slot = slot, secret = true, time = Now(), seq = self:NextSeq() }
		return true
	end
	if current then
		current.secret = true
	end
	return true
end

function Tracker:OnTotemUpdate(_, slot)
	if slot and self:ReadSlot(slot) then
		self:Publish()
	end
end

function Tracker:ScanSlots()
	for slot = 1, Compat.NumTotemSlots() do
		self:ReadSlot(slot)
	end
	self:Publish()
end

----------------------------------------------------------------------------------------------------
-- Casts
----------------------------------------------------------------------------------------------------

---@param spellID number
function Tracker:OnSpellCast(spellID)
	local spell = self.Spells:Identify(spellID)
	if not spell then
		return
	end

	if spell.track == 'cast' and spell.duration then
		local start = Now()
		self.casts[spell.key] = { key = spell.key, start = start, duration = spell.duration, seq = self:NextSeq() }
		C_Timer.After(spell.duration + 0.05, function()
			local rec = self.casts[spell.key]
			if rec and rec.start == start then
				self.casts[spell.key] = nil
				self:Publish()
			end
		end)
		self:Publish()
	elseif spell.track == 'totem' then
		self.lastCast = { key = spell.key, time = Now() }
		-- The slot may have changed just before the cast event arrived.
		local recent = self.lastSecretSlot
		if recent and Now() - recent.time <= PAIR_WINDOW then
			self.lastSecretSlot = nil
			self.slots[recent.slot] = { key = spell.key, slot = recent.slot, secret = true, time = Now(), seq = self:NextSeq() }
			self:Publish()
			return
		end
		for _, rec in pairs(self.slots) do
			if not rec.key and rec.time and Now() - rec.time <= PAIR_WINDOW then
				rec.key = spell.key
				self:Publish()
				return
			end
		end
	end
end

function Tracker:OnCombatLog()
	local _, subEvent, _, sourceGUID, _, _, _, _, _, _, _, _, spellName = CombatLogGetCurrentEventInfo()
	if sourceGUID ~= self.playerGUID or not spellName then
		return
	end
	if subEvent ~= 'SPELL_AURA_APPLIED' and subEvent ~= 'SPELL_DAMAGE' and subEvent ~= 'SPELL_SUMMON' and subEvent ~= 'SPELL_CAST_SUCCESS' then
		return
	end
	-- "Freezing Trap Effect", "Immolation Trap Effect", "Frost Trap Aura": the armed trap sprang.
	for key in pairs(self.casts) do
		local spell = self.Spells.byKey[key]
		if spell and spell.name and spellName ~= spell.name and spellName:find(spell.name, 1, true) == 1 then
			self.casts[key] = nil
			self:Publish()
			return
		end
		if subEvent == 'SPELL_SUMMON' and spell and spellName == spell.name then
			self.casts[key] = nil
			self:Publish()
			return
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Results
----------------------------------------------------------------------------------------------------

function Tracker:Publish()
	local active, groupActive = {}, {}
	local now = Now()
	local Spells = self.Spells

	local function Consider(timer)
		local spell = timer.key and Spells.byKey[timer.key]
		if not spell then
			return
		end
		local existing = active[timer.key]
		if not existing or timer.seq > existing.seq then
			active[timer.key] = timer
		end
		local g = groupActive[spell.group.key]
		if not g or timer.seq > g.seq then
			groupActive[spell.group.key] = timer
		end
	end

	for _, rec in pairs(self.slots) do
		Consider(rec)
	end
	for key, rec in pairs(self.casts) do
		if rec.start + rec.duration > now then
			Consider(rec)
		else
			self.casts[key] = nil
		end
	end

	self.active = active
	self.groupActive = groupActive
	self:SendMessage(Addon.MSG_TIMERS)
end

---@param spellKey number
---@return LibsTotembar.Timer|nil
function Tracker:GetTimer(spellKey)
	return self.active[spellKey]
end

---@param groupKey string
---@return LibsTotembar.Timer|nil
function Tracker:GetGroupTimer(groupKey)
	return self.groupActive[groupKey]
end

---Everything a widget needs to draw a timer.
---@param timer LibsTotembar.Timer
---@return table|nil durationObject Engine duration (nil on clients without them)
---@return number|nil start Readable start time, when known
---@return number|nil length Readable length, when known
function Tracker:Resolve(timer)
	local durationObject
	if timer.slot then
		durationObject = Compat.TotemDuration(timer.slot)
	end
	if timer.start and timer.duration then
		if not durationObject then
			durationObject = Compat.MakeDuration(timer.start, timer.duration)
		end
		return durationObject, timer.start, timer.duration
	end
	return durationObject, nil, nil
end
