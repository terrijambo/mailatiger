--!strict
-- The Animal Pen menu: a grid of every animal, with prices, what you own, and what's locked.
-- Opens when the server says so (you used the Pen counter). Picking an animal asks the server, which checks
-- distance, coins and ownership itself.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer

local PenMenu = {}

local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)
local TIER_NAMES = { "Backyard", "Farm", "Wild", "Apex", "Giants", "Silly" }

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

local function round(parent: Instance, radius: number?)
	make("UICorner", { CornerRadius = UDim.new(0, radius or 10) }, parent)
end

local function ownedSet(): { [string]: boolean }
	local set = {}
	local raw = player:GetAttribute("OwnedAnimals")
	if typeof(raw) == "string" then
		for _, id in string.split(raw, ",") do
			set[id] = true
		end
	end
	return set
end

local function coins(): number
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild("Coins") :: IntValue?
	return if value then value.Value else 0
end

function PenMenu.Start()
	local gui =
		make("ScreenGui", { Name = "PenMenu", ResetOnSpawn = false, Enabled = false }, player:WaitForChild("PlayerGui"))
	local requestAnimal = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RequestAnimal") :: RemoteEvent
	local freeInStudio = Config.Dev.FreeAnimalsInStudio and RunService:IsStudio()

	local window = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.75),
		BackgroundColor3 = Color3.fromRGB(250, 240, 220),
	}, gui)
	round(window, 16)
	make("UIStroke", { Thickness = 4, Color = Color3.fromRGB(120, 70, 40) }, window)
	make("UISizeConstraint", { MaxSize = Vector2.new(900, 640) }, window)

	make("TextLabel", {
		Position = UDim2.fromOffset(20, 10),
		Size = UDim2.new(1, -80, 0, 40),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(120, 60, 30),
		Text = if freeInStudio then "Animal Pen  (Studio: everything is free)" else "Animal Pen",
	}, window)

	local close = make("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = Color3.fromRGB(200, 60, 60),
		Font = FONT,
		TextSize = 24,
		TextColor3 = WHITE,
		Text = "X",
	}, window)
	round(close, 20)

	local list = make("ScrollingFrame", {
		Position = UDim2.fromOffset(16, 60),
		Size = UDim2.new(1, -32, 1, -76),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, window)
	make("UIGridLayout", {
		CellSize = UDim2.fromOffset(160, 120),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, list)

	local cards: { [string]: { Button: TextButton, Status: TextLabel } } = {}

	for index, animal in Config.Animals.List do
		local button = make("TextButton", {
			LayoutOrder = index,
			BackgroundColor3 = WHITE,
			AutoButtonColor = true,
			Text = "",
		}, list)
		round(button)

		local swatch = make("Frame", {
			Position = UDim2.fromOffset(10, 10),
			Size = UDim2.fromOffset(36, 36),
			BackgroundColor3 = animal.Color or WHITE,
		}, button)
		round(swatch, 18)
		make("UIStroke", { Thickness = 2, Color = Color3.fromRGB(60, 60, 60) }, swatch)

		make("TextLabel", {
			Position = UDim2.fromOffset(54, 8),
			Size = UDim2.new(1, -60, 0, 24),
			BackgroundTransparency = 1,
			Font = FONT,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(40, 30, 25),
			Text = animal.DisplayName,
		}, button)
		make("TextLabel", {
			Position = UDim2.fromOffset(54, 32),
			Size = UDim2.new(1, -60, 0, 16),
			BackgroundTransparency = 1,
			Font = FONT,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(120, 110, 100),
			Text = `Tier {animal.Tier} · {TIER_NAMES[animal.Tier] or ""}`,
		}, button)
		make("TextLabel", {
			Position = UDim2.fromOffset(10, 54),
			Size = UDim2.new(1, -20, 0, 18),
			BackgroundTransparency = 1,
			Font = FONT,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(90, 80, 70),
			Text = `Pays {animal.BaseValue} · Difficulty {string.rep("★", animal.Tier)}`,
		}, button)
		local status = make("TextLabel", {
			Position = UDim2.new(0, 10, 1, -40),
			Size = UDim2.new(1, -20, 0, 30),
			BackgroundColor3 = Color3.fromRGB(90, 180, 90),
			Font = FONT,
			TextSize = 16,
			TextColor3 = WHITE,
			Text = "",
		}, button)
		round(status, 8)

		button.Activated:Connect(function()
			requestAnimal:FireServer(animal.Id)
			gui.Enabled = false
		end)
		cards[animal.Id] = { Button = button, Status = status }
	end

	local function refresh()
		local owned = ownedSet()
		local myCoins = coins()
		for _, animal in Config.Animals.List do
			local card = cards[animal.Id]
			local status = card.Status
			if animal.Carriers > 1 then
				status.Text = `Needs {animal.Carriers} carriers (soon)`
				status.BackgroundColor3 = Color3.fromRGB(140, 140, 150)
				card.Button.Active = false
			elseif owned[animal.Id] then
				status.Text = "Owned - Box it!"
				status.BackgroundColor3 = Color3.fromRGB(90, 180, 90)
				card.Button.Active = true
			elseif freeInStudio then
				status.Text = "FREE (Studio)"
				status.BackgroundColor3 = Color3.fromRGB(80, 150, 220)
				card.Button.Active = true
			elseif myCoins >= animal.Price then
				status.Text = `Buy: {animal.Price} coins`
				status.BackgroundColor3 = Color3.fromRGB(230, 160, 40)
				card.Button.Active = true
			else
				status.Text = `{animal.Price} coins`
				status.BackgroundColor3 = Color3.fromRGB(170, 90, 80)
				card.Button.Active = true -- the server will say you can't afford it
			end
		end
	end

	close.Activated:Connect(function()
		gui.Enabled = false
	end)

	-- Close the menu once you've started boxing an animal
	player:GetAttributeChangedSignal("Stage"):Connect(function()
		if player:GetAttribute("Stage") ~= "" then
			gui.Enabled = false
		end
	end)

	local notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent
	notify.OnClientEvent:Connect(function(kind: string)
		if kind == "OpenPen" then
			refresh()
			gui.Enabled = true
		end
	end)
end

return PenMenu
