--!strict
-- Wild animals: every zone always has animals roaming around in it. Walk up to one and HOLD E to grab it,
-- then box it. Mostly the zone's own animals, plus now and then a rarer "visitor" from the zone above.
--
-- Every animal has a LEVEL (worked out below from the zone it lives in). Grab one above your level and it
-- VINE BOOMs you out of the zone. The name tag over a wild animal turns red when it's too strong for you.
--
-- LURES (temporary boosts): for a few minutes, rarer animals keep turning up right next to you, with better
-- Shiny/Golden odds. The small one is bought with coins in the Supply Shop, the Mega Lure with Robux.

local Animals = require(script.Parent.Animals)
local Arenas = require(script.Parent.Arenas)
local Levels = require(script.Parent.Levels)

export type Lure = {
	Id: string,
	DisplayName: string,
	Seconds: number,
	Every: number, -- a lured animal turns up near you this often (seconds)...
	MaxNearby: number, -- ...while fewer than this many of your lured animals are still around
	Rarity: number, -- 0..1: how much it favors the rarest animals in the zone
	VisitorChance: number, -- chance it's a visitor from a zone above instead
	VisitorReach: number, -- how many zones above it can come from
	VariantLuck: number, -- Shiny/Golden odds x this
}

local Wild = {
	PerZone = 4, -- animals roaming each zone at once (a grabbed one is replaced after RespawnSeconds)
	RespawnSeconds = 3,
	VisitorChance = 0.12, -- a normal spawn is a visitor from the next zone up this often
	RarityFalloff = 0.7, -- higher-level animals in a zone are rarer: weight = 1 / (1 + rank x this)
	WanderSpeed = { Min = 2.5, Max = 5 }, -- studs/second
	PauseSeconds = { Min = 1, Max = 4 }, -- standing still between strolls
	GrabHold = 0.5, -- seconds to HOLD E
	-- You can take on animals up to this many levels above you (the BOX gets harder the further above; at the
	-- full gap it's the hardest it gets, see Boxing.Box.Hard). Any higher: VINE BOOM.
	MaxLevelGap = 10,
	GrabDistance = 10,
	LuredLifetime = 60, -- a lured animal nobody grabs wanders off after this long

	-- Too strong for you: you're launched out of the zone with a VINE BOOM, and land back in town
	Boom = { Up = 110, Out = 45, Seconds = 2.2 },

	Lures = {
		Lure = {
			Id = "Lure",
			DisplayName = "Animal Lure",
			Seconds = 180,
			Every = 8,
			MaxNearby = 3,
			Rarity = 0.6,
			VisitorChance = 0.3,
			VisitorReach = 1,
			VariantLuck = 3,
		},
		MegaLure = {
			Id = "MegaLure",
			DisplayName = "MEGA Lure",
			Seconds = 600,
			Every = 5,
			MaxNearby = 5,
			Rarity = 0.9,
			VisitorChance = 0.45,
			VisitorReach = 2,
			VariantLuck = 8,
		},
	} :: { [string]: Lure },
	-- The coin lure costs this many jobs' worth of your best animal (so it stays fair at every level)
	LureCoinJobs = 12,

	LevelOf = {} :: { [string]: number }, -- animal id -> level
	ZoneOf = {} :: { [string]: string }, -- animal id -> the zone it lives in
	ZoneAnimals = {} :: { [string]: { string } }, -- zone id -> its animals, easiest first
}

-- Levels: each zone's animals are spread from the level the zone opens at up to just below the next zone's,
-- in the order they're listed in Animals.luau (e.g. Backyard: Hamster 1, Bunny 1, Goldfish 2, Hedgehog 2,
-- Parrot 3). The last zone spreads over 10 levels.
for index, arena in Arenas.List do
	local from = Levels.ZoneLevels[arena.Id] or 1
	local nextArena = Arenas.List[index + 1]
	local to = if nextArena then (Levels.ZoneLevels[nextArena.Id] or from + 4) else from + 10
	local list = {}
	for _, animal in Animals.List do
		if table.find(arena.Tiers, animal.Tier) then
			table.insert(list, animal.Id)
		end
	end
	for i, id in list do
		Wild.LevelOf[id] = from + math.floor((i - 1) * (to - from) / #list)
		Wild.ZoneOf[id] = arena.Id
	end
	Wild.ZoneAnimals[arena.Id] = list
end

-- The zone after this one (nil for the last)
function Wild.NextZone(arenaId: string, steps: number?): string?
	for index, arena in Arenas.List do
		if arena.Id == arenaId then
			local target = Arenas.List[index + (steps or 1)]
			return if target then target.Id else nil
		end
	end
	return nil
end

-- Picks an animal from a zone's list. rarity 0 = the usual mix (easy ones common), 1 = rare ones favored.
function Wild.Pick(arenaId: string, roll: number, rarity: number?): string?
	local list = Wild.ZoneAnimals[arenaId]
	if not list or #list == 0 then
		return nil
	end
	local favor = rarity or 0
	local weights = {}
	local total = 0
	for rank, _ in list do
		local common = 1 / (1 + (rank - 1) * Wild.RarityFalloff)
		local rare = rank / #list
		local weight = common * (1 - favor) + rare * favor
		weights[rank] = weight
		total += weight
	end
	local pick = roll * total
	for rank, id in list do
		pick -= weights[rank]
		if pick <= 0 then
			return id
		end
	end
	return list[#list]
end

return Wild
