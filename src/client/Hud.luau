--!strict
-- The on-screen HUD: coins, a tip banner for the current stage, Gruff's popups and receipts, and the big
-- RETURN TO SENDER stamp. It only READS what the server tells it (Player attributes + the Notify remote).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Profile = require(script.Parent.Profile)

local player = Players.LocalPlayer

local Hud = {}

local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)
local PANEL = Color3.fromRGB(30, 30, 36)

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

local function round(parent: Instance, radius: number?)
	make("UICorner", { CornerRadius = UDim.new(0, radius or 10) }, parent)
end

-- Short numbers for big amounts: 9500, 12.5K, 3.2M, 1.05B
local UNITS: { { From: number, Divide: number, Suffix: string } } = {
	{ From = 1e12, Divide = 1e12, Suffix = "T" },
	{ From = 1e9, Divide = 1e9, Suffix = "B" },
	{ From = 1e6, Divide = 1e6, Suffix = "M" },
	{ From = 1e4, Divide = 1e3, Suffix = "K" },
}
function Hud.Short(n: number): string
	for _, unit in UNITS do
		if math.abs(n) >= unit.From then
			local scaled = n / unit.Divide
			local text = if math.abs(scaled) >= 100
				then tostring(math.floor(scaled))
				else (string.gsub(string.format("%.1f", scaled), "%.0$", ""))
			return text .. unit.Suffix
		end
	end
	return tostring(n)
end

