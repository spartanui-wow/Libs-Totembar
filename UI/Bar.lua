local _, ns = ...
local Addon = ns.Addon
local T = Addon.Theme

-- The bar: one secure header holding every button, laid out group by group. A group shows either
-- all of its spells in a row ("expanded") or one button that opens a flyout of the rest
-- ("flyout"). Under each group runs a thin strip in the group color that drains while something
-- from that group is placed.
--
-- Layout writes secure attributes and positions, so it only runs out of combat. Picking a spell
-- from a flyout swaps the group's button through a secure snippet, which works in combat too.

---@class LibsTotembar.Bar : AceModule, AceEvent-3.0
local Bar = Addon:NewModule('Bar')

local BUTTON_PREFIX = 'LibsTotembarButton'
local ACCENT_SIZE = 2
local ACCENT_GAP = 3
local FLYOUT_PAD = 3

local FLYOUT_OPEN = [[
	if self:GetAttribute('ltb-flyout') then
		local flyout = self:GetFrameRef('flyout')
		if flyout then
			flyout:Show()
			flyout:RegisterAutoHide(0.4)
			flyout:AddToAutoHide(self)
		end
	end
]]

local FLYOUT_PICK_PRE = [[
	return nil, 'pick'
]]

local FLYOUT_PICK_POST = [[
	local main = self:GetFrameRef('main')
	if main then
		main:SetAttribute('spell', self:GetAttribute('spell'))
		main:SetAttribute('ltb-key', self:GetAttribute('ltb-key'))
	end
	self:GetParent():Hide()
]]

function Bar:OnInitialize()
	self.buttons = {} -- named pool, in bar order
	self.views = {} -- per visible group
	self.active = {} -- every button currently showing a spell, flyout choices included
end

function Bar:OnEnable()
	self.Spells = Addon:GetModule('Spells')
	self.Tracker = Addon:GetModule('Tracker')
	if not self.Spells.data then
		return
	end

	self:CreateHeader()

	self:RegisterMessage(Addon.MSG_SPELLS, 'Layout')
	self:RegisterMessage(Addon.MSG_TIMERS, 'UpdateTimers')
	self:RegisterMessage(Addon.MSG_SETTINGS, 'OnSettingsChanged')

	self:RegisterEvent('SPELL_UPDATE_COOLDOWN', 'UpdateCooldowns')
	self:RegisterEvent('SPELL_UPDATE_USABLE', 'UpdateUsable')
	self:RegisterEvent('UPDATE_BINDINGS', 'UpdateHotkeys')
	self:RegisterEvent('PLAYER_REGEN_DISABLED', 'UpdateFade')
	self:RegisterEvent('PLAYER_REGEN_ENABLED', 'UpdateFade')
	pcall(self.RegisterEvent, self, 'ACTIONBAR_UPDATE_COOLDOWN', 'UpdateCooldowns')
	pcall(self.RegisterEvent, self, 'ACTIONBAR_UPDATE_USABLE', 'UpdateUsable')

	self:Layout()
end

----------------------------------------------------------------------------------------------------
-- Frames
----------------------------------------------------------------------------------------------------

function Bar:CreateHeader()
	local header = CreateFrame('Frame', 'LibsTotembarBar', UIParent, 'SecureHandlerStateTemplate')
	header:SetMovable(true)
	header:SetClampedToScreen(true)
	header:SetFrameStrata('MEDIUM')
	header:SetSize(1, 1)
	if header.SetDontSavePosition then
		header:SetDontSavePosition(true)
	end
	self.header = header
	self:ApplyPosition()
	self:CreateMover()
end

function Bar:CreateMover()
	local header = self.header
	local mover = CreateFrame('Frame', nil, header)
	mover:SetPoint('TOPLEFT', -4, 4)
	mover:SetPoint('BOTTOMRIGHT', 4, -4)
	mover:SetFrameLevel(header:GetFrameLevel() + 60)
	mover:EnableMouse(true)
	mover:RegisterForDrag('LeftButton')

	local c = T.color.mover
	T.Fill(mover, { c[1], c[2], c[3], 0.16 })
	mover.border = T.Border(mover, { c[1], c[2], c[3], 0.9 })

	local label = T.Text(mover, 11, T.color.text)
	label:SetPoint('BOTTOMLEFT', mover, 'TOPLEFT', 0, 4)
	label:SetText('Totem Bar')
	local hint = T.Text(mover, 10, T.color.muted)
	hint:SetPoint('LEFT', label, 'RIGHT', 8, 0)
	hint:SetText('Drag to move. Right-click to lock.')

	mover:SetScript('OnDragStart', function()
		if not InCombatLockdown() then
			header:StartMoving()
		end
	end)
	mover:SetScript('OnDragStop', function()
		header:StopMovingOrSizing()
		self:SavePosition()
		self:Layout()
	end)
	mover:SetScript('OnMouseUp', function(_, mouseButton)
		if mouseButton == 'RightButton' then
			Addon:SetLocked(true)
		end
	end)
	mover:Hide()
	self.mover = mover
