--!strict
-- Long-term progression: rebirths, Gruff's orders board, and saving.

return {
	Rebirth = {
		BaseCost = 10000000, -- coins needed for the first rebirth...
		CostGrowth = 2.5, -- ...and each one after costs this many times more
		PayoutBonusPerRebirth = 0.25, -- +25% coins from every job, forever, per rebirth
	},

	-- Gruff's daily paycheck: paid automatically once a day when you play. Coins = your best animal's base pay
	-- x JobsPerDay x your streak (days in a row, up to MaxStreak). Miss a day and the streak restarts.
	Paycheck = {
		JobsPerDay = 5,
		MaxStreak = 7,
	},

	Orders = {
		Count = 3,
		RefreshMinutes = 10,
		MinRewardMult = 2, -- reward = animal value x a random number between these...
		MaxRewardMult = 3,
		HardConditionMult = 1.5, -- ...x this if the order has a condition
	},

	Save = {
		StoreName = "PlayerData_v1", -- change the version to wipe everyone's data (e.g. before launch)
		AutosaveSeconds = 60,
		LockTimeoutSeconds = 600, -- a lock older than this is treated as abandoned (crashed server)
		LoadRetries = 5, -- on the last retry a stale lock is taken over so players never get stuck
	},
}
