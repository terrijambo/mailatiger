--!strict
-- Sends events to Roblox's built-in analytics (Creator Dashboard -> your game -> Analytics).
-- Nothing to set up: it starts showing data once the game is published and people play. Every event, what
-- its value and fields mean, and where to find it is listed in docs/ANALYTICS.md.
--
--   Onboarding funnel  where brand-new players drop off in their first session, step by step
--   Funnels            "CoreLoop" (grab -> boxed -> mailed) and "StampLoop" (dropped in -> collected ->
--                      mailed stamped), once per parcel, for every player
--   Economy            coins and Rebirth Points: where they come from and where they go
--   Progression        chute levels and rebirths
--   Custom             everything else: sessions, returns, quits, BOX screen stats, blocked actions, menus,
--                      purchases, milestones (with the playtime it took to reach them)
--
-- Custom fields: Roblox allows 3 text fields per event (Field01-03 in the dashboard's breakdowns). They're
-- kept to small sets of values (buckets like "L4-7", never raw numbers) so every breakdown stays readable.
-- Event names never contain ids: the id goes in a field, so the game stays far under Roblox's cap on
-- distinct event names.
--
-- Rate limit: Roblox accepts about 120 + 20 x players events a minute per server. This module keeps under
-- 80% of that, and when it's tight it drops the "nice to have" events (BOX screen stats, menus, zones,
-- performance) before the important ones (funnels, economy, sessions, purchases).
--
-- Every call is wrapped so analytics can never break the game (e.g. in Studio, or if Roblox changes the API).
-- In Studio, set the Workspace attribute AnalyticsDebug = true to print every event to the Output window.

local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Remotes = require(script.Parent.Remotes)

local Analytics = {}

---------------------------------------------------------------------------------------------------
-- Sending

local FIELD_KEYS = {
	Enum.AnalyticsCustomFieldKeys.CustomField01.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField02.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField03.Name,
}

local function fields(a: string?, b: string?, c: string?): { [string]: string }?
	if not a and not b and not c then
		return nil
	end
	local result = {}
	if a then
		result[FIELD_KEYS[1]] = string.sub(a, 1, 50)
	end
	if b then
		result[FIELD_KEYS[2]] = string.sub(b, 1, 50)
	end
	if c then
		result[FIELD_KEYS[3]] = string.sub(c, 1, 50)
	end
	return result
end

