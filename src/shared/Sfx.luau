--!strict
-- Plays a sound from Config.Sounds by name, e.g. Sfx.Play("TapeRip") or Sfx.Play("Roar", somePart).
-- Silent (and harmless) while that sound's Id is still "". Works from the server or a client:
--   * with `at` (a part or a position): the sound plays there in 3D
--   * without: it plays "in your ears" (for the local player on a client)

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local Sfx = {}

local lastPlayed: { [string]: number } = {}

function Sfx.Play(name: string, at: (BasePart | Vector3)?)
	local def = Config.Sounds[name]
	if not def or def.Id == "" then
		return
	end
	-- The player turned sound effects off in Settings (the client sets this on itself)
	if RunService:IsClient() and Players.LocalPlayer:GetAttribute("SfxOff") == true then
		return
	end
	local now = os.clock()
	local cooldown = def.Cooldown
	if cooldown and now - (lastPlayed[name] or -math.huge) < cooldown then
		return
	end
	lastPlayed[name] = now

	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = def.Id
	sound.Volume = def.Volume
	sound.PlaybackSpeed = def.Pitch or 1
	sound.RollOffMaxDistance = 150

	if typeof(at) == "Vector3" then
		local attachment = Instance.new("Attachment")
		attachment.WorldPosition = at
		attachment.Parent = Workspace.Terrain
		sound.Parent = attachment
		Debris:AddItem(attachment, 10)
	elseif at then
		sound.Parent = at
	else
		sound.Parent = SoundService
	end
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	Debris:AddItem(sound, 10)
end

return Sfx
