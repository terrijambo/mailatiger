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
	Profile.Watch(function()
		local profile = Profile.Get()
		coinsLabel.Text = `{profile.Coins} coins`
		local parts = {}
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
	end)

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
			tip.Text = "Go to the Animal Pen and choose an animal!"
		end
		tip.Visible = player:GetAttribute("Stage") ~= "Box" -- the BOX screen has its own instructions
	end
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
		elseif kind == "Receipt" then
			local stars = string.rep("★", data.Stars) .. string.rep("☆", 5 - data.Stars)
			local time = string.format("%.0f", data.Seconds)
			local extras = ""
			if data.Stamp then
				extras ..= `   {data.Stamp}`
			end
			if data.OrderBonus and data.OrderBonus > 0 then
				extras ..= `   +{data.OrderBonus} order!`
			end
			showToast(
				`Postmaster Gruff  ·  {data.Animal} mailed!`,
				`"{data.Line}"`,
				`{stars}   +{data.Coins} coins   ({time}s){extras}`
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
