local _, ns = ...
local Addon = ns.Addon
local Compat = Addon.Compat
local T = Addon.Theme

-- One square spell button: a secure action button that casts its spell, plus everything drawn on
-- top of it. Attributes are only ever written out of combat (or by our own secure snippets); the
-- visuals below are plain regions and can change at any time.
--
-- States, from the design brief:
--   ready      full-color icon, faint hairline
--   cooldown   dark swipe with the game's own countdown numbers
--   no power   icon tinted blue; not usable: icon grayed
--   placed     1px border in the group color and a countdown along the bottom edge

---@class LibsTotembar.Button : Button
local ButtonMixin = {}
Addon.ButtonMixin = ButtonMixin

local ICON_CROP = 0.08
local EMPTY_DURATION = Compat.HasDurationObjects and C_DurationUtil.CreateDuration() or nil

---@param parent Frame
---@param name string|nil Global name (bound keys use it)
---@param keyboard boolean Also react on key down (for key bindings)
---@return LibsTotembar.Button
function Addon:CreateSpellButton(parent, name, keyboard)
	---@type LibsTotembar.Button
	local button = CreateFrame('Button', name, parent, 'SecureActionButtonTemplate')
	Mixin(button, ButtonMixin)
	if keyboard then
		button:RegisterForClicks('AnyUp', 'AnyDown')
	else
		button:RegisterForClicks('AnyUp')
	end
	button:SetAttribute('type', 'spell')

	button.plate = T.Fill(button, T.color.plate, 'BACKGROUND')

	local icon = button:CreateTexture(nil, 'ARTWORK')
	icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
	button.icon = icon

	button.border = T.Border(button, T.color.line, 'OVERLAY', 1)

	local cooldown = CreateFrame('Cooldown', nil, button, 'CooldownFrameTemplate')
	cooldown:SetDrawEdge(false)
	cooldown:SetDrawBling(false)
	cooldown:SetSwipeColor(0, 0, 0, 0.72)
	button.cooldown = cooldown

	-- Everything above the cooldown swipe lives on this layer frame.
	local overlay = CreateFrame('Frame', nil, button)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(cooldown:GetFrameLevel() + 2)
	button.overlay = overlay

	-- The "placed" border sits in its own frame so its alpha can follow a secret boolean.
	local placed = CreateFrame('Frame', nil, overlay)
	placed:SetAllPoints()
	placed:SetAlpha(0)
	button.placed = placed
	button.placedBorder = T.Border(placed, { 1, 1, 1, 1 }, 'OVERLAY', 2, 1)

	local pulse = placed:CreateAnimationGroup()
	local grow = pulse:CreateAnimation('Alpha')
	grow:SetFromAlpha(0.35)
	grow:SetToAlpha(1)
	grow:SetDuration(0.35)
	grow:SetSmoothing('OUT')
	button.pulse = pulse

	button.timer = T.Text(overlay, 11, T.color.text)
	button.timer:SetPoint('BOTTOM', button, 'BOTTOM', 0, 2)
	button.timerBinding = Compat.CreateTextBinding(button.timer)

	button.hotkey = T.Text(overlay, 9, T.color.muted)
	button.hotkey:SetPoint('TOPRIGHT', button, 'TOPRIGHT', -2, -3)
	button.hotkey:SetJustifyH('RIGHT')

	-- In flyout mode: a small badge showing which other spell of the group is currently placed.
	local badge = CreateFrame('Frame', nil, overlay)
	badge:SetSize(14, 14)
	badge:SetPoint('TOPLEFT', button, 'TOPLEFT', -3, 3)
	badge.plate = T.Fill(badge, { 0, 0, 0, 1 })
	badge.icon = badge:CreateTexture(nil, 'ARTWORK')
	badge.icon:SetPoint('TOPLEFT', 1, -1)
	badge.icon:SetPoint('BOTTOMRIGHT', -1, 1)
	badge.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
	badge:Hide()
	button.badge = badge

	button.chevron = T.Chevron(overlay, { 1, 1, 1, 0.55 })
	button.chevron:Hide()

	local hover = T.Fill(button, T.color.hover, 'HIGHLIGHT')
	hover:SetBlendMode('ADD')
	local pushed = button:CreateTexture(nil, 'OVERLAY')
	pushed:SetTexture(T.WHITE)
	pushed:SetVertexColor(unpack(T.color.pressed))
	pushed:SetAllPoints()
	button:SetPushedTexture(pushed)

	-- Manual countdowns for clients without engine duration text.
	button.ticker = CreateFrame('Frame', nil, button)

	button:HookScript('OnEnter', button.OnEnter)
	button:HookScript('OnLeave', button.OnLeave)
	button:HookScript('OnSizeChanged', button.OnSizeChanged)
	return button
end

function ButtonMixin:OnSizeChanged()
	local inset = T.Pixel(self)
	self.icon:ClearAllPoints()
	self.icon:SetPoint('TOPLEFT', inset, -inset)
	self.icon:SetPoint('BOTTOMRIGHT', -inset, inset)
	T.LayoutBorder(self, self.border)
	T.LayoutBorder(self.placed, self.placedBorder)
	local size = self:GetHeight()
	if size and size > 0 then
		T.SetTextSize(self.timer, math.max(9, math.floor(size * 0.32 + 0.5)))
		T.SetTextSize(self.hotkey, math.max(8, math.floor(size * 0.24 + 0.5)))
		self.badge:SetSize(math.floor(size * 0.42 + 0.5), math.floor(size * 0.42 + 0.5))
	end
end

