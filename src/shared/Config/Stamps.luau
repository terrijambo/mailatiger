--!strict
-- Stamps are one-use modifiers. Buy them at the Supply Shop, pick one as your "next job" stamp, and it's
-- used up when you start boxing your next animal. Risk more, earn more.
--   PayoutMult     : multiplies the job's payout
--   MissesAllowed  : replaces how many STUFF misses you get (normally 2)
--   StartLid       : replaces where the lid starts in TAPE
--   UnderParMult   : extra payout multiplier if you finish under par time

export type Stamp = {
	Id: string,
	DisplayName: string,
	Description: string,
	Price: number,
	PayoutMult: number,
	MissesAllowed: number?,
	StartLid: number?,
	UnderParMult: number?,
}

local List: { Stamp } = {
	{
		Id = "Fragile",
		DisplayName = "FRAGILE",
		Description = "+50% pay, but only 1 miss allowed while stuffing.",
		Price = 150,
		PayoutMult = 1.5,
		MissesAllowed = 1,
	},
	{
		Id = "Express",
		DisplayName = "EXPRESS",
		Description = "+75% pay if you finish under par time.",
		Price = 300,
		PayoutMult = 1,
		UnderParMult = 1.75,
	},
	{
		Id = "Priority",
		DisplayName = "PRIORITY",
		Description = "Double pay, but the lid starts half open. Gruff approves.",
		Price = 1500,
		PayoutMult = 2,
		StartLid = 50,
	},
}

local ById: { [string]: Stamp } = {}
for _, stamp in List do
	ById[stamp.Id] = stamp
end

return {
	List = List,
	ById = ById,
}
