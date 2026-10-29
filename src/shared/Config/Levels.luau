--!strict
-- Levels and XP. You earn XP by mailing animals (more for harder animals and better ratings), from Gruff's
-- orders and quests, and a big bonus the first time you mail each kind of animal. Your level counts inside your
-- realm (Config/Realms.luau): it lets you take on that realm's animals one by one, and it's what the next realm
-- asks for. Rebirth, and moving to a new realm, start you back at level 1 (Config/Machines.luau).

local Machines = require(script.Parent.Machines)

local Levels = {
	MaxLevel = 50,

	-- XP needed to go from `level` to the next one
	-- (times the XP multiplier from the machines you'd own by then: Config/Machines.luau)
	XPToNext = function(level: number): number
		return math.floor(40 * level ^ 1.5 * Machines.ExpectedMult(level))
	end,

	-- XP for each parcel you mail = MailXPPerTier x the animal's weight x the star multiplier. Its weight grows
	-- with its rank in its realm (the easiest is 1, each one after adds RankXP), so every realm levels you at
	-- the same pace; animals from older realms count less (Realms.OlderRealmXP).
	MailXPPerTier = 15,
	RankXP = 0.5,
	StarXPMult = { 0.5, 0.75, 1, 1.25, 1.6 }, -- for 1..5 stars
	-- First time you ever mail an animal: this x its weight
	NewSpeciesXP = 40,
	-- Completing one of Gruff's side orders: this x the animal's weight
	OrderXP = 25,
	TutorialXP = 50,

	-- Level-up bonus: coins worth this many jobs of your best animal, times the new level
	LevelUpJobs = 2,

	-- (Before realms, 2026-10-29, the islands opened at these levels. Only used to move old saves into realms:
	-- DataService.)
	OldZoneLevels = {
		Backyard = 1,
		Barn = 4,
		Jungle = 8,
		IceRink = 12,
		Rooftop = 18,
	} :: { [string]: number },
}

-- How much an animal counts for XP (mailing, first-time bonus, orders), for a player whose realm is `realm`
function Levels.Weight(animalId: string, realm: number): number
	local Animals = require(script.Parent.Animals) :: any
	local Wild = require(script.Parent.Wild) :: any
	local Realms = require(script.Parent.Realms) :: any
	local animal = Animals.ById[animalId]
	if not animal then
		return 1
	end
	local weight = 1 + ((Wild.RankOf[animalId] or 1) - 1) * Levels.RankXP
	local behind = math.max(0, realm - animal.Tier)
	return weight * Realms.OlderRealmXP ^ behind
end

-- Total XP needed to reach `level` from level 1
function Levels.TotalXPFor(level: number): number
	local total = 0
	for l = 1, level - 1 do
		total += Levels.XPToNext(l)
	end
	return total
end

return Levels
