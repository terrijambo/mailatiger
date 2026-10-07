--!strict
-- How you move, every frame, on your own device (your character is simulated by your client):
--   * Base speed comes from the server ("WalkSpeed" attribute, raised by Sneakers). "Frozen" = can't move.
--   * Hold C to sneak (slow, doesn't wake sleeping animals).
--   * Mud (Jungle) slows you down.
--   * Ice (Ice Rink) makes you slide: you keep your momentum and only slowly turn toward where you're
--     steering. (Runs just before physics each frame: it reads your stick/keys from MoveDirection, then walks
--     the Humanoid along the sliding velocity instead. No forces, so nothing fights the Humanoid.)

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer

local Movement = {}

local SNEAK_SPEED = 7

local sneaking = false
local sliding = false
local slideVelocity = Vector3.zero

local function onSneak(_name: string, state: Enum.UserInputState, _input: InputObject)
	sneaking = state == Enum.UserInputState.Begin
	return Enum.ContextActionResult.Pass
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

	local floor = humanoid.FloorMaterial
	if floor == Enum.Material.Ice and not frozen then
		if not sliding then
			sliding = true
			local v = root.AssemblyLinearVelocity
			slideVelocity = Vector3.new(v.X, 0, v.Z)
		end
	elseif sliding and floor ~= Enum.Material.Air then
		sliding = false -- keep sliding while airborne over the ice, stop once you land on something else
	end

	if sliding and humanoid:GetState() ~= Enum.HumanoidStateType.Physics then
		-- Momentum: ease toward where you're steering instead of turning instantly
		local input = Vector3.new(humanoid.MoveDirection.X, 0, humanoid.MoveDirection.Z)
		local target = input * speed
		local grip = math.min(1, Config.Arenas.IceGrip * dt)
		slideVelocity += (target - slideVelocity) * grip
		local glide = slideVelocity.Magnitude
		if glide > 0.3 then
			humanoid.WalkSpeed = glide
			humanoid:Move(slideVelocity / glide, false)
		else
			slideVelocity = Vector3.zero
			humanoid.WalkSpeed = speed
		end
	else
		humanoid.WalkSpeed = speed
	end
end

function Movement.Start()
	ContextActionService:BindAction("Sneak", onSneak, true, Enum.KeyCode.C, Enum.KeyCode.ButtonL2)
	ContextActionService:SetTitle("Sneak", "Sneak")
	-- (before physics, after the controls have set MoveDirection for this frame)
	RunService.PreSimulation:Connect(update)
	player.CharacterAdded:Connect(function()
		sliding = false
		slideVelocity = Vector3.zero
	end)
end

return Movement
