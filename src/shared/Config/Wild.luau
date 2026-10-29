--!strict
-- Wild animals: every zone always has animals roaming around in it. Walk up to one and HOLD E to grab it,
-- then box it. Mostly the zone's own animals, plus now and then a rarer "visitor" from the zone above.
--
-- Every animal has a LEVEL inside its realm (worked out below; Config/Realms.luau) and a POWER to compare it with
-- yours across realms. Grab one too far above you and it VINE BOOMs you out of the zone (anything from a realm
-- you haven't bought always does). The name tag over a wild animal turns red when it's too strong for you.
--
-- LURES (temporary boosts): for a few minutes, rarer animals keep turning up right next to you, with better
-- Shiny/Golden odds. The small one is bought with coins in the Supply Shop, the Mega Lure with Robux.

local Animals = require(script.Parent.Animals)
local Arenas = require(script.Parent.Arenas)
local Rarity = require(script.Parent.Rarity)
local Realms = require(script.Parent.Realms)

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

	-- A realm's animals are spread over levels 1 to this, in the order Animals.luau lists them
	LevelSpread = 8,
	LevelOf = {} :: { [string]: number }, -- animal id -> its level inside its realm (shown on its name tag)
	PowerOf = {} :: { [string]: number }, -- animal id -> its realm's Base + its level (compare with Realms.Power)
	RankOf = {} :: { [string]: number }, -- animal id -> 1 for its realm's easiest animal, 2 for the next...
	ZoneOf = {} :: { [string]: string }, -- animal id -> the zone it lives in
	ZoneAnimals = {} :: { [string]: { string } }, -- zone id -> its animals, easiest first
	RarityOf = {} :: { [string]: string }, -- animal id -> rarity id (Config/Rarity.luau)
}

-- Levels: each realm's animals (its tier) are spread over levels 1..LevelSpread in the order they're listed in
-- Animals.luau, the first two both at level 1 (e.g. Backyard: Hamster 1, Bunny 1, Goldfish 3, Hedgehog 4, Parrot 6)
for _, realm in Realms.List do
	local list = {}
	for _, animal in Animals.List do
		if animal.Tier == realm.Index then
			table.insert(list, animal.Id)
		end
	end
	for i, id in list do
		Wild.LevelOf[id] = math.max(1, ((i - 1) * Wild.LevelSpread) // #list)
		Wild.PowerOf[id] = Realms.Base(realm.Index) + Wild.LevelOf[id]
		Wild.RankOf[id] = i
	end
end

-- Zones (the islands the realms' animals roam on until each realm has its own map), easiest first
for index, arena in Arenas.List do
	local list = {}
	for _, animal in Animals.List do
		if table.find(arena.Tiers, animal.Tier) then
			table.insert(list, animal.Id)
		end
	end
	table.sort(list, function(a, b)
		return Wild.PowerOf[a] < Wild.PowerOf[b]
	end)
	for _, id in list do
		Wild.ZoneOf[id] = arena.Id
	end
	Wild.ZoneAnimals[arena.Id] = list
	-- Rarity: Common for the zone's easiest animal up to Legendary for its rarest, starting one step higher
	-- every two zones (so the Rooftop's rarest reach Ethereal)
	local offset = (index - 1) // 2
	local spread = {}
	for _, id in list do
		if id ~= "Gruff" then -- (Gruff is the Secret one)
			table.insert(spread, id)
		end
	end
	for i, id in spread do
		local step = if #spread > 1 then math.round((i - 1) / (#spread - 1) * 4) else 0
		Wild.RarityOf[id] = Rarity.List[math.min(step + offset + 1, #Rarity.List - 1)].Id
	end
end
Wild.RarityOf.Gruff = "Secret"

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
