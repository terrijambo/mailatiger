--!strict
-- Background music: a town track, an arena track while you chase, and a tense track during BOX.
-- Tracks fade into each other. Ids live in src/shared/Config/Sounds.luau (MusicTown, MusicArena,
-- MusicBox); a track with no id is just silence. Turn music off in Settings.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer

local Music = {}

local FADE = TweenInfo.new(1.5)

function Music.Start()
	local tracks: { [string]: Sound } = {}
	for _, name in { "MusicTown", "MusicArena", "MusicBox" } do
		local def = Config.Sounds[name]
		if def and def.Id ~= "" then
			local sound = Instance.new("Sound")
			sound.Name = name
			sound.SoundId = def.Id
			sound.Looped = true
			sound.Volume = 0
			sound:SetAttribute("FullVolume", def.Volume)
			sound.Parent = SoundService
			tracks[name] = sound
		end
	end
	if next(tracks) == nil then
		return -- no music ids set yet
	end

	local current = ""
	local function choose(): string
		if player:GetAttribute("MusicOff") == true then
			return ""
		end
		local stage = player:GetAttribute("Stage")
		if stage == "Box" then
			return "MusicBox"
		elseif stage == "Catch" then
			return "MusicArena"
		end
		return "MusicTown"
	end

	local function refresh()
		local wanted = choose()
		if wanted == current then
			return
		end
		current = wanted
		for name, sound in tracks do
			local on = name == wanted
			if on and not sound.IsPlaying then
				sound:Play()
			end
			local volume = if on then (sound:GetAttribute("FullVolume") :: number?) or 0.25 else 0
			TweenService:Create(sound, FADE, { Volume = volume }):Play()
		end
	end

	player:GetAttributeChangedSignal("Stage"):Connect(refresh)
	player:GetAttributeChangedSignal("MusicOff"):Connect(refresh)
	refresh()
end

return Music
