--!strict
-- Builds the gameplay side of the world in code: the town's counters and the five catching zones. Where
-- everything sits comes from src/shared/Config/World.luau (an archipelago: a round town plaza on a cliff
-- island in the middle, themed islands around it, wooden bridges between). The islands, cliffs, sea,
-- bridges and all the decoration are in server/Scenery.
-- Every grey block that has a Blender model (ReplicatedStorage > MapModels, see README) gets that model laid
-- over it. The block stays, invisible, as the collider, the prompt holder and the name tag. Missing models
-- just leave the grey block showing, so the game always works.
--
-- Town (ground y = 0, the fountain at the very middle): the Post Office with Gruff, his counter, the Mail
-- Chute and the orders board on the north side; the Supply Shop east; the Animal Pen counter southwest; the
-- leaderboards west; the spawn south, facing the fountain.
-- Zones: a fenced play area in the middle of each island, its gate on the side facing town (World.Gate).
-- The Rooftop's play area is up on a 30-stud building, with an elevator pad at its foot.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local ModelFit = require(ReplicatedStorage.Shared.ModelFit)
local SignText = require(ReplicatedStorage.Shared.SignText)
local Scenery = require(script.Parent.Scenery)

local World = Config.World

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
	TravelPads: { [string]: BasePart }, -- (none any more: MENU > TRAVEL)
	LiftPads: { [string]: BasePart }, -- pads out in the world that take you into an arena (the Rooftop elevator)
	ReturnPads: { BasePart }, -- (none any more)
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
	Grass = Color3.fromRGB(104, 184, 78),
	DarkGrass = Color3.fromRGB(66, 150, 66),
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
	Leaves = Color3.fromRGB(70, 162, 70),
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
-- widthStuds: size it in the world instead of on screen, so it shrinks with distance (labels standing
-- side by side, like the travel pads, then never overlap each other)
function MapBuilder.Label(adornee: BasePart, text: string, height: number, color: Color3?, widthStuds: number?)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = if widthStuds then UDim2.fromScale(widthStuds, widthStuds * 0.16) else UDim2.fromOffset(190, 30)
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
-- Arenas, laid out in each zone's own frame: u runs across the gate (left to right as you walk in), w runs
-- toward the gate (the gate is at w = +HW, the far side at w = -HW). World.Gate picks which way that is.

type Frame = {
	Id: string,
	C: Vector3, -- the play area's center (ground level)
	F: Vector3, -- toward the gate / town
	R: Vector3, -- across, to the right as you look out of the gate... (any consistent side works)
	HU: number, -- half the play area across
	HW: number, -- half the play area along
}

local function frameOf(id: string): Frame
	local island = World.ById[id]
	local f = island.Gate or Vector3.zAxis
	local play = island.Play or Vector2.new(30, 25)
	return {
		Id = id,
		C = island.Center,
		F = f,
		R = Vector3.new(0, 1, 0):Cross(f),
		HU = play.X,
		HW = play.Y,
	}
end

-- A world point from frame coordinates (y is absolute)
local function L(fr: Frame, u: number, w: number, y: number?): Vector3
	return fr.C + fr.R * u + fr.F * w + Vector3.new(0, y or 0, 0)
end

-- A block between two frame corners (u0, w0) - (u1, w1), from y0 to y1
local function lbox(
	parent: Instance,
	name: string,
	fr: Frame,
	u0: number,
	w0: number,
	u1: number,
	w1: number,
	y0: number,
	y1: number,
	color: Color3,
	extra: { [string]: any }?
): Part
	local a, b = L(fr, u0, w0), L(fr, u1, w1)
	return block(
		parent,
		name,
		Vector3.new(math.min(a.X, b.X), y0, math.min(a.Z, b.Z)),
		Vector3.new(math.max(a.X, b.X), y1, math.max(a.Z, b.Z)),
		color,
		extra
	)
end

-- A floor spot in frame coordinates, facing `direction` (default: toward the gate)
local function lspot(fr: Frame, u: number, w: number, y: number, direction: Vector3?): CFrame
	local p = L(fr, u, w, y)
	return spot(p.X, p.Y, p.Z, direction or fr.F)
