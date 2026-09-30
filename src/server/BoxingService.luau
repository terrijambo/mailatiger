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
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local MailService = require(script.Parent.MailService)
local MapBuilder = require(script.Parent.MapBuilder)
local ModelFit = require(ReplicatedStorage.Shared.ModelFit)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Remotes = require(script.Parent.Remotes)
local StampsConfig = require(ReplicatedStorage.Shared.Config.Stamps)
local Travel = require(script.Parent.Travel)
local Types = require(script.Parent.Types)

type Session = Types.Session
type TwistSet = BoxingConfig.TwistSet

local Boxing = Config.Boxing
local Tuning = Boxing.TwistTuning
local Social = Config.Social
local Gruff = Config.Gruff

local WALK_SPEED = 16
local JUMP_HEIGHT = 7.2

local BoxingService = {}

local sessions: { [Player]: Session } = {} -- owner -> job
local crewOf: { [Player]: Session } = {} -- crew member -> the job they're helping with
local stunnedUntil: { [Player]: number } = {}
local lastPenUse: { [Player]: number } = {}
local lastShove: { [Player]: number } = {}
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
	local busy = s ~= nil and s.Stage ~= "Catch"
	local stunned = os.clock() < (stunnedUntil[player] or 0)
	local speed = WALK_SPEED + Economy.ToolBonus(player, "Sneakers")
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
	local strip = piece(
		"Tape",
		Vector3.new(0.05, 0.3, 0.7),
		box.CFrame * CFrame.new(0, 1.75 * scale, 0),
		-- VIP pass: golden tape
		if s.Player:GetAttribute("Pass_VIP") == true
			then Color3.fromRGB(255, 200, 40)
			else Color3.fromRGB(230, 200, 120)
	)
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
local function makeSpots(s: Session): { BoxMath.Spot }
	local cfg = Boxing.Box
	local tier = Config.Animals.ById[s.AnimalId].Tier
	local twists = twistsFor(s.AnimalId)
	local drift = cfg.SpotMovePerTier * (tier - 1)
	local speed = cfg.SpotMoveSpeed * (if twists.Wiggle then Tuning.Wiggle.SpotSpeedMult else 1)
	local sweetRadius = math.max(cfg.MinSweetRadius, cfg.SweetRadius + cfg.SweetRadiusPerTier * (tier - 1))
	local angryRadius = cfg.AngryRadius * (if twists.Poke then Tuning.Poke.AngryRadiusMult else 1)

	local spots: { BoxMath.Spot } = {}
	local function add(kind: string, radius: number)
		local margin = radius + drift + 0.02
		local x, y = 0.5, 0.3
		for _ = 1, 30 do
			-- Only on the part of the animal sticking out of the box (see BoxMath.VISIBLE_HEIGHT)
			x = margin + math.random() * (1 - 2 * margin)
			y = margin + math.random() * math.max(0, BoxMath.VISIBLE_HEIGHT - 2 * margin)
			local clear = true
			for _, other in spots do
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
		table.insert(spots, {
			Kind = kind,
			X = x,
			Y = y,
			Radius = radius,
			Drift = drift,
			Speed = speed,
			Phase = math.random() * math.pi * 2,
		})
	end

	for _ = 1, cfg.SweetSpots do
		add("Sweet", sweetRadius)
	end
	for _ = 1, cfg.AngrySpotsByTier[tier] or 3 do
		add("Angry", angryRadius)
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
	s.Box = {
		Start = Workspace:GetServerTimeNow(),
		Anger = if stamp and stamp.StartAnger then stamp.StartAnger else box.StartAnger, -- PRIORITY starts high
		Spots = makeSpots(s),
		SeamCount = seamCount,
		Taped = taped,
		LastSeam = os.clock(),
		LastPet = {},
		LastAngryTouch = 0,
		NextPound = os.clock() + Tuning.Pound.Interval,
		TapeAngerMult = s.TapeAngerMult,
		AngerMult = angerMult,
	}
	assignRoles(s)
	setStage(s, "Box", "Rub the ♥ spots to keep it calm while you drag tape across every seam! Avoid the ✖ spots.")
	local state = s.Box :: Types.BoxState
	for _, member in membersOf(s) do
		Analytics.Onboarding(member, "Caught")
		notify(member, "BoxStart", {
			AnimalId = s.AnimalId,
			Start = state.Start,
			Spots = state.Spots,
			SeamCount = seamCount,
			Role = s.Roles[member] or "Both",
		})
	end
	syncBox(s)
	updateBoxVisual(s)
