--!strict
-- The Settings window (MENU > SETTINGS): music, sound effects, camera shake/zoom and Chaos Mode on or off,
-- the reward-code box, and INVITE FRIENDS.
-- Choices are saved with your progress. Other scripts read them from attributes this sets on you:
-- MusicOff, SfxOff, MotionOff.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Config = require(ReplicatedStorage.Shared.Config)
local Menus = require(script.Parent.Menus)
local Profile = require(script.Parent.Profile)
local Track = require(script.Parent.Track)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local Settings = {}

local DEFAULTS: { [string]: boolean } = { Chaos = true }

local OPTIONS = {
	{ Key = "Music", Label = "Music" },
	{ Key = "Sfx", Label = "Sound effects" },
	{ Key = "Motion", Label = "Camera shake & zoom" },
	-- (on unless you turn it off: other players can troll your animal, but every job pays +50%)
	{ Key = "Chaos", Label = "Chaos Mode (+50% pay)" },
}

function Settings.Start()
	local playerGui = player:WaitForChild("PlayerGui")
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Setting") :: RemoteEvent
	-- A small window: the switches, the code box and the invite button
	local gui, window = Ui.window(playerGui, "Settings", "Settings", Ui.GREY, Vector2.new(440, 440))

	-- What you just clicked, until the server's saved copy catches up
	local pending: { [string]: boolean } = {}
	local function isOn(key: string): boolean
		local waiting = pending[key]
		if waiting ~= nil then
			return waiting
		end
		return Profile.Setting(key, DEFAULTS[key])
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

	-- Reward codes (the server checks them; see src/shared/Config/Codes.luau)
	local redeem = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RedeemCode") :: RemoteEvent
	local codeY = 14 + (#OPTIONS + 1) * 56
	local codeBox = Ui.make("TextBox", {
		Position = UDim2.fromOffset(24, codeY),
		Size = UDim2.new(1, -170, 0, 40),
		BackgroundColor3 = Ui.WHITE,
		Font = Ui.FONT,
		TextSize = 18,
		TextColor3 = Ui.INK,
		PlaceholderText = "Type a code",
		Text = "",
		ClearTextOnFocus = false,
	}, window)
	Ui.round(codeBox, 8)
	Ui.field(codeBox)
	local redeemButton = Ui.button(window, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, codeY),
		Size = UDim2.fromOffset(110, 40),
		BackgroundColor3 = Ui.ORANGE,
		TextSize = 18,
		Text = "Redeem",
	})
	local function submit()
		if codeBox.Text ~= "" then
			redeem:FireServer(codeBox.Text)
			codeBox.Text = ""
		end
	end
	redeemButton.Activated:Connect(submit)
	codeBox.FocusLost:Connect(function(enterPressed: boolean)
		if enterPressed then
			submit()
		end
	end)

	-- Invite friends: your UserId rides along with the invite, so you get paid when they join and play
	-- (InviteService on the server). Only shown where Roblox allows invites.
	local invite = Ui.button(window, {
		Position = UDim2.fromOffset(24, codeY + 56),
		Size = UDim2.new(1, -48, 0, 44),
		BackgroundColor3 = Ui.GREEN,
		TextSize = 20,
		Text = "👋 INVITE FRIENDS (you both get coins!)",
		Visible = false,
	})
	invite.Activated:Connect(function()
		local options = Instance.new("ExperienceInviteOptions")
		options.PromptMessage =
			`Invite friends: they get {Config.Social.Invites.NewPlayerGift} coins, and you get a big coin bonus for each one!`
		options.LaunchData = tostring(player.UserId)
		Track.Send("InviteOpened")
		pcall(SocialService.PromptGameInvite, SocialService, player, options)
	end)
	-- Analytics: how many friends they actually invited
	pcall(function()
		SocialService.GameInvitePromptClosed:Connect(function(_sender: Player, recipients: { number })
			Track.Send("InviteSent", #recipients)
		end)
	end)
	task.spawn(function()
		local ok, allowed = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
		invite.Visible = ok and allowed == true
	end)

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
			if Profile.Setting(key, DEFAULTS[key]) == value then
				pending[key] = nil
			end
		end
		Settings.Apply()
	end)

	-- Opened from MENU > SETTINGS (SideButtons.luau)
	Menus.Register("Settings", gui)
end

function Settings.Apply() end -- replaced in Start

return Settings
