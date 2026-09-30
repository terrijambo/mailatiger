--!strict
-- Diamonds 💎: the rare currency. You earn them slowly by playing (level-ups, Gruff's quests, rebirths) or
-- buy them in the Store with Robux. They're spent on DIAMOND UPGRADES: permanent boosts that are kept
-- through rebirths, so they're the long-term goal once coins stop being scarce.
--
-- Upgrades never touch Chaos Mode fights (no shove, spook, speed or troll bonuses), so buying diamonds
-- can't make you stronger against other players.
--
--   MaxLevel    how many times you can buy it
--   BaseCost    diamonds for the first level
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
		DisplayName = "Rebirth Toolkit",
		Description = "After a rebirth, your tools start at level {n}",
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

local Diamonds = {
	List = list,
	ById = byId,

	-- EARNING (free players)
	PerLevelUp = 3, -- every level-up
	MilestoneEvery = 5, -- every 5th level (5, 10, 15...) also gives
	MilestoneBonus = 10,
	PerQuest = 2, -- finishing one of Gruff's main quests
	PerRebirth = 25,
}

-- Diamonds for the next level of an upgrade you have at `level`
function Diamonds.Cost(upgrade: Upgrade, level: number): number
	return math.round(upgrade.BaseCost * upgrade.CostGrowth ^ level)
end

-- The total bonus at a level (e.g. Golden Paws level 3 -> 30)
function Diamonds.Bonus(upgrade: Upgrade, level: number): number
	return upgrade.PerLevel * level
end

-- Description with the number filled in
function Diamonds.Text(upgrade: Upgrade, level: number): string
	return (string.gsub(upgrade.Description, "{n}", tostring(Diamonds.Bonus(upgrade, level))))
end

-- Diamonds earned for reaching `level`
function Diamonds.ForLevel(level: number): number
	return Diamonds.PerLevelUp + (if level % Diamonds.MilestoneEvery == 0 then Diamonds.MilestoneBonus else 0)
end

return Diamonds
