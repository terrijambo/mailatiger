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
	Dust: ParticleEmitter, -- puffs kicked up while it runs
	StillFor: number, -- seconds it's been standing still (a sudden dash after a rest pops a "!")
	Boss: Highlight?, -- hourly bosses: a glowing outline that turns red when it's about to blow
	Smooth: CFrame?, -- (bosses) a smoothed copy of the ball's position, so the giant doesn't jitter
	AttackMark: BillboardGui?, -- the red "!!" while a wild animal winds up an attack
	Limbs: { Limb }, -- (generated animals) parts that move on their own: ears, tails, legs, wings, fins
}

-- A part of a generated animal (docs/ANIMAL_PROMPTS.md) that moves on its own, turning around its joint
type Limb = {
	Part: BasePart,
	Rest: CFrame, -- relative to the model's pivot, at its spawn scale
	Joint: Vector3, -- where it turns, relative to the pivot
	Kind: string, -- "Ear", "Tail", "Leg", "Wing", "Fin", "Head", "Beak" (ears and beaks ride on the head)
	Side: number, -- -1 left, 1 right, 0 middle
	Front: boolean,
}

local LIMB_KINDS = { "Ear", "Tail", "Leg", "Foot", "Paw", "Wing", "Fin", "Head", "Beak", "Quills" }

