--!strict
-- Saves and loads each player's progress with DataStores.
--
-- Session locking: when a server loads a player it writes a "lock" (its session id + time) into their save.
-- Another server that sees a fresh lock waits instead of loading, so two servers can never both write the
-- same player's data. (Without this, rejoining quickly can duplicate or wipe progress.)
--   * Autosaves every Config.Progression.Save.AutosaveSeconds, and saves + releases the lock on leave.
--   * A lock older than LockTimeoutSeconds is treated as abandoned (the old server crashed).
--   * If DataStores aren't available (Studio without API access), progress works but isn't saved.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Save = Config.Progression.Save

export type Order = {
	AnimalId: string,
	Condition: string, -- "Any", "Stars4", "NoEscape" or "UnderPar"
	Reward: number,
	Done: boolean,
	Claimed: boolean?, -- false = done, waiting for you to press CLAIM (nil on old saves = already paid)
}

-- A taped-up animal in your bag, waiting to be mailed. Its pay is worked out when it's taped; the chute you
-- mail it with can add a bonus.
export type Parcel = {
	AnimalId: string,
	Stars: number,
	Coins: number,
	Seconds: number,
	Escapes: number,
	UnderPar: boolean,
	Stamp: string?, -- stamp or CHAOS label, shown on the receipt
	Variant: string?, -- "Shiny" or "Golden" (Config/Variants.luau)
}

export type ChallengeProgress = { Id: string, Progress: number, Done: boolean, Claimed: boolean? } -- (Claimed as in Order)
export type ChallengeState = {
	Day: number, -- the day (UTC) the dailies were picked
	Daily: { ChallengeProgress },
	Week: number,
	Weekly: { ChallengeProgress },
	Streak: number, -- days in a row with all dailies done
	LastAllDay: number, -- the last day all dailies were done
}

export type Profile = {
	Coins: number,
	Parcels: { Parcel }, -- your bag
	ChuteTier: string, -- your mail chute upgrade (Config.Mail.Chutes id)
	Owned: { [string]: boolean }, -- animals
	Boxes: { [string]: boolean },
	EquippedBox: string,
	Tools: { [string]: number }, -- tool id -> level
	Stamps: { [string]: number }, -- stamp id -> how many you have
	SelectedStamp: string?, -- used on your next job
	Rebirths: number,
	Mailed: number, -- total animals mailed
	Orders: { Order },
	OrdersRefreshAt: number, -- os.time() when new orders come in
	-- Leaderboard stats (kept through rebirths)
	FiveStampJobs: number,
	BestTigerSeconds: number, -- 0 = never mailed a tiger
	RarestIndex: number, -- position in Animals.List of the rarest animal ever mailed (0 = none)
	TutorialDone: boolean, -- finished or skipped Gruff's walkthrough
	Receipts: { string }, -- recent Robux purchase ids already granted (so a retry never pays twice)
	PaycheckDay: number, -- the last day (days since 1970, UTC) you got Gruff's daily paycheck
	PaycheckStreak: number, -- days in a row
	Settings: { [string]: boolean }, -- Music, Sfx, Motion (camera shake/zoom). Missing = on
	Codes: { [string]: boolean }, -- reward codes already redeemed
	-- Progression (kept through rebirths)
	Level: number,
	XP: number, -- progress toward the next level
	Quest: number, -- which of Gruff's main quests you're on (Config/Quests.luau)
	QuestProgress: number, -- count toward the current quest (for "mail N" / "complete N orders" quests)
	OrdersDone: number, -- total side orders completed
	Species: { [string]: number }, -- animal id -> how many you've mailed (the collection)
	Trolls: { [string]: boolean }, -- troll items you own
	-- Diamonds (kept through rebirths)
	Diamonds: number,
	Upgrades: { [string]: number }, -- diamond upgrade id -> level (Config/Diamonds.luau)
	-- Shiny and Golden animals mailed, by animal id (the collection), and the all-time Golden count
	Shinies: { [string]: number },
	Goldens: { [string]: number },
	GoldenMailed: number,
	Challenges: ChallengeState,
	-- This week's leaderboard stats (reset when a new week starts)
	WeekStats: { Week: number, FiveStamps: number, BossWins: number? },
	BossWins: number, -- hourly bosses beaten
	BossKills: { [string]: number }, -- by boss animal id (the boss collection in the Bag)
	LuckyNext: boolean, -- the next job is a guaranteed Shiny (a boss reward)
	-- Invites (Config/Social.luau Invites)
	InvitedBy: number, -- the friend whose invite you joined from (0 = none)
	InvitePaid: boolean, -- that friend has been paid for you
	InviteRewards: number, -- friends you've been paid for
	FollowAsked: number, -- times the Favorite / Get updates card was shown
}

