--!strict
-- The town island: a round paved plaza with the wishing fountain in the middle, a sunburst of paving lines
-- and rings, benches, flower beds, a ring of lamps and low hedges, paths out to every bridge (each with a
-- stone arch naming where it goes), info boards by the spawn, the big title over the Post Office, and a
-- green ring of trees, cottages and flowers between the plaza and the cliffs.
-- (The Post Office, counters, shop and leaderboards are gameplay pieces: MapBuilder places those, and tells
-- us where they are in layout.Keep so nothing grows through them.)

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Kit)
local Islands = require(script.Parent.Islands)

local C = Kit.C
local part = Kit.part
local box = Kit.box
local World = Config.World

local Town = {}

export type Destination = {
	Id: string,
	Name: string, -- e.g. "🐔 BARN"
	Subtitle: string, -- e.g. "LEVEL 4"
	Color: Color3,
	From: Vector3, -- the bridge's start on the town island
	To: Vector3,
}

-- Distance from p to the segment a-b (flat)
local function segmentDistance(p: Vector3, a: Vector3, b: Vector3): number
	local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local ap = Vector3.new(p.X - a.X, 0, p.Z - a.Z)
	local t = math.clamp(ap:Dot(ab) / math.max(ab:Dot(ab), 0.001), 0, 1)
	return (ap - ab * t).Magnitude
end
Town.SegmentDistance = segmentDistance

-- A stone arch over a path with a sign naming where it goes (both sides)
function Town.Arch(parent: Instance, at: Vector3, along: Vector3, title: string, subtitle: string, color: Color3)
	local cf = CFrame.lookAt(at, at + Vector3.new(along.X, 0, along.Z))
	local stone = Color3.fromRGB(214, 206, 192)
	for _, side in { -1, 1 } do
		local x = side * (World.BridgeWidth / 2 + 2.5)
		part(parent, {
			Name = "ArchPillar",
			Size = Vector3.new(2.6, 13, 2.6),
			CFrame = cf * CFrame.new(x, 6.5, 0),
			Color = stone,
		})
		part(parent, {
			Name = "ArchPillarFoot",
			Size = Vector3.new(3.4, 1.4, 3.4),
			CFrame = cf * CFrame.new(x, 0.7, 0),
			Color = C.PavingDark,
		})
		part(parent, {
			Name = "ArchPillarCap",
			Size = Vector3.new(3.4, 1, 3.4),
			CFrame = cf * CFrame.new(x, 13.5, 0),
			Color = C.PavingDark,
		})
		Kit.ball(parent, "ArchKnob", (cf * CFrame.new(x, 14.6, 0)).Position, 1.6, C.Gold)
	end
	local sign = part(parent, {
		Name = "ArchSign",
		Size = Vector3.new(World.BridgeWidth + 3, 4.6, 0.8),
		CFrame = cf * CFrame.new(0, 11.4, 0),
		Color = color,
	})
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		Kit.signText(sign, face, title, Color3.new(1, 1, 1), if subtitle ~= "" then subtitle else nil, color)
	end
	part(parent, {
		Name = "ArchBeam",
		Size = Vector3.new(World.BridgeWidth + 7, 1, 1.4),
		CFrame = cf * CFrame.new(0, 14, 0),
		Color = C.DarkWood,
	})
end

