--!strict
-- Reward codes players can type into Settings -> "Redeem a code" (share them on social media, in your
-- group, in video descriptions...). Each works once per player. Codes aren't case-sensitive.
--
--   Jobs     coins worth this many jobs of the player's best animal (so a code is useful at any level)
--   Stamps   stamp id -> how many
--   Expires  optional: the code stops working after this date, written as os.time({ year = 2026, month = 12, day = 31 })
--
-- Remove a code (or let it expire) to retire it. To add one, copy a line and change the name.

export type Code = {
	Jobs: number?,
	Stamps: { [string]: number }?,
	Expires: number?,
}

local codes: { [string]: Code } = {
	LAUNCH = { Jobs = 10 },
	GRUFF = { Stamps = { Priority = 2 } },
}

return codes
