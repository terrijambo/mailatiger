--!strict
-- Builds the world in code: the hub town and five themed catching arenas.
-- Every grey block that has a Blender model (ReplicatedStorage > MapModels, see README) gets that model laid
-- over it. The block stays, invisible, as the collider, the prompt holder and the name tag. Missing models
-- just leave the grey block showing, so the game always works.
--
-- Layout (top-down, ground at y = 0):
--   Hub town     plaza around (0, 30): spawn, Animal Pen, Supply Shop, Post Office (facing the plaza, with
--                Gruff, his counter and the chute out front), Gruff's Orders, and a row of travel pads at z = 32
--   Backyard     x  -30..30,   z  -40..0      (right next to the hub)
--   Barn         x -140..-80,  z  -50..0
--   Jungle       x   70..140,  z  -50..0
--   Ice Rink     x  -40..40,   z -150..-100
--   Rooftop      x   80..130,  z -150..-100, on top of a 30-stud-tall building
-- Every arena's gate is on its +Z side. Arena ids and tiers are in src/shared/Config/Arenas.luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local ModelFit = require(ReplicatedStorage.Shared.ModelFit)

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
	ChutePrompt: ProximityPrompt,
	Gruff: BasePart, -- invisible when his Blender model is showing; holds his name tag
	GruffHat: BasePart,
	ShopPrompt: ProximityPrompt,
	ShopCounter: BasePart,
	OrdersPrompt: ProximityPrompt,
	OrdersBoard: BasePart,
	Leaderboards: { [string]: BasePart }, -- board id -> the part whose +X (Right) face shows the board
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

