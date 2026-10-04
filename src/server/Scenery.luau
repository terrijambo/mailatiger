--!strict
-- Everything in the world that's just for looks: the island (terrain), the ocean and mountains, the hub's
-- terraces, fountain and info boards, the street grid out to each zone with their giant entrance banners,
-- and each zone's theme (a house by the Backyard, a farm by the Barn, a waterfall cliff in the Jungle, a snowy
-- winter zone around the Ice Rink, and a city of skyscrapers around the Rooftop).
-- Gameplay pieces (arenas, counters, pads) are built in MapBuilder, which calls Scenery.Build with the layout.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Scenery = {}

export type Zone = {
	Id: string,
	Name: string,
	Color: Color3,
	Icon: string, -- emoji on the banner
	Center: Vector3,
	HalfX: number,
	HalfZ: number,
	FloorY: number,
	Gate: Vector3, -- where the path arrives
}

export type Layout = {
	PlazaMin: Vector3,
	PlazaMax: Vector3,
	Zones: { Zone },
}

-- Bright, flat colors in the style of popular simulators (smooth plastic, no gritty textures)
local C = {
	Grass = Color3.fromRGB(122, 204, 92),
	GrassTop = Color3.fromRGB(112, 214, 86),
	Brick = Color3.fromRGB(214, 124, 88), -- terrace sides
	Stone = Color3.fromRGB(238, 238, 244),
	Path = Color3.fromRGB(78, 80, 92), -- roads
	Sidewalk = Color3.fromRGB(186, 188, 196),
	Line = Color3.fromRGB(250, 250, 250),
	Wood = Color3.fromRGB(196, 136, 84),
	White = Color3.fromRGB(250, 250, 250),
	Roof = Color3.fromRGB(80, 120, 220),
	Water = Color3.fromRGB(96, 196, 255),
	Leaves = Color3.fromRGB(96, 196, 84),
	Pine = Color3.fromRGB(64, 160, 96),
	Bark = Color3.fromRGB(150, 100, 64),
	Snow = Color3.fromRGB(246, 250, 255),
	Glass = Color3.fromRGB(170, 220, 250),
	Dark = Color3.fromRGB(40, 42, 54),
	Gold = Color3.fromRGB(255, 205, 60),
	Hedge = Color3.fromRGB(140, 218, 106),
	Sand = Color3.fromRGB(236, 206, 148),
}

-- Leafy greens for trees, picked by position so the world doesn't look copy-pasted
local LEAF_COLORS = {
	Color3.fromRGB(96, 196, 84),
	Color3.fromRGB(120, 210, 90),
	Color3.fromRGB(80, 180, 90),
	Color3.fromRGB(140, 214, 96),
}

-- Everything is smooth plastic except materials that matter to the look: Neon (glows), Glass
-- (see-through), Ice (shiny)
local KEEP_MATERIAL = {
	[Enum.Material.Neon] = true,
	[Enum.Material.Glass] = true,
	[Enum.Material.Ice] = true,
}

local function part(parent: Instance, props: { [string]: any }): BasePart
	local className = props.ClassName or "Part"
	local p = Instance.new(className) :: BasePart
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "ClassName" then
			(p :: any)[key] = value
		end
	end
	if not KEEP_MATERIAL[p.Material] then
		p.Material = Enum.Material.SmoothPlastic
	end
	p.Parent = parent
	return p
end

local function box(
	parent: Instance,
	name: string,
	center: Vector3,
	size: Vector3,
	color: Color3,
	material: Enum.Material?
): BasePart
	return part(parent, {
		Name = name,
		Position = center,
		Size = size,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
end

-- A sign face: big chunky text on one face of a part (like the zone banners in popular simulators)
local function signText(
	target: BasePart,
	face: Enum.NormalId,
	text: string,
	color: Color3,
	subtitle: string?,
	background: Color3?
)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.MaxDistance = 600
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = background or C.Dark
	frame.BackgroundTransparency = if background then 0 else 1
	frame.Parent = gui
	if background then
		-- A light frame just inside the edge, so signs look finished
		local border = Instance.new("UIStroke")
		border.Thickness = 10
		border.Color = Color3.new(1, 1, 1)
		border.Transparency = 0.2
		border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		border.Parent = frame
	end
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(0.9, if subtitle then 0.56 else 0.8)
	title.Position = UDim2.fromScale(0.05, if subtitle then 0.08 else 0.1)
	title.Font = Enum.Font.LuckiestGuy
	title.TextScaled = true
	title.TextWrapped = false -- one line, shrunk to fit (instead of wrapping into a jumble)
	title.TextColor3 = color
	title.Text = text
	title.Name = "Title"
	title.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Transparency = 0.1
	stroke.Parent = title
	if subtitle then
		local sub = Instance.new("TextLabel")
		sub.BackgroundTransparency = 1
		sub.Size = UDim2.fromScale(0.86, 0.22)
		sub.Position = UDim2.fromScale(0.07, 0.68)
		sub.TextWrapped = false
		sub.Font = Enum.Font.FredokaOne
		sub.TextScaled = true
		sub.TextColor3 = Color3.new(1, 1, 1)
		sub.Text = subtitle
		sub.Name = "Subtitle"
		sub.Parent = frame
		local subStroke = stroke:Clone()
		subStroke.Thickness = 3
		subStroke.Parent = sub
	end
	gui.Parent = target
end

---------------------------------------------------------------------------------------------------
-- Terrain: island, beach, ocean, mountains

local function buildTerrain(_layout: Layout)
	local terrain = Workspace.Terrain
	-- Water looks nicer a bit clearer and wavier than the default
	terrain.WaterColor = C.Water
	terrain.WaterTransparency = 0.35
	terrain.WaterWaveSize = 0.2
	terrain.WaterWaveSpeed = 8

	-- Ocean everywhere (the island itself is flat smooth parts: see buildGround)
	terrain:FillBlock(CFrame.new(0, -16, -150), Vector3.new(2400, 20, 2400), Enum.Material.Water)
	-- Brighter terrain colors for the mountains on the horizon
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(150, 150, 162))
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(112, 196, 90))
	terrain:SetMaterialColor(Enum.Material.Snow, Color3.fromRGB(248, 250, 255))
	-- Puffy clouds
	if not terrain:FindFirstChildOfClass("Clouds") then
		local clouds = Instance.new("Clouds")
		clouds.Cover = 0.55
		clouds.Density = 0.65
		clouds.Color = Color3.new(1, 1, 1)
		clouds.Parent = terrain
	end

	-- Mountains on the horizon (big lumps of rock, snow-capped on the winter side)
	type Mountain = { X: number, Z: number, R: number, Snowy: boolean }
	local mountains: { Mountain } = {
		{ X = -420, Z = -560, R = 150, Snowy = true },
		{ X = -140, Z = -600, R = 170, Snowy = true },
		{ X = 170, Z = -600, R = 160, Snowy = false },
		{ X = 440, Z = -540, R = 150, Snowy = false },
		{ X = -560, Z = -300, R = 140, Snowy = true },
		{ X = 570, Z = -300, R = 140, Snowy = false },
		{ X = -560, Z = 40, R = 120, Snowy = false },
		{ X = 560, Z = 40, R = 120, Snowy = false },
		{ X = -300, Z = 380, R = 110, Snowy = false },
		{ X = 320, Z = 380, R = 110, Snowy = false },
	}
	for _, m in mountains do
		local x, z, r = m.X, m.Z, m.R
		terrain:FillBall(Vector3.new(x, -r * 0.35, z), r, Enum.Material.Rock)
		terrain:FillBall(Vector3.new(x + r * 0.3, -r * 0.45, z + r * 0.2), r * 0.8, Enum.Material.Grass)
		if m.Snowy then
			terrain:FillBall(Vector3.new(x, r * 0.35, z), r * 0.32, Enum.Material.Snow)
		end
	end
