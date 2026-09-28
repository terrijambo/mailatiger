--!strict
-- The core loop: box an animal, carry it (wobbly!), take damage, get it to the Post Office.
--
-- How it works:
--   * The box is a physics part pulled toward a point in front of your character by AlignPosition and
--     AlignOrientation. Because those constraints aren't rigid, the box lags and sways behind you.
--   * Your client simulates the box (network owner) so it feels smooth, but the SERVER reads its velocity
--     every frame and decides damage, rage and payouts. Clients never tell the server numbers.
--   * Current HP / rage are copied onto Player attributes so the HUD can show them.

local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(script.Parent.Economy)
local MapBuilder = require(script.Parent.MapBuilder)
local Remotes = require(script.Parent.Remotes)

local Carry = Config.Carry
local Gruff = Config.Gruff

type Delivery = {
	Player: Player,
	Box: Part,
	Hold: Attachment,
	AnimalId: string,
	BoxId: string,
	HP: number,
	MaxHP: number,
	Rage: number,
	PayoutMult: number,
	BellRung: boolean,
	StartTime: number,
	History: { { T: number, V: Vector3 } },
	LastImpact: number,
	NextRattle: number,
}

local BoxService = {}

local active: { [Player]: Delivery } = {}
local loose: { [Player]: BasePart } = {}
local map: MapBuilder.Map
local boxesFolder: Folder
local looseFolder: Folder

