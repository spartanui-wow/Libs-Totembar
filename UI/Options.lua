local addonName, ns = ...
local Addon = ns.Addon

---@class LibsTotembar.Options : AceModule, AceEvent-3.0
local Options = Addon:NewModule('Options')

local APP = addonName
local TITLE = 'Libs - Totembar'

local function Get(info)
	return Addon:Settings()[info[#info]]
end

local function Set(info, value)
	local key = info[#info]
	Addon:Settings()[key] = value
	Addon:SendMessage(Addon.MSG_SETTINGS, key)
end

local function Combat()
	return InCombatLockdown()
end

function Options:OnInitialize()
	self.options = {
		type = 'group',
		name = TITLE,
		childGroups = 'tab',
		args = {
			bar = {
				type = 'group',
				name = 'Bar',
				order = 1,
				get = Get,
				set = Set,
				disabled = Combat,
				args = {
					enabled = {
						type = 'toggle',
						name = 'Show the bar',
						desc = 'Turn the bar off without turning off the addon.',
						order = 1,
					},
					locked = {
						type = 'toggle',
						name = 'Lock position',
						desc = 'Unlock to drag the bar somewhere else. You can also type /totembar unlock.',
						order = 2,
						set = function(_, value)
							Addon:SetLocked(value)
						end,
					},
					reset = {
						type = 'execute',
						name = 'Reset position',
						desc = 'Put the bar back in its starting spot, just below the middle of the screen.',
						order = 3,
						func = function()
							Addon:GetModule('Bar'):ResetPosition()
						end,
					},
					layoutHeader = { type = 'header', name = 'Layout', order = 10 },
					orientation = {
						type = 'select',
						name = 'Direction',
						desc = 'Lay the buttons out in a row or a column.',
						order = 11,
						values = { HORIZONTAL = 'Row', VERTICAL = 'Column' },
					},
					layout = {
						type = 'select',
						name = 'Groups',
						desc = 'Show every spell, or one button per group that opens the rest when you point at it. Automatic uses one button for each totem element, since only one totem of an element can be down at a time.',
						order = 12,
						values = { auto = 'Automatic', expanded = 'Show every spell', flyout = 'One button per group' },
						sorting = { 'auto', 'expanded', 'flyout' },
					},
					flyoutDirection = {
						type = 'select',
						name = 'Pop-out side',
						desc = 'Which way the list of spells opens from a group button. Automatic opens toward the middle of the screen.',
						order = 13,
						values = { auto = 'Automatic', UP = 'Up', DOWN = 'Down', LEFT = 'Left', RIGHT = 'Right' },
						sorting = { 'auto', 'UP', 'DOWN', 'LEFT', 'RIGHT' },
					},
					scale = {
						type = 'range',
						name = 'Scale',
						order = 14,
						min = 0.5,
						max = 2,
						step = 0.05,
						isPercent = true,
					},
					buttonSize = {
						type = 'range',
						name = 'Button size',
						order = 15,
						min = 20,
						max = 64,
						step = 1,
					},
					spacing = {
						type = 'range',
						name = 'Space between buttons',
						order = 16,
						min = 0,
						max = 12,
						step = 1,
					},
					groupSpacing = {
						type = 'range',
						name = 'Space between groups',
						order = 17,
						min = 0,
						max = 40,
						step = 1,
					},
					displayHeader = { type = 'header', name = 'What to show', order = 20 },
					showTimers = {
						type = 'toggle',
						name = 'Time left',
						desc = 'Show how long a placed totem or trap has left, on its button.',
						order = 21,
					},
					showAccent = {
						type = 'toggle',
						name = 'Group color strip',
						desc = 'A thin line under each group in its color. It empties as the placed totem runs out.',
						order = 22,
					},
					showCooldownNumbers = {
						type = 'toggle',
						name = 'Cooldown numbers',
						desc = 'Show the seconds left before a spell can be cast again.',
						order = 23,
					},
					showKeybinds = {
						type = 'toggle',
						name = 'Key bindings',
						desc = 'Show the key bound to each button. Set keys in Key Bindings, under AddOns.',
						order = 24,
					},
					visibilityHeader = { type = 'header', name = 'When to show', order = 30 },
					hideOutOfCombat = {
						type = 'toggle',
						name = 'Only in combat',
						desc = 'Hide the bar when you are not fighting.',
						order = 31,
					},
					fadeOutOfCombat = {
						type = 'range',
						name = 'Opacity out of combat',
						desc = 'Make the bar see-through when you are not fighting. It goes back to full in combat.',
						order = 32,
						min = 0.1,
						max = 1,
						step = 0.05,
						isPercent = true,
						disabled = function()
							return Combat() or Addon:Settings().hideOutOfCombat
						end,
					},
				},
			},
			spells = {
				type = 'group',
				name = 'Spells',
				order = 2,
				disabled = Combat,
				args = {},
			},
			profiles = LibStub('AceDBOptions-3.0'):GetOptionsTable(Addon.db),
		},
	}
	self.options.args.profiles.order = 3

	LibStub('AceConfig-3.0'):RegisterOptionsTable(APP, self.options)
	self.panel = LibStub('AceConfigDialog-3.0'):AddToBlizOptions(APP, TITLE)
	LibStub('AceConfigDialog-3.0'):SetDefaultSize(APP, 640, 560)
end

function Options:OnEnable()
	self:RegisterMessage(Addon.MSG_SPELLS, 'BuildSpellOptions')
	self:BuildSpellOptions()
end

---One toggle per known spell, grouped the way the bar groups them.
function Options:BuildSpellOptions()
	local args = {}
	local Spells = Addon:GetModule('Spells')
	local groups = Spells:GetGroups()

	args.intro = {
		type = 'description',
		name = 'Pick which spells appear on the bar. Only spells you have learned are listed; new ones show up as you learn them.',
		order = 0,
		fontSize = 'medium',
	}

	if #groups == 0 then
		args.none = {
			type = 'description',
			name = Spells.data and 'You have not learned any of these spells yet.' or 'Your class has no totems, traps or statues for this bar in this version of the game.',
			order = 1,
		}
	end

	for gi, group in ipairs(groups) do
		local c = group.color
		local hex = format('ff%02x%02x%02x', floor(c[1] * 255 + 0.5), floor(c[2] * 255 + 0.5), floor(c[3] * 255 + 0.5))
		local groupArgs = {}
		for si, spell in ipairs(group.all) do
			groupArgs['s' .. spell.key] = {
				type = 'toggle',
				name = '|T' .. tostring(spell.icon) .. ':16:16:0:0:64:64:5:59:5:59|t ' .. (spell.name or tostring(spell.key)),
				order = si,
				width = 'full',
				get = function()
					return not Addon:Settings().hidden[spell.key]
				end,
				set = function(_, value)
					Addon:Settings().hidden[spell.key] = (not value) or nil
					Addon:SendMessage(Addon.MSG_SETTINGS, 'hidden')
				end,
			}
		end
		args['g' .. gi] = {
			type = 'group',
			inline = true,
			name = '|c' .. hex .. group.name .. '|r',
			order = gi,
			args = groupArgs,
		}
	end

	self.options.args.spells.args = args
	LibStub('AceConfigRegistry-3.0'):NotifyChange(APP)
end

function Options:Open()
	local dialog = LibStub('AceConfigDialog-3.0')
	if dialog.OpenFrames[APP] then
		dialog:Close(APP)
	else
		dialog:Open(APP)
	end
end
