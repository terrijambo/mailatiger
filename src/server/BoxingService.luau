--!strict
-- The boxing loop:
--   Pick an animal at the Pen -> CATCH it in the arena -> BOX it -> it flies into the mail chute and Gruff rates you.
--
-- BOX: the animal and an open box pop up on your screen. Its ANGER keeps rising. Rub its sweet spots to calm it
-- (don't touch its angry spots!) while you drag tape across every seam of the box. Each strip annoys it more.
-- If anger hits 100: VINE BOOM, you're launched into the air as a ragdoll, and it escapes back into the arena.
--
-- The server runs everything and checks every message. The client only draws the screen and reports what you
-- rubbed and taped. Calming is capped per second and tape strips can't come faster than a human could drag them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BoxMath = require(ReplicatedStorage.Shared.BoxMath)
local BoxingConfig = require(ReplicatedStorage.Shared.Config.Boxing)
local CatchAI = require(script.Parent.CatchAI)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local MapBuilder = require(script.Parent.MapBuilder)
local Orders = require(script.Parent.Orders)
local Remotes = require(script.Parent.Remotes)
local StampsConfig = require(ReplicatedStorage.Shared.Config.Stamps)
local Travel = require(script.Parent.Travel)
local Types = require(script.Parent.Types)

type Session = Types.Session
type TwistSet = BoxingConfig.TwistSet

local Boxing = Config.Boxing
local Tuning = Boxing.TwistTuning
local Gruff = Config.Gruff

local WALK_SPEED = 16
local JUMP_HEIGHT = 7.2

local BoxingService = {}

local sessions: { [Player]: Session } = {}
local stunnedUntil: { [Player]: number } = {}
local lastPenUse: { [Player]: number } = {}
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

-- You can't walk while boxing, or while stunned (or ragdolled).
local function refreshMovement(player: Player)
	local _, humanoid = getCharacterParts(player)
	if not humanoid then
		return
	end
	local s = sessions[player]
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
	s.Player:SetAttribute("Stage", stage)
	s.Player:SetAttribute("Tip", tip)
	refreshMovement(s.Player)
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
	local box = piece("Box", Vector3.new(3, 3, 3), boxCFrame, boxColor)
	piece(
		"Lid",
		Vector3.new(3.1, 0.25, 3.1),
		boxCFrame * CFrame.new(0, 1.6, 0),
		boxColor:Lerp(Color3.new(0, 0, 0), 0.15)
	)
	local strip =
		piece("Tape", Vector3.new(0.05, 0.3, 0.7), boxCFrame * CFrame.new(0, 1.75, 0), Color3.fromRGB(230, 200, 120))
	strip.Transparency = 1 -- appears as you tape
	local critter = piece(
		"Animal",
		Vector3.new(1.6, 1.6, 1.6),
		boxCFrame * CFrame.new(0, 2.6, 0),
		animal.Color or Color3.new(1, 1, 1)
	)
	critter.Shape = Enum.PartType.Ball
	MapBuilder.Label(box, `{s.Player.DisplayName}'s {animal.DisplayName}`, 4)

	model.PrimaryPart = box
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
	local shake = if state.Anger > 70 then (math.random() - 0.5) * 0.15 else 0
	local angle = math.rad(math.clamp(state.Anger, 0, 100) * 0.6)
	lid.CFrame = box.CFrame * CFrame.new(shake, 1.6, 1.55) * CFrame.Angles(angle, 0, 0) * CFrame.new(0, 0, -1.55)
	local taped = 0
	for _, done in state.Taped do
		taped += if done then 1 else 0
	end
	local length = 3.1 * taped / state.SeamCount
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
	if twistsFor(s.AnimalId).Sleep then
		return `Your {animal.DisplayName} is asleep in the {arenaName}. Hold C to sneak up, then hold E to grab it.`
	end
	return `Catch your {animal.DisplayName} in the {arenaName}! Corner it, then hold E to grab it.`
end

local function startCatch(s: Session, at: Vector3?)
	destroyBox(s)
	s.Box = nil
	s.Player:SetAttribute("Anger", nil)
	CatchAI.Spawn(s, at)
	setStage(s, "Catch", catchTip(s))
end

---------------------------------------------------------------------------------------------------
-- Stage 2: BOX

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
		local x, y = 0.5, 0.5
		for _ = 1, 30 do
			x = margin + math.random() * (1 - 2 * margin)
			y = margin + math.random() * (1 - 2 * margin)
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
		s.Player:SetAttribute("Anger", math.floor(state.Anger))
	end
end

local function startBox(s: Session)
	local cfg = Boxing.Box
	local tier = Config.Animals.ById[s.AnimalId].Tier
	local box = Config.Boxes.ById[s.BoxId]
	local stamp = stampOf(s)
	local seamCount = cfg.SeamsByTier[tier] or 5

	local taped = {}
	for index = 1, seamCount do
		taped[index] = false
	end
	s.Box = {
		Start = Workspace:GetServerTimeNow(),
		Anger = if stamp and stamp.StartAnger then stamp.StartAnger else box.StartAnger, -- PRIORITY starts high
		Spots = makeSpots(s),
		SeamCount = seamCount,
		Taped = taped,
		LastSeam = os.clock(),
		LastPet = os.clock(),
		LastAngryTouch = 0,
		NextPound = os.clock() + Tuning.Pound.Interval,
		TapeAngerMult = s.TapeAngerMult,
		AngerMult = box.AngerMult * (if stamp and stamp.AngerMult then stamp.AngerMult else 1), -- FRAGILE is touchier
	}
	setStage(s, "Box", "Rub the ♥ spots to keep it calm while you drag tape across every seam! Avoid the ✖ spots.")
	local state = s.Box :: Types.BoxState
	notify(s.Player, "BoxStart", {
		AnimalId = s.AnimalId,
		Start = state.Start,
		Spots = state.Spots,
		SeamCount = seamCount,
	})
	syncBox(s)
	updateBoxVisual(s)
end

local function endSession(s: Session)
	local player = s.Player
	CatchAI.Remove(s)
	sessions[player] = nil
	player:SetAttribute("Stage", "")
	player:SetAttribute("Tip", "")
	player:SetAttribute("Anger", nil)
	refreshMovement(player)
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
	gruffSays(s.Player, pick(Gruff.Breakout))
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
	notify(s.Player, "Break", {})
	if how == "Launch" and twistsFor(s.AnimalId).Breakout then
		breakout(s, position)
	else
		gruffSays(s.Player, pick(Gruff.Escape))
	end
	startCatch(s, position)
end

local function playVineBoom(at: BasePart)
	local id = Config.Sounds.VineBoom
	if id == "" then
		return -- no sound id set yet (see src/shared/Config/Sounds.luau)
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = Config.Sounds.VineBoomVolume
	sound.RollOffMaxDistance = 150
	sound.Parent = at
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

-- Anger hit 100: VINE BOOM, launch the player as a ragdoll, and the animal escapes.
local function launch(s: Session)
	local cfg = Boxing.Box
	local player = s.Player
	local root = getCharacterParts(player)
	local angle = math.random() * math.pi * 2
	local velocity =
		Vector3.new(math.cos(angle) * cfg.LaunchSideways, cfg.LaunchSpeed, math.sin(angle) * cfg.LaunchSideways)
	if root then
		playVineBoom(root)
	end
	notify(player, "Launch", { Velocity = velocity, Seconds = cfg.RagdollSeconds })
	stun(player, cfg.RagdollSeconds)
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

-- Taped shut! Fly it to the mail chute and pay up.
--   coins = value x stamps x escapes x stamp bonus x rebirth bonus + egg bonus, plus any orders filled
local function mail(s: Session)
	local player = s.Player
	local animal = Config.Animals.ById[s.AnimalId]
	local stars = starsFor(s)
	local underPar = isUnderPar(s)
	local stamp = stampOf(s)

	local mult = Boxing.StarPayoutMult[stars] * Boxing.EscapePayoutMult ^ s.Escapes * Economy.PayoutMult(player)
	if stamp then
		mult *= stamp.PayoutMult
		if stamp.UnderParMult and underPar then
			mult *= stamp.UnderParMult
		end
	end
	local coins = math.max(1, math.round(animal.BaseValue * mult + s.Bonus))

	local orderBonus = 0
	local profile = DataService.Get(player)
	if profile then
		profile.Mailed += 1
		orderBonus = Orders.OnMailed(profile, s.AnimalId, { Stars = stars, Escapes = s.Escapes, UnderPar = underPar })
	end
	local seconds = os.clock() - s.StartTime

	local model = s.BoxModel
	s.BoxModel = nil
	if model then
		local critter = model:FindFirstChild("Animal") :: Part?
		if critter then
			critter.Transparency = 1 -- it's in the box now
		end
		task.spawn(function()
			local from = model:GetPivot()
			local to = map.Chute.CFrame * CFrame.new(0, map.Chute.Size.Y / 2 + 1.5, 0)
			-- It flies all the way to the chute in town: farther arenas = longer, higher flight
			local distance = (to.Position - from.Position).Magnitude
			local frames = math.clamp(math.round(distance / 4), 30, 90)
			local height = math.max(6, distance / 4)
			for i = 1, frames do
				local t = i / frames
				local arc = CFrame.new(0, math.sin(t * math.pi) * height, 0)
				model:PivotTo(arc * from:Lerp(to, t))
				task.wait()
			end
			model:Destroy()
		end)
	end

	endSession(s)
	notify(player, "BoxDone", {})
	Economy.AddCoins(player, coins + orderBonus)
	notify(player, "Receipt", {
		Animal = animal.DisplayName,
		Stars = stars,
		Coins = coins,
		OrderBonus = orderBonus,
		Stamp = if stamp then stamp.DisplayName else nil,
		Line = pick(Gruff.Ratings[stars]),
		Seconds = seconds,
	})
end

local function cancel(s: Session)
	destroyBox(s)
	endSession(s)
	notify(s.Player, "BoxDone", {})
end

---------------------------------------------------------------------------------------------------
-- Messages from the BOX screen

-- Rubbing a sweet spot. Calming is limited by the time since the last message, so spamming doesn't help.
local function onPet(s: Session, spotIndex: unknown)
	local state = s.Box
	if not state or typeof(spotIndex) ~= "number" then
		return
	end
	local spot = state.Spots[spotIndex]
	if not spot or spot.Kind ~= "Sweet" then
		return
	end
	local now = os.clock()
	local elapsed = math.min(now - state.LastPet, 0.25)
	state.LastPet = now
	state.Anger = math.max(0, state.Anger - Boxing.Box.PetCalmPerSecond * elapsed)
	syncBox(s)
end

-- Rubbed an angry spot. Ouch.
local function onAngryTouch(s: Session, spotIndex: unknown)
	local state = s.Box
	if not state or typeof(spotIndex) ~= "number" then
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
	notify(s.Player, "AngryTouch", {})
	syncBox(s)
end

-- Dragged a strip of tape along a seam.
local function onTape(s: Session, seamIndex: unknown)
	local state = s.Box
	if not state or typeof(seamIndex) ~= "number" then
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
		mail(s)
		return
	end
	notify(s.Player, "SeamTaped", { Seam = seamIndex })
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
		notify(s.Player, "Thump", {})
	end
	if twists.Snap and math.random() < Tuning.Snap.ChancePerSecond * dt then
		state.Anger += Tuning.Snap.Spike
		notify(s.Player, "Thump", {})
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
			notify(s.Player, "Peel", { Seam = seam })
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
-- Picking an animal

local function onRequestAnimal(player: Player, animalId: unknown)
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
	if sessions[player] then
		gruffSays(player, Gruff.AlreadyBoxing)
		return
	end
	if animal.Carriers > 1 then
		gruffSays(player, Gruff.NeedsCoop)
		return
	end
	if not Economy.Owns(player, animalId) then
		local free = Config.Dev.FreeAnimalsInStudio and RunService:IsStudio()
		if not free and not Economy.TrySpend(player, animal.Price) then
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
	Travel.ToArena(player, arenaId) -- off to the arena for this animal's tier
	startCatch(s, nil)
	if stampId then
		say(player, "Stamp", `{Config.Stamps.ById[stampId].DisplayName} stamp applied to this job!`)
	end
end

-- Rooftop: fall off the edge and you're put back on the roof, dazed, with a word from Gruff.
local function checkFall(s: Session)
	local arena = map.Arenas[s.ArenaId]
	local root = getCharacterParts(s.Player)
	if arena.Edges and root and root.Position.Y < arena.FloorY - 8 then
		Travel.ToArena(s.Player, s.ArenaId)
		stun(s.Player, Config.Arenas.FallBackStun)
		gruffSays(s.Player, "You fell off the ROOF?! Get back up there.")
	end
end

local function onPenUsed(player: Player)
	local s = sessions[player]
	if not s then
		notify(player, "OpenPen", {})
		return
	end
	-- Using the Pen twice within 5 seconds gives up on the current animal
	local last = lastPenUse[player]
	lastPenUse[player] = os.clock()
	if last and os.clock() - last < 5 then
		gruffSays(player, Gruff.GaveUp)
		cancel(s)
	else
		gruffSays(player, Gruff.AlreadyBoxing)
	end
end

---------------------------------------------------------------------------------------------------

local function onPlayerAdded(player: Player)
	player:SetAttribute("Stage", "")
	player:SetAttribute("Tip", "")

	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.Died:Connect(function()
			local s = sessions[player]
			if s then
				cancel(s)
			end
		end)
	end)

	task.delay(2, function()
		if player.Parent then
			gruffSays(player, Gruff.FirstBox)
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
		OnCaught = function(s: Session)
			CatchAI.Remove(s)
			s.BoxModel = buildBox(s)
			startBox(s)
		end,
	})

	map.PenPrompt.Triggered:Connect(onPenUsed)
	Remotes.RequestAnimal.OnServerEvent:Connect(onRequestAnimal)
	Remotes.BoxingInput.OnServerEvent:Connect(function(player: Player, action: unknown, index: unknown)
		local s = sessions[player]
		if not s or s.Stage ~= "Box" then
			return
		end
		if action == "Pet" then
			onPet(s, index)
		elseif action == "Angry" then
			onAngryTouch(s, index)
		elseif action == "Tape" then
			onTape(s, index)
		end
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local s = sessions[player]
		if s then
			cancel(s)
		end
		stunnedUntil[player] = nil
		lastPenUse[player] = nil
	end)

	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for _, s in sessions do
			if s.Stage == "Catch" then
				CatchAI.Update(s, now, dt)
				checkFall(s)
			elseif s.Stage == "Box" then
				updateBox(s, now, dt)
			end
		end
	end)
end

return BoxingService
