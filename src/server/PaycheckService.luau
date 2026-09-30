--!strict
-- Gruff's daily paycheck: the first time you play each day (UTC), you get coins for showing up.
-- Come back on consecutive days to grow the streak (up to Config.Progression.Paycheck.MaxStreak).
-- Players who stay past midnight get it too (checked every few minutes).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Remotes = require(script.Parent.Remotes)

local Tuning = Config.Progression.Paycheck

local PaycheckService = {}

local function today(): number
	return math.floor(os.time() / 86400)
end

local function pay(player: Player)
	local profile = DataService.Get(player)
	local day = today()
	if not profile or profile.PaycheckDay >= day then
		return
	end
	profile.PaycheckStreak = if profile.PaycheckDay == day - 1 then profile.PaycheckStreak + 1 else 1
	profile.PaycheckDay = day
	local streak = math.min(profile.PaycheckStreak, Tuning.MaxStreak)
	local coins = Economy.BestBaseValue(player) * Tuning.JobsPerDay * streak
	Economy.AddCoins(player, coins, "Paycheck")
	Analytics.Custom(player, "PaycheckStreak", profile.PaycheckStreak)
	local tomorrow = if streak < Tuning.MaxStreak
		then "Come back tomorrow and it goes up."
		else "Max streak! Keep it up."
	Remotes.Notify:FireClient(player, "Message", {
		Speaker = "Postmaster Gruff",
		Text = `Daily paycheck, day {profile.PaycheckStreak} in a row: +{coins} coins. {tomorrow}`,
	})
end

function PaycheckService.Start()
	DataService.Loaded:Connect(function(player: Player)
		task.delay(6, function() -- after the welcome line, so the popups don't pile up
			if player.Parent then
				pay(player)
			end
		end)
	end)
	task.spawn(function()
		while true do
			task.wait(300)
			for _, player in Players:GetPlayers() do
				pay(player)
			end
		end
	end)
end

return PaycheckService