-- The per-server event budget (refills every second)
local tokens = 100
local refilledAt = os.clock()
local function allow(important: boolean): boolean
	local now = os.clock()
	local perMinute = (120 + 20 * #Players:GetPlayers()) * 0.8
	tokens = math.min(perMinute, tokens + (now - refilledAt) * perMinute / 60)
	refilledAt = now
	-- Nice-to-have events leave a quarter of the budget free for the important ones
	local floor = if important then 1 else perMinute * 0.25
	if tokens < floor then
		return false
	end
	tokens -= 1
	return true
end

local function debugPrint(text: string)
	if RunService:IsStudio() and Workspace:GetAttribute("AnalyticsDebug") == true then
		print(`[Analytics] {text}`)
	end
end

local function safely(important: boolean, describe: string, f: () -> ...any)
	if not allow(important) then
		debugPrint(`(dropped, over budget) {describe}`)
		return
	end
	debugPrint(describe)
	local ok, err = pcall(f)
	if not ok then
		warn(`[Analytics] {err}`)
	end
end

---------------------------------------------------------------------------------------------------
-- Per-player session state (only for this visit; the lasting numbers are in the save)

type State = {
	JoinedClock: number, -- os.clock() when they joined
	NewPlayer: boolean, -- brand new (in the onboarding funnel this visit)
	Onboarding: { [string]: boolean }, -- onboarding steps logged
	LastStep: string, -- the last onboarding step reached
	LastAction: string, -- the last thing they did (for "what were they doing when they quit")
	LastActionClock: number,
	Zone: string, -- Town, Beach, Boss, or an island id
	Zones: { [string]: boolean }, -- zones visited this visit
	Menu: string?, -- the window open on their screen right now
	MenuClock: number,
	Device: string, -- "Touch", "Gamepad", "KeyboardMouse" (from the client), or "Unknown"
	Screen: string,
	TutorialStep: string,
	TutorialClock: number,
	SpawnAt: Vector3?, -- for the "Moved" onboarding step
	ClientValues: number, -- distinct values a client sent (a cap, so nobody can flood the dashboard)
	Prompted: { [string]: number }, -- purchase prompts open: item key -> os.clock()
}

local states: { [Player]: State } = {}

local function newState(): State
	local now = os.clock()
	return {
		JoinedClock = now,
		NewPlayer = false,
		Onboarding = {},
		LastStep = "",
		LastAction = "Joined",
		LastActionClock = now,
		Zone = "Town",
		Zones = {},
		Menu = nil,
		MenuClock = now,
		Device = "Unknown",
		Screen = "Unknown",
		TutorialStep = "",
		TutorialClock = now,
		SpawnAt = nil,
		ClientValues = 0,
		Prompted = {},
	}
end

local function stateOf(player: Player): State
	local state = states[player]
	if not state then
		state = newState()
		states[player] = state
	end
	return state
end

-- Remembers the last thing the player did
function Analytics.Did(player: Player, action: string)
	local state = stateOf(player)
	state.LastAction = action
	state.LastActionClock = os.clock()
end

---------------------------------------------------------------------------------------------------
-- Buckets (small sets of values for the fields)

local function bucket(value: number, edges: { number }, labels: { string }): string
	for index, edge in edges do
		if value < edge then
			return labels[index]
		end
	end
	return labels[#labels]
end

local function today(): number
	return os.time() // 86400 -- (days since 1970, UTC: Roblox's retention days are UTC too)
end

function Analytics.LevelBand(level: number): string
	return bucket(level, { 4, 8, 12, 18 }, { "L1-3", "L4-7", "L8-11", "L12-17", "L18+" })
end

-- How long ago they first joined: D0 (first day), D1, D2-6, D7-29, D30+
function Analytics.DayBand(player: Player): string
	local profile = DataService.Get(player)
	if not profile or (profile.FirstJoin or 0) == 0 then
		return "D?"
	end
	local days = today() - profile.FirstJoin // 86400
	return bucket(days, { 1, 2, 7, 30 }, { "D0", "D1", "D2-6", "D7-29", "D30+" })
end

-- "D0|L1-3": how long they've been playing and how far they've got. Used as a field on many events.
function Analytics.Segment(player: Player): string
	local profile = DataService.Get(player)
	local level = if profile then profile.Level else 1
	local rebirth = if profile and profile.Rebirths > 0 then "|R" else ""
	return `{Analytics.DayBand(player)}|{Analytics.LevelBand(level)}{rebirth}`
end

function Analytics.RarityOf(animalId: string): string
	return Config.Wild.RarityOf[animalId] or "Common"
end

function Analytics.DeviceOf(player: Player): string
	return stateOf(player).Device
end

-- The step of Gruff's walkthrough on their screen ("None" if it isn't running)
function Analytics.TutorialStepOf(player: Player): string
	local step = stateOf(player).TutorialStep
	return if step == "" then "None" else step
end

local function minutesBucket(minutes: number): string
	return bucket(
		minutes,
		{ 1, 3, 5, 10, 20, 40, 90 },
		{ "<1m", "1-3m", "3-5m", "5-10m", "10-20m", "20-40m", "40-90m", "90m+" }
	)
end

-- Minutes played in total (every visit so far, plus this one)
function Analytics.PlayMinutes(player: Player): number
	local profile = DataService.Get(player)
	local saved = if profile then profile.PlaySeconds or 0 else 0
	local state = states[player]
	local now = if state then os.clock() - state.JoinedClock else 0
	return math.floor((saved + now) / 6) / 10 -- (one decimal)
end

-- Where the player is right now, for "where were they when they quit"
local function whereOf(player: Player, state: State): string
	local stage = player:GetAttribute("Stage")
	if stage == "Box" then
		return "BoxScreen"
	elseif stage == "Catch" then
		return "Catching"
	elseif state.Menu then
		return `Menu_{state.Menu}`
	end
	return state.Zone
end

---------------------------------------------------------------------------------------------------
-- Custom events

-- `value` is what the dashboard sums and averages (a count, seconds, minutes...). Fields: see the top.
-- important = false for events that may be dropped when the server is busy.
function Analytics.Custom(
	player: Player,
	name: string,
	value: number?,
	field1: string?,
	field2: string?,
	field3: string?,
	important: boolean?
)
	local amount = value or 1
	safely(important ~= false, `{player.Name} {name} = {amount} [{field1}, {field2}, {field3}]`, function()
		AnalyticsService:LogCustomEvent(player, name, amount, fields(field1, field2, field3))
	end)
end

-- Something the player tried that didn't work (not enough coins, locked island, bag full...). The most
-- direct friction signal: see which reasons pile up, and at which levels.
function Analytics.Blocked(player: Player, reason: string, detail: string?)
	Analytics.Did(player, `Blocked_{reason}`)
	Analytics.Custom(player, "Blocked", 1, reason, detail or "-", Analytics.Segment(player))
end

-- A first time for something, logged once ever per player, with the minutes of playtime it took
function Analytics.Milestone(player: Player, id: string)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local reached = profile.Milestones
	if reached[id] then
		return
	end
	local minutes = Analytics.PlayMinutes(player)
	reached[id] = minutes
	-- Players who were already playing before tracking started have a guessed first-join date
	local how = if profile.FirstJoinGuessed then "Guessed" else "Tracked"
	Analytics.Custom(player, "Milestone", minutes, id, how, Analytics.DayBand(player))
end

---------------------------------------------------------------------------------------------------
-- Onboarding funnel (brand-new players, first visit only)

local STEPS = {
	"Joined", -- save loaded
	"Spawned", -- their character appeared
	"Moved", -- walked a few steps
	"ReachedIsland", -- walked onto an island
	"PickedAnimal", -- grabbed their first animal
	"Caught", -- the BOX screen opened
	"FirstHeart", -- rubbed a heart spot
	"FirstTape", -- taped a seam
	"Taped", -- finished the box
	"Mailed", -- mailed it at the chute
	"TutorialDone", -- finished Gruff's walkthrough
}
local stepNumber: { [string]: number } = {}
for index, name in STEPS do
	stepNumber[name] = index
end

function Analytics.Onboarding(player: Player, step: string)
	local state = states[player]
	local number = stepNumber[step]
	if not state or not state.NewPlayer or not number or state.Onboarding[step] then
		return
	end
	state.Onboarding[step] = true
	state.LastStep = step
	local seconds = math.floor(os.clock() - state.JoinedClock)
	local device = state.Device
	safely(true, `{player.Name} onboarding {number} {step} at {seconds}s`, function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, number, step, fields(device))
	end)
	-- How long each step took to reach (seconds since joining)
	Analytics.Custom(player, "OnboardingSeconds", seconds, step, device)
