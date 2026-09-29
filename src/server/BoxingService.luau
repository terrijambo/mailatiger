--!strict
-- The boxing loop:
--   Pick an animal at the Pen -> CATCH it in the arena -> STUFF it into the box -> TAPE the lid shut
--   -> it slides down the mail chute and Gruff rates the job.
-- Fail STUFF (too many misses) or TAPE (the lid bursts) and the animal escapes back into the arena.
--
-- The server runs every stage and judges every button press. Clients only draw the minigames and send presses.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BoxingConfig = require(ReplicatedStorage.Shared.Config.Boxing)
local CatchAI = require(script.Parent.CatchAI)
local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(script.Parent.Economy)
local MapBuilder = require(script.Parent.MapBuilder)
local Remotes = require(script.Parent.Remotes)
local StuffMath = require(ReplicatedStorage.Shared.StuffMath)
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

local function getCharacterParts(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?, character:FindFirstChildOfClass("Humanoid")
end

-- You can't walk while stuffing or taping, or while stunned.
local function refreshMovement(player: Player)
	local _, humanoid = getCharacterParts(player)
	if not humanoid then
		return
	end
	local s = sessions[player]
	local busy = s ~= nil and s.Stage ~= "Catch"
	local stunned = os.clock() < (stunnedUntil[player] or 0)
	humanoid.UseJumpPower = false
	humanoid.WalkSpeed = if busy or stunned then 0 else WALK_SPEED
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
-- The box on the ground (visible to everyone during Stuff and Tape)

local function buildBox(s: Session): Model
	local root = getCharacterParts(s.Player)
	local animal = Config.Animals.ById[s.AnimalId]
	local base = if root then root.CFrame else CFrame.new(map.ArenaCenter)
	local look = base.LookVector
	local spot = base.Position + Vector3.new(look.X, 0, look.Z).Unit * 4
	local boxCFrame =
		CFrame.lookAt(Vector3.new(spot.X, 1.5, spot.Z), Vector3.new(base.Position.X, 1.5, base.Position.Z))

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

	local box = piece("Box", Vector3.new(3, 3, 3), boxCFrame, Color3.fromRGB(198, 156, 109))
	piece("Lid", Vector3.new(3.1, 0.25, 3.1), boxCFrame * CFrame.new(0, 1.6, 0), Color3.fromRGB(170, 130, 85))
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

-- Tilts the lid open as the animal pushes, and grows the tape strip as you tape.
local function updateBoxVisual(s: Session)
	local model = s.BoxModel
	local tape = s.Tape
	if not model or not tape then
		return
	end
	local box = model:FindFirstChild("Box") :: Part?
	local lid = model:FindFirstChild("Lid") :: Part?
	local strip = model:FindFirstChild("Tape") :: Part?
	if not (box and lid and strip) then
		return
	end
	local angle = math.rad(math.clamp(tape.Lid, 0, 100) * 0.7)
	lid.CFrame = box.CFrame * CFrame.new(0, 1.6, 1.55) * CFrame.Angles(angle, 0, 0) * CFrame.new(0, 0, -1.55)
	local length = 3.1 * tape.Tape / 100
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
-- Stages

local function catchTip(s: Session): string
	local animal = Config.Animals.ById[s.AnimalId]
	if twistsFor(s.AnimalId).Sleep then
		return `Your {animal.DisplayName} is asleep. Hold C to sneak up on it, then hold E to grab it.`
	end
	return `Catch your {animal.DisplayName}! Corner it in the arena, then hold E to grab it.`
end

local function startCatch(s: Session, at: Vector3?)
	destroyBox(s)
	s.Stuff = nil
	s.Tape = nil
	CatchAI.Spawn(s, at)
	setStage(s, "Catch", catchTip(s))
end

local function randomZoneCenter(width: number, amplitude: number): number
	local margin = width / 2 + amplitude
	return margin + math.random() * (1 - 2 * margin)
end

local function sendStuff(s: Session)
	notify(s.Player, "Stuff", s.Stuff :: any)
end

local function startStuff(s: Session)
	local animal = Config.Animals.ById[s.AnimalId]
	local tier = animal.Tier
	local cfg = Boxing.Stuff
	local width = math.max(cfg.MinZoneWidth, cfg.BaseZoneWidth + cfg.ZoneWidthPerTier * (tier - 1))
	local amplitude = if twistsFor(s.AnimalId).Wiggle then Tuning.Wiggle.Amplitude else 0

	s.Stuff = {
		Start = Workspace:GetServerTimeNow(),
		Speed = cfg.BaseSweepsPerSecond + cfg.SweepsPerTier * (tier - 1),
		ZoneCenter = randomZoneCenter(width, amplitude),
		ZoneWidth = width,
		Amplitude = amplitude,
		Frequency = Tuning.Wiggle.Frequency,
		Hits = 0,
		HitsNeeded = cfg.HitsNeededByTier[tier] or 3,
		Misses = 0,
		MissesAllowed = cfg.MissesAllowed,
		LastPress = 0,
	}
	setStage(s, "Stuff", "STUFF IT! Press SPACE (or tap) when the marker is in the green.")
	sendStuff(s)
end

local function syncTape(s: Session)
	local tape = s.Tape
	if tape then
		s.Player:SetAttribute("Lid", math.floor(tape.Lid))
		s.Player:SetAttribute("Tape", math.floor(tape.Tape))
	end
end

local function startTape(s: Session)
	s.Stuff = nil
	s.Tape = {
		Lid = 20,
		Tape = 0,
		Start = os.clock(),
		Presses = {},
		NextPound = os.clock() + Tuning.Pound.Interval,
	}
	local model = s.BoxModel
	local critter = model and model:FindFirstChild("Animal") :: Part?
	if critter then
		critter.Transparency = 1 -- it's in the box now
	end
	setStage(s, "Tape", "TAPE IT! Mash E or SPACE (or tap) to hold the lid down and tape it shut!")
	syncTape(s)
	updateBoxVisual(s)
end

local function endSession(s: Session)
	local player = s.Player
	CatchAI.Remove(s)
	sessions[player] = nil
	player:SetAttribute("Stage", "")
	player:SetAttribute("Tip", "")
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

-- "RETURN TO SENDER": a tiger (or Gruff!) bursting the lid is the big clip moment.
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
	local position = if model then model:GetPivot().Position elseif root then root.Position else map.ArenaCenter
	s.Escapes += 1
	notify(s.Player, "Break", {})
	if how == "Burst" and twistsFor(s.AnimalId).Breakout then
		breakout(s, position)
	else
		gruffSays(s.Player, pick(Gruff.Escape))
	end
	startCatch(s, position)
end

local function starsFor(s: Session): number
	local animal = Config.Animals.ById[s.AnimalId]
	local par = Boxing.ParSecondsBase + Boxing.ParSecondsPerTier * (animal.Tier - 1)
	local stars = 5
	stars -= math.min(2, s.StuffMisses)
	stars -= if s.MaxLid >= Boxing.Tape.DangerLid then 1 else 0
	stars -= if os.clock() - s.StartTime > par then 1 else 0
	stars -= s.Escapes
	return math.clamp(stars, 1, 5)
end

-- Taped shut! Slide it down the mail chute and pay up.
local function mail(s: Session)
	local player = s.Player
	local animal = Config.Animals.ById[s.AnimalId]
	local stars = starsFor(s)
	local coins = math.max(
		1,
		math.round(animal.BaseValue * Boxing.StarPayoutMult[stars] * Boxing.EscapePayoutMult ^ s.Escapes + s.Bonus)
	)
	local seconds = os.clock() - s.StartTime

	local model = s.BoxModel
	s.BoxModel = nil
	if model then
		task.spawn(function()
			local from = model:GetPivot()
			local to = map.Chute.CFrame * CFrame.new(0, map.Chute.Size.Y / 2 + 1.5, 0)
			for i = 1, 30 do
				local t = i / 30
				local arc = CFrame.new(0, math.sin(t * math.pi) * 6, 0)
				model:PivotTo(arc * from:Lerp(to, t))
				task.wait()
			end
			model:Destroy()
		end)
	end

	endSession(s)
	Economy.AddCoins(player, coins)
	notify(player, "Receipt", {
		Animal = animal.DisplayName,
		Stars = stars,
		Coins = coins,
		Line = pick(Gruff.Ratings[stars]),
		Seconds = seconds,
	})
end

local function cancel(s: Session)
	destroyBox(s)
	endSession(s)
end

---------------------------------------------------------------------------------------------------
-- Input from clients

local function onStuffPress(s: Session, claimedTime: unknown)
	local stuff = s.Stuff
	if not stuff then
		return
	end
	local cfg = Boxing.Stuff
	local now = Workspace:GetServerTimeNow()
	if now - stuff.LastPress < cfg.PressCooldown then
		return
	end
	stuff.LastPress = now

	-- Judge at the moment the player pressed (allowing for lag), not when the message arrived
	local t = now
	if typeof(claimedTime) == "number" and claimedTime <= now + 0.05 and claimedTime >= now - cfg.LatencyAllowance then
		t = claimedTime
	end

	local hit = StuffMath.IsHit(stuff, t)
	if hit then
		stuff.Hits += 1
		notify(s.Player, "StuffResult", { Hit = true })
		if stuff.Hits >= stuff.HitsNeeded then
			startTape(s)
			return
		end
		stuff.ZoneCenter = randomZoneCenter(stuff.ZoneWidth, stuff.Amplitude)
	else
		stuff.Misses += 1
		s.StuffMisses += 1
		notify(s.Player, "StuffResult", { Hit = false })
		if stuff.Misses > stuff.MissesAllowed then
			escape(s, "Stuff")
			return
		end
	end
	sendStuff(s)
end

local function onTapePress(s: Session)
	local tape = s.Tape
	if not tape then
		return
	end
	local cfg = Boxing.Tape
	local now = os.clock()

	-- Ignore presses beyond a human mashing speed
	local presses = tape.Presses
	while #presses > 0 and now - presses[1] > 1 do
		table.remove(presses, 1)
	end
	if #presses >= cfg.MaxPressesPerSecond then
		return
	end
	table.insert(presses, now)

	if twistsFor(s.AnimalId).Poke and math.random() < Tuning.Poke.OuchChance then
		notify(s.Player, "Ouch", {})
		return
	end

	local tier = Config.Animals.ById[s.AnimalId].Tier
	local pressesNeeded = cfg.BasePresses + cfg.PressesPerTier * (tier - 1)
	tape.Lid = math.max(0, tape.Lid - cfg.PressDown)
	tape.Tape = math.min(100, tape.Tape + 100 / pressesNeeded)
	if tape.Tape >= 100 then
		mail(s)
	else
		syncTape(s)
		updateBoxVisual(s)
	end
end

---------------------------------------------------------------------------------------------------
-- Every frame: the animal pushes the lid up

local function updateTape(s: Session, now: number, dt: number)
	local tape = s.Tape
	if not tape then
		return
	end
	local cfg = Boxing.Tape
	local twists = twistsFor(s.AnimalId)
	local tier = Config.Animals.ById[s.AnimalId].Tier

	local push = (cfg.BasePush + cfg.PushPerTier * (tier - 1)) * (1 + cfg.RageGrowth * (now - tape.Start))
	tape.Lid += push * dt

	if twists.Pound and now >= tape.NextPound then
		tape.NextPound = now + Tuning.Pound.Interval
		tape.Lid += Tuning.Pound.Spike
		notify(s.Player, "Thump", {})
	end
	if twists.Snap and math.random() < Tuning.Snap.ChancePerSecond * dt then
		tape.Lid += Tuning.Snap.Spike
		notify(s.Player, "Thump", {})
	end
	if twists.Squeeze then
		tape.Tape = math.max(0, tape.Tape - Tuning.Squeeze.TapeLossPerSecond * dt)
	end

	s.MaxLid = math.max(s.MaxLid, tape.Lid)
	if tape.Lid >= 100 then
		escape(s, "Burst")
		return
	end
	syncTape(s)
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

	local s: Session = {
		Player = player,
		AnimalId = animalId,
		Stage = "Catch",
		StartTime = os.clock(),
		Escapes = 0,
		StuffMisses = 0,
		MaxLid = 0,
		Bonus = 0,
		CatchState = {},
	}
	sessions[player] = s
	startCatch(s, nil)
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
			startStuff(s)
		end,
	})

	map.PenPrompt.Triggered:Connect(onPenUsed)
	Remotes.RequestAnimal.OnServerEvent:Connect(onRequestAnimal)
	Remotes.BoxingInput.OnServerEvent:Connect(function(player: Player, action: unknown, claimedTime: unknown)
		local s = sessions[player]
		if not s then
			return
		end
		if action == "Stuff" and s.Stage == "Stuff" then
			onStuffPress(s, claimedTime)
		elseif action == "Tape" and s.Stage == "Tape" then
			onTapePress(s)
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
			elseif s.Stage == "Tape" then
				updateTape(s, now, dt)
			end
		end
	end)
end

return BoxingService
