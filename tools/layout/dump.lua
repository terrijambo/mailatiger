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
print("LAYOUT done")
