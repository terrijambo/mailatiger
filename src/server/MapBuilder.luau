--!strict
-- Builds the world in code: the hub town and five themed catching arenas.
-- Every grey block that has a Blender model (ReplicatedStorage > MapModels, see README) gets that model laid
-- over it. The block stays, invisible, as the collider, the prompt holder and the name tag. Missing models
-- just leave the grey block showing, so the game always works.
--
-- Layout (top-down, ground at y = 0; the island, terraces, paths and zone themes are in Scenery.luau):
--   Hub town     plaza x -90..90, z -60..95. Spawn at the south end facing north; the Post Office (Gruff,
--                counter, chute, orders) front and center; Animal Pen west; Supply Shop east; travel pads
--                in a row at z = 18; leaderboards on the west edge
--   Zones        spread across the north of the island (see ARENA_LAYOUT), each reached by a stone path:
--                Backyard (0, -150), Barn (-160, -170), Jungle (160, -170), Ice Rink (-150, -320),
--                Rooftop (150, -320, on top of a 30-stud building with an elevator pad at its foot)
-- Every arena's gate is on its +Z side, facing town. Arena ids and tiers are in src/shared/Config/Arenas.luau.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local ModelFit = require(ReplicatedStorage.Shared.ModelFit)
local Scenery = require(script.Parent.Scenery)

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
	LiftPads: { [string]: BasePart }, -- extra pads out in the world that take you into an arena (the Rooftop elevator)
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

-- Bright, flat colors (the look of popular simulators: smooth plastic, no gritty textures)
local COLORS = {
	Grass = Color3.fromRGB(122, 204, 92),
	DarkGrass = Color3.fromRGB(88, 178, 74),
	Dirt = Color3.fromRGB(214, 168, 112),
	Stone = Color3.fromRGB(170, 168, 164), -- plaza paving (grey stone)
	Wood = Color3.fromRGB(196, 136, 84),
	Yellow = Color3.fromRGB(255, 220, 90),
	PostRed = Color3.fromRGB(226, 72, 66),
	PostBlue = Color3.fromRGB(70, 120, 225),
	Chute = Color3.fromRGB(60, 62, 75),
	Walrus = Color3.fromRGB(150, 125, 110),
	Hay = Color3.fromRGB(252, 214, 104),
	BarnRed = Color3.fromRGB(214, 66, 58),
	Bark = Color3.fromRGB(150, 100, 64),
	Leaves = Color3.fromRGB(96, 196, 84),
	Mud = Color3.fromRGB(140, 96, 64),
	Ice = Color3.fromRGB(214, 242, 255),
	White = Color3.fromRGB(250, 250, 250),
	Concrete = Color3.fromRGB(186, 190, 202),
	Metal = Color3.fromRGB(196, 200, 212),
}

-- The plaza's material. SmoothPlastic gives flat grey tiles; try Enum.Material.Quartz (or Marble, Slate)
-- for a stone texture instead.
local PLAZA_MATERIAL = Enum.Material.SmoothPlastic

-- Everything is smooth plastic except materials that matter: Ice (you slide), Mud (slows you),
-- Neon (glows) and Glass (see-through)
local KEEP_MATERIAL = {
	[Enum.Material.Ice] = true,
	[Enum.Material.Mud] = true,
	[Enum.Material.Neon] = true,
	[Enum.Material.Glass] = true,
	[Enum.Material.ForceField] = true,
}

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	if not KEEP_MATERIAL[p.Material] and p.Material ~= PLAZA_MATERIAL then
		p.Material = Enum.Material.SmoothPlastic
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
	if model then
		-- e.g. "PenCounterArt": never the same name as the grey part it covers, so code that looks a part
		-- up by name (like the tutorial arrow) always finds the part
		model.Name = `{name}Art`
	end
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

