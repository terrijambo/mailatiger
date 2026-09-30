--!strict
-- The Supply Shop (boxes, tools, stamps, chutes, rebirth) and Gruff's orders board.
-- Clients send ShopAction(action, id). The server checks coins, distance and ownership before changing anything.
--   BuyBox / EquipBox (box id)   UpgradeTool (tool id)   BuyStamp / SelectStamp (stamp id, "" = none)
--   BuyChute (chute id, must be the next one up)   Rebirth

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local MapBuilder = require(script.Parent.MapBuilder)
local Orders = require(script.Parent.Orders)
local Remotes = require(script.Parent.Remotes)

local ShopService = {}

local map: MapBuilder.Map

local function reply(player: Player, text: string)
	Remotes.Notify:FireClient(player, "Message", { Speaker = "Supply Shop", Text = text })
end

local function isNear(player: Player, part: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and (root.Position - part.Position).Magnitude <= 20
end

local function onShopAction(player: Player, action: unknown, id: unknown)
	local profile = DataService.Get(player)
	if not profile or typeof(action) ~= "string" then
		return
	end
	local itemId = if typeof(id) == "string" then id else ""

	-- Choosing your next-job stamp works anywhere. Everything else happens at the counter.
	if action ~= "SelectStamp" and not isNear(player, map.ShopCounter) then
		reply(player, "Come back to the Supply Shop counter for that.")
		return
	end

	if action == "BuyBox" then
		local box = Config.Boxes.ById[itemId]
		if not box or profile.Boxes[itemId] then
			return
		end
		if not Economy.TrySpend(player, box.Price, `Box_{itemId}`) then
			reply(player, `The {box.DisplayName} costs {box.Price} coins.`)
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
			reply(player, `Level {level + 1} {tool.DisplayName} costs {price} coins.`)
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
			reply(player, `A {stamp.DisplayName} stamp costs {stamp.Price} coins.`)
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
			reply(player, `The {chute.DisplayName} costs {chute.Price} coins.`)
			return
		end
		profile.ChuteTier = itemId
		reply(player, `{chute.DisplayName} installed! {chute.Description}`)
	elseif action == "Rebirth" then
		local cost = Economy.RebirthCost(profile.Rebirths)
		if profile.Coins < cost then
			reply(player, `Rebirth costs {cost} coins.`)
			return
		end
		-- Start over, but keep a permanent coin bonus
		Analytics.Spend(player, profile.Coins, 0, `Rebirth_{profile.Rebirths + 1}`)
		Analytics.Custom(player, "Rebirth", profile.Rebirths + 1)
		profile.Coins = 0
		profile.Owned = { Hamster = true }
		profile.Boxes = { Cardboard = true }
		profile.EquippedBox = "Cardboard"
		profile.ChuteTier = "Basic" -- (parcels still in your bag are kept)
		profile.Tools = {}
		profile.Stamps = {}
		profile.SelectedStamp = nil
		profile.Rebirths += 1
		Orders.Refresh(profile, true)
		local bonus = math.round(profile.Rebirths * Config.Progression.Rebirth.PayoutBonusPerRebirth * 100)
		reply(player, `REBIRTH #{profile.Rebirths}! Every job now pays +{bonus}% coins, forever.`)
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

	Remotes.ShopAction.OnServerEvent:Connect(onShopAction)

	-- New players (and anyone whose orders expired while they were away) get fresh orders on join
	DataService.Loaded:Connect(function(player: Player, profile: DataService.Profile)
		if Orders.Refresh(profile) then
			Economy.Sync(player)
		end
	end)
end

return ShopService
