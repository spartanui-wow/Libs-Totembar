local _, ns = ...
local Addon = ns.Addon

-- What the bar can show, per game family and class. Only spells the player has learned appear,
-- so listing a spell that a given client or level does not have is harmless: it never shows.
--
-- Spell IDs are the base (rank 1) spell. On Classic clients the bar casts by name, which always
-- uses the highest rank the player knows.
--
-- track:
--   'totem' (default) - timer comes from the game's totem slots
--   'cast'            - timer starts when the spell is cast and runs for `duration` seconds
--   'none'            - a plain button, no timer
--
-- group.slot pins a group to one totem slot (Classic elements: fire 1, earth 2, water 3, air 4).
-- group.color is an element color, or 'class' for the player's class color.

local FIRE, EARTH, WATER, AIR = FIRE_TOTEM_SLOT or 1, EARTH_TOTEM_SLOT or 2, WATER_TOTEM_SLOT or 3, AIR_TOTEM_SLOT or 4

local ELEMENT = {
	EARTH = { 0.58, 0.78, 0.30 },
	FIRE = { 1.00, 0.45, 0.16 },
	WATER = { 0.28, 0.62, 1.00 },
	AIR = { 0.74, 0.64, 1.00 },
}
ns.ElementColors = ELEMENT

ns.SpellData = {
	RETAIL = {
		SHAMAN = {
			{
				key = 'CONTROL',
				name = 'Control',
				color = ELEMENT.EARTH,
				spells = {
					{ id = 2484 }, -- Earthbind Totem
					{ id = 51485 }, -- Earthgrab Totem
					{ id = 192058 }, -- Capacitor Totem
					{ id = 8143 }, -- Tremor Totem
					{ id = 192077 }, -- Wind Rush Totem
					{ id = 204336 }, -- Grounding Totem
					{ id = 383013 }, -- Poison Cleansing Totem
					{ id = 383017 }, -- Stoneskin Totem
					{ id = 383019 }, -- Tranquil Air Totem
					{ id = 204331 }, -- Counterstrike Totem
					{ id = 355580 }, -- Static Field Totem
				},
			},
			{
				key = 'HEALING',
				name = 'Healing',
				color = ELEMENT.WATER,
				spells = {
					{ id = 5394 }, -- Healing Stream Totem
					{ id = 157153 }, -- Cloudburst Totem
					{ id = 108280 }, -- Healing Tide Totem
					{ id = 98008 }, -- Spirit Link Totem
					{ id = 198838 }, -- Earthen Wall Totem
					{ id = 207399 }, -- Ancestral Protection Totem
					{ id = 16191 }, -- Mana Tide Totem
					{ id = 444995 }, -- Surging Totem
				},
			},
			{
				key = 'OFFENSE',
				name = 'Offense',
				color = ELEMENT.FIRE,
				spells = {
					{ id = 192222 }, -- Liquid Magma Totem
					{ id = 8512 }, -- Windfury Totem
					{ id = 108285, track = 'none' }, -- Totemic Recall
					{ id = 108287, track = 'none' }, -- Totemic Projection
				},
			},
		},
		HUNTER = {
			{
				key = 'TRAPS',
				name = 'Traps',
				color = 'class',
				spells = {
					{ id = 187650, track = 'cast', duration = 60 }, -- Freezing Trap
					{ id = 187698, track = 'cast', duration = 60 }, -- Tar Trap
					{ id = 162488, track = 'cast', duration = 60 }, -- Steel Trap
					{ id = 236776, track = 'cast', duration = 60 }, -- High Explosive Trap
					{ id = 462031, track = 'cast', duration = 60 }, -- Implosive Trap
					{ id = 109248, track = 'cast', duration = 10 }, -- Binding Shot
					{ id = 1543, track = 'cast', duration = 20 }, -- Flare
				},
			},
		},
		MONK = {
			{
				key = 'STATUES',
				name = 'Statues',
				color = 'class',
				spells = {
					{ id = 115315 }, -- Summon Black Ox Statue
					{ id = 115313 }, -- Summon Jade Serpent Statue
					{ id = 388686 }, -- Summon White Tiger Statue
				},
			},
		},
		DRUID = {
			{
				key = 'GROUND',
				name = 'Efflorescence',
				color = 'class',
				spells = {
					{ id = 145205 }, -- Efflorescence
				},
			},
		},
	},

	CLASSIC = {
		SHAMAN = {
			{
				key = 'EARTH',
				name = 'Earth',
				color = ELEMENT.EARTH,
				slot = EARTH,
				spells = {
					{ id = 8071 }, -- Stoneskin Totem
					{ id = 2484 }, -- Earthbind Totem
					{ id = 5730 }, -- Stoneclaw Totem
					{ id = 8075 }, -- Strength of Earth Totem
					{ id = 8143 }, -- Tremor Totem
					{ id = 2062 }, -- Earth Elemental Totem
					{ id = 108270 }, -- Stone Bulwark Totem
					{ id = 51485 }, -- Earthgrab Totem
				},
			},
			{
				key = 'FIRE',
				name = 'Fire',
				color = ELEMENT.FIRE,
				slot = FIRE,
				spells = {
					{ id = 3599 }, -- Searing Totem
					{ id = 1535 }, -- Fire Nova Totem
					{ id = 8190 }, -- Magma Totem
					{ id = 8227 }, -- Flametongue Totem
					{ id = 8181 }, -- Frost Resistance Totem
					{ id = 30706 }, -- Totem of Wrath
					{ id = 2894 }, -- Fire Elemental Totem
				},
			},
			{
				key = 'WATER',
				name = 'Water',
				color = ELEMENT.WATER,
				slot = WATER,
				spells = {
					{ id = 5394 }, -- Healing Stream Totem
					{ id = 5675 }, -- Mana Spring Totem
					{ id = 16190 }, -- Mana Tide Totem
					{ id = 8166 }, -- Poison Cleansing Totem
					{ id = 8170 }, -- Disease Cleansing Totem / Cleansing Totem
					{ id = 8184 }, -- Fire Resistance Totem
					{ id = 108280 }, -- Healing Tide Totem
				},
			},
			{
				key = 'AIR',
				name = 'Air',
				color = ELEMENT.AIR,
				slot = AIR,
				spells = {
					{ id = 8512 }, -- Windfury Totem
					{ id = 8835 }, -- Grace of Air Totem
					{ id = 3738 }, -- Wrath of Air Totem
					{ id = 8177 }, -- Grounding Totem
					{ id = 10595 }, -- Nature Resistance Totem
					{ id = 15107 }, -- Windwall Totem
					{ id = 25908 }, -- Tranquil Air Totem
					{ id = 6495 }, -- Sentry Totem
					{ id = 108269 }, -- Capacitor Totem
					{ id = 98008 }, -- Spirit Link Totem
					{ id = 108273 }, -- Windwalk Totem
					{ id = 120668 }, -- Stormlash Totem
				},
			},
			{
				key = 'RECALL',
				name = 'Recall',
				color = 'class',
				spells = {
					{ id = 36936, track = 'none' }, -- Totemic Call / Totemic Recall
				},
			},
		},
		HUNTER = {
			{
				key = 'TRAPS',
				name = 'Traps',
				color = 'class',
				spells = {
					{ id = 1499, track = 'cast', duration = 60 }, -- Freezing Trap
					{ id = 13809, track = 'cast', duration = 60 }, -- Frost Trap / Ice Trap
					{ id = 13795, track = 'cast', duration = 60 }, -- Immolation Trap
					{ id = 13813, track = 'cast', duration = 60 }, -- Explosive Trap
					{ id = 34600, track = 'cast', duration = 60 }, -- Snake Trap
					{ id = 109248, track = 'cast', duration = 10 }, -- Binding Shot
					{ id = 1543, track = 'cast', duration = 30 }, -- Flare
					{ id = 77769, track = 'none' }, -- Trap Launcher
				},
			},
		},
		MONK = {
			{
				key = 'STATUES',
				name = 'Statues',
				color = 'class',
				spells = {
					{ id = 115315 }, -- Summon Black Ox Statue
					{ id = 115313 }, -- Summon Jade Serpent Statue
				},
			},
		},
	},
}

---The group definitions for the player's class on this client, or nil when the class has none.
---@param classFile string
---@return table[]|nil
function Addon:GetClassGroups(classFile)
	local family = self.IsRetail and ns.SpellData.RETAIL or ns.SpellData.CLASSIC
	return family[classFile]
end
