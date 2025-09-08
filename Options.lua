local addonName, root = ...
---@class LibsTotembar
local LibsTotembar = LibStub('AceAddon-3.0'):GetAddon(addonName)
local Log = LibsTotembar.Log

-- Import AceConfig libraries
local AceConfig = LibStub('AceConfig-3.0')
local AceConfigDialog = LibStub('AceConfigDialog-3.0')

-- Constants
local MAX_BUTTONS = 10

-- Options management functionality
local OptionsManager = {}

---Setup comprehensive options panel
function OptionsManager:SetupOptions()
	local options = {
		name = 'LibsTotembar',
		handler = LibsTotembar,
		type = 'group',
		args = {
			general = {
				type = 'group',
				name = 'General Settings',
				order = 10,
				args = {
					enabled = {
						type = 'toggle',
						name = 'Enable LibsTotembar',
						desc = 'Enable or disable the addon',
						order = 1,
						get = function(info)
							return LibsTotembar.db.profile.enabled
						end,
						set = function(info, value)
							LibsTotembar.db.profile.enabled = value
							LibsTotembar.BarManager:UpdateBarVisibility()
						end
					},
					maxButtons = {
						type = 'range',
						name = 'Maximum Buttons',
						desc = 'Maximum number of buttons to show on the bar',
						order = 2,
						min = 4,
						max = MAX_BUTTONS,
						step = 1,
						get = function(info)
							return LibsTotembar.db.profile.maxButtons
						end,
						set = function(info, value)
							LibsTotembar.db.profile.maxButtons = value
							LibsTotembar.BarManager:UpdateBarLayout()
						end
					},
					hideWhenEmpty = {
						type = 'toggle',
						name = 'Hide When Empty',
						desc = 'Hide the bar when no abilities are active',
						order = 3,
						get = function(info)
							return LibsTotembar.db.profile.hideWhenEmpty
						end,
						set = function(info, value)
							LibsTotembar.db.profile.hideWhenEmpty = value
							LibsTotembar.BarManager:UpdateBarVisibility()
						end
					},
					lockPosition = {
						type = 'toggle',
						name = 'Lock Position',
						desc = 'Lock the bar position to prevent accidental movement',
						order = 4,
						get = function(info)
							return LibsTotembar.db.profile.behavior.lockPosition
						end,
						set = function(info, value)
							LibsTotembar.db.profile.behavior.lockPosition = value
							LibsTotembar.BarManager:UpdateBarLayout()
						end
					}
				}
			},
			layout = {
				type = 'group',
				name = 'Layout & Appearance',
				order = 20,
				args = {
					scale = {
						type = 'range',
						name = 'Scale',
						desc = 'Scale of the entire bar',
						order = 1,
						min = 0.5,
						max = 2.0,
						step = 0.1,
						get = function(info)
							return LibsTotembar.db.profile.layout.scale
						end,
						set = function(info, value)
							LibsTotembar.db.profile.layout.scale = value
							LibsTotembar.BarManager:UpdateBarLayout()
						end
					},
					spacing = {
						type = 'range',
						name = 'Button Spacing',
						desc = 'Space between buttons',
						order = 2,
						min = 0,
						max = 10,
						step = 1,
						get = function(info)
							return LibsTotembar.db.profile.layout.spacing
						end,
						set = function(info, value)
							LibsTotembar.db.profile.layout.spacing = value
							-- Would need to reposition buttons here
							Log('Button spacing changed - restart required for full effect', 'info')
						end
					},
					showBackground = {
						type = 'toggle',
						name = 'Show Background',
						desc = 'Show background on buttons',
						order = 3,
						get = function(info)
							return LibsTotembar.db.profile.appearance.showBackground
						end,
						set = function(info, value)
							LibsTotembar.db.profile.appearance.showBackground = value
							LibsTotembar.BarManager:UpdateButtonAppearance()
						end
					},
					showCooldownText = {
						type = 'toggle',
						name = 'Show Timer Text',
						desc = 'Show remaining time text on buttons',
						order = 4,
						get = function(info)
							return LibsTotembar.db.profile.appearance.showCooldownText
						end,
						set = function(info, value)
							LibsTotembar.db.profile.appearance.showCooldownText = value
						end
					}
				}
			},
			spells = {
				type = 'group',
				name = 'Spell Settings',
				order = 30,
				args = {
					header = {
						type = 'header',
						name = 'Available Spells',
						order = 1
					},
					desc = {
						type = 'description',
						name = 'Enable or disable individual spells for tracking. Custom spells can be added using the commands.',
						order = 2
					}
					-- Dynamic spell toggles will be added here
				}
			},
			filters = {
				type = 'group',
				name = 'Filters & Display',
				order = 40,
				args = {
					hideInCombat = {
						type = 'toggle',
						name = 'Hide in Combat',
						desc = 'Hide the bar during combat',
						order = 1,
						get = function(info)
							return LibsTotembar.db.profile.filters.hideInCombat
						end,
						set = function(info, value)
							LibsTotembar.db.profile.filters.hideInCombat = value
							LibsTotembar.BarManager:UpdateBarVisibility()
						end
					},
					hideOutOfCombat = {
						type = 'toggle',
						name = 'Hide out of Combat',
						desc = 'Hide the bar when not in combat',
						order = 2,
						get = function(info)
							return LibsTotembar.db.profile.filters.hideOutOfCombat
						end,
						set = function(info, value)
							LibsTotembar.db.profile.filters.hideOutOfCombat = value
							LibsTotembar.BarManager:UpdateBarVisibility()
						end
					},
					showUnknownSpells = {
						type = 'toggle',
						name = 'Show Unknown Spells',
						desc = 'Show spells that you do not know',
						order = 3,
						get = function(info)
							return LibsTotembar.db.profile.filters.showUnknownSpells
						end,
						set = function(info, value)
							LibsTotembar.db.profile.filters.showUnknownSpells = value
						end
					}
				}
			},
			custom = {
				type = 'group',
				name = 'Custom Spells',
				order = 50,
				args = {
					header = {
						type = 'header',
						name = 'Add Custom Spells',
						order = 1
					},
					desc = {
						type = 'description',
						name = 'Use the commands below to add any spell to tracking:\n/totembar add <spellID> [duration] [category]\n/totembar remove <spellID>\n\nExamples:\n/totembar add 2825 40 Utility  (Bloodlust)\n/totembar add 121536 8 Mobility  (Angelic Feather)',
						order = 2
					},
					customList = {
						type = 'group',
						name = 'Current Custom Spells',
						inline = true,
						order = 3,
						args = {}
					}
				}
			}
		}
	}

	-- Add dynamic spell toggles
	self:UpdateSpellOptions(options)

	-- Register options (with safety checks)
	if AceConfig and AceConfigDialog then
		AceConfig:RegisterOptionsTable('LibsTotembar', options)
		AceConfigDialog:AddToBlizOptions('LibsTotembar', 'LibsTotembar')
		Log('Configuration panel registered successfully', 'debug')
	else
		Log('Cannot register configuration panel - missing AceConfig libraries', 'error')
	end
