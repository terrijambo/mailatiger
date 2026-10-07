--!strict
-- The boss island: black volcanic rock, a round dark-stone arena floor (the fight itself and the stands are
-- BossService / BossArena), a giant skull gate on the side facing town, lava cracks and glowing pools with
-- embers drifting up, lava falls pouring down the cliffs, jagged spikes, and a smoking volcano behind the
-- stands.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Kit)
local Islands = require(script.Parent.Islands)

local part = Kit.part
local World = Config.World
local Boss = Config.Events.Boss

local Volcano = {}

local LAVA = Color3.fromRGB(255, 110, 30)
local LAVA_HOT = Color3.fromRGB(255, 190, 60)
local BASALT = { Color3.fromRGB(58, 52, 54), Color3.fromRGB(70, 62, 62), Color3.fromRGB(48, 44, 48) }

local function embers(parent: BasePart, rate: number)
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(LAVA_HOT, LAVA)
	e.LightEmission = 1
	e.Size = NumberSequence.new(0.35, 0.05)
	e.Speed = NumberRange.new(3, 7)
	e.SpreadAngle = Vector2.new(25, 25)
	e.Lifetime = NumberRange.new(1.5, 3)
	e.Rate = rate
	e.Acceleration = Vector3.new(0, 2, 0)
	e.Parent = parent
end

local function glow(parent: BasePart, range: number)
	local light = Instance.new("PointLight")
	light.Color = LAVA
	light.Range = range
	light.Brightness = 1.5
	light.Parent = parent
end

