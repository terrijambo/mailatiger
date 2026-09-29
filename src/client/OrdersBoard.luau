--!strict
-- Gruff's orders board: shows your current orders, what each needs, and whether it's done.
-- Orders complete automatically when you mail a matching animal.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Profile = require(script.Parent.Profile)
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
	local gui, window = Ui.window(player:WaitForChild("PlayerGui"), "OrdersBoard", "Gruff's Orders")

	local list = Ui.make("Frame", {
		Position = UDim2.fromOffset(20, 60),
		Size = UDim2.new(1, -40, 1, -110),
		BackgroundTransparency = 1,
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
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local profile = Profile.Get()
		for index, order in profile.Orders do
			local animal = Config.Animals.ById[order.AnimalId]
			local frame = Ui.make("Frame", {
				LayoutOrder = index,
				Size = UDim2.new(1, 0, 0, 70),
				BackgroundColor3 = if order.Done then Color3.fromRGB(220, 245, 220) else Ui.WHITE,
			}, list)
			Ui.round(frame)
			Ui.label(frame, {
				Position = UDim2.fromOffset(14, 8),
				Size = UDim2.new(1, -200, 0, 26),
				TextSize = 22,
				Text = `Mail a {if animal then animal.DisplayName else order.AnimalId}`,
			})
			Ui.label(frame, {
				Position = UDim2.fromOffset(14, 38),
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
				Text = if order.Done then "DONE ✓" else `+{order.Reward} coins`,
			})
		end
		local minutes = math.max(0, math.ceil((profile.OrdersRefreshAt - os.time()) / 60))
		footer.Text = `New orders in about {minutes} min. They only ask for animals you own.`
	end

	Profile.Watch(function()
		if gui.Enabled then
			redraw()
		end
	end)

	notify.OnClientEvent:Connect(function(kind: string)
		if kind == "OpenOrders" then
			redraw()
			gui.Enabled = true
		end
	end)
end

return OrdersBoard
