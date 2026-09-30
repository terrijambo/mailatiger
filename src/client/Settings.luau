--!strict
-- The Settings button (top-left, next to Store): music, sound effects, and camera shake/zoom on or off.
-- Also the Invite button under it (asks Roblox to show its invite-friends popup).
-- Choices are saved with your progress. Other scripts read them from attributes this sets on you:
-- MusicOff, SfxOff, MotionOff.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Profile = require(script.Parent.Profile)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local Settings = {}

local OPTIONS = {
	{ Key = "Music", Label = "Music" },
	{ Key = "Sfx", Label = "Sound effects" },
	{ Key = "Motion", Label = "Camera shake & zoom" },
}

function Settings.Start()
	local playerGui = player:WaitForChild("PlayerGui")
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Setting") :: RemoteEvent
	local gui, window = Ui.window(playerGui, "Settings", "Settings")
	local size = window:FindFirstChildOfClass("UISizeConstraint")
	if size then
		size.MaxSize = Vector2.new(420, 260) -- a small window: just three switches
	end

	-- What you just clicked, until the server's saved copy catches up
	local pending: { [string]: boolean } = {}
	local function isOn(key: string): boolean
		local waiting = pending[key]
		if waiting ~= nil then
			return waiting
		end
		return Profile.Setting(key)
	end

	local buttons: { [string]: TextButton } = {}
	for index, option in OPTIONS do
		Ui.label(window, {
			Position = UDim2.fromOffset(24, 14 + index * 56),
			Size = UDim2.new(1, -170, 0, 40),
			TextSize = 20,
			Text = option.Label,
		})
		local button = Ui.button(window, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -24, 0, 14 + index * 56),
			Size = UDim2.fromOffset(110, 40),
			TextSize = 18,
			Text = "",
		})
		button.Activated:Connect(function()
			local on = not isOn(option.Key)
			pending[option.Key] = on
			remote:FireServer(option.Key, on)
			Settings.Apply()
		end)
		buttons[option.Key] = button
	end

	function Settings.Apply()
		for _, option in OPTIONS do
			local on = isOn(option.Key)
			player:SetAttribute(`{option.Key}Off`, not on)
			local button = buttons[option.Key]
			button.Text = if on then "ON" else "OFF"
			button.BackgroundColor3 = if on then Ui.GREEN else Ui.GREY
		end
	end
	Profile.Watch(function()
		-- The saved copy has caught up with anything we clicked
		for key, value in pending do
			if Profile.Setting(key) == value then
				pending[key] = nil
			end
		end
		Settings.Apply()
	end)

	local hud = Ui.make("ScreenGui", { Name = "SettingsButton", ResetOnSpawn = false }, playerGui)
	local open = Ui.button(hud, {
		Position = UDim2.fromOffset(116, 8),
		Size = UDim2.fromOffset(96, 36),
		BackgroundColor3 = Ui.GREY,
		TextSize = 17,
		Text = "Settings",
	})
	open.Activated:Connect(function()
		gui.Enabled = not gui.Enabled
	end)

	-- Invite friends (Roblox's own invite popup). Hidden where Roblox doesn't allow invites.
	local invite = Ui.button(hud, {
		Position = UDim2.fromOffset(220, 8),
		Size = UDim2.fromOffset(96, 36),
		BackgroundColor3 = Ui.BLUE,
		TextSize = 17,
		Text = "Invite",
		Visible = false,
	})
	task.spawn(function()
		local ok, allowed = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
		invite.Visible = ok and allowed == true
	end)
	invite.Activated:Connect(function()
		pcall(SocialService.PromptGameInvite, SocialService, player)
	end)
end

function Settings.Apply() end -- replaced in Start

return Settings
