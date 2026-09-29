--!strict
-- Types shared between server modules.

-- The Stuff stage's moving bar. Everything is computed from these numbers and the synced server clock,
-- so the client can draw it and the server can judge presses without sending updates every frame.
export type StuffState = {
	Start: number, -- server time when the marker started sweeping
	Speed: number, -- sweeps per second
	ZoneCenter: number, -- 0..1 along the bar
	ZoneWidth: number, -- 0..1
	Amplitude: number, -- how far the zone wiggles (0 = still)
	Frequency: number, -- wiggles per second
	Hits: number,
	HitsNeeded: number,
	Misses: number,
	MissesAllowed: number,
	LastPress: number,
}

export type TapeState = {
	Lid: number, -- 0 = shut, 100 = bursts open
	Tape: number, -- 0..100, done at 100
	Start: number,
	Presses: { number }, -- times of recent presses (for the auto-clicker limit)
	NextPound: number, -- for animals with the Pound twist
}

-- One player's current boxing job, from catching to mailing.
export type Session = {
	Player: Player,
	AnimalId: string,
	Stage: string, -- "Catch", "Stuff" or "Tape"
	StartTime: number,
	Escapes: number,
	StuffMisses: number,
	MaxLid: number,
	Bonus: number,

	-- Locked in when the job starts, from the player's gear
	BoxId: string, -- equipped box
	StampId: string?, -- stamp used on this job (already taken from their inventory)
	GrabHoldMult: number, -- Gloves
	GrabDistanceBonus: number, -- Net
	TapeMult: number, -- Tape Gun

	Critter: Part?, -- the running animal during Catch
	CatchState: { [string]: any }, -- scratch space for the catch AI
	BoxModel: Model?, -- the box on the ground during Stuff and Tape
	Stuff: StuffState?,
	Tape: TapeState?,
}

return {}
