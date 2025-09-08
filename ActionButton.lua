local addonName, root = ...
---@class LibsTotembar
local LibsTotembar = LibStub('AceAddon-3.0'):GetAddon(addonName)
local Log = LibsTotembar.Log

-- Constants
local BUTTON_SIZE = 36

---@class LibsTotembar.ActionButton : Button, BackdropTemplate
---@field id string
---@field slotIndex number
---@field spellId number
---@field spellData LibsTotembar.SpellData?
---@field timer LibsTotembar.Timer?
---@field cooldownFrame Cooldown
---@field icon Texture
---@field countText FontString
---@field glowFrame Frame
---@field state LibsTotembar.ButtonState
---@field timerId string?

---@class LibsTotembar.ButtonState
---@field enabled boolean
---@field usable boolean
---@field inRange boolean
---@field charges number
---@field cooldownRemaining number
---@field onGlobalCooldown boolean
---@field spellKnown boolean

---ActionButton class for advanced button functionality
local ActionButton = {}
ActionButton.__index = ActionButton

---Create a new ActionButton instance
---@param index number
---@param parent Frame
---@return LibsTotembar.ActionButton
function ActionButton.New(index, parent)
	local button = CreateFrame('Button', 'LibsTotembar_Button' .. index, parent, 'BackdropTemplate')

	-- Initialize button properties
	button.id = 'button_' .. index
	button.slotIndex = index
	button.spellId = 0

	-- Initialize state
	button.state = {
		enabled = true,
		usable = false,
		inRange = true,
		charges = 0,
		cooldownRemaining = 0,
		onGlobalCooldown = false,
		spellKnown = false
	}

	button:SetWidth(BUTTON_SIZE)
	button:SetHeight(BUTTON_SIZE)
	ActionButton.SetupVisuals(button)
	ActionButton.SetupEvents(button)
	ActionButton.SetupSecureAttributes(button)

	return button
end

---Setup visual components
function ActionButton.SetupVisuals(button)
	-- Set up backdrop similar to action buttons
	button:SetBackdrop({
		bgFile = 'Interface\\Buttons\\UI-Quickslot2',
		edgeFile = 'Interface\\Buttons\\UI-Quickslot-Depress',
		tile = false,
		edgeSize = 2,
		insets = {left = 2, right = 2, top = 2, bottom = 2}
	})
	button:SetBackdropColor(1, 1, 1, 1)
	button:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

	-- Create icon texture
	button.icon = button:CreateTexture(nil, 'ARTWORK')
	button.icon:SetPoint('TOPLEFT', button, 'TOPLEFT', 2, -2)
	button.icon:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', -2, 2)
	button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	-- Create cooldown frame
	button.cooldownFrame = CreateFrame('Cooldown', nil, button, 'CooldownFrameTemplate')
	button.cooldownFrame:SetAllPoints()
	button.cooldownFrame:SetDrawEdge(false)
	button.cooldownFrame:SetDrawSwipe(true)

	-- Create count text (for timer display)
	button.countText = button:CreateFontString(nil, 'OVERLAY', 'NumberFontNormal')
	button.countText:SetPoint('BOTTOMRIGHT', -2, 2)
	button.countText:SetTextColor(1, 1, 1, 1)
	button.countText:SetJustifyH('RIGHT')

	-- Create border highlight
	button.border = button:CreateTexture(nil, 'OVERLAY')
	button.border:SetAllPoints()
	button.border:SetTexture('Interface\\Buttons\\UI-ActionButton-Border')
	button.border:SetBlendMode('ADD')
	button.border:Hide()

	-- Hide button initially (only show when it has content)
	button:Hide()
end

---Setup event handlers
function ActionButton.SetupEvents(button)
	button:SetScript(
		'OnEnter',
		function(self)
			if LibsTotembar.db.profile.behavior.showTooltips and self.spellId and self.spellId > 0 then
				GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
				GameTooltip:SetSpellByID(self.spellId)

				-- Add timer info if available
				if self.timer then
					local remaining = LibsTotembar:TimeLeft(self.timerId)
					if remaining > 0 then
						GameTooltip:AddLine(string.format('Time remaining: %.1fs', remaining), 1, 1, 1)
					end
				end

				-- Add category info
				if self.spellData then
					GameTooltip:AddLine('Category: ' .. (self.spellData.category or 'Unknown'), 0.7, 0.7, 0.7)
					if self.spellData.customAdded then
						GameTooltip:AddLine('Custom spell', 0.5, 0.5, 1)
					end
				end

				GameTooltip:Show()
			end
		end
	)

	button:SetScript(
		'OnLeave',
		function()
			GameTooltip:Hide()
		end
	)
