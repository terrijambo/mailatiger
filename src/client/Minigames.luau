--!strict
-- The STUFF and TAPE minigame screens. They draw what the server says and send your presses.
--   STUFF: a marker bounces across a bar. Press when it's inside the green zone.
--   TAPE:  the animal pushes the lid up (red bar). Mash to shove it down and fill the tape bar.
-- Controls: SPACE or E on keyboard, A / R2 on a controller, or the big round button (mobile or mouse).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local StuffMath = require(ReplicatedStorage.Shared.StuffMath)

local player = Players.LocalPlayer

local Minigames = {}

local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)
local PANEL = Color3.fromRGB(30, 30, 36)
local GREEN = Color3.fromRGB(90, 210, 100)
local RED = Color3.fromRGB(230, 70, 60)
local TAPE = Color3.fromRGB(230, 200, 120)
local BAR_BACK = Color3.fromRGB(60, 60, 68)

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

local function flash(frame: GuiObject, color: Color3)
	local original = frame.BackgroundColor3
	frame.BackgroundColor3 = color
	TweenService:Create(frame, TweenInfo.new(0.35), { BackgroundColor3 = original }):Play()
end

local function jolt(frame: GuiObject)
	local home = frame.Position
	task.spawn(function()
		for _ = 1, 6 do
			frame.Position = home + UDim2.fromOffset(math.random(-8, 8), math.random(-5, 5))
			task.wait(0.03)
		end
		frame.Position = home
	end)
end

local function panel(gui: Instance, title: string): (Frame, TextLabel)
	local frame = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.fromOffset(560, 130),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.15,
		Visible = false,
	}, gui)
	round(frame, 14)
	make("TextLabel", {
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 28,
		TextColor3 = WHITE,
		Text = title,
	}, frame)
	local status = make("TextLabel", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -6),
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 18,
		TextColor3 = Color3.fromRGB(210, 210, 220),
		Text = "",
	}, frame)
	return frame, status
end

-- A labelled horizontal meter. Returns the background (for flashing) and the fill.
local function meter(parent: Instance, y: number, label: string, color: Color3): (Frame, Frame)
	local back = make("Frame", {
		Position = UDim2.fromOffset(90, y),
		Size = UDim2.new(1, -110, 0, 24),
		BackgroundColor3 = BAR_BACK,
	}, parent)
	round(back, 8)
	local fill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = color }, back)
	round(fill, 8)
	make("TextLabel", {
		Position = UDim2.fromOffset(16, y),
		Size = UDim2.fromOffset(70, 24),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = color,
		Text = label,
	}, parent)
	return back, fill
end

