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

-- Short numbers (1k, 12.5k, 1M): see src/shared/Format.luau
Hud.Short = Format.Short

-- One row of the stats stack: an emoji icon and a big outlined value
local function statRow(parent: Instance, order: number, icon: string, color: Color3): (Frame, TextLabel)
	local row = Ui.make("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(260, 44),
		BackgroundTransparency = 1,
	}, parent)
	Ui.make("TextLabel", {
		Size = UDim2.fromOffset(44, 44),
		BackgroundTransparency = 1,
		Font = Ui.FONT,
		TextScaled = true,
		Text = icon,
	}, row)
	local value = Ui.outlined(row, {
		Position = UDim2.fromOffset(52, 0),
		Size = UDim2.new(1, -52, 1, 0),
		TextSize = 38,
		TextXAlignment = Enum.TextXAlignment.Left,
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
	Ui.autoScale(stack) -- smaller on phones (labels don't block the thumbstick underneath)
	Ui.make("UIListLayout", {
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
	}, stack)
	local boostRow, boostLabel = statRow(stack, 1, "⚡", BOOST_ORANGE)
	local _, bagLabel = statRow(stack, 2, "📦", BAG_TAN)
	local coinRow, coinsLabel = statRow(stack, 3, "💰", COIN_GREEN)

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
	local status = Ui.outlined(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 64),
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

		-- Total coin boost from rebirths, passes, Premium and the group
		local money = Config.Monetization
		local mult = 1 + profile.Rebirths * Config.Progression.Rebirth.PayoutBonusPerRebirth
		if player:GetAttribute("Pass_DoubleCoins") then
			mult *= money.DoubleCoinsMult
		end
		if player:GetAttribute("Premium") then
			mult *= money.PremiumPayoutMult
		end
		if player:GetAttribute("InGroup") then
			mult *= money.GroupPayoutMult
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
	for _, attribute in { "Chaos", "Premium", "InGroup", "Pass_DoubleCoins" } do
		player:GetAttributeChangedSignal(attribute):Connect(refreshStatus)
	end

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
	local toast = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 94),
		Size = UDim2.fromOffset(470, 124),
		BackgroundColor3 = Ui.PAPER,
		Visible = false,
		ZIndex = 5,
	}, popupLayer)
	local function placeToast()
		-- In the corner while the BOX screen or a menu window is up, so it never covers what you're using
		local corner = player:GetAttribute("Stage") == "Box" or Menus.AnyOpen()
		toast.AnchorPoint = if corner then Vector2.new(1, 1) else Vector2.new(0.5, 0)
		toast.Position = if corner then UDim2.new(1, -14, 1, -14) else UDim2.new(0.5, 0, 0, 94)
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

	-- Popups wait their turn: each one shows for 5 seconds, or 2.5 if another is waiting behind it
	type Toast = { Who: string, Text: string, Foot: string?, Stars: number?, Color: Color3? }
	local queue: { Toast } = {}
	local running = false

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
		table.insert(queue, { Who = who, Text = text, Foot = foot, Stars = stars, Color = color })
		if running then
			return
		end
		running = true
		task.spawn(function()
			while #queue > 0 do
				present(table.remove(queue, 1) :: Toast)
				local shown = 0
				while shown < 5 and not (shown >= 2.5 and #queue > 0) do
					shown += task.wait(0.1)
				end
			end
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
			showToast(
				`📦 Taped! {data.Animal} is in your bag ({data.Count}/{data.Capacity})`,
				"Carry it to the Mail Chute in town and hold E to mail it.",
				`worth {Format.Short(data.Coins)} coins{stamp}`,
				data.Stars,
				Ui.GREEN
			)
		elseif kind == "MailReceipt" then
			-- You mailed your bag at the chute
			local extras = if data.OrderBonus > 0 then `   +{Format.Short(data.OrderBonus)} from orders!` else ""
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
		end
	end)
end

return Hud
