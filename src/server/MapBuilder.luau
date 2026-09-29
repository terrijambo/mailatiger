--!strict
-- Builds the graybox world in code: the hub town and five themed catching arenas.
-- This is a placeholder. The real map gets built by hand in Studio later, and this file shrinks.
--
-- Layout (top-down, ground at y = 0):
--   Hub town     plaza around (0, 30): spawn, Animal Pen, Supply Shop, Post Office, Gruff's Orders,
--                and a row of travel pads (one per arena) at z = 32
--   Backyard     x  -30..30,   z  -40..0      (right next to the hub)
--   Barn         x -140..-80,  z  -50..0
--   Jungle       x   70..140,  z  -50..0
--   Ice Rink     x  -40..40,   z -150..-100
--   Rooftop      x   80..130,  z -150..-100, on top of a 30-stud-tall building
-- Every arena's gate is on its +Z side. Arena ids and tiers are in src/shared/Config/Arenas.luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local MapBuilder = {}

-- Something in an arena the animals steer around (trees, hay bales, bushes...)
export type Obstacle = {
	Center: Vector3,
	Radius: number,
}

export type Arena = {
	Id: string,
	Min: Vector3, -- animals are kept inside Min..Max (Y = floor height)
	Max: Vector3,
	Center: Vector3,
	FloorY: number,
	Gate: CFrame, -- where players are teleported to, facing into the arena
	Obstacles: { Obstacle },
	Edges: boolean, -- true = no fence, you can fall off (Rooftop)
}

export type Map = {
	PenPrompt: ProximityPrompt,
	PenCounter: BasePart,
	Arenas: { [string]: Arena },
	TownSpawn: CFrame,
	TravelPads: { [string]: BasePart }, -- in town, one per arena
	ReturnPads: { BasePart }, -- at each arena, back to town
	Chute: BasePart,
	GruffHat: BasePart,
	ShopPrompt: ProximityPrompt,
	ShopCounter: BasePart,
	OrdersPrompt: ProximityPrompt,
}

local COLORS = {
	Grass = Color3.fromRGB(106, 170, 84),
	DarkGrass = Color3.fromRGB(70, 130, 60),
	Dirt = Color3.fromRGB(150, 115, 80),
	Stone = Color3.fromRGB(190, 190, 180),
	Wood = Color3.fromRGB(160, 110, 70),
	Yellow = Color3.fromRGB(240, 210, 80),
	PostRed = Color3.fromRGB(200, 60, 60),
	PostBlue = Color3.fromRGB(60, 90, 170),
	Chute = Color3.fromRGB(45, 45, 55),
	Walrus = Color3.fromRGB(130, 110, 100),
	Hay = Color3.fromRGB(230, 200, 100),
	BarnRed = Color3.fromRGB(170, 50, 45),
	Bark = Color3.fromRGB(100, 70, 45),
	Leaves = Color3.fromRGB(50, 150, 60),
	Mud = Color3.fromRGB(90, 65, 45),
	Ice = Color3.fromRGB(200, 235, 255),
	White = Color3.fromRGB(245, 245, 245),
	Concrete = Color3.fromRGB(150, 150, 155),
	Metal = Color3.fromRGB(170, 175, 180),
}

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

-- A part filling the box between two corners. Much easier to lay out than center + size.
local function block(
	parent: Instance,
	name: string,
	min: Vector3,
	max: Vector3,
	color: Color3,
	extra: { [string]: any }?
): Part
	local props: { [string]: any } = extra or {}
	props.Name = name
	props.Size = max - min
	props.Position = (min + max) / 2
	props.Color = color
	return part(parent, props)
end

function MapBuilder.Label(adornee: BasePart, text: string, height: number, color: Color3?)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(240, 44)
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.MaxDistance = 120

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Parent = gui

	gui.Parent = adornee
end

local function prompt(parent: BasePart, action: string, object: string, hold: number): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = hold
	p.RequiresLineOfSight = false
	p.Parent = parent
	return p
end

---------------------------------------------------------------------------------------------------
-- Arenas

