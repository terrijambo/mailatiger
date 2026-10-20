--!strict
-- Draws UIPack Plus ("ShardUI", bought: lives in vendor/, synced to ReplicatedStorage.ShardUI) inside the
-- game's own frames and buttons, so every screen built with Ui.luau gets the pack's look without moving any
-- of its layout. Used by Ui.luau; nothing else needs to call this.
--
--   ShardSkin.Available()          false when the pack isn't in the place (a fresh copy of the public code):
--                                  Ui.luau then keeps its older painted / drawn look
--   ShardSkin.Gem(target, kind)    a bevelled gem button (kind "Button" or "IconButton") filling `target`,
--                                  colored by the family nearest to target.BackgroundColor3 (and recolored when
--                                  that changes, so "button turns green" code keeps working)
--   ShardSkin.Panel(target, head)  a window frame: faceted colored border, the dark header bar on top, and a
--                                  cream paper area for the content (the game's text is dark ink on paper)
--   ShardSkin.Plate(target)        a flat chamfered plate with the pack's outline (light cards in lists)
--   ShardSkin.Icon(name)           one of the pack's 3D icons (e.g. "Close", "Coin"), or nil
--
-- The pack's pieces are drawn at 2x and 9-sliced. Their corners are a fixed size, so small pieces get
-- their corners scaled down to fit (Ui.luau's buttons are often smaller than the pack's own).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShardSkin = {}

local Geometry: any, Assets: any, Palette: any, Icons: any = nil, nil, nil, nil
do
	local pack = ReplicatedStorage:FindFirstChild("ShardUI")
	local shared = pack and pack:FindFirstChild("Shared")
	if shared then
		local ok = pcall(function()
			Geometry = require(shared:FindFirstChild("Geometry") :: ModuleScript) :: any
			Assets = require(shared:FindFirstChild("Assets") :: ModuleScript) :: any
			Palette = require(shared:FindFirstChild("Palette") :: ModuleScript) :: any
			Icons = require(shared:FindFirstChild("Icons") :: ModuleScript) :: any
		end)
		if not ok then
			Geometry = nil
		end
	end
end

local PAPER = Color3.fromRGB(252, 247, 236)
local LIGHT = 0.82 -- colors brighter than this (white, cream) are "paper", not a gem family

function ShardSkin.Available(): boolean
	return Geometry ~= nil
end

function ShardSkin.Icon(name: string): string?
	return if Icons then Icons[name] else nil
end

-- The pack family closest to a color (the game passes its own colors: Ui.GREEN, Ui.ORANGE...)
local function familyFor(color: Color3, families: { [string]: any }): (string, any)
	local bestName, best, bestDistance = "slate", families.slate, math.huge
	for name, family in families do
		local m: Color3 = family.m
		local distance = (m.R - color.R) ^ 2 + (m.G - color.G) ^ 2 + (m.B - color.B) ^ 2
		if distance < bestDistance then
			bestName, best, bestDistance = name, family, distance
		end
	end
	return bestName, best
end

local function isLight(color: Color3): boolean
	local _, saturation, value = color:ToHSV()
	return value > LIGHT and saturation < 0.25
end

-- Three hard color bands on a 60 degree slant: the pack's faceted look
local function bands(family: any, gradient: UIGradient?, cuts: { number }): UIGradient
	local g = gradient or Instance.new("UIGradient")
	g.Rotation = 60
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, family.l),
		ColorSequenceKeypoint.new(cuts[1], family.l),
		ColorSequenceKeypoint.new(cuts[1] + 0.01, family.m),
		ColorSequenceKeypoint.new(cuts[2], family.m),
		ColorSequenceKeypoint.new(cuts[2] + 0.01, family.d),
		ColorSequenceKeypoint.new(1, family.d),
	})
	return g
end

local function layer(parent: Instance, name: string, image: string, slice: Rect, z: number): ImageLabel
	local img = Instance.new("ImageLabel")
	img.Name = name
	img.BackgroundTransparency = 1
	img.Image = image
	img.ScaleType = Enum.ScaleType.Slice
	img.SliceCenter = slice
	img.SliceScale = 1 / Geometry.Scale
	img.Size = UDim2.fromScale(1, 1)
	img.ZIndex = z
	img.Parent = parent
	return img
end

