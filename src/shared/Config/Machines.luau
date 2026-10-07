--!strict
-- The Post Office machines and the chute's income (the main loop):
--   1. Every parcel you mail rides the conveyor past the machines you own. Each one multiplies the XP that
--      parcel gives (they stack: Stamp Machine x1.5 and Postage Scale x1.5 = x2.25).
--   2. XP levels up your CHUTE. Your chute level is your level: it opens zones, and it sets how many coins
--      the chute pays you every minute (ChuteRate below). Mailing a parcel also pays a small tip at once.
--   3. Machines unlock at a chute level, then you buy them with coins.
--   4. REBIRTH (needs Rebirth.MinLevel and coins) resets your coins, machines and chute level, but every
--      rebirth multiplies your coins per minute and pays Rebirth Points, which buy tool upgrades (Sneakers,
--      Grabbing Gloves...) that you keep forever.
--
-- Machine fields:
--   Level   : the chute level it unlocks at
--   XPMult  : multiplies the XP of every parcel you mail
--   PriceMinutes : its price, in minutes of chute income at that level (so prices keep up with the game)
--   Emoji, Color : how it shows in the shop and in the Post Office

export type Machine = {
	Id: string,
	DisplayName: string,
	Description: string,
	Emoji: string,
	Color: Color3,
	Level: number,
	XPMult: number,
	PriceMinutes: number,
}

local List: { Machine } = {
	{
		Id = "Stamp",
		DisplayName = "Stamp Machine",
		Description = "KA-CHUNK. Stamps every parcel so it counts for more.",
		Emoji = "📮",
		Color = Color3.fromRGB(220, 70, 70),
		Level = 2,
		XPMult = 1.5,
		PriceMinutes = 6,
	},
	{
		Id = "Scale",
		DisplayName = "Postage Scale",
		Description = "Weighs every parcel. Heavier mail, more XP.",
		Emoji = "⚖️",
		Color = Color3.fromRGB(70, 140, 220),
		Level = 5,
		XPMult = 1.5,
		PriceMinutes = 8,
	},
	{
		Id = "Fragile",
		DisplayName = "Fragile Handler",
		Description = "Bubble-wraps every parcel. Nothing arrives broken.",
		Emoji = "🫧",
		Color = Color3.fromRGB(240, 170, 60),
		Level = 9,
		XPMult = 2,
		PriceMinutes = 10,
	},
	{
		Id = "Sorter",
		DisplayName = "Sorting Belt",
		Description = "Sorts the mail by zip code at top speed.",
		Emoji = "📦",
		Color = Color3.fromRGB(120, 190, 80),
		Level = 13,
		XPMult = 2,
		PriceMinutes = 12,
	},
	{
		Id = "Express",
		DisplayName = "Express Sorter",
		Description = "Next-day delivery for everything. EXPRESS!",
		Emoji = "⚡",
		Color = Color3.fromRGB(250, 210, 60),
		Level = 19,
		XPMult = 2.5,
		PriceMinutes = 14,
	},
	{
		Id = "Drone",
		DisplayName = "Airmail Drone Dock",
		Description = "A fleet of little drones flies every parcel out.",
		Emoji = "🛸",
		Color = Color3.fromRGB(150, 100, 220),
		Level = 26,
		XPMult = 3,
		PriceMinutes = 16,
	},
	{
		Id = "Rocket",
		DisplayName = "Rocket Launcher",
		Description = "Parcels go to SPACE (and back). Also: press M to mail from anywhere.",
		Emoji = "🚀",
		Color = Color3.fromRGB(240, 90, 60),
		Level = 35,
		XPMult = 4,
		PriceMinutes = 30,
	},
}

local ById: { [string]: Machine } = {}
for _, machine in List do
	ById[machine.Id] = machine
end

local Machines = {
	List = List,
	ById = ById,

	-- The chute pays this many coins per minute: ChuteMinutes x the base pay of the best animal your level
	-- lets you take on, + ChuteLevelBonus per chute level (so it keeps climbing between new animals)
	ChuteMinutes = 1.5,
	ChuteLevelBonus = 0.04,
	PayEverySeconds = 10, -- (paid in small chunks, so the coins keep ticking up)
	-- Mailing a parcel pays this share of what it's worth right away (the tip); the chute is the main income
	MailTip = 0.3,

	Rebirth = {
		MinLevel = 20, -- chute level needed to rebirth
		CostMinutes = 120, -- costs this many minutes of chute income at MinLevel...
		CostGrowth = 2.5, -- ...times this for every rebirth you've already done
		ChuteMult = 1.5, -- every rebirth multiplies coins per minute by this (they stack)
		PointsBase = 5, -- Rebirth Points for your first rebirth...
		PointsStep = 2, -- ...and this many more for each one after
	},
}

-- The base pay of the best animal a chute level lets you take on (Config/Wild.luau gives every animal a level)
function Machines.BestValueAt(level: number): number
	local Animals = require(script.Parent.Animals) :: any
	local Wild = require(script.Parent.Wild) :: any
	local best = 1
	for _, animal in Animals.List do
		if (Wild.LevelOf[animal.Id] or 1) <= level then
			best = math.max(best, animal.BaseValue)
		end
	end
	return best
end

-- Coins per minute at a chute level, before rebirths and other boosts
function Machines.ChuteRate(level: number): number
	return Machines.BestValueAt(level) * Machines.ChuteMinutes * (1 + Machines.ChuteLevelBonus * (level - 1))
end

function Machines.Price(machine: Machine): number
	local raw = Machines.ChuteRate(machine.Level) * machine.PriceMinutes
	-- round to 2 significant figures, so prices look tidy (1,200 not 1,187)
	local digits = math.max(0, math.floor(math.log10(math.max(raw, 1))) - 1)
	local unit = 10 ^ digits
	return math.max(10, math.round(raw / unit) * unit)
end

-- XP multiplier from a set of owned machines
function Machines.XPMult(owned: { [string]: boolean }): number
	local mult = 1
	for _, machine in List do
		if owned[machine.Id] then
			mult *= machine.XPMult
		end
	end
	return mult
end

-- The XP multiplier you'd have at `level` if you'd bought every machine as it unlocked (the level curve is
-- scaled by this, so keeping up with machines keeps leveling at a steady pace; skipping them slows you down)
function Machines.ExpectedMult(level: number): number
	local mult = 1
	for _, machine in List do
		if machine.Level < level then
			mult *= machine.XPMult
		end
	end
	return mult
end

function Machines.RebirthCost(rebirths: number): number
	local rebirth = Machines.Rebirth
	local raw = Machines.ChuteRate(rebirth.MinLevel) * rebirth.CostMinutes * rebirth.CostGrowth ^ rebirths
	local digits = math.max(0, math.floor(math.log10(math.max(raw, 1))) - 1)
	local unit = 10 ^ digits
	return math.round(raw / unit) * unit
end

-- Rebirth Points for the rebirth that takes you to `rebirths` rebirths in total
function Machines.RebirthPoints(rebirths: number): number
	return Machines.Rebirth.PointsBase + Machines.Rebirth.PointsStep * (rebirths - 1)
end

return Machines
