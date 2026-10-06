--!strict
-- Plays sound effects for what happens to you. The sounds themselves (and their ids) live in
-- src/shared/Config/Sounds.luau, and each one is silent until you give it an id.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Profile = require(script.Parent.Profile)
local Sfx = require(ReplicatedStorage.Shared.Sfx)

local Audio = {}

-- Notify event from the server -> sound to play
local FOR_EVENT: { [string]: string } = {
	BoxStart = "Pop",
	SeamTaped = "TapeRip",
	Peel = "TapePeel",
	AngryTouch = "AngryHit",
	Thump = "Growl",
	Parcel = "StampThud",
	Break = "Escape",
	Roar = "Roar",
	Spray = "Spray",
	Freeze = "Freeze",
	Knockback = "Bonk",
	MailReceipt = "MailWhoosh",
	OpenPen = "Click",
	OpenShop = "Click",
	OpenOrders = "Click",
	LevelUp = "LevelUp",
	QuestDone = "QuestDone",
	Diamonds = "Diamond",
	ServerBoost = "ServerBoost",
	UpgradeBought = "Diamond",
	VariantFound = "LevelUp",
	VariantBoxed = "Diamond",
	ChallengeDone = "QuestDone",
	AllDailies = "LevelUp",
	StreakLost = "AngryHit",
	EventStart = "ServerBoost",
	EventWinner = "Ding",
	StampedeCatch = "Pop",
	BossStart = "Roar",
	BossWin = "LevelUp",
	BossReward = "CoinJingle",
	NewSpecies = "CoinJingle",
}

function Audio.Start()
	local notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent
	notify.OnClientEvent:Connect(function(kind: string)
		local name = FOR_EVENT[kind]
		if name then
			Sfx.Play(name)
		end
		if kind == "MailReceipt" then
			task.delay(0.5, Sfx.Play, "CoinJingle")
		end
	end)

	-- Ka-ching when your coins go down (you bought something)
	local lastCoins: number? = nil
	Profile.Watch(function()
		local coins = Profile.Get().Coins
		if lastCoins and coins < lastCoins then
			Sfx.Play("Kaching")
		end
		lastCoins = coins
	end)
end

return Audio
