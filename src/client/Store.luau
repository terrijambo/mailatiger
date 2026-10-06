--!strict
-- The Robux Store (the STORE side button): the 2x Coins Server Boost, diamond packs, passes and goodies.
-- Buying opens Roblox's own purchase popup; the server gives you what you bought (MonetizationService).
--
-- Items whose Id in src/shared/Config/Monetization.luau is still 0 (not created on Roblox yet):
--   * in Studio they show a purple TEST button that gives the item for free, so you can try everything
--   * in the live game they show "Soon" and can't be bought

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Menus = require(script.Parent.Menus)
local Profile = require(script.Parent.Profile)
local Ui = require(script.Parent.Ui)

local Money = Config.Monetization
local player = Players.LocalPlayer

local DIAMOND_BLUE = Color3.fromRGB(60, 170, 235)
local TEST_PURPLE = Color3.fromRGB(140, 90, 220)

local Store = {}

-- Is there an animal left for "Skip the Wait" to unlock (tier 4 or lower, in a zone you've opened)?
local function canUnlockNext(): boolean
	local data = Profile.Get()
	for _, animal in Config.Animals.List do
		local arena = Config.Arenas.ByTier[animal.Tier]
		local zoneLevel = if arena then Config.Levels.ZoneLevels[arena.Id] or 1 else 1
		if not data.Owned[animal.Id] and animal.Tier <= Money.UnlockNextMaxTier and (data.Level or 1) >= zoneLevel then
			return true
		end
	end
	return false
end

local function boostLeft(): number
	local untilTime = Workspace:GetAttribute("BoostUntil")
	return if typeof(untilTime) == "number" then math.max(0, untilTime - Workspace:GetServerTimeNow()) else 0
end

function Store.Start()
	local shopAction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ShopAction") :: RemoteEvent
	local playerGui = player:WaitForChild("PlayerGui")
	local gui, window = Ui.window(playerGui, "Store", "Store", Ui.GOLD)
	local studio = RunService:IsStudio()

	local list = Ui.make("ScrollingFrame", {
		Position = UDim2.fromOffset(16, 60),
		Size = UDim2.new(1, -32, 1, -76),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, window)
	Ui.make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)

	-- The buy button for a Robux item: real purchase, Studio test, or "Soon"
	type Item = { Key: string, Id: number, Price: number }
	local function buyButton(parent: Instance, item: Item, isPass: boolean, color: Color3, size: UDim2): TextButton
		local owned = isPass and player:GetAttribute(`Pass_{item.Key}`) == true
		local text, fill = `R$ {item.Price}`, color
		if owned then
			text, fill = "Owned ✓", Ui.GREEN
		elseif item.Id == 0 and studio then
			text, fill = `TEST (R$ {item.Price})`, TEST_PURPLE
		elseif item.Id == 0 then
			text, fill = "Soon", Ui.GREY
		end
		local button = Ui.button(parent, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = size,
			BackgroundColor3 = fill,
			TextSize = if #text > 10 then 16 else 22,
			Text = text,
		})
		if owned or (item.Id == 0 and not studio) then
			button.AutoButtonColor = false
			return button
		end
		button.Activated:Connect(function()
			if item.Id == 0 then
				shopAction:FireServer("StudioBuy", item.Key) -- Studio only: free, for testing
			elseif isPass then
				MarketplaceService:PromptGamePassPurchase(player, item.Id)
			else
				MarketplaceService:PromptProductPurchase(player, item.Id)
			end
		end)
		return button
	end

	local function row(order: number, item: Item, title: string, description: string, isPass: boolean, color: Color3)
		local frame = Ui.card(list, {
			LayoutOrder = order,
			Size = UDim2.new(1, -12, 0, 64),
			BackgroundColor3 = Ui.WHITE,
		})
		Ui.icon(frame, `Store_{item.Key}`, { Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(48, 48) })
		Ui.label(frame, {
			Position = UDim2.fromOffset(68, 6),
			Size = UDim2.new(1, -240, 0, 24),
			TextSize = 20,
			Text = title,
		})
		Ui.label(frame, {
			Position = UDim2.fromOffset(68, 32),
			Size = UDim2.new(1, -240, 0, 28),
			TextSize = 14,
			TextColor3 = Color3.fromRGB(110, 100, 90),
			Text = description,
		})
		buyButton(frame, item, isPass, color, UDim2.fromOffset(150, 40))
	end

	local function header(order: number, text: string)
		Ui.label(list, {
			LayoutOrder = order,
			Size = UDim2.new(1, -12, 0, 30),
			Font = Ui.TITLE_FONT,
			TextSize = 24,
			TextColor3 = Ui.BROWN,
			Text = text,
		})
	end

	local boostStatus: TextLabel? = nil

	local function redraw()
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local order = 0
		local function nextOrder(): number
			order += 1
			return order
		end
		local data = Profile.Get()

		-- Featured: the Server Boost, a big gold card
		local boost = Money.ProductByKey.ServerBoost
		local featured = Ui.card(list, {
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, -12, 0, 104),
			BackgroundColor3 = Color3.fromRGB(255, 220, 110),
		})
		Ui.gloss(featured)
		Ui.icon(featured, "Store_ServerBoost", { Position = UDim2.fromOffset(12, 16), Size = UDim2.fromOffset(72, 72) })
		Ui.outlined(featured, {
			Position = UDim2.fromOffset(96, 8),
			Size = UDim2.new(1, -290, 0, 34),
			TextSize = 30,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = `{Money.BoostMult}x COINS FOR EVERYONE`,
		})
		Ui.label(featured, {
			Position = UDim2.fromOffset(96, 42),
			Size = UDim2.new(1, -290, 0, 22),
			TextSize = 16,
			Text = `Everyone in this server earns {Money.BoostMult}x coins for {Money.BoostSeconds // 60} minutes. Buying more adds time.`,
		})
		boostStatus = Ui.label(featured, {
			Position = UDim2.fromOffset(96, 68),
			Size = UDim2.new(1, -290, 0, 24),
			TextSize = 18,
			TextColor3 = Ui.BROWN,
			Text = "",
		})
		buyButton(featured, boost, false, Ui.ORANGE, UDim2.fromOffset(180, 60))

		-- Diamonds
		header(nextOrder(), `💎 Diamonds  (you have {Format.Short(data.Diamonds or 0)})`)
		for _, key in { "DiamondsSmall", "DiamondsMedium", "DiamondsLarge" } do
			local product = Money.ProductByKey[key]
			row(nextOrder(), product, product.DisplayName, product.Description, false, DIAMOND_BLUE)
		end
		local spend = Ui.button(list, {
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, -12, 0, 40),
			BackgroundColor3 = DIAMOND_BLUE,
			TextSize = 18,
			Text = "Spend diamonds on DIAMOND UPGRADES →",
		})
		spend.Activated:Connect(function()
			Menus.Open("Upgrades")
		end)

		-- Passes
		header(nextOrder(), "Passes (yours forever)")
		for _, pass in Money.Passes do
			row(nextOrder(), pass, pass.DisplayName, pass.Description, true, Ui.ORANGE)
		end

		-- Goodies
		header(nextOrder(), "Goodies")
		for _, product in Money.Products do
			local skip = product.Key == "ServerBoost" or Money.DiamondPacks[product.Key] ~= nil
			if not skip and (product.Key ~= "UnlockNext" or canUnlockNext()) then
				row(nextOrder(), product, product.DisplayName, product.Description, false, Ui.BLUE)
			end
		end

		if studio then
			-- Studio only: start any event right now, to test it without waiting for the clock
			header(nextOrder(), "STUDIO: start an event now")
			local ids = { "Boss" }
			for _, event in Config.Events.Small do
				table.insert(ids, event.Id)
			end
			for _, id in ids do
				local event = Config.Events.ById[id]
				local button = Ui.button(list, {
					LayoutOrder = nextOrder(),
					Size = UDim2.new(1, -12, 0, 36),
					BackgroundColor3 = TEST_PURPLE,
					TextSize = 18,
					Text = if event then `TEST: {event.Emoji} {event.DisplayName}` else "TEST: ⚔️ BOSS FIGHT",
				})
				button.Activated:Connect(function()
					shopAction:FireServer("StudioEvent", id)
					Menus.CloseAll()
				end)
			end
			Ui.label(list, {
				LayoutOrder = nextOrder(),
				Size = UDim2.new(1, -12, 0, 40),
				TextSize = 13,
				TextColor3 = TEST_PURPLE,
				Text = "STUDIO: purple TEST buttons give the item free (it isn't set up on Roblox yet). Real ones show Roblox's test popup, which never charges in Studio.",
			})
		end
	end

	-- Opened by the STORE side button (SideButtons.luau)
	Menus.Register("Store", gui, redraw)

	-- Keep it current while it's open (after a purchase, a new pass, an unlock...)
	local function refreshIfOpen()
		if gui.Enabled then
			redraw()
		end
	end
	Profile.Watch(refreshIfOpen)
	player.AttributeChanged:Connect(function(name: string)
		if string.sub(name, 1, 5) == "Pass_" then
			refreshIfOpen()
		end
	end)
	-- The boost countdown on the featured card
	task.spawn(function()
		while gui.Parent do
			local label = boostStatus
			if gui.Enabled and label and label.Parent then
				local left = math.floor(boostLeft())
				label.Text = if left > 0
					then string.format("🚀 Boost running: %d:%02d left", left // 60, left % 60)
					else "No boost running right now. Be the hero."
			end
			task.wait(0.5)
		end
	end)
end

return Store