-- A small floating name tag: white text with a dark outline (like "Tiny House $15K" in popular sims).
-- It only shows when you're fairly close, so the town isn't a wall of text.
function MapBuilder.Label(adornee: BasePart, text: string, height: number, color: Color3?)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(190, 30)
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.MaxDistance = 70

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = if color and color ~= COLORS.Yellow then color else Color3.new(1, 1, 1)
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(25, 22, 30)
	stroke.Parent = label

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
		Vector3.new(spec.MaxX, y + 0.1, spec.MaxZ),
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
		dress(folder, "ArenaGate", spot(center.X, y, z1 + 0.5), 12.5, { leftPost, rightPost, sign })
		-- Land just outside the gate, facing in
		local landing = Vector3.new(center.X, y + 3, z1 + 6)
		gate = CFrame.lookAt(landing, landing - Vector3.zAxis)
		block(
			folder,
			"GatePath",
			Vector3.new(center.X - 5, y - 0.5, z1),
			Vector3.new(center.X + 5, y + 0.02, z1 + 12),
			COLORS.Stone
		)
	else
		-- No fence: land on the roof itself
		local landing = Vector3.new(center.X, y + 3, spec.MaxZ - 4)
		gate = CFrame.lookAt(landing, landing - Vector3.zAxis)
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

	-- Pad back to town, just to the right of where you arrive
	do
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

-- Where each arena sits: its center, and half its width (X) and depth (Z). Arenas are spread out around the
-- north of the island as themed zones, each reached by a path from town (or a travel pad).
local ARENA_LAYOUT: { [string]: { Center: Vector3, HalfX: number, HalfZ: number } } = {
	Backyard = { Center = Vector3.new(0, 0, -150), HalfX = 30, HalfZ = 20 },
	Barn = { Center = Vector3.new(-160, 0, -170), HalfX = 30, HalfZ = 25 },
	Jungle = { Center = Vector3.new(160, 0, -170), HalfX = 35, HalfZ = 25 },
	IceRink = { Center = Vector3.new(-150, 0, -320), HalfX = 40, HalfZ = 25 },
	Rooftop = { Center = Vector3.new(150, 0, -320), HalfX = 25, HalfZ = 25 },
}

-- The spec for an arena from its layout entry
local function around(id: string, floorY: number): (number, number, number, number, Vector3)
	local l = ARENA_LAYOUT[id]
	local c = l.Center
	return c.X - l.HalfX, c.X + l.HalfX, c.Z - l.HalfZ, c.Z + l.HalfZ, c + Vector3.new(0, floorY, 0)
end

