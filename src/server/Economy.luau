--!strict
-- Coins and owned animals. Coins show in the player list via leaderstats.
-- Owned animals are mirrored to the "OwnedAnimals" player attribute (comma-separated) for the Pen menu.
-- Nothing is saved yet: saving comes in Phase 3.

local Players = game:GetService("Players")

local Economy = {}

local owned: { [Player]: { [string]: boolean } } = {}

local function coinsValue(player: Player): IntValue?
	local leaderstats = player:FindFirstChild("leaderstats")
	return leaderstats and leaderstats:FindFirstChild("Coins") :: IntValue?
end

local function syncOwned(player: Player)
	local set = owned[player]
	if not set then
		return
	end
	local ids = {}
	for id in set do
		table.insert(ids, id)
	end
	player:SetAttribute("OwnedAnimals", table.concat(ids, ","))
end

local function setupPlayer(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = leaderstats

	leaderstats.Parent = player

	owned[player] = { Hamster = true } -- everyone starts with the hamster
	syncOwned(player)
end

function Economy.AddCoins(player: Player, amount: number)
	local coins = coinsValue(player)
	if coins then
		coins.Value += amount
	end
end

-- Takes coins if the player has enough. Returns whether it worked.
function Economy.TrySpend(player: Player, amount: number): boolean
	local coins = coinsValue(player)
	if not coins or coins.Value < amount then
		return false
	end
	coins.Value -= amount
	return true
end

function Economy.Owns(player: Player, animalId: string): boolean
	local set = owned[player]
	return set ~= nil and set[animalId] == true
end

function Economy.Unlock(player: Player, animalId: string)
	local set = owned[player]
	if set then
		set[animalId] = true
		syncOwned(player)
	end
end

function Economy.Start()
	Players.PlayerAdded:Connect(setupPlayer)
	for _, player in Players:GetPlayers() do
		setupPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
	end)
end

return Economy
