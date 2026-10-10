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

	-- Inviting friends (MENU > INVITE). A friend who joins from your invite gets a welcome gift right away;
	-- you get paid once they've mailed a few animals (so it's a real player, not a quick alt account).
	-- If you're not in their server then, it waits and is paid the next time you join.
	Invites = {
		NewPlayerGift = 500, -- coins for the friend who joined from an invite (a nice head start)
		InviterRewardMinutes = 30, -- for you, per friend: coins worth this many minutes of your chute's income
		PayAfterMails = 3, -- the friend must mail this many animals first
		MaxRewards = 20, -- the most friends you can be paid for, ever
		StoreName = "Referrals_launch1", -- (rewards waiting for inviters who weren't online)
	},

	-- A one-time "Having fun? Favorite / Get updates" card (no reward: Roblox doesn't allow paying for those)
	Follow = {
		AfterMinutes = 12, -- of play in this session
		MaxAsks = 2, -- across all sessions (asked again later if they closed it the first time)
	},
}