type ArenaSpec = {
	Id: string,
	MinX: number,
	MaxX: number,
	MinZ: number,
	MaxZ: number,
	FloorY: number,
	FloorColor: Color3,
	FloorMaterial: Enum.Material,
	FenceColor: Color3?, -- nil = no fence (edges!)
}

-- Floor, fence with a gate on the +Z side, a sign, and a pad back to town.
local function buildArena(parent: Instance, spec: ArenaSpec, returnPads: { BasePart }): Arena
	local folder = Instance.new("Folder")
	folder.Name = spec.Id
	folder.Parent = parent

	local y = spec.FloorY
	local min = Vector3.new(spec.MinX, y, spec.MinZ)
	local max = Vector3.new(spec.MaxX, y, spec.MaxZ)
	local center = (min + max) / 2
	local def = Config.Arenas.ById[spec.Id]

	block(
		folder,
		"Floor",
		Vector3.new(spec.MinX, y - 0.5, spec.MinZ),
		Vector3.new(spec.MaxX, y + 0.02, spec.MaxZ),
		spec.FloorColor,
		{
			Material = spec.FloorMaterial,
		}
	)

	local gate: CFrame
	local fenceColor = spec.FenceColor
	if fenceColor then
		local h = 4
		local x0, x1, z0, z1 = spec.MinX, spec.MaxX, spec.MinZ, spec.MaxZ
		block(folder, "Fence", Vector3.new(x0 - 1, y, z0 - 1), Vector3.new(x1 + 1, y + h, z0), fenceColor)
		block(folder, "Fence", Vector3.new(x0 - 1, y, z0 - 1), Vector3.new(x0, y + h, z1 + 1), fenceColor)
		block(folder, "Fence", Vector3.new(x1, y, z0 - 1), Vector3.new(x1 + 1, y + h, z1 + 1), fenceColor)
		block(folder, "Fence", Vector3.new(x0 - 1, y, z1), Vector3.new(center.X - 5, y + h, z1 + 1), fenceColor)
		block(folder, "Fence", Vector3.new(center.X + 5, y, z1), Vector3.new(x1 + 1, y + h, z1 + 1), fenceColor)
		block(
			folder,
			"GatePost",
			Vector3.new(center.X - 6, y, z1),
			Vector3.new(center.X - 5, y + 8.5, z1 + 1),
			COLORS.Stone
		)
		block(
			folder,
			"GatePost",
			Vector3.new(center.X + 5, y, z1),
			Vector3.new(center.X + 6, y + 8.5, z1 + 1),
			COLORS.Stone
		)
		local sign = block(
			folder,
			"GateSign",
			Vector3.new(center.X - 5, y + 7, z1),
			Vector3.new(center.X + 5, y + 8.5, z1 + 1),
			def.Color
		)
		MapBuilder.Label(sign, string.upper(def.DisplayName), 2, COLORS.Yellow)
		-- Land just outside the gate, facing in
		local spot = Vector3.new(center.X, y + 3, z1 + 6)
		gate = CFrame.lookAt(spot, spot - Vector3.zAxis)
		block(
			folder,
			"GatePath",
			Vector3.new(center.X - 5, y - 0.5, z1),
			Vector3.new(center.X + 5, y + 0.02, z1 + 12),
			COLORS.Stone
		)
	else
		-- No fence: land on the roof itself
		local spot = Vector3.new(center.X, y + 3, spec.MaxZ - 4)
		gate = CFrame.lookAt(spot, spot - Vector3.zAxis)
		local sign = block(
			folder,
			"Sign",
			Vector3.new(center.X - 5, y + 7, spec.MaxZ - 1),
			Vector3.new(center.X + 5, y + 8.5, spec.MaxZ),
			def.Color
		)
		MapBuilder.Label(sign, string.upper(def.DisplayName), 2, COLORS.Yellow)
		block(
			folder,
			"SignPost",
			Vector3.new(center.X - 0.5, y, spec.MaxZ - 1),
			Vector3.new(center.X + 0.5, y + 7, spec.MaxZ),
			COLORS.Stone
		)
	end

	-- Pad back to town, just to the right of where you arrive (the Backyard is already in town)
	if spec.Id ~= "Backyard" then
		local padSpot = gate.Position + Vector3.new(9, -3, 0)
		local pad = part(folder, {
			Name = "ReturnPad",
			Size = Vector3.new(6, 1, 6),
			Position = padSpot + Vector3.new(0, 0.5, 0),
			Color = COLORS.PostBlue,
			Material = Enum.Material.Neon,
		})
		MapBuilder.Label(pad, "BACK TO TOWN", 3, COLORS.Yellow)
		table.insert(returnPads, pad)
	end

	return {
		Id = spec.Id,
		Min = min,
		Max = max,
		Center = center,
		FloorY = y,
		Gate = gate,
		Obstacles = {},
		Edges = fenceColor == nil,
	}
