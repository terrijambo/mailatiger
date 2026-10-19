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

	-- Your chute keeps working while you're away: when you come back after at least MinMinutes, you get
	-- Rate x your chute's coins per minute for the time you were gone (counted up to MaxMinutes).
	-- Kept small on purpose: machines and rebirths cost 6-30 minutes of chute income.
	Offline = {
		MinMinutes = 10,
		MaxMinutes = 180,
		Rate = 0.1,
	},

	-- Delivery streak: every box finished with MinStars or more in a row raises your streak, and each step
	-- up adds PerStep to that job's pay (x1, x1.125, x1.25 ... up to Max). A worse box, a launch or quitting a
	-- job resets it. Kept only while you're in the server.
	Streak = {
		MinStars = 4,
		PerStep = 0.125,
		Max = 2,
	},

	Orders = {
		Count = 3,
		RefreshMinutes = 10,
		MinRewardMult = 2, -- reward = animal value x a random number between these...
		MaxRewardMult = 3,
		HardConditionMult = 1.5, -- ...x this if the order has a condition
	},

	Save = {
		StoreName = "PlayerData_launch1", -- change this to wipe everyone's data. (Fresh at launch, 2026-10-06; v1 held Studio test progress)
		AutosaveSeconds = 60,
		LockTimeoutSeconds = 600, -- a lock older than this is treated as abandoned (crashed server)
		LoadRetries = 5, -- on the last retry a stale lock is taken over so players never get stuck
	},
}
