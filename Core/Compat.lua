local _, ns = ...
local Addon = ns.Addon

-- One place for every API that differs between Retail and the Classic clients, and for the
-- Retail 12.x secret-value rules. Nothing outside this file calls a spell, cooldown or totem
-- API directly, so the rest of the addon never has to ask which game it is running in.

---@class LibsTotembar.Compat
local Compat = {}
Addon.Compat = Compat

local C_Spell = C_Spell
local C_SpellBook = C_SpellBook
local C_DurationUtil = C_DurationUtil
local C_StringUtil = C_StringUtil
local canaccessvalue = canaccessvalue

---True when the value is hidden from addon code (Retail 12.x combat restrictions).
---@param value any
---@return boolean
function Compat.IsSecret(value)
	return issecretvalue and issecretvalue(value) or false
end

---True when addon code may compare or do math on the value (always true before 12.0).
---@param value any
---@return boolean
function Compat.CanAccess(value)
	if canaccessvalue then
		return canaccessvalue(value) and true or false
	end
	return true
end

----------------------------------------------------------------------------------------------------
-- Spell info
----------------------------------------------------------------------------------------------------

---@param spell number|string
---@return string|nil
function Compat.SpellName(spell)
	if C_Spell and C_Spell.GetSpellName then
		return C_Spell.GetSpellName(spell)
	end
	return (GetSpellInfo(spell))
end

---@param spell number|string
---@return number|string|nil
function Compat.SpellIcon(spell)
	if C_Spell and C_Spell.GetSpellTexture then
		return C_Spell.GetSpellTexture(spell)
	end
	return GetSpellTexture and GetSpellTexture(spell) or select(3, GetSpellInfo(spell))
end

---The spell a talent or effect currently replaces this one with (Retail), or the spell itself.
---@param spellID number
---@return number
function Compat.OverrideID(spellID)
	local override
	if C_Spell and C_Spell.GetOverrideSpell then
		override = C_Spell.GetOverrideSpell(spellID)
	elseif C_SpellBook and C_SpellBook.FindSpellOverrideByID then
		override = C_SpellBook.FindSpellOverrideByID(spellID)
	end
	if override and override ~= 0 and Compat.CanAccess(override) then
		return override
	end
	return spellID
end

---Retail: whether the player has learned the spell (or a talent that replaces it).
---@param spellID number
---@return boolean
function Compat.IsKnown(spellID)
	if C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(spellID) then
		return true
	end
	if IsPlayerSpell and IsPlayerSpell(spellID) then
		return true
	end
	if IsSpellKnownOrOverridesKnown and IsSpellKnownOrOverridesKnown(spellID) then
		return true
	end
	return false
end

---Every learned spell in the player's spellbook: name -> highest rank spell ID. Classic clients
---list each rank as its own entry in ascending order, so the last one seen is the best rank.
---@return table<string, number> byName
---@return table<number, boolean> byID
function Compat.ScanSpellBook()
	local byName, byID = {}, {}

	local function Add(spellID, name)
		if spellID and name then
			byName[name] = spellID
			byID[spellID] = true
		end
	end

	local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
	local spellType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
	if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookItemInfo and bank and spellType then
		for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
			local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo(line)
			if lineInfo and lineInfo.numSpellBookItems then
				local offset = lineInfo.itemIndexOffset or 0
				for slot = offset + 1, offset + lineInfo.numSpellBookItems do
					local item = C_SpellBook.GetSpellBookItemInfo(slot, bank)
					if item and item.itemType == spellType and not item.isPassive then
						Add(item.spellID, item.name)
					end
				end
			end
		end
	elseif GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemInfo then
		local book = BOOKTYPE_SPELL or 'spell'
		for tab = 1, GetNumSpellTabs() do
			local _, _, offset, numSpells = GetSpellTabInfo(tab)
			for slot = (offset or 0) + 1, (offset or 0) + (numSpells or 0) do
				local kind, spellID = GetSpellBookItemInfo(slot, book)
				if kind == 'SPELL' and spellID then
					Add(spellID, GetSpellBookItemName and GetSpellBookItemName(slot, book) or Compat.SpellName(spellID))
				end
			end
		end
	end
	return byName, byID
end

----------------------------------------------------------------------------------------------------
-- Usability and cooldowns
----------------------------------------------------------------------------------------------------

---@param spell number|string
---@return boolean usable
---@return boolean noPower
function Compat.SpellUsable(spell)
	local usable, noPower
	if C_Spell and C_Spell.IsSpellUsable then
		usable, noPower = C_Spell.IsSpellUsable(spell)
	elseif IsUsableSpell then
		usable, noPower = IsUsableSpell(spell)
	else
		return true, false
	end
	if not Compat.CanAccess(usable) or not Compat.CanAccess(noPower) then
		return true, false
	end
	return usable and true or false, noPower and true or false
end

local useDurationCooldowns = C_Spell and C_Spell.GetSpellCooldownDuration and C_Spell.GetSpellCooldown and true or false

local function ClearCooldown(cooldown)
	if cooldown.Clear then
		cooldown:Clear()
	else
		CooldownFrame_Clear(cooldown)
	end
end

