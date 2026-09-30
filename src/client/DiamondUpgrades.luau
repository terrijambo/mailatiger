--!strict
-- Diamond Upgrades (the UPGRADES side button, or tap your 💎 counter): permanent boosts bought with
-- diamonds, kept through rebirths. The list and numbers are in src/shared/Config/Diamonds.luau.
-- Each card shows what the upgrade does now, what the next level gives, and a level bar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Menus = require(script.Parent.Menus)
local Profile = require(script.Parent.Profile)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer
local Diamonds = Config.Diamonds

local DIAMOND_BLUE = Color3.fromRGB(60, 170, 235)

local DiamondUpgrades = {}

function DiamondUpgrades.Start()
	local shopAction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ShopAction") :: RemoteEvent
	local gui, window = Ui.window(player:WaitForChild("PlayerGui"), "Upgrades", "Diamond Upgrades", DIAMOND_BLUE)

	-- Your balance, and how to get more
	local balance = Ui.outlined(window, {
		Position = UDim2.fromOffset(20, 58),
		Size = UDim2.new(0.5, -20, 0, 36),
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(150, 235, 255),
		Text = "",
	})
	local getMore = Ui.button(window, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 56),
		Size = UDim2.fromOffset(170, 38),
		TextSize = 18,
		BackgroundColor3 = Ui.GOLD,
		Text = "Get more 💎",
	})
	getMore.Activated:Connect(function()
		Menus.Open("Store")
	end)
	Ui.label(window, {
		Position = UDim2.fromOffset(20, 96),
		Size = UDim2.new(1, -40, 0, 20),
		TextSize = 14,
		TextColor3 = Color3.fromRGB(110, 100, 90),
		Text = `Earn 💎 by leveling up (+{Diamonds.PerLevelUp}, +{Diamonds.MilestoneBonus} more every {Diamonds.MilestoneEvery} levels), finishing Gruff's quests and rebirthing. Upgrades are kept forever.`,
	})

	local list = Ui.make("ScrollingFrame", {
		Position = UDim2.fromOffset(20, 124),
		Size = UDim2.new(1, -40, 1, -140),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, window)
	Ui.make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)

	local function redraw()
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local data = Profile.Get()
		local have = data.Diamonds or 0
		balance.Text = `💎 {Format.Short(have)}`

		for index, upgrade in Diamonds.List do
			local level = data.Upgrades[upgrade.Id] or 0
			local maxed = level >= upgrade.MaxLevel
			local cost = Diamonds.Cost(upgrade, level)
			local card = Ui.card(list, {
				LayoutOrder = index,
				Size = UDim2.new(1, -12, 0, 84),
				BackgroundColor3 = if maxed then Color3.fromRGB(220, 245, 220) else Ui.WHITE,
			})
			Ui.icon(
				card,
				`Upgrade_{upgrade.Id}`,
				{ Position = UDim2.fromOffset(10, 14), Size = UDim2.fromOffset(56, 56) }
			)
			Ui.label(card, {
				Position = UDim2.fromOffset(76, 6),
				Size = UDim2.new(1, -240, 0, 26),
				Font = Ui.TITLE_FONT,
				TextSize = 22,
				Text = `{upgrade.DisplayName}  Lv {level}/{upgrade.MaxLevel}`,
			})
			Ui.label(card, {
				Position = UDim2.fromOffset(76, 32),
				Size = UDim2.new(1, -240, 0, 20),
				TextSize = 15,
				TextColor3 = Color3.fromRGB(110, 100, 90),
				Text = if maxed
					then `Now: {Diamonds.Text(upgrade, level)} (MAX)`
					elseif level == 0 then `Next: {Diamonds.Text(upgrade, 1)}`
					else `Now: {Diamonds.Text(upgrade, level)}  →  {Diamonds.Text(upgrade, level + 1)}`,
			})
			-- Level pips
			local pips = Ui.make("Frame", {
				Position = UDim2.fromOffset(76, 58),
				Size = UDim2.new(1, -240, 0, 14),
				BackgroundTransparency = 1,
			}, card)
			Ui.make("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 4),
			}, pips)
			for pip = 1, upgrade.MaxLevel do
				local dot = Ui.make("Frame", {
					Size = UDim2.new(1 / upgrade.MaxLevel, -4, 1, 0),
					BackgroundColor3 = if pip <= level then DIAMOND_BLUE else Color3.fromRGB(215, 215, 225),
				}, pips)
				Ui.round(dot, 7)
			end

			local button = Ui.button(card, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.fromOffset(140, 46),
				BackgroundColor3 = if maxed then Ui.GREEN elseif have >= cost then DIAMOND_BLUE else Ui.GREY,
				Text = if maxed then "MAXED" else `💎 {Format.Short(cost)}`,
			})
			if maxed then
				button.AutoButtonColor = false
			else
				button.Activated:Connect(function()
					if (Profile.Get().Diamonds or 0) >= cost then
						shopAction:FireServer("BuyUpgrade", upgrade.Id)
					else
						Menus.Open("Store") -- not enough: show where to get more
					end
				end)
			end
		end
	end

	Menus.Register("Upgrades", gui, redraw)
	Profile.Watch(function()
		if gui.Enabled then
			redraw()
		end
	end)
end

return DiamondUpgrades