-- The moving parts of a generated animal (models made by Studio's mesh generator carry a "Generated" attribute)
local function findLimbs(model: Model): { Limb }
	local limbs: { Limb } = {}
	if model:GetAttribute("Generated") == nil then
		return limbs
	end
	local pivot = model:GetPivot()
	local center = model:GetBoundingBox().Position
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			local kind: string? = nil
			for _, k in LIMB_KINDS do
				if string.find(p.Name, k, 1, true) then
					kind = k
				end
			end
			if kind == "Foot" or kind == "Paw" then
				kind = "Leg"
			elseif kind == "Quills" then
				kind = nil
			end
			if kind then
				local rest = pivot:ToObjectSpace(p.CFrame)
				local half = p.Size / 2
				-- The joint: legs turn at their top, ears at their base, the rest at the end nearest the body
				local joint: Vector3
				if kind == "Leg" then
					joint = rest.Position + Vector3.new(0, half.Y, 0)
				elseif kind == "Ear" then
					joint = rest.Position - Vector3.new(0, half.Y, 0)
				elseif kind == "Head" then
					joint = rest.Position - Vector3.new(0, half.Y * 0.8, 0)
				else
					local toBody = pivot:PointToObjectSpace(center) - rest.Position
					local reach = math.min(half.X, half.Y, half.Z) + 0.4 * math.max(half.X, half.Y, half.Z)
					joint = rest.Position + (if toBody.Magnitude > 0.01 then toBody.Unit * reach else Vector3.zero)
				end
				local side = if string.find(p.Name, "Left", 1, true)
					then -1
					elseif string.find(p.Name, "Right", 1, true) then 1
					else 0
				table.insert(limbs, {
					Part = p,
					Rest = rest,
					Joint = joint,
					Kind = kind,
					Side = side,
					Front = string.find(p.Name, "Front", 1, true) ~= nil,
				})
			end
		end
	end
	return limbs
end

-- Turns each limb around its joint for this frame (after the whole model has been placed)
local function moveLimbs(model: Model, limbs: { Limb }, baseScale: number, running: boolean, phase: number, now: number)
	if #limbs == 0 then
		return
	end
	local pivot = model:GetPivot()
	local s = model:GetScale() / baseScale
	-- The head's nod, which the ears and beak ride along with
	local headMove = CFrame.identity
	for _, limb in limbs do
		if limb.Kind == "Head" then
			local joint = limb.Joint * s
			headMove = CFrame.new(joint) * CFrame.Angles(math.sin(now * 1.7) * 0.06, 0, 0) * CFrame.new(-joint)
		end
	end
	for _, limb in limbs do
		local turn = CFrame.identity
		local kind = limb.Kind
		if kind == "Leg" then
			-- paddling while it runs: front and back, left and right out of step
			local offset = (if limb.Front then 0 else math.pi) + (if limb.Side < 0 then 0 else math.pi / 2)
			turn = CFrame.Angles(if running then math.sin(phase * 2 + offset) * 0.7 else 0, 0, 0)
		elseif kind == "Ear" then
			turn = CFrame.Angles(0, 0, limb.Side * (0.08 + 0.1 * math.sin(now * 3 + limb.Side)))
		elseif kind == "Tail" then
			turn = CFrame.Angles(0, math.sin(now * (if running then 14 else 5)) * 0.4, 0)
		elseif kind == "Wing" then
			turn = CFrame.Angles(
				0,
				0,
				limb.Side * math.sin(now * (if running then 16 else 3)) * (if running then 0.6 else 0.1)
			)
		elseif kind == "Fin" then
			turn = CFrame.Angles(0, math.sin(now * 6 + limb.Side) * 0.3, 0)
		end
		local joint = limb.Joint * s
		local rest = CFrame.new(limb.Rest.Position * s) * limb.Rest.Rotation
		local onHead = if kind == "Head" or kind == "Ear" or kind == "Beak" then headMove else CFrame.identity
		limb.Part.CFrame = pivot * onHead * CFrame.new(joint) * turn * CFrame.new(-joint) * rest
	end
end

-- Hourly bosses: what swirls around each one
local BOSS_AURA: { [string]: { Color: Color3, Particle: Color3 } } = {
	Tiger = { Color = Color3.fromRGB(255, 150, 40), Particle = Color3.fromRGB(120, 220, 90) }, -- jungle leaves
	Yeti = { Color = Color3.fromRGB(140, 210, 255), Particle = Color3.fromRGB(250, 252, 255) }, -- snowflakes
	Dragon = { Color = Color3.fromRGB(255, 80, 40), Particle = Color3.fromRGB(255, 160, 50) }, -- embers
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
	-- Shiny: a glowing outline and sparkles. Golden: solid shiny gold, with gold sparkles and a glow.
	-- A boss: glowing outline, a slow swirl of leaves/snow/embers, a light, and a crown floating overhead
	local bossHighlight: Highlight? = nil
	local auraId = ball:GetAttribute("BossAura")
	local aura = if typeof(auraId) == "string" then BOSS_AURA[auraId] else nil
	if aura then
		local outline = Instance.new("Highlight")
		outline.OutlineColor = aura.Color
		outline.FillColor = Color3.fromRGB(255, 40, 40)
		outline.FillTransparency = 1
		outline.Parent = model
		bossHighlight = outline
		local swirl = Instance.new("ParticleEmitter")
		swirl.Color = ColorSequence.new(aura.Particle)
		swirl.Size = NumberSequence.new(0.8, 0.2)
		swirl.Lifetime = NumberRange.new(2, 3)
		swirl.Rate = 25
		swirl.Speed = NumberRange.new(3, 6)
		swirl.SpreadAngle = Vector2.new(180, 180)
		swirl.Rotation = NumberRange.new(0, 360)
		swirl.RotSpeed = NumberRange.new(-120, 120)
		swirl.LightEmission = 0.4
		swirl.Parent = ball
		local light = Instance.new("PointLight")
		light.Color = aura.Color
		light.Range = 40
		light.Brightness = 2
		light.Parent = ball
	end

	local variant = ball:GetAttribute("Variant")
	if variant == "Golden" then
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") then
				p.Color = Color3.fromRGB(255, 200, 40):Lerp(p.Color, 0.2)
				p.Material = Enum.Material.Foil
			end
		end
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 210, 80)
		glow.Range = 14
		glow.Brightness = 2
		glow.Parent = ball
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Color3.fromRGB(255, 220, 90)
		sparkles.Parent = ball
	elseif variant == "Shiny" then
		local outline = Instance.new("Highlight")
		outline.FillColor = Color3.fromRGB(140, 230, 255)
		outline.FillTransparency = 0.75
		outline.OutlineColor = Color3.new(1, 1, 1)
		outline.Parent = model
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Color3.fromRGB(150, 235, 255)
		sparkles.Parent = ball
	end
	local parts = {}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			table.insert(parts, p)
		end
	end
	local _, size = model:GetBoundingBox()
	-- Dust puffs at its feet (only emitted while running, see updateCritter)
	local feet = Instance.new("Attachment")
	feet.Name = "Feet"
	feet.Position = Vector3.new(0, -ball.Size.Y / 2 + 0.3, 0)
	feet.Parent = ball
	local dust = Instance.new("ParticleEmitter")
	dust.Color = ColorSequence.new(Color3.fromRGB(235, 225, 205))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.8) })
	dust.Transparency = NumberSequence.new(0.35, 1)
	dust.Lifetime = NumberRange.new(0.4, 0.7)
	dust.Speed = NumberRange.new(1, 3)
	dust.SpreadAngle = Vector2.new(70, 70)
	dust.Acceleration = Vector3.new(0, 3, 0)
	dust.Rate = 0
	dust.Parent = feet
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
		Dust = dust,
		StillFor = 0,
		Boss = bossHighlight,
		Limbs = findLimbs(model),
	}
end

