--!strict
-- The game's UI kit: every menu builds its windows, buttons and labels from these, so they all share one
-- chunky, colorful look (thick dark outlines, glossy gradients, bold outlined text).
--   Ui.window       a popup: colored title bar, cream body, red X
--   Ui.button       a chunky glossy button (set BackgroundColor3 to recolor it any time)
--   Ui.sideButton   a big square icon button with a label (PEN, SHOP, ...), like the side buttons in popular sims
--   Ui.icon         a 2D icon from Config/Icons.luau (your image, or an emoji until you add one)
--   Ui.label        plain text for inside windows
--   Ui.outlined     big white text with a dark outline, for the HUD
--   Ui.modelIcon    a little 3D picture of one of your Blender models
-- Screens and devices (phones, consoles, computers):
--   Ui.compact()     true on phones and small windows: the HUD uses its compact layout
--   Ui.margin()      how far HUD pieces stay from the screen edge (more on TVs, which cut off the edges)
--   Ui.inputKind()   "Gamepad", "Touch" or "Keyboard" (what the player used last), Ui.onInputKind(fn)
--   Ui.onResize(fn)  runs fn now and whenever the screen changes size (e.g. a phone rotates)

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local ModelFit = require(ReplicatedStorage.Shared.ModelFit)
local ShardSkin = require(script.Parent.ShardSkin)

local Ui = {}

-- The UIPack Plus look (client/ShardSkin.luau) when the pack is in the place and Config.UiSkin.Shard is on;
-- otherwise the older painted sheet (Ui.skin) or the plain drawn look
local SHARD = ShardSkin.Available() and Config.UiSkin.Shard ~= false
Ui.SHARD = SHARD

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

-- Paints a part of the ForgeGUI skin sheet (Config/UiSkin.luau) behind a frame or button, and hides the
-- frame's own flat background. tint: the painting follows BackgroundColor3 (white parts take the color).
-- Returns nil while the sheet isn't uploaded yet, so callers keep the drawn look.
function Ui.skin(target: GuiObject, partName: string, tint: boolean): ImageLabel?
	local sheet = Config.UiSkin.Sheet
	local part = Config.UiSkin.Parts[partName]
	if sheet == "" or not part then
		return nil
	end
	local image = Ui.make("ImageLabel", {
		Name = "Skin",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = sheet,
		ImageRectOffset = part.Offset,
		ImageRectSize = part.Size,
		ZIndex = 0, -- under everything else inside the target
	}, target)
	local slice = part.Slice
	if slice then
		image.ScaleType = Enum.ScaleType.Slice
		image.SliceCenter = Rect.new(slice[1], slice[2], slice[3], slice[4])
		image.SliceScale = part.SliceScale or 1
		if part.FitHeight then
			local function fit()
				image.SliceScale = math.max(target.AbsoluteSize.Y, 1) / part.Size.Y
			end
			target:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
			fit()
		end
	end
	target.BackgroundTransparency = 1
	-- Code that fades the background (e.g. a button greyed out while it waits) fades the painting instead
	target:GetPropertyChangedSignal("BackgroundTransparency"):Connect(function()
		if target.BackgroundTransparency < 1 then
			image.ImageTransparency = target.BackgroundTransparency
			target.BackgroundTransparency = 1
		end
	end)
	if tint then
		local function recolor()
			image.ImageColor3 = target.BackgroundColor3
		end
		target:GetPropertyChangedSignal("BackgroundColor3"):Connect(recolor)
		recolor()
	end
	-- The painting has its own outline and rounded corners
	for _, child in target:GetChildren() do
		if
			child:IsA("UICorner")
			or child:IsA("UIGradient")
			or (child:IsA("UIStroke") and child.ApplyStrokeMode == Enum.ApplyStrokeMode.Border)
		then
			child:Destroy()
		end
	end
	return image
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

---------------------------------------------------------------------------------------------------
-- Screens and devices

-- The part of the screen the game's UI can use (the whole screen minus Roblox's top bar)
function Ui.viewSize(): Vector2
	local view = workspace.CurrentCamera.ViewportSize
	return Vector2.new(view.X, view.Y - GuiService:GetGuiInset().Y)
end

function Ui.compact(): boolean
	local view = Ui.viewSize()
	return view.Y < 520 or view.X < 900
end

function Ui.margin(): number
	return if GuiService:IsTenFootInterface() then 48 else 14
end

