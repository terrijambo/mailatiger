--!strict
-- Troll items: unlocked by level, bought with coins at the Supply Shop (Trolls tab), used from the hotbar
-- (keys 1-5). They ONLY affect players who turned on Chaos Mode (and their animals), so nobody gets trolled
-- without signing up for it. They're never sold for Robux (no pay-to-win in Chaos Mode).

export type Troll = {
	Id: string,
	DisplayName: string,
	Description: string,
	Emoji: string,
	Level: number, -- level needed to buy it
	Price: number,
	Cooldown: number, -- seconds between uses
	Radius: number, -- how far it reaches (studs)
	Duration: number, -- how long it lasts or how long its effect lasts (seconds)
	Power: number, -- how strong (meaning depends on the item, see Description)
}

local list: { Troll } = {
	{
		Id = "BananaPeel",
		DisplayName = "Banana Peel",
		Description = "Drop a peel. The first Chaos player who steps on it slips and flops over.",
		Emoji = "🍌",
		Level = 5,
		Price = 2000,
		Cooldown = 10,
		Radius = 3,
		Duration = 25, -- the peel stays this long
		Power = 1.6, -- seconds flopped over
	},
	{
		Id = "StinkBomb",
		DisplayName = "Stink Bomb",
		Description = "A green cloud: Chaos players in it see green and slow down, and Chaos animals flee.",
		Emoji = "💨",
		Level = 9,
		Price = 12000,
		Cooldown = 20,
		Radius = 14,
		Duration = 6,
		Power = 0.5, -- speed multiplier inside the cloud
	},
	{
		Id = "GluePuddle",
		DisplayName = "Glue Puddle",
		Description = "A sticky puddle. Chaos players who walk through it crawl along.",
		Emoji = "🧴",
		Level = 13,
		Price = 45000,
		Cooldown = 18,
		Radius = 7,
		Duration = 12,
		Power = 0.3, -- speed multiplier on the glue
	},
	{
		Id = "TapeBomb",
		DisplayName = "Tape Bomb",
		Description = "Lob it at the nearest Chaos player who's boxing: their animal gets furious.",
		Emoji = "💣",
		Level = 17,
		Price = 160000,
		Cooldown = 30,
		Radius = 35,
		Duration = 0,
		Power = 22, -- anger added
	},
	{
		Id = "AirHorn",
		DisplayName = "Air Horn",
		Description = "HOOONK. Knocks back nearby Chaos players and scares their animals.",
		Emoji = "📯",
		Level = 22,
		Price = 600000,
		Cooldown = 25,
		Radius = 25,
		Duration = 0,
		Power = 70, -- knockback strength
	},
}

local byId: { [string]: Troll } = {}
for _, troll in list do
	byId[troll.Id] = troll
end

return {
	List = list,
	ById = byId,
	-- The hotbar keys, in order
	Keys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five },
}
