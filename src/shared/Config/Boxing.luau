--!strict
-- Tuning for the three boxing stages: CATCH -> STUFF -> TAPE.
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
	-- Stuff stage
	Wiggle: boolean?, -- the green zone moves
	-- Tape stage
	Poke: boolean?, -- some of your presses go "ouch" and don't count
	Pound: boolean?, -- slams the lid up every few seconds
	Snap: boolean?, -- random lid jolts
	Squeeze: boolean?, -- tape slowly peels off
	Breakout: boolean?, -- bursting the lid triggers the big RETURN TO SENDER moment
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
	Porcupine = { Poke = true },
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

	-- Stage 2: STUFF. A marker sweeps across a bar; press when it's in the green zone.
	Stuff = {
		BaseSweepsPerSecond = 0.6, -- how fast the marker crosses the bar at tier 1...
		SweepsPerTier = 0.18, -- ...plus this per tier above 1
		BaseZoneWidth = 0.3, -- green zone width (fraction of the bar) at tier 1...
		ZoneWidthPerTier = -0.035, -- ...changes by this per tier
		MinZoneWidth = 0.08,
		HitsNeededByTier = { 1, 1, 2, 2, 3, 3 },
		MissesAllowed = 2, -- one more miss than this and it escapes
		PressCooldown = 0.25,
		LatencyAllowance = 0.4, -- seconds of network lag the server forgives when judging your press
	},

	-- Stage 3: TAPE. The animal pushes the lid up; mash to shove it down and tape it shut.
	Tape = {
		BasePush = 10, -- lid rises this much per second at tier 1 (100 = burst open)...
		PushPerTier = 6, -- ...plus this per tier above 1
		RageGrowth = 0.05, -- push grows 5% per second as the animal gets angrier
		PressDown = 7, -- each press shoves the lid down this much
		BasePresses = 12, -- presses needed to finish taping at tier 1...
		PressesPerTier = 5, -- ...plus this per tier above 1
		MaxPressesPerSecond = 14, -- extra presses are ignored (no auto-clickers)
		DangerLid = 75, -- letting the lid get above this costs a stamp
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
		Wiggle = { Amplitude = 0.25, Frequency = 0.6 },
		Poke = { OuchChance = 0.2 },
		Pound = { Interval = 3, Spike = 22 },
		Snap = { ChancePerSecond = 0.35, Spike = 14 },
		Squeeze = { TapeLossPerSecond = 4 },
	},

	Twists = Twists,

	-- Rating: start at 5 stamps, lose one for each stuff miss, letting the lid pass DangerLid, going over par
	-- time, and each escape. Payout = animal value x StarPayoutMult[stamps] x EscapePayoutMult^escapes + egg bonus.
	ParSecondsBase = 30,
	ParSecondsPerTier = 10,
	StarPayoutMult = { 0.4, 0.6, 0.8, 1, 1.25 },
	EscapePayoutMult = 0.5,
}