local function buildBackyard(parent: Instance, returnPads: { BasePart }): Arena
	local x0, x1, z0, z1, c = around("Backyard", 0)
	local arena = buildArena(parent, {
		Id = "Backyard",
		MinX = x0,
		MaxX = x1,
		MinZ = z0,
		MaxZ = z1,
		FloorY = 0,
		FloorColor = COLORS.Grass,
		FloorMaterial = Enum.Material.Grass,
		FenceColor = COLORS.Wood,
		FenceModel = "PicketFence",
		FenceStep = 9, -- segment lengths make each fence about 3 studs tall (sizes: art/blender_scripts)
	}, returnPads)
	local folder = parent:FindFirstChild("Backyard") :: Folder
	-- (spots are relative to the arena's center)
	for _, at in { { -15, -5, 2.5 }, { 12, 8, 2 }, { 18, -10, 2.5 } } do
		local position = addObstacle(arena, c.X + at[1], c.Z + at[2], at[3])
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
	local doghouse = addObstacle(arena, c.X - 23, c.Z + 12, 3)
	if not dress(folder, "Doghouse", spot(doghouse.X, 0, doghouse.Z, Vector3.xAxis), 5.5, nil, { Solid = true }) then
		table.remove(arena.Obstacles) -- nothing there to steer around
	end
	dress(folder, "Flowerbed", spot(c.X, 0, c.Z - 17), 12)
	return arena
end

local function buildBarn(parent: Instance, returnPads: { BasePart }): Arena
	local x0, x1, z0, z1, c = around("Barn", 0)
	local arena = buildArena(parent, {
		Id = "Barn",
		MinX = x0,
		MaxX = x1,
		MinZ = z0,
		MaxZ = z1,
		FloorY = 0,
		FloorColor = COLORS.Dirt,
		FloorMaterial = Enum.Material.Ground,
		FenceColor = COLORS.BarnRed,
		FenceModel = "FarmFence",
		FenceStep = 8,
	}, returnPads)
	local folder = parent:FindFirstChild("Barn") :: Folder
	-- The barn itself, behind the arena
	local wall =
		block(folder, "BarnWall", Vector3.new(c.X - 25, 0, z0 - 14), Vector3.new(c.X + 25, 16, z0 - 2), COLORS.BarnRed)
	local roof =
		block(folder, "BarnRoof", Vector3.new(c.X - 27, 16, z0 - 16), Vector3.new(c.X + 27, 18, z0), COLORS.Stone)
	local barn = dress(folder, "Barn", spot(c.X, 0, z0 - 20), 28, { wall, roof }, { Solid = true })
	if barn then
		ModelFit.Align(barn, Vector3.zAxis, z0 - 2) -- its front sits just behind the back fence
	end
	-- Hay bales to hide behind
	for _, at in { { -15, -10 }, { 0, 10 }, { 15, -13 }, { 10, 13 }, { -12, 15 }, { 0, -15 } } do
		local position = addObstacle(arena, c.X + at[1], c.Z + at[2], 3.3)
		local bale = part(folder, {
			Name = "HayBale",
			Size = Vector3.new(5, 4, 5),
			Position = position + Vector3.new(0, 2, 0),
			Color = COLORS.Hay,
			Material = Enum.Material.Fabric,
		})
		dress(folder, "HayBale", spot(position.X, 0, position.Z), 5, { bale })
	end
	local trough = addObstacle(arena, c.X + 24, c.Z - 1, 2.6)
	if not dress(folder, "Trough", spot(trough.X, 0, trough.Z, Vector3.xAxis), 5, nil, { Solid = true }) then
		table.remove(arena.Obstacles)
	end
	return arena
end

local function buildJungle(parent: Instance, returnPads: { BasePart }): Arena
	local x0, x1, z0, z1, c = around("Jungle", 0)
	local arena = buildArena(parent, {
		Id = "Jungle",
		MinX = x0,
		MaxX = x1,
		MinZ = z0,
		MaxZ = z1,
		FloorY = 0,
		FloorColor = COLORS.DarkGrass,
		FloorMaterial = Enum.Material.LeafyGrass,
		FenceColor = COLORS.Bark,
		FenceModel = "BambooFence",
		FenceStep = 8,
	}, returnPads)
	local folder = parent:FindFirstChild("Jungle") :: Folder
	for index, at in { { -23, -15 }, { -10, 5 }, { 5, -13 }, { 20, 10 }, { 27, -17 }, { -5, 17 }, { 13, -3 } } do
		local position = addObstacle(arena, c.X + at[1], c.Z + at[2], 1.8)
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
	for _, at in { { -29, 13 }, { 31, -3 } } do
		local rock = addObstacle(arena, c.X + at[1], c.Z + at[2], 2)
		if not dress(folder, "Rock", spot(rock.X, 0, rock.Z), 4, nil, { Solid = true }) then
			table.remove(arena.Obstacles)
		end
	end
	-- Mud pits slow you down (Material = Mud is how the client knows, even when the block is hidden)
	for _, rect in { { -21, -7, 12, 8 }, { 15, 19, 10, 8 }, { -1, -22, 14, 5 } } do
		local x, z, sx, sz = c.X + rect[1], c.Z + rect[2], rect[3], rect[4]
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
		-- The puddle model is round, so a long strip gets a row of puddles
		local long, short = math.max(sx, sz), math.min(sx, sz)
		local count = math.max(1, math.round(long / short))
		local axis = if sx >= sz then Vector3.xAxis else Vector3.zAxis
		local step = long / count
		for i = 0, count - 1 do
			local at = Vector3.new(x, 0.02, z) + axis * (-long / 2 + step * (i + 0.5))
			local turn = CFrame.Angles(0, i * 2.1, 0)
			if not dress(folder, "MudPuddle", spot(at.X, at.Y, at.Z) * turn, math.max(step, short) * 1.1, { mud }) then
				break
			end
		end
	end
	return arena
end

local function buildIceRink(parent: Instance, returnPads: { BasePart }): Arena
	local x0, x1, z0, z1, c = around("IceRink", 0)
	local arena = buildArena(parent, {
		Id = "IceRink",
		MinX = x0,
		MaxX = x1,
		MinZ = z0,
		MaxZ = z1,
		FloorY = 0,
		FloorColor = COLORS.Ice,
		FloorMaterial = Enum.Material.Ice, -- the client makes you slide on Ice
		FenceColor = COLORS.White,
		FenceModel = "RinkBoard",
		FenceStep = 9,
	}, returnPads)
	local folder = parent:FindFirstChild("IceRink") :: Folder
	for _, dx in { -30, 30 } do
		local position = addObstacle(arena, c.X + dx, c.Z, 2.5)
		local goal = block(
			folder,
			"Goal",
			position - Vector3.new(1.5, 0, 2.5),
			position + Vector3.new(1.5, 4, 2.5),
			COLORS.PostRed
		)
		-- Goals face the middle of the rink
		local inward = Vector3.new(-math.sign(dx), 0, 0)
		dress(folder, "HockeyGoal", spot(position.X, 0, position.Z, inward), 5, { goal })
	end
	for _, at in { { -18, -15 }, { 18, 15 } } do
		local snowman = addObstacle(arena, c.X + at[1], c.Z + at[2], 1.8)
		if not dress(folder, "Snowman", spot(snowman.X, 0, snowman.Z), 6, nil, { ByHeight = true, Solid = true }) then
			table.remove(arena.Obstacles)
		end
	end
	return arena
end

local ROOF_Y = 30

local function buildRooftop(parent: Instance, returnPads: { BasePart }): Arena
	local roofY = ROOF_Y
	local x0, x1, z0, z1, c = around("Rooftop", roofY)
	block(parent, "RooftopBuilding", Vector3.new(x0, 0, z0), Vector3.new(x1, roofY - 0.5, z1), COLORS.Concrete)
	local arena = buildArena(parent, {
		Id = "Rooftop",
		MinX = x0,
		MaxX = x1,
		MinZ = z0,
		MaxZ = z1,
		FloorY = roofY,
		FloorColor = COLORS.Concrete,
		FloorMaterial = Enum.Material.Concrete,
		FenceColor = nil, -- no fence. Edges!
	}, returnPads)
	local folder = parent:FindFirstChild("Rooftop") :: Folder
	for _, at in { { -13, 5, 3 }, { 10, -10, 3 }, { 13, 13, 3 }, { -5, -17, 2 } } do
		local position = addObstacle(arena, c.X + at[1], c.Z + at[2], at[3])
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
	local tower = addObstacle(arena, c.X + 19, c.Z - 19, 3.5)
	if not dress(folder, "WaterTower", spot(tower.X, roofY, tower.Z), 16, nil, { ByHeight = true, Solid = true }) then
		table.remove(arena.Obstacles)
	end
	local chimney = addObstacle(arena, c.X - 19, c.Z + 15, 1.6)
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
	-- 2.5 wide: the cap was modeled for Gruff at Blender size, and he's scaled up ~1.75x here
	local hatModel = ModelFit.Spawn("PropModels", "GruffHat", hat.CFrame * CFrame.new(0, -0.5, 0), 2.5, hat)
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

-- The hub plaza (everything in town faces +Z, toward the spawn at the south end)
local PLAZA_MIN = Vector3.new(-90, 0, -60)
local PLAZA_MAX = Vector3.new(90, 0, 95)
-- Emoji on each zone's entrance banner
local ZONE_ICONS: { [string]: string } = {
	Backyard = "🏡",
	Barn = "🐔",
	Jungle = "🌴",
	IceRink = "❄️",
	Rooftop = "🏙️",
}
function MapBuilder.Build(): Map
	local existing = Workspace:FindFirstChild("GrayboxMap")
	if existing then
		existing:Destroy()
	end
	local map = Instance.new("Folder")
	map.Name = "GrayboxMap"
	map.Parent = Workspace

	-- Hub town plaza + spawn (the island itself is terrain, made in Scenery.luau)
	block(map, "Plaza", PLAZA_MIN - Vector3.new(0, 0.2, 0), PLAZA_MAX + Vector3.new(0, 0.1, 0), COLORS.Stone, {
		Material = PLAZA_MATERIAL,
	})
	-- Big paving tiles: darker grout lines every 12 studs, and a darker stone border around the edge
	local grout = Color3.fromRGB(140, 138, 134)
	local plazaSize = PLAZA_MAX - PLAZA_MIN
	local plazaCenter = (PLAZA_MIN + PLAZA_MAX) / 2
	for x = PLAZA_MIN.X + 12, PLAZA_MAX.X - 1, 12 do
		part(map, {
			Name = "Grout",
			Size = Vector3.new(0.4, 0.04, plazaSize.Z),
			Position = Vector3.new(x, 0.12, plazaCenter.Z),
			Color = grout,
			CanCollide = false,
		})
	end
	for z = PLAZA_MIN.Z + 12, PLAZA_MAX.Z - 1, 12 do
		part(map, {
			Name = "Grout",
			Size = Vector3.new(plazaSize.X, 0.04, 0.4),
			Position = Vector3.new(plazaCenter.X, 0.12, z),
			Color = grout,
			CanCollide = false,
		})
	end
	for _, edge in
		{
			{ Vector3.new(plazaCenter.X, 0, PLAZA_MIN.Z + 1.5), Vector3.new(plazaSize.X, 0.3, 3) },
			{ Vector3.new(plazaCenter.X, 0, PLAZA_MAX.Z - 1.5), Vector3.new(plazaSize.X, 0.3, 3) },
			{ Vector3.new(PLAZA_MIN.X + 1.5, 0, plazaCenter.Z), Vector3.new(3, 0.3, plazaSize.Z) },
			{ Vector3.new(PLAZA_MAX.X - 1.5, 0, plazaCenter.Z), Vector3.new(3, 0.3, plazaSize.Z) },
		}
	do
		part(map, {
			Name = "PlazaBorder",
			Size = edge[2],
			Position = edge[1] + Vector3.new(0, 0.05, 0),
			Color = Color3.fromRGB(128, 126, 124),
		})
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = Vector3.new(0, 0.5, 72)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = COLORS.PostBlue
	spawn.Parent = map
	dress(map, "SpawnPad", spot(0, 0, 72), 7, { spawn })

	-- Post Office, front and center: the building, Postmaster Gruff in front of it, his counter, and the chute.
	local building =
		block(map, "PostOfficeBuilding", Vector3.new(-10, 0, -44), Vector3.new(10, 12, -30), COLORS.PostRed)
	local roof = block(map, "PostOfficeRoof", Vector3.new(-11, 12, -45), Vector3.new(11, 13, -29), COLORS.PostBlue)
	-- (no floating name: the giant MAIL A TIGER sign sits over the Post Office)
	-- The building model is deep (14 studs at this size), so it's 18 wide with its front at z = -30
	local office = dress(map, "PostOffice", spot(0, 0, -37), 18, { building, roof }, { Solid = true })
	if office then
		ModelFit.Align(office, Vector3.zAxis, -30) -- its front door sits right behind Gruff
	end
	block(map, "PostOfficeFloor", Vector3.new(-12, 0, -30), Vector3.new(14, 0.3, -19), COLORS.Stone)
	local gruff, gruffHat = buildGruff(map, spot(-2, 0.3, -27))
	local postCounter = block(map, "Counter", Vector3.new(-7, 0.3, -24), Vector3.new(3, 3.8, -22), COLORS.Wood)
	dress(map, "PostCounter", spot(-2, 0.3, -23), 10.5, { postCounter })
	local chute = block(map, "MailChute", Vector3.new(5, 0.3, -25), Vector3.new(9, 5, -21), COLORS.Chute)
	MapBuilder.Label(chute, "MAIL CHUTE", 3.5, COLORS.Yellow)
	-- Hold E here to mail your bag. (Each player's client shortens the hold and swaps in their chute's model.)
	local chutePrompt = prompt(chute, "Mail Parcels", "Mail Chute", Config.Mail.ChuteById.Basic.HoldTime)
	chutePrompt.MaxActivationDistance = 12

	-- Gruff's orders board (right of the Post Office)
	local board = block(map, "OrdersBoard", Vector3.new(12, 0, -28), Vector3.new(18, 7, -27), COLORS.Wood)
	MapBuilder.Label(board, "GRUFF'S ORDERS", 5, COLORS.Yellow)
	local ordersPrompt = prompt(board, "Read Orders", "Gruff's Orders", 0.2)
	dress(map, "OrdersBoard", spot(15, 0, -27.5), 6.5, { board })
	-- A letter bobbing over the board so it catches your eye (it spins on each client: Animate.luau)
	local letter = ModelFit.Spawn("PropModels", "Envelope", CFrame.new(15, 8.5, -27.5), 2, map)
	if letter then
		letter.Name = "OrdersLetter"
		letter:SetAttribute("Spin", true)
	end

	-- Animal Pen (west side of the plaza)
	local counter = block(map, "PenCounter", Vector3.new(-44, 0, -12), Vector3.new(-36, 3, -10), COLORS.Wood)
	MapBuilder.Label(counter, "ANIMAL PEN", 4, COLORS.Yellow)
	local penPrompt = prompt(counter, "Choose an Animal", "Animal Pen", 0.3)
	dress(map, "PenCounter", spot(-40, 0, -11), 8.5, { counter })

	-- Supply Shop (east side), with a table of the tools it sells
	local shopCounter = block(map, "ShopCounter", Vector3.new(36, 0, -12), Vector3.new(44, 3, -10), COLORS.PostBlue)
	MapBuilder.Label(shopCounter, "SUPPLY SHOP", 4, COLORS.Yellow)
	local shopPrompt = prompt(shopCounter, "Shop", "Boxes, Tools, Stamps", 0.2)
	dress(map, "ShopStall", spot(40, 0, -11), 9.5, { shopCounter }, { Solid = true })
	local displayTable = block(map, "DisplayTable", Vector3.new(47, 0, -12), Vector3.new(55, 2.6, -10), COLORS.Wood)
	for index, name in SHOP_DISPLAY do
		local x = 47 + (index - 0.5) * (8 / #SHOP_DISPLAY)
		local item = ModelFit.Spawn("PropModels", name, spot(x, 2.6, -11), 1.25, displayTable)
		if item then
			item:SetAttribute("Spin", true)
		end
	end

	-- Scenery right around the counters (only if imported)
	for _, at in { { -16, -18 }, { 22, -18 }, { -50, -4 }, { 50, -4 } } do
		dress(map, "Lamppost", spot(at[1], 0, at[2]), 9, nil, { ByHeight = true, Solid = true })
	end
	dress(map, "Bench", spot(-16, 0, 48, Vector3.xAxis), 5, nil, { Solid = true })
	dress(map, "Bench", spot(16, 0, 48, -Vector3.xAxis), 5, nil, { Solid = true })
	dress(map, "Mailbox", spot(6, 0, 70, -Vector3.zAxis), 3.5, nil, { ByHeight = true, Solid = true })
	dress(map, "Planter", spot(-26, 0, -18), 5, nil, { Solid = true })
	dress(map, "Planter", spot(30, 0, -18), 5, nil, { Solid = true })

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

	-- The Rooftop can't be walked up to, so its street has an elevator pad up to the roof
	local liftPads: { [string]: BasePart } = {}
	do
		local l = ARENA_LAYOUT.Rooftop
		local at = l.Center + Vector3.new(0, 0, l.HalfZ + 5)
		local pad = part(map, {
			Name = "ElevatorPad",
			Size = Vector3.new(6, 1, 6),
			Position = at + Vector3.new(0, 0.5, 0),
			Color = Config.Arenas.ById.Rooftop.Color,
			Material = Enum.Material.Neon,
		})
		MapBuilder.Label(pad, "ELEVATOR TO THE ROOF", 3, COLORS.Yellow)
		tint(dress(map, "TravelPad", spot(at.X, 0, at.Z), 7, { pad }), "Center", Config.Arenas.ById.Rooftop.Color)
		liftPads.Rooftop = pad
	end

	-- Travel pads in town: one per arena, in a row across the plaza (walking there works too)
	local travelPads: { [string]: BasePart } = {}
	for index, def in Config.Arenas.List do
		local x = -40 + (index - 1) * 20
		local pad = part(map, {
			Name = `TravelPad_{def.Id}`,
			Size = Vector3.new(6, 1, 6),
			Position = Vector3.new(x, 0.5, 18),
			Color = def.Color,
			Material = Enum.Material.Neon,
		})
		local tiers = table.concat(def.Tiers, "&")
		MapBuilder.Label(pad, `{string.upper(def.DisplayName)} · T{tiers}`, 2.5, COLORS.Yellow)
		tint(dress(map, "TravelPad", spot(x, 0, 18), 7, { pad }), "Center", def.Color)
		travelPads[def.Id] = pad
	end

	-- Leaderboards on the west edge of the plaza, facing into town (LeaderboardService draws on them)
	local LEADERBOARD_X = -79.1 -- where the boards' faces are
	local leaderboards: { [string]: BasePart } = {}
	for index, id in { "FastestTiger", "FiveStamps", "Rarest" } do
		local z = 12 + (index - 1) * 12
		local x = LEADERBOARD_X
		local face =
			block(map, `Leaderboard_{id}`, Vector3.new(x - 1, 0, z - 4.5), Vector3.new(x, 11, z + 4.5), COLORS.PostBlue)
		local stand = dress(map, "LeaderboardStand", spot(x - 1.5, 0, z, Vector3.xAxis), 9.5, { face })
		if stand then
			ModelFit.Align(stand, Vector3.xAxis, x)
			-- Shrink the (invisible) score part to fit exactly on the stand's dark board. The numbers come
			-- from art/blender_scripts/town.py: the stand is 9 wide, its board 8.2 x 7.6 centered 4.6 up,
			-- set 0.63 back from the front of the plinth.
			local _, size = stand:GetBoundingBox()
			local k = math.max(size.X, size.Z) / 9
			face.Size = Vector3.new(0.2, 7.6 * k, 8.2 * k)
			face.Position = Vector3.new(x - 0.63 * k - 0.08, 4.6 * k, z)
		end
		leaderboards[id] = face
	end

	-- Lock barriers: a shimmering wall across the front of each zone that isn't open yet, with the level it
	-- opens at. Each player's client hides the ones they've unlocked (ZoneLocks.luau). The server does the
	-- actual keeping-out (Travel.luau), so these don't block anything by themselves.
	for _, def in Config.Arenas.List do
		local l = ARENA_LAYOUT[def.Id]
		local need = Config.Levels.ZoneLevels[def.Id] or 1
		if l and need > 1 then
			local front = l.Center.Z + l.HalfZ + (if def.Id == "Rooftop" then 9 else 8)
			local width = l.HalfX * 2 + 24
			local wall = part(map, {
				Name = `ZoneLock_{def.Id}`,
				Size = Vector3.new(width, 14, 0.6),
				Position = Vector3.new(l.Center.X, 7, front),
				Color = Color3.fromRGB(255, 120, 90),
				Material = Enum.Material.ForceField,
				CanCollide = false,
				CanQuery = false,
			})
			wall:SetAttribute("ArenaId", def.Id)
			wall:SetAttribute("Level", need)
			CollectionService:AddTag(wall, "ZoneLock")
			local sign = part(map, {
				Name = "ZoneLockSign",
				Size = Vector3.new(16, 5, 0.4),
				Position = Vector3.new(l.Center.X, 6, front + 0.6),
				Color = Color3.fromRGB(40, 30, 30),
				CanCollide = false,
				CanQuery = false,
			})
			sign:SetAttribute("ArenaId", def.Id)
			sign:SetAttribute("Level", need)
			CollectionService:AddTag(sign, "ZoneLock")
			local gui = Instance.new("SurfaceGui")
			gui.Face = Enum.NormalId.Back -- facing town (+Z)
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 40
			gui.LightInfluence = 0
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.LuckiestGuy
			label.TextScaled = true
			label.TextWrapped = false
			label.TextColor3 = Color3.fromRGB(255, 220, 90)
			label.Text = `🔒 LEVEL {need}`
			label.Parent = gui
			local stroke = Instance.new("UIStroke")
			stroke.Thickness = 4
			stroke.Parent = label
			gui.Parent = sign
		end
	end

	-- Everything that's just for looks: the island, ocean, terraces, paths, zone themes
	local zones: { Scenery.Zone } = {}
	for _, def in Config.Arenas.List do
		local l = ARENA_LAYOUT[def.Id]
		if l then
			local gateZ = l.Center.Z + l.HalfZ + (if def.Id == "Rooftop" then 2 else 0)
			table.insert(zones, {
				Id = def.Id,
				Name = def.DisplayName,
				Color = def.Color,
				Icon = ZONE_ICONS[def.Id] or "",
				Center = l.Center,
				HalfX = l.HalfX,
				HalfZ = l.HalfZ,
				FloorY = if def.Id == "Rooftop" then ROOF_Y else 0,
				Gate = Vector3.new(l.Center.X, 0, gateZ),
			})
		end
	end
	Scenery.Build(map, { PlazaMin = PLAZA_MIN, PlazaMax = PLAZA_MAX, Zones = zones })

	local townSpot = Vector3.new(0, 3, 66)
	return {
		Leaderboards = leaderboards,
		PenPrompt = penPrompt,
		PenCounter = counter,
		Arenas = arenas,
		TownSpawn = CFrame.lookAt(townSpot, townSpot - Vector3.zAxis),
		TravelPads = travelPads,
		LiftPads = liftPads,
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