-- A floor spot at (x, y, z) facing `direction` (default +Z, toward the town's spawn)
local function spot(x: number, y: number, z: number, direction: Vector3?): CFrame
	local position = Vector3.new(x, y, z)
	return CFrame.lookAt(position, position + (direction or Vector3.zAxis))
end

-- Lays the Blender model MapModels > <name> over the grey parts in `hide` and makes those parts invisible.
-- Returns nil (and leaves the blocks showing) if the model isn't imported.
local function dress(
	parent: Instance,
	name: string,
	floor: CFrame,
	size: number,
	hide: { any }?, -- grey parts to make invisible (any: Luau won't pass a {Part} where {BasePart} is expected)
	options: ModelFit.SpawnOptions?
): Model?
	local model = ModelFit.Spawn("MapModels", name, floor, size, parent, options)
	if model and hide then
		for _, p in hide do
			(p :: BasePart).Transparency = 1
		end
	end
	return model
end

-- Tints one named part of a model (e.g. the glowing center of a travel pad in the arena's color)
local function tint(model: Model?, partName: string, color: Color3)
	if not model then
		return
	end
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and string.find(string.lower(p.Name), string.lower(partName), 1, true) then
			p.Color = color
			p.Material = Enum.Material.Neon
		end
	end
end

-- Lines a fence block with fence-segment models about `step` studs long, then hides the block
-- (it stays as the invisible wall that keeps animals in).
local function dressFence(parent: Instance, name: string, fence: BasePart, step: number)
	local size = fence.Size
	local alongX = size.X >= size.Z
	local length = if alongX then size.X else size.Z
	local count = math.max(1, math.round(length / step))
	local segment = length / count
	local axis = if alongX then Vector3.xAxis else Vector3.zAxis
	local facing = if alongX then Vector3.zAxis else Vector3.xAxis
	local bottom = fence.Position - Vector3.new(0, size.Y / 2, 0)
	local first = bottom - axis * (length / 2 - segment / 2)
	for i = 0, count - 1 do
		local position = first + axis * segment * i
		if not dress(parent, name, spot(position.X, position.Y, position.Z, facing), segment) then
			return -- not imported: keep the block
		end
	end
	fence.Transparency = 1
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
	FenceModel: string?, -- MapModels fence segment to line the fence with
	FenceStep: number?, -- how long each segment is, in studs
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
		local fences = {
			block(folder, "Fence", Vector3.new(x0 - 1, y, z0 - 1), Vector3.new(x1 + 1, y + h, z0), fenceColor),
			block(folder, "Fence", Vector3.new(x0 - 1, y, z0 - 1), Vector3.new(x0, y + h, z1 + 1), fenceColor),
			block(folder, "Fence", Vector3.new(x1, y, z0 - 1), Vector3.new(x1 + 1, y + h, z1 + 1), fenceColor),
			block(folder, "Fence", Vector3.new(x0 - 1, y, z1), Vector3.new(center.X - 5, y + h, z1 + 1), fenceColor),
			block(folder, "Fence", Vector3.new(center.X + 5, y, z1), Vector3.new(x1 + 1, y + h, z1 + 1), fenceColor),
		}
		if spec.FenceModel then
			for _, fence in fences do
				dressFence(folder, spec.FenceModel, fence, spec.FenceStep or 6)
			end
		end
		local leftPost = block(
			folder,
			"GatePost",
			Vector3.new(center.X - 6, y, z1),
			Vector3.new(center.X - 5, y + 8.5, z1 + 1),
			COLORS.Stone
		)
		local rightPost = block(
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
		dress(folder, "ArenaGate", spot(center.X, y, z1 + 0.5), 12.5, { leftPost, rightPost, sign })
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
		tint(dress(folder, "TravelPad", spot(padSpot.X, padSpot.Y, padSpot.Z), 7, { pad }), "Center", COLORS.PostBlue)
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
		FenceModel = "PicketFence",
		FenceStep = 6,
	}, returnPads)
	local folder = parent:FindFirstChild("Backyard") :: Folder
	for _, at in { { -15, -25, 2.5 }, { 12, -12, 2 }, { 18, -30, 2.5 } } do
		local position = addObstacle(arena, at[1], at[2], at[3])
		local bush = part(folder, {
			Name = "Bush",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * at[3] * 2,
			Position = position + Vector3.new(0, at[3] * 0.6, 0),
			Color = COLORS.DarkGrass,
			Material = Enum.Material.Grass,
		})
		dress(folder, "Bush", spot(position.X, 0, position.Z), at[3] * 2.3, { bush })
	end
	-- Extra scenery (only if imported)
	local doghouse = addObstacle(arena, -23, -8, 3)
	if not dress(folder, "Doghouse", spot(doghouse.X, 0, doghouse.Z, Vector3.xAxis), 5.5, nil, { Solid = true }) then
		table.remove(arena.Obstacles) -- nothing there to steer around
	end
	dress(folder, "Flowerbed", spot(0, 0, -37), 12)
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
		FenceModel = "FarmFence",
		FenceStep = 7,
	}, returnPads)
	local folder = parent:FindFirstChild("Barn") :: Folder
	-- The barn itself, behind the arena
	local wall = block(folder, "BarnWall", Vector3.new(-135, 0, -64), Vector3.new(-85, 16, -52), COLORS.BarnRed)
	local roof = block(folder, "BarnRoof", Vector3.new(-137, 16, -66), Vector3.new(-83, 18, -50), COLORS.Stone)
	local barn = dress(folder, "Barn", spot(-110, 0, -70), 34, { wall, roof }, { Solid = true })
	if barn then
		ModelFit.Align(barn, Vector3.zAxis, -52) -- its front sits just behind the back fence
	end
	-- Hay bales to hide behind
	for _, at in { { -125, -35 }, { -110, -15 }, { -95, -38 }, { -100, -12 }, { -122, -10 }, { -110, -40 } } do
		local position = addObstacle(arena, at[1], at[2], 3.3)
		local bale = part(folder, {
			Name = "HayBale",
			Size = Vector3.new(5, 4, 5),
			Position = position + Vector3.new(0, 2, 0),
			Color = COLORS.Hay,
			Material = Enum.Material.Fabric,
		})
		dress(folder, "HayBale", spot(position.X, 0, position.Z), 5, { bale })
	end
	local trough = addObstacle(arena, -86, -26, 2.6)
	if not dress(folder, "Trough", spot(trough.X, 0, trough.Z, Vector3.xAxis), 5, nil, { Solid = true }) then
		table.remove(arena.Obstacles)
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
		FenceModel = "BambooFence",
		FenceStep = 6,
	}, returnPads)
	local folder = parent:FindFirstChild("Jungle") :: Folder
	for index, at in { { 82, -40 }, { 95, -20 }, { 110, -38 }, { 125, -15 }, { 132, -42 }, { 100, -8 }, { 118, -28 } } do
		local position = addObstacle(arena, at[1], at[2], 1.8)
		local trunk = part(folder, {
			Name = "Trunk",
			Size = Vector3.new(2.4, 12, 2.4),
			Position = position + Vector3.new(0, 6, 0),
			Color = COLORS.Bark,
			Material = Enum.Material.Wood,
		})
		local canopy = part(folder, {
			Name = "Canopy",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(10, 10, 10),
			Position = position + Vector3.new(0, 13, 0),
			Color = COLORS.Leaves,
			Material = Enum.Material.Grass,
			CanCollide = false,
		})
		-- Turn each tree a different way so the jungle doesn't look copy-pasted
		local turn = CFrame.Angles(0, index * 1.3, 0)
		dress(folder, "JungleTree", spot(position.X, 0, position.Z) * turn, 17, { trunk, canopy }, { ByHeight = true })
	end
	for _, at in { { 76, -12 }, { 136, -28 } } do
		local rock = addObstacle(arena, at[1], at[2], 2)
		if not dress(folder, "Rock", spot(rock.X, 0, rock.Z), 4, nil, { Solid = true }) then
			table.remove(arena.Obstacles)
		end
	end
	-- Mud pits slow you down (Material = Mud is how the client knows, even when the block is hidden)
	for _, rect in { { 84, -32, 12, 8 }, { 120, -6, 10, 8 }, { 104, -47, 14, 5 } } do
		local x, z, sx, sz = rect[1], rect[2], rect[3], rect[4]
		local mud = block(
			folder,
			"Mud",
			Vector3.new(x - sx / 2, 0, z - sz / 2),
			Vector3.new(x + sx / 2, 0.12, z + sz / 2),
			COLORS.Mud,
			{
				Material = Enum.Material.Mud,
			}
		)
		local facing = if sx >= sz then Vector3.zAxis else Vector3.xAxis
		dress(folder, "MudPuddle", spot(x, 0.02, z, facing), math.max(sx, sz), { mud })
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
		FenceModel = "RinkBoard",
		FenceStep = 10,
	}, returnPads)
	local folder = parent:FindFirstChild("IceRink") :: Folder
	for _, at in { { -30, -125 }, { 30, -125 } } do
		local position = addObstacle(arena, at[1], at[2], 2.5)
		local goal = block(
			folder,
			"Goal",
			position - Vector3.new(1.5, 0, 2.5),
			position + Vector3.new(1.5, 4, 2.5),
			COLORS.PostRed
		)
		-- Goals face the middle of the rink
		local inward = Vector3.new(-math.sign(position.X), 0, 0)
		dress(folder, "HockeyGoal", spot(position.X, 0, position.Z, inward), 5, { goal })
	end
	for _, at in { { -18, -140 }, { 18, -110 } } do
		local snowman = addObstacle(arena, at[1], at[2], 1.8)
		if not dress(folder, "Snowman", spot(snowman.X, 0, snowman.Z), 6, nil, { ByHeight = true, Solid = true }) then
			table.remove(arena.Obstacles)
		end
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
	for _, at in { { 92, -120, 3 }, { 115, -135, 3 }, { 118, -112, 3 }, { 100, -142, 2 } } do
		local position = addObstacle(arena, at[1], at[2], at[3])
		local unit = block(
			folder,
			"AirConditioner",
			position - Vector3.new(2, 0, 2),
			position + Vector3.new(2, 3, 2),
			COLORS.Metal,
			{
				Material = Enum.Material.DiamondPlate,
			}
		)
		dress(folder, "ACUnit", spot(position.X, roofY, position.Z, Vector3.xAxis), 4, { unit })
	end
	local tower = addObstacle(arena, 124, -144, 3.5)
	if not dress(folder, "WaterTower", spot(tower.X, roofY, tower.Z), 16, nil, { ByHeight = true, Solid = true }) then
		table.remove(arena.Obstacles)
	end
	local chimney = addObstacle(arena, 86, -110, 1.6)
	if not dress(folder, "Chimney", spot(chimney.X, roofY, chimney.Z), 6, nil, { ByHeight = true, Solid = true }) then
		table.remove(arena.Obstacles)
	end
	return arena