end

-- Adds a round-ish obstacle to an arena (for the AI) and returns its position
local function addObstacle(arena: Arena, x: number, z: number, radius: number): Vector3
	local position = Vector3.new(x, arena.FloorY, z)
	table.insert(arena.Obstacles, { Center = position, Radius = radius })
	return position
end

local function buildBackyard(parent: Instance, returnPads: { BasePart }): Arena
	local arena = buildArena(parent, {
		Id = "Backyard",
		MinX = -30,
		MaxX = 30,
		MinZ = -40,
		MaxZ = 0,
		FloorY = 0,
		FloorColor = COLORS.Grass,
		FloorMaterial = Enum.Material.Grass,
		FenceColor = COLORS.Wood,
	}, returnPads)
	local folder = parent:FindFirstChild("Backyard") :: Folder
	for _, spot in { { -15, -25, 2.5 }, { 12, -12, 2 }, { 18, -30, 2.5 } } do
		local position = addObstacle(arena, spot[1], spot[2], spot[3])
		part(folder, {
			Name = "Bush",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * spot[3] * 2,
			Position = position + Vector3.new(0, spot[3] * 0.6, 0),
			Color = COLORS.DarkGrass,
			Material = Enum.Material.Grass,
		})
	end
	return arena
end

local function buildBarn(parent: Instance, returnPads: { BasePart }): Arena
	local arena = buildArena(parent, {
		Id = "Barn",
		MinX = -140,
		MaxX = -80,
		MinZ = -50,
		MaxZ = 0,
		FloorY = 0,
		FloorColor = COLORS.Dirt,
		FloorMaterial = Enum.Material.Ground,
		FenceColor = COLORS.BarnRed,
	}, returnPads)
	local folder = parent:FindFirstChild("Barn") :: Folder
	-- The barn itself, behind the arena
	block(folder, "BarnWall", Vector3.new(-135, 0, -64), Vector3.new(-85, 16, -52), COLORS.BarnRed)
	block(folder, "BarnRoof", Vector3.new(-137, 16, -66), Vector3.new(-83, 18, -50), COLORS.Stone)
	-- Hay bales to hide behind
	for _, spot in { { -125, -35 }, { -110, -15 }, { -95, -38 }, { -100, -12 }, { -122, -10 }, { -110, -40 } } do
		local position = addObstacle(arena, spot[1], spot[2], 3.3)
		part(folder, {
			Name = "HayBale",
			Size = Vector3.new(5, 4, 5),
			Position = position + Vector3.new(0, 2, 0),
			Color = COLORS.Hay,
			Material = Enum.Material.Fabric,
		})
	end
	return arena
end

local function buildJungle(parent: Instance, returnPads: { BasePart }): Arena
	local arena = buildArena(parent, {
		Id = "Jungle",
		MinX = 70,
		MaxX = 140,
		MinZ = -50,
		MaxZ = 0,
		FloorY = 0,
		FloorColor = COLORS.DarkGrass,
		FloorMaterial = Enum.Material.LeafyGrass,
		FenceColor = COLORS.Bark,
	}, returnPads)
	local folder = parent:FindFirstChild("Jungle") :: Folder
	for _, spot in { { 82, -40 }, { 95, -20 }, { 110, -38 }, { 125, -15 }, { 132, -42 }, { 100, -8 }, { 118, -28 } } do
		local position = addObstacle(arena, spot[1], spot[2], 1.8)
		part(folder, {
			Name = "Trunk",
			Size = Vector3.new(2.4, 12, 2.4),
			Position = position + Vector3.new(0, 6, 0),
			Color = COLORS.Bark,
			Material = Enum.Material.Wood,
		})
		part(folder, {
			Name = "Canopy",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(10, 10, 10),
			Position = position + Vector3.new(0, 13, 0),
			Color = COLORS.Leaves,
			Material = Enum.Material.Grass,
			CanCollide = false,
		})
	end
	-- Mud pits slow you down (Material = Mud is how the client knows)
	for _, rect in { { 84, -32, 12, 8 }, { 120, -6, 10, 8 }, { 104, -47, 14, 5 } } do
		local x, z, sx, sz = rect[1], rect[2], rect[3], rect[4]
		block(
			folder,
			"Mud",
			Vector3.new(x - sx / 2, 0, z - sz / 2),
			Vector3.new(x + sx / 2, 0.12, z + sz / 2),
			COLORS.Mud,
			{
				Material = Enum.Material.Mud,
			}
		)
	end
	return arena
