--!strict
-- Daily and weekly challenges (list and rewards in src/shared/Config/Challenges.luau).
--   * Each new day (UTC) you get 3 dailies; each new week, one weekly. Picked at random from the ones your
--     level can do, so everyone's are a bit different.
--   * The rest of the game reports what you did with ChallengeService.Track(player, kind, details):
--       "Box"    { Stars, Seconds, Chaos }   a box finished
--       "Mail"   { Variant }                 one animal mailed
--       "Order"  {}                          a side order completed
--       "Streak" { Count }                   your delivery streak just reached Count
--       "Troll"  {}                          a troll item used
--   * A finished challenge waits on the Orders board until you press CLAIM (ChallengeService.Claim).
--     All 3 dailies done grows a day streak bonus (paid right away).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Remotes = require(script.Parent.Remotes)

local Challenges = Config.Challenges
type Challenge = typeof(Config.Challenges.Daily[1])
type Profile = DataService.Profile

local ChallengeService = {}

-- Picks `count` challenges from `pool` that this player can do, the same every time for this day/week
local function pick(
	profile: Profile,
	pool: { Challenge },
	count: number,
	seed: number
): { DataService.ChallengeProgress }
	local options = {}
	for _, challenge in pool do
		local levelOk = (challenge.MinLevel or 1) <= profile.Level
		local trollOk = not challenge.NeedsTroll or next(profile.Trolls) ~= nil
		if levelOk and trollOk then
			table.insert(options, challenge)
		end
	end
	local random = Random.new(seed)
	for i = #options, 2, -1 do
		local j = random:NextInteger(1, i)
		options[i], options[j] = options[j], options[i]
	end
	local picked = {}
	for i = 1, math.min(count, #options) do
		table.insert(picked, { Id = options[i].Id, Progress = 0, Done = false })
	end
	return picked
end

-- New dailies on a new day, a new weekly on a new week. Returns whether anything changed.
local function refresh(player: Player, profile: Profile): boolean
	local now = os.time()
	local day, week = Challenges.Day(now), Challenges.Week(now)
	local state = profile.Challenges
	local changed = false
	if state.Day ~= day then
		state.Day = day
		state.Daily = pick(profile, Challenges.Daily, Challenges.DailyCount, day * 7919 + player.UserId)
		if state.LastAllDay < day - 1 then
			state.Streak = 0 -- missed a day
		end
		changed = true
	end
	if state.Week ~= week then
		state.Week = week
		state.Weekly = pick(profile, Challenges.Weekly, 1, week * 104729 + player.UserId)
		changed = true
	end
	return changed
end

local function matches(challenge: Challenge, kind: string, data: { [string]: any }): boolean
	if challenge.Kind ~= kind then
		return false
	end
	if challenge.MinStars and (data.Stars or 0) < challenge.MinStars then
		return false
	end
	if challenge.MaxSeconds and (data.Seconds or math.huge) > challenge.MaxSeconds then
		return false
	end
	if challenge.Chaos and data.Chaos ~= true then
		return false
	end
	if challenge.Variant and data.Variant == nil then
		return false
	end
	return true
end

-- Done: it waits on the board for CLAIM
local function finished(player: Player, entry: DataService.ChallengeProgress, challenge: Challenge, weekly: boolean)
	entry.Done = true
	entry.Claimed = false
	Analytics.Custom(
		player,
		if weekly then "WeeklyChallengeDone" else "DailyChallengeDone",
		1,
		challenge.Id,
		Analytics.Segment(player)
	)
	Analytics.Milestone(player, "FirstChallenge")
	Remotes.Notify:FireClient(player, "ChallengeDone", {
		Text = Challenges.Text(challenge),
		Weekly = weekly,
		Coins = Economy.BestBaseValue(player) * challenge.Jobs,
	})
end

-- CLAIM: pays a finished challenge. Returns whether it paid.
function ChallengeService.Claim(player: Player, weekly: boolean, index: number): boolean
	local profile = DataService.Get(player)
	local list = if profile then (if weekly then profile.Challenges.Weekly else profile.Challenges.Daily) else nil
	local entry = list and list[index]
	local challenge = entry and Challenges.ById[entry.Id]
	if not profile or not entry or not challenge or not entry.Done or entry.Claimed ~= false then
		return false
	end
	entry.Claimed = true
	local coins = Economy.BestBaseValue(player) * challenge.Jobs
	Economy.AddCoins(player, coins, "Challenge")
	return true
end

-- All 3 dailies done: a bonus that grows with each day in a row
local function checkAllDailies(player: Player, profile: Profile)
	local state = profile.Challenges
	if #state.Daily == 0 or state.LastAllDay == state.Day then
		return
	end
	for _, entry in state.Daily do
		if not entry.Done then
			return
		end
	end
	state.Streak = if state.LastAllDay == state.Day - 1 then state.Streak + 1 else 1
	state.LastAllDay = state.Day
	Analytics.Custom(player, "AllDailiesDone", state.Streak, Analytics.Segment(player))
	local minutes = Challenges.AllDailiesMinutes
		+ Challenges.StreakMinutes * math.min(state.Streak, Challenges.MaxStreak)
	local coins = Economy.AddPrize(player, minutes, "AllDailies")
	Remotes.Notify:FireClient(player, "AllDailies", { Streak = state.Streak, Coins = coins })
end

function ChallengeService.Track(player: Player, kind: string, data: { [string]: any }?)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local details: { [string]: any } = data or {}
	local changed = refresh(player, profile)
	for _, scope in
		{ { List = profile.Challenges.Daily, Weekly = false }, { List = profile.Challenges.Weekly, Weekly = true } }
	do
		for _, entry in scope.List do
			local challenge = Challenges.ById[entry.Id]
			if challenge and not entry.Done and matches(challenge, kind, details) then
				if kind == "Streak" then
					entry.Progress = math.max(entry.Progress, details.Count or 0)
				else
					entry.Progress += 1
				end
				changed = true
				if entry.Progress >= challenge.Count then
					entry.Progress = challenge.Count
					finished(player, entry, challenge, scope.Weekly)
				end
			end
		end
	end
	checkAllDailies(player, profile)
	if changed then
		Economy.Sync(player)
	end
end

-- For the board: time left until the dailies change (seconds)
function ChallengeService.SecondsToNewDay(): number
	return 86400 - os.time() % 86400
end

function ChallengeService.Start()
	DataService.Loaded:Connect(function(player: Player)
		local profile = DataService.Get(player)
		if profile and refresh(player, profile) then
			Economy.Sync(player)
		end
	end)
	-- New challenges at midnight (UTC) for players who are online then
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				local profile = DataService.Get(player)
				if profile and refresh(player, profile) then
					Economy.Sync(player)
					Remotes.Notify:FireClient(player, "Message", {
						Speaker = "Postmaster Gruff",
						Text = "New day, new challenges. They're on my Orders board.",
					})
				end
			end
		end
	end)
end

return ChallengeService
