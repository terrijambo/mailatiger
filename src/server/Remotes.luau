--!strict
-- Creates the RemoteEvents the server and clients use to talk.
--   Notify         server -> client   Notify:FireClient(player, kind, data)
--   RequestAnimal  client -> server   the player picked an animal in the Pen menu (server checks everything)
--   BoxingInput    client -> server   a button press in the Stuff or Tape stage (server judges it)
--   ShopAction     client -> server   buy/equip/upgrade/rebirth at the Supply Shop (server checks everything)
--   Shove          client -> server   Chaos Mode shove (server picks the target and checks range/cooldown)
--   MailAnywhere   client -> server   press M to mail your bag from anywhere (Rocket Chute only; server checks)
--   Tutorial       client -> server   "Done" or "Skip" for Gruff's walkthrough (server checks the reward)
--   Setting        client -> server   turn a setting (Music, Sfx, Motion) on or off; saved with your progress

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = Instance.new("Folder")
folder.Name = "Remotes"

local function remote(name: string): RemoteEvent
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = folder
	return event
end

local notify = remote("Notify")
local requestAnimal = remote("RequestAnimal")
local boxingInput = remote("BoxingInput")
local shopAction = remote("ShopAction")
local shove = remote("Shove")
local mailAnywhere = remote("MailAnywhere")
local tutorial = remote("Tutorial")
local setting = remote("Setting")

folder.Parent = ReplicatedStorage

-- Connects a server handler that ignores a player who fires this remote more than `perSecond` times a
-- second (with a burst allowance of the same size). Normal play never gets near it; it just stops an
-- exploiter from flooding the server. Every client -> server remote goes through this.
local function listen(event: RemoteEvent, perSecond: number, handler: (Player, ...any) -> ())
	local buckets: { [Player]: { Tokens: number, At: number } } = {}
	event.OnServerEvent:Connect(function(player: Player, ...: any)
		local now = os.clock()
		local bucket = buckets[player]
		if not bucket then
			bucket = { Tokens = perSecond, At = now }
			buckets[player] = bucket
		end
		bucket.Tokens = math.min(perSecond, bucket.Tokens + (now - bucket.At) * perSecond)
		bucket.At = now
		if bucket.Tokens < 1 then
			return
		end
		bucket.Tokens -= 1
		handler(player, ...)
	end)
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

return {
	Listen = listen,
	Notify = notify,
	RequestAnimal = requestAnimal,
	BoxingInput = boxingInput,
	ShopAction = shopAction,
	Shove = shove,
	MailAnywhere = mailAnywhere,
	Tutorial = tutorial,
	Setting = setting,
}
