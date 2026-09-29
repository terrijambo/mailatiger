--!strict
-- The rules for coins, unlocks, tools and rebirths, on top of the saved profile (DataService).
-- Every change calls Economy.Sync, which updates leaderstats (the player list) and the "Profile" attribute
-- the client UI reads.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)

local Economy = {}

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
	DataService.Sync(player)
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
	Economy.Sync(player)
end

function Economy.AddCoins(player: Player, amount: number)
	local profile = DataService.Get(player)
	if profile then
		profile.Coins += amount
		Economy.Sync(player)
	end
end

-- Takes coins if the player has enough. Returns whether it worked.
function Economy.TrySpend(player: Player, amount: number): boolean
	local profile = DataService.Get(player)
	if not profile or profile.Coins < amount then
		return false
	end
	profile.Coins -= amount
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

function Economy.RebirthCost(rebirths: number): number
	local rebirth = Config.Progression.Rebirth
	return math.round(rebirth.BaseCost * rebirth.CostGrowth ^ rebirths)
end

-- Permanent payout multiplier from rebirths
function Economy.PayoutMult(player: Player): number
	local profile = DataService.Get(player)
	local rebirths = if profile then profile.Rebirths else 0
	return 1 + rebirths * Config.Progression.Rebirth.PayoutBonusPerRebirth
end

function Economy.Start()
	DataService.Loaded:Connect(setupPlayer)
end

return Economy
