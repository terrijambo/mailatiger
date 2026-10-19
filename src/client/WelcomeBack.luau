--!strict
-- The "Welcome back!" card (WelcomeService on the server sends it when a returning player joins): the coins
-- your chute earned while you were away, and the "New this week" lines once per update (Config/News.luau).
-- Waits for a calm moment (not boxing, no menu open), then slides up. Tap OK or wait and it goes away.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Format)
local Menus = require(script.Parent.Menus)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local WelcomeBack = {}

local WIDTH = 440
local LINE_HEIGHT = 26

local function calm(): boolean
	local playerGui = player:FindFirstChild("PlayerGui")
	local boxing = playerGui and playerGui:FindFirstChild("BoxingScreen") :: ScreenGui?
	return not (boxing and boxing.Enabled) and not Menus.AnyOpen()
end

local function awayText(minutes: number, maxedOut: boolean): string
	local hours = minutes // 60
	local text = if hours > 0 then `{hours}h {minutes % 60}m` else `{minutes}m`
	return if maxedOut then `{text}, the most it counts` else text
end

local function show(data: { [string]: any })
	local waited = 0
	while not calm() and waited < 60 do
		task.wait(1)
		waited += 1
	end

	local lines: { string } = {}
	if typeof(data.Coins) == "number" then
		local minutes = if typeof(data.Minutes) == "number" then data.Minutes else 0
		table.insert(
			lines,
			`💤 Your chute earned <b>{Format.Short(data.Coins)} coins</b> while you were away ({awayText(
				minutes,
				data.MaxedOut == true
			)})`
		)
	end
	local news = data.News
	local title = "Welcome back!"
	if typeof(news) == "table" and typeof(news.Lines) == "table" then
		if #lines > 0 then
			table.insert(lines, "")
		end
		table.insert(lines, `<b>{news.Title or "New this week!"}</b>`)
		for _, line in news.Lines do
			if typeof(line) == "string" then
				table.insert(lines, line)
			end
		end
	end
	if #lines == 0 then
		return
	end

	local gui = Ui.make("ScreenGui", {
		Name = "WelcomeBack",
		DisplayOrder = 8,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))
	local height = 64 + #lines * LINE_HEIGHT + 64
	local card = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, height + 40),
		Size = UDim2.fromOffset(WIDTH, height),
		BackgroundColor3 = Ui.PAPER,
	}, gui)
	Ui.round(card, 16)
	Ui.border(card, 3)
	Ui.autoScale(card)
	Ui.outlined(card, {
		Position = UDim2.fromOffset(0, 10),
		Size = UDim2.new(1, 0, 0, 36),
		TextSize = 30,
		Text = title,
	})
	for index, line in lines do
		Ui.label(card, {
			Position = UDim2.fromOffset(20, 52 + (index - 1) * LINE_HEIGHT),
			Size = UDim2.new(1, -40, 0, LINE_HEIGHT),
			TextSize = 17,
			RichText = true,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = line,
		})
	end
	local ok = Ui.button(card, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(160, 44),
		BackgroundColor3 = Ui.GREEN,
		Text = "OK!",
		TextSize = 22,
	})

	local closing = false
	local function dismiss()
		if closing then
			return
		end
		closing = true
		local slide = TweenService:Create(card, TweenInfo.new(0.25), { Position = UDim2.new(0.5, 0, 1, height + 40) })
		slide:Play()
		slide.Completed:Wait()
		gui:Destroy()
	end
	ok.Activated:Connect(dismiss)

	TweenService:Create(card, TweenInfo.new(0.4, Enum.EasingStyle.Back), {
		Position = UDim2.new(0.5, 0, 1, -Ui.margin() - 90),
	}):Play()
	task.delay(20, function()
		if gui.Parent then
			dismiss()
		end
	end)
end

function WelcomeBack.Start()
	local notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent
	notify.OnClientEvent:Connect(function(kind: string, data: any)
		if kind == "WelcomeBack" and typeof(data) == "table" then
			task.spawn(show, data)
		end
	end)
end

return WelcomeBack
