--!strict
-- Each animal's special ability. A behavior is a table of optional hooks that BoxService calls:
--   Start(d)               when the animal is boxed
--   Update(d, now, dt)     every frame while it's carried
--   OnJostle(d, amount)    when the box gets shaken (amount = velocity change in studs/sec)
--   OnBell(d)              when the Post Office door bell rings
-- Tuning numbers live in src/shared/Config/Behaviors.luau.
--
-- To add a new behavior: add a table here, give it an id, and put that id in an animal's Behavior field.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(script.Parent.Types)

type Delivery = Types.Delivery

-- Things behaviors are allowed to do, supplied by BoxService.
export type Api = {
	Damage: (d: Delivery, amount: number) -> (),
	AddRage: (d: Delivery, amount: number) -> (),
	Impulse: (d: Delivery, direction: Vector3, strength: number) -> (), -- kick the box (client simulates it)
	Effect: (player: Player, kind: string, data: { [string]: any }) -> (), -- screen effect on one player
	Say: (player: Player, speaker: string, text: string) -> (),
	Escape: (d: Delivery) -> (), -- the animal gets out (ends the delivery)
	Stun: (player: Player, seconds: number) -> (),
	Boost: (player: Player, mult: number, seconds: number) -> (),
	GruffHat: BasePart,
}

export type Behavior = {
	Start: ((d: Delivery) -> ())?,
	Update: ((d: Delivery, now: number, dt: number) -> ())?,
	OnJostle: ((d: Delivery, amount: number) -> ())?,
	OnBell: ((d: Delivery) -> ())?,
}

local Tuning = Config.Behaviors
local api: Api

local Behaviors: { [string]: Behavior } = {}

---------------------------------------------------------------------------------------------------
-- Helpers

local function randomBetween(min: number, max: number): number
	return min + math.random() * (max - min)
end

-- Returns true once every min..max seconds. The first interval starts the first time it's called.
local function every(d: Delivery, key: string, now: number, min: number, max: number?): boolean
	local nextTime = d.State[key]
	if nextTime == nil then
		d.State[key] = now + randomBetween(min, max or min)
		return false
	end
	if now < nextTime then
		return false
	end
	d.State[key] = now + randomBetween(min, max or min)
	return true
end

local function nameOf(d: Delivery): string
	return Config.Animals.ById[d.AnimalId].DisplayName
end

local function carrierRoot(d: Delivery): BasePart?
	local root = d.Hold.Parent
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function randomFlatDirection(): Vector3
	local angle = math.random() * math.pi * 2
	return Vector3.new(math.cos(angle), 0, math.sin(angle))
end

local effectsFolder: Folder? = nil
local function effects(): Folder
	if effectsFolder then
		return effectsFolder
	end
	local folder = Instance.new("Folder")
	folder.Name = "AnimalEffects"
	folder.Parent = Workspace
	effectsFolder = folder
	return folder
end

-- Drops a flat pad on the ground under the carrier (ice patches, rainbow trail). Removed after `lifetime`.
local function dropPad(d: Delivery, size: Vector3, color: Color3, material: Enum.Material, lifetime: number): Part?
	local root = carrierRoot(d)
	if not root then
		return nil
	end
	local ignore: { Instance } = { d.Box, effects() }
	if d.Player.Character then
		table.insert(ignore, d.Player.Character)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local result = Workspace:Raycast(root.Position, Vector3.new(0, -20, 0), params)
	if not result then
		return nil
	end

	local pad = Instance.new("Part")
	pad.Anchored = true
	pad.CanCollide = false
	pad.Size = size
	pad.Color = color
	pad.Material = material
	pad.CFrame = CFrame.new(result.Position + Vector3.new(0, size.Y / 2, 0))
	pad.Parent = effects()
	Debris:AddItem(pad, lifetime)
	return pad
end

