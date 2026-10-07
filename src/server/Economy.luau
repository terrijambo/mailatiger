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
	-- Brand-new players go into the onboarding funnel (see Analytics.luau)
	if profile and profile.Mailed == 0 and not profile.TutorialDone then
		Analytics.StartOnboarding(player)
	end
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

-- Diamond upgrades (Config/Diamonds.luau): your level in one, and its total bonus
function Economy.UpgradeLevel(player: Player, upgradeId: string): number
	local profile = DataService.Get(player)
	return if profile then profile.Upgrades[upgradeId] or 0 else 0
end

function Economy.UpgradeBonus(player: Player, upgradeId: string): number
	return Config.Diamonds.Bonus(Config.Diamonds.ById[upgradeId], Economy.UpgradeLevel(player, upgradeId))
end

-- source: where they came from, e.g. "LevelUp" or "DiamondsSmall" (for analytics)
function Economy.AddDiamonds(player: Player, amount: number, source: string)
	local profile = DataService.Get(player)
	if profile and amount > 0 then
		profile.Diamonds += amount
		Analytics.Custom(player, `Diamonds_{source}`, amount)
		Remotes.Notify:FireClient(player, "Diamonds", { Amount = amount, Source = source })
		Economy.Sync(player)
	end
end

-- Buys the next level of a diamond upgrade. Returns a message for the player.
function Economy.BuyUpgrade(player: Player, upgradeId: string): (boolean, string)
	local profile = DataService.Get(player)
	local upgrade = Config.Diamonds.ById[upgradeId]
	if not profile or not upgrade then
		return false, ""
	end
	local level = profile.Upgrades[upgradeId] or 0
	if level >= upgrade.MaxLevel then
		return false, `{upgrade.DisplayName} is maxed out.`
	end
	local cost = Config.Diamonds.Cost(upgrade, level)
	if profile.Diamonds < cost then
		return false, `{upgrade.DisplayName} costs {cost} 💎. You have {profile.Diamonds}.`
	end
	profile.Diamonds -= cost
	profile.Upgrades[upgradeId] = level + 1
	Analytics.Custom(player, `Upgrade_{upgradeId}`, level + 1)
	Economy.Sync(player)
	return true, `{upgrade.Emoji} {upgrade.DisplayName} Lv {level + 1}: {Config.Diamonds.Text(upgrade, level + 1)}!`
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

function Economy.Start()
	DataService.Loaded:Connect(setupPlayer)
	Players.PlayerRemoving:Connect(Analytics.Forget)
end

return Economy