-- How much a 9-slice's corners must shrink so they fit in `size` (1 = the pack's own size)
local function cornerFit(spec: any, size: Vector2): number
	local w, h = spec.Size.X * Geometry.Scale, spec.Size.Y * Geometry.Scale
	local slice: Rect = spec.Slice
	local across = slice.Min.X + (w - slice.Max.X)
	local down = slice.Min.Y + (h - slice.Max.Y)
	return math.min(1, size.X * Geometry.Scale / math.max(across, 1), size.Y * Geometry.Scale / math.max(down, 1))
end

-- Clears the frame's own drawn look (the painting has its own outline and corners)
local function clear(target: GuiObject)
	target.BackgroundTransparency = 1
	for _, child in target:GetChildren() do
		if
			child:IsA("UICorner")
			or child:IsA("UIGradient")
			-- (on a text object a contextual stroke outlines the text: keep that; on a frame every stroke is a border)
			or (child:IsA("UIStroke") and (child.ApplyStrokeMode == Enum.ApplyStrokeMode.Border or not target:IsA(
				"TextButton"
			)))
			or child.Name == "Skin"
		then
			child:Destroy()
		end
	end
end

-- A holder for the layers, under everything else inside the target. A target that lays its children out
-- (a grid or list of buttons) would treat the holder as one more cell, so then (and for text boxes) it sits right behind
-- the target instead, as a sibling that copies its place, size, visibility and pop-open scale.
local function holder(target: GuiObject): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Shard"
	frame.BackgroundTransparency = 1
	-- (a text box draws its typed text under its own children, so it also gets the painting behind it)
	if not (target:IsA("TextBox") or target:FindFirstChildWhichIsA("UIGridStyleLayout")) then
		frame.Size = UDim2.fromScale(1, 1)
		frame.ZIndex = 0
		frame.Parent = target
		return frame
	end
	frame.Name = `{target.Name}Shard`
	local scale = Instance.new("UIScale")
	scale.Parent = frame
	local targetScale = target:FindFirstChildWhichIsA("UIScale")
	local function follow()
		frame.AnchorPoint = target.AnchorPoint
		frame.Position = target.Position
		frame.Size = target.Size
		frame.Visible = target.Visible
		frame.ZIndex = target.ZIndex - 1
		frame.LayoutOrder = target.LayoutOrder
		scale.Scale = if targetScale then targetScale.Scale else 1
	end
	for _, property in { "AnchorPoint", "Position", "Size", "Visible", "ZIndex" } do
		target:GetPropertyChangedSignal(property):Connect(follow)
	end
	if targetScale then
		targetScale:GetPropertyChangedSignal("Scale"):Connect(follow)
	end
	follow()
	frame.Parent = target.Parent
	target.AncestryChanged:Connect(function()
		frame.Parent = target.Parent
	end)
	return frame
end

-- Code that fades a background (a button greyed out while it waits) fades the painting instead
local function followFade(target: GuiObject, layers: { ImageLabel })
	local rest: { [ImageLabel]: number } = {}
	for _, img in layers do
		rest[img] = img.ImageTransparency
	end
	target:GetPropertyChangedSignal("BackgroundTransparency"):Connect(function()
		local fade = target.BackgroundTransparency
		if fade < 1 then
			for _, img in layers do
				img.ImageTransparency = 1 - (1 - rest[img]) * (1 - fade)
			end
			target.BackgroundTransparency = 1
		end
	end)
end

