--!strict
-- Launch your character into the air as a floppy ragdoll, then stand back up.
-- How it works: every joint (Motor6D) is swapped for a loose ball-socket joint, the humanoid is switched to
-- "Physics" (no walking or balancing), and we give the body a big shove. Your client simulates your own
-- character, so this runs here. When time's up, the joints go back to normal and you get up.

local Players = game:GetService("Players")

local player = Players.LocalPlayer

local Ragdoll = {}

local active = false

function Ragdoll.Launch(velocity: Vector3, seconds: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (character and humanoid and root) or active or humanoid.Health <= 0 then
		return
	end
	active = true

	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	humanoid.AutoRotate = false

	-- Swap stiff joints for floppy ones (keep the root joint so the body stays attached to the root part)
	local swapped: { { Motor: Motor6D, Parts: { Instance } } } = {}
	for _, joint in character:GetDescendants() do
		if
			joint:IsA("Motor6D")
			and joint.Part0
			and joint.Part1
			and joint.Name ~= "RootJoint"
			and joint.Name ~= "Root"
		then
			local part0 = joint.Part0 :: BasePart
			local part1 = joint.Part1 :: BasePart
			local a0 = Instance.new("Attachment")
			a0.CFrame = joint.C0
			a0.Parent = part0
			local a1 = Instance.new("Attachment")
			a1.CFrame = joint.C1
			a1.Parent = part1
			local socket = Instance.new("BallSocketConstraint")
			socket.Attachment0 = a0
			socket.Attachment1 = a1
			socket.LimitsEnabled = true
			socket.UpperAngle = 70
			socket.TwistLimitsEnabled = true
			socket.TwistLowerAngle = -45
			socket.TwistUpperAngle = 45
			socket.Parent = part0
			joint.Enabled = false
			table.insert(swapped, { Motor = joint, Parts = { a0, a1, socket } })
		end
	end

	-- Let arms and legs bump into things while flopping
	local collisions: { [BasePart]: boolean } = {}
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") and part ~= root and not part:FindFirstAncestorOfClass("Accessory") then
			collisions[part] = part.CanCollide
			part.CanCollide = true
		end
	end

	-- WHEEE
	root.AssemblyLinearVelocity = velocity
	root.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))

	task.delay(seconds, function()
		for _, entry in swapped do
			entry.Motor.Enabled = true
			for _, extra in entry.Parts do
				extra:Destroy()
			end
		end
		for part, canCollide in collisions do
			if part.Parent then
				part.CanCollide = canCollide
			end
		end
		if humanoid.Health > 0 then
			humanoid.AutoRotate = true
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
		active = false
	end)
end

return Ragdoll
