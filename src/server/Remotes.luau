--!strict
-- Creates the RemoteEvents the server uses to talk to clients.
-- Notify:FireClient(player, kind, data) where kind is "Message", "Receipt", "Bell" or "Break".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = Instance.new("Folder")
folder.Name = "Remotes"

local notify = Instance.new("RemoteEvent")
notify.Name = "Notify"
notify.Parent = folder

folder.Parent = ReplicatedStorage

return {
	Notify = notify,
}