local DataService = {}

local loadedEvent = Instance.new("BindableEvent")
-- Fires (player, profile) once a player's data is ready.
-- CAREFUL: the profile passed along is a COPY (Roblox events copy tables). To change the player's save,
-- use DataService.Get(player) inside the handler.
DataService.Loaded = loadedEvent.Event

local profiles: { [Player]: Profile } = {}
local temporary: { [Player]: boolean } = {}
local sessionId = HttpService:GenerateGUID(false)
local store: DataStore? = nil

local function newProfile(): Profile
	return {
		Coins = 0,
		Parcels = {},
		ChuteTier = "Basic",
		Owned = { Hamster = true },
		Boxes = { Cardboard = true },
		EquippedBox = "Cardboard",
		Tools = {},
		Stamps = {},
		SelectedStamp = nil,
		Rebirths = 0,
		Mailed = 0,
		Orders = {},
		OrdersRefreshAt = 0,
		FiveStampJobs = 0,
		BestTigerSeconds = 0,
		RarestIndex = 0,
		TutorialDone = false,
		Receipts = {},
		PaycheckDay = 0,
		PaycheckStreak = 0,
		Settings = {},
		Codes = {},
		Level = 1,
		XP = 0,
		Quest = 1,
		QuestProgress = 0,
		OrdersDone = 0,
		Species = {},
		Trolls = {},
		Diamonds = 0,
		Upgrades = {},
		Shinies = {},
		Goldens = {},
		GoldenMailed = 0,
		Challenges = { Day = 0, Daily = {}, Week = 0, Weekly = {}, Streak = 0, LastAllDay = 0 },
		WeekStats = { Week = 0, FiveStamps = 0 },
		BossWins = 0,
		BossKills = {},
		LuckyNext = false,
		InvitedBy = 0,
		InvitePaid = false,
		InviteRewards = 0,
		FollowAsked = 0,
	}
end

-- Older saves may be missing fields added in later updates: start from a fresh profile and copy saved values over.
local function reconcile(saved: any): Profile
	local profile = newProfile()
	if type(saved) == "table" then
		for key, value in saved do
			(profile :: any)[key] = value
		end
		-- Saves from before levels existed: start at a level that keeps open every zone you already own
		-- animals in (so nobody gets locked out of what they were playing)
		if saved.Level == nil and type(saved.Owned) == "table" then
			local level = 1
			for animalId in saved.Owned do
				local animal = Config.Animals.ById[animalId]
				local arena = animal and Config.Arenas.ByTier[animal.Tier]
				if arena then
					level = math.max(level, Config.Levels.ZoneLevels[arena.Id] or 1)
				end
			end
			profile.Level = level
		end
		-- Saves from before the tutorial existed: anyone who has mailed something already knows how to play
		if saved.TutorialDone == nil and type(saved.Mailed) == "number" and saved.Mailed > 0 then
			profile.TutorialDone = true
		end
	end
	return profile
end

local function keyFor(player: Player): string
	return `Player_{player.UserId}`
end

