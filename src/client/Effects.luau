--!strict
-- Screen and character effects: camera shake, skunk spray, yeti freeze, knockbacks, ragdoll launches,
-- and the Chaos Mode shove key. (Sneaking, mud and ice are in Movement.luau.)

local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Ragdoll = require(script.Parent.Ragdoll)

local player = Players.LocalPlayer

local Effects = {}

local function getHumanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- Settings -> "Camera shake & zoom" off: no shakes or zooms
local function calm(): boolean
	return player:GetAttribute("MotionOff") == true
end

local function shakeCamera(strength: number, duration: number)
	local humanoid = getHumanoid()
	if not humanoid or calm() then
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

-- Zooms the camera out (positive) or in (negative) for a moment, then eases back
local BASE_FOV = 70
local function fovPunch(amount: number, seconds: number)
	local camera = Workspace.CurrentCamera
	if not camera or calm() then
		return
	end
	camera.FieldOfView = BASE_FOV + amount
	TweenService:Create(camera, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FieldOfView = BASE_FOV,
	}):Play()
end

-- A burst of confetti at a spot in the world (only you see it)
local CONFETTI = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 215, 80)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(110, 220, 120)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(90, 160, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 120, 255)),
})
local function confetti(at: Vector3, amount: number)
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = at
	attachment.Parent = Workspace.Terrain
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = CONFETTI
	emitter.Size = NumberSequence.new(0.35, 0.15)
	emitter.Lifetime = NumberRange.new(1.2, 2)
	emitter.Speed = NumberRange.new(14, 26)
	emitter.SpreadAngle = Vector2.new(50, 50)
	emitter.Acceleration = Vector3.new(0, -30, 0)
	emitter.Drag = 1.5
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-300, 300)
	emitter.LightEmission = 0.3
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Enabled = false
	emitter.Parent = attachment
	emitter:Emit(amount)
	task.delay(3, function()
		attachment:Destroy()
	end)
end

