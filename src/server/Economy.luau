--!strict
-- The rules for coins, unlocks, tools and rebirths, on top of the saved profile (DataService).
-- Every change calls Economy.Sync, which updates leaderstats (the player list) and the "Profile" attribute
-- the client UI reads.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)

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
	DataService.Sync(player)
end

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

-- Base pay of the best animal you own. Rewards scale with it so they stay worth having all game.
function Economy.BestBaseValue(player: Player): number
	local profile = DataService.Get(player)
	local best = 1
	for _, animal in Config.Animals.List do
		if profile and profile.Owned[animal.Id] then
			best = math.max(best, animal.BaseValue)
		end
	end
	return best
end

function Economy.RebirthCost(rebirths: number): number
	local rebirth = Config.Progression.Rebirth
	return math.round(rebirth.BaseCost * rebirth.CostGrowth ^ rebirths)
end

-- Your personal payout multiplier: rebirths, the Double Coins pass, Roblox Premium and the group bonus
-- (MonetizationService sets those attributes)
function Economy.PayoutMult(player: Player): number
	local profile = DataService.Get(player)
	local rebirths = if profile then profile.Rebirths else 0
	local mult = 1 + rebirths * Config.Progression.Rebirth.PayoutBonusPerRebirth
	local money = Config.Monetization
	if player:GetAttribute("Pass_DoubleCoins") == true then
		mult *= money.DoubleCoinsMult
	end
	if player:GetAttribute("Premium") == true then
		mult *= money.PremiumPayoutMult
	end
	if player:GetAttribute("InGroup") == true then
		mult *= money.GroupPayoutMult
	end
	return mult
end

function Economy.Start()
	DataService.Loaded:Connect(setupPlayer)
	Players.PlayerRemoving:Connect(Analytics.Forget)
end

return Economy
