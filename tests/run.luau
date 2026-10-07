--!nocheck
-- Automated checks for the game's settings and shared math. Runs outside Roblox, in a few seconds:
--     lune run tests/run.luau
-- It loads the real files from src/shared (Config and BoxMath) and checks that everything fits together:
-- every twist names a real animal, every tier has an arena, every animal has colors, prices go up, and
-- the tape-stroke math accepts a good stroke and rejects a bad one. Run it after changing any Config file.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

---------------------------------------------------------------------------------------------------
-- A tiny stand-in for Roblox's `script` + `require`, so ModuleScripts from src/shared load here as-is.

local ROOT = "src/shared"
local loaded = {}

local Node = {}
local function node(path)
	return setmetatable({ __path = path }, Node)
end
Node.__index = function(self, key)
	local path = rawget(self, "__path")
	if key == "Parent" then
		return node((string.match(path, "^(.*)/[^/]+$")))
	end
	return node(path .. "/" .. key)
end

local environment
local function load(target)
	local path = rawget(target, "__path")
	if loaded[path] ~= nil then
		return loaded[path]
	end
	local result
	if fs.isFile(path .. ".json") then
		result = serde.decode("json", fs.readFile(path .. ".json"))
	else
		local file = if fs.isFile(path .. ".luau") then path .. ".luau" else path .. "/init.luau"
		local chunk = luau.load(fs.readFile(file), {
			debugName = file,
			environment = environment(target),
		})
		result = chunk()
	end
	loaded[path] = result
	return result
end

environment = function(scriptNode)
	return {
		script = scriptNode,
		require = load,
		Vector2 = roblox.Vector2,
		Vector3 = roblox.Vector3,
		Color3 = roblox.Color3,
		CFrame = roblox.CFrame,
		UDim2 = roblox.UDim2,
		Enum = roblox.Enum,
	}
end

---------------------------------------------------------------------------------------------------
-- Test helpers

local failures, passes = 0, 0
local function check(ok, message)
	if ok then
		passes += 1
	else
		failures += 1
		print("  FAIL: " .. message)
	end
end

local function section(name)
	print("- " .. name)
end

---------------------------------------------------------------------------------------------------

local Config = load(node(ROOT .. "/Config"))
local BoxMath = load(node(ROOT .. "/BoxMath"))
local artColors = {}
for _, file in fs.readDir(ROOT .. "/ArtColors") do
	artColors[string.gsub(file, "%.json$", "")] = true
end

section("Animals")
local lastTier = 0
local seenIds = {}
for _, animal in Config.Animals.List do
	check(not seenIds[animal.Id], `animal id {animal.Id} is used twice`)
	seenIds[animal.Id] = true
	check(Config.Animals.ById[animal.Id] == animal, `{animal.Id} missing from Animals.ById`)
	check(animal.Tier >= lastTier, `{animal.Id} is out of tier order in the list (the Pen and "Skip the Wait" rely on it)`)
	lastTier = animal.Tier
	check(Config.Arenas.ByTier[animal.Tier] ~= nil, `no arena for {animal.Id}'s tier {animal.Tier}`)
	check(animal.BaseValue > 0, `{animal.Id} pays nothing`)
	check(animal.Price >= 0, `{animal.Id} has a negative price`)
	check(animal.Carriers >= 1 and animal.Carriers <= 4, `{animal.Id} needs {animal.Carriers} carriers`)
	check(artColors[animal.Id], `{animal.Id} has no ArtColors/{animal.Id}.json (its model would stay grey)`)
end
check(Config.Animals.ById.Hamster and Config.Animals.ById.Hamster.Price == 0, "the Hamster (starter animal) should be free")
check(Config.Animals.ById.Tiger ~= nil, "no Tiger! The game is called Mail a Tiger")

section("Twists")
for animalId, twists in Config.Boxing.Twists do
	check(Config.Animals.ById[animalId] ~= nil, `Boxing.Twists has "{animalId}", which isn't an animal`)
	for twist in twists do
		check(type(twist) == "string", `a twist on {animalId} isn't named`)
	end
end