local function pick(list: { string }): string
	return list[math.random(1, #list)]
end

local function notify(player: Player, kind: string, data: { [string]: any })
	Remotes.Notify:FireClient(player, kind, data)
end

local function gruffSays(player: Player, text: string)
	notify(player, "Message", { Speaker = "Postmaster Gruff", Text = text })
end

local function isInside(zone: BasePart, point: Vector3): boolean
	local localPoint = zone.CFrame:PointToObjectSpace(point)
	local half = zone.Size / 2
	return math.abs(localPoint.X) <= half.X and math.abs(localPoint.Y) <= half.Y and math.abs(localPoint.Z) <= half.Z
end

local function starsFor(hpFraction: number): number
	for stars = 5, 2, -1 do
		if hpFraction >= Carry.StarThresholds[stars] then
			return stars
		end
	end
	return 1
end

local function getCharacterParts(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?, character:FindFirstChildOfClass("Humanoid")
end

local function syncAttributes(player: Player, d: Delivery?)
	if d then
		player:SetAttribute("Carrying", true)
		player:SetAttribute("HP", math.max(0, math.ceil(d.HP)))
		player:SetAttribute("MaxHP", d.MaxHP)
		player:SetAttribute("Rage", math.floor(d.Rage))
	else
		player:SetAttribute("Carrying", false)
	end
end

local function endDelivery(d: Delivery)
	local player = d.Player
	active[player] = nil
	d.Box:Destroy()
	d.Hold:Destroy()

	local _, humanoid = getCharacterParts(player)
	if humanoid then
		humanoid.WalkSpeed = Carry.BaseWalkSpeed
		humanoid.JumpHeight = Carry.NormalJumpHeight
	end
	syncAttributes(player, nil)
end

local function giveBox(player: Player, animalId: string, payoutMult: number)
	local root, humanoid = getCharacterParts(player)
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	local animal = Config.Animals.ById[animalId]
	local boxDef = Config.Boxes.ById.Cardboard

	-- The point in front of the character the box is pulled toward
	local hold = Instance.new("Attachment")
	hold.Name = "BoxHold"
	hold.Position = Carry.HoldOffset
	hold.Parent = root

	local box = Instance.new("Part")
	box.Name = `Box_{player.UserId}`
	box.Size = Carry.BoxSize
	box.Color = Color3.fromRGB(198, 156, 109)
	box.Material = Enum.Material.SmoothPlastic
	box.CustomPhysicalProperties = PhysicalProperties.new(0.3, 0.5, 0.2)
	box.CollisionGroup = "Boxes"
	box.CFrame = root.CFrame * CFrame.new(Carry.HoldOffset)

	local boxAttachment = Instance.new("Attachment")
	boxAttachment.Parent = box

	local alignPosition = Instance.new("AlignPosition")
	alignPosition.Attachment0 = boxAttachment
	alignPosition.Attachment1 = hold
	alignPosition.Responsiveness = Carry.PositionResponsiveness
	alignPosition.MaxForce = Carry.MaxForce
	alignPosition.Parent = box

	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Attachment0 = boxAttachment
	alignOrientation.Attachment1 = hold
	alignOrientation.Responsiveness = Carry.RotationResponsiveness
	alignOrientation.MaxTorque = Carry.MaxTorque
	alignOrientation.Parent = box

	MapBuilder.Label(box, animal.DisplayName, 2.5)

	box.Parent = boxesFolder
	box:SetNetworkOwner(player)

	local weight = animal.Weight + boxDef.Weight
	humanoid.WalkSpeed =
		math.max(Carry.MinWalkSpeed, Carry.BaseWalkSpeed * (1 - Carry.SpeedLossPerWeight * (weight - 1)))
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = Carry.CarryJumpHeight

	local d: Delivery = {
		Player = player,
		Box = box,
		Hold = hold,
		AnimalId = animalId,
		BoxId = boxDef.Id,
		HP = boxDef.MaxHP,
		MaxHP = boxDef.MaxHP,
		Rage = 0,
		PayoutMult = payoutMult,
		BellRung = false,
		StartTime = os.clock(),
		History = {},
		LastImpact = 0,
		NextRattle = 0,
	}
	active[player] = d

	player:SetAttribute("AnimalName", animal.DisplayName)
	player:SetAttribute("BoxName", boxDef.DisplayName)
	player:SetAttribute("Loose", false)
	syncAttributes(player, d)
end

local function groundBelow(position: Vector3): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { boxesFolder, looseFolder }
	params.CollisionGroup = "Boxes" -- Boxes ignore characters, so the ray does too
	local result = Workspace:Raycast(position + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), params)
	return result and result.Position
end

local function spawnLooseAnimal(player: Player, animalId: string, at: Vector3)
	local animal = Config.Animals.ById[animalId]

	local critter = Instance.new("Part")
	critter.Name = `Loose_{player.UserId}`
	critter.Shape = Enum.PartType.Ball
	critter.Size = Vector3.new(1.6, 1.6, 1.6)
	critter.Color = Color3.fromRGB(235, 160, 70)
	critter.Anchored = true
	critter.CanCollide = false
	critter.Position = (groundBelow(at) or at) + Vector3.new(0, 0.8, 0)
	MapBuilder.Label(critter, `{player.DisplayName}'s {animal.DisplayName}!`, 2.5)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Catch"
	prompt.ObjectText = animal.DisplayName
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = critter

	critter.Parent = looseFolder
	loose[player] = critter
	player:SetAttribute("Loose", true)

	prompt.Triggered:Connect(function(who: Player)
		if who ~= player then
			gruffSays(who, Gruff.NotYours)
			return
		end
		if active[player] then
			return
		end
		critter:Destroy()
		loose[player] = nil
		giveBox(player, animalId, Carry.RecatchPayoutMult)
		gruffSays(player, pick(Gruff.Recatch))
	end)

	-- Hop around randomly near where it escaped
	task.spawn(function()
		local home = critter.Position
		while critter.Parent do
			task.wait(1 + math.random() * 1.5)
			if not critter.Parent then
				break
			end
			local offset = Vector3.new(math.random() * 2 - 1, 0, math.random() * 2 - 1) * Carry.EscapeWanderRadius
			local ground = groundBelow(home + offset)
			if ground then
				local tween = TweenService:Create(critter, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {
					Position = ground + Vector3.new(0, 0.8, 0),
				})
				tween:Play()
			end
		end
	end)
end

local function clearLooseAnimal(player: Player)
	local critter = loose[player]
	if critter then
		critter:Destroy()
		loose[player] = nil
	end
	player:SetAttribute("Loose", false)
end

local function breakBox(d: Delivery)
	local player = d.Player
	local position = d.Box.Position
	local color = d.Box.Color
	local animalId = d.AnimalId
	endDelivery(d)

	for _ = 1, 6 do
		local piece = Instance.new("Part")
		piece.Size = Vector3.new(1.4, 0.2, 1.4)
		piece.Color = color
		piece.CollisionGroup = "Boxes"
		piece.Position = position + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2
		piece.Parent = boxesFolder
		piece.AssemblyLinearVelocity = Vector3.new(math.random(-20, 20), math.random(15, 30), math.random(-20, 20))
		Debris:AddItem(piece, 4)
	end

	notify(player, "Break", {})
	gruffSays(player, pick(Gruff.Escape))
	spawnLooseAnimal(player, animalId, position)
end

local function deliver(d: Delivery)
	local player = d.Player
	local animal = Config.Animals.ById[d.AnimalId]
	local route = Config.Routes.ById.Town
	local stars = starsFor(math.clamp(d.HP / d.MaxHP, 0, 1))
	local coins =
		math.max(1, math.round(animal.BaseValue * route.PayoutMult * Carry.StarPayoutMult[stars] * d.PayoutMult))
	local seconds = os.clock() - d.StartTime
	endDelivery(d)

	Economy.AddCoins(player, coins)
	notify(player, "Receipt", {
		Stars = stars,
		Coins = coins,
		Line = pick(Gruff.Ratings[stars]),
		Seconds = seconds,
	})
end

local function update(d: Delivery, now: number, dt: number)
	local player = d.Player
	local box = d.Box
	local animal = Config.Animals.ById[d.AnimalId]
	local boxDef = Config.Boxes.ById[d.BoxId]

	-- Impacts: how much did the box's velocity change over the last ImpactWindow seconds?
	local history = d.History
	table.insert(history, { T = now, V = box.AssemblyLinearVelocity })
	while #history > 1 and now - history[1].T > Carry.ImpactWindow do
		table.remove(history, 1)
	end
	local velocityChange = (history[#history].V - history[1].V).Magnitude

	if velocityChange > Carry.JostleThreshold then
		d.Rage += (velocityChange - Carry.JostleThreshold) * Carry.RagePerJostle * dt
	end
	if velocityChange > Carry.ImpactThreshold and now - d.LastImpact > Carry.ImpactCooldown then
		d.HP -= (velocityChange - Carry.ImpactThreshold) * Carry.DamagePerSpeed
		d.LastImpact = now
		table.clear(history)
	end

	-- Snagged on something and left behind? You dropped it.
	if not d.Hold.Parent or (box.Position - d.Hold.WorldPosition).Magnitude > Carry.DropDistance then
		d.HP = 0
	end

	-- Rage builds over time. Past RattleStartsAt the animal rattles the box, faster as rage climbs.
	d.Rage = math.min(100, d.Rage + animal.RageRate * boxDef.RageDamp * dt)
	if d.Rage >= Carry.RattleStartsAt and now >= d.NextRattle then
		d.HP -= Carry.RattleDamage
		local rattles = (player:GetAttribute("Rattle") :: number?) or 0
		player:SetAttribute("Rattle", rattles + 1)
		local t = (d.Rage - Carry.RattleStartsAt) / (100 - Carry.RattleStartsAt)
		d.NextRattle = now + Carry.RattleIntervalSlow + (Carry.RattleIntervalFast - Carry.RattleIntervalSlow) * t
	end

	-- The Post Office door bell. Animals hate it.
	if not d.BellRung and isInside(map.BellZone, box.Position) then
		d.BellRung = true
		d.Rage = math.min(100, d.Rage + Carry.BellRage)
		map.BellSound:Play()
		notify(player, "Bell", {})
	end

	if d.HP <= 0 then
		breakBox(d)
	elseif isInside(map.DeliveryZone, box.Position) then
		deliver(d)
	else
		syncAttributes(player, d)
	end
end

local function setCollisionGroup(instance: Instance)
	if instance:IsA("BasePart") then
		instance.CollisionGroup = "Characters"
	end
end

local function onCharacterAdded(player: Player, character: Model)
	for _, descendant in character:GetDescendants() do
		setCollisionGroup(descendant)
	end
	character.DescendantAdded:Connect(setCollisionGroup)

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		local d = active[player]
		if d then
			local position = d.Box.Position
			local animalId = d.AnimalId
			endDelivery(d)
			gruffSays(player, pick(Gruff.Fainted))
			spawnLooseAnimal(player, animalId, position)
		end
	end)
end

local function onPlayerAdded(player: Player)
	player:SetAttribute("Carrying", false)
	player:SetAttribute("Loose", false)
	player:SetAttribute("Rattle", 0)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end

	task.delay(2, function()
		if player.Parent then
			gruffSays(player, Gruff.FirstBox)
		end
	end)
end

function BoxService.Start(builtMap: MapBuilder.Map)
	map = builtMap

	-- Boxes pass through characters (so you don't trip over your own box) but still hit the world.
	PhysicsService:RegisterCollisionGroup("Characters")
	PhysicsService:RegisterCollisionGroup("Boxes")
	PhysicsService:CollisionGroupSetCollidable("Characters", "Boxes", false)

	boxesFolder = Instance.new("Folder")
	boxesFolder.Name = "Boxes"
	boxesFolder.Parent = Workspace

	looseFolder = Instance.new("Folder")
	looseFolder.Name = "LooseAnimals"
	looseFolder.Parent = Workspace

	map.PenPrompt.Triggered:Connect(function(player: Player)
		if active[player] then
			gruffSays(player, Gruff.AlreadyCarrying)
			return
		end
		clearLooseAnimal(player)
		giveBox(player, "Hamster", 1)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local d = active[player]
		if d then
			endDelivery(d)
		end
		clearLooseAnimal(player)
	end)

	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for _, d in active do
			update(d, now, dt)
		end
	end)
end

return BoxService
