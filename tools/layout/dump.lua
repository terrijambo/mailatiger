-- Used by tools/layout/run.sh (runs inside a temporary Studio, in edit mode).
-- Builds the real map with the real models, then prints the world bounding box of every piece:
--   L|<path under the map>|minX|minY|minZ|maxX|maxY|maxZ
-- Models count as one piece (their whole bounding box). tools/layout/check.py reads this.
-- Safety: only ever run inside the throwaway test place (marked by merge.luau), never in your own game
if game:GetService("Workspace"):GetAttribute("MailATigerTestPlace") ~= true then
	return
end
local server = game:GetService("ServerScriptService"):FindFirstChild("Server")
local ok, err = pcall(function()
	require(server.Look).Apply()
	require(server.MapBuilder).Build()
end)
print("LAYOUT build ok:", ok, err)
local map = game:GetService("Workspace"):FindFirstChild("GrayboxMap")
if not map then
	return
end
local function pathOf(inst)
	local names = {}
	local node = inst
	while node and node ~= map do
		table.insert(names, 1, node.Name)
		node = node.Parent
	end
	return table.concat(names, "/")
end
local function emit(inst, cf, size)
	-- world-space box around a rotated box
	local r = cf - cf.Position
	local hx = math.abs(r.RightVector.X) * size.X + math.abs(r.UpVector.X) * size.Y + math.abs(r.LookVector.X) * size.Z
	local hy = math.abs(r.RightVector.Y) * size.X + math.abs(r.UpVector.Y) * size.Y + math.abs(r.LookVector.Y) * size.Z
	local hz = math.abs(r.RightVector.Z) * size.X + math.abs(r.UpVector.Z) * size.Y + math.abs(r.LookVector.Z) * size.Z
	local p = cf.Position
	print(string.format("L|%s|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f", pathOf(inst), p.X - hx / 2, p.Y - hy / 2, p.Z - hz / 2, p.X + hx / 2, p.Y + hy / 2, p.Z + hz / 2))
end
local function walk(node)
	for _, child in node:GetChildren() do
		if child:IsA("Model") then
			local cf, size = child:GetBoundingBox()
			emit(child, cf, size)
		elseif child:IsA("BasePart") then
			if child.Transparency < 1 then
				emit(child, child.CFrame, child.Size)
			end
			walk(child)
		else
			walk(child)
		end
	end
end
walk(map)
-- Invisible walls: parts you can't see but still bump into (I|path|box...)
for _, p in map:GetDescendants() do
	if p:IsA("BasePart") and p.CanCollide and p.Transparency >= 0.95 then
		local cf, size = p.CFrame, p.Size
		local r = cf - cf.Position
		local hx = math.abs(r.RightVector.X) * size.X + math.abs(r.UpVector.X) * size.Y + math.abs(r.LookVector.X) * size.Z
		local hz = math.abs(r.RightVector.Z) * size.X + math.abs(r.UpVector.Z) * size.Y + math.abs(r.LookVector.Z) * size.Z
		local pos = cf.Position
		print(string.format("I|%s|%.1f|%.1f|%.1f|%.1f|%.1f|%.1f", pathOf(p), pos.X - hx / 2, pos.Y - size.Y / 2, pos.Z - hz / 2, pos.X + hx / 2, pos.Y + size.Y / 2, pos.Z + hz / 2))
	end
end