function Minigames.Start()
	local gui = make("ScreenGui", { Name = "Minigames", ResetOnSpawn = false }, player:WaitForChild("PlayerGui"))
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local input = remotes:WaitForChild("BoxingInput") :: RemoteEvent
	local notify = remotes:WaitForChild("Notify") :: RemoteEvent

	-- STUFF: bouncing marker + green zone
	local stuffPanel, stuffStatus = panel(gui, "STUFF IT!")
	local bar = make("Frame", {
		Position = UDim2.fromOffset(20, 50),
		Size = UDim2.new(1, -40, 0, 36),
		BackgroundColor3 = BAR_BACK,
		ClipsDescendants = true,
	}, stuffPanel)
	round(bar, 8)
	local zone = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromScale(0.3, 1),
		BackgroundColor3 = GREEN,
	}, bar)
	round(zone, 6)
	local marker = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(0, 6, 1, 8),
		BackgroundColor3 = WHITE,
		ZIndex = 2,
	}, bar)

	local stuffParams: StuffMath.Params? = nil
	RunService.RenderStepped:Connect(function()
		local p = stuffParams
		if p and stuffPanel.Visible then
			local t = Workspace:GetServerTimeNow()
			zone.Size = UDim2.fromScale(p.ZoneWidth, 1)
			zone.Position = UDim2.fromScale(StuffMath.Zone(p, t), 0)
			marker.Position = UDim2.fromScale(StuffMath.Marker(p, t), 0.5)
		end
	end)

	-- TAPE: lid (danger) and tape (progress) meters
	local tapePanel, tapeStatus = panel(gui, "TAPE IT!")
	local lidBack, lidFill = meter(tapePanel, 46, "LID", RED)
	local _, tapeFill = meter(tapePanel, 78, "TAPE", TAPE)

	local function refreshTape()
		local lid = (player:GetAttribute("Lid") :: number?) or 0
		local tape = (player:GetAttribute("Tape") :: number?) or 0
		lidFill.Size = UDim2.fromScale(math.clamp(lid / 100, 0, 1), 1)
		tapeFill.Size = UDim2.fromScale(math.clamp(tape / 100, 0, 1), 1)
		tapeStatus.Text = if lid >= 75 then "IT'S BURSTING OUT! MASH!" else "Mash to hold the lid down!"
		tapeStatus.TextColor3 = if lid >= 75 then RED else Color3.fromRGB(210, 210, 220)
	end
	player:GetAttributeChangedSignal("Lid"):Connect(refreshTape)
	player:GetAttributeChangedSignal("Tape"):Connect(refreshTape)

	-- The big round button (mobile / mouse)
	local actionButton = make("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -30, 1, -30),
		Size = UDim2.fromOffset(150, 150),
		BackgroundColor3 = Color3.fromRGB(230, 150, 40),
		Font = FONT,
		TextSize = 34,
		TextColor3 = WHITE,
		Text = "",
		Visible = false,
	}, gui)
	round(actionButton, 75)
	make("UIStroke", { Thickness = 4, Color = Color3.fromRGB(120, 70, 20) }, actionButton)

	local function press()
		local stage = player:GetAttribute("Stage")
		if stage == "Stuff" then
			input:FireServer("Stuff", Workspace:GetServerTimeNow())
		elseif stage == "Tape" then
			input:FireServer("Tape")
			jolt(actionButton)
		end
	end
	actionButton.Activated:Connect(press)

	local function onAction(_name: string, state: Enum.UserInputState, _input: InputObject)
		if state == Enum.UserInputState.Begin then
			press()
		end
		return Enum.ContextActionResult.Sink
	end

	local function onStage()
		local stage = player:GetAttribute("Stage")
		local playing = stage == "Stuff" or stage == "Tape"
		stuffPanel.Visible = stage == "Stuff"
		tapePanel.Visible = stage == "Tape"
		actionButton.Visible = playing
		actionButton.Text = if stage == "Stuff" then "STUFF!" else "TAPE!"
		if playing then
			ContextActionService:BindActionAtPriority(
				"BoxingPress",
				onAction,
				false,
				Enum.ContextActionPriority.High.Value,
				Enum.KeyCode.Space,
				Enum.KeyCode.E,
				Enum.KeyCode.ButtonA,
				Enum.KeyCode.ButtonR2
			)
		else
			ContextActionService:UnbindAction("BoxingPress")
		end
		if stage ~= "Stuff" then
			stuffParams = nil
		end
		if stage == "Tape" then
			refreshTape()
		end
	end
	player:GetAttributeChangedSignal("Stage"):Connect(onStage)
	onStage()

	notify.OnClientEvent:Connect(function(kind: string, data: { [string]: any })
		if kind == "Stuff" then
			stuffParams = data :: any
			local left = data.MissesAllowed - data.Misses
			stuffStatus.Text = `Stuffed {data.Hits}/{data.HitsNeeded}     Misses left: {left}`
		elseif kind == "StuffResult" then
			flash(bar, if data.Hit then GREEN else RED)
			if not data.Hit then
				jolt(stuffPanel)
			end
		elseif kind == "Ouch" then
			flash(tapePanel, RED)
			tapeStatus.Text = "OUCH! That press didn't count!"
		elseif kind == "Thump" then
			flash(lidBack, WHITE)
			jolt(tapePanel)
		end
	end)
end

return Minigames
