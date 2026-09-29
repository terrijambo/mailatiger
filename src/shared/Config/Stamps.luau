--!strict
-- Stamps are one-use modifiers. Buy them at the Supply Shop, pick one as your "next job" stamp, and it's
-- used up when you start boxing your next animal. Risk more, earn more.
--   PayoutMult     : multiplies the job's payout
--   AngerMult      : multiplies how fast the animal gets angry in the BOX stage
--   StartAnger     : replaces how angry it starts in the BOX stage
--   UnderParMult   : extra payout multiplier if you finish under par time

export type Stamp = {
	Id: string,
	DisplayName: string,
	Description: string,
	Price: number,
	PayoutMult: number,
	AngerMult: number?,
	StartAnger: number?,
	UnderParMult: number?,
}

local List: { Stamp } = {
	{
		Id = "Fragile",
		DisplayName = "FRAGILE",
		Description = "+50% pay, but the animal gets angry 30% faster.",
		Price = 150,
		PayoutMult = 1.5,
		AngerMult = 1.3,
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
		Description = "Double pay, but the animal starts half-furious. Gruff approves.",
		Price = 1500,
		PayoutMult = 2,
		StartAnger = 50,
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
