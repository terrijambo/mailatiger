--!strict
-- The Premium (Robux) Store: opened from Gruff's Shop (PREMIUM) or the + by your coins. The 2x Coins Server
-- Boost, passes and goodies (incl. the Invincibility Shield). Its SHOP button flips back to Gruff's Shop.
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
local Menus = require(script.Parent.Menus)
local Profile = require(script.Parent.Profile)
local Track = require(script.Parent.Track)
local Ui = require(script.Parent.Ui)

local Money = Config.Monetization
local player = Players.LocalPlayer

local TEST_PURPLE = Color3.fromRGB(140, 90, 220)

local Store = {}

-- Today's deal (Config.Monetization.DealFor): days since 1970, by the server's clock
local function todaysDeal(): string?
	return Money.DealFor(math.floor(Workspace:GetServerTimeNow() / 86400))
end

local function boostLeft(): number
	local untilTime = Workspace:GetAttribute("BoostUntil")
	return if typeof(untilTime) == "number" then math.max(0, untilTime - Workspace:GetServerTimeNow()) else 0
end

function Store.Start()
	local shopAction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ShopAction") :: RemoteEvent
	local playerGui = player:WaitForChild("PlayerGui")
	local gui, window = Ui.window(playerGui, "Store", "Premium", Ui.GOLD)
	-- SHOP flips back to Gruff's Shop (its PREMIUM button opens this)
	Ui.windowSwitch(window, "🛒 SHOP", Ui.ORANGE, function()
		Menus.Open("Shop")
	end)
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
			if not button.Active then
				return -- (the boost button while the boost is full)
			end
			if item.Id ~= 0 then
				Track.Send("PurchasePrompt", item.Key, if isPass then "Pass" else "Product")
			end
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
		local deal = not isPass and todaysDeal() == item.Key
		local frame = Ui.card(list, {
			LayoutOrder = order,
			Size = UDim2.new(1, -12, 0, 64),
			BackgroundColor3 = if deal then Color3.fromRGB(255, 236, 200) else Ui.WHITE,
		})
		if deal then
			title = `🔥 {title}: +{math.round(Money.DealBonus * 100)}% TODAY`
		end
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
	local boostButton: TextButton? = nil

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
		boostButton = buyButton(featured, boost, false, Ui.ORANGE, UDim2.fromOffset(180, 60))

		-- Today's deal: one product gives more today (MonetizationService adds the bonus)
		local dealKey = todaysDeal()
		local dealItem = if dealKey then Money.ProductByKey[dealKey] else nil
		if dealItem then
			header(nextOrder(), `🔥 Today's deal: +{math.round(Money.DealBonus * 100)}% more`)
			row(nextOrder(), dealItem, dealItem.DisplayName, dealItem.Description, false, Ui.RED)
		end

		-- Passes
		header(nextOrder(), "Passes (yours forever)")
		for _, pass in Money.Passes do
			row(nextOrder(), pass, pass.DisplayName, pass.Description, true, Ui.ORANGE)
		end

		-- Your style: tape colors (Gold with VIP, the rest with the Style Pack) and the run trail
		header(nextOrder(), "🎨 Your style")
		local data = Profile.Get()
		local function owns(passKey: string): boolean
			return player:GetAttribute(`Pass_{passKey}`) == true
		end
		local current = Config.Styles.TapeFor(data.TapeStyle, owns)
		local swatches = Ui.make("Frame", {
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, -12, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		}, list)
		Ui.make("UIGridLayout", {
			CellSize = UDim2.fromOffset(84, 56),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, swatches)
		for index, tape in Config.Styles.Tapes do
			local unlocked = tape.Needs == nil or owns(tape.Needs)
			local chosen = tape.Id == current.Id
			local swatch = Ui.button(swatches, {
				LayoutOrder = index,
				BackgroundColor3 = tape.Color,
				TextSize = 14,
				TextColor3 = if tape.Id == "White"
						or tape.Id == "Gold"
						or tape.Id == "Classic"
					then Ui.BROWN
					else Ui.WHITE,
				Text = if chosen
					then `✓ {tape.DisplayName}`
					elseif unlocked then tape.DisplayName
					else `🔒 {tape.DisplayName}`,
			})
			swatch.Activated:Connect(function()
				if unlocked then
					shopAction:FireServer("SetTape", tape.Id)
					return
				end
				-- Locked: offer the pass that unlocks it
				local pass = Money.PassByKey[tape.Needs or ""]
				if pass and pass.Id ~= 0 then
					Track.Send("PurchasePrompt", pass.Key, "Pass")
					MarketplaceService:PromptGamePassPurchase(player, pass.Id)
				end
			end)
		end
		if owns("StylePack") then
			local trailOn = data.TrailOn ~= false
			local trail = Ui.button(list, {
				LayoutOrder = nextOrder(),
				Size = UDim2.new(1, -12, 0, 40),
				BackgroundColor3 = if trailOn then Ui.GREEN else Ui.GREY,
				TextSize = 18,
				Text = if trailOn then "✨ Run trail: ON" else "Run trail: OFF",
			})
			trail.Activated:Connect(function()
				shopAction:FireServer("ToggleTrail")
			end)
		else
			Ui.label(list, {
				LayoutOrder = nextOrder(),
				Size = UDim2.new(1, -12, 0, 22),
				TextSize = 14,
				TextColor3 = Color3.fromRGB(110, 100, 90),
				Text = "🔒 colors and a matching run trail come with the Style Pack. Gold tape comes with VIP.",
			})
		end

		-- Goodies
		header(nextOrder(), "Goodies")
		for _, product in Money.Products do
			local skip = product.Key == "ServerBoost" or product.Retired == true or product.Key == dealKey
			if not skip then
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
				-- Nearly at the 1-hour cap: buying now would add almost nothing, so the button waits
				local button = boostButton
				if button and button.Parent then
					local full = left > Money.BoostMaxSeconds - Money.BoostSeconds
					button.Active = not full
					button.AutoButtonColor = not full
					button.BackgroundTransparency = if full then 0.5 else 0
					if full then
						label.Text =
							string.format("🚀 Boost is full: %d:%02d left (max 1 hour)", left // 60, left % 60)
					end
				end
			end
			task.wait(0.5)
		end
	end)
end

return Store
