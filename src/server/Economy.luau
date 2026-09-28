--!strict
-- Coins. Shown in the player list via leaderstats. (Saving comes in Phase 3.)

local Players = game:GetService("Players")

local Economy = {}

local function setupPlayer(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = leaderstats

	leaderstats.Parent = player
end

function Economy.AddCoins(player: Player, amount: number)
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins") :: IntValue?
	if coins then
		coins.Value += amount
	end
end

function Economy.Start()
	Players.PlayerAdded:Connect(setupPlayer)
	for _, player in Players:GetPlayers() do
		setupPlayer(player)
	end
end

return Economy