end

---Setup secure attributes for clicking
function ActionButton.SetupSecureAttributes(button)
	local db = LibsTotembar.db.profile
	if db.behavior.clickToDestroy then
		if LibsTotembar.playerClass == 'SHAMAN' and button.slotIndex <= 4 then -- Totem slots
			button:SetAttribute('type', 'destroytotem')
			button:SetAttribute('totem-slot', button.slotIndex)
		end
	end
end

---Update button with spell information
---@param spellData LibsTotembar.SpellData
function ActionButton:UpdateSpell(spellData)
	Log('UpdateSpell called for button ' .. (self.slotIndex or 'unknown') .. ' with spell: ' .. (spellData.name or spellData.id), 'debug')
	
	self.spellId = spellData.id
	self.spellData = spellData

	-- Get spell info
	local spellInfo = C_Spell.GetSpellInfo(spellData.id)
	local spellName = spellInfo and spellInfo.name
	local spellIcon = spellInfo and spellInfo.iconID
	Log('C_Spell.GetSpellInfo returned: name=' .. (spellName or 'nil') .. ', icon=' .. (spellIcon or 'nil'), 'debug')

	if spellName then
		self.icon:SetTexture(spellIcon or spellData.icon)
		self:Show()
		Log('Button ' .. self.slotIndex .. ' shown with spell: ' .. spellName, 'debug')

		-- Start timer
		local timerId = LibsTotembar:ScheduleTimer('ExpireSpell', spellData.duration, self.slotIndex, spellData.id)
		self.timerId = timerId

		-- Create timer data
		self.timer = {
			spellId = spellData.id,
			duration = spellData.duration,
			startTime = GetTime(),
			endTime = GetTime() + spellData.duration,
			category = spellData.category,
			slotId = spellData.slot,
			timerId = timerId,
			metadata = {}
		}

		LibsTotembar.activeTimers[timerId] = self.timer

		-- Start cooldown display
		self.cooldownFrame:SetCooldown(GetTime(), spellData.duration)

		Log('Spell active: ' .. spellName .. ' for ' .. spellData.duration .. 's', 'debug')
	else
		ActionButton.ClearSpell(self)
	end
end

---Clear spell from button
function ActionButton.ClearSpell(button)
	if button.timerId then
		LibsTotembar:CancelTimer(button.timerId)
		LibsTotembar.activeTimers[button.timerId] = nil
		button.timerId = nil
	end

	button.spellId = 0
	button.spellData = nil
	button.icon:SetTexture(nil)
	button.cooldownFrame:Clear()
	button.countText:SetText('')
	button.timer = nil
	button:Hide()
end

---Update timer display
function ActionButton.UpdateTimer(button)
	if button.timer and button.timerId then
		local remaining = LibsTotembar:TimeLeft(button.timerId)
		if remaining > 0 then
			local db = LibsTotembar.db.profile
			if db.appearance.showCooldownText then
				if remaining >= 60 then
					button.countText:SetText(string.format('%.1fm', remaining / 60))
				else
					button.countText:SetText(string.format('%.0fs', remaining))
				end
			end
		else
			-- Timer expired
			ActionButton.ClearSpell(button)
		end
	else
		button.countText:SetText('')
	end
end

---Update button appearance based on settings
function ActionButton:UpdateAppearance()
	local db = LibsTotembar.db.profile

	if db.appearance.showBackground then
		self:SetBackdropColor(unpack(db.appearance.backgroundColor))
		self:SetBackdropBorderColor(unpack(db.appearance.borderColor))
	else
		self:SetBackdropColor(0, 0, 0, 0)
		self:SetBackdropBorderColor(0, 0, 0, 0)
	end
end

-- Export the ActionButton class to the main addon
LibsTotembar.ActionButton = ActionButton