end

type ArenaSpec = {
	Frame: Frame,
	FloorY: number,
	FloorColor: Color3,
	FloorMaterial: Enum.Material,
	FenceColor: Color3?, -- nil = no fence (edges!)
	FenceModel: string?, -- MapModels fence segment to line the fence with
	FenceStep: number?, -- how long each segment is, in studs
}

-- Floor, a fence with a gate on the town side, and a sign
local function buildArena(parent: Instance, spec: ArenaSpec): Arena
	local fr = spec.Frame
	local folder = Instance.new("Folder")
	folder.Name = fr.Id
	folder.Parent = parent

	local y = spec.FloorY
	local hu, hw = fr.HU, fr.HW
	local def = Config.Arenas.ById[fr.Id]
	local floor = lbox(folder, "Floor", fr, -hu, -hw, hu, hw, y - 0.5, y + 0.1, spec.FloorColor, {
		Material = spec.FloorMaterial,
	})

	local gate: CFrame
	local fenceColor = spec.FenceColor
	if fenceColor then
		local h = 4
		local fences = {
			lbox(folder, "Fence", fr, -hu - 1, -hw - 1, hu + 1, -hw, y, y + h, fenceColor),
			lbox(folder, "Fence", fr, -hu - 1, -hw - 1, -hu, hw + 1, y, y + h, fenceColor),
			lbox(folder, "Fence", fr, hu, -hw - 1, hu + 1, hw + 1, y, y + h, fenceColor),
			lbox(folder, "Fence", fr, -hu - 1, hw, -5, hw + 1, y, y + h, fenceColor),
			lbox(folder, "Fence", fr, 5, hw, hu + 1, hw + 1, y, y + h, fenceColor),
		}
		if spec.FenceModel then
			for _, fence in fences do
				dressFence(folder, spec.FenceModel, fence, spec.FenceStep or 6)
			end
		end
		local leftPost = lbox(folder, "GatePost", fr, -6, hw, -5, hw + 1, y, y + 8.5, COLORS.Stone)
		local rightPost = lbox(folder, "GatePost", fr, 5, hw, 6, hw + 1, y, y + 8.5, COLORS.Stone)
		local sign = lbox(folder, "GateSign", fr, -5, hw, 5, hw + 1, y + 7, y + 8.5, def.Color)
		dress(folder, "ArenaGate", lspot(fr, 0, hw + 0.5, y), 12.5, { leftPost, rightPost, sign })
		-- Land just outside the gate, facing in
		local landing = L(fr, 0, hw + 6, y + 3)
		gate = CFrame.lookAt(landing, landing - fr.F)
		lbox(folder, "GatePath", fr, -5, hw, 5, hw + 12, y - 0.5, y + 0.02, COLORS.Stone)
	else
		-- No fence: land on the roof itself
		local landing = L(fr, 0, hw - 4, y + 3)
		gate = CFrame.lookAt(landing, landing - fr.F)
		local sign = lbox(folder, "Sign", fr, -5, hw - 1, 5, hw, y + 7, y + 8.5, def.Color)
		MapBuilder.Label(sign, string.upper(def.DisplayName), 2, COLORS.Yellow)
		lbox(folder, "SignPost", fr, -0.5, hw - 1, 0.5, hw, y, y + 7, COLORS.Stone)
	end

	local min = floor.Position - floor.Size / 2
	local max = floor.Position + floor.Size / 2
	return {
		Id = fr.Id,
		Min = Vector3.new(min.X, y, min.Z),
		Max = Vector3.new(max.X, y, max.Z),
		Center = L(fr, 0, 0, y),
		FloorY = y,
		Gate = gate,
		Obstacles = {},
		Edges = fenceColor == nil,
	}
end

-- Adds a round-ish obstacle to an arena (for the AI) at frame coordinates, and returns its position
local function addObstacle(arena: Arena, fr: Frame, u: number, w: number, radius: number): Vector3
	local position = L(fr, u, w, arena.FloorY)
	table.insert(arena.Obstacles, { Center = position, Radius = radius })
	return position
