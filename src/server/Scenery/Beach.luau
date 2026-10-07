--!strict
-- The beach island (just for fun, reached from the Backyard): sand sloping into turquoise shallows, palm
-- trees, a red-and-white lighthouse on a rocky point, a tiki hut, umbrellas and towels, a pier out to sea, a
-- sandcastle, and an old shipwreck run aground in the shallows.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Kit)
local Islands = require(script.Parent.Islands)

local C = Kit.C
local part = Kit.part
local box = Kit.box
local World = Config.World

local Beach = {}

local function lighthouse(f: Instance, at: Vector3, random: Random)
	-- A rocky base
	for _ = 1, 4 do
		Kit.rock(
			f,
			at + Vector3.new(random:NextNumber(-5, 5), -1, random:NextNumber(-5, 5)),
			random:NextNumber(5, 8),
			random
		)
	end
	local model = Kit.model(f, "Lighthouse", at + Vector3.new(0, 1, 0), Vector3.new(at.X, 0, at.Z).Unit, 36, true)
	if model then
		-- the lamp room glows, and shines a beam out to sea
		local lamp = model:FindFirstChild("Lamp", true)
		if lamp and lamp:IsA("BasePart") then
			lamp.Material = Enum.Material.Neon
			local beam = Instance.new("SpotLight")
			beam.Range = 60
			beam.Angle = 30
			beam.Brightness = 2
			beam.Color = Color3.fromRGB(255, 240, 190)
			beam.Face = Enum.NormalId.Back
			beam.Parent = lamp
		end
		return
	end
	Kit.cylinder(f, "LighthouseBase", at + Vector3.new(0, 2, 0), 3, 6, Color3.fromRGB(150, 150, 156))
	-- Striped tower, getting a little narrower as it goes up
	for i = 0, 6 do
		Kit.cylinder(
			f,
			"LighthouseTower",
			at + Vector3.new(0, 5 + i * 4, 0),
			4,
			4.6 - i * 0.25,
			if i % 2 == 0 then Color3.fromRGB(226, 60, 56) else Color3.fromRGB(250, 248, 244)
		)
	end
	local top = at + Vector3.new(0, 33, 0)
	Kit.cylinder(f, "LighthouseDeck", top, 0.8, 4.4, Color3.fromRGB(60, 62, 72))
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		box(
			f,
			"Railing",
			top + Vector3.new(math.cos(a) * 4.1, 1.6, math.sin(a) * 4.1),
			Vector3.new(0.25, 1.6, 0.25),
			Color3.fromRGB(60, 62, 72)
		)
	end
	local lamp = Kit.cylinder(
		f,
		"LighthouseLamp",
		top + Vector3.new(0, 0.8, 0),
		3.4,
		2.6,
		Color3.fromRGB(255, 236, 160),
		{ Material = Enum.Material.Neon }
	)
	Kit.cylinder(
		f,
		"LighthouseGlass",
		top + Vector3.new(0, 0.8, 0),
		3.4,
		3,
		Color3.fromRGB(200, 230, 255),
		{ Material = Enum.Material.Glass, Transparency = 0.6 }
	)
	part(f, {
		ClassName = "WedgePart",
		Name = "LighthouseRoof",
		Size = Vector3.new(6.6, 3, 6.6),
		CFrame = CFrame.new(top + Vector3.new(0, 5.7, 0)),
		Color = Color3.fromRGB(226, 60, 56),
	})
	Kit.ball(f, "LighthouseTip", top + Vector3.new(0, 7.6, 0), 1, C.Gold)
	local beam = Instance.new("SpotLight")
	beam.Range = 60
	beam.Angle = 30
	beam.Brightness = 2
	beam.Color = Color3.fromRGB(255, 240, 190)
	beam.Parent = lamp
	box(f, "LighthouseDoor", at + Vector3.new(0, 7, -4.4), Vector3.new(2.4, 4, 0.4), C.DarkWood)
end

