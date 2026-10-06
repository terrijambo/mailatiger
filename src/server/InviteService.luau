--!strict
-- Inviting friends pays diamonds (Config/Social.luau Invites).
-- The INVITE button sends Roblox's invite with your UserId tucked inside ("launch data"). A brand-new player who
-- joins from it gets a welcome gift, and once they've mailed a few animals, you get paid: right away if you're
-- in their server, otherwise it waits in a small DataStore until you next join.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local MailService = require(script.Parent.MailService)
local Remotes = require(script.Parent.Remotes)

local Invites = Config.Social.Invites

local InviteService = {}

local store: DataStore? = nil

local function say(player: Player, text: string)
	Remotes.Notify:FireClient(player, "Message", { Speaker = "Postmaster Gruff", Text = text })
end

local function keyFor(userId: number): string
	return `Inviter_{userId}`
end

-- Pays an inviter for `count` friends (up to the lifetime limit)
local function payInviter(player: Player, count: number, friendName: string?)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local allowed = math.min(count, Invites.MaxRewards - profile.InviteRewards)
	if allowed <= 0 then
		return
	end
	profile.InviteRewards += allowed
	Economy.AddDiamonds(player, Invites.InviterReward * allowed, "Invite")
	Analytics.Custom(player, "InvitePaid", allowed)
	if friendName then
		say(player, `{friendName} joined from your invite and got going. Here's {Invites.InviterReward} diamonds!`)
	else
		say(
			player,
			`{allowed} friend{if allowed == 1 then "" else "s"} you invited got going while you were away. Here's your diamonds!`
		)
	end
end

-- Rewards that were waiting for this player (their friends finished while they were offline)
local function claimWaiting(player: Player)
	local activeStore = store
	if not activeStore then
		return
	end
	local waiting = 0
	local ok, err = pcall(function()
		activeStore:UpdateAsync(keyFor(player.UserId), function(old: any)
			waiting = if type(old) == "number" then old else 0
			if waiting <= 0 then
				return nil -- nothing waiting: don't write
			end
			return 0
		end)
	end)
	if not ok then
		warn(`[InviteService] Checking invite rewards for {player.Name} failed: {err}`)
		return
	end
	if waiting > 0 and player.Parent then
		payInviter(player, waiting)
	end
end

-- A new player: did they come from a friend's invite?
local function checkJoin(player: Player)
	local profile = DataService.Get(player)
	if not profile or profile.InvitedBy ~= 0 or profile.Mailed > 0 then
		return -- only brand-new players count
	end
	local ok, joinData = pcall(player.GetJoinData, player)
	local launchData = if ok and type(joinData) == "table" then joinData.LaunchData else nil
	local inviterId = if type(launchData) == "string" then tonumber(launchData) else nil
	if not inviterId or inviterId <= 0 or inviterId == player.UserId or inviterId % 1 ~= 0 then
		return
	end
	-- Invites only go to friends; checking stops someone sharing a link around for free diamonds
	local friendsOk, friends = pcall(player.IsFriendsWithAsync, player, inviterId)
	if not friendsOk or friends ~= true then
		return
	end
	profile = DataService.Get(player)
	if not profile or profile.InvitedBy ~= 0 then
		return
	end
	profile.InvitedBy = inviterId
	Economy.AddDiamonds(player, Invites.NewPlayerGift, "InviteGift")
	Analytics.Custom(player, "JoinedFromInvite")
	local inviter = Players:GetPlayerByUserId(inviterId)
	say(
		player,
		`Welcome! Your friend{if inviter then " " .. inviter.DisplayName else ""} invited you, so here's {Invites.NewPlayerGift} diamonds to start.`
	)
end

-- Called after each mailed animal: pays the inviter once their friend has mailed enough
local function onMailed(player: Player)
	local profile = DataService.Get(player)
	if not profile or profile.InvitedBy == 0 or profile.InvitePaid or profile.Mailed < Invites.PayAfterMails then
		return
	end
	profile.InvitePaid = true
	local inviterId = profile.InvitedBy
	local inviter = Players:GetPlayerByUserId(inviterId)
	if inviter and DataService.Get(inviter) then
		payInviter(inviter, 1, player.DisplayName)
		return
	end
	-- They're not here: leave it waiting for their next join
	local activeStore = store
	if not activeStore then
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			activeStore:UpdateAsync(keyFor(inviterId), function(old: any)
				return (if type(old) == "number" then old else 0) + 1
			end)
		end)
		if not ok then
			warn(`[InviteService] Saving an invite reward for {inviterId} failed: {err}`)
		end
	end)
end

function InviteService.Start()
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, Invites.StoreName)
	if ok then
		store = result
	end

	DataService.Loaded:Connect(function(player: Player)
		task.spawn(checkJoin, player)
		if DataService.IsOnline() then
			task.spawn(claimWaiting, player)
		end
	end)

	-- Runs alongside whatever else listens for mailed animals (EventService's Rush Order)
	local previous = MailService.OnMailed
	MailService.OnMailed = function(player: Player, animalId: string)
		if previous then
			previous(player, animalId)
		end
		onMailed(player)
	end
end

return InviteService
