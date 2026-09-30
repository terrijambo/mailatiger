-- Used by tools/smoke/run.sh: copies the imported model folders from your place into a fresh build.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local built = roblox.deserializePlace(fs.readFile(process.args[1]))
local user = roblox.deserializePlace(fs.readFile(process.args[2]))
for _, name in { "AnimalModels", "BoxModels", "PropModels", "MapModels" } do
	local folder = user:GetService("ReplicatedStorage"):FindFirstChild(name)
	if folder then
		folder:Clone().Parent = built:GetService("ReplicatedStorage")
		print("copied", name, #folder:GetChildren())
	end
end
-- Keep the user's lighting too, so Look.Apply is tested against it
fs.writeFile(process.args[3], roblox.serializePlace(built))
print("wrote", process.args[3])
