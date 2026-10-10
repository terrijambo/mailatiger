--!strict
-- REBIRTH UPGRADES ♻️: permanent boosts bought with Rebirth Points at the Rebirth Market (Rebirth Beach),
-- kept through every rebirth. Rebirth Points only come from rebirthing (Config/Machines.luau), so these are
-- the long-term goal. (They replaced Diamond Upgrades on 2026-10-10: diamonds became Rebirth Points 1 for 1.)
--
--   MaxLevel    how many times you can buy it
--   BaseCost    Rebirth Points for the first level
--   CostGrowth  each level costs this much more than the last (1.3 = +30%)
--   PerLevel    how much each level adds (meaning depends on the upgrade, see Description)

export type Upgrade = {
	Id: string,
	DisplayName: string,
	Description: string, -- {n} is replaced by the total bonus at a given level
	Emoji: string,
	MaxLevel: number,
	BaseCost: number,
	CostGrowth: number,
	PerLevel: number,
}

local list: { Upgrade } = {
	{
		Id = "GoldenPaws",
		DisplayName = "Golden Paws",
		Description = "+{n}% coins from every job",
		Emoji = "🐾",
		MaxLevel = 10,
		BaseCost = 8,
		CostGrowth = 1.25,
		PerLevel = 10,
	},
	{
		Id = "QuickStudy",
		DisplayName = "Quick Study",
		Description = "+{n}% XP from everything",
		Emoji = "📚",
		MaxLevel = 10,
		BaseCost = 6,
		CostGrowth = 1.25,
		PerLevel = 10,
	},
	{
		Id = "DeepPockets",
		DisplayName = "Deep Pockets",
		Description = "+{n} bag slots",
		Emoji = "👖",
		MaxLevel = 5,
		BaseCost = 10,
		CostGrowth = 1.5,
		PerLevel = 1,
	},
	{
		Id = "CalmHands",
		DisplayName = "Calm Hands",
		Description = "Animals start boxing {n} anger calmer",
		Emoji = "🫳",
		MaxLevel = 5,
		BaseCost = 10,
		CostGrowth = 1.4,
		PerLevel = 3,
	},
	{
		Id = "PayRaise",
		DisplayName = "Pay Raise",
		Description = "+{n}% daily paycheck",
		Emoji = "💵",
		MaxLevel = 4,
		BaseCost = 10,
		CostGrowth = 1.5,
		PerLevel = 25,
	},
	{
		Id = "BusyDesk",
		DisplayName = "Busy Desk",
		Description = "+{n} side orders from Gruff",
		Emoji = "📋",
		MaxLevel = 2,
		BaseCost = 20,
		CostGrowth = 2,
		PerLevel = 1,
	},
	{
		Id = "RebirthKit",
		DisplayName = "Head Start",
		Description = "After a rebirth, you keep your first {n} Post Office machines",
		Emoji = "🧰",
		MaxLevel = 3,
		BaseCost = 30,
		CostGrowth = 1.6,
		PerLevel = 1,
	},
}

local byId: { [string]: Upgrade } = {}
for _, upgrade in list do
	byId[upgrade.Id] = upgrade
end

local Upgrades = {
	List = list,
	ById = byId,
}

-- Rebirth Points for the next level of an upgrade you have at `level`
function Upgrades.Cost(upgrade: Upgrade, level: number): number
	return math.round(upgrade.BaseCost * upgrade.CostGrowth ^ level)
end

-- The total bonus at a level (e.g. Golden Paws level 3 -> 30)
function Upgrades.Bonus(upgrade: Upgrade, level: number): number
	return upgrade.PerLevel * level
end

-- Description with the number filled in
function Upgrades.Text(upgrade: Upgrade, level: number): string
	return (string.gsub(upgrade.Description, "{n}", tostring(Upgrades.Bonus(upgrade, level))))
end

return Upgrades