end

---Update spell options dynamically
function OptionsManager:UpdateSpellOptions(options)
	if not options then
		return
	end

	local availableSpells = LibsTotembar:GetAvailableSpells()
	local spellArgs = {}
	local customArgs = {}

	-- Group spells by category
	local categories = {}
	for spellId, spellData in pairs(availableSpells) do
		local category = spellData.category or 'Unknown'
		if not categories[category] then
			categories[category] = {}
		end
		table.insert(categories[category], {id = spellId, data = spellData})
	end

	-- Create category groups
	local order = 10
	for category, spells in pairs(categories) do
		spellArgs[category:lower():gsub(' ', '')] = {
			type = 'group',
			name = category .. ' Spells',
			inline = true,
			order = order,
			args = {}
		}

		-- Add spells to category
		table.sort(
			spells,
			function(a, b)
				return a.data.name < b.data.name
			end
		)
		for i, spellInfo in ipairs(spells) do
			local spellId = spellInfo.id
			local spellData = spellInfo.data

			local key = 'spell_' .. spellId
			spellArgs[category:lower():gsub(' ', '')].args[key] = {
				type = 'toggle',
				name = spellData.name .. (spellData.customAdded and ' (Custom)' or ''),
				desc = string.format('Duration: %ds | Category: %s%s', spellData.duration, spellData.category, spellData.customAdded and '\nCustom spell added by user' or ''),
				order = i,
				get = function(info)
					return LibsTotembar.db.profile.spells.enabled[spellId] ~= false
				end,
				set = function(info, value)
					LibsTotembar.db.profile.spells.enabled[spellId] = value
					Log((value and 'Enabled' or 'Disabled') .. ' spell: ' .. spellData.name, 'info')
				end
			}

			-- Add remove button for custom spells
			if spellData.customAdded then
				customArgs['remove_' .. spellId] = {
					type = 'execute',
					name = 'Remove ' .. spellData.name,
					desc = 'Remove this custom spell',
					order = i,
					func = function()
						LibsTotembar:RemoveCustomSpell(spellId)
						-- Refresh options
						self:UpdateSpellOptions(options)
						AceConfigDialog:Open('LibsTotembar')
					end
				}
			end
		end

		order = order + 10
	end

	-- Update the options table
	options.args.spells.args = spellArgs
	options.args.custom.args.customList.args = customArgs
end

-- Export the OptionsManager to the main addon
LibsTotembar.OptionsManager = OptionsManager

-- Also export individual functions for backward compatibility
LibsTotembar.SetupOptions = function(self)
	return OptionsManager:SetupOptions()
end
LibsTotembar.UpdateSpellOptions = function(self, options)
	return OptionsManager:UpdateSpellOptions(options)
end
