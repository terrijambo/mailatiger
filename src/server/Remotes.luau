--!strict
-- Creates the RemoteEvents the server and clients use to talk.
--   Notify         server -> client   Notify:FireClient(player, kind, data)
--   RequestAnimal  client -> server   the player picked an animal in the Pen menu (server checks everything)
--   BoxingInput    client -> server   a button press in the Stuff or Tape stage (server judges it)
--   ShopAction     client -> server   buy/equip/upgrade/rebirth at the Supply Shop (server checks everything)
--   Shove          client -> server   Chaos Mode shove (server picks the target and checks range/cooldown)
--   MailAnywhere   client -> server   press M to mail your bag from anywhere (Rocket Chute only; server checks)

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

folder.Parent = ReplicatedStorage

return {
	Notify = notify,
	RequestAnimal = requestAnimal,
	BoxingInput = boxingInput,
	ShopAction = shopAction,
	Shove = shove,
	MailAnywhere = mailAnywhere,
}
