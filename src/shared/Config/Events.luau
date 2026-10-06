--!strict
-- Server events (plan in docs/EVENTS_PLAN.md). They follow the real clock, so every server runs the same
-- event at the same time:
--   * every 10 minutes (:10 :20 :30 :40 :50) a SMALL event, picked from the list below (never the same twice
--     in a row), announced AnnounceSeconds early
--   * on the hour (:00) THE BIG ONE: a boss fight for the whole server (Boss below)

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
		Diamonds = { 5, 3, 2 }, -- 1st, 2nd, 3rd
		Jobs = { 10, 6, 4 }, -- coins worth this many jobs of your best animal
	},
	CoinRain = {
		Center = Vector3.new(0, 0, 17),
		Radius = 80,
		Drops = 160,
		DiamondChance = 0.06,
		CoinJobs = 0.5, -- each coin = half a job of your best animal
	},
	Mystery = {
		Diamonds = 8,
		Jobs = 15,
		-- Where it can land: the plaza, the boulevard and the avenues (x, z)
		Spots = {
			Vector3.new(-60, 0, 40),
			Vector3.new(60, 0, -20),
			Vector3.new(0, 0, 80),
			Vector3.new(-120, 0, -112),
			Vector3.new(120, 0, -112),
			Vector3.new(-76, 0, -180),
			Vector3.new(76, 0, -200),
			Vector3.new(-100, 0, 117),
			Vector3.new(100, 0, 117),
		},
	},
	Stampede = {
		Animals = { "Hamster", "Bunny", "Goldfish", "Hedgehog" },
		Count = 20,
		Center = Vector3.new(0, 0, 17),
		Radius = 75,
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
		ArenaCenter = Vector3.new(400, 0, -150), -- a floating island over the ocean, east of town
		ArenaSize = 110,
		WarnSeconds = 300, -- the BOSS pad opens and the warning shows this long before
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
		Diamonds = { Min = 10, Max = 30 },
		Jobs = 20,
		LoseDiamonds = 3,
		-- MAIL IT (after it's boxed): push the box into the giant chute in time for a bonus
		MailSeconds = 60,
		MailSpeedPerPusher = 4, -- studs/second for each player pushing...
		MailMaxSpeed = 12, -- ...up to this
		MailBonus = 1.5, -- rewards x this when it's mailed in time
	},
}