-- A jagged crack of lava from a to b
local function crack(f: Instance, a: Vector3, b: Vector3, random: Random)
	local points = { a }
	local steps = math.max(2, math.floor((b - a).Magnitude / 7))
	for i = 1, steps - 1 do
		local t = i / steps
		local p = a:Lerp(b, t)
		local side = Vector3.new(0, 1, 0):Cross((b - a).Unit)
		table.insert(points, p + side * random:NextNumber(-2.5, 2.5))
	end
	table.insert(points, b)
	for i = 1, #points - 1 do
		local p, q = points[i], points[i + 1]
		local seg = part(f, {
			Name = "LavaCrack",
			Size = Vector3.new(random:NextNumber(1, 1.8), 0.2, (q - p).Magnitude + 0.8),
			CFrame = CFrame.lookAt((p + q) / 2 + Vector3.new(0, 0.06, 0), q + Vector3.new(0, 0.06, 0)),
			Color = LAVA,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		if i == 2 then
			glow(seg, 12)
		end
	end
end

local function skullGate(f: Instance, at: Vector3, facing: Vector3)
	local cf = CFrame.lookAt(at, at + facing)
	local bone = Color3.fromRGB(206, 196, 170)
	-- Two spiky pillars
	for _, x in { -11, 11 } do
		for i = 0, 3 do
			part(f, {
				Name = "GatePillar",
				Size = Vector3.new(5 - i * 0.6, 5, 5 - i * 0.6),
				CFrame = cf * CFrame.new(x, 2.5 + i * 5, 0) * CFrame.Angles(0, i * 0.4, 0),
				Color = BASALT[(i % #BASALT) + 1],
			})
		end
		part(f, {
			ClassName = "WedgePart",
			Name = "GateSpike",
			Size = Vector3.new(3, 6, 3),
			CFrame = cf * CFrame.new(x, 23, 0),
			Color = BASALT[1],
		})
		local brazier = part(f, {
			Name = "Brazier",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(2.6, 2.6, 2.6),
			CFrame = cf * CFrame.new(x, 27, 0),
			Color = LAVA,
			Material = Enum.Material.Neon,
		})
		glow(brazier, 12)
		embers(brazier, 10)
	end
	-- The skull, between the pillars
	local skull = cf * CFrame.new(0, 19, 0)
	part(
		f,
		{ Name = "Skull", Shape = Enum.PartType.Ball, Size = Vector3.new(13, 13, 13), CFrame = skull, Color = bone }
	)
	part(
		f,
		{ Name = "SkullJaw", Size = Vector3.new(9, 3.4, 7), CFrame = skull * CFrame.new(0, -6, -1.6), Color = bone }
	)
	for i = -3, 3 do
		part(f, {
			ClassName = "WedgePart",
			Name = "Tooth",
			Size = Vector3.new(1, 1.4, 0.8),
			CFrame = skull * CFrame.new(i * 1.15, -4.2, -5) * CFrame.Angles(math.pi, 0, 0),
			Color = Color3.new(1, 1, 1),
		})
	end
	for _, x in { -2.6, 2.6 } do
		part(f, {
			Name = "EyeSocket",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(3.6, 3.6, 3.6),
			CFrame = skull * CFrame.new(x, 1, -4.6),
			Color = Color3.fromRGB(20, 16, 18),
		})
		part(f, {
			Name = "SkullEye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.6, 1.6, 1.6),
			CFrame = skull * CFrame.new(x, 1, -5.8),
			Color = Color3.fromRGB(255, 40, 30),
			Material = Enum.Material.Neon,
		})
	end
	part(f, {
		ClassName = "WedgePart",
		Name = "SkullNose",
		Size = Vector3.new(1.8, 1.8, 1),
		CFrame = skull * CFrame.new(0, -1.6, -6),
		Color = Color3.fromRGB(20, 16, 18),
	})
	-- Horns
	for _, x in { -1, 1 } do
		part(f, {
			ClassName = "WedgePart",
			Name = "Horn",
			Size = Vector3.new(1.6, 7, 3),
			CFrame = skull * CFrame.new(x * 6.4, 5, 0) * CFrame.Angles(0, 0, -x * 0.6),
			Color = bone:Lerp(Color3.new(0, 0, 0), 0.15),
		})
	end
	-- An iron crossbar and chains hanging from it
	part(f, {
		Name = "Crossbar",
		Size = Vector3.new(26, 1.4, 1.4),
		CFrame = cf * CFrame.new(0, 12, 1.5),
		Color = Color3.fromRGB(60, 58, 64),
	})
	for _, x in { -6, 6 } do
		for i = 0, 5 do
			part(f, {
				Name = "ChainLink",
				Size = Vector3.new(0.3, 1.2, 0.8),
				CFrame = cf
					* CFrame.new(x, 11 - i * 1.05, 1.5)
					* CFrame.Angles(0, if i % 2 == 0 then 0 else math.pi / 2, 0),
				Color = Color3.fromRGB(80, 78, 86),
			})
		end
	end
end

function Volcano.Build(island: Islands.Island, bridgeEnd: Vector3)
	local f = Instance.new("Folder")
	f.Name = "Theme"
	f.Parent = island.Folder
	local random = Random.new(666)
	local center = Boss.ArenaCenter
	local half = Boss.ArenaSize / 2
	local entrance = (World.ById.Boss.Gate or Vector3.xAxis)

	-- The arena floor: a round slab of dark stone with rings, a little above the island
	Kit.disc(f, "ArenaFloor", center, 0.12, 0.6, half + 6, Color3.fromRGB(78, 72, 76))
	Kit.disc(f, "ArenaFloor", center, 0.14, 0.6, half + 2, Color3.fromRGB(96, 90, 94))
	for _, ringRadius in { 20, 38 } do
		local count = math.floor(ringRadius * 2 * math.pi / 3)
		for i = 1, count do
			local a = i / count * math.pi * 2
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			part(f, {
				Name = "ArenaRing",
				Size = Vector3.new(ringRadius * 2 * math.pi / count + 0.05, 0.05, 0.6),
				CFrame = CFrame.lookAt(
					center + dir * ringRadius + Vector3.new(0, 0.15, 0),
					center + dir * (ringRadius + 1) + Vector3.new(0, 0.15, 0)
				),
				Color = Color3.fromRGB(70, 64, 68),
				CanCollide = false,
			})
		end
	end

	-- The skull gate, out past the entrance, on the path from the bridge
	local door = center + entrance * half
	local walk = Vector3.new(bridgeEnd.X - door.X, 0, bridgeEnd.Z - door.Z)
	skullGate(f, door + walk * 0.45, walk.Unit)
	local mid = (door + bridgeEnd) / 2
	part(f, {
		Name = "BossPath",
		Size = Vector3.new(World.BridgeWidth + 2, 0.24, ((center + entrance * half) - bridgeEnd).Magnitude + 6),
		CFrame = CFrame.lookAt(Vector3.new(mid.X, 0.1, mid.Z), Vector3.new(bridgeEnd.X, 0.1, bridgeEnd.Z)),
		Color = Color3.fromRGB(90, 84, 88),
	})

	-- Lava: cracks running out from the arena to the cliffs (between the stands), glowing pools, and two lava
	-- falls pouring down the cliff into the sea
	local function freeForLava(p: Vector3, pad: number): boolean
		local o = Vector3.new(p.X - center.X, 0, p.Z - center.Z)
		local inArena = math.abs(o.X) < half + 20 + pad and math.abs(o.Z) < half + 20 + pad
		local along = math.clamp((p - door):Dot(walk.Unit), 0, walk.Magnitude + 4)
		local nearest = door + walk.Unit * along
		local onPath = Vector3.new(p.X - nearest.X, 0, p.Z - nearest.Z).Magnitude < World.BridgeWidth / 2 + 8 + pad
		return island.OnLand(p, pad) and not inArena and not onPath
	end
	for i = 0, 7 do
		local a = (i + 0.5) / 8 * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local from = center + dir * (half + 22)
		local to = center + dir * (island.Outline(a) - 3)
		if freeForLava(from, 0) then
			crack(f, from, to, random)
		end
	end
	local pools = 0
	for _ = 1, 60 do
		if pools >= 5 then
			break
		end
		local a = random:NextNumber(0, math.pi * 2)
		local p = center + Vector3.new(math.cos(a), 0, math.sin(a)) * random:NextNumber(half + 24, island.Radius)
		if freeForLava(p, 5) then
			pools += 1
			Kit.disc(f, "LavaRim", p, 0.3, 0.8, 5.5, BASALT[1])
			local pool =
				Kit.disc(f, "LavaPool", p, 0.4, 0.6, 4.4, LAVA, { Material = Enum.Material.Neon, CanCollide = false })
			glow(pool, 18)
			embers(pool, 6)
		end
	end
	for _, a in { random:NextNumber(0, 6.28), random:NextNumber(0, 6.28) } do
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local edge = center + dir * (island.Outline(a) + 0.5)
		if freeForLava(center + dir * (island.Outline(a) - 4), 0) then
			part(f, {
				Name = "LavaFall",
				Size = Vector3.new(3.4, -World.WaterY + 1, 0.6),
				CFrame = CFrame.lookAt(
					edge + Vector3.new(0, World.WaterY / 2, 0),
					edge + dir + Vector3.new(0, World.WaterY / 2, 0)
				),
				Color = LAVA,
				Material = Enum.Material.Neon,
				CanCollide = false,
			})
			local steam = part(f, {
				Name = "Steam",
				Size = Vector3.new(4, 1, 4),
				CFrame = CFrame.new(edge + dir * 2 + Vector3.new(0, World.WaterY, 0)),
				Transparency = 1,
				CanCollide = false,
				CanQuery = false,
			})
			local s = Instance.new("ParticleEmitter")
			s.Color = ColorSequence.new(Color3.fromRGB(230, 230, 230))
			s.Size = NumberSequence.new(3, 7)
			s.Transparency = NumberSequence.new(0.5, 1)
			s.Speed = NumberRange.new(3, 6)
			s.Lifetime = NumberRange.new(2, 3)
			s.Rate = 8
			s.Parent = steam
		end
	end

	-- Jagged basalt spikes around the edges
	for _ = 1, 40 do
		local a = random:NextNumber(0, math.pi * 2)
		local p = center + Vector3.new(math.cos(a), 0, math.sin(a)) * random:NextNumber(half + 26, island.Radius)
		if freeForLava(p, 3) then
			local h = random:NextNumber(4, 11)
			part(f, {
				ClassName = "WedgePart",
				Name = "Spike",
				Size = Vector3.new(random:NextNumber(2, 4), h, random:NextNumber(2, 4)),
				CFrame = CFrame.new(p + Vector3.new(0, h / 2 - 0.5, 0)) * CFrame.Angles(
					random:NextNumber(-0.2, 0.2),
					random:NextNumber(0, 6.28),
					random:NextNumber(-0.2, 0.2)
				),
				Color = BASALT[random:NextInteger(1, #BASALT)],
			})
		end
	end

	-- A smoking volcano behind the stands
	local back = center - entrance * (island.Outline(math.atan2(-entrance.Z, -entrance.X)) - 14)
	for i = 0, 5 do
		Kit.cylinder(f, "VolcanoCone", back + Vector3.new(0, i * 5, 0), 5.2, 13 - i * 1.8, BASALT[(i % #BASALT) + 1])
	end
	local crater = Kit.disc(f, "Crater", back, 30.4, 1, 3.6, LAVA, { Material = Enum.Material.Neon })
	glow(crater, 40)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Color = ColorSequence.new(Color3.fromRGB(70, 66, 70), Color3.fromRGB(150, 146, 150))
	smoke.Size = NumberSequence.new(6, 16)
	smoke.Transparency = NumberSequence.new(0.3, 1)
	smoke.Speed = NumberRange.new(6, 10)
	smoke.SpreadAngle = Vector2.new(15, 15)
	smoke.Lifetime = NumberRange.new(5, 8)
	smoke.Rate = 6
	smoke.Parent = crater
	embers(crater, 20)
end

return Volcano