end

---@param index number
---@return LibsTotembar.Button
function Bar:GetButton(index)
	local button = self.buttons[index]
	if button then
		return button
	end
	button = Addon:CreateSpellButton(self.header, BUTTON_PREFIX .. index, true)
	SecureHandlerWrapScript(button, 'OnEnter', self.header, FLYOUT_OPEN)
	button:HookScript('OnAttributeChanged', function(btn, name, value)
		if name == 'ltb-key' and btn.isFlyoutMain and value then
			self:OnFlyoutPicked(btn, value)
		end
	end)
	self.buttons[index] = button
	return button
end

---@param index number
---@return table view
function Bar:GetView(index)
	local view = self.views[index]
	if view then
		return view
	end
	view = { choices = {} }

	local strip = CreateFrame('StatusBar', nil, self.header)
	strip:SetStatusBarTexture(T.WHITE)
	strip:SetMinMaxValues(0, 1)
	strip:SetValue(0)
	strip.track = T.Fill(strip, { 1, 1, 1, 0.2 }, 'BACKGROUND')
	strip.ticker = CreateFrame('Frame', nil, strip)
	view.strip = strip

	local flyout = CreateFrame('Frame', nil, self.header, 'SecureFrameTemplate')
	flyout:SetFrameLevel(self.header:GetFrameLevel() + 30)
	flyout.plate = T.Fill(flyout, T.color.flyout)
	flyout.border = T.Border(flyout, T.color.lineStrong)
	flyout.accent = flyout:CreateTexture(nil, 'OVERLAY')
	flyout.accent:SetTexture(T.WHITE)
	flyout:Hide()
	view.flyout = flyout

	self.views[index] = view
	return view
end

---@param view table
---@param index number
---@return LibsTotembar.Button
function Bar:GetChoice(view, index)
	local choice = view.choices[index]
	if choice then
		return choice
	end
	choice = Addon:CreateSpellButton(view.flyout, nil, false)
	choice.isFlyoutChoice = true
	SecureHandlerWrapScript(choice, 'OnClick', self.header, FLYOUT_PICK_PRE, FLYOUT_PICK_POST)
	view.choices[index] = choice
	return choice
end

----------------------------------------------------------------------------------------------------
-- Position
----------------------------------------------------------------------------------------------------

function Bar:ApplyPosition()
	local pos = Addon:Settings().position
	self.header:ClearAllPoints()
	self.header:SetPoint(pos.point or 'CENTER', UIParent, pos.relativePoint or pos.point or 'CENTER', pos.x or 0, pos.y or 0)
end

function Bar:SavePosition()
	local point, _, relativePoint, x, y = self.header:GetPoint(1)
	local pos = Addon:Settings().position
	pos.point, pos.relativePoint, pos.x, pos.y = point, relativePoint, x, y
end

function Bar:ResetPosition()
	if not self.header then
		return
	end
	Addon:RunOutOfCombat('position', function()
		local pos = Addon:Settings().position
		pos.point, pos.relativePoint, pos.x, pos.y = 'CENTER', 'CENTER', 0, -180
		self:ApplyPosition()
		self:Layout()
	end)
end

----------------------------------------------------------------------------------------------------
-- Layout
----------------------------------------------------------------------------------------------------

---@param group LibsTotembar.Group
---@return string 'flyout'|'expanded'
local function GroupMode(group, setting)
	if #group.spells <= 1 then
		return 'expanded'
	end
	if setting == 'flyout' or setting == 'expanded' then
		return setting
	end
	-- Only one totem of an element can be down at a time, so an element needs just one button.
	if group.slot then
		return 'flyout'
	end
	return #group.spells > 6 and 'flyout' or 'expanded'
end