-- Calls `onTouch` once per other player who steps on the pad.
local function onOtherPlayerTouch(pad: Part, carrier: Player, onTouch: (Player) -> ())
	local touched: { [Player]: boolean } = {}
	pad.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player and player ~= carrier and not touched[player] then
			touched[player] = true
			onTouch(player)
		end
	end)
end

---------------------------------------------------------------------------------------------------
-- Tier 1: Backyard

Behaviors.Slosh = { -- Goldfish
	Update = function(d: Delivery, now: number, dt: number)
		local t = Tuning.Slosh
		if math.abs(d.Box.AssemblyAngularVelocity.Y) > t.SpinThreshold then
			api.AddRage(d, t.RagePerSecond * dt)
			api.Damage(d, t.DamagePerSecond * dt)
			if every(d, "SloshMessage", now, 4) then
				api.Say(d.Player, nameOf(d), "Sloshhh... the water's spilling! Turn slower!")
			end
		end
	end,
}

Behaviors.Poke = { -- Hedgehog
	Update = function(d: Delivery, now: number, _dt: number)
		if every(d, "Poke", now, Tuning.Poke.Interval) then
			api.Damage(d, Tuning.Poke.Damage)
		end
	end,
}

Behaviors.Squawk = { -- Parrot
	Update = function(d: Delivery, now: number, _dt: number)
		local t = Tuning.Squawk
		if every(d, "Squawk", now, t.Interval) then
			api.AddRage(d, t.Rage)
			local highlight = Instance.new("Highlight")
			highlight.FillColor = Color3.fromRGB(80, 220, 120)
			highlight.Parent = d.Box
			Debris:AddItem(highlight, t.HighlightSeconds)
			api.Say(d.Player, nameOf(d), "SQUAWK! EVERYBODY LOOK AT US!")
		end
	end,
}

---------------------------------------------------------------------------------------------------
-- Tier 2: Farm

Behaviors.LayEgg = { -- Chicken
	Update = function(d: Delivery, now: number, _dt: number)
		local t = Tuning.LayEgg
		if every(d, "Egg", now, t.Interval) and d.Rage < t.MaxRage then
			local bonus = math.round(Config.Animals.ById[d.AnimalId].BaseValue * t.BonusFraction)
			d.Bonus += bonus

			local egg = Instance.new("Part")
			egg.Shape = Enum.PartType.Ball
			egg.Size = Vector3.new(0.9, 0.9, 0.9)
			egg.Color = Color3.fromRGB(255, 250, 235)
			egg.CollisionGroup = "Boxes"
			egg.Position = d.Box.Position - Vector3.new(0, 2, 0)
			egg.Parent = effects()
			Debris:AddItem(egg, 5)

			api.Say(d.Player, nameOf(d), `*bawk* An egg! +{bonus} bonus coins on delivery.`)
		end
	end,
}

Behaviors.Headbutt = { -- Goat
	Update = function(d: Delivery, now: number, _dt: number)
		local t = Tuning.Headbutt
		local root = carrierRoot(d)
		if root and every(d, "Headbutt", now, t.MinInterval, t.MaxInterval) then
			api.Impulse(d, root.CFrame.LookVector, t.Strength)
		end
	end,
}

Behaviors.Spray = { -- Skunk
	Update = function(d: Delivery, now: number, _dt: number)
		local t = Tuning.Spray
		if d.Rage >= t.MinRage and every(d, "Spray", now, t.Interval) then
			api.Effect(d.Player, "Spray", { Seconds = t.Seconds })
			api.Say(d.Player, nameOf(d), "Pssssssht. Oh no. OH NO.")
		end
	end,
}

---------------------------------------------------------------------------------------------------
-- Tier 3: Wild

Behaviors.StealStamp = { -- Monkey
	Update = function(d: Delivery, now: number, _dt: number)
		local t = Tuning.StealStamp
		if every(d, "Steal", now, t.Interval) and math.random() < t.Chance then
			d.PayoutMult *= t.PayoutMult
			api.Say(d.Player, nameOf(d), "*the monkey swiped a stamp* Payout down 10%!")
		end
	end,
}