end

local function buildBackyard(parent: Instance): Arena
	local fr = frameOf("Backyard")
	local arena = buildArena(parent, {
		Frame = fr,
		FloorY = 0,
		FloorColor = COLORS.Grass,
		FloorMaterial = Enum.Material.Grass,
		FenceColor = COLORS.Wood,
		FenceModel = "PicketFence",
		FenceStep = 9, -- segment lengths make each fence about 3 studs tall (sizes: art/blender_scripts)
	})
	local folder = parent:FindFirstChild("Backyard") :: Folder
	for _, at in { { -15, -5, 2.5 }, { 12, 8, 2 }, { 18, -10, 2.5 }, { -24, 14, 2 } } do
		local position = addObstacle(arena, fr, at[1], at[2], at[3])
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
	local doghouse = addObstacle(arena, fr, -26, 16, 3)
	if not dress(folder, "Doghouse", spot(doghouse.X, 0, doghouse.Z, fr.R), 5.5, nil, { Solid = true }) then
		table.remove(arena.Obstacles) -- nothing there to steer around
	end
	dress(folder, "Flowerbed", lspot(fr, 0, -20, 0), 12)
	return arena
end

local function buildBarn(parent: Instance): Arena
	local fr = frameOf("Barn")
	local hw = fr.HW
	local arena = buildArena(parent, {
		Frame = fr,
		FloorY = 0,
		FloorColor = COLORS.Dirt,
		FloorMaterial = Enum.Material.Ground,
		FenceColor = COLORS.BarnRed,
		FenceModel = "FarmFence",
		FenceStep = 8,
	})
	local folder = parent:FindFirstChild("Barn") :: Folder
	-- The barn itself, behind the play area
	local wall = lbox(folder, "BarnWall", fr, -25, -hw - 14, 25, -hw - 2, 0, 16, COLORS.BarnRed)
	local roof = lbox(folder, "BarnRoof", fr, -27, -hw - 16, 27, -hw, 16, 18, COLORS.Stone)
	local barn = dress(folder, "Barn", lspot(fr, 0, -hw - 20, 0), 28, { wall, roof }, { Solid = true })
	if barn then
		ModelFit.Align(barn, fr.F, L(fr, 0, -hw - 2):Dot(fr.F)) -- its front sits just behind the back fence
	end
	-- Hay bales to hide behind
	for _, at in { { -15, -10 }, { 0, 10 }, { 15, -13 }, { 10, 13 }, { -12, 15 }, { 0, -15 }, { -26, 0 } } do
		local position = addObstacle(arena, fr, at[1], at[2], 3.3)
		local bale = part(folder, {
			Name = "HayBale",
			Size = Vector3.new(5, 4, 5),
			Position = position + Vector3.new(0, 2, 0),
			Color = COLORS.Hay,
			Material = Enum.Material.Fabric,
		})
		dress(folder, "HayBale", spot(position.X, 0, position.Z), 5, { bale })
	end
	local trough = addObstacle(arena, fr, 28, -1, 2.6)
	if not dress(folder, "Trough", spot(trough.X, 0, trough.Z, fr.R), 5, nil, { Solid = true }) then
		table.remove(arena.Obstacles)
	end
	return arena
end

