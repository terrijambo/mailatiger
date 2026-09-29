--!strict
-- Creates the RemoteEvents the server and clients use to talk.
--   Notify         server -> client   Notify:FireClient(player, kind, data)
--   RequestAnimal  client -> server   the player picked an animal in the Pen menu (server checks everything)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = Instance.new("Folder")
folder.Name = "Remotes"

local notify = Instance.new("RemoteEvent")
notify.Name = "Notify"
notify.Parent = folder

local requestAnimal = Instance.new("RemoteEvent")
requestAnimal.Name = "RequestAnimal"
requestAnimal.Parent = folder

folder.Parent = ReplicatedStorage

return {
	Notify = notify,
	RequestAnimal = requestAnimal,
}