local function myPosition(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position
end

local function knockback(direction: Vector3, strength: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.AssemblyLinearVelocity = direction.Unit * strength + Vector3.new(0, strength * 0.5, 0)
	end
	shakeCamera(1.2, 0.3)
end

function Effects.Start()
	-- Chaos Mode: F (or the on-screen button) shoves the nearest player doing a Chaos job.
	-- The server picks who, and checks range and cooldown.
	-- The key and button only exist while someone else is on a Chaos job (otherwise there's nobody to shove,
	-- and on phones the button would just be clutter).
	local shove = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Shove") :: RemoteEvent
	local bound = false
	local function refreshShove()
		local anyone = false
		for _, other in Players:GetPlayers() do
			if other ~= player and other:GetAttribute("Chaos") == true then
				anyone = true
			end
		end
		if anyone and not bound then
			bound = true
			ContextActionService:BindAction("Shove", function(_name: string, state: Enum.UserInputState)
				if state == Enum.UserInputState.Begin then
					shove:FireServer()
				end
				return Enum.ContextActionResult.Pass
			end, true, Config.Social.Chaos.ShoveKey, Enum.KeyCode.ButtonB) -- (X is the grab prompt)
			ContextActionService:SetTitle("Shove", "Shove")
		elseif not anyone and bound then
			bound = false
			ContextActionService:UnbindAction("Shove")
		end
	end
	local function watch(other: Player)
		other:GetAttributeChangedSignal("Chaos"):Connect(refreshShove)
	end
	for _, other in Players:GetPlayers() do
		watch(other)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function()
		task.defer(refreshShove)
	end)
	refreshShove()

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
		elseif kind == "Launch" then
			-- VINE BOOM (the sound plays from the server so everyone nearby hears it)
			shakeCamera(2, 0.4)
			fovPunch(22, 0.9)
			Ragdoll.Launch(data.Velocity, data.Seconds)
		elseif kind == "LevelUp" then
			local at = myPosition()
			if at then
				confetti(at + Vector3.new(0, 3, 0), 90)
			end
			fovPunch(10, 0.8)
		elseif kind == "BossLanded" or kind == "BossPinned" then
			-- The boss's parcel slams down / the boss is pinned flat: a dust burst and a big shake
			local attachment = Instance.new("Attachment")
			attachment.WorldPosition = data.At + Vector3.new(0, 1, 0)
			attachment.Parent = Workspace.Terrain
			local dust = Instance.new("ParticleEmitter")
			dust.Color = ColorSequence.new(
				if kind == "BossPinned" then Color3.fromRGB(255, 220, 120) else Color3.fromRGB(230, 215, 190)
			)
			dust.Size = NumberSequence.new(3, 8)
			dust.Transparency = NumberSequence.new(0.2, 1)
			dust.Lifetime = NumberRange.new(1, 1.6)
			dust.Speed = NumberRange.new(30, 45)
			dust.SpreadAngle = Vector2.new(10, 180)
			dust.EmissionDirection = Enum.NormalId.Top
			dust.Acceleration = Vector3.new(0, -10, 0)
			dust.Drag = 3
			dust.Enabled = false
			dust.Parent = attachment
			dust:Emit(if kind == "BossLanded" then 60 else 35)
			task.delay(2.5, function()
				attachment:Destroy()
			end)
			shakeCamera(if kind == "BossLanded" then 2.2 else 1.4, 0.5)
			fovPunch(if kind == "BossLanded" then 14 else 8, 0.7)
		elseif kind == "BossFirework" then
			-- The boxed boss bursts in the sky: a huge confetti firework
			confetti(data.At, 220)
			confetti(data.At + Vector3.new(8, -6, 0), 120)
			confetti(data.At + Vector3.new(-8, -6, 0), 120)
			shakeCamera(0.8, 0.3)
		elseif kind == "BossRoar" then
			-- A shockwave bubble blasting out from the boss
			local bubble = Instance.new("Part")
			bubble.Shape = Enum.PartType.Ball
			bubble.Anchored = true
			bubble.CanCollide = false
			bubble.CanQuery = false
			bubble.Material = Enum.Material.ForceField
			bubble.Color = Color3.fromRGB(255, 120, 90)
			bubble.Size = Vector3.one * 6
			bubble.CFrame = CFrame.new(data.At)
			bubble.Parent = Workspace
			TweenService:Create(bubble, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.one * data.Radius * 2,
				Transparency = 1,
			}):Play()
			task.delay(0.7, function()
				bubble:Destroy()
			end)
			fovPunch(-10, 0.6)
		elseif kind == "HelpPop" then
			-- "+HELP" floats up over a boss fighter who's carrying the team
			local helper = Players:GetPlayerByUserId(data.UserId)
			local head = helper and helper.Character and helper.Character:FindFirstChild("Head") :: BasePart?
			if head then
				local pop = Instance.new("BillboardGui")
				pop.Size = UDim2.fromOffset(110, 34)
				pop.StudsOffset = Vector3.new(0, 3, 0)
				pop.AlwaysOnTop = true
				pop.MaxDistance = 120
				local label = Instance.new("TextLabel")
				label.Size = UDim2.fromScale(1, 1)
				label.BackgroundTransparency = 1
				label.Font = Enum.Font.LuckiestGuy
				label.TextScaled = true
				label.TextColor3 = Color3.fromRGB(120, 255, 140)
				label.TextStrokeTransparency = 0
				label.Text = "+HELP"
				label.Parent = pop
				pop.Adornee = head
				pop.Parent = Workspace
				TweenService:Create(pop, TweenInfo.new(1.2), { StudsOffset = Vector3.new(0, 7, 0) }):Play()
				TweenService:Create(label, TweenInfo.new(1.2), { TextTransparency = 1, TextStrokeTransparency = 1 })
					:Play()
				task.delay(1.3, function()
					pop:Destroy()
				end)
			end
		elseif kind == "BossStomp" then
			-- A red ring on the ground that fills in: jump before it lands!
			local ring = Instance.new("Part")
			ring.Name = "StompWarning"
			ring.Shape = Enum.PartType.Cylinder
			ring.Anchored = true
			ring.CanCollide = false
			ring.CanQuery = false
			ring.Material = Enum.Material.Neon
			ring.Color = Color3.fromRGB(255, 60, 60)
			ring.Transparency = 0.7
			ring.Size = Vector3.new(0.3, 2, 2)
			ring.CFrame = CFrame.new(data.At + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
			ring.Parent = Workspace
			TweenService:Create(ring, TweenInfo.new(data.Delay, Enum.EasingStyle.Linear), {
				Size = Vector3.new(0.3, data.Radius * 2, data.Radius * 2),
				Transparency = 0.35,
			}):Play()
			task.delay(data.Delay + 0.2, function()
				ring:Destroy()
				shakeCamera(1, 0.25)
				-- The hit: a dust wave racing outward and cracks left in the ground for a few seconds
				local attachment = Instance.new("Attachment")
				attachment.WorldPosition = data.At + Vector3.new(0, 0.5, 0)
				attachment.Parent = Workspace.Terrain
				local dust = Instance.new("ParticleEmitter")
				dust.Color = ColorSequence.new(Color3.fromRGB(225, 210, 185))
				dust.Size = NumberSequence.new(2, 5)
				dust.Transparency = NumberSequence.new(0.3, 1)
				dust.Lifetime = NumberRange.new(0.6, 0.9)
				dust.Speed = NumberRange.new(data.Radius * 1.4, data.Radius * 1.7)
				dust.SpreadAngle = Vector2.new(85, 180)
				dust.EmissionDirection = Enum.NormalId.Top
				dust.Acceleration = Vector3.new(0, -25, 0)
				dust.Drag = 2
				dust.Enabled = false
				dust.Parent = attachment
				dust:Emit(70)
				local cracks = {}
				for i = 1, 7 do
					local angle = i / 7 * math.pi * 2 + math.random() * 0.4
					local length = data.Radius * (0.4 + math.random() * 0.4)
					local crack = Instance.new("Part")
					crack.Anchored = true
					crack.CanCollide = false
					crack.CanQuery = false
					crack.Color = Color3.fromRGB(60, 50, 45)
					crack.Size = Vector3.new(0.5, 0.06, length)
					crack.CFrame = CFrame.new(data.At + Vector3.new(0, 0.12, 0))
						* CFrame.Angles(0, angle, 0)
						* CFrame.new(0, 0, -length / 2 - 2)
					crack.Parent = Workspace
					table.insert(cracks, crack)
				end
				task.delay(4, function()
					attachment:Destroy()
					for _, crack in cracks do
						crack:Destroy()
					end
				end)
			end)
		elseif kind == "Slip" then
			-- Slipped on a banana peel: a little flop
			shakeCamera(0.8, 0.2)
			Ragdoll.Launch(Vector3.new(0, 18, 0), data.Seconds)
		elseif kind == "Parcel" then
			-- Taped and stamped! A little celebration, bigger for better ratings
			local at = myPosition()
			if at then
				confetti(at + Vector3.new(0, 2, 0), 10 + (data.Stars or 1) * 8)
			end
			fovPunch(-6, 0.35)
		elseif kind == "MailReceipt" then
			local map = Workspace:FindFirstChild("GrayboxMap")
			local chute = map and map:FindFirstChild("MailChute") :: BasePart?
			local at = if chute then chute.Position + Vector3.new(0, chute.Size.Y / 2 + 1, 0) else myPosition()
			if at then
				confetti(at, 40 + 10 * (data.Count or 1))
			end
			fovPunch(6, 0.5)
			shakeCamera(0.4, 0.2)
		end
	end)
end

return Effects
