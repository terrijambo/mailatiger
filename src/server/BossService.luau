--!strict
-- THE BIG ONE: the hourly boss (numbers in Config/Events.luau -> Boss, plan in docs/EVENTS_PLAN.md).
-- A giant animal (Mega Tiger, King Yeti, Mama Dragon, one per hour in turn) lands on a floating island east of
-- town. Everyone there works together:
--   1. PIN IT: hold the glowing rope handles around it. It's pinned while enough people hold on at once (about
--      half the players there); stay pinned long enough and it's caught. It stomps (jump over the shockwave!)
--      and roars to throw people off.
--   2. BOX IT: everyone gets the BOX screen at once, on one shared box. Each seam needs several strips (more
--      players, more strips) while petters keep the shared anger down. At 100 anger: MEGA VINE BOOM, everyone
--      is launched and it's back to step 1.
-- Rewards depend on how much each player helped. The top helper wears a crown until the next boss.
-- Workspace attributes for the client: BossName, BossPhase ("Pin"/"Box"), BossPin (0..1), BossHeld,
-- BossNeed, BossTaped, BossSeams, BossEndsAt, BossPadOpen.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BoxMath = require(ReplicatedStorage.Shared.BoxMath)
local Config = require(ReplicatedStorage.Shared.Config)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Analytics = require(script.Parent.Analytics)
local Badges = require(script.Parent.Badges)
local BoxingService = require(script.Parent.BoxingService)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local MapBuilder = require(script.Parent.MapBuilder)
local Remotes = require(script.Parent.Remotes)
local Travel = require(script.Parent.Travel)

local Boss = Config.Events.Boss
local SEAMS = 5

local BossService = {}

local arena: Folder
local platformTop = 0
local pad: BasePart? = nil
type Fight = {
	Until: number,
	Name: string,
	AnimalId: string,
	Phase: string,
	Ball: BasePart,
	Handles: { BasePart },
	Holding: { [Player]: BasePart },
	Pin: number,
	Target: Vector3,
	NextStomp: number,
	NextRoar: number,
	Work: { [Player]: number },
	-- BOX phase
	Boxers: { Player },
	Anger: number,
	Spots: { BoxMath.Spot },
	Start: number,
	Strips: { number },
	Taped: { boolean },
	Need: number,
	LastStrip: { [Player]: number },
	LastPet: { [Player]: number },
	LastAngry: { [Player]: number },
	Raged: { [number]: boolean },
}
local fight: Fight? = nil
local stunnedUntil: { [Player]: number } = {}
local crownHolder: Player? = nil
local bossIndex = 0

local function center(): Vector3
	return Boss.ArenaCenter + Vector3.new(0, platformTop, 0)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function inArena(player: Player): boolean
	local root = rootOf(player)
	if not root then
		return false
	end
	local offset = root.Position - Boss.ArenaCenter
	return math.abs(offset.X) < Boss.ArenaSize / 2 + 10
		and math.abs(offset.Z) < Boss.ArenaSize / 2 + 10
		and root.Position.Y > -20
end

