--!strict
-- The "Welcome back" card when a returning player joins:
--   * Your chute kept working: coins for the time you were away (Config.Progression.Offline)
--   * "New this week": the Config/News.luau lines, once per update
-- Brand-new players get neither (their first visit starts with an empty screen and Gruff's walkthrough).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Remotes = require(script.Parent.Remotes)

local WelcomeService = {}

-- Coins your chute earned while you were away, for a save last seen at `lastSeen`
local function offlineCoins(player: Player, lastSeen: number): (number, number)
	local tuning = Config.Progression.Offline
	if lastSeen <= 0 then
		return 0, 0 -- (older save: we don't know when they left)
	end
	local minutes = math.floor((os.time() - lastSeen) / 60)
	if minutes < tuning.MinMinutes then
		return 0, minutes
	end
	local counted = math.min(minutes, tuning.MaxMinutes)
	return math.floor(Economy.ChuteRate(player) * counted * tuning.Rate), minutes
end

local function welcome(player: Player, lastSeen: number)
	local profile = DataService.Get(player)
	if not profile or not player.Parent or profile.Mailed <= 0 then
		return
	end
	local data: { [string]: any } = {}

	local coins, minutes = offlineCoins(player, lastSeen)
	if coins > 0 then
		Economy.AddCoins(player, coins, "Offline")
		Analytics.Custom(player, "OfflinePay", coins, Analytics.Segment(player))
		data.Coins = coins
		data.Minutes = math.min(minutes, Config.Progression.Offline.MaxMinutes)
		data.MaxedOut = minutes >= Config.Progression.Offline.MaxMinutes
	end

	local news = Config.News
	if profile.NewsSeen ~= news.Id then
		profile.NewsSeen = news.Id
		data.News = { Title = news.Title, Lines = news.Lines }
	end

	if data.Coins or data.News then
		Economy.Sync(player)
		Remotes.Notify:FireClient(player, "WelcomeBack", data)
	end
end

function WelcomeService.Start()
	DataService.Loaded:Connect(function(player: Player, loaded: DataService.Profile)
		-- (`loaded` is a copy made before anything else this session saved, so its LastSeen is when they left)
		local lastSeen = loaded.LastSeen or 0
		task.delay(3, function() -- after the HUD is up, before the daily paycheck popup
			welcome(player, lastSeen)
		end)
	end)
end

return WelcomeService