end

---------------------------------------------------------------------------------------------------
-- Town

-- Gruff: the Blender walrus if imported (AnimalModels > Gruff), else a grey ball. His cap is always a real
-- part (so a tiger breakout can knock it flying); the GruffHat model rides on it if you've imported that.
local function buildGruff(map: Instance, floor: CFrame): (BasePart, BasePart)
	local gruff = part(map, {
		Name = "Gruff",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(7, 7, 7),
		Position = floor.Position + Vector3.new(0, 3.5, 0),
		Color = COLORS.Walrus,
	})
	MapBuilder.Label(gruff, "Postmaster Gruff", 5)
	local hatSpot = floor.Position + Vector3.new(0, 7.5, 0)
	local model = ModelFit.Spawn("AnimalModels", "Gruff", floor, 6.5, map, { ByHeight = true })
	if model then
		model.Name = "GruffModel"
		gruff.Transparency = 1
		gruff.CanCollide = false
		local box, size = model:GetBoundingBox()
		hatSpot = box.Position + Vector3.new(0, size.Y / 2 + 0.3, 0)
	end
	-- Postmaster Gruff animates (bobs, turns to look at players) on each client: see src/client/Animate.luau
	gruff:SetAttribute("GruffBody", true)

	local hat = part(map, {
		Name = "GruffHat",
		Size = Vector3.new(3.5, 1, 3.5),
		CFrame = CFrame.lookAt(hatSpot, hatSpot + floor.LookVector),
		Color = COLORS.PostBlue,
	})
	local hatModel = ModelFit.Spawn("PropModels", "GruffHat", hat.CFrame * CFrame.new(0, -0.5, 0), 3.2, hat)
	if hatModel then
		hat.Transparency = 1
		-- Weld the model to the cap part only now that both are in the world (see CatchAI for why)
		for _, p in hatModel:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored = false
				p.Massless = true
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = hat
				weld.Part1 = p
				weld.Parent = p
			end
		end
	end
	return gruff, hat