function ButtonMixin:OnEnter()
	local spell = self.spell
	if not spell then
		return
	end
	GameTooltip:SetOwner(self, 'ANCHOR_TOP')
	GameTooltip:SetSpellByID(spell.id)
	if self.isFlyoutMain then
		GameTooltip:AddLine(' ')
		GameTooltip:AddLine('Hover to pick another ' .. spell.group.name:lower() .. ' spell.', T.color.muted[1], T.color.muted[2], T.color.muted[3], true)
	elseif self.isFlyoutChoice then
		GameTooltip:AddLine(' ')
		GameTooltip:AddLine('Click to cast it and keep it on the bar.', T.color.muted[1], T.color.muted[2], T.color.muted[3], true)
	end
	if self.canDismiss then
		GameTooltip:AddLine('Right-click to remove the placed totem.', T.color.muted[1], T.color.muted[2], T.color.muted[3], true)
	end
	GameTooltip:Show()
end

function ButtonMixin:OnLeave()
	if GameTooltip:IsOwned(self) then
		GameTooltip:Hide()
	end
end

---Points the button at a spell. Writes secure attributes, so callers run this out of combat.
---@param spell LibsTotembar.Spell|nil
function ButtonMixin:SetSpell(spell)
	self.spell = spell
	self:SetAttribute('spell', spell and spell.cast or nil)
	self:SetAttribute('ltb-key', spell and spell.key or nil)
	self:ShowSpell(spell)
end

---Visual half of SetSpell, safe in combat (used when a secure snippet already swapped the spell).
---@param spell LibsTotembar.Spell|nil
function ButtonMixin:ShowSpell(spell)
	self.spell = spell
	if spell then
		self.icon:SetTexture(spell.icon)
		self.accent = spell.group.color
	else
		self.icon:SetTexture(nil)
	end
	self:UpdateAll()
end

function ButtonMixin:UpdateAll()
	self:UpdateCooldown()
	self:UpdateUsable()
end

function ButtonMixin:UpdateCooldown()
	if self.spell then
		Compat.ApplySpellCooldown(self.cooldown, self.spell.id)
	else
		Compat.ClearCooldown(self.cooldown)
	end
end

function ButtonMixin:UpdateUsable()
	if not self.spell then
		return
	end
	local usable, noPower = Compat.SpellUsable(self.spell.id)
	if usable then
		self.icon:SetVertexColor(1, 1, 1)
		self.icon:SetDesaturated(false)
	elseif noPower then
		local c = T.color.noPower
		self.icon:SetVertexColor(c[1], c[2], c[3])
		self.icon:SetDesaturated(false)
	else
		local c = T.color.unusable
		self.icon:SetVertexColor(c[1] * 2, c[2] * 2, c[3] * 2)
		self.icon:SetDesaturated(true)
	end
end

---@param settings table
function ButtonMixin:ApplySettings(settings)
	self.cooldown:SetHideCountdownNumbers(not settings.showCooldownNumbers)
	self.showTimer = settings.showTimers
	if not settings.showTimers then
		self.timer:Hide()
	end
	self:UpdateHotkey(settings.showKeybinds)
end

---@param show boolean
function ButtonMixin:UpdateHotkey(show)
	local name = self:GetName()
	local key = show and name and GetBindingKey('CLICK ' .. name .. ':LeftButton')
	if key then
		local text = GetBindingText(key, 'KEY_', true) or key
		self.hotkey:SetText(text)
		self.hotkey:Show()
	else
		self.hotkey:SetText('')
		self.hotkey:Hide()
	end
end

local function TickText(ticker)
	local button = ticker:GetParent()
	local remaining = button.timerEnd - GetTime()
	if remaining <= 0 then
		ticker:SetScript('OnUpdate', nil)
		button.timer:SetText('')
		return
	end
	button.timer:SetText(Compat.FormatRemaining(remaining))
end

---Shows (or clears) the countdown for a placed totem or armed trap.
---@param timer LibsTotembar.Timer|nil
---@param tracker LibsTotembar.Tracker
---@param badgeSpell? LibsTotembar.Spell Placed spell to show as a badge, when it is not this button's
function ButtonMixin:SetTimer(timer, tracker, badgeSpell)
	local wasActive = self.timerActive
	self.ticker:SetScript('OnUpdate', nil)

	if badgeSpell then
		self.badge.icon:SetTexture(badgeSpell.icon)
		self.badge:Show()
	else
		self.badge:Hide()
	end

	if not timer then
		self.timerActive = nil
		self.placed:SetAlpha(0)
		self.timer:SetText('')
		if self.timerBinding and EMPTY_DURATION then
			self.timerBinding:SetDuration(EMPTY_DURATION)
		end
		return
	end

	local color = (badgeSpell and badgeSpell.group.color) or (self.spell and self.spell.group.color) or T.color.text
	T.ColorBorder(self.placedBorder, color[1], color[2], color[3], 1)

	local durationObject, start, length = tracker:Resolve(timer)

	-- A secret slot cannot be tested, so let the engine hide the border once the totem is gone.
	local have = timer.secret and timer.slot and GetTotemInfo(timer.slot)
	if Compat.IsSecret(have) and self.placed.SetAlphaFromBoolean then
		self.placed:SetAlphaFromBoolean(have, 1, 0)
	else
		self.placed:SetAlpha(1)
		if not wasActive then
			self.pulse:Restart()
		end
	end
	self.timerActive = true

	if not self.showTimer then
		self.timer:SetText('')
		return
	end
	self.timer:Show()
	if self.timerBinding and durationObject then
		self.timerBinding:SetDuration(durationObject)
	elseif start and length then
		self.timerEnd = start + length
		self.ticker:SetScript('OnUpdate', TickText)
		TickText(self.ticker)
	else
		self.timer:SetText('')
	end
end
