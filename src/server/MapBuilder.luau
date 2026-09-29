--!strict
-- Builds the graybox map in code: spawn, the Animal Pen counter, the fenced catching arena, and Gruff's
-- mail counter with the mail chute. This is a placeholder. The real map gets built by hand in Studio later.
--
-- Layout (top-down, ground at y = 0):
--   Spawn           around (0, 45)
--   Animal Pen      counter at (-14, 7), just outside the arena gate
--   Catching arena  x -30..30, z -40..0, gate in the middle of the z = 0 fence
--   Post Office     Gruff's counter and the mail chute at (16, 8), orders board at (30, 11)
--   Supply Shop     counter at (-14, 21), behind the Animal Pen

local Workspace = game:GetService("Workspace")

local MapBuilder = {}

export type Map = {
	PenPrompt: ProximityPrompt,
	PenCounter: BasePart,
	ArenaMin: Vector3, -- animals are kept inside these bounds
	ArenaMax: Vector3,
	ArenaCenter: Vector3,
	Chute: BasePart,
	GruffHat: BasePart,
	ShopPrompt: ProximityPrompt,
	ShopCounter: BasePart,
	OrdersPrompt: ProximityPrompt,
}

local COLORS = {
	Grass = Color3.fromRGB(106, 170, 84),
	Dirt = Color3.fromRGB(150, 115, 80),
	Stone = Color3.fromRGB(190, 190, 180),
	Wood = Color3.fromRGB(160, 110, 70),
	Yellow = Color3.fromRGB(240, 210, 80),
	PostRed = Color3.fromRGB(200, 60, 60),
	PostBlue = Color3.fromRGB(60, 90, 170),
	Chute = Color3.fromRGB(45, 45, 55),
	Walrus = Color3.fromRGB(130, 110, 100),
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

function MapBuilder.Build(): Map
	local existing = Workspace:FindFirstChild("GrayboxMap")
	if existing then
		existing:Destroy()
	end
	local map = Instance.new("Folder")
	map.Name = "GrayboxMap"
	map.Parent = Workspace

	-- Ground + spawn
	block(map, "Ground", Vector3.new(-100, -1, -100), Vector3.new(100, 0, 100), COLORS.Grass, {
		Material = Enum.Material.Grass,
	})
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = Vector3.new(0, 0.5, 45)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = COLORS.PostBlue
	spawn.Parent = map

	-- Catching arena: dirt floor and a fence with a gate
	local arenaMin = Vector3.new(-30, 0, -40)
	local arenaMax = Vector3.new(30, 0, 0)
	block(map, "ArenaFloor", Vector3.new(-30, -0.5, -40), Vector3.new(30, 0.02, 0), COLORS.Dirt, {
		Material = Enum.Material.Ground,
	})
	local fenceHeight = 4
	block(map, "Fence", Vector3.new(-31, 0, -41), Vector3.new(31, fenceHeight, -40), COLORS.Wood)
	block(map, "Fence", Vector3.new(-31, 0, -41), Vector3.new(-30, fenceHeight, 1), COLORS.Wood)
	block(map, "Fence", Vector3.new(30, 0, -41), Vector3.new(31, fenceHeight, 1), COLORS.Wood)
	block(map, "Fence", Vector3.new(-31, 0, 0), Vector3.new(-5, fenceHeight, 1), COLORS.Wood)
	block(map, "Fence", Vector3.new(5, 0, 0), Vector3.new(31, fenceHeight, 1), COLORS.Wood)
	local gateSign = block(map, "GateSign", Vector3.new(-5, 7, 0), Vector3.new(5, 8.5, 1), COLORS.Yellow)
	MapBuilder.Label(gateSign, "CATCHING ARENA", 2, COLORS.Yellow)
	block(map, "GatePost", Vector3.new(-6, 0, 0), Vector3.new(-5, 8.5, 1), COLORS.Stone)
	block(map, "GatePost", Vector3.new(5, 0, 0), Vector3.new(6, 8.5, 1), COLORS.Stone)

	-- Animal Pen counter (just outside the gate, on the left)
	local counter = block(map, "PenCounter", Vector3.new(-18, 0, 6), Vector3.new(-10, 3, 8), COLORS.Wood)
	MapBuilder.Label(counter, "ANIMAL PEN", 4, COLORS.Yellow)
	local penPrompt = Instance.new("ProximityPrompt")
	penPrompt.ActionText = "Choose an Animal"
	penPrompt.ObjectText = "Animal Pen"
	penPrompt.HoldDuration = 0.3
	penPrompt.RequiresLineOfSight = false
	penPrompt.Parent = counter

	-- Post Office: Gruff's counter, back wall, and the mail chute (just outside the gate, on the right)
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
	local ordersPrompt = Instance.new("ProximityPrompt")
	ordersPrompt.ActionText = "Read Orders"
	ordersPrompt.ObjectText = "Gruff's Orders"
	ordersPrompt.HoldDuration = 0.2
	ordersPrompt.RequiresLineOfSight = false
	ordersPrompt.Parent = board

	-- Supply Shop (behind the Animal Pen)
	local shopCounter = block(map, "ShopCounter", Vector3.new(-18, 0, 20), Vector3.new(-10, 3, 22), COLORS.PostBlue)
	MapBuilder.Label(shopCounter, "SUPPLY SHOP", 4, COLORS.Yellow)
	local shopPrompt = Instance.new("ProximityPrompt")
	shopPrompt.ActionText = "Shop"
	shopPrompt.ObjectText = "Boxes, Tools, Stamps"
	shopPrompt.HoldDuration = 0.2
	shopPrompt.RequiresLineOfSight = false
	shopPrompt.Parent = shopCounter

	return {
		PenPrompt = penPrompt,
		PenCounter = counter,
		ArenaMin = arenaMin,
		ArenaMax = arenaMax,
		ArenaCenter = (arenaMin + arenaMax) / 2,
		Chute = chute,
		GruffHat = gruffHat,
		ShopPrompt = shopPrompt,
		ShopCounter = shopCounter,
		OrdersPrompt = ordersPrompt,
	}
end

return MapBuilder
