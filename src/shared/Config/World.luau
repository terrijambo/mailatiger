--!strict
-- The world: an archipelago. A round town plaza on a cliff island in the middle, and themed islands around
-- it, each joined to town by a wooden bridge over the sea. (Built by server/MapBuilder.luau for the
-- gameplay pieces and server/Scenery for everything that's just for looks.)
--
--        Beach        Barn
--   Backyard   [TOWN]      Jungle
--        Boss        Ice Rink
--             Rooftop
--
-- North is -Z, east is +X. Ground is y = 0 everywhere (the Rooftop arena is up on a building).

export type Island = {
	Id: string, -- a zone id (Config/Arenas.luau), or "Beach" / "Boss"
	Center: Vector3,
	Radius: number, -- roughly (each island's outline is a blob around this)
	Gate: Vector3?, -- zones: which side of the play area faces town (and has the gate)
	Play: Vector2?, -- zones: half the play area's size, across x along (local: across the gate, toward it)
	BridgeFrom: string?, -- "Town" (default) or another island's id
	Ground: Color3,
	Seed: number, -- shapes the outline
}

local function at(angleDegrees: number, distance: number): Vector3
	local a = math.rad(angleDegrees)
	return Vector3.new(math.sin(a) * distance, 0, -math.cos(a) * distance)
end

local islands: { Island } = {
	{
		Id = "Barn",
		Center = at(0, 238),
		Radius = 80,
		Gate = Vector3.zAxis,
		Play = Vector2.new(36, 28),
		Ground = Color3.fromRGB(128, 186, 84),
		Seed = 3,
	},
	{
		Id = "Jungle",
		Center = at(55, 238),
		Radius = 82,
		Gate = -Vector3.xAxis,
		Play = Vector2.new(36, 30),
		Ground = Color3.fromRGB(58, 138, 62),
		Seed = 7,
	},
	{
		Id = "IceRink",
		Center = at(118, 238),
		Radius = 82,
		Gate = -Vector3.xAxis,
		Play = Vector2.new(38, 28),
		Ground = Color3.fromRGB(214, 228, 242),
		Seed = 11,
	},
	{
		Id = "Rooftop",
		Center = at(180, 240),
		Radius = 80,
		Gate = -Vector3.zAxis,
		Play = Vector2.new(26, 26),
		Ground = Color3.fromRGB(98, 102, 116),
		Seed = 5,
	},
	{
		Id = "Boss",
		Center = at(242, 242),
		Radius = 100,
		Gate = Vector3.xAxis, -- (the arena's way in faces town)
		Ground = Color3.fromRGB(70, 58, 56),
		Seed = 13,
	},
	{
		Id = "Backyard",
		Center = at(298, 238),
		Radius = 78,
		Gate = Vector3.xAxis,
		Play = Vector2.new(36, 28),
		Ground = Color3.fromRGB(102, 186, 80),
		Seed = 2,
	},
	{
		Id = "Beach",
		Center = at(330, 312),
		Radius = 66,
		BridgeFrom = "Backyard",
		Ground = Color3.fromRGB(230, 196, 136),
		Seed = 17,
	},
}

local byId: { [string]: Island } = {}
for _, island in islands do
	byId[island.Id] = island
end

local TOWN_RADIUS = 114

-- Where an island's bridge starts (on the town / other island) and ends (on this island), at ground level.
-- Each island's outline never comes in closer than its Radius, so both ends are always on land.
local function bridge(island: Island): (Vector3, Vector3)
	local fromCenter, fromRadius = Vector3.zero, TOWN_RADIUS
	local other = island.BridgeFrom and byId[island.BridgeFrom]
	if other then
		fromCenter, fromRadius = other.Center, other.Radius
	end
	local direction = (island.Center - fromCenter).Unit
	return fromCenter + direction * (fromRadius - 6), island.Center - direction * (island.Radius - 6)
end

-- Which area a point is in: "Town", an island's Id, or "Sea" (the water and the bridges). Used for each
-- zone's color grade (client/ZoneLook) and by tools/layout to sort glitches and the budget by zone.
local function zoneAt(position: Vector3): string
	local flat = Vector3.new(position.X, 0, position.Z)
	if flat.Magnitude <= TOWN_RADIUS + 10 then
		return "Town"
	end
	local best, bestDistance = "Sea", math.huge
	for _, island in islands do
		local distance = (flat - island.Center).Magnitude
		if distance <= island.Radius * 1.35 and distance < bestDistance then
			best, bestDistance = island.Id, distance
		end
	end
	return best
end

return {
	-- Your character is drawn at this size (0.6 = 60%), so the world, the animals and Gruff feel big
	PlayerScale = 0.6,
	Islands = islands,
	ById = byId,
	Town = {
		Center = Vector3.zero,
		Radius = TOWN_RADIUS, -- the island
		PlazaRadius = 62, -- the round paved plaza
		Ground = Color3.fromRGB(98, 182, 76),
	},
	WaterY = -9, -- the sea's surface
	CliffBottom = -30, -- how far down the cliffs go
	BridgeWidth = 12,
	At = at,
	Bridge = bridge,
	ZoneAt = zoneAt,
}
