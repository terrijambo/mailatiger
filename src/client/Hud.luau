--!strict
-- The on-screen HUD, kept clean: only what matters right now is on screen.
--   * one objective line across the top ("Box your hamster!"), and a status line under it only when
--     there's something to say (Gruff's quest is in the TASKS panel on the right: OrdersBoard.luau)
--   * bottom-left: your level (with small coin-boost and streak badges after the XP bar), and your coins
--     with a + (opens the Premium Store) and your Rebirth Points beside them
--   * bottom-right: your bag, only while you're carrying parcels (it pulses when it's nearly full)
--   Everything shrinks a little on small screens (Ui.autoScale), so phones keep the same layout.
--   * popups from Gruff and the chute (receipts get a red star-rating stamp), queued so none get lost
--   * the giant RETURN TO SENDER stamp
-- It only READS what the server tells it (Player attributes + the Notify remote).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Menus = require(script.Parent.Menus)
local Profile = require(script.Parent.Profile)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local Hud = {}

local COIN_GREEN = Color3.fromRGB(110, 255, 110)
local BAG_TAN = Color3.fromRGB(255, 205, 120)
local BOOST_ORANGE = Color3.fromRGB(255, 170, 60)
local REBIRTH_PURPLE = Color3.fromRGB(210, 160, 255)

-- 185 -> "3:05"
local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- Seconds left on the server-wide 2x coins boost (0 = none)
local function boostLeft(): number
	local untilTime = Workspace:GetAttribute("BoostUntil")
	return if typeof(untilTime) == "number" then math.max(0, untilTime - Workspace:GetServerTimeNow()) else 0
end

-- Short numbers (1k, 12.5k, 1M): see src/shared/Format.luau
Hud.Short = Format.Short

-- One row of the stats stack: an emoji icon and a big outlined value
-- (icon is a key in Config/Icons.luau)
-- (mirrored: icon on the right and the number right-aligned, for the bottom-right corner)
local function statRow(
	parent: Instance,
	order: number,
	icon: string,
	color: Color3,
	mirrored: boolean?
): (Frame, TextLabel)
	local row = Ui.make("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(260, 44),
		BackgroundTransparency = 1,
	}, parent)
	Ui.icon(row, icon, {
		AnchorPoint = Vector2.new(if mirrored then 1 else 0, 0),
		Position = if mirrored then UDim2.fromScale(1, 0) else UDim2.new(),
		Size = UDim2.fromOffset(44, 44),
	})
	local value = Ui.outlined(row, {
		Position = UDim2.fromOffset(if mirrored then 0 else 52, 0),
		Size = UDim2.new(1, -52, 1, 0),
		TextSize = 38,
		TextXAlignment = if mirrored then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left,
		TextColor3 = color,
		Text = "",
	})
	return row, value
end

