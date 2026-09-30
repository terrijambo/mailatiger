--!strict
-- The game's UI kit: every menu builds its windows, buttons and labels from these, so they all share one
-- chunky, colorful look (thick dark outlines, glossy gradients, bold outlined text).
--   Ui.window       a popup: colored title bar, cream body, red X
--   Ui.button       a chunky glossy button (set BackgroundColor3 to recolor it any time)
--   Ui.sideButton   a big square icon button with a label (PEN, SHOP, ...), like the side buttons in popular sims
--   Ui.label        plain text for inside windows
--   Ui.outlined     big white text with a dark outline, for the HUD
--   Ui.modelIcon    a little 3D picture of one of your Blender models

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ModelFit = require(ReplicatedStorage.Shared.ModelFit)

local Ui = {}

Ui.FONT = Enum.Font.FredokaOne
Ui.TITLE_FONT = Enum.Font.LuckiestGuy -- big, bold, cartoony: titles and headline numbers
Ui.WHITE = Color3.new(1, 1, 1)
Ui.PAPER = Color3.fromRGB(252, 247, 236)
Ui.INK = Color3.fromRGB(40, 32, 30)
Ui.OUTLINE = Color3.fromRGB(25, 22, 30)
Ui.BROWN = Color3.fromRGB(120, 70, 40)
Ui.GREEN = Color3.fromRGB(70, 205, 85)
Ui.ORANGE = Color3.fromRGB(255, 160, 35)
Ui.RED = Color3.fromRGB(235, 65, 70)
Ui.GREY = Color3.fromRGB(150, 150, 165)
Ui.BLUE = Color3.fromRGB(45, 150, 255)
Ui.PURPLE = Color3.fromRGB(160, 95, 255)
Ui.PINK = Color3.fromRGB(245, 80, 150)
Ui.GOLD = Color3.fromRGB(255, 200, 45)

-- Creates an instance, sets its properties, and parents it.
function Ui.make(className: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Ui.round(parent: Instance, radius: number?)
	Ui.make("UICorner", { CornerRadius = UDim.new(0, radius or 10) }, parent)
end

-- A thick dark outline around a frame or button
function Ui.border(target: Instance, thickness: number?)
	return Ui.make("UIStroke", {
		Thickness = thickness or 3,
		Color = Ui.OUTLINE,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, target)
end

-- A dark outline around text (makes white text readable on anything)
function Ui.textOutline(target: Instance, thickness: number?)
	return Ui.make("UIStroke", {
		Thickness = thickness or 2,
		Color = Ui.OUTLINE,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, target)
end

-- Glossy shading: lighter at the top, darker at the bottom. It multiplies BackgroundColor3, so the color
-- can still be changed later (e.g. a button turning green).
function Ui.gloss(target: Instance)
	return Ui.make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(235, 235, 235)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(175, 175, 175)),
		}),
	}, target)
end

-- Big white text with a dark outline, for the HUD
function Ui.outlined(parent: Instance, props: { [string]: any }): TextLabel
	local base: { [string]: any } = {
		BackgroundTransparency = 1,
		Font = Ui.TITLE_FONT,
		TextSize = 30,
		TextColor3 = Ui.WHITE,
	}
	for key, value in props do
		base[key] = value
	end
	local label = Ui.make("TextLabel", base, parent)
	Ui.textOutline(label, if (base.TextSize :: number) >= 28 then 3 else 2)
	return label
end

-- A popup window: colored title bar, cream body, red X. Returns the ScreenGui and the content frame.
-- Content starts about 56 px down (below the title bar).
function Ui.window(parentGui: Instance, name: string, title: string, color: Color3?): (ScreenGui, Frame)
	local gui = Ui.make("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		Enabled = false,
		DisplayOrder = 3, -- above the HUD
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, -- children draw on top of their parent
	}, parentGui)
	local frame = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.8, 0.75),
		BackgroundColor3 = Ui.PAPER,
	}, gui)
	Ui.round(frame, 18)
	Ui.border(frame, 4)
	Ui.make("UISizeConstraint", { MaxSize = Vector2.new(900, 640) }, frame)

	-- Title bar: rounded on top, square where it meets the body
	local bar = Ui.make("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundColor3 = color or Ui.BLUE,
	}, frame)
	Ui.round(bar, 18)
	Ui.gloss(bar)
	local filler = Ui.make("Frame", {
		Position = UDim2.new(0, 0, 1, -18),
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundColor3 = color or Ui.BLUE,
		BorderSizePixel = 0,
	}, bar)
	Ui.make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(205, 205, 205), Color3.fromRGB(175, 175, 175)),
	}, filler)
	Ui.make("Frame", { -- the dark line under the bar
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 3),
		BackgroundColor3 = Ui.OUTLINE,
		BorderSizePixel = 0,
	}, bar)
	Ui.outlined(bar, {
		Name = "Title",
		Position = UDim2.fromOffset(18, 4),
		Size = UDim2.new(1, -90, 1, -6),
		TextSize = 32,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = title,
	})

	local close = Ui.make("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 8, 0, 6),
		Size = UDim2.fromOffset(48, 48),
		BackgroundColor3 = Ui.RED,
		Font = Ui.TITLE_FONT,
		TextSize = 30,
		TextColor3 = Ui.WHITE,
		Text = "X",
		ZIndex = 5,
	}, frame)
	Ui.round(close, 12)
	Ui.border(close, 3)
	Ui.gloss(close)
	Ui.textOutline(close, 2)
	close.Activated:Connect(function()
		gui.Enabled = false
	end)
	Ui.press(close)
	Ui.pop(gui, frame)
	return gui, frame
end

