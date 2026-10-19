--!strict
-- The boxing loop:
--   Pick an animal at the Pen -> CATCH it in the arena -> BOX it -> it goes into your bag as a Parcel
--   -> carry it to the Mail Chute and mail it yourself (MailService.luau), where you get paid and rated.
--
-- BOX: the animal and an open box pop up on your screen. Its ANGER keeps rising. Rub its sweet spots to calm it
-- (don't touch its angry spots!) while you drag tape across every seam of the box. Each strip annoys it more.
-- If anger hits 100: VINE BOOM, you're launched into the air as a ragdoll, and it escapes back into the arena.
--
-- Multiplayer (Phase 5):
--   * Giant animals need a CREW. Other players press E on the animal to join. Everyone must be close when it's
--     grabbed, and on the BOX screen the owner tapes while the crew pets.
--   * CHAOS MODE (chosen in the Pen menu) pays more, but other players can spook your animal (E on it) and
--     shove you (F).
--
-- The server runs everything and checks every message. The client only draws the screen and reports what you
-- rubbed and taped. Calming is capped per second and tape strips can't come faster than a human could drag them.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BoxMath = require(ReplicatedStorage.Shared.BoxMath)
local BoxingConfig = require(ReplicatedStorage.Shared.Config.Boxing)
local CatchAI = require(script.Parent.CatchAI)
local Config = require(ReplicatedStorage.Shared.Config)
local Analytics = require(script.Parent.Analytics)
local Badges = require(script.Parent.Badges)
local ChallengeService = require(script.Parent.ChallengeService)
local DataService = require(script.Parent.DataService)
local DiveService = require(script.Parent.DiveService)
local Economy = require(script.Parent.Economy)
local MailService = require(script.Parent.MailService)
local ProgressionService = require(script.Parent.ProgressionService)
local MapBuilder = require(script.Parent.MapBuilder)
local ModelFit = require(ReplicatedStorage.Shared.ModelFit)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Remotes = require(script.Parent.Remotes)
local StampsConfig = require(ReplicatedStorage.Shared.Config.Stamps)
local StreakService = require(script.Parent.StreakService)
local Travel = require(script.Parent.Travel)
local Types = require(script.Parent.Types)

type Session = Types.Session
type TwistSet = BoxingConfig.TwistSet

local Boxing = Config.Boxing
local Tuning = Boxing.TwistTuning
local Social = Config.Social
local Gruff = Config.Gruff

local JUMP_HEIGHT = 7.2

local BoxingService = {}

-- Set by WildService: an escaped animal goes back into the wild (animal id, zone, where, Shiny/Golden)
BoxingService.OnEscape = nil :: ((string, string, Vector3, string?) -> ())?

local sessions: { [Player]: Session } = {} -- owner -> job
local crewOf: { [Player]: Session } = {} -- crew member -> the job they're helping with
local stunnedUntil: { [Player]: number } = {}
local lastShove: { [Player]: number } = {}

-- The Invincibility Shield (Robux, MonetizationService): no vine boom, and Chaos attacks skip you
local function invincible(player: Player): boolean
	local untilTime = player:GetAttribute("InvincibleUntil")
	return typeof(untilTime) == "number" and untilTime > os.time()
end
local map: MapBuilder.Map
local boxesFolder: Folder

---------------------------------------------------------------------------------------------------
-- Helpers

local function pick(list: { string }): string
	return list[math.random(1, #list)]
end

local function notify(player: Player, kind: string, data: { [string]: any })
	Remotes.Notify:FireClient(player, kind, data)
end

local function say(player: Player, speaker: string, text: string)
	notify(player, "Message", { Speaker = speaker, Text = text })
end

local function gruffSays(player: Player, text: string)
	say(player, "Postmaster Gruff", text)
end

local function twistsFor(animalId: string): TwistSet
	return Boxing.Twists[animalId] or {}
end

local function stampOf(s: Session): StampsConfig.Stamp?
	return if s.StampId then Config.Stamps.ById[s.StampId] else nil
end

local function getCharacterParts(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?, character:FindFirstChildOfClass("Humanoid")
end

-- The job a player is part of, as the owner or as crew
local function jobOf(player: Player): Session?
	return sessions[player] or crewOf[player]
end

-- Owner first, then the crew
local function membersOf(s: Session): { Player }
	local members = { s.Player }
	for _, helper in s.Crew do
		table.insert(members, helper)
	end
	return members
end

local function notifyAll(s: Session, kind: string, data: { [string]: any })
	for _, member in membersOf(s) do
		notify(member, kind, data)
	end
end

local function sayAll(s: Session, speaker: string, text: string)
	notifyAll(s, "Message", { Speaker = speaker, Text = text })
end

-- You can't walk while boxing, or while stunned (or ragdolled).
local function refreshMovement(player: Player)
	local _, humanoid = getCharacterParts(player)
	if not humanoid then
		return
	end
	local s = jobOf(player)
	-- (boxing the hourly boss counts too: BossService sets your Stage to "Box" without a job of its own)
	local busy = (s ~= nil and s.Stage ~= "Catch") or (s == nil and player:GetAttribute("Stage") == "Box")
	local stunned = os.clock() < (stunnedUntil[player] or 0)
	local speed = Economy.WalkSpeed(player)
	player:SetAttribute("WalkSpeed", speed) -- the client's Movement module builds on this (sneak, mud, ice)
	player:SetAttribute("Frozen", busy or stunned)
	humanoid.UseJumpPower = false
	humanoid.WalkSpeed = if busy or stunned then 0 else speed
	humanoid.JumpHeight = if busy or stunned then 0 else JUMP_HEIGHT
end

local function stun(player: Player, seconds: number)
	stunnedUntil[player] = os.clock() + seconds
	refreshMovement(player)
	task.delay(seconds + 0.05, refreshMovement, player)
end

local function setStage(s: Session, stage: string, tip: string)
	s.Stage = stage
	for _, member in membersOf(s) do
		member:SetAttribute("Stage", stage)
		member:SetAttribute("Tip", tip)
		member:SetAttribute("Chaos", s.Chaos)
		member:SetAttribute("JobArena", s.ArenaId) -- lets you stay in a zone you're working in
		refreshMovement(member)
	end
end

---------------------------------------------------------------------------------------------------
-- The box on the ground, so everyone nearby can watch you wrestle with it

local function buildBox(s: Session): Model
	local root = getCharacterParts(s.Player)
	local animal = Config.Animals.ById[s.AnimalId]
	local arena = map.Arenas[s.ArenaId]
	local base = if root then root.CFrame else CFrame.new(arena.Center)
	local look = base.LookVector
	local spot = base.Position + Vector3.new(look.X, 0, look.Z).Unit * 4
	local boxY = arena.FloorY + 1.5 -- sits on the arena floor (the Rooftop is 30 studs up)
	local boxCFrame =
		CFrame.lookAt(Vector3.new(spot.X, boxY, spot.Z), Vector3.new(base.Position.X, boxY, base.Position.Z))

	local model = Instance.new("Model")
	model.Name = `Box_{s.Player.UserId}`

	local function piece(name: string, size: Vector3, cframe: CFrame, color: Color3): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.Size = size
		p.CFrame = cframe
		p.Color = color
		p.Parent = model
		return p
	end

	local boxColor = Config.Boxes.ById[s.BoxId].Color
	local scale = if animal.Carriers > 1 then 2 else 1 -- giants get a giant box
	local box = piece("Box", Vector3.new(3, 3, 3) * scale, boxCFrame * CFrame.new(0, 1.5 * (scale - 1), 0), boxColor)
	local lid = piece(
		"Lid",
		Vector3.new(3.1 * scale, 0.25, 3.1 * scale),
		box.CFrame * CFrame.new(0, 1.6 * scale, 0),
		boxColor:Lerp(Color3.new(0, 0, 0), 0.15)
	)
	-- Your tape color (Config/Styles.luau: Gold with VIP, any color with the Style Pack)
	local profile = DataService.Get(s.Player)
	local tapeColor =
		Config.Styles.TapeFor(if profile then profile.TapeStyle else "", function(passKey: string): boolean
			return s.Player:GetAttribute(`Pass_{passKey}`) == true
		end).Color
	local strip = piece("Tape", Vector3.new(0.05, 0.3, 0.7), box.CFrame * CFrame.new(0, 1.75 * scale, 0), tapeColor)
	strip.Transparency = 1 -- appears as you tape
	local critter = piece(
		"Animal",
		Vector3.new(1.6, 1.6, 1.6) * scale,
		box.CFrame * CFrame.new(0, 2.6 * scale, 0),
		animal.Color or Color3.new(1, 1, 1)
	)
	critter.Shape = Enum.PartType.Ball
	MapBuilder.Label(box, `{s.Player.DisplayName}'s {animal.DisplayName}`, 4 * scale)
	box:SetAttribute("Scale", scale)

	-- Your Blender art, if you've put it in Studio: ReplicatedStorage > BoxModels > "<box id>" (e.g. "Cardboard")
	-- and ReplicatedStorage > AnimalModels > "<animal id>". The plain parts stay (invisible) to keep positions.
	local function art(folderName: string, id: string, name: string, floor: CFrame, width: number): Model?
		local folder = ReplicatedStorage:FindFirstChild(folderName)
		local template = folder and folder:FindFirstChild(id)
		if not (template and template:IsA("Model")) then
			return nil
		end
		local clone = template:Clone()
		clone.Name = name
		ModelFit.Paint(clone, id)
		for _, descendant in clone:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
			end
		end
		ModelFit.Fit(clone, floor, width)
		clone.Parent = model
		return clone
	end
	if art("BoxModels", s.BoxId, "BoxArt", box.CFrame * CFrame.new(0, -1.5 * scale, 0), 3 * scale) then
		box.Transparency = 1
		lid.Transparency = 1 -- the model has its own flaps
	end
	-- The animal sits down inside the box with its top half poking out
	if art("AnimalModels", s.AnimalId, "AnimalArt", box.CFrame * CFrame.new(0, 0.6 * scale, 0), 1.9 * scale) then
		critter.Transparency = 1
	end

	model.PrimaryPart = box
	-- Each client wiggles the box art by anger and squishes the animal when it's petted (Animate.luau)
	model:SetAttribute("Anger", 0)
	CollectionService:AddTag(model, "JobBox")
	model.Parent = boxesFolder
	return model
end

-- The lid lifts as the animal gets angrier, and the tape strip grows with each seam taped.
local function updateBoxVisual(s: Session)
	local model = s.BoxModel
	local state = s.Box
	if not model or not state then
		return
	end
	local box = model:FindFirstChild("Box") :: Part?
	local lid = model:FindFirstChild("Lid") :: Part?
	local strip = model:FindFirstChild("Tape") :: Part?
	if not (box and lid and strip) then
		return
	end
	model:SetAttribute("Anger", state.Anger)
	local scale = (box:GetAttribute("Scale") :: number?) or 1
	local shake = if state.Anger > 70 then (math.random() - 0.5) * 0.15 * scale else 0
	local angle = math.rad(math.clamp(state.Anger, 0, 100) * 0.6)
	lid.CFrame = box.CFrame
		* CFrame.new(shake, 1.6 * scale, 1.55 * scale)
		* CFrame.Angles(angle, 0, 0)
		* CFrame.new(0, 0, -1.55 * scale)
	local taped = 0
	for _, done in state.Taped do
		taped += if done then 1 else 0
	end
	local length = 3.1 * scale * taped / state.SeamCount
	strip.Transparency = if length > 0.05 then 0 else 1
	strip.Size = Vector3.new(math.max(0.05, length), 0.3, 0.7)
	strip.CFrame = lid.CFrame * CFrame.new(0, 0.15, 0)
end

local function destroyBox(s: Session)
	if s.BoxModel then
		s.BoxModel:Destroy()
		s.BoxModel = nil
	end
end

---------------------------------------------------------------------------------------------------
-- Stage 1: CATCH (the chase itself is in CatchAI.luau)

local function catchTip(s: Session): string
	local animal = Config.Animals.ById[s.AnimalId]
	local arenaName = Config.Arenas.ById[s.ArenaId].DisplayName
	if animal.Carriers > 1 then
		local have = 1 + #s.Crew
		if have < animal.Carriers then
			return `CO-OP: your {animal.DisplayName} needs {animal.Carriers} players ({have} so far). Others press E on it to join!`
		end
		return `Crew complete! Everyone get close to the {animal.DisplayName} in the {arenaName}, then hold E to grab it.`
	end
	if twistsFor(s.AnimalId).Sleep then
		return `Your {animal.DisplayName} is asleep in the {arenaName}. Hold C to sneak up, then hold E to grab it.`
	end
	return `Catch your {animal.DisplayName} in the {arenaName}! Corner it, then hold E to grab it.`
end

local function startCatch(s: Session, at: Vector3?)
	destroyBox(s)
	s.Box = nil
	for _, member in membersOf(s) do
		member:SetAttribute("Anger", nil)
	end
	CatchAI.Spawn(s, at)
	setStage(s, "Catch", catchTip(s))
end

---------------------------------------------------------------------------------------------------
-- Stage 2: BOX

-- Who does what on the BOX screen. Solo: "Both". Crew: the owner tapes, and helpers take turns being petters
-- and tapers (Pet, Tape, Pet...), so a 2-player crew is one taper + one petter.
local function assignRoles(s: Session)
	s.Roles = {}
	if #s.Crew == 0 then
		s.Roles[s.Player] = "Both"
		return
	end
	s.Roles[s.Player] = "Tape"
	for index, helper in s.Crew do
		s.Roles[helper] = if index % 2 == 1 then "Pet" else "Tape"
	end
end

local function canDo(s: Session, player: Player, action: string): boolean
	local role = s.Roles[player]
	return role == "Both" or role == action
end

-- Picks spots on the animal picture that don't overlap each other
-- Finds a clear place for a new spot (not on top of the others) on the visible part of the animal
local function placeSpot(
	others: { BoxMath.Spot },
	kind: string,
	radius: number,
	drift: number,
	speed: number
): BoxMath.Spot
	local margin = radius + drift + 0.02
	local x, y = 0.5, 0.3
	for _ = 1, 30 do
		-- Only on the part of the animal sticking out of the box (see BoxMath.VISIBLE_HEIGHT)
		x = margin + math.random() * (1 - 2 * margin)
		y = margin + math.random() * math.max(0, BoxMath.VISIBLE_HEIGHT - 2 * margin)
		local clear = true
		for _, other in others do
			if
				(Vector2.new(x, y) - Vector2.new(other.X, other.Y)).Magnitude
				< radius + other.Radius + 2 * drift + 0.04
			then
				clear = false
				break
			end
		end
		if clear then
			break
		end
	end
	return {
		Kind = kind,
		X = x,
		Y = y,
		Radius = radius,
		Drift = drift,
		Speed = speed,
		Phase = math.random() * math.pi * 2,
	}
end

local function makeSpots(s: Session): { BoxMath.Spot }
	local cfg = Boxing.Box
	local hard = cfg.Hard
	local d = s.Difficulty
	local tier = Config.Animals.ById[s.AnimalId].Tier
	local twists = twistsFor(s.AnimalId)
	local drift = cfg.SpotMovePerTier * (tier - 1) + hard.ExtraDrift * d
	local speed = cfg.SpotMoveSpeed * (if twists.Wiggle then Tuning.Wiggle.SpotSpeedMult else 1)
	local sweetRadius = math.max(cfg.MinSweetRadius, cfg.SweetRadius + cfg.SweetRadiusPerTier * (tier - 1))
		* (1 + (hard.SweetRadiusMult - 1) * d)
	local angryRadius = cfg.AngryRadius * (if twists.Poke then Tuning.Poke.AngryRadiusMult else 1)

	local spots: { BoxMath.Spot } = {}
	for _ = 1, cfg.SweetSpots do
		table.insert(spots, placeSpot(spots, "Sweet", sweetRadius, drift, speed))
	end
	for _ = 1, (cfg.AngrySpotsByTier[tier] or 3) + math.round(hard.ExtraAngrySpots * d) do
		table.insert(spots, placeSpot(spots, "Angry", angryRadius, drift, speed))
	end
	return spots
end

local function syncBox(s: Session)
	local state = s.Box
	if state then
		for _, member in membersOf(s) do
			member:SetAttribute("Anger", math.floor(state.Anger))
		end
	end
end

local function sendRoles(s: Session)
	for _, member in membersOf(s) do
		notify(member, "Role", { Role = s.Roles[member] or "Both" })
	end
end

local function startBox(s: Session)
	local cfg = Boxing.Box
	local animal = Config.Animals.ById[s.AnimalId]
	local box = Config.Boxes.ById[s.BoxId]
	local stamp = stampOf(s)
	local seamCount = cfg.SeamsByTier[animal.Tier] or 5

	local taped = {}
	for index = 1, seamCount do
		taped[index] = false
	end
	local angerMult = box.AngerMult * (if stamp and stamp.AngerMult then stamp.AngerMult else 1) -- FRAGILE is touchier
	if animal.Carriers > 1 then
		angerMult *= Social.Coop.AngerMult -- giants: more hands, angrier animal
	end
	local hard = cfg.Hard
	angerMult *= 1 + (hard.AngerRateMult - 1) * s.Difficulty -- an animal above your level is a handful
	-- A brand-new player's very first box (Gruff's walkthrough) is a gentle one: calm to start, slow to anger
	local owner = DataService.Get(s.Player)
	local firstBox = owner ~= nil and owner.Mailed == 0 and not owner.TutorialDone and #owner.Parcels == 0
	if firstBox then
		angerMult *= Boxing.FirstBoxAngerMult
	end
	s.Box = {
		Start = Workspace:GetServerTimeNow(),
		Anger = if firstBox
			then 0
			else math.max( -- PRIORITY starts high; the Calm Hands Rebirth Upgrade takes some off
				0,
				(if stamp and stamp.StartAnger then stamp.StartAnger else box.StartAnger)
					- Economy.UpgradeBonus(s.Player, "CalmHands")
			),
		Spots = makeSpots(s),
		SeamCount = seamCount,
		Taped = taped,
		LastSeam = os.clock(),
		LastPet = {},
		LastAngryTouch = 0,
		NextPound = os.clock() + Tuning.Pound.Interval,
		TapeAngerMult = s.TapeAngerMult,
		AngerMult = angerMult,
		HeartReady = {},
		HeartCooldown = cfg.HeartCooldown + hard.HeartCooldownExtra * s.Difficulty,
	}
	assignRoles(s)
	setStage(
		s,
		"Box",
		"Rub a ♥ to reset its anger to 0 (then it recharges) while you tape every seam! Avoid the ✖ spots."
	)
	local state = s.Box :: Types.BoxState
	for _, member in membersOf(s) do
		Analytics.Onboarding(member, "Caught")
		notify(member, "BoxStart", {
			AnimalId = s.AnimalId,
			Start = state.Start,
			Spots = state.Spots,
			SeamCount = seamCount,
			BoxId = s.BoxId,
			Role = s.Roles[member] or "Both",
			Variant = s.Variant,
			Difficulty = s.Difficulty,
			Gap = math.max(
				0,
				(Config.Wild.LevelOf[s.AnimalId] or 1) - (DataService.Get(s.Player) or { Level = 1 } :: any).Level
			),
		})
	end
	syncBox(s)
	updateBoxVisual(s)
end

-- Analytics: what happened on the BOX screen, logged once when it ends. outcome: Taped, Launched or Cancelled.
-- "_Idle" on the outcome = nobody rubbed or taped anything (didn't understand the screen, or walked off).
local function logBox(s: Session, outcome: string)
	local state = s.Box
	if not state then
		return -- (still in the catch stage: no BOX screen yet)
	end
	local player = s.Player
	local seconds = math.floor(Workspace:GetServerTimeNow() - state.Start)
	local taped = 0
	for _, done in state.Taped do
		if done then
			taped += 1
		end
	end
	local kind = Analytics.RarityOf(s.AnimalId) .. (if s.Difficulty > 0 then "_Hard" else "")
	local device = Analytics.DeviceOf(player)
	local result = outcome .. (if s.FirstTouch == nil then "_Idle" else "")
	Analytics.Custom(player, "BoxEnd", seconds, result, kind, device)
	-- One "BoxStat" per number (Field01 says which), so they all share one event name
	local both = `{kind}|{device}`
	Analytics.Custom(player, "BoxStat", taped, `SeamsOf{state.SeamCount}`, result, both, false)
	Analytics.Custom(player, "BoxStat", s.Hearts, "Hearts", result, both, false)
	Analytics.Custom(player, "BoxStat", s.AngryTouches, "RedSpots", result, both, false)
	Analytics.Custom(player, "BoxStat", math.floor(s.MaxAnger), "MaxAnger", result, both, false)
	if s.Peels > 0 then
		Analytics.Custom(player, "BoxStat", s.Peels, "Peels", result, both, false)
	end
	local firstTouch = s.FirstTouch
	if firstTouch then
		-- Seconds before the first rub or tape (long = the screen is confusing)
		Analytics.Custom(
			player,
			"BoxStat",
			math.floor(firstTouch - state.Start),
			"FirstTouchSeconds",
			result,
			both,
			false
		)
	end
	Analytics.Custom(
		player,
		"BoxAnimal",
		seconds,
		s.AnimalId,
		result,
		Analytics.LevelBand((DataService.Get(player) or { Level = 1 } :: any).Level),
		false
	)
end

local function endSession(s: Session)
	CatchAI.Remove(s)
	sessions[s.Player] = nil
	for _, member in membersOf(s) do
		DiveService.Engage(member, 3) -- (a few seconds' peace after a job before anything attacks you)
		crewOf[member] = nil
		member:SetAttribute("Stage", "")
		member:SetAttribute("Tip", "")
		member:SetAttribute("Anger", nil)
		member:SetAttribute("Chaos", false)
		member:SetAttribute("JobArena", nil)
		refreshMovement(member)
	end
end

local function knockOffGruffsHat()
	local hat = map.GruffHat
	if not hat.Anchored then
		return -- already flying
	end
	local home = hat.CFrame
	hat.Anchored = false
	hat.AssemblyLinearVelocity = Vector3.new(math.random(-10, 10), 45, -25)
	hat.AssemblyAngularVelocity = Vector3.new(math.random(-10, 10), math.random(-10, 10), math.random(-10, 10))
	task.delay(6, function()
		hat.Anchored = true
		hat.CFrame = home
	end)
end

-- "RETURN TO SENDER": a tiger (or Gruff!) launching you is the big clip moment.
local function breakout(s: Session, position: Vector3)
	knockOffGruffsHat()
	for _, player in Players:GetPlayers() do
		local root = getCharacterParts(player)
		if root and (root.Position - position).Magnitude <= 80 then
			notify(player, "Breakout", { Animal = Config.Animals.ById[s.AnimalId].DisplayName })
		end
	end
	for _, member in membersOf(s) do
		gruffSays(member, pick(Gruff.Breakout))
		Badges.Award(member, "ReturnToSender")
	end
end

-- The animal gets out. Normal animals go back into the wild right where they escaped (the job ends; grab or
-- dive at it again). Giants stay your job, running loose, so the crew can have another go.
local function escape(s: Session, how: string)
	local root = getCharacterParts(s.Player)
	local model = s.BoxModel
	local position = if model
		then model:GetPivot().Position
		elseif root then root.Position
		else map.Arenas[s.ArenaId].Center
	s.Escapes += 1
	notifyAll(s, "Break", {})
	logBox(s, if how == "Launch" then "Launched" else "Escaped")
	Analytics.Custom(
		s.Player,
		if how == "Launch" then "Launched" else "Escaped",
		1,
		s.AnimalId,
		Analytics.RarityOf(s.AnimalId) .. (if s.Difficulty > 0 then "_Hard" else ""),
		Analytics.Segment(s.Player)
	)
	Analytics.Did(s.Player, "VineBoomed")
	Analytics.Milestone(s.Player, "FirstEscape")
	if how == "Launch" and twistsFor(s.AnimalId).Breakout then
		breakout(s, position)
	else
		sayAll(s, "Postmaster Gruff", pick(Gruff.Escape))
	end
	if Config.Animals.ById[s.AnimalId].Carriers > 1 then
		startCatch(s, position)
		return
	end
	local members = membersOf(s)
	destroyBox(s)
	endSession(s)
	for _, member in members do
		notify(member, "BoxDone", {})
	end
	local hook = BoxingService.OnEscape
	if hook then
		hook(s.AnimalId, s.ArenaId, position, s.Variant)
	end
end

local function playVineBoom(at: BasePart)
	Sfx.Play("VineBoom", at) -- silent until you set its id in src/shared/Config/Sounds.luau
end

-- Anger hit 100: VINE BOOM, launch everyone in the job as ragdolls, and the animal escapes.
local function launch(s: Session)
	local cfg = Boxing.Box
	for _, member in membersOf(s) do
		local root = getCharacterParts(member)
		local angle = math.random() * math.pi * 2
		local velocity =
			Vector3.new(math.cos(angle) * cfg.LaunchSideways, cfg.LaunchSpeed, math.sin(angle) * cfg.LaunchSideways)
		if root then
			playVineBoom(root)
		end
		notify(member, "Launch", { Velocity = velocity, Seconds = cfg.RagdollSeconds })
		stun(member, cfg.RagdollSeconds)
		StreakService.Break(member, "getting launched")
	end
	escape(s, "Launch")
end

local function isUnderPar(s: Session): boolean
	local animal = Config.Animals.ById[s.AnimalId]
	local par = Boxing.ParSecondsBase + Boxing.ParSecondsPerTier * (animal.Tier - 1)
	return os.clock() - s.StartTime <= par
end

local function starsFor(s: Session): number
	local stars = 5
	stars -= if s.MaxAnger >= Boxing.Box.DangerAnger then 1 else 0
	stars -= if s.AngryTouches >= 3 then 1 else 0
	stars -= if isUnderPar(s) then 0 else 1
	stars -= s.Escapes
	return math.clamp(stars, 1, 5)
end

-- Taped shut! Everyone in the job gets a Parcel in their bag. They get paid when they mail it at the chute
-- (MailService), so the pay is worked out now and stored on the parcel:
--   coins = value x stamps x escapes x stamp x chaos x (each player's own rebirth bonus) + egg bonus
local function finishJob(s: Session)
	local animal = Config.Animals.ById[s.AnimalId]
	local stars = starsFor(s)
	local underPar = isUnderPar(s)
	local stamp = stampOf(s)
	local seconds = os.clock() - s.StartTime

	local mult = Boxing.StarPayoutMult[stars] * Boxing.EscapePayoutMult ^ s.Escapes
	local perfect = Workspace:GetAttribute("PerfectMult") -- Speed Tape event: 5-stamp jobs pay more
	if stars == 5 and typeof(perfect) == "number" then
		mult *= perfect
	end
	if stamp then
		mult *= stamp.PayoutMult
		if stamp.UnderParMult and underPar then
			mult *= stamp.UnderParMult
		end
	end
	if s.Chaos then
		mult *= Social.Chaos.PayoutMult
	end
	local variant = if s.Variant then Config.Variants.ById[s.Variant] else nil
	if variant then
		mult *= variant.PayMult
	end

	-- The taped box shrinks into the owner's arms
	local model = s.BoxModel
	s.BoxModel = nil
	if model then
		model:SetAttribute("Done", true) -- clients stop wiggling it
		local critter = model:FindFirstChild("Animal") :: Part?
		if critter then
			critter.Transparency = 1 -- it's in the box now
		end
		local animalArt = model:FindFirstChild("AnimalArt")
		if animalArt then
			animalArt:Destroy()
		end
		local root = getCharacterParts(s.Player)
		task.spawn(function()
			local from = model:GetPivot()
			local to = if root then root.CFrame * CFrame.new(0, 0, -1.4) else from
			for i = 1, 15 do
				local t = i / 15
				model:PivotTo(from:Lerp(to, t))
				model:ScaleTo(math.max(0.1, 1 - t * 0.7))
				task.wait()
			end
			model:Destroy()
		end)
	end

	logBox(s, "Taped")
	local members = membersOf(s)
	endSession(s)
	local label = if stamp then stamp.DisplayName elseif s.Chaos then "CHAOS" else nil
	for _, member in members do
		-- The delivery streak (a good box in a row pays more)
		local streakMult = StreakService.OnBox(member, stars)
		local coins =
			math.max(1, math.round(animal.BaseValue * mult * streakMult * Economy.PayoutMult(member) + s.Bonus))
		Analytics.Onboarding(member, "Taped")
		local loopId = if member == s.Player then s.LoopId else Analytics.NewLoopId()
		if member ~= s.Player then
			Analytics.Loop(member, "CoreLoop", loopId, 1, "Grab") -- (a crew helper's own run)
		end
		Analytics.Loop(member, "CoreLoop", loopId, 2, "Boxed")
		Analytics.Did(member, "Boxed")
		Analytics.Milestone(member, "FirstBox")
		if stars == 5 then
			Analytics.Milestone(member, "FirstFiveStars")
		end
		Analytics.Custom(member, "BoxStat", stars, "Stars", "Taped", Analytics.Segment(member), false)
		MailService.AddParcel(member, {
			AnimalId = s.AnimalId,
			Stars = stars,
			Coins = coins,
			Seconds = seconds,
			Escapes = s.Escapes,
			UnderPar = underPar,
			Stamp = label,
			Variant = s.Variant,
			Loop = loopId,
		})
		ChallengeService.Track(member, "Box", { Stars = stars, Seconds = seconds, Chaos = s.Chaos })
		notify(member, "BoxDone", {})
		-- Gruff's walkthrough: the first parcel zips you straight to the mail chute (no walking back)
		local profile = DataService.Get(member)
		if profile and profile.Mailed == 0 and not profile.TutorialDone then
			task.delay(1.5, function()
				if member.Parent then
					Travel.ToGruff(member)
				end
			end)
		end
		notify(member, "Parcel", {
			Animal = animal.DisplayName,
			Stars = stars,
			Coins = coins,
			Stamp = label,
			Variant = s.Variant,
			Streak = streakMult,
			Count = MailService.Count(member),
			Capacity = MailService.Capacity(member),
		})
	end
	-- Everyone in the server hears about a Shiny or Golden
	if variant then
		Remotes.Notify:FireAllClients("VariantBoxed", {
			Player = s.Player.DisplayName,
			Animal = animal.DisplayName,
			Variant = variant.Id,
		})
	end
end

local function cancel(s: Session)
	logBox(s, "Cancelled")
	destroyBox(s)
	local members = membersOf(s)
	endSession(s)
	for _, member in members do
		notify(member, "BoxDone", {})
		StreakService.Break(member, "quitting a job")
	end
end

---------------------------------------------------------------------------------------------------
-- Crews

local function joinCrew(s: Session, helper: Player)
	table.insert(s.Crew, helper)
	crewOf[helper] = s
	CatchAI.RefreshLabel(s)
	setStage(s, "Catch", catchTip(s))
	local animal = Config.Animals.ById[s.AnimalId]
	sayAll(s, "Crew", `{helper.DisplayName} joined the crew for {s.Player.DisplayName}'s {animal.DisplayName}!`)
end

-- A helper left (or died). During BOX the remaining players' roles are reshuffled so nothing is left undone.
local function leaveCrew(s: Session, helper: Player)
	local index = table.find(s.Crew, helper)
	if not index then
		return
	end
	table.remove(s.Crew, index)
	crewOf[helper] = nil
	s.Roles[helper] = nil
	helper:SetAttribute("Stage", "")
	helper:SetAttribute("Tip", "")
	helper:SetAttribute("Anger", nil)
	helper:SetAttribute("Chaos", false)
	helper:SetAttribute("JobArena", nil)
	notify(helper, "BoxDone", {})
	refreshMovement(helper)
	CatchAI.RefreshLabel(s)
	if s.Stage == "Box" then
		assignRoles(s)
		sendRoles(s)
	else
		setStage(s, "Catch", catchTip(s))
	end
	sayAll(s, "Crew", `{helper.DisplayName} left the crew.`)
end

-- Someone pressed E on a job's animal
local function onPrompt(s: Session, who: Player)
	local animal = Config.Animals.ById[s.AnimalId]
	local isMember = who == s.Player or crewOf[who] == s

	if isMember then
		if animal.Carriers > 1 then
			-- Co-op: the whole crew has to be here, and close
			local members = membersOf(s)
			if #members < animal.Carriers then
				say(who, "Crew", `You need {animal.Carriers} players for this one ({#members} so far).`)
				return
			end
			local critter = s.Critter
			for _, member in members do
				local root = getCharacterParts(member)
				if
					not (critter and root and (root.Position - critter.Position).Magnitude <= Social.Coop.GrabRadius)
				then
					say(who, "Crew", `Everyone has to be close! {member.DisplayName} is too far away.`)
					return
				end
			end
		end
		if CatchAI.TryGrab(s, who) then
			CatchAI.Remove(s)
			s.BoxModel = buildBox(s)
			startBox(s)
		end
		return
	end

	-- Not in this job: join a giant's crew if there's room...
	if animal.Carriers > 1 and not jobOf(who) and 1 + #s.Crew < animal.Carriers then
		if not MailService.HasRoom(who) then
			gruffSays(who, Gruff.BagFull)
			return
		end
		joinCrew(s, who)
		return
	end
	-- ...or spook it, if the owner turned on Chaos Mode
	if s.Chaos then
		local now = os.clock()
		if now - (s.SpookedBy[who] or 0) >= Social.Chaos.SpookCooldown then
			s.SpookedBy[who] = now
			CatchAI.Spook(s, who)
			sayAll(s, "CHAOS", `{who.DisplayName} spooked your {animal.DisplayName}!`)
		end
		return
	end
	gruffSays(who, Gruff.NotYours)
end

---------------------------------------------------------------------------------------------------
-- Messages from the BOX screen

-- Rubbing a sweet spot. Calming is limited by the time since that player's last message, so spamming
-- doesn't help, but two petters do calm twice as fast.
local function onPet(s: Session, player: Player, spotIndex: unknown)
	local state = s.Box
	if not state or typeof(spotIndex) ~= "number" or not canDo(s, player, "Pet") then
		return
	end
	local spot = state.Spots[spotIndex]
	if not spot or spot.Kind ~= "Sweet" then
		return
	end
	local now = os.clock()
	if now < (state.HeartReady[spotIndex] or 0) then
		return -- still recharging
	end
	-- Calm! Anger back to 0, and the heart hops somewhere new and recharges
	s.Hearts += 1
	s.FirstTouch = s.FirstTouch or Workspace:GetServerTimeNow()
	Analytics.Onboarding(player, "FirstHeart")
	state.Anger = 0
	state.HeartReady[spotIndex] = now + state.HeartCooldown
	local others = {}
	for index, other in state.Spots do
		if index ~= spotIndex then
			table.insert(others, other)
		end
	end
	local moved = placeSpot(others, "Sweet", spot.Radius, spot.Drift, spot.Speed)
	state.Spots[spotIndex] = moved
	notifyAll(s, "HeartUsed", { Index = spotIndex, Spot = moved, ReadyIn = state.HeartCooldown })
	syncBox(s)
end

-- Rubbed an angry spot. Ouch.
local function onAngryTouch(s: Session, player: Player, spotIndex: unknown)
	local state = s.Box
	if not state or typeof(spotIndex) ~= "number" or not canDo(s, player, "Pet") then
		return
	end
	local spot = state.Spots[spotIndex]
	local now = os.clock()
	if not spot or spot.Kind ~= "Angry" or now - state.LastAngryTouch < 0.5 then
		return
	end
	state.LastAngryTouch = now
	s.FirstTouch = s.FirstTouch or Workspace:GetServerTimeNow()
	state.Anger += Boxing.Box.AngrySpotAnger
	s.AngryTouches += 1
	notifyAll(s, "AngryTouch", {})
	syncBox(s)
end

-- Dragged a strip of tape along a seam.
local function onTape(s: Session, player: Player, seamIndex: unknown)
	local state = s.Box
	if not state or typeof(seamIndex) ~= "number" or not canDo(s, player, "Tape") then
		return
	end
	local now = os.clock()
	if state.Taped[seamIndex] ~= false or now - state.LastSeam < Boxing.Box.MinSeamInterval then
		return
	end
	state.LastSeam = now
	state.Taped[seamIndex] = true
	s.FirstTouch = s.FirstTouch or Workspace:GetServerTimeNow()
	Analytics.Onboarding(player, "FirstTape")
	state.Anger += Boxing.Box.TapeAnger * state.TapeAngerMult * state.AngerMult
	if invincible(s.Player) then
		-- (shielded: it can't break out, so the last seam always closes the box instead of jamming at 100)
		state.Anger = math.min(state.Anger, 99)
	end

	local allTaped = true
	for _, done in state.Taped do
		allTaped = allTaped and done
	end
	if allTaped and state.Anger < 100 then
		finishJob(s)
		return
	end
	notifyAll(s, "SeamTaped", { Seam = seamIndex })
	syncBox(s)
	updateBoxVisual(s)
end

---------------------------------------------------------------------------------------------------
-- Every frame during BOX: the animal gets angrier

local function updateBox(s: Session, now: number, dt: number)
	local state = s.Box
	if not state then
		return
	end
	local cfg = Boxing.Box
	local twists = twistsFor(s.AnimalId)
	local tier = Config.Animals.ById[s.AnimalId].Tier
	local elapsed = Workspace:GetServerTimeNow() - state.Start

	local rate = (cfg.BaseAngerRate + cfg.AngerRatePerTier * (tier - 1)) * (1 + cfg.AngerGrowth * elapsed)
	local eventMult = Workspace:GetAttribute("AngerMult") -- Speed Tape event
	state.Anger += rate * state.AngerMult * (if typeof(eventMult) == "number" then eventMult else 1) * dt

	if twists.Pound and now >= state.NextPound then
		state.NextPound = now + Tuning.Pound.Interval
		state.Anger += Tuning.Pound.Spike
		notifyAll(s, "Thump", {})
	end
	if twists.Snap and math.random() < Tuning.Snap.ChancePerSecond * dt then
		state.Anger += Tuning.Snap.Spike
		notifyAll(s, "Thump", {})
	end
	if twists.Squeeze and math.random() < Tuning.Squeeze.PeelChancePerSecond * dt then
		-- A taped seam peels back open
		local taped = {}
		for index, done in state.Taped do
			if done then
				table.insert(taped, index)
			end
		end
		if #taped > 0 then
			local seam = taped[math.random(1, #taped)]
			state.Taped[seam] = false
			s.Peels += 1
			notifyAll(s, "Peel", { Seam = seam })
		end
	end

	s.MaxAnger = math.max(s.MaxAnger, state.Anger)
	if state.Anger >= 100 then
		if invincible(s.Player) then
			state.Anger = 99 -- (shielded: it can rage, but it can't break out)
		else
			launch(s)
			return
		end
	end
	syncBox(s)
	updateBoxVisual(s)
end

---------------------------------------------------------------------------------------------------
-- Chaos Mode: shoving

local function onShove(shover: Player)
	local cfg = Social.Chaos
	local now = os.clock()
	if now - (lastShove[shover] or 0) < cfg.ShoveCooldown then
		return
	end
	local shoverRoot = getCharacterParts(shover)
	if not shoverRoot then
		return
	end
	local shoverJob = jobOf(shover)

	-- Shove the closest player who is doing a Chaos job (and isn't on your own crew)
	local target: Player? = nil
	local targetRoot: BasePart? = nil
	local best = cfg.ShoveRange
	for _, other in Players:GetPlayers() do
		local job = jobOf(other)
		local root = getCharacterParts(other)
		if other ~= shover and job and job.Chaos and job ~= shoverJob and root and not invincible(other) then
			local distance = (root.Position - shoverRoot.Position).Magnitude
			if distance <= best then
				target, targetRoot, best = other, root, distance
			end
		end
	end
	if not (target and targetRoot) then
		return
	end
	lastShove[shover] = now

	local flat = targetRoot.Position - shoverRoot.Position
	local direction = Vector3.new(flat.X, 0, flat.Z)
	direction = if direction.Magnitude > 0.01 then direction.Unit else shoverRoot.CFrame.LookVector
	notify(target, "Knockback", { Direction = direction, Strength = cfg.ShoveStrength })
	say(target, "CHAOS", `{shover.DisplayName} shoved you!`)
	Analytics.Custom(
		target,
		"Chaos",
		1,
		"Hit",
		if jobOf(target) and (jobOf(target) :: Session).Box then "Shove_MidBox" else "Shove",
		Analytics.Segment(target)
	)
	Analytics.Custom(shover, "Chaos", 1, "Attack", "Shove", Analytics.Segment(shover))

	local job = jobOf(target)
	if job and job.Box then
		job.Box.Anger += cfg.ShoveAnger -- bumping someone mid-BOX riles up their animal
		syncBox(job)
	end
end

---------------------------------------------------------------------------------------------------
-- Picking an animal

local newSession: (Player, string, string, boolean, string?, number?) -> Session?
local announceJob: (Session) -> ()

-- Studio only (the automated playtest and the Promo Kit): start a job with a chosen animal, the old Pen way.
-- In the live game, animals are grabbed in the wild (WildService).
local function onRequestAnimal(player: Player, animalId: unknown, chaos: unknown)
	if not RunService:IsStudio() then
		return
	end
	if typeof(animalId) ~= "string" then
		return
	end
	local animal = Config.Animals.ById[animalId]
	if not animal then
		return
	end

	local root = getCharacterParts(player)
	-- The Pen works from anywhere (the PEN button opens it, and picking an animal sends you to its arena),
	-- but you need to be in the world, not respawning
	if not root then
		return
	end
	if jobOf(player) then
		gruffSays(player, Gruff.AlreadyBoxing)
		return
	end
	if not MailService.HasRoom(player) then
		gruffSays(player, Gruff.BagFull)
		return
	end
	-- Each zone opens at a level (Config/Levels.luau)
	local allowed, why = ProgressionService.CanTakeAnimal(player, animalId)
	if not allowed then
		gruffSays(player, why or "Not yet.")
		return
	end
	if not Economy.Owns(player, animalId) then
		local free = Config.Dev.FreeAnimalsInStudio and RunService:IsStudio()
		if not free and not Economy.TrySpend(player, animal.Price, `Animal_{animalId}`) then
			gruffSays(player, Gruff.TooPoor)
			return
		end
		Economy.Unlock(player, animalId)
	end
	local s = newSession(player, animalId, Config.Arenas.ByTier[animal.Tier].Id, chaos == true, nil)
	if not s then
		return -- still loading their save
	end
	Travel.ToArena(player, s.ArenaId) -- off to the arena for this animal's tier
	startCatch(s, nil)
	announceJob(s)
end

-- A new job (shared by the Studio test hook above and wild grabs): uses up your selected stamp, rolls
-- Shiny/Golden (or takes the wild animal's own), and registers the session. Returns nil while the save loads.
newSession = function(
	player: Player,
	animalId: string,
	arenaId: string,
	chaos: boolean,
	wildVariant: string?,
	difficulty: number?
): Session?
	local profile = DataService.Get(player)
	if not profile then
		return nil
	end

	-- Use up the selected stamp (if they still have one)
	local stampId: string? = nil
	local selected = profile.SelectedStamp
	if selected and (profile.Stamps[selected] or 0) > 0 then
		stampId = selected
		profile.Stamps[selected] -= 1
		if profile.Stamps[selected] <= 0 then
			profile.Stamps[selected] = nil
			profile.SelectedStamp = nil
		end
		Economy.Sync(player)
	end

	-- Shiny or Golden? (Your LuckyJob-th job ever is always at least Shiny. Events can raise the odds
	-- with the Workspace attribute VariantLuck.)
	local luck = Workspace:GetAttribute("VariantLuck")
	-- (a wild animal was already rolled when it spawned: you can see a Shiny or Golden one before you grab it)
	local variant = if wildVariant
		then Config.Variants.ById[wildVariant]
		else Config.Variants.Roll(math.random(), if typeof(luck) == "number" then luck else 1)
	local jobsSoFar = profile.Mailed + #profile.Parcels
	if not variant and jobsSoFar == Config.Variants.LuckyJob - 1 and next(profile.Shinies) == nil then
		variant = Config.Variants.ById.Shiny
	end
	if not variant and profile.LuckyNext then
		variant = Config.Variants.ById.Shiny -- a reward for beating the boss
	end
	profile.LuckyNext = false
	-- Promo Kit (Studio only): film a Shiny or Golden on demand
	local forced = player:GetAttribute("PromoVariant")
	if RunService:IsStudio() and typeof(forced) == "string" and Config.Variants.ById[forced] then
		variant = Config.Variants.ById[forced]
		player:SetAttribute("PromoVariant", nil)
	end

	local s: Session = {
		Player = player,
		Crew = {},
		Roles = {},
		Chaos = chaos,
		SpookedBy = {},
		AnimalId = animalId,
		ArenaId = arenaId,
		Stage = "Catch",
		StartTime = os.clock(),
		Escapes = 0,
		AngryTouches = 0,
		MaxAnger = 0,
		Bonus = 0,
		Variant = if variant then variant.Id else nil,
		Difficulty = math.clamp(difficulty or 0, 0, 1),
		LoopId = Analytics.NewLoopId(),
		Hearts = 0,
		Peels = 0,
		BoxId = profile.EquippedBox,
		StampId = stampId,
		GrabHoldMult = 1 - Economy.ToolBonus(player, "Gloves"),
		GrabDistanceBonus = Economy.ToolBonus(player, "Net"),
		TapeAngerMult = 1 - Economy.ToolBonus(player, "TapeGun"),
		CatchState = {},
	}
	sessions[player] = s
	Analytics.Onboarding(player, "PickedAnimal")
	Analytics.Loop(player, "CoreLoop", s.LoopId, 1, "Grab")
	Analytics.Did(player, "Grabbed")
	Analytics.Milestone(player, "FirstGrab")
	if s.Variant then
		Analytics.Custom(player, "VariantFound", 1, s.Variant, Analytics.RarityOf(animalId), Analytics.Segment(player))
	end
	if stampId then
		Analytics.Custom(player, "StampUsed", 1, stampId, Analytics.Segment(player))
	end
	return s
end

-- Tells the player about their new job's stamp, Shiny/Golden and Chaos Mode
announceJob = function(s: Session)
	local player = s.Player
	local animal = Config.Animals.ById[s.AnimalId]
	local stampId = s.StampId
	local variant = if s.Variant then Config.Variants.ById[s.Variant] else nil
	if stampId then
		say(player, "Stamp", `{Config.Stamps.ById[stampId].DisplayName} stamp applied to this job!`)
	end
	if variant then
		notify(player, "VariantFound", {
			Animal = animal.DisplayName,
			Variant = variant.Id,
			PayMult = variant.PayMult,
		})
	end
	if s.Chaos then
		say(
			player,
			"CHAOS",
			"Chaos Mode ON: +50% pay, but anyone can spook your animal and shove you (F, or B on a controller)!"
		)
	end
end

-- Rooftop (any arena without fences): fall off the edge and you're put back on the roof with a word from
-- Gruff, whether or not you're on a job (and dazed if you are). Anyone seen standing on the roof in the
-- last few seconds who drops well below it counts as fallen.
local lastOnRoof: { [Player]: number } = {}

local function checkFalls(now: number)
	for _, arena in map.Arenas do
		if not arena.Edges then
			continue
		end
		for _, player in Players:GetPlayers() do
			local root = getCharacterParts(player)
			if not root then
				continue
			end
			local p = root.Position
			local overRoof = p.X >= arena.Min.X - 2
				and p.X <= arena.Max.X + 2
				and p.Z >= arena.Min.Z - 2
				and p.Z <= arena.Max.Z + 2
			if overRoof and p.Y >= arena.FloorY - 1 then
				lastOnRoof[player] = now
			elseif
				p.Y < arena.FloorY - 8
				and now - (lastOnRoof[player] or -math.huge) < 4
				-- still next to the building (not teleported to town by the BACK TO TOWN pad or a reset)
				and p.X >= arena.Min.X - 25
				and p.X <= arena.Max.X + 25
				and p.Z >= arena.Min.Z - 25
				and p.Z <= arena.Max.Z + 25
			then
				lastOnRoof[player] = nil
				Analytics.Custom(player, "Fell", 1, "Roof", Analytics.Segment(player))
				Travel.ToArena(player, arena.Id)
				if jobOf(player) then
					stun(player, Config.Arenas.FallBackStun)
				end
				gruffSays(player, "You fell off the ROOF?! Get back up there.")
			end
		end
	end
end

-- A player left the game or died
local function dropPlayer(player: Player)
	local s = sessions[player]
	if s then
		cancel(s)
		return
	end
	local helping = crewOf[player]
	if helping then
		leaveCrew(helping, player)
	end
end

---------------------------------------------------------------------------------------------------

local function onPlayerAdded(player: Player)
	player:SetAttribute("Stage", "")
	player:SetAttribute("Tip", "")
	player:SetAttribute("Chaos", false)

	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.Died:Connect(function()
			dropPlayer(player)
		end)
	end)

	-- New hires get Gruff's walkthrough (src/client/Tutorial.luau). Everyone else gets grumbled at.
	task.delay(3, function()
		local profile = DataService.Get(player)
		if player.Parent and profile and profile.TutorialDone then
			gruffSays(player, pick(Gruff.WelcomeBack))
		end
	end)
end

---------------------------------------------------------------------------------------------------
-- For troll items (TrollService). They only ever touch Chaos Mode jobs, never anyone who didn't opt in.

-- Is this player on a Chaos Mode job (owner or crew)? (Shielded players count as out of it: trolls skip them)
function BoxingService.InChaos(player: Player): boolean
	local s = jobOf(player)
	return s ~= nil and s.Chaos and not invincible(player)
end

-- Spooks every Chaos animal within `radius` of `position` (except the troller's own)
function BoxingService.SpookNear(position: Vector3, radius: number, byPlayer: Player): number
	local count = 0
	for _, s in sessions do
		local critter = s.Critter
		if s.Chaos and s.Stage == "Catch" and critter and jobOf(byPlayer) ~= s and not invincible(s.Player) then
			if (critter.Position - position).Magnitude <= radius then
				CatchAI.Spook(s, byPlayer)
				count += 1
			end
		end
	end
	return count
end

-- Makes the nearest Chaos player who's boxing (within `radius`) angrier. Returns who got hit.
function BoxingService.AngerNearest(position: Vector3, radius: number, byPlayer: Player, amount: number): Player?
	local best: Session? = nil
	local bestDistance = radius
	for _, s in sessions do
		local root = getCharacterParts(s.Player)
		if s.Chaos and s.Box and root and jobOf(byPlayer) ~= s and not invincible(s.Player) then
			local distance = (root.Position - position).Magnitude
			if distance <= bestDistance then
				best, bestDistance = s, distance
			end
		end
	end
	local target = best
	if not target then
		return nil
	end
	local state = target.Box :: Types.BoxState
	state.Anger += amount
	syncBox(target)
	notifyAll(target, "Thump", {})
	return target.Player
end

-- Set by BossService: BOX screen messages from players who aren't on a normal job
BoxingService.ExternalInput = nil :: ((Player, unknown, unknown) -> ())?

-- Is this player busy with a job (their own, or helping a crew)?
function BoxingService.HasJob(player: Player): boolean
	return jobOf(player) ~= nil
end

-- Is this player in the BOX screen right now?
function BoxingService.IsBoxing(player: Player): boolean
	local s = jobOf(player)
	return s ~= nil and s.Stage == "Box"
end

-- Drops a job that isn't being boxed (a giant waiting for its crew, an animal running loose), so grabbing a
-- new wild animal never gets blocked by an old one
function BoxingService.DropJob(player: Player)
	local s = jobOf(player)
	if not s or s.Stage == "Box" then
		return
	end
	if s.Player == player then
		cancel(s)
	else
		leaveCrew(s, player)
	end
end

-- Gives up the current job, even mid-BOX (Studio only: the automated tests use it to reset between steps)
function BoxingService.GiveUp(player: Player)
	local s = jobOf(player)
	if not s then
		return
	end
	if s.Player == player then
		cancel(s)
	else
		leaveCrew(s, player)
	end
end

-- A wild animal was grabbed (WildService has already checked the level and the bag). Normal animals go
-- straight to the BOX screen; giants need a crew, so they stay put (as a job animal) for others to join.
function BoxingService.StartWild(
	player: Player,
	animalId: string,
	arenaId: string,
	variant: string?,
	at: Vector3,
	difficulty: number
): boolean
	local animal = Config.Animals.ById[animalId]
	if not animal or jobOf(player) or not getCharacterParts(player) then
		return false
	end
	local profile = DataService.Get(player)
	local chaos = profile ~= nil and profile.Settings.Chaos ~= false -- (on unless you turned it off)
	local s = newSession(player, animalId, arenaId, chaos, variant, difficulty)
	if not s then
		return false
	end
	if animal.Carriers > 1 then
		startCatch(s, at)
	else
		s.BoxModel = buildBox(s)
		startBox(s)
	end
	announceJob(s)
	return true
end

function BoxingService.Stun(player: Player, seconds: number)
	stun(player, seconds)
end

-- Re-applies walk speed, jumping and Frozen from the player's current state (after the boss's BOX IT ends)
function BoxingService.RefreshMovement(player: Player)
	refreshMovement(player)
end

function BoxingService.Start(builtMap: MapBuilder.Map)
	map = builtMap

	boxesFolder = Instance.new("Folder")
	boxesFolder.Name = "Boxes"
	boxesFolder.Parent = Workspace

	-- Diving: animal attacks stun you this way, and diving into your own job's animal grabs it
	DiveService.Stun = stun
	table.insert(DiveService.OnDive, function(player: Player, root: BasePart): boolean
		local s = jobOf(player)
		if not s or s.Stage ~= "Catch" then
			return false
		end
		local critter = s.Critter
		if not critter then
			return false
		end
		if (critter.Position - root.Position).Magnitude > critter.Size.X / 2 + Config.Dive.GrabReach then
			return false
		end
		onPrompt(s, player) -- (the same as HOLD E: crews, slippery animals and all)
		return true
	end)
	CatchAI.Init(map, {
		Stun = stun,
		Effect = notify,
		Say = say,
		OnPrompt = onPrompt,
		Members = membersOf,
	})

	Remotes.Listen(Remotes.RequestAnimal, 4, onRequestAnimal)
	Remotes.Listen(Remotes.Shove, 4, onShove)
	-- Petting sends ~10 a second, so 30 leaves lots of room
	Remotes.Listen(Remotes.BoxingInput, 30, function(player: Player, action: unknown, index: unknown)
		local s = jobOf(player)
		if not s or s.Stage ~= "Box" then
			-- (the boss fight has its own shared box: BossService)
			local external = BoxingService.ExternalInput
			if external then
				external(player, action, index)
			end
			return
		end
		if action == "Pet" then
			onPet(s, player, index)
		elseif action == "Angry" then
			onAngryTouch(s, player, index)
		elseif action == "Tape" then
			onTape(s, player, index)
		end
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		dropPlayer(player)
		stunnedUntil[player] = nil
		lastShove[player] = nil
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastOnRoof[player] = nil
	end)
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		checkFalls(now)
		for _, s in sessions do
			if s.Stage == "Catch" then
				CatchAI.Update(s, now, dt)
			elseif s.Stage == "Box" then
				updateBox(s, now, dt)
			end
		end
	end)
end

return BoxingService