function Ui.onResize(fn: () -> ())
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fn)
	fn()
end

local function kindOf(inputType: Enum.UserInputType): string?
	if string.sub(inputType.Name, 1, 7) == "Gamepad" then
		return "Gamepad"
	elseif inputType == Enum.UserInputType.Touch then
		return "Touch"
	elseif inputType == Enum.UserInputType.Keyboard or string.sub(inputType.Name, 1, 5) == "Mouse" then
		return "Keyboard"
	end
	return nil
end

local currentKind = kindOf(UserInputService:GetLastInputType())
	or (if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then "Touch" else "Keyboard")
local kindChanged = Instance.new("BindableEvent")
UserInputService.LastInputTypeChanged:Connect(function(inputType: Enum.UserInputType)
	local kind = kindOf(inputType)
	if kind and kind ~= currentKind then
		currentKind = kind
		kindChanged:Fire()
	end
end)

function Ui.inputKind(): string
	return currentKind
end

-- Runs fn now and whenever the player switches between gamepad, touch and keyboard/mouse
function Ui.onInputKind(fn: () -> ())
	kindChanged.Event:Connect(fn)
	fn()
end

-- Picks the words for how to do something on the player's device, e.g. Ui.hint("hold E", "hold X", "tap and hold")
function Ui.hint(keyboard: string, gamepad: string, touch: string): string
	return if currentKind == "Gamepad" then gamepad elseif currentKind == "Touch" then touch else keyboard
end

-- A small picture of a controller button (the right one for Xbox or PlayStation), shown only while a
-- gamepad is being used
function Ui.gamepadGlyph(parent: Instance, keyCode: Enum.KeyCode, props: { [string]: any }): ImageLabel
	local base: { [string]: any } = {
		BackgroundTransparency = 1,
		Image = UserInputService:GetImageForKeyCode(keyCode),
		ZIndex = 6,
	}
	for key, value in props do
		base[key] = value
	end
	local glyph = Ui.make("ImageLabel", base, parent)
	Ui.onInputKind(function()
		glyph.Visible = currentKind == "Gamepad"
	end)
	return glyph
end

-- How big windows are drawn: full size on computers and consoles, smaller on phones so more fits
function Ui.windowScale(): number
	local view = Ui.viewSize()
	return math.clamp(math.min(view.Y / 680, view.X / 1000), 0.7, 1)
end

-- A popup window: colored title bar, cream body, red X. Returns the ScreenGui and the content frame.
-- Content starts about 56 px down (below the title bar). maxSize: the biggest it gets (default 900 x 640).
-- On phones the whole window is drawn smaller (Ui.windowScale) and fills more of the screen.
function Ui.window(
	parentGui: Instance,
	name: string,
	title: string,
	color: Color3?,
	maxSize: Vector2?
): (ScreenGui, Frame)
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
		BackgroundColor3 = Ui.PAPER,
	}, gui)
	Ui.round(frame, 18)
	Ui.border(frame, 4)
	local biggest = maxSize or Vector2.new(900, 640)
	local fit = Ui.make("UIScale", { Scale = 1 }, frame)
	Ui.onResize(function()
		local view = Ui.viewSize()
		local scale = Ui.windowScale()
		local share = if Ui.compact() then Vector2.new(0.94, 0.9) else Vector2.new(0.8, 0.75)
		frame.Size = UDim2.fromOffset(
			math.min(biggest.X, view.X * share.X / scale),
			math.min(biggest.Y, view.Y * share.Y / scale)
		)
		fit.Scale = scale
	end)

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
	-- UIPack Plus: a faceted frame in the window's color, its dark header bar, and cream paper for the content
	local shard = SHARD and ShardSkin.Panel(frame, color or Ui.BLUE, 46, true) ~= nil
	if shard then
		for _, child in bar:GetChildren() do
			child:Destroy() -- (the gloss, corner, filler and dark line: the header bar is painted)
		end
		bar.BackgroundTransparency = 1
		bar.Position = UDim2.fromOffset(5, 5)
		bar.Size = UDim2.new(1, -10, 0, 46)
	end
	-- With the painted skin: a cream paper card, and a glossy plaque for a title bar that sits over its top edge
	local painted = not shard and Ui.skin(frame, "Panel", false) ~= nil
	if painted then
		bar.Position = UDim2.fromOffset(10, -10)
		bar.Size = UDim2.new(1, -20, 0, 60)
		filler:Destroy()
		for _, child in bar:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy() -- the dark line under the bar
			end
		end
		Ui.skin(bar, "Ribbon", true)
	end
	Ui.outlined(bar, {
		Name = "Title",
		Position = UDim2.fromOffset(if shard then 24 else 18, if painted then 2 elseif shard then 2 else 4),
		Size = UDim2.new(1, -90, 1, if painted then -14 elseif shard then -8 else -6),
		TextSize = if shard then 28 else 32,
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
	local closeIcon = if SHARD then ShardSkin.Icon("Close") else nil
	if SHARD and ShardSkin.Gem(close, "IconButton") then
		-- A red gem in the header bar's right end, with the pack's white X
		close.AnchorPoint = Vector2.new(1, 0.5)
		close.Position = UDim2.new(1, -12, 0, 28)
		close.Size = UDim2.fromOffset(42, 42)
		if closeIcon then
			close.Text = ""
			Ui.make("ImageLabel", {
				Name = "Icon",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, -2),
				Size = UDim2.fromScale(0.62, 0.62),
				BackgroundTransparency = 1,
				Image = closeIcon,
				ZIndex = 6,
			}, close)
		end
	elseif Ui.skin(close, "Close", false) then
		close.Text = ""
		close.Size = UDim2.fromOffset(54, 54)
	end
	close.Activated:Connect(function()
		gui.Enabled = false
	end)
	Ui.press(close)
	-- Windows pop open with a little bounce instead of just appearing
	gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if gui.Enabled then
			local target = Ui.windowScale()
			fit.Scale = target * 0.85
			TweenService:Create(fit, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = target,
			}):Play()
		end
	end)
	return gui, frame
