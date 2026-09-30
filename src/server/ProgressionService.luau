--!strict
-- Levels, XP and Gruff's main quests (numbers in Config/Levels.luau and Config/Quests.luau).
--   * XP comes from mailing (ProgressionService.OnParcelMailed), orders (OnOrderDone), quests, and the tutorial.
--   * Leveling up pays a coin bonus and tells the client (a big LEVEL UP popup with what just unlocked).
--   * Zones open by level (ProgressionService.ZoneOpen). Levels are kept through rebirths.
--   * Quests run one at a time. "Count" quests (mail X, complete X orders) count from when the quest starts.
--     "State" quests (own the Bunny, reach level 4, buy Sneakers...) complete the moment they're true.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

local function arenaForTier(tier: number): string
	local arena = Config.Arenas.ByTier[tier]
	return if arena then arena.Id else "Backyard"
end

-- Is this zone (arena id) open for the player?
function ProgressionService.ZoneOpen(player: Player, arenaId: string): boolean
	local profile = DataService.Get(player)
	local need = Levels.ZoneLevels[arenaId] or 1
	return profile ~= nil and profile.Level >= need
end

function ProgressionService.ZoneLevel(arenaId: string): number
	return Levels.ZoneLevels[arenaId] or 1
end

-- What opens at exactly this level (for the LEVEL UP popup)
local function unlocksAt(level: number): { string }
	local list = {}
	for _, def in Config.Arenas.List do
		if (Levels.ZoneLevels[def.Id] or 1) == level then
			table.insert(list, `🔓 The {def.DisplayName} zone`)
		end
	end
	for _, troll in Config.Trolls.List do
		if troll.Level == level then
			table.insert(list, `{troll.Emoji} {troll.DisplayName} (troll item)`)
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
	amount = math.floor(amount)
	profile.XP += amount
	notify(player, "XP", { Amount = amount, Reason = reason })
	local leveled = false
	while profile.Level < Levels.MaxLevel and profile.XP >= Levels.XPToNext(profile.Level) do
		profile.XP -= Levels.XPToNext(profile.Level)
		profile.Level += 1
		leveled = true
		local coins = Economy.BestBaseValue(player) * Levels.LevelUpJobs * profile.Level
		profile.Coins += coins
		Analytics.Custom(player, "LevelUp", profile.Level)
		notify(player, "LevelUp", { Level = profile.Level, Coins = coins, Unlocks = unlocksAt(profile.Level) })
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
	elseif quest.Type == "Chute" then
		return (Config.Mail.ChuteIndex[profile.ChuteTier] or 1) >= (Config.Mail.ChuteIndex[quest.Chute or ""] or 99)
	elseif quest.Type == "Troll" then
		return profile.Trolls[quest.Troll or ""] == true
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
		profile.Quest += 1
		profile.QuestProgress = 0
		Analytics.Custom(player, "QuestDone", profile.Quest - 1)
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
function ProgressionService.OnParcelMailed(player: Player, animalId: string, stars: number)
	local profile = DataService.Get(player)
	local animal = Config.Animals.ById[animalId]
	if not profile or not animal then
		return
	end
	local xp = Levels.MailXPPerTier * animal.Tier * (Levels.StarXPMult[stars] or 1)
	local first = (profile.Species[animalId] or 0) == 0
	profile.Species[animalId] = (profile.Species[animalId] or 0) + 1
	if first then
		xp += Levels.NewSpeciesXP * animal.Tier
		notify(player, "NewSpecies", { Animal = animal.DisplayName, XP = Levels.NewSpeciesXP * animal.Tier })
	end
	ProgressionService.AddXP(player, xp, "Mail")
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
	ProgressionService.AddXP(player, Levels.OrderXP * (if animal then animal.Tier else 1), "Order")
	questCount(player, profile, function(quest)
		return quest.Type == "Orders"
	end)
end

-- Can this player take this animal (its zone has to be open)? Returns a reason if not.
function ProgressionService.CanTakeAnimal(player: Player, animalId: string): (boolean, string?)
	local animal = Config.Animals.ById[animalId]
	if not animal then
		return false, nil
	end
	local arenaId = arenaForTier(animal.Tier)
	if not ProgressionService.ZoneOpen(player, arenaId) then
		local def = Config.Arenas.ById[arenaId]
		return false,
			`🔒 {animal.DisplayName}s live in the {def.DisplayName}, which opens at Level {Levels.ZoneLevels[arenaId]}. Keep mailing!`
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