local function buildJungle(parent: Instance): Arena
	local fr = frameOf("Jungle")
	local arena = buildArena(parent, {
		Frame = fr,
		FloorY = 0,
		FloorColor = COLORS.DarkGrass,
		FloorMaterial = Enum.Material.LeafyGrass,
		FenceColor = COLORS.Bark,
		FenceModel = "BambooFence",
		FenceStep = 8,
	})
	local folder = parent:FindFirstChild("Jungle") :: Folder
	for index, at in { { -23, -15 }, { -10, 5 }, { 5, -13 }, { 20, 10 }, { 27, -17 }, { -5, 19 }, { 13, -3 } } do
		local position = addObstacle(arena, fr, at[1], at[2], 1.8)
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
	for _, at in { { -30, 13 }, { 31, -3 } } do
		local rock = addObstacle(arena, fr, at[1], at[2], 2)
		if not dress(folder, "Rock", spot(rock.X, 0, rock.Z), 4, nil, { Solid = true }) then
			table.remove(arena.Obstacles)
		end
	end
	-- Mud pits slow you down (Material = Mud is how the client knows, even when the block is hidden)
	for _, rect in { { -21, -7, 12, 8 }, { 15, 21, 10, 6 }, { -1, -24, 14, 5 } } do
		local u, w, su, sw = rect[1], rect[2], rect[3], rect[4]
		local mud = lbox(folder, "Mud", fr, u - su / 2, w - sw / 2, u + su / 2, w + sw / 2, 0, 0.12, COLORS.Mud, {
			Material = Enum.Material.Mud,
		})
		-- The puddle model is round, so a long strip gets a row of puddles
		local long, short = math.max(su, sw), math.min(su, sw)
		local count = math.max(1, math.round(long / short))
		local axis = if su >= sw then fr.R else fr.F
		local step = long / count
		local middle = L(fr, u, w, 0.02)
		for i = 0, count - 1 do
			local at = middle + axis * (-long / 2 + step * (i + 0.5))
			local turn = CFrame.Angles(0, i * 2.1, 0)
			if not dress(folder, "MudPuddle", spot(at.X, at.Y, at.Z) * turn, math.max(step, short) * 1.1, { mud }) then
				break
			end
		end
	end
	return arena
end

local function buildIceRink(parent: Instance): Arena
	local fr = frameOf("IceRink")
	local arena = buildArena(parent, {
		Frame = fr,
		FloorY = 0,
		FloorColor = COLORS.Ice,
		FloorMaterial = Enum.Material.Ice, -- the client makes you slide on Ice
		FenceColor = COLORS.White,
		FenceModel = "RinkBoard",
		FenceStep = 9,
	})
	local folder = parent:FindFirstChild("IceRink") :: Folder
	for _, du in { -32, 32 } do
		local position = addObstacle(arena, fr, du, 0, 2.5)
		local goal = part(folder, {
			Name = "Goal",
			Size = Vector3.new(3, 4, 5),
			CFrame = CFrame.lookAt(
				position + Vector3.new(0, 2, 0),
				position + Vector3.new(0, 2, 0) - fr.R * math.sign(du)
			),
			Color = COLORS.PostRed,
		})
		-- Goals face the middle of the rink
		dress(folder, "HockeyGoal", spot(position.X, 0, position.Z, -fr.R * math.sign(du)), 5, { goal })
	end
	for _, at in { { -18, -15 }, { 18, 15 } } do
		local snowman = addObstacle(arena, fr, at[1], at[2], 1.8)
		if not dress(folder, "Snowman", spot(snowman.X, 0, snowman.Z), 6, nil, { ByHeight = true, Solid = true }) then
			table.remove(arena.Obstacles)
		end
	end
	return arena
end

local ROOF_Y = 30

local function buildRooftop(parent: Instance): Arena
	local fr = frameOf("Rooftop")
	local roofY = ROOF_Y
	local building = lbox(parent, "RooftopBuilding", fr, -fr.HU, -fr.HW, fr.HU, fr.HW, 0, roofY - 0.5, COLORS.Concrete)
	building.Color = Color3.fromRGB(150, 156, 176)
	local arena = buildArena(parent, {
		Frame = fr,
		FloorY = roofY,
		FloorColor = COLORS.Concrete,
		FloorMaterial = Enum.Material.Concrete,
		FenceColor = nil, -- no fence. Edges!
	})
	local folder = parent:FindFirstChild("Rooftop") :: Folder
	for _, at in { { -13, 5, 3 }, { 10, -10, 3 }, { 13, 13, 3 }, { -5, -17, 2 } } do
		local position = addObstacle(arena, fr, at[1], at[2], at[3])
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
		dress(folder, "ACUnit", spot(position.X, roofY, position.Z, fr.R), 4, { unit })
	end
	local tower = addObstacle(arena, fr, 19, -19, 3.5)
	if not dress(folder, "WaterTower", spot(tower.X, roofY, tower.Z), 16, nil, { ByHeight = true, Solid = true }) then
		table.remove(arena.Obstacles)
	end
	local chimney = addObstacle(arena, fr, -19, 15, 1.6)
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

