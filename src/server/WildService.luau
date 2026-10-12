--!strict
-- Wild animals roaming every zone (numbers in Config/Wild.luau).
--   * Each zone keeps Wild.PerZone animals strolling around: mostly its own, sometimes a rarer visitor from
--     the zone above. Shiny/Golden is rolled when one appears, so you can spot a special one and go for it.
--   * HOLD E on one to grab it. Up to Wild.MaxLevelGap levels above you is allowed, but the BOX gets harder
--     the further above you it is. Any higher: VINE BOOM, you're launched out of the zone and land in town. Otherwise it's your job: normal animals go straight to the BOX screen (BoxingService.StartWild),
--     giants stay put for a crew.
--   * Lures (WildService.StartLure): for a few minutes, rarer animals you're able to take keep turning up
--     next to you, with better Shiny/Golden odds.
-- The client draws each animal's model on its ball (tag "Critter") and turns its name tag red when it's
-- too strong for you (client/WildTags.luau).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Analytics = require(script.Parent.Analytics)
local BoxingService = require(script.Parent.BoxingService)
local CatchAI = require(script.Parent.CatchAI)
local DataService = require(script.Parent.DataService)
local DiveService = require(script.Parent.DiveService)
local MailService = require(script.Parent.MailService)
local MapBuilder = require(script.Parent.MapBuilder)
local MonetizationService = require(script.Parent.MonetizationService)
local Remotes = require(script.Parent.Remotes)
local Travel = require(script.Parent.Travel)

local WildConfig = require(ReplicatedStorage.Shared.Config.Wild)

local Wild = Config.Wild
type Lure = WildConfig.Lure

type Entry = {
	Ball: Part,
	AnimalId: string,
	ArenaId: string,
	Variant: string?,
	Radius: number,
	Target: Vector3,
	Speed: number,
	PauseUntil: number,
	LuredFor: Player?,
	Expires: number?,
	Taken: boolean,
	-- Animals with an attack (Roar / Freeze / Spray / Charge, from Boxing.Twists) wind up and strike at players
	-- who come too close
	Attack: string?,
	NextAttack: number,
	AttackAt: number?, -- (os.clock) it strikes then; the client shows a red "!!" until it does
	Victim: Player?, -- who it's attacking
	ChargeUntil: number?,
}

local WildService = {}

local map: MapBuilder.Map
local folder: Folder
local wilds: { Entry } = {}
local nextSpawn: { [string]: number } = {}
local lastLure: { [Player]: number } = {}
local lastBoom: { [Player]: number } = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function between(range: { Min: number, Max: number }): number
	return range.Min + math.random() * (range.Max - range.Min)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function say(player: Player, text: string)
	Remotes.Notify:FireClient(player, "Message", { Speaker = "Postmaster Gruff", Text = text })
end

-- Which zone is this point in?
local function zoneAt(position: Vector3): string?
	for arenaId, arena in map.Arenas do
		if
			position.X >= arena.Min.X
			and position.X <= arena.Max.X
			and position.Z >= arena.Min.Z
			and position.Z <= arena.Max.Z
			and position.Y > arena.FloorY - 6
		then
			return arenaId
		end
	end
	return nil
end

local function radiusOf(animalId: string): number
	local animal = Config.Animals.ById[animalId]
	-- (big: a Hamster comes up to your shoulder, a tier 6 animal towers over you; Config/World PlayerScale)
	return 0.7 + (if animal then animal.Tier else 1) * 0.45
end

-- Shiny or Golden? (events like Golden Hour raise the odds too)
local function rollVariant(luck: number): string?
	local event = Workspace:GetAttribute("VariantLuck")
	local variant = Config.Variants.Roll(math.random(), luck * (if typeof(event) == "number" then event else 1))
	return if variant then variant.Id else nil
end

-- A normal spawn: mostly the zone's own animals, sometimes a visitor from the zone above
local function pickNormal(arenaId: string): string?
	if math.random() < Wild.VisitorChance then
		local above = Wild.NextZone(arenaId)
		local visitor = above and Wild.Pick(above, math.random() * 0.5) -- (the easier ones up there wander down)
		if visitor then
			return visitor
		end
	end
	return Wild.Pick(arenaId, math.random())
