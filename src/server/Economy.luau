--!strict
-- The rules for coins, unlocks, tools and rebirths, on top of the saved profile (DataService).
-- Every change calls Economy.Sync, which updates leaderstats (the player list) and the "Profile" attribute
-- the client UI reads.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local Remotes = require(script.Parent.Remotes)

local Economy = {}

Economy.BASE_WALK_SPEED = 16

function Economy.Sync(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local coins = leaderstats:FindFirstChild("Coins") :: IntValue?
		local rebirths = leaderstats:FindFirstChild("Rebirths") :: IntValue?
		if coins then
			coins.Value = profile.Coins
		end
		if rebirths then
			rebirths.Value = profile.Rebirths
		end
	end
	-- Your running speed (with Sneakers). The client's Movement module uses it, in town too.
	player:SetAttribute("WalkSpeed", Economy.WalkSpeed(player))
	-- Coins per minute from your chute (the HUD shows it)
	player:SetAttribute("ChuteRate", math.floor(Economy.ChuteRate(player)))
	DataService.Sync(player)
	local hook = Economy.OnSync
	if hook then
		hook(player)
	end
end

-- Set by ProgressionService: runs after every change to a player's progress (to finish "state" quests)
Economy.OnSync = nil :: ((Player) -> ())?

-- Base running speed plus Sneakers
function Economy.WalkSpeed(player: Player): number
	return Economy.BASE_WALK_SPEED + Economy.ToolBonus(player, "Sneakers")
end

local function setupPlayer(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = leaderstats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = leaderstats
	leaderstats.Parent = player

	-- Studio testing only: free coins when nothing is being saved (see Config.Dev.StudioTestCoins)
	local profile = DataService.Get(player)
	if profile and RunService:IsStudio() and player:GetAttribute("TemporaryData") == true then
		profile.Coins = math.max(profile.Coins, Config.Dev.StudioTestCoins)
	end
	Economy.Sync(player)
end

-- source: where the coins came from, for analytics (e.g. "MailPayout")
function Economy.AddCoins(player: Player, amount: number, source: string?)
	local profile = DataService.Get(player)
	if profile then
		profile.Coins += amount
		Analytics.Earn(player, amount, profile.Coins, source or "Other")
		Economy.Sync(player)
	end
end

-- Takes coins if the player has enough. Returns whether it worked.
-- item: what they bought, for analytics (e.g. "Box_Steel")
function Economy.TrySpend(player: Player, amount: number, item: string?): boolean
	local profile = DataService.Get(player)
	if not profile or profile.Coins < amount then
		return false
	end
	profile.Coins -= amount
	Analytics.Spend(player, amount, profile.Coins, item or "Other")
	Economy.Sync(player)
	return true
end

function Economy.Owns(player: Player, animalId: string): boolean
	local profile = DataService.Get(player)
	return profile ~= nil and profile.Owned[animalId] == true
end

function Economy.Unlock(player: Player, animalId: string)
	local profile = DataService.Get(player)
	if profile then
		profile.Owned[animalId] = true
		Economy.Sync(player)
	end
end

function Economy.ToolLevel(player: Player, toolId: string): number
	local profile = DataService.Get(player)
	return if profile then profile.Tools[toolId] or 0 else 0
end

-- How much the tool helps at the player's level (level x PerLevel)
function Economy.ToolBonus(player: Player, toolId: string): number
	return Economy.ToolLevel(player, toolId) * Config.Tools.ById[toolId].PerLevel
end

-- Base pay of the best animal your level lets you take on (wild animals: Config/Wild.luau). Rewards scale
-- with it so they stay worth having all game.
function Economy.BestBaseValue(player: Player): number
	local profile = DataService.Get(player)
	local best = 1
	for _, animal in Config.Animals.List do
		if profile and (Config.Wild.LevelOf[animal.Id] or 1) <= profile.Level then
			best = math.max(best, animal.BaseValue)
		end
	end
	return best
end

function Economy.RebirthCost(rebirths: number): number
	return Config.Machines.RebirthCost(rebirths)
end

-- Coins per minute your chute pays: your chute level, x1.5 per rebirth, and the usual boosts
function Economy.ChuteRate(player: Player): number
	local profile = DataService.Get(player)
	if not profile then
		return 0
	end
	local machines = Config.Machines
	return machines.ChuteRate(profile.Level) * machines.Rebirth.ChuteMult ^ profile.Rebirths * Economy.BoostMult(player)
end

-- Rebirth Upgrades (Config/Upgrades.luau): your level in one, and its total bonus
function Economy.UpgradeLevel(player: Player, upgradeId: string): number
	local profile = DataService.Get(player)
	return if profile then profile.Upgrades[upgradeId] or 0 else 0
end

function Economy.UpgradeBonus(player: Player, upgradeId: string): number
	return Config.Upgrades.Bonus(Config.Upgrades.ById[upgradeId], Economy.UpgradeLevel(player, upgradeId))
end

-- A prize (a challenge, the boss, an event, an invite...): coins worth `minutes` of your chute's income, so
-- it's always worth having at any level. Returns the coins paid. source: for analytics (e.g. "Boss")
function Economy.PrizeCoins(player: Player, minutes: number): number
	return math.max(1, math.floor(Economy.ChuteRate(player) * minutes))
end

function Economy.AddPrize(player: Player, minutes: number, source: string): number
	if minutes <= 0 then
		return 0
	end
	local coins = Economy.PrizeCoins(player, minutes)
	Economy.AddCoins(player, coins, source)
	Remotes.Notify:FireClient(player, "Prize", { Coins = coins, Source = source })
	return coins
end

-- Rebirth Points (only from rebirthing, or the old diamond packs: MonetizationService)
function Economy.AddRebirthPoints(player: Player, amount: number, source: string)
	local profile = DataService.Get(player)
	if profile and amount > 0 then
		profile.RebirthPoints += amount
		Analytics.EarnPoints(player, amount, profile.RebirthPoints, source)
		Analytics.Custom(player, "RebirthPointsEarned", amount, source, Analytics.Segment(player))
		Economy.Sync(player)
	end
end

-- Buys the next level of a Rebirth Upgrade with Rebirth Points. Returns a message for the player.
function Economy.BuyUpgrade(player: Player, upgradeId: string): (boolean, string)
	local profile = DataService.Get(player)
	local upgrade = Config.Upgrades.ById[upgradeId]
	if not profile or not upgrade then
		return false, ""
	end
	local level = profile.Upgrades[upgradeId] or 0
	if level >= upgrade.MaxLevel then
		return false, `{upgrade.DisplayName} is maxed out.`
	end
	local cost = Config.Upgrades.Cost(upgrade, level)
	if profile.RebirthPoints < cost then
		return false,
			`{upgrade.DisplayName} costs {cost} Rebirth Points. You have {profile.RebirthPoints}. Rebirth to earn more!`
	end
	profile.RebirthPoints -= cost
	profile.Upgrades[upgradeId] = level + 1
	Analytics.SpendPoints(player, cost, profile.RebirthPoints, `Upgrade_{upgradeId}`)
	Analytics.Custom(player, "Bought", level + 1, "Upgrade", upgradeId, Analytics.Segment(player))
	Analytics.Milestone(player, "FirstUpgrade")
	Economy.Sync(player)
	return true, `{upgrade.Emoji} {upgrade.DisplayName} Lv {level + 1}: {Config.Upgrades.Text(upgrade, level + 1)}!`
end

-- The server-wide 2x coins boost (bought in the Store). Workspace attribute BoostUntil = server time it ends.
function Economy.BoostActive(): boolean
	local untilTime = Workspace:GetAttribute("BoostUntil")
	return typeof(untilTime) == "number" and Workspace:GetServerTimeNow() < untilTime
end

-- Your payout multiplier: rebirths, then the boosts below
function Economy.PayoutMult(player: Player): number
	local profile = DataService.Get(player)
	local rebirths = if profile then profile.Rebirths else 0
	return (1 + rebirths * Config.Progression.Rebirth.PayoutBonusPerRebirth) * Economy.BoostMult(player)
end

-- Boosts on everything you earn: Golden Paws, the server boost, Roblox Premium, the group and friends
-- (MonetizationService sets those attributes)
function Economy.BoostMult(player: Player): number
	local mult = 1 + Economy.UpgradeBonus(player, "GoldenPaws") / 100
	local money = Config.Monetization
	if Economy.BoostActive() then
		mult *= money.BoostMult
	end
	if player:GetAttribute("Premium") == true then
		mult *= money.PremiumPayoutMult
	end
	if player:GetAttribute("InGroup") == true then
		mult *= money.GroupPayoutMult
	end
	-- Playing with Roblox friends in the same server (MonetizationService counts them)
	local friends = player:GetAttribute("FriendsHere")
	if typeof(friends) == "number" and friends > 0 then
		local tuning = Config.Social.Friends
		mult *= 1 + tuning.BonusPerFriend * math.min(friends, tuning.MaxFriends)
	end
	return mult
end

-- Characters are drawn small (Config/World.luau PlayerScale), so the world feels big
local function shrink(character: Model)
	character:WaitForChild("HumanoidRootPart", 10)
	task.defer(function()
		if character.Parent then
			character:ScaleTo(Config.World.PlayerScale)
		end
	end)
end

function Economy.Start()
	DataService.Loaded:Connect(setupPlayer)
	local function watch(player: Player)
		player.CharacterAdded:Connect(shrink)
		if player.Character then
			shrink(player.Character)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return Economy