section("Boxing")
local seams = Config.Boxing.Box.SeamsByTier
for tier = 1, 6 do
	local count = seams[tier]
	check(type(count) == "number" and count >= 1 and count <= #BoxMath.Seams(99), `SeamsByTier[{tier}] = {count}`)
end
check(Config.Boxing.Box.MinSeamInterval > 0, "MinSeamInterval must be above 0 (it stops tape spam)")

section("Boxes, stamps, tools, chutes")
for _, box in Config.Boxes.List do
	check(artColors[box.Id], `box {box.Id} has no ArtColors file`)
	check(box.AngerMult > 0, `box {box.Id} AngerMult`)
end
check(Config.Stamps.ById.Priority ~= nil, "the Priority stamp is sold in the Store, so it must exist")
for _, tool in Config.Tools.List do
	check(string.find(tool.Effect or "", "{}", 1, true) ~= nil, `{tool.Id} Effect needs a \{\} for the number`)
	local last = -1
	for level = 0, tool.MaxLevel - 1 do
		local price = Config.Tools.PriceFor(tool, level)
		check(price > last, `{tool.Id} level {level + 1} isn't pricier than the one before`)
		last = price
	end
end
local lastLevel, lastHold = 0, math.huge
for index, chute in Config.Mail.Chutes do
	check(Config.Mail.ChuteIndex[chute.Id] == index, `ChuteIndex for {chute.Id}`)
	check(chute.Level > lastLevel, `{chute.Id} arrives at a level no higher than the chute before it`)
	check(chute.HoldTime <= lastHold, `{chute.Id} is slower than the chute before it`)
	check(artColors[chute.Model], `chute model {chute.Model} has no ArtColors file`)
	check(Config.Mail.ChuteFor(chute.Level).Id == chute.Id, `ChuteFor({chute.Level}) should be {chute.Id}`)
	lastLevel, lastHold = chute.Level, chute.HoldTime
end
for _, tool in Config.Tools.List do
	check(Config.Tools.PointsFor(tool, 0) >= 1, `{tool.Id} level 1 should cost at least 1 Rebirth Point`)
end

section("Machines and the chute")
local Machines = Config.Machines
local lastMachineLevel, lastMachinePrice = 0, 0
for _, machine in Machines.List do
	local price = Machines.Price(machine)
	check(machine.Level > lastMachineLevel, `{machine.Id} unlocks no later than the machine before it`)
	check(price > lastMachinePrice, `{machine.Id} isn't pricier than the machine before it`)
	check(machine.XPMult > 1, `{machine.Id} XPMult should be above 1`)
	print(string.format("    %-20s Lv %2d  x%.1f XP  costs %s", machine.DisplayName, machine.Level, machine.XPMult, tostring(price)))
	lastMachineLevel, lastMachinePrice = machine.Level, price
end
local lastRate = 0
for level = 1, Config.Levels.MaxLevel do
	local rate = Machines.ChuteRate(level)
	check(rate >= lastRate, `coins per minute drop at chute level {level}`)
	lastRate = rate
	if level % 5 == 0 or level == 1 then
		print(string.format("    Lv %2d: %8.0f coins/min, %9d XP to next", level, rate, Config.Levels.XPToNext(level)))
	end
end
for rebirths = 0, 3 do
	print(`    rebirth #{rebirths + 1}: costs {Machines.RebirthCost(rebirths)}, pays {Machines.RebirthPoints(rebirths + 1)} RP`)
end
check(Machines.ById.Rocket ~= nil, "the Rocket Launcher gives mail-anywhere, so it must exist")

section("Robux store")
local keys = {}
for _, list in { Config.Monetization.Passes, Config.Monetization.Products } do
	for _, item in list do
		check(not keys[item.Key], `store key {item.Key} is used twice`)
		keys[item.Key] = true
		check(type(item.Id) == "number", `{item.Key} Id must be a number (0 = not set up yet)`)
		check(item.Price > 0, `{item.Key} price`)
	end
end
for key in Config.Monetization.CoinPackJobs do
	check(Config.Monetization.ProductByKey[key] ~= nil, `CoinPackJobs has {key}, which isn't a product`)
end

for key in Config.Monetization.DiamondPacks do
	check(Config.Monetization.ProductByKey[key] ~= nil, `DiamondPacks has {key}, which isn't a product`)
end
check(Config.Monetization.ProductByKey.ServerBoost ~= nil, "the Server Boost product is missing")
for key in keys do
	check(Config.Icons[`Store_{key}`] ~= nil, `store item {key} has no Store_{key} icon`)
end

section("Icon sheets")
for key, cell in Config.IconAtlas.Cells do
	check(Config.Icons[key] ~= nil, `art/ui_icons/{key}.png isn't an icon key in Config/Icons.luau (typo in the file name?)`)
	check(cell.Sheet >= 1 and cell.Sheet <= Config.IconAtlas.SheetCount, `{key} is on sheet {cell.Sheet}, which doesn't exist`)
	check(cell.X + Config.IconAtlas.Size <= 1024 and cell.Y + Config.IconAtlas.Size <= 1024, `{key} sits outside its sheet`)
end
check(#Config.IconSheets >= Config.IconAtlas.SheetCount, "IconSheets.luau needs one line per sheet")

section("Shiny and Golden")
local Variants = Config.Variants
check(Variants.Roll(0) ~= nil and Variants.Roll(0).Id == "Golden", "the luckiest roll is Golden")
check(Variants.Roll(0.99) == nil, "most rolls are plain")
local hits = 0
for i = 1, 4000 do
	if Variants.Roll((i - 0.5) / 4000) then
		hits += 1
	end
end
check(hits > 90 and hits < 125, `about 1 in 36 jobs is special (got {hits} of 4000)`)
for _, variant in Variants.List do
	check(variant.PayMult > 1 and variant.XPMult >= 1, `{variant.Id} pays more`)
end

section("Challenges")
local Challenges = Config.Challenges
for _, list in { Challenges.Daily, Challenges.Weekly } do
	for _, challenge in list do
		check(Challenges.ById[challenge.Id] == challenge, `challenge {challenge.Id} ById`)
		check(table.find({ "Box", "Mail", "Order", "Streak", "Troll" }, challenge.Kind) ~= nil, `{challenge.Id} kind {challenge.Kind}`)
		check(challenge.Count > 0 and challenge.Diamonds > 0, `{challenge.Id} count and reward`)
		check(not string.find(Challenges.Text(challenge), "{", 1, true), `{challenge.Id} text keeps a placeholder`)
	end
end
local easy = 0
for _, challenge in Challenges.Daily do
	if not challenge.MinLevel and not challenge.NeedsTroll then
		easy += 1
	end
end
check(easy >= Challenges.DailyCount, "a brand-new player can always get a full set of dailies")
check(Challenges.Week(4 * 86400) == Challenges.Week(10 * 86400) and Challenges.Week(10 * 86400) ~= Challenges.Week(11 * 86400), "weeks start on Monday")
local streak = Config.Progression.Streak
check(streak.Max > 1 and streak.PerStep > 0, "the delivery streak pays more")

section("Diamonds")
local Diamonds = Config.Diamonds
for _, upgrade in Diamonds.List do
	check(Diamonds.ById[upgrade.Id] == upgrade, `diamond upgrade {upgrade.Id} ById`)
	check(Config.Icons[`Upgrade_{upgrade.Id}`] ~= nil, `diamond upgrade {upgrade.Id} has no icon`)
	check(string.find(upgrade.Description, "{n}", 1, true) ~= nil, `{upgrade.Id} description needs a {"{n}"}`)
	local last = 0
	for level = 0, upgrade.MaxLevel - 1 do
		local cost = Diamonds.Cost(upgrade, level)
		check(cost > 0 and cost >= last, `{upgrade.Id} level {level + 1} cost {cost} should be positive and rising`)
		last = cost
	end
	check(not string.find(Diamonds.Text(upgrade, 2), "{", 1, true), `{upgrade.Id} text keeps a placeholder`)
end
check(Diamonds.ForLevel(4) == Diamonds.PerLevelUp, "a normal level gives PerLevelUp diamonds")
check(Diamonds.ForLevel(5) == Diamonds.PerLevelUp + Diamonds.MilestoneBonus, "every 5th level gives the milestone bonus")

section("Reward codes")
for name, code in Config.Codes do
	check(name == string.upper(name) and not string.find(name, "%s"), `code "{name}" must be UPPERCASE with no spaces (players' typing is uppercased)`)
	check(code.Jobs ~= nil or code.Stamps ~= nil, `code {name} gives nothing`)
	for stampId in code.Stamps or {} do
		check(Config.Stamps.ById[stampId] ~= nil, `code {name} gives "{stampId}" stamps, which don't exist`)
	end
end

section("Badges")
for key, badge in Config.Badges do
	check(type(badge.Id) == "number", `badge {key} Id must be a number (0 = not set up yet)`)
	check(#badge.Description > 0, `badge {key} needs a description`)
end

section("Sounds")
for name, sound in Config.Sounds do
	check(type(sound.Id) == "string", `sound {name} has no Id string`)
	check(sound.Id == "" or string.match(sound.Id, "^rbxassetid://%d+$") ~= nil, `sound {name}: "{sound.Id}" should look like rbxassetid://123`)
	check(type(sound.Volume) == "number" and sound.Volume >= 0 and sound.Volume <= 10, `sound {name} volume`)
end

section("Gruff")
for _, step in { "Pen", "Catch", "Escaped", "Box", "Mail", "Shop", "Reward" } do
	check(type(Config.Gruff.Tutorial[step]) == "string", `Gruff.Tutorial.{step} is missing (the tutorial uses it)`)
end
for stars = 1, 5 do
	check(#Config.Gruff.Ratings[stars] > 0, `Gruff has no rating lines for {stars} stars`)
end
check(#Config.Gruff.WelcomeBack > 0, "Gruff.WelcomeBack is empty")

section("BoxMath")
for count = 1, 5 do
	check(#BoxMath.Seams(count) == count, `Seams({count})`)
end
for index, seam in BoxMath.Seams(5) do
	local path = {}
	for step = 0, 10 do
		table.insert(path, seam.A:Lerp(seam.B, step / 10))
	end
	check(BoxMath.IsTapeStroke(seam, path), `a clean stroke along seam {index} should count`)
	local backwards = {}
	for i = #path, 1, -1 do
		table.insert(backwards, path[i])
	end
	check(BoxMath.IsTapeStroke(seam, backwards), `a backwards stroke along seam {index} should count`)
	check(not BoxMath.IsTapeStroke(seam, { seam.A, seam.A }), `a stroke that never leaves the start (seam {index}) shouldn't count`)
	local wobbly = table.clone(path)
	wobbly[6] = wobbly[6] + roblox.Vector2.new(0.2, 0.2)
	check(not BoxMath.IsTapeStroke(seam, wobbly), `a stroke that wanders off seam {index} shouldn't count`)
end
local spot = { Kind = "Sweet", X = 0.5, Y = 0.3, Radius = 0.1, Drift = 0.15, Speed = 0.3, Phase = 1 }
for t = 0, 20, 0.25 do
	local p = BoxMath.SpotPosition(spot, 0, t)
	check(p.X >= 0 and p.X <= 1 and p.Y >= 0 and p.Y <= BoxMath.VISIBLE_HEIGHT, `a drifting spot left the picture at t={t}`)
end

section("Number formatting")
local Format = load(node(ROOT .. "/Format"))
for input, expected in {
	[5] = "5", [999] = "999", [1000] = "1k", [1500] = "1.5k", [12500] = "12.5k", [150000] = "150k",
	[1000000] = "1M", [2500000] = "2.5M", [999999] = "999k", [1e9] = "1B", [3.2e12] = "3.2T",
} do
	check(Format.Short(input) == expected, `Format.Short({input}) = {Format.Short(input)}, expected {expected}`)
end

print(`\n{passes} checks passed, {failures} failed`)
process.exit(if failures == 0 then 0 else 1)