-- Glitch detectors and per-zone budget (overhaul Phase 1). tools/layout/check.py reports them:
--   F|path|zone|x|y|z|gap          floating: nothing touches it from below or the sides (gap = drop to what's under it, -1 = nothing)
--   S|path|zone|x|y|z|depth|height a model sunk into the ground deeper than it should be
--   Z|pathA|pathB|zone|x|y|z|area  z-fighting: two different-looking faces on the same plane (they flicker)
--   W|path|zone|x|y|z|sx|sy|sz     invisible wall: a collidable invisible part with nothing visible around it
--   B|zone|visible|total|meshParts|uniqueMeshes|uniqueTextures|lights|emitters
local Workspace = game:GetService("Workspace")
local World = require(game:GetService("ReplicatedStorage").Shared.Config.World)

local zoneOf = World.ZoneAt

-- Decorations are built with CanQuery off, which hides them from the overlap checks below (a hat on Gruff's
-- head would look like it floats). This is a throwaway test place, so switch it back on everywhere.
for _, part in Workspace:GetDescendants() do
	if part:IsA("BasePart") then
		part.CanQuery = true
	end
end

local function hidden(part)
	return part.Transparency >= 0.95
end

local function worldHalf(cf, size)
	local r = cf - cf.Position
	return Vector3.new(
		math.abs(r.RightVector.X) * size.X + math.abs(r.UpVector.X) * size.Y + math.abs(r.LookVector.X) * size.Z,
		math.abs(r.RightVector.Y) * size.X + math.abs(r.UpVector.Y) * size.Y + math.abs(r.LookVector.Y) * size.Z,
		math.abs(r.RightVector.Z) * size.X + math.abs(r.UpVector.Z) * size.Y + math.abs(r.LookVector.Z) * size.Z
	) / 2
end

-- First visible thing straight down from a point (skips invisible colliders and the piece itself)
-- (onlyGround: also skip anything inside a model, like a neighbour's tree canopy or a hat, so the hit is the
-- ground itself)
local function groundBelow(origin, exclude, length, onlyGround)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip = { exclude }
	for _ = 1, 30 do
		params.FilterDescendantsInstances = skip
		local hit = Workspace:Raycast(origin, Vector3.new(0, -length, 0), params)
		if not hit then
			return nil
		end
		local inModel = onlyGround and hit.Instance:FindFirstAncestorOfClass("Model") ~= nil
		if hit.Instance:IsA("Terrain") or (not hidden(hit.Instance) and not inModel) then
			return hit.Position.Y
		end
		table.insert(skip, hit.Instance)
	end
	return nil
end

-- The pieces: each Model as one, and each visible part that isn't inside a Model
local pieces = {}
local function collect(node)
	for _, child in node:GetChildren() do
		if child:IsA("Model") then
			table.insert(pieces, child)
		elseif child:IsA("BasePart") then
			if not hidden(child) then
				table.insert(pieces, child)
			end
			collect(child)
		else
			collect(child)
		end
	end
end
collect(map)

local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
overlap.RespectCanCollide = false
local function touchesVisible(box, exclude)
	overlap.FilterDescendantsInstances = { exclude }
	for _, other in Workspace:GetPartBoundsInBox(box.cf, box.size, overlap) do
		if not hidden(other) then
			return true
		end
	end
	return false
end

for index, piece in pieces do
	local cf, size
	if piece:IsA("Model") then
		cf, size = piece:GetBoundingBox()
	else
		cf, size = piece.CFrame, piece.Size
	end
	local half = worldHalf(cf, size)
	local p = cf.Position
	local bottom = p.Y - half.Y
	-- Floating: grow the box a little (0.3 down, 0.15 sideways) and look for anything visible it touches
	local grown = { cf = CFrame.new(p.X, p.Y - 0.15, p.Z), size = half * 2 + Vector3.new(0.3, 0.3, 0.3) }
	if not touchesVisible(grown, piece) then
		local onTerrain = groundBelow(Vector3.new(p.X, bottom + 0.05, p.Z), piece, 0.5)
		if not onTerrain then
			local ground = groundBelow(Vector3.new(p.X, bottom, p.Z), piece, 300)
			print(string.format("F|%s|%s|%.1f|%.1f|%.1f|%.2f", pathOf(piece), zoneOf(p), p.X, bottom, p.Z, if ground then bottom - ground else -1))
		end
	end
	-- Sunk: a model whose base sits well below the ground under its middle
	if piece:IsA("Model") then
		local ground = groundBelow(Vector3.new(p.X, p.Y + half.Y + 0.1, p.Z), piece, half.Y * 2 + 20, true)
		if ground then
			local depth = ground - bottom
			if depth > 0.5 and depth > half.Y * 2 * 0.15 then
				print(string.format("S|%s|%s|%.1f|%.1f|%.1f|%.2f|%.2f", pathOf(piece), zoneOf(p), p.X, bottom, p.Z, depth, half.Y * 2))
			end
		end
	end
	if index % 500 == 0 then
		task.wait()
	end
end

-- Z-fighting: faces of plain axis-aligned blocks that lie on the same plane, face the same way, overlap,
-- and look different (a different color or material). Same-looking faces flicker too, but you can't see it.
local function axisAligned(cf)
	for _, v in { cf.RightVector, cf.UpVector, cf.LookVector } do
		if math.max(math.abs(v.X), math.abs(v.Y), math.abs(v.Z)) < 0.999 then
			return false
		end
	end
	return true
end
local AXES = { "X", "Y", "Z" }
local OTHER = { X = { "Y", "Z" }, Y = { "X", "Z" }, Z = { "X", "Y" } }
local buckets = {}
for _, part in map:GetDescendants() do
	if part:IsA("Part") and part.Shape == Enum.PartType.Block and not hidden(part) and axisAligned(part.CFrame) then
		local half = worldHalf(part.CFrame, part.Size)
		local c = part.Position
		for _, axis in AXES do
			for _, sign in { -1, 1 } do
				if axis == "Y" and sign == -1 then
					continue -- (undersides sit on the ground: nobody sees them flicker)
				end
				local coord = c[axis] + sign * half[axis]
				local key = axis .. sign .. math.floor(coord * 50 + 0.5)
				local u, v = OTHER[axis][1], OTHER[axis][2]
				local face = { part = part, u0 = c[u] - half[u], u1 = c[u] + half[u], v0 = c[v] - half[v], v1 = c[v] + half[v] }
				buckets[key] = buckets[key] or {}
				table.insert(buckets[key], face)
			end
		end
	end
end
local fights = 0
for _, faces in buckets do
	for i = 1, #faces do
		for j = i + 1, #faces do
			local a, b = faces[i], faces[j]
			if a.part ~= b.part and (a.part.Color ~= b.part.Color or a.part.Material ~= b.part.Material) then
				local du = math.min(a.u1, b.u1) - math.max(a.u0, b.u0)
				local dv = math.min(a.v1, b.v1) - math.max(a.v0, b.v0)
				if du > 0.05 and dv > 0.05 and du * dv > 0.1 then
					local q = a.part.Position
					print(string.format("Z|%s|%s|%s|%.1f|%.1f|%.1f|%.2f", pathOf(a.part), pathOf(b.part), zoneOf(q), q.X, q.Y, q.Z, du * dv))
					fights += 1
				end
			end
		end
	end
	if fights > 3000 then
		break -- the rest of the list would only repeat itself
	end
end

-- Invisible walls: collidable invisible parts with nothing visible in or around them (zone locks are meant to be there)
for _, part in map:GetDescendants() do
	if part:IsA("BasePart") and part.CanCollide and hidden(part) and not string.find(pathOf(part), "ZoneLock", 1, true) then
		local half = worldHalf(part.CFrame, part.Size)
		if not touchesVisible({ cf = CFrame.new(part.Position), size = half * 2 + Vector3.new(0.2, 0.2, 0.2) }, part) then
			local q = part.Position
			print(string.format("W|%s|%s|%.1f|%.1f|%.1f|%.1f|%.1f|%.1f", pathOf(part), zoneOf(q), q.X, q.Y, q.Z, half.X * 2, half.Y * 2, half.Z * 2))
		end
	end
end

-- Budget per zone (the whole Workspace, so models outside the map folder count too)
local budget = {}
local function stats(zone)
	budget[zone] = budget[zone] or { visible = 0, total = 0, meshParts = 0, meshes = {}, textures = {}, lights = 0, emitters = 0 }
	return budget[zone]
end
for _, d in Workspace:GetDescendants() do
	if d:IsA("BasePart") and not d:IsA("Terrain") then
		local s = stats(zoneOf(d.Position))
		s.total += 1
		if not hidden(d) then
			s.visible += 1
		end
		if d:IsA("MeshPart") then
			s.meshParts += 1
			s.meshes[d.MeshId] = true
			if d.TextureID ~= "" then
				s.textures[d.TextureID] = true
			end
		end
	elseif (d:IsA("Decal") or d:IsA("Texture")) and d.Parent and d.Parent:IsA("BasePart") then
		stats(zoneOf(d.Parent.Position)).textures[d.Texture] = true
	elseif d:IsA("SurfaceAppearance") and d.Parent and d.Parent:IsA("BasePart") then
		stats(zoneOf(d.Parent.Position)).textures[d.ColorMap] = true
	elseif d:IsA("Light") and d.Parent and d.Parent:IsA("BasePart") then
		stats(zoneOf(d.Parent.Position)).lights += 1
	elseif d:IsA("ParticleEmitter") and d.Parent and d.Parent:IsA("BasePart") then
		stats(zoneOf(d.Parent.Position)).emitters += 1
	end
end
local function count(set)
	local n = 0
	for _ in set do
		n += 1
	end
	return n
end
for zone, s in budget do
	print(string.format("B|%s|%d|%d|%d|%d|%d|%d|%d", zone, s.visible, s.total, s.meshParts, count(s.meshes), count(s.textures), s.lights, s.emitters))
end
print("LAYOUT done")
