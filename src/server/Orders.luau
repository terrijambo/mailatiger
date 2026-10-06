--!strict
-- Gruff's orders board: a few orders like "Mail a Skunk with 4+ stamps" that pay bonus coins.
-- They only ask for animals you own, so there's always something you can do, and they refresh every
-- Config.Progression.Orders.RefreshMinutes minutes. Orders are saved with your profile.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)

type Profile = DataService.Profile
type Order = DataService.Order

local Tuning = Config.Progression.Orders
local CONDITIONS = { "Any", "Stars4", "NoEscape", "UnderPar" }

export type JobResult = {
	Stars: number,
	Escapes: number,
	UnderPar: boolean,
}

local Orders = {}

local function waiting(order: Order): boolean
	return order.Done and order.Claimed == false
end

-- Makes new orders if it's time (or `force` is true). Returns whether anything changed.
-- Finished orders you haven't claimed yet are kept (they stay until you press CLAIM).
function Orders.Refresh(profile: Profile, force: boolean?): boolean
	-- New orders when it's time, or as soon as every order is done (so "complete N orders" quests never get stuck)
	local allDone = true
	local kept: { Order } = {}
	for _, order in profile.Orders do
		if not order.Done then
			allDone = false
		end
		if waiting(order) then
			table.insert(kept, order)
		end
	end
	if not force and not allDone and os.time() < profile.OrdersRefreshAt then
		return false
	end

	local choices = {}
	for animalId in profile.Owned do
		local animal = Config.Animals.ById[animalId]
		if animal and animal.Carriers == 1 then
			table.insert(choices, animal)
		end
	end
	if #choices == 0 then
		return false
	end

	local busyDesk = Config.Diamonds.Bonus(Config.Diamonds.ById.BusyDesk, profile.Upgrades.BusyDesk or 0)
	local slots = Tuning.Count + busyDesk - #kept
	if slots <= 0 then
		return false -- (all of them are waiting to be claimed)
	end
	local orders: { Order } = kept
	for _ = 1, slots do
		local animal = choices[math.random(1, #choices)]
		local condition = CONDITIONS[math.random(1, #CONDITIONS)]
		local mult = Tuning.MinRewardMult + math.random() * (Tuning.MaxRewardMult - Tuning.MinRewardMult)
		if condition ~= "Any" then
			mult *= Tuning.HardConditionMult
		end
		table.insert(orders, {
			AnimalId = animal.Id,
			Condition = condition,
			Reward = math.max(5, math.round(animal.BaseValue * mult)),
			Done = false,
		})
	end
	profile.Orders = orders
	profile.OrdersRefreshAt = os.time() + Tuning.RefreshMinutes * 60
	return true
end

-- Pays nothing itself: returns the reward for a finished order and marks it claimed (nil if it can't be)
function Orders.Claim(profile: Profile, index: number): number?
	local order = profile.Orders[index]
	if not order or not waiting(order) then
		return nil
	end
	order.Claimed = true
	return order.Reward
end

local function conditionMet(condition: string, result: JobResult): boolean
	if condition == "Stars4" then
		return result.Stars >= 4
	elseif condition == "NoEscape" then
		return result.Escapes == 0
	elseif condition == "UnderPar" then
		return result.UnderPar
	end
	return true
end

-- Call after a job is mailed. Marks matching orders done (ready to claim).
-- Returns the coins now waiting to be claimed, and how many orders this completed
function Orders.OnMailed(profile: Profile, animalId: string, result: JobResult): (number, number)
	local total, completed = 0, 0
	for _, order in profile.Orders do
		if not order.Done and order.AnimalId == animalId and conditionMet(order.Condition, result) then
			order.Done = true
			order.Claimed = false -- (paid when they press CLAIM on the Orders board)
			total += order.Reward
			completed += 1
		end
	end
	return total, completed
end

return Orders
