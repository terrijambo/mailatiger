--!strict
-- Sends events to Roblox's built-in analytics (Creator Dashboard -> your game -> Analytics).
-- Nothing to set up: it starts showing data once the game is published and people play.
--
--   Onboarding funnel  where new players drop off: joined -> picked an animal -> caught it -> taped it ->
--                      mailed it -> finished the tutorial
--   Economy            where coins come from (mail payouts, orders, packs) and where they go (shop, animals)
--   Custom             fun moments worth counting: launches, escapes, rebirths
--
-- Every call is wrapped so analytics can never break the game (e.g. in Studio, or if Roblox changes the API).

local AnalyticsService = game:GetService("AnalyticsService")

local Analytics = {}

-- Onboarding funnel steps, in order (Roblox wants them numbered from 1)
local STEPS = { "Joined", "PickedAnimal", "Caught", "Taped", "Mailed", "TutorialDone" }
local stepNumber: { [string]: number } = {}
for index, name in STEPS do
	stepNumber[name] = index
end

-- Only new players are in the funnel, and each step is logged once per session
local tracking: { [Player]: { [string]: boolean } } = {}

local function safely(f: () -> ...any)
	local ok, err = pcall(f)
	if not ok then
		warn(`[Analytics] {err}`)
	end
end

-- Call when a new player's save loads (they haven't mailed anything yet)
function Analytics.StartOnboarding(player: Player)
	tracking[player] = {}
	Analytics.Onboarding(player, "Joined")
end

function Analytics.Onboarding(player: Player, step: string)
	local done = tracking[player]
	local number = stepNumber[step]
	if not done or not number or done[step] then
		return
	end
	done[step] = true
	safely(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, number, step)
	end)
end

-- Coins in. `source` is a short id like "MailPayout" or "CoinPack".
function Analytics.Earn(player: Player, amount: number, balance: number, source: string, bought: boolean?)
	if amount <= 0 then
		return
	end
	safely(function()
		AnalyticsService:LogEconomyEvent(
			player,
			Enum.AnalyticsEconomyFlowType.Source,
			"Coins",
			amount,
			balance,
			if bought
				then Enum.AnalyticsEconomyTransactionType.IAP.Name
				else Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
			source
		)
	end)
end

-- Coins out. `item` is what they bought, like "Box_Steel" or "Animal_Tiger".
function Analytics.Spend(player: Player, amount: number, balance: number, item: string)
	if amount <= 0 then
		return
	end
	safely(function()
		AnalyticsService:LogEconomyEvent(
			player,
			Enum.AnalyticsEconomyFlowType.Sink,
			"Coins",
			amount,
			balance,
			Enum.AnalyticsEconomyTransactionType.Shop.Name,
			item
		)
	end)
end

function Analytics.Custom(player: Player, name: string, value: number?)
	safely(function()
		AnalyticsService:LogCustomEvent(player, name, value or 1)
	end)
end

function Analytics.Forget(player: Player)
	tracking[player] = nil
end

return Analytics
