--!strict
-- Small helpers for building UI in code, shared by the menus.

local Ui = {}

Ui.FONT = Enum.Font.FredokaOne
Ui.WHITE = Color3.new(1, 1, 1)
Ui.PAPER = Color3.fromRGB(250, 240, 220)
Ui.INK = Color3.fromRGB(40, 30, 25)
Ui.BROWN = Color3.fromRGB(120, 70, 40)
Ui.GREEN = Color3.fromRGB(90, 180, 90)
Ui.ORANGE = Color3.fromRGB(230, 160, 40)
Ui.RED = Color3.fromRGB(190, 80, 70)
Ui.GREY = Color3.fromRGB(140, 140, 150)
Ui.BLUE = Color3.fromRGB(80, 150, 220)

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

-- A paper-style popup window with a title and a close button. Returns the ScreenGui and the content frame.
function Ui.window(parentGui: Instance, name: string, title: string): (ScreenGui, Frame)
	local gui = Ui.make("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, -- children draw on top of their parent
	}, parentGui)
	local frame = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.75),
		BackgroundColor3 = Ui.PAPER,
	}, gui)
	Ui.round(frame, 16)
	Ui.make("UIStroke", { Thickness = 4, Color = Ui.BROWN }, frame)
	Ui.make("UISizeConstraint", { MaxSize = Vector2.new(900, 640) }, frame)
	Ui.make("TextLabel", {
		Name = "Title",
		Position = UDim2.fromOffset(20, 10),
		Size = UDim2.new(1, -80, 0, 40),
		BackgroundTransparency = 1,
		Font = Ui.FONT,
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Ui.BROWN,
		Text = title,
	}, frame)
	local close = Ui.make("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = Color3.fromRGB(200, 60, 60),
		Font = Ui.FONT,
		TextSize = 24,
		TextColor3 = Ui.WHITE,
		Text = "X",
	}, frame)
	Ui.round(close, 20)
	close.Activated:Connect(function()
		gui.Enabled = false
	end)
	return gui, frame
end

-- A small colored button.
function Ui.button(parent: Instance, props: { [string]: any }): TextButton
	local base: { [string]: any } = {
		BackgroundColor3 = Ui.ORANGE,
		Font = Ui.FONT,
		TextSize = 16,
		TextColor3 = Ui.WHITE,
		AutoButtonColor = true,
	}
	for key, value in props do
		base[key] = value
	end
	local button = Ui.make("TextButton", base, parent)
	Ui.round(button, 8)
	return button
end

-- A text label with sensible defaults.
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

return Ui
