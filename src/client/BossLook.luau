--!strict
-- The boss arena's show, on each player's own device (BossArena.luau builds the stage):
--   * the crowd in the stands bounces and waves: calm between fights, hyped during one, wild on a win,
--     slumped on a MEGA VINE BOOM (Workspace attribute "CrowdMood")
--   * floodlights switch on and sweep the floor while a boss is on
--   * fight lighting: while you're on the island during a fight, the sky darkens and a coloured tint and
--     haze close in (Settings -> "Camera shake & zoom" off keeps it subtle)

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer
local Boss = Config.Events.Boss

local BossLook = {}

type Fan = { Model: Model, Home: CFrame, Seed: number }

function BossLook.Start()
	local fans: { Fan } = {}
	local function addFan(model: Instance)
		if model:IsA("Model") and model.PrimaryPart then
			local seed = model:GetAttribute("Seed")
			table.insert(fans, {
				Model = model,
				Home = model:GetPivot(),
				Seed = if typeof(seed) == "number" then seed else math.random(1, 100),
			})
		end
	end
	CollectionService:GetInstanceAddedSignal("BossCrowd"):Connect(addFan)
	for _, model in CollectionService:GetTagged("BossCrowd") do
		addFan(model)
	end

	-- Fight lighting (made once, faded in and out)
	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "BossTint"
	tint.Enabled = false
	tint.Parent = Lighting
	local fighting = false

	local function nearArena(): boolean
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return false
		end
		local offset = root.Position - Boss.ArenaCenter
		return math.abs(offset.X) < 150 and math.abs(offset.Z) < 150
	end

	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local mood = Workspace:GetAttribute("CrowdMood")
		local on = Workspace:GetAttribute("BossPhase") ~= nil
		local close = nearArena()

		-- The crowd (only animated when you're close enough to see it)
		if close then
			local jump = if mood == "Cheer" then 1.6 elseif mood == "Hype" then 0.7 elseif mood == "Boo" then 0 else 0.15
			local speed = if mood == "Cheer" then 9 elseif mood == "Hype" then 6 else 2
			for _, fan in fans do
				if fan.Model.Parent then
					local t = now * speed + fan.Seed * 1.7
					local lift = math.abs(math.sin(t)) * jump
					local sway = if mood == "Boo" then -0.25 else math.sin(t * 0.5) * 0.08 * jump
					fan.Model:PivotTo(fan.Home * CFrame.new(0, lift, 0) * CFrame.Angles(sway, 0, 0))
				end
			end
		end

		-- Floodlights sweep while a boss is on
		for _, lamp in CollectionService:GetTagged("BossFloodlight") do
			local light = lamp:FindFirstChildOfClass("SpotLight")
			if light then
				light.Enabled = on
			end
		end

		-- Fight lighting while you're on the island
		local want = on and close
		if want ~= fighting then
			fighting = want
			local calm = player:GetAttribute("MotionOff") == true
			tint.Enabled = true
			TweenService:Create(tint, TweenInfo.new(1.5), {
				TintColor = if want then Color3.fromRGB(255, 215, 200) else Color3.new(1, 1, 1),
				Contrast = if want then 0.15 else 0,
				Brightness = if want then (if calm then -0.02 else -0.06) else 0,
				Saturation = if want then 0.1 else 0,
			}):Play()
		end
	end)

	-- Sweep the floodlights back and forth (separately, slower)
	task.spawn(function()
		while true do
			local t = os.clock()
			for index, lamp in CollectionService:GetTagged("BossFloodlight") do
				if lamp:IsA("BasePart") and Workspace:GetAttribute("BossPhase") ~= nil then
					local home = lamp:GetAttribute("Home")
					if typeof(home) ~= "CFrame" then
						lamp:SetAttribute("Home", lamp.CFrame)
						home = lamp.CFrame
					end
					lamp.CFrame = (home :: CFrame)
						* CFrame.Angles(math.sin(t * 0.7 + index) * 0.25, math.sin(t * 0.5 + index * 2) * 0.5, 0)
				end
			end
			task.wait(1 / 30)
		end
	end)
end

return BossLook
