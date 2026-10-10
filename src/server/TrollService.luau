--!strict
-- Troll items (list and numbers in src/shared/Config/Trolls.luau): bought at the Rebirth Market once you reach
-- their level, used from the hotbar. The server checks everything: you own it, it's off cooldown, and it only
-- affects players on a Chaos Mode job (the opt-in PvP mode) and their animals.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Analytics = require(script.Parent.Analytics)
local BoxingService = require(script.Parent.BoxingService)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local ChallengeService = require(script.Parent.ChallengeService)
local Remotes = require(script.Parent.Remotes)
local Sfx = require(ReplicatedStorage.Shared.Sfx)

local Trolls = Config.Trolls
type Troll = typeof(Trolls.List[1])

local TrollService = {}

local lastUse: { [Player]: { [string]: number } } = {}
-- Slowdowns from stink clouds and glue: player -> { multiplier, until }
local slowed: { [Player]: { Mult: number, Until: number } } = {}
local folder: Folder

local function say(player: Player, speaker: string, text: string)
	Remotes.Notify:FireClient(player, "Message", { Speaker = speaker, Text = text })
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Chaos players (other than `me`) within `radius` of `position`
local function chaosPlayersNear(position: Vector3, radius: number, me: Player): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if
			player ~= me
			and root
			and BoxingService.InChaos(player)
			and (root.Position - position).Magnitude <= radius
		then
			table.insert(list, player)
		end
	end
	return list
end

local function slow(player: Player, mult: number, seconds: number)
	local current = slowed[player]
	if not current or current.Mult > mult or current.Until < os.clock() then
		slowed[player] = { Mult = mult, Until = os.clock() + seconds }
	else
		current.Until = math.max(current.Until, os.clock() + seconds)
	end
end

-- Where your feet are
local function groundUnder(root: BasePart): Vector3
	return root.Position - Vector3.new(0, 3, 0)
end

local function part(props: { [string]: any }): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = folder
	return p
end

---------------------------------------------------------------------------------------------------
-- The items

local EFFECTS: { [string]: (Player, BasePart, Troll) -> () } = {}

EFFECTS.BananaPeel = function(player, root, troll)
	local peel = part({
		Name = "BananaPeel",
		Size = Vector3.new(2.2, 0.4, 1.4),
		Position = groundUnder(root) + Vector3.new(0, 0.25, 0),
		Color = Color3.fromRGB(255, 225, 70),
		CanTouch = true,
	})
	Debris:AddItem(peel, troll.Duration)
	local armedAt = os.clock() + 0.8 -- so you don't slip on your own peel as you drop it
	peel.Touched:Connect(function(hit)
		local victim = Players:GetPlayerFromCharacter(hit.Parent)
		if not victim or victim == player or os.clock() < armedAt or not peel.Parent then
			return
		end
		if BoxingService.InChaos(victim) then
			peel:Destroy()
			BoxingService.Stun(victim, troll.Power)
			Remotes.Notify:FireClient(victim, "Slip", { Seconds = troll.Power })
			say(victim, "CHAOS", `🍌 You slipped on {player.DisplayName}'s banana peel!`)
		end
	end)
end

EFFECTS.StinkBomb = function(player, root, troll)
	local center = groundUnder(root)
	local cloud = part({
		Name = "StinkCloud",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * troll.Radius * 2,
		Position = center,
		Color = Color3.fromRGB(140, 220, 90),
		Transparency = 0.75,
	})
	Debris:AddItem(cloud, troll.Duration)
	local hit: { [Player]: boolean } = {}
	task.spawn(function()
		local stop = os.clock() + troll.Duration
		while os.clock() < stop and cloud.Parent do
			for _, victim in chaosPlayersNear(center, troll.Radius, player) do
				slow(victim, troll.Power, 0.7)
				if not hit[victim] then
					hit[victim] = true
					Remotes.Notify:FireClient(victim, "Spray", { Seconds = 3 })
				end
			end
			BoxingService.SpookNear(center, troll.Radius, player)
			task.wait(0.5)
		end
	end)
end

EFFECTS.GluePuddle = function(player, root, troll)
	local center = groundUnder(root)
	local puddle = part({
		Name = "GluePuddle",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, troll.Radius * 2, troll.Radius * 2),
		CFrame = CFrame.new(center + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(245, 245, 225),
		Transparency = 0.15,
	})
	Debris:AddItem(puddle, troll.Duration)
	task.spawn(function()
		local stop = os.clock() + troll.Duration
		while os.clock() < stop and puddle.Parent do
			for _, victim in chaosPlayersNear(center, troll.Radius, player) do
				slow(victim, troll.Power, 0.5)
			end
			task.wait(0.3)
		end
	end)
