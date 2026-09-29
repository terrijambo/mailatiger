--!strict
-- Creates the RemoteEvents the server and clients use to talk.
--   Notify         server -> client   Notify:FireClient(player, kind, data)
--   RequestAnimal  client -> server   the player picked an animal in the Pen menu (server checks everything)
--   BoxingInput    client -> server   a button press in the Stuff or Tape stage (server judges it)

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

folder.Parent = ReplicatedStorage

return {
	Notify = notify,
	RequestAnimal = requestAnimal,
	BoxingInput = boxingInput,
}
