--!strict
-- Effects on the carrier's own screen and box: rattles, animal kicks, skunk spray, camera shake, and ducking.
-- This client simulates its own box (the server made it the network owner), so impulses applied here move it.

local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer

local BoxEffects = {}

local function getBox(): BasePart?
	local folder = Workspace:FindFirstChild("Boxes")
	return folder and folder:FindFirstChild(`Box_{player.UserId}`) :: BasePart?
end

local function getHold(): Attachment?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and root:FindFirstChild("BoxHold") :: Attachment?
end

local function shakeCamera(strength: number, duration: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
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

local function randomUnit(): Vector3
	return Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit
end

local function kickBox(direction: Vector3, strength: number)
	local box = getBox()
	if box then
		local mass = box.AssemblyMass
		box:ApplyImpulse(direction.Unit * mass * strength)
		box:ApplyAngularImpulse(randomUnit() * mass * strength * 0.75)
	end
end

-- Skunk spray: green tint + blur, fading out
local function spray(seconds: number)
	local tint = Instance.new("ColorCorrectionEffect")
	tint.TintColor = Color3.fromRGB(170, 255, 120)
	tint.Saturation = -0.3
	tint.Parent = Lighting
	local blur = Instance.new("BlurEffect")
	blur.Size = 14
	blur.Parent = Lighting

	local fade = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(tint, fade, { TintColor = Color3.new(1, 1, 1), Saturation = 0 }):Play()
	TweenService:Create(blur, fade, { Size = 0 }):Play()
	task.delay(seconds, function()
		tint:Destroy()
		blur:Destroy()
	end)
end

-- Hold C (or the on-screen button on mobile) to lower the box under low signs
local function onDuck(_actionName: string, inputState: Enum.UserInputState, _input: InputObject)
	local hold = getHold()
	local baseOffset = player:GetAttribute("HoldOffset")
	if hold and typeof(baseOffset) == "Vector3" then
		if inputState == Enum.UserInputState.Begin then
			hold.Position = baseOffset - Vector3.new(0, Config.Carry.DuckDrop, 0)
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			hold.Position = baseOffset
		end
	end
	return Enum.ContextActionResult.Sink
end

function BoxEffects.Start()
	local lastHp = 0
	player:GetAttributeChangedSignal("HP"):Connect(function()
		local hp = (player:GetAttribute("HP") :: number?) or 0
		if hp < lastHp - 3 then
			shakeCamera(0.6, 0.15)
		end
		lastHp = hp
	end)

	player:GetAttributeChangedSignal("Carrying"):Connect(function()
		if player:GetAttribute("Carrying") then
			ContextActionService:BindAction("DuckBox", onDuck, true, Enum.KeyCode.C, Enum.KeyCode.ButtonL2)
			ContextActionService:SetTitle("DuckBox", "Duck")
		else
			ContextActionService:UnbindAction("DuckBox")
		end
	end)

	local notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent
	notify.OnClientEvent:Connect(function(kind: string, data: { [string]: any })
		if kind == "Rattle" then
			kickBox(randomUnit() + Vector3.new(0, 0.8, 0), data.Strength)
			shakeCamera(0.4, 0.2)
		elseif kind == "Impulse" then
			kickBox(data.Direction, data.Strength)
		elseif kind == "Spray" then
			spray(data.Seconds)
		elseif kind == "Bell" then
			shakeCamera(0.8, 0.4)
		elseif kind == "Break" then
			shakeCamera(1.2, 0.35)
		elseif kind == "Roar" then
			shakeCamera(1.5, 0.6)
		elseif kind == "Breakout" then
			shakeCamera(2.5, 0.9)
		end
	end)
end

return BoxEffects
