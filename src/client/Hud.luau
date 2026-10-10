--!strict
-- The on-screen HUD, kept clean: only what matters right now is on screen.
--   * one objective line across the top ("Box your hamster!"); your quest's progress swaps in for a few
--     seconds whenever it moves, and a status line shows under it only when there's something to say
--   * bottom-left: your level and coins. Next to the coins: a + (opens the Store), your coin boost when you
--     have one, and your delivery streak. Diamonds pop up for a moment when they change.
--   * bottom-right: your bag, only while you're carrying parcels (it pulses when it's nearly full)
--   Everything shrinks a little on small screens (Ui.autoScale), so phones keep the same layout.
--   * popups from Gruff and the chute (receipts get a red star-rating stamp), queued so none get lost
--   * the giant RETURN TO SENDER stamp
-- It only READS what the server tells it (Player attributes + the Notify remote).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Menus = require(script.Parent.Menus)
local Profile = require(script.Parent.Profile)
local QuestText = require(script.Parent.QuestText)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local Hud = {}

local COIN_GREEN = Color3.fromRGB(110, 255, 110)
local BAG_TAN = Color3.fromRGB(255, 205, 120)
local BOOST_ORANGE = Color3.fromRGB(255, 170, 60)
local DIAMOND_BLUE = Color3.fromRGB(120, 230, 255)

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

