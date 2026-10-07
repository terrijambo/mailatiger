--!strict
-- The Supply Shop (boxes, tools, stamps, chutes, rebirth) and Gruff's orders board.
-- Clients send ShopAction(action, id). The server checks coins, distance and ownership before changing anything.
--   BuyBox / EquipBox (box id)   UpgradeTool (tool id)   BuyStamp / SelectStamp (stamp id, "" = none)
--   BuyChute (chute id, must be the next one up)   Rebirth   BuyTroll (troll id)
--   BuyUpgrade (diamond upgrade id)   StudioBuy (Robux item key, Studio testing only)
--   Claim ("O2" / "D1" / "W1" / "All")   Promo (Promo Kit shot setup, Studio only)

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Analytics = require(script.Parent.Analytics)
local Badges = require(script.Parent.Badges)
local BossService = require(script.Parent.BossService)
local ChallengeService = require(script.Parent.ChallengeService)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local EventService = require(script.Parent.EventService)
local MapBuilder = require(script.Parent.MapBuilder)
local MonetizationService = require(script.Parent.MonetizationService)
local Orders = require(script.Parent.Orders)
local Remotes = require(script.Parent.Remotes)
local Travel = require(script.Parent.Travel)
local TrollService = require(script.Parent.TrollService)

local ShopService = {}

local map: MapBuilder.Map

local function reply(player: Player, text: string)
	Remotes.Notify:FireClient(player, "Message", { Speaker = "Supply Shop", Text = text })
end

-- Promo Kit (client/PromoKit.luau): set up shots for promo videos. Studio only, so it can't be used live.
local defaultClock: number? = nil
local function promo(player: Player, profile: DataService.Profile, id: string)
	if not RunService:IsStudio() then
		return
	end
	if id == "Golden" or id == "Shiny" then
		player:SetAttribute("PromoVariant", id)
		Remotes.Notify:FireClient(player, "Message", { Speaker = "Promo Kit", Text = `Your next animal will be {id}.` })
	elseif id == "UnlockAll" then
		for _, animal in Config.Animals.List do
			profile.Owned[animal.Id] = true
		end
		for _, level in Config.Levels.ZoneLevels do
			profile.Level = math.max(profile.Level, level)
		end
		profile.Coins += 1000000
		Economy.Sync(player)
		Remotes.Notify:FireClient(
			player,
			"Message",
			{ Speaker = "Promo Kit", Text = "Every animal and zone unlocked, +1M coins." }
		)
	elseif id == "Sunset" or id == "Day" or id == "Night" then
		defaultClock = defaultClock or Lighting.ClockTime
		Lighting.ClockTime = if id == "Sunset" then 17.7 elseif id == "Night" then 0 else defaultClock :: number
	end
end

-- CLAIM on the Orders board. id: "O2" (side order 2), "D1" (daily 1), "W1" (weekly 1), or "All"
local function claim(player: Player, profile: DataService.Profile, id: string)
	local coins = 0
	local function claimOrder(index: number)
		local reward = Orders.Claim(profile, index)
		if reward then
			coins += reward
		end
	end
	if id == "All" then
		for index = 1, #profile.Orders do
			claimOrder(index)
		end
		for index = 1, #profile.Challenges.Daily do
			ChallengeService.Claim(player, false, index)
		end
		for index = 1, #profile.Challenges.Weekly do
			ChallengeService.Claim(player, true, index)
		end
	else
		local kind, number = string.match(id, "^(%u)(%d+)$")
		local index = tonumber(number)
		if not index then
			return
		end
		if kind == "O" then
			claimOrder(index)
		elseif kind == "D" or kind == "W" then
			ChallengeService.Claim(player, kind == "W", index)
		end
	end
	if coins > 0 then
		Economy.AddCoins(player, coins, "Order")
	end
	-- Every order done and claimed: new ones right away
	if Orders.Refresh(profile) then
		Remotes.Notify:FireClient(
			player,
			"Message",
			{ Speaker = "Postmaster Gruff", Text = "New orders are up on my board!" }
		)
	end
	Remotes.Notify:FireClient(player, "Claimed", {})
	Economy.Sync(player)
