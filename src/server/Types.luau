--!strict
-- Types shared between server modules.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoxMath = require(ReplicatedStorage.Shared.BoxMath)

-- The BOX stage: the animal on your screen (with pet spots) and the box (with seams to tape).
export type BoxState = {
	Start: number, -- server time the stage began (the spots drift from here)
	Anger: number, -- 0..100. At 100 you get launched
	Spots: { BoxMath.Spot },
	SeamCount: number,
	Taped: { boolean }, -- one per seam
	LastSeam: number, -- os.clock() of the last strip (nobody tapes that fast)
	LastPet: { [Player]: number }, -- os.clock() of each petter's last message (limits calming per second)
	LastAngryTouch: number,
	NextPound: number, -- for animals with the Pound twist
	TapeAngerMult: number, -- Tape Gun
	AngerMult: number, -- box and stamp
	HeartReady: { [number]: number }, -- os.clock() each ♥ (by spot index) can be used again
	HeartCooldown: number,
}

-- One boxing job, from catching to mailing. Player is the job's owner. Giant animals also have a Crew of
-- helpers, and everyone in the job gets a Role on the BOX screen: "Pet", "Tape" or "Both".
export type Session = {
	Player: Player,
	Crew: { Player }, -- helpers (not including the owner)
	Roles: { [Player]: string },
	Chaos: boolean, -- Chaos Mode: pays more, others can spook the animal and shove the players
	SpookedBy: { [Player]: number }, -- when each player last spooked this animal (cooldown)
	AnimalId: string,
	ArenaId: string, -- where the animal is released (by its tier, see Config/Arenas.luau)
	Stage: string, -- "Catch" or "Box"
	StartTime: number,
	Escapes: number,
	AngryTouches: number, -- how often you rubbed an angry spot
	MaxAnger: number,
	Bonus: number,
	Variant: string?, -- "Shiny" or "Golden" (rolled when the job starts)
	Difficulty: number, -- 0..1: how far above your level this animal is (wild grabs), see Boxing.Box.Hard
	-- Analytics (Analytics.luau): this job's funnel id and what happened on the BOX screen
	LoopId: string,
	Hearts: number, -- hearts rubbed
	Peels: number, -- seams that peeled back open (the Squeeze twist)
	FirstTouch: number?, -- server time of the first rub or tape on the BOX screen

	-- Locked in when the job starts, from the player's gear
	BoxId: string, -- equipped box
	StampId: string?, -- stamp used on this job (already taken from their inventory)
	GrabHoldMult: number, -- Gloves
	GrabDistanceBonus: number, -- Net
	TapeAngerMult: number, -- Tape Gun

	Critter: Part?, -- the running animal during Catch
	CatchState: { [string]: any }, -- scratch space for the catch AI
	BoxModel: Model?, -- the box on the ground during Box (so other players can watch)
	Box: BoxState?,
}

return {}
