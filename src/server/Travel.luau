--!strict
-- Getting around: MENU > TRAVEL (Gruff, any zone you've unlocked, the boss arena), and the PEN button, a quick
-- teleport between Gruff and your best zone. The Rooftop's elevator pad takes you up to the roof.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Analytics = require(script.Parent.Analytics)
local MapBuilder = require(script.Parent.MapBuilder)
local ProgressionService = require(script.Parent.ProgressionService)
local Remotes = require(script.Parent.Remotes)

local Travel = {}

local map: MapBuilder.Map
local lastTeleport: { [Player]: number } = {}

-- (With streaming on, the ground where you're going may not be loaded on your device yet: ask for it first,
-- waiting up to a couple of seconds, so you don't land in empty space)
function Travel.StreamAround(player: Player, position: Vector3)
	if Workspace.StreamingEnabled then
		pcall(function()
			player:RequestStreamAroundAsync(position, 2)
		end)
	end
end

local function teleport(player: Player, cframe: CFrame)
	local character = player.Character
	if character then
		lastTeleport[player] = os.clock()
		Travel.StreamAround(player, cframe.Position)
		character:PivotTo(cframe)
	end
end

function Travel.ToArena(player: Player, arenaId: string)
	local arena = map.Arenas[arenaId]
	if arena then
		teleport(player, arena.Gate)
	end
end

-- The realm you're in right now (the one you last travelled to; your home realm when you join). Its hub is
-- where "back to town" and the GRUFF button take you (MapBuilder.HubFor).
function Travel.CurrentRealm(player: Player): number
	local here = player:GetAttribute("AtRealm")
	if typeof(here) == "number" then
		return here
	end
	local home = player:GetAttribute("Realm")
	return if typeof(home) == "number" then home else 1
end

function Travel.HubOf(player: Player): MapBuilder.Hub
	return MapBuilder.HubFor(map, Travel.CurrentRealm(player))
end

-- Back to the hub of the realm you're in
function Travel.ToTown(player: Player)
	teleport(player, Travel.HubOf(player).Spawn)
end

-- The GRUFF button: straight to Postmaster Gruff's counter (and the mail chute next to him) at your realm's
-- hub. Not while you're boxing an animal (you can't leave the BOX screen), and not more than once every few
-- seconds.
function Travel.ToGruff(player: Player): boolean
	if player:GetAttribute("Stage") == "Box" or os.clock() - (lastTeleport[player] or 0) < 3 then
		return false
	end
	local hub = Travel.HubOf(player)
	local gruff = hub.Gruff.Position
	local toPlaza = Vector3.new(hub.Center.X - gruff.X, 0, hub.Center.Z - gruff.Z).Unit -- (he faces the plaza)
	local stand = gruff + toPlaza * 14 + Vector3.new(0, 2, 0) -- in front of his counter, facing him
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
	Analytics.Blocked(player, "ZoneLocked", arenaId)
	local def = Config.Arenas.ById[arenaId]
	local realm = ProgressionService.ZoneRealm(arenaId)
	Remotes.Notify:FireClient(player, "Message", {
		Speaker = "Postmaster Gruff",
		Text = `🔒 The {def.DisplayName} is part of the {realm.DisplayName} realm. Buy it at MENU > REALMS!`,
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

-- Your best zone: where your home realm's animals roam (Config/Realms.luau)
function Travel.BestZone(player: Player): string
	local realm = player:GetAttribute("Realm")
	return Config.Realms.At(if typeof(realm) == "number" then realm else 1).Arena
end

-- MENU > REALMS: to a realm you've bought (its island, until each realm has its own map). Not while boxing.
function Travel.ToRealm(player: Player, index: number): boolean
	local home = player:GetAttribute("Realm")
	if player:GetAttribute("Stage") == "Box" or typeof(home) ~= "number" or index < 1 or index > home then
		return false
	end
	player:SetAttribute("AtRealm", index)
	Travel.ToArena(player, Config.Realms.At(index).Arena)
	return true
end

-- The PEN button: at Gruff's -> your best zone; anywhere else -> back to Gruff
function Travel.Quick(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or player:GetAttribute("Stage") == "Box" then
		return
	end
	local nearGruff = (root.Position - MapBuilder.NearestHub(map, root.Position).Gruff.Position).Magnitude < 45
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
-- helping a crew). The glowing barrier at each zone's entrance shows the realm it belongs to.
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
				Analytics.Custom(player, "Fell", 1, "Sea", Analytics.Segment(player))
				continue
			end
			if root then
				-- Analytics: which part of the map they're in (an island, Rebirth Beach, the boss island, or town)
				local p = root.Position
				local here = "Town"
				for arenaId, arena in map.Arenas do
					if p.X > arena.Min.X and p.X < arena.Max.X and p.Z > arena.Min.Z and p.Z < arena.Max.Z then
						here = arenaId
					end
				end
				local beach = Config.World.ById.Beach
				if
					here == "Town"
					and beach
					and Vector3.new(p.X - beach.Center.X, 0, p.Z - beach.Center.Z).Magnitude < beach.Radius
				then
					here = "Beach"
				elseif here == "Town" and (Vector3.new(p.X - bossCenter.X, 0, p.Z - bossCenter.Z)).Magnitude < 125 then
					here = "Boss"
				end
				Analytics.Zone(player, here)
				for arenaId, arena in map.Arenas do
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
