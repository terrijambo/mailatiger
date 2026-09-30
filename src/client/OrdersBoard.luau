--!strict
-- Gruff's orders board: shows your current orders, what each needs, and whether it's done.
-- Orders complete automatically when you mail a matching animal.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Menus = require(script.Parent.Menus)
local Profile = require(script.Parent.Profile)
local QuestText = require(script.Parent.QuestText)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local OrdersBoard = {}

local CONDITION_TEXT = {
	Any = "any rating",
	Stars4 = "with 4+ stamps",
	NoEscape = "without it escaping",
	UnderPar = "under par time",
}

function OrdersBoard.Start()
	local notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent
	local gui, window = Ui.window(player:WaitForChild("PlayerGui"), "OrdersBoard", "Gruff's Orders", Ui.PURPLE)

	local list = Ui.make("ScrollingFrame", {
		Position = UDim2.fromOffset(20, 62),
		Size = UDim2.new(1, -40, 1, -110),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, window)
	Ui.make("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	local footer = Ui.label(window, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -12),
		Size = UDim2.new(1, -40, 0, 30),
		TextColor3 = Color3.fromRGB(110, 100, 90),
		Text = "",
	})

	local function redraw()
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local profile = Profile.Get()

		-- Gruff's main quest, on top in gold
		local quest = QuestText.Current()
		local questCard = Ui.card(list, {
			LayoutOrder = 0,
			Size = UDim2.new(1, 0, 0, 92),
			BackgroundColor3 = Color3.fromRGB(255, 232, 150),
		})
		Ui.icon(questCard, "Hud_Quest", { Position = UDim2.fromOffset(10, 16), Size = UDim2.fromOffset(56, 56) })
		Ui.label(questCard, {
			Position = UDim2.fromOffset(76, 6),
			Size = UDim2.new(1, -200, 0, 20),
			TextSize = 15,
			TextColor3 = Ui.BROWN,
			Text = if quest.Done then "GRUFF'S QUESTS" else `GRUFF'S QUEST #{quest.Number}`,
		})
		Ui.label(questCard, {
			Position = UDim2.fromOffset(76, 26),
			Size = UDim2.new(1, -200, 0, 28),
			Font = Ui.TITLE_FONT,
			TextSize = 24,
			Text = quest.Text,
		})
		local barBack = Ui.make("Frame", {
			Position = UDim2.fromOffset(76, 62),
			Size = UDim2.new(1, -200, 0, 16),
			BackgroundColor3 = Color3.fromRGB(120, 90, 40),
		}, questCard)
		Ui.round(barBack, 8)
		local barFill = Ui.make("Frame", {
			Size = UDim2.fromScale(quest.Fraction, 1),
			BackgroundColor3 = Ui.GREEN,
		}, barBack)
		Ui.round(barFill, 8)
		Ui.gloss(barFill)
		Ui.outlined(questCard, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.fromOffset(110, 60),
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = Ui.GOLD,
			Text = if quest.Done then "" else `{quest.Progress}  +{Format.Short(quest.XP)} XP`,
			TextWrapped = true,
		})

		Ui.label(list, {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 24),
			Font = Ui.TITLE_FONT,
			TextSize = 20,
			TextColor3 = Ui.BROWN,
			Text = "SIDE ORDERS (bonus coins + XP)",
		})
		for index, order in profile.Orders do
			local animal = Config.Animals.ById[order.AnimalId]
			local frame = Ui.card(list, {
				LayoutOrder = index + 1,
				Size = UDim2.new(1, 0, 0, 64),
				BackgroundColor3 = if order.Done then Color3.fromRGB(220, 245, 220) else Ui.WHITE,
			})
			Ui.icon(
				frame,
				`Animal_{order.AnimalId}`,
				{ Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(48, 48) }
			)
			Ui.label(frame, {
				Position = UDim2.fromOffset(68, 6),
				Size = UDim2.new(1, -200, 0, 26),
				TextSize = 22,
				Text = `Mail a {if animal then animal.DisplayName else order.AnimalId}`,
			})
			Ui.label(frame, {
				Position = UDim2.fromOffset(68, 34),
				Size = UDim2.new(1, -200, 0, 22),
				TextColor3 = Color3.fromRGB(110, 100, 90),
				Text = CONDITION_TEXT[order.Condition] or order.Condition,
			})
			Ui.label(frame, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -14, 0.5, 0),
				Size = UDim2.fromOffset(180, 30),
				TextSize = 20,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = if order.Done then Ui.GREEN else Color3.fromRGB(200, 140, 0),
				Text = if order.Done then "DONE ✓" else `+{Format.Short(order.Reward)} coins`,
			})
		end
		local minutes = math.max(0, math.ceil((profile.OrdersRefreshAt - os.time()) / 60))
		footer.Text = `New side orders in about {minutes} min. They only ask for animals you own.`
	end

	-- The ORDERS side button and the board in town both open it. Opening asks the server for fresh orders
	-- if the old ones have expired.
	local shopAction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ShopAction") :: RemoteEvent
	Menus.Register("Orders", gui, function()
		shopAction:FireServer("RefreshOrders")
		redraw()
	end)

	Profile.Watch(function()
		if gui.Enabled then
			redraw()
		end
	end)

	notify.OnClientEvent:Connect(function(kind: string)
		if kind == "OpenOrders" then
			Menus.Open("Orders")
		end
	end)
end

return OrdersBoard
