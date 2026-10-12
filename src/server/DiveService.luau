--!strict
-- The DIVE (Config/Dive.luau). The client does the move itself (client/Dive.luau) and tells the server, which:
--   * opens a dodge window: animal attacks (DiveService.Hit) and the boss's stomp miss you while it's open
--   * checks for dive-grabs every frame: other modules register a grab check (OnDive) — BoxingService for
--     your own job's animal, WildService for wild ones. Diving into one grabs it, no holding E.
-- DiveService.Hit is the one way an animal attack hits a player: VINE BOOM, thrown away as a ragdoll.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Analytics = require(script.Parent.Analytics)
local Remotes = require(script.Parent.Remotes)

local Dive = Config.Dive

local DiveService = {}

local dodgeUntil: { [Player]: number } = {}
local lastDive: { [Player]: number } = {}
local grabbing: { [Player]: boolean } = {} -- still looking for something to grab on this dive

-- Grab checks: return true if the dive grabbed something (BoxingService and WildService add theirs)
DiveService.OnDive = {} :: { (Player, BasePart) -> boolean }
-- Set by BoxingService: stuns a player (no moving or jumping) for a while
DiveService.Stun = nil :: ((Player, number) -> ())?

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function DiveService.IsDodging(player: Player): boolean
	return os.clock() < (dodgeUntil[player] or 0)
end

-- Busy with an animal (grabbing one, in the BOX screen, or just finished): animals leave you alone
function DiveService.IsEngaged(player: Player): boolean
	if player:GetAttribute("Stage") == "Box" then
		return true
	end
	local safeUntil = player:GetAttribute("SafeUntil")
	return typeof(safeUntil) == "number" and Workspace:GetServerTimeNow() < safeUntil
end

-- Marks a player as busy with an animal for a few seconds (no attacks meanwhile)
function DiveService.Engage(player: Player, seconds: number)
	local now = Workspace:GetServerTimeNow()
	local current = player:GetAttribute("SafeUntil")
	local untilTime = math.max(if typeof(current) == "number" then current else 0, now + seconds)
	player:SetAttribute("SafeUntil", untilTime)
end

-- An animal attack hits `player` from `from`: VINE BOOM, thrown away as a ragdoll. Diving dodges it.
-- kind ("Roar", "Freeze", "Spray", "Charge") adds its own flavor on the player's screen.
-- Returns whether it hit.
function DiveService.Hit(player: Player, from: Vector3, kind: string, attacker: string): boolean
	local root = rootOf(player)
	if not root then
		return false
	end
	if DiveService.IsEngaged(player) then
		return false -- (busy with an animal: the others leave you alone)
	end
	if DiveService.IsDodging(player) then
		Remotes.Notify:FireClient(player, "Dodged", {})
		Analytics.Custom(player, "WildAttack", 1, "Dodged", kind, Analytics.Segment(player))
		Analytics.Milestone(player, "FirstDodge")
		return false
	end
	-- Hit by a wild animal's attack (a big source of "this game is annoying" if it happens too often)
	Analytics.Custom(player, "WildAttack", 1, "Hit", kind, Analytics.Segment(player))
	Analytics.Did(player, "GotHit")
	local attack = Dive.Attack
	local away = Vector3.new(root.Position.X - from.X, 0, root.Position.Z - from.Z)
	away = if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis
	Sfx.Play("VineBoom", root)
	local stun = DiveService.Stun
	if stun then
		stun(player, attack.RagdollSeconds)
	end
	Remotes.Notify:FireClient(player, "Launch", {
		Velocity = away * attack.Out + Vector3.new(0, attack.Up, 0),
		Seconds = attack.RagdollSeconds,
	})
	if kind == "Spray" then
		Remotes.Notify:FireClient(player, "Spray", { Seconds = 3 })
	elseif kind == "Freeze" or kind == "Roar" then
		Remotes.Notify:FireClient(player, kind, {})
	end
	local lines = {
		Roar = "ROAAAR! VINE BOOM!",
		Freeze = "Frozen solid... and VINE BOOMED!",
		Spray = "Pssssht! You got sprayed into ORBIT!",
		Charge = "*WHAM!* Right in the parcel!",
	}
	Remotes.Notify:FireClient(player, "Message", {
		Speaker = attacker,
		Text = `{lines[kind] or "VINE BOOM!"} (Double-jump to dive and dodge!)`,
	})
	return true
end

local function onDive(player: Player)
	local now = os.clock()
	if now - (lastDive[player] or 0) < Dive.Cooldown * 0.8 then
		return -- (a little slack for lag)
	end
	if player:GetAttribute("Frozen") == true or player:GetAttribute("Stage") == "Box" or not rootOf(player) then
		return
	end
	lastDive[player] = now
	dodgeUntil[player] = now + Dive.DodgeSeconds
	grabbing[player] = true
end

function DiveService.Start()
	Remotes.Listen(Remotes.Dive, 3, onDive)
	RunService.Heartbeat:Connect(function()
		for player in grabbing do
			local root = rootOf(player)
			if not root or not player.Parent or not DiveService.IsDodging(player) then
				grabbing[player] = nil
				continue
			end
			for _, check in DiveService.OnDive do
				if check(player, root) then
					grabbing[player] = nil
					break
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		dodgeUntil[player] = nil
		lastDive[player] = nil
		grabbing[player] = nil
	end)
end

return DiveService