local function load(player: Player): Profile?
	local activeStore = store
	if not activeStore then
		temporary[player] = true
		return newProfile()
	end

	for attempt = 1, Save.LoadRetries do
		local canTakeOver = attempt == Save.LoadRetries
		local ok, result = pcall(function()
			return activeStore:UpdateAsync(keyFor(player), function(old: any)
				local lock = if type(old) == "table" then old.Lock else nil
				local lockIsFresh = lock ~= nil and os.time() - lock.Time < Save.LockTimeoutSeconds
				if lock and lock.Session ~= sessionId and lockIsFresh and not canTakeOver then
					return nil -- another server still has this player; cancel and retry shortly
				end
				local data = if type(old) == "table" then old else { Profile = newProfile() }
				data.Lock = { Session = sessionId, Time = os.time() }
				return data
			end)
		end)
		if ok and type(result) == "table" and result.Lock and result.Lock.Session == sessionId then
			return reconcile(result.Profile)
		end
		if not ok then
			warn(`[DataService] Loading {player.Name} failed (attempt {attempt}): {result}`)
		end
		task.wait(3)
	end
	return nil
end

-- Returns whether the save reached Roblox (always false when saving is off)
local function save(player: Player, release: boolean): boolean
	local profile = profiles[player]
	local activeStore = store
	if not profile or not activeStore or temporary[player] then
		return false
	end

	local lostLock = false
	local ok, err = pcall(function()
		activeStore:UpdateAsync(keyFor(player), function(old: any)
			local lock = if type(old) == "table" then old.Lock else nil
			if lock and lock.Session ~= sessionId then
				lostLock = true
				return nil -- another server took over; don't overwrite its newer data
			end
			return {
				Profile = profile,
				Lock = if release then nil else { Session = sessionId, Time = os.time() },
			}
		end)
	end)
	if not ok then
		warn(`[DataService] Saving {player.Name} failed: {err}`)
	end
	if lostLock and not release and player.Parent then
		player:Kick("Your progress was opened on another server. Please rejoin.")
	end
	return ok and not lostLock
end

local function onPlayerAdded(player: Player)
	local profile = load(player)

	if not player.Parent then
		-- They left while we were loading: give the lock back
		if profile then
			profiles[player] = profile
			save(player, true)
			profiles[player] = nil
		end
		temporary[player] = nil
		return
	end
	if not profile then
		player:Kick("Couldn't load your progress. Please rejoin in a minute.")
		return
	end

	profiles[player] = profile
	player:SetAttribute("TemporaryData", temporary[player] == true)
	loadedEvent:Fire(player, profile)
end

function DataService.Get(player: Player): Profile?
	return profiles[player]
end

-- Every loaded profile on this server (used for leaderboards when DataStores are off)
function DataService.GetAll(): { [Player]: Profile }
	return profiles
end

-- Whether saving works this session (leaderboards need it too)
function DataService.IsOnline(): boolean
	return store ~= nil
end

-- Saves right now (used after Robux purchases). True if it saved, or if saving is off this session
-- (Studio without API access), where there's nothing to wait for.
function DataService.SaveNow(player: Player): boolean
	if not profiles[player] then
		return false
	end
	if temporary[player] or not store then
		return true
	end
	return save(player, false)
end

-- Copies the profile onto the player as JSON so their UI can read it.
function DataService.Sync(player: Player)
	local profile = profiles[player]
	if profile then
		player:SetAttribute("Profile", HttpService:JSONEncode(profile))
	end
end

function DataService.Start()
	local ok, result = pcall(function()
		local dataStore = DataStoreService:GetDataStore(Save.StoreName)
		dataStore:GetAsync("__probe") -- fails right away if DataStores aren't allowed here
		return dataStore
	end)
	if ok then
		store = result
	else
		warn(
			"[DataService] DataStores unavailable, so progress WON'T be saved this session. "
				.. "In Studio: publish the place, then Game Settings > Security > Enable Studio Access to API Services. "
				.. tostring(result)
		)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		save(player, true)
		profiles[player] = nil
		temporary[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(Save.AutosaveSeconds)
			for player in profiles do
				task.spawn(save, player, false)
			end
		end
	end)

	-- When the server shuts down, save everyone before it closes (Roblox allows about 30 seconds)
	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				save(player, true)
				pending -= 1
			end)
		end
		local start = os.clock()
		while pending > 0 and os.clock() - start < 25 do
			task.wait()
		end
	end)
end

return DataService
