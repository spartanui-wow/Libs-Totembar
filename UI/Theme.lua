local _, ns = ...
local Addon = ns.Addon

-- Visual tokens, shared with the Libs family: near-black translucent panes, flat and square,
-- 1px hairlines. The only saturated colors carry game meaning: the totem element (or class
-- color) of each group, the red of "out of range of mana", and nothing else.

---@class LibsTotembar.Theme
local T = {}
Addon.Theme = T

local WHITE = 'Interface\\Buttons\\WHITE8X8'
T.WHITE = WHITE

T.color = {
	plate = { 0.047, 0.051, 0.059, 0.82 },
	flyout = { 0.047, 0.051, 0.059, 0.94 },
	line = { 1, 1, 1, 0.10 },
	lineStrong = { 1, 1, 1, 0.22 },
	hover = { 1, 1, 1, 0.10 },
	pressed = { 1, 1, 1, 0.16 },
	text = { 0.91, 0.90, 0.88 },
	muted = { 0.61, 0.61, 0.64 },
	faint = { 0.42, 0.42, 0.44 },
	noPower = { 0.36, 0.44, 0.95 },
	unusable = { 0.40, 0.40, 0.42 },
	mover = { 0.28, 0.62, 1.00 },
}

---One physical pixel in the frame's own units.
---@param frame? Frame
---@return number
function T.Pixel(frame)
	local _, height = GetPhysicalScreenSize()
	local scale = (frame or UIParent):GetEffectiveScale()
	if not height or height == 0 or not scale or scale == 0 then
		return 1
	end
	return 768 / height / scale
end

---@param parent Frame
---@param color table
---@param layer? string
---@param sublevel? number
---@return Texture
function T.Fill(parent, color, layer, sublevel)
	local tex = parent:CreateTexture(nil, layer or 'BACKGROUND', nil, sublevel)
	tex:SetTexture(WHITE)
	tex:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
	tex:SetAllPoints(parent)
	return tex
end

---A hairline border as four textures on the given layer. Returns the list so it can be recolored.
---@param frame Frame
---@param color table
---@param layer? string
---@param sublevel? number
---@param thickness? number In physical pixels
---@return Texture[]
function T.Border(frame, color, layer, sublevel, thickness)
	local lines = {}
	for i, side in ipairs({ 'TOP', 'BOTTOM', 'LEFT', 'RIGHT' }) do
		local tex = frame:CreateTexture(nil, layer or 'BORDER', nil, sublevel)
		tex:SetTexture(WHITE)
		tex:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
		tex.side = side
		lines[i] = tex
	end
	lines.thickness = thickness or 1
	T.LayoutBorder(frame, lines)
	return lines
end

---Re-applies pixel-exact thickness (call after the frame's scale changes).
---@param frame Frame
---@param lines Texture[]
function T.LayoutBorder(frame, lines)
	local px = T.Pixel(frame) * (lines.thickness or 1)
	for _, tex in ipairs(lines) do
		tex:ClearAllPoints()
		local side = tex.side
		if side == 'TOP' or side == 'BOTTOM' then
			tex:SetPoint(side .. 'LEFT', frame, side .. 'LEFT')
			tex:SetPoint(side .. 'RIGHT', frame, side .. 'RIGHT')
			tex:SetHeight(px)
		else
			tex:SetPoint('TOP' .. side, frame, 'TOP' .. side)
			tex:SetPoint('BOTTOM' .. side, frame, 'BOTTOM' .. side)
			tex:SetWidth(px)
		end
	end
end

---@param lines Texture[]
---@param r number
---@param g number
---@param b number
---@param a? number
function T.ColorBorder(lines, r, g, b, a)
	for _, tex in ipairs(lines) do
		tex:SetVertexColor(r, g, b, a or 1)
	end
end

---@param parent Frame
---@param size number
---@param color? table
---@param layer? string
---@return FontString
function T.Text(parent, size, color, layer)
	local fs = parent:CreateFontString(nil, layer or 'OVERLAY')
	local face = (GameFontNormal and GameFontNormal:GetFont()) or STANDARD_TEXT_FONT
	fs:SetFont(face, size, 'OUTLINE')
	fs:SetShadowColor(0, 0, 0, 0.6)
	fs:SetShadowOffset(1, -1)
	color = color or T.color.text
	fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
	fs:SetWordWrap(false)
	return fs
end

---@param fs FontString
---@param size number
function T.SetTextSize(fs, size)
	local face = (GameFontNormal and GameFontNormal:GetFont()) or STANDARD_TEXT_FONT
	fs:SetFont(face, size, 'OUTLINE')
end

---A small chevron made from two hairlines, pointing toward `direction` (UP, DOWN, LEFT, RIGHT).
---@param parent Frame
---@param color table
---@return table chevron { left, right, SetDirection(direction), Show(), Hide() }
function T.Chevron(parent, color)
	local chevron = {}
	for _, key in ipairs({ 'a', 'b' }) do
		local tex = parent:CreateTexture(nil, 'OVERLAY', nil, 6)
		tex:SetTexture(WHITE)
		tex:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
		tex:SetSize(5, 1.5)
		chevron[key] = tex
	end

	local ROTATION = { UP = 0, RIGHT = -math.pi / 2, DOWN = math.pi, LEFT = math.pi / 2 }
	local EDGE = { UP = 'TOP', DOWN = 'BOTTOM', LEFT = 'LEFT', RIGHT = 'RIGHT' }

	function chevron:SetDirection(direction)
		local turn = ROTATION[direction] or 0
		local edge = EDGE[direction] or 'TOP'
		local inset = 4
		local ox = (edge == 'LEFT' and inset) or (edge == 'RIGHT' and -inset) or 0
		local oy = (edge == 'TOP' and -inset) or (edge == 'BOTTOM' and inset) or 0
		-- Two strokes meet at the tip: "/" and "\" for an upward chevron, rotated for the rest.
		local dx, dy = 1.6 * math.cos(turn), 1.6 * math.sin(turn)
		self.a:ClearAllPoints()
		self.b:ClearAllPoints()
		self.a:SetPoint('CENTER', parent, edge, ox - dx, oy - dy)
		self.b:SetPoint('CENTER', parent, edge, ox + dx, oy + dy)
		self.a:SetRotation(turn + math.pi / 4)
		self.b:SetRotation(turn - math.pi / 4)
	end
	function chevron:Show()
		self.a:Show()
		self.b:Show()
	end
	function chevron:Hide()
		self.a:Hide()
		self.b:Hide()
	end
	chevron:SetDirection('UP')
	return chevron
end
