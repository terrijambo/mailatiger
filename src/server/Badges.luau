--!strict
-- Awards Roblox badges (ids in src/shared/Config/Badges.luau). Badges with Id 0 are skipped, and each
-- badge is only tried once per player per server, so this never spams Roblox's badge service.

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Badges = {}

local tried: { [Player]: { [string]: boolean } } = {}

function Badges.Award(player: Player, key: string)
	local badge = Config.Badges[key]
	if not badge or badge.Id == 0 then
		return
	end
	local mine = tried[player]
	if not mine then
		mine = {}
		tried[player] = mine
	end
	if mine[key] then
		return
	end
	mine[key] = true
	task.spawn(function()
		local ok, has = pcall(BadgeService.UserHasBadgeAsync, BadgeService, player.UserId, badge.Id)
		if ok and not has then
			pcall(BadgeService.AwardBadge, BadgeService, player.UserId, badge.Id)
		end
	end)
end

Players.PlayerRemoving:Connect(function(player)
	tried[player] = nil
end)

return Badges
