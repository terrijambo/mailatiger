--!strict
-- Getting around: MENU > TRAVEL (Gruff, any zone you've unlocked, the boss arena), and the PEN button, a quick
-- teleport between Gruff and your best zone. The Rooftop's elevator pad takes you up to the roof.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local MapBuilder = require(script.Parent.MapBuilder)
local ProgressionService = require(script.Parent.ProgressionService)
local Remotes = require(script.Parent.Remotes)

local Travel = {}

local map: MapBuilder.Map
local lastTeleport: { [Player]: number } = {}

local function teleport(player: Player, cframe: CFrame)
	local character = player.Character
	if character then
		lastTeleport[player] = os.clock()
		character:PivotTo(cframe)
	end
end

function Travel.ToArena(player: Player, arenaId: string)
	local arena = map.Arenas[arenaId]
	if arena then
		teleport(player, arena.Gate)
	end
end

function Travel.ToTown(player: Player)
	teleport(player, map.TownSpawn)
end

-- The GRUFF button: straight to Postmaster Gruff's counter (and the mail chute next to him). Not while
-- you're boxing an animal (you can't leave the BOX screen), and not more than once every few seconds.
function Travel.ToGruff(player: Player): boolean
	if player:GetAttribute("Stage") == "Box" or os.clock() - (lastTeleport[player] or 0) < 3 then
		return false
	end
	local gruff = map.Gruff.Position
	local stand = Vector3.new(gruff.X, gruff.Y + 2, gruff.Z + 14) -- in front of his counter, facing him
	teleport(player, CFrame.lookAt(stand, Vector3.new(gruff.X, stand.Y, gruff.Z)))
	return true
end

-- Calls `go` when a player steps on the pad (at most once every 2 seconds per player)
local function onStep(pad: BasePart, go: (Player) -> ())
	pad.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player and os.clock() - (lastTeleport[player] or 0) > 2 then
			go(player)
		end
	end)
end

local function lockedMessage(player: Player, arenaId: string)
	local def = Config.Arenas.ById[arenaId]
	Remotes.Notify:FireClient(player, "Message", {
		Speaker = "Postmaster Gruff",
		Text = `🔒 The {def.DisplayName} opens at Level {ProgressionService.ZoneLevel(arenaId)}. Mail more animals to level up!`,
	})
end

-- MENU > TRAVEL: to a zone you've unlocked (not while boxing)
function Travel.ToZone(player: Player, arenaId: string)
	if player:GetAttribute("Stage") == "Box" or not Config.Arenas.ById[arenaId] then
		return
	end
	if not ProgressionService.ZoneOpen(player, arenaId) then
		lockedMessage(player, arenaId)
		return
	end
	Travel.ToArena(player, arenaId)
end

-- Your best zone: the highest one you've unlocked
function Travel.BestZone(player: Player): string
	local best = Config.Arenas.List[1].Id
	for _, def in Config.Arenas.List do
		if ProgressionService.ZoneOpen(player, def.Id) then
			best = def.Id
		end
	end
	return best
end

-- The PEN button: at Gruff's -> your best zone; anywhere else -> back to Gruff
function Travel.Quick(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or player:GetAttribute("Stage") == "Box" then
		return
	end
	local nearGruff = (root.Position - map.Gruff.Position).Magnitude < 45
	if nearGruff then
		Travel.ToZone(player, Travel.BestZone(player))
	else
		Travel.ToGruff(player)
	end
end

-- Travel pads only take you to zones you've unlocked
local function padTo(arenaId: string): (Player) -> ()
	return function(player: Player)
		if ProgressionService.ZoneOpen(player, arenaId) then
			Travel.ToArena(player, arenaId)
		elseif os.clock() - (lastTeleport[player] or 0) > 2 then
			lastTeleport[player] = os.clock()
			lockedMessage(player, arenaId)
		end
	end
end

-- Walking into a zone you haven't unlocked yet sends you back to town (unless you're on a job there, e.g.
-- helping a crew). The glowing barrier at each zone's entrance shows the level it opens at.
local function watchZones()
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.5 then
			return
		end
		elapsed = 0
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			-- Fell into the sea (off a cliff or a bridge): Gruff fishes you out and puts you back in town. (The
			-- boss island puts you back in its arena instead: BossService.)
			local bossCenter = Config.Events.Boss.ArenaCenter
			if
				root
				and root.Position.Y < Config.World.WaterY + 2
				and (Vector3.new(root.Position.X - bossCenter.X, 0, root.Position.Z - bossCenter.Z)).Magnitude > 125
				and player:GetAttribute("Stage") ~= "Box"
			then
				Travel.ToTown(player)
				Remotes.Notify:FireClient(player, "Message", {
					Speaker = "Postmaster Gruff",
					Text = "SPLASH! I fished you out. Mind the edge next time.",
				})
				continue
			end
			if root then
				for arenaId, arena in map.Arenas do
					local p = root.Position
					local inside = p.X > arena.Min.X - 12
						and p.X < arena.Max.X + 12
						and p.Z > arena.Min.Z - 12
						and p.Z < arena.Max.Z + 12
					if
						inside
						and not ProgressionService.ZoneOpen(player, arenaId)
						and player:GetAttribute("JobArena") ~= arenaId
					then
						Travel.ToTown(player)
						lockedMessage(player, arenaId)
					end
				end
			end
		end
	end)
end

function Travel.Start(builtMap: MapBuilder.Map)
	map = builtMap
	for arenaId, pad in map.TravelPads do
		onStep(pad, padTo(arenaId))
	end
	for arenaId, pad in map.LiftPads do
		onStep(pad, padTo(arenaId))
	end
	watchZones()
	for _, pad in map.ReturnPads do
		onStep(pad, Travel.ToTown)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastTeleport[player] = nil
	end)
end

return Travel