end

local function buildIceRink(parent: Instance, returnPads: { BasePart }): Arena
	local arena = buildArena(parent, {
		Id = "IceRink",
		MinX = -40,
		MaxX = 40,
		MinZ = -150,
		MaxZ = -100,
		FloorY = 0,
		FloorColor = COLORS.Ice,
		FloorMaterial = Enum.Material.Ice, -- the client makes you slide on Ice
		FenceColor = COLORS.White,
	}, returnPads)
	local folder = parent:FindFirstChild("IceRink") :: Folder
	for _, spot in { { -30, -125 }, { 30, -125 } } do
		local position = addObstacle(arena, spot[1], spot[2], 2.5)
		block(folder, "Goal", position - Vector3.new(1.5, 0, 2.5), position + Vector3.new(1.5, 4, 2.5), COLORS.PostRed)
	end
	return arena
end

local function buildRooftop(parent: Instance, returnPads: { BasePart }): Arena
	local roofY = 30
	block(parent, "RooftopBuilding", Vector3.new(80, 0, -150), Vector3.new(130, roofY - 0.5, -100), COLORS.Concrete)
	local arena = buildArena(parent, {
		Id = "Rooftop",
		MinX = 80,
		MaxX = 130,
		MinZ = -150,
		MaxZ = -100,
		FloorY = roofY,
		FloorColor = COLORS.Concrete,
		FloorMaterial = Enum.Material.Concrete,
		FenceColor = nil, -- no fence. Edges!
	}, returnPads)
	local folder = parent:FindFirstChild("Rooftop") :: Folder
	for _, spot in { { 92, -120, 3 }, { 115, -135, 3 }, { 118, -112, 3 }, { 100, -142, 2 } } do
		local position = addObstacle(arena, spot[1], spot[2], spot[3])
		block(
			folder,
			"AirConditioner",
			position - Vector3.new(2, 0, 2),
			position + Vector3.new(2, 3, 2),
			COLORS.Metal,
			{
				Material = Enum.Material.DiamondPlate,
			}
		)
	end
	return arena
end

---------------------------------------------------------------------------------------------------

