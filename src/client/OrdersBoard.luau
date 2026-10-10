--!strict
-- Gruff's orders board: shows your current orders, what each needs, and whether it's done.
-- Orders and challenges finish by themselves as you play, then wait here for you to press CLAIM.

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
	local gui, window = Ui.window(player:WaitForChild("PlayerGui"), "OrdersBoard", "Orders & Challenges", Ui.PURPLE)

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

	local shopAction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ShopAction") :: RemoteEvent

	-- A green CLAIM button on the right of a card
	local function claimButton(card: GuiObject, id: string, reward: string)
		local button = Ui.button(card, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(150, 42),
			BackgroundColor3 = Ui.GREEN,
			Text = `CLAIM {reward}`,
			TextSize = 18,
		})
		button.Activated:Connect(function()
			button.Active = false
			button.Text = "..."
			shopAction:FireServer("Claim", id)
		end)
	end

	local function redraw()
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local profile = Profile.Get()

		-- CLAIM ALL, when there's more than one thing waiting
		local waiting = Profile.Claimable(profile)
		if waiting > 1 then
			local all = Ui.button(list, {
				LayoutOrder = -1,
				Size = UDim2.new(1, 0, 0, 46),
				BackgroundColor3 = Ui.GREEN,
				Text = `CLAIM ALL ({waiting})`,
				Font = Ui.TITLE_FONT,
				TextSize = 24,
			})
			all.Activated:Connect(function()
				all.Active = false
				shopAction:FireServer("Claim", "All")
			end)
		end

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

		-- Daily and weekly challenges
		local state = profile.Challenges
		if state then
			local secondsLeft = 86400 - os.time() % 86400
			Ui.label(list, {
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 24),
				Font = Ui.TITLE_FONT,
				TextSize = 20,
				TextColor3 = Ui.BROWN,
				Text = `DAILY CHALLENGES  (new ones in {secondsLeft // 3600}h {secondsLeft % 3600 // 60}m)`,
			})
			local order = 1
			local function challengeCard(
				entry: { Id: string, Progress: number, Done: boolean, Claimed: boolean? },
				weekly: boolean,
				index: number
			)
				local challenge = Config.Challenges.ById[entry.Id]
				if not challenge then
					return
				end
				order += 1
				local card = Ui.card(list, {
					LayoutOrder = order,
					Size = UDim2.new(1, 0, 0, 56),
					BackgroundColor3 = if entry.Done
						then Color3.fromRGB(220, 245, 220)
						elseif weekly then Color3.fromRGB(225, 235, 255)
						else Ui.WHITE,
				})
				Ui.label(card, {
					Position = UDim2.fromOffset(12, 4),
					Size = UDim2.new(1, -170, 0, 24),
					TextSize = 18,
					Text = (if weekly then "WEEKLY: " else "") .. Config.Challenges.Text(challenge),
				})
				local back = Ui.make("Frame", {
					Position = UDim2.fromOffset(12, 32),
					Size = UDim2.new(1, -170, 0, 14),
					BackgroundColor3 = Color3.fromRGB(200, 195, 185),
				}, card)
				Ui.round(back, 7)
				local fill = Ui.make("Frame", {
					Size = UDim2.fromScale(math.clamp(entry.Progress / challenge.Count, 0, 1), 1),
					BackgroundColor3 = if entry.Done then Ui.GREEN else Color3.fromRGB(60, 170, 235),
				}, back)
				Ui.round(fill, 7)
				-- (the same reward the server pays: jobs of the best animal your level allows)
				local coins = Config.Machines.BestValueAt(Profile.Get().Level or 1) * challenge.Jobs
				if entry.Done and entry.Claimed == false then
					claimButton(card, `{if weekly then "W" else "D"}{index}`, Format.Short(coins))
					return
				end
				Ui.label(card, {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -12, 0.5, 0),
					Size = UDim2.fromOffset(150, 40),
					TextSize = 18,
					TextXAlignment = Enum.TextXAlignment.Right,
					TextColor3 = if entry.Done then Ui.GREEN else Ui.BROWN,
					Text = if entry.Done
						then "CLAIMED ✓"
						else `{entry.Progress}/{challenge.Count}   +{Format.Short(coins)}`,
				})
			end
			for index, entry in state.Daily do
				challengeCard(entry, false, index)
			end
			for index, entry in state.Weekly do
				challengeCard(entry, true, index)
			end
			if state.Streak > 0 then
				order += 1
				Ui.label(list, {
					LayoutOrder = order,
					Size = UDim2.new(1, 0, 0, 20),
					TextSize = 15,
					TextColor3 = Color3.fromRGB(110, 100, 90),
					Text = `🔥 All dailies done {state.Streak} day{if state.Streak == 1 then "" else "s"} in a row: the bonus grows each day (up to {Config.Challenges.MaxStreak}).`,
				})
			end
		end

		Ui.label(list, {
			LayoutOrder = 20,
			Size = UDim2.new(1, 0, 0, 24),
			Font = Ui.TITLE_FONT,
			TextSize = 20,
			TextColor3 = Ui.BROWN,
			Text = "SIDE ORDERS (bonus coins + XP)",
		})
		for index, order in profile.Orders do
			local animal = Config.Animals.ById[order.AnimalId]
			local frame = Ui.card(list, {
				LayoutOrder = 20 + index,
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
			if order.Done and order.Claimed == false then
				claimButton(frame, `O{index}`, Format.Short(order.Reward))
				continue
			end
			Ui.label(frame, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -14, 0.5, 0),
				Size = UDim2.fromOffset(180, 30),
				TextSize = 20,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = if order.Done then Ui.GREEN else Color3.fromRGB(200, 140, 0),
				Text = if order.Done then "CLAIMED ✓" else `+{Format.Short(order.Reward)} coins`,
			})
		end
		local minutes = math.max(0, math.ceil((profile.OrdersRefreshAt - os.time()) / 60))
		footer.Text = `New side orders in about {minutes} min. They only ask for animals you own.`
	end

	-- The ORDERS side button and the board in town both open it. Opening asks the server for fresh orders
	-- if the old ones have expired.
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
