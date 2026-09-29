--!strict
-- Shared math for the BOX screen, so the client draws exactly what the server set up.
--   * Pet spots on the animal picture: sweet spots (rub these) and angry spots (don't!). They drift around
--     using Workspace:GetServerTimeNow(), a clock Roblox keeps in sync between server and clients.
--   * Seams on the box face: the lines you drag tape across.
-- All positions are 0..1 across the picture (0,0 = top-left).

local BoxMath = {}

-- The animal pokes out of the top of the box, and only the top part of its picture is visible.
-- Pet spots are kept within 0..VISIBLE_HEIGHT (top to bottom) so they're never hidden behind the box.
BoxMath.VISIBLE_HEIGHT = 0.7

export type Spot = {
	Kind: string, -- "Sweet" or "Angry"
	X: number,
	Y: number,
	Radius: number,
	Drift: number, -- how far it drifts from X,Y
	Speed: number, -- drifts per second
	Phase: number,
}

export type Seam = {
	A: Vector2,
	B: Vector2,
}

-- Where a spot is at server time `t` (it wanders in a lazy figure-eight)
function BoxMath.SpotPosition(spot: Spot, start: number, t: number): Vector2
	local angle = (t - start) * spot.Speed * 2 * math.pi + spot.Phase
	return Vector2.new(spot.X + spot.Drift * math.sin(angle), spot.Y + spot.Drift * 0.6 * math.sin(angle * 2))
end

-- The box's seams, in the order they're used (more seams for harder animals)
local SEAMS: { Seam } = {
	{ A = Vector2.new(0.5, 0.1), B = Vector2.new(0.5, 0.9) }, -- down the middle
	{ A = Vector2.new(0.1, 0.5), B = Vector2.new(0.9, 0.5) }, -- across the middle
	{ A = Vector2.new(0.18, 0.1), B = Vector2.new(0.18, 0.9) }, -- left edge
	{ A = Vector2.new(0.82, 0.1), B = Vector2.new(0.82, 0.9) }, -- right edge
	{ A = Vector2.new(0.1, 0.18), B = Vector2.new(0.9, 0.18) }, -- top edge
}

function BoxMath.Seams(count: number): { Seam }
	local seams = {}
	for index = 1, math.min(count, #SEAMS) do
		seams[index] = SEAMS[index]
	end
	return seams
end

local function distanceToSegment(p: Vector2, a: Vector2, b: Vector2): number
	local ab = b - a
	local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
	return (p - (a + ab * t)).Magnitude
end

-- Did this drag (a list of points, 0..1 on the box face) tape along the seam?
-- It must start near one end, finish near the other, and never stray far from the line.
function BoxMath.IsTapeStroke(seam: Seam, path: { Vector2 }): boolean
	if #path < 2 then
		return false
	end
	local endTolerance, lineTolerance = 0.14, 0.09
	local first, last = path[1], path[#path]
	local forward = (first - seam.A).Magnitude < endTolerance and (last - seam.B).Magnitude < endTolerance
	local backward = (first - seam.B).Magnitude < endTolerance and (last - seam.A).Magnitude < endTolerance
	if not (forward or backward) then
		return false
	end
	for _, point in path do
		if distanceToSegment(point, seam.A, seam.B) > lineTolerance then
			return false
		end
	end
	return true
end

return BoxMath
