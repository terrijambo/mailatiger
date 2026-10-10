--!strict
-- The TASKS panel: a small see-through dashboard on the right side of the screen with Gruff's quest, your
-- daily and weekly challenges, and Gruff's side orders. One short line each, with a thin progress bar.
-- Finished ones get a green CLAIM button right there (CLAIM ALL when more than one is waiting); claimed ones
-- drop off the list. Tap the header to fold it down to just the header (and again to open it).
-- It steps aside while a window is open, during the BOX screen and during Gruff's walkthrough. On phones it
-- starts folded. Gruff's orders board in town opens it too.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Menus = require(script.Parent.Menus)
local Profile = require(script.Parent.Profile)
local QuestText = require(script.Parent.QuestText)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local OrdersBoard = {}

local WIDTH = 270
local ROW = 34
local MAX_BODY = 290 -- taller than this and the list scrolls
local DIM = Color3.fromRGB(190, 185, 210)

local CONDITION_TEXT = {
	Any = "",
	Stars4 = " (4+ stamps)",
	NoEscape = " (no escape)",
	UnderPar = " (under par)",
}

function OrdersBoard.Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local notify = remotes:WaitForChild("Notify") :: RemoteEvent
	local shopAction = remotes:WaitForChild("ShopAction") :: RemoteEvent

	local gui = Ui.make("ScreenGui", {
		Name = "OrdersBoard",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))
	local panel = Ui.make("Frame", {
		Name = "Dashboard",
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(WIDTH, 32),
		BackgroundColor3 = Color3.fromRGB(20, 18, 35),
		BackgroundTransparency = 0.3,
	}, gui)
	Ui.round(panel, 12)
	Ui.make("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.8, Thickness = 1.5 }, panel)
	Ui.autoScale(panel)

	-- Header: tap to fold / unfold
	local header = Ui.make("TextButton", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		Text = "",
	}, panel)
	local title = Ui.outlined(header, {
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -50, 1, 0),
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "📋 TASKS",
	})
	local arrow = Ui.outlined(header, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 0),
		Size = UDim2.fromOffset(30, 32),
		TextSize = 20,
		Text = "–",
	})
	local headerDot = Ui.alertDot(header)
	headerDot.Size = UDim2.fromOffset(20, 20)
	headerDot.Position = UDim2.new(1, -44, 0.5, 0)

	local body = Ui.make("ScrollingFrame", {
		Name = "Body",
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.fromScale(1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, panel)
	Ui.make("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 6),
	}, body)
	local layout = Ui.make("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, body)

	-- (phones start folded: the screen is small)
	local folded = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local function resize()
		local content = layout.AbsoluteContentSize.Y / math.max(Ui.screenScale(), 0.01) + 8
		local height = if folded then 0 else math.min(content, MAX_BODY)
		body.Visible = not folded
		body.Size = UDim2.new(1, 0, 0, height)
		panel.Size = UDim2.fromOffset(if folded then 150 else WIDTH, 32 + height)
		arrow.Text = if folded then "+" else "–"
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resize)

	-- Right side: under the event chip on big screens; a bit lower on phones (the bag is top-right there)
	Ui.onResize(function()
		panel.Position = if Ui.compact() then UDim2.new(1, -Ui.margin(), 0, 130) else UDim2.new(1, -Ui.margin(), 0, 150)
	end)

	local function sectionLabel(order: number, text: string)
		Ui.label(body, {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 18),
			Font = Ui.TITLE_FONT,
			TextSize = 14,
			TextColor3 = DIM,
			Text = text,
		})
	end

	-- One line: what to do, then progress or a CLAIM button, with a thin bar underneath
	local function row(order: number, text: string, right: string, fraction: number, color: Color3, claimId: string?)
		local frame = Ui.make("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, ROW),
			BackgroundTransparency = 1,
		}, body)
		Ui.label(frame, {
			Size = UDim2.new(1, if claimId then -78 else -64, 0, 24),
			TextSize = 15,
			TextColor3 = Ui.WHITE,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = false,
			Text = text,
		})
		if claimId then
			local button = Ui.button(frame, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromOffset(74, 26),
				BackgroundColor3 = Ui.GREEN,
				TextSize = 14,
				Text = "CLAIM",
			})
			button.Activated:Connect(function()
				button.Active = false
				button.Text = "..."
				shopAction:FireServer("Claim", claimId)
			end)
		else
			Ui.label(frame, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromOffset(62, 24),
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = color,
				Text = right,
			})
		end
		local back = Ui.make("Frame", {
			Position = UDim2.fromOffset(0, 26),
			Size = UDim2.new(1, 0, 0, 4),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.8,
			BorderSizePixel = 0,
		}, frame)
		Ui.round(back, 2)
		local fill = Ui.make("Frame", {
			Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
		}, back)
		Ui.round(fill, 2)
	end

	-- What's on the panel right now, as text: it only rebuilds when this changes (the profile updates every
	-- few seconds as the chute pays, and rebuilding each time would make the buttons flicker)
	local shownKey = ""
	local function redraw(force: boolean?)
		local profile = Profile.Get()
		local quest = QuestText.Current()
		local state = profile.Challenges
		local parts = { quest.Text, quest.Progress, tostring(quest.Fraction), tostring(folded) }
		if state then
			for _, entry in state.Daily do
				table.insert(parts, `{entry.Id}{entry.Progress}{entry.Done}{entry.Claimed}`)
			end
			for _, entry in state.Weekly do
				table.insert(parts, `W{entry.Id}{entry.Progress}{entry.Done}{entry.Claimed}`)
			end
		end
		for _, order in profile.Orders do
			table.insert(parts, `O{order.AnimalId}{order.Condition}{order.Done}{order.Claimed}{order.Reward}`)
		end
		table.insert(parts, tostring(math.floor((86400 - os.time() % 86400) / 3600)))
		local key = table.concat(parts, "|")
		local waiting = Profile.Claimable(profile)
		headerDot.Visible = waiting > 0 and folded
		title.Text = if waiting > 0 then `📋 TASKS  ({waiting} ✓)` else "📋 TASKS"
		if key == shownKey and not force then
			return
		end
		shownKey = key
		for _, child in body:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end

		if waiting > 1 then
			local all = Ui.button(body, {
				LayoutOrder = 0,
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundColor3 = Ui.GREEN,
				TextSize = 16,
				Text = `CLAIM ALL ({waiting})`,
			})
			all.Activated:Connect(function()
				all.Active = false
				shopAction:FireServer("Claim", "All")
			end)
		end

		-- Gruff's quest
		sectionLabel(1, if quest.Done then "GRUFF'S QUESTS" else `GRUFF'S QUEST #{quest.Number}`)
		row(2, quest.Text, if quest.Done then "✓" else quest.Progress, quest.Fraction, Ui.GOLD, nil)

		-- Challenges (claimed ones drop off)
		if state then
			local hours = math.floor((86400 - os.time() % 86400) / 3600)
			sectionLabel(10, `CHALLENGES  ·  new in {hours}h`)
			local shown = 0
			local function challenge(entry: any, weekly: boolean, index: number)
				local def = Config.Challenges.ById[entry.Id]
				if not def or (entry.Done and entry.Claimed ~= false) then
					return
				end
				shown += 1
				local text = (if weekly then "W: " else "") .. Config.Challenges.Text(def)
				local claim = if entry.Done and entry.Claimed == false
					then `{if weekly then "W" else "D"}{index}`
					else nil
				row(
					10 + shown,
					text,
					`{entry.Progress}/{def.Count}`,
					entry.Progress / def.Count,
					if weekly then Color3.fromRGB(120, 180, 255) else Color3.fromRGB(110, 220, 120),
					claim
				)
			end
			for index, entry in state.Daily do
				challenge(entry, false, index)
			end
			for index, entry in state.Weekly do
				challenge(entry, true, index)
			end
			if shown == 0 then
				row(11, "✓ All done! New ones tomorrow", "", 1, Ui.GREEN, nil)
			end
		end

		-- Gruff's side orders
		sectionLabel(30, "SIDE ORDERS")
		local orders = 0
		for index, order in profile.Orders do
			if order.Done and order.Claimed ~= false then
				continue
			end
			orders += 1
			local animal = Config.Animals.ById[order.AnimalId]
			row(
				30 + index,
				`Mail a {if animal then animal.DisplayName else order.AnimalId}{CONDITION_TEXT[order.Condition] or ""}`,
				`+{Format.Short(order.Reward)}`,
				if order.Done then 1 else 0,
				Color3.fromRGB(255, 200, 80),
				if order.Done and order.Claimed == false then `O{index}` else nil
			)
		end
		if orders == 0 then
			local minutes = math.max(0, math.ceil((profile.OrdersRefreshAt - os.time()) / 60))
			row(31, `New orders in about {minutes} min`, "", 0, DIM, nil)
		end
		resize()
	end

	local function setFolded(value: boolean)
		folded = value
		if not folded then
			shopAction:FireServer("RefreshOrders") -- (new orders if the old ones ran out)
		end
		redraw(true)
		resize()
	end
	header.Activated:Connect(function()
		setFolded(not folded)
	end)

	-- Out of the way during the walkthrough, the BOX screen and while a window is open
	task.spawn(function()
		while gui.Parent do
			gui.Enabled = not Profile.Learning() and player:GetAttribute("Stage") ~= "Box" and not Menus.AnyOpen()
			task.wait(0.25)
		end
	end)
	Profile.Watch(function()
		redraw()
	end)
	task.spawn(function()
		while gui.Parent do
			task.wait(30)
			redraw() -- (the "new in Nh" timers)
		end
	end)

	-- Gruff's orders board in town (and the d-pad shortcut) open it, with a little pop
	local pop = Ui.make("UIScale", { Scale = 1 }, header)
	local function open()
		setFolded(false)
		pop.Scale = 1.15
		TweenService:Create(pop, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	OrdersBoard.Open = open
	OrdersBoard.Toggle = function()
		setFolded(not folded)
	end
	notify.OnClientEvent:Connect(function(kind: string)
		if kind == "OpenOrders" then
			Menus.CloseAll()
			open()
		end
	end)
	resize()
end

OrdersBoard.Open = function() end -- (replaced in Start)
OrdersBoard.Toggle = function() end -- (replaced in Start)

return OrdersBoard