-- Emoji on each zone's entrance arch
local ZONE_ICONS: { [string]: string } = {
	Backyard = "🏡",
	Barn = "🐔",
	Jungle = "🌴",
	IceRink = "❄️",
	Rooftop = "🏙️",
}

-- A counter (or any box) standing at `at`, its front facing `facing` (size: width across, height, depth)
local function facingBox(
	parent: Instance,
	name: string,
	at: Vector3,
	facing: Vector3,
	size: Vector3,
	color: Color3
): Part
	return part(parent, {
		Name = name,
		Size = size,
		CFrame = CFrame.lookAt(at + Vector3.new(0, size.Y / 2, 0), at + Vector3.new(0, size.Y / 2, 0) + facing),
		Color = color,
	})
end

function MapBuilder.Build(): Map
	local existing = Workspace:FindFirstChild("GrayboxMap")
	if existing then
		existing:Destroy()
	end
	local map = Instance.new("Folder")
	map.Name = "GrayboxMap"
	map.Parent = Workspace

	-- Spawn: on the south side of the plaza, facing the fountain and the Post Office beyond it
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = Vector3.new(0, 0.5, 44)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = COLORS.PostBlue
	spawn.Parent = map
	dress(map, "SpawnPad", spot(0, 0, 44), 7, { spawn })

	-- Post Office on the north side: the building, Postmaster Gruff in front of it, his counter, the chute
	-- and his orders board. (All facing south, +Z, toward the fountain.)
	local N = -22 -- (how far north of where it all used to be)
	local building =
		block(map, "PostOfficeBuilding", Vector3.new(-10, 0, -44 + N), Vector3.new(10, 12, -30 + N), COLORS.PostRed)
	local roof =
		block(map, "PostOfficeRoof", Vector3.new(-11, 12, -45 + N), Vector3.new(11, 13, -29 + N), COLORS.PostBlue)
	local office = dress(map, "PostOffice", spot(0, 0, -37 + N), 18, { building, roof }, { Solid = true })
	if office then
		ModelFit.Align(office, Vector3.zAxis, -30 + N) -- its front door sits right behind Gruff
	end
	block(map, "PostOfficeFloor", Vector3.new(-12, 0, -30 + N), Vector3.new(20, 0.3, -19 + N), COLORS.Stone)
	local gruff, gruffHat = buildGruff(map, spot(-2, 0.3, -27 + N))
	local postCounter = block(map, "Counter", Vector3.new(-7, 0.3, -24 + N), Vector3.new(3, 3.8, -22 + N), COLORS.Wood)
	dress(map, "PostCounter", spot(-2, 0.3, -23 + N), 10.5, { postCounter })
	local chute = block(map, "MailChute", Vector3.new(5, 0.3, -25 + N), Vector3.new(9, 5, -21 + N), COLORS.Chute)
	MapBuilder.Label(chute, "MAIL CHUTE", 3.5, COLORS.Yellow)
	-- Hold E here to mail your bag. (Each player's client shortens the hold and swaps in their chute's model.)
	local chutePrompt = prompt(chute, "Mail Parcels", "Mail Chute", Config.Mail.ChuteById.Basic.HoldTime)
	chutePrompt.MaxActivationDistance = 12

	-- Gruff's orders board (right of the Post Office)
	local board = block(map, "OrdersBoard", Vector3.new(12, 0, -28 + N), Vector3.new(18, 7, -27 + N), COLORS.Wood)
	MapBuilder.Label(board, "GRUFF'S ORDERS", 5, COLORS.Yellow)
	local ordersPrompt = prompt(board, "Read Orders", "Gruff's Orders", 0.2)
	dress(map, "OrdersBoard", spot(15, 0, -27.5 + N), 6.5, { board })
	-- A letter bobbing over the board so it catches your eye (it spins on each client: Animate.luau)
	local letter = ModelFit.Spawn("PropModels", "Envelope", CFrame.new(15, 8.5, -27.5 + N), 2, map)
	if letter then
		letter.Name = "OrdersLetter"
		letter:SetAttribute("Spin", true)
	end

	-- Animal Pen counter (southwest of the fountain): sends you to your best zone
	local penAt = Vector3.new(-36, 0, 30)
	local penFacing = (Vector3.zero - penAt).Unit
	local counter = facingBox(map, "PenCounter", penAt, penFacing, Vector3.new(8, 3, 2), COLORS.Wood)
	MapBuilder.Label(counter, "ANIMAL PEN", 4, COLORS.Yellow)
	local penPrompt = prompt(counter, "Go to the wild", "Animal Pen", 0.3)
	dress(map, "PenCounter", spot(penAt.X, 0, penAt.Z, penFacing), 8.5, { counter })

	-- Supply Shop (east side, facing the fountain), with a table of the tools it sells beside it
	local shopAt = Vector3.new(44, 0, -6)
	local shopCounter = facingBox(map, "ShopCounter", shopAt, -Vector3.xAxis, Vector3.new(8, 3, 2), COLORS.PostBlue)
	MapBuilder.Label(shopCounter, "SUPPLY SHOP", 4, COLORS.Yellow)
	local shopPrompt = prompt(shopCounter, "Shop", "Boxes, Tools, Stamps", 0.2)
	dress(map, "ShopStall", spot(shopAt.X, 0, shopAt.Z, -Vector3.xAxis), 9.5, { shopCounter }, { Solid = true })
	local displayTable = block(map, "DisplayTable", Vector3.new(43, 0, 4), Vector3.new(45.6, 2.6, 12), COLORS.Wood)
	for index, name in SHOP_DISPLAY do
		local z = 4 + (index - 0.5) * (8 / #SHOP_DISPLAY)
		local item = ModelFit.Spawn("PropModels", name, spot(44.3, 2.6, z, -Vector3.xAxis), 1.25, displayTable)
		if item then
			item:SetAttribute("Spin", true)
		end
	end

	-- Scenery right around the counters (only if imported)
	for _, at in { { -16, -40 }, { 24, -40 }, { 40, -16 }, { 40, 16 } } do
		dress(map, "Lamppost", spot(at[1], 0, at[2]), 9, nil, { ByHeight = true, Solid = true })
	end
	dress(map, "Mailbox", spot(7, 0, 44, -Vector3.zAxis), 3.5, nil, { ByHeight = true, Solid = true })
	dress(map, "Planter", spot(-26, 0, -42), 5, nil, { Solid = true })
	dress(map, "Planter", spot(32, 0, -42), 5, nil, { Solid = true })

	-- Zones
	local arenaFolder = Instance.new("Folder")
	arenaFolder.Name = "Arenas"
	arenaFolder.Parent = map
	local arenas: { [string]: Arena } = {}
	for _, arena in
		{
			buildBackyard(arenaFolder),
			buildBarn(arenaFolder),
			buildJungle(arenaFolder),
			buildIceRink(arenaFolder),
			buildRooftop(arenaFolder),
		}
	do
		arenas[arena.Id] = arena
	end

	-- The Rooftop can't be walked up to, so its building has an elevator pad at its foot, on the town side
	local liftPads: { [string]: BasePart } = {}
	do
		local fr = frameOf("Rooftop")
		local at = L(fr, 0, fr.HW + 6, 0)
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

	-- Leaderboards on the west side of the plaza, facing the fountain (LeaderboardService draws on them)
	local LEADERBOARD_X = -55 -- where the boards' faces are
	local leaderboards: { [string]: BasePart } = {}
	for index, id in { "FastestTiger", "FiveStamps", "Rarest" } do
		local z = -12 + (index - 1) * 12
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

	-- Lock barriers: a shimmering wall across the island end of each locked zone's bridge, with the level it
	-- opens at. Each player's client hides the ones they've unlocked (ZoneLocks.luau). The server does the
	-- actual keeping-out (Travel.luau), so these don't block anything by themselves.
	for _, def in Config.Arenas.List do
		local island = World.ById[def.Id]
		local need = Config.Levels.ZoneLevels[def.Id] or 1
		if island and need > 1 then
			local from, to = World.Bridge(island)
			local direction = Vector3.new(to.X - from.X, 0, to.Z - from.Z).Unit
			local at = to - direction * 2
			-- (its Front faces away from town, so the sign's Back face reads from the bridge)
			local wall = part(map, {
				Name = `ZoneLock_{def.Id}`,
				Size = Vector3.new(World.BridgeWidth + 8, 14, 0.6),
				CFrame = CFrame.lookAt(at + Vector3.new(0, 7, 0), at + Vector3.new(0, 7, 0) + direction),
				Color = Color3.fromRGB(255, 120, 90),
				Material = Enum.Material.ForceField,
				CanCollide = false,
				CanQuery = false,
			})
			wall:SetAttribute("ArenaId", def.Id)
			wall:SetAttribute("Level", need)
			CollectionService:AddTag(wall, "ZoneLock")
			local signAt = at - direction * 0.6 + Vector3.new(0, 6, 0)
			local sign = part(map, {
				Name = "ZoneLockSign",
				Size = Vector3.new(14, 5, 0.4),
				CFrame = CFrame.lookAt(signAt, signAt + direction),
				Color = Color3.fromRGB(40, 30, 30),
				CanCollide = false,
				CanQuery = false,
			})
			sign:SetAttribute("ArenaId", def.Id)
			sign:SetAttribute("Level", need)
			CollectionService:AddTag(sign, "ZoneLock")
			local gui = Instance.new("SurfaceGui")
			gui.Face = Enum.NormalId.Back -- facing town
			gui.LightInfluence = 0
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(0.9, 0.8)
			label.Position = UDim2.fromScale(0.05, 0.1)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.LuckiestGuy
			label.TextColor3 = Color3.fromRGB(255, 220, 90)
			label.Text = `🔒 LEVEL {need}`
			label.Parent = gui
			local stroke = Instance.new("UIStroke")
			stroke.Thickness = math.max(1.5, SignText.Fit(gui, label, sign) * 0.08)
			stroke.Parent = label
			gui.Parent = sign
		end
	end

	-- Everything that's just for looks: the sea, the islands and their cliffs, the bridges, the plaza and
	-- each island's theme. Scenery keeps its trees and props clear of the gameplay pieces listed here.
	local zones: { Scenery.Zone } = {}
	for _, def in Config.Arenas.List do
		local fr = frameOf(def.Id)
		local arena = arenas[def.Id]
		table.insert(zones, {
			Id = def.Id,
			Name = def.DisplayName,
			Color = def.Color,
			Icon = ZONE_ICONS[def.Id] or "",
			Min = arena.Min,
			Max = arena.Max,
			FloorY = arena.FloorY,
			Facing = fr.F,
		})
	end
	Scenery.Build(map, {
		Zones = zones,
		-- Spots in town to keep clear of trees and props: { x, z, radius }
		Keep = {
			{ 0, -60, 24 }, -- the Post Office, Gruff and his counter
			{ 15, -50, 6 }, -- orders board
			{ penAt.X, penAt.Z, 8 },
			{ 44, 0, 14 }, -- the Supply Shop and its table
			{ -57, 0, 22 }, -- leaderboards
			{ 0, 44, 8 }, -- spawn
		},
	})

	local townSpot = Vector3.new(0, 3, 40)
	return {
		Leaderboards = leaderboards,
		PenPrompt = penPrompt,
		PenCounter = counter,
		Arenas = arenas,
		TownSpawn = CFrame.lookAt(townSpot, townSpot - Vector3.zAxis),
		TravelPads = {},
		LiftPads = liftPads,
		ReturnPads = {},
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