end

-- A button in a window's title bar, left of the X: flips to a sister window (Shop <-> Premium Store)
function Ui.windowSwitch(frame: Frame, text: string, color: Color3, onClick: () -> ()): TextButton
	local bar = frame:FindFirstChild("TitleBar")
	local title = bar and bar:FindFirstChild("Title")
	if title and title:IsA("TextLabel") then
		title.Size = UDim2.new(1, -230, title.Size.Y.Scale, title.Size.Y.Offset) -- (room for the button)
	end
	local button = Ui.button(frame, {
		Name = "Switch",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -54, 0, 20),
		Size = UDim2.fromOffset(150, 38),
		BackgroundColor3 = color,
		Font = Ui.TITLE_FONT,
		TextSize = 20,
		Text = text,
		ZIndex = 5,
	})
	button.Activated:Connect(onClick)
	return button
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

-- A 2D icon from Config/Icons.luau (e.g. "Button_Pen", "Animal_Tiger"): your uploaded image if you've set
-- its id, otherwise its emoji. `props` sets Size, Position and so on.
function Ui.icon(parent: Instance, key: string, props: { [string]: any }): GuiObject
	local entry = Config.Icons[key]
	local image = entry and entry.Image or ""
	-- Otherwise its cell in an uploaded sprite sheet (tools/pack_icons.py, Config/IconSheets.luau)
	local cell = Config.IconAtlas.Cells[key]
	local sheet = if cell then Config.IconSheets[cell.Sheet] or "" else ""
	local object: GuiObject
	if image ~= "" then
		object = Ui.make("ImageLabel", {
			BackgroundTransparency = 1,
			Image = image,
			ScaleType = Enum.ScaleType.Fit,
		}, parent)
	elseif cell and sheet ~= "" then
		local size = Config.IconAtlas.Size
		object = Ui.make("ImageLabel", {
			BackgroundTransparency = 1,
			Image = sheet,
			ImageRectOffset = Vector2.new(cell.X, cell.Y),
			ImageRectSize = Vector2.new(size, size),
			ScaleType = Enum.ScaleType.Fit,
		}, parent)
	else
		object = Ui.make("TextLabel", {
			BackgroundTransparency = 1,
			Font = Ui.FONT,
			TextScaled = true,
			Text = if entry then entry.Emoji else "❔",
		}, parent)
	end
	for key2, value in props do
		(object :: any)[key2] = value
	end
	return object
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
	Ui.press(button)
	local painted = if SHARD then ShardSkin.Gem(button, "Button") ~= nil else Ui.skin(button, "Button", true) ~= nil
	if not painted then
		Ui.textOutline(button, 2)
		return button
	end
	-- Painted: the button's own text would draw under the painting, so a label on top shows it instead
	-- (button.Text etc. still work as usual: the label copies them). It sits a bit high, above the 3D lip.
	button.TextTransparency = 1
	local label = Ui.make("TextLabel", {
		Name = "Label",
		Size = UDim2.fromScale(1, 0.88),
		BackgroundTransparency = 1,
	}, button)
	Ui.textOutline(label, 2)
	local copied = {
		"Text",
		"TextColor3",
		"TextSize",
		"Font",
		"TextScaled",
		"TextWrapped",
		"RichText",
		"TextXAlignment",
		"TextYAlignment",
	}
	for _, property in copied do
		local function copy()
			(label :: any)[property] = (button :: any)[property]
		end
		button:GetPropertyChangedSignal(property):Connect(copy)
		copy()
	end
	return button
