--!strict
-- Finding the pieces of the realms' hubs (server/MapBuilder.luau, docs/REALMS_PLAN.md section 7). Every realm
-- has its own Gruff, counter, chute, orders board and machines, tagged with CollectionService and a Realm
-- attribute:
--   HubGruff, HubGruffModel, HubGruffHat, HubCounter, HubChute, HubOrdersBoard, HubMachines
-- Pieces can turn up late (and, with streaming, come and go), so scripts either ask for them when they need
-- them (Nearest, OfRealm) or watch for them (Each).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Hubs = {}

local function positionOf(instance: Instance): Vector3?
	if instance:IsA("BasePart") then
		return instance.Position
	elseif instance:IsA("Model") then
		return instance:GetPivot().Position
	end
	return nil
end

-- Calls `added` for every piece with this tag, now and whenever one turns up
function Hubs.Each(tag: string, added: (Instance) -> ())
	CollectionService:GetInstanceAddedSignal(tag):Connect(added)
	for _, instance in CollectionService:GetTagged(tag) do
		task.spawn(added, instance)
	end
end

-- The piece with this tag nearest a spot (flat distance), or nil if there are none
function Hubs.Nearest(tag: string, position: Vector3): Instance?
	local best, bestDistance = nil, math.huge
	for _, instance in CollectionService:GetTagged(tag) do
		local at = positionOf(instance)
		if at then
			local distance = Vector3.new(at.X - position.X, 0, at.Z - position.Z).Magnitude
			if distance < bestDistance then
				best, bestDistance = instance, distance
			end
		end
	end
	return best
end

-- The piece with this tag nearest the local player (or any one, before they've spawned)
function Hubs.NearMe(tag: string): Instance?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		return Hubs.Nearest(tag, root.Position)
	end
	return CollectionService:GetTagged(tag)[1]
end

-- The piece with this tag in a realm's hub, or nil
function Hubs.OfRealm(tag: string, realm: number): Instance?
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:GetAttribute("Realm") == realm then
			return instance
		end
	end
	return nil
end

return Hubs
