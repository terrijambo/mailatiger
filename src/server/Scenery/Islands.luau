--!strict
-- The sea, the islands and the bridges.
--   Sea      terrain water all around, a sandy seabed, and pale shallows ringing every island
--   Island   a flat top (one big disc plus a few lobes, so each outline is a different blob) standing on a
--            ring of chunky grey rock pillars: a two-tier cliff dropping into the sea, darker at the waterline.
--            Or, with Shore = true, a sandy slope running down into the water instead (the beach).
--   Bridge   a wooden plank bridge on piles, with posts, sagging rope rails and lanterns at both ends

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Kit)

local C = Kit.C
local World = Config.World

local Islands = {}

export type Island = {
	Id: string,
	Center: Vector3,
	Radius: number,
	Folder: Folder,
	Outline: (number) -> number, -- how far the edge is from the center, at an angle (radians, from +X toward +Z)
	OnLand: (Vector3, number) -> boolean, -- is this point on the island, at least `margin` from the edge?
}

local function angleOf(offset: Vector3): number
	return math.atan2(offset.Z, offset.X)
end

---------------------------------------------------------------------------------------------------
-- The sea

function Islands.Sea(islands: { { Center: Vector3, Radius: number } })
	local terrain = Workspace.Terrain
	terrain:Clear()
	terrain.WaterColor = Color3.fromRGB(26, 118, 196)
	terrain.WaterTransparency = 0.55
	terrain.WaterReflectance = 0.5
	terrain.WaterWaveSize = 0.25
	terrain.WaterWaveSpeed = 8
	local top = World.WaterY
	-- Water everywhere, a dark seabed far below it...
	terrain:FillBlock(CFrame.new(0, top - 30, 0), Vector3.new(4000, 60, 4000), Enum.Material.Water)
	terrain:FillBlock(CFrame.new(0, top - 66, 0), Vector3.new(4000, 12, 4000), Enum.Material.Basalt)
	-- ...and sand rising close under the water around every island (two steps: shallow further out, very
	-- shallow close in), so the sea glows a paler turquoise near the shore
	for _, island in islands do
		terrain:FillCylinder(
			CFrame.new(island.Center.X, top - 26, island.Center.Z),
			24,
			island.Radius + 34,
			Enum.Material.Sand
		)
		terrain:FillCylinder(
			CFrame.new(island.Center.X, top - 12, island.Center.Z),
			8,
			island.Radius + 18,
			Enum.Material.Sand
		)
	end
	if not terrain:FindFirstChildOfClass("Clouds") then
		local clouds = Instance.new("Clouds")
		clouds.Cover = 0.55
		clouds.Density = 0.65
		clouds.Color = Color3.new(1, 1, 1)
		clouds.Parent = terrain
	end
end

---------------------------------------------------------------------------------------------------
-- Islands

export type IslandSpec = {
	Id: string,
	Center: Vector3,
	Radius: number,
	Seed: number,
	Ground: Color3,
	GroundMaterial: Enum.Material?,
	Shore: boolean?, -- a sandy beach slope instead of cliffs
	CliffColors: { Color3 }?,
	CliffDark: { Color3 }?,
}

