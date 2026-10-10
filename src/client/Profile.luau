--!strict
-- Reads your saved progress, which the server copies onto you as the "Profile" attribute (JSON).
-- Read-only: changing it here does nothing. Only the server can change your progress.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer

local Profile = {}

export type Data = {
	Coins: number,
	Owned: { [string]: boolean },
	Boxes: { [string]: boolean },
	EquippedBox: string,
	Tools: { [string]: number },
	Stamps: { [string]: number },
	SelectedStamp: string?,
	Rebirths: number,
	Mailed: number,
	Orders: { { AnimalId: string, Condition: string, Reward: number, Done: boolean, Claimed: boolean? } },
	OrdersRefreshAt: number,
	Parcels: { { AnimalId: string, Stars: number, Coins: number, Machines: { [string]: boolean }? } },
	ChuteTier: string,
	Machines: { [string]: boolean }?,
	Processing: { [string]: { Parcels: { any }, ReadyAt: number } }?,
	RebirthPoints: number?,
	TutorialDone: boolean?,
	Settings: { [string]: boolean }?,
	Level: number,
	XP: number,
	Quest: number,
	QuestProgress: number,
	OrdersDone: number,
	Species: { [string]: number },
	Trolls: { [string]: boolean },
	FollowAsked: number?,
	InviteRewards: number?,
	Upgrades: { [string]: number },
	Shinies: { [string]: number }?,
	Goldens: { [string]: number }?,
	Challenges: {
		Day: number,
		Daily: { { Id: string, Progress: number, Done: boolean, Claimed: boolean? } },
		Week: number,
		Weekly: { { Id: string, Progress: number, Done: boolean, Claimed: boolean? } },
		Streak: number,
		LastAllDay: number,
	}?,
}

local EMPTY: Data = {
	Coins = 0,
	Parcels = {},
	ChuteTier = "Basic",
	Owned = { Hamster = true },
	Boxes = { Cardboard = true },
	EquippedBox = "Cardboard",
	Tools = {},
	Stamps = {},
	SelectedStamp = nil,
	Rebirths = 0,
	Mailed = 0,
	Orders = {},
	OrdersRefreshAt = 0,
	Level = 1,
	XP = 0,
	Quest = 1,
	QuestProgress = 0,
	OrdersDone = 0,
	Species = {},
	Trolls = {},
	Upgrades = {},
}

function Profile.Get(): Data
	local raw = player:GetAttribute("Profile")
	if typeof(raw) ~= "string" then
		return EMPTY
	end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok and type(data) == "table" then data else EMPTY
end

-- How many parcels your bag holds (starting size + Mail Bag upgrades)
-- Whether a setting (Music, Sfx, Motion) is on. Everything starts on.
-- A setting's saved value; missing = `default` (on, unless given)
function Profile.Setting(name: string, default: boolean?): boolean
	local settings = Profile.Get().Settings
	local value = settings and settings[name]
	if value == nil then
		return default ~= false
	end
	return value == true
end

function Profile.BagCapacity(data: Data): number
	local mail = Config.Mail
	local bigBag = if player:GetAttribute("Pass_BigBag") == true then Config.Monetization.BigBagSlots else 0
	local pockets = Config.Upgrades.Bonus(Config.Upgrades.ById.DeepPockets, data.Upgrades.DeepPockets or 0)
	return mail.BagCapacity + (data.Tools.MailBag or 0) * Config.Tools.ById.MailBag.PerLevel + bigBag + pockets
end

-- Calls `callback` now and whenever your progress changes.
-- How many finished orders and challenges are waiting for CLAIM (for the red "!" dots)
function Profile.Claimable(data: Data): number
	local count = 0
	for _, order in data.Orders do
		if order.Done and order.Claimed == false then
			count += 1
		end
	end
	local state = data.Challenges
	if state then
		for _, list in { state.Daily, state.Weekly } do
			for _, entry in list do
				if entry.Done and entry.Claimed == false then
					count += 1
				end
			end
		end
	end
	return count
end

-- Still doing Gruff's first-time walkthrough? (Simple start: most of the HUD stays hidden until it's done,
-- so a new player only sees what they need right now)
function Profile.Learning(): boolean
	return Profile.Get().TutorialDone ~= true
end

function Profile.Watch(callback: () -> ())
	player:GetAttributeChangedSignal("Profile"):Connect(callback)
	callback()
end

return Profile
