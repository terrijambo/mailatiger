--!strict
-- Multiplayer: co-op crews for giant animals, opt-in Chaos Mode, and the leaderboards in town.

return {
	-- Giant animals (Carriers > 1 in Animals.luau) need a crew. Other players join by pressing E on the animal.
	Coop = {
		GrabRadius = 14, -- every crew member must be this close to the animal when it's grabbed
		AngerMult = 1.4, -- giants get angry faster, because there are more of you to calm them
	},

	-- Chaos Mode: switch it on in the Pen menu. Your job pays more, but other players can mess with you.
	Chaos = {
		PayoutMult = 1.5,
		SpookCooldown = 5, -- seconds between spooks from the same player
		SpookSpeedMult = 1.6, -- a spooked animal runs this much faster for SpookSeconds
		SpookSeconds = 3,
		ShoveKey = Enum.KeyCode.F,
		ShoveRange = 7,
		ShoveStrength = 70,
		ShoveCooldown = 3,
		ShoveAnger = 10, -- shoving someone mid-BOX makes their animal angrier
	},

	Leaderboards = {
		StoreVersion = "launch1", -- change to reset the boards (fresh at launch, 2026-10-06)
		RefreshSeconds = 60,
		Size = 10,
		-- Tiger times faster than this are ignored (nobody catches AND boxes a tiger that fast, so it's a cheat)
		MinTigerSeconds = 5,
	},

	-- Playing in the same server as your Roblox friends: +10% coins per friend, up to 3 friends (+30%)
	Friends = {
		BonusPerFriend = 0.1,
		MaxFriends = 3,
	},
}
