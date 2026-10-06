--!strict
-- The three leaderboards in town:
--   FastestTiger  quickest tiger job (seconds, lower is better), all time
--   FiveStamps    most 5-stamp jobs THIS WEEK (a fresh board every Monday, so new players can place)
--   Rarest        most Golden animals mailed, all time (the board's id is older than its job)
-- Scores are stored in OrderedDataStores (global across all servers) and the boards refresh every minute.
-- If DataStores are off (Studio without API access), the boards rank just the players in this server.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local MapBuilder = require(script.Parent.MapBuilder)

type Profile = DataService.Profile

local Tuning = Config.Social.Leaderboards

type Board = {
	Id: string,
	Title: string,
	Ascending: boolean, -- true = smaller is better
	Weekly: boolean?, -- a new board every week (Monday, UTC)
	StoreKey: string?, -- the saved board's name, when it differs from Id
	Score: (Profile) -> number, -- 0 = no score yet
	Format: (number) -> string,
}

local BOARDS: { Board } = {
	{
		Id = "FastestTiger",
		Title = "FASTEST TIGER",
		Ascending = true,
		Score = function(profile: Profile)
			return math.round(profile.BestTigerSeconds * 10) -- stored as tenths of a second (whole numbers)
		end,
		Format = function(value: number)
			return string.format("%.1fs", value / 10)
		end,
	},
	{
		Id = "FiveStamps",
		Title = "5-STAMP JOBS THIS WEEK",
		Ascending = false,
		Weekly = true,
		Score = function(profile: Profile)
			local stats = profile.WeekStats
			return if stats.Week == Config.Challenges.Week(os.time()) then stats.FiveStamps else 0
		end,
		Format = function(value: number)
			return `{value} jobs`
		end,
	},
	{
		Id = "BossHunters",
		Title = "⚔️ BOSS HUNTERS THIS WEEK",
		Ascending = false,
		Weekly = true,
		Score = function(profile: Profile)
			local stats = profile.WeekStats
			return if stats.Week == Config.Challenges.Week(os.time()) then stats.BossWins or 0 else 0
		end,
		Format = function(value: number)
			return `{value} boss{if value == 1 then "" else "es"}`
		end,
	},
	{
		Id = "Rarest",
		Title = "🌟 GOLDEN ANIMALS",
		StoreKey = "Golden", -- (a fresh store: the old Rarest scores meant something else)
		Ascending = false,
		Score = function(profile: Profile)
			return profile.GoldenMailed
		end,
		Format = function(value: number)
			return `{value} golden`
		end,
	},
}

type Entry = { Name: string, Value: number }

local LeaderboardService = {}

local map: MapBuilder.Map
local stores: { [string]: OrderedDataStore } = {}
local online = false

-- The store for a board (weekly boards get a new store each week)
local function storeFor(board: Board): OrderedDataStore?
	if not online then
		return nil
	end
	local name = `Leaderboard_{board.StoreKey or board.Id}_{Tuning.StoreVersion}`
	if board.Weekly then
		name ..= `_W{Config.Challenges.Week(os.time())}`
	end
	local store = stores[name]
	if not store then
		local ok, result = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, name)
		if ok then
			store = result
			stores[name] = result
		end
	end
	return store
end

local nameCache: { [number]: string } = {}

local function nameFor(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	local result = if ok then name else `Player {userId}`
	nameCache[userId] = result
	return result
end

-- Writes a player's scores to the global boards
local function upload(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	for _, board in BOARDS do
		local store = storeFor(board)
		local score = board.Score(profile)
		if store and score > 0 then
			local ok, err = pcall(store.SetAsync, store, tostring(player.UserId), score)
			if not ok then
				warn(`[Leaderboards] Couldn't save {board.Id} for {player.Name}: {err}`)
			end
		end
	end
end

local function fetch(board: Board): { Entry }
	local entries: { Entry } = {}
	local store = storeFor(board)
	if store then
		local ok, pages = pcall(store.GetSortedAsync, store, board.Ascending, Tuning.Size, 1)
		if ok then
			for _, item in (pages :: DataStorePages):GetCurrentPage() do
				local userId = tonumber(item.key)
				if userId then
					table.insert(entries, { Name = nameFor(userId), Value = item.value })
				end
			end
		end
		return entries
	end

	-- Offline: rank the players in this server
	for player, profile in DataService.GetAll() do
		local score = board.Score(profile)
		if score > 0 then
			table.insert(entries, { Name = player.DisplayName, Value = score })
		end
	end
	table.sort(entries, function(a, b)
		return if board.Ascending then a.Value < b.Value else a.Value > b.Value
	end)
	while #entries > Tuning.Size do
		table.remove(entries)
	end
	return entries
end

local function draw(board: Board, entries: { Entry })
	local part = map.Leaderboards[board.Id]
	local old = part:FindFirstChild("Board")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Board"
	gui.Face = Enum.NormalId.Right
	gui.CanvasSize = Vector2.new(360, 440)
	gui.LightInfluence = 0

	local lines = { board.Title, if online then "(all servers)" else "(this server only)", "" }
	for rank, entry in entries do
		table.insert(lines, `{rank}. {entry.Name}   {board.Format(entry.Value)}`)
	end
	if #entries == 0 then
		table.insert(lines, "No scores yet. Be the first!")
	end

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(30, 40, 80)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 24
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Text = table.concat(lines, "\n")
	label.Parent = gui
	gui.Parent = part
end

local function refreshAll()
	for _, board in BOARDS do
		draw(board, fetch(board))
	end
end

-- Call after a job is mailed. Jobs take a while, so uploading each time stays well inside DataStore limits.
function LeaderboardService.Submit(player: Player)
	if online then
		task.spawn(upload, player)
	else
		task.defer(refreshAll) -- offline boards: just redraw from this server's players
	end
end

function LeaderboardService.Start(builtMap: MapBuilder.Map)
	map = builtMap

	online = DataService.IsOnline()

	task.spawn(function()
		while true do
			refreshAll()
			task.wait(Tuning.RefreshSeconds)
		end
	end)
end

return LeaderboardService
