--!strict
-- Robux purchases. Nothing here can be bought until you create it on Roblox and paste its id below:
--   Game passes:  Creator Dashboard -> your game -> Monetization -> Passes -> Create a Pass. Copy its id.
--   Dev products: Creator Dashboard -> your game -> Monetization -> Developer Products -> Create. Copy its id.
-- An Id of 0 means "not set up yet": it's hidden from the Store and can never be bought.
-- The Price here is only what the Store button shows. The real price is whatever you set on Roblox,
-- so keep them the same.
--
-- Rules (see ROADMAP -> Phase 7): no random crates, and nothing that makes you stronger against other
-- players in Chaos Mode. Passes save time or look cool.

export type Pass = {
	Key: string,
	Id: number,
	Price: number,
	DisplayName: string,
	Description: string,
}

export type Product = {
	Key: string,
	Id: number,
	Price: number,
	DisplayName: string,
	Description: string,
}

local passes: { Pass } = {
	{
		Key = "DoubleCoins",
		Id = 0,
		Price = 199,
		DisplayName = "Double Coins",
		Description = "Every job pays 2x coins. Forever.",
	},
	{
		Key = "BigBag",
		Id = 0,
		Price = 99,
		DisplayName = "Big Mail Bag",
		Description = "Carry 3 more parcels before you have to mail them.",
	},
	{
		Key = "VIP",
		Id = 0,
		Price = 149,
		DisplayName = "VIP Postie",
		Description = "Golden tape on every box, and a golden VIP tag over your head.",
	},
}

local products: { Product } = {
	{
		Key = "CoinsSmall",
		Id = 0,
		Price = 49,
		DisplayName = "Sack of Coins",
		Description = "Coins worth 20 jobs of your best animal.",
	},
	{
		Key = "CoinsMedium",
		Id = 0,
		Price = 129,
		DisplayName = "Crate of Coins",
		Description = "Coins worth 60 jobs of your best animal.",
	},
	{
		Key = "CoinsLarge",
		Id = 0,
		Price = 349,
		DisplayName = "Vault of Coins",
		Description = "Coins worth 200 jobs of your best animal.",
	},
	{
		Key = "UnlockNext",
		Id = 0,
		Price = 99,
		DisplayName = "Skip the Wait",
		Description = "Unlocks the next animal you don't own yet (up to tier 4).",
	},
	{
		Key = "PriorityStamps",
		Id = 0,
		Price = 29,
		DisplayName = "Priority Stamp Pack",
		Description = "5 Priority stamps (double pay on a job).",
	},
	{
		Key = "GruffCoffee",
		Id = 0,
		Price = 5,
		DisplayName = "Buy Gruff a Coffee",
		Description = "Does nothing. Gruff appreciates it. Probably.",
	},
}

local passByKey: { [string]: Pass } = {}
for _, pass in passes do
	passByKey[pass.Key] = pass
end
local productByKey: { [string]: Product } = {}
for _, product in products do
	productByKey[product.Key] = product
end

return {
	Passes = passes,
	PassByKey = passByKey,
	Products = products,
	ProductByKey = productByKey,

	DoubleCoinsMult = 2,
	BigBagSlots = 3,
	-- Coin packs: how many jobs' worth of your best owned animal's base pay
	CoinPackJobs = { CoinsSmall = 20, CoinsMedium = 60, CoinsLarge = 200 },
	UnlockNextMaxTier = 4,
	PriorityStampCount = 5,
}