local function removeCritter(ball: Instance)
	local rig = critters[ball :: BasePart]
	if rig then
		rig.Model:Destroy()
		local feet = rig.Dust.Parent
		if feet then
			feet:Destroy()
		end
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

	-- Dust while running (more the faster it goes)
	rig.Dust.Rate = if running and not hidden then math.clamp(rig.Speed * 1.5, 4, 30) else 0
	-- "!" when it bolts after standing still for a moment
	if running then
		if rig.StillFor > 1 and not hidden then
			local mark = Instance.new("BillboardGui")
			mark.Size = UDim2.fromOffset(60, 60)
			mark.StudsOffsetWorldSpace = Vector3.new(0, h + 1.5, 0)
			mark.AlwaysOnTop = true
			mark.MaxDistance = 90
			local text = Instance.new("TextLabel")
			text.Size = UDim2.fromScale(1, 1)
			text.BackgroundTransparency = 1
			text.Font = Enum.Font.LuckiestGuy
			text.TextScaled = true
			text.TextColor3 = Color3.fromRGB(255, 70, 70)
			text.TextStrokeTransparency = 0
			text.Text = "!"
			text.Parent = mark
			mark.Parent = ball
			task.delay(0.7, function()
				mark:Destroy()
			end)
		end
		rig.StillFor = 0
	else
		rig.StillFor += dt
	end

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
	-- A boss strains against the ropes, lies squashed and trembling once pinned, and pulses red when angry
	local bossOutline = rig.Boss
	if bossOutline then
		if Workspace:GetAttribute("BossPhase") == "Box" then
			-- pinned: squashed and trembling (standing on the floor, not sunk into it)
			lift, pitch, yaw, roll = 0, 0, 0, math.sin(now * 25) * 0.015
			stretch = -0.08
		else
			-- A giant doesn't hop like a hamster: a heavy, swaying stomp
			if running then
				lift = math.abs(math.sin(rig.Phase * 0.5)) * h * 0.035
				pitch = -0.04
				roll = math.sin(rig.Phase * 0.5) * 0.05
				stretch = 0
			end
			local held = Workspace:GetAttribute("BossHeld")
			local need = Workspace:GetAttribute("BossNeed")
			local strain = if typeof(held) == "number"
					and typeof(need) == "number"
					and need > 0
				then math.clamp(held / need, 0, 1)
				else 0
			pitch += 0.18 * strain -- leaning back against the pull
			roll += math.sin(now * 30) * 0.05 * strain -- shaking
			-- STOMP: a crouch, a big leap, and a slam right as the shockwave hits (StompAt is the server time
			-- of the impact). That leap is your cue to jump too.
			local stompAt = ball:GetAttribute("StompAt")
			if typeof(stompAt) == "number" then
				local left = stompAt - Workspace:GetServerTimeNow()
				if left > 0.85 and left <= 1 then
					stretch = -0.1 -- crouching to spring
					pitch = 0
				elseif left > 0 and left <= 0.85 then
					local u = 1 - left / 0.85 -- 0 at take-off, 1 at the slam
					lift = h * 0.9 * math.sin(u * math.pi) ^ 0.7
					stretch = 0.06 * (1 - u)
					pitch = -0.15 + 0.3 * u -- nose up going up, nose down coming down
					roll = 0
				elseif left <= 0 and left > -0.3 then
					stretch = -0.14 * (1 + left / 0.3) -- squashed flat by the landing
					lift = 0
				end
			end
		end
		local anger = Workspace:GetAttribute("BossAnger")
		bossOutline.FillTransparency = if typeof(anger) == "number" and anger >= 70
			then 0.55 + 0.3 * math.sin(now * 10)
			else 1
	end
	-- A wild animal winding up an attack (WildService): crouch, shake, and a red "!!" (dive or back off!)
	local attackAt = ball:GetAttribute("AttackAt")
	if typeof(attackAt) == "number" and Workspace:GetServerTimeNow() < attackAt then
		stretch = -0.12
		roll += math.sin(now * 45) * 0.09
		if not rig.AttackMark then
			local mark = Instance.new("BillboardGui")
			mark.Size = UDim2.fromOffset(80, 60)
			mark.StudsOffsetWorldSpace = Vector3.new(0, h + 2, 0)
			mark.AlwaysOnTop = true
			mark.MaxDistance = 120
			local text = Instance.new("TextLabel")
			text.Size = UDim2.fromScale(1, 1)
			text.BackgroundTransparency = 1
			text.Font = Enum.Font.LuckiestGuy
			text.TextScaled = true
			text.TextColor3 = Color3.fromRGB(255, 50, 50)
			text.TextStrokeTransparency = 0
			text.Text = "!!"
			text.Parent = mark
			mark.Parent = ball
			rig.AttackMark = mark
		end
	elseif rig.AttackMark then
		rig.AttackMark:Destroy()
		rig.AttackMark = nil
	end
	rig.Model:ScaleTo(rig.BaseScale * (1 + stretch))
	local base = ball.CFrame
	if bossOutline then
		-- (the server moves the ball in small steps; glide between them)
		local smooth = rig.Smooth or base
		smooth = smooth:Lerp(base, math.min(1, dt * 8))
		rig.Smooth = smooth
		base = smooth
	end
	rig.Model:PivotTo(base * rig.Offset * CFrame.new(0, lift, 0) * CFrame.Angles(pitch, yaw, roll))
	moveLimbs(rig.Model, rig.Limbs, rig.BaseScale, running, rig.Phase, now)
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