end

-- A lured spawn: the rarest animals the player can take on, from this zone or (sometimes) zones above
local function pickLured(arenaId: string, lure: Lure, level: number): string?
	local candidates: { string } = {}
	local zones = { arenaId }
	if math.random() < lure.VisitorChance then
		for step = 1, lure.VisitorReach do
			local up = Wild.NextZone(arenaId, step)
			if up then
				table.insert(zones, up)
			end
		end
	end
	for _, zone in zones do
		local list: { string } = Wild.ZoneAnimals[zone] or {}
		for _, id in list do
			if (Wild.LevelOf[id] or 1) <= level then
				table.insert(candidates, id)
			end
		end
	end
	if #candidates == 0 then
		return pickNormal(arenaId)
	end
	table.sort(candidates, function(a, b)
		return (Wild.LevelOf[a] or 1) < (Wild.LevelOf[b] or 1)
	end)
	-- Weighted toward the top of the list (the rarest you can take)
	local total = 0
	local weights = {}
	for rank in candidates do
		local weight = 1 + (rank - 1) * lure.Rarity * 2
		weights[rank] = weight
		total += weight
	end
	local roll = math.random() * total
	for rank, id in candidates do
		roll -= weights[rank]
		if roll <= 0 then
			return id
		end
	end
	return candidates[#candidates]
end

local updateAttack: (Entry, MapBuilder.Arena, number, number) -> boolean

local function remove(entry: Entry)
	entry.Taken = true
	local index = table.find(wilds, entry)
	if index then
		table.remove(wilds, index)
	end
	entry.Ball:Destroy()
end

-- Its attack, if it has one (the first of these twists it has)
local function attackOf(animalId: string): string?
	local twists = Config.Boxing.Twists[animalId]
	if not twists then
		return nil
	end
	for _, kind in { "Roar", "Freeze", "Spray", "Charge" } do
		if (twists :: any)[kind] then
			return kind
		end
	end
	return nil
end

-- Too strong for you: VINE BOOM, out of the zone, back to town
local function boom(player: Player, entry: Entry, level: number, playerLevel: number)
	local now = os.clock()
	if now - (lastBoom[player] or 0) < 3 then
		return
	end
	lastBoom[player] = now
	local root = rootOf(player)
	if not root then
		return
	end
	local animal = Config.Animals.ById[entry.AnimalId]
	local name = if animal then animal.DisplayName else entry.AnimalId
	local away = flat(root.Position - entry.Ball.Position)
	away = if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis
	Sfx.Play("VineBoom", root)
	BoxingService.Stun(player, Wild.Boom.Seconds)
	Remotes.Notify:FireClient(player, "Launch", {
		Velocity = away * Wild.Boom.Out + Vector3.new(0, Wild.Boom.Up, 0),
		Seconds = Wild.Boom.Seconds,
	})
	Remotes.Notify:FireClient(player, "Breakout", { Animal = name })
	say(player, `That {name} is Level {level}. You're Level {playerLevel}. RETURN TO SENDER!`)
	Analytics.Custom(player, "WildBoom", level - playerLevel, entry.AnimalId, Analytics.LevelBand(playerLevel))
	Analytics.Blocked(player, "TooStrong", entry.AnimalId)
	task.delay(Wild.Boom.Seconds, function()
		if player.Parent then
			Travel.ToTown(player)
		end
	end)
end

local function onGrab(entry: Entry, player: Player)
	if entry.Taken then
		return
	end
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	if BoxingService.IsBoxing(player) then
		return
	end
	BoxingService.DropJob(player) -- (an old animal still running loose doesn't block a new grab)
	if not MailService.HasRoom(player) then
		say(player, Config.Gruff.BagFull)
		Analytics.Blocked(player, "GrabBagFull", tostring(MailService.Count(player)))
		return
	end
	local level = Wild.LevelOf[entry.AnimalId] or 1
	if level > profile.Level + Wild.MaxLevelGap then
		boom(player, entry, level, profile.Level)
		return
	end
	-- Above your level (but within reach): a harder BOX, the hardest at the full gap
	local difficulty = math.clamp((level - profile.Level) / Wild.MaxLevelGap, 0, 1)
	local at = entry.Ball.Position
	remove(entry)
	if BoxingService.StartWild(player, entry.AnimalId, entry.ArenaId, entry.Variant, at, difficulty) then
		Analytics.Custom(
			player,
			"WildGrab",
			1,
			Analytics.RarityOf(entry.AnimalId),
			if difficulty > 0 then "Hard" else "Normal",
			if entry.Variant then entry.Variant else Analytics.Segment(player)
		)
	end
end

local function spawn(
	arenaId: string,
	near: Vector3?,
	lure: Lure?,
	luredFor: Player?,
	forced: string?,
	forcedVariant: string?
): Entry?
	local arena = map.Arenas[arenaId]
	if not arena then
		return nil
	end
	local animalId = if forced
		then forced
		elseif lure and luredFor then pickLured(
			arenaId,
			lure,
			(DataService.Get(luredFor) or { Level = 1 } :: any).Level
		)
		else pickNormal(arenaId)
	local animal = animalId and Config.Animals.ById[animalId]
	if not animalId or not animal then
		return nil
	end
	local radius = radiusOf(animalId)
	local position = if near
		then CatchAI.PushOutOfObstacles(arena, CatchAI.ClampToArena(arena, flat(near), radius), radius)
		else CatchAI.RandomArenaPoint(arena, radius)
	local variantId = forcedVariant or rollVariant(if lure then lure.VariantLuck else 1)
	local variant = if variantId then Config.Variants.ById[variantId] else nil
	local level = Wild.LevelOf[animalId] or 1

	local ball = Instance.new("Part")
	ball.Name = "WildAnimal"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * radius * 2
	ball.Color = animal.Color or Color3.new(1, 1, 1)
	ball.Anchored = true
	ball.CanCollide = false
	ball:SetAttribute("AnimalId", animalId)
	ball:SetAttribute("Variant", variantId)
	ball:SetAttribute("Wild", true)
	ball:SetAttribute("Level", level)
	if luredFor then
		ball:SetAttribute("LuredFor", luredFor.UserId)
	end
	ball.CFrame = CFrame.new(position + Vector3.new(0, arena.FloorY + radius, 0))
	MapBuilder.Label(
		ball,
		`{if variant then variant.Emoji .. " " .. variant.DisplayName .. " " else ""}{animal.DisplayName}  Lv {level}`,
		radius + 1.5,
		if variant then variant.Color else nil
	)
	-- its rarity, in the rarity's color, as a second line of the name tag (Config/Rarity.luau). (The name stays
	-- the tag's first TextLabel: client/WildTags.luau recolors it.)
	local rarity = Config.Rarity.ById[Wild.RarityOf[animal.Id] or "Common"]
	local nameTag = ball:FindFirstChild("Label") :: BillboardGui?
	local nameText = nameTag and nameTag:FindFirstChildOfClass("TextLabel")
	if rarity and nameTag and nameText then
		nameTag.Size = UDim2.fromOffset(190, 50)
		nameTag.StudsOffset += Vector3.new(0, 0.4, 0)
		nameText.Size = UDim2.fromScale(1, 0.6)
		local text = Instance.new("TextLabel")
		text.Name = "Rarity"
		text.Position = UDim2.fromScale(0, 0.62)
		text.Size = UDim2.fromScale(1, 0.38)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.LuckiestGuy
		text.TextScaled = true
		text.TextColor3 = rarity.Color
		text.TextStrokeTransparency = 0
		text.TextStrokeColor3 = if rarity.Id == "Secret" then Color3.new(1, 0.85, 0.3) else Color3.new(0, 0, 0)
		text.Text = string.upper(rarity.DisplayName)
		text.Parent = nameTag
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = if animal.Carriers > 1 then "Grab (needs a crew)" else "Grab"
	prompt.ObjectText = `{animal.DisplayName} · Lv {level}`
	prompt.HoldDuration = Wild.GrabHold
	prompt.MaxActivationDistance = Wild.GrabDistance + radius
	prompt.RequiresLineOfSight = false
	prompt.Parent = ball

	local entry: Entry = {
		Ball = ball,
		AnimalId = animalId,
		ArenaId = arenaId,
		Variant = variantId,
		Radius = radius,
		Target = CatchAI.RandomArenaPoint(arena, radius),
		Speed = between(Wild.WanderSpeed),
		PauseUntil = os.clock() + between(Wild.PauseSeconds),
		LuredFor = luredFor,
		Expires = if luredFor then os.clock() + Wild.LuredLifetime else nil,
		Taken = false,
		Attack = attackOf(animalId),
		NextAttack = os.clock() + 2,
	}
	prompt.Triggered:Connect(function(player: Player)
		onGrab(entry, player)
	end)
	prompt.PromptButtonHoldBegan:Connect(function(player: Player)
		DiveService.Engage(player, Wild.GrabHold + 1) -- (grabbing this one: the others hold off)
	end)
	ball.Parent = folder
	CollectionService:AddTag(ball, "Critter") -- (the client draws the Blender model on it)
	table.insert(wilds, entry)
	return entry
end

-- The nearest player this animal could attack (in range, not busy boxing)
local function attackTarget(entry: Entry, range: number): Player?
	if Workspace:GetAttribute("WildCalm") == true then
		return nil -- (Studio test switch: the automated playtest turns attacks off for its scripted steps)
	end
	local best, bestDistance = nil, range
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root and not DiveService.IsEngaged(player) and player:GetAttribute("Frozen") ~= true then
			local distance = (flat(root.Position) - flat(entry.Ball.Position)).Magnitude
			if distance < bestDistance and math.abs(root.Position.Y - entry.Ball.Position.Y) < 12 then
				best, bestDistance = player, distance
			end
		end
	end
	return best
end

-- Winds up (red "!!"), then strikes: Roar / Freeze / Spray hit everyone close; Charge dashes at its target.
-- Returns true while the attack is moving the animal (so it doesn't wander meanwhile).
updateAttack = function(entry: Entry, arena: MapBuilder.Arena, now: number, dt: number): boolean
	local attack = Config.Dive.Attack
	local kind = entry.Attack :: string
	local range = (attack.Range :: any)[kind] or 10
	local animal = Config.Animals.ById[entry.AnimalId]
	local name = if animal then animal.DisplayName else entry.AnimalId
	-- Charging: run straight at the target; contact = VINE BOOM
	if entry.ChargeUntil then
		local target = entry.Victim
		local root = target and rootOf(target)
		if now > entry.ChargeUntil or not root then
			entry.ChargeUntil = nil
			return false
		end
		local here = flat(entry.Ball.Position)
		local toward = flat(root.Position) - here
		if toward.Magnitude < entry.Radius + 2.5 then
			entry.ChargeUntil = nil
			DiveService.Hit(target :: Player, entry.Ball.Position, "Charge", name)
			return false
		end
		local nextPos = here + toward.Unit * math.min(28 * dt, toward.Magnitude)
		nextPos = CatchAI.ClampToArena(arena, nextPos, entry.Radius)
		local y = arena.FloorY + entry.Radius
		entry.Ball.CFrame =
			CFrame.lookAt(Vector3.new(nextPos.X, y, nextPos.Z), Vector3.new(root.Position.X, y, root.Position.Z))
		return true
	end
	-- Winding up
	if entry.AttackAt then
		local victim = entry.Victim
		if victim and DiveService.IsEngaged(victim) then
			-- They grabbed another animal: never mind
			entry.AttackAt = nil
			entry.Ball:SetAttribute("AttackAt", nil)
			entry.NextAttack = now + attack.Cooldown
			return false
		end
		if now < entry.AttackAt then
			return true -- (stands still, shaking, with the red "!!")
		end
		entry.AttackAt = nil
		entry.Ball:SetAttribute("AttackAt", nil)
		entry.NextAttack = now + attack.Cooldown
		if kind == "Charge" then
			entry.ChargeUntil = now + 0.8
			return true
		end
		for _, player in Players:GetPlayers() do
			local root = rootOf(player)
			if
				root
				and not DiveService.IsEngaged(player)
				and (flat(root.Position) - flat(entry.Ball.Position)).Magnitude < range * 1.15
				and math.abs(root.Position.Y - entry.Ball.Position.Y) < 12
			then
				DiveService.Hit(player, entry.Ball.Position, kind, name)
			end
		end
		return false
	end
	-- Ready to attack? Pick on the closest player in range
	if now >= entry.NextAttack then
		local target = attackTarget(entry, range)
		if target then
			entry.Victim = target
			entry.AttackAt = now + attack.WindUp
			entry.Ball:SetAttribute("AttackAt", Workspace:GetServerTimeNow() + attack.WindUp)
			entry.Ball:SetAttribute("AttackKind", kind)
			return true
		end
		entry.NextAttack = now + 0.5 -- (nobody near: look again soon)
	end
	return false
end

local function step(dt: number)
	local now = os.clock()
	for i = #wilds, 1, -1 do
		local entry = wilds[i]
		if entry.Taken then
			continue
		end
		if entry.Expires and now > entry.Expires then
			remove(entry)
			continue
		end
		local arena = map.Arenas[entry.ArenaId]
		if entry.Attack and updateAttack(entry, arena, now, dt) then
			continue -- (winding up or charging: the attack moves it)
		end
		if now < entry.PauseUntil then
			continue
		end
		local here = flat(entry.Ball.Position)
		local toTarget = entry.Target - here
		if toTarget.Magnitude < 1 then
			-- Arrived: stand around for a bit, then stroll somewhere new
			entry.Target = CatchAI.RandomArenaPoint(arena, entry.Radius)
			entry.Speed = between(Wild.WanderSpeed)
			entry.PauseUntil = now + between(Wild.PauseSeconds)
			continue
		end
		local direction = (toTarget.Unit + CatchAI.ObstacleAvoidance(arena, here, entry.Radius) * 0.5)
		direction = if direction.Magnitude > 0.01 then direction.Unit else toTarget.Unit
		local nextPos = here + direction * math.min(entry.Speed * dt, toTarget.Magnitude)
		nextPos = CatchAI.PushOutOfObstacles(arena, CatchAI.ClampToArena(arena, nextPos, entry.Radius), entry.Radius)
		local y = arena.FloorY + entry.Radius
		entry.Ball.CFrame =
			CFrame.lookAt(Vector3.new(nextPos.X, y, nextPos.Z), Vector3.new(entry.Target.X, y, entry.Target.Z))
	end
end

-- Keeps each zone stocked, and spawns lured animals next to players with a lure running
local function restock()
	local now = os.clock()
	local counts: { [string]: number } = {}
	local lured: { [Player]: number } = {}
	for _, entry in wilds do
		if entry.LuredFor then
			lured[entry.LuredFor] = (lured[entry.LuredFor] or 0) + 1
		else
			counts[entry.ArenaId] = (counts[entry.ArenaId] or 0) + 1
		end
	end
	for arenaId in map.Arenas do
		if (counts[arenaId] or 0) < Wild.PerZone and now >= (nextSpawn[arenaId] or 0) then
			nextSpawn[arenaId] = now + Wild.RespawnSeconds
			spawn(arenaId, nil, nil, nil)
		end
	end
	local serverNow = Workspace:GetServerTimeNow()
	for _, player in Players:GetPlayers() do
		local untilTime = player:GetAttribute("LureUntil")
		local lureId = player:GetAttribute("LureId")
		local lure = if typeof(lureId) == "string" then Wild.Lures[lureId] else nil
		if not lure or typeof(untilTime) ~= "number" or untilTime <= serverNow then
			continue
		end
		local root = rootOf(player)
		local zone = root and zoneAt(root.Position)
		if not root or not zone or player:GetAttribute("Stage") == "Box" then
			continue
		end
		if now - (lastLure[player] or 0) >= lure.Every and (lured[player] or 0) < lure.MaxNearby then
			lastLure[player] = now
			local angle = math.random() * math.pi * 2
			local distance = 8 + math.random() * 10
			spawn(zone, root.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance, lure, player)
		end
	end
end

-- Studio only (the automated playtest and the Promo Kit): a wild animal of your choice right next to you, in
-- the zone you're standing in (or the Backyard)
-- An animal hatched from an egg (EggService): it pops out at `at`, in its own zone
function WildService.Hatch(animalId: string, at: Vector3, _forPlayer: Player?)
	if not Config.Animals.ById[animalId] then
		return
	end
	local zone = zoneAt(at) or Wild.ZoneOf[animalId] or "Backyard"
	spawn(zone, at, nil, nil, animalId)
end

function WildService.SpawnNear(player: Player, animalId: string)
	local root = rootOf(player)
	if not RunService:IsStudio() or not root or not Config.Animals.ById[animalId] then
		return
	end
	local zone = zoneAt(root.Position) or "Backyard"
	spawn(zone, root.Position + root.CFrame.LookVector * 6, nil, nil, animalId)
end

-- Gruff's walkthrough: a calm, easy animal standing right in front of a brand-new player (TutorialService), so
-- the first grab takes seconds instead of a hunt. It never attacks, never wanders off, and is theirs alone.
function WildService.SpawnTutorial(player: Player)
	local root = rootOf(player)
	if not root then
		return
	end
	-- The easiest one-person animal on the Backyard
	local easiest, easiestLevel = nil, math.huge
	for _, animal in Config.Animals.List do
		local level = Wild.LevelOf[animal.Id] or 1
		if Wild.ZoneOf[animal.Id] == "Backyard" and animal.Carriers == 1 and level < easiestLevel then
			easiest, easiestLevel = animal.Id, level
		end
	end
	if not easiest then
		return
	end
	local entry = spawn("Backyard", root.Position + root.CFrame.LookVector * 10, nil, player, easiest, nil)
	if entry then
		entry.Attack = nil
		entry.PauseUntil = os.clock() + 600 -- (stands still)
		entry.Expires = os.clock() + 600
		entry.Ball:SetAttribute("Tutorial", true)
	end
end

-- Starts (or extends) a lure for a player: "Lure" (coins) or "MegaLure" (Robux)
function WildService.StartLure(player: Player, lureId: string)
	local lure = Wild.Lures[lureId]
	if not lure then
		return
	end
	local now = Workspace:GetServerTimeNow()
	local current = player:GetAttribute("LureUntil")
	local from = if typeof(current) == "number" and current > now then current else now
	player:SetAttribute("LureUntil", from + lure.Seconds)
	-- (a Mega Lure always wins over a small one while both are running)
	if player:GetAttribute("LureId") ~= "MegaLure" or lureId == "MegaLure" then
		player:SetAttribute("LureId", lureId)
	end
	say(
		player,
		`{lure.DisplayName} on! Rarer animals will turn up right next to you in any zone for {lure.Seconds // 60} minutes.`
	)
	Analytics.Custom(player, "Bought", 1, "Lure", lureId, Analytics.Segment(player))
end

function WildService.Start(builtMap: MapBuilder.Map)
	map = builtMap
	folder = Instance.new("Folder")
	folder.Name = "WildAnimals"
	folder.Parent = Workspace
	-- Fill every zone right away
	for arenaId in map.Arenas do
		for _ = 1, Wild.PerZone do
			spawn(arenaId, nil, nil, nil)
		end
	end
	-- Diving into a wild animal grabs it (no holding E). Too strong for you? Same VINE BOOM.
	table.insert(DiveService.OnDive, function(player: Player, root: BasePart): boolean
		local best, bestDistance = nil, math.huge
		for _, entry in wilds do
			if not entry.Taken then
				local distance = (entry.Ball.Position - root.Position).Magnitude
				if distance < entry.Radius + Config.Dive.GrabReach and distance < bestDistance then
					best, bestDistance = entry, distance
				end
			end
		end
		if not best then
			return false
		end
		onGrab(best, player)
		return true
	end)
	-- An animal that escaped a box goes back into the wild where it got out (a Shiny stays Shiny)
	BoxingService.OnEscape = function(animalId: string, arenaId: string, at: Vector3, variant: string?)
		spawn(if map.Arenas[arenaId] then arenaId else "Backyard", at, nil, nil, animalId, variant)
	end
	MonetizationService.OnMegaLure = function(player: Player)
		WildService.StartLure(player, "MegaLure")
	end
	RunService.Heartbeat:Connect(step)
	task.spawn(function()
		while true do
			task.wait(1)
			restock()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastLure[player] = nil
		lastBoom[player] = nil
		for i = #wilds, 1, -1 do
			if wilds[i].LuredFor == player then
				remove(wilds[i])
			end
		end
	end)
end

return WildService