---Draws the spell's cooldown on a Cooldown frame. On Retail the start and length can be secret,
---so they travel inside a duration object that the engine reads for us.
---@param cooldown Cooldown
---@param spell number|string
function Compat.ApplySpellCooldown(cooldown, spell)
	if useDurationCooldowns and cooldown.SetCooldownFromDurationObject then
		local info = C_Spell.GetSpellCooldown(spell)
		if info and info.isActive ~= nil then
			if info.isActive then
				local duration = C_Spell.GetSpellCooldownDuration(spell)
				if duration then
					cooldown:SetCooldownFromDurationObject(duration)
					return
				end
			end
			ClearCooldown(cooldown)
			return
		end
	end

	local start, length, enabled, modRate
	if C_Spell and C_Spell.GetSpellCooldown then
		local info = C_Spell.GetSpellCooldown(spell)
		if info then
			start, length, enabled, modRate = info.startTime, info.duration, info.isEnabled, info.modRate
		end
	elseif GetSpellCooldown then
		start, length, enabled, modRate = GetSpellCooldown(spell)
	end
	if start and length and Compat.CanAccess(start) and Compat.CanAccess(length) and start > 0 and length > 0 then
		CooldownFrame_Set(cooldown, start, length, enabled ~= false and enabled ~= 0, false, modRate)
	else
		ClearCooldown(cooldown)
	end
end
Compat.ClearCooldown = ClearCooldown

----------------------------------------------------------------------------------------------------
-- Durations (engine-side countdowns)
----------------------------------------------------------------------------------------------------

Compat.HasDurationObjects = C_DurationUtil and C_DurationUtil.CreateDuration and true or false
Compat.HasTextBinding = C_DurationUtil and C_DurationUtil.CreateDurationTextBinding and C_StringUtil and C_StringUtil.CreateSecondsFormatter and true or false

---A duration object for a span we measured ourselves (never secret).
---@param start number
---@param length number
---@return table|nil
function Compat.MakeDuration(start, length)
	if not Compat.HasDurationObjects then
		return nil
	end
	local duration = C_DurationUtil.CreateDuration()
	if not duration or not duration.SetTimeFromStart then
		return nil
	end
	duration:SetTimeFromStart(start, length)
	return duration
end

local function CountdownFormatter()
	local formatter = C_StringUtil.CreateSecondsFormatter()
	if formatter and formatter.SetDefaultAbbreviation and Enum.SecondsFormatterAbbreviation then
		formatter:SetDefaultAbbreviation(Enum.SecondsFormatterAbbreviation.OneLetter)
	end
	if formatter and formatter.SetStripIntervalWhitespace and Enum.SecondsFormatterIntervalWhitespace then
		formatter:SetStripIntervalWhitespace(Enum.SecondsFormatterIntervalWhitespace.Strip)
	end
	return formatter
end

---Lets the engine write a live countdown into the font string. nil when unsupported.
---@param fontString FontString
---@return table|nil
function Compat.CreateTextBinding(fontString)
	if not Compat.HasTextBinding then
		return nil
	end
	local binding = C_DurationUtil.CreateDurationTextBinding()
	binding:SetFontString(fontString)
	local formatter = CountdownFormatter()
	if formatter then
		binding:SetFormatter(formatter)
	end
	binding:SetExpiredText('')
	binding:SetZeroDurationText('')
	binding:SetEnabled(true)
	return binding
end

---Short countdown text for our own timers: 1:05, 42, 4.2
---@param remaining number
---@return string
function Compat.FormatRemaining(remaining)
	if remaining >= 60 then
		return format('%d:%02d', floor(remaining / 60), floor(remaining % 60))
	elseif remaining >= 5 then
		return format('%d', floor(remaining + 0.5))
	end
	return format('%.1f', remaining)
end

----------------------------------------------------------------------------------------------------
-- Totem slots
----------------------------------------------------------------------------------------------------

---@return number
function Compat.NumTotemSlots()
	if GetNumTotemSlots then
		local count = GetNumTotemSlots()
		if count and count > 0 then
			return count
		end
	end
	return MAX_TOTEMS or 4
end

---@class LibsTotembar.TotemInfo
---@field secret boolean The slot can only be shown through engine-side calls right now
---@field have boolean|nil
---@field name string|nil
---@field start number|nil
---@field duration number|nil
---@field icon number|string|nil
---@field spellID number|nil

local scratch = {}

---Reads a totem slot. When Retail hides the slot during combat, only `secret` is set and the
---caller must fall back to engine-side displays.
---@param slot number
---@return LibsTotembar.TotemInfo
function Compat.ReadTotem(slot)
	wipe(scratch)
	if C_Secrets and C_Secrets.ShouldTotemSlotBeSecret then
		local isSecret = C_Secrets.ShouldTotemSlotBeSecret(slot)
		if not Compat.CanAccess(isSecret) or isSecret then
			scratch.secret = true
			return scratch
		end
	end
	local have, name, start, duration, icon, _, spellID = GetTotemInfo(slot)
	if not (Compat.CanAccess(have) and Compat.CanAccess(start) and Compat.CanAccess(duration)) then
		scratch.secret = true
		return scratch
	end
	scratch.secret = false
	scratch.have = have and duration and duration > 0 or false
	scratch.name = Compat.CanAccess(name) and name or nil
	scratch.start = start
	scratch.duration = duration
	scratch.icon = Compat.CanAccess(icon) and icon or nil
	scratch.spellID = spellID and Compat.CanAccess(spellID) and spellID or nil
	return scratch
end

---Engine-side duration for a totem slot (safe while the slot is secret). nil when unsupported.
---@param slot number
---@return table|nil
function Compat.TotemDuration(slot)
	if GetTotemDuration then
		return GetTotemDuration(slot)
	end
	return nil
end
