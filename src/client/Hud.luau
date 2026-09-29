--!strict
-- The on-screen HUD: coins, box HP and rage bars, a hint line, and Gruff's speech/receipt popup.
-- It only READS what the server tells it (Player attributes + the Notify remote).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local Hud = {}

local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)
local PANEL = Color3.fromRGB(30, 30, 36)
local HP_FULL = Color3.fromRGB(90, 200, 90)
local HP_EMPTY = Color3.fromRGB(230, 70, 60)
local RAGE = Color3.fromRGB(255, 140, 40)

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

-- A labelled progress bar. Returns the fill frame and the text label.
local function bar(parent: Instance, y: number, color: Color3): (Frame, TextLabel)
	local back = make("Frame", {
		Size = UDim2.new(1, -20, 0, 20),
		Position = UDim2.fromOffset(10, y),
		BackgroundColor3 = Color3.fromRGB(55, 55, 60),
	}, parent)
	round(back, 10)
	local fill = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color }, back)
	round(fill, 10)
	local label = make("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 15,
		TextColor3 = WHITE,
		TextStrokeTransparency = 0.4,
		ZIndex = 2,
		Text = "",
	}, back)
	return fill, label
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
	task.spawn(function()
		local coins = player:WaitForChild("leaderstats"):WaitForChild("Coins") :: IntValue
		local function update()
			coinsLabel.Text = `{coins.Value} coins`
		end
		coins.Changed:Connect(update)
		update()
	end)

	-- Carry panel (bottom center, only while carrying)
	local panel = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Size = UDim2.fromOffset(340, 88),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.2,
	}, gui)
	round(panel)
	local title = make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 20,
		TextColor3 = WHITE,
		Text = "",
	}, panel)
	local hpFill, hpText = bar(panel, 32, HP_FULL)
	local rageFill, rageText = bar(panel, 58, RAGE)

	-- Hint (bottom center, when not carrying)
	local hint = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -30),
		Size = UDim2.fromOffset(460, 36),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.3,
		Font = FONT,
		TextSize = 20,
		TextColor3 = WHITE,
		Text = "",
	}, gui)
	round(hint)

	local function refresh()
		local carrying = player:GetAttribute("Carrying") == true
		panel.Visible = carrying
		hint.Visible = not carrying

		if carrying then
			local hp = player:GetAttribute("HP") or 0
			local maxHp = player:GetAttribute("MaxHP") or 1
			local rage = player:GetAttribute("Rage") or 0
			local hpFraction = math.clamp(hp / maxHp, 0, 1)

			local sleeping = if player:GetAttribute("Asleep") then "  (asleep - don't bump it!)" else ""
			title.Text =
				`{player:GetAttribute("AnimalName") or "?"} in a {player:GetAttribute("BoxName") or "box"}{sleeping}`
			hpFill.Size = UDim2.fromScale(hpFraction, 1)
			hpFill.BackgroundColor3 = HP_EMPTY:Lerp(HP_FULL, hpFraction)
			hpText.Text = `BOX  {hp} / {maxHp}`
			rageFill.Size = UDim2.fromScale(math.clamp(rage / 100, 0, 1), 1)
			rageText.Text = if rage >= 70 then `RAGE  {rage}  - IT'S RATTLING!` else `RAGE  {rage}`
		elseif player:GetAttribute("Loose") == true then
			hint.Text = "Your animal escaped! Find it and hold E to catch it."
		else
			hint.Text = "Go to the Animal Pen and choose an animal!"
		end
	end
	for _, name in { "Carrying", "HP", "MaxHP", "Rage", "AnimalName", "BoxName", "Loose", "Asleep" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()

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

	-- A giant red stamp that slams onto the screen (the "Doorstep Breakout" moment)
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
			local time = string.format("%.1f", data.Seconds)
			showToast("Postmaster Gruff", `"{data.Line}"`, `{stars}   +{data.Coins} coins   ({time}s)`)
		elseif kind == "Bell" then
			showToast("*DING DONG*", "The door bell spooked your animal!")
		elseif kind == "Roar" then
			showToast("ROOOOAR!", "The tiger roared! Anyone close by is stunned.")
		elseif kind == "Breakout" then
			slamStamp("RETURN TO SENDER")
		end
	end)
end

return Hud
