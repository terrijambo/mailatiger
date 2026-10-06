--!strict
-- "Having fun?" card: a one-tap ⭐ FAVORITE (adds the game to their Roblox favorites) and 🔔 GET UPDATES
-- (Roblox's notification opt-in, so they hear about updates). Favorites and returning players are what
-- Roblox's recommendations reward most. No reward for pressing them: Roblox doesn't allow paying for favorites.
-- Shows after Follow.AfterMinutes of play or a boss win (whichever comes first), at a calm moment, at most
-- Follow.MaxAsks times ever (Config/Social.luau).

local AvatarEditorService = game:GetService("AvatarEditorService")
local ExperienceNotificationService = game:GetService("ExperienceNotificationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Menus = require(script.Parent.Menus)
local Profile = require(script.Parent.Profile)
local Ui = require(script.Parent.Ui)

local Follow = Config.Social.Follow
local player = Players.LocalPlayer

local FollowPrompt = {}

local shown = false

-- Not in the middle of something (boxing, a boss fight, a menu, the tutorial)
local function calm(): boolean
	local playerGui = player:FindFirstChild("PlayerGui")
	local boxing = playerGui and playerGui:FindFirstChild("BoxingScreen") :: ScreenGui?
	return not (boxing and boxing.Enabled)
		and not Menus.AnyOpen()
		and Workspace:GetAttribute("BossPhase") == nil
		and Profile.Get().TutorialDone == true
end

local function show(shopAction: RemoteEvent)
	if shown or (Profile.Get().FollowAsked or 0) >= Follow.MaxAsks then
		return
	end
	-- Wait (up to a few minutes) for a calm moment
	local waited = 0
	while not calm() and waited < 240 do
		task.wait(2)
		waited += 2
	end
	if shown or not calm() then
		return
	end
	shown = true
	shopAction:FireServer("FollowAsked")

	local canNotify = false
	local ok, result = pcall(ExperienceNotificationService.CanPromptOptInAsync, ExperienceNotificationService)
	canNotify = ok and result == true

	local gui = Ui.make("ScreenGui", {
		Name = "FollowPrompt",
		DisplayOrder = 8,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))
	local card = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 200),
		Size = UDim2.fromOffset(if canNotify then 420 else 300, 132),
		BackgroundColor3 = Ui.PAPER,
	}, gui)
	Ui.round(card, 16)
	Ui.border(card, 3)
	Ui.autoScale(card)
	Ui.outlined(card, {
		Position = UDim2.fromOffset(0, 10),
		Size = UDim2.new(1, 0, 0, 34),
		TextSize = 28,
		Text = "Having fun? 🐯",
	})
	local close = Ui.button(card, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 10, 0, -10),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = Ui.RED,
		Text = "X",
		TextSize = 20,
	})
	local row = Ui.make("Frame", {
		Position = UDim2.fromOffset(16, 58),
		Size = UDim2.new(1, -32, 0, 56),
		BackgroundTransparency = 1,
	}, card)
	Ui.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 14),
	}, row)

	local buttons = 0
	local function dismiss()
		local slide = TweenService:Create(card, TweenInfo.new(0.25), { Position = UDim2.new(0.5, 0, 1, 200) })
		slide:Play()
		slide.Completed:Wait()
		gui:Destroy()
	end
	local function used(button: TextButton)
		button:Destroy()
		buttons -= 1
		if buttons <= 0 then
			task.spawn(dismiss)
		end
	end

	local favorite = Ui.button(row, {
		Size = UDim2.fromOffset(180, 56),
		BackgroundColor3 = Ui.GOLD,
		Text = "⭐ FAVORITE",
		TextSize = 22,
		LayoutOrder = 1,
	})
	buttons += 1
	favorite.Activated:Connect(function()
		pcall(AvatarEditorService.PromptSetFavorite, AvatarEditorService, game.PlaceId, Enum.AvatarItemType.Asset, true)
		used(favorite)
	end)
	if canNotify then
		local updates = Ui.button(row, {
			Size = UDim2.fromOffset(180, 56),
			BackgroundColor3 = Ui.BLUE,
			Text = "🔔 GET UPDATES",
			TextSize = 22,
			LayoutOrder = 2,
		})
		buttons += 1
		updates.Activated:Connect(function()
			pcall(ExperienceNotificationService.PromptOptIn, ExperienceNotificationService)
			used(updates)
		end)
	end
	close.Activated:Connect(function()
		dismiss()
	end)

	local margin = Ui.margin()
	TweenService:Create(card, TweenInfo.new(0.4, Enum.EasingStyle.Back), {
		Position = UDim2.new(0.5, 0, 1, -margin - 90),
	}):Play()
	-- It doesn't hang around forever
	task.delay(25, function()
		if gui.Parent then
			dismiss()
		end
	end)
end

function FollowPrompt.Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local shopAction = remotes:WaitForChild("ShopAction") :: RemoteEvent
	local notify = remotes:WaitForChild("Notify") :: RemoteEvent

	task.delay(Follow.AfterMinutes * 60, show, shopAction)
	notify.OnClientEvent:Connect(function(kind: string)
		if kind == "BossWin" then
			task.delay(15, show, shopAction) -- (after the victory screen)
		end
	end)
end

return FollowPrompt