end

-- The tools you can buy, laid out on a table next to the shop (decoration only, if imported)
local SHOP_DISPLAY = { "GrabbingGloves", "Sneakers", "TapeGun", "ButterflyNet", "TapeRoll", "RubberStamp" }

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
	dress(map, "SpawnPad", spot(0, 0, 45), 7, { spawn })

	-- Animal Pen counter (next to the Backyard gate)
	local counter = block(map, "PenCounter", Vector3.new(-18, 0, 6), Vector3.new(-10, 3, 8), COLORS.Wood)
	MapBuilder.Label(counter, "ANIMAL PEN", 4, COLORS.Yellow)
	local penPrompt = prompt(counter, "Choose an Animal", "Animal Pen", 0.3)
	dress(map, "PenCounter", spot(-14, 0, 7), 8.5, { counter })

	-- Post Office, facing the plaza: the building, Postmaster Gruff in front of it, his counter, and the chute.
	local building = block(map, "PostOfficeBuilding", Vector3.new(8, 0, 2), Vector3.new(28, 12, 12.5), COLORS.PostRed)
	local roof = block(map, "PostOfficeRoof", Vector3.new(7, 12, 1), Vector3.new(29, 13, 13.5), COLORS.PostBlue)
	MapBuilder.Label(building, "POST OFFICE", 8, COLORS.Yellow)
	local office = dress(map, "PostOffice", spot(18, 0, 7), 21, { building, roof }, { Solid = true })
	if office then
		ModelFit.Align(office, Vector3.zAxis, 13) -- its front door sits right behind Gruff
	end
	block(map, "PostOfficeFloor", Vector3.new(8, 0, 12.5), Vector3.new(28, 0.3, 23), COLORS.Stone)
	local gruff, gruffHat = buildGruff(map, spot(16, 0.3, 16))
	local postCounter = block(map, "Counter", Vector3.new(11, 0.3, 19), Vector3.new(21, 3.8, 21), COLORS.Wood)
	dress(map, "PostCounter", spot(16, 0.3, 20), 10.5, { postCounter })
	local chute = block(map, "MailChute", Vector3.new(23, 0.3, 18), Vector3.new(27, 5, 22), COLORS.Chute)
	MapBuilder.Label(chute, "MAIL CHUTE", 3.5, COLORS.Yellow)
	-- Hold E here to mail your bag. (Each player's client shortens the hold and swaps in their chute's model.)
	local chutePrompt = prompt(chute, "Mail Parcels", "Mail Chute", Config.Mail.ChuteById.Basic.HoldTime)
	chutePrompt.MaxActivationDistance = 12

	-- Gruff's orders board (right of the Post Office, facing the plaza)
	local board = block(map, "OrdersBoard", Vector3.new(30, 0, 16), Vector3.new(36, 7, 17), COLORS.Wood)
	MapBuilder.Label(board, "GRUFF'S ORDERS", 5, COLORS.Yellow)
	local ordersPrompt = prompt(board, "Read Orders", "Gruff's Orders", 0.2)
	dress(map, "OrdersBoard", spot(33, 0, 16.5), 6.5, { board })
	-- A letter bobbing over the board so it catches your eye (it spins on each client: Animate.luau)
	local letter = ModelFit.Spawn("PropModels", "Envelope", CFrame.new(33, 8.5, 16.5), 2, map)
	if letter then
		letter.Name = "OrdersLetter"
		letter:SetAttribute("Spin", true)
	end

	-- Supply Shop (behind the Animal Pen), with a table of the tools it sells
	local shopCounter = block(map, "ShopCounter", Vector3.new(-18, 0, 20), Vector3.new(-10, 3, 22), COLORS.PostBlue)
	MapBuilder.Label(shopCounter, "SUPPLY SHOP", 4, COLORS.Yellow)
	local shopPrompt = prompt(shopCounter, "Shop", "Boxes, Tools, Stamps", 0.2)
	dress(map, "ShopStall", spot(-14, 0, 21), 9.5, { shopCounter }, { Solid = true })
	local displayTable = block(map, "DisplayTable", Vector3.new(-8.5, 0, 20), Vector3.new(-0.5, 2.6, 22), COLORS.Wood)
	for index, name in SHOP_DISPLAY do
		local x = -8.5 + (index - 0.5) * (8 / #SHOP_DISPLAY)
		local item = ModelFit.Spawn("PropModels", name, spot(x, 2.6, 21), 1.15, displayTable)
		if item then
			item:SetAttribute("Spin", true)
		end
	end

	-- Scenery around the plaza (only if imported)
	for _, at in { { -36, 26 }, { 36, 26 }, { -36, 54 }, { 36, 54 }, { 6, 26 } } do
		dress(map, "Lamppost", spot(at[1], 0, at[2]), 9, nil, { ByHeight = true, Solid = true })
	end
	dress(map, "Bench", spot(-14, 0, 54, -Vector3.zAxis), 5, nil, { Solid = true })
	dress(map, "Bench", spot(14, 0, 54, -Vector3.zAxis), 5, nil, { Solid = true })
	dress(map, "Mailbox", spot(5, 0, 44, Vector3.xAxis), 3.5, nil, { ByHeight = true, Solid = true })
	dress(map, "Planter", spot(-28, 0, 14, Vector3.xAxis), 5, nil, { Solid = true })
	dress(map, "Planter", spot(28, 0, 44), 5, nil, { Solid = true })

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
		tint(dress(map, "TravelPad", spot(x, 0, 32), 7, { pad }), "Center", def.Color)
		travelPads[def.Id] = pad
	end

	-- Leaderboards on the west edge of the plaza, facing into town (LeaderboardService draws on them)
	local leaderboards: { [string]: BasePart } = {}
	for index, id in { "FastestTiger", "FiveStamps", "Rarest" } do
		local z = 34 + (index - 1) * 10
		local face =
			block(map, `Leaderboard_{id}`, Vector3.new(-42, 0, z - 4.5), Vector3.new(-41, 11, z + 4.5), COLORS.PostBlue)
		local stand = dress(map, "LeaderboardStand", spot(-42.5, 0, z, Vector3.xAxis), 10.5, { face })
		if stand then
			ModelFit.Align(stand, Vector3.xAxis, -41.1) -- the scores sit on the board's face
		end
		leaderboards[id] = face
	end

	local townSpot = Vector3.new(0, 3, 40)
	return {
		Leaderboards = leaderboards,
		PenPrompt = penPrompt,
		PenCounter = counter,
		Arenas = arenas,
		TownSpawn = CFrame.lookAt(townSpot, townSpot - Vector3.zAxis),
		TravelPads = travelPads,
		ReturnPads = returnPads,
		Chute = chute,
		ChutePrompt = chutePrompt,
		Gruff = gruff,
		GruffHat = gruffHat,
		ShopPrompt = shopPrompt,
		ShopCounter = shopCounter,
		OrdersPrompt = ordersPrompt,
		OrdersBoard = board,
	}
end

return MapBuilder
