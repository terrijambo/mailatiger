--!strict
-- The on-screen HUD, in the style of popular simulators:
--   * a big objective banner across the top ("Box your hamster!"), with a status line under it
--   * your coins, bag and boosts stacked in the bottom-left corner, with big outlined numbers
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
	-- The bag and your coin boost live in the bottom-right corner (top-right on phones)
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
	local boostRow, boostLabel = statRow(rightStack, 1, "Hud_Boost", BOOST_ORANGE, true)
	local _, bagLabel = statRow(rightStack, 2, "Hud_Bag", BAG_TAN, true)
	local coinRow, coinsLabel = statRow(stack, 3, "Hud_Coins", COIN_GREEN)

	-- Delivery streak: a flame next to your coins ("🔥x5") that pops each time it grows
	local streakLabel = Ui.outlined(coinRow, {
		Position = UDim2.fromOffset(178, 2),
		Size = UDim2.fromOffset(120, 40),
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 150, 40),
		Text = "",
		Visible = false,
		ZIndex = 3,
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
	-- Diamonds (tap to open Diamond Upgrades)
	local diamondRow, diamondLabel = statRow(stack, 4, "Hud_Diamonds", DIAMOND_BLUE)
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
	Profile.Watch(function()
		diamondLabel.Text = Format.Short(Profile.Get().Diamonds or 0)
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
	-- Objective banner (top center) + a status line under it
	local banner = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.new(0.62, 0, 0, 58),
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
		Size = UDim2.new(0.8, 0, 0, 44),
		TextScaled = true,
		Text = "",
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 38 }, objective)
	-- Quest tracker: Gruff's current main quest, under the banner
	local questPill = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 64),
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
	local function refreshQuest()
		local quest = QuestText.Current()
		questLabel.Text = if quest.Done
			then quest.Text
			else `QUEST: {quest.Text}{if quest.Progress ~= "" then "  ·  " .. quest.Progress else ""}`
		questFill.Size = UDim2.fromScale(quest.Fraction, 1)
		questPill.Visible = player:GetAttribute("Stage") ~= "Box"
	end
	Profile.Watch(refreshQuest)
	player:GetAttributeChangedSignal("Stage"):Connect(refreshQuest)

	local status = Ui.outlined(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 98),
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
		bagLabel.TextColor3 = if #profile.Parcels >= capacity then Color3.fromRGB(255, 100, 90) else BAG_TAN

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
		boostRow.Visible = mult > 1.001
		boostLabel.Text = `+{math.round((mult - 1) * 100)}% coins`

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
	local wasBoosted = false
	task.spawn(function()
		while gui.Parent do
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
			local parcels = #Profile.Get().Parcels
			objective.Text = if parcels > 0
				then `📦 Mail your {parcels} parcel{if parcels == 1 then "" else "s"} at the Mail Chute!`
				else "🐹 Pick an animal at the PEN!"
		end
		banner.Visible = player:GetAttribute("Stage") ~= "Box" -- the BOX screen has its own instructions
	end
	Profile.Watch(refreshObjective)
	player:GetAttributeChangedSignal("Tip"):Connect(refreshObjective)
	player:GetAttributeChangedSignal("Stage"):Connect(refreshObjective)
	refreshObjective()

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

	local toast = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 124),
		Size = UDim2.fromOffset(470, 124),
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
	Ui.round(toast, 14)
	Ui.border(toast, 3)
	local toastSizer = Ui.autoScale(toast)
	local header = Ui.make("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Ui.BLUE,
		ZIndex = 5,
	}, toast)
	Ui.round(header, 14)
	Ui.gloss(header)
	local speaker = Ui.outlined(header, {
		Position = UDim2.fromOffset(14, 2),
		Size = UDim2.new(1, -28, 1, -4),
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		ZIndex = 6,
	})
	local body = Ui.label(toast, {
		Position = UDim2.fromOffset(14, 40),
		Size = UDim2.new(1, -28, 0, 48),
		TextSize = 18,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
		ZIndex = 6,
	})
	local footer = Ui.outlined(toast, {
		Position = UDim2.fromOffset(14, 88),
		Size = UDim2.new(1, -28, 0, 30),
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Ui.GOLD,
		Text = "",
		ZIndex = 6,
	})

	-- A red rating stamp that thumps onto receipts (e.g. "★★★★☆")
	local ratingStamp = Ui.make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -78, 1, -24),
		Size = UDim2.fromOffset(140, 42),
		Rotation = -10,
		BackgroundTransparency = 1,
		Font = Ui.TITLE_FONT,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(220, 40, 40),
		Text = "",
		Visible = false,
		ZIndex = 7,
	}, toast)
	Ui.make("UIStroke", { Thickness = 2, Color = Color3.fromRGB(110, 0, 0) }, ratingStamp)

	-- Popups: each shows about 3.5 seconds, but only 1.2 if another is waiting. At most 2 wait in line (older
	-- ones are dropped, so you only ever see what's current), and repeats of the same message are skipped.
	type Toast = { Who: string, Text: string, Foot: string?, Stars: number?, Color: Color3? }
	local MAX_WAITING = 2
	local SHOW_ALONE, SHOW_BUSY = 3.5, 1.2
	local queue: { Toast } = {}
	local running = false
	local current: Toast? = nil
	local function present(item: Toast)
		placeToast()
		speaker.Text = item.Who
		header.BackgroundColor3 = item.Color or Ui.BLUE
		body.Text = item.Text
		footer.Text = item.Foot or ""
		toast.Visible = true
		-- Pop in (from 80% of whatever size suits this screen)
		local full = Ui.screenScale()
		toastSizer.Scale = full * 0.8
		TweenService:Create(toastSizer, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = full,
		}):Play()
		local stars = item.Stars
		ratingStamp.Visible = stars ~= nil
		if stars then
			ratingStamp.Text = string.rep("★", stars) .. string.rep("☆", 5 - stars)
			ratingStamp.Size = UDim2.fromOffset(280, 84)
			ratingStamp.TextTransparency = 1
			task.delay(0.35, function()
				TweenService:Create(ratingStamp, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Size = UDim2.fromOffset(140, 42),
					TextTransparency = 0,
				}):Play()
			end)
		end
	end

	local function showToast(who: string, text: string, foot: string?, stars: number?, color: Color3?)
		local item: Toast = { Who = who, Text = text, Foot = foot, Stars = stars, Color = color }
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
	notify.OnClientEvent:Connect(function(kind: string, data: { [string]: any })
		if kind == "Message" then
			showToast(data.Speaker, data.Text, nil, nil, SPEAKER_COLORS[data.Speaker] or Ui.BLUE)
		elseif kind == "Parcel" then
			-- A taped box went into your bag
			local stamp = if data.Stamp then `   {data.Stamp}` else ""
			local variant = if data.Variant then Config.Variants.ById[data.Variant] else nil
			local streak = if data.Streak and data.Streak > 1.001
				then `   🔥 streak x{math.floor(data.Streak * 100 + 0.5) / 100}`
				else ""
			showToast(
				`📦 Taped! {if variant then variant.Emoji .. " " .. variant.DisplayName .. " " else ""}{data.Animal} is in your bag ({data.Count}/{data.Capacity})`,
				`Carry it to the Mail Chute in town and {Ui.hint("hold E", "hold X", "hold the Mail button")} to mail it.`,
				`worth {Format.Short(data.Coins)} coins{stamp}{streak}`,
				data.Stars,
				Ui.GREEN
			)
		elseif kind == "MailReceipt" then
			-- You mailed your bag at the chute: coins fly into your counter
			flyInto("Hud_Coins", math.clamp(6 + data.Count * 2, 8, 18), coinRow)
			local ready = data.OrdersReady or 0
			local extras = if ready > 0
				then `   📋 {ready} order{if ready == 1 then "" else "s"} ready to CLAIM!`
				else ""
			local plural = if data.Count == 1 then "parcel" else "parcels"
			showToast(
				`✉️ {data.Count} {plural} mailed ({data.Chute})`,
				`"{data.Line}"   {table.concat(data.Lines, ",  ")}`,
				`+{Format.Short(data.Coins)} coins{extras}`,
				data.Best,
				Ui.GOLD
			)
		elseif kind == "Roar" then
			showToast("ROOOOAR!", "It roared at you! You're frozen in fear for a second.", nil, nil, Ui.RED)
		elseif kind == "Freeze" then
			showToast("Brrr!", "It froze you solid for a moment!", nil, nil, Ui.BLUE)
		elseif kind == "Spray" then
			showToast("Pssssht!", "You got sprayed. Oh no. OH NO.", nil, nil, Ui.GREEN)
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
				"🚀 SERVER BOOST!",
				`{data.By} gave EVERYONE {data.Mult}x coins! Go mail some animals.`,
				`{clock(data.Seconds)} left`,
				nil,
				Ui.GOLD
			)
		elseif kind == "QuestDone" then
			local nextText = if data.Next then `Next: {data.Next}` else "That was the last one. Legend."
			showToast(
				`✅ Quest complete: {data.Text}`,
				nextText,
				`+{Format.Short(data.XP)} XP   +{Format.Short(data.Coins)} coins   +{data.Diamonds or 0} 💎`,
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
			showToast(
				`⚔️ {data.Boss} HAS LANDED!`,
				"Step on the red BOSS pad in the plaza and help pin it down and box it!",
				nil,
				nil,
				Ui.RED
			)
		elseif kind == "BossWin" then
			showToast(
				`🏆 {data.Boss} BOXED!`,
				if data.Top then `Top helper: {data.Top} (crown until the next boss!)` else "The whole server did it!",
				nil,
				nil,
				Ui.GOLD
			)
		elseif kind == "BossLose" then
			showToast(`📮 {data.Boss} got away`, "RETURN TO SENDER. It'll be back next hour.", nil, nil, Ui.GREY)
		elseif kind == "BossReward" then
			showToast(
				if data.Top then "👑 You were the top helper!" else "⚔️ Boss reward",
				if data.Mailed
					then "Mailed it in time: rewards x1.5! Your next job is a guaranteed Shiny!"
					else "Your next job is a guaranteed Shiny!",
				`CLAIM +{data.Diamonds} 💎  +{Format.Short(data.Coins)} coins in MENU > ORDERS`,
				nil,
				Ui.GOLD
			)
		elseif kind == "VariantFound" then
			local variant = Config.Variants.ById[data.Variant]
			if variant then
				showToast(
					`{variant.Emoji} A {string.upper(variant.DisplayName)} {data.Animal}!`,
					`Rare find! It pays {data.PayMult}x coins and extra XP. Don't let it get away!`,
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
			showToast(
				`💔 Streak lost (x{data.Count})`,
				`Your delivery streak ended ({data.Why}). Box with 4+ stamps to build it back up!`,
				nil,
				nil,
				Ui.RED
			)
		elseif kind == "ChallengeDone" then
			showToast(
				`✅ {if data.Weekly then "Weekly" else "Daily"} challenge done!`,
				data.Text,
				`+{data.Diamonds} 💎   +{Format.Short(data.Coins)} coins`,
				nil,
				Ui.GREEN
			)
		elseif kind == "AllDailies" then
			showToast(
				"🏆 All daily challenges done!",
				`{data.Streak} day{if data.Streak == 1 then "" else "s"} in a row. Come back tomorrow to grow the bonus!`,
				`+{data.Diamonds} 💎`,
				nil,
				Ui.GOLD
			)
		elseif kind == "NewSpecies" then
			showToast(
				`📚 New animal mailed: {data.Animal}!`,
				"It's in your collection (BAG, then Animals).",
				`+{Format.Short(data.XP)} XP`,
				nil,
				Ui.PURPLE
			)
		end
	end)
end

return Hud
