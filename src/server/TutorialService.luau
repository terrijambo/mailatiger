--!strict
-- Gruff's first-time walkthrough. The client runs the steps (src/client/Tutorial.luau); the server only
-- remembers that you finished or skipped it, and pays a small signing bonus if you really did mail an animal.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Remotes = require(script.Parent.Remotes)

-- Coins for finishing the walkthrough (not for skipping it)
local REWARD = 100

local TutorialService = {}

-- Settings live here too (it's the other tiny "remember this about me" remote)
local SETTINGS = { Music = true, Sfx = true, Motion = true }

function TutorialService.Start()
	Remotes.Listen(Remotes.Setting, 5, function(player: Player, name: unknown, on: unknown)
		local profile = DataService.Get(player)
		if profile and typeof(name) == "string" and SETTINGS[name] and typeof(on) == "boolean" then
			profile.Settings[name] = on
			DataService.Sync(player)
		end
	end)

	Remotes.Listen(Remotes.Tutorial, 2, function(player: Player, action: unknown)
		local profile = DataService.Get(player)
		if not profile or profile.TutorialDone or (action ~= "Done" and action ~= "Skip") then
			return
		end
		profile.TutorialDone = true
		if action == "Done" then
			Analytics.Onboarding(player, "TutorialDone")
		else
			Analytics.Custom(player, "TutorialSkipped")
		end
		-- Checked here, not trusted from the client: the bonus needs a real mailed animal
		if action == "Done" and profile.Mailed > 0 then
			profile.Coins += REWARD
			Analytics.Earn(player, REWARD, profile.Coins, "TutorialBonus")
			Remotes.Notify:FireClient(
				player,
				"Message",
				{
					Speaker = "Postmaster Gruff",
					Text = `{Config.Gruff.Tutorial.Reward} (+{Format.Short(REWARD)} coins)`,
				}
			)
		end
		Economy.Sync(player)
	end)
end

return TutorialService
