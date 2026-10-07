--!strict
-- The big square buttons on the left side of the screen, like PETS / EGGS / SHOP in popular simulators.
-- Always there: PEN (pick an animal), SHOP (boxes, tools, stamps, chutes, trolls), STORE (Robux) and MENU.
-- PEN is a quick teleport between Gruff and your best zone.
-- MENU pops out the rest next to it: ORDERS, BAG, UPGRADES, TRAVEL (teleport to Gruff, a zone or the boss),
-- SETTINGS and INVITE. Picking one (or pressing MENU again, or opening any window) folds it away.
-- Big screens: one column down the middle of the left edge. Phones (Ui.compact): a 2x2 grid under the stats
-- in the top-left, so the thumbstick (bottom-left) stays clear.
-- Gamepad: d-pad left/up/right/down opens PEN/SHOP/ORDERS/BAG; inside a window you can move to any button.
-- They hide while the BOX screen is up so they don't get in the way.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Menus = require(script.Parent.Menus)
local Profile = require(script.Parent.Profile)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local SideButtons = {}

local CELL = 78
local GAP_X, GAP_Y = 12, 16
local STATS_HEIGHT = 140 -- the left stats' height (Hud.luau), for placing the phone grid under them

function SideButtons.Start()
	local shopAction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ShopAction") :: RemoteEvent
	local gui = Ui.make("ScreenGui", {
		Name = "SideButtons",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))

	-- The always-there buttons
	local column = Ui.make("Frame", { BackgroundTransparency = 1 }, gui)
	Ui.autoScale(column)
	local grid = Ui.make("UIGridLayout", {
		CellSize = UDim2.fromOffset(CELL, CELL),
		CellPadding = UDim2.fromOffset(GAP_X, GAP_Y),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	}, column)

	-- The pop-out menu (opens to the right of the column)
	local popup = Ui.make("Frame", {
		BackgroundColor3 = Color3.fromRGB(35, 30, 55),
		BackgroundTransparency = 0.1,
		Visible = false,
	}, gui)
	Ui.round(popup, 16)
	Ui.border(popup, 3)
	local popupScale = Ui.make("UIScale", { Scale = 1 }, popup)
	Ui.make("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}, popup)
	Ui.make("UIGridLayout", {
		CellSize = UDim2.fromOffset(CELL, CELL),
		CellPadding = UDim2.fromOffset(GAP_X, GAP_Y),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirectionMaxCells = 3,
	}, popup)

	local function setMenu(open: boolean)
		if open == popup.Visible then
			return
		end
		popup.Visible = open
		if open then
			local full = Ui.screenScale()
			popupScale.Scale = full * 0.85
			TweenService:Create(popupScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = full,
			}):Play()
		end
	end

	-- keyCode: the d-pad shortcut on a gamepad (its button picture shows on the corner while using one)
	local function add(parent: Instance, spec: Ui.SideButtonSpec, keyCode: Enum.KeyCode?, onClick: () -> ()): TextButton
		local button = Ui.sideButton(parent, spec)
		button.Activated:Connect(function()
			if parent == popup then
				setMenu(false)
			end
			onClick()
		end)
		if keyCode then
			Ui.gamepadGlyph(button, keyCode, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(4, 4),
				Size = UDim2.fromOffset(30, 30),
			})
			ContextActionService:BindAction(`Menu_{spec.Label}`, function(_name: string, state: Enum.UserInputState)
				if Menus.AnyOpen() or not gui.Enabled then
					return Enum.ContextActionResult.Pass -- the d-pad moves around inside the open window
				end
				if state == Enum.UserInputState.Begin then
					setMenu(false)
					onClick()
				end
				return Enum.ContextActionResult.Sink
			end, false, keyCode)
		end
		return button
	end

	add(
		column,
		{ Label = "PEN", Icon = "Button_Pen", Color = Ui.GREEN, LayoutOrder = 1 },
		Enum.KeyCode.DPadLeft,
		function()
			-- Quick teleport: at Gruff's -> your best zone; anywhere else -> back to Gruff
			Menus.CloseAll()
			shopAction:FireServer("QuickTravel")
		end
	)
	local shopButton = add(
		column,
		{ Label = "SHOP", Icon = "Button_Shop", Color = Ui.ORANGE, LayoutOrder = 2 },
		Enum.KeyCode.DPadUp,
		function()
			Menus.Toggle("Shop")
		end
	)
	local storeButton = add(
		column,
		{ Label = "STORE", Icon = "Button_Store", Color = Ui.GOLD, LayoutOrder = 3 },
		nil,
		function()
			Menus.Toggle("Store")
		end
	)
	local menuButton = add(
		column,
		{ Label = "MENU", Icon = "Button_Menu", Color = Ui.PURPLE, LayoutOrder = 4 },
		nil,
		function()
			setMenu(not popup.Visible)
		end
	)

	local ordersButton = add(
		popup,
		{ Label = "ORDERS", Icon = "Button_Orders", Color = Ui.PURPLE, LayoutOrder = 1 },
		Enum.KeyCode.DPadRight,
		function()
			Menus.Toggle("Orders")
		end
	)
	add(
		popup,
		{ Label = "BAG", Icon = "Button_Inventory", Color = Ui.PINK, LayoutOrder = 2 },
		Enum.KeyCode.DPadDown,
		function()
			Menus.Toggle("Inventory")
		end
	)
	add(popup, { Label = "UPGRADES", Icon = "Button_Upgrades", Color = Ui.BLUE, LayoutOrder = 3 }, nil, function()
		Menus.Toggle("Upgrades")
	end)
	add(popup, { Label = "TRAVEL", Icon = "Button_Travel", Color = Ui.RED, LayoutOrder = 4 }, nil, function()
		Menus.Toggle("Travel")
	end)
	add(popup, { Label = "SETTINGS", Icon = "Button_Settings", Color = Ui.GREY, LayoutOrder = 5 }, nil, function()
		Menus.Toggle("Settings")
	end)
	local invite = add(
		popup,
		{ Label = "INVITE", Icon = "Button_Invite", Color = Ui.GREEN, LayoutOrder = 6 },
		nil,
		function()
			-- Your UserId rides along with the invite, so you get paid diamonds when they join and play
			-- (InviteService on the server)
			local options = Instance.new("ExperienceInviteOptions")
			options.PromptMessage =
				`Invite friends: they get {Config.Social.Invites.NewPlayerGift} diamonds, you get {Config.Social.Invites.InviterReward} each!`
			options.LaunchData = tostring(player.UserId)
			pcall(SocialService.PromptGameInvite, SocialService, player, options)
		end
	)
	invite.Visible = false

	local function layout()
		local compact = Ui.compact()
		local margin = Ui.margin()
		local scale = Ui.screenScale()
		local columns = if compact then 2 else 1
		local rows = math.ceil(4 / columns)
		grid.FillDirectionMaxCells = columns
		column.Size = UDim2.fromOffset(columns * CELL + (columns - 1) * GAP_X, rows * (CELL + GAP_Y))
		if compact then
			column.AnchorPoint = Vector2.new(0, 0)
			column.Position = UDim2.fromOffset(margin, 8 + STATS_HEIGHT * scale + 6)
		else
			column.AnchorPoint = Vector2.new(0, 0.5)
			column.Position = UDim2.new(0, margin, 0.47, 0)
		end
		-- The pop-out sits just right of the column, lined up with the MENU button
		local items = 0
		for _, child in popup:GetChildren() do
			if child:IsA("GuiButton") and child.Visible then
				items += 1
			end
		end
		local popRows = math.ceil(items / 3)
		popup.Size = UDim2.fromOffset(3 * CELL + 2 * GAP_X + 24, popRows * (CELL + GAP_Y) - GAP_Y + 24 + 6)
		popup.AnchorPoint = Vector2.new(0, 1)
		local menuBottom = menuButton.AbsolutePosition.Y + menuButton.AbsoluteSize.Y
		local right = column.AbsolutePosition.X + column.AbsoluteSize.X + 12
		popup.Position = UDim2.fromOffset(right, math.max(menuBottom, popup.Size.Y.Offset * scale + 8))
	end
	task.spawn(function()
		-- Only where Roblox allows invites
		local ok, allowed = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
		invite.Visible = ok and allowed == true
		layout()
	end)
	Ui.onResize(function()
		task.defer(layout) -- (after the column's own size and scale update)
	end)
	popup:GetPropertyChangedSignal("Visible"):Connect(layout)

	-- Red "!" on MENU and ORDERS while a finished order or challenge is waiting for CLAIM
	local menuDot = Ui.alertDot(menuButton)
	local ordersDot = Ui.alertDot(ordersButton)
	Profile.Watch(function()
		local data = Profile.Get()
		local learning = Profile.Learning()
		local waiting = Profile.Claimable(data) > 0 and not learning
		menuDot.Visible = waiting
		ordersDot.Visible = waiting
		-- Simple start: PEN first, SHOP once you've mailed something (Gruff sends you there), STORE and MENU
		-- once the walkthrough is done
		local shopWas, menuWas = shopButton.Visible, menuButton.Visible
		shopButton.Visible = not learning or (data.Mailed or 0) > 0
		storeButton.Visible = not learning
		menuButton.Visible = not learning
		local function popIn(button: TextButton, was: boolean)
			if button.Visible and not was then
				-- A little pop so the new button gets noticed
				local pop = button:FindFirstChildOfClass("UIScale") or Ui.make("UIScale", {}, button)
				pop.Scale = 0.3
				TweenService:Create(pop, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Scale = 1,
				}):Play()
			end
		end
		popIn(shopButton, shopWas)
		popIn(menuButton, menuWas)
		if menuButton.Visible ~= menuWas or shopButton.Visible ~= shopWas then
			layout()
		end
	end)

	-- Opening any window folds the menu away
	Menus.OnOpen = function()
		setMenu(false)
	end

	-- Step aside during the BOX screen
	local function refresh()
		gui.Enabled = player:GetAttribute("Stage") ~= "Box"
		if not gui.Enabled then
			setMenu(false)
		end
	end
	player:GetAttributeChangedSignal("Stage"):Connect(refresh)
	refresh()
end

return SideButtons