end

---------------------------------------------------------------------------------------------------
-- Recurring funnels (one run per parcel)

function Analytics.NewLoopId(): string
	return HttpService:GenerateGUID(false)
end

function Analytics.Loop(player: Player, funnel: string, loopId: string?, step: number, stepName: string)
	if not loopId then
		return -- (a parcel from before tracking)
	end
	local device = stateOf(player).Device
	safely(true, `{player.Name} {funnel} {step} {stepName}`, function()
		AnalyticsService:LogFunnelStepEvent(
			player,
			funnel,
			loopId,
			step,
			stepName,
			fields(Analytics.Segment(player), device)
		)
	end)
end

---------------------------------------------------------------------------------------------------
-- Progression

function Analytics.Progress(player: Player, path: string, level: number)
	safely(true, `{player.Name} progression {path} {level}`, function()
		AnalyticsService:LogProgressionCompleteEvent(
			player,
			path,
			level,
			`{path}{level}`,
			fields(Analytics.DayBand(player), minutesBucket(Analytics.PlayMinutes(player)))
		)
	end)
end

---------------------------------------------------------------------------------------------------
-- Economy (coins and Rebirth Points)

local function economy(
	player: Player,
	flow: Enum.AnalyticsEconomyFlowType,
	currency: string,
	amount: number,
	balance: number,
	transaction: string,
	sku: string
)
	if amount <= 0 then
		return
	end
	safely(true, `{player.Name} {currency} {flow.Name} {amount} {sku}`, function()
		AnalyticsService:LogEconomyEvent(
			player,
			flow,
			currency,
			amount,
			balance,
			transaction,
			sku,
			fields(Analytics.Segment(player))
		)
	end)
