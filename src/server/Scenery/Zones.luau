--!strict
-- Each zone's island, dressed around its play area (MapBuilder builds the play area itself: floor, fence,
-- gate, the obstacles the animals steer around). Every theme keeps clear of the play area and of the path
-- from the bridge to the gate.
--   Backyard  cottages, a vegetable garden, a pond with lily pads, a swing set, gnomes and flowers
--   Barn      a silo, a windmill, wheat fields, a pumpkin patch, a chicken coop, a tractor, a scarecrow
--   Jungle    giant trees with vines, temple ruins, broken columns, a stone idol, a waterfall into a pool
--   Ice Rink  snowy pines, glowing ice crystals, an igloo, a frozen pond, snowfall
--   Rooftop   a city block: streets, skyscrapers with lit windows, a crane, a billboard, a helipad on top

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Kit)
local Islands = require(script.Parent.Islands)

local C = Kit.C
local part = Kit.part
local box = Kit.box
local World = Config.World

local Zones = {}

export type Zone = {
	Id: string,
	Name: string,
	Color: Color3,
	Icon: string,
	Min: Vector3, -- the open ground in the middle (MapBuilder): scenery keeps off it
	Max: Vector3,
	FloorY: number,
	Facing: Vector3, -- toward the gate / town
	-- The animals roam the whole island: scenery that's in the way goes in here, so they steer round it
	Obstacles: { { Center: Vector3, Radius: number } },
}

type Ctx = {
	Zone: Zone,
	Island: Islands.Island,
	Folder: Folder,
	Random: Random,
	Center: Vector3, -- the play area's center at ground level
	F: Vector3, -- toward the gate
	R: Vector3, -- across
	HU: number, -- half the play area across...
	HW: number, -- ...and along
	BridgeEnd: Vector3,
	Gate: Vector3, -- just outside the gate
	Free: (Vector3, number) -> boolean, -- on the island, clear of the play area and the approach path
	At: (number, number) -> Vector3, -- a ground point from (across, along) around the play area's center
}

local function segmentDistance(p: Vector3, a: Vector3, b: Vector3): number
	local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local ap = Vector3.new(p.X - a.X, 0, p.Z - a.Z)
	local t = math.clamp(ap:Dot(ab) / math.max(ab:Dot(ab), 0.001), 0, 1)
	return (ap - ab * t).Magnitude
end

-- Fills the free ground with `count` things made by `make`
-- Something big the roaming animals should steer around
local function solid(ctx: Ctx, at: Vector3, radius: number)
	table.insert(ctx.Zone.Obstacles, { Center = at, Radius = radius })
end

local function scatter(ctx: Ctx, count: number, pad: number, make: (Vector3) -> ())
	local placed = 0
	for _ = 1, count * 12 do
		if placed >= count then
			return
		end
		local a = ctx.Random:NextNumber(0, math.pi * 2)
		-- out toward the cliffs, leaving the middle of the island open for chasing animals (and each other)
		local p = ctx.Island.Center
			+ Vector3.new(math.cos(a), 0, math.sin(a))
				* ctx.Island.Radius
				* math.sqrt(ctx.Random:NextNumber(0.36, 1.17))
		if ctx.Free(p, pad) then
			placed += 1
			make(p)
			if pad >= 3 then -- (trees, hay, rocks: not flowers and ferns)
				table.insert(ctx.Zone.Obstacles, { Center = p, Radius = pad })
			end
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Backyard

