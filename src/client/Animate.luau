--!strict
-- Code-driven animation. Everything here runs on each player's own device, so it costs no network traffic.
-- Blender models here are one mesh per color (ears are part of the "Fur" mesh, and so on), so these animate
-- whole models: hops, bobs, lean, squash and little twitches.
--
--   Critters   the animal you chase. The server moves an invisible ball; this draws your Blender model on
--              it and makes it hop while running, and breathe, bob and twitch while standing still.
--   JobBoxes   the box in the arena while you pet and tape: it wiggles harder the angrier the animal gets,
--              and the animal squishes happily when its anger drops (someone petted it).
--   Gruff      bobs and turns to look at the nearest player.
--   Spinners   anything with a "Spin" attribute (shop display tools, the letter over the orders board).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ModelFit = require(ReplicatedStorage.Shared.ModelFit)

local Animate = {}

local player = Players.LocalPlayer

type CritterRig = {
	Ball: BasePart,
	Model: Model,
	Parts: { BasePart },
	Offset: CFrame, -- model pivot relative to the ball
	Height: number,
	BaseScale: number,
	LastPosition: Vector3,
	Speed: number,
	Phase: number,
	TwitchAt: number,
	TwitchStart: number,
	TwitchSign: number,
	Hidden: boolean,
}

type BoxRig = {
	Model: Model,
	Art: { [Model]: CFrame }, -- each art model's resting pivot
	LastAnger: number,
	SquishUntil: number,
	Seed: number,
}

local critters: { [BasePart]: CritterRig } = {}
local boxes: { [Model]: BoxRig } = {}
local spinners: { [Model]: CFrame } = {}

---------------------------------------------------------------------------------------------------
-- Critters

local function addCritter(ball: Instance)
	if not ball:IsA("BasePart") or critters[ball] then
		return
	end
	local animalId = ball:GetAttribute("AnimalId")
	if typeof(animalId) ~= "string" then
		return
	end
	local floor = ball.CFrame * CFrame.new(0, -ball.Size.Y / 2, 0)
	local model = ModelFit.Spawn("AnimalModels", animalId, floor, ball.Size.X * 1.15, Workspace)
	if not model then
		return -- no model imported: you chase the plain ball
	end
	model.Name = `{animalId}Art`
	ball.LocalTransparencyModifier = 1
	local parts = {}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			table.insert(parts, p)
		end
	end
	local _, size = model:GetBoundingBox()
	critters[ball] = {
		Ball = ball,
		Model = model,
		Parts = parts,
		Offset = ball.CFrame:ToObjectSpace(model:GetPivot()),
		Height = size.Y,
		BaseScale = model:GetScale(),
		LastPosition = ball.Position,
		Speed = 0,
		Phase = math.random() * 10,
		TwitchAt = os.clock() + 1 + math.random() * 3,
		TwitchStart = -10,
		TwitchSign = 1,
		Hidden = false,
	}
end

local function removeCritter(ball: Instance)
	local rig = critters[ball :: BasePart]
	if rig then
		rig.Model:Destroy()
		critters[ball :: BasePart] = nil
	end
end

local function updateCritter(rig: CritterRig, dt: number, now: number)
	local ball = rig.Ball
	local hidden = ball:GetAttribute("Hidden") == true
	if hidden ~= rig.Hidden then
		rig.Hidden = hidden
		for _, p in rig.Parts do
			p.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end

	-- How fast is it running? (smoothed, flat)
	local moved = ball.Position - rig.LastPosition
	rig.LastPosition = ball.Position
	local flatSpeed = Vector3.new(moved.X, 0, moved.Z).Magnitude / math.max(dt, 1 / 240)
	rig.Speed += (flatSpeed - rig.Speed) * math.min(1, dt * 10)
	local running = rig.Speed > 1.5
	local h = rig.Height

	local lift, pitch, yaw, roll, stretch = 0, 0, 0, 0, 0
	if running then
		-- Hop: bounce off the ground, lean into the run, stretch in the air and squash on landing
		rig.Phase += dt * (7 + rig.Speed * 0.35)
		local bounce = math.abs(math.sin(rig.Phase))
		lift = bounce * h * 0.22
		pitch = -0.12 - 0.1 * math.cos(rig.Phase * 2)
		roll = math.sin(rig.Phase) * 0.06
		stretch = (bounce - 0.5) * 0.12
	else
		-- Idle: breathe and bob, and now and then a quick head-turn twitch
		rig.Phase += dt * 2.2
		lift = (math.sin(rig.Phase) * 0.5 + 0.5) * h * 0.03
		stretch = math.sin(rig.Phase) * 0.025
		if now >= rig.TwitchAt then
			rig.TwitchStart = now
			rig.TwitchAt = now + 1.5 + math.random() * 3.5
			rig.TwitchSign = if math.random() < 0.5 then -1 else 1
		end
		local age = now - rig.TwitchStart
		if age < 0.35 then
			yaw = math.sin(age / 0.35 * math.pi * 2) * 0.25 * rig.TwitchSign -- a quick look left-right
		end
	end
	rig.Model:ScaleTo(rig.BaseScale * (1 + stretch))
	rig.Model:PivotTo(ball.CFrame * rig.Offset * CFrame.new(0, lift, 0) * CFrame.Angles(pitch, yaw, roll))
end

---------------------------------------------------------------------------------------------------
-- Job boxes (the box in the arena during the BOX stage)