Behaviors.Hop = { -- Kangaroo
	Update = function(d: Delivery, now: number, _dt: number)
		local t = Tuning.Hop
		if every(d, "Hop", now, t.MinInterval, t.MaxInterval) then
			d.ImpactGraceUntil = now + t.GraceSeconds -- the hop itself doesn't hurt; landing on something might
			api.Impulse(d, Vector3.yAxis, t.Strength)
		end
	end,
}

Behaviors.InnerDamage = { -- Porcupine
	Update = function(d: Delivery, now: number, _dt: number)
		local t = Tuning.InnerDamage
		if every(d, "Quills", now, t.Interval) then
			api.Damage(d, t.BaseDamage + d.Rage * t.DamagePerRage)
		end
	end,
}

Behaviors.Slide = { -- Penguin
	Update = function(d: Delivery, now: number, _dt: number)
		local t = Tuning.Slide
		if d.Box.AssemblyLinearVelocity.Y < t.DownhillSpeed then
			d.SpeedMult = t.SpeedMult
			d.State.SlideUntil = now + 1
		elseif now > (d.State.SlideUntil or 0) then
			d.SpeedMult = 1
		end
	end,
}

Behaviors.Squeeze = { -- Octopus
	Update = function(d: Delivery, _now: number, dt: number)
		local t = Tuning.Squeeze
		if d.HP / d.MaxHP < t.BelowHP and math.random() < t.ChancePerSecond * dt then
			api.Say(d.Player, nameOf(d), "*squelch* The octopus squeezed out through a crack!")
			api.Escape(d)
		end
	end,
}

---------------------------------------------------------------------------------------------------
-- Tier 4: Apex

Behaviors.Snap = { -- Crocodile
	Update = function(d: Delivery, now: number, _dt: number)
		local t = Tuning.Snap
		if every(d, "Snap", now, t.MinInterval, t.MaxInterval) then
			api.Impulse(d, randomFlatDirection(), t.Strength)
			api.AddRage(d, t.Rage)
		end
	end,
}

Behaviors.Pound = { -- Gorilla
	Start = function(d: Delivery)
		d.RattleDamageMult = Tuning.Pound.RattleDamageMult
		d.RattleImpulseMult = Tuning.Pound.RattleImpulseMult
	end,
}

local function wakeBear(d: Delivery)
	d.State.Asleep = false
	d.RageLocked = false
	d.WeightMult = 1
	api.AddRage(d, Tuning.Sleep.WakeRage)
	api.Say(d.Player, nameOf(d), "GRRRAAAH! You woke the bear!")
end

Behaviors.Sleep = { -- Bear
	Update = function(d: Delivery, now: number, _dt: number)
		local t = Tuning.Sleep
		if not d.State.Asleep and now - d.StartTime > t.AfterSeconds and d.Rage < t.MaxRage then
			d.State.Asleep = true
			d.RageLocked = true
			d.WeightMult = t.WeightMult
			api.Say(d.Player, nameOf(d), "Zzz... the bear fell asleep. It's SO heavy. Don't wake it.")
		end
	end,
	OnJostle = function(d: Delivery, amount: number)
		if d.State.Asleep and amount > Tuning.Sleep.WakeJostle then
			wakeBear(d)
		end
	end,
	OnBell = function(d: Delivery)
		if d.State.Asleep then
			wakeBear(d)
		end
	end,
}

local function roar(d: Delivery)
	local t = Tuning.Roar
	local origin = d.Box.Position
	api.Effect(d.Player, "Roar", {})
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if other ~= d.Player and root and (root.Position - origin).Magnitude <= t.Radius then
			api.Stun(other, t.StunSeconds)
			api.Effect(other, "Roar", {})
		end
	end
end