local function playersHere(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if inArena(player) then
			table.insert(list, player)
		end
	end
	return list
end

local function notifyHere(kind: string, data: { [string]: any })
	for _, player in playersHere() do
		Remotes.Notify:FireClient(player, kind, data)
	end
end

local function addWork(player: Player, amount: number)
	if fight then
		fight.Work[player] = (fight.Work[player] or 0) + amount
	end
end

local function teleport(player: Player, at: Vector3)
	local character = player.Character
	if character then
		character:PivotTo(CFrame.new(at + Vector3.new(0, 4, 0)))
	end
end

---------------------------------------------------------------------------------------------------
-- The arena (built once: a floating grass island over the ocean, with a rim and a way home)

local function buildArena(map: MapBuilder.Map)
	arena = Instance.new("Folder")
	arena.Name = "BossArena"
	arena.Parent = Workspace
	local size = Boss.ArenaSize
	local function block(name: string, cframe: CFrame, partSize: Vector3, color: Color3, material: Enum.Material?)
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.Size = partSize
		part.CFrame = cframe
		part.Color = color
		part.Material = material or Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.Parent = arena
		return part
	end
	local c = Boss.ArenaCenter
	block("Island", CFrame.new(c + Vector3.new(0, -4, 0)), Vector3.new(size, 8, size), Color3.fromRGB(112, 214, 86))
	block(
		"Cliff",
		CFrame.new(c + Vector3.new(0, -14, 0)),
		Vector3.new(size - 8, 14, size - 8),
		Color3.fromRGB(150, 110, 80)
	)
	for _, side in { -1, 1 } do
		block(
			"Rim",
			CFrame.new(c + Vector3.new(side * (size / 2 - 1), 1.5, 0)),
			Vector3.new(2, 3, size),
			Color3.fromRGB(200, 200, 210)
		)
		block(
			"Rim",
			CFrame.new(c + Vector3.new(0, 1.5, side * (size / 2 - 1))),
			Vector3.new(size, 3, 2),
			Color3.fromRGB(200, 200, 210)
		)
	end
	platformTop = 0
	-- The pad home
	local home = block(
		"BackToTown",
		CFrame.new(c + Vector3.new(0, 0.2, size / 2 - 8)),
		Vector3.new(10, 0.4, 6),
		Color3.fromRGB(70, 160, 255),
		Enum.Material.Neon
	)
	MapBuilder.Label(home, "BACK TO TOWN", 3)
	home.Touched:Connect(function(hit)
		local model = hit:FindFirstAncestorOfClass("Model")
		local player = model and Players:GetPlayerFromCharacter(model)
		if player and not (fight and fight.Phase == "Box" and table.find(fight.Boxers, player)) then
			Travel.ToTown(player)
		end
	end)
	local _ = map
end

-- The BOSS pad in the plaza (only there while a boss is coming or on)
local function setPad(open: boolean)
	Workspace:SetAttribute("BossPadOpen", open)
	if open and not pad then
		local part = Instance.new("Part")
		part.Name = "BossPad"
		part.Anchored = true
		part.Size = Vector3.new(10, 0.4, 10)
		part.CFrame = CFrame.new(0, 0.25, 2)
		part.Color = Color3.fromRGB(255, 70, 70)
		part.Material = Enum.Material.Neon
		part.CanCollide = false
		part.Parent = arena
		MapBuilder.Label(part, "⚔️ BOSS ARENA", 5, Color3.fromRGB(255, 120, 120))
		part.Touched:Connect(function(hit)
			local model = hit:FindFirstAncestorOfClass("Model")
			local player = model and Players:GetPlayerFromCharacter(model)
			if not player or inArena(player) then
				return
			end
			local stage = player:GetAttribute("Stage")
			if typeof(stage) == "string" and stage ~= "" then
				Remotes.Notify:FireClient(player, "Message", {
					Speaker = "Postmaster Gruff",
					Text = "Finish your job first. The boss can wait. Barely.",
				})
				return
			end
			teleport(player, center() + Vector3.new(math.random(-10, 10), 0, Boss.ArenaSize / 2 - 16))
		end)
		pad = part
	elseif not open and pad then
		pad:Destroy()
		pad = nil
	end
end

function BossService.SetWarning(coming: boolean, at: number)
	if coming then
		local next = Boss.Bosses[(bossIndex % #Boss.Bosses) + 1]
		Workspace:SetAttribute("BossName", next.DisplayName)
	end
	setPad(coming or fight ~= nil)
	local _ = at
end

---------------------------------------------------------------------------------------------------
-- Ending a fight

local function endBox(players: { Player })
	for _, player in players do
		if player.Parent then
			player:SetAttribute("Stage", "")
			player:SetAttribute("Tip", "")
			player:SetAttribute("Anger", nil)
			player:SetAttribute("Frozen", false)
			Remotes.Notify:FireClient(player, "BoxDone", {})
		end
	end
end

local function giveCrown(player: Player?)
	local old = crownHolder
	crownHolder = player
	if old and old.Parent then
		old:SetAttribute("BossCrown", nil)
	end
	if player then
		player:SetAttribute("BossCrown", true)
	end
end

local function finish(won: boolean)
	local f = fight
	if not f then
		return
	end
	fight = nil
	if f.Phase == "Box" then
		endBox(f.Boxers)
	end
	for _, handle in f.Handles do
		handle:Destroy()
	end
	f.Ball:Destroy()
	for _, name in { "BossPhase", "BossPin", "BossHeld", "BossNeed", "BossTaped", "BossSeams", "BossEndsAt" } do
		Workspace:SetAttribute(name, nil)
	end
	setPad(false)

	local top, topPlayer = 0, nil
	for player, work in f.Work do
		if work > top and player.Parent then
			top, topPlayer = work, player
		end
	end
	for player, work in f.Work do
		local profile = DataService.Get(player)
		if profile and player.Parent and work > 0 then
			local share = if top > 0 then work / top else 0
			if won then
				local diamonds = math.round(Boss.Diamonds.Min + (Boss.Diamonds.Max - Boss.Diamonds.Min) * share)
				local coins = math.round(Economy.BestBaseValue(player) * Boss.Jobs * (0.5 + 0.5 * share))
				profile.Diamonds += diamonds
				profile.BossWins += 1
				profile.LuckyNext = true -- their next job is a Shiny
				Economy.AddCoins(player, coins, "Boss")
				Remotes.Notify:FireClient(player, "Diamonds", { Amount = diamonds, Source = "Boss" })
				Remotes.Notify:FireClient(player, "BossReward", {
					Diamonds = diamonds,
					Coins = coins,
					Top = player == topPlayer,
				})
				Badges.Award(player, "BossHunter")
			else
				profile.Diamonds += Boss.LoseDiamonds
				Remotes.Notify:FireClient(player, "Diamonds", { Amount = Boss.LoseDiamonds, Source = "BossLose" })
				Economy.Sync(player)
			end
			Analytics.Custom(player, if won then "BossWon" else "BossLost")
		end
	end
	if won then
		giveCrown(topPlayer)
	end
	Remotes.Notify:FireAllClients(if won then "BossWin" else "BossLose", {
		Boss = f.Name,
		Top = if won and topPlayer then topPlayer.DisplayName else nil,
	})
end

---------------------------------------------------------------------------------------------------
-- PIN IT

local function makeSpots(): { BoxMath.Spot }
	local spots = {}
	local layout: { { any } } = {
		{ "Sweet", 0.3, 0.25, 0.12 },
		{ "Sweet", 0.7, 0.35, 0.12 },
		{ "Angry", 0.5, 0.15, 0.09 },
		{ "Angry", 0.2, 0.5, 0.09 },
		{ "Angry", 0.8, 0.55, 0.09 },
	}
	for _, s in layout do
		table.insert(spots, {
			Kind = s[1],
			X = s[2],
			Y = s[3],
			Radius = s[4],
			Drift = 0.08,
			Speed = 0.3,
			Phase = math.random() * math.pi * 2,
		})
	end
	return spots
end

local function startBox()
	local f = fight
	if not f then
		return
	end
	f.Phase = "Box"
	f.Holding = {}
	f.Boxers = {}
	for _, player in playersHere() do
		if (stunnedUntil[player] or 0) < os.clock() and rootOf(player) then
			table.insert(f.Boxers, player)
		end
	end
	f.Anger = Boss.StartAnger
	f.Spots = makeSpots()
	f.Start = Workspace:GetServerTimeNow()
	f.Need = math.clamp(math.ceil(#f.Boxers * Boss.StripsPerSeamPerPlayer), 1, Boss.MaxStripsPerSeam)
	f.Strips = table.create(SEAMS, 0)
	f.Taped = table.create(SEAMS, false)
	f.Raged = {}
	Workspace:SetAttribute("BossPhase", "Box")
	Workspace:SetAttribute("BossTaped", 0)
	Workspace:SetAttribute("BossSeams", SEAMS)
	for _, player in f.Boxers do
		player:SetAttribute("Stage", "Box")
		player:SetAttribute(
			"Tip",
			`BOX THE {f.Name}! Everyone tapes the same box, and every seam needs {f.Need} strips.`
		)
		player:SetAttribute("Frozen", true)
		player:SetAttribute("Anger", math.floor(f.Anger))
		Remotes.Notify:FireClient(player, "BoxStart", {
			AnimalId = f.AnimalId,
			Start = f.Start,
			Spots = f.Spots,
			SeamCount = SEAMS,
			BoxId = "Steel",
			Role = "Both",
		})
	end
	notifyHere("Message", { Speaker = "BOSS", Text = `PINNED! Now BOX the {f.Name} together, before it blows!` })
end

local function stomp(f: Fight?)
	if not f then
		return
	end
	local at = f.Ball.Position
	notifyHere("BossStomp", { At = Vector3.new(at.X, platformTop, at.Z), Radius = Boss.StompRadius, Delay = 1 })
	task.delay(1, function()
		if fight ~= f then
			return
		end
		Sfx.Play("Bonk", f.Ball)
		for _, player in playersHere() do
			local root = rootOf(player)
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if root and humanoid then
				local flat = Vector3.new(root.Position.X - at.X, 0, root.Position.Z - at.Z)
				local airborne = humanoid.FloorMaterial == Enum.Material.Air
				if flat.Magnitude < Boss.StompRadius and not airborne then
					stunnedUntil[player] = os.clock() + Boss.StompStun
					f.Holding[player] = nil
					BoxingService.Stun(player, Boss.StompStun)
					Remotes.Notify:FireClient(player, "Knockback", {
						Direction = if flat.Magnitude > 0.1 then flat.Unit else Vector3.xAxis,
						Strength = 45,
					})
				end
			end
		end
	end)
end

local function roar(f: Fight?)
	if not f then
		return
	end
	Sfx.Play("Roar", f.Ball)
	notifyHere("Roar", {})
	for _, player in playersHere() do
		local root = rootOf(player)
		if root then
			local flat = Vector3.new(root.Position.X - f.Ball.Position.X, 0, root.Position.Z - f.Ball.Position.Z)
			if flat.Magnitude < Boss.RoarRadius then
				f.Holding[player] = nil
				Remotes.Notify:FireClient(player, "Knockback", {
					Direction = if flat.Magnitude > 0.1 then flat.Unit else Vector3.zAxis,
					Strength = 70,
				})
			end
		end
	end
end

local function updatePin(f: Fight?, dt: number)
	if not f then
		return
	end
	local now = os.clock()
	-- Who's holding on right now (not stunned, still close to their handle)
	local held = 0
	for player, handle in f.Holding do
		local root = rootOf(player)
		if
			not player.Parent
			or not root
			or (stunnedUntil[player] or 0) > now
			or (root.Position - handle.Position).Magnitude > 14
		then
			f.Holding[player] = nil
		else
			held += 1
			addWork(player, dt)
		end
	end
	local need = math.clamp(math.ceil(#playersHere() / 2), 1, Boss.Handles)
	if held >= need then
		f.Pin = math.min(1, f.Pin + dt / Boss.PinSeconds)
	else
		f.Pin = math.max(0, f.Pin - dt / (Boss.PinSeconds * 2))
	end
	Workspace:SetAttribute("BossPin", math.floor(f.Pin * 100) / 100)
	Workspace:SetAttribute("BossHeld", held)
	Workspace:SetAttribute("BossNeed", need)
	if f.Pin >= 1 then
		startBox()
		return
	end

	-- It wanders, slower the more people hang on
	local ball = f.Ball
	local flat = Vector3.new(ball.Position.X, 0, ball.Position.Z)
	local toTarget = f.Target - flat
	if toTarget.Magnitude < 3 then
		local angle, distance = math.random() * math.pi * 2, math.random() * (Boss.ArenaSize / 2 - Boss.Size / 2 - 6)
		f.Target = Vector3.new(
			Boss.ArenaCenter.X + math.cos(angle) * distance,
			0,
			Boss.ArenaCenter.Z + math.sin(angle) * distance
		)
	else
		local speed = Boss.Speed * math.max(0.15, 1 - held / need * 0.85)
		local step = flat + toTarget.Unit * math.min(speed * dt, toTarget.Magnitude)
		ball.CFrame = CFrame.lookAt(
			step + Vector3.new(0, platformTop + Boss.Size / 2, 0),
			f.Target + Vector3.new(0, platformTop + Boss.Size / 2, 0)
		)
	end
	for index, handle in f.Handles do
		local angle = index / #f.Handles * math.pi * 2
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (Boss.Size / 2 + 1.5)
		handle.CFrame = CFrame.new(Vector3.new(ball.Position.X, platformTop + 3, ball.Position.Z) + offset)
	end

	if now >= f.NextStomp then
		f.NextStomp = now + Boss.StompEvery
		stomp(f)
	end
	if now >= f.NextRoar then
		f.NextRoar = now + Boss.RoarEvery
		roar(f)
	end
end

---------------------------------------------------------------------------------------------------
-- BOX IT

local function launchAll(f: Fight?)
	if not f then
		return
	end
	local boxers = f.Boxers
	endBox(boxers)
	for _, player in boxers do
		local root = rootOf(player)
		if root then
			Sfx.Play("VineBoom", root)
		end
		local angle = math.random() * math.pi * 2
		Remotes.Notify:FireClient(player, "Launch", {
			Velocity = Vector3.new(math.cos(angle) * 30, 120, math.sin(angle) * 30),
			Seconds = 3,
		})
		BoxingService.Stun(player, 3)
	end
	notifyHere("Message", { Speaker = "BOSS", Text = `MEGA VINE BOOM! The {f.Name} broke free! Pin it again!` })
	f.Phase = "Pin"
	f.Pin = 0
	f.Boxers = {}
	Workspace:SetAttribute("BossPhase", "Pin")
	Workspace:SetAttribute("BossTaped", nil)
end

local function updateBox(f: Fight?, dt: number)
	if not f then
		return
	end
	-- Anyone who left the island drops out of the box
	for i = #f.Boxers, 1, -1 do
		local player = f.Boxers[i]
		if not player.Parent or not inArena(player) then
			table.remove(f.Boxers, i)
			endBox({ player })
		end
	end
	if #f.Boxers == 0 then
		f.Phase = "Pin"
		f.Pin = 0
		Workspace:SetAttribute("BossPhase", "Pin")
		return
	end
	f.Anger += Boss.AngerRate * dt
	if f.Anger >= 100 then
		launchAll(f)
		return
	end
	for _, player in f.Boxers do
		player:SetAttribute("Anger", math.floor(f.Anger))
	end
end

local function onInput(player: Player, action: unknown, index: unknown)
	local f = fight
	if not f or f.Phase ~= "Box" or not table.find(f.Boxers, player) or typeof(index) ~= "number" then
		return
	end
	local now = os.clock()
	if action == "Pet" then
		local spot = f.Spots[index]
		if spot and spot.Kind == "Sweet" then
			local elapsed = math.min(now - (f.LastPet[player] or now), 0.25)
			f.LastPet[player] = now
			f.Anger = math.max(0, f.Anger - Boss.PetCalmPerSecond * elapsed)
			addWork(player, elapsed * 2)
		end
	elseif action == "Angry" then
		local spot = f.Spots[index]
		if spot and spot.Kind == "Angry" and now - (f.LastAngry[player] or 0) >= 0.5 then
			f.LastAngry[player] = now
			f.Anger += 8
			Remotes.Notify:FireClient(player, "AngryTouch", {})
		end
	elseif action == "Tape" then
		if f.Taped[index] ~= false or now - (f.LastStrip[player] or 0) < 0.35 then
			return
		end
		f.LastStrip[player] = now
		f.Strips[index] += 1
		f.Anger += Boss.TapeAnger
		addWork(player, 3)
		if f.Strips[index] >= f.Need then
			f.Taped[index] = true
			local done = 0
			for _, taped in f.Taped do
				if taped then
					done += 1
				end
			end
			Workspace:SetAttribute("BossTaped", done)
			if done == SEAMS then
				-- Boxed it! (everyone's BOX screen shows the SEALED! finale)
				for _, boxer in f.Boxers do
					Remotes.Notify:FireClient(boxer, "SeamTaped", { Seam = index })
				end
				finish(true)
				return
			end
			for _, boxer in f.Boxers do
				Remotes.Notify:FireClient(boxer, "SeamTaped", { Seam = index })
			end
			-- It rages at 50% and 80%
			for _, mark in { 0.5, 0.8 } do
				if done / SEAMS >= mark and not f.Raged[mark] then
					f.Raged[mark] = true
					f.Anger += Boss.RageAnger
					Sfx.Play("Roar", f.Ball)
					for _, boxer in f.Boxers do
						Remotes.Notify:FireClient(boxer, "Thump", {})
						Remotes.Notify:FireClient(
							boxer,
							"Message",
							{ Speaker = "BOSS", Text = `The {f.Name} is RAGING! Pet it!` }
						)
					end
				end
			end
		else
			for _, boxer in f.Boxers do
				Remotes.Notify:FireClient(boxer, "BossStrip", { Seam = index, Have = f.Strips[index], Need = f.Need })
			end
		end
	end
	for _, boxer in f.Boxers do
		boxer:SetAttribute("Anger", math.floor(f.Anger))
	end
end

---------------------------------------------------------------------------------------------------

-- Starts a boss fight that lasts until `untilTime` (unix time)
function BossService.Begin(untilTime: number, _studio: boolean)
	if fight or os.time() >= untilTime - 10 then
		return
	end
	bossIndex += 1
	local def = Boss.Bosses[((bossIndex - 1) % #Boss.Bosses) + 1]
	local animal = Config.Animals.ById[def.AnimalId]
	if not animal then
		return
	end
	local ball = Instance.new("Part")
	ball.Name = "Boss"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * Boss.Size
	ball.Color = animal.Color or Color3.new(1, 1, 1)
	ball.Anchored = true
	ball.CanCollide = false
	ball:SetAttribute("AnimalId", def.AnimalId)
	ball.CFrame = CFrame.new(center() + Vector3.new(0, Boss.Size / 2, -10))
	ball.Parent = arena
	CollectionService:AddTag(ball, "Critter") -- (the client draws the giant Blender model on it)
	MapBuilder.Label(ball, `👑 {def.DisplayName}`, Boss.Size / 2 + 4, Color3.fromRGB(255, 110, 110))

	local f: Fight = {
		Until = untilTime,
		Name = def.DisplayName,
		AnimalId = def.AnimalId,
		Phase = "Pin",
		Ball = ball,
		Handles = {},
		Holding = {},
		Pin = 0,
		Target = Vector3.new(Boss.ArenaCenter.X, 0, Boss.ArenaCenter.Z),
		NextStomp = os.clock() + Boss.StompEvery,
		NextRoar = os.clock() + Boss.RoarEvery,
		Work = {},
		Boxers = {},
		Anger = 0,
		Spots = {},
		Start = 0,
		Strips = {},
		Taped = {},
		Need = 1,
		LastStrip = {},
		LastPet = {},
		LastAngry = {},
		Raged = {},
	}
	for _ = 1, Boss.Handles do
		local handle = Instance.new("Part")
		handle.Name = "BossHandle"
		handle.Shape = Enum.PartType.Ball
		handle.Size = Vector3.new(2.4, 2.4, 2.4)
		handle.Color = Color3.fromRGB(255, 230, 90)
		handle.Material = Enum.Material.Neon
		handle.Anchored = true
		handle.CanCollide = false
		handle.Parent = arena
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Hold on!"
		prompt.ObjectText = "Rope"
		prompt.HoldDuration = 600 -- (never "finishes": you hold on for as long as you keep the key down)
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = handle
		prompt.PromptButtonHoldBegan:Connect(function(player: Player)
			if fight == f and f.Phase == "Pin" and (stunnedUntil[player] or 0) < os.clock() then
				f.Holding[player] = handle
			end
		end)
		prompt.PromptButtonHoldEnded:Connect(function(player: Player)
			if f.Holding[player] == handle then
				f.Holding[player] = nil
			end
		end)
		table.insert(f.Handles, handle)
	end
	fight = f
	setPad(true)
	Workspace:SetAttribute("BossName", def.DisplayName)
	Workspace:SetAttribute("BossPhase", "Pin")
	Workspace:SetAttribute("BossEndsAt", untilTime)
	giveCrown(nil) -- last hour's crown comes off
	Remotes.Notify:FireAllClients("BossStart", { Boss = def.DisplayName })
end

function BossService.Init(map: MapBuilder.Map)
	buildArena(map)
	BoxingService.ExternalInput = onInput
	-- Crowns follow their wearer through respawns
	local function crown(player: Player)
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		local old = head and head:FindFirstChild("BossCrown")
		if not head then
			return
		end
		if player:GetAttribute("BossCrown") == true and not old then
			local gui = Instance.new("BillboardGui")
			gui.Name = "BossCrown"
			gui.Size = UDim2.fromOffset(120, 34)
			gui.StudsOffset = Vector3.new(0, 4.2, 0)
			gui.MaxDistance = 120
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.LuckiestGuy
			label.TextScaled = true
			label.TextColor3 = Color3.fromRGB(255, 205, 50)
			label.TextStrokeTransparency = 0
			label.Text = "👑 BOSS HUNTER"
			label.Parent = gui
			gui.Parent = head
		elseif player:GetAttribute("BossCrown") ~= true and old then
			old:Destroy()
		end
	end
	local function watch(player: Player)
		player:GetAttributeChangedSignal("BossCrown"):Connect(function()
			crown(player)
		end)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 10)
			crown(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		stunnedUntil[player] = nil
		if crownHolder == player then
			crownHolder = nil
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		-- Fell off the island into the sea: back on top
		for _, player in Players:GetPlayers() do
			local root = rootOf(player)
			if root then
				local offset = root.Position - Boss.ArenaCenter
				if math.abs(offset.X) < 120 and math.abs(offset.Z) < 120 and root.Position.Y < -6 then
					teleport(player, center() + Vector3.new(0, 0, Boss.ArenaSize / 2 - 16))
				end
			end
		end
		local f = fight
		if not f then
			return
		end
		Workspace:SetAttribute("BossEndsAt", f.Until)
		if os.time() >= f.Until then
			notifyHere(
				"Message",
				{ Speaker = "Postmaster Gruff", Text = `Time's up. RETURN TO SENDER! The {f.Name} got away.` }
			)
			finish(false)
		elseif f.Phase == "Pin" then
			updatePin(f, dt)
		else
			updateBox(f, dt)
		end
	end)
end

return BossService
