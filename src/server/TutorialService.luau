--!strict
-- Gruff's first-time walkthrough. The client runs the steps (src/client/Tutorial.luau); the server only
-- remembers that you finished or skipped it, and pays a small signing bonus if you really did mail an animal.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local ProgressionService = require(script.Parent.ProgressionService)
local Remotes = require(script.Parent.Remotes)
local Travel = require(script.Parent.Travel)
local WildService = require(script.Parent.WildService)

-- Coins for finishing the walkthrough (not for skipping it)
local REWARD = 100

local TutorialService = {}

-- Settings live here too (it's the other tiny "remember this about me" remote)
local SETTINGS = { Music = true, Sfx = true, Motion = true, Chaos = true }

-- A new hire starts right on the Backyard, face to face with a calm, easy animal (no PEN button, no hunting)
local function startNewHire(player: Player)
	local profile = DataService.Get(player)
	if not profile or profile.TutorialDone or profile.Mailed > 0 then
		return
	end
	local character = player.Character or player.CharacterAdded:Wait()
	character:WaitForChild("HumanoidRootPart", 10)
	task.wait(0.5) -- (let the character settle before moving it)
	if not player.Parent then
		return
	end
	Travel.ToArena(player, "Backyard")
	Analytics.Teleported(player)
	task.wait(0.2)
	WildService.SpawnTutorial(player)
end

function TutorialService.Start()
	DataService.Loaded:Connect(function(player: Player)
		task.spawn(startNewHire, player)
	end)
	Remotes.Listen(Remotes.Setting, 5, function(player: Player, name: unknown, on: unknown)
		local profile = DataService.Get(player)
		if profile and typeof(name) == "string" and SETTINGS[name] and typeof(on) == "boolean" then
			if (profile.Settings[name] ~= false) ~= on then
				Analytics.Custom(
					player,
					"SettingChanged",
					1,
					name,
					if on then "On" else "Off",
					Analytics.Segment(player)
				)
			end
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
			Analytics.Milestone(player, "TutorialDone")
			ProgressionService.AddXP(player, Config.Levels.TutorialXP, "Tutorial")
		else
			-- Value: minutes played. Fields: the walkthrough step they skipped at, and their device
			Analytics.Custom(
				player,
				"TutorialSkipped",
				Analytics.PlayMinutes(player),
				Analytics.TutorialStepOf(player),
				Analytics.DeviceOf(player)
			)
		end
		-- Checked here, not trusted from the client: the bonus needs a real mailed animal
		if action == "Done" and profile.Mailed > 0 then
			profile.Coins += REWARD
			Analytics.Earn(player, REWARD, profile.Coins, "TutorialBonus")
			Remotes.Notify:FireClient(player, "Message", {
				Speaker = "Postmaster Gruff",
				Text = `{Config.Gruff.Tutorial.Reward} (+{Format.Short(REWARD)} coins)`,
			})
		end
		Economy.Sync(player)
	end)
end

return TutorialService
