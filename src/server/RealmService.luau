--!strict
-- Realms (Config/Realms.luau, docs/REALMS_PLAN.md): buying the next realm and travelling between the ones you
-- have. Clients send Realm("Buy") or Realm("Go", index); the server checks everything.
--
-- Buying the next realm needs the realm's chute level, its rebirths and its price in coins. Then you move in:
-- coins, chute level, XP, machines, rebirths, animals, boxes and stamps start over (like a rebirth, and your
-- rebirths too), but you keep Rebirth Points, upgrades, tools, troll items, quests and your collection, and you
-- earn Rebirth Points x2 for every realm past the first.
--
-- Players from before realms were moved in by DataService (by the level they'd reached); the first time they
-- join after that, Gruff pays them a moving-day gift.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Orders = require(script.Parent.Orders)
local Remotes = require(script.Parent.Remotes)
local Travel = require(script.Parent.Travel)

local Realms = Config.Realms

local RealmService = {}

-- Gruff's moving-day gift for players who were already playing: this many minutes of chute income
local GIFT_MINUTES = 10

local function say(player: Player, text: string)
	Remotes.Notify:FireClient(player, "Message", { Speaker = "Postmaster Gruff", Text = text })
end

-- Buy the next realm and move in
function RealmService.Buy(player: Player): boolean
	local profile = DataService.Get(player)
	if not profile or player:GetAttribute("Stage") == "Box" then
		return false
	end
	local price = Realms.Price(profile.Realm)
	if not price then
		say(player, "You're in the last realm already. Nothing left to buy... yet!")
		return false
	end
	local nextRealm = Realms.At(profile.Realm + 1)
	local missing = Realms.Missing(profile.Realm, profile.Level, profile.Rebirths)
	if #missing > 0 then
		say(player, `To move to the {nextRealm.DisplayName}: {table.concat(missing, ", ")}.`)
		Analytics.Blocked(player, "RealmNeeds", nextRealm.Id)
		return false
	end
	if profile.Coins < price then
		say(player, `The {nextRealm.DisplayName} costs {Format.Short(price)} coins.`)
		Analytics.Blocked(player, "RealmCoins", nextRealm.Id)
		return false
	end

	Analytics.Spend(player, profile.Coins, 0, `Realm_{nextRealm.Id}`)
	-- Value: which realm. Fields: days since first join, total playtime, the realm's id
	Analytics.Custom(
		player,
		"RealmBought",
		nextRealm.Index,
		Analytics.DayBand(player),
		`{math.floor(Analytics.PlayMinutes(player) / 30) * 30}m+`,
		nextRealm.Id
	)
	Analytics.Milestone(player, `Realm_{nextRealm.Id}`)
	Analytics.Progress(player, "Realm", nextRealm.Index)

	-- Start over in the new realm (see the top of this file for what's kept)
	profile.Realm = nextRealm.Index
	profile.Coins = 0
	profile.Level = 1
	profile.XP = 0
	profile.Rebirths = 0
	profile.Owned = { Hamster = true }
	profile.Boxes = { Cardboard = true }
	profile.EquippedBox = "Cardboard"
	profile.Stamps = {}
	profile.SelectedStamp = nil
	profile.Machines = {}
	-- Head Start (Rebirth Upgrade): keep your first few machines, as after a rebirth
	local keep = Economy.UpgradeBonus(player, "RebirthKit")
	for index, machine in Config.Machines.List do
		if index <= keep then
			profile.Machines[machine.Id] = true
		end
	end
	Orders.Refresh(profile, true)
	Economy.Sync(player)
	Remotes.Notify:FireClient(player, "RealmMoved", {
		Index = nextRealm.Index,
		Name = nextRealm.DisplayName,
		Emoji = nextRealm.Emoji,
		PointsMult = Realms.PointsMultFor(nextRealm.Index),
	})
	say(
		player,
		`Welcome to the {nextRealm.DisplayName}! New animals, bigger pay, and every rebirth here pays x{Realms.PointsMultFor(
			nextRealm.Index
		)} Rebirth Points.`
	)
	task.delay(1.5, function()
		if player.Parent then
			Travel.ToRealm(player, nextRealm.Index)
		end
	end)
	return true
end

-- Players who were already playing before realms: a moving-day gift, once
local function giftIfDue(player: Player)
	local profile = DataService.Get(player)
	if not profile or not profile.RealmGiftDue then
		return
	end
	profile.RealmGiftDue = false
	local coins = Economy.AddPrize(player, GIFT_MINUTES, "RealmGift")
	local realm = Realms.At(profile.Realm)
	say(
		player,
		`Big news: the world is split into REALMS now! You live in the {realm.DisplayName}, with everything you had. Here's {Format.Short(
			coins
		)} coins for moving day. MENU > REALMS shows what's next.`
	)
end

function RealmService.Start()
	Remotes.Listen(Remotes.Realm, 2, function(player: Player, action: any, index: any)
		if action == "Buy" then
			RealmService.Buy(player)
		elseif action == "Go" and type(index) == "number" and index == index then
			Travel.ToRealm(player, math.floor(index))
		end
	end)
	DataService.Loaded:Connect(function(player: Player)
		task.delay(4, function()
			if player.Parent then
				giftIfDue(player)
			end
		end)
	end)
end

return RealmService
