--!strict
-- The two shop windows:
--   Gruff's Shop (talk to Gruff, or the SHOP button, from anywhere): Machines, Boxes and Stamps
--   Rebirth Market (only at its stall on Rebirth Beach): Rebirth, Tools, Upgrades, Trolls and Lures. Tools and
--     Rebirth Upgrades cost Rebirth Points, which only come from rebirthing. It closes if you walk away.
-- Buttons only ASK the server (ShopAction). The server checks coins and distance, then updates your profile,
-- and the window redraws from the new profile.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Menus = require(script.Parent.Menus)
local Profile = require(script.Parent.Profile)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local Shop = {}

local SHOP_TABS = { "Machines", "Boxes", "Stamps" }
local MARKET_TABS = { "Rebirth", "Tools", "Upgrades", "Trolls", "Lures" }

local function multText(mult: number): string
	return string.format("%g", math.round(mult * 100) / 100)
end

-- Are you on Rebirth Beach? (the same check the server makes before selling Rebirth Market items)
local function onRebirthBeach(): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local beach = Config.World.ById.Beach
	if not root then
		return false
	end
	local offset = root.Position - beach.Center
	return Vector3.new(offset.X, 0, offset.Z).Magnitude < beach.Radius + 12
end

-- Builds one shop window with its tabs. Returns its ScreenGui.
local function build(menuName: string, windowTitle: string, windowColor: Color3, tabs: { string }): ScreenGui
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local shopAction = remotes:WaitForChild("ShopAction") :: RemoteEvent

	local gui, window = Ui.window(player:WaitForChild("PlayerGui"), menuName, windowTitle, windowColor)

	local tabBar = Ui.make("Frame", {
		Position = UDim2.fromOffset(20, 56),
		Size = UDim2.new(1, -40, 0, 36),
		BackgroundTransparency = 1,
	}, window)
	Ui.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, tabBar)

	local list = Ui.make("ScrollingFrame", {
		Position = UDim2.fromOffset(20, 100),
		Size = UDim2.new(1, -40, 1, -116),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, window)
	Ui.make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)

	local currentTab = tabs[1]
	local tabButtons: { [string]: TextButton } = {}
	local rebirthArmedUntil = 0

	-- One row: an icon (a key in Config/Icons.luau), name + description, then one or two buttons
	local function row(order: number, title: string, description: string, icon: string?): Frame
		local frame = Ui.card(list, {
			LayoutOrder = order,
			Size = UDim2.new(1, -12, 0, 70),
			BackgroundColor3 = Ui.WHITE,
		})
		local left = 14
		if icon then
			Ui.icon(frame, icon, {
				Position = UDim2.fromOffset(10, 9),
				Size = UDim2.fromOffset(52, 52),
			})
			left = 72
		end
		Ui.label(frame, {
			Position = UDim2.fromOffset(left, 8),
			Size = UDim2.new(1, -300, 0, 24),
			TextSize = 20,
			Text = title,
		})
		Ui.label(frame, {
			Position = UDim2.fromOffset(left, 34),
			Size = UDim2.new(1, -300, 0, 30),
			TextSize = 14,
			TextColor3 = Color3.fromRGB(110, 100, 90),
			Text = description,
		})
		return frame
	end

	local function rowButton(frame: Frame, slot: number, text: string, color: Color3, onClick: (() -> ())?)
		local button = Ui.button(frame, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12 - (slot - 1) * 140, 0.5, 0),
			Size = UDim2.fromOffset(130, 40),
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
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for name, button in tabButtons do
			button.BackgroundColor3 = if name == currentTab then Ui.BROWN else Ui.GREY
		end

		local profile = Profile.Get()
		if currentTab == "Machines" then
			-- Post Office machines: unlock with your chute level, buy with coins; each multiplies parcel XP
			local owned = profile.Machines or {}
			local level = profile.Level or 1
			row(
				0,
				`Every parcel gives x{multText(Config.Machines.XPMult(owned))} XP`,
				"XP levels up your chute, and your chute level sets your coins per minute.",
				"Machine_Stamp"
			)
			for index, machine in Config.Machines.List do
				local frame = row(
					index,
					`{machine.DisplayName}  (x{multText(machine.XPMult)} XP)`,
					machine.Description,
					`Machine_{machine.Id}`
				)
				if owned[machine.Id] then
					rowButton(frame, 1, "Installed ✓", Ui.GREEN, nil)
				elseif level < machine.Level then
					rowButton(frame, 1, `🔒 Level {machine.Level}`, Ui.GREY, nil)
				else
					local price = Config.Machines.Price(machine)
					rowButton(
						frame,
						1,
						`Buy: {Format.Short(price)}`,
						if profile.Coins >= price then Ui.ORANGE else Ui.GREY,
						function()
							shopAction:FireServer("BuyMachine", machine.Id)
						end
					)
				end
			end
		elseif currentTab == "Boxes" then
			for index, box in Config.Boxes.List do
				local frame = row(
					index,
					box.DisplayName,
					`Animals start at {box.StartAnger} anger · get angry {math.round(box.AngerMult * 100)}% as fast`,
					`Box_{box.Id}`
				)
				if profile.EquippedBox == box.Id then
					rowButton(frame, 1, "Equipped", Ui.GREEN, nil)
				elseif profile.Boxes[box.Id] then
					rowButton(frame, 1, "Equip", Ui.BLUE, function()
						shopAction:FireServer("EquipBox", box.Id)
					end)
				else
					rowButton(frame, 1, `Buy: {Format.Short(box.Price)}`, Ui.ORANGE, function()
						shopAction:FireServer("BuyBox", box.Id)
					end)
				end
			end
		elseif currentTab == "Tools" then
			-- Tools are bought with Rebirth Points (from rebirthing) and kept forever
			local points = profile.RebirthPoints or 0
			row(
				0,
				`You have {points} Rebirth Point{if points == 1 then "" else "s"}`,
				"Rebirth to earn more. Tool upgrades are yours forever, through every rebirth.",
				"Button_Upgrades"
			)
			for index, tool in Config.Tools.List do
				local level = profile.Tools[tool.Id] or 0
				local now = if level > 0 then `  ·  now: {Config.Tools.EffectText(tool, level)}` else ""
				local frame = row(
					index,
					`{tool.DisplayName}  (Lv {level}/{tool.MaxLevel}){now}`,
					tool.Description,
					`Tool_{tool.Id}`
				)
				if level >= tool.MaxLevel then
					rowButton(frame, 1, "MAXED", Ui.GREEN, nil)
				else
					local cost = Config.Tools.PointsFor(tool, level)
					rowButton(frame, 1, `Upgrade: {cost} RP`, if points >= cost then Ui.PURPLE else Ui.GREY, function()
						shopAction:FireServer("UpgradeTool", tool.Id)
					end)
				end
			end
		elseif currentTab == "Upgrades" then
			-- Rebirth Upgrades: permanent boosts, bought with Rebirth Points (Config/Upgrades.luau)
			local points = profile.RebirthPoints or 0
			row(
				0,
				`You have {points} Rebirth Point{if points == 1 then "" else "s"}`,
				"Rebirth to earn more. Upgrades are yours forever, through every rebirth.",
				"Button_Upgrades"
			)
			local Upgrades = Config.Upgrades
			for index, upgrade in Upgrades.List do
				local level = profile.Upgrades[upgrade.Id] or 0
				local maxed = level >= upgrade.MaxLevel
				local frame = row(
					index,
					`{upgrade.DisplayName}  (Lv {level}/{upgrade.MaxLevel})`,
					if maxed
						then `Now: {Upgrades.Text(upgrade, level)} (MAX)`
						elseif level == 0 then `Next: {Upgrades.Text(upgrade, 1)}`
						else `Now: {Upgrades.Text(upgrade, level)}  →  {Upgrades.Text(upgrade, level + 1)}`,
					`Upgrade_{upgrade.Id}`
				)
				if maxed then
					rowButton(frame, 1, "MAXED", Ui.GREEN, nil)
				else
					local cost = Upgrades.Cost(upgrade, level)
					rowButton(frame, 1, `Upgrade: {cost} RP`, if points >= cost then Ui.PURPLE else Ui.GREY, function()
						shopAction:FireServer("BuyUpgrade", upgrade.Id)
					end)
				end
			end
		elseif currentTab == "Stamps" then
			local none = row(0, "No stamp", "Your next job uses no stamp.")
			if profile.SelectedStamp == nil then
				rowButton(none, 1, "Selected", Ui.GREEN, nil)
			else
				rowButton(none, 1, "Select", Ui.BLUE, function()
					shopAction:FireServer("SelectStamp", "")
				end)
			end
			for index, stamp in Config.Stamps.List do
				local count = profile.Stamps[stamp.Id] or 0
				local frame =
					row(index, `{stamp.DisplayName}  (you have {count})`, stamp.Description, `Stamp_{stamp.Id}`)
				rowButton(frame, 1, `Buy: {Format.Short(stamp.Price)}`, Ui.ORANGE, function()
					shopAction:FireServer("BuyStamp", stamp.Id)
				end)
				if profile.SelectedStamp == stamp.Id then
					rowButton(frame, 2, "Next job ✓", Ui.GREEN, nil)
				elseif count > 0 then
					rowButton(frame, 2, "Use next job", Ui.BLUE, function()
						shopAction:FireServer("SelectStamp", stamp.Id)
					end)
				end
			end
		elseif currentTab == "Lures" then
			-- Lures: for a few minutes, rarer animals you can take on keep turning up right next to you
			local best = 1
			for _, animal in Config.Animals.List do
				if (Config.Wild.LevelOf[animal.Id] or 1) <= (profile.Level or 1) then
					best = math.max(best, animal.BaseValue)
				end
			end
			local lure = Config.Wild.Lures.Lure
			local cost = best * Config.Wild.LureCoinJobs
			local frame = row(
				1,
				`{lure.DisplayName}  ({lure.Seconds // 60} min)`,
				`Rarer animals you're able to grab keep turning up right next to you, in any zone, with {lure.VariantLuck}x Shiny & Golden odds.`,
				"Store_UnlockNext"
			)
			rowButton(frame, 1, `Buy: {Format.Short(cost)}`, Ui.ORANGE, function()
				shopAction:FireServer("BuyLure")
			end)
			local mega = Config.Wild.Lures.MegaLure
			local megaFrame = row(
				2,
				`{mega.DisplayName}  ({mega.Seconds // 60} min)`,
				`Even rarer animals, more of them at once, and {mega.VariantLuck}x Shiny & Golden odds. In the Store.`,
				"Store_UnlockNext"
			)
			rowButton(megaFrame, 1, "Open Store", Ui.GOLD, function()
				Menus.Open("Store")
			end)
		elseif currentTab == "Trolls" then
			-- Troll items: unlock by level, buy once, use from the hotbar. Only affect Chaos Mode players.
			for index, troll in Config.Trolls.List do
				local owned = profile.Trolls and profile.Trolls[troll.Id]
				local locked = (profile.Level or 1) < troll.Level
				local frame = row(
					index,
					`{troll.DisplayName}  (Level {troll.Level}, {troll.Cooldown}s cooldown)`,
					troll.Description,
					`Troll_{troll.Id}`
				)
				if owned then
					rowButton(frame, 1, "Owned ✓", Ui.GREEN, nil)
				elseif locked then
					rowButton(frame, 1, `🔒 Level {troll.Level}`, Ui.GREY, nil)
				else
					rowButton(frame, 1, `Buy: {Format.Short(troll.Price)}`, Ui.ORANGE, function()
						shopAction:FireServer("BuyTroll", troll.Id)
					end)
				end
			end
		elseif currentTab == "Rebirth" then
			local rebirth = Config.Machines.Rebirth
			local cost = Config.Machines.RebirthCost(profile.Rebirths)
			local level = profile.Level or 1
			local needLevel = Config.Machines.RebirthLevel(profile.Rebirths)
			local ready = level >= needLevel and profile.Coins >= cost
			local points = Config.Machines.RebirthPoints(profile.Rebirths + 1)
			local frame = row(
				1,
				`Rebirth #{profile.Rebirths + 1}   (Level {needLevel} chute + {Format.Short(cost)} coins)`,
				`Coins per minute x{multText(rebirth.ChuteMult ^ (profile.Rebirths + 1))} forever, and +{points} Rebirth Points.`
			)
			local armed = os.clock() < rebirthArmedUntil
			if level < needLevel then
				rowButton(frame, 1, `🔒 Level {needLevel}`, Ui.GREY, nil)
			else
				rowButton(
					frame,
					1,
					if armed then "SURE? Again!" else "REBIRTH",
					if armed then Ui.RED elseif ready then Ui.ORANGE else Ui.GREY,
					function()
						if os.clock() < rebirthArmedUntil then
							rebirthArmedUntil = 0
							shopAction:FireServer("Rebirth")
						else
							rebirthArmedUntil = os.clock() + 3 -- click again within 3 seconds to confirm
							redraw()
							task.delay(3.1, function()
								if gui.Enabled and currentTab == "Rebirth" then
									redraw()
								end
							end)
						end
					end
				)
			end
			row(
				2,
				"What resets",
				"Your chute level (back to 1), coins, machines, animals, boxes and stamps. Zones lock again."
			)
			row(
				3,
				"What you keep",
				`Rebirth Points, tools, Rebirth Upgrades, your collection, quests and troll items. Now: x{multText(
					rebirth.ChuteMult ^ profile.Rebirths
				)} coins per minute.`
			)
		end
	end

	for index, name in tabs do
		local button = Ui.button(tabBar, {
			Name = `Tab{name}`,
			LayoutOrder = index,
			Size = UDim2.fromOffset(104, 36),
			TextSize = 18,
			Text = name,
		})
		button.Activated:Connect(function()
			currentTab = name
			redraw()
		end)
		tabButtons[name] = button
	end

	Profile.Watch(function()
		if gui.Enabled then
			redraw()
		end
	end)

	Menus.Register(menuName, gui, redraw)
	return gui
end

function Shop.Start()
	local notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent
	-- Gruff's Shop: the SHOP side button, or talking to Gruff
	build("Shop", "Gruff's Shop", Ui.ORANGE, SHOP_TABS)
	-- The Rebirth Market: its stall on Rebirth Beach
	local market = build("Market", "Rebirth Market", Ui.PURPLE, MARKET_TABS)
	notify.OnClientEvent:Connect(function(kind: string)
		if kind == "OpenShop" then
			Menus.Open("Shop")
		elseif kind == "OpenMarket" then
			Menus.Open("Market")
		end
	end)
	-- Walk off the beach and the market closes (it only sells there)
	task.spawn(function()
		while market.Parent do
			if market.Enabled and not onRebirthBeach() then
				market.Enabled = false
			end
			task.wait(0.5)
		end
	end)
end

return Shop
