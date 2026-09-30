--!strict
-- Everything in the world that's just for looks: the island (terrain), the ocean and mountains, the hub's
-- terraces, fountain and info boards, the stone paths out to each zone with their giant entrance banners,
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
	PathStarts: { [string]: Vector3 }, -- zone id -> where its path leaves the plaza
}

local C = {
	Grass = Color3.fromRGB(106, 180, 84),
	GrassTop = Color3.fromRGB(96, 190, 70),
	Brick = Color3.fromRGB(184, 72, 60),
	Stone = Color3.fromRGB(200, 196, 186),
	Path = Color3.fromRGB(176, 168, 150),
	Wood = Color3.fromRGB(150, 100, 62),
	White = Color3.fromRGB(245, 245, 245),
	Roof = Color3.fromRGB(80, 90, 120),
	Water = Color3.fromRGB(90, 170, 230),
	Leaves = Color3.fromRGB(60, 160, 70),
	Pine = Color3.fromRGB(40, 110, 70),
	Bark = Color3.fromRGB(110, 75, 50),
	Snow = Color3.fromRGB(240, 246, 255),
	Glass = Color3.fromRGB(150, 200, 235),
	Dark = Color3.fromRGB(30, 30, 40),
	Gold = Color3.fromRGB(255, 205, 60),
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
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(0.94, if subtitle then 0.68 else 0.9)
	title.Position = UDim2.fromScale(0.03, 0.05)
	title.Font = Enum.Font.LuckiestGuy
	title.TextScaled = true
	title.TextColor3 = color
	title.Text = text
	title.Name = "Title"
	title.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 6
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Transparency = 0.1
	stroke.Parent = title
	if subtitle then
		local sub = Instance.new("TextLabel")
		sub.BackgroundTransparency = 1
		sub.Size = UDim2.fromScale(0.9, 0.24)
		sub.Position = UDim2.fromScale(0.05, 0.72)
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

local function buildTerrain(layout: Layout)
	local terrain = Workspace.Terrain
	-- Water looks nicer a bit clearer and wavier than the default
	terrain.WaterColor = C.Water
	terrain.WaterTransparency = 0.35
	terrain.WaterWaveSize = 0.2
	terrain.WaterWaveSpeed = 8

	-- Ocean everywhere, then the island on top of it
	terrain:FillBlock(CFrame.new(0, -14, -150), Vector3.new(2400, 20, 2400), Enum.Material.Water)
	local minX, maxX, minZ, maxZ = -300, 300, -470, 170
	local width, depth = maxX - minX, maxZ - minZ
	local middle = Vector3.new((minX + maxX) / 2, 0, (minZ + maxZ) / 2)
	-- Sand shelf a bit wider than the island (the beach), then grass on top
	terrain:FillBlock(CFrame.new(middle.X, -6, middle.Z), Vector3.new(width + 60, 12, depth + 60), Enum.Material.Sand)
	terrain:FillBlock(CFrame.new(middle.X, -4, middle.Z), Vector3.new(width, 8, depth), Enum.Material.Grass)

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

	-- Themed ground under each zone (a little wider than the arena)
	local zoneGround: { [string]: Enum.Material } = {
		Barn = Enum.Material.Ground,
		Jungle = Enum.Material.LeafyGrass,
		IceRink = Enum.Material.Snow,
		Rooftop = Enum.Material.Asphalt,
	}
	for _, zone in layout.Zones do
		local material = zoneGround[zone.Id]
		if material then
			local pad = if zone.Id == "Rooftop" or zone.Id == "IceRink" then 55 else 35
			terrain:FillBlock(
				CFrame.new(zone.Center.X, -2, zone.Center.Z),
				Vector3.new(zone.HalfX * 2 + pad * 2, 4, zone.HalfZ * 2 + pad * 2),
				material
			)
		end
	end
	-- Snowy hills around the winter zone
	for _, zone in layout.Zones do
		if zone.Id == "IceRink" then
			local c = zone.Center
			for _, h in { { -80, -40, 28 }, { -70, 30, 22 }, { 70, -45, 30 }, { 90, 20, 20 }, { 0, -85, 34 } } do
				terrain:FillBall(Vector3.new(c.X + h[1], -h[3] * 0.4, c.Z + h[2]), h[3], Enum.Material.Snow)
			end
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Little building blocks for scenery

local function tree(parent: Instance, at: Vector3, height: number, leaves: Color3?)
	local h = height
	box(
		parent,
		"Trunk",
		at + Vector3.new(0, h * 0.35, 0),
		Vector3.new(h * 0.12, h * 0.7, h * 0.12),
		C.Bark,
		Enum.Material.Wood
	)
	part(parent, {
		Name = "Leaves",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * h * 0.6,
		Position = at + Vector3.new(0, h * 0.78, 0),
		Color = leaves or C.Leaves,
		Material = Enum.Material.Grass,
	})
	part(parent, {
		Name = "Leaves",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * h * 0.42,
		Position = at + Vector3.new(h * 0.22, h * 0.62, h * 0.1),
		Color = (leaves or C.Leaves):Lerp(Color3.new(1, 1, 0.6), 0.12),
		Material = Enum.Material.Grass,
	})
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
			Material = if snowy and i == 3 then Enum.Material.Snow else Enum.Material.Grass,
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

-- A flat stone path between two points (a single long part, turned to face along the path)
local function path(parent: Instance, from: Vector3, to: Vector3, width: number)
	local flatFrom = Vector3.new(from.X, 0.06, from.Z)
	local flatTo = Vector3.new(to.X, 0.06, to.Z)
	local length = (flatTo - flatFrom).Magnitude
	part(parent, {
		Name = "Path",
		Size = Vector3.new(width, 0.12, length + width),
		CFrame = CFrame.lookAt((flatFrom + flatTo) / 2, flatTo),
		Color = C.Path,
		Material = Enum.Material.Cobblestone,
	})
	-- Lampposts along both sides every ~40 studs
	local direction = (flatTo - flatFrom).Unit
	local side = Vector3.new(-direction.Z, 0, direction.X)
	local count = math.floor(length / 40)
	for i = 1, count do
		local at = flatFrom + direction * (i * length / (count + 1))
		lamppost(parent, at + side * (width / 2 + 2) * (if i % 2 == 0 then 1 else -1))
	end
end

-- A raised grassy block with brick-red sides (the stepped terraces around the hub)
local function terrace(parent: Instance, min: Vector3, max: Vector3)
	local size = max - min
	local center = (min + max) / 2
	box(
		parent,
		"TerraceSide",
		center - Vector3.new(0, 0.5, 0),
		size - Vector3.new(0, 1, 0),
		C.Brick,
		Enum.Material.Brick
	)
	box(
		parent,
		"TerraceTop",
		Vector3.new(center.X, max.Y - 0.5, center.Z),
		Vector3.new(size.X + 0.4, 1, size.Z + 0.4),
		C.GrassTop,
		Enum.Material.Grass
	)
end

---------------------------------------------------------------------------------------------------
-- The hub

local function buildHub(parent: Instance, layout: Layout)
	local folder = Instance.new("Folder")
	folder.Name = "Hub"
	folder.Parent = parent
	local min, max = layout.PlazaMin, layout.PlazaMax

	-- Terraces around the plaza (two steps), with gaps where the paths leave
	local steps = {
		-- west side
		{ Vector3.new(min.X - 30, 0, min.Z + 20), Vector3.new(min.X - 4, 4, max.Z - 10) },
		{ Vector3.new(min.X - 44, 0, min.Z + 30), Vector3.new(min.X - 26, 9, max.Z - 20) },
		-- east side
		{ Vector3.new(max.X + 4, 0, min.Z + 20), Vector3.new(max.X + 30, 4, max.Z - 10) },
		{ Vector3.new(max.X + 26, 0, min.Z + 30), Vector3.new(max.X + 44, 9, max.Z - 20) },
		-- south, behind the spawn (split for the beach walk)
		{ Vector3.new(min.X + 10, 0, max.Z + 6), Vector3.new(-14, 5, max.Z + 26) },
		{ Vector3.new(14, 0, max.Z + 6), Vector3.new(max.X - 10, 5, max.Z + 26) },
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
		Color = C.Stone,
		Material = Enum.Material.Marble,
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
	box(
		folder,
		"FountainPillar",
		fountainAt + Vector3.new(0, 4, 0),
		Vector3.new(2.5, 6, 2.5),
		C.Stone,
		Enum.Material.Marble
	)
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

	-- Plaza lampposts around the edge
	for _, x in { min.X + 6, max.X - 6 } do
		for z = min.Z + 20, max.Z - 10, 30 do
			lamppost(folder, Vector3.new(x, 0, z))
		end
	end

	-- Info boards near the spawn (big, readable, like the boards in popular simulators)
	local function board(name: string, at: Vector3, facing: Vector3, size: Vector2, color: Color3): BasePart
		box(
			folder,
			name .. "Post",
			at + Vector3.new(-size.X / 2 + 0.6, size.Y / 2 + 1, 0),
			Vector3.new(0.8, size.Y + 2, 0.8),
			C.Dark,
			Enum.Material.Metal
		)
		box(
			folder,
			name .. "Post",
			at + Vector3.new(size.X / 2 - 0.6, size.Y / 2 + 1, 0),
			Vector3.new(0.8, size.Y + 2, 0.8),
			C.Dark,
			Enum.Material.Metal
		)
		local face = part(folder, {
			Name = name,
			Size = Vector3.new(size.X, size.Y, 0.6),
			CFrame = CFrame.lookAt(
				at + Vector3.new(0, size.Y / 2 + 2, 0),
				at + Vector3.new(0, size.Y / 2 + 2, 0) + facing
			),
			Color = color,
			Material = Enum.Material.SmoothPlastic,
		})
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
	Workspace.Terrain:FillBlock(
		CFrame.new(c.X, 18, back - 8),
		Vector3.new(zone.HalfX * 2 + 60, 44, 16),
		Enum.Material.Rock
	)
	Workspace.Terrain:FillBlock(
		CFrame.new(c.X, 42, back - 8),
		Vector3.new(zone.HalfX * 2 + 60, 4, 16),
		Enum.Material.LeafyGrass
	)
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

local function winterTheme(parent: Instance, zone: Zone)
	local c = zone.Center
	for i = 1, 16 do
		local angle = i / 16 * math.pi * 2
		local rx, rz = zone.HalfX + 22 + (i % 3) * 8, zone.HalfZ + 22 + (i % 2) * 10
		local at = Vector3.new(c.X + math.cos(angle) * rx, 0, c.Z + math.sin(angle) * rz)
		if at.Z < c.Z + zone.HalfZ + 6 or math.abs(at.X - c.X) > 20 then -- keep the gate clear
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
local function scatter(parent: Instance, layout: Layout)
	local random = Random.new(20260930)
	local segments: { { Vector3 } } = {}
	for _, zone in layout.Zones do
		local start = layout.PathStarts[zone.Id]
		if start then
			table.insert(segments, { start, zone.Gate + Vector3.new(0, 0, 14) })
		end
	end
	local function nearPath(p: Vector3): boolean
		for _, seg in segments do
			local a, b = seg[1], seg[2]
			local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
			local ap = Vector3.new(p.X - a.X, 0, p.Z - a.Z)
			local t = math.clamp(ap:Dot(ab) / ab:Dot(ab), 0, 1)
			if (ap - ab * t).Magnitude < 14 then
				return true
			end
		end
		return false
	end
	local function blocked(p: Vector3): boolean
		local min, max = layout.PlazaMin, layout.PlazaMax
		if p.X > min.X - 50 and p.X < max.X + 50 and p.Z > min.Z - 10 and p.Z < max.Z + 30 then
			return true -- the plaza and its terraces
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
		return nearPath(p)
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
	buildHub(folder, layout)
	local wild = Instance.new("Folder")
	wild.Name = "Wilderness"
	wild.Parent = folder
	scatter(wild, layout)
	signpost(folder, Vector3.new(26, 0, layout.PlazaMin.Z + 6), layout)

	local paths = Instance.new("Folder")
	paths.Name = "Paths"
	paths.Parent = folder
	for _, zone in layout.Zones do
		local start = layout.PathStarts[zone.Id]
		if start then
			path(paths, start, zone.Gate + Vector3.new(0, 0, 14), 12)
		end
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