end

-- Coins in. `source` is a short id like "MailPayout" or "CoinPack".
function Analytics.Earn(player: Player, amount: number, balance: number, source: string, bought: boolean?)
	economy(
		player,
		Enum.AnalyticsEconomyFlowType.Source,
		"Coins",
		amount,
		balance,
		if bought
			then Enum.AnalyticsEconomyTransactionType.IAP.Name
			else Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
		source
	)
end

-- Coins out. `item` is what they bought, like "Box_Steel" or "Machine_Stamp".
function Analytics.Spend(player: Player, amount: number, balance: number, item: string)
	economy(
		player,
		Enum.AnalyticsEconomyFlowType.Sink,
		"Coins",
		amount,
		balance,
		Enum.AnalyticsEconomyTransactionType.Shop.Name,
		item
	)
end

-- Rebirth Points in and out (the second currency)
function Analytics.EarnPoints(player: Player, amount: number, balance: number, source: string)
	economy(
		player,
		Enum.AnalyticsEconomyFlowType.Source,
		"RebirthPoints",
		amount,
		balance,
		Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
		source
	)
end

function Analytics.SpendPoints(player: Player, amount: number, balance: number, item: string)
	economy(
		player,
		Enum.AnalyticsEconomyFlowType.Sink,
		"RebirthPoints",
		amount,
		balance,
		Enum.AnalyticsEconomyTransactionType.Shop.Name,
		item
	)
end

---------------------------------------------------------------------------------------------------
-- Zones (Travel calls this as players walk around)

function Analytics.Zone(player: Player, zone: string)
	local state = states[player]
	if not state or state.Zone == zone then
		return
	end
	state.Zone = zone
	if state.Zones[zone] then
		return
	end
	state.Zones[zone] = true
	Analytics.Custom(player, "ZoneEnter", Analytics.PlayMinutes(player), zone, Analytics.Segment(player), nil, false)
	if Config.Arenas.ById[zone] then
		Analytics.Onboarding(player, "ReachedIsland")
		Analytics.Milestone(player, `Visit_{zone}`)
	elseif zone == "Beach" then
		Analytics.Milestone(player, "Visit_Beach")
	end
end

---------------------------------------------------------------------------------------------------
-- Sessions: start, return days, and the quit

local function sessionsBucket(sessions: number): string
	return bucket(sessions, { 2, 3, 4, 6, 11, 21 }, { "S1", "S2", "S3", "S4-5", "S6-10", "S11-20", "S21+" })
end