-- Windows pop open with a little bounce instead of just appearing
function Ui.pop(gui: ScreenGui, frame: GuiObject)
	local scale = Ui.make("UIScale", { Scale = 1 }, frame)
	gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if gui.Enabled then
			scale.Scale = 0.85
			TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
		end
	end)
end

-- Buttons grow a little when you hover and squish while you press them
function Ui.press(button: GuiButton)
	local scale = Ui.make("UIScale", { Scale = 1 }, button)
	local function to(value: number, time: number)
		TweenService:Create(scale, TweenInfo.new(time, Enum.EasingStyle.Back), { Scale = value }):Play()
	end
	button.MouseEnter:Connect(function()
		to(1.05, 0.12)
	end)
	button.MouseLeave:Connect(function()
		to(1, 0.15)
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.08), { Scale = 0.92 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		to(1, 0.15)
	end)
end

-- A little 3D picture of one of your Blender models (e.g. "AnimalModels", "Tiger"), turned to face you.
-- Returns nil if that model isn't imported, so callers can keep a plain fallback.
function Ui.modelIcon(parent: Instance, folderName: string, modelName: string, props: { [string]: any }): ViewportFrame?
	local model = ModelFit.Spawn(folderName, modelName, CFrame.identity, 4, nil)
	if not model then
		return nil
	end
	local viewport = Ui.make("ViewportFrame", {
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(170, 170, 170),
		LightDirection = Vector3.new(-0.4, -1, 0.6),
	}, parent)
	for key, value in props do
		(viewport :: any)[key] = value
	end
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	-- Look at it from the front and a little to the side and above (models face -Z)
	local box, size = model:GetBoundingBox()
	local reach = math.max(size.X, size.Y, size.Z) / 2 / math.tan(math.rad(15)) * 1.15
	local direction = Vector3.new(0.45, 0.35, -1).Unit
	camera.CFrame = CFrame.lookAt(box.Position + direction * reach, box.Position)
	model.Parent = viewport
	return viewport
end

-- A chunky glossy button with outlined text. Set BackgroundColor3 to recolor it (the gloss keeps working).
function Ui.button(parent: Instance, props: { [string]: any }): TextButton
	local base: { [string]: any } = {
		BackgroundColor3 = Ui.ORANGE,
		Font = Ui.FONT,
		TextSize = 18,
		TextColor3 = Ui.WHITE,
		AutoButtonColor = true,
	}
	for key, value in props do
		base[key] = value
	end
	local button = Ui.make("TextButton", base, parent)
	Ui.round(button, 10)
	Ui.border(button, 3)
	Ui.gloss(button)
	Ui.textOutline(button, 2)
	Ui.press(button)
	return button
end

-- A big square side button: an icon (a 3D model if you've imported it, otherwise an emoji) with a bold
-- label across the bottom, like PETS / EGGS / SHOP in popular simulators.
export type SideButtonSpec = {
	Label: string,
	Emoji: string,
	Color: Color3,
	Model: { string }?, -- { folder, model name }, e.g. { "AnimalModels", "Hamster" }
	LayoutOrder: number?,
}

function Ui.sideButton(parent: Instance, spec: SideButtonSpec): TextButton
	local button = Ui.make("TextButton", {
		Name = spec.Label,
		Size = UDim2.fromOffset(78, 78),
		BackgroundColor3 = spec.Color,
		Text = "",
		AutoButtonColor = true,
		LayoutOrder = spec.LayoutOrder or 0,
	}, parent)
	Ui.round(button, 16)
	Ui.border(button, 3)
	Ui.gloss(button)
	Ui.press(button)
	local icon: GuiObject? = nil
	local model = spec.Model
	if model then
		icon = Ui.modelIcon(button, model[1], model[2], {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 2),
			Size = UDim2.fromOffset(58, 58),
		})
	end
	if not icon then
		Ui.make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 6),
			Size = UDim2.fromOffset(52, 46),
			BackgroundTransparency = 1,
			Font = Ui.FONT,
			TextScaled = true,
			Text = spec.Emoji,
		}, button)
	end
	Ui.outlined(button, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 6),
		Size = UDim2.new(1, 12, 0, 26),
		TextSize = 22,
		Text = spec.Label,
		ZIndex = 3,
	})
	return button
end

-- A text label with sensible defaults (for inside windows).
function Ui.label(parent: Instance, props: { [string]: any }): TextLabel
	local base: { [string]: any } = {
		BackgroundTransparency = 1,
		Font = Ui.FONT,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Ui.INK,
		TextWrapped = true,
	}
	for key, value in props do
		base[key] = value
	end
	return Ui.make("TextLabel", base, parent)
end

-- Shrinks a HUD element on small screens (phones) and keeps it full size on big ones. The element shrinks
-- toward its AnchorPoint, so corner-anchored things stay in their corner.
-- How much HUD elements are shrunk on this screen (1 = full size)
function Ui.screenScale(): number
	local size = workspace.CurrentCamera.ViewportSize
	return math.clamp(math.min(size.Y / 800, size.X / 1300), 0.58, 1)
end

function Ui.autoScale(target: GuiObject)
	local scale = Ui.make("UIScale", { Scale = 1 }, target)
	local camera = workspace.CurrentCamera
	local function update()
		scale.Scale = Ui.screenScale()
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	update()
	return scale
end

-- A white rounded card with an outline (a row in a list, a tile in a grid)
function Ui.card(parent: Instance, props: { [string]: any }): Frame
	local base: { [string]: any } = {
		BackgroundColor3 = Ui.WHITE,
	}
	for key, value in props do
		base[key] = value
	end
	local card = Ui.make("Frame", base, parent)
	Ui.round(card, 12)
	Ui.border(card, 2.5)
	return card
end

return Ui
