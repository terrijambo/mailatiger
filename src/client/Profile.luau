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
	Orders: { { AnimalId: string, Condition: string, Reward: number, Done: boolean } },
	OrdersRefreshAt: number,
	Parcels: { { AnimalId: string, Stars: number, Coins: number } },
	ChuteTier: string,
	TutorialDone: boolean?,
	Settings: { [string]: boolean }?,
	Level: number,
	XP: number,
	Quest: number,
	QuestProgress: number,
	OrdersDone: number,
	Species: { [string]: number },
	Trolls: { [string]: boolean },
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
function Profile.Setting(name: string): boolean
	local settings = Profile.Get().Settings
	return not settings or settings[name] ~= false
end

function Profile.BagCapacity(data: Data): number
	local mail = Config.Mail
	local bigBag = if player:GetAttribute("Pass_BigBag") == true then Config.Monetization.BigBagSlots else 0
	return mail.BagCapacity + (data.Tools.MailBag or 0) * Config.Tools.ById.MailBag.PerLevel + bigBag
end

-- Calls `callback` now and whenever your progress changes.
function Profile.Watch(callback: () -> ())
	player:GetAttributeChangedSignal("Profile"):Connect(callback)
	callback()
end

return Profile