local function onLoaded(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local state = stateOf(player)
	local now = os.time()
	local day = today()
	if (profile.FirstJoin or 0) == 0 then
		profile.FirstJoin = now
		-- Already playing before tracking existed: the date is a guess (today), so their numbers are kept apart
		profile.FirstJoinGuessed = profile.Mailed > 0 or profile.TutorialDone or profile.Rebirths > 0
	end
	local lastDay = profile.LastDay or 0
	local newDay = lastDay ~= day
	local daysSinceFirst = day - profile.FirstJoin // 86400
	profile.Sessions = (profile.Sessions or 0) + 1
	if newDay then
		profile.DaysPlayed = (profile.DaysPlayed or 0) + 1
	end
	profile.LastDay = day
	profile.LastJoin = now

	local segment = Analytics.Segment(player)
	local kind = if profile.Sessions == 1
		then "First"
		elseif not newDay then "SameDay"
		else `Gap{bucket(day - lastDay, { 2, 3, 7, 14, 30 }, { "1d", "2d", "3-6d", "7-13d", "14-29d", "30d+" })}`
	Analytics.Custom(player, "SessionStart", profile.Sessions, sessionsBucket(profile.Sessions), kind, segment)
	if newDay and profile.Sessions > 1 then
		-- Came back on a new day: which day since they first joined, and how many different days so far
		local dayLabel = if daysSinceFirst <= 7
			then `D{daysSinceFirst}`
			else bucket(daysSinceFirst, { 14, 30, 60 }, { "D8-13", "D14-29", "D30-59", "D60+" })
		local played = bucket(
			profile.DaysPlayed,
			{ 3, 4, 5, 8, 15 },
			{ "2days", "3days", "4days", "5-7days", "8-14days", "15+days" }
		)
		local guessed = if profile.FirstJoinGuessed then "Guessed" else segment
		Analytics.Custom(player, "ReturnDay", daysSinceFirst, dayLabel, played, guessed)
	end

	-- Brand-new players go into the onboarding funnel
	if profile.Mailed == 0 and not profile.TutorialDone and profile.Sessions == 1 then
		state.NewPlayer = true
		Analytics.Onboarding(player, "Joined")
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			state.SpawnAt = root.Position
			Analytics.Onboarding(player, "Spawned")
		end
	end
	DataService.Sync(player)
end

-- Called by DataService just before the save on leave (and on server shutdown)
local function onLeaving(player: Player, profile: DataService.Profile)
	local state = states[player]
	if not state then
		return
	end
	states[player] = nil
	local seconds = os.clock() - state.JoinedClock
	profile.PlaySeconds = (profile.PlaySeconds or 0) + seconds
	local minutes = math.floor(seconds / 6) / 10
	local segment = Analytics.Segment(player)
	local where = whereOf(player, state)
	local quiet = os.clock() - state.LastActionClock
	local quietLabel = bucket(quiet, { 30, 120, 300 }, { "Active<30s", "Quiet30s-2m", "Quiet2-5m", "Away5m+" })
	local friends = player:GetAttribute("FriendsHere")
	local social = if typeof(friends) == "number" and friends > 0 then "WithFriends" else "Solo"

	-- How long the visit was, and where they were when they left
	Analytics.Custom(player, "SessionEnd", minutes, minutesBucket(minutes), where, segment)
	-- What they last did, and how long before leaving (a long quiet = bored or lost; short = left mid-action)
	Analytics.Custom(player, "QuitAfter", math.floor(quiet), state.LastAction, quietLabel, segment)
	-- The level and quest they quit at, and whether friends were in the server
	Analytics.Custom(player, "QuitAt", minutes, `L{profile.Level}`, `Q{profile.Quest}`, social)
	if state.NewPlayer then
		-- The first visit: the furthest onboarding step, the tutorial step on screen, and the device
		Analytics.Custom(
			player,
			"FirstSessionEnd",
			minutes,
			state.LastStep,
			if profile.TutorialDone then "TutorialDone" else `Tut_{state.TutorialStep}`,
			state.Device
		)
	end
end

---------------------------------------------------------------------------------------------------
-- Events from the player's own screen (menus, tutorial steps, device, performance, purchase prompts)

-- name -> how many text values it takes (each checked below)
local CLIENT_EVENTS: { [string]: boolean } = {
	Device = true, -- input type, screen size
	Perf = true, -- frames per second, ping (ms)
	TutorialStep = true, -- the step now on screen
	MenuOpen = true, -- window name
	MenuClose = true, -- window name
	PurchasePrompt = true, -- item key, "Pass" or "Product"
	InviteOpened = true,
	InviteSent = true, -- number of friends invited
	FollowShown = true,
	FollowClicked = true, -- "Favorite" or "Updates" or "Close"
	FavoriteResult = true, -- Roblox's result name
}
local TUTORIAL_STEPS = { Pen = true, Wild = true, Catch = true, Escaped = true, Box = true, Mail = true, Shop = true }
local INPUTS = { Touch = true, Gamepad = true, KeyboardMouse = true }

local function cleanText(value: unknown): string?
	if typeof(value) ~= "string" or #value == 0 or #value > 32 or not string.match(value, "^[%w_%-]+$") then
		return nil
	end
	return value
end

local function cleanNumber(value: unknown, low: number, high: number): number?
	if typeof(value) ~= "number" or value ~= value then
		return nil
	end
	return math.clamp(value, low, high)
end

local function onClient(player: Player, name: unknown, a: unknown, b: unknown)
	if typeof(name) ~= "string" or not CLIENT_EVENTS[name] then
		return
	end
	local state = stateOf(player)
	if name == "Device" then
		local input, screen = cleanText(a), cleanText(b)
		if not input or not INPUTS[input] or not screen then
			return
		end
		local changed = state.Device ~= input
		state.Device, state.Screen = input, screen
		if changed then
			Analytics.Custom(player, "Device", 1, input, screen, Analytics.Segment(player))
		end
	elseif name == "Perf" then
		local fps, ping = cleanNumber(a, 0, 240), cleanNumber(b, 0, 5000)
		if not fps or not ping then
			return
		end
		local fpsLabel = bucket(fps, { 20, 30, 45, 58 }, { "FPS<20", "FPS20-29", "FPS30-44", "FPS45-57", "FPS58+" })
		local pingLabel = bucket(ping, { 100, 200, 400 }, { "Ping<100", "Ping100-199", "Ping200-399", "Ping400+" })
		Analytics.Custom(player, "Perf", math.floor(fps), fpsLabel, pingLabel, state.Device, false)
	elseif name == "TutorialStep" then
		local step = cleanText(a)
		if not step or not TUTORIAL_STEPS[step] or step == state.TutorialStep then
			return
		end
		local now = os.clock()
		local previous = if state.TutorialStep == "" then "Start" else state.TutorialStep
		-- Seconds spent on the step they just left (long = stuck there)
		Analytics.Custom(
			player,
			"TutorialStepTime",
			math.floor(now - state.TutorialClock),
			previous,
			step,
			state.Device
		)
		state.TutorialStep, state.TutorialClock = step, now
		Analytics.Did(player, `Tutorial_{step}`)
	elseif name == "MenuOpen" then
		local menu = cleanText(a)
		if not menu then
			return
		end
		state.ClientValues += 1
		if state.ClientValues > 400 then
			return -- (a normal visit never gets near this)
		end
		state.Menu, state.MenuClock = menu, os.clock()
		Analytics.Did(player, `Menu_{menu}`)
		Analytics.Custom(player, "Menu", 1, menu, "Opened", Analytics.Segment(player), false)
		if menu == "Store" then
			Analytics.Milestone(player, "FirstStoreOpen")
		end
	elseif name == "MenuClose" then
		local menu = cleanText(a)
		if not menu or state.Menu ~= menu then
			return
		end
		state.Menu = nil
		-- Value: seconds the window was open
		Analytics.Custom(player, "Menu", math.floor(os.clock() - state.MenuClock), menu, "SecondsOpen", nil, false)
	elseif name == "PurchasePrompt" then
		local key, kind = cleanText(a), cleanText(b)
		if not key or (kind ~= "Pass" and kind ~= "Product") then
			return
		end
		state.Prompted[key] = os.clock()
		Analytics.Did(player, `Prompt_{key}`)
		Analytics.Custom(player, "PurchasePrompt", 1, key, kind, Analytics.Segment(player))
	elseif name == "InviteOpened" then
		Analytics.Did(player, "InviteOpened")
		Analytics.Custom(player, "Invite", 1, "Opened", Analytics.Segment(player))
	elseif name == "InviteSent" then
		local count = cleanNumber(a, 0, 100)
		if count and count > 0 then
			Analytics.Custom(player, "Invite", math.floor(count), "Sent", Analytics.Segment(player))
			Analytics.Milestone(player, "FirstInviteSent")
		end
	elseif name == "FollowShown" then
		Analytics.Custom(player, "FollowPrompt", 1, "Shown", Analytics.Segment(player))
	elseif name == "FollowClicked" then
		local choice = cleanText(a)
		if choice == "Favorite" or choice == "Updates" or choice == "Close" then
			Analytics.Custom(player, "FollowPrompt", 1, choice, Analytics.Segment(player))
		end
	elseif name == "FavoriteResult" then
		local result = cleanText(a)
		if result then
			Analytics.Custom(player, "FollowPrompt", 1, `Favorite_{result}`, Analytics.Segment(player))
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Robux purchases: bought or cancelled (the prompt itself comes from the client, above)

local passKeys: { [number]: { Key: string, Price: number } } = {}
local productKeys: { [number]: { Key: string, Price: number } } = {}
for _, pass in Config.Monetization.Passes do
	if pass.Id ~= 0 then
		passKeys[pass.Id] = { Key = pass.Key, Price = pass.Price }
	end
end
for _, product in Config.Monetization.Products do
	if product.Id ~= 0 then
		productKeys[product.Id] = { Key = product.Key, Price = product.Price }
	end
end

local function purchaseFinished(player: Player, item: { Key: string, Price: number }?, kind: string, bought: boolean)
	if not item then
		return
	end
	local state = stateOf(player)
	local promptedAt = state.Prompted[item.Key]
	state.Prompted[item.Key] = nil
	local outcome = if bought then "Bought" else "Cancelled"
	Analytics.Did(player, `{outcome}_{item.Key}`)
	-- Value: the Robux price. Field 3: how long the prompt was up (quick cancel = price shock)
	local seconds = if promptedAt then os.clock() - promptedAt else -1
	local decided = if seconds < 0 then "?" else bucket(seconds, { 3, 10, 30 }, { "<3s", "3-10s", "10-30s", "30s+" })
	Analytics.Custom(player, "PurchaseResult", item.Price, `{kind}_{item.Key}`, outcome, decided)
	if bought then
		Analytics.Milestone(player, "FirstPurchase")
		Analytics.Milestone(player, `Bought_{item.Key}`)
	end
end

---------------------------------------------------------------------------------------------------

-- Kept so older call sites still work (cleanup now happens on leave)
function Analytics.Forget(_player: Player) end

function Analytics.Start()
	local function onPlayerAdded(player: Player)
		local state = stateOf(player)
		player.CharacterAdded:Connect(function(character)
			local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
			if root and state.NewPlayer and not state.Onboarding.Moved then
				state.SpawnAt = root.Position
			end
			Analytics.Onboarding(player, "Spawned")
		end)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	-- (in case a save never loads: drop the state when they go)
	Players.PlayerRemoving:Connect(function(player)
		task.delay(10, function()
			states[player] = nil
		end)
	end)

	DataService.Loaded:Connect(onLoaded)
	DataService.OnLeaving = onLeaving

	Remotes.Listen(Remotes.Track, 6, onClient)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, bought: boolean)
		purchaseFinished(player, passKeys[passId], "Pass", bought)
	end)
	pcall(function()
		MarketplaceService.PromptProductPurchaseFinished:Connect(
			function(userId: number, productId: number, bought: boolean)
				local player = Players:GetPlayerByUserId(userId)
				if player then
					purchaseFinished(player, productKeys[productId], "Product", bought)
				end
			end
		)
	end)

	-- New players: the "Moved" step (walked a few steps from where they appeared)
	task.spawn(function()
		while true do
			task.wait(1)
			for player, state in states do
				local from = state.SpawnAt
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if from and root and (root.Position - from).Magnitude > 12 then
					state.SpawnAt = nil
					Analytics.Onboarding(player, "Moved")
				end
			end
		end
	end)
end

return Analytics
