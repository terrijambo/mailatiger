--!strict
-- The themed catching arenas. When you pick an animal you're teleported to the arena for its tier.
-- (Where each arena sits in the world is in src/server/MapBuilder.luau.)
--   Tiers        : which animal tiers get released here
--   MudSpeedMult : walking speed while on mud (Jungle)
--   IceGrip      : how quickly you can change direction on ice (lower = slidier)
--   FallBackStun : seconds you're dazed after falling off the Rooftop

export type ArenaDef = {
	Id: string,
	DisplayName: string,
	Description: string,
	Tiers: { number },
	Color: Color3,
}

local List: { ArenaDef } = {
	{
		Id = "Backyard",
		DisplayName = "Backyard",
		Description = "An open lawn with a few bushes. A gentle start.",
		Tiers = { 1 },
		Color = Color3.fromRGB(120, 200, 90),
	},
	{
		Id = "Barn",
		DisplayName = "Barn",
		Description = "Hay bales everywhere. Animals duck around them.",
		Tiers = { 2 },
		Color = Color3.fromRGB(200, 70, 60),
	},
	{
		Id = "Jungle",
		DisplayName = "Jungle",
		Description = "Trees to dodge around and mud that slows you down.",
		Tiers = { 3 },
		Color = Color3.fromRGB(40, 140, 60),
	},
	{
		Id = "IceRink",
		DisplayName = "Ice Rink",
		Description = "You slide on the ice. The animals don't.",
		Tiers = { 4, 5 },
		Color = Color3.fromRGB(150, 210, 255),
	},
	{
		Id = "Rooftop",
		DisplayName = "Rooftop",
		Description = "No fences, just edges. Don't fall off.",
		Tiers = { 6 },
		Color = Color3.fromRGB(120, 120, 140),
	},
}

local ById: { [string]: ArenaDef } = {}
local ByTier: { [number]: ArenaDef } = {}
for _, arena in List do
	ById[arena.Id] = arena
	for _, tier in arena.Tiers do
		ByTier[tier] = arena
	end
end

return {
	List = List,
	ById = ById,
	ByTier = ByTier,

	MudSpeedMult = 0.5,
	IceGrip = 1.5,
	FallBackStun = 1.5,
}
