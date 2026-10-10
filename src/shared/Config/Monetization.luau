--!strict
-- Robux purchases. Nothing here can be bought until you create it on Roblox and paste its id below:
--   Game passes:  Creator Dashboard -> your game -> Monetization -> Passes -> Create a Pass. Copy its id.
--   Dev products: Creator Dashboard -> your game -> Monetization -> Developer Products -> Create. Copy its id.
-- An Id of 0 means "not set up yet": it's hidden from the Store and can never be bought.
-- The Price here is only what the Store button shows. The real price is whatever you set on Roblox,
-- so keep them the same.
--
-- Rules (see ROADMAP -> Decisions): no random crates. The one Robux item that helps in Chaos Mode is the
-- Invincibility Shield (the owner's call, 2026-10-10): for a few minutes shoves and troll items bounce off
-- you, and your animal can't vine boom. Everything else saves time or looks cool.
--
-- TESTING IN STUDIO: items with Id 0 show a "TEST" button in the Store that gives you the item for free
-- (Studio only, so you can try everything before creating it on Roblox). Once an item has a real Id,
-- Studio shows Roblox's own test purchase popup instead (it never charges you in Studio).

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
	Retired: boolean?, -- no longer sold (never shown in the Store), but an old purchase still gets delivered
}

local passes: { Pass } = {
	{
		Key = "BigBag",
		Id = 2004224253,
		Price = 99,
		DisplayName = "Big Mail Bag",
		Description = "Carry 3 more parcels before you have to mail them.",
	},
	{
		Key = "VIP",
		Id = 2002502739,
		Price = 149,
		DisplayName = "VIP Postie",
		Description = "Golden tape on every box, and a golden VIP tag over your head.",
	},
}

local products: { Product } = {
	{
		Key = "ServerBoost",
		Id = 3715699078,
		Price = 99,
		DisplayName = "2x Coins Server Boost",
		Description = "EVERYONE in the server earns 2x coins for 3 minutes. Stacks.",
	},
	{
		Key = "DiamondsSmall",
		Id = 3715699154,
		Price = 49,
		DisplayName = "Handful of Diamonds",
		Description = "(Retired: Rebirth Points only come from rebirthing now.)",
		Retired = true,
	},
	{
		Key = "DiamondsMedium",
		Id = 3715699204,
		Price = 129,
		DisplayName = "Pouch of Diamonds",
		Description = "(Retired)",
		Retired = true,
	},
	{
		Key = "DiamondsLarge",
		Id = 3715699258,
		Price = 349,
		DisplayName = "Chest of Diamonds",
		Description = "(Retired)",
		Retired = true,
	},
	{
		Key = "CoinsSmall",
		Id = 3715699284,
		Price = 49,
		DisplayName = "Sack of Coins",
		Description = "Coins worth 20 jobs of your best animal.",
	},
	{
		Key = "CoinsMedium",
		Id = 3715699312,
		Price = 129,
		DisplayName = "Crate of Coins",
		Description = "Coins worth 60 jobs of your best animal.",
	},
	{
		Key = "CoinsLarge",
		Id = 3715699347,
		Price = 349,
		DisplayName = "Vault of Coins",
		Description = "Coins worth 200 jobs of your best animal.",
	},
	{
		-- (was "Skip the Wait": same product, now the MEGA Lure. Rename it on the Creator Dashboard to match.)
		Key = "UnlockNext",
		Id = 3715699375,
		Price = 99,
		DisplayName = "MEGA Lure",
		Description = "10 minutes of rare animals turning up right next to you, with 8x Shiny & Golden odds.",
	},
	{
		-- Create it on the Creator Dashboard (Developer Products) and paste its id here
		Key = "Invincible",
		Id = 0,
		Price = 79,
		DisplayName = "Invincibility Shield",
		Description = "5 minutes: no vine boom, and Chaos shoves and troll items bounce off you. Stacks.",
	},
	{
		Key = "PriorityStamps",
		Id = 3715699426,
		Price = 29,
		DisplayName = "Priority Stamp Pack",
		Description = "5 Priority stamps (double pay on a job).",
	},
	{
		Key = "GruffCoffee",
		Id = 3715699503,
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

	-- Server Boost: everyone in the server gets this coin multiplier. Each purchase adds BoostSeconds
	-- (buying during a boost extends it), up to BoostMaxSeconds of time left.
	BoostMult = 2,
	BoostSeconds = 180,
	BoostMaxSeconds = 3600,
	-- The old diamond packs (retired 2026-10-10): if a purchase still comes through, it gives this many
	-- Rebirth Points (what the diamonds would have turned into)
	DiamondPacks = { DiamondsSmall = 40, DiamondsMedium = 120, DiamondsLarge = 400 },
	-- Invincibility Shield: seconds per purchase (buying more adds time), up to InvincibleMaxSeconds left
	InvincibleSeconds = 300,
	InvincibleMaxSeconds = 1800,
	-- Roblox Premium members earn a little more (Roblox also pays you for Premium players' playtime)
	PremiumPayoutMult = 1.1,
	-- Join-the-group bonus. Create a group on Roblox, paste its id here (0 = off). Players in it earn more.
	GroupId = 0,
	GroupPayoutMult = 1.1,
	BigBagSlots = 3,
	-- Coin packs: how many jobs' worth of your best owned animal's base pay
	CoinPackJobs = { CoinsSmall = 20, CoinsMedium = 60, CoinsLarge = 200 },
	UnlockNextMaxTier = 4,
	PriorityStampCount = 5,
}
