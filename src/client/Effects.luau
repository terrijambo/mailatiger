--!strict
-- Screen and character effects: camera shake, skunk spray, yeti freeze, charge knockback, and sneaking.

local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local Effects = {}

local SNEAK_SPEED = 7
local NORMAL_SPEED = 16

local function getHumanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function shakeCamera(strength: number, duration: number)
	local humanoid = getHumanoid()
	if not humanoid then
		return
	end
	task.spawn(function()
		local start = os.clock()
		while os.clock() - start < duration do
			humanoid.CameraOffset = Vector3.new((math.random() - 0.5) * strength, (math.random() - 0.5) * strength, 0)
			task.wait()
		end
		humanoid.CameraOffset = Vector3.zero
	end)
end

-- A colored tint (+ optional blur) that fades out
local function tint(color: Color3, blurSize: number, seconds: number)
	local correction = Instance.new("ColorCorrectionEffect")
	correction.TintColor = color
	correction.Saturation = -0.3
	correction.Parent = Lighting
	local blur = Instance.new("BlurEffect")
	blur.Size = blurSize
	blur.Parent = Lighting

	local fade = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(correction, fade, { TintColor = Color3.new(1, 1, 1), Saturation = 0 }):Play()
	TweenService:Create(blur, fade, { Size = 0 }):Play()
	task.delay(seconds, function()
		correction:Destroy()
		blur:Destroy()
	end)
end

local function knockback(direction: Vector3, strength: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.AssemblyLinearVelocity = direction.Unit * strength + Vector3.new(0, strength * 0.5, 0)
	end
	shakeCamera(1.2, 0.3)
end

-- Hold C to sneak (moving slowly doesn't wake sleeping animals)
local function onSneak(_name: string, state: Enum.UserInputState, _input: InputObject)
	local humanoid = getHumanoid()
	if humanoid then
		if state == Enum.UserInputState.Begin and humanoid.WalkSpeed > 0 then
			humanoid.WalkSpeed = SNEAK_SPEED
		elseif state ~= Enum.UserInputState.Begin and humanoid.WalkSpeed == SNEAK_SPEED then
			humanoid.WalkSpeed = NORMAL_SPEED
		end
	end
	return Enum.ContextActionResult.Pass
end

function Effects.Start()
	ContextActionService:BindAction("Sneak", onSneak, true, Enum.KeyCode.C, Enum.KeyCode.ButtonL2)
	ContextActionService:SetTitle("Sneak", "Sneak")

	local notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent
	notify.OnClientEvent:Connect(function(kind: string, data: { [string]: any })
		if kind == "Spray" then
			tint(Color3.fromRGB(170, 255, 120), 14, data.Seconds)
		elseif kind == "Freeze" then
			tint(Color3.fromRGB(170, 220, 255), 6, 1.5)
			shakeCamera(0.5, 0.3)
		elseif kind == "Roar" then
			shakeCamera(1.5, 0.6)
		elseif kind == "Knockback" then
			knockback(data.Direction, data.Strength)
		elseif kind == "Break" then
			shakeCamera(1.2, 0.35)
		elseif kind == "Thump" then
			shakeCamera(0.5, 0.15)
		elseif kind == "Breakout" then
			shakeCamera(2.5, 0.9)
		end
	end)
end

return Effects
