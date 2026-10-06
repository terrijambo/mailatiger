--!strict
-- The delivery streak: box animals well (Config.Progression.Streak.MinStars or better) again and again and
-- each one pays more (x1.125, x1.25 ... up to x2). A worse box, getting launched, or quitting a job resets
-- it. It's kept only while you're in the server, and shown on the HUD (player attribute "Streak").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ChallengeService = require(script.Parent.ChallengeService)
local Remotes = require(script.Parent.Remotes)

local Tuning = Config.Progression.Streak

local StreakService = {}

local streaks: { [Player]: number } = {}

-- Pay multiplier for a streak this long
function StreakService.MultFor(count: number): number
	return math.min(Tuning.Max, 1 + Tuning.PerStep * math.max(0, count - 1))
end

local function set(player: Player, count: number)
	streaks[player] = count
	player:SetAttribute("Streak", count)
end

-- A box was finished: returns the pay multiplier for it
function StreakService.OnBox(player: Player, stars: number): number
	if stars < Tuning.MinStars then
		StreakService.Break(player, "a box under " .. Tuning.MinStars .. " stamps")
		return 1
	end
	local count = (streaks[player] or 0) + 1
	set(player, count)
	local mult = StreakService.MultFor(count)
	Remotes.Notify:FireClient(player, "Streak", { Count = count, Mult = mult })
	ChallengeService.Track(player, "Streak", { Count = count })
	return mult
end

-- Launched, quit, or a weak box: back to zero (says so if the streak was worth something)
function StreakService.Break(player: Player, why: string)
	local count = streaks[player] or 0
	if count >= 2 then
		Remotes.Notify:FireClient(player, "StreakLost", { Count = count, Why = why })
	end
	set(player, 0)
end

function StreakService.Start()
	Players.PlayerRemoving:Connect(function(player)
		streaks[player] = nil
	end)
end

return StreakService