local function captureBoxArt(rig: BoxRig)
	for _, name in { "BoxArt", "AnimalArt" } do
		local art = rig.Model:FindFirstChild(name)
		if art and art:IsA("Model") and not rig.Art[art] then
			rig.Art[art] = art:GetPivot()
		end
	end
end

local function addBox(model: Instance)
	if not model:IsA("Model") or boxes[model] then
		return
	end
	local rig: BoxRig = {
		Model = model,
		Art = {},
		LastAnger = 0,
		SquishUntil = 0,
		Seed = math.random() * 100,
	}
	captureBoxArt(rig)
	boxes[model] = rig
end

local function updateBox(rig: BoxRig, now: number)
	local model = rig.Model
	if model:GetAttribute("Done") then
		return -- the server is shrinking it into your arms
	end
	captureBoxArt(rig)
	local anger = (model:GetAttribute("Anger") :: number?) or 0
	if anger < rig.LastAnger - 0.5 then
		rig.SquishUntil = now + 0.3 -- it calmed down: someone petted it
	end
	rig.LastAnger = anger
	local fury = math.clamp(anger / 100, 0, 1)
	local t = now + rig.Seed

	for art, home in rig.Art do
		if not art.Parent then
			rig.Art[art] = nil
			continue
		end
		local isAnimal = art.Name == "AnimalArt"
		local offset: CFrame
		if isAnimal then
			-- The animal strains and thrashes more the angrier it is, and squishes when petted
			local thrash = fury * fury
			local squish = if now < rig.SquishUntil then math.sin((rig.SquishUntil - now) / 0.3 * math.pi) else 0
			local hop = if anger >= 75 then math.abs(math.sin(t * 16)) * 0.35 else 0
			offset = CFrame.new(0, hop - squish * 0.25 + math.sin(t * 2) * 0.05, 0)
				* CFrame.Angles(0, math.sin(t * 9) * 0.35 * thrash, math.sin(t * 13) * 0.2 * thrash)
		else
			-- The box rattles when the animal gets really mad
			local rattle = math.max(0, fury - 0.4) / 0.6
			offset = CFrame.new(math.sin(t * 31) * 0.08 * rattle, 0, 0)
				* CFrame.Angles(0, 0, math.sin(t * 23) * 0.06 * rattle)
		end
		art:PivotTo(home * offset)
	end
end

---------------------------------------------------------------------------------------------------
-- Gruff and spinners

local gruffModel: Model? = nil
local gruffHome: CFrame? = nil
local hat: BasePart? = nil
local hatOffset: CFrame? = nil

local function updateGruff(now: number)
	local model, home = gruffModel, gruffHome
	if not (model and home and model.Parent) then
		return
	end
	-- Look at the nearest player within 30 studs (turning at most 60 degrees either way)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local yaw = 0
	if root then
		local toPlayer = home:PointToObjectSpace(root.Position)
		if toPlayer.Magnitude < 30 then
			yaw = math.clamp(math.atan2(-toPlayer.X, -toPlayer.Z), -1, 1)
		end
	end
	local target = home * CFrame.new(0, math.sin(now * 1.6) * 0.12, 0) * CFrame.Angles(0, yaw, 0)
	local current = model:GetPivot()
	local pose = current:Lerp(target, 0.1)
	model:PivotTo(pose)
	-- His cap rides along (unless a tiger just knocked it flying)
	local cap, capOffset = hat, hatOffset
	if cap and capOffset and cap.Anchored then
		cap.CFrame = pose * capOffset
	end
end

local function findGruff()
	task.spawn(function()
		local map = Workspace:WaitForChild("GrayboxMap")
		local model = map:WaitForChild("GruffModel", 10)
		local cap = map:WaitForChild("GruffHat", 10)
		if model and model:IsA("Model") then
			gruffModel = model
			gruffHome = model:GetPivot()
			if cap and cap:IsA("BasePart") then
				hat = cap
				hatOffset = model:GetPivot():ToObjectSpace(cap.CFrame)
			end
		end
	end)
end

local function addSpinner(instance: Instance)
	if instance:IsA("Model") and instance:GetAttribute("Spin") and not spinners[instance] then
		spinners[instance] = instance:GetPivot()
	end
end

---------------------------------------------------------------------------------------------------

function Animate.Start()
	for _, ball in CollectionService:GetTagged("Critter") do
		addCritter(ball)
	end
	CollectionService:GetInstanceAddedSignal("Critter"):Connect(addCritter)
	CollectionService:GetInstanceRemovedSignal("Critter"):Connect(removeCritter)

	for _, model in CollectionService:GetTagged("JobBox") do
		addBox(model)
	end
	CollectionService:GetInstanceAddedSignal("JobBox"):Connect(addBox)
	CollectionService:GetInstanceRemovedSignal("JobBox"):Connect(function(model)
		boxes[model :: Model] = nil
	end)

	findGruff()
	for _, instance in Workspace:GetDescendants() do
		addSpinner(instance)
	end
	Workspace.DescendantAdded:Connect(addSpinner)

	RunService.RenderStepped:Connect(function(dt: number)
		local now = os.clock()
		for ball, rig in critters do
			if ball.Parent then
				updateCritter(rig, dt, now)
			else
				removeCritter(ball)
			end
		end
		for _, rig in boxes do
			updateBox(rig, now)
		end
		updateGruff(now)
		for model, home in spinners do
			if model.Parent then
				model:PivotTo(home * CFrame.new(0, math.sin(now * 2) * 0.15, 0) * CFrame.Angles(0, now * 1.5, 0))
			else
				spinners[model] = nil
			end
		end
	end)
end

return Animate