---Which way flyouts open. 'auto' opens toward the middle of the screen.
---@return string
function Bar:FlyoutDirection()
	local s = Addon:Settings()
	local horizontal = s.orientation == 'HORIZONTAL'
	local dir = s.flyoutDirection
	if horizontal and (dir == 'UP' or dir == 'DOWN') then
		return dir
	end
	if not horizontal and (dir == 'LEFT' or dir == 'RIGHT') then
		return dir
	end
	local x, y = self.header:GetCenter()
	local width, height = UIParent:GetSize()
	local scale = self.header:GetEffectiveScale() / UIParent:GetEffectiveScale()
	if horizontal then
		return (not y or y * scale < height / 2) and 'UP' or 'DOWN'
	end
	return (not x or x * scale < width / 2) and 'RIGHT' or 'LEFT'
end

---@param group LibsTotembar.Group
---@return LibsTotembar.Spell
local function ChosenSpell(group)
	local key = Addon:Settings().chosen[group.key]
	if key then
		for _, spell in ipairs(group.spells) do
			if spell.key == key then
				return spell
			end
		end
	end
	return group.spells[1]
end

function Bar:Layout()
	Addon:RunOutOfCombat('layout', function()
		self:DoLayout()
	end)
end

function Bar:DoLayout()
	local s = Addon:Settings()
	local header = self.header
	local size, spacing, gap = s.buttonSize, s.spacing, s.groupSpacing
	local horizontal = s.orientation == 'HORIZONTAL'
	local accent = s.showAccent and (ACCENT_SIZE + ACCENT_GAP) or 0
	local direction = self:FlyoutDirection()

	header:SetScale(s.scale)
	wipe(self.active)

	local used, viewCount, cursor = 0, 0, 0
	for _, group in ipairs(self.Spells:GetGroups()) do
		if #group.spells > 0 then
			viewCount = viewCount + 1
			local view = self:GetView(viewCount)
			view.group = group
			view.mode = GroupMode(group, s.layout)
			view.buttons = {}
			local first = cursor

			local list = view.mode == 'flyout' and { ChosenSpell(group) } or group.spells
			for _, spell in ipairs(list) do
				used = used + 1
				local button = self:GetButton(used)
				self:PlaceButton(button, cursor, horizontal, accent, size)
				button.isFlyoutMain = view.mode == 'flyout'
				button:SetSpell(spell)
				self:SetDismiss(button, group)
				button:SetAttribute('ltb-flyout', button.isFlyoutMain)
				if not button.isFlyoutMain then
					button.chevron:Hide()
				end
				button:ApplySettings(s)
				button:Show()
				view.buttons[#view.buttons + 1] = button
				self.active[#self.active + 1] = button
				cursor = cursor + size + spacing
			end
			local last = cursor - spacing

			self:PlaceStrip(view, first, last, horizontal, size, s.showAccent)
			if view.mode == 'flyout' then
				self:BuildFlyout(view, view.buttons[1], group, direction, size, spacing)
			else
				view.flyout:Hide()
				for _, choice in ipairs(view.choices) do
					choice:Hide()
				end
			end
			cursor = last + gap
		end
	end

	for i = used + 1, #self.buttons do
		local button = self.buttons[i]
		button:SetSpell(nil)
		button:SetAttribute('ltb-flyout', false)
		button:SetAttribute('type2', nil)
		button.isFlyoutMain = nil
		button.chevron:Hide()
		button:Hide()
	end
	for i = viewCount + 1, #self.views do
		local view = self.views[i]
		view.group = nil
		view.strip:Hide()
		view.flyout:Hide()
	end
	self.viewCount = viewCount

	local length = math.max(size, cursor - gap)
	if horizontal then
		header:SetSize(length, size + accent)
	else
		header:SetSize(size + accent, length)
	end

	self:UpdateVisibility()
	self:UpdateFade()
	self:UpdateTimers()
	self:UpdateHotkeys()
end

function Bar:PlaceButton(button, cursor, horizontal, accent, size)
	button:ClearAllPoints()
	button:SetSize(size, size)
	if horizontal then
		button:SetPoint('TOPLEFT', self.header, 'TOPLEFT', cursor, 0)
	else
		button:SetPoint('TOPLEFT', self.header, 'TOPLEFT', accent, -cursor)
	end
end

---Right-click removes the placed totem where a group owns a fixed totem slot (Classic elements).
function Bar:SetDismiss(button, group)
	if group.slot then
		button:SetAttribute('type2', 'destroytotem')
		button:SetAttribute('totem-slot', group.slot)
		button.canDismiss = true
	else
		button:SetAttribute('type2', nil)
		button:SetAttribute('totem-slot', nil)
		button.canDismiss = nil
	end
end

function Bar:PlaceStrip(view, first, last, horizontal, size, show)
	local strip = view.strip
	local c = view.group.color
	strip:SetStatusBarColor(c[1], c[2], c[3], 1)
	strip.track:SetVertexColor(c[1], c[2], c[3], 0.22)
	strip:ClearAllPoints()
	if horizontal then
		strip:SetOrientation('HORIZONTAL')
		strip:SetPoint('TOPLEFT', self.header, 'TOPLEFT', first, -(size + ACCENT_GAP))
		strip:SetSize(math.max(1, last - first), ACCENT_SIZE)
	else
		strip:SetOrientation('VERTICAL')
		strip:SetPoint('TOPLEFT', self.header, 'TOPLEFT', 0, -first)
		strip:SetSize(ACCENT_SIZE, math.max(1, last - first))
	end
	strip:SetShown(show)
end

local STEP = {
	UP = { 0, 1, 'BOTTOM', 'TOP' },
	DOWN = { 0, -1, 'TOP', 'BOTTOM' },
	RIGHT = { 1, 0, 'LEFT', 'RIGHT' },
	LEFT = { -1, 0, 'RIGHT', 'LEFT' },
}

function Bar:BuildFlyout(view, main, group, direction, size, spacing)
	local flyout = view.flyout
	local step = STEP[direction]
	local count = #group.spells

	for i, spell in ipairs(group.spells) do
		local choice = self:GetChoice(view, i)
		choice:ClearAllPoints()
		choice:SetSize(size, size)
		local offset = FLYOUT_PAD + (i - 1) * (size + spacing)
		choice:SetPoint(step[3], flyout, step[3], step[1] * offset, step[2] * offset)
		choice:SetSpell(spell)
		choice:ApplySettings(Addon:Settings())
		SecureHandlerSetFrameRef(choice, 'main', main)
		choice:Show()
		self.active[#self.active + 1] = choice
	end
	for i = count + 1, #view.choices do
		view.choices[i]:SetSpell(nil)
		view.choices[i]:Hide()
	end

	local along = FLYOUT_PAD * 2 + count * size + (count - 1) * spacing
	local across = size + FLYOUT_PAD * 2
	flyout:ClearAllPoints()
	if step[1] == 0 then
		flyout:SetSize(across, along)
	else
		flyout:SetSize(along, across)
	end
	flyout:SetPoint(step[3], main, step[4], 0, 0)

	local c = group.color
	flyout.accent:SetVertexColor(c[1], c[2], c[3], 1)
	flyout.accent:ClearAllPoints()
	flyout.accent:SetPoint(step[3] == 'BOTTOM' and 'BOTTOMLEFT' or step[3] == 'TOP' and 'TOPLEFT' or step[3] == 'LEFT' and 'TOPLEFT' or 'TOPRIGHT', flyout)
	if step[1] == 0 then
		flyout.accent:SetSize(across, ACCENT_SIZE)
	else
		flyout.accent:SetSize(ACCENT_SIZE, across)
	end
	for _, border in ipairs(flyout.border) do
		border:SetShown(true)
	end
	T.LayoutBorder(flyout, flyout.border)

	SecureHandlerSetFrameRef(main, 'flyout', flyout)
	main.chevron:SetDirection(direction)
	main.chevron:Show()
	flyout:Hide()
end

---A spell was picked from a flyout (possibly in combat, through the secure snippet).
function Bar:OnFlyoutPicked(button, key)
	local spell = self.Spells.byKey[key]
	if not spell or spell == button.spell then
		return
	end
	button:ShowSpell(spell)
	Addon:Settings().chosen[spell.group.key] = key
	self:UpdateTimers()
end

----------------------------------------------------------------------------------------------------
-- Visibility
----------------------------------------------------------------------------------------------------

local function HideConditions()
	local toc = Addon.toc
	if Addon.IsRetail or toc >= 50000 then
		return '[petbattle] hide; [vehicleui] hide; [overridebar] hide; [possessbar] hide; '
	elseif toc >= 30000 then
		return '[vehicleui] hide; [possessbar] hide; '
	end
	return ''
end

function Bar:UpdateVisibility()
	Addon:RunOutOfCombat('visibility', function()
		local s = Addon:Settings()
		local header = self.header
		local unlocked = not s.locked
		local driver
		if not s.enabled or (self.viewCount or 0) == 0 then
			driver = 'hide'
		elseif unlocked then
			driver = 'show'
		else
			driver = HideConditions() .. (s.hideOutOfCombat and '[nocombat] hide; ' or '') .. 'show'
		end
		UnregisterStateDriver(header, 'visibility')
		RegisterStateDriver(header, 'visibility', driver)
		self.mover:SetShown(unlocked and s.enabled and (self.viewCount or 0) > 0)
	end)
end

-- PLAYER_REGEN_DISABLED arrives before combat lockdown starts, so the event itself counts.
function Bar:UpdateFade(event)
	local s = Addon:Settings()
	local inCombat
	if event == 'PLAYER_REGEN_DISABLED' then
		inCombat = true
	elseif event == 'PLAYER_REGEN_ENABLED' then
		inCombat = false
	else
		inCombat = UnitAffectingCombat('player') or InCombatLockdown()
	end
	if not s.locked or inCombat then
		self.header:SetAlpha(1)
	else
		self.header:SetAlpha(s.fadeOutOfCombat or 1)
	end
end

function Bar:OnSettingsChanged(_, what)
	if what == 'position' or what == 'profile' then
		Addon:RunOutOfCombat('position', function()
			self:ApplyPosition()
		end)
	end
	if what == 'locked' then
		self:UpdateVisibility()
		self:UpdateFade()
		return
	end
	self:Layout()
end

----------------------------------------------------------------------------------------------------
-- Live updates
----------------------------------------------------------------------------------------------------

function Bar:UpdateCooldowns()
	for _, button in ipairs(self.active) do
		button:UpdateCooldown()
	end
end

function Bar:UpdateUsable()
	for _, button in ipairs(self.active) do
		button:UpdateUsable()
	end
end

function Bar:UpdateHotkeys()
	local show = Addon:Settings().showKeybinds
	for _, button in ipairs(self.buttons) do
		button:UpdateHotkey(show)
	end
end

local function TickStrip(ticker)
	local strip = ticker:GetParent()
	local remaining = strip.timerEnd - GetTime()
	if remaining <= 0 then
		ticker:SetScript('OnUpdate', nil)
		strip:SetValue(0)
		return
	end
	strip:SetValue(remaining / strip.timerLength)
end

function Bar:SetStripTimer(strip, timer)
	strip.ticker:SetScript('OnUpdate', nil)
	if not timer then
		strip:SetMinMaxValues(0, 1)
		strip:SetValue(0)
		return
	end
	local durationObject, start, length = self.Tracker:Resolve(timer)
	if durationObject and strip.SetTimerDuration then
		strip:SetTimerDuration(durationObject, Enum.StatusBarInterpolation.Immediate, Enum.StatusBarTimerDirection.RemainingTime)
	elseif start and length and length > 0 then
		strip:SetMinMaxValues(0, 1)
		strip.timerEnd = start + length
		strip.timerLength = length
		strip.ticker:SetScript('OnUpdate', TickStrip)
		TickStrip(strip.ticker)
	else
		strip:SetMinMaxValues(0, 1)
		strip:SetValue(0)
	end
end

function Bar:UpdateTimers()
	local Tracker = self.Tracker
	local Spells = self.Spells
	for i = 1, self.viewCount or 0 do
		local view = self.views[i]
		local group = view.group
		local groupTimer = Tracker:GetGroupTimer(group.key)
		self:SetStripTimer(view.strip, groupTimer)

		if view.mode == 'flyout' then
			local main = view.buttons[1]
			local placed = groupTimer and Spells.byKey[groupTimer.key]
			local other = placed and main.spell and placed.key ~= main.spell.key and placed or nil
			main:SetTimer(groupTimer, Tracker, other)
			for _, choice in ipairs(view.choices) do
				if choice.spell then
					choice:SetTimer(Tracker:GetTimer(choice.spell.key), Tracker)
				end
			end
		else
			for _, button in ipairs(view.buttons) do
				button:SetTimer(button.spell and Tracker:GetTimer(button.spell.key), Tracker)
			end
		end
	end
end
