--!strict
-- Tuning for each animal's special behavior (the Behavior id in Animals.luau).
-- Intervals are in seconds. "Strength" is how hard the box gets kicked (studs/sec).

return {
	Slosh = { SpinThreshold = 4, RagePerSecond = 15, DamagePerSecond = 4 }, -- Goldfish: turning fast spills water
	Poke = { Interval = 4, Damage = 1 }, -- Hedgehog
	Squawk = { Interval = 8, Rage = 5, HighlightSeconds = 2 }, -- Parrot: lights the box up for everyone
	LayEgg = { Interval = 10, MaxRage = 30, BonusFraction = 0.1 }, -- Chicken: calm = bonus eggs
	Headbutt = { MinInterval = 5, MaxInterval = 8, Strength = 18 }, -- Goat: lurches the box forward
	Spray = { MinRage = 60, Interval = 10, Seconds = 3 }, -- Skunk: green, blurry screen
	StealStamp = { Interval = 12, Chance = 0.3, PayoutMult = 0.9 }, -- Monkey: chips away at your payout
	Hop = { MinInterval = 3, MaxInterval = 5, Strength = 22, GraceSeconds = 0.6 }, -- Kangaroo
	InnerDamage = { Interval = 2, BaseDamage = 0.5, DamagePerRage = 0.04 }, -- Porcupine: worse when angry
	Slide = { DownhillSpeed = -3, SpeedMult = 1.6 }, -- Penguin: you speed up going downhill
	Squeeze = { BelowHP = 0.5, ChancePerSecond = 0.05 }, -- Octopus: slips out of a damaged box
	Snap = { MinInterval = 6, MaxInterval = 9, Strength = 20, Rage = 5 }, -- Crocodile: sideways lunges
	Pound = { RattleDamageMult = 2, RattleImpulseMult = 2 }, -- Gorilla: rattles twice as hard
	Sleep = { AfterSeconds = 15, MaxRage = 20, WeightMult = 2, WakeJostle = 15, WakeRage = 30 }, -- Bear
	Roar = { MinRage = 80, Interval = 8, Radius = 20, StunSeconds = 1.5, BreakoutChance = 0.5 }, -- Tiger
	Freeze = { Interval = 1, PatchSeconds = 5, FreezeSeconds = 1 }, -- Yeti: icy trail freezes other players
	BurnBox = { DrainPerSecond = 2, ByBox = { Cardboard = 1, Wood = 0.6, Steel = 0, Vault = 0 } }, -- Dragon
	Float = { Interval = 6, Seconds = 2, Height = 4 }, -- Alien: box floats up into low signs
	RainbowTrail = { Interval = 0.5, PadSeconds = 4, BoostMult = 1.4, BoostSeconds = 1.5 }, -- Unicorn
}
