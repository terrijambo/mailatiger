--!strict
-- The Robux Store: a button on the left of the screen opens a window of game passes and products.
-- Only things you've set up on Roblox show up (an Id in src/shared/Config/Monetization.luau that isn't 0).
-- Buying is handled by Roblox's own purchase popup; the server gives you what you bought.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Profile = require(script.Parent.Profile)
local Ui = require(script.Parent.Ui)

local Money = Config.Monetization
local player = Players.LocalPlayer

local Store = {}

-- Is there an animal left for "Skip the Wait" to unlock?
local function canUnlockNext(): boolean
	local owned = Profile.Get().Owned
	for _, animal in Config.Animals.List do
		if not owned[animal.Id] and animal.Tier <= Money.UnlockNextMaxTier then
			return true
		end
	end
	return false
end

function Store.Start()
	local playerGui = player:WaitForChild("PlayerGui")
	local gui, window = Ui.window(playerGui, "Store", "Store")

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

	local function row(
		order: number,
		title: string,
		description: string,
		button: string,
		color: Color3,
		onClick: (() -> ())?
	)
		local frame = Ui.make("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, -12, 0, 64),
			BackgroundColor3 = Ui.WHITE,
		}, list)
		Ui.round(frame)
		Ui.label(frame, {
			Position = UDim2.fromOffset(14, 6),
			Size = UDim2.new(1, -180, 0, 24),
			TextSize = 20,
			Text = title,
		})
		Ui.label(frame, {
			Position = UDim2.fromOffset(14, 32),
			Size = UDim2.new(1, -180, 0, 28),
			TextSize = 14,
			TextColor3 = Color3.fromRGB(110, 100, 90),
			Text = description,
		})
		local b = Ui.button(frame, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(140, 40),
			BackgroundColor3 = color,
			Text = button,
		})
		if onClick then
			b.Activated:Connect(onClick)
		else
			b.AutoButtonColor = false
		end
	end

	local function header(order: number, text: string)
		Ui.label(list, {
			LayoutOrder = order,
			Size = UDim2.new(1, -12, 0, 28),
			TextSize = 22,
			TextColor3 = Ui.BROWN,
			Text = text,
		})
	end

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
		local any = false

		header(nextOrder(), "Passes (yours forever)")
		for _, pass in Money.Passes do
			if pass.Id ~= 0 then
				any = true
				local owned = player:GetAttribute(`Pass_{pass.Key}`) == true
				row(
					nextOrder(),
					pass.DisplayName,
					pass.Description,
					if owned then "Owned ✓" else `R$ {pass.Price}`,
					if owned then Ui.GREEN else Ui.ORANGE,
					if owned
						then nil
						else function()
							MarketplaceService:PromptGamePassPurchase(player, pass.Id)
						end
				)
			end
		end

		header(nextOrder(), "Goodies")
		for _, product in Money.Products do
			if product.Id ~= 0 and (product.Key ~= "UnlockNext" or canUnlockNext()) then
				any = true
				row(nextOrder(), product.DisplayName, product.Description, `R$ {product.Price}`, Ui.BLUE, function()
					MarketplaceService:PromptProductPurchase(player, product.Id)
				end)
			end
		end

		if not any then
			for _, child in list:GetChildren() do
				if child:IsA("GuiObject") then
					child:Destroy()
				end
			end
			header(1, "The Store opens soon! Gruff is still counting the stamps.")
		end
	end

	-- The button that opens it (left side of the screen)
	local hud = Ui.make("ScreenGui", { Name = "StoreButton", ResetOnSpawn = false }, playerGui)
	local open = Ui.button(hud, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.4, 0),
		Size = UDim2.fromOffset(96, 40),
		BackgroundColor3 = Color3.fromRGB(80, 180, 90),
		TextSize = 20,
		Text = "Store",
	})
	open.Activated:Connect(function()
		redraw()
		gui.Enabled = not gui.Enabled
	end)

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
end

return Store
