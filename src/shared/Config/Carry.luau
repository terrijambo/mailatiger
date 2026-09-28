--!strict
-- Tuning for carrying, damage, rage and delivery ratings.
-- These are the numbers to tweak during playtests.

return {
	-- Where the box floats relative to your character (studs). Negative Z = in front of you.
	HoldOffset = Vector3.new(0, 0.5, -3.5),
	BoxSize = Vector3.new(3, 3, 3),

	-- Wobble: lower responsiveness = floppier, laggier box
	PositionResponsiveness = 18,
	RotationResponsiveness = 8,
	MaxForce = 20000,
	MaxTorque = 20000,
	DropDistance = 12, -- if the box gets snagged this far from your hands, you drop it

	-- Movement while carrying
	BaseWalkSpeed = 16,
	SpeedLossPerWeight = 0.12, -- each point of total weight above 1 slows you 12%
	MinWalkSpeed = 6,
	NormalJumpHeight = 7.2,
	CarryJumpHeight = 4,

	-- Impacts: change in box velocity (studs/sec) measured over ImpactWindow seconds
	ImpactWindow = 0.1,
	ImpactThreshold = 22, -- changes above this hurt the box
	DamagePerSpeed = 0.6, -- HP lost per stud/sec above the threshold
	ImpactCooldown = 0.25,

	-- Rage (0-100)
	JostleThreshold = 8, -- velocity changes above this annoy the animal
	RagePerJostle = 2, -- rage per second, per stud/sec above the jostle threshold
	RattleStartsAt = 70,
	RattleIntervalSlow = 1.5, -- seconds between rattles at RattleStartsAt rage
	RattleIntervalFast = 0.6, -- seconds between rattles at 100 rage
	RattleDamage = 5,
	BellRage = 40, -- the Post Office door bell. Animals hate it.

	-- Escapes
	EscapeWanderRadius = 25,
	RecatchPayoutMult = 0.5,

	-- Delivery rating: minimum fraction of box HP left for each star count (below 2 stars = 1 star)
	StarThresholds = { [5] = 0.9, [4] = 0.7, [3] = 0.5, [2] = 0.25 },
	StarPayoutMult = { 0.4, 0.6, 0.8, 1, 1.25 }, -- index = stars
}
