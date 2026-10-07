--!strict
-- The DIVE (Fall Guys style). Q on a keyboard, L1 on a controller, the DIVE button on a phone.
-- You launch flat out, arms first, in the direction you're moving (or facing), belly-slide on landing, and
-- hop back up. Your own client moves your character, so the whole move happens here; the server is told,
-- and while the dive lasts animal attacks can't hit you and diving into an animal grabs it
-- (server/DiveService.luau). Numbers in Config/Dive.luau.
--
-- How the pose works: the humanoid goes into "Physics" (no walking or balancing), an AlignOrientation lays
-- the body flat facing the dive, and the shoulders swing the arms out in front, like Superman.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Sfx = require(ReplicatedStorage.Shared.Sfx)

local Tuning = Config.Dive
local player = Players.LocalPlayer

local Dive = {}

local diving = false
local lastDive = 0

local SHOULDERS = { "RightShoulder", "LeftShoulder", "Right Shoulder", "Left Shoulder" }

local function onGround(root: BasePart, character: Model): boolean
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { character }
	params.FilterType = Enum.RaycastFilterType.Exclude
	return Workspace:Raycast(root.Position, Vector3.new(0, -3.2, 0), params) ~= nil
end

-- A puff of dust where you land
local function dust(at: Vector3)
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = at
	attachment.Parent = Workspace.Terrain
	local puff = Instance.new("ParticleEmitter")
	puff.Color = ColorSequence.new(Color3.fromRGB(235, 225, 205))
	puff.Size = NumberSequence.new(1.2, 2.6)
	puff.Transparency = NumberSequence.new(0.3, 1)
	puff.Lifetime = NumberRange.new(0.4, 0.7)
	puff.Speed = NumberRange.new(6, 10)
	puff.SpreadAngle = Vector2.new(80, 80)
	puff.Enabled = false
	puff.Parent = attachment
	puff:Emit(14)
	task.delay(1, function()
		attachment:Destroy()
	end)
end

function Dive.Try()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local now = os.clock()
	if
		not (character and humanoid and root)
		or diving
		or now - lastDive < Tuning.Cooldown
		or humanoid.Health <= 0
		or humanoid.Sit
		or humanoid:GetState() == Enum.HumanoidStateType.Physics -- (already a ragdoll)
		or player:GetAttribute("Frozen") == true
		or player:GetAttribute("Stage") == "Box"
	then
		return
	end
	diving = true
	lastDive = now

	-- Which way: where you're steering, or where you're facing
	local move = Vector3.new(humanoid.MoveDirection.X, 0, humanoid.MoveDirection.Z)
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	local direction = if move.Magnitude > 0.1
		then move.Unit
		elseif look.Magnitude > 0.1 then look.Unit
		else Vector3.zAxis

	ReplicatedStorage.Remotes.Dive:FireServer()
	Sfx.Play("MailWhoosh", root)

	humanoid.AutoRotate = false
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	-- Lay flat, face down, heading into the dive
	local attachment = Instance.new("Attachment")
	attachment.Name = "DiveAttachment"
	attachment.Parent = root
	local align = Instance.new("AlignOrientation")
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.MaxTorque = math.huge
	align.Responsiveness = 45
	align.CFrame = CFrame.lookAt(Vector3.zero, direction) * CFrame.Angles(math.rad(-80), 0, 0)
	align.Parent = root

	-- Arms out in front (swung up over the head, which is "forward" once you're lying flat)
	local saved: { [Motor6D]: CFrame } = {}
	for _, name in SHOULDERS do
		local joint = character:FindFirstChild(name, true)
		if joint and joint:IsA("Motor6D") then
			saved[joint] = joint.C0
			joint.C0 = joint.C0 * CFrame.Angles(math.rad(165), 0, 0)
		end
	end

	-- WHOOSH
	root.AssemblyLinearVelocity = direction * Tuning.Speed + Vector3.new(0, Tuning.Up, 0)

	local started = os.clock()
	local landedAt: number? = nil
	local connection: RBXScriptConnection? = nil
	local function finish()
		if connection then
			connection:Disconnect()
		end
		align:Destroy()
		attachment:Destroy()
		for joint, c0 in saved do
			if joint.Parent then
				joint.C0 = c0
			end
		end
		if humanoid.Health > 0 and humanoid:GetState() == Enum.HumanoidStateType.Physics then
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
		humanoid.AutoRotate = true
		diving = false
	end
	connection = RunService.Heartbeat:Connect(function()
		if not root.Parent or humanoid.Health <= 0 then
			finish()
			return
		end
		local t = os.clock() - started
		-- Landed: a short belly-slide, then up you get
		if not landedAt and t > 0.2 and onGround(root, character :: Model) then
			landedAt = os.clock()
			dust(root.Position - Vector3.new(0, 2, 0))
		end
		if (landedAt and os.clock() - landedAt > Tuning.SlideSeconds) or t > Tuning.MaxAirSeconds then
			finish()
		end
	end)
end

function Dive.Start()
	ContextActionService:BindAction("Dive", function(_, state)
		if state == Enum.UserInputState.Begin then
			Dive.Try()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonL1)
	ContextActionService:SetTitle("Dive", "DIVE")
	ContextActionService:SetPosition("Dive", UDim2.new(1, -170, 1, -90)) -- (left of the jump button)

	-- "DODGE!" over your head when a dive made an attack miss
	local notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent
	notify.OnClientEvent:Connect(function(kind: string)
		if kind ~= "Dodged" then
			return
		end
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		if not head then
			return
		end
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(160, 50)
		gui.StudsOffset = Vector3.new(0, 3, 0)
		gui.AlwaysOnTop = true
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.LuckiestGuy
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(120, 255, 140)
		label.TextStrokeTransparency = 0
		label.Text = "DODGE!"
		label.Parent = gui
		gui.Parent = head
		TweenService:Create(gui, TweenInfo.new(0.8), { StudsOffset = Vector3.new(0, 6, 0) }):Play()
		TweenService:Create(label, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.delay(0.9, function()
			gui:Destroy()
		end)
	end)
end

return Dive
