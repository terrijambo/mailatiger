--!strict
-- The Supply Shop window: Boxes, Tools, Stamps, Chutes and Rebirth tabs.
-- Buttons only ASK the server (ShopAction). The server checks coins and distance, then updates your profile,
-- and this window redraws from the new profile.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Menus = require(script.Parent.Menus)
local Profile = require(script.Parent.Profile)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local Shop = {}

local TABS = { "Boxes", "Tools", "Stamps", "Chutes", "Trolls", "Rebirth" }

local function rebirthCost(rebirths: number): number
	local rebirth = Config.Progression.Rebirth
	return math.round(rebirth.BaseCost * rebirth.CostGrowth ^ rebirths)
end

function Shop.Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local shopAction = remotes:WaitForChild("ShopAction") :: RemoteEvent
	local notify = remotes:WaitForChild("Notify") :: RemoteEvent

	local gui, window = Ui.window(player:WaitForChild("PlayerGui"), "Shop", "Supply Shop", Ui.ORANGE)

	local tabBar = Ui.make("Frame", {
		Position = UDim2.fromOffset(20, 56),
		Size = UDim2.new(1, -40, 0, 36),
		BackgroundTransparency = 1,
	}, window)
	Ui.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
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

	local currentTab = "Boxes"
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
		if currentTab == "Boxes" then
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
					rowButton(
						frame,
						1,
						`Upgrade: {Format.Short(Config.Tools.PriceFor(tool, level))}`,
						Ui.ORANGE,
						function()
							shopAction:FireServer("UpgradeTool", tool.Id)
						end
					)
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
		elseif currentTab == "Chutes" then
			-- Your personal chute upgrade: bought in order, each one mails faster and pays more
			local current = Config.Mail.ChuteIndex[profile.ChuteTier] or 1
			for index, chute in Config.Mail.Chutes do
				local pay = math.round((chute.PayMult - 1) * 100)
				local frame = row(
					index,
					`{chute.DisplayName}  (+{pay}% pay, {chute.HoldTime}s to mail)`,
					chute.Description,
					`Chute_{chute.Id}`
				)
				if index == current then
					rowButton(frame, 1, "Installed", Ui.GREEN, nil)
				elseif index < current then
					rowButton(frame, 1, "Owned", Ui.GREY, nil)
				elseif index == current + 1 then
					rowButton(frame, 1, `Buy: {Format.Short(chute.Price)}`, Ui.ORANGE, function()
						shopAction:FireServer("BuyChute", chute.Id)
					end)
				else
					rowButton(frame, 1, "Locked", Ui.GREY, nil)
				end
			end
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
			local rebirth = Config.Progression.Rebirth
			local cost = rebirthCost(profile.Rebirths)
			local bonusNow = math.round(profile.Rebirths * rebirth.PayoutBonusPerRebirth * 100)
			local bonusNext = math.round((profile.Rebirths + 1) * rebirth.PayoutBonusPerRebirth * 100)
			local frame = row(
				1,
				`Rebirth #{profile.Rebirths + 1}   (costs {Format.Short(cost)} coins)`,
				`Resets coins, animals, boxes, tools and stamps. Coin bonus: +{bonusNow}% now, +{bonusNext}% after. Forever.`
			)
			local armed = os.clock() < rebirthArmedUntil
			rowButton(
				frame,
				1,
				if armed then "SURE? Again!" else "REBIRTH",
				if armed then Ui.RED else Ui.ORANGE,
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
			row(2, `Jobs mailed so far: {profile.Mailed}`, "Every rebirth makes every future job pay more.")
		end
	end

	for index, name in TABS do
		local button = Ui.button(tabBar, {
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

	-- The SHOP side button and the shop counter both open it
	Menus.Register("Shop", gui, redraw)

	notify.OnClientEvent:Connect(function(kind: string)
		if kind == "OpenShop" then
			Menus.Open("Shop")
		end
	end)
end

return Shop