end

local function endSession(s: Session)
	CatchAI.Remove(s)
	sessions[s.Player] = nil
	for _, member in membersOf(s) do
		crewOf[member] = nil
		member:SetAttribute("Stage", "")
		member:SetAttribute("Tip", "")
		member:SetAttribute("Anger", nil)
		member:SetAttribute("Chaos", false)
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
	end
end

-- The animal gets out and runs back into the arena.
local function escape(s: Session, how: string)
	local root = getCharacterParts(s.Player)
	local model = s.BoxModel
	local position = if model
		then model:GetPivot().Position
		elseif root then root.Position
		else map.Arenas[s.ArenaId].Center
	s.Escapes += 1
	notifyAll(s, "Break", {})
	Analytics.Custom(s.Player, if how == "Launch" then "Launched" else "Escaped")
	if how == "Launch" and twistsFor(s.AnimalId).Breakout then
		breakout(s, position)
	else
		sayAll(s, "Postmaster Gruff", pick(Gruff.Escape))
	end
	startCatch(s, position)
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
	if stamp then
		mult *= stamp.PayoutMult
		if stamp.UnderParMult and underPar then
			mult *= stamp.UnderParMult
		end
	end
	if s.Chaos then
		mult *= Social.Chaos.PayoutMult
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

	local members = membersOf(s)
	endSession(s)
	local label = if stamp then stamp.DisplayName elseif s.Chaos then "CHAOS" else nil
	for _, member in members do
		local coins = math.max(1, math.round(animal.BaseValue * mult * Economy.PayoutMult(member) + s.Bonus))
		Analytics.Onboarding(member, "Taped")
		MailService.AddParcel(member, {
			AnimalId = s.AnimalId,
			Stars = stars,
			Coins = coins,
			Seconds = seconds,
			Escapes = s.Escapes,
			UnderPar = underPar,
			Stamp = label,
		})
		notify(member, "BoxDone", {})
		notify(member, "Parcel", {
			Animal = animal.DisplayName,
			Stars = stars,
			Coins = coins,
			Stamp = label,
			Count = MailService.Count(member),
			Capacity = MailService.Capacity(member),
		})
	end
end

local function cancel(s: Session)
	destroyBox(s)
	local members = membersOf(s)
	endSession(s)
	for _, member in members do
		notify(member, "BoxDone", {})
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
	local elapsed = math.min(now - (state.LastPet[player] or now), 0.25)
	state.LastPet[player] = now
	state.Anger = math.max(0, state.Anger - Boxing.Box.PetCalmPerSecond * elapsed)
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
	state.Anger += Boxing.Box.TapeAnger * state.TapeAngerMult * state.AngerMult

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
	state.Anger += rate * state.AngerMult * dt

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
			notifyAll(s, "Peel", { Seam = seam })
		end
	end

	s.MaxAnger = math.max(s.MaxAnger, state.Anger)
	if state.Anger >= 100 then
		launch(s)
		return
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
		if other ~= shover and job and job.Chaos and job ~= shoverJob and root then
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

	local job = jobOf(target)
	if job and job.Box then
		job.Box.Anger += cfg.ShoveAnger -- bumping someone mid-BOX riles up their animal
		syncBox(job)
	end
end

---------------------------------------------------------------------------------------------------
-- Picking an animal