end

-- A big square side button: an icon (a 3D model if you've imported it, otherwise an emoji) with a bold
-- label across the bottom, like PETS / EGGS / SHOP in popular simulators.
export type SideButtonSpec = {
	Label: string,
	Icon: string, -- a key in Config/Icons.luau (e.g. "Button_Pen")
	Color: Color3,
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
	if not (SHARD and ShardSkin.Gem(button, "IconButton")) then
		Ui.skin(button, "Tile", true)
	end
	Ui.icon(button, spec.Icon, {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 5),
		Size = UDim2.fromOffset(54, 50),
	})
	local label = Ui.outlined(button, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 6),
		Size = UDim2.new(1, 4, 0, 26),
		TextScaled = true, -- (long words like UPGRADES shrink to fit)
		Text = spec.Label,
		ZIndex = 3,
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 22 }, label)
	return button
end

-- A red "!" dot in a button's top-right corner (something to claim). Toggle it with .Visible.
function Ui.alertDot(button: GuiObject): Frame
	local dot = Ui.make("Frame", {
		Name = "AlertDot",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = Ui.RED,
		Visible = false,
		ZIndex = 10,
	}, button)
	Ui.round(dot, 14)
	Ui.border(dot, 3)
	Ui.make("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Ui.TITLE_FONT,
		Text = "!",
		TextSize = 22,
		TextColor3 = Ui.WHITE,
		ZIndex = 11,
	}, dot)
	-- A gentle bob so it catches the eye
	local scale = Ui.make("UIScale", {}, dot)
	task.spawn(function()
		while dot.Parent do
			scale.Scale = 1 + 0.12 * math.abs(math.sin(os.clock() * 4))
			task.wait(0.05)
		end
	end)
	return dot
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

-- A HUD panel (white text on it): the pack's solid faceted panel when the UIPack Plus look is on, otherwise the
-- frame keeps its own drawn look. color picks the panel's color family (Ui.GREY = slate).
function Ui.hudPanel(frame: GuiObject, color: Color3): boolean
	return SHARD and ShardSkin.Panel(frame, color, 0, false) ~= nil
end

-- A progress bar in the UIPack Plus look: back is the bar's background, fill its child that grows (width as a
-- fraction). Returns false (and changes nothing) without the pack.
function Ui.bar(back: GuiObject, fill: GuiObject, color: Color3): boolean
	return SHARD and ShardSkin.Bar(back, fill, color)
end

-- A cream card that pops up (a toast, Gruff's speech bubble): the pack's outlined flat plate. No-op without it.
function Ui.plate(frame: GuiObject): boolean
	return SHARD and ShardSkin.Plate(frame) ~= nil
end

-- A text box in the pack's dark input well (its text turns white). No-op without the pack.
function Ui.field(box: TextBox): boolean
	return SHARD and ShardSkin.Field(box)
end

-- A dark see-through plate behind a row of HUD numbers that fits whatever is showing. No-op without the pack.
function Ui.pill(row: GuiObject): boolean
	return SHARD and ShardSkin.Pill(row)
end

-- A colored gem behind a HUD frame (a timer pill): its color comes from BackgroundColor3. No-op without the pack.
function Ui.gem(frame: GuiObject): boolean
	return SHARD and ShardSkin.Gem(frame, "Button") ~= nil
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
	-- UIPack Plus: a flat chamfered plate in the card's color (cards hold dark text, so no gem shading).
	-- Otherwise the painted sheet's glossy plate, tinted to its color.
	if not (SHARD and ShardSkin.Plate(card)) then
		Ui.skin(card, "Button", true)
	end
	return card
end

return Ui