function Islands.Island(parent: Instance, spec: IslandSpec): Island
	local folder = Instance.new("Folder")
	folder.Name = spec.Id
	folder.Parent = parent
	local random = Random.new(spec.Seed * 7919)
	local center, radius = spec.Center, spec.Radius

	-- The outline: a disc of `radius`, plus lobes that bulge out past it (so it's never smaller than radius)
	local discs: { { Offset: Vector3, Radius: number } } = { { Offset = Vector3.zero, Radius = radius } }
	local lobes = random:NextInteger(5, 7)
	local turn = random:NextNumber(0, math.pi * 2)
	for i = 1, lobes do
		local a = turn + (i / lobes) * math.pi * 2 + random:NextNumber(-0.25, 0.25)
		local reach = radius * random:NextNumber(1.04, 1.16)
		local r = radius * random:NextNumber(0.34, 0.48)
		table.insert(discs, { Offset = Vector3.new(math.cos(a), 0, math.sin(a)) * (reach - r), Radius = r })
	end
	local function outline(angle: number): number
		local u = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local best = 0
		for _, d in discs do
			local along = u:Dot(d.Offset)
			local across2 = d.Offset:Dot(d.Offset) - along * along
			local inside = d.Radius * d.Radius - across2
			if inside >= 0 then
				best = math.max(best, along + math.sqrt(inside))
			end
		end
		return best
	end

	-- The flat top (the lobes a hair lower than the main disc, so the overlaps never flicker)
	for index, d in discs do
		Kit.disc(folder, "IslandTop", center + d.Offset, -(index - 1) * 0.01, 4, d.Radius, spec.Ground, {
			Material = spec.GroundMaterial or Enum.Material.SmoothPlastic,
		})
	end

	local bottom = World.CliffBottom
	local water = World.WaterY
	if spec.Shore then
		-- A beach: sand sloping gently down into the sea all the way around
		local count = math.ceil(radius * 2 * math.pi / 6)
		for i = 1, count do
			local a = i / count * math.pi * 2
			local r = outline(a)
			local out = Vector3.new(math.cos(a), 0, math.sin(a))
			local width = 2 * math.pi * r / count * 1.5
			local edge = center + out * (r - 0.5)
			-- (a wedge's tall side is its back, +Z: facing it outward puts the tall side at the island's edge
			-- and the low end out at sea)
			Kit.part(folder, {
				ClassName = "WedgePart",
				Name = "Shore",
				Size = Vector3.new(width, -water + 3, 22),
				CFrame = CFrame.lookAt(
					edge + out * 11 + Vector3.new(0, (water - 3) / 2, 0),
					edge + out * 12 + Vector3.new(0, (water - 3) / 2, 0)
				),
				Color = spec.Ground:Lerp(Color3.fromRGB(255, 240, 200), 0.1),
			})
			Kit.part(folder, {
				Name = "ShoreBase",
				Size = Vector3.new(width, 12, 26),
				CFrame = CFrame.lookAt(
					edge + out * 12 + Vector3.new(0, water - 9, 0),
					edge + out * 13 + Vector3.new(0, water - 9, 0)
				),
				Color = spec.Ground:Lerp(Color3.fromRGB(150, 130, 90), 0.3),
			})
		end
	else
		-- Cliffs: a ring of chunky rock pillars under the edge (their tops peek out just below the grass), and
		-- a lower, darker, wider tier at the waterline
		local light = spec.CliffColors or C.Rock
		local dark = spec.CliffDark or C.RockDark
		local count = math.ceil(radius * 2 * math.pi / 5.5)
		for i = 1, count do
			local a = i / count * math.pi * 2 + random:NextNumber(-0.01, 0.01)
			local r = outline(a)
			local out = Vector3.new(math.cos(a), 0, math.sin(a))
			local width = 2 * math.pi * r / count * random:NextNumber(1.35, 1.7)
			local depth = random:NextNumber(6, 9)
			local topY = random:NextNumber(-1.1, -0.25)
			local upperBottom = water - 2
			local at = center + out * (r - depth / 2 + random:NextNumber(0.6, 1.8))
			local pillar = CFrame.lookAt(at, at + out)
				* CFrame.Angles(
					random:NextNumber(-0.05, 0.05),
					random:NextNumber(-0.18, 0.18),
					random:NextNumber(-0.04, 0.04)
				)
			Kit.part(folder, {
				Name = "Cliff",
				Size = Vector3.new(width, topY - upperBottom, depth),
				CFrame = pillar + Vector3.new(0, (topY + upperBottom) / 2, 0),
				Color = light[random:NextInteger(1, #light)],
			})
			-- Every few pillars, a ledge sticking out a little (it breaks up the wall)
			if random:NextNumber() < 0.3 then
				Kit.part(folder, {
					Name = "CliffLedge",
					Size = Vector3.new(width * 0.7, random:NextNumber(2, 4), 3),
					CFrame = pillar * CFrame.new(0, random:NextNumber(water + 1, -3), -depth / 2 - 1),
					Color = light[random:NextInteger(1, #light)],
				})
			end
			-- The lower tier, a little further out
			local low = center + out * (r - depth / 2 + random:NextNumber(2.5, 4.5))
			Kit.part(folder, {
				Name = "CliffBase",
				Size = Vector3.new(width * 1.1, upperBottom - bottom + 2, depth + 2),
				CFrame = CFrame.lookAt(low, low + out) * CFrame.Angles(0, random:NextNumber(-0.2, 0.2), 0)
					+ Vector3.new(0, (upperBottom + 2 + bottom) / 2, 0),
				Color = dark[random:NextInteger(1, #dark)],
			})
		end
		-- A few boulders in the surf
		for _ = 1, math.floor(radius / 14) do
			local a = random:NextNumber(0, math.pi * 2)
			local out = Vector3.new(math.cos(a), 0, math.sin(a))
			Kit.rock(
				folder,
				center + out * (outline(a) + random:NextNumber(4, 10)) + Vector3.new(0, water - 2, 0),
				random:NextNumber(3, 6),
				random,
				dark
			)
		end
	end

	local function onLand(p: Vector3, margin: number): boolean
		local offset = Vector3.new(p.X - center.X, 0, p.Z - center.Z)
		return offset.Magnitude <= outline(angleOf(offset)) - margin
	end
	return {
		Id = spec.Id,
		Center = center,
		Radius = radius,
		Folder = folder,
		Outline = outline,
		OnLand = onLand,
	}
end

---------------------------------------------------------------------------------------------------
-- Bridges

function Islands.Bridge(parent: Instance, from: Vector3, to: Vector3, name: string)
	local folder = Instance.new("Folder")
	folder.Name = `Bridge_{name}`
	folder.Parent = parent
	local random = Random.new(#name * 131)
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local length = flat.Magnitude
	local along = flat.Unit
	local width = World.BridgeWidth
	local base = CFrame.lookAt(from, from + along) -- (local -Z runs along the bridge)
	local function at(distance: number, side: number, y: number): CFrame
		return base * CFrame.new(side, y, -distance)
	end

	-- The deck: planks across, with little gaps between
	local step = 1.35
	local count = math.floor(length / step)
	for i = 0, count do
		Kit.part(folder, {
			Name = "Plank",
			Size = Vector3.new(width + random:NextNumber(-0.3, 0.3), 0.5, step - 0.18),
			CFrame = at(i * step + step / 2, random:NextNumber(-0.1, 0.1), 0.05)
				* CFrame.Angles(0, random:NextNumber(-0.015, 0.015), 0),
			Color = C.Plank[random:NextInteger(1, #C.Plank)],
		})
	end
	-- Two beams under the planks, and piles down into the sea
	for _, side in { -width / 2 + 1.2, width / 2 - 1.2 } do
		Kit.part(folder, {
			Name = "BridgeBeam",
			Size = Vector3.new(1.2, 1.2, length),
			CFrame = at(length / 2, side, -0.8),
			Color = C.DarkWood,
		})
	end
	local spans = math.max(2, math.round(length / 9))
	local postTops: { [number]: { Vector3 } } = { [-1] = {}, [1] = {} }
	for i = 0, spans do
		local d = length * i / spans
		for _, side in { -1, 1 } do
			local x = side * (width / 2 + 0.2)
			-- Piles only where there's water under the bridge (not on the islands themselves)
			if i > 0 and i < spans then
				Kit.part(folder, {
					Name = "Pile",
					Shape = Enum.PartType.Cylinder,
					Size = Vector3.new(26, 1.6, 1.6),
					CFrame = at(d, x, -13) * CFrame.Angles(0, 0, math.rad(90)),
					Color = C.DarkWood,
				})
			end
			local post = at(d, x, 2)
			Kit.part(folder, { Name = "RailPost", Size = Vector3.new(0.7, 4, 0.7), CFrame = post, Color = C.DarkWood })
			Kit.part(folder, {
				Name = "PostCap",
				Size = Vector3.new(0.95, 0.3, 0.95),
				CFrame = post * CFrame.new(0, 2.1, 0),
				Color = C.Plank[1],
			})
			table.insert(postTops[side], (post * CFrame.new(0, 1.6, 0)).Position)
		end
	end
	-- Rope rails, sagging a little between posts
	for _, side in { -1, 1 } do
		local tops = postTops[side]
		for i = 1, #tops - 1 do
			local a, b = tops[i], tops[i + 1]
			local mid = (a + b) / 2 - Vector3.new(0, 0.7, 0)
			for _, pair in { { a, mid }, { mid, b } } do
				local p, q = pair[1], pair[2]
				Kit.part(folder, {
					Name = "Rope",
					Size = Vector3.new(0.28, 0.28, (q - p).Magnitude + 0.2),
					CFrame = CFrame.lookAt((p + q) / 2, q),
					Color = C.Rope,
					CanCollide = false,
				})
			end
		end
	end
	-- Lanterns at both ends
	for _, d in { 0.8, length - 0.8 } do
		for _, side in { -1, 1 } do
			Kit.lantern(folder, (at(d, side * (width / 2 + 1.4), 0)).Position, 6)
		end
	end
end

return Islands