local function shipwreck(f: Instance, at: Vector3, facing: Vector3)
	if Kit.model(f, "Shipwreck", at - Vector3.new(0, 1.5, 0), facing, 26, false) then
		return
	end
	-- Run aground and leaning over, half in the water
	local cf = CFrame.lookAt(at, at + facing) * CFrame.Angles(0, 0, math.rad(14)) * CFrame.Angles(math.rad(-6), 0, 0)
	local hull = Color3.fromRGB(110, 72, 44)
	local hullDark = Color3.fromRGB(86, 56, 34)
	part(f, { Name = "Hull", Size = Vector3.new(9, 6, 26), CFrame = cf * CFrame.new(0, 0, 0), Color = hull })
	for _, side in { -1, 1 } do
		part(f, {
			ClassName = "WedgePart",
			Name = "HullBow",
			Size = Vector3.new(9, 6, 8) * Vector3.new(0.5, 1, 1),
			CFrame = cf * CFrame.new(side * 2.25, 0, -17) * CFrame.Angles(0, math.pi, 0),
			Color = hull,
		})
	end
	part(
		f,
		{ Name = "Deck", Size = Vector3.new(8.4, 0.4, 25), CFrame = cf * CFrame.new(0, 3.1, 0), Color = C.Plank[1] }
	)
	for z = -10, 10, 2 do
		part(f, {
			Name = "HullPlank",
			Size = Vector3.new(9.2, 0.35, 0.25),
			CFrame = cf * CFrame.new(0, 1.5, z),
			Color = hullDark,
		})
	end
	part(f, { Name = "Cabin", Size = Vector3.new(6, 4, 6), CFrame = cf * CFrame.new(0, 5.2, 8), Color = hull })
	part(f, {
		Name = "BrokenHole",
		Size = Vector3.new(0.3, 3, 4),
		CFrame = cf * CFrame.new(4.6, 0.6, -2),
		Color = Color3.fromRGB(30, 24, 20),
	})
	-- A snapped mast with a tattered sail, and the broken top lying across the deck
	part(f, { Name = "Mast", Size = Vector3.new(0.9, 16, 0.9), CFrame = cf * CFrame.new(0, 11, -3), Color = hullDark })
	part(f, { Name = "Yard", Size = Vector3.new(10, 0.6, 0.6), CFrame = cf * CFrame.new(0, 17, -3), Color = hullDark })
	part(f, {
		Name = "Sail",
		Size = Vector3.new(8, 7, 0.2),
		CFrame = cf * CFrame.new(0.4, 13.2, -2.6) * CFrame.Angles(0, 0, math.rad(4)),
		Color = Color3.fromRGB(240, 230, 205),
	})
	part(f, {
		Name = "SailTear",
		Size = Vector3.new(2.4, 3, 0.25),
		CFrame = cf * CFrame.new(2, 12, -2.6),
		Color = Color3.fromRGB(40, 120, 170),
	})
	part(f, {
		Name = "MastTop",
		Size = Vector3.new(0.7, 9, 0.7),
		CFrame = cf * CFrame.new(2.4, 4, 4) * CFrame.Angles(math.rad(80), math.rad(20), 0),
		Color = hullDark,
	})
	-- A flag
	part(f, {
		Name = "Flag",
		Size = Vector3.new(3, 2, 0.15),
		CFrame = cf * CFrame.new(1.6, 18.4, -3),
		Color = Color3.fromRGB(30, 30, 36),
	})
end

