--!strict
-- Levels, XP and Gruff's main quests (numbers in Config/Levels.luau and Config/Quests.luau).
--   * XP comes from mailing (ProgressionService.OnParcelMailed), orders (OnOrderDone), quests, and the tutorial.
--   * Leveling up pays a coin bonus and tells the client (a big LEVEL UP popup with what just unlocked).
--   * Zones (islands) open by realm (ProgressionService.ZoneOpen, Config/Realms.luau). Your level is your chute
--     level in your realm: it lets you take on the realm's animals one by one, sets the chute's coins per
--     minute and which machines you can buy (Config/Machines.luau). Rebirth and a realm move reset it.
--   * Quests run one at a time. "Count" quests (mail X, complete X orders) count from when the quest starts.
--     "State" quests (own the Bunny, reach level 4, buy Sneakers...) complete the moment they're true.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Remotes = require(script.Parent.Remotes)

local Levels = Config.Levels
local Quests = Config.Quests

local ProgressionService = {}

type Profile = DataService.Profile
type Quest = typeof(Quests[1])

local function notify(player: Player, kind: string, data: { [string]: any })
	Remotes.Notify:FireClient(player, kind, data)
end

-- Is this zone (arena id) open for the player? (Its realm has to be bought.)
function ProgressionService.ZoneOpen(player: Player, arenaId: string): boolean
	local profile = DataService.Get(player)
	return profile ~= nil and Config.Realms.OfArena(arenaId) <= profile.Realm
end

-- The realm a zone (arena id) belongs to
function ProgressionService.ZoneRealm(arenaId: string)
	return Config.Realms.At(Config.Realms.OfArena(arenaId))
end

-- What opens at exactly this level in this realm (for the LEVEL UP popup)
local function unlocksAt(level: number, realm: number): { string }
	local list = {}
	for _, animal in Config.Animals.List do
		if animal.Tier == realm and level > 1 and (Config.Wild.LevelOf[animal.Id] or 1) == level then
			table.insert(list, `🐾 You can take on the {animal.DisplayName} now`)
		end
	end
	local here = Config.Realms.At(realm)
	if realm < Config.Realms.Count and level == here.NeedLevel then
		table.insert(list, `🌍 The level you need for the next realm (MENU > REALMS)`)
	end
	for _, troll in Config.Trolls.List do
		if troll.Level == level then
			table.insert(list, `{troll.Emoji} {troll.DisplayName} (troll item)`)
		end
	end
	for _, machine in Config.Machines.List do
		if machine.Level == level then
			table.insert(list, `{machine.Emoji} The {machine.DisplayName} (Shop > Machines)`)
		end
	end
	for _, chute in Config.Mail.Chutes do
		if chute.Level == level and level > 1 then
			table.insert(list, `📮 Your chute becomes the {chute.DisplayName}`)
		end
	end
	return list
end

local checkQuest: (Player) -> ()

function ProgressionService.AddXP(player: Player, amount: number, reason: string?)
	local profile = DataService.Get(player)
	if not profile or amount <= 0 then
		return
	end
	local eventMult = Workspace:GetAttribute("XPMult") -- Double XP event
	amount = math.floor(
		amount
			* (1 + Economy.UpgradeBonus(player, "QuickStudy") / 100) -- Rebirth Upgrade
			* (if typeof(eventMult) == "number" then eventMult else 1)
	)
	profile.XP += amount
	notify(player, "XP", { Amount = amount, Reason = reason })
	local leveled = false
	while profile.Level < Levels.MaxLevel and profile.XP >= Levels.XPToNext(profile.Level) do
		profile.XP -= Levels.XPToNext(profile.Level)
		profile.Level += 1
		leveled = true
		local coins = Economy.BestBaseValue(player) * Levels.LevelUpJobs * profile.Level
		profile.Coins += coins
		Analytics.Earn(player, coins, profile.Coins, "LevelUp")
		Analytics.Custom(player, "LevelUp", profile.Level)
		-- Value: total minutes played to get here. Fields: the level, rebirths so far, days since first join
		Analytics.Custom(
			player,
			"LevelReached",
			Analytics.PlayMinutes(player),
			`L{profile.Level}`,
			`R{math.min(profile.Rebirths, 5)}`,
			Analytics.DayBand(player)
		)
		Analytics.Progress(player, "ChuteLevel", profile.Level)
		notify(player, "LevelUp", {
			Level = profile.Level,
			Coins = coins,
			Unlocks = unlocksAt(profile.Level, profile.Realm),
		})
	end
	if profile.Level >= Levels.MaxLevel then
		profile.XP = 0
	end
	Economy.Sync(player)
	if leveled then
		checkQuest(player) -- "reach level N" quests
	end
end

---------------------------------------------------------------------------------------------------
-- Quests

-- Is a "state" quest already true?
local function questDone(profile: Profile, quest: Quest): boolean
	if quest.Type == "Own" then
		return profile.Owned[quest.Animal or ""] == true
	elseif quest.Type == "Level" then
		return profile.Level >= (quest.Level or 1)
	elseif quest.Type == "Tool" then
		return (profile.Tools[quest.Tool or ""] or 0) >= (quest.Level or 1)
	elseif quest.Type == "Machine" then
		return profile.Machines[quest.Machine or ""] == true
	elseif quest.Type == "Troll" then
		return profile.Trolls[quest.Troll or ""] == true
	elseif quest.Type == "Realm" then
		return profile.Realm >= (quest.Realm or 1)
	end
	-- Count quests
	return profile.QuestProgress >= (quest.Count or 1)
