--!strict
-- Stage 1: CATCH. Drives each player's animal around the arena: wandering, fleeing, juking past you when
-- it's cornered, and doing its twist tricks (hopping, flying, charging, roaring...).
-- The animal is an anchored part that the server moves every frame, kept inside the arena bounds.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BoxingConfig = require(ReplicatedStorage.Shared.Config.Boxing)
local Config = require(ReplicatedStorage.Shared.Config)
local MapBuilder = require(script.Parent.MapBuilder)
local Types = require(script.Parent.Types)

type Session = Types.Session
type TwistSet = BoxingConfig.TwistSet

export type Api = {
	Stun: (player: Player, seconds: number) -> (),
	Effect: (player: Player, kind: string, data: { [string]: any }) -> (),
	Say: (player: Player, speaker: string, text: string) -> (),
	OnCaught: (s: Session) -> (),
}

local Catch = Config.Boxing.Catch
local Tuning = Config.Boxing.TwistTuning

local CatchAI = {}

local api: Api
local map: MapBuilder.Map
local folder: Folder

---------------------------------------------------------------------------------------------------
-- Helpers

local function randomBetween(min: number, max: number): number
	return min + math.random() * (max - min)
end

-- True once every `interval` seconds. The first interval starts the first time it's called.
local function every(state: { [string]: any }, key: string, now: number, interval: number): boolean
	local nextTime = state[key]
	if nextTime == nil then
		state[key] = now + interval * randomBetween(0.7, 1.3)
		return false
	end
	if now < nextTime then
		return false
	end
	state[key] = now + interval * randomBetween(0.7, 1.3)
	return true
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function twistsFor(animalId: string): TwistSet
	return Config.Boxing.Twists[animalId] or {}
end

