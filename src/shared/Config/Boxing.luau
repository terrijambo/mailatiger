--!strict
-- Tuning for boxing an animal: CATCH it in the arena, then BOX it.
--   BOX: the animal and the box pop up on your screen. Rub the animal's sweet spots to keep it calm while you
--   drag tape across every seam of the box. Taping annoys it. If its ANGER hits 100: VINE BOOM, you get
--   launched into the air as a ragdoll, and it escapes back into the arena.
-- Difficulty scales with the animal's tier (1-6). Each animal also gets "twists" (its own tricks), listed below.

export type TwistSet = {
	-- Catch stage
	Hop: boolean?, -- leaps away
	Fly: boolean?, -- rises out of reach now and then
	Hide: boolean?, -- turns invisible for a moment
	Teleport: boolean?, -- blinks to a random spot
	Sleep: boolean?, -- starts asleep; sneak up (hold C) or it wakes and bolts
	Roar: boolean?, -- stuns you if you get close
	Freeze: boolean?, -- freezes you if you get close
	Spray: boolean?, -- sprays you (green, blurry screen) if you get close
	Charge: boolean?, -- charges and knocks you back
	Slippery: boolean?, -- can slip out of your hands when you grab it
	Eggs: boolean?, -- drops eggs you can pick up for bonus coins
	-- Box stage
	Wiggle: boolean?, -- its sweet spots move around faster
	Poke: boolean?, -- its angry spots are bigger (careful where you rub!)
	Pound: boolean?, -- anger spikes every few seconds
	Snap: boolean?, -- random anger jolts
	Squeeze: boolean?, -- taped seams can peel back open
	Breakout: boolean?, -- getting launched triggers the big RETURN TO SENDER moment
}

local Twists: { [string]: TwistSet } = {
	Hamster = {},
	Bunny = { Hop = true },
	Goldfish = { Slippery = true, Wiggle = true },
	Hedgehog = { Poke = true },
	Parrot = { Fly = true },
	Chicken = { Eggs = true },
	Goat = { Charge = true, Pound = true },
	Pig = { Slippery = true },
	Skunk = { Spray = true },
	Monkey = { Fly = true, Wiggle = true },
	Kangaroo = { Hop = true, Pound = true },
	Raccoon = { Hide = true, Slippery = true }, -- (a sneaky little bandit)
	Penguin = { Slippery = true },
	Octopus = { Hide = true, Wiggle = true, Squeeze = true },
	Crocodile = { Charge = true, Snap = true },
	Gorilla = { Charge = true, Pound = true },
	Bear = { Sleep = true, Pound = true },
	Tiger = { Roar = true, Snap = true, Breakout = true },
	Giraffe = { Wiggle = true },
	Elephant = { Charge = true, Pound = true },
	Whale = { Slippery = true, Pound = true },
	Yeti = { Freeze = true, Pound = true },
	Dragon = { Fly = true, Roar = true, Squeeze = true },
	Alien = { Teleport = true, Wiggle = true },
	Unicorn = { Teleport = true, Hop = true },
	Gruff = { Roar = true, Pound = true, Breakout = true },
}

