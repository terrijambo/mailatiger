-- Used by tools/smoke/run.sh (runs inside a temporary Studio, in edit mode).
-- Smoke test (edit mode): build the real map with the real models by calling the game's own modules.
local server = game:GetService("ServerScriptService"):FindFirstChild("Server")
local ok, err = pcall(function()
	local Look = require(server.Look)
	Look.Apply()
	local MapBuilder = require(server.MapBuilder)
	local built = MapBuilder.Build()
	print("SMOKE built; arenas:", built.Arenas.Backyard ~= nil, built.Arenas.Rooftop ~= nil)
end)
print("SMOKE build ok:", ok, err)
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local map = Workspace:FindFirstChild("GrayboxMap")
if map then
	local models, hidden, shown = {}, 0, 0
	for _, d in map:GetDescendants() do
		if d:IsA("Model") then
			models[d.Name] = (models[d.Name] or 0) + 1
		elseif d:IsA("BasePart") and not d:FindFirstAncestorOfClass("Model") then
			if d.Transparency >= 1 then hidden += 1 else shown += 1 end
		end
	end
	local names = {}
	for name, n in models do table.insert(names, name .. "x" .. n) end
	table.sort(names)
	print("SMOKE models: " .. table.concat(names, ", "))
	print("SMOKE grey parts hidden:", hidden, "still visible:", shown)
	local visibleNames = {}
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") and not d:FindFirstAncestorOfClass("Model") and d.Transparency < 1 then
			visibleNames[d.Name] = (visibleNames[d.Name] or 0) + 1
		end
	end
	local v = {}
	for name, n in visibleNames do table.insert(v, name .. "x" .. n) end
	table.sort(v)
	print("SMOKE visible grey: " .. table.concat(v, ", "))
	for _, name in { "PostOfficeArt", "GruffModel", "PostCounterArt", "PenCounterArt", "ShopStallArt", "OrdersBoardArt", "SpawnPadArt" } do
		local m = map:FindFirstChild(name)
		if m then
			local cf, size = m:GetBoundingBox()
			print(string.format("SMOKE %s at (%.1f, %.1f, %.1f) size (%.1f, %.1f, %.1f)", name, cf.X, cf.Y, cf.Z, size.X, size.Y, size.Z))
		end
	end
	local hat = map:FindFirstChild("GruffHat")
	print("SMOKE hat", hat and tostring(hat.Position), hat and #hat:GetDescendants())
	for _, id in { "FastestTiger", "FiveStamps", "Rarest" } do
		local part = map:FindFirstChild("Leaderboard_" .. id)
		print("SMOKE board", id, part and tostring(part.Position), part and tostring(part.Size))
	end
	for _, arena in map.Arenas:GetChildren() do
		local n = 0
		for _, d in arena:GetChildren() do if d:IsA("Model") then n += 1 end end
		print("SMOKE arena", arena.Name, "models:", n)
	end
	local barn = map.Arenas.Barn:FindFirstChild("BarnArt")
	if barn then
		local cf, size = barn:GetBoundingBox()
		print(string.format("SMOKE Barn at (%.1f, %.1f, %.1f) size (%.1f, %.1f, %.1f)", cf.X, cf.Y, cf.Z, size.X, size.Y, size.Z))
	end
end
-- Load every module (without starting anything) to catch load-time errors
local failed = {}
for _, container in { server, game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("Client") } do
	if container then
		for _, module in container:GetChildren() do
			if module:IsA("ModuleScript") then
				local okLoad, loadErr = pcall(require, module)
				if not okLoad then
					table.insert(failed, module.Name .. ": " .. tostring(loadErr))
				end
			end
		end
	end
end
print("SMOKE modules that failed to load: " .. (if #failed == 0 then "none" else table.concat(failed, " | ")))
print("SMOKE lighting", Lighting.GlobalShadows, Lighting.ClockTime, Lighting:FindFirstChildOfClass("Atmosphere") ~= nil)
print("SMOKE DONE")
