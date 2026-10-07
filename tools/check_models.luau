--!nocheck
-- Checks the models you've imported into Studio against the list the game expects.
-- Reads your saved place file (it never changes it) and reports missing, misplaced and extra models,
-- any model whose front (its eyes/face/door) doesn't point the way the game expects (-Z), and any part the
-- game can't color (its name doesn't match anything in src/shared/ArtColors/<Model>.json).
--
-- Run it from the project folder after saving in Studio (Ctrl+S):
--     lune run tools/check_models.luau MailATiger.rbxl
-- (Lune is a tool that runs Luau outside Roblox: `rokit add --global lune-org/lune` installs it.)

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local EXPECTED = {
	AnimalModels = {
		"Hamster", "Bunny", "Goldfish", "Hedgehog", "Chicken", "Pig", "Goat", "Parrot", "Skunk", "Monkey",
		"Penguin", "Raccoon", "Kangaroo", "Octopus", "Bear", "Crocodile", "Gorilla", "Tiger", "Giraffe",
		"Elephant", "Whale", "Dragon", "Unicorn", "Alien", "Yeti", "Gruff",
	},
	BoxModels = { "Cardboard", "Wood", "Steel", "Vault" },
	PropModels = {
		"Parcel", "MailChute", "MailChuteExpress", "MailChutePneumatic", "MailChuteRocket", "GruffHat", "BossCrown", "Egg",
		"Envelope", "GrabbingGloves", "Sneakers", "TapeGun", "ButterflyNet", "TapeRoll", "RubberStamp",
	},
	MapModels = {
		"PostOffice", "PostCounter", "PenCounter", "ShopStall", "OrdersBoard", "LeaderboardStand", "TravelPad",
		"SpawnPad", "Lamppost", "Bench", "Mailbox", "Planter", "ArenaGate", "PicketFence", "Bush", "Doghouse",
		"Flowerbed", "Barn", "HayBale", "FarmFence", "Trough", "JungleTree", "MudPuddle", "BambooFence", "Rock",
		"RinkBoard", "HockeyGoal", "Snowman", "ACUnit", "WaterTower", "Chimney",
		-- scenery (art/blender_scripts/scenery.py)
		"OakTree", "BirchTree", "PineTree", "SnowPine", "PalmTree", "Tractor", "Windmill", "Silo", "Scarecrow",
		"Lighthouse", "Rowboat", "Shipwreck", "TikiHut", "Igloo", "Cottage",
	},
}
local FRONT_PARTS = { Eyes = true, Face = true, Door = true, Nose = true }

local path = process.args[1] or "MailATiger.rbxl"
local game = roblox.deserializePlace(fs.readFile(path))
local storage = game:GetService("ReplicatedStorage")

-- Where each expected model should live
local home = {}
for folder, names in EXPECTED do
	for _, name in names do
		home[name] = folder
	end
end

local problems = 0
local function report(text)
	problems += 1
	print("  - " .. text)
end

print(`Checking {path}\n`)
for folder, names in EXPECTED do
	local container = storage:FindFirstChild(folder)
	if not container then
		report(`ReplicatedStorage has no "{folder}" folder`)
		continue
	end
	for _, name in names do
		local model = container:FindFirstChild(name)
		if not model then
			local elsewhere = nil
			for other in EXPECTED do
				local otherFolder = storage:FindFirstChild(other)
				if other ~= folder and otherFolder and otherFolder:FindFirstChild(name) then
					elsewhere = other
				end
			end
			report(if elsewhere
				then `{name} is in {elsewhere}, but belongs in {folder}`
				else `{name} is missing from {folder}`)
		elseif not model:IsA("Model") then
			report(`{folder}/{name} is a {model.ClassName}, not a Model (import it as one Model with its parts)`)
		else
			-- Colors: every part needs a matching entry in its ArtColors file (exact name, or a name containing it)
			local colorFile = `src/shared/ArtColors/{name}.json`
			if not fs.isFile(colorFile) then
				report(`{name} has no {colorFile}, so it will stay grey`)
			else
				local colors = serde.decode("json", fs.readFile(colorFile))
				for _, part in model:GetDescendants() do
					if part:IsA("BasePart") then
						local found = colors[part.Name] ~= nil
						for key in colors do
							found = found or string.find(string.lower(part.Name), string.lower(key), 1, true) ~= nil
						end
						if not found then
							report(`{folder}/{name} part "{part.Name}" has no color (it'll stay grey; was it renamed?)`)
						end
					end
				end
			end
			-- Facing: the front parts should sit on the model's -Z side
			local lo, hi = nil, nil
			local fronts = {}
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") then
					local p, s = part.CFrame.Position, part.Size
					local a, b = p - s / 2, p + s / 2
					lo = if lo then roblox.Vector3.new(math.min(lo.X, a.X), math.min(lo.Y, a.Y), math.min(lo.Z, a.Z)) else a
					hi = if hi then roblox.Vector3.new(math.max(hi.X, b.X), math.max(hi.Y, b.Y), math.max(hi.Z, b.Z)) else b
					if FRONT_PARTS[part.Name] then
						table.insert(fronts, p)
					end
				end
			end
			if lo and #fronts > 0 then
				local center = (lo + hi) / 2
				local sum = roblox.Vector3.new(0, 0, 0)
				for _, p in fronts do
					sum += p - center
				end
				local offset = sum / #fronts
				if math.abs(offset.X) > math.abs(offset.Z) or offset.Z > 0 then
					report(`{folder}/{name} may face the wrong way (give it a Number attribute YawOffset = 180 or 90)`)
				end
			end
		end
	end
	for _, child in container:GetChildren() do
		if not table.find(names, child.Name) then
			local belongs = home[child.Name]
			report(if belongs
				then `{folder} has an extra {child.Name} (it belongs in {belongs}; this copy can be deleted)`
				else `{folder} has "{child.Name}", which the game doesn't use (check the name?)`)
		end
	end
end

print(if problems == 0 then "\nAll models are in place." else `\n{problems} thing(s) to look at. Everything else is fine.`)