function MapBuilder.Build(): Map
	local existing = Workspace:FindFirstChild("GrayboxMap")
	if existing then
		existing:Destroy()
	end
	local map = Instance.new("Folder")
	map.Name = "GrayboxMap"
	map.Parent = Workspace

	-- Ground
	block(map, "Ground", Vector3.new(-170, -1, -175), Vector3.new(170, 0, 75), COLORS.Grass, {
		Material = Enum.Material.Grass,
	})

	-- Hub town plaza + spawn
	block(map, "Plaza", Vector3.new(-36, 0, 2), Vector3.new(36, 0.05, 56), COLORS.Stone, {
		Material = Enum.Material.Cobblestone,
	})
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = Vector3.new(0, 0.5, 45)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = COLORS.PostBlue
	spawn.Parent = map

	-- Animal Pen counter (next to the Backyard gate)
	local counter = block(map, "PenCounter", Vector3.new(-18, 0, 6), Vector3.new(-10, 3, 8), COLORS.Wood)
	MapBuilder.Label(counter, "ANIMAL PEN", 4, COLORS.Yellow)
	local penPrompt = prompt(counter, "Choose an Animal", "Animal Pen", 0.3)

	-- Post Office: Gruff's counter, back wall, and the mail chute
	block(map, "PostOfficeFloor", Vector3.new(8, 0, 4), Vector3.new(28, 0.3, 18), COLORS.Stone)
	local backWall = block(map, "PostOfficeWall", Vector3.new(8, 0.3, 17), Vector3.new(28, 12, 18), COLORS.PostRed)
	MapBuilder.Label(backWall, "POST OFFICE", 7, COLORS.Yellow)
	block(map, "PostOfficeRoof", Vector3.new(7, 12, 3), Vector3.new(29, 13, 18), COLORS.PostBlue)
	block(map, "Counter", Vector3.new(10, 0.3, 7), Vector3.new(20, 3.5, 9), COLORS.Wood)
	local gruff = part(map, {
		Name = "Gruff",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(7, 7, 7),
		Position = Vector3.new(15, 3.8, 12),
		Color = COLORS.Walrus,
	})
	MapBuilder.Label(gruff, "Postmaster Gruff", 5)
	-- His tiny postal cap. A tiger breakout knocks it off.
	local gruffHat = part(map, {
		Name = "GruffHat",
		Size = Vector3.new(3.5, 1, 3.5),
		Position = Vector3.new(15, 7.8, 12),
		Color = COLORS.PostBlue,
	})
	local chute = block(map, "MailChute", Vector3.new(22, 0.3, 6), Vector3.new(26, 5, 10), COLORS.Chute)
	MapBuilder.Label(chute, "MAIL CHUTE", 3.5, COLORS.Yellow)

	-- Gruff's orders board (right of the Post Office)
	local board = block(map, "OrdersBoard", Vector3.new(30, 0, 8), Vector3.new(31, 7, 14), COLORS.Wood)
	MapBuilder.Label(board, "GRUFF'S ORDERS", 5, COLORS.Yellow)
	local ordersPrompt = prompt(board, "Read Orders", "Gruff's Orders", 0.2)

	-- Supply Shop (behind the Animal Pen)
	local shopCounter = block(map, "ShopCounter", Vector3.new(-18, 0, 20), Vector3.new(-10, 3, 22), COLORS.PostBlue)
	MapBuilder.Label(shopCounter, "SUPPLY SHOP", 4, COLORS.Yellow)
	local shopPrompt = prompt(shopCounter, "Shop", "Boxes, Tools, Stamps", 0.2)

	-- Arenas
	local arenaFolder = Instance.new("Folder")
	arenaFolder.Name = "Arenas"
	arenaFolder.Parent = map
	local returnPads: { BasePart } = {}
	local arenas: { [string]: Arena } = {}
	for _, arena in
		{
			buildBackyard(arenaFolder, returnPads),
			buildBarn(arenaFolder, returnPads),
			buildJungle(arenaFolder, returnPads),
			buildIceRink(arenaFolder, returnPads),
			buildRooftop(arenaFolder, returnPads),
		}
	do
		arenas[arena.Id] = arena
	end

	-- Travel pads in town: one per arena, in a row across the plaza
	local travelPads: { [string]: BasePart } = {}
	for index, def in Config.Arenas.List do
		local x = -32 + (index - 1) * 16
		local pad = part(map, {
			Name = `TravelPad_{def.Id}`,
			Size = Vector3.new(6, 1, 6),
			Position = Vector3.new(x, 0.5, 32),
			Color = def.Color,
			Material = Enum.Material.Neon,
		})
		local tiers = table.concat(def.Tiers, " & ")
		MapBuilder.Label(pad, `{def.DisplayName} (tier {tiers})`, 3, COLORS.Yellow)
		travelPads[def.Id] = pad
	end

	local townSpot = Vector3.new(0, 3, 40)
	return {
		PenPrompt = penPrompt,
		PenCounter = counter,
		Arenas = arenas,
		TownSpawn = CFrame.lookAt(townSpot, townSpot - Vector3.zAxis),
		TravelPads = travelPads,
		ReturnPads = returnPads,
		Chute = chute,
		GruffHat = gruffHat,
		ShopPrompt = shopPrompt,
		ShopCounter = shopCounter,
		OrdersPrompt = ordersPrompt,
	}
end

return MapBuilder
