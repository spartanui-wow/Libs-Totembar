local _, ns = ...
local Addon = ns.Addon

---Save a bar setting and let the bar redraw
---@param key string
---@param value any
local function SetSetting(key, value)
	Addon:Settings()[key] = value
	Addon:SendMessage(Addon.MSG_SETTINGS, key)
end

---Register the first-run setup with Libs-AddonTools. Must run before the database is created, so
---a new install can be told apart from a player who used the addon before.
function Addon:RegisterSetup()
	if not LibAT or not LibAT.Setup then
		return
	end

	local reg = LibAT.Setup:Register('libs-totembar', {
		name = "Lib's Totembar",
		icon = 'Interface\\AddOns\\Libs-Totembar\\Logo-Icon',
		summary = 'One click places your totems, traps and statues, with a timer for each.',
		priority = 90,
		isExistingUser = function()
			return type(LibsTotembarDB) == 'table' and next(LibsTotembarDB) ~= nil
		end,
		optionsCommand = '/totembar',
	})
	if not reg then
		return
	end

	-- Only classes with totems, traps or statues are asked; the addon waits for one of those.
	local function HasSpells()
		local _, classFile = UnitClass('player')
		return Addon:GetClassGroups(classFile) ~= nil
	end

	reg:AddStep({
		id = 'visibility',
		kind = 'choice',
		name = 'Your bar',
		title = 'When should the bar show?',
		text = 'Move the bar with /totembar unlock.',
		hidden = function()
			return not HasSpells()
		end,
		extra = {
			title = 'How should the buttons line up?',
			choices = {
				{ value = 'HORIZONTAL', title = 'In a row' },
				{ value = 'VERTICAL', title = 'In a column' },
			},
			get = function()
				return Addon:Settings().orientation
			end,
			set = function(value)
				SetSetting('orientation', value)
			end,
		},
		choices = {
			{ value = 'always', title = 'All the time', caption = 'The bar is always on screen.', recommended = true },
			{ value = 'faded', title = 'Faded out of combat', caption = 'The bar is see-through until a fight starts.' },
			{ value = 'combat', title = 'Only in combat', caption = 'The bar hides when you are not fighting.' },
		},
		get = function()
			local s = Addon:Settings()
			if s.hideOutOfCombat then
				return 'combat'
			elseif (s.fadeOutOfCombat or 1) < 1 then
				return 'faded'
			end
			return 'always'
		end,
		set = function(value)
			local s = Addon:Settings()
			s.hideOutOfCombat = value == 'combat'
			SetSetting('fadeOutOfCombat', value == 'faded' and 0.5 or 1)
			Addon.logger.debug('Setup set visibility to ' .. tostring(value))
		end,
	})
end
