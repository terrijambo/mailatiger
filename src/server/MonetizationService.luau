--!strict
-- Robux: game passes and developer products (ids in src/shared/Config/Monetization.luau).
--
--   Passes are checked when you join (and right after you buy one), then copied onto you as attributes
--   like "Pass_DoubleCoins" = true, so the rest of the game and your UI can read them.
--   Products (coins, stamps, unlocks) are granted in ProcessReceipt. Each purchase id is written into your
--   save before Roblox is told "granted", so a retry can never pay out twice, and a failed save means
--   Roblox tries again later instead of charging you for nothing.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Remotes = require(script.Parent.Remotes)

local Money = Config.Monetization

local MonetizationService = {}

local RECEIPTS_KEPT = 50

function MonetizationService.HasPass(player: Player, key: string): boolean
	return player:GetAttribute(`Pass_{key}`) == true
end

local function checkPasses(player: Player)
	for _, pass in Money.Passes do
		if pass.Id ~= 0 and not MonetizationService.HasPass(player, pass.Key) then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
			if ok and owns then
				player:SetAttribute(`Pass_{pass.Key}`, true)
			end
		end
	end
end

local function say(player: Player, text: string)
	Remotes.Notify:FireClient(player, "Message", { Speaker = "Postmaster Gruff", Text = text })
end

-- Gives what a product buys. Returns false if it can't be given right now (e.g. nothing left to unlock),
-- which tells Roblox not to charge.
local function grant(player: Player, profile: DataService.Profile, key: string): boolean
	local jobs = Money.CoinPackJobs[key]
	if jobs then
		local coins = Economy.BestBaseValue(player) * jobs -- scales with your best animal
		profile.Coins += coins
		Analytics.Earn(player, coins, profile.Coins, key, true)
		say(player, `{coins} coins. Don't let it go to your head.`)
		return true
	elseif key == "UnlockNext" then
		for _, animal in Config.Animals.List do
			if not profile.Owned[animal.Id] and animal.Tier <= Money.UnlockNextMaxTier then
				profile.Owned[animal.Id] = true
				say(player, `Fine. The {animal.DisplayName} is yours. Go box it.`)
				return true
			end
		end
		return false
	elseif key == "PriorityStamps" then
		profile.Stamps.Priority = (profile.Stamps.Priority or 0) + Money.PriorityStampCount
		say(player, `{Money.PriorityStampCount} Priority stamps. Use them wisely. You won't.`)
		return true
	elseif key == "GruffCoffee" then
		say(player, "...A coffee? For me? ...Hmph. Thanks. Now get back to work.")
		Remotes.Notify:FireClient(player, "Coffee", {})
		return true
	end
	return false
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local profile = player and DataService.Get(player)
	if not (player and profile) then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- not in this server (or still loading): retry later
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if table.find(profile.Receipts, purchaseId) then
		-- Already given. Just make sure it's saved.
		return if DataService.SaveNow(player)
			then Enum.ProductPurchaseDecision.PurchaseGranted
			else Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local key: string? = nil
	for _, product in Money.Products do
		if product.Id ~= 0 and product.Id == receipt.ProductId then
			key = product.Key
		end
	end
	if not key or not grant(player, profile, key) then
		warn(`[Monetization] Couldn't grant product {receipt.ProductId} to {player.Name}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	table.insert(profile.Receipts, purchaseId)
	while #profile.Receipts > RECEIPTS_KEPT do
		table.remove(profile.Receipts, 1)
	end
	Economy.Sync(player)
	return if DataService.SaveNow(player)
		then Enum.ProductPurchaseDecision.PurchaseGranted
		else Enum.ProductPurchaseDecision.NotProcessedYet
end

-- VIP pass: a golden tag over your head
local function addVipTag(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head or not MonetizationService.HasPass(player, "VIP") or head:FindFirstChild("VipTag") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "VipTag"
	gui.Size = UDim2.fromOffset(80, 26)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 80
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 205, 50)
	label.TextStrokeTransparency = 0
	label.Text = "★ VIP ★"
	label.Parent = gui
	gui.Parent = head
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Head", 10)
		addVipTag(player)
	end)
	player:GetAttributeChangedSignal("Pass_VIP"):Connect(function()
		addVipTag(player)
	end)
	checkPasses(player)
	addVipTag(player)
end

function MonetizationService.Start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, bought: boolean)
		if not bought then
			return
		end
		for _, pass in Money.Passes do
			if pass.Id == passId then
				player:SetAttribute(`Pass_{pass.Key}`, true)
				say(player, `{pass.DisplayName}! ...Fancy.`)
			end
		end
	end)
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(watchPlayer, player)
	end
end

return MonetizationService
