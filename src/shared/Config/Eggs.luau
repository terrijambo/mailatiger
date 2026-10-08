--!strict
-- Eggs: every island has an egg stand next to its arrival circle. Buy an egg with coins and it rolls one of
-- that island's animals (rarer ones less often: Config/Rarity.luau weights) and the animal hatches right
-- next to you, wild, to grab and box. A way to hunt for the exact animal an order or quest needs.
-- Animals too strong for you to take on (more than Wild.MaxLevelGap levels above you) are left out of
-- your roll.

local Eggs = {
	-- An egg costs this many minutes of chute income at the level its island opens (Config/Machines.luau)
	PriceMinutes = 3,
	HatchSeconds = 1.4, -- the egg on the stand wobbles and cracks for this long
	-- The slot-machine roller (client/EggRoller.luau): the reel spins for RollSeconds, slowing down, lands on
	-- the animal you got and shows it off for RevealSeconds. The animal hatches next to you as it lands.
	RollSeconds = 3.4,
	RevealSeconds = 1.6,
	ReelCards = 34, -- cards that go past before it lands (more = a longer, faster-looking spin)
}

local function tidy(raw: number): number
	local digits = math.max(0, math.floor(math.log10(math.max(raw, 1))) - 1)
	local unit = 10 ^ digits
	return math.max(10, math.round(raw / unit) * unit)
end

function Eggs.Price(zoneId: string): number
	local Levels = require(script.Parent.Levels) :: any
	local Machines = require(script.Parent.Machines) :: any
	return tidy(Machines.ChuteRate(Levels.ZoneLevels[zoneId] or 1) * Eggs.PriceMinutes)
end

export type Odd = { AnimalId: string, Chance: number, Locked: boolean }

-- The odds for a zone's egg. With `level`, animals too strong for that level are locked (chance 0) and the
-- rest share their chances.
function Eggs.Odds(zoneId: string, level: number?): { Odd }
	local Wild = require(script.Parent.Wild) :: any
	local Rarity = require(script.Parent.Rarity) :: any
	local list = Wild.ZoneAnimals[zoneId] or {}
	local odds: { Odd } = {}
	local total = 0
	for _, animalId in list do
		local locked = level ~= nil and (Wild.LevelOf[animalId] or 1) > level + Wild.MaxLevelGap
		local weight = if locked then 0 else Rarity.ById[Wild.RarityOf[animalId] or "Common"].Weight
		total += weight
		table.insert(odds, { AnimalId = animalId, Chance = weight, Locked = locked })
	end
	for _, odd in odds do
		odd.Chance = if total > 0 then odd.Chance / total else 0
	end
	return odds
end

-- Rolls an animal from a zone's egg (roll: 0..1). nil if every animal is too strong for you.
function Eggs.Roll(zoneId: string, level: number, roll: number): string?
	local acc = 0
	local last: string? = nil
	for _, odd in Eggs.Odds(zoneId, level) do
		if odd.Chance > 0 then
			acc += odd.Chance
			last = odd.AnimalId
			if roll <= acc then
				return odd.AnimalId
			end
		end
	end
	return last
end

return Eggs