end

local checking: { [Player]: boolean } = {}

checkQuest = function(player: Player)
	local profile = DataService.Get(player)
	if not profile or checking[player] then
		return
	end
	checking[player] = true
	-- (A loop, in case several quests in a row are already done)
	while true do
		local quest = Quests[profile.Quest]
		if not quest or not questDone(profile, quest) then
			break
		end
		local coins = Economy.BestBaseValue(player) * quest.Jobs
		profile.Coins += coins
		Analytics.Earn(player, coins, profile.Coins, "Quest")
		profile.Quest += 1
		profile.QuestProgress = 0
		Analytics.Custom(player, "QuestDone", profile.Quest - 1)
		-- Value: total minutes played to finish it (a quest that takes much longer than the one before = stuck)
		Analytics.Custom(
			player,
			"QuestReached",
			Analytics.PlayMinutes(player),
			`Q{profile.Quest - 1}`,
			Analytics.LevelBand(profile.Level),
			Analytics.DayBand(player)
		)
		Analytics.Did(player, "QuestDone")
		local nextQuest = Quests[profile.Quest]
		notify(player, "QuestDone", {
			Text = quest.Text,
			XP = quest.XP,
			Coins = coins,
			Next = if nextQuest then nextQuest.Text else nil,
		})
		ProgressionService.AddXP(player, quest.XP, "Quest")
	end
	Economy.Sync(player)
	checking[player] = nil
end
ProgressionService.CheckQuest = checkQuest

-- A count quest ticks up (mail N of an animal, complete N orders)
local function questCount(player: Player, profile: Profile, matches: (Quest) -> boolean)
	local quest = Quests[profile.Quest]
	if quest and matches(quest) then
		profile.QuestProgress += 1
		checkQuest(player)
	end
end

---------------------------------------------------------------------------------------------------
-- Events from the rest of the game

-- One parcel mailed at the chute
function ProgressionService.OnParcelMailed(
	player: Player,
	animalId: string,
	stars: number,
	variantId: string?,
	machines: { [string]: boolean }? -- the machines that stamped it
)
	local profile = DataService.Get(player)
	local animal = Config.Animals.ById[animalId]
	if not profile or not animal then
		return
	end
	local variant = if variantId then Config.Variants.ById[variantId] else nil
	local weight = Levels.Weight(animalId, profile.Realm)
	local xp = Levels.MailXPPerTier
		* weight
		* (Levels.StarXPMult[stars] or 1)
		* (if variant then variant.XPMult else 1)
		* Config.Machines.XPMult(machines or {}) -- its machine stamps (Config/Machines.luau)
	local first = (profile.Species[animalId] or 0) == 0
	profile.Species[animalId] = (profile.Species[animalId] or 0) + 1
	if first then
		local bonus = math.floor(Levels.NewSpeciesXP * weight)
		xp += bonus
		notify(player, "NewSpecies", { Animal = animal.DisplayName, XP = bonus })
	end
	ProgressionService.AddXP(player, math.floor(xp), "Mail")
	questCount(player, profile, function(quest)
		return quest.Type == "Mail"
			and (quest.Animal == nil or quest.Animal == animalId)
			and stars >= (quest.MinStars or 0)
	end)
end

-- One of Gruff's side orders was completed
function ProgressionService.OnOrderDone(player: Player, animalId: string)
	local profile = DataService.Get(player)
	local animal = Config.Animals.ById[animalId]
	if not profile then
		return
	end
	profile.OrdersDone += 1
	local weight = if animal then Levels.Weight(animalId, profile.Realm) else 1
	ProgressionService.AddXP(player, math.floor(Levels.OrderXP * weight), "Order")
	questCount(player, profile, function(quest)
		return quest.Type == "Orders"
	end)
end

-- Can this player take this animal (its realm bought, and your level high enough)? Returns a reason if not.
function ProgressionService.CanTakeAnimal(player: Player, animalId: string): (boolean, string?)
	local animal = Config.Animals.ById[animalId]
	if not animal then
		return false, nil
	end
	local profile = DataService.Get(player)
	if not profile then
		return false, nil
	end
	if animal.Tier > profile.Realm then
		local realm = Config.Realms.At(animal.Tier)
		return false, `The {animal.DisplayName} lives in the {realm.DisplayName} realm. Buy it at MENU > REALMS first!`
	end
	-- Every animal has a level in its realm and a power (Config/Wild.luau): yours has to be at least as high
	if Config.Realms.Power(profile.Realm, profile.Level) < (Config.Wild.PowerOf[animalId] or 1) then
		return false,
			`That {animal.DisplayName} is Level {Config.Wild.LevelOf[animalId] or 1}. Keep mailing to level up!`
	end
	return true, nil
end

function ProgressionService.Start()
	-- Quest "state" checks after anything changes (bought an animal, a tool, a chute, a troll...)
	Economy.OnSync = function(player: Player)
		local profile = DataService.Get(player)
		local quest = profile and Quests[profile.Quest]
		if profile and quest and quest.Type ~= "Mail" and quest.Type ~= "Orders" and questDone(profile, quest) then
			task.defer(checkQuest, player)
		end
	end
	DataService.Loaded:Connect(function(player: Player)
		task.delay(1, checkQuest, player)
	end)
end

return ProgressionService