local function fountain(folder: Instance)
	-- Fountain in the middle of the plaza: a warm sandstone wishing fountain (it stands out on the white
	-- tiles), with a teal pool full of coins, two tiers that spill water curtains into each other, arcing
	-- jets from the rim, and a gold parcel with a red ribbon on top (this is a post office, after all).
	local fountainAt = Vector3.zero
	local SANDSTONE = Color3.fromRGB(232, 186, 132)
	local SANDSTONE_DARK = Color3.fromRGB(205, 152, 100)
	local POOL = Color3.fromRGB(40, 150, 190)
	local WATER = Color3.fromRGB(110, 210, 255)
	local function disc(
		name: string,
		y: number,
		diameter: number,
		height: number,
		color: Color3,
		props: { [string]: any }?
	): BasePart
		local p = part(folder, {
			Name = name,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height, diameter, diameter),
			CFrame = CFrame.new(fountainAt + Vector3.new(0, y + height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = color,
		})
		for key, value in (props or {}) :: { [string]: any } do
			(p :: any)[key] = value
		end
		return p
	end
	local function water(name: string, y: number, diameter: number, height: number): BasePart
		return disc(name, y, diameter, height, WATER, {
			Material = Enum.Material.Glass,
			Transparency = 0.35,
			Reflectance = 0.15,
			CanCollide = false,
			CastShadow = false,
		})
	end

	-- The step around it, the pool floor, and the rim wall (a ring of blocks, so the pool inside is open)
	local RIM_R, RIM_TOP, FLOOR = 11, 3.4, 1.0
	disc("FountainStep", 0, 26, 0.6, SANDSTONE_DARK)
	disc("FountainBasin", 0.6, 22.4, FLOOR - 0.6, SANDSTONE_DARK)
	disc("FountainPoolFloor", FLOOR, 21.6, 0.2, POOL)
	local SEGMENTS = 28
	for i = 1, SEGMENTS do
		local angle = (i / SEGMENTS) * math.pi * 2
		local around = CFrame.new(fountainAt) * CFrame.Angles(0, angle, 0)
		local width = 2 * math.pi * RIM_R / SEGMENTS + 0.35
		part(folder, {
			Name = "FountainRim",
			Size = Vector3.new(width, RIM_TOP - 0.6, 1.4),
			CFrame = around * CFrame.new(0, 0.6 + (RIM_TOP - 0.6) / 2, -RIM_R),
			Color = SANDSTONE,
		})
		-- A white cap along the top, a little wider than the wall
		part(folder, {
			Name = "FountainRimCap",
			Size = Vector3.new(width + 0.1, 0.5, 2),
			CFrame = around * CFrame.new(0, RIM_TOP + 0.25, -RIM_R),
			Color = C.White,
		})
	end
	local poolWater = water("FountainWater", FLOOR + 0.2, 21.4, RIM_TOP - 0.6 - FLOOR - 0.2)

	-- Wishes: coins on the bottom of the pool
	local random = Random.new(47)
	for _ = 1, 18 do
		local r = random:NextNumber(3.5, 9.5)
		local a = random:NextNumber(0, math.pi * 2)
		part(folder, {
			Name = "FountainCoin",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.15, 0.9, 0.9),
			CFrame = CFrame.new(fountainAt + Vector3.new(math.cos(a) * r, FLOOR + 0.28, math.sin(a) * r))
				* CFrame.Angles(random:NextNumber(-0.25, 0.25), random:NextNumber(0, 6), math.rad(90)),
			Color = C.Gold,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
	end

	-- Lower column and the middle bowl, full to the brim (the water sits just above a thin white lip, so
	-- the two never fight over the same surface)
	disc("FountainPillar", FLOOR, 3.2, 6.2 - FLOOR, SANDSTONE)
	disc("FountainBand", 3.2, 3.6, 0.4, C.Gold)
	disc("FountainBowlFoot", 5.6, 5, 0.6, SANDSTONE_DARK)
	disc("FountainBowl", 6.2, 11, 1.1, SANDSTONE)
	disc("FountainBowlLip", 7.3, 11.4, 0.1, C.White)
	water("FountainBowlWater", 7.3, 10.4, 0.25)

	-- Upper column and the top bowl
	disc("FountainUpperPillar", 7.3, 1.8, 2.6, SANDSTONE)
	disc("FountainUpperBand", 8.4, 2.2, 0.3, C.Gold)
	disc("FountainTopBowl", 9.9, 5.2, 0.8, SANDSTONE)
	disc("FountainTopLip", 10.7, 5.5, 0.1, C.White)
	water("FountainTopWater", 10.7, 4.8, 0.2)

	-- The gold parcel on top (sitting in the top bowl's water), tied with a red ribbon and bow
	local parcelAt = fountainAt + Vector3.new(0, 11.9, 0)
	local parcelTurn = CFrame.Angles(0, math.rad(20), 0)
	local RIBBON = Color3.fromRGB(230, 60, 70)
	part(folder, {
		Name = "FountainParcel",
		Size = Vector3.new(2.4, 2, 2.4),
		CFrame = CFrame.new(parcelAt) * parcelTurn,
		Color = C.Gold,
	})
	for _, size in { Vector3.new(2.5, 2.1, 0.45), Vector3.new(0.45, 2.1, 2.5) } do
		part(folder, {
			Name = "FountainRibbon",
			Size = size,
			CFrame = CFrame.new(parcelAt) * parcelTurn,
			Color = RIBBON,
		})
	end
	for _, side in { -1, 1 } do
		part(folder, {
			Name = "FountainBow",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.9, 0.9, 0.9),
			CFrame = CFrame.new(parcelAt) * parcelTurn * CFrame.new(side * 0.45, 1.3, 0),
			Color = RIBBON,
		})
	end

	-- Spray: a jet out of the top, arcing jets from four gold spouts on the rim, and mist on the pool
	local function emitter(host: BasePart, props: { [string]: any })
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(Color3.fromRGB(215, 240, 255))
		e.Transparency = NumberSequence.new(0.15, 0.9)
		e.LightEmission = 0.2
		for key, value in props do
			(e :: any)[key] = value
		end
		e.Parent = host
	end
	local spout = part(folder, {
		Name = "FountainTop",
		Size = Vector3.new(0.6, 0.6, 0.6),
		Position = parcelAt + Vector3.new(0, 1.9, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	emitter(spout, {
		Size = NumberSequence.new(0.55, 0.15),
		Speed = NumberRange.new(9, 12),
		SpreadAngle = Vector2.new(14, 14),
		Acceleration = Vector3.new(0, -30, 0),
		Lifetime = NumberRange.new(0.9, 1.2),
		Rate = 70,
	})
	for i = 1, 4 do
		local angle = (i / 4) * math.pi * 2 + math.pi / 4
		local at = fountainAt + Vector3.new(math.cos(angle) * RIM_R, RIM_TOP + 0.6, math.sin(angle) * RIM_R)
		part(folder, {
			Name = "FountainSpout",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.1, 1.1, 1.1),
			Position = at,
			Color = C.Gold,
		})
		-- Aimed inward and up; gravity bends it into an arc that lands near the column
		local inward = (Vector3.new(fountainAt.X, at.Y, fountainAt.Z) - at).Unit
		local nozzle = part(folder, {
			Name = "FountainNozzle",
			Size = Vector3.new(0.3, 0.3, 0.3),
			CFrame = CFrame.lookAt(at, at + inward + Vector3.new(0, 0.9, 0)),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		})
		emitter(nozzle, {
			EmissionDirection = Enum.NormalId.Front,
			Size = NumberSequence.new(0.35, 0.12),
			Speed = NumberRange.new(13, 14),
			SpreadAngle = Vector2.new(3, 3),
			Acceleration = Vector3.new(0, -30, 0),
			Lifetime = NumberRange.new(0.66, 0.7), -- (lands just inside the middle bowl's curtain)
			Rate = 40,
		})
	end
	emitter(poolWater, {
		Size = NumberSequence.new(0.8, 1.6),
		Speed = NumberRange.new(0.5, 1.5),
		Lifetime = NumberRange.new(0.8, 1.4),
		Transparency = NumberSequence.new(0.6, 1),
		Rate = 12,
		LightEmission = 0,
	})
	-- Water spilling over each bowl's edge: droplets thrown outward from a ring around the lip, falling
	-- into the bowl or pool below
	local function spill(name: string, y: number, diameter: number, fall: number, rate: number)
		local lipRing = part(folder, {
			Name = name,
			Size = Vector3.new(diameter, 0.1, diameter),
			Position = fountainAt + Vector3.new(0, y, 0),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		})
		local seconds = math.sqrt(2 * fall / 30)
		emitter(lipRing, {
			Shape = Enum.ParticleEmitterShape.Disc,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
			Size = NumberSequence.new(0.4, 0.25),
			Speed = NumberRange.new(1, 2),
			Acceleration = Vector3.new(0, -30, 0),
			Lifetime = NumberRange.new(seconds, seconds + 0.05),
			Transparency = NumberSequence.new(0.25, 0.6),
			Rate = rate,
		})
	end
	spill("FountainSpillMiddle", 7.5, 11.2, 7.5 - (RIM_TOP - 0.6), 140)
	spill("FountainSpillTop", 10.85, 5.3, 10.85 - 7.55, 70)

	-- A soft blue glow from the pool at night
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(120, 210, 255)
	glow.Range = 16
	glow.Brightness = 0.4
	glow.Shadows = false
	glow:SetAttribute("DayBrightness", 0.4)
	glow:SetAttribute("NightBrightness", 2.5)
	CollectionService:AddTag(glow, "NightLight")
	glow.Parent = poolWater
end

-- A board on two posts facing `facing` (how to play, paycheck...)
local function board(
	folder: Instance,
	name: string,
	at: Vector3,
	facing: Vector3,
	size: Vector2,
	color: Color3
): BasePart
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

-- The signs turn to face the spawn pad, so you can read them the moment you arrive
local SPAWN = Vector3.new(24, 0, 0)
local function towardSpawn(at: Vector3): Vector3
	local flat = SPAWN - at
	return Vector3.new(flat.X, 0, flat.Z).Unit
end

local function infoBoards(folder: Instance)
	local howToAt = Vector3.new(-22, 0, 50)
	local howTo = board(folder, "HowToPlayBoard", howToAt, towardSpawn(howToAt), Vector2.new(18, 10), C.Dark)
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
			.. "1. Cross a bridge to a zone\n"
			.. "2. GRAB an animal: hold E, or DIVE\n"
			.. "3. BOX it: rub a ♥, tape the seams\n"
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

	local paycheckAt = Vector3.new(22, 0, 50)
	local paycheck = board(folder, "PaycheckBoard", paycheckAt, towardSpawn(paycheckAt), Vector2.new(14, 6), C.Dark)
	Kit.signText(
		paycheck,
		Enum.NormalId.Front,
		"💵 DAILY PAYCHECK",
		C.Gold,
		"Play every day for a bigger one!",
		Color3.fromRGB(35, 70, 40)
	)
	task.spawn(function()
		local gui = paycheck:FindFirstChildOfClass("SurfaceGui")
		local frame = gui and gui:FindFirstChildOfClass("Frame")
		local sub = frame and frame:FindFirstChild("Subtitle") :: TextLabel?
		while paycheck.Parent do
			local left = 86400 - os.time() % 86400
			if sub then
				sub.Text =
					string.format("Play daily for a bigger one! Next in %dh %02dm", left // 3600, (left % 3600) // 60)
			end
			task.wait(1)
		end
	end)

	local groupAt = Vector3.new(36, 0, 40)
	local group = board(folder, "GroupBoard", groupAt, towardSpawn(groupAt), Vector2.new(12, 6), C.Dark)
	Kit.signText(
		group,
		Enum.NormalId.Front,
		"⭐ JOIN THE GROUP",
		Color3.fromRGB(120, 255, 140),
		"+10% coins forever! 👍 Like the game too",
		Color3.fromRGB(40, 45, 80)
	)
end

function Town.Build(parent: Instance, island: Islands.Island, destinations: { Destination }, keep: { { number } })
	local folder = Instance.new("Folder")
	folder.Name = "Town"
	folder.Parent = parent
	local random = Random.new(20261006)
	local R = World.Town.PlazaRadius

	-- Is p clear of the gameplay pieces (Post Office, counters...) by `pad`?
	local function clearOfKeep(p: Vector3, pad: number): boolean
		for _, k in keep do
			if (Vector3.new(p.X - k[1], 0, p.Z - k[2])).Magnitude < k[3] + pad then
				return false
			end
		end
		return true
	end
	-- Path centerlines: from the plaza's edge to each bridge
	local paths: { { A: Vector3, B: Vector3 } } = {}
	for _, d in destinations do
		local dir = Vector3.new(d.From.X, 0, d.From.Z).Unit
		table.insert(paths, { A = dir * (R - 2), B = d.From + dir * 2 })
	end
	local function nearPath(p: Vector3, pad: number): boolean
		for _, path in paths do
			if segmentDistance(p, path.A, path.B) < World.BridgeWidth / 2 + 2 + pad then
				return true
			end
		end
		return false
	end

	-- The plaza: a pale paved disc with a darker border, a ring around the fountain, a sunburst of lines and
	-- a mid ring of tiles
	Kit.disc(folder, "PlazaFloor", Vector3.zero, 0.2, 0.6, R, C.PavingDark)
	Kit.disc(folder, "PlazaFloor", Vector3.zero, 0.22, 0.6, R - 2.5, C.Paving)
	Kit.disc(folder, "PlazaFloor", Vector3.zero, 0.24, 0.6, 20, C.PavingDark)
	Kit.disc(folder, "PlazaFloor", Vector3.zero, 0.26, 0.6, 18.4, Color3.fromRGB(216, 202, 178))
	for i = 1, 24 do
		local a = i / 24 * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local length = R - 2.5 - 20
		part(folder, {
			Name = "Grout",
			Size = Vector3.new(0.5, 0.06, length),
			CFrame = CFrame.lookAt(
				dir * (20 + length / 2) + Vector3.new(0, 0.24, 0),
				dir * R + Vector3.new(0, 0.24, 0)
			),
			Color = C.PavingDark,
			CanCollide = false,
		})
	end
	for _, ringRadius in { 34, 48 } do
		local count = math.floor(ringRadius * 2 * math.pi / 3)
		for i = 1, count do
			local a = i / count * math.pi * 2
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			part(folder, {
				Name = "Grout",
				Size = Vector3.new(ringRadius * 2 * math.pi / count + 0.05, 0.06, 0.5),
				CFrame = CFrame.lookAt(
					dir * ringRadius + Vector3.new(0, 0.24, 0),
					dir * (ringRadius + 1) + Vector3.new(0, 0.24, 0)
				),
				Color = C.PavingDark,
				CanCollide = false,
			})
		end
	end

	fountain(folder)

	-- Round flower beds on the mid ring (between the paths and the counters)
	local flowerColors = {
		Color3.fromRGB(255, 120, 150),
		Color3.fromRGB(255, 220, 90),
		Color3.fromRGB(170, 130, 255),
		Color3.fromRGB(255, 255, 255),
		Color3.fromRGB(255, 150, 70),
	}
	for i = 0, 11 do
		local a = (i + 0.5) / 12 * math.pi * 2
		local p = Vector3.new(math.cos(a), 0, math.sin(a)) * 41
		if not nearPath(p, 3) and clearOfKeep(p, 5) then
			Kit.disc(folder, "BedRim", p, 0.9, 0.9, 4.2, C.PavingDark)
			Kit.disc(folder, "BedSoil", p, 0.95, 0.4, 3.6, Color3.fromRGB(110, 82, 58))
			Kit.flowers(folder, p + Vector3.new(0, 0.9, 0), flowerColors[(i % #flowerColors) + 1], random)
			Kit.bush(folder, p + Vector3.new(0, 0.9, 0), 2.2, C.Hedge)
		end
	end

	-- Lamps and a low hedge around the edge of the plaza (with gaps for the paths and the Post Office)
	local edgeCount = 72
	for i = 1, edgeCount do
		local a = i / edgeCount * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local p = dir * (R + 1.2)
		if not nearPath(p, 1) and clearOfKeep(p, 2) then
			part(folder, {
				Name = "Hedge",
				Size = Vector3.new((R + 1.2) * 2 * math.pi / edgeCount + 0.4, 2.2, 1.8),
				CFrame = CFrame.lookAt(p + Vector3.new(0, 1.1, 0), p + dir + Vector3.new(0, 1.1, 0)),
				Color = if i % 2 == 0 then C.Hedge else C.Hedge:Lerp(Color3.new(0, 0.3, 0), 0.08),
			})
		end
	end
	for i = 1, 16 do
		local a = (i + 0.5) / 16 * math.pi * 2
		local p = Vector3.new(math.cos(a), 0, math.sin(a)) * (R - 4)
		if not nearPath(p, 1) and clearOfKeep(p, 3) then
			Kit.lamppost(folder, p + Vector3.new(0, 0.2, 0))
		end
	end

	-- Paths out to the bridges: paving with darker curbs, lamps along them, and an arch at each bridge
	for index, d in destinations do
		local path = paths[index]
		local along = (path.B - path.A).Unit
		local length = (path.B - path.A).Magnitude
		local mid = (path.A + path.B) / 2
		local cf = CFrame.lookAt(mid + Vector3.new(0, 0.15, 0), mid + along + Vector3.new(0, 0.15, 0))
		Kit.road(folder, path.A, path.B, World.BridgeWidth + 4, Kit.ROADS.Town, index)
		local lamps = math.floor(length / 16)
		for i = 1, lamps do
			for _, side in { -1, 1 } do
				local p = (cf * CFrame.new(
					side * (World.BridgeWidth / 2 + 3.5),
					-0.15,
					-length / 2 + i * length / (lamps + 1)
				)).Position
				Kit.lamppost(folder, Vector3.new(p.X, 0, p.Z))
			end
		end
		Town.Arch(folder, d.From - along * 3, along, d.Name, d.Subtitle, d.Color)
	end

	infoBoards(folder)

	-- The big title over the Post Office
	local title = part(folder, {
		Name = "TitleSign",
		Size = Vector3.new(44, 10, 1),
		CFrame = CFrame.lookAt(Vector3.new(62, 22, 0), Vector3.new(72, 22, 0)), -- (over the Post Office, facing the plaza)
		Transparency = 1,
		CanCollide = false,
	})
	Kit.signText(title, Enum.NormalId.Back, "📦 MAIL A TIGER 🐯", Color3.fromRGB(255, 200, 60), nil, nil)

	-- The green ring: cottages between the paths, then trees, bushes, flowers and rocks wherever there's room
	local cottageColors = {
		{ Color3.fromRGB(250, 236, 205), Color3.fromRGB(70, 120, 210) },
		{ Color3.fromRGB(255, 214, 160), Color3.fromRGB(200, 70, 60) },
		{ Color3.fromRGB(214, 236, 255), Color3.fromRGB(60, 150, 110) },
		{ Color3.fromRGB(255, 226, 226), Color3.fromRGB(150, 90, 200) },
	}
	local houses = 0
	for i = 0, 23 do
		local a = (i + 0.5) / 24 * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local p = dir * 88
		if houses < 6 and i % 3 == 0 and not nearPath(p, 12) and clearOfKeep(p, 14) and island.OnLand(p, 14) then
			houses += 1
			local colors = cottageColors[(houses % #cottageColors) + 1]
			Kit.cottage(folder, p, -dir, colors[1], colors[2], 0.9)
			-- A little garden fence and a mailbox in front
			box(
				folder,
				"Mailbox",
				p - dir * 9 + dir:Cross(Vector3.yAxis) * 4 + Vector3.new(0, 1.6, 0),
				Vector3.new(0.9, 0.9, 1.4),
				Color3.fromRGB(70, 120, 225)
			)
			box(
				folder,
				"MailboxPost",
				p - dir * 9 + dir:Cross(Vector3.yAxis) * 4 + Vector3.new(0, 0.6, 0),
				Vector3.new(0.3, 1.2, 0.3),
				C.DarkWood
			)
		end
	end
	local placed = 0
	for _ = 1, 900 do
		if placed >= 120 then
			break
		end
		local a = random:NextNumber(0, math.pi * 2)
		local r = random:NextNumber(R + 5, World.Town.Radius + 20)
		local p = Vector3.new(math.cos(a), 0, math.sin(a)) * r
		if island.OnLand(p, 6) and not nearPath(p, 4) and clearOfKeep(p, 8) then
			-- (not on a cottage)
			local free = true
			for _, child in folder:GetChildren() do
				if child.Name == "CottageWall" and ((child :: BasePart).Position - p).Magnitude < 13 then
					free = false
					break
				end
			end
			if free then
				placed += 1
				local roll = random:NextNumber()
				-- (a tree's canopy needs more room: next to a path its branches hit the path's lamps, and at a
				-- bridge they hang through the ropes; a bush goes there instead)
				local cramped = nearPath(p, 9)
				for _, d in destinations do
					if segmentDistance(p, d.From, d.To) < World.BridgeWidth / 2 + 16 then
						cramped = true
					end
				end
				if roll < 0.55 and not cramped then
					Kit.tree(folder, p, random:NextNumber(13, 22))
				elseif roll < 0.72 then
					Kit.bush(folder, p, random:NextNumber(2.5, 4))
				elseif roll < 0.88 then
					Kit.flowers(folder, p, flowerColors[random:NextInteger(1, #flowerColors)], random)
				else
					Kit.rock(folder, p, random:NextNumber(2, 4), random)
				end
			end
		end
	end
end

return Town
