--!strict
-- Promo Kit: for filming promo videos. Studio only (it doesn't exist in the live game).
--   F7   show / hide the Promo Kit panel
--   F8   clean screen: hides the HUD, side buttons, popups and Roblox's own top bar and chat, so only the
--        world (plus the BOX screen and boss title cards, which look good on video) shows. F8 again brings it back.
-- Panel buttons set up shots: a boss or any event right now, make the next animal Golden or Shiny, unlock
-- every animal (for tiger shots), and sunset / day / night lighting.
-- Roblox's own free camera (Shift+P) works too, for smooth flyover shots.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local PromoKit = {}

-- The everyday HUD that F8 hides (menus and the BOX screen still show when you open them)
local HIDE = { "MailATigerHud", "SideButtons", "TrollBar", "Tutorial", "FollowPrompt", "Popups", "LevelUp" }

function PromoKit.Start()
	if not RunService:IsStudio() then
		return
	end
	local shopAction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ShopAction") :: RemoteEvent
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = Ui.make("ScreenGui", {
		Name = "PromoKit",
		DisplayOrder = 20,
		ResetOnSpawn = false,
		Enabled = false,
	}, playerGui)
	local panel = Ui.make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(230, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(35, 30, 45),
	}, gui)
	Ui.round(panel, 12)
	Ui.border(panel, 3)
	Ui.make("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
	}, panel)
	Ui.make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, panel)

	local order = 0
	local function title(text: string)
		order += 1
		Ui.outlined(panel, { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 22), TextSize = 18, Text = text })
	end
	local function button(text: string, color: Color3, onClick: () -> ())
		order += 1
		local b = Ui.button(panel, {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundColor3 = color,
			Text = text,
			TextSize = 16,
		})
		b.Activated:Connect(onClick)
	end

	title("🎬 PROMO KIT  (F7)")
	button("F8: clean screen", Ui.GREY, function()
		PromoKit.ToggleClean()
	end)
	title("Shots")
	button("⚔️ Boss fight now", Ui.RED, function()
		shopAction:FireServer("StudioEvent", "Boss")
	end)
	for _, event in Config.Events.Small do
		button(`{event.Emoji} {event.DisplayName}`, Ui.PURPLE, function()
			shopAction:FireServer("StudioEvent", event.Id)
		end)
	end
	button("🌟 Next animal: Golden", Ui.GOLD, function()
		shopAction:FireServer("Promo", "Golden")
	end)
	button("✨ Next animal: Shiny", Ui.BLUE, function()
		shopAction:FireServer("Promo", "Shiny")
	end)
	button("🐯 Unlock every animal", Ui.ORANGE, function()
		shopAction:FireServer("Promo", "UnlockAll")
	end)
	title("Light")
	button("🌅 Sunset", Ui.ORANGE, function()
		shopAction:FireServer("Promo", "Sunset")
	end)
	button("☀️ Day", Ui.GREEN, function()
		shopAction:FireServer("Promo", "Day")
	end)
	button("🌙 Night", Ui.GREY, function()
		shopAction:FireServer("Promo", "Night")
	end)

	ContextActionService:BindAction("PromoKitPanel", function(_, state)
		if state == Enum.UserInputState.Begin then
			gui.Enabled = not gui.Enabled
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.F7)
	ContextActionService:BindAction("PromoKitClean", function(_, state)
		if state == Enum.UserInputState.Begin then
			PromoKit.ToggleClean()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.F8)

	print("[Promo Kit] F7 = panel, F8 = clean screen (Studio only)")
end

local clean = false
local hidden: { ScreenGui } = {}

function PromoKit.ToggleClean()
	clean = not clean
	local playerGui = player:FindFirstChild("PlayerGui")
	if clean then
		hidden = {}
		for _, name in HIDE do
			local target = playerGui and playerGui:FindFirstChild(name)
			if target and target:IsA("ScreenGui") and target.Enabled then
				target.Enabled = false
				table.insert(hidden, target)
			end
		end
		local promo = playerGui and playerGui:FindFirstChild("PromoKit")
		if promo and promo:IsA("ScreenGui") then
			promo.Enabled = false
		end
	else
		for _, target in hidden do
			target.Enabled = true
		end
		hidden = {}
	end
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, not clean)
	pcall(StarterGui.SetCore, StarterGui, "TopbarEnabled", not clean)
end

return PromoKit
