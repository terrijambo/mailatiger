--!strict
-- Short numbers everywhere in the game: 950, 1k, 12.5k, 150k, 1M, 2.5M, 1B, 1T.
-- Use Format.Short(n) for anything shown to players (UI and Gruff's messages).

local Format = {}

local UNITS: { { Size: number, Suffix: string } } = {
	{ Size = 1e15, Suffix = "Qa" },
	{ Size = 1e12, Suffix = "T" },
	{ Size = 1e9, Suffix = "B" },
	{ Size = 1e6, Suffix = "M" },
	{ Size = 1e3, Suffix = "k" },
}

function Format.Short(n: number): string
	local size = math.abs(n)
	for _, unit in UNITS do
		if size >= unit.Size then
			local scaled = n / unit.Size
			-- One decimal under 100 (12.5k), none above (150k); drop a trailing ".0" (1k, not 1.0k)
			local text = if math.abs(scaled) >= 100
				then tostring(math.floor(scaled))
				else (string.gsub(string.format("%.1f", math.floor(scaled * 10) / 10), "%.0$", ""))
			return text .. unit.Suffix
		end
	end
	return tostring(math.floor(n))
end

return Format
