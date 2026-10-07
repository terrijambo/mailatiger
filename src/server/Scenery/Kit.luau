--!strict
-- The scenery toolkit: colors, and little building blocks (parts, trees, pines, palms, rocks, lamps, benches,
-- cottages, signs) that the rest of Scenery builds the world out of. Everything is chunky low-poly smooth
-- plastic, in the bright style of popular simulators.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModelFit = require(ReplicatedStorage.Shared.ModelFit)
local SignText = require(ReplicatedStorage.Shared.SignText)

local Kit = {}

local C = {
	Grass = Color3.fromRGB(122, 204, 92),
	GrassTop = Color3.fromRGB(112, 214, 86),
	Brick = Color3.fromRGB(214, 124, 88), -- terrace sides
	Stone = Color3.fromRGB(222, 222, 230), -- (plaza tiles: a touch darker so town isn't glaring)
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

-- More colors for the islands
C.Rock = {
	Color3.fromRGB(128, 126, 134),
	Color3.fromRGB(142, 140, 148),
	Color3.fromRGB(116, 116, 126),
	Color3.fromRGB(150, 146, 150),
}
C.RockDark = { Color3.fromRGB(92, 92, 102), Color3.fromRGB(102, 100, 110), Color3.fromRGB(84, 86, 96) }
C.Plank = {
	Color3.fromRGB(186, 128, 78),
	Color3.fromRGB(170, 116, 70),
	Color3.fromRGB(198, 140, 88),
	Color3.fromRGB(160, 108, 66),
}
C.DarkWood = Color3.fromRGB(110, 74, 48)
C.Rope = Color3.fromRGB(214, 184, 130)
C.Paving = Color3.fromRGB(208, 184, 148)
C.PavingDark = Color3.fromRGB(166, 138, 106)
Kit.C = C

-- Leafy greens for trees, picked by position so the world doesn't look copy-pasted
local LEAF_COLORS = {
	Color3.fromRGB(78, 164, 70),
	Color3.fromRGB(96, 178, 74),
	Color3.fromRGB(62, 148, 72),
	Color3.fromRGB(112, 184, 76),
}
Kit.LEAF_COLORS = LEAF_COLORS

-- Everything is smooth plastic except materials that matter to the look: Neon (glows), Glass
-- (see-through), Ice and Glacier (shiny), Sand and Mud (gameplay)
local KEEP_MATERIAL = {
	[Enum.Material.Neon] = true,
	[Enum.Material.Glass] = true,
	[Enum.Material.Ice] = true,
	[Enum.Material.Glacier] = true,
	[Enum.Material.ForceField] = true,
}

function Kit.part(parent: Instance, props: { [string]: any }): BasePart
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
local part = Kit.part

function Kit.box(
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
local box = Kit.box

-- A vertical cylinder standing with its bottom at `bottom`
function Kit.cylinder(
	parent: Instance,
	name: string,
	bottom: Vector3,
	height: number,
	radius: number,
	color: Color3,
	props: { [string]: any }?
): BasePart
	local p = part(parent, {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = CFrame.new(bottom + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
	})
	for key, value in props or {} :: { [string]: any } do
		(p :: any)[key] = value
	end
	return p
end

-- A flat disc whose top is at `top`
function Kit.disc(
	parent: Instance,
	name: string,
	center: Vector3,
	top: number,
	thickness: number,
	radius: number,
	color: Color3,
	props: { [string]: any }?
): BasePart
	return Kit.cylinder(parent, name, Vector3.new(center.X, top - thickness, center.Z), thickness, radius, color, props)
end

function Kit.ball(
	parent: Instance,
	name: string,
	center: Vector3,
	diameter: number,
	color: Color3,
	props: { [string]: any }?
): BasePart
	local p = part(parent, {
		Name = name,
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * diameter,
		Position = center,
		Color = color,
	})
	for key, value in props or {} :: { [string]: any } do
		(p :: any)[key] = value
	end
	return p
end

-- Picks from a list by a number (the same spot always gets the same pick)
function Kit.pick<T>(list: { T }, n: number): T
	return list[(math.floor(math.abs(n)) % #list) + 1]
end

---------------------------------------------------------------------------------------------------
-- Signs

-- Big chunky text on one face of a part
-- A Blender model from ReplicatedStorage > MapModels (art/blender_scripts/scenery.py), standing at `at` and
-- facing `facing`, `size` studs wide (or tall, with byHeight). Returns nil if it isn't imported yet, so the
-- caller builds its plain-part version instead. `tint` recolors parts by name: { Leaves = Color3 }.
function Kit.model(
	parent: Instance,
	name: string,
	at: Vector3,
	facing: Vector3?,
	size: number,
	byHeight: boolean?,
	tint: { [string]: Color3 }?
): Model?
	local look = facing or Vector3.new(math.sin(at.X * 1.7 + at.Z), 0, math.cos(at.X * 1.7 + at.Z))
	local floor = CFrame.lookAt(at, at + Vector3.new(look.X, 0, look.Z))
	local model = ModelFit.Spawn("MapModels", name, floor, size, parent, { ByHeight = byHeight })
	if model and tint then
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") then
				local color = tint[p.Name]
				if color then
					p.Color = color
				end
			end
		end
	end
	return model
end

function Kit.signText(
	target: BasePart,
	face: Enum.NormalId,
	text: string,
	color: Color3,
	subtitle: string?,
	background: Color3?
)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.LightInfluence = 0
	gui.MaxDistance = 600
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = background or C.Dark
	frame.BackgroundTransparency = if background then 0 else 1
	frame.Parent = gui
	if background then
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
	title.TextWrapped = false
	title.TextColor3 = color
	title.Text = text
	title.Name = "Title"
	title.Parent = frame
	local pixelsPerStud = SignText.Fit(gui, title, target)
	local border = frame:FindFirstChildOfClass("UIStroke")
	if border then
		border.Thickness = math.max(2, pixelsPerStud * 0.15)
	end
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = math.max(1.5, pixelsPerStud * 0.08)
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
		SignText.Fit(gui, sub, target)
		local subStroke = stroke:Clone()
		subStroke.Thickness = math.max(1, pixelsPerStud * 0.06)
		subStroke.Parent = sub
	end
	gui.Parent = target
end

---------------------------------------------------------------------------------------------------
-- Plants

-- A round, blobby cartoon tree: a short trunk and a cluster of leafy balls
function Kit.tree(parent: Instance, at: Vector3, height: number, leaves: Color3?)
	local h = height
	local green = leaves or LEAF_COLORS[(math.floor(math.abs(at.X * 7 + at.Z * 3)) % #LEAF_COLORS) + 1]
	-- The Blender trees: mostly oaks, now and then a birch (only where no special leaf color is asked for)
	local birch = leaves == nil and math.floor(math.abs(at.X * 3 + at.Z * 5)) % 5 == 0
	local tint = if leaves then { Leaves = leaves, LeavesLight = leaves:Lerp(Color3.new(1, 1, 0.6), 0.18) } else nil
	if Kit.model(parent, if birch then "BirchTree" else "OakTree", at, nil, h * 1.15, true, tint) then
		return
	end
	box(parent, "Trunk", at + Vector3.new(0, h * 0.3, 0), Vector3.new(h * 0.13, h * 0.6, h * 0.13), C.Bark)
	local blobs = {
		{ 0, 0.72, 0, 0.62 },
		{ 0.22, 0.6, 0.12, 0.44 },
		{ -0.2, 0.62, -0.1, 0.42 },
		{ 0.05, 0.9, -0.05, 0.4 },
	}
	for index, b in blobs do
		Kit.ball(
			parent,
			"Leaves",
			at + Vector3.new(h * b[1], h * b[2], h * b[3]),
			h * b[4],
			green:Lerp(Color3.new(1, 1, 0.7), (index - 1) * 0.05)
		)
	end
end

-- A low-poly pine: a stepped cone of tiers, each with a cap of snow when snowy
-- A low-poly pyramid: four wedges leaning together (their tall backs meet in the middle), turned by `spin`
local function pyramid(
	parent: Instance,
	name: string,
	base: Vector3,
	radius: number,
	height: number,
	spin: number,
	color: Color3
)
	for k = 0, 3 do
		local a = spin + k * math.pi / 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local mid = base + dir * (radius / 2) + Vector3.new(0, height / 2, 0)
		part(parent, {
			ClassName = "WedgePart",
			Name = name,
			Size = Vector3.new(radius * 2, height, radius),
			CFrame = CFrame.lookAt(mid, mid + dir),
			Color = color,
			CanCollide = false,
		})
	end
end

function Kit.pine(parent: Instance, at: Vector3, height: number, snowy: boolean)
	local h = height
	if Kit.model(parent, if snowy then "SnowPine" else "PineTree", at, nil, h, true) then
		return
	end
	box(
		parent,
		"Trunk",
		at + Vector3.new(0, h * 0.1, 0),
		Vector3.new(h * 0.09, h * 0.2, h * 0.09),
		C.Bark,
		Enum.Material.Wood
	)
	local green = if snowy then Color3.fromRGB(40, 104, 78) else C.Pine
	local tiers = 4
	for i = 0, tiers - 1 do
		local t = i / tiers
		local radius = h * (0.21 - t * 0.04)
		local bottom = h * (0.12 + t * 0.2)
		local tall = h * (0.34 - t * 0.02)
		local spin = i * math.pi / 4 + at.X * 0.37
		pyramid(
			parent,
			"Needles",
			at + Vector3.new(0, bottom, 0),
			radius,
			tall,
			spin,
			green:Lerp(Color3.new(0, 0, 0), i * 0.03)
		)
		if snowy then
			-- a snow cap on the top third of each tier
			pyramid(
				parent,
				"Snow",
				at + Vector3.new(0, bottom + tall * 0.62, 0),
				radius * 0.4,
				tall * 0.4,
				spin,
				C.Snow
			)
		end
	end
end

-- A palm tree: a gently curved trunk and a crown of drooping fronds
function Kit.palm(parent: Instance, at: Vector3, height: number, lean: number)
	local h = height
	if Kit.model(parent, "PalmTree", at, nil, h * 1.05, true) then
		return
	end
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
	for i = 0, 6 do
		local angle = i / 7 * math.pi * 2
		part(parent, {
			Name = "Frond",
			Size = Vector3.new(1.4, 0.3, 8),
			CFrame = CFrame.new(top)
				* CFrame.Angles(0, angle, 0)
				* CFrame.Angles(math.rad(-22), 0, 0)
				* CFrame.new(0, 0, -3.8),
			Color = if i % 2 == 0 then Color3.fromRGB(64, 150, 64) else Color3.fromRGB(52, 134, 60),
			CanCollide = false,
		})
	end
	Kit.ball(parent, "Coconuts", top - Vector3.new(0, 0.6, 0), 1.4, Color3.fromRGB(120, 84, 50))
end

-- A little clump of flowers
function Kit.flowers(parent: Instance, at: Vector3, color: Color3, random: Random)
	for _ = 1, 5 do
		local p = at + Vector3.new(random:NextNumber(-2.2, 2.2), 0, random:NextNumber(-2.2, 2.2))
		box(parent, "Stem", p + Vector3.new(0, 0.4, 0), Vector3.new(0.15, 0.8, 0.15), Color3.fromRGB(70, 150, 60))
		Kit.ball(parent, "Flower", p + Vector3.new(0, 0.9, 0), 0.9, color, { CanCollide = false })
	end
end

-- A bush: two or three leafy balls
function Kit.bush(parent: Instance, at: Vector3, size: number, color: Color3?)
	local green = color or C.Hedge
	Kit.ball(parent, "Bush", at + Vector3.new(0, size * 0.35, 0), size, green)
	Kit.ball(
		parent,
		"Bush",
		at + Vector3.new(size * 0.4, size * 0.25, size * 0.1),
		size * 0.7,
		green:Lerp(Color3.new(0, 0.2, 0), 0.1)
	)
	Kit.ball(
		parent,
		"Bush",
		at + Vector3.new(-size * 0.35, size * 0.22, -size * 0.15),
		size * 0.65,
		green:Lerp(Color3.new(1, 1, 0.6), 0.08)
	)
end

---------------------------------------------------------------------------------------------------
-- Rocks

-- A chunky low-poly boulder (a few tilted blocks)
function Kit.rock(parent: Instance, at: Vector3, size: number, random: Random, colors: { Color3 }?)
	local palette = colors or C.Rock
	for i = 1, 3 do
		local s = size * (1 - (i - 1) * 0.25)
		part(parent, {
			Name = "Rock",
			Size = Vector3.new(
				s * random:NextNumber(1, 1.4),
				s * random:NextNumber(0.6, 0.9),
				s * random:NextNumber(0.9, 1.2)
			),
			CFrame = CFrame.new(
				at
					+ Vector3.new(
						random:NextNumber(-0.3, 0.3) * size,
						s * 0.25 + (i - 1) * size * 0.18,
						random:NextNumber(-0.3, 0.3) * size
					)
			) * CFrame.Angles(random:NextNumber(-0.3, 0.3), random:NextNumber(0, 6.28), random:NextNumber(-0.3, 0.3)),
			Color = palette[random:NextInteger(1, #palette)],
		})
	end
end

---------------------------------------------------------------------------------------------------
-- Town furniture

local LAMP_GREEN = Color3.fromRGB(38, 62, 52)
function Kit.lamppost(parent: Instance, at: Vector3)
	box(parent, "LampBase", at + Vector3.new(0, 0.35, 0), Vector3.new(1.5, 0.7, 1.5), LAMP_GREEN, Enum.Material.Metal)
	box(parent, "LampBase", at + Vector3.new(0, 0.95, 0), Vector3.new(1, 0.5, 1), LAMP_GREEN, Enum.Material.Metal)
	box(parent, "LampPole", at + Vector3.new(0, 4.8, 0), Vector3.new(0.4, 8, 0.4), LAMP_GREEN, Enum.Material.Metal)
	box(parent, "LampCollar", at + Vector3.new(0, 3, 0), Vector3.new(0.7, 0.35, 0.7), C.Gold, Enum.Material.Metal)
	box(parent, "LampCollar", at + Vector3.new(0, 8.75, 0), Vector3.new(0.9, 0.3, 0.9), LAMP_GREEN, Enum.Material.Metal)
	-- The lantern: a warm light inside a glass box with dark corner posts
	local glow = part(parent, {
		Name = "Lamp",
		Size = Vector3.new(0.8, 1.1, 0.8),
		Position = at + Vector3.new(0, 9.6, 0),
		Color = Color3.fromRGB(255, 225, 150),
		Material = Enum.Material.Neon,
	})
	part(parent, {
		Name = "LampGlass",
		Size = Vector3.new(1.3, 1.5, 1.3),
		Position = at + Vector3.new(0, 9.65, 0),
		Color = Color3.fromRGB(255, 245, 210),
		Material = Enum.Material.Glass,
		Transparency = 0.45,
	})
	for _, corner in { Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, -1) } do
		box(
			parent,
			"LampFrame",
			at + Vector3.new(corner.X * 0.65, 9.65, corner.Z * 0.65),
			Vector3.new(0.15, 1.5, 0.15),
			LAMP_GREEN,
			Enum.Material.Metal
		)
	end
	box(parent, "LampCap", at + Vector3.new(0, 10.5, 0), Vector3.new(1.7, 0.25, 1.7), LAMP_GREEN, Enum.Material.Metal)
	box(parent, "LampCap", at + Vector3.new(0, 10.75, 0), Vector3.new(1.1, 0.25, 1.1), LAMP_GREEN, Enum.Material.Metal)
	local knob = part(parent, {
		Name = "LampKnob",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.45, 0.45, 0.45),
		Position = at + Vector3.new(0, 11.05, 0),
		Color = C.Gold,
		Material = Enum.Material.Metal,
	})
	knob.CanCollide = false
	local light = Instance.new("PointLight")
	light.Range = 22
	light.Brightness = 0.5
	light.Color = Color3.fromRGB(255, 220, 150)
	light:SetAttribute("DayBrightness", 0.5) -- (the day/night cycle in Look.luau turns it up at night)
	light:SetAttribute("NightBrightness", 2.6)
	CollectionService:AddTag(light, "NightLight")
	light.Parent = glow
end

-- A wooden park bench facing `facing`
function Kit.bench(parent: Instance, at: Vector3, facing: Vector3)
	local cf = CFrame.lookAt(at, at + Vector3.new(facing.X, 0, facing.Z))
	local wood = C.Wood
	local iron = Color3.fromRGB(45, 48, 55)
	for _, x in { -2.2, 2.2 } do
		part(
			parent,
			{ Name = "BenchLeg", Size = Vector3.new(0.4, 1.6, 1.8), CFrame = cf * CFrame.new(x, 0.8, 0), Color = iron }
		)
		part(parent, {
			Name = "BenchArm",
			Size = Vector3.new(0.4, 0.3, 1.8),
			CFrame = cf * CFrame.new(x, 2.2, 0.2),
			Color = iron,
		})
	end
	for i = 0, 2 do
		part(parent, {
			Name = "BenchSeat",
			Size = Vector3.new(5.2, 0.25, 0.5),
			CFrame = cf * CFrame.new(0, 1.65, -0.6 + i * 0.6),
			Color = wood,
		})
	end
	for i = 0, 1 do
		part(parent, {
			Name = "BenchBack",
			Size = Vector3.new(5.2, 0.5, 0.25),
			CFrame = cf * CFrame.new(0, 2.4 + i * 0.7, 0.95) * CFrame.Angles(math.rad(-10), 0, 0),
			Color = wood,
		})
	end
end

-- A little cottage: walls, a gable roof, a door, windows and a chimney. Faces `facing`.
function Kit.cottage(parent: Instance, at: Vector3, facing: Vector3, wall: Color3, roof: Color3, scale: number?)
	local k = scale or 1
	if
		Kit.model(parent, "Cottage", at, facing, 15 * k, false, {
			Walls = wall,
			Roof = roof,
			Shingles = roof:Lerp(Color3.new(0, 0, 0), 0.18),
			Shutters = roof:Lerp(Color3.new(0, 0, 0), 0.1),
		})
	then
		return
	end
	local cf = CFrame.lookAt(at, at + Vector3.new(facing.X, 0, facing.Z))
	local w, d, h = 14 * k, 11 * k, 8 * k
	part(
		parent,
		{ Name = "CottageWall", Size = Vector3.new(w, h, d), CFrame = cf * CFrame.new(0, h / 2, 0), Color = wall }
	)
	-- A gable roof: two wedges meeting at the ridge (a wedge's tall side is its back, so one is turned around)
	for _, side in { -1, 1 } do
		part(parent, {
			ClassName = "WedgePart",
			Name = "CottageRoof",
			Size = Vector3.new(w + 1.6 * k, 5 * k, d / 2 + 1 * k),
			CFrame = cf
				* CFrame.new(0, h + 2.5 * k, side * (d / 4 + 0.5 * k))
				* CFrame.Angles(0, if side == 1 then math.pi else 0, 0),
			Color = roof,
		})
	end
	part(parent, {
		Name = "Ridge",
		Size = Vector3.new(w + 1.8 * k, 0.5 * k, 0.8 * k),
		CFrame = cf * CFrame.new(0, h + 5.1 * k, 0),
		Color = roof:Lerp(Color3.new(0, 0, 0), 0.25),
	})
	part(parent, {
		Name = "Door",
		Size = Vector3.new(2.6 * k, 4.6 * k, 0.3),
		CFrame = cf * CFrame.new(0, 2.3 * k, -d / 2 - 0.1),
		Color = C.DarkWood,
	})
	part(parent, {
		Name = "DoorStep",
		Size = Vector3.new(4 * k, 0.4, 1.4 * k),
		CFrame = cf * CFrame.new(0, 0.2, -d / 2 - 0.7 * k),
		Color = C.PavingDark,
	})
	for _, x in { -4.2 * k, 4.2 * k } do
		part(parent, {
			Name = "Window",
			Size = Vector3.new(2.6 * k, 2.4 * k, 0.3),
			CFrame = cf * CFrame.new(x, 4.6 * k, -d / 2 - 0.1),
			Color = Color3.fromRGB(255, 236, 170),
			Material = Enum.Material.Neon,
		})
		part(parent, {
			Name = "WindowFrame",
			Size = Vector3.new(3.1 * k, 2.9 * k, 0.2),
			CFrame = cf * CFrame.new(x, 4.6 * k, -d / 2 - 0.02),
			Color = C.White,
		})
		part(parent, {
			Name = "Shutter",
			Size = Vector3.new(0.6 * k, 2.6 * k, 0.25),
			CFrame = cf * CFrame.new(x - 1.9 * k, 4.6 * k, -d / 2 - 0.15),
			Color = roof,
		})
		part(parent, {
			Name = "Shutter",
			Size = Vector3.new(0.6 * k, 2.6 * k, 0.25),
			CFrame = cf * CFrame.new(x + 1.9 * k, 4.6 * k, -d / 2 - 0.15),
			Color = roof,
		})
	end
	part(parent, {
		Name = "Chimney",
		Size = Vector3.new(1.6 * k, 5 * k, 1.6 * k),
		CFrame = cf * CFrame.new(w / 3, h + 4 * k, d / 5),
		Color = Color3.fromRGB(176, 92, 74),
	})
end

---------------------------------------------------------------------------------------------------
-- Roads

export type RoadStyle = {
	Pattern: "Pavers" | "Stepping" | "Asphalt",
	Bed: Color3, -- what's under and between the stones (mortar, dirt, snow, tarmac)
	Stones: { Color3 }, -- stone colors to vary between
	Curb: Color3?, -- raised edge stones (nil = no curbs)
}

Kit.ROADS = {
	Town = {
		Pattern = "Pavers",
		Bed = Color3.fromRGB(150, 126, 98),
		Stones = { Color3.fromRGB(196, 170, 134), Color3.fromRGB(182, 156, 120), Color3.fromRGB(208, 184, 150) },
		Curb = Color3.fromRGB(134, 128, 122),
	},
	Dirt = {
		Pattern = "Stepping",
		Bed = Color3.fromRGB(176, 140, 96),
		Stones = { Color3.fromRGB(170, 166, 158), Color3.fromRGB(150, 146, 140) },
	},
	Snow = {
		Pattern = "Stepping",
		Bed = Color3.fromRGB(214, 228, 240),
		Stones = { Color3.fromRGB(150, 176, 200), Color3.fromRGB(170, 194, 214) },
	},
	Jungle = {
		Pattern = "Pavers",
		Bed = Color3.fromRGB(90, 110, 70),
		Stones = { Color3.fromRGB(150, 150, 136), Color3.fromRGB(130, 136, 120), Color3.fromRGB(164, 160, 144) },
		Curb = Color3.fromRGB(96, 100, 88),
	},
	Volcano = {
		Pattern = "Pavers",
		Bed = Color3.fromRGB(150, 60, 30),
		Stones = { Color3.fromRGB(70, 64, 68), Color3.fromRGB(84, 78, 80), Color3.fromRGB(62, 56, 60) },
		Curb = Color3.fromRGB(46, 42, 46),
	},
	City = {
		Pattern = "Asphalt",
		Bed = Color3.fromRGB(70, 72, 80),
		Stones = { Color3.fromRGB(240, 240, 240) },
		Curb = Color3.fromRGB(176, 178, 186),
	},
} :: { [string]: RoadStyle }

-- A road from a to b (on the ground), `width` studs wide: a bed, then laid stones (rows of pavers in a
-- staggered pattern, or stepping stones, or tarmac with a dashed line), and curbstones down both sides.
function Kit.road(parent: Instance, a: Vector3, b: Vector3, width: number, style: RoadStyle, seed: number?)
	local flatA, flatB = Vector3.new(a.X, 0, a.Z), Vector3.new(b.X, 0, b.Z)
	local length = (flatB - flatA).Magnitude
	if length < 1 then
		return
	end
	local random = Random.new(seed or math.floor(a.X * 13 + a.Z * 7))
	local along = (flatB - flatA).Unit
	local mid = (flatA + flatB) / 2
	local cf = CFrame.lookAt(mid, mid + along) -- -Z runs from a to b, X runs across
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end
	part(parent, {
		Name = "RoadBed",
		Size = Vector3.new(width, 0.3, length),
		CFrame = at(0, 0.15, 0),
		Color = style.Bed,
	})
	local inner = if style.Curb then width - 2 else width
	if style.Pattern == "Pavers" then
		local rowLength = 2.6
		local stoneWidth = 3.2
		local rows = math.max(1, math.floor(length / rowLength))
		local across = math.max(1, math.floor(inner / stoneWidth))
		local w = inner / across
		for row = 0, rows - 1 do
			local z = -length / 2 + (row + 0.5) * length / rows
			local offset = if row % 2 == 0 then 0 else w / 2
			for k = 0, across do
				local x0 = -inner / 2 + k * w - offset
				local x1 = math.min(inner / 2, x0 + w)
				x0 = math.max(-inner / 2, x0)
				if x1 - x0 > 0.6 then
					part(parent, {
						Name = "Paver",
						Size = Vector3.new(x1 - x0 - 0.22, 0.14, length / rows - 0.22),
						CFrame = at((x0 + x1) / 2, 0.34 + random:NextNumber(-0.02, 0.02), z),
						Color = style.Stones[random:NextInteger(1, #style.Stones)],
					})
				end
			end
		end
	elseif style.Pattern == "Stepping" then
		local z = -length / 2 + 1.5
		while z < length / 2 - 1 do
			local r = random:NextNumber(1.1, 1.7)
			part(parent, {
				Name = "SteppingStone",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.3, r * 2, r * 2 * random:NextNumber(0.8, 1)),
				CFrame = at(random:NextNumber(-width * 0.18, width * 0.18), 0.36, z)
					* CFrame.Angles(0, random:NextNumber(0, math.pi), math.pi / 2),
				Color = style.Stones[random:NextInteger(1, #style.Stones)],
			})
			z += random:NextNumber(2.6, 3.4)
		end
	else
		-- Tarmac: a dashed white center line
		local z = -length / 2 + 2
		while z < length / 2 - 2 do
			part(parent, {
				Name = "RoadLine",
				Size = Vector3.new(0.4, 0.05, 2.4),
				CFrame = at(0, 0.32, z + 1.2),
				Color = style.Stones[1],
			})
			z += 5
		end
	end
	local curb = style.Curb
	if curb then
		local pieces = math.max(1, math.floor(length / 3.6))
		local pieceLength = length / pieces
		for _, side in { -1, 1 } do
			for k = 0, pieces - 1 do
				part(parent, {
					Name = "Curb",
					Size = Vector3.new(1, 0.55, pieceLength - 0.12),
					CFrame = at(side * (width / 2 - 0.5), 0.3, -length / 2 + (k + 0.5) * pieceLength),
					Color = curb:Lerp(Color3.new(1, 1, 1), if k % 2 == 0 then 0 else 0.08),
				})
			end
		end
	end
end

-- A wooden lantern post (bridges, piers): a post with a glowing lantern that brightens at night
function Kit.lantern(parent: Instance, at: Vector3, height: number?)
	local h = height or 6
	box(parent, "LanternPost", at + Vector3.new(0, h / 2, 0), Vector3.new(0.7, h, 0.7), C.DarkWood)
	box(parent, "LanternCap", at + Vector3.new(0, h + 1.15, 0), Vector3.new(1.4, 0.3, 1.4), Color3.fromRGB(45, 40, 38))
	local glow = box(
		parent,
		"Lantern",
		at + Vector3.new(0, h + 0.4, 0),
		Vector3.new(0.9, 1.1, 0.9),
		Color3.fromRGB(255, 214, 120),
		Enum.Material.Neon
	)
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 0.3
	light.Color = Color3.fromRGB(255, 210, 140)
	light:SetAttribute("DayBrightness", 0.3)
	light:SetAttribute("NightBrightness", 2.2)
	CollectionService:AddTag(light, "NightLight")
	light.Parent = glow
end

return Kit
