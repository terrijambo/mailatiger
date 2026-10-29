--!strict
-- MENU > REALMS (Config/Realms.luau, docs/REALMS_PLAN.md): the six realms in order. The ones you've bought have
-- a GO button; the next one shows what it still needs and its price, with a BUY button (press twice: moving
-- starts you over); the rest are locked. Buttons only ASK the server (the Realm remote); the window redraws
-- from your profile when anything changes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Menus = require(script.Parent.Menus)
local Profile = require(script.Parent.Profile)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local Realms = {}

-- Each realm's animals, easiest first ("Hamster, Bunny, Goldfish...")
local function animalsOf(index: number): string
	local names = {}
	for _, animal in Config.Animals.List do
		if animal.Tier == index then
			table.insert(names, animal.DisplayName)
		end
	end
	return table.concat(names, ", ")
end

function Realms.Start()
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Realm") :: RemoteEvent
	local gui, window = Ui.window(player:WaitForChild("PlayerGui"), "Realms", "🗺️ REALMS", Ui.PURPLE)

	local list = Ui.make("ScrollingFrame", {
		Position = UDim2.fromOffset(20, 60),
		Size = UDim2.new(1, -40, 1, -76),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, window)
	Ui.make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)

	local armedUntil = 0

	local function row(order: number, title: string, description: string, emoji: string, color: Color3): Frame
		local frame = Ui.card(list, {
			LayoutOrder = order,
			Size = UDim2.new(1, -12, 0, 84),
			BackgroundColor3 = Ui.WHITE,
		})
		local badge = Ui.make("Frame", {
			Position = UDim2.fromOffset(10, 12),
			Size = UDim2.fromOffset(60, 60),
			BackgroundColor3 = color,
		}, frame)
		Ui.round(badge, 12)
		Ui.make("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = Ui.FONT,
			TextScaled = true,
			Text = emoji,
		}, badge)
		Ui.label(frame, {
			Position = UDim2.fromOffset(82, 8),
			Size = UDim2.new(1, -240, 0, 24),
			TextSize = 20,
			Text = title,
		})
		Ui.label(frame, {
			Position = UDim2.fromOffset(82, 34),
			Size = UDim2.new(1, -240, 0, 44),
			TextSize = 14,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = Color3.fromRGB(110, 100, 90),
			Text = description,
		})
		return frame
	end

	local function button(frame: Frame, text: string, color: Color3, onClick: (() -> ())?)
		local b = Ui.button(frame, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(140, 44),
			BackgroundColor3 = color,
			Text = text,
		})
		if onClick then
			b.Activated:Connect(onClick)
		else
			b.AutoButtonColor = false
		end
	end

	local function redraw()
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local data = Profile.Get()
		local home = data.Realm or 1
		local level = data.Level or 1
		local rebirths = data.Rebirths or 0

		for _, realm in Config.Realms.List do
			local index = realm.Index
			local title = `{realm.DisplayName}{if index == home then "  (HOME)" else ""}`
			if index <= home then
				local frame = row(index, title, `{realm.Blurb}\nAnimals: {animalsOf(index)}`, realm.Emoji, realm.Color)
				button(frame, "GO", Ui.BLUE, function()
					remote:FireServer("Go", index)
					gui.Enabled = false
				end)
			elseif index == home + 1 then
				local price = Config.Realms.Price(home) or 0
				local missing = Config.Realms.Missing(home, level, rebirths)
				if (data.Coins or 0) < price then
					table.insert(missing, `{Format.Short(price)} coins (you have {Format.Short(data.Coins or 0)})`)
				end
				local needs = if #missing == 0
					then "Ready to move! You start over there with bigger animals and x2 Rebirth Points."
					else `Still needed: {table.concat(missing, "; ")}`
				local frame = row(index, `🔒 {realm.DisplayName}`, `{realm.Blurb}\n{needs}`, realm.Emoji, realm.Color)
				local armed = os.clock() < armedUntil
				button(
					frame,
					if armed then "SURE? Again!" else `BUY: {Format.Short(price)}`,
					if armed then Ui.RED elseif #missing == 0 then Ui.ORANGE else Ui.GREY,
					function()
						if #missing > 0 then
							remote:FireServer("Buy") -- (the server says what's missing)
						elseif os.clock() < armedUntil then
							armedUntil = 0
							remote:FireServer("Buy")
						else
							armedUntil = os.clock() + 3 -- press again within 3 seconds to confirm
							redraw()
							task.delay(3.1, function()
								if gui.Enabled then
									redraw()
								end
							end)
						end
					end
				)
			else
				local frame = row(
					index,
					`🔒 {realm.DisplayName}`,
					`{realm.Blurb}\nUnlock the realm before it first.`,
					realm.Emoji,
					Color3.fromRGB(150, 150, 160)
				)
				button(frame, "LOCKED", Ui.GREY, nil)
			end
		end
		row(
			Config.Realms.Count + 1,
			"What moving does",
			`Starts you over in the new realm: coins, chute level, machines and rebirths. You keep Rebirth Points, upgrades, tools, troll items and your collection. Each realm pays x{Config.Realms.PointsMult} Rebirth Points.`,
			"📦",
			Ui.BROWN
		)
	end

	Menus.Register("Realms", gui, redraw)
	Profile.Watch(function()
		if gui.Enabled then
			redraw()
		end
	end)
end

return Realms
