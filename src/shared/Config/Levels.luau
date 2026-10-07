--!strict
-- Levels and XP. You earn XP by mailing animals (more for harder animals and better ratings), from Gruff's
-- orders and quests, and a big bonus the first time you mail each kind of animal. Levels open new zones.
-- Rebirth starts you back at level 1 (Config/Machines.luau).

local Machines = require(script.Parent.Machines)

local Levels = {
	MaxLevel = 50,

	-- XP needed to go from `level` to the next one
	-- (times the XP multiplier from the machines you'd own by then: Config/Machines.luau)
	XPToNext = function(level: number): number
		return math.floor(40 * level ^ 1.5 * Machines.ExpectedMult(level))
	end,

	-- XP for each parcel you mail = MailXPPerTier x the animal's tier x the star multiplier
	MailXPPerTier = 15,
	StarXPMult = { 0.5, 0.75, 1, 1.25, 1.6 }, -- for 1..5 stars
	-- First time you ever mail an animal: this x its tier
	NewSpeciesXP = 40,
	-- Completing one of Gruff's side orders: this x the animal's tier
	OrderXP = 25,
	TutorialXP = 50,

	-- Level-up bonus: coins worth this many jobs of your best animal, times the new level
	LevelUpJobs = 2,

	-- The level each zone opens at (by arena id; see Config/Arenas.luau)
	ZoneLevels = {
		Backyard = 1,
		Barn = 4,
		Jungle = 8,
		IceRink = 12,
		Rooftop = 18,
	} :: { [string]: number },
}

-- Total XP needed to reach `level` from level 1
function Levels.TotalXPFor(level: number): number
	local total = 0
	for l = 1, level - 1 do
		total += Levels.XPToNext(l)
	end
	return total
end

return Levels