function ShardSkin.Gem(target: GuiObject, kind: string): ImageLabel?
	if not Geometry then
		return nil
	end
	local function pick(size: Vector2): string
		if kind == "IconButton" then
			local side = math.min(size.X, size.Y)
			return if side < 68 then "sm" elseif side < 92 then "md" else "lg"
		end
		return if size.Y < 64 then "sm" elseif size.Y < 90 then "md" else "big"
	end
	-- (before it's on screen, AbsoluteSize is still 0: read the size it was given instead)
	local given = Vector2.new(target.Size.X.Offset, target.Size.Y.Offset)
	local variant = pick(if target.AbsoluteSize.Y > 1 then target.AbsoluteSize else given)
	local geo = Geometry[kind][variant]
	local ids = Assets[kind][variant]
	local L = geo.Layers
	clear(target)
	local root = holder(target)

	local shadow = layer(root, "Shadow", ids.outline, L.outline.Slice, 0)
	shadow.ImageColor3 = Color3.new(0, 0, 0)
	shadow.ImageTransparency = 0.74
	local outline = layer(root, "Outline", ids.outline, L.outline.Slice, 1)
	outline.ImageColor3 = Palette.Line
	local body = layer(root, "Body", ids.body, L.body.Slice, 2)
	local face = layer(root, "Face", ids.face, L.face.Slice, 3)
	local shading = layer(face, "Shading", ids.faceShading, L.faceShading.Slice, 4)
	local gradient = bands(Palette.Families.slate, nil, { 0.28, 0.57 })
	gradient.Parent = face

	local function fit()
		local size = target.AbsoluteSize
		if size.X < 2 or size.Y < 2 then
			return
		end
		local s = math.min(cornerFit(L.outline, size), cornerFit(L.face, size))
		local px = 1 / Geometry.Scale * s
		for _, img in { shadow, outline, body, face, shading } do
			img.SliceScale = px
		end
		local inset = math.max(2, math.floor(4 * s + 0.5))
		local depth = math.max(2, math.floor(geo.Depth * s + 0.5))
		shadow.Position = UDim2.fromOffset(0, math.max(1, math.floor(geo.Shadow * s + 0.5)))
		body.Position = UDim2.fromOffset(inset, inset)
		body.Size = UDim2.new(1, -inset * 2, 1, -inset * 2)
		face.Position = UDim2.fromOffset(inset, inset)
		face.Size = UDim2.new(1, -inset * 2, 1, -inset * 2 - depth)
	end
	target:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()

	local function recolor()
		local name, family = familyFor(target.BackgroundColor3, Palette.Families)
		if isLight(target.BackgroundColor3) then
			name, family = "slate", Palette.Families.slate
		end
		body.ImageColor3 = family.b
		bands(family, gradient, { 0.28, 0.57 })
		target:SetAttribute("ShardFamily", name)
	end
	target:GetPropertyChangedSignal("BackgroundColor3"):Connect(recolor)
	recolor()
	followFade(target, { shadow, outline, body, face, shading })
	return face
end

-- A window frame. head: how tall the header bar is (the game's title bar; 0 = none). paper: a cream area for
-- dark text under the header (windows); without it, white text sits right on the colored frame (HUD panels).
-- Returns the frame layer.
function ShardSkin.Panel(target: GuiObject, color: Color3, head: number, withPaper: boolean?): ImageLabel?
	if not Geometry then
		return nil
	end
	local geo = Geometry.Panel.md
	local ids = Assets.Panel.md
	local L = geo.Layers
	clear(target)
	local root = holder(target)
	local _, family = familyFor(color, Palette.Panels)

	local shadow = layer(root, "Shadow", ids.outline, L.outline.Slice, 0)
	shadow.Position = UDim2.fromOffset(0, geo.Shadow)
	shadow.ImageColor3 = Color3.new(0, 0, 0)
	shadow.ImageTransparency = 0.74
	local outline = layer(root, "Outline", ids.outline, L.outline.Slice, 1)
	outline.ImageColor3 = Palette.Line
	local frame = layer(root, "Frame", ids.frame, L.frame.Slice, 2)
	frame.Position = UDim2.fromOffset(geo.Pad, geo.Pad)
	frame.Size = UDim2.new(1, -geo.Pad * 2, 1, -geo.Pad * 2)
	bands(family, nil, { 0.23, 0.57 }).Parent = frame
	local shading = layer(frame, "Shading", ids.frameShading, L.frameShading.Slice, 3)
	if head > 0 then
		local bar = layer(frame, "Head", ids.head, L.head.Slice, 4)
		bar.Size = UDim2.new(1, 0, 0, head)
	end
	-- Small panels (a collapsed HUD panel is 32 px tall) get smaller corners
	local function fit()
		local s = cornerFit(L.outline, target.AbsoluteSize)
		for _, img in { shadow, outline, frame, shading } do
			img.SliceScale = 1 / Geometry.Scale * s
		end
	end
	target:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	followFade(target, { shadow, outline, frame, shading })
	if not withPaper then
		return frame
	end

	-- The cream paper the content sits on: the same chamfered shape, outlined, inside the colored frame
	local paperOutline = layer(root, "PaperOutline", ids.outline, L.outline.Slice, 5)
	paperOutline.ImageColor3 = Palette.Line
	paperOutline.SliceScale = 1 / Geometry.Scale * 0.6
	paperOutline.Position = UDim2.fromOffset(12, geo.Pad + head + 1)
	paperOutline.Size = UDim2.new(1, -24, 1, -geo.Pad - head - 13)
	local paper = layer(paperOutline, "Paper", ids.frame, L.frame.Slice, 6)
	paper.SliceScale = 1 / Geometry.Scale * 0.6
	paper.ImageColor3 = PAPER
	paper.Position = UDim2.fromOffset(3, 3)
	paper.Size = UDim2.new(1, -6, 1, -6)
	return frame
end

-- A progress bar: the pack's dark shell and sunken track inside `back`, and its banded fill inside `fill`
-- (a child of back whose width the game tweens, e.g. Size = (fraction, 0, 1, 0))
function ShardSkin.Bar(back: GuiObject, fill: GuiObject, color: Color3): boolean
	if not Geometry then
		return false
	end
	local geo = Geometry.Bar.md
	local ids = Assets.Bar.md
	local L = geo.Layers
	clear(back)
	clear(fill)
	local root = holder(back)
	local shell = layer(root, "Shell", ids.shell, L.shell.Slice, 0)
	shell.ImageColor3 = Palette.Line
	local track = layer(root, "Track", ids.track, L.track.Slice, 1)
	local pad = 3
	track.Position = UDim2.fromOffset(pad, pad)
	track.Size = UDim2.new(1, -pad * 2, 1, -pad * 2)
	-- The fill frame keeps its own size (the game animates it); its picture sits inside the shell's padding
	fill.Position = UDim2.fromOffset(pad, 0)
	local picture = layer(fill, "Fill", ids.fill, L.fill.Slice, 2)
	picture.Position = UDim2.fromOffset(0, pad)
	picture.Size = UDim2.new(1, -pad * 2, 1, -pad * 2)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Parent = picture
	-- The fill's color can change as it fills (the ANGER meter goes green to red): it follows the fill's
	-- BackgroundColor3 (still set by the game, though the frame itself is no longer drawn)
	local shown = ""
	local function recolor(from: Color3)
		local name, family = familyFor(from, Palette.Families)
		if name == shown then
			return
		end
		shown = name
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, family.l),
			ColorSequenceKeypoint.new(0.32, family.l),
			ColorSequenceKeypoint.new(0.33, family.m),
			ColorSequenceKeypoint.new(0.66, family.m),
			ColorSequenceKeypoint.new(0.67, family.d),
			ColorSequenceKeypoint.new(1, family.d),
		})
	end
	recolor(color)
	fill:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
		recolor(fill.BackgroundColor3)
	end)
	local function fit()
		local s = cornerFit(L.shell, back.AbsoluteSize)
		shell.SliceScale = 1 / Geometry.Scale * s
		track.SliceScale = 1 / Geometry.Scale * s
		picture.SliceScale = 1 / Geometry.Scale * math.min(s, cornerFit(L.fill, picture.AbsoluteSize))
	end
	back:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fill:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	return true