-- Shows `object` for `seconds`, then hides it again (showing it again restarts the clock)
local function flash(object: GuiObject, seconds: number)
	object.Visible = true
	local last = object:GetAttribute("FlashToken")
	local token = (if typeof(last) == "number" then last else 0) + 1
	object:SetAttribute("FlashToken", token)
	task.delay(seconds, function()
		if object:GetAttribute("FlashToken") == token then
			object.Visible = false
		end
	end)
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

	-- Next to the coins, left to right: a + (opens the Store), your coin boost, your delivery streak
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
	-- Your total coin boost, as a small glowing chip ("⚡+20%")
	local boostLabel = Ui.outlined(coinExtras, {
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 24,
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

	-- Delivery streak: a flame next to your coins ("🔥x5") that pops each time it grows
	local streakLabel = Ui.outlined(coinExtras, {
		LayoutOrder = 3,
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 30,
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
	-- Diamonds: pop up for a few seconds when they change (tap to open Diamond Upgrades). The Store and
	-- Diamond Upgrades show your total too.
	local diamondRow, diamondLabel = statRow(stack, 4, "Hud_Diamonds", DIAMOND_BLUE)
	diamondRow.Visible = false
	diamondRow.Size = UDim2.fromOffset(260, 38)
	diamondLabel.TextSize = 30
	local diamondButton = Ui.make("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 5,
	}, diamondRow)
	diamondButton.Activated:Connect(function()
		Menus.Open("Upgrades")
	end)
	local knownDiamonds: number? = nil
	Profile.Watch(function()
		local diamonds = Profile.Get().Diamonds or 0
		diamondLabel.Text = Format.Short(diamonds)
		if knownDiamonds and diamonds ~= knownDiamonds and not Profile.Learning() then
			flash(diamondRow, 4)
		end
		knownDiamonds = diamonds
	end)

	-- Level + XP bar (top of the stack)
	local levelRow, levelLabel = statRow(stack, 0, "Hud_Level", Ui.GOLD)
	levelLabel.Size = UDim2.fromOffset(90, 44)
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
	local xpText = Ui.outlined(xpBack, {
		Size = UDim2.fromScale(1, 1),
		Font = Ui.FONT,
		TextSize = 14,
		Text = "",
		ZIndex = 3,
	})
	stack.Size = UDim2.fromOffset(300, 140)
	-- Simple start: during the walkthrough it's just your coins. Your level and the + to the Store pop in
	-- when it's done.
	Profile.Watch(function()
		local learning = Profile.Learning()
		storePlus.Visible = not learning
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
	-- Quest tracker: Gruff's current main quest, under the objective. It only pops in for a few seconds when
	-- the quest moves (the Orders board always has it).
	local questPill = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 52),
		Visible = false,
		Size = UDim2.fromOffset(460, 30),
		BackgroundColor3 = Color3.fromRGB(40, 30, 20),
		BackgroundTransparency = 0.3,
	}, gui)
	Ui.round(questPill, 15)
	Ui.autoScale(questPill)
	local questFill = Ui.make("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.fromRGB(255, 190, 60),
		BackgroundTransparency = 0.55,
	}, questPill)
	Ui.round(questFill, 15)
	Ui.icon(questPill, "Hud_Quest", { Position = UDim2.fromOffset(6, 2), Size = UDim2.fromOffset(26, 26), ZIndex = 2 })
	local questLabel = Ui.outlined(questPill, {
		Position = UDim2.fromOffset(38, 0),
		Size = UDim2.new(1, -46, 1, 0),
		Font = Ui.FONT,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		ZIndex = 2,
	})
	local shownQuest: string? = nil
	local function refreshQuest()
		local quest = QuestText.Current()
		local text = if quest.Done
			then quest.Text
			else `QUEST: {quest.Text}{if quest.Progress ~= "" then "  ·  " .. quest.Progress else ""}`
		questLabel.Text = text
		questFill.Size = UDim2.fromScale(quest.Fraction, 1)
		-- (simple start: during the walkthrough, Gruff's panel is the only instruction)
		local allowed = player:GetAttribute("Stage") ~= "Box" and not Profile.Learning()
		if not allowed then
			questPill.Visible = false
		elseif shownQuest ~= nil and text ~= shownQuest then
			flash(questPill, 5)
		end
		shownQuest = text
	end
	Profile.Watch(refreshQuest)
	player:GetAttributeChangedSignal("Stage"):Connect(refreshQuest)

	local status = Ui.outlined(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 86),
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

		-- Total coin boost from rebirths, Golden Paws, the server boost, Premium and the group
		-- (the same math as Economy.PayoutMult on the server)
		local money = Config.Monetization
		local mult = 1 + profile.Rebirths * Config.Progression.Rebirth.PayoutBonusPerRebirth
		local paws = Config.Diamonds.ById.GoldenPaws
		mult *= 1 + Config.Diamonds.Bonus(paws, profile.Upgrades.GoldenPaws or 0) / 100
		if boostLeft() > 0 then
			mult *= money.BoostMult
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
	for _, attribute in { "Chaos", "Premium", "InGroup", "FriendsHere" } do
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
	local wasBoosted = false
	task.spawn(function()
		while gui.Parent do
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
	-- Coins (or diamonds) burst out from the middle of the screen and fly into their counter
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
	local function showLevelUp(level: number, coins: number, diamonds: number, unlocks: { string })
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
			Text = `Level {level}   +{Format.Short(coins)} coins   +{diamonds} 💎`,
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
			showLevelUp(data.Level, data.Coins, data.Diamonds or 0, data.Unlocks or {})
		elseif kind == "Diamonds" then
			flyInto("Hud_Diamonds", math.clamp(data.Amount, 3, 14), diamondRow)
			-- A floating "+40 💎" by the diamond counter
			local float = Ui.outlined(diamondRow, {
				Position = UDim2.fromOffset(120, -4),
				Size = UDim2.fromOffset(140, 30),
				TextSize = 28,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = DIAMOND_BLUE,
				Text = `+{Format.Short(data.Amount)} 💎`,
				ZIndex = 4,
			})
			local stroke = float:FindFirstChildOfClass("UIStroke")
			TweenService
				:Create(float, TweenInfo.new(1.4), { Position = UDim2.fromOffset(120, -56), TextTransparency = 1 })
				:Play()
			if stroke then
				TweenService:Create(stroke, TweenInfo.new(1.4), { Transparency = 1 }):Play()
			end
			task.delay(1.5, function()
				float:Destroy()
			end)
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
			showToast(
				"✅ Quest done!",
				nextText,
				`+{Format.Short(data.Coins)} coins  +{data.Diamonds or 0} 💎`,
				nil,
				Ui.GREEN
			)
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
				`+{data.Diamonds} 💎  +{Format.Short(data.Coins)} coins`,
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
				"Claim it in MENU, then ORDERS.",
				`+{data.Diamonds} 💎  +{Format.Short(data.Coins)} coins`,
				nil,
				Ui.GREEN
			)
		elseif kind == "AllDailies" then
			showToast(
				"🏆 All dailies done!",
				`{data.Streak} day{if data.Streak == 1 then "" else "s"} in a row!`,
				`+{data.Diamonds} 💎`,
				nil,
				Ui.GOLD
			)
		elseif kind == "NewSpecies" then
			showToast(
				`📚 New animal: {data.Animal}!`,
				"Added to your collection in the BAG.",
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
