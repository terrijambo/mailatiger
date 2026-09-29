--!strict
-- The Stuff stage's bar math. Shared so the client draws exactly what the server judges.
-- Both sides use Workspace:GetServerTimeNow(), a clock Roblox keeps in sync between server and clients.

local StuffMath = {}

export type Params = {
	Start: number, -- server time the marker started
	Speed: number, -- sweeps per second (one sweep = one side of the bar to the other)
	ZoneCenter: number, -- 0..1
	ZoneWidth: number, -- 0..1
	Amplitude: number, -- how far the green zone wiggles
	Frequency: number, -- wiggles per second
}

-- Where the marker is (0 = left end, 1 = right end). It bounces back and forth.
function StuffMath.Marker(p: Params, t: number): number
	local phase = ((t - p.Start) * p.Speed) % 2
	return if phase <= 1 then phase else 2 - phase
end

-- Where the middle of the green zone is.
function StuffMath.Zone(p: Params, t: number): number
	return p.ZoneCenter + p.Amplitude * math.sin((t - p.Start) * p.Frequency * 2 * math.pi)
end

function StuffMath.IsHit(p: Params, t: number): boolean
	return math.abs(StuffMath.Marker(p, t) - StuffMath.Zone(p, t)) <= p.ZoneWidth / 2
end

return StuffMath
