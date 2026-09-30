--!strict
-- The Settings window (SETTINGS side button): music, sound effects, and camera shake/zoom on or off, plus
-- the reward-code box.
-- Choices are saved with your progress. Other scripts read them from attributes this sets on you:
-- MusicOff, SfxOff, MotionOff.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Menus = require(script.Parent.Menus)
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
	local gui, window = Ui.window(playerGui, "Settings", "Settings", Ui.GREY)
	local size = window:FindFirstChildOfClass("UISizeConstraint")
	if size then
		size.MaxSize = Vector2.new(420, 330) -- a small window: three switches and the code box
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

	-- Opened by the SETTINGS side button (SideButtons.luau)
	Menus.Register("Settings", gui)
end

function Settings.Apply() end -- replaced in Start

return Settings
