--!strict
-- REALMS (docs/REALMS_PLAN.md): six worlds, one per animal tier. You start in the Backyard; when you've grown
-- enough there (a chute level and some rebirths in that realm), you BUY the next realm with coins and move in.
-- Moving resets your coins, machines, chute level and rebirths (rebirths start cheap again), but keeps Rebirth
-- Points, upgrades, tools and your collection, and every realm you reach doubles the Rebirth Points you earn.
--
-- Levels are counted inside your realm (you're Level 1 again when you move in), and so are animal levels
-- (Config/Wild.luau). To compare them across realms every animal and player has a POWER: the realm's Base plus
-- the level. An animal from an older realm is always weaker than you; one from a realm you haven't bought is
-- always far too strong.
--
-- Until each realm has its own map, its animals live on today's islands (Arena): the Backyard island, the
-- Barn, the Jungle, the Ice Rink (realms 4 and 5) and the Rooftop. The town plaza is everyone's hub.
--
-- Fields:
--   Index      : 1-6, also the animal tier that lives there
--   Arena      : the island its animals roam on for now (Config/Arenas.luau)
--   NeedLevel  : chute level needed in THIS realm to buy the next one...
--   NeedRebirths : ...and rebirths done in this realm
--   PriceMinutes : the next realm's price, in minutes of this realm's chute income at NeedLevel

export type Realm = {
	Index: number,
	Id: string,
	DisplayName: string,
	Blurb: string,
	Emoji: string,
	Color: Color3,
	Arena: string,
	NeedLevel: number,
	NeedRebirths: number,
	PriceMinutes: number,
}

local List: { Realm } = {
	{
		Index = 1,
		Id = "Backyard",
		DisplayName = "Backyard",
		Blurb = "Garden houses, a lily pond and a treehouse. Where every postie starts.",
		Emoji = "🏡",
		Color = Color3.fromRGB(120, 200, 90),
		Arena = "Backyard",
		NeedLevel = 6,
		NeedRebirths = 1,
		PriceMinutes = 20,
	},
	{
		Index = 2,
		Id = "SunnyFarm",
		DisplayName = "Sunny Farm",
		Blurb = "Chicken coops, pumpkin patches and a windmill orchard.",
		Emoji = "🌻",
		Color = Color3.fromRGB(240, 190, 70),
		Arena = "Barn",
		NeedLevel = 10,
		NeedRebirths = 2,
		PriceMinutes = 20,
	},
	{
		Index = 3,
		Id = "WildCove",
		DisplayName = "Wild Cove",
		Blurb = "Jungle cliffs, a campsite in the woods and a cove full of tide pools.",
		Emoji = "🏝️",
		Color = Color3.fromRGB(60, 170, 150),
		Arena = "Jungle",
		NeedLevel = 10,
		NeedRebirths = 2,
		PriceMinutes = 20,
	},
	{
		Index = 4,
		Id = "TempleJungle",
		DisplayName = "Temple Jungle",
		Blurb = "A jungle river, rope bridges and the ruins of the tiger temple.",
		Emoji = "🐯",
		Color = Color3.fromRGB(40, 140, 60),
		Arena = "IceRink",
		NeedLevel = 12,
		NeedRebirths = 2,
		PriceMinutes = 20,
	},
	{
		Index = 5,
		Id = "GiantSavanna",
		DisplayName = "Giant Savanna",
		Blurb = "Open grassland, a watering hole and a bay big enough for a whale.",
		Emoji = "🦒",
		Color = Color3.fromRGB(220, 160, 70),
		Arena = "IceRink",
		NeedLevel = 12,
		NeedRebirths = 2,
		PriceMinutes = 20,
	},
	{
		Index = 6,
		Id = "WonderPeaks",
		DisplayName = "Wonder Peaks",
		Blurb = "Snowy peaks, a little volcano, a crashed UFO and a rainbow meadow.",
		Emoji = "🌈",
		Color = Color3.fromRGB(170, 130, 255),
		Arena = "Rooftop",
		NeedLevel = 0, -- (the last realm: nothing after it)
		NeedRebirths = 0,
		PriceMinutes = 0,
	},
}

local ById: { [string]: Realm } = {}
for _, realm in List do
	ById[realm.Id] = realm
end

local Realms = {
	List = List,
	ById = ById,
	Count = #List,

	PowerStep = 100, -- each realm's Base is this much above the one before (far more than any level gap)
	PointsMult = 2, -- Rebirth Points x this for every realm you've reached past the first
	-- XP for mailing an animal from an older realm than yours: x this for every realm it's behind
	OlderRealmXP = 0.5,
}

-- A realm by index, clamped to 1..Count
function Realms.At(index: number): Realm
	return List[math.clamp(math.floor(index), 1, #List)]
end

-- The power a realm's levels start from
function Realms.Base(index: number): number
	return (math.clamp(math.floor(index), 1, #List) - 1) * Realms.PowerStep
end

-- A player's power: their realm's Base plus their chute level in it
function Realms.Power(realm: number, level: number): number
	return Realms.Base(realm) + level
end

-- Rebirth Points multiplier for a player whose realm is `realm`
function Realms.PointsMultFor(realm: number): number
	return Realms.PointsMult ^ (math.clamp(math.floor(realm), 1, #List) - 1)
end

-- Can a player in `realm` reach this realm (visit it, see its island)?
function Realms.Open(realm: number, index: number): boolean
	return index <= realm
end

-- The next realm's price in coins, for a player in `realm` (nil in the last one). Uses this realm's chute rate.
function Realms.Price(realm: number): number?
	local here = List[realm]
	if not here or realm >= #List then
		return nil
	end
	local Machines = require(script.Parent.Machines) :: any
	local raw = Machines.ChuteRate(here.NeedLevel, realm) * here.PriceMinutes
	local digits = math.max(0, math.floor(math.log10(math.max(raw, 1))) - 1)
	local unit = 10 ^ digits
	return math.max(100, math.round(raw / unit) * unit)
end

-- What's still missing before a player can buy the next realm: a list of short lines (empty = ready, except
-- for the coins, which the caller checks)
function Realms.Missing(realm: number, level: number, rebirths: number): { string }
	local here = List[realm]
	local missing = {}
	if not here or realm >= #List then
		return { "This is the last realm" }
	end
	if level < here.NeedLevel then
		table.insert(missing, `Reach chute Level {here.NeedLevel} (you're Level {level})`)
	end
	if rebirths < here.NeedRebirths then
		table.insert(
			missing,
			`Rebirth {here.NeedRebirths} time{if here.NeedRebirths == 1 then "" else "s"} in this realm ({rebirths} so far)`
		)
	end
	return missing
end

-- The realm an arena (island) belongs to: the lowest realm whose animals roam there
function Realms.OfArena(arenaId: string): number
	local best = #List
	for _, realm in List do
		if realm.Arena == arenaId then
			best = math.min(best, realm.Index)
		end
	end
	return best
end

return Realms