end

EFFECTS.TapeBomb = function(player, root, troll)
	local target = BoxingService.AngerNearest(root.Position, troll.Radius, player, troll.Power)
	if target then
		say(target, "CHAOS", `💣 {player.DisplayName} tape-bombed your box! Your animal is furious!`)
		local targetRoot = rootOf(target)
		if targetRoot then
			-- A little tape-wrapped bomb flies over (just for show)
			local bomb = part({
				Name = "TapeBomb",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(1.4, 1.4, 1.4),
				Position = root.Position,
				Color = Color3.fromRGB(60, 60, 70),
			})
			task.spawn(function()
				local from, to = root.Position, targetRoot.Position
				for i = 1, 20 do
					local t = i / 20
					bomb.Position = from:Lerp(to, t) + Vector3.new(0, math.sin(t * math.pi) * 10, 0)
					task.wait()
				end
				bomb:Destroy()
			end)
		end
	else
		say(player, "CHAOS", "Nobody in Chaos Mode is boxing nearby. The bomb fizzled.")
	end
end

EFFECTS.AirHorn = function(player, root, troll)
	for _, victim in chaosPlayersNear(root.Position, troll.Radius, player) do
		local victimRoot = rootOf(victim)
		if victimRoot then
			local flat = victimRoot.Position - root.Position
			local direction = Vector3.new(flat.X, 0, flat.Z)
			direction = if direction.Magnitude > 0.01 then direction.Unit else root.CFrame.LookVector
			Remotes.Notify:FireClient(victim, "Knockback", { Direction = direction, Strength = troll.Power })
			say(victim, "CHAOS", `📯 HOOOONK! {player.DisplayName} air-horned you!`)
		end
	end
	BoxingService.SpookNear(root.Position, troll.Radius, player)
end

---------------------------------------------------------------------------------------------------

local function use(player: Player, trollId: unknown)
	local profile = DataService.Get(player)
	if typeof(trollId) ~= "string" or not profile then
		return
	end
	local troll = Trolls.ById[trollId]
	local effect = EFFECTS[trollId]
	local root = rootOf(player)
	if not troll or not effect or not root or not profile.Trolls[trollId] then
		return
	end
	local mine = lastUse[player]
	if not mine then
		mine = {}
		lastUse[player] = mine
	end
	if os.clock() - (mine[trollId] or -math.huge) < troll.Cooldown then
		return
	end
	mine[trollId] = os.clock()
	Remotes.Notify:FireClient(player, "TrollUsed", { Id = trollId, Cooldown = troll.Cooldown })
	effect(player, root, troll)
	Sfx.Play(`Troll_{trollId}`, root.Position)
	Analytics.Custom(player, `Troll_{trollId}`)
	ChallengeService.Track(player, "Troll", {})
end

-- Buying (from ShopService, "BuyTroll")
function TrollService.Buy(player: Player, trollId: string): boolean
	local profile = DataService.Get(player)
	local troll = Trolls.ById[trollId]
	if not profile or not troll or profile.Trolls[trollId] then
		return false
	end
	if profile.Level < troll.Level then
		say(player, "Rebirth Market", `🔒 The {troll.DisplayName} unlocks at Level {troll.Level}.`)
		return false
	end
	if not Economy.TrySpend(player, troll.Price, `Troll_{trollId}`) then
		say(player, "Rebirth Market", `The {troll.DisplayName} costs {Format.Short(troll.Price)} coins.`)
		return false
	end
	profile.Trolls[trollId] = true
	say(
		player,
		"Rebirth Market",
		`{troll.Emoji} {troll.DisplayName} is in your hotbar! It only works on players in Chaos Mode.`
	)
	Economy.Sync(player)
	return true
end

function TrollService.Start()
	folder = Instance.new("Folder")
	folder.Name = "Trolls"
	folder.Parent = Workspace
	Remotes.Listen(Remotes.Troll, 6, use)

	-- Keep each player's SpeedMult attribute up to date (the client's Movement module applies it)
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for player, entry in slowed do
			if now > entry.Until or not player.Parent then
				slowed[player] = nil
				if player.Parent then
					player:SetAttribute("SpeedMult", nil)
				end
			elseif player:GetAttribute("SpeedMult") ~= entry.Mult then
				player:SetAttribute("SpeedMult", entry.Mult)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastUse[player] = nil
		slowed[player] = nil
	end)
end

return TrollService
