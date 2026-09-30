--!strict
-- Your inventory (the BAG side button): everything you own, in tabs.
--   Trolls   your troll items and their hotbar keys (locked ones show the level they unlock at)
--   Boxes    your mail boxes: equip one for your next job
--   Stamps   how many of each stamp you have, and which one your next job uses
--   Tools    your tool levels and what they do right now
--   Animals  your collection: every animal you've mailed, and how many (the rest are mystery silhouettes)
-- Buying happens in the Supply Shop; this is where you see and use what you have.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Menus = require(script.Parent.Menus)
local Profile = require(script.Parent.Profile)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local Inventory = {}

local TABS = { "Trolls", "Boxes", "Stamps", "Tools", "Animals" }

function Inventory.Start()
	local shopAction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ShopAction") :: RemoteEvent
	local gui, window = Ui.window(player:WaitForChild("PlayerGui"), "Inventory", "Your Bag", Ui.PINK)

	local tabBar = Ui.make("Frame", {
		Position = UDim2.fromOffset(20, 60),
		Size = UDim2.new(1, -40, 0, 36),
		BackgroundTransparency = 1,
	}, window)
	Ui.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }, tabBar)

	local list = Ui.make("ScrollingFrame", {
		Position = UDim2.fromOffset(20, 104),
		Size = UDim2.new(1, -40, 1, -120),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, window)

	local current = "Trolls"
	local tabButtons: { [string]: TextButton } = {}

	local function clear()
		-- (layouts too: the Animals tab is a grid, the others are lists)
		for _, child in list:GetChildren() do
			child:Destroy()
		end
	end

	-- A row: icon, title, a line of detail, and an optional button
	local function row(order: number, icon: string, title: string, detail: string): Frame
		local card = Ui.card(list, {
			LayoutOrder = order,
			Size = UDim2.new(1, -12, 0, 66),
			BackgroundColor3 = Ui.WHITE,
		})
		Ui.icon(card, icon, { Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(50, 50) })
		Ui.label(card, {
			Position = UDim2.fromOffset(70, 6),
			Size = UDim2.new(1, -230, 0, 26),
			TextSize = 20,
			Text = title,
		})
		Ui.label(card, {
			Position = UDim2.fromOffset(70, 32),
			Size = UDim2.new(1, -230, 0, 28),
			TextSize = 14,
			TextColor3 = Color3.fromRGB(110, 100, 90),
			Text = detail,
		})
		return card
	end

	local function rowButton(card: Frame, text: string, color: Color3, onClick: (() -> ())?)
		local button = Ui.button(card, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(140, 40),
			BackgroundColor3 = color,
			Text = text,
		})
		if onClick then
			button.Activated:Connect(onClick)
		else
			button.AutoButtonColor = false
		end
	end

	local function redraw()
		clear()
		for name, button in tabButtons do
			button.BackgroundColor3 = if name == current then Ui.PINK else Ui.GREY
		end
		local data = Profile.Get()

		if current == "Animals" then
			-- The collection: a grid of every animal
			Ui.make("UIGridLayout", {
				CellSize = UDim2.fromOffset(118, 132),
				CellPadding = UDim2.fromOffset(10, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			}, list)
			local collected = 0
			for index, animal in Config.Animals.List do
				local mailed = (data.Species or {})[animal.Id] or 0
				if mailed > 0 then
					collected += 1
				end
				local card = Ui.card(list, {
					LayoutOrder = index,
					BackgroundColor3 = if mailed > 0 then Ui.WHITE else Color3.fromRGB(215, 215, 225),
				})
				local icon = Ui.icon(card, `Animal_{animal.Id}`, {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, 8),
					Size = UDim2.fromOffset(70, 66),
				})
				if mailed == 0 then
					-- Not mailed yet: a mystery silhouette
					if icon:IsA("ImageLabel") then
						icon.ImageColor3 = Color3.fromRGB(30, 30, 40)
					elseif icon:IsA("TextLabel") then
						icon.TextTransparency = 0.8
					end
				end
				Ui.label(card, {
					Position = UDim2.fromOffset(4, 78),
					Size = UDim2.new(1, -8, 0, 22),
					Font = Ui.TITLE_FONT,
					TextSize = 17,
					TextXAlignment = Enum.TextXAlignment.Center,
					Text = if mailed > 0 then animal.DisplayName else "???",
				})
				Ui.label(card, {
					Position = UDim2.fromOffset(4, 102),
					Size = UDim2.new(1, -8, 0, 20),
					TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextColor3 = Color3.fromRGB(110, 100, 90),
					Text = if mailed > 0 then `Mailed ×{Format.Short(mailed)}` else `Tier {animal.Tier}`,
				})
			end
			local title = (window:FindFirstChild("TitleBar") :: Frame):FindFirstChild("Title") :: TextLabel
			title.Text = `Your Bag  ·  Collection {collected}/{#Config.Animals.List}`
			return
		end
		local title = (window:FindFirstChild("TitleBar") :: Frame):FindFirstChild("Title") :: TextLabel
		title.Text = "Your Bag"
		Ui.make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)

		if current == "Trolls" then
			local keyIndex = 0
			for index, troll in Config.Trolls.List do
				local owned = (data.Trolls or {})[troll.Id]
				if owned then
					keyIndex += 1
				end
				local card = row(
					index,
					`Troll_{troll.Id}`,
					troll.DisplayName,
					`{troll.Description} ({troll.Cooldown}s cooldown)`
				)
				if owned then
					rowButton(card, `Key {keyIndex}`, Ui.GREEN, nil)
				elseif (data.Level or 1) < troll.Level then
					rowButton(card, `🔒 Level {troll.Level}`, Ui.GREY, nil)
				else
					rowButton(card, "Buy in Shop", Ui.ORANGE, function()
						Menus.Open("Shop")
					end)
				end
			end
			Ui.label(list, {
				LayoutOrder = 99,
				Size = UDim2.new(1, -12, 0, 40),
				TextSize = 14,
				TextColor3 = Color3.fromRGB(110, 100, 90),
				Text = "Troll items only work on players who turned on Chaos Mode (in the Pen). Use them from the hotbar or keys 1-5.",
			})
		elseif current == "Boxes" then
			for index, box in Config.Boxes.List do
				local card = row(
					index,
					`Box_{box.Id}`,
					box.DisplayName,
					`Animals start at {box.StartAnger} anger and get angry {math.round(box.AngerMult * 100)}% as fast`
				)
				if data.EquippedBox == box.Id then
					rowButton(card, "Equipped ✓", Ui.GREEN, nil)
				elseif data.Boxes[box.Id] then
					rowButton(card, "Equip", Ui.BLUE, function()
						shopAction:FireServer("EquipBox", box.Id)
					end)
				else
					rowButton(card, "Buy in Shop", Ui.ORANGE, function()
						Menus.Open("Shop")
					end)
				end
			end
		elseif current == "Stamps" then
			for index, stamp in Config.Stamps.List do
				local count = data.Stamps[stamp.Id] or 0
				local card = row(index, `Stamp_{stamp.Id}`, `{stamp.DisplayName}  ×{count}`, stamp.Description)
				if data.SelectedStamp == stamp.Id then
					rowButton(card, "Next job ✓", Ui.GREEN, function()
						shopAction:FireServer("SelectStamp", "")
					end)
				elseif count > 0 then
					rowButton(card, "Use next job", Ui.BLUE, function()
						shopAction:FireServer("SelectStamp", stamp.Id)
					end)
				else
					rowButton(card, "Buy in Shop", Ui.ORANGE, function()
						Menus.Open("Shop")
					end)
				end
			end
		elseif current == "Tools" then
			for index, tool in Config.Tools.List do
				local level = data.Tools[tool.Id] or 0
				local now = if level > 0 then `Now: {Config.Tools.EffectText(tool, level)}` else tool.Description
				local card = row(index, `Tool_{tool.Id}`, `{tool.DisplayName}  (Lv {level}/{tool.MaxLevel})`, now)
				if level < tool.MaxLevel then
					rowButton(card, "Upgrade in Shop", Ui.ORANGE, function()
						Menus.Open("Shop")
					end)
				else
					rowButton(card, "MAXED", Ui.GREEN, nil)
				end
			end
		end
	end

	for index, name in TABS do
		local button = Ui.button(tabBar, {
			LayoutOrder = index,
			Size = UDim2.fromOffset(110, 36),
			TextSize = 18,
			Text = name,
		})
		button.Activated:Connect(function()
			current = name
			redraw()
		end)
		tabButtons[name] = button
	end

	Menus.Register("Inventory", gui, redraw)
	Profile.Watch(function()
		if gui.Enabled then
			redraw()
		end
	end)
end

return Inventory
