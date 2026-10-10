--!strict
-- Server events (plan in docs/EVENTS_PLAN.md). They follow the real clock, so every server runs the same
-- event at the same time:
--   * every 10 minutes (:10 :20 :30 :40 :50) a SMALL event, picked from the list below (never the same twice
--     in a row), announced AnnounceSeconds early
--   * on the hour (:00) THE BIG ONE: a boss fight for the whole server (Boss below)

local World = require(script.Parent.World)

export type SmallEvent = {
	Id: string,
	DisplayName: string,
	Emoji: string,
	Description: string, -- the banner line while it runs
	Seconds: number,
}

local small: { SmallEvent } = {
	{
		Id = "GoldenHour",
		DisplayName = "GOLDEN HOUR",
		Emoji = "🌟",
		Description = "Shiny and Golden animals are 5x more likely!",
		Seconds = 180,
	},
	{
		Id = "DoubleXP",
		DisplayName = "DOUBLE XP",
		Emoji = "⚡",
		Description = "Every bit of XP counts twice!",
		Seconds = 180,
	},
	{
		Id = "SpeedTape",
		DisplayName = "SPEED TAPE",
		Emoji = "🩹",
		Description = "Animals get angry half as fast, and 5-stamp jobs pay +50%!",
		Seconds = 180,
	},
	{
		Id = "RushOrder",
		DisplayName = "RUSH ORDER",
		Emoji = "📮",
		Description = "Gruff needs one animal, FAST. First 3 to mail it win!",
		Seconds = 180,
	},
	{
		Id = "CoinRain",
		DisplayName = "COIN RAIN",
		Emoji = "🪙",
		Description = "Coins are falling on the plaza! Run over them to grab them!",
		Seconds = 75,
	},
	{
		Id = "MysteryParcel",
		DisplayName = "MYSTERY PARCEL",
		Emoji = "📦",
		Description = "A mystery parcel landed somewhere! Grab it and mail it at the chute!",
		Seconds = 150,
	},
	{
		Id = "Stampede",
		DisplayName = "STAMPEDE",
		Emoji = "🐹",
		Description = "Wild animals are running through town! Grab as many as you can!",
		Seconds = 90,
	},
}

local byId: { [string]: SmallEvent } = {}
for _, event in small do
	byId[event.Id] = event
end

return {
	Small = small,
	ById = byId,
	SlotSeconds = 600, -- one event slot every 10 minutes
	AnnounceSeconds = 30,

	GoldenHourLuck = 5,
	DoubleXPMult = 2,
	SpeedTapeAngerMult = 0.5,
	SpeedTapePerfectMult = 1.5,

	Rush = {
		Animals = { "Hamster", "Bunny", "Goldfish", "Hedgehog", "Parrot" }, -- ones nearly everyone owns
		Jobs = { 10, 6, 4 }, -- 1st, 2nd, 3rd: coins worth this many jobs of your best animal
	},
	CoinRain = {
		Center = Vector3.zero, -- the round plaza in town
		Radius = 56,
		Drops = 160,
		CoinJobs = 0.5, -- each coin = half a job of your best animal
		BigCoinChance = 0.06, -- some are big coins...
		BigCoinJobs = 5, -- ...worth this many jobs
	},
	Mystery = {
		Jobs = 15,
		-- Where it can land: around the plaza and out on the town island's green (x, z)
		Spots = {
			Vector3.new(-40, 0, 28),
			Vector3.new(40, 0, 28),
			Vector3.new(30, 0, -36),
			Vector3.new(-30, 0, -36),
			Vector3.new(0, 0, 50),
			Vector3.new(-82, 0, 30),
			Vector3.new(82, 0, -30),
			Vector3.new(70, 0, 70),
			Vector3.new(-70, 0, -70),
		},
	},
	Stampede = {
		Animals = { "Hamster", "Bunny", "Goldfish", "Hedgehog" },
		Count = 20,
		Center = Vector3.zero, -- (they run around the round plaza)
		Radius = 55,
		Jobs = 1.5, -- each catch = this many jobs of your best animal
		XP = 15,
	},

	-- THE BIG ONE: the hourly boss
	Boss = {
		Bosses = {
			{ AnimalId = "Tiger", DisplayName = "MEGA TIGER" },
			{ AnimalId = "Yeti", DisplayName = "KING YETI" },
			{ AnimalId = "Dragon", DisplayName = "MAMA DRAGON" },
		},
		ArenaCenter = World.ById.Boss.Center, -- the volcano island, southwest of town (Config/World.luau)
		ArenaSize = 110,
		WarnSeconds = 300, -- a small countdown shows this long before...
		GoSeconds = 30, -- ...and the real notification (GO FIGHT, teleporting in) only this long before
		Seconds = 420, -- the whole fight (pin + box), restarting the pin after a launch
		Size = 26, -- studs across
		Speed = 9, -- studs/second when nobody holds it
		Handles = 6,
		PinSeconds = 6, -- held down (enough handles at once) this long to pin it
		StompEvery = 6,
		StompRadius = 26,
		StompStun = 1.6,
		RoarEvery = 15,
		RoarRadius = 40,
		KickEvery = 9, -- it kicks two crates across the arena
		-- The giant box: 5 seams, each needs this many strips (more players = more strips)
		StripsPerSeamPerPlayer = 0.5,
		MaxStripsPerSeam = 4,
		AngerRate = 3, -- per second
		PetCalmPerSecond = 22, -- per petter
		TapeAnger = 4,
		StartAnger = 15,
		RageAnger = 15, -- at 50% and 80% taped it rages
		-- Rewards, scaled by how much you helped (0..1 share of the top helper's work)
		Jobs = 20,
		LosePrizeMinutes = 3, -- lost: coins worth this many minutes of your chute's income, for trying
		-- MAIL IT (after it's boxed): push the box into the giant chute in time for a bonus
		MailSeconds = 60,
		MailSpeedPerPusher = 4, -- studs/second for each player pushing...
		MailMaxSpeed = 12, -- ...up to this
		MailBonus = 1.5, -- rewards x this when it's mailed in time
	},
}
