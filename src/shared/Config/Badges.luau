--!strict
-- Roblox badges (achievements shown on your game's page). Nothing is awarded until you create each badge
-- and paste its id here: Creator Dashboard -> your experience -> Associated Items -> Badges -> Create.
-- Id 0 = not set up yet (skipped).

export type Badge = {
	Id: number,
	DisplayName: string,
	Description: string, -- what to write as the badge's description on Roblox
}

local badges: { [string]: Badge } = {
	FirstDelivery = { Id = 1129895110676226, DisplayName = "First Delivery", Description = "Mailed your first animal." },
	TigerMailed = { Id = 3184538417839974, DisplayName = "Mail a Tiger", Description = "You actually did it. You mailed a tiger." },
	ReturnToSender = {
		Id = 2526709665761261,
		DisplayName = "RETURN TO SENDER",
		Description = "Got launched into the sky by a tiger. Gruff's hat is still missing.",
	},
	FiveStamps = {
		Id = 2349516005192355,
		DisplayName = "Five Stamps",
		Description = "A perfect 5-stamp job. Gruff said 'acceptable'.",
	},
	SpecialDelivery = { Id = 3245484368836474, DisplayName = "Special Delivery", Description = "Mailed Postmaster Gruff himself." },
	ChaosCourier = { Id = 0, DisplayName = "Chaos Courier", Description = "Mailed an animal in Chaos Mode." },
	Reborn = { Id = 0, DisplayName = "Reborn", Description = "Rebirthed for a permanent coin bonus." },
}

return badges
