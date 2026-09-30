--!strict
-- How you move, every frame, on your own device (your character is simulated by your client):
--   * Base speed comes from the server ("WalkSpeed" attribute, raised by Sneakers). "Frozen" = can't move.
--   * Hold C to sneak (slow, doesn't wake sleeping animals).
--   * Mud (Jungle) slows you down.
--   * Ice (Ice Rink) makes you slide: a LinearVelocity carries your momentum and only slowly turns toward
--     where you're steering.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer

local Movement = {}

local SNEAK_SPEED = 7

local sneaking = false
local slide: LinearVelocity? = nil
local slideVelocity = Vector3.zero

local function onSneak(_name: string, state: Enum.UserInputState, _input: InputObject)
	sneaking = state == Enum.UserInputState.Begin
	return Enum.ContextActionResult.Pass
end

local function stopSliding()
	local current = slide
	if current then
		local attachment = current.Attachment0
		if attachment then
			attachment:Destroy()
		end
		current:Destroy()
		slide = nil
	end
end

local function startSliding(root: BasePart)
	local attachment = Instance.new("Attachment")
	attachment.Name = "IceSlide"
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane -- only pushes sideways, gravity still works
	velocity.PrimaryTangentAxis = Vector3.xAxis
	velocity.SecondaryTangentAxis = Vector3.zAxis
	velocity.MaxForce = 4000
	velocity.Parent = root
	slide = velocity
	slideVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
end

local function update(dt: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (humanoid and root) then
		return
	end

	local frozen = player:GetAttribute("Frozen") == true
	local baseSpeed = player:GetAttribute("WalkSpeed")
	local speed = if typeof(baseSpeed) == "number" then baseSpeed else 16
	if sneaking then
		speed = math.min(speed, SNEAK_SPEED)
	end
	if humanoid.FloorMaterial == Enum.Material.Mud then
		speed *= Config.Arenas.MudSpeedMult
	end
	-- Troll items (stink clouds, glue) slow you down for a moment
	local slowdown = player:GetAttribute("SpeedMult")
	if typeof(slowdown) == "number" then
		speed *= slowdown
	end
	if frozen then
		speed = 0
	end

	local onIce = humanoid.FloorMaterial == Enum.Material.Ice and not frozen
	if onIce then
		if not slide then
			startSliding(root)
		end
		-- Momentum: ease toward where you're steering instead of turning instantly
		local target = humanoid.MoveDirection * speed
		local grip = math.min(1, Config.Arenas.IceGrip * dt)
		slideVelocity += (target - slideVelocity) * grip
		local current = slide
		if current then
			current.PlaneVelocity = Vector2.new(slideVelocity.X, slideVelocity.Z)
		end
		humanoid.WalkSpeed = 0 -- the slide does the moving
	else
		if slide and humanoid.FloorMaterial ~= Enum.Material.Air then
			stopSliding() -- keep sliding while airborne over the ice, stop once you land on something else
		end
		if not slide then
			humanoid.WalkSpeed = speed
		end
	end
end

function Movement.Start()
	ContextActionService:BindAction("Sneak", onSneak, true, Enum.KeyCode.C, Enum.KeyCode.ButtonL2)
	ContextActionService:SetTitle("Sneak", "Sneak")
	RunService.Heartbeat:Connect(update)
	player.CharacterAdded:Connect(function()
		slide = nil
		slideVelocity = Vector3.zero
	end)
end

return Movement
