--!strict
-- Gruff's first-time walkthrough. The client runs the steps (src/client/Tutorial.luau); the server only
-- remembers that you finished or skipped it, and pays a small signing bonus if you really did mail an animal.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Remotes = require(script.Parent.Remotes)

-- Coins for finishing the walkthrough (not for skipping it)
local REWARD = 100

local TutorialService = {}

function TutorialService.Start()
	Remotes.Tutorial.OnServerEvent:Connect(function(player: Player, action: unknown)
		local profile = DataService.Get(player)
		if not profile or profile.TutorialDone or (action ~= "Done" and action ~= "Skip") then
			return
		end
		profile.TutorialDone = true
		-- Checked here, not trusted from the client: the bonus needs a real mailed animal
		if action == "Done" and profile.Mailed > 0 then
			profile.Coins += REWARD
			Remotes.Notify:FireClient(
				player,
				"Message",
				{ Speaker = "Postmaster Gruff", Text = `{Config.Gruff.Tutorial.Reward} (+{REWARD} coins)` }
			)
		end
		Economy.Sync(player)
	end)
end

return TutorialService
