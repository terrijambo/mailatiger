--!strict
-- Feel-good effects on the carrier's own screen: the box jolting when the animal rattles, and camera shake.
-- This client simulates its own box (the server made it the network owner), so impulses applied here move it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local BoxEffects = {}

local RATTLE_IMPULSE = 16 -- studs/sec kick. Keep below Carry.ImpactThreshold so rattles don't double-damage.

local function getBox(): BasePart?
	local folder = Workspace:FindFirstChild("Boxes")
	return folder and folder:FindFirstChild(`Box_{player.UserId}`) :: BasePart?
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

local function rattle()
	local box = getBox()
	if box then
		local mass = box.AssemblyMass
		local direction = (randomUnit() + Vector3.new(0, 0.8, 0)).Unit
		box:ApplyImpulse(direction * mass * RATTLE_IMPULSE)
		box:ApplyAngularImpulse(randomUnit() * mass * 12)
	end
	shakeCamera(0.4, 0.2)
end

function BoxEffects.Start()
	player:GetAttributeChangedSignal("Rattle"):Connect(rattle)

	local lastHp = 0
	player:GetAttributeChangedSignal("HP"):Connect(function()
		local hp = player:GetAttribute("HP") or 0
		if hp < lastHp - 3 then
			shakeCamera(0.6, 0.15)
		end
		lastHp = hp
	end)

	local notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent
	notify.OnClientEvent:Connect(function(kind: string)
		if kind == "Bell" then
			shakeCamera(0.8, 0.4)
		elseif kind == "Break" then
			shakeCamera(1.2, 0.35)
		end
	end)
end

return BoxEffects