end

-- The island: flat smooth ground at exactly y = 0 (terrain bulges above its fill line, which buried the
-- plaza and half-sank the props), a sandy beach step around it, and flat colored ground under each zone.
-- Snowy hills (smooth white domes) around the winter zone: { x, z offset from the Ice Rink's center, radius }
local SNOW_HILLS = { { -80, -40, 28 }, { -80, 30, 22 }, { 70, -45, 30 }, { 90, 20, 20 }, { 0, -85, 34 } }

-- Is this spot on one of the snow hills (so trees and rocks don't get half-buried in them)?
local function onSnowHill(layout: Layout, p: Vector3, pad: number): boolean
	for _, zone in layout.Zones do
		if zone.Id == "IceRink" then
			for _, h in SNOW_HILLS do
				local dx, dz = p.X - (zone.Center.X + h[1]), p.Z - (zone.Center.Z + h[2])
				if math.sqrt(dx * dx + dz * dz) < h[3] + pad then
					return true
				end
			end
		end
	end
	return false
end

local function buildGround(parent: Instance, layout: Layout)
	local folder = Instance.new("Folder")
	folder.Name = "Ground"
	folder.Parent = parent
	box(folder, "Island", Vector3.new(0, -2, -150), Vector3.new(600, 4, 640), C.Grass)
	box(folder, "Beach", Vector3.new(0, -2.4, -150), Vector3.new(680, 3.2, 720), C.Sand)

	local zoneGround: { [string]: Color3 } = {
		Barn = Color3.fromRGB(222, 180, 122),
		Jungle = Color3.fromRGB(86, 172, 76),
		IceRink = C.Snow,
		Rooftop = Color3.fromRGB(96, 98, 110),
	}
	for _, zone in layout.Zones do
		local color = zoneGround[zone.Id]
		if color then
			local pad = if zone.Id == "Rooftop" or zone.Id == "IceRink" then 55 else 35
			box(
				folder,
				"ZoneGround",
				Vector3.new(zone.Center.X, -0.08, zone.Center.Z),
				Vector3.new(zone.HalfX * 2 + pad * 2, 0.24, zone.HalfZ * 2 + pad * 2),
				color
			)
		end
		-- Snowy hills (smooth white domes) around the winter zone
		if zone.Id == "IceRink" then
			local c = zone.Center
			for _, h in SNOW_HILLS do
				part(folder, {
					Name = "SnowHill",
					Shape = Enum.PartType.Ball,
					Size = Vector3.one * h[3] * 2,
					Position = Vector3.new(c.X + h[1], -h[3] * 0.45, c.Z + h[2]),
					Color = C.Snow,
				})
			end
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Little building blocks for scenery

-- A round, blobby cartoon tree: a short trunk and a cluster of leafy balls
local function tree(parent: Instance, at: Vector3, height: number, leaves: Color3?)
	local h = height
	local green = leaves or LEAF_COLORS[(math.floor(at.X * 7 + at.Z * 3) % #LEAF_COLORS) + 1]
	box(parent, "Trunk", at + Vector3.new(0, h * 0.3, 0), Vector3.new(h * 0.13, h * 0.6, h * 0.13), C.Bark)
	local blobs = {
		{ 0, 0.72, 0, 0.62 },
		{ 0.22, 0.6, 0.12, 0.44 },
		{ -0.2, 0.62, -0.1, 0.42 },
		{ 0.05, 0.9, -0.05, 0.4 },
	}
	for index, b in blobs do
		part(parent, {
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * h * b[4],
			Position = at + Vector3.new(h * b[1], h * b[2], h * b[3]),
			Color = green:Lerp(Color3.new(1, 1, 0.7), (index - 1) * 0.05),
		})
	end
end

-- A low-poly pine: stacked discs getting smaller, with snow on top if snowy
local function pine(parent: Instance, at: Vector3, height: number, snowy: boolean)
	local h = height
	box(
		parent,
		"Trunk",
		at + Vector3.new(0, h * 0.15, 0),
		Vector3.new(h * 0.1, h * 0.3, h * 0.1),
		C.Bark,
		Enum.Material.Wood
	)
	for i = 0, 3 do
		local t = i / 4
		local radius = h * (0.42 - t * 0.3)
		local y = h * (0.25 + t * 0.22)
		part(parent, {
			Name = "Needles",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(h * 0.16, radius * 2, radius * 2),
			CFrame = CFrame.new(at + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = if snowy and i == 3 then C.Snow else C.Pine,
		})
	end
end

local function lamppost(parent: Instance, at: Vector3)
	box(parent, "LampPole", at + Vector3.new(0, 4.5, 0), Vector3.new(0.5, 9, 0.5), C.Dark, Enum.Material.Metal)
	local bulb = part(parent, {
		Name = "Lamp",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.6, 1.6, 1.6),
		Position = at + Vector3.new(0, 9.4, 0),
		Color = Color3.fromRGB(255, 235, 170),
		Material = Enum.Material.Neon,
	})
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 225, 160)
	light.Parent = bulb
end

---------------------------------------------------------------------------------------------------
-- Roads: a small street grid, all at right angles (like the towns in popular city sims). The ring road
-- around the plaza, a boulevard north of town, and streets out to every zone gate. Where two roads meet,
-- the asphalt joins into one square, sidewalks stop at the corner (or wrap around it), the center dashes
-- stop, and crosswalks go across the side street. Lamps only ever stand on a sidewalk.

export type Road = { A: Vector3, B: Vector3, Width: number }

local SIDEWALK = 3 -- sidewalk width
local RING = 22 -- plaza edge to the middle of the ring road
local RING_WIDTH = 14
local STREET_WIDTH = 12
local BOULEVARD_GAP = 30 -- ring road to boulevard (middle to middle)
-- The avenues up to the far zones run between the Backyard's trees (x up to about 60) and the Barn and
-- Jungle (the Jungle's cliff starts at x = 95), so nothing overlaps them
local AVENUE_X = 76

local function makeRoad(ax: number, az: number, bx: number, bz: number, width: number): Road
	return { A = Vector3.new(ax, 0, az), B = Vector3.new(bx, 0, bz), Width = width }
end

-- The whole street grid for this layout
local function roadNetwork(layout: Layout): { Road }
	local min, max = layout.PlazaMin, layout.PlazaMax
	local x0, x1 = min.X - RING, max.X + RING
	local z0, z1 = min.Z - RING, max.Z + RING
	local roads = {
		makeRoad(x0, z0, x1, z0, RING_WIDTH),
		makeRoad(x0, z1, x1, z1, RING_WIDTH),
		makeRoad(x0, z0, x0, z1, RING_WIDTH),
		makeRoad(x1, z0, x1, z1, RING_WIDTH),
	}
	-- The boulevard north of town. Zones whose gates are close to it sit along it; the rest are "far".
	local boulevardZ = z0 - BOULEVARD_GAP
	local near: { Zone }, far: { Zone } = {}, {}
	for _, zone in layout.Zones do
		local front = zone.Gate.Z + 14 -- roads stop a little in front of the gate
		table.insert(if front > boulevardZ - 40 then near else far, zone)
	end
	local west, east = 0, 0
	for _, zone in near do
		west = math.min(west, zone.Gate.X)
		east = math.max(east, zone.Gate.X)
	end
	table.insert(roads, makeRoad(west, boulevardZ, east, boulevardZ, RING_WIDTH))
	for _, zone in near do
		local front = zone.Gate.Z + 14
		if front < boulevardZ - RING_WIDTH / 2 - 4 then -- (a gate right on the boulevard needs no street)
			table.insert(roads, makeRoad(zone.Gate.X, boulevardZ, zone.Gate.X, front, STREET_WIDTH))
		end
	end
	-- Main street: the ring road straight up to the boulevard, facing the Backyard gate
	table.insert(roads, makeRoad(0, z0, 0, boulevardZ, STREET_WIDTH))
	-- Far zones: an avenue from the ring road up past the boulevard, then across and up to the gate
	for _, zone in far do
		local avenueX = if zone.Gate.X < 0 then -AVENUE_X else AVENUE_X
		local front = zone.Gate.Z + 14
		local turnZ = front + 31
		table.insert(roads, makeRoad(avenueX, z0, avenueX, turnZ, STREET_WIDTH))
		table.insert(roads, makeRoad(avenueX, turnZ, zone.Gate.X, turnZ, STREET_WIDTH))
		table.insert(roads, makeRoad(zone.Gate.X, turnZ, zone.Gate.X, front, STREET_WIDTH))
	end
	return roads
end

local function roadDirection(road: Road): Vector3
	return (road.B - road.A).Unit
end

local function roadLength(road: Road): number
	return (road.B - road.A).Magnitude
end

-- How far along the road's middle line a point is, or nil if the point isn't on that line
local function alongRoad(road: Road, point: Vector3): number?
	local direction = roadDirection(road)
	local t = (point - road.A):Dot(direction)
	if t < -0.5 or t > roadLength(road) + 0.5 then
		return nil
	end
	if (road.A + direction * t - point).Magnitude > 0.5 then
		return nil
	end
	return t
end

-- Where another road meets this one: how far along this road, the other road, which ways the other road
-- leaves the meeting point, and whether the meeting point is one of the other road's ends
type Meeting = { T: number, Other: Road, Arms: { Vector3 }, OtherEnds: boolean }

local function meetingsOf(road: Road, roads: { Road }): { Meeting }
	local list: { Meeting } = {}
	local direction = roadDirection(road)
	for _, other in roads do
		if other ~= road then
			local point: Vector3? = nil
			for _, p in { other.A, other.B, road.A, road.B } do
				if not point and alongRoad(road, p) and alongRoad(other, p) then
					point = p
				end
			end
			if not point and math.abs(direction:Dot(roadDirection(other))) < 0.01 then
				-- Crossing in the middle of both
				local p = if math.abs(direction.X) > 0.5
					then Vector3.new(other.A.X, 0, road.A.Z)
					else Vector3.new(road.A.X, 0, other.A.Z)
				if alongRoad(road, p) and alongRoad(other, p) then
					point = p
				end
			end
			if point then
				local otherT = alongRoad(other, point) :: number
				local otherLength = roadLength(other)
				local arms = {}
				if otherT > 0.5 then
					table.insert(arms, -roadDirection(other))
				end
				if otherT < otherLength - 0.5 then
					table.insert(arms, roadDirection(other))
				end
				table.insert(list, {
					T = alongRoad(road, point) :: number,
					Other = other,
					Arms = arms,
					OtherEnds = otherT < 0.5 or otherT > otherLength - 0.5,
				})
			end
		end
	end
	return list
end

-- White zebra stripes across a road at `at` (the road runs along `along`)
local function crosswalk(parent: Instance, at: Vector3, along: Vector3, roadWidth: number)
	local frame = CFrame.lookAt(at, at + along)
	for i = -3, 3 do
		part(parent, {
			Name = "Crosswalk",
			Size = Vector3.new(roadWidth - 2, 0.05, 1.4),
			CFrame = frame * CFrame.new(0, 0.12, i * 2.6),
			Color = C.Line,
			CanCollide = false,
		})
	end
end

-- Is this spot on (or right next to) any road's asphalt or sidewalks?
local function onAnyRoad(roads: { Road }, point: Vector3, margin: number): boolean
	for _, road in roads do
		local t = (point - road.A):Dot(roadDirection(road))
		local reach = road.Width / 2 + SIDEWALK + margin
		local length = roadLength(road)
		if t > -reach and t < length + reach then
			local closest = road.A + roadDirection(road) * math.clamp(t, 0, length)
			local offset = point - closest
			if math.abs(offset.X) < reach and math.abs(offset.Z) < reach then
				return true
			end
		end
	end
	return false
end

local function buildRoads(parent: Instance, roads: { Road })
	for _, road in roads do
		local direction = roadDirection(road)
		local length = roadLength(road)
		local side = Vector3.new(-direction.Z, 0, direction.X)
		local meetings = meetingsOf(road, roads)
		local function frameAt(t: number, lateral: number, y: number): CFrame
			local p = road.A + direction * t + side * lateral + Vector3.new(0, y, 0)
			return CFrame.lookAt(p, p + direction)
		end

		-- Asphalt. At a corner it runs on to fill the corner square; at a dead end it stops flat.
		local from, to = 0, length
		for _, meeting in meetings do
			if meeting.OtherEnds then
				if meeting.T < 0.5 then
					from = -meeting.Other.Width / 2
				elseif meeting.T > length - 0.5 then
					to = length + meeting.Other.Width / 2
				end
			end
		end
		part(parent, {
			Name = "Road",
			Size = Vector3.new(road.Width, 0.3, to - from),
			CFrame = frameAt((from + to) / 2, 0, -0.05),
			Color = C.Path,
		})

		-- Crosswalks across this road where it leaves a junction with a road that carries on through it
		local noDashes: { { number } } = {}
		local placed: { number } = {}
		for _, meeting in meetings do
			local half = meeting.Other.Width / 2
			if not meeting.OtherEnds then
				for _, arm in { -1, 1 } do
					local t = meeting.T + arm * (half + 9.5)
					local free = t > 8 and t < length - 8
					for _, other in placed do
						if math.abs(other - t) < 17 then
							free = false -- (two junctions close together share one crosswalk)
						end
					end
					if free then
						table.insert(placed, t)
						crosswalk(parent, road.A + direction * t, direction, road.Width)
					end
				end
				table.insert(noDashes, { meeting.T - half - 18, meeting.T + half + 18 })
			else
				table.insert(noDashes, { meeting.T - half - 3, meeting.T + half + 3 })
			end
		end

		-- White center dashes every 10 studs (not inside junctions or over crosswalks)
		for d = 5, length - 5, 10 do
			local clear = true
			for _, zone in noDashes do
				if d > zone[1] and d < zone[2] then
					clear = false
				end
			end
			if clear then
				part(parent, {
					Name = "RoadLine",
					Size = Vector3.new(0.6, 0.05, 4),
					CFrame = frameAt(d, 0, 0.12),
					Color = C.Line,
					CanCollide = false,
				})
			end
		end

		-- Sidewalks on both sides, cut where a side street joins and wrapped around outside corners
		for _, s in { -1, 1 } do
			local walkFrom, walkTo = 0, length
			local cuts: { { number } } = {}
			for _, meeting in meetings do
				local half = meeting.Other.Width / 2
				local toThisSide = false
				for _, arm in meeting.Arms do
					if arm:Dot(side) * s > 0.5 then
						toThisSide = true
					end
				end
				if meeting.T < 0.5 then
					walkFrom = if toThisSide or not meeting.OtherEnds then half else -(half + SIDEWALK)
				elseif meeting.T > length - 0.5 then
					walkTo = if toThisSide or not meeting.OtherEnds then length - half else length + half + SIDEWALK
				elseif toThisSide then
					table.insert(cuts, { meeting.T - half, meeting.T + half })
				end
			end
			table.sort(cuts, function(a, b)
				return a[1] < b[1]
			end)
			local pieces: { { number } } = {}
			local start = walkFrom
			for _, cut in cuts do
				if cut[1] > start then
					table.insert(pieces, { start, math.min(cut[1], walkTo) })
				end
				start = math.max(start, cut[2])
			end
			if walkTo > start then
				table.insert(pieces, { start, walkTo })
			end
			for _, piece in pieces do
				local pieceLength = piece[2] - piece[1]
				if pieceLength > 0.5 then
					part(parent, {
						Name = "Sidewalk",
						Size = Vector3.new(SIDEWALK, 0.5, pieceLength),
						CFrame = frameAt((piece[1] + piece[2]) / 2, s * (road.Width / 2 + SIDEWALK / 2), 0.05),
						Color = C.Sidewalk,
					})
					-- Lampposts along it, staggered between the two sides
					local first = piece[1] + (if s < 0 then 8 else 28)
					for t = first, piece[2] - 6, 40 do
						local spot = road.A + direction * t + side * s * (road.Width / 2 + 1.6)
						local onOtherRoad = false
						for _, other in roads do
							if other ~= road and onAnyRoad({ other }, spot, 1) then
								onOtherRoad = true
							end
						end
						if not onOtherRoad then
							lamppost(parent, spot)
						end
					end
				end
			end
		end
	end
end

-- A raised grassy block with brick-red sides (the stepped terraces around the hub)
local function terrace(parent: Instance, min: Vector3, max: Vector3)
	local size = max - min
	local center = (min + max) / 2
	box(parent, "TerraceSide", center - Vector3.new(0, 0.5, 0), size - Vector3.new(0, 1, 0), C.Brick)
	box(
		parent,
		"TerraceTop",
		Vector3.new(center.X, max.Y - 0.5, center.Z),
		Vector3.new(size.X + 0.4, 1, size.Z + 0.4),
		C.GrassTop
	)
end

---------------------------------------------------------------------------------------------------
-- The hub

local function buildHub(parent: Instance, layout: Layout)
	local folder = Instance.new("Folder")
	folder.Name = "Hub"
	folder.Parent = parent
	local min, max = layout.PlazaMin, layout.PlazaMax

	-- (The ring road around the plaza is part of the street grid, see buildRoads)
	local ring = RING
	local roadWidth = RING_WIDTH
	local ringMax = Vector3.new(max.X + ring, 0, max.Z + ring)
	crosswalk(folder, Vector3.new(0, 0, ringMax.Z), Vector3.xAxis, roadWidth) -- toward the beach
	-- Grass verges between the plaza and the ring road's sidewalks (a touch lower than the sidewalks, so
	-- the two never flicker where they meet)
	local verge = ring - roadWidth / 2 - SIDEWALK
	for _, strip in
		{
			{ Vector3.new(0, 0, min.Z - verge / 2), Vector3.new(max.X - min.X + verge * 2, 0.44, verge) },
			{ Vector3.new(0, 0, max.Z + verge / 2), Vector3.new(max.X - min.X + verge * 2, 0.44, verge) },
			{ Vector3.new(min.X - verge / 2, 0, (min.Z + max.Z) / 2), Vector3.new(verge, 0.44, max.Z - min.Z) },
			{ Vector3.new(max.X + verge / 2, 0, (min.Z + max.Z) / 2), Vector3.new(verge, 0.44, max.Z - min.Z) },
		}
	do
		box(folder, "Verge", strip[1] + Vector3.new(0, 0.06, 0), strip[2], C.GrassTop)
	end

	-- Terraces outside the ring road (two steps), with gaps where the roads leave
	local out = ring + roadWidth / 2 + 6
	local steps = {
		-- west side
		{ Vector3.new(min.X - out - 26, 0, min.Z + 20), Vector3.new(min.X - out, 4, max.Z - 10) },
		{ Vector3.new(min.X - out - 40, 0, min.Z + 30), Vector3.new(min.X - out - 22, 9, max.Z - 20) },
		-- east side
		{ Vector3.new(max.X + out, 0, min.Z + 20), Vector3.new(max.X + out + 26, 4, max.Z - 10) },
		{ Vector3.new(max.X + out + 22, 0, min.Z + 30), Vector3.new(max.X + out + 40, 9, max.Z - 20) },
		-- south, behind the spawn (split for the beach road)
		{ Vector3.new(min.X + 10, 0, max.Z + out), Vector3.new(-14, 5, max.Z + out + 20) },
		{ Vector3.new(14, 0, max.Z + out), Vector3.new(max.X - 10, 5, max.Z + out + 20) },
	}
	for _, s in steps do
		terrace(folder, s[1], s[2])
		-- Trees and bushes on top
		local top = s[2].Y
		for i = 1, 4 do
			local x = s[1].X + (s[2].X - s[1].X) * (i - 0.5) / 4
			local z = s[1].Z + (s[2].Z - s[1].Z) * ((i * 37) % 10 + 0.5) / 10
			tree(folder, Vector3.new(x, top, z), 14 + (i % 3) * 3)
		end
	end

	-- Fountain in the middle of the plaza
	local fountainAt = Vector3.new(0, 0, (min.Z + max.Z) / 2 + 30)
	part(folder, {
		Name = "FountainBasin",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 22, 22),
		CFrame = CFrame.new(fountainAt + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = C.White,
	})
	part(folder, {
		Name = "FountainWater",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 19, 19),
		CFrame = CFrame.new(fountainAt + Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = C.Water,
		Material = Enum.Material.Glass,
		Transparency = 0.3,
		CanCollide = false,
	})
	box(folder, "FountainPillar", fountainAt + Vector3.new(0, 4, 0), Vector3.new(2.5, 6, 2.5), C.White)
	local spout = part(folder, {
		Name = "FountainTop",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(4, 4, 4),
		Position = fountainAt + Vector3.new(0, 7.5, 0),
		Color = C.Water,
		Material = Enum.Material.Glass,
		Transparency = 0.2,
	})
	local spray = Instance.new("ParticleEmitter")
	spray.Color = ColorSequence.new(Color3.fromRGB(200, 235, 255))
	spray.Size = NumberSequence.new(0.6, 0.1)
	spray.Speed = NumberRange.new(10, 14)
	spray.SpreadAngle = Vector2.new(25, 25)
	spray.Acceleration = Vector3.new(0, -35, 0)
	spray.Lifetime = NumberRange.new(0.8, 1.1)
	spray.Rate = 60
	spray.Transparency = NumberSequence.new(0.2, 0.9)
	spray.Parent = spout

	-- Lawn beds on the plaza: raised grass with a low hedge around it and a couple of small trees
	local function bed(center: Vector3, size: Vector2)
		box(folder, "Lawn", center + Vector3.new(0, 0.35, 0), Vector3.new(size.X, 0.7, size.Y), C.GrassTop)
		for _, edge in
			{
				{ Vector3.new(0, 0, -size.Y / 2), Vector3.new(size.X, 1.6, 1.4) },
				{ Vector3.new(0, 0, size.Y / 2), Vector3.new(size.X, 1.6, 1.4) },
				{ Vector3.new(-size.X / 2, 0, 0), Vector3.new(1.4, 1.6, size.Y) },
				{ Vector3.new(size.X / 2, 0, 0), Vector3.new(1.4, 1.6, size.Y) },
			}
		do
			box(folder, "Hedge", center + edge[1] + Vector3.new(0, 0.8, 0), edge[2], C.Hedge)
		end
		tree(folder, center + Vector3.new(-size.X / 4, 0.7, 0), 12)
		tree(folder, center + Vector3.new(size.X / 4, 0.7, 2), 10)
	end
	bed(Vector3.new(-58, 0, 62), Vector2.new(26, 22))
	bed(Vector3.new(58, 0, 62), Vector2.new(26, 22))
	bed(Vector3.new(-26, 0, -50), Vector2.new(20, 12))
	bed(Vector3.new(26, 0, -50), Vector2.new(20, 12))

	-- Plaza lampposts around the edge
	for _, x in { min.X + 6, max.X - 6 } do
		for z = min.Z + 20, max.Z - 10, 30 do
			if not (x < 0 and z > 0 and z < 45) then -- (the leaderboards stand there on the west side)
				lamppost(folder, Vector3.new(x, 0, z))
			end
		end
	end

	-- Info boards near the spawn (big, readable, like the boards in popular simulators)
	local function board(name: string, at: Vector3, facing: Vector3, size: Vector2, color: Color3): BasePart
		-- The board faces `facing`; its posts hang off its own left and right edges (so they line up at any angle)
		local center = at + Vector3.new(0, size.Y / 2 + 2, 0)
		local faceCFrame = CFrame.lookAt(center, center + Vector3.new(facing.X, 0, facing.Z))
		local face = part(folder, {
			Name = name,
			Size = Vector3.new(size.X, size.Y, 0.6),
			CFrame = faceCFrame,
			Color = color,
		})
		local postHeight = size.Y + 2.4
		for _, side in { -1, 1 } do
			local edge = faceCFrame * CFrame.new(side * (size.X / 2 + 0.4), 0, 0.2)
			part(folder, {
				Name = name .. "Post",
				Size = Vector3.new(0.8, postHeight, 0.8),
				CFrame = CFrame.new(edge.Position.X, postHeight / 2, edge.Position.Z) * faceCFrame.Rotation,
				Color = C.Dark,
			})
		end
		return face
	end

	-- Boards stand a little ahead of the spawn, on both sides, facing back toward it
	local howTo = board(
		"HowToPlayBoard",
		Vector3.new(-34, 0, max.Z - 42),
		Vector3.new(0.35, 0, 1).Unit,
		Vector2.new(16, 10),
		C.Dark
	)
	do
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0
		local list = Instance.new("TextLabel")
		list.Size = UDim2.fromScale(1, 1)
		list.BackgroundColor3 = Color3.fromRGB(35, 40, 70)
		list.Font = Enum.Font.FredokaOne
		list.TextScaled = true
		list.TextColor3 = Color3.new(1, 1, 1)
		list.TextXAlignment = Enum.TextXAlignment.Left
		list.RichText = true
		list.Text = '<font color="#FFD23C">HOW TO MAIL AN ANIMAL</font>\n'
			.. "1. Pick an animal at the ANIMAL PEN\n"
			.. "2. CATCH it: chase it and hold E\n"
			.. "3. BOX it: rub the ♥ spots, tape the seams\n"
			.. "4. MAIL it at Gruff's MAIL CHUTE"
		list.Parent = gui
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0.04, 0)
		padding.PaddingRight = UDim.new(0.04, 0)
		padding.PaddingTop = UDim.new(0.05, 0)
		padding.PaddingBottom = UDim.new(0.05, 0)
		padding.Parent = list
		gui.Parent = howTo
	end

	local paycheck = board(
		"PaycheckBoard",
		Vector3.new(34, 0, max.Z - 42),
		Vector3.new(-0.35, 0, 1).Unit,
		Vector2.new(14, 6),
		C.Dark
	)
	signText(paycheck, Enum.NormalId.Front, "DAILY PAYCHECK", C.Gold, "New paycheck in ...", Color3.fromRGB(35, 70, 40))
	-- Count down to the next paycheck (a new day, UTC) once a second
	task.spawn(function()
		local gui = paycheck:FindFirstChildOfClass("SurfaceGui")
		local frame = gui and gui:FindFirstChildOfClass("Frame")
		local sub = frame and frame:FindFirstChild("Subtitle") :: TextLabel?
		while paycheck.Parent do
			local left = 86400 - os.time() % 86400
			if sub then
				sub.Text = string.format("Next one in %dh %02dm %02ds", left // 3600, (left % 3600) // 60, left % 60)
			end
			task.wait(1)
		end
	end)

	local group =
		board("GroupBoard", Vector3.new(62, 0, max.Z - 62), Vector3.new(-0.6, 0, 1).Unit, Vector2.new(12, 6), C.Dark)
	signText(
		group,
		Enum.NormalId.Front,
		"👍 LIKE THE GAME",
		Color3.fromRGB(120, 255, 140),
		"⭐ Join the group: +10% coins",
		Color3.fromRGB(40, 45, 80)
	)

	-- The big title over the Post Office
	local title = part(folder, {
		Name = "TitleSign",
		Size = Vector3.new(44, 10, 1),
		CFrame = CFrame.new(0, 26, min.Z + 14),
		Transparency = 1,
		CanCollide = false,
	})
	signText(title, Enum.NormalId.Back, "📦 MAIL A TIGER 🐯", Color3.fromRGB(255, 200, 60), nil, nil)
end

---------------------------------------------------------------------------------------------------
-- Zones: paths, entrance banners, themes

local function banner(parent: Instance, zone: Zone)
	local gate = zone.Gate
	local width = 30
	box(
		parent,
		"BannerPole",
		gate + Vector3.new(-width / 2 - 1, 8, 4),
		Vector3.new(2, 16, 2),
		C.Dark,
		Enum.Material.Metal
	)
	box(
		parent,
		"BannerPole",
		gate + Vector3.new(width / 2 + 1, 8, 4),
		Vector3.new(2, 16, 2),
		C.Dark,
		Enum.Material.Metal
	)
	local sign = part(parent, {
		Name = "ZoneBanner",
		Size = Vector3.new(width, 7, 1),
		Position = gate + Vector3.new(0, 16, 4),
		Color = zone.Color:Lerp(Color3.new(1, 1, 1), 0.15),
		Material = Enum.Material.SmoothPlastic,
	})
	-- Front (+Z side, toward the town) and back both get the name
	local tiers = zone.Name
	signText(sign, Enum.NormalId.Back, `{zone.Icon} {string.upper(tiers)}`, Color3.new(1, 1, 1), nil, zone.Color)
	signText(sign, Enum.NormalId.Front, `{zone.Icon} {string.upper(tiers)}`, Color3.new(1, 1, 1), nil, zone.Color)
end

local function backyardTheme(parent: Instance, zone: Zone)
	local c = zone.Center
	local back = c.Z - zone.HalfZ - 22
	-- A suburban house behind the yard
	local houseAt = Vector3.new(c.X, 0, back - 10)
	box(
		parent,
		"House",
		houseAt + Vector3.new(0, 9, 0),
		Vector3.new(40, 18, 22),
		Color3.fromRGB(235, 220, 190),
		Enum.Material.SmoothPlastic
	)
	for _, side in { -1, 1 } do
		part(parent, {
			ClassName = "WedgePart",
			Name = "HouseRoof",
			Size = Vector3.new(42, 10, 12),
			CFrame = CFrame.new(houseAt + Vector3.new(0, 23, side * 6))
				* CFrame.Angles(0, if side == 1 then 0 else math.pi, 0),
			Color = C.Roof,
			Material = Enum.Material.Slate,
		})
	end
	box(parent, "Door", houseAt + Vector3.new(0, 4.5, 11.1), Vector3.new(5, 9, 0.4), C.Wood, Enum.Material.Wood)
	for _, x in { -13, -6, 6, 13 } do
		box(parent, "Window", houseAt + Vector3.new(x, 11, 11.1), Vector3.new(4, 4, 0.3), C.Glass, Enum.Material.Glass)
	end
	-- Trees around the yard
	for _, t in { { -48, -10 }, { -52, 20 }, { 48, -12 }, { 52, 18 }, { -40, -40 }, { 40, -42 } } do
		tree(parent, Vector3.new(c.X + t[1], 0, c.Z + t[2]), 18)
	end
end

local function barnTheme(parent: Instance, zone: Zone)
	local c = zone.Center
	-- A silo next to the barn
	local siloAt = Vector3.new(c.X - zone.HalfX - 14, 0, c.Z - zone.HalfZ - 12) -- west side, away from the paths
	part(parent, {
		Name = "Silo",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(30, 12, 12),
		CFrame = CFrame.new(siloAt + Vector3.new(0, 15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(190, 60, 50),
		Material = Enum.Material.CorrodedMetal,
	})
	part(parent, {
		Name = "SiloTop",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(12, 12, 12),
		Position = siloAt + Vector3.new(0, 30, 0),
		Color = C.Stone,
		Material = Enum.Material.Metal,
	})
	-- Crop fields on both sides
	for _, side in { -1 } do -- (only the west side: the Ice Rink path runs past the east side)
		local fieldX = c.X + side * (zone.HalfX + 26)
		for row = -3, 3 do
			box(
				parent,
				"CropRow",
				Vector3.new(fieldX, 0.6, c.Z + row * 6),
				Vector3.new(16, 1.2, 2.4),
				Color3.fromRGB(110, 170, 60),
				Enum.Material.Grass
			)
		end
	end
	-- Loose hay around the farm
	for _, h in { { -40, 30 }, { 42, 32 }, { -44, -5 } } do
		box(
			parent,
			"Hay",
			Vector3.new(c.X + h[1], 2, c.Z + h[2]),
			Vector3.new(5, 4, 5),
			Color3.fromRGB(230, 200, 100),
			Enum.Material.Fabric
		)
	end
end

local function jungleTheme(parent: Instance, zone: Zone)
	local c = zone.Center
	local back = c.Z - zone.HalfZ - 26
	-- A rock cliff with a waterfall behind the jungle
	box(
		parent,
		"Cliff",
		Vector3.new(c.X, 20, back - 8),
		Vector3.new(zone.HalfX * 2 + 60, 40, 16),
		Color3.fromRGB(150, 150, 162)
	)
	box(parent, "CliffTop", Vector3.new(c.X, 40.6, back - 8), Vector3.new(zone.HalfX * 2 + 61, 1.2, 17), C.GrassTop)
	for index, x in { -40, -15, 18, 42 } do
		tree(parent, Vector3.new(c.X + x, 41.2, back - 8 + (index % 2) * 3), 16)
	end
	part(parent, {
		Name = "Waterfall",
		Size = Vector3.new(14, 40, 1),
		Position = Vector3.new(c.X, 20, back + 0.6),
		Color = C.Water,
		Material = Enum.Material.Glass,
		Transparency = 0.25,
		CanCollide = false,
	})
	part(parent, {
		Name = "Pool",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 22, 22),
		CFrame = CFrame.new(c.X, 0.3, back + 8) * CFrame.Angles(0, 0, math.rad(90)),
		Color = C.Water,
		Material = Enum.Material.Glass,
		Transparency = 0.2,
		CanCollide = false,
	})
	local mist = Instance.new("ParticleEmitter")
	mist.Color = ColorSequence.new(Color3.new(1, 1, 1))
	mist.Size = NumberSequence.new(3, 6)
	mist.Transparency = NumberSequence.new(0.6, 1)
	mist.Speed = NumberRange.new(2, 5)
	mist.Lifetime = NumberRange.new(1.5, 2.5)
	mist.Rate = 12
	mist.Parent = parent:FindFirstChild("Pool")
	-- Giant trees around the edges
	-- (none on the near-west side: the Rooftop path runs past there)
	for _, t in { { 58, -18 }, { 62, 18 }, { 34, 40 }, { -30, 40 }, { 60, -38 }, { -62, -38 } } do
		tree(parent, Vector3.new(c.X + t[1], 0, c.Z + t[2]), 30, Color3.fromRGB(40, 140, 60))
	end
end

-- The street grid being built (set in Scenery.Build), so zone themes can keep their trees off the roads
local currentRoads: { Road } = {}

local function winterTheme(parent: Instance, zone: Zone)
	local c = zone.Center
	for i = 1, 16 do
		local angle = i / 16 * math.pi * 2
		local rx, rz = zone.HalfX + 22 + (i % 3) * 8, zone.HalfZ + 22 + (i % 2) * 10
		local at = Vector3.new(c.X + math.cos(angle) * rx, 0, c.Z + math.sin(angle) * rz)
		local clear = at.Z < c.Z + zone.HalfZ + 6 or math.abs(at.X - c.X) > 20 -- keep the gate clear
		if clear and not onAnyRoad(currentRoads, at, 12) then -- (and the branches off the sidewalks)
			-- On a snow hill, the pine stands on the hill's surface instead of poking out of it
			for _, h in SNOW_HILLS do
				local dx, dz = at.X - (c.X + h[1]), at.Z - (c.Z + h[2])
				local d2 = dx * dx + dz * dz
				if d2 < h[3] * h[3] then
					at = Vector3.new(at.X, math.max(at.Y, -h[3] * 0.45 + math.sqrt(h[3] * h[3] - d2) - 0.5), at.Z)
				end
			end
			pine(parent, at, 16 + (i % 4) * 4, true)
		end
	end
	-- A frozen lake shimmer and a snow sign
	box(
		parent,
		"FrozenLake",
		Vector3.new(c.X - zone.HalfX - 30, 0.1, c.Z + 10),
		Vector3.new(26, 0.2, 40),
		Color3.fromRGB(190, 225, 245),
		Enum.Material.Glacier
	)
	local snow = Instance.new("ParticleEmitter")
	snow.Color = ColorSequence.new(Color3.new(1, 1, 1))
	snow.Size = NumberSequence.new(0.4)
	snow.Speed = NumberRange.new(4, 6)
	snow.SpreadAngle = Vector2.new(60, 60)
	snow.EmissionDirection = Enum.NormalId.Bottom
	snow.Lifetime = NumberRange.new(8, 10)
	snow.Rate = 80
	local sky = part(parent, {
		Name = "SnowCloud",
		Size = Vector3.new(zone.HalfX * 2 + 80, 1, zone.HalfZ * 2 + 80),
		Position = Vector3.new(c.X, 70, c.Z),
		Transparency = 1,
		CanCollide = false,
	})
	snow.Parent = sky
end

local function cityTheme(parent: Instance, zone: Zone)
	local c = zone.Center
	local buildings = {
		{ -58, -40, 20, 70 },
		{ -60, 0, 18, 50 },
		{ -56, 36, 20, 42 },
		{ 58, -38, 22, 80 },
		{ 60, 4, 18, 55 },
		{ 56, 38, 18, 38 },
		{ -20, -62, 24, 90 },
		{ 22, -60, 20, 64 },
	}
	local palette = {
		Color3.fromRGB(120, 130, 150),
		Color3.fromRGB(170, 150, 130),
		Color3.fromRGB(90, 110, 140),
		Color3.fromRGB(200, 190, 170),
	}
	for index, b in buildings do
		local at = Vector3.new(c.X + b[1], 0, c.Z + b[2])
		local size, height = b[3], b[4]
		box(
			parent,
			"Skyscraper",
			at + Vector3.new(0, height / 2, 0),
			Vector3.new(size, height, size),
			palette[index % #palette + 1],
			Enum.Material.Concrete
		)
		-- Window bands
		for y = 6, height - 4, 7 do
			box(
				parent,
				"Windows",
				at + Vector3.new(0, y, 0),
				Vector3.new(size + 0.3, 2.2, size + 0.3),
				C.Glass,
				Enum.Material.Glass
			)
		end
		box(
			parent,
			"RoofEdge",
			at + Vector3.new(0, height + 0.5, 0),
			Vector3.new(size + 1, 1, size + 1),
			C.Dark,
			Enum.Material.Metal
		)
	end
	-- Window bands on the rooftop arena's own building too
	for y = 6, zone.FloorY - 4, 7 do
		box(
			parent,
			"Windows",
			Vector3.new(c.X, y, c.Z),
			Vector3.new(zone.HalfX * 2 + 0.3, 2.2, zone.HalfZ * 2 + 0.3),
			C.Glass,
			Enum.Material.Glass
		)
	end
	-- Streets (dark strips) around the block
	for _, s in
		{
			{ 0, zone.HalfZ + 12, 140, 10 },
			{ 0, -zone.HalfZ - 12, 140, 10 },
			{ -zone.HalfX - 12, 0, 10, 120 },
			{ zone.HalfX + 12, 0, 10, 120 },
		}
	do
		box(
			parent,
			"Street",
			Vector3.new(c.X + s[1], 0.08, c.Z + s[2]),
			Vector3.new(s[3], 0.16, s[4]),
			Color3.fromRGB(55, 55, 60),
			Enum.Material.Asphalt
		)
	end
end

local THEMES: { [string]: (Instance, Zone) -> () } = {
	Backyard = backyardTheme,
	Barn = barnTheme,
	Jungle = jungleTheme,
	IceRink = winterTheme,
	Rooftop = cityTheme,
}

-- Scatters trees, rocks and flower patches across the open land between the town and the zones, keeping clear
-- of the plaza, the zones and the paths. Uses a fixed random seed, so every server looks the same.
local function scatter(parent: Instance, layout: Layout, roads: { Road })
	local random = Random.new(20260930)
	local function nearPath(p: Vector3): boolean
		return onAnyRoad(roads, p, 12) -- (room for a big tree's branches between it and the road)
	end
	local function blocked(p: Vector3): boolean
		local min, max = layout.PlazaMin, layout.PlazaMax
		if p.X > min.X - 80 and p.X < max.X + 80 and p.Z > min.Z - 40 and p.Z < max.Z + 70 then
			return true -- the plaza, its ring road and terraces
		end
		for _, zone in layout.Zones do
			local pad = if zone.Id == "Rooftop" then 75 else 45
			if
				math.abs(p.X - zone.Center.X) < zone.HalfX + pad
				and math.abs(p.Z - zone.Center.Z) < zone.HalfZ + pad
			then
				return true
			end
		end
		return nearPath(p) or onSnowHill(layout, p, 4)
	end
	local flowerColors = {
		Color3.fromRGB(255, 120, 150),
		Color3.fromRGB(255, 220, 90),
		Color3.fromRGB(170, 130, 255),
		Color3.fromRGB(255, 255, 255),
	}
	local placed = 0
	for _ = 1, 900 do
		if placed >= 170 then
			break
		end
		local p = Vector3.new(random:NextNumber(-285, 285), 0, random:NextNumber(-455, 155))
		if not blocked(p) then
			placed += 1
			local roll = random:NextNumber()
			if roll < 0.55 then
				tree(parent, p, random:NextNumber(12, 24))
			elseif roll < 0.7 then
				pine(parent, p, random:NextNumber(14, 22), p.X < -120 and p.Z < -250)
			elseif roll < 0.85 then
				local size = random:NextNumber(3, 7)
				part(parent, {
					Name = "Boulder",
					Size = Vector3.new(size * 1.3, size, size),
					CFrame = CFrame.new(p + Vector3.new(0, size * 0.35, 0))
						* CFrame.Angles(0, random:NextNumber(0, 6.28), random:NextNumber(-0.3, 0.3)),
					Color = Color3.fromRGB(130, 130, 125),
					Material = Enum.Material.Slate,
				})
			else
				local color = flowerColors[random:NextInteger(1, #flowerColors)]
				for _ = 1, 6 do
					part(parent, {
						Name = "Flower",
						Shape = Enum.PartType.Ball,
						Size = Vector3.new(1.1, 1.1, 1.1),
						Position = p + Vector3.new(random:NextNumber(-3, 3), 0.6, random:NextNumber(-3, 3)),
						Color = color,
						Material = Enum.Material.SmoothPlastic,
						CanCollide = false,
					})
				end
			end
		end
	end
end

-- A palm tree: a gently curved trunk and a crown of drooping fronds
local function palm(parent: Instance, at: Vector3, height: number, lean: number)
	local h = height
	local top = at
	for i = 0, 3 do
		local segment = h / 4
		local tilt = lean * (i + 1) * 0.08
		local cf = CFrame.new(top) * CFrame.Angles(0, 0, tilt) * CFrame.new(0, segment / 2, 0)
		part(parent, {
			Name = "PalmTrunk",
			Size = Vector3.new(1.3 - i * 0.12, segment + 0.3, 1.3 - i * 0.12),
			CFrame = cf,
			Color = Color3.fromRGB(176, 128, 82),
		})
		top = (cf * CFrame.new(0, segment / 2, 0)).Position
	end
	for i = 0, 5 do
		local angle = i / 6 * math.pi * 2
		part(parent, {
			Name = "Frond",
			Size = Vector3.new(1.6, 0.3, 8),
			CFrame = CFrame.new(top)
				* CFrame.Angles(0, angle, 0)
				* CFrame.Angles(math.rad(-20), 0, 0)
				* CFrame.new(0, 0, -3.6),
			Color = Color3.fromRGB(86, 190, 80),
			CanCollide = false,
		})
	end
end

-- A wooden signpost where the paths leave town, with an arrow sign for each zone
local function signpost(parent: Instance, at: Vector3, layout: Layout)
	box(parent, "SignpostPole", at + Vector3.new(0, 6, 0), Vector3.new(1, 12, 1), C.Wood, Enum.Material.Wood)
	for index, zone in layout.Zones do
		local direction = Vector3.new(zone.Gate.X - at.X, 0, zone.Gate.Z - at.Z).Unit
		local arrow = part(parent, {
			Name = "SignArrow",
			Size = Vector3.new(9, 1.6, 0.4),
			CFrame = CFrame.lookAt(
				at + Vector3.new(0, 12 - index * 1.9, 0),
				at + Vector3.new(0, 12 - index * 1.9, 0) + direction
			) * CFrame.Angles(0, math.rad(90), 0) * CFrame.new(4, 0, 0),
			Color = zone.Color,
			Material = Enum.Material.Wood,
		})
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local gui = Instance.new("SurfaceGui")
			gui.Face = face
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 40
			gui.LightInfluence = 0
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.LuckiestGuy
			label.TextScaled = true
			label.TextColor3 = Color3.new(1, 1, 1)
			label.TextStrokeTransparency = 0
			label.TextWrapped = false
			label.Text = `{zone.Icon} {string.upper(zone.Name)}`
			label.Parent = gui
			gui.Parent = arrow
		end
	end
end

function Scenery.Build(parent: Instance, layout: Layout)
	local folder = Instance.new("Folder")
	folder.Name = "Scenery"
	folder.Parent = parent

	buildTerrain(layout)
	buildGround(folder, layout)
	buildHub(folder, layout)
	-- Palm trees along the south beach
	local beach = Instance.new("Folder")
	beach.Name = "Beach"
	beach.Parent = folder
	for i = -5, 5 do
		if math.abs(i) > 0 then
			palm(
				beach,
				Vector3.new(i * 48 + (i % 2) * 9, -0.8, 184 + (i % 3) * 5),
				16 + (i % 3) * 3,
				if i % 2 == 0 then 1 else -1
			)
		end
	end
	local wild = Instance.new("Folder")
	wild.Name = "Wilderness"
	wild.Parent = folder
	local roads = roadNetwork(layout)
	currentRoads = roads
	scatter(wild, layout, roads)
	signpost(folder, Vector3.new(26, 0, layout.PlazaMin.Z + 6), layout)

	local roadFolder = Instance.new("Folder")
	roadFolder.Name = "Roads"
	roadFolder.Parent = folder
	buildRoads(roadFolder, roads)
	for _, zone in layout.Zones do
		local zoneFolder = Instance.new("Folder")
		zoneFolder.Name = zone.Id
		zoneFolder.Parent = folder
		banner(zoneFolder, zone)
		local theme = THEMES[zone.Id]
		if theme then
			theme(zoneFolder, zone)
		end
	end

	-- A sky with a bit of drama (only if you haven't added your own)
	if not Lighting:FindFirstChildOfClass("Sky") then
		local sky = Instance.new("Sky")
		sky.SunAngularSize = 14
		sky.Parent = Lighting
	end
end

return Scenery