function Hud.Start()
	local gui = make("ScreenGui", { Name = "MailATigerHud", ResetOnSpawn = false }, player:WaitForChild("PlayerGui"))

	-- Coins (top center)
	local coinsLabel = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(180, 40),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.2,
		Font = FONT,
		TextSize = 26,
		TextColor3 = Color3.fromRGB(255, 215, 80),
		Text = "0 coins",
	}, gui)
	round(coinsLabel)

	-- Your mail bag (right of the coins): parcels carried / capacity
	local bagLabel = make("TextLabel", {
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0.5, 98, 0, 8),
		Size = UDim2.fromOffset(110, 40),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.2,
		Font = FONT,
		TextSize = 22,
		TextColor3 = Color3.fromRGB(215, 175, 105),
		Text = "Bag 0/3",
	}, gui)
	round(bagLabel)

	-- Status line under the coins: rebirth bonus, next-job stamp, and a warning if progress isn't saving
	local status = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 50),
		Size = UDim2.fromOffset(520, 20),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 16,
		TextColor3 = WHITE,
		TextStrokeTransparency = 0.4,
		Text = "",
	}, gui)
	-- The coin counter rolls up to its new value, bounces, and floats a "+123" when you get paid
	local shownCoins = Instance.new("NumberValue")
	local coinScale = make("UIScale", { Scale = 1 }, coinsLabel)
	local knownCoins: number? = nil
	shownCoins.Changed:Connect(function(value: number)
		coinsLabel.Text = `{Hud.Short(math.round(value))} coins`
	end)
	local function showCoins(coins: number)
		local before = knownCoins
		knownCoins = coins
		if before == nil then
			shownCoins.Value = coins
			coinsLabel.Text = `{Hud.Short(coins)} coins`
			return
		end
		if coins == before then
			return
		end
		TweenService:Create(shownCoins, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Value = coins }):Play()
		coinScale.Scale = 1.15
		TweenService:Create(coinScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		if coins > before then
			local gain = make("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 44),
				Size = UDim2.fromOffset(200, 30),
				BackgroundTransparency = 1,
				Font = FONT,
				TextSize = 26,
				TextColor3 = Color3.fromRGB(255, 215, 80),
				TextStrokeTransparency = 0.3,
				Text = `+{Hud.Short(coins - before)}`,
			}, gui)
			local rise = TweenService:Create(gain, TweenInfo.new(1.1), {
				Position = UDim2.new(0.5, 0, 0, 90),
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			})
			rise:Play()
			rise.Completed:Once(function()
				gain:Destroy()
			end)
		end
	end

	local function refreshStatus()
		local profile = Profile.Get()
		showCoins(profile.Coins)
		local capacity = Profile.BagCapacity(profile)
		bagLabel.Text = `Bag {#profile.Parcels}/{capacity}`
		bagLabel.TextColor3 = if #profile.Parcels >= capacity
			then Color3.fromRGB(255, 110, 100)
			else Color3.fromRGB(215, 175, 105)
		local parts = {}
		if player:GetAttribute("Chaos") then
			table.insert(parts, "CHAOS MODE (+50% pay): others can spook your animal and shove you")
		end
		if profile.Rebirths > 0 then
			local bonus = math.round(profile.Rebirths * Config.Progression.Rebirth.PayoutBonusPerRebirth * 100)
			table.insert(parts, `Rebirth {profile.Rebirths} (+{bonus}% coins)`)
		end
		local stamp = profile.SelectedStamp and Config.Stamps.ById[profile.SelectedStamp]
		if stamp then
			table.insert(parts, `Next job: {stamp.DisplayName} stamp`)
		end
		if player:GetAttribute("TemporaryData") then
			table.insert(parts, "⚠ Progress isn't saving (DataStores off)")
		end
		status.Text = table.concat(parts, "   ·   ")
		status.TextColor3 = if player:GetAttribute("Chaos") then Color3.fromRGB(255, 120, 120) else WHITE
	end
	Profile.Watch(refreshStatus)
	player:GetAttributeChangedSignal("Chaos"):Connect(refreshStatus)

	-- Tip banner (bottom center): what to do right now
	local tip = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -30),
		Size = UDim2.fromOffset(620, 40),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.25,
		Font = FONT,
		TextSize = 20,
		TextWrapped = true,
		TextColor3 = WHITE,
		Text = "",
	}, gui)
	round(tip)
	local function refreshTip()
		local text = player:GetAttribute("Tip")
		if typeof(text) == "string" and text ~= "" then
			tip.Text = text
		else
			local parcels = #Profile.Get().Parcels
			tip.Text = if parcels > 0
				then `You have {parcels} parcel{if parcels == 1 then "" else "s"} in your bag: mail them at the Mail Chute (hold E), or box another animal!`
				else "Go to the Animal Pen and choose an animal!"
		end
		tip.Visible = player:GetAttribute("Stage") ~= "Box" -- the BOX screen has its own instructions
	end
	Profile.Watch(refreshTip)
	player:GetAttributeChangedSignal("Tip"):Connect(refreshTip)
	player:GetAttributeChangedSignal("Stage"):Connect(refreshTip)
	refreshTip()

	-- Gruff popup (top center, below coins)
	local toast = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 60),
		Size = UDim2.fromOffset(480, 110),
		BackgroundColor3 = Color3.fromRGB(250, 240, 220),
		Visible = false,
	}, gui)
	round(toast)
	make("UIStroke", { Thickness = 3, Color = Color3.fromRGB(120, 70, 40) }, toast)
	local speaker = make("TextLabel", {
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.new(1, -28, 0, 24),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(160, 40, 40),
		Text = "",
	}, toast)
	local body = make("TextLabel", {
		Position = UDim2.fromOffset(14, 30),
		Size = UDim2.new(1, -28, 0, 46),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 19,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Color3.fromRGB(40, 30, 25),
		Text = "",
	}, toast)
	local footer = make("TextLabel", {
		Position = UDim2.fromOffset(14, 78),
		Size = UDim2.new(1, -28, 0, 26),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(200, 140, 0),
		Text = "",
	}, toast)

	local toastId = 0
	local function showToast(who: string, text: string, foot: string?)
		toastId += 1
		local myId = toastId
		speaker.Text = who
		body.Text = text
		footer.Text = foot or ""
		toast.Visible = true
		task.delay(5, function()
			if toastId == myId then
				toast.Visible = false
			end
		end)
	end

	-- A giant red stamp that slams onto the screen (the "RETURN TO SENDER" moment)
	local function slamStamp(text: string)
		local stamp = make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromOffset(1400, 360),
			Rotation = -12,
			BackgroundTransparency = 1,
			Font = FONT,
			TextScaled = true,
			TextColor3 = Color3.fromRGB(220, 30, 30),
			TextTransparency = 1,
			Text = text,
			ZIndex = 10,
		}, gui)
		make("UIStroke", { Thickness = 6, Color = Color3.fromRGB(120, 0, 0) }, stamp)
		local slam = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		TweenService:Create(stamp, slam, { Size = UDim2.fromOffset(700, 180), TextTransparency = 0 }):Play()
		task.delay(2.5, function()
			local fade = TweenService:Create(stamp, TweenInfo.new(0.5), { TextTransparency = 1 })
			fade:Play()
			fade.Completed:Wait()
			stamp:Destroy()
		end)
	end

	local notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent
	notify.OnClientEvent:Connect(function(kind: string, data: { [string]: any })
		if kind == "Message" then
			showToast(data.Speaker, data.Text)
		elseif kind == "Parcel" then
			-- A taped box went into your bag
			local stars = string.rep("★", data.Stars) .. string.rep("☆", 5 - data.Stars)
			local stamp = if data.Stamp then `   {data.Stamp}` else ""
			showToast(
				`Taped!  ·  {data.Animal} is in your bag ({data.Count}/{data.Capacity})`,
				"Carry it to the Mail Chute in town and hold E to mail it.",
				`{stars}   worth {data.Coins} coins{stamp}`
			)
		elseif kind == "MailReceipt" then
			-- You mailed your bag at the chute
			local extras = if data.OrderBonus > 0 then `   +{data.OrderBonus} from orders!` else ""
			local plural = if data.Count == 1 then "parcel" else "parcels"
			showToast(
				`Postmaster Gruff  ·  {data.Count} {plural} mailed ({data.Chute})`,
				`"{data.Line}"   {table.concat(data.Lines, ",  ")}`,
				`+{data.Coins} coins{extras}`
			)
		elseif kind == "Roar" then
			showToast("ROOOOAR!", "It roared at you! You're frozen in fear for a second.")
		elseif kind == "Freeze" then
			showToast("Brrr!", "It froze you solid for a moment!")
		elseif kind == "Spray" then
			showToast("Pssssht!", "You got sprayed. Oh no. OH NO.")
		elseif kind == "Breakout" then
			slamStamp("RETURN TO SENDER")
		end
	end)
end

return Hud
