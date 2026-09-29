--!strict
-- Builds the Phase 1 graybox map in code: hub + Animal Pen, one route with hazards, and the Post Office.
-- This is a placeholder. In Phase 4 the real map gets built by hand in Studio and this file goes away.
--
-- Layout (top-down, X runs left to right):
--   x -50..0    Hub: spawn + Animal Pen
--   x 0..240    Town Streets route (raised road, top at y = 4)
--   x 240..290  Post Office (bell at the door, drop-off zone inside, Gruff at the counter)

local Workspace = game:GetService("Workspace")

local MapBuilder = {}

export type Map = {
	PenPrompt: ProximityPrompt,
	PenCounter: BasePart,
	BellZone: BasePart,
	BellSound: Sound,
	DeliveryZone: BasePart,
	GruffHat: BasePart,
}

local ROAD_TOP = 4
local W = 7 -- road half-width

local COLORS = {
	Grass = Color3.fromRGB(106, 170, 84),
	Road = Color3.fromRGB(72, 72, 80),
	Stone = Color3.fromRGB(190, 190, 180),
	Pit = Color3.fromRGB(50, 45, 40),
	Wood = Color3.fromRGB(160, 110, 70),
	Yellow = Color3.fromRGB(240, 210, 80),
	Hazard = Color3.fromRGB(230, 90, 60),
	PostRed = Color3.fromRGB(200, 60, 60),
	PostBlue = Color3.fromRGB(60, 90, 170),
	Green = Color3.fromRGB(90, 220, 110),
	Hamster = Color3.fromRGB(235, 160, 70),
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

local function wedge(parent: Instance, cframe: CFrame, size: Vector3, color: Color3)
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.Size = size
	w.CFrame = cframe
	w.Color = color
	w.Parent = parent
end

function MapBuilder.Label(adornee: BasePart, text: string, height: number, color: Color3?)
	local gui = Instance.new("BillboardGui")
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

-- A spinning bar that knocks boxes around. Speed is in radians/sec (negative = other direction).
local function sweeper(parent: Instance, x: number, speed: number)
	local post = part(parent, {
		Name = "SweeperPost",
		Size = Vector3.new(1.5, 6, 1.5),
		Position = Vector3.new(x, ROAD_TOP + 3, 0),
		Color = COLORS.Stone,
	})
	local bar = part(parent, {
		Name = "SweeperBar",
		Anchored = false,
		Size = Vector3.new(W * 2 - 1, 1, 1),
		Position = Vector3.new(x, ROAD_TOP + 3.5, 0),
		Color = COLORS.Hazard,
		CustomPhysicalProperties = PhysicalProperties.new(5, 0.3, 0.5),
	})

	-- Hinges spin around the attachment's X axis, so rotate both attachments to point X straight up.
	local postAttachment = Instance.new("Attachment")
	postAttachment.Orientation = Vector3.new(0, 0, 90)
	postAttachment.Position = Vector3.new(0, 0.5, 0)
	postAttachment.Parent = post

	local barAttachment = Instance.new("Attachment")
	barAttachment.Orientation = Vector3.new(0, 0, 90)
	barAttachment.Parent = bar

	local hinge = Instance.new("HingeConstraint")
	hinge.Attachment0 = postAttachment
	hinge.Attachment1 = barAttachment
	hinge.ActuatorType = Enum.ActuatorType.Motor
	hinge.AngularVelocity = speed
	hinge.MotorMaxTorque = 1e7
	hinge.MotorMaxAcceleration = math.huge
	hinge.Parent = post

	local noCollide = Instance.new("NoCollisionConstraint")
	noCollide.Part0 = post
	noCollide.Part1 = bar
	noCollide.Parent = post

	bar:SetNetworkOwner(nil) -- server simulates it so every player sees the same bar
end

function MapBuilder.Build(): Map
	local existing = Workspace:FindFirstChild("GrayboxMap")
	if existing then
		existing:Destroy()
	end
	local map = Instance.new("Folder")
	map.Name = "GrayboxMap"
	map.Parent = Workspace

	-- Ground
	block(map, "Ground", Vector3.new(-80, -1, -80), Vector3.new(320, 0, 80), COLORS.Grass, {
		Material = Enum.Material.Grass,
	})

	-- Hub
	block(map, "Hub", Vector3.new(-50, 0, -25), Vector3.new(0, ROAD_TOP, 25), COLORS.Stone)

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = Vector3.new(-40, ROAD_TOP + 0.5, 0)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = COLORS.PostBlue
	spawn.Parent = map

	-- Animal Pen
	block(map, "PenFence", Vector3.new(-32, ROAD_TOP, -22), Vector3.new(-18, ROAD_TOP + 3, -21.5), COLORS.Wood)
	block(map, "PenFence", Vector3.new(-32, ROAD_TOP, -10.5), Vector3.new(-18, ROAD_TOP + 3, -10), COLORS.Wood)
	block(map, "PenFence", Vector3.new(-32, ROAD_TOP, -22), Vector3.new(-31.5, ROAD_TOP + 3, -10), COLORS.Wood)
	block(map, "PenFence", Vector3.new(-18.5, ROAD_TOP, -22), Vector3.new(-18, ROAD_TOP + 3, -10), COLORS.Wood)

	local penHamster = part(map, {
		Name = "PenHamster",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.6, 1.6, 1.6),
		Position = Vector3.new(-25, ROAD_TOP + 0.8, -16),
		Color = COLORS.Hamster,
	})
	MapBuilder.Label(penHamster, "Hamster", 2)

	local counter =
		block(map, "PenCounter", Vector3.new(-28, ROAD_TOP, -9.5), Vector3.new(-22, ROAD_TOP + 3, -7.5), COLORS.Wood)
	MapBuilder.Label(counter, "ANIMAL PEN", 4, COLORS.Yellow)

	local penPrompt = Instance.new("ProximityPrompt")
	penPrompt.ActionText = "Choose an Animal"
	penPrompt.ObjectText = "Animal Pen"
	penPrompt.HoldDuration = 0.3
	penPrompt.RequiresLineOfSight = false
	penPrompt.Parent = counter

	-- Route: road tiles every 10 studs, with potholes and a gap for the plank bridge
	local function road(x0: number, x1: number, z0: number, z1: number)
		block(map, "Road", Vector3.new(x0, 0, z0), Vector3.new(x1, ROAD_TOP, z1), COLORS.Road, {
			Material = Enum.Material.Asphalt,
		})
	end
	local function pothole(x0: number, x1: number, z0: number, z1: number)
		block(map, "Pothole", Vector3.new(x0, 0, z0), Vector3.new(x1, 1.5, z1), COLORS.Pit)
	end

	for x = 0, 230, 10 do
		local x1 = x + 10
		if x == 100 or x == 110 then
			continue -- gap: crossed by the plank below
		end

		if x == 60 then
			road(x, x1, -W, 0)
			pothole(x, x1, 0, W)
		elseif x == 80 then
			road(x, x1, 0, W)
			pothole(x, x1, -W, 0)
		elseif x == 200 then
			road(x, x1, -2.5, 2.5)
			pothole(x, x1, -W, -2.5)
			pothole(x, x1, 2.5, W)
		else
			road(x, x1, -W, W)
		end
	end

	-- Speed bumps
	for _, x in { 25, 35, 45 } do
		block(map, "SpeedBump", Vector3.new(x - 1, ROAD_TOP, -W), Vector3.new(x + 1, ROAD_TOP + 0.8, W), COLORS.Yellow)
	end

	-- Narrow plank bridge
	block(map, "Plank", Vector3.new(100, ROAD_TOP - 0.5, -1.5), Vector3.new(120, ROAD_TOP, 1.5), COLORS.Wood)

	-- Spinning sweepers
	sweeper(map, 135, 1.2)
	sweeper(map, 190, -1.8)

	-- Low-clearance signs: characters and normal boxes fit under, tall boxes (giraffe!) must duck (hold C)
	for _, x in { 70, 145 } do
		local clearance = ROAD_TOP + 7
		local sign = block(
			map,
			"LowSign",
			Vector3.new(x - 0.5, clearance, -W - 1),
			Vector3.new(x + 0.5, clearance + 1.5, W + 1),
			COLORS.Yellow
		)
		block(
			map,
			"LowSignPost",
			Vector3.new(x - 0.5, 0, -W - 1.5),
			Vector3.new(x + 0.5, clearance + 1.5, -W - 0.5),
			COLORS.Stone
		)
		block(
			map,
			"LowSignPost",
			Vector3.new(x - 0.5, 0, W + 0.5),
			Vector3.new(x + 0.5, clearance + 1.5, W + 1.5),
			COLORS.Stone
		)
		MapBuilder.Label(sign, "LOW CLEARANCE - hold C to duck", 2, COLORS.Yellow)
	end

	-- Hill: up ramp, flat top, down ramp
	wedge(
		map,
		CFrame.new(154, ROAD_TOP + 1, 0) * CFrame.Angles(0, math.rad(90), 0),
		Vector3.new(W * 2, 2, 8),
		COLORS.Road
	)
	block(map, "Hill", Vector3.new(158, ROAD_TOP, -W), Vector3.new(172, ROAD_TOP + 2, W), COLORS.Road)
	wedge(
		map,
		CFrame.new(176, ROAD_TOP + 1, 0) * CFrame.Angles(0, math.rad(-90), 0),
		Vector3.new(W * 2, 2, 8),
		COLORS.Road
	)

	-- Ramps back up to the road if you fall off the side
	for _, x in { 50, 125, 215 } do
		wedge(
			map,
			CFrame.new(x, ROAD_TOP / 2, W + 4) * CFrame.Angles(0, math.pi, 0),
			Vector3.new(6, ROAD_TOP, 8),
			COLORS.Stone
		)
		wedge(map, CFrame.new(x, ROAD_TOP / 2, -W - 4), Vector3.new(6, ROAD_TOP, 8), COLORS.Stone)
	end

	-- Post Office
	local wallTop = ROAD_TOP + 14
	block(map, "PostOfficeFloor", Vector3.new(240, 0, -20), Vector3.new(290, ROAD_TOP, 20), COLORS.Stone)
	block(map, "Wall", Vector3.new(248, ROAD_TOP, -20), Vector3.new(249, wallTop, -5), COLORS.PostRed)
	block(map, "Wall", Vector3.new(248, ROAD_TOP, 5), Vector3.new(249, wallTop, 20), COLORS.PostRed)
	local lintel =
		block(map, "Lintel", Vector3.new(248, ROAD_TOP + 10, -5), Vector3.new(249, wallTop, 5), COLORS.PostRed)
	block(map, "Wall", Vector3.new(289, ROAD_TOP, -20), Vector3.new(290, wallTop, 20), COLORS.PostRed)
	block(map, "Wall", Vector3.new(248, ROAD_TOP, -20), Vector3.new(290, wallTop, -19), COLORS.PostRed)
	block(map, "Wall", Vector3.new(248, ROAD_TOP, 19), Vector3.new(290, wallTop, 20), COLORS.PostRed)
	block(map, "Roof", Vector3.new(247, wallTop, -21), Vector3.new(291, wallTop + 1, 21), COLORS.PostBlue)
	MapBuilder.Label(lintel, "POST OFFICE", 5, COLORS.Yellow)

	local bell = part(map, {
		Name = "Bell",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.5, 1.5, 1.5),
		Position = Vector3.new(246.5, ROAD_TOP + 9, 0),
		Color = COLORS.Yellow,
		Material = Enum.Material.Metal,
	})
	local bellSound = Instance.new("Sound")
	bellSound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	bellSound.Parent = bell

	local zoneProps = { Transparency = 0.85, CanCollide = false, CanQuery = false, CanTouch = false }
	local bellZone = block(
		map,
		"BellZone",
		Vector3.new(236, ROAD_TOP, -7),
		Vector3.new(248, ROAD_TOP + 8, 7),
		COLORS.Yellow,
		table.clone(zoneProps)
	)
	local deliveryZone = block(
		map,
		"DeliveryZone",
		Vector3.new(252, ROAD_TOP, -15),
		Vector3.new(278, ROAD_TOP + 8, 15),
		COLORS.Green,
		table.clone(zoneProps)
	)
	MapBuilder.Label(deliveryZone, "DROP OFF HERE", 1, COLORS.Green)

	block(map, "Counter", Vector3.new(279, ROAD_TOP, -8), Vector3.new(281, ROAD_TOP + 4, 8), COLORS.Wood)
	local gruff = part(map, {
		Name = "Gruff",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(7, 7, 7),
		Position = Vector3.new(284, ROAD_TOP + 3.5, 0),
		Color = COLORS.Walrus,
	})
	MapBuilder.Label(gruff, "Postmaster Gruff", 5)

	-- His tiny postal cap. A tiger breakout knocks it off.
	local gruffHat = part(map, {
		Name = "GruffHat",
		Size = Vector3.new(3.5, 1, 3.5),
		Position = Vector3.new(284, ROAD_TOP + 7.5, 0),
		Color = COLORS.PostBlue,
	})

	return {
		PenPrompt = penPrompt,
		PenCounter = counter,
		BellZone = bellZone,
		BellSound = bellSound,
		DeliveryZone = deliveryZone,
		GruffHat = gruffHat,
	}
end

return MapBuilder