local function onRequestAnimal(player: Player, animalId: unknown, chaos: unknown)
	if typeof(animalId) ~= "string" then
		return
	end
	local animal = Config.Animals.ById[animalId]
	if not animal then
		return
	end

	local root = getCharacterParts(player)
	if not root or (root.Position - map.PenCounter.Position).Magnitude > 20 then
		gruffSays(player, Gruff.TooFar)
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
	if not Economy.Owns(player, animalId) then
		local free = Config.Dev.FreeAnimalsInStudio and RunService:IsStudio()
		if not free and not Economy.TrySpend(player, animal.Price, `Animal_{animalId}`) then
			gruffSays(player, Gruff.TooPoor)
			return
		end
		Economy.Unlock(player, animalId)
	end
	local profile = DataService.Get(player)
	if not profile then
		return -- still loading their save
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

	local arenaId = Config.Arenas.ByTier[animal.Tier].Id
	local s: Session = {
		Player = player,
		Crew = {},
		Roles = {},
		Chaos = chaos == true,
		SpookedBy = {},
		AnimalId = animalId,
		ArenaId = arenaId,
		Stage = "Catch",
		StartTime = os.clock(),
		Escapes = 0,
		AngryTouches = 0,
		MaxAnger = 0,
		Bonus = 0,
		BoxId = profile.EquippedBox,
		StampId = stampId,
		GrabHoldMult = 1 - Economy.ToolBonus(player, "Gloves"),
		GrabDistanceBonus = Economy.ToolBonus(player, "Net"),
		TapeAngerMult = 1 - Economy.ToolBonus(player, "TapeGun"),
		CatchState = {},
	}
	sessions[player] = s
	Analytics.Onboarding(player, "PickedAnimal")
	Travel.ToArena(player, arenaId) -- off to the arena for this animal's tier
	startCatch(s, nil)
	if stampId then
		say(player, "Stamp", `{Config.Stamps.ById[stampId].DisplayName} stamp applied to this job!`)
	end
	if s.Chaos then
		say(player, "CHAOS", "Chaos Mode ON: +50% pay, but anyone can spook your animal and shove you (F)!")
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
			elseif p.Y < arena.FloorY - 8 and now - (lastOnRoof[player] or -math.huge) < 4 then
				lastOnRoof[player] = nil
				Travel.ToArena(player, arena.Id)
				if jobOf(player) then
					stun(player, Config.Arenas.FallBackStun)
				end
				gruffSays(player, "You fell off the ROOF?! Get back up there.")
			end
		end
	end
end

local function onPenUsed(player: Player)
	local s = jobOf(player)
	if not s then
		notify(player, "OpenPen", {})
		return
	end
	-- Using the Pen twice within 5 seconds gives up on the current animal (or leaves the crew)
	local last = lastPenUse[player]
	lastPenUse[player] = os.clock()
	if last and os.clock() - last < 5 then
		if s.Player == player then
			gruffSays(player, Gruff.GaveUp)
			cancel(s)
		else
			leaveCrew(s, player)
		end
	else
		gruffSays(player, Gruff.AlreadyBoxing)
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

function BoxingService.Start(builtMap: MapBuilder.Map)
	map = builtMap

	boxesFolder = Instance.new("Folder")
	boxesFolder.Name = "Boxes"
	boxesFolder.Parent = Workspace

	CatchAI.Init(map, {
		Stun = stun,
		Effect = notify,
		Say = say,
		OnPrompt = onPrompt,
		Members = membersOf,
	})

	map.PenPrompt.Triggered:Connect(onPenUsed)
	Remotes.Listen(Remotes.RequestAnimal, 4, onRequestAnimal)
	Remotes.Listen(Remotes.Shove, 4, onShove)
	-- Petting sends ~10 a second, so 30 leaves lots of room
	Remotes.Listen(Remotes.BoxingInput, 30, function(player: Player, action: unknown, index: unknown)
		local s = jobOf(player)
		if not s or s.Stage ~= "Box" then
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
		lastPenUse[player] = nil
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
