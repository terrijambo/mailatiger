--!strict
-- Getting around: travel pads in town take you to an arena, return pads take you back to town.
-- Picking an animal at the Pen also sends you straight to its arena (BoxingService calls Travel.ToArena).

local Players = game:GetService("Players")

local MapBuilder = require(script.Parent.MapBuilder)

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

function Travel.Start(builtMap: MapBuilder.Map)
	map = builtMap
	for arenaId, pad in map.TravelPads do
		onStep(pad, function(player)
			Travel.ToArena(player, arenaId)
		end)
	end
	for arenaId, pad in map.LiftPads do
		onStep(pad, function(player)
			Travel.ToArena(player, arenaId)
		end)
	end
	for _, pad in map.ReturnPads do
		onStep(pad, Travel.ToTown)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastTeleport[player] = nil
	end)
end

return Travel
