--!strict
-- The Animal Pen menu: a grid of every animal as chunky cards (3D picture, tier, pay and a PLAY / BUY
-- button). Opens from the PEN side button or the Pen counter. Picking an animal asks the server, which checks
-- coins and ownership itself, then sends you to that animal's arena.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Menus = require(script.Parent.Menus)
local Profile = require(script.Parent.Profile)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local PenMenu = {}

local TIER_NAMES = { "Backyard", "Farm", "Wild", "Apex", "Giants", "Silly" }
local TIER_COLORS = {
	Color3.fromRGB(110, 205, 100),
	Color3.fromRGB(240, 170, 70),
	Color3.fromRGB(60, 175, 120),
	Color3.fromRGB(240, 90, 80),
	Color3.fromRGB(90, 150, 255),
	Color3.fromRGB(190, 110, 255),
}

type Card = { Button: TextButton, Status: TextButton, Icon: GuiObject, Lock: GuiObject }

function PenMenu.Start()
	local gui, window = Ui.window(player:WaitForChild("PlayerGui"), "PenMenu", "Animal Pen", Ui.GREEN)
	local requestAnimal = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RequestAnimal") :: RemoteEvent
	local freeInStudio = Config.Dev.FreeAnimalsInStudio and RunService:IsStudio()
	if freeInStudio then
		local title = window:FindFirstChild("TitleBar") and (window :: any).TitleBar:FindFirstChild("Title")
		if title then
			title.Text = "Animal Pen  (Studio: all free)"
		end
	end

	-- Chaos Mode toggle: +50% pay, but other players can spook your animal and shove you
	local chaos = false
	local chaosButton = Ui.button(window, {
		Position = UDim2.fromOffset(16, 62),
		Size = UDim2.new(1, -32, 0, 38),
		TextSize = 18,
		Text = "",
	})
	local function refreshChaos()
		chaosButton.Text = if chaos
			then "🔥 CHAOS MODE: ON  (+50% pay, but anyone can spook your animal and shove you)"
			else "Chaos Mode: off  (turn on for +50% pay, but others can mess with you)"
		chaosButton.BackgroundColor3 = if chaos then Ui.RED else Ui.GREY
	end
	chaosButton.Activated:Connect(function()
		chaos = not chaos
		refreshChaos()
	end)
	refreshChaos()

	local list = Ui.make("ScrollingFrame", {
		Position = UDim2.fromOffset(12, 110),
		Size = UDim2.new(1, -24, 1, -122),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, window)
	Ui.make("UIGridLayout", {
		CellSize = UDim2.fromOffset(150, 176),
		CellPadding = UDim2.fromOffset(12, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}, list)
	Ui.make("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, list)

	local cards: { [string]: Card } = {}

	for index, animal in Config.Animals.List do
		local tierColor = TIER_COLORS[animal.Tier] or Ui.GREY
		local card = Ui.make("TextButton", {
			LayoutOrder = index,
			BackgroundColor3 = Ui.WHITE,
			AutoButtonColor = false,
			Text = "",
		}, list)
		Ui.round(card, 14)
		Ui.border(card, 3)
		Ui.press(card)
		-- Colored top half behind the picture
		local top = Ui.make("Frame", {
			Size = UDim2.new(1, 0, 0, 92),
			BackgroundColor3 = tierColor,
		}, card)
		Ui.round(top, 14)
		Ui.gloss(top)

		local icon = Ui.icon(card, `Animal_{animal.Id}`, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 8),
			Size = UDim2.fromOffset(80, 76),
			ZIndex = 2,
		})
		-- A padlock over animals whose zone isn't open yet
		local lock = Ui.icon(card, "Hud_Lock", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 26),
			Size = UDim2.fromOffset(28, 28),
			ZIndex = 4,
			Visible = false,
		})
		-- Tier badge in the corner
		local badge = Ui.outlined(card, {
			Position = UDim2.fromOffset(6, 4),
			Size = UDim2.fromOffset(40, 20),
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = `T{animal.Tier}`,
			ZIndex = 3,
		})
		badge.Font = Ui.TITLE_FONT
		if animal.Carriers > 1 then
			Ui.outlined(card, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -6, 0, 4),
				Size = UDim2.fromOffset(60, 20),
				TextSize = 16,
				TextXAlignment = Enum.TextXAlignment.Right,
				Text = `👥{animal.Carriers}`,
				ZIndex = 3,
			})
		end

		Ui.label(card, {
			Position = UDim2.fromOffset(6, 94),
			Size = UDim2.new(1, -12, 0, 24),
			Font = Ui.TITLE_FONT,
			TextSize = 20,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = animal.DisplayName,
		})
		Ui.label(card, {
			Position = UDim2.fromOffset(6, 116),
			Size = UDim2.new(1, -12, 0, 16),
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Color3.fromRGB(110, 100, 95),
			Text = `{TIER_NAMES[animal.Tier] or ""} · pays {Format.Short(animal.BaseValue)}`,
		})
		local status = Ui.button(card, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -16, 0, 32),
			TextSize = 18,
			Text = "",
		})

		local function pick()
			requestAnimal:FireServer(animal.Id, chaos)
			gui.Enabled = false
		end
		card.Activated:Connect(pick)
		status.Activated:Connect(pick)
		cards[animal.Id] = { Button = card, Status = status, Icon = icon, Lock = lock }
	end

	local function refresh()
		local data = Profile.Get()
		for _, animal in Config.Animals.List do
			local card = cards[animal.Id]
			local status = card.Status
			local owned = data.Owned[animal.Id] == true
			local affordable = data.Coins >= animal.Price
			-- The animal's zone opens at a level (Config/Levels.luau)
			local arena = Config.Arenas.ByTier[animal.Tier]
			local needLevel = if arena then Config.Levels.ZoneLevels[arena.Id] or 1 else 1
			local zoneLocked = (data.Level or 1) < needLevel
			if zoneLocked then
				status.Text = `🔒 Lv {needLevel}`
				status.BackgroundColor3 = Ui.GREY
			elseif owned then
				status.Text = "PLAY"
				status.BackgroundColor3 = Ui.GREEN
			elseif freeInStudio then
				status.Text = "FREE (Studio)"
				status.BackgroundColor3 = Ui.BLUE
			elseif affordable then
				status.Text = `BUY {Format.Short(animal.Price)}`
				status.BackgroundColor3 = Ui.ORANGE
			else
				status.Text = `💰 {Format.Short(animal.Price)}`
				status.BackgroundColor3 = Color3.fromRGB(190, 95, 90)
			end
			card.Lock.Visible = zoneLocked
			-- Animals you can't have yet are dimmed
			local dim = zoneLocked or not (owned or freeInStudio or affordable)
			local iconObject = card.Icon
			if iconObject:IsA("ImageLabel") then
				iconObject.ImageColor3 = if dim then Color3.fromRGB(40, 40, 50) else Ui.WHITE
			elseif iconObject:IsA("TextLabel") then
				iconObject.TextTransparency = if dim then 0.55 else 0
			end
		end
	end

	Menus.Register("Pen", gui, refresh)
	Profile.Watch(function()
		if gui.Enabled then
			refresh()
		end
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
			Menus.Open("Pen")
		end
	end)
end

return PenMenu