local function playerRoot(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function clampToArena(position: Vector3, radius: number): Vector3
	return Vector3.new(
		math.clamp(position.X, map.ArenaMin.X + radius, map.ArenaMax.X - radius),
		0,
		math.clamp(position.Z, map.ArenaMin.Z + radius, map.ArenaMax.Z - radius)
	)
end

local function randomArenaPoint(radius: number): Vector3
	return clampToArena(
		Vector3.new(randomBetween(map.ArenaMin.X, map.ArenaMax.X), 0, randomBetween(map.ArenaMin.Z, map.ArenaMax.Z)),
		radius
	)
end

-- Pushes away from nearby fences, so smarter animals run along walls instead of into corners.
local function wallAvoidance(position: Vector3): Vector3
	local range = 6
	local push = Vector3.zero
	local left = position.X - map.ArenaMin.X
	local right = map.ArenaMax.X - position.X
	local back = position.Z - map.ArenaMin.Z
	local front = map.ArenaMax.Z - position.Z
	if left < range then
		push += Vector3.xAxis * (1 - left / range)
	end
	if right < range then
		push -= Vector3.xAxis * (1 - right / range)
	end
	if back < range then
		push += Vector3.zAxis * (1 - back / range)
	end
	if front < range then
		push -= Vector3.zAxis * (1 - front / range)
	end
	return push
end

-- If you've made a model for this animal, put it in ReplicatedStorage > AnimalModels, named after the
-- animal's Id (e.g. "Hamster"). It's welded onto the running animal instead of showing a plain ball.
local function attachModel(critter: Part, animalId: string)
	local models = ReplicatedStorage:FindFirstChild("AnimalModels")
	local template = models and models:FindFirstChild(animalId)
	if not (template and template:IsA("Model")) then
		return
	end
	local model = template:Clone()
	model:PivotTo(critter.CFrame)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.Massless = true
			descendant:SetAttribute("BaseTransparency", descendant.Transparency)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = critter
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end
	model.Parent = critter
	critter.Transparency = 1
	critter:SetAttribute("HasModel", true)
end

local function setHidden(critter: Part, hidden: boolean)
	if critter:GetAttribute("Hidden") == hidden then
		return
	end
	critter:SetAttribute("Hidden", hidden)
	if not critter:GetAttribute("HasModel") then
		critter.Transparency = if hidden then 1 else 0
	end
	for _, descendant in critter:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = if hidden
				then 1
				else (descendant:GetAttribute("BaseTransparency") :: number?) or 0
		elseif descendant:IsA("BillboardGui") or descendant:IsA("ProximityPrompt") then
			(descendant :: any).Enabled = not hidden
		end
	end
end

local function placeCritter(s: Session)
	local critter = s.Critter
	if not critter then
		return
	end
	local st = s.CatchState
	local position = st.Pos + Vector3.new(0, map.ArenaMin.Y + st.Radius + st.Lift, 0)
	critter.CFrame = CFrame.lookAt(position, position + st.Facing)
end

local function startDodge(s: Session, now: number, toPlayer: Vector3)
	local st = s.CatchState
	local towardPlayer = if toPlayer.Magnitude > 0.01 then toPlayer.Unit else Vector3.xAxis
	local side = Vector3.new(-towardPlayer.Z, 0, towardPlayer.X) * (if math.random() < 0.5 then 1 else -1)
	st.DodgeDir = (side + towardPlayer * 0.6).Unit -- dart sideways PAST you
	st.DodgeUntil = now + Catch.DodgeSeconds
end

local function dropEgg(s: Session)
	local st = s.CatchState
	local animal = Config.Animals.ById[s.AnimalId]
	local egg = Instance.new("Part")
	egg.Name = "Egg"
	egg.Shape = Enum.PartType.Ball
	egg.Size = Vector3.new(1, 1, 1)
	egg.Color = Color3.fromRGB(255, 250, 235)
	egg.Anchored = true
	egg.CanCollide = false
	egg.Position = st.Pos + Vector3.new(0, map.ArenaMin.Y + 0.5, 0)
	egg.Parent = folder
	Debris:AddItem(egg, 20)

	local taken = false
	egg.Touched:Connect(function(hit)
		if taken or Players:GetPlayerFromCharacter(hit.Parent) ~= s.Player then
			return
		end
		taken = true
		egg:Destroy()
		local bonus = math.max(1, math.round(animal.BaseValue * Tuning.Eggs.BonusFraction))
		s.Bonus += bonus
		api.Say(s.Player, animal.DisplayName, `You picked up an egg! +{bonus} bonus coins.`)
	end)
end

local function onGrab(s: Session, who: Player)
	if who ~= s.Player then
		api.Say(who, "Postmaster Gruff", Config.Gruff.NotYours)
		return
	end
	if s.Stage ~= "Catch" or not s.Critter then
		return
	end
	local animal = Config.Animals.ById[s.AnimalId]
	if twistsFor(s.AnimalId).Slippery and math.random() < Tuning.Slippery.SlipChance then
		local root = playerRoot(s.Player)
		local toPlayer = if root then flat(root.Position) - s.CatchState.Pos else Vector3.xAxis
		startDodge(s, os.clock(), toPlayer)
		api.Say(s.Player, animal.DisplayName, "*SLIP* It wriggled right out of your hands!")
		return
	end
	api.OnCaught(s)
end

---------------------------------------------------------------------------------------------------

function CatchAI.Init(builtMap: MapBuilder.Map, catchApi: Api)
	map = builtMap
	api = catchApi
	folder = Instance.new("Folder")
	folder.Name = "ArenaAnimals"
	folder.Parent = Workspace
end

function CatchAI.Remove(s: Session)
	if s.Critter then
		s.Critter:Destroy()
		s.Critter = nil
	end
end

-- Puts the player's animal into the arena (at `at` if given, e.g. where it escaped from).
function CatchAI.Spawn(s: Session, at: Vector3?)
	CatchAI.Remove(s)
	local animal = Config.Animals.ById[s.AnimalId]
	local twists = twistsFor(s.AnimalId)
	local radius = 0.8 + animal.Tier * 0.25

	local critter = Instance.new("Part")
	critter.Name = `Critter_{s.Player.UserId}`
	critter.Shape = Enum.PartType.Ball
	critter.Size = Vector3.one * radius * 2
	critter.Color = animal.Color or Color3.new(1, 1, 1)
	critter.Anchored = true
	critter.CanCollide = false
	attachModel(critter, s.AnimalId)
	MapBuilder.Label(critter, `{s.Player.DisplayName}'s {animal.DisplayName}`, radius + 1.5)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Grab"
	prompt.ObjectText = animal.DisplayName
	prompt.HoldDuration = Catch.BaseGrabHold + Catch.GrabHoldPerTier * (animal.Tier - 1)
	prompt.MaxActivationDistance = Catch.GrabDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = critter
	prompt.Triggered:Connect(function(who: Player)
		onGrab(s, who)
	end)

	local start = if at then clampToArena(flat(at), radius) else randomArenaPoint(radius)
	s.CatchState = {
		Pos = start,
		Radius = radius,
		Facing = Vector3.xAxis,
		Lift = 0,
		SpeedMult = 1,
		Asleep = twists.Sleep == true,
	}
	s.Critter = critter
	placeCritter(s)
	critter.Parent = folder
end

function CatchAI.Update(s: Session, now: number, dt: number)
	local critter = s.Critter
	if not critter then
		return
	end
	local st = s.CatchState
	local player = s.Player
	local animal = Config.Animals.ById[s.AnimalId]
	local twists = twistsFor(s.AnimalId)
	local tier = animal.Tier
	local root = playerRoot(player)

	local toPlayer = if root then flat(root.Position) - st.Pos else Vector3.zero
	local distance = if root then toPlayer.Magnitude else math.huge
	local away = if distance > 0.01 then -toPlayer.Unit else Vector3.xAxis

	-- Sleeping: stays put until you come close without sneaking
	if st.Asleep then
		if
			root
			and distance < Tuning.Sleep.WakeRadius
			and flat(root.AssemblyLinearVelocity).Magnitude > Catch.SneakSpeed
		then
			st.Asleep = false
			st.SpeedMult = Tuning.Sleep.WakeSpeedMult
			api.Say(player, animal.DisplayName, "GRRRR! It woke up! (Hold C to sneak next time.)")
		end
		placeCritter(s)
		return
	end

	-- Close-range attacks
	if root then
		if twists.Roar and distance < Tuning.Roar.Radius and now > (st.RoarReady or 0) then
			st.RoarReady = now + Tuning.Roar.Cooldown
			api.Stun(player, Tuning.Roar.StunSeconds)
			api.Effect(player, "Roar", {})
		end
		if twists.Freeze and distance < Tuning.Freeze.Radius and now > (st.FreezeReady or 0) then
			st.FreezeReady = now + Tuning.Freeze.Cooldown
			api.Stun(player, Tuning.Freeze.StunSeconds)
			api.Effect(player, "Freeze", {})
		end
		if twists.Spray and distance < Tuning.Spray.Radius and now > (st.SprayReady or 0) then
			st.SprayReady = now + Tuning.Spray.Cooldown
			api.Effect(player, "Spray", { Seconds = Tuning.Spray.Seconds })
		end
		if twists.Charge and distance < Tuning.Charge.Range and every(st, "Charge", now, Tuning.Charge.Interval) then
			st.ChargeUntil = now + Tuning.Charge.Seconds
		end
	end

	-- Pick a direction and speed
	local speed = (Catch.BaseSpeed + Catch.SpeedPerTier * (tier - 1)) * st.SpeedMult
	local direction: Vector3
	if st.DodgeUntil and now < st.DodgeUntil then
		direction = st.DodgeDir
		speed *= Catch.DodgeSpeedMult
	elseif st.ChargeUntil and now < st.ChargeUntil then
		direction = -away
		speed *= Tuning.Charge.SpeedMult
		if distance < st.Radius + 2.5 then
			st.ChargeUntil = nil
			api.Effect(player, "Knockback", { Direction = -away, Strength = Tuning.Charge.Knockback })
			api.Say(player, animal.DisplayName, "*WHAM!*")
		end
	elseif distance < Catch.FleeRadius then
		local smarts = (tier - 1) * 0.25 -- higher tiers steer away from walls, so they're harder to corner
		local flee = away + wallAvoidance(st.Pos) * smarts
		direction = if flee.Magnitude > 0.01 then flee.Unit else away
	else
		if not st.WanderTarget or now > st.WanderUntil or (st.WanderTarget - st.Pos).Magnitude < 1 then
			st.WanderTarget = randomArenaPoint(st.Radius)
			st.WanderUntil = now + randomBetween(2, 4)
		end
		local toTarget = st.WanderTarget - st.Pos
		direction = if toTarget.Magnitude > 0.01 then toTarget.Unit else Vector3.zero
		speed = Catch.WanderSpeed
	end

	-- Tricks over time
	local lift = 0
	if twists.Hop and distance < Catch.FleeRadius and every(st, "Hop", now, Tuning.Hop.Interval) then
		st.HopStart = now
	end
	if st.HopStart and now - st.HopStart < Tuning.Hop.Seconds then
		lift = math.sin((now - st.HopStart) / Tuning.Hop.Seconds * math.pi) * Tuning.Hop.Height
		speed = math.max(speed, Tuning.Hop.Distance / Tuning.Hop.Seconds)
	end
	if twists.Fly and every(st, "Fly", now, Tuning.Fly.Interval) then
		st.FlyUntil = now + Tuning.Fly.Seconds
	end
	if st.FlyUntil and now < st.FlyUntil then
		lift = math.max(lift, Tuning.Fly.Height)
	end
	st.Lift += (lift - st.Lift) * math.min(1, dt * 10)

	if twists.Hide and every(st, "Hide", now, Tuning.Hide.Interval) then
		st.HideUntil = now + Tuning.Hide.Seconds
	end
	setHidden(critter, st.HideUntil ~= nil and now < st.HideUntil)

	if twists.Teleport and every(st, "Teleport", now, Tuning.Teleport.Interval) then
		st.Pos = randomArenaPoint(st.Radius)
	end
	if twists.Eggs and every(st, "Egg", now, Tuning.Eggs.Interval) then
		dropEgg(s)
	end

	-- Move, staying inside the arena. Barely moving while fleeing = cornered, which is when it tries to juke.
	local intended = st.Pos + direction * speed * dt
	local clamped = clampToArena(intended, st.Radius)
	local moved = (clamped - st.Pos).Magnitude
	st.Pos = clamped
	if direction.Magnitude > 0.01 then
		st.Facing = direction
	end

	local fleeing = distance < Catch.FleeRadius and not (st.DodgeUntil and now < st.DodgeUntil)
	local cornered = fleeing and moved < speed * dt * 0.35
	if cornered and distance < 10 then
		local chancePerSecond = Catch.BaseDodgeChance + Catch.DodgeChancePerTier * (tier - 1)
		if math.random() < chancePerSecond * dt then
			startDodge(s, now, toPlayer)
		end
	end

	placeCritter(s)
end

return CatchAI