end

-- A flat plate: the pack's outline around one color (cards in lists, which hold dark text)
function ShardSkin.Plate(target: GuiObject): ImageLabel?
	if not Geometry then
		return nil
	end
	local geo = Geometry.Panel.md
	local ids = Assets.Panel.md
	local L = geo.Layers
	local color = target.BackgroundColor3
	clear(target)
	local root = holder(target)
	local outline = layer(root, "Outline", ids.outline, L.outline.Slice, 1)
	outline.ImageColor3 = Palette.Line
	local plate = layer(root, "Plate", ids.frame, L.frame.Slice, 2)
	plate.Position = UDim2.fromOffset(3, 3)
	plate.Size = UDim2.new(1, -6, 1, -6)
	local function fit()
		local s = math.min(0.55, cornerFit(L.outline, target.AbsoluteSize))
		outline.SliceScale = 1 / Geometry.Scale * s
		plate.SliceScale = 1 / Geometry.Scale * s
	end
	target:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	local function recolor()
		plate.ImageColor3 = target.BackgroundColor3
	end
	target:GetPropertyChangedSignal("BackgroundColor3"):Connect(recolor)
	target.BackgroundColor3 = color
	recolor()
	followFade(target, { outline, plate })
	return plate
end

-- A text box: the pack's dark sunken input well (white text on it)
function ShardSkin.Field(target: TextBox): boolean
	if not Geometry then
		return false
	end
	local function pick(height: number): string
		return if height < 54 then "sm" elseif height < 66 then "md" else "lg"
	end
	local given = if target.AbsoluteSize.Y > 1 then target.AbsoluteSize.Y else target.Size.Y.Offset
	local size = pick(given)
	local geo = Geometry.Field[size]
	local ids = Assets.Field[size]
	local L = geo.Layers
	clear(target)
	local root = holder(target)
	local shell = layer(root, "Shell", ids.shell, L.shell.Slice, 0)
	shell.ImageColor3 = Palette.Line
	local plate = layer(root, "Plate", ids.plate, L.plate.Slice, 1)
	plate.Position = UDim2.fromOffset(geo.Pad, geo.Pad)
	plate.Size = UDim2.new(1, -geo.Pad * 2, 1, -geo.Pad * 2)
	local function fit()
		local s = cornerFit(L.shell, target.AbsoluteSize)
		shell.SliceScale = 1 / Geometry.Scale * s
		plate.SliceScale = 1 / Geometry.Scale * s
	end
	target:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	target.TextColor3 = Color3.new(1, 1, 1)
	target.PlaceholderColor3 = Color3.fromRGB(170, 180, 205)
	return true
