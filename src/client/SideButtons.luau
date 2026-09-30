--!strict
-- The big square buttons down the sides of the screen, like PETS / EGGS / SHOP in popular simulators:
--   left:  PEN (pick an animal), SHOP (boxes, tools, stamps, chutes, trolls), ORDERS (Gruff's orders and
--          quests), BAG (your inventory: troll items, mail boxes, stamps, tools, animal collection)
--   right: STORE (Robux), UPGRADES (diamond upgrades), SETTINGS, INVITE (friends)
-- They hide while the BOX screen is up so they don't get in the way.

local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")

local Menus = require(script.Parent.Menus)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local SideButtons = {}

local function column(gui: ScreenGui, side: number): Frame
	local frame = Ui.make("Frame", {
		AnchorPoint = Vector2.new(if side < 0 then 0 else 1, 0.5),
		Position = if side < 0 then UDim2.new(0, 14, 0.47, 0) else UDim2.new(1, -14, 0.47, 0),
		Size = UDim2.fromOffset(84, 380),
		BackgroundTransparency = 1,
	}, gui)
	Ui.autoScale(frame) -- smaller on phones
	Ui.make("UIListLayout", {
		Padding = UDim.new(0, 16),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}, frame)
	return frame
end

function SideButtons.Start()
	local gui = Ui.make("ScreenGui", {
		Name = "SideButtons",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))
	local left = column(gui, -1)
	local right = column(gui, 1)

	local function add(parent: Frame, spec: Ui.SideButtonSpec, onClick: () -> ()): TextButton
		local button = Ui.sideButton(parent, spec)
		button.Activated:Connect(onClick)
		return button
	end

	add(left, { Label = "PEN", Icon = "Button_Pen", Color = Ui.GREEN, LayoutOrder = 1 }, function()
		Menus.Toggle("Pen")
	end)
	add(left, { Label = "SHOP", Icon = "Button_Shop", Color = Ui.ORANGE, LayoutOrder = 2 }, function()
		Menus.Toggle("Shop")
	end)
	add(left, { Label = "ORDERS", Icon = "Button_Orders", Color = Ui.PURPLE, LayoutOrder = 3 }, function()
		Menus.Toggle("Orders")
	end)
	add(left, { Label = "BAG", Icon = "Button_Inventory", Color = Ui.PINK, LayoutOrder = 4 }, function()
		Menus.Toggle("Inventory")
	end)

	add(right, { Label = "STORE", Icon = "Button_Store", Color = Ui.GOLD, LayoutOrder = 1 }, function()
		Menus.Toggle("Store")
	end)
	add(right, { Label = "UPGRADES", Icon = "Button_Upgrades", Color = Ui.BLUE, LayoutOrder = 2 }, function()
		Menus.Toggle("Upgrades")
	end)
	add(right, { Label = "SETTINGS", Icon = "Button_Settings", Color = Ui.GREY, LayoutOrder = 3 }, function()
		Menus.Toggle("Settings")
	end)
	local invite = add(
		right,
		{ Label = "INVITE", Icon = "Button_Invite", Color = Ui.GREEN, LayoutOrder = 4 },
		function()
			pcall(SocialService.PromptGameInvite, SocialService, player)
		end
	)
	invite.Visible = false
	task.spawn(function()
		-- Only where Roblox allows invites
		local ok, allowed = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
		invite.Visible = ok and allowed == true
	end)

	-- Step aside during the BOX screen
	local function refresh()
		gui.Enabled = player:GetAttribute("Stage") ~= "Box"
	end
	player:GetAttributeChangedSignal("Stage"):Connect(refresh)
	refresh()
end

return SideButtons
