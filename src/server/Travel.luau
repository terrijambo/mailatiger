--!strict
-- Getting around: travel pads in town take you to an arena, return pads take you back to town.
-- Picking an animal at the Pen also sends you straight to its arena (BoxingService calls Travel.ToArena).

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