function Beach.Build(island: Islands.Island, bridgeEnd: Vector3)
	local f = Instance.new("Folder")
	f.Name = "Theme"
	f.Parent = island.Folder
	local random = Random.new(1717)
	local center = island.Center
	local toBridge = Vector3.new(bridgeEnd.X - center.X, 0, bridgeEnd.Z - center.Z).Unit
	local away = -toBridge
	local side = Vector3.new(0, 1, 0):Cross(away)
	local function free(p: Vector3, pad: number): boolean
		local offset = Vector3.new(p.X - center.X, 0, p.Z - center.Z)
		-- (keep the walkway from the bridge clear)
		local along = offset:Dot(toBridge)
		local across = math.abs(offset:Dot(side))
		return island.OnLand(p, pad + 2) and not (along > 0 and across < World.BridgeWidth / 2 + 4 + pad)
	end

	-- The lighthouse on the far point
	local point = center + away * (island.Outline(math.atan2(away.Z, away.X)) - 12)
	lighthouse(f, point, random)
	-- A tiki hut
	local hutAt = center + side * 22 + away * 6
	do
		local cf = CFrame.lookAt(hutAt, hutAt - side)
		local hut = Kit.model(f, "TikiHut", hutAt, -side, 13, false)
		if not hut then
			for _, x in { -4, 4 } do
				for _, z in { -3, 3 } do
					part(f, {
						Name = "HutPost",
						Size = Vector3.new(0.7, 7, 0.7),
						CFrame = cf * CFrame.new(x, 3.5, z),
						Color = C.DarkWood,
					})
				end
			end
			part(f, {
				Name = "HutCounter",
				Size = Vector3.new(9, 3, 1.4),
				CFrame = cf * CFrame.new(0, 1.5, -3.4),
				Color = C.Plank[2],
			})
			for i = 0, 3 do
				part(f, {
					Name = "HutThatch",
					Size = Vector3.new(11 - i * 2.4, 1.2, 9 - i * 2),
					CFrame = cf * CFrame.new(0, 7.4 + i * 1.1, 0),
					Color = if i % 2 == 0 then Color3.fromRGB(220, 190, 120) else Color3.fromRGB(200, 170, 100),
				})
			end
		end
		-- (the model's thatch is lower: hang the sign just under it)
		local sign = part(f, {
			Name = "HutSign",
			Size = Vector3.new(6, 1.6, 0.3),
			CFrame = cf * CFrame.new(0, if hut then 4.6 else 6.2, if hut then -3.2 else -3.6),
			Color = Color3.fromRGB(255, 120, 80),
		})
		Kit.signText(sign, Enum.NormalId.Front, "SMOOTHIES", Color3.new(1, 1, 1), nil, Color3.fromRGB(255, 120, 80))
	end
	-- Umbrellas with towels and chairs
	local stripes = {
		{ Color3.fromRGB(255, 90, 90), Color3.new(1, 1, 1) },
		{ Color3.fromRGB(80, 170, 255), Color3.fromRGB(255, 230, 90) },
		{ Color3.fromRGB(120, 220, 120), Color3.new(1, 1, 1) },
		{ Color3.fromRGB(255, 160, 60), Color3.fromRGB(80, 170, 255) },
	}
	local umbrellas = 0
	for _ = 1, 80 do
		if umbrellas >= 6 then
			break
		end
		local a = random:NextNumber(0, math.pi * 2)
		local p = center + Vector3.new(math.cos(a), 0, math.sin(a)) * random:NextNumber(12, island.Radius - 8)
		if free(p, 6) and (p - hutAt).Magnitude > 14 and (p - point).Magnitude > 16 then
			umbrellas += 1
			local colors = stripes[(umbrellas % #stripes) + 1]
			box(f, "UmbrellaPole", p + Vector3.new(0, 3.5, 0), Vector3.new(0.3, 7, 0.3), Color3.new(1, 1, 1))
			Kit.cylinder(f, "Umbrella", p + Vector3.new(0, 7, 0), 0.5, 4.6, colors[1], { CanCollide = false })
			Kit.cylinder(f, "Umbrella", p + Vector3.new(0, 7.45, 0), 0.4, 3, colors[2], { CanCollide = false })
			Kit.cylinder(f, "Umbrella", p + Vector3.new(0, 7.8, 0), 0.4, 1.4, colors[1], { CanCollide = false })
			local towelDir = Vector3.new(math.cos(a + 1), 0, math.sin(a + 1))
			part(f, {
				Name = "Towel",
				Size = Vector3.new(2.6, 0.1, 5),
				CFrame = CFrame.lookAt(
					p + towelDir * 3 + Vector3.new(0, 0.05, 0),
					p + towelDir * 4 + Vector3.new(0, 0.05, 0)
				),
				Color = colors[2]:Lerp(colors[1], 0.5),
				CanCollide = false,
			})
			part(f, {
				Name = "BeachChair",
				Size = Vector3.new(2.2, 0.4, 5),
				CFrame = CFrame.lookAt(
					p - towelDir * 3 + Vector3.new(0, 1, 0),
					p - towelDir * 4 + Vector3.new(0, 1, 0)
				) * CFrame.Angles(math.rad(-12), 0, 0),
				Color = Color3.new(1, 1, 1),
			})
		end
	end
	-- A sandcastle, a beach ball, starfish
	local castle = center - side * 18 + away * 10
	if free(castle, 3) then
		local sandy = Color3.fromRGB(226, 196, 136)
		box(f, "Sandcastle", castle + Vector3.new(0, 1, 0), Vector3.new(5, 2, 5), sandy)
		for _, c in { { -2, -2 }, { 2, -2 }, { -2, 2 }, { 2, 2 } } do
			Kit.cylinder(f, "CastleTower", castle + Vector3.new(c[1], 0, c[2]), 3.4, 0.9, sandy)
			part(f, {
				ClassName = "WedgePart",
				Name = "CastleTop",
				Size = Vector3.new(1.4, 1, 1.4),
				CFrame = CFrame.new(castle + Vector3.new(c[1], 3.9, c[2])),
				Color = sandy,
			})
		end
		box(f, "CastleFlag", castle + Vector3.new(0, 3.4, 0), Vector3.new(0.1, 2.8, 0.1), C.DarkWood)
		box(
			f,
			"CastleFlagCloth",
			castle + Vector3.new(0.6, 4.4, 0),
			Vector3.new(1.1, 0.7, 0.05),
			Color3.fromRGB(255, 80, 80)
		)
	end
	Kit.ball(f, "BeachBall", center + side * 10 - away * 6 + Vector3.new(0, 1.2, 0), 2.4, Color3.fromRGB(255, 220, 80))
	for _ = 1, 8 do
		local a = random:NextNumber(0, math.pi * 2)
		local p = center + Vector3.new(math.cos(a), 0, math.sin(a)) * (island.Outline(a) - random:NextNumber(2, 6))
		for i = 0, 4 do
			part(f, {
				Name = "Starfish",
				Size = Vector3.new(0.5, 0.2, 1.2),
				CFrame = CFrame.new(p + Vector3.new(0, 0.1, 0))
					* CFrame.Angles(0, i * 1.2566, 0)
					* CFrame.new(0, 0, -0.55),
				Color = Color3.fromRGB(255, 140, 90),
				CanCollide = false,
			})
		end
	end
	-- Palm trees
	local palms = 0
	for _ = 1, 120 do
		if palms >= 14 then
			break
		end
		local a = random:NextNumber(0, math.pi * 2)
		local p = center + Vector3.new(math.cos(a), 0, math.sin(a)) * random:NextNumber(10, island.Radius)
		if free(p, 4) and (p - hutAt).Magnitude > 10 and (p - point).Magnitude > 12 then
			palms += 1
			Kit.palm(f, p, random:NextNumber(15, 22), if random:NextNumber() < 0.5 then 1 else -1)
		end
	end
	-- A pier out to sea on the side, with a little boat tied up at the end
	local pierDir = Vector3.new(side.X + away.X * 0.3, 0, side.Z + away.Z * 0.3).Unit
	local pierStart = center + pierDir * (island.Outline(math.atan2(pierDir.Z, pierDir.X)) - 6)
	local pierLength = 36
	local pierCF = CFrame.lookAt(pierStart, pierStart + pierDir)
	for i = 0, math.floor(pierLength / 1.4) do
		part(f, {
			Name = "PierPlank",
			Size = Vector3.new(6, 0.4, 1.2),
			CFrame = pierCF * CFrame.new(0, 0.6, -i * 1.4),
			Color = C.Plank[random:NextInteger(1, #C.Plank)],
		})
	end
	for i = 1, 5 do
		for _, x in { -3.2, 3.2 } do
			part(f, {
				Name = "PierPost",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(16, 1.1, 1.1),
				CFrame = pierCF * CFrame.new(x, -6, -i * pierLength / 5) * CFrame.Angles(0, 0, math.rad(90)),
				Color = C.DarkWood,
			})
		end
	end
	Kit.lantern(f, (pierCF * CFrame.new(2.8, 0.8, -pierLength)).Position, 4)
	local boat = (pierCF * CFrame.new(5.5, World.WaterY + 0.6, -pierLength + 4)).Position
	if not Kit.model(f, "Rowboat", boat - Vector3.new(0, 0.4, 0), pierDir, 8, false) then
		part(f, {
			Name = "Rowboat",
			Size = Vector3.new(3, 1.4, 8),
			CFrame = CFrame.lookAt(boat, boat + pierDir),
			Color = Color3.fromRGB(70, 140, 220),
		})
		part(f, {
			Name = "RowboatSeat",
			Size = Vector3.new(2.8, 0.3, 1),
			CFrame = CFrame.lookAt(boat, boat + pierDir) * CFrame.new(0, 0.6, 0),
			Color = C.Plank[1],
		})
	end
	-- The shipwreck, aground in the shallows off the far side
	local wreckDir = Vector3.new(away.X - side.X * 0.6, 0, away.Z - side.Z * 0.6).Unit
	local wreckAt = center
		+ wreckDir * (island.Outline(math.atan2(wreckDir.Z, wreckDir.X)) + 22)
		+ Vector3.new(0, World.WaterY + 1, 0)
	shipwreck(f, wreckAt, side)
	-- Rocks along the shore
	for _ = 1, 6 do
		local a = random:NextNumber(0, math.pi * 2)
		local p = center
			+ Vector3.new(math.cos(a), 0, math.sin(a)) * (island.Outline(a) + random:NextNumber(4, 12))
			+ Vector3.new(0, World.WaterY - 1, 0)
		Kit.rock(f, p, random:NextNumber(3, 6), random)
	end
end

return Beach
