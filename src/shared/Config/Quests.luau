--!strict
-- Gruff's main quests: a chain of story orders, one at a time, shown in the quest tracker. They push you on
-- to new animals ("Unlock the Bunny", "Mail a Chicken"...) and new zones. Finish one and the next starts.
--
-- Types:
--   Mail    mail Count parcels of Animal (any animal if Animal is nil), with at least MinStars stars
--   Own     own the Animal (buy it at the Pen)
--   Level   reach Level
--   Orders  complete Count of Gruff's side orders
--   Tool    get Tool up to Level (Supply Shop -> Tools)
--   Chute   install the Chute (Supply Shop -> Chutes)
--   Troll   own the troll item Troll (Supply Shop -> Trolls)

export type Quest = {
	Text: string,
	Type: string,
	Animal: string?,
	Count: number?,
	MinStars: number?,
	Level: number?,
	Tool: string?,
	Chute: string?,
	Troll: string?,
	XP: number,
	Jobs: number, -- coin reward: this many jobs' worth of your best animal
}

local quests: { Quest } = {
	{ Text = "Mail your first Hamster", Type = "Mail", Animal = "Hamster", Count = 1, XP = 30, Jobs = 5 },
	{ Text = "Mail 3 Hamsters", Type = "Mail", Animal = "Hamster", Count = 3, XP = 40, Jobs = 5 },
	{ Text = "Grab a wild Bunny and mail it", Type = "Mail", Animal = "Bunny", Count = 1, XP = 30, Jobs = 3 },
	{
		Text = "Mail 2 Bunnies with 3+ stars",
		Type = "Mail",
		Animal = "Bunny",
		Count = 2,
		MinStars = 3,
		XP = 60,
		Jobs = 5,
	},
	{ Text = "Complete 2 of Gruff's orders", Type = "Orders", Count = 2, XP = 60, Jobs = 5 },
	{ Text = "Reach Level 2 (Goldfish stop running from you)", Type = "Level", Level = 2, XP = 40, Jobs = 3 },
	{ Text = "Mail a Goldfish", Type = "Mail", Animal = "Goldfish", Count = 1, XP = 60, Jobs = 5 },
	{ Text = "Buy Sneakers in the Supply Shop", Type = "Tool", Tool = "Sneakers", Level = 1, XP = 40, Jobs = 3 },
	{ Text = "Reach Level 4 to open the Barn", Type = "Level", Level = 4, XP = 50, Jobs = 5 },
	{ Text = "Mail a Chicken from the Barn", Type = "Mail", Animal = "Chicken", Count = 1, XP = 60, Jobs = 3 },
	{ Text = "Mail 2 Chickens", Type = "Mail", Animal = "Chicken", Count = 2, XP = 100, Jobs = 5 },
	{ Text = "Mail a Pig with 4+ stars", Type = "Mail", Animal = "Pig", Count = 1, MinStars = 4, XP = 150, Jobs = 6 },
	{ Text = "Install the Express Chute", Type = "Chute", Chute = "Express", XP = 120, Jobs = 4 },
	{ Text = "Buy a Banana Peel (troll item)", Type = "Troll", Troll = "BananaPeel", XP = 100, Jobs = 3 },
	{ Text = "Reach Level 8 to open the Jungle", Type = "Level", Level = 8, XP = 150, Jobs = 6 },
	{ Text = "Mail a Monkey from the Jungle", Type = "Mail", Animal = "Monkey", Count = 1, XP = 250, Jobs = 6 },
	{ Text = "Complete 5 of Gruff's orders", Type = "Orders", Count = 5, XP = 250, Jobs = 6 },
	{
		Text = "Mail 3 Skunks without getting sprayed... good luck",
		Type = "Mail",
		Animal = "Skunk",
		Count = 3,
		XP = 300,
		Jobs = 6,
	},
	{ Text = "Reach Level 12 to open the Ice Rink", Type = "Level", Level = 12, XP = 300, Jobs = 8 },
	{ Text = "Mail a Penguin", Type = "Mail", Animal = "Penguin", Count = 1, XP = 400, Jobs = 6 },
	{ Text = "Install the Pneumatic Chute", Type = "Chute", Chute = "Pneumatic", XP = 400, Jobs = 6 },
	{ Text = "MAIL A TIGER", Type = "Mail", Animal = "Tiger", Count = 1, XP = 800, Jobs = 10 },
	{
		Text = "Mail 3 Tigers with 4+ stars",
		Type = "Mail",
		Animal = "Tiger",
		Count = 3,
		MinStars = 4,
		XP = 1200,
		Jobs = 10,
	},
	{ Text = "Reach Level 18 to open the Rooftop", Type = "Level", Level = 18, XP = 1000, Jobs = 10 },
	{ Text = "Mail a Dragon", Type = "Mail", Animal = "Dragon", Count = 1, XP = 1500, Jobs = 10 },
	{ Text = "Mail an Alien (it teleports!)", Type = "Mail", Animal = "Alien", Count = 1, XP = 2000, Jobs = 10 },
	{
		Text = "Get a crew and mail Postmaster Gruff himself",
		Type = "Mail",
		Animal = "Gruff",
		Count = 1,
		XP = 5000,
		Jobs = 20,
	},
}

return quests
