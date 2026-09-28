-- Stamps are one-use modifiers slapped on a box before a delivery.
--   PayoutMult  : multiplies the delivery payout
--   DamageMult  : multiplies damage the box takes
--   SpeedMult   : multiplies the carrier's walk speed

export type Stamp = {
	Id: string,
	DisplayName: string,
	Description: string,
	Price: number,
	PayoutMult: number,
	DamageMult: number,
	SpeedMult: number,
}

local List: { Stamp } = {
	{
		Id = "Fragile",
		DisplayName = "FRAGILE",
		Description = "+50% pay, but the box takes +50% damage.",
		Price = 100,
		PayoutMult = 1.5,
		DamageMult = 1.5,
		SpeedMult = 1,
	},
	{
		Id = "BubbleWrap",
		DisplayName = "Bubble Wrap",
		Description = "Box takes 30% less damage.",
		Price = 150,
		PayoutMult = 1,
		DamageMult = 0.7,
		SpeedMult = 1,
	},
	{
		Id = "Express",
		DisplayName = "EXPRESS",
		Description = "Walk 20% faster.",
		Price = 200,
		PayoutMult = 1,
		DamageMult = 1,
		SpeedMult = 1.2,
	},
	{
		Id = "Priority",
		DisplayName = "PRIORITY",
		Description = "+100% pay, box takes +100% damage. Gruff approves.",
		Price = 1000,
		PayoutMult = 2,
		DamageMult = 2,
		SpeedMult = 1,
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
