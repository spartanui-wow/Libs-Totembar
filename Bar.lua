local addonName, root = ...
---@class LibsTotembar
local LibsTotembar = LibStub('AceAddon-3.0'):GetAddon(addonName)
local Log = LibsTotembar.Log

-- Constants
local BUTTON_SIZE = 36
local BUTTON_SPACING = 2
local MAX_BUTTONS = 10

-- Module variables
local barFrame ---@type Frame?
local totemButtons = {} ---@type table<number, LibsTotembar.ActionButton>

-- Bar management functionality
local BarManager = {}

---Create the main bar frame
function BarManager:CreateBarFrame()
	if barFrame then
		return barFrame
	end

	local db = LibsTotembar.db.profile
	local frameWidth = BUTTON_SIZE * db.maxButtons + BUTTON_SPACING * (db.maxButtons - 1)

	barFrame = CreateFrame('Frame', 'LibsTotembarFrame', UIParent, 'BackdropTemplate')
	barFrame:SetSize(frameWidth, BUTTON_SIZE)
	barFrame:SetScale(db.layout.scale)

	-- Add backdrop for visibility
	barFrame:SetBackdrop({
		bgFile = 'Interface\\Tooltips\\UI-Tooltip-Background',
		edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border',
		tile = true,
		tileSize = 16,
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	barFrame:SetBackdropColor(0, 0, 0, 0.8)
	barFrame:SetBackdropBorderColor(0.8, 0.8, 0.8, 1)

	-- Set position
	barFrame:SetPoint(db.position.anchor, UIParent, db.position.anchor, db.position.x, db.position.y)

	-- Make it movable (if not locked)
	if not db.behavior.lockPosition then
		barFrame:EnableMouse(true)
		barFrame:SetMovable(true)
		barFrame:RegisterForDrag('LeftButton')
		barFrame:SetScript('OnDragStart', function(self)
			self:StartMoving()
		end)
		barFrame:SetScript('OnDragStop', function(self)
			self:StopMovingOrSizing()
			-- Save position
			local point, _, _, x, y = self:GetPoint()
			LibsTotembar.db.profile.position.anchor = point
			LibsTotembar.db.profile.position.x = x
			LibsTotembar.db.profile.position.y = y
		end)
	end

	-- Create buttons
	for i = 1, MAX_BUTTONS do
		totemButtons[i] = LibsTotembar.ActionButton.New(i, barFrame)

		-- Position buttons
		if i == 1 then
			totemButtons[i]:SetPoint('LEFT', barFrame, 'LEFT', 0, 0)
		else
			totemButtons[i]:SetPoint('LEFT', totemButtons[i - 1], 'RIGHT', BUTTON_SPACING, 0)
		end
	end

	-- Only enable test mode for supported classes in development
	if LibsTotembar.playerClass == 'SHAMAN' or LibsTotembar.playerClass == 'HUNTER' then
		self:EnableTestMode()
	end

	-- Let UpdateBarVisibility determine if bar should show
	self:UpdateBarVisibility()

	return barFrame
end

---Update bar visibility based on settings and active abilities
function BarManager:UpdateBarVisibility()
	if not barFrame then
		return
	end

	local db = LibsTotembar.db.profile
	if not db.enabled then
		barFrame:Hide()
		return
	end

	-- Apply combat filters
	local inCombat = InCombatLockdown()
	if (inCombat and db.filters.hideInCombat) or (not inCombat and db.filters.hideOutOfCombat) then
		barFrame:Hide()
		return
	end

	if db.hideWhenEmpty then
		-- Check if any buttons have active content
		local hasContent = false
		for i = 1, db.maxButtons do
			if totemButtons[i] and totemButtons[i].spellId > 0 then
				hasContent = true
				break
			end
		end

		if hasContent then
			barFrame:Show()
		else
			barFrame:Hide()
		end
	else
		barFrame:Show()
	end
end

---Update bar layout and positioning
function BarManager:UpdateBarLayout()
	if not barFrame then
		return
	end

	local db = LibsTotembar.db.profile

	-- Update frame size based on maxButtons
	local frameWidth = BUTTON_SIZE * db.maxButtons + BUTTON_SPACING * (db.maxButtons - 1)
	barFrame:SetSize(frameWidth, BUTTON_SIZE)

	-- Update scale
	barFrame:SetScale(db.layout.scale)

	-- Update movability
	if db.behavior.lockPosition then
		barFrame:SetMovable(false)
		barFrame:EnableMouse(false)
	else
		barFrame:SetMovable(true)
		barFrame:EnableMouse(true)
	end
end

---Update all button appearances
function BarManager:UpdateButtonAppearance()
	for i = 1, MAX_BUTTONS do
		if totemButtons[i] then
			totemButtons[i]:UpdateAppearance()
		end
	end
end

---Get button by index
---@param index number
---@return LibsTotembar.ActionButton?
function BarManager:GetButton(index)
	return totemButtons[index]
end

---Get all buttons
---@return table<number, LibsTotembar.ActionButton>
function BarManager:GetAllButtons()
	return totemButtons
end

---Update frame on regular timer (called from main addon timer)
function BarManager:UpdateFrame()
	-- Update all button timers
	for i = 1, LibsTotembar.db.profile.maxButtons do
		if totemButtons[i] then
			LibsTotembar.ActionButton.UpdateTimer(totemButtons[i])
		end
	end

	-- Update bar visibility
	self:UpdateBarVisibility()
end

---Timer callback for spell expiration
---@param buttonIndex number
---@param spellId number
function BarManager:ExpireSpell(buttonIndex, spellId)
	Log('Spell expired: ' .. spellId .. ' from button ' .. buttonIndex, 'debug')
	if totemButtons[buttonIndex] then
		LibsTotembar.ActionButton.ClearSpell(totemButtons[buttonIndex])
	end
	self:UpdateBarVisibility()
end

---Handle totem slot updates (Shaman specific)
---@param slot number
function BarManager:UpdateTotemSlot(slot)
	if LibsTotembar.playerClass ~= 'SHAMAN' or not slot or slot > MAX_BUTTONS then
		return
	end

	local haveTotem, name, startTime, duration, icon = GetTotemInfo(slot)
	local button = totemButtons[slot] ---@type LibsTotembar.ActionButton

	if button then
		if haveTotem and name then
			-- Find spell data for this totem
			local availableSpells = LibsTotembar:GetAvailableSpells()
			local spellData = nil

			for spellId, spell in pairs(availableSpells) do
				if spell.name == name and spell.enabled then
					spellData = spell
					break
				end
			end

			if spellData then
				button:UpdateSpell(spellData)
				Log('Totem updated in slot ' .. slot .. ': ' .. name, 'debug')
			end
		else
			LibsTotembar.ActionButton.ClearSpell(button)
			Log('Totem cleared from slot ' .. slot, 'debug')
		end
	end

	self:UpdateBarVisibility()
end

---Update all totem slots (Shaman specific)
function BarManager:UpdateAllTotems()
	if LibsTotembar.playerClass == 'SHAMAN' then
		for i = 1, 4 do -- Shaman has 4 totem slots
			self:UpdateTotemSlot(i)
		end
	end
end

---Handle spell cast events for ability tracking
---@param unit string
---@param spellName string
---@param spellId number
function BarManager:HandleSpellCast(unit, spellName, spellId)
	if unit ~= 'player' then
		return
	end

	local availableSpells = LibsTotembar:GetAvailableSpells()
	local spellData = availableSpells[spellId]

	if spellData and spellData.enabled then
		-- Find an available button (prioritize empty buttons)
		local button ---@type LibsTotembar.ActionButton?

		-- For slotted spells (totems), use specific slot
		if spellData.slot then
			button = totemButtons[spellData.slot]
		else
			-- Find first empty button
			for i = 1, LibsTotembar.db.profile.maxButtons do
				if totemButtons[i] and totemButtons[i].spellId == 0 then
					button = totemButtons[i]
					break
				end
			end
		end

		if button then
			button:UpdateSpell(spellData)
			Log('Ability cast: ' .. spellName, 'debug')
			self:UpdateBarVisibility()
		else
			Log('No available button for spell: ' .. spellName, 'warning')
		end
	end
end

---Test mode - show some dummy buttons
function BarManager:EnableTestMode()
	Log('EnableTestMode starting for class: ' .. (LibsTotembar.playerClass or 'unknown'), 'debug')

	local testSpells = {}
	if LibsTotembar.playerClass == 'SHAMAN' then
		testSpells = { 2484, 8143, 5394, 8512 } -- Earthbind, Tremor, Healing Stream, Windfury
		Log('Using SHAMAN test spells', 'debug')
	elseif LibsTotembar.playerClass == 'HUNTER' then
		testSpells = { 187650, 187698, 162488, 1543 } -- Freezing Trap, Tar Trap, Steel Trap, Flare
		Log('Using HUNTER test spells', 'debug')
	else
		-- No test spells for unsupported classes
		testSpells = {}
		Log('No test spells for unsupported class: ' .. (LibsTotembar.playerClass or 'unknown'), 'debug')
	end

	Log('Testing ' .. #testSpells .. ' spells', 'debug')

	for i, spellId in ipairs(testSpells) do
		Log('Processing spell ' .. i .. ': ' .. spellId, 'debug')

		if totemButtons[i] then
			Log('Button ' .. i .. ' exists', 'debug')
			local spellInfo = C_Spell.GetSpellInfo(spellId)
			local spellName = spellInfo and spellInfo.name
			local spellIcon = spellInfo and spellInfo.iconID
			Log('Spell details for ' .. spellId .. ': name=' .. (spellName or 'nil') .. ', icon=' .. (spellIcon or 'nil'), 'debug')

			if spellName then
				local testData = {
					id = spellId,
					name = spellName,
					duration = 30,
					category = 'Test',
					icon = spellIcon,
				}
				Log('Updating button ' .. i .. ' with spell: ' .. spellName, 'debug')
				totemButtons[i]:UpdateSpell(testData)
			else
				Log('No spell name found for spell ID: ' .. spellId, 'warning')
			end
		else
			Log('Button ' .. i .. ' does not exist!', 'warning')
		end
	end

	self:UpdateBarVisibility()
	Log('Test mode activated with ' .. #testSpells .. ' spells', 'info')
end

---Clear all buttons (disable test mode)
function BarManager:ClearAllButtons()
	for i = 1, MAX_BUTTONS do
		if totemButtons[i] then
			LibsTotembar.ActionButton.ClearSpell(totemButtons[i])
		end
	end
	self:UpdateBarVisibility()
end

-- Export the BarManager to the main addon
LibsTotembar.BarManager = BarManager

-- Also export individual functions for backward compatibility
LibsTotembar.CreateBarFrame = function(self)
	return BarManager:CreateBarFrame()
end
LibsTotembar.UpdateBarVisibility = function(self)
	return BarManager:UpdateBarVisibility()
end
LibsTotembar.UpdateTotemSlot = function(self, slot)
	return BarManager:UpdateTotemSlot(slot)
end
LibsTotembar.HandleSpellCast = function(self, unit, spellName, spellId)
	return BarManager:HandleSpellCast(unit, spellName, spellId)
end