end

local function onShopAction(player: Player, action: unknown, id: unknown)
	local profile = DataService.Get(player)
	if not profile or typeof(action) ~= "string" then
		return
	end
	local itemId = if typeof(id) == "string" then id else ""

	-- (The shop works from anywhere: the SHOP button opens it, and the map is too big to walk back each time.
	-- Coins and everything else are still checked below.)
	if action == "BuyTroll" then
		TrollService.Buy(player, itemId)
		return
	elseif action == "BuyUpgrade" then
		local ok, text = Economy.BuyUpgrade(player, itemId)
		if text ~= "" then
			Remotes.Notify:FireClient(player, "Message", { Speaker = "Diamond Upgrades", Text = text })
		end
		if ok then
			Remotes.Notify:FireClient(player, "UpgradeBought", { Id = itemId })
		end
		return
	elseif action == "StudioBuy" then
		MonetizationService.StudioBuy(player, itemId)
		return
	elseif action == "Promo" then
		promo(player, profile, itemId) -- (Studio only)
		return
	elseif action == "Claim" then
		claim(player, profile, itemId)
		return
	elseif action == "FollowAsked" then
		-- The Favorite / Get updates card was shown (so it's only asked a couple of times, ever)
		profile.FollowAsked = math.min(profile.FollowAsked + 1, 99)
		DataService.Sync(player)
		return
	elseif action == "GoToBoss" then
		BossService.TeleportIn(player)
		return
	elseif action == "GoToGruff" then
		Travel.ToGruff(player)
		return
	elseif action == "StudioEvent" then
		EventService.StudioStart(itemId) -- (does nothing outside Studio)
		return
	elseif action == "RefreshOrders" then
		-- Opening Gruff's Orders from the side button: new orders if the old ones ran out
		if Orders.Refresh(profile) then
			Economy.Sync(player)
		end
		return
	elseif action == "BuyBox" then
		local box = Config.Boxes.ById[itemId]
		if not box or profile.Boxes[itemId] then
			return
		end
		if not Economy.TrySpend(player, box.Price, `Box_{itemId}`) then
			reply(player, `The {box.DisplayName} costs {Format.Short(box.Price)} coins.`)
			return
		end
		profile.Boxes[itemId] = true
		profile.EquippedBox = itemId
		reply(player, `Bought the {box.DisplayName}! It's equipped.`)
	elseif action == "EquipBox" then
		if profile.Boxes[itemId] then
			profile.EquippedBox = itemId
		end
	elseif action == "UpgradeTool" then
		local tool = Config.Tools.ById[itemId]
		if not tool then
			return
		end
		local level = profile.Tools[itemId] or 0
		if level >= tool.MaxLevel then
			reply(player, `Your {tool.DisplayName} are maxed out.`)
			return
		end
		local price = Config.Tools.PriceFor(tool, level)
		if not Economy.TrySpend(player, price, `Tool_{itemId}_{level + 1}`) then
			reply(player, `Level {level + 1} {tool.DisplayName} costs {Format.Short(price)} coins.`)
			return
		end
		profile.Tools[itemId] = level + 1
		reply(player, `{tool.DisplayName} upgraded to level {level + 1}!`)
	elseif action == "BuyStamp" then
		local stamp = Config.Stamps.ById[itemId]
		if not stamp then
			return
		end
		if not Economy.TrySpend(player, stamp.Price, `Stamp_{itemId}`) then
			reply(player, `A {stamp.DisplayName} stamp costs {Format.Short(stamp.Price)} coins.`)
			return
		end
		profile.Stamps[itemId] = (profile.Stamps[itemId] or 0) + 1
		profile.SelectedStamp = profile.SelectedStamp or itemId
		reply(player, `Bought a {stamp.DisplayName} stamp.`)
	elseif action == "SelectStamp" then
		if itemId == "" then
			profile.SelectedStamp = nil
		elseif (profile.Stamps[itemId] or 0) > 0 then
			profile.SelectedStamp = itemId
		end
	elseif action == "BuyChute" then
		-- Chutes are bought in order: you can only buy the next one up
		local chute = Config.Mail.ChuteById[itemId]
		local current = Config.Mail.ChuteIndex[profile.ChuteTier] or 1
		if not chute or Config.Mail.ChuteIndex[itemId] ~= current + 1 then
			return
		end
		if not Economy.TrySpend(player, chute.Price, `Chute_{itemId}`) then
			reply(player, `The {chute.DisplayName} costs {Format.Short(chute.Price)} coins.`)
			return
		end
		profile.ChuteTier = itemId
		reply(player, `{chute.DisplayName} installed! {chute.Description}`)
	elseif action == "Rebirth" then
		local cost = Economy.RebirthCost(profile.Rebirths)
		if profile.Coins < cost then
			reply(player, `Rebirth costs {Format.Short(cost)} coins.`)
			return
		end
		-- Start over, but keep a permanent coin bonus
		Analytics.Spend(player, profile.Coins, 0, `Rebirth_{profile.Rebirths + 1}`)
		Analytics.Custom(player, "Rebirth", profile.Rebirths + 1)
		Badges.Award(player, "Reborn")
		profile.Coins = 0
		profile.Owned = { Hamster = true }
		profile.Boxes = { Cardboard = true }
		profile.EquippedBox = "Cardboard"
		profile.ChuteTier = "Basic" -- (parcels still in your bag are kept)
		profile.Tools = {}
		-- Rebirth Toolkit (diamond upgrade): tools start at a level instead of 0
		local kit = Economy.UpgradeBonus(player, "RebirthKit")
		if kit > 0 then
			for _, tool in Config.Tools.List do
				profile.Tools[tool.Id] = math.min(kit, tool.MaxLevel)
			end
		end
		profile.Stamps = {}
		profile.SelectedStamp = nil
		profile.Rebirths += 1
		profile.Diamonds += Config.Diamonds.PerRebirth
		Orders.Refresh(profile, true)
		local bonus = math.round(profile.Rebirths * Config.Progression.Rebirth.PayoutBonusPerRebirth * 100)
		reply(
			player,
			`REBIRTH #{profile.Rebirths}! Every job now pays +{bonus}% coins, forever. +{Config.Diamonds.PerRebirth} 💎`
		)
	end

	Economy.Sync(player)
end

function ShopService.Start(builtMap: MapBuilder.Map)
	map = builtMap

	map.ShopPrompt.Triggered:Connect(function(player: Player)
		Remotes.Notify:FireClient(player, "OpenShop", {})
	end)

	map.OrdersPrompt.Triggered:Connect(function(player: Player)
		local profile = DataService.Get(player)
		if profile and Orders.Refresh(profile) then
			Economy.Sync(player)
		end
		Remotes.Notify:FireClient(player, "OpenOrders", {})
	end)

	Remotes.Listen(Remotes.ShopAction, 8, onShopAction)

	-- Fresh orders for everyone online when theirs expire or are all done (not only when the board is opened)
	task.spawn(function()
		while true do
			task.wait(20)
			for player, profile in DataService.GetAll() do
				if Orders.Refresh(profile) then
					Economy.Sync(player)
				end
			end
		end
	end)

	-- New players (and anyone whose orders expired while they were away) get fresh orders on join
	DataService.Loaded:Connect(function(player: Player)
		local profile = DataService.Get(player) -- the real save (the event only passes a copy)
		if profile and Orders.Refresh(profile) then
			Economy.Sync(player)
		end
	end)
end

return ShopService
