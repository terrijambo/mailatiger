--!strict
-- Reward codes (list in src/shared/Config/Codes.luau). Players type them into Settings -> "Redeem a code".
-- The server checks everything: the code exists, hasn't expired, and this player hasn't used it before.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Remotes = require(script.Parent.Remotes)

local CodesService = {}

local function reply(player: Player, text: string)
	Remotes.Notify:FireClient(player, "Message", { Speaker = "Postmaster Gruff", Text = text })
end

function CodesService.Start()
	-- 1 try per second is plenty for typing, and stops anyone guessing codes by brute force
	Remotes.Listen(Remotes.RedeemCode, 1, function(player: Player, typed: unknown)
		local profile = DataService.Get(player)
		if not profile or typeof(typed) ~= "string" or #typed > 40 then
			return
		end
		local key = string.upper((string.gsub(typed, "%s", "")))
		local code = Config.Codes[key]
		if not code or (code.Expires and os.time() > code.Expires) then
			reply(player, "Never heard of that code. Did you make it up?")
			return
		end
		if profile.Codes[key] then
			reply(player, "You already used that one. Nice try.")
			return
		end
		profile.Codes[key] = true

		local gifts = {}
		if code.Jobs then
			local coins = Economy.BestBaseValue(player) * code.Jobs
			profile.Coins += coins
			Analytics.Earn(player, coins, profile.Coins, `Code_{key}`)
			table.insert(gifts, `{coins} coins`)
		end
		local stamps: { [string]: number } = code.Stamps or {}
		for stampId, count in stamps do
			if Config.Stamps.ById[stampId] then
				profile.Stamps[stampId] = (profile.Stamps[stampId] or 0) + count
				table.insert(gifts, `{count} {Config.Stamps.ById[stampId].DisplayName} stamps`)
			end
		end
		Economy.Sync(player)
		reply(player, `Code accepted: {table.concat(gifts, " and ")}. Don't tell anyone. Actually, do.`)
	end)
end

return CodesService