end

-- A dark see-through plate behind a row of HUD numbers and icons, resized to what's showing in it (a coin
-- count grows and shrinks). Only things that draw count: text (by its actual words), images and viewports.
function ShardSkin.Pill(row: GuiObject): boolean
	if not Geometry then
		return false
	end
	local ids = Assets.Panel.md
	local L = Geometry.Panel.md.Layers
	local root = Instance.new("Frame")
	root.Name = "Pill"
	root.BackgroundTransparency = 1
	root.ZIndex = 0
	root.Parent = row
	local outline = layer(root, "Outline", ids.outline, L.outline.Slice, 0)
	outline.ImageColor3 = Palette.Line
	outline.ImageTransparency = 0.25
	local plate = layer(root, "Plate", ids.frame, L.frame.Slice, 0)
	plate.ImageColor3 = Palette.Families.slate.b
	plate.ImageTransparency = 0.3
	plate.Position = UDim2.fromOffset(3, 3)
	plate.Size = UDim2.new(1, -6, 1, -6)
	local PAD_X, PAD_Y = 10, 2

	local function shows(object: GuiObject): boolean
		local node: Instance? = object
		while node and node ~= row do
			if node:IsA("GuiObject") and not node.Visible then
				return false
			end
			node = node.Parent
		end
		return true
	end
	local function refresh()
		local scale = if row.Size.X.Offset > 0 then row.AbsoluteSize.X / row.Size.X.Offset else 1
		if scale <= 0 or not row.Visible then
			return
		end
		local left, top, right, bottom = math.huge, math.huge, -math.huge, -math.huge
		for _, d in row:GetDescendants() do
			if
				(d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("ImageLabel") or d:IsA("ImageButton"))
				and not d:IsDescendantOf(root)
				and d.AbsoluteSize.X > 1
				and shows(d)
			then
				local x0, x1 = d.AbsolutePosition.X, d.AbsolutePosition.X + d.AbsoluteSize.X
				if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" and not d.TextScaled then
					local w = math.min(d.TextBounds.X, d.AbsoluteSize.X)
					if d.TextXAlignment == Enum.TextXAlignment.Left then
						x1 = x0 + w
					elseif d.TextXAlignment == Enum.TextXAlignment.Right then
						x0 = x1 - w
					else
						local middle = (x0 + x1) / 2
						x0, x1 = middle - w / 2, middle + w / 2
					end
				elseif
					(d:IsA("TextLabel") or d:IsA("TextButton"))
					and d.Text == ""
					and d.BackgroundTransparency >= 1
				then
					continue
				end
				left = math.min(left, x0)
				right = math.max(right, x1)
				top = math.min(top, d.AbsolutePosition.Y)
				bottom = math.max(bottom, d.AbsolutePosition.Y + d.AbsoluteSize.Y)
			end
		end
		if left == math.huge then
			root.Visible = false
			return
		end
		root.Visible = true
		local origin = row.AbsolutePosition
		root.Position = UDim2.fromOffset((left - origin.X) / scale - PAD_X, (top - origin.Y) / scale - PAD_Y)
		root.Size = UDim2.fromOffset((right - left) / scale + PAD_X * 2, (bottom - top) / scale + PAD_Y * 2)
		local s = math.min(0.4, cornerFit(L.outline, root.AbsoluteSize))
		outline.SliceScale = 1 / Geometry.Scale * s
		plate.SliceScale = 1 / Geometry.Scale * s
	end
	task.spawn(function()
		while root.Parent do
			refresh()
			task.wait(0.2)
		end
	end)
	return true
end

-- Light colors (white, cream) are plates; everything else is a gem
function ShardSkin.IsLight(color: Color3): boolean
	return isLight(color)
end

return ShardSkin