function Hud.Start()
	local gui = Ui.make("ScreenGui", {
		Name = "MailATigerHud",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))

	---------------------------------------------------------------------------------------------------
	-- Stats stack (bottom-left)
	local stack = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -14),
		Size = UDim2.fromOffset(260, 150),
		BackgroundTransparency = 1,
	}, gui)
	Ui.autoScale(stack) -- smaller on phones
	local stackLayout = Ui.make("UIListLayout", {
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
	}, stack)
	-- The bag lives in the bottom-right corner (top-right on phones)
	local rightStack = Ui.make("Frame", {
		Size = UDim2.fromOffset(270, 100),
		BackgroundTransparency = 1,
	}, gui)
	Ui.autoScale(rightStack)
	local rightLayout = Ui.make("UIListLayout", {
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
	}, rightStack)
	local bagRow, bagLabel = statRow(rightStack, 2, "Hud_Bag", BAG_TAN, true)
	bagRow.Visible = false
	local bagPulse = Ui.make("UIScale", { Scale = 1 }, bagRow)
	task.spawn(function()
		while bagRow.Parent do
			bagPulse.Scale = if bagRow:GetAttribute("NearlyFull")
				then 1 + 0.08 * math.abs(math.sin(os.clock() * 4))
				else 1
			task.wait(0.05)
		end
	end)
	local coinRow, coinsLabel = statRow(stack, 3, "Hud_Coins", COIN_GREEN)
	Ui.pill(coinRow)
	Ui.pill(bagRow)

	-- Next to the coins, left to right: a + (opens the Premium Store), then your Rebirth Points
	local coinExtras = Ui.make("Frame", {
		Size = UDim2.fromOffset(240, 44),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, coinRow)
	Ui.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	}, coinExtras)
	local function placeExtras()
		coinExtras.Position = UDim2.fromOffset(52 + coinsLabel.TextBounds.X + 8, 0)
	end
	coinsLabel:GetPropertyChangedSignal("TextBounds"):Connect(placeExtras)
	placeExtras()
	local storePlus = Ui.button(coinExtras, {
		Name = "StorePlus",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = Ui.GREEN,
		Font = Ui.TITLE_FONT,
		TextSize = 28,
		Text = "+",
	})
	storePlus.Activated:Connect(function()
		Menus.Toggle("Store")
	end)
	-- Rebirth Points (spent at the Rebirth Market): always shown; the number pops when it changes
	local pointsIcon = Ui.icon(coinExtras, "Hud_RebirthPoints", {
		LayoutOrder = 2,
		Size = UDim2.fromOffset(36, 36),
	})
	local pointsLabel = Ui.outlined(coinExtras, {
		Name = "RebirthPoints",
		LayoutOrder = 3,
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 32,
		TextColor3 = REBIRTH_PURPLE,
		Text = "",
	})
	local pointsPop = Ui.make("UIScale", { Scale = 1 }, pointsLabel)
	local knownPoints: number? = nil
	Profile.Watch(function()
		local points = Profile.Get().RebirthPoints or 0
		pointsLabel.Text = Format.Short(points)
		if knownPoints and points ~= knownPoints then
			pointsPop.Scale = 1.5
			TweenService:Create(pointsPop, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
		end
		knownPoints = points
	end)

	-- Small badges after the XP bar: your total coin boost ("⚡+40%", glowing) and delivery streak ("🔥x5")
	local levelExtras = Ui.make("Frame", {
		Position = UDim2.fromOffset(294, 0),
		Size = UDim2.fromOffset(160, 44),
		BackgroundTransparency = 1,
	})
	Ui.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	}, levelExtras)
	local boostLabel = Ui.outlined(levelExtras, {
		LayoutOrder = 1,
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		Font = Ui.FONT,
		TextSize = 18,
		TextColor3 = BOOST_ORANGE,
		Text = "",
		Visible = false,
	})
	task.spawn(function()
		while boostLabel.Parent do
			if boostLabel.Visible then
				local glow = 0.5 + 0.5 * math.sin(os.clock() * 3)
				boostLabel.TextColor3 = BOOST_ORANGE:Lerp(Ui.GOLD, glow)
			end
			task.wait(0.05)
		end
	end)
	-- Delivery streak: pops each time it grows
	local streakLabel = Ui.outlined(levelExtras, {
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 20,
		TextColor3 = Color3.fromRGB(255, 150, 40),
		Text = "",
		Visible = false,
	})
	local streakPop = Ui.make("UIScale", { Scale = 1 }, streakLabel)
	local function refreshStreak()
		local count = player:GetAttribute("Streak")
		local show = typeof(count) == "number" and count >= 2
		streakLabel.Visible = show
		if show then
			streakLabel.Text = `🔥x{count}`
			streakPop.Scale = 1.5
			TweenService:Create(streakPop, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
		end
	end
	player:GetAttributeChangedSignal("Streak"):Connect(refreshStreak)
	refreshStreak()

	-- Level + XP bar (top of the stack)
	local levelRow, levelLabel = statRow(stack, 0, "Hud_Level", Ui.GOLD)
	levelLabel.Size = UDim2.fromOffset(90, 44)
	levelExtras.Parent = levelRow
	Ui.pill(levelRow)
	local xpBack = Ui.make("Frame", {
		Position = UDim2.fromOffset(136, 12),
		Size = UDim2.fromOffset(150, 20),
		BackgroundColor3 = Color3.fromRGB(30, 30, 40),
		BackgroundTransparency = 0.2,
	}, levelRow)
	Ui.round(xpBack, 10)
	Ui.border(xpBack, 2)
	local xpFill = Ui.make("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.fromRGB(80, 200, 255),
	}, xpBack)
	Ui.round(xpFill, 10)
	Ui.gloss(xpFill)
	Ui.bar(xpBack, xpFill, Color3.fromRGB(80, 200, 255))
	local xpText = Ui.outlined(xpBack, {
		Size = UDim2.fromScale(1, 1),
		Font = Ui.FONT,
		TextSize = 14,
		Text = "",
		ZIndex = 3,
	})
	stack.Size = UDim2.fromOffset(300, 140)
	-- Empty start: nothing at all until the first mail (Profile.Bare), the Roblox player list included
	local wasBare: boolean? = nil
	Profile.Watch(function()
		local bare = Profile.Bare()
		gui.Enabled = not bare
		if bare ~= wasBare then
			wasBare = bare
			pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, not bare)
		end
	end)
	-- Simple start: during the walkthrough it's just your coins. Your level, Rebirth Points and the + to the
	-- Store pop in when it's done.
	Profile.Watch(function()
		local learning = Profile.Learning()
		storePlus.Visible = not learning
		pointsIcon.Visible = not learning
		pointsLabel.Visible = not learning
		if levelRow.Visible == learning then
			levelRow.Visible = not learning
			if not learning then
				local pop = levelRow:FindFirstChildOfClass("UIScale") or Ui.make("UIScale", {}, levelRow)
				pop.Scale = 0.3
				TweenService:Create(pop, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Scale = 1,
				}):Play()
			end
		end
	end)
	-- Big screens: bottom-left. Phones: top-left, so the thumbstick (bottom-left) is free; the side buttons
	-- go under it (SideButtons.luau)
	Ui.onResize(function()
		local margin = Ui.margin()
		if Ui.compact() then
			stack.AnchorPoint = Vector2.new(0, 0)
			stack.Position = UDim2.fromOffset(margin, 8)
			stackLayout.VerticalAlignment = Enum.VerticalAlignment.Top
			-- (under the server boost timer, which is top-right on phones)
			rightStack.AnchorPoint = Vector2.new(1, 0)
			rightStack.Position = UDim2.new(1, -margin, 0, 8 + 60 * Ui.screenScale())
			rightLayout.VerticalAlignment = Enum.VerticalAlignment.Top
		else
			stack.AnchorPoint = Vector2.new(0, 1)
			stack.Position = UDim2.new(0, margin, 1, -margin)
			stackLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
			rightStack.AnchorPoint = Vector2.new(1, 1)
			rightStack.Position = UDim2.new(1, -margin, 1, -margin)
			rightLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
		end
	end)
	local function refreshLevel()
		local data = Profile.Get()
		local level = data.Level or 1
		local need = Config.Levels.XPToNext(level)
		levelLabel.Text = `Lv {level}`
		local fraction = if level >= Config.Levels.MaxLevel then 1 else math.clamp((data.XP or 0) / need, 0, 1)
		TweenService:Create(xpFill, TweenInfo.new(0.4), { Size = UDim2.fromScale(fraction, 1) }):Play()
		xpText.Text = if level >= Config.Levels.MaxLevel
			then "MAX"
			else `{Format.Short(data.XP or 0)} / {Format.Short(need)} XP`
	end
	Profile.Watch(refreshLevel)

	-- The coin counter rolls up to its new value, bounces, and floats a "+123" when you get paid
	local shownCoins = Instance.new("NumberValue")
	local coinScale = Ui.make("UIScale", { Scale = 1 }, coinsLabel)
	local knownCoins: number? = nil
	shownCoins.Changed:Connect(function(value: number)
		coinsLabel.Text = Hud.Short(math.round(value))
	end)
	local function showCoins(coins: number)
		local before = knownCoins
		knownCoins = coins
		if before == nil then
			shownCoins.Value = coins
			coinsLabel.Text = Hud.Short(coins)
			return
		end
		if coins == before then
			return
		end
		TweenService:Create(shownCoins, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Value = coins }):Play()
		coinScale.Scale = 1.2
		TweenService:Create(coinScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		if coins > before then
			local gain = Ui.outlined(coinRow, {
				Position = UDim2.fromOffset(150, -6),
				Size = UDim2.fromOffset(200, 36),
				TextSize = 32,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Ui.GOLD,
				Text = `+{Hud.Short(coins - before)}`,
				ZIndex = 4,
			})
			local stroke = gain:FindFirstChildOfClass("UIStroke")
			local rise = TweenService:Create(gain, TweenInfo.new(1.2), {
				Position = UDim2.fromOffset(150, -60),
				TextTransparency = 1,
			})
			if stroke then
				TweenService:Create(stroke, TweenInfo.new(1.2), { Transparency = 1 }):Play()
			end
			rise:Play()
			rise.Completed:Once(function()
				gain:Destroy()
			end)
		end
	end

	---------------------------------------------------------------------------------------------------
	-- Objective line (top center) + a status line under it
	local banner = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.new(0.56, 0, 0, 44),
		BackgroundColor3 = Color3.fromRGB(15, 15, 25),
		BackgroundTransparency = 0.35,
	}, gui)
	-- Fade out at both ends
	Ui.autoScale(banner)
	Ui.make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.18, 0),
			NumberSequenceKeypoint.new(0.82, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, banner)
	local objective = Ui.outlined(banner, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.84, 0, 0, 32),
		TextScaled = true,
		Text = "",
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 28 }, objective)

	local status = Ui.outlined(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 52),
		Size = UDim2.fromOffset(640, 22),
		Font = Ui.FONT,
		TextSize = 17,
		Text = "",
	})
	Ui.autoScale(status)

	local function refreshStatus()
		local profile = Profile.Get()
		showCoins(profile.Coins)
		local capacity = Profile.BagCapacity(profile)
		bagLabel.Text = `{#profile.Parcels} / {capacity}`
		-- Only while you're carrying parcels; it pulses once it's nearly full
		bagRow.Visible = #profile.Parcels > 0
		bagLabel.TextColor3 = if #profile.Parcels >= capacity then Color3.fromRGB(255, 100, 90) else BAG_TAN
		bagRow:SetAttribute("NearlyFull", #profile.Parcels >= math.max(1, math.ceil(capacity * 0.8)))

		-- Total coin boost from rebirths, Golden Paws, the server boost, 2x Coins, Premium and the group
		-- (the same math as Economy.PayoutMult on the server)
		local money = Config.Monetization
		local mult = 1 + profile.Rebirths * Config.Progression.Rebirth.PayoutBonusPerRebirth
		local paws = Config.Upgrades.ById.GoldenPaws
		mult *= 1 + Config.Upgrades.Bonus(paws, profile.Upgrades.GoldenPaws or 0) / 100
		if boostLeft() > 0 then
			mult *= money.BoostMult
		end
		if player:GetAttribute("Pass_Coins2x") then
			mult *= money.Coins2xMult
		end
		if player:GetAttribute("Premium") then
			mult *= money.PremiumPayoutMult
		end
		if player:GetAttribute("InGroup") then
			mult *= money.GroupPayoutMult
		end
		local friends = player:GetAttribute("FriendsHere")
		if typeof(friends) == "number" and friends > 0 then
			local tuning = Config.Social.Friends
			mult *= 1 + tuning.BonusPerFriend * math.min(friends, tuning.MaxFriends)
		end
		boostLabel.Visible = mult > 1.001
		boostLabel.Text = `⚡+{math.round((mult - 1) * 100)}%`

		local parts = {}
		if player:GetAttribute("Chaos") then
			table.insert(parts, "🔥 CHAOS MODE: +50% pay, but others can spook your animal and shove you")
		end
		local stamp = profile.SelectedStamp and Config.Stamps.ById[profile.SelectedStamp]
		if stamp then
			table.insert(parts, `Next job: {stamp.DisplayName} stamp`)
		end
		if player:GetAttribute("TemporaryData") then
			table.insert(parts, "⚠ Progress isn't saving (DataStores off)")
		end
		status.Text = table.concat(parts, "   ·   ")
		status.TextColor3 = if player:GetAttribute("Chaos") then Color3.fromRGB(255, 130, 120) else Ui.WHITE
	end
	Profile.Watch(refreshStatus)
	for _, attribute in { "Chaos", "Premium", "InGroup", "FriendsHere", "Pass_Coins2x" } do
		player:GetAttributeChangedSignal(attribute):Connect(refreshStatus)
	end

	---------------------------------------------------------------------------------------------------
	-- Server boost timer (top-left): "🚀 2x COINS 2:41, boosted by Name"
	local boostPill = Ui.make("Frame", {
		Size = UDim2.fromOffset(230, 52),
		BackgroundColor3 = Color3.fromRGB(255, 190, 40),
		Visible = false,
	}, gui)
	Ui.round(boostPill, 14)
	Ui.border(boostPill, 3)
	Ui.gloss(boostPill)
	Ui.gem(boostPill)
	Ui.autoScale(boostPill)
	-- Top-left on big screens; top-right on phones (the stats are top-left there)
	Ui.onResize(function()
		local compact = Ui.compact()
		boostPill.AnchorPoint = Vector2.new(if compact then 1 else 0, 0)
		boostPill.Position = if compact then UDim2.new(1, -Ui.margin(), 0, 8) else UDim2.fromOffset(Ui.margin(), 8)
	end)
	Ui.icon(boostPill, "Hud_ServerBoost", { Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(40, 40) })
	local boostTime = Ui.outlined(boostPill, {
		Position = UDim2.fromOffset(52, 2),
		Size = UDim2.new(1, -58, 0, 28),
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	})
	local boostBy = Ui.outlined(boostPill, {
		Position = UDim2.fromOffset(52, 28),
		Size = UDim2.new(1, -58, 0, 20),
		Font = Ui.FONT,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	})
	-- Your lure (Supply Shop / Store): "🧲 MEGA Lure 7:12", under the boost timer
	local lureLabel = Ui.outlined(gui, {
		Size = UDim2.fromOffset(230, 30),
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 120, 220),
		Text = "",
		Visible = false,
	})
	Ui.autoScale(lureLabel)
	Ui.onResize(function()
		local compact = Ui.compact()
		lureLabel.AnchorPoint = Vector2.new(if compact then 1 else 0, 0)
		lureLabel.TextXAlignment = if compact then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left
		lureLabel.Position = if compact
			then UDim2.new(1, -Ui.margin(), 0, 64)
			else UDim2.fromOffset(Ui.margin() + 4, 64)
	end)
	-- Your Invincibility Shield (Store): "🛡️ 4:12", under the lure, only while it runs
	local shieldLabel = Ui.outlined(gui, {
		Size = UDim2.fromOffset(230, 30),
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(120, 220, 255),
		Text = "",
		Visible = false,
	})
	Ui.autoScale(shieldLabel)
	Ui.onResize(function()
		local compact = Ui.compact()
		shieldLabel.AnchorPoint = Vector2.new(if compact then 1 else 0, 0)
		shieldLabel.TextXAlignment = if compact then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left
		shieldLabel.Position = if compact
			then UDim2.new(1, -Ui.margin(), 0, 94)
			else UDim2.fromOffset(Ui.margin() + 4, 94)
	end)
	local wasBoosted = false
	task.spawn(function()
		while gui.Parent do
			local shieldUntil = player:GetAttribute("InvincibleUntil")
			local shieldLeft = if typeof(shieldUntil) == "number" then shieldUntil - Workspace:GetServerTimeNow() else 0
			shieldLabel.Visible = shieldLeft > 0
			if shieldLeft > 0 then
				shieldLabel.Text = `🛡️ Invincible {clock(shieldLeft)}`
			end
			local lureUntil = player:GetAttribute("LureUntil")
			local lureLeft = if typeof(lureUntil) == "number" then lureUntil - Workspace:GetServerTimeNow() else 0
			lureLabel.Visible = lureLeft > 0
			if lureLeft > 0 then
				local lure = Config.Wild.Lures[player:GetAttribute("LureId") or ""]
				lureLabel.Text = `🧲 {if lure then lure.DisplayName else "Lure"} {clock(lureLeft)}`
			end
			local left = boostLeft()
			boostPill.Visible = left > 0
			if left > 0 then
				boostTime.Text = `{Config.Monetization.BoostMult}x COINS  {clock(left)}`
				local by = Workspace:GetAttribute("BoostBy")
				boostBy.Text = if typeof(by) == "string" then `thanks to {by}!` else ""
			end
			if (left > 0) ~= wasBoosted then
				wasBoosted = left > 0
				refreshStatus() -- the +% coins row
			end
			task.wait(0.5)
		end
	end)

	local function refreshObjective()
		local text = player:GetAttribute("Tip")
		if typeof(text) == "string" and text ~= "" then
			objective.Text = text
		else
			local data = Profile.Get()
			local parcels = #data.Parcels
			-- parcels a machine you own could still stamp (more XP), and parcels waiting inside machines
			local stampable = 0
			local owned: { [string]: boolean } = data.Machines or {}
			local processing: { [string]: any } = data.Processing or {}
			for _, parcel in data.Parcels do
				for id in owned do
					if not (parcel.Machines and parcel.Machines[id]) then
						stampable += 1
						break
					end
				end
			end
			local waiting = 0
			for _ in processing do
				waiting += 1
			end
			objective.Text = if stampable > 0
				then "📮 Stamp your parcels at your machines, then mail them!"
				elseif
					parcels > 0
				then `📦 Mail your {parcels} parcel{if parcels == 1 then "" else "s"} at Gruff's chute!`
				elseif waiting > 0 then "⏳ Collect your parcels from the machines"
				else `🐾 Grab a wild animal: {Ui.hint("hold E", "hold X", "tap and hold")}`
		end
		-- (the BOX screen has its own instructions; during the walkthrough, Gruff's panel is the only one)
		banner.Visible = player:GetAttribute("Stage") ~= "Box" and not Profile.Learning()
	end
	Profile.Watch(refreshObjective)
	player:GetAttributeChangedSignal("Tip"):Connect(refreshObjective)
	player:GetAttributeChangedSignal("Stage"):Connect(refreshObjective)
	Ui.onInputKind(refreshObjective) -- (hold E / hold X / tap and hold)

	---------------------------------------------------------------------------------------------------
	-- Popups (top center, under the banner): a colored header with who's talking, then the message
	-- Popups get their own layer above everything (even the BOX screen). During BOX they sit in the
	-- bottom-right corner so they don't cover the animal, the box or the anger meter.
	local popupLayer = Ui.make("ScreenGui", {
		Name = "Popups",
		ResetOnSpawn = false,
		DisplayOrder = 6,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, gui.Parent)
	-- Coins burst out from the middle of the screen and fly into their counter
	local function flyInto(iconKey: string, count: number, target: GuiObject)
		local view = popupLayer.AbsoluteSize
		local from = Vector2.new(view.X / 2, view.Y * 0.45)
		local size = math.floor(40 * Ui.screenScale())
		for i = 1, count do
			local icon = Ui.icon(popupLayer, iconKey, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(from.X, from.Y),
				Size = UDim2.fromOffset(size, size),
				ZIndex = 20,
			})
			-- Scatter out first...
			local angle = math.random() * math.pi * 2
			local spread = Vector2.new(math.cos(angle), math.sin(angle)) * (60 + math.random() * 90)
			local out = from + spread
			TweenService:Create(icon, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.fromOffset(out.X, out.Y),
			}):Play()
			-- ...then swoop into the counter, one after another
			task.delay(0.3 + i * 0.05, function()
				local goal = target.AbsolutePosition + Vector2.new(22, target.AbsoluteSize.Y / 2)
				local fly =
					TweenService:Create(icon, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
						Position = UDim2.fromOffset(goal.X, goal.Y),
						Size = UDim2.fromOffset(size * 0.6, size * 0.6),
					})
				fly:Play()
				fly.Completed:Once(function()
					icon:Destroy()
				end)
			end)
		end
	end

	-- A friendly little card: a round badge (Gruff's face, or the message's emoji) on the left, a short title,
	-- one short line, and the reward in big gold letters.
	local toast = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 124),
		Size = UDim2.fromOffset(420, 96),
		BackgroundColor3 = Ui.PAPER,
		Visible = false,
		ZIndex = 5,
	}, popupLayer)
	local function placeToast()
		-- In the corner while the BOX screen or a menu window is up, so it never covers what you're using
		local corner = player:GetAttribute("Stage") == "Box" or Menus.AnyOpen()
		toast.AnchorPoint = if corner then Vector2.new(1, 1) else Vector2.new(0.5, 0)
		toast.Position = if corner then UDim2.new(1, -14, 1, -14) else UDim2.new(0.5, 0, 0, 124)
	end
	player:GetAttributeChangedSignal("Stage"):Connect(placeToast)
	placeToast()
	Ui.round(toast, 18)
	local toastStroke = Ui.border(toast, 3)
	Ui.plate(toast)
	local toastSizer = Ui.autoScale(toast)
	local badge = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(70, 70),
		BackgroundColor3 = Ui.BLUE,
		ZIndex = 6,
	}, toast)
	Ui.round(badge, 35)
	Ui.border(badge, 3)
	local badgeIcon: GuiObject? = nil
	local title = Ui.outlined(toast, {
		Position = UDim2.fromOffset(94, 8),
		Size = UDim2.new(1, -106, 0, 28),
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		ZIndex = 6,
	})
	local body = Ui.label(toast, {
		Position = UDim2.fromOffset(94, 36),
		Size = UDim2.new(1, -106, 0, 22),
		TextSize = 17,
		TextColor3 = Color3.fromRGB(80, 70, 65),
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		Text = "",
		ZIndex = 6,
	})
	local footer = Ui.outlined(toast, {
		Position = UDim2.fromOffset(94, 58),
		Size = UDim2.new(1, -106, 0, 32),
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Ui.GOLD,
		Text = "",
		ZIndex = 6,
	})

	-- Popups: each shows about 2.8 seconds, but only 1 if another is waiting. At most 1 waits in line (older
	-- ones are dropped, so you only ever see what's current), and repeats of the same message are skipped.
	type Toast = { Who: string, Text: string, Foot: string?, Stars: number?, Color: Color3?, Icon: string? }
	local MAX_WAITING = 1
	local SHOW_ALONE, SHOW_BUSY = 2.8, 1
	local queue: { Toast } = {}
	local running = false
	local current: Toast? = nil
	-- "📦 Boxed a Hamster!" -> badge "📦", title "Boxed a Hamster!" (titles start with their emoji)
	local function splitEmoji(text: string): (string?, string)
		local first, rest = string.match(text, "^(%S+)%s+(.+)$")
		if first and rest and not string.find(first, "[%w%p]") then
			return first, rest
		end
		return nil, text
	end
	local function present(item: Toast)
		placeToast()
		local emoji, cleanTitle = splitEmoji(item.Who)
		title.Text = cleanTitle
		body.Text = item.Text
		footer.Text = item.Foot or ""
		local color = item.Color or Ui.BLUE
		badge.BackgroundColor3 = color
		if toastStroke then
			toastStroke.Color = color:Lerp(Color3.new(0, 0, 0), 0.45)
		end
		-- The badge: Gruff's face when he's talking, otherwise the title's emoji
		if badgeIcon then
			badgeIcon:Destroy()
			badgeIcon = nil
		end
		local iconKey = item.Icon or (if item.Who == "Postmaster Gruff" then "Button_Gruff" else nil)
		if iconKey then
			badgeIcon = Ui.icon(badge, iconKey, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.95, 0.95),
				ZIndex = 7,
			})
		else
			badgeIcon = Ui.outlined(badge, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.75, 0.75),
				TextScaled = true,
				Text = emoji or "✉️",
				ZIndex = 7,
			})
		end
		-- Short messages: no reward line, so the card is smaller
		local hasFoot = footer.Text ~= ""
		toast.Size = UDim2.fromOffset(420, if hasFoot then 96 else 76)
		body.TextWrapped = not hasFoot
		body.Size = UDim2.new(1, -106, 0, if hasFoot then 22 else 34)
		toast.Visible = true
		-- Pop in (from 80% of whatever size suits this screen)
		local full = Ui.screenScale()
		toastSizer.Scale = full * 0.8
		TweenService:Create(toastSizer, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = full,
		}):Play()
	end

	local function showToast(who: string, text: string, foot: string?, stars: number?, color: Color3?, icon: string?)
		local item: Toast = { Who = who, Text = text, Foot = foot, Stars = stars, Color = color, Icon = icon }
		local last = queue[#queue] or current
		if last and last.Who == who and last.Text == text then
			return -- the same message again
		end
		table.insert(queue, item)
		while #queue > MAX_WAITING do
			table.remove(queue, 1)
		end
		if running then
			return
		end
		running = true
		task.spawn(function()
			while #queue > 0 do
				local nextItem = table.remove(queue, 1) :: Toast
				current = nextItem
				present(nextItem)
				local shown = 0
				while shown < SHOW_ALONE and not (shown >= SHOW_BUSY and #queue > 0) do
					shown += task.wait(0.1)
				end
			end
			current = nil
			toast.Visible = false
			running = false
		end)
	end

	-- A giant red stamp that slams onto the screen (the "RETURN TO SENDER" moment)
	local function slamStamp(text: string)
		local stamp = Ui.make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromOffset(1400, 360),
			Rotation = -12,
			BackgroundTransparency = 1,
			Font = Ui.TITLE_FONT,
			TextScaled = true,
			TextColor3 = Color3.fromRGB(230, 30, 30),
			TextTransparency = 1,
			Text = text,
			ZIndex = 10,
		}, gui)
		Ui.make("UIStroke", { Thickness = 8, Color = Color3.fromRGB(110, 0, 0) }, stamp)
		local slam = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		TweenService:Create(stamp, slam, { Size = UDim2.fromOffset(700, 180), TextTransparency = 0 }):Play()
		task.delay(2.5, function()
			local fade = TweenService:Create(stamp, TweenInfo.new(0.5), { TextTransparency = 1 })
			fade:Play()
			fade.Completed:Wait()
			stamp:Destroy()
		end)
	end

	-- LEVEL UP: a big burst in the middle of the screen with what just unlocked
	local levelLayer = Ui.make("ScreenGui", {
		Name = "LevelUp",
		ResetOnSpawn = false,
		DisplayOrder = 7,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, gui.Parent)
	local function showLevelUp(level: number, coins: number, unlocks: { string })
		local card = Ui.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.4),
			Size = UDim2.fromOffset(420, 150 + #unlocks * 28),
			BackgroundTransparency = 1,
		}, levelLayer)
		local sizer = Ui.autoScale(card)
		Ui.outlined(card, {
			Size = UDim2.new(1, 0, 0, 70),
			TextSize = 64,
			TextColor3 = Ui.GOLD,
			Text = "LEVEL UP!",
		})
		Ui.outlined(card, {
			Position = UDim2.fromOffset(0, 66),
			Size = UDim2.new(1, 0, 0, 40),
			TextSize = 36,
			Text = `Level {level}   +{Format.Short(coins)} coins`,
		})
		for index, unlock in unlocks do
			Ui.outlined(card, {
				Position = UDim2.fromOffset(0, 104 + index * 28),
				Size = UDim2.new(1, 0, 0, 28),
				Font = Ui.FONT,
				TextSize = 22,
				TextColor3 = Color3.fromRGB(150, 255, 150),
				Text = `NEW: {unlock}`,
			})
		end
		local full = Ui.screenScale()
		sizer.Scale = full * 0.3
		TweenService
			:Create(sizer, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = full })
			:Play()
		task.delay(3.5, function()
			local fade = TweenService:Create(sizer, TweenInfo.new(0.3), { Scale = full * 0.01 })
			fade:Play()
			fade.Completed:Wait()
			card:Destroy()
		end)
	end

	local SPEAKER_COLORS: { [string]: Color3 } = {
		["Postmaster Gruff"] = Ui.BLUE,
		["Supply Shop"] = Ui.ORANGE,
		["Mail Chute"] = Ui.PURPLE,
		Stamp = Ui.RED,
		CHAOS = Ui.RED,
		Crew = Ui.GREEN,
	}

	local notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent
	-- Simple start: these popups wait until the walkthrough is done (events, the boss, quests, challenges)
	local QUIET_WHILE_LEARNING: { [string]: boolean } = {
		EventStart = true,
		EventWinner = true,
		BossStart = true,
		BossWin = true,
		BossLose = true,
		QuestDone = true,
		ChallengeDone = true,
		AllDailies = true,
	}
	notify.OnClientEvent:Connect(function(kind: string, data: { [string]: any })
		if QUIET_WHILE_LEARNING[kind] and Profile.Learning() then
			return
		end
		if kind == "Message" then
			showToast(data.Speaker, data.Text, nil, nil, SPEAKER_COLORS[data.Speaker] or Ui.BLUE)
		elseif kind == "Parcel" then
			-- A taped box went into your bag
			local variant = if data.Variant then Config.Variants.ById[data.Variant] else nil
			showToast(
				`📦 Boxed a {if variant then variant.DisplayName .. " " else ""}{data.Animal}! {string.rep(
					"★",
					data.Stars or 0
				)}`,
				`Mail it at the chute in town ({data.Count}/{data.Capacity} in your bag)`,
				`+{Format.Short(data.Coins)} coins`,
				nil,
				Ui.GREEN
			)
		elseif kind == "MailReceipt" then
			-- You mailed your bag at the chute: coins fly into your counter
			flyInto("Hud_Coins", math.clamp(6 + data.Count * 2, 8, 18), coinRow)
			local ready = data.OrdersReady or 0
			-- Gruff's speech bubble: his reaction, a word about your best animal, and the coins
			local variant = if data.BestVariant then Config.Variants.ById[data.BestVariant] else nil
			local about = if variant
				then `That {data.BestName} was {string.upper(variant.DisplayName)}. Not bad.`
				elseif ready > 0 then `{ready} order{if ready == 1 then "" else "s"} ready to claim in MENU.`
				elseif data.Count > 1 then `{data.Count} parcels. Best one: the {data.BestName}.`
				else `One {data.BestName}, delivered.`
			showToast(`"{data.Line}"`, about, `+{Format.Short(data.Coins)} coins`, nil, Ui.GOLD, "Button_Gruff")
		elseif kind == "Breakout" then
			slamStamp("RETURN TO SENDER")
		elseif kind == "XP" then
			-- A floating "+36 XP" by the level bar
			local float = Ui.outlined(levelRow, {
				Position = UDim2.fromOffset(150, -4),
				Size = UDim2.fromOffset(140, 28),
				TextSize = 24,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Color3.fromRGB(120, 220, 255),
				Text = `+{Format.Short(data.Amount)} XP`,
				ZIndex = 4,
			})
			local stroke = float:FindFirstChildOfClass("UIStroke")
			TweenService
				:Create(float, TweenInfo.new(1.2), { Position = UDim2.fromOffset(150, -50), TextTransparency = 1 })
				:Play()
			if stroke then
				TweenService:Create(stroke, TweenInfo.new(1.2), { Transparency = 1 }):Play()
			end
			task.delay(1.3, function()
				float:Destroy()
			end)
		elseif kind == "LevelUp" then
			showLevelUp(data.Level, data.Coins, data.Unlocks or {})
		elseif kind == "Prize" then
			flyInto("Hud_Coins", 12, coinRow) -- (the coin counter shows the "+123" itself)
		elseif kind == "ServerBoost" then
			showToast(
				`🚀 {data.Mult}x coins for everyone!`,
				`Thanks, {data.By}!`,
				`{clock(data.Seconds)} left`,
				nil,
				Ui.GOLD
			)
		elseif kind == "QuestDone" then
			local nextText = if data.Next then `Next: {data.Next}` else "That was the last one. Legend."
			showToast("✅ Quest done!", nextText, `+{Format.Short(data.Coins)} coins`, nil, Ui.GREEN)
		elseif kind == "EventStart" then
			local event = Config.Events.ById[data.Id]
			if event then
				showToast(`{event.Emoji} {event.DisplayName}!`, event.Description, nil, nil, Ui.PURPLE)
			end
		elseif kind == "EventWinner" then
			showToast(`🏁 {data.Player}`, data.Text, nil, nil, Ui.PURPLE)
		elseif kind == "StampedeCatch" then
			showToast("🐹 Caught one!", `You grabbed a wild {data.Animal}!`, nil, nil, Ui.GREEN)
		elseif kind == "BossStart" then
			if player:GetAttribute("SkipBoss") == true then
				return -- (they pressed Skip on the boss banner)
			end
			showToast(`⚔️ {data.Boss} has landed!`, "Press GO FIGHT to join the whole server.", nil, nil, Ui.RED)
		elseif kind == "BossWin" then
			showToast(
				`🏆 {data.Boss} boxed!`,
				if data.Top then `Top helper: {data.Top}` else "The whole server did it!",
				nil,
				nil,
				Ui.GOLD
			)
		elseif kind == "BossLose" then
			showToast(`📮 {data.Boss} got away`, "RETURN TO SENDER. It'll be back next hour.", nil, nil, Ui.GREY)
		elseif kind == "BossReward" then
			showToast(
				if data.Top then "👑 Top helper!" else "⚔️ Boss reward!",
				"Your next animal is a guaranteed Shiny.",
				`+{Format.Short(data.Coins)} coins`,
				nil,
				Ui.GOLD
			)
		elseif kind == "VariantFound" then
			local variant = Config.Variants.ById[data.Variant]
			if variant then
				showToast(
					`{variant.Emoji} {variant.DisplayName} {data.Animal}!`,
					`It pays {data.PayMult}x. Don't let it get away!`,
					nil,
					nil,
					variant.Color
				)
			end
		elseif kind == "VariantBoxed" then
			local variant = Config.Variants.ById[data.Variant]
			if variant and data.Player ~= player.DisplayName then
				showToast(
					`{variant.Emoji} {string.upper(variant.DisplayName)}!`,
					`{data.Player} just boxed a {variant.DisplayName} {data.Animal}!`,
					nil,
					nil,
					variant.Color
				)
			end
		elseif kind == "StreakLost" then
			showToast("💔 Streak lost", "Box with 4+ stars to start a new one.", nil, nil, Ui.RED)
		elseif kind == "ChallengeDone" then
			showToast(
				"✅ Challenge done!",
				"Claim it in the TASKS panel on the right.",
				`+{Format.Short(data.Coins)} coins`,
				nil,
				Ui.GREEN
			)
		elseif kind == "AllDailies" then
			showToast(
				"🏆 All dailies done!",
				`{data.Streak} day{if data.Streak == 1 then "" else "s"} in a row!`,
				`+{Format.Short(data.Coins)} coins`,
				nil,
				Ui.GOLD
			)
		elseif kind == "NewSpecies" then
			showToast(
				`📚 New animal: {data.Animal}!`,
				"Added to your COLLECTION (in MENU).",
				`+{Format.Short(data.XP)} XP`,
				nil,
				Ui.PURPLE
			)
		elseif kind == "MachineReady" then
			showToast(
				`✅ {data.Name}: {data.Count} parcel{if data.Count == 1 then "" else "s"} ready!`,
				"Hold E at the machine to collect them, stamped.",
				nil,
				nil,
				Ui.GREEN,
				`Machine_{data.Id}`
			)
		elseif kind == "EggHatched" then
			local rarity = Config.Rarity.ById[data.Rarity or "Common"]
			showToast(
				`🥚 {string.upper(rarity and rarity.DisplayName or "")} {data.Animal}!`,
				"It hatched right next to you. Grab it before someone else does!",
				nil,
				nil,
				if rarity then rarity.Color else Ui.GOLD,
				`Animal_{data.AnimalId}`
			)
		end
	end)
end

return Hud
