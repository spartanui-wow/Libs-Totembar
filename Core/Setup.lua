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

	reg:AddStep({
		id = 'direction',
		kind = 'choice',
		name = 'Bar shape',
		title = 'How should the bar be laid out?',
		text = 'For shamans, hunters, monks and druids. You can move the bar with /totembar unlock.',
		choices = {
			{ value = 'HORIZONTAL', title = 'A row', caption = 'Buttons sit side by side.', recommended = true },
			{ value = 'VERTICAL', title = 'A column', caption = 'Buttons stack on top of each other.' },
		},
		get = function()
			return Addon:Settings().orientation
		end,
		set = function(value)
			SetSetting('orientation', value)
		end,
	})

	reg:AddStep({
		id = 'visibility',
		kind = 'choice',
		name = 'When to show',
		title = 'When should the bar show?',
		text = 'You can change this later.',
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