local hatFlying = false
local function knockOffGruffsHat()
	if hatFlying then
		return
	end
	hatFlying = true
	local hat = api.GruffHat
	local home = hat.CFrame
	hat.Anchored = false
	hat.AssemblyLinearVelocity = Vector3.new(-25, 45, randomBetween(-10, 10))
	hat.AssemblyAngularVelocity = Vector3.new(randomBetween(-10, 10), randomBetween(-10, 10), randomBetween(-10, 10))
	task.delay(6, function()
		hat.Anchored = true
		hat.CFrame = home
		hatFlying = false
	end)
end

Behaviors.Roar = { -- Tiger
	Update = function(d: Delivery, now: number, _dt: number)
		local t = Tuning.Roar
		if d.Rage >= t.MinRage and every(d, "Roar", now, t.Interval) then
			roar(d)
		end
	end,

	-- "Doorstep Breakout": a maxed-out tiger can burst out right at the Post Office door.
	OnBell = function(d: Delivery)
		if d.Rage >= 100 and math.random() < Tuning.Roar.BreakoutChance then
			roar(d)
			knockOffGruffsHat()
			local origin = d.Box.Position
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root and (root.Position - origin).Magnitude <= 80 then
					api.Effect(player, "Breakout", { Animal = nameOf(d) })
				end
			end
			local lines = Config.Gruff.Breakout
			api.Say(d.Player, "Postmaster Gruff", lines[math.random(1, #lines)])
			api.Escape(d)
		end
	end,
}

---------------------------------------------------------------------------------------------------
-- Tier 6: Silly

Behaviors.Freeze = { -- Yeti
	Update = function(d: Delivery, now: number, _dt: number)
		local t = Tuning.Freeze
		if every(d, "Ice", now, t.Interval) then
			local pad =
				dropPad(d, Vector3.new(6, 0.2, 6), Color3.fromRGB(180, 230, 255), Enum.Material.Ice, t.PatchSeconds)
			if pad then
				onOtherPlayerTouch(pad, d.Player, function(player)
					api.Stun(player, t.FreezeSeconds)
					api.Say(player, "Brrr!", "You stepped on yeti ice. Your feet are frozen!")
				end)
			end
		end
	end,
}

Behaviors.BurnBox = { -- Dragon
	Start = function(d: Delivery)
		local fire = Instance.new("Fire")
		fire.Heat = 6
		fire.Size = 4
		fire.Parent = d.Box
	end,
	Update = function(d: Delivery, _now: number, dt: number)
		local t = Tuning.BurnBox
		local burnRate = (t.ByBox :: { [string]: number })[d.BoxId] or 1
		api.Damage(d, t.DrainPerSecond * burnRate * dt)
	end,
}

Behaviors.Float = { -- Alien
	Update = function(d: Delivery, now: number, _dt: number)
		local t = Tuning.Float
		if every(d, "Float", now, t.Interval) then
			d.State.FloatUntil = now + t.Seconds
			d.Hold.Position = Config.Carry.HoldOffset + Vector3.new(0, t.Height, 0)
			api.Say(d.Player, nameOf(d), "Bleep bloop. *the box floats up*")
		elseif d.State.FloatUntil and now > d.State.FloatUntil then
			d.State.FloatUntil = nil
			d.Hold.Position = Config.Carry.HoldOffset
		end
	end,
}

Behaviors.RainbowTrail = { -- Unicorn
	Update = function(d: Delivery, now: number, _dt: number)
		local t = Tuning.RainbowTrail
		if every(d, "Rainbow", now, t.Interval) then
			local color = Color3.fromHSV((now * 0.5) % 1, 0.7, 1)
			local pad = dropPad(d, Vector3.new(4, 0.2, 4), color, Enum.Material.Neon, t.PadSeconds)
			if pad then
				onOtherPlayerTouch(pad, d.Player, function(player)
					api.Boost(player, t.BoostMult, t.BoostSeconds)
				end)
			end
		end
	end,
}

---------------------------------------------------------------------------------------------------

local module = {}

function module.Init(boxServiceApi: Api)
	api = boxServiceApi
end

function module.Get(behaviorId: string?): Behavior?
	if behaviorId then
		return Behaviors[behaviorId]
	end
	return nil
end

return module