local function backyard(ctx: Ctx)
	local f, r, random = ctx.Folder, ctx.R, ctx.Random
	-- Cottages behind and beside the yard, facing it
	local houses: { { any } } = {
		{ -24, -ctx.HW - 22, Color3.fromRGB(250, 236, 205), Color3.fromRGB(70, 120, 210) },
		{ 26, -ctx.HW - 20, Color3.fromRGB(255, 220, 140), Color3.fromRGB(210, 80, 70) },
		{ ctx.HU + 22, -6, Color3.fromRGB(214, 236, 255), Color3.fromRGB(90, 160, 110) },
	}
	for _, h in houses do
		local p = ctx.At(h[1], h[2])
		Kit.cottage(f, p, (ctx.Center - p).Unit, h[3], h[4], 1.05)
		solid(ctx, p, 9)
	end
	-- A vegetable garden (rows of soil with sprouts), on the open side
	local garden = ctx.At(-ctx.HU - 18, 8)
	if ctx.Free(garden, 6) then
		for row = -2, 2 do
			local p = garden + ctx.F * row * 3.2
			part(f, {
				Name = "Soil",
				Size = Vector3.new(2.2, 0.6, 12),
				CFrame = CFrame.lookAt(p + Vector3.new(0, 0.3, 0), p + r + Vector3.new(0, 0.3, 0)),
				Color = Color3.fromRGB(120, 86, 58),
			})
			for i = -2, 2 do
				Kit.ball(f, "Sprout", p + r * i * 2.4 + Vector3.new(0, 0.9, 0), 1.1, Color3.fromRGB(90, 190, 70))
			end
		end
	end
	-- A pond with lily pads
	local pond = ctx.At(ctx.HU + 20, ctx.HW + 4)
	if ctx.Free(pond, 4) then
		Kit.disc(f, "PondRim", pond, 0.25, 0.5, 9, Color3.fromRGB(150, 150, 140))
		Kit.disc(
			f,
			"Pond",
			pond,
			0.3,
			0.5,
			8,
			Color3.fromRGB(70, 170, 210),
			{ Material = Enum.Material.Glass, Transparency = 0.15 }
		)
		for i = 1, 5 do
			local a = i * 1.3
			Kit.disc(
				f,
				"LilyPad",
				pond + Vector3.new(math.cos(a), 0, math.sin(a)) * random:NextNumber(2, 6),
				0.42,
				0.12,
				random:NextNumber(0.8, 1.3),
				Color3.fromRGB(70, 160, 70)
			)
		end
		Kit.ball(f, "LilyFlower", pond + Vector3.new(2, 0.6, 1), 0.7, Color3.fromRGB(255, 160, 200))
	end
	-- A swing set
	local swing = ctx.At(-ctx.HU - 16, -ctx.HW - 4)
	if ctx.Free(swing, 5) then
		local cf = CFrame.lookAt(swing, swing + ctx.F)
		for _, x in { -5, 5 } do
			for _, z in { -1.6, 1.6 } do
				part(f, {
					Name = "SwingLeg",
					Size = Vector3.new(0.5, 8.4, 0.5),
					CFrame = cf * CFrame.new(x, 4, z * 0.5) * CFrame.Angles(math.rad(z * 9), 0, 0),
					Color = Color3.fromRGB(220, 70, 60),
				})
			end
		end
		part(f, {
			Name = "SwingBar",
			Size = Vector3.new(11, 0.5, 0.5),
			CFrame = cf * CFrame.new(0, 8, 0),
			Color = Color3.fromRGB(240, 200, 60),
		})
		for _, x in { -2.2, 2.2 } do
			for _, side in { -0.6, 0.6 } do
				part(f, {
					Name = "SwingRope",
					Size = Vector3.new(0.1, 5.5, 0.1),
					CFrame = cf * CFrame.new(x + side, 5.25, 0),
					Color = C.Rope,
				})
			end
			part(f, {
				Name = "SwingSeat",
				Size = Vector3.new(1.8, 0.25, 1),
				CFrame = cf * CFrame.new(x, 2.5, 0),
				Color = Color3.fromRGB(70, 120, 225),
			})
		end
	end
	-- Trees, bushes, flowers, gnomes
	local flowerColors = {
		Color3.fromRGB(255, 120, 150),
		Color3.fromRGB(255, 220, 90),
		Color3.fromRGB(170, 130, 255),
		Color3.fromRGB(255, 255, 255),
	}
	scatter(ctx, 22, 5, function(p)
		Kit.tree(f, p, random:NextNumber(13, 20))
	end)
	scatter(ctx, 18, 2, function(p)
		Kit.flowers(f, p, flowerColors[random:NextInteger(1, #flowerColors)], random)
	end)
	scatter(ctx, 10, 3, function(p)
		Kit.bush(f, p, random:NextNumber(2.4, 3.6))
	end)
	scatter(ctx, 4, 2, function(p)
		-- A garden gnome
		box(f, "GnomeBody", p + Vector3.new(0, 0.7, 0), Vector3.new(0.9, 1.4, 0.9), Color3.fromRGB(70, 110, 220))
		Kit.ball(f, "GnomeHead", p + Vector3.new(0, 1.7, 0), 0.8, Color3.fromRGB(255, 210, 180))
		Kit.ball(f, "GnomeBeard", p + Vector3.new(0, 1.45, 0.25), 0.6, Color3.new(1, 1, 1))
		part(f, {
			ClassName = "WedgePart",
			Name = "GnomeHat",
			Size = Vector3.new(0.8, 1.2, 0.8),
			CFrame = CFrame.new(p + Vector3.new(0, 2.5, 0)),
			Color = Color3.fromRGB(220, 50, 50),
		})
	end)
end

---------------------------------------------------------------------------------------------------
-- Barn

local function barnZone(ctx: Ctx)
	local f, r, random = ctx.Folder, ctx.R, ctx.Random
	-- A silo beside the barn (the barn itself is behind the play area: MapBuilder)
	local silo = ctx.At(-34, -ctx.HW - 14)
	solid(ctx, silo, 6)
	if not Kit.model(f, "Silo", silo, (ctx.Center - silo).Unit, 30, true) then
		Kit.cylinder(f, "Silo", silo, 30, 6.5, Color3.fromRGB(196, 64, 54))
		for y = 4, 28, 6 do
			Kit.cylinder(f, "SiloBand", silo + Vector3.new(0, y, 0), 0.6, 6.7, Color3.fromRGB(230, 230, 236))
		end
		Kit.ball(f, "SiloDome", silo + Vector3.new(0, 30, 0), 13, Color3.fromRGB(200, 205, 214))
	end
	-- A windmill: a tapered tower, a cap, and four sails
	local mill = ctx.At(ctx.HU + 20, -ctx.HW - 10)
	solid(ctx, mill, 5)
	if ctx.Free(mill, 4) then
		local face = (ctx.Center - mill).Unit
		local cf = CFrame.lookAt(mill, mill + face)
		if not Kit.model(f, "Windmill", mill, face, 30, true) then
			for i = 0, 3 do
				part(f, {
					Name = "MillTower",
					Size = Vector3.new(7 - i, 6, 7 - i),
					CFrame = cf * CFrame.new(0, 3 + i * 6, 0),
					Color = if i % 2 == 0 then Color3.fromRGB(240, 236, 226) else Color3.fromRGB(226, 220, 208),
				})
			end
			part(f, {
				ClassName = "WedgePart",
				Name = "MillCap",
				Size = Vector3.new(5, 3, 5),
				CFrame = cf * CFrame.new(0, 25.5, 0),
				Color = Color3.fromRGB(150, 70, 50),
			})
			local hub = cf * CFrame.new(0, 22, -3)
			Kit.ball(f, "MillHub", hub.Position, 1.6, C.DarkWood)
			for i = 0, 3 do
				local sail = hub * CFrame.Angles(0, 0, i * math.pi / 2 + 0.4) * CFrame.new(0, 5.5, -0.4)
				part(f, { Name = "MillArm", Size = Vector3.new(0.6, 11, 0.4), CFrame = sail, Color = C.DarkWood })
				part(f, {
					Name = "MillSail",
					Size = Vector3.new(2.4, 8, 0.15),
					CFrame = sail * CFrame.new(1.5, 1, 0),
					Color = Color3.fromRGB(250, 245, 230),
				})
			end
		end
	end
	-- Fields: rows of wheat and corn, and a pumpkin patch
	local fields: { { any } } =
		{ { -ctx.HU - 20, 4, Color3.fromRGB(240, 205, 90) }, { ctx.HU + 22, 18, Color3.fromRGB(120, 190, 70) } }
	for index, field in fields do
		local p = ctx.At(field[1], field[2])
		if ctx.Free(p, 8) then
			for row = -3, 3 do
				local rowAt = p + ctx.F * row * 3
				part(f, {
					Name = "FieldRow",
					Size = Vector3.new(14, 1.4, 1.8),
					CFrame = CFrame.lookAt(rowAt + Vector3.new(0, 0.7, 0), rowAt + Vector3.new(0, 0.7, 0) + ctx.F)
						* CFrame.Angles(0, math.pi / 2, 0),
					Color = field[3],
				})
				part(f, {
					Name = "Furrow",
					Size = Vector3.new(14, 0.3, 1.2),
					CFrame = CFrame.lookAt(
						rowAt + ctx.F * 1.5 + Vector3.new(0, 0.15, 0),
						rowAt + ctx.F * 2.5 + Vector3.new(0, 0.15, 0)
					) * CFrame.Angles(0, math.pi / 2, 0),
					Color = Color3.fromRGB(150, 110, 70),
				})
			end
			if index == 1 then
				-- A scarecrow in the wheat
				local s = p + Vector3.new(0, 0, 0)
				if not Kit.model(f, "Scarecrow", s, -ctx.F, 8.5, true) then
					box(f, "ScarecrowPost", s + Vector3.new(0, 3.5, 0), Vector3.new(0.4, 7, 0.4), C.DarkWood)
					part(f, {
						Name = "ScarecrowArms",
						Size = Vector3.new(6, 0.4, 0.4),
						CFrame = CFrame.lookAt(s + Vector3.new(0, 5.5, 0), s + Vector3.new(0, 5.5, 0) + ctx.F)
							* CFrame.Angles(0, math.pi / 2, 0),
						Color = C.DarkWood,
					})
					box(
						f,
						"ScarecrowShirt",
						s + Vector3.new(0, 4.8, 0),
						Vector3.new(1.8, 2.2, 1.2),
						Color3.fromRGB(80, 120, 200)
					)
					Kit.ball(f, "ScarecrowHead", s + Vector3.new(0, 6.6, 0), 1.6, Color3.fromRGB(230, 200, 130))
					Kit.cylinder(f, "ScarecrowHat", s + Vector3.new(0, 7.2, 0), 0.3, 1.6, Color3.fromRGB(150, 110, 60))
					Kit.cylinder(f, "ScarecrowHatTop", s + Vector3.new(0, 7.5, 0), 1, 0.8, Color3.fromRGB(150, 110, 60))
				end
			end
		end
	end
	local patch = ctx.At(ctx.HU + 18, ctx.HW + 2)
	if ctx.Free(patch, 5) then
		for _ = 1, 9 do
			local p = patch + Vector3.new(random:NextNumber(-5, 5), 0, random:NextNumber(-5, 5))
			Kit.ball(
				f,
				"Pumpkin",
				p + Vector3.new(0, 0.9, 0),
				random:NextNumber(1.6, 2.4),
				Color3.fromRGB(245, 140, 40)
			)
			box(f, "PumpkinStem", p + Vector3.new(0, 2, 0), Vector3.new(0.25, 0.6, 0.25), Color3.fromRGB(90, 140, 60))
		end
	end
	-- A chicken coop
	local coop = ctx.At(-ctx.HU - 16, -16)
	if ctx.Free(coop, 5) then
		local face = (ctx.Center - coop).Unit
		local cf = CFrame.lookAt(coop, coop + face)
		part(f, {
			Name = "CoopHouse",
			Size = Vector3.new(6, 4, 5),
			CFrame = cf * CFrame.new(0, 3.2, 0),
			Color = Color3.fromRGB(220, 190, 140),
		})
		for _, x in { -2.6, 2.6 } do
			for _, z in { -2, 2 } do
				box(f, "CoopLeg", (cf * CFrame.new(x, 0.6, z)).Position, Vector3.new(0.4, 1.2, 0.4), C.DarkWood)
			end
		end
		for _, side in { -1, 1 } do
			part(f, {
				ClassName = "WedgePart",
				Name = "CoopRoof",
				Size = Vector3.new(7, 2, 3),
				CFrame = cf * CFrame.new(0, 6.2, side * 1.5) * CFrame.Angles(0, if side == 1 then math.pi else 0, 0),
				Color = Color3.fromRGB(196, 64, 54),
			})
		end
		part(f, {
			Name = "CoopRamp",
			Size = Vector3.new(1.4, 0.2, 3),
			CFrame = cf * CFrame.new(0, 0.7, -3.4) * CFrame.Angles(math.rad(20), 0, 0),
			Color = C.Wood,
		})
	end
	-- A little red tractor
	local tractor = ctx.At(ctx.HU + 14, -ctx.HW - 4)
	solid(ctx, tractor, 5)
	if ctx.Free(tractor, 4) then
		local cf = CFrame.lookAt(tractor, tractor + r)
		if not Kit.model(f, "Tractor", tractor, r, 9, false) then
			part(f, {
				Name = "TractorBody",
				Size = Vector3.new(3.4, 2.4, 6),
				CFrame = cf * CFrame.new(0, 2.4, 0),
				Color = Color3.fromRGB(210, 50, 45),
			})
			part(f, {
				Name = "TractorCab",
				Size = Vector3.new(3.2, 3, 2.6),
				CFrame = cf * CFrame.new(0, 4.6, 1.4),
				Color = Color3.fromRGB(230, 230, 236),
				Material = Enum.Material.Glass,
				Transparency = 0.3,
			})
			part(f, {
				Name = "TractorRoof",
				Size = Vector3.new(3.6, 0.3, 3),
				CFrame = cf * CFrame.new(0, 6.2, 1.4),
				Color = Color3.fromRGB(210, 50, 45),
			})
			box(f, "TractorPipe", (cf * CFrame.new(0.8, 4.4, -2)).Position, Vector3.new(0.4, 2, 0.4), C.Dark)
			for _, w in { { -2, 1.6, 1.6 }, { 2, 1.6, 1.6 }, { -1.9, -2, 1 }, { 1.9, -2, 1 } } do
				part(f, {
					Name = "TractorWheel",
					Shape = Enum.PartType.Cylinder,
					Size = Vector3.new(1, w[3] * 2, w[3] * 2),
					CFrame = cf * CFrame.new(w[1], w[3], w[2]),
					Color = Color3.fromRGB(40, 40, 44),
				})
			end
		end
	end
	-- Hay, crates and trees
	scatter(ctx, 8, 3, function(p)
		box(f, "Hay", p + Vector3.new(0, 1.6, 0), Vector3.new(4, 3.2, 4), Color3.fromRGB(236, 205, 100))
	end)
	scatter(ctx, 6, 2, function(p)
		box(
			f,
			"Crate",
			p + Vector3.new(0, 1.2, 0),
			Vector3.new(2.4, 2.4, 2.4),
			C.Plank[random:NextInteger(1, #C.Plank)]
		)
	end)
	scatter(ctx, 14, 5, function(p)
		Kit.tree(f, p, random:NextNumber(14, 20))
	end)
end

---------------------------------------------------------------------------------------------------
-- Jungle

local function jungle(ctx: Ctx)
	local f, random = ctx.Folder, ctx.Random
	local mossy = { Color3.fromRGB(140, 150, 130), Color3.fromRGB(126, 138, 118), Color3.fromRGB(150, 158, 140) }
	local moss = Color3.fromRGB(80, 150, 70)
	-- Temple ruins behind the play area: a stepped pyramid with a doorway and moss on every step
	local temple = ctx.At(0, -ctx.HW - 24)
	solid(ctx, temple, 16)
	local tcf = CFrame.lookAt(temple, temple + ctx.F)
	for i = 0, 4 do
		local w = 30 - i * 5
		part(f, {
			Name = "TempleStep",
			Size = Vector3.new(w, 4, w * 0.8),
			CFrame = tcf * CFrame.new(0, 2 + i * 4, 0),
			Color = mossy[(i % #mossy) + 1],
		})
		part(f, {
			Name = "Moss",
			Size = Vector3.new(w + 0.2, 0.5, w * 0.8 + 0.2),
			CFrame = tcf * CFrame.new(0, 4 + i * 4, 0),
			Color = moss,
		})
	end
	part(f, {
		Name = "TempleDoor",
		Size = Vector3.new(5, 7, 1),
		CFrame = tcf * CFrame.new(0, 3.5, -12.1),
		Color = Color3.fromRGB(40, 40, 44),
	})
	part(
		f,
		{ Name = "TempleShrine", Size = Vector3.new(7, 6, 6), CFrame = tcf * CFrame.new(0, 23, 0), Color = mossy[1] }
	)
	Kit.ball(
		f,
		"TempleGem",
		(tcf * CFrame.new(0, 27.5, 0)).Position,
		2.2,
		Color3.fromRGB(60, 230, 140),
		{ Material = Enum.Material.Neon }
	)
	-- A stone idol head
	local idol = ctx.At(ctx.HU + 16, -ctx.HW + 2)
	if ctx.Free(idol, 4) then
		local cf = CFrame.lookAt(idol, idol + (ctx.Center - idol).Unit)
		part(f, { Name = "IdolHead", Size = Vector3.new(6, 8, 5), CFrame = cf * CFrame.new(0, 4, 0), Color = mossy[2] })
		part(f, {
			Name = "IdolBrow",
			Size = Vector3.new(6.4, 1, 1.4),
			CFrame = cf * CFrame.new(0, 5.6, -2.4),
			Color = mossy[3],
		})
		for _, x in { -1.5, 1.5 } do
			part(f, {
				Name = "IdolEye",
				Size = Vector3.new(1.2, 0.8, 0.3),
				CFrame = cf * CFrame.new(x, 4.8, -2.55),
				Color = Color3.fromRGB(255, 200, 60),
				Material = Enum.Material.Neon,
			})
		end
		part(f, {
			Name = "IdolMouth",
			Size = Vector3.new(3.4, 1, 0.3),
			CFrame = cf * CFrame.new(0, 2, -2.55),
			Color = Color3.fromRGB(40, 40, 44),
		})
		part(f, { Name = "Moss", Size = Vector3.new(6.2, 0.6, 5.2), CFrame = cf * CFrame.new(0, 8.2, 0), Color = moss })
	end
	-- Broken columns
	scatter(ctx, 5, 3, function(p)
		local h = random:NextNumber(4, 10)
		Kit.cylinder(f, "Column", p, h, 1.6, mossy[random:NextInteger(1, #mossy)])
		Kit.cylinder(f, "ColumnBase", p, 1, 2.2, mossy[1])
		part(f, {
			Name = "ColumnChunk",
			Size = Vector3.new(2.6, 2, 2.6),
			CFrame = CFrame.new(p + Vector3.new(random:NextNumber(2, 3), 1, random:NextNumber(-2, 2)))
				* CFrame.Angles(0.3, 0.6, 0.2),
			Color = mossy[2],
		})
	end)
	-- A waterfall: a rocky outcrop with water pouring down into a pool
	local fall = ctx.At(-ctx.HU - 18, -ctx.HW - 6)
	if ctx.Free(fall, 6) then
		local face = (ctx.Center - fall).Unit
		local cf = CFrame.lookAt(fall, fall + face)
		for i, rock in
			{ { 0, 10, 0, 16, 20, 10 }, { -6, 7, 2, 8, 14, 8 }, { 7, 8, 1, 7, 16, 8 }, { 0, 21, -1, 12, 4, 9 } }
		do
			part(f, {
				Name = "FallRock",
				Size = Vector3.new(rock[4], rock[5], rock[6]),
				CFrame = cf * CFrame.new(rock[1], rock[2], rock[3] + 3) * CFrame.Angles(0, (i - 2) * 0.12, 0),
				Color = Kit.C.Rock[(i % #Kit.C.Rock) + 1],
			})
		end
		part(
			f,
			{ Name = "Moss", Size = Vector3.new(12.4, 0.6, 9.4), CFrame = cf * CFrame.new(0, 23.2, 2), Color = moss }
		)
		part(f, {
			Name = "Waterfall",
			Size = Vector3.new(5, 22, 0.8),
			CFrame = cf * CFrame.new(0, 11, -2.3),
			Color = Color3.fromRGB(150, 220, 255),
			Material = Enum.Material.Glass,
			Transparency = 0.3,
			CanCollide = false,
		})
		local pool = (cf * CFrame.new(0, 0, -8)).Position
		Kit.disc(f, "PoolRim", pool, 0.3, 0.6, 8, mossy[1])
		local water = Kit.disc(
			f,
			"Pool",
			pool,
			0.4,
			0.6,
			7,
			Color3.fromRGB(70, 180, 220),
			{ Material = Enum.Material.Glass, Transparency = 0.2, CanCollide = false }
		)
		local mist = Instance.new("ParticleEmitter")
		mist.Color = ColorSequence.new(Color3.new(1, 1, 1))
		mist.Size = NumberSequence.new(2, 5)
		mist.Transparency = NumberSequence.new(0.5, 1)
		mist.Speed = NumberRange.new(2, 4)
		mist.Lifetime = NumberRange.new(1, 2)
		mist.Rate = 14
		mist.Parent = water
	end
	-- A river from a spring behind the ruins, across the island and over the cliff into the sea as a waterfall
	do
		local back = -ctx.F
		local a = math.atan2(back.Z + ctx.R.Z * 0.8, back.X + ctx.R.X * 0.8)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local edgeDistance = ctx.Island.Outline(a)
		local spring = ctx.Island.Center + dir * (edgeDistance * 0.55)
		local lip = ctx.Island.Center + dir * (edgeDistance + 0.5)
		if ctx.Free(spring, 0) then
			local length = (lip - spring).Magnitude
			local mid = (spring + lip) / 2
			part(f, {
				Name = "RiverBank",
				Size = Vector3.new(9, 0.3, length),
				CFrame = CFrame.lookAt(mid + Vector3.new(0, 0.12, 0), lip + Vector3.new(0, 0.12, 0)),
				Color = Color3.fromRGB(120, 110, 90),
			})
			part(f, {
				Name = "River",
				Size = Vector3.new(7, 0.3, length),
				CFrame = CFrame.lookAt(mid + Vector3.new(0, 0.2, 0), lip + Vector3.new(0, 0.2, 0)),
				Color = Color3.fromRGB(70, 180, 220),
				Material = Enum.Material.Glass,
				Transparency = 0.15,
				CanCollide = false,
			})
			Kit.disc(
				f,
				"SpringPool",
				spring,
				0.3,
				0.5,
				6,
				Color3.fromRGB(70, 180, 220),
				{ Material = Enum.Material.Glass, Transparency = 0.15, CanCollide = false }
			)
			for i = 1, 4 do
				Kit.rock(
					f,
					spring + Vector3.new(math.cos(i * 1.6), 0, math.sin(i * 1.6)) * 7,
					random:NextNumber(2, 3.5),
					random,
					mossy
				)
			end
			-- The fall itself, down the cliff face, with spray where it hits the sea
			local drop = -World.WaterY + 1
			part(f, {
				Name = "Waterfall",
				Size = Vector3.new(7, drop, 0.8),
				CFrame = CFrame.lookAt(
					lip + Vector3.new(0, -drop / 2 + 0.3, 0),
					lip + dir + Vector3.new(0, -drop / 2 + 0.3, 0)
				),
				Color = Color3.fromRGB(160, 225, 255),
				Material = Enum.Material.Glass,
				Transparency = 0.2,
				CanCollide = false,
			})
			local splash = Instance.new("ParticleEmitter")
			splash.Color = ColorSequence.new(Color3.new(1, 1, 1))
			splash.Size = NumberSequence.new(3, 7)
			splash.Transparency = NumberSequence.new(0.4, 1)
			splash.Speed = NumberRange.new(3, 6)
			splash.SpreadAngle = Vector2.new(40, 40)
			splash.EmissionDirection = Enum.NormalId.Top
			splash.Lifetime = NumberRange.new(1, 2)
			splash.Rate = 16
			local foam = part(f, {
				Name = "Foam",
				Size = Vector3.new(8, 0.2, 6),
				CFrame = CFrame.new(lip + dir * 3 + Vector3.new(0, World.WaterY + 0.2, 0)),
				Transparency = 1,
				CanCollide = false,
				CanQuery = false,
			})
			splash.Parent = foam
		end
	end
	-- Giant trees all around, some with hanging vines; ferns and bright flowers underneath
	local leaves = {
		Color3.fromRGB(34, 120, 54),
		Color3.fromRGB(44, 138, 62),
		Color3.fromRGB(28, 104, 50),
		Color3.fromRGB(56, 150, 66),
	}
	scatter(ctx, 30, 5, function(p)
		local h = random:NextNumber(18, 32)
		Kit.tree(f, p, h, leaves[random:NextInteger(1, #leaves)])
		for _ = 1, 3 do
			local v = p + Vector3.new(random:NextNumber(-h * 0.25, h * 0.25), 0, random:NextNumber(-h * 0.25, h * 0.25))
			local length = random:NextNumber(5, 9)
			box(
				f,
				"Vine",
				v + Vector3.new(0, h * 0.5 - length / 2, 0),
				Vector3.new(0.25, length, 0.25),
				Color3.fromRGB(60, 140, 50)
			)
		end
	end)
	scatter(ctx, 30, 2, function(p)
		for i = 0, 4 do
			part(f, {
				Name = "Fern",
				Size = Vector3.new(1, 0.2, 4),
				CFrame = CFrame.new(p + Vector3.new(0, 0.9, 0))
					* CFrame.Angles(0, i * 1.26, 0)
					* CFrame.Angles(math.rad(25), 0, 0)
					* CFrame.new(0, 0, -1.6),
				Color = Color3.fromRGB(70, 170, 70),
				CanCollide = false,
			})
		end
		if random:NextNumber() < 0.5 then
			Kit.ball(
				f,
				"JungleFlower",
				p + Vector3.new(0, 1.2, 0),
				1,
				if random:NextNumber() < 0.5 then Color3.fromRGB(255, 80, 120) else Color3.fromRGB(180, 90, 255),
				{ CanCollide = false }
			)
		end
	end)
end

---------------------------------------------------------------------------------------------------
-- Ice Rink

local function iceRink(ctx: Ctx)
	local f, random = ctx.Folder, ctx.Random
	local ice = { Color3.fromRGB(150, 230, 255), Color3.fromRGB(120, 210, 250), Color3.fromRGB(190, 240, 255) }
	-- An igloo
	local igloo = ctx.At(-ctx.HU - 16, -ctx.HW + 4)
	solid(ctx, igloo, 9)
	if ctx.Free(igloo, 4) then
		local face = (ctx.Center - igloo).Unit
		local cf = CFrame.lookAt(igloo, igloo + face)
		if not Kit.model(f, "Igloo", igloo, face, 17, false) then
			Kit.ball(f, "Igloo", igloo, 14, Color3.fromRGB(236, 246, 255))
			for ring = 1, 3 do
				Kit.cylinder(
					f,
					"IglooRing",
					igloo + Vector3.new(0, ring * 1.9 - 0.2, 0),
					0.15,
					math.sqrt(49 - (ring * 1.9) ^ 2) + 0.05,
					Color3.fromRGB(200, 222, 240)
				)
			end
			part(f, {
				Name = "IglooDoor",
				Size = Vector3.new(4, 4, 4),
				CFrame = cf * CFrame.new(0, 2, -6.5),
				Color = Color3.fromRGB(236, 246, 255),
			})
			part(f, {
				Name = "IglooHole",
				Size = Vector3.new(2.6, 3, 0.3),
				CFrame = cf * CFrame.new(0, 1.5, -8.55),
				Color = Color3.fromRGB(40, 60, 90),
			})
		end
	end
	-- Ice crystal clusters (glowing a little)
	scatter(ctx, 9, 4, function(p)
		for i = 1, random:NextInteger(3, 5) do
			local h = random:NextNumber(3, 8)
			local crystal = part(f, {
				Name = "IceCrystal",
				Size = Vector3.new(h * 0.3, h, h * 0.3),
				CFrame = CFrame.new(
					p + Vector3.new(random:NextNumber(-1.5, 1.5), h * 0.4, random:NextNumber(-1.5, 1.5))
				)
					* CFrame.Angles(random:NextNumber(-0.4, 0.4), random:NextNumber(0, 6), random:NextNumber(-0.4, 0.4)),
				Color = ice[random:NextInteger(1, #ice)],
				Material = Enum.Material.Ice,
				Transparency = 0.05,
			})
			if i == 1 then
				local glow = Instance.new("PointLight")
				glow.Color = Color3.fromRGB(150, 220, 255)
				glow.Range = 10
				glow.Brightness = 0.8
				glow.Parent = crystal
			end
		end
	end)
	-- A frozen pond
	local pond = ctx.At(ctx.HU + 18, 10)
	if ctx.Free(pond, 4) then
		Kit.disc(
			f,
			"FrozenPond",
			pond,
			0.25,
			0.5,
			10,
			Color3.fromRGB(190, 228, 248),
			{ Material = Enum.Material.Glacier }
		)
	end
	-- A sled
	local sled = ctx.At(ctx.HU + 12, -ctx.HW - 6)
	if ctx.Free(sled, 3) then
		local cf = CFrame.lookAt(sled, sled + ctx.R)
		part(f, {
			Name = "Sled",
			Size = Vector3.new(2.4, 0.4, 5),
			CFrame = cf * CFrame.new(0, 0.9, 0),
			Color = Color3.fromRGB(200, 60, 50),
		})
		for _, x in { -1, 1 } do
			part(f, {
				Name = "SledRunner",
				Size = Vector3.new(0.2, 0.3, 5.6),
				CFrame = cf * CFrame.new(x, 0.3, 0),
				Color = Color3.fromRGB(200, 200, 210),
			})
		end
	end
	-- Snowy pines and snow piles
	scatter(ctx, 26, 5, function(p)
		Kit.pine(f, p, random:NextNumber(14, 24), true)
	end)
	scatter(ctx, 12, 3, function(p)
		Kit.ball(f, "SnowPile", p - Vector3.new(0, 1, 0), random:NextNumber(4, 7), Color3.fromRGB(250, 252, 255))
	end)
	-- Snow falling over the island
	local snow = Instance.new("ParticleEmitter")
	snow.Color = ColorSequence.new(Color3.new(1, 1, 1))
	snow.Size = NumberSequence.new(0.4)
	snow.Speed = NumberRange.new(4, 6)
	snow.SpreadAngle = Vector2.new(60, 60)
	snow.EmissionDirection = Enum.NormalId.Bottom
	snow.Lifetime = NumberRange.new(8, 10)
	snow.Rate = 80
	local sky = part(f, {
		Name = "SnowCloud",
		Size = Vector3.new(ctx.Island.Radius * 2, 1, ctx.Island.Radius * 2),
		Position = ctx.Island.Center + Vector3.new(0, 70, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	snow.Parent = sky
end

---------------------------------------------------------------------------------------------------
-- Rooftop (a city block)

local function city(ctx: Ctx)
	local f, random = ctx.Folder, ctx.Random
	local y = ctx.Zone.FloorY
	-- Streets around the arena's building, with lane dashes and sidewalks
	local street = Color3.fromRGB(58, 60, 68)
	local ring = math.max(ctx.HU, ctx.HW) + 12
	for _, side in { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } } do
		local center = ctx.Center + Vector3.new(side[1] * ring, 0.12, side[2] * ring)
		local alongX = side[1] == 0
		local length = ring * 2 + 12
		box(
			f,
			"Street",
			center,
			if alongX then Vector3.new(length, 0.24, 10) else Vector3.new(10, 0.24, length),
			street
		)
		for i = -5, 5 do
			box(
				f,
				"LaneDash",
				center + (if alongX then Vector3.new(i * 7, 0.03, 0) else Vector3.new(0, 0.03, i * 7)),
				if alongX then Vector3.new(3, 0.22, 0.4) else Vector3.new(0.4, 0.22, 3),
				Color3.fromRGB(250, 220, 90)
			)
		end
	end
	-- Window bands on the arena's building, and a helipad on its roof
	for wy = 5, y - 4, 6 do
		box(
			f,
			"Windows",
			ctx.Center + Vector3.new(0, wy, 0),
			Vector3.new(ctx.HU * 2 + 0.3, 2.2, ctx.HW * 2 + 0.3),
			Color3.fromRGB(150, 200, 240),
			Enum.Material.Glass
		)
	end
	local pad = ctx.Center + Vector3.new(0, y + 0.12, 0)
	part(f, {
		Name = "Helipad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.1, 22, 22),
		CFrame = CFrame.new(pad) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(240, 200, 60),
		CanCollide = false,
	})
	part(f, {
		Name = "Helipad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.12, 20, 20),
		CFrame = CFrame.new(pad) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(70, 74, 86),
		CanCollide = false,
	})
	for _, piece in { { -3, 0, 1.2, 9 }, { 3, 0, 1.2, 9 }, { 0, 0, 6, 1.2 } } do
		box(
			f,
			"HelipadH",
			pad + Vector3.new(piece[1], 0.04, piece[2]),
			Vector3.new(piece[3], 0.1, piece[4]),
			Color3.new(1, 1, 1)
		)
	end
	-- Skyscrapers all around, with lit windows and roof details
	local palette = {
		Color3.fromRGB(110, 120, 150),
		Color3.fromRGB(150, 140, 170),
		Color3.fromRGB(90, 110, 140),
		Color3.fromRGB(170, 160, 150),
		Color3.fromRGB(70, 90, 130),
	}
	local count = 0
	for _ = 1, 200 do
		if count >= 12 then
			break
		end
		local a = random:NextNumber(0, math.pi * 2)
		local p = ctx.Island.Center
			+ Vector3.new(math.cos(a), 0, math.sin(a)) * random:NextNumber(ring + 14, ctx.Island.Radius - 6)
		local size = random:NextNumber(12, 18)
		if ctx.Free(p, size * 0.75) then
			-- (not on another tower)
			local free = true
			for _, child in f:GetChildren() do
				if child.Name == "Skyscraper" then
					local offset = (child :: BasePart).Position - p
					if Vector3.new(offset.X, 0, offset.Z).Magnitude < size + 6 then
						free = false
						break
					end
				end
			end
			if free then
				count += 1
				local height = random:NextNumber(40, 95)
				local color = palette[random:NextInteger(1, #palette)]
				box(f, "Skyscraper", p + Vector3.new(0, height / 2, 0), Vector3.new(size, height, size), color)
				for wy = 5, height - 4, 5 do
					if random:NextNumber() < 0.85 then
						box(
							f,
							"Windows",
							p + Vector3.new(0, wy, 0),
							Vector3.new(size + 0.25, 1.8, size + 0.25),
							if random:NextNumber() < 0.3
								then Color3.fromRGB(255, 226, 150)
								else Color3.fromRGB(160, 205, 240),
							if random:NextNumber() < 0.3 then Enum.Material.Neon else Enum.Material.Glass
						)
					end
				end
				box(
					f,
					"RoofEdge",
					p + Vector3.new(0, height + 0.4, 0),
					Vector3.new(size + 0.8, 0.8, size + 0.8),
					Color3.fromRGB(50, 52, 62)
				)
				local roll = random:NextNumber()
				if roll < 0.35 then
					box(
						f,
						"Antenna",
						p + Vector3.new(0, height + 6, 0),
						Vector3.new(0.4, 12, 0.4),
						Color3.fromRGB(200, 200, 210)
					)
					box(
						f,
						"AntennaLight",
						p + Vector3.new(0, height + 12.2, 0),
						Vector3.new(0.8, 0.8, 0.8),
						Color3.fromRGB(255, 60, 60),
						Enum.Material.Neon
					)
				elseif roll < 0.65 then
					Kit.cylinder(f, "WaterTank", p + Vector3.new(size * 0.2, height + 0.8, 0), 4, 2, C.Plank[2])
					part(f, {
						ClassName = "WedgePart",
						Name = "TankCap",
						Size = Vector3.new(4.2, 1.6, 4.2),
						CFrame = CFrame.new(p + Vector3.new(size * 0.2, height + 5.6, 0)),
						Color = C.DarkWood,
					})
				else
					box(
						f,
						"RoofBox",
						p + Vector3.new(-size * 0.2, height + 1.8, size * 0.15),
						Vector3.new(size * 0.4, 2.8, size * 0.3),
						Color3.fromRGB(180, 184, 196)
					)
				end
			end
		end
	end
	-- A construction crane and a billboard
	local crane = ctx.At(ctx.HU + 16, ctx.HW + 16)
	if ctx.Free(crane, 3) then
		for i = 0, 9 do
			box(
				f,
				"CraneMast",
				crane + Vector3.new(0, 3 + i * 6, 0),
				Vector3.new(2.2, 6, 2.2),
				if i % 2 == 0 then Color3.fromRGB(250, 200, 40) else Color3.fromRGB(235, 180, 30)
			)
		end
		part(f, {
			Name = "CraneJib",
			Size = Vector3.new(2, 2, 34),
			CFrame = CFrame.lookAt(crane + Vector3.new(0, 61, 0), crane + Vector3.new(0, 61, 0) - ctx.F)
				* CFrame.new(0, 0, -10),
			Color = Color3.fromRGB(250, 200, 40),
		})
		box(f, "CraneCab", crane + Vector3.new(0, 58, 0), Vector3.new(3.6, 3, 3.6), Color3.fromRGB(230, 230, 236))
	end
	local billboard = ctx.At(-ctx.HU - 16, ctx.HW + 14)
	if ctx.Free(billboard, 3) then
		local face = ctx.F
		for _, x in { -5, 5 } do
			box(
				f,
				"BillboardPost",
				billboard + face:Cross(Vector3.yAxis) * x + Vector3.new(0, 7, 0),
				Vector3.new(0.8, 14, 0.8),
				Color3.fromRGB(60, 62, 72)
			)
		end
		local sign = part(f, {
			Name = "Billboard",
			Size = Vector3.new(18, 9, 0.6),
			CFrame = CFrame.lookAt(billboard + Vector3.new(0, 17, 0), billboard + Vector3.new(0, 17, 0) + face),
			Color = Color3.fromRGB(226, 72, 66),
		})
		Kit.signText(
			sign,
			Enum.NormalId.Front,
			"NOW HIRING",
			Color3.new(1, 1, 1),
			"Mail a Tiger Co.",
			Color3.fromRGB(226, 72, 66)
		)
	end
	-- Street lamps and cones
	scatter(ctx, 8, 2, function(p)
		Kit.lamppost(f, p)
	end)
	scatter(ctx, 6, 1, function(p)
		part(f, {
			ClassName = "WedgePart",
			Name = "Cone",
			Size = Vector3.new(1, 1.6, 1),
			CFrame = CFrame.new(p + Vector3.new(0, 0.8, 0)),
			Color = Color3.fromRGB(255, 130, 40),
		})
	end)
end

local THEMES: { [string]: (Ctx) -> () } = {
	Backyard = backyard,
	Barn = barnZone,
	Jungle = jungle,
	IceRink = iceRink,
	Rooftop = city,
}

-- The open ground in the middle of the island: a soft oval in the island's style (a lawn, a farmyard, a
-- mossy clearing), with a slightly bigger, darker edge under it. On the Ice Rink, a snowbank around the rink
-- (which stays the slippery rectangle) and low boards with a gap in each side.
local CLEARINGS: { [string]: { Color3 } } = {
	Backyard = { Color3.fromRGB(116, 196, 84), Color3.fromRGB(92, 168, 70) },
	Barn = { Color3.fromRGB(198, 156, 104), Color3.fromRGB(150, 160, 86) },
	Jungle = { Color3.fromRGB(86, 146, 70), Color3.fromRGB(64, 116, 60) },
	IceRink = { Color3.fromRGB(228, 238, 248), Color3.fromRGB(206, 222, 238) },
}

local function clearing(ctx: Ctx)
	local colors = CLEARINGS[ctx.Zone.Id]
	if not colors then
		return
	end
	local up = Vector3.new(0, 1, 0)
	local function oval(name: string, extra: number, top: number, color: Color3)
		part(ctx.Folder, {
			Name = name,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.1, (ctx.HW + extra) * 2, (ctx.HU + extra) * 2),
			CFrame = CFrame.fromMatrix(ctx.Center + Vector3.new(0, top - 0.05, 0), up, ctx.F),
			Color = color,
			CanCollide = false,
		})
	end
	oval("ClearingEdge", 16, 0.05, colors[2])
	oval("Clearing", 11, 0.08, colors[1])
	if ctx.Zone.Id == "IceRink" then
		-- low boards round the rink, open in the middle of each side
		local white = Color3.fromRGB(246, 248, 252)
		type Side = { Normal: Vector3, Out: number, Along: Vector3, Half: number }
		local sides: { Side } = {
			{ Normal = ctx.R, Out = ctx.HU, Along = ctx.F, Half = ctx.HW },
			{ Normal = ctx.F, Out = ctx.HW, Along = ctx.R, Half = ctx.HU },
		}
		for _, side in sides do
			local normal, out, along, half = side.Normal, side.Out, side.Along, side.Half
			for _, sign in { -1, 1 } do
				for _, piece in { -1, 1 } do
					local length = half - 5
					local mid = ctx.Center + normal * sign * (out + 0.5) + along * piece * (5 + length / 2)
					part(ctx.Folder, {
						Name = "RinkBoard",
						Size = Vector3.new(1, 1.4, length),
						CFrame = CFrame.lookAt(mid + Vector3.new(0, 0.7, 0), mid + Vector3.new(0, 0.7, 0) + along),
						Color = white,
					})
					part(ctx.Folder, {
						Name = "RinkBoardTrim",
						Size = Vector3.new(1.1, 0.25, length),
						CFrame = CFrame.lookAt(mid + Vector3.new(0, 1.45, 0), mid + Vector3.new(0, 1.45, 0) + along),
						Color = Color3.fromRGB(60, 110, 200),
					})
				end
			end
		end
	end
end

function Zones.Build(island: Islands.Island, zone: Zone, bridgeEnd: Vector3)
	local folder = Instance.new("Folder")
	folder.Name = "Theme"
	folder.Parent = island.Folder
	local center = (zone.Min + zone.Max) / 2
	center = Vector3.new(center.X, 0, center.Z)
	local f = zone.Facing
	local r = Vector3.new(0, 1, 0):Cross(f)
	local half = (zone.Max - zone.Min) / 2
	local hu = math.abs(half:Dot(r))
	local hw = math.abs(half:Dot(f))
	local gate = center + f * (hw + 12)
	local function inPlay(p: Vector3, pad: number): boolean
		return p.X > zone.Min.X - pad and p.X < zone.Max.X + pad and p.Z > zone.Min.Z - pad and p.Z < zone.Max.Z + pad
	end
	local ctx: Ctx = {
		Zone = zone,
		Island = island,
		Folder = folder,
		Random = Random.new(#zone.Id * 977),
		Center = center,
		F = f,
		R = r,
		HU = hu,
		HW = hw,
		BridgeEnd = bridgeEnd,
		Gate = gate,
		Free = function(p: Vector3, pad: number): boolean
			return island.OnLand(p, pad + 2)
				and not inPlay(p, pad + 6)
				and segmentDistance(p, bridgeEnd, gate) > World.BridgeWidth / 2 + 3 + pad
		end,
		At = function(u: number, w: number): Vector3
			return center + r * u + f * w
		end,
	}
	-- A path from the bridge to the gate
	local along = Vector3.new(gate.X - bridgeEnd.X, 0, gate.Z - bridgeEnd.Z)
	if along.Magnitude > 1 then
		local style = if zone.Id == "IceRink"
			then Kit.ROADS.Snow
			elseif zone.Id == "Rooftop" then Kit.ROADS.City
			elseif zone.Id == "Jungle" then Kit.ROADS.Jungle
			else Kit.ROADS.Dirt
		Kit.road(folder, bridgeEnd, gate, World.BridgeWidth, style)
	end
	clearing(ctx)
	local theme = THEMES[zone.Id]
	if theme then
		theme(ctx)
	end
end

return Zones
