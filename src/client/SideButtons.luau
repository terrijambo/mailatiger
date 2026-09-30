--!strict
-- The big square buttons down the sides of the screen, like PETS / EGGS / SHOP in popular simulators:
--   left:  PEN (pick an animal), SHOP (boxes, tools, stamps, chutes, trolls), ORDERS (Gruff's orders and
--          quests), BAG (your inventory: troll items, mail boxes, stamps, tools, animal collection)
--   right: STORE (Robux), UPGRADES (diamond upgrades), SETTINGS, INVITE (friends)
-- They hide while the BOX screen is up so they don't get in the way.
-- Gamepad: d-pad left/up/right/down opens PEN/SHOP/ORDERS/BAG; inside a window you can move to any button.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")

local Menus = require(script.Parent.Menus)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local SideButtons = {}

-- Big screens: one column down the middle of each side. Phones (Ui.compact): a 2x2 grid near the top, so the
-- thumbstick (bottom-left) and the jump button (bottom-right) stay clear. The left grid sits under the
-- stats (coins, level...), which move to the top-left on phones (Hud.luau).
local CELL = 78
local GAP_X, GAP_Y = 12, 16
local STATS_HEIGHT = 240 -- the stats stack's height (Hud.luau), for placing the left grid under it

local function column(gui: ScreenGui, side: number): (Frame, () -> ())
	local frame = Ui.make("Frame", {
		BackgroundTransparency = 1,
	}, gui)
	Ui.autoScale(frame) -- smaller on phones
	local grid = Ui.make("UIGridLayout", {
		CellSize = UDim2.fromOffset(CELL, CELL),
		CellPadding = UDim2.fromOffset(GAP_X, GAP_Y),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = if side < 0 then Enum.HorizontalAlignment.Left else Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	}, frame)
	local function layout()
		local compact = Ui.compact()
		local margin = Ui.margin()
		local count = 0
		for _, child in frame:GetChildren() do
			if child:IsA("GuiButton") and child.Visible then
				count += 1
			end
		end
		local columns = if compact then 2 else 1
		local rows = math.max(1, math.ceil(count / columns))
		grid.FillDirectionMaxCells = columns
		frame.Size = UDim2.fromOffset(columns * CELL + (columns - 1) * GAP_X, rows * (CELL + GAP_Y))
		if compact then
			-- Left: under the stats. Right: under the server boost timer.
			local top = if side < 0 then 8 + STATS_HEIGHT * Ui.screenScale() + 6 else 8 + 52 * Ui.screenScale() + 8
			frame.AnchorPoint = Vector2.new(if side < 0 then 0 else 1, 0)
			frame.Position = if side < 0 then UDim2.fromOffset(margin, top) else UDim2.new(1, -margin, 0, top)
		else
			frame.AnchorPoint = Vector2.new(if side < 0 then 0 else 1, 0.5)
			frame.Position = if side < 0 then UDim2.new(0, margin, 0.47, 0) else UDim2.new(1, -margin, 0.47, 0)
		end
	end
	return frame, layout
end

function SideButtons.Start()
	local gui = Ui.make("ScreenGui", {
		Name = "SideButtons",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))
	local left, layoutLeft = column(gui, -1)
	local right, layoutRight = column(gui, 1)

	-- keyCode: the d-pad shortcut on a gamepad (its button picture shows on the corner while using one)
	local function add(parent: Frame, spec: Ui.SideButtonSpec, keyCode: Enum.KeyCode?, onClick: () -> ()): TextButton
		local button = Ui.sideButton(parent, spec)
		button.Activated:Connect(onClick)
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
					onClick()
				end
				return Enum.ContextActionResult.Sink
			end, false, keyCode)
		end
		return button
	end

	add(
		left,
		{ Label = "PEN", Icon = "Button_Pen", Color = Ui.GREEN, LayoutOrder = 1 },
		Enum.KeyCode.DPadLeft,
		function()
			Menus.Toggle("Pen")
		end
	)
	add(
		left,
		{ Label = "SHOP", Icon = "Button_Shop", Color = Ui.ORANGE, LayoutOrder = 2 },
		Enum.KeyCode.DPadUp,
		function()
			Menus.Toggle("Shop")
		end
	)
	add(
		left,
		{ Label = "ORDERS", Icon = "Button_Orders", Color = Ui.PURPLE, LayoutOrder = 3 },
		Enum.KeyCode.DPadRight,
		function()
			Menus.Toggle("Orders")
		end
	)
	add(
		left,
		{ Label = "BAG", Icon = "Button_Inventory", Color = Ui.PINK, LayoutOrder = 4 },
		Enum.KeyCode.DPadDown,
		function()
			Menus.Toggle("Inventory")
		end
	)

	-- (On a gamepad these are reached from inside any window: open one with the d-pad, then move to them)
	add(right, { Label = "STORE", Icon = "Button_Store", Color = Ui.GOLD, LayoutOrder = 1 }, nil, function()
		Menus.Toggle("Store")
	end)
	add(right, { Label = "UPGRADES", Icon = "Button_Upgrades", Color = Ui.BLUE, LayoutOrder = 2 }, nil, function()
		Menus.Toggle("Upgrades")
	end)
	add(right, { Label = "SETTINGS", Icon = "Button_Settings", Color = Ui.GREY, LayoutOrder = 3 }, nil, function()
		Menus.Toggle("Settings")
	end)
	local invite = add(
		right,
		{ Label = "INVITE", Icon = "Button_Invite", Color = Ui.GREEN, LayoutOrder = 4 },
		nil,
		function()
			pcall(SocialService.PromptGameInvite, SocialService, player)
		end
	)
	invite.Visible = false
	task.spawn(function()
		-- Only where Roblox allows invites
		local ok, allowed = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
		invite.Visible = ok and allowed == true
		layoutRight()
	end)
	Ui.onResize(function()
		layoutLeft()
		layoutRight()
	end)

	-- Step aside during the BOX screen
	local function refresh()
		gui.Enabled = player:GetAttribute("Stage") ~= "Box"
	end
	player:GetAttributeChangedSignal("Stage"):Connect(refresh)
	refresh()
end

return SideButtons