return {
	-- Stage 1: CATCH. The animal runs around the arena. Corner it, then hold E to grab it.
	Catch = {
		FleeRadius = 18, -- it runs when you're this close
		WanderSpeed = 6,
		BaseSpeed = 10, -- flee speed at tier 1...
		SpeedPerTier = 1.6, -- ...plus this per tier above 1 (you walk at 16)
		BaseGrabHold = 0.3, -- seconds you must hold E to grab it...
		GrabHoldPerTier = 0.12, -- ...plus this per tier above 1
		GrabDistance = 6,
		BaseDodgeChance = 0.4, -- chance per second to juke past you when cornered...
		DodgeChancePerTier = 0.25, -- ...plus this per tier above 1
		DodgeSpeedMult = 2.2,
		DodgeSeconds = 0.6,
		SneakSpeed = 9, -- moving slower than this counts as sneaking (hold C)
	},

	-- Stage 2: BOX. Pet it calm while you tape the box shut.
	Box = {
		SeamsByTier = { 2, 2, 3, 3, 4, 5 }, -- tape strips needed to close the box
		StartAnger = 20, -- (boxes and stamps can change this)
		BaseAngerRate = 10, -- anger per second at tier 1... (fast! a ♥ resets it to 0)
		AngerRatePerTier = 4, -- ...plus this per tier above 1
		AngerGrowth = 0.04, -- and it grows 4% per second the longer it takes
		TapeAnger = 12, -- every seam you tape annoys it this much
		PetCalmPerSecond = 30, -- (the boss fight's petting; normal jobs use hearts, below)
		-- Rubbing a ♥ resets anger to 0. That heart then hops to a new spot and recharges for this long
		HeartCooldown = 3.5,
		AngrySpotAnger = 15, -- rubbing an angry spot adds this much (at most twice a second)
		DangerAnger = 75, -- letting anger get above this costs a stamp
		MinSeamInterval = 0.35, -- seconds between tape strips (nobody tapes faster than that)

		-- The animal on your screen: where to rub (positions are 0..1 across the picture)
		SweetSpots = 2,
		AngrySpotsByTier = { 1, 1, 2, 2, 3, 3 },
		SweetRadius = 0.14, -- sweet spot size at tier 1...
		SweetRadiusPerTier = -0.012, -- ...changes by this per tier
		MinSweetRadius = 0.07,
		AngryRadius = 0.1,
		SpotMovePerTier = 0.04, -- how far spots drift around, per tier above 1
		SpotMoveSpeed = 0.35, -- drifts per second

		-- Harder animals: you can grab an animal up to Wild.MaxLevelGap levels above you. Difficulty goes from
		-- 0 (your level or below) to 1 (MaxLevelGap above), and at 1 the BOX stage is:
		Hard = {
			AngerRateMult = 1.7, -- anger climbs this much faster
			HeartCooldownExtra = 2.5, -- hearts take this much longer to recharge (seconds)
			SweetRadiusMult = 0.7, -- hearts are this much smaller
			ExtraAngrySpots = 2, -- more ✖ spots
			ExtraDrift = 0.05, -- spots wander further
		},

		-- Getting launched when anger hits 100
		LaunchSpeed = 110, -- straight up (studs/sec)
		LaunchSideways = 35,
		RagdollSeconds = 3,
	},

	-- Twist tuning (seconds unless noted)
	TwistTuning = {
		Hop = { Interval = 3, Height = 6, Distance = 14, Seconds = 0.8 },
		Fly = { Interval = 7, Height = 9, Seconds = 2.5 },
		Hide = { Interval = 7, Seconds = 2 },
		Teleport = { Interval = 5 },
		Sleep = { WakeRadius = 14, WakeSpeedMult = 1.4 },
		Roar = { Radius = 9, StunSeconds = 1.2, Cooldown = 6 },
		Freeze = { Radius = 9, StunSeconds = 1.5, Cooldown = 7 },
		Spray = { Radius = 9, Seconds = 3, Cooldown = 8 },
		Charge = { Interval = 6, Range = 16, SpeedMult = 2.5, Seconds = 0.8, Knockback = 60 },
		Slippery = { SlipChance = 0.35 },
		Eggs = { Interval = 8, BonusFraction = 0.1 }, -- each egg picked up = 10% of the animal's value
		Wiggle = { SpotSpeedMult = 2.5 },
		Poke = { AngryRadiusMult = 1.6 },
		Pound = { Interval = 3, Spike = 18 },
		Snap = { ChancePerSecond = 0.35, Spike = 12 },
		Squeeze = { PeelChancePerSecond = 0.08 },
	},

	Twists = Twists,

	-- Rating: start at 5 stamps, lose one each for: letting anger pass DangerAnger, rubbing angry spots 3+ times,
	-- going over par time, and each escape. Payout = value x StarPayoutMult[stamps] x EscapePayoutMult^escapes
	-- (x stamp and rebirth bonuses) + egg bonus.
	ParSecondsBase = 30,
	ParSecondsPerTier = 10,
	StarPayoutMult = { 0.4, 0.6, 0.8, 1, 1.25 },
	EscapePayoutMult = 0.5,
}
