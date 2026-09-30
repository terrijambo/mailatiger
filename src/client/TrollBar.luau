--!strict
-- The troll hotbar (bottom center): one slot per troll item you own, with its key (1-5) and a cooldown
-- shade that drains as it recharges. Press the key or tap the slot to use it. The server checks everything
-- (TrollService.luau), and troll items only affect players in Chaos Mode.
-- Gamepad: R1 picks the next item (gold outline), R2 uses it. Touch: tap a slot.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Profile = require(script.Parent.Profile)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer
local Trolls = Config.Trolls

local TrollBar = {}

function TrollBar.Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local trollRemote = remotes:WaitForChild("Troll") :: RemoteEvent
	local notify = remotes:WaitForChild("Notify") :: RemoteEvent

	local gui = Ui.make("ScreenGui", {
		Name = "TrollBar",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))
	local bar = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -Ui.margin()),
		Size = UDim2.fromOffset(400, 76),
		BackgroundTransparency = 1,
	}, gui)
	Ui.autoScale(bar)
	Ui.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, bar)

	local slots: { [string]: { Button: TextButton, Shade: Frame } } = {}
	local bound: { string } = {}
	local ownedOrder: { string } = {} -- owned item ids, in hotbar order
	local selected = 1 -- (gamepad) which slot R2 uses
	local keyLabels: { TextLabel } = {}

	-- The gamepad's pick: a gold outline and the R2 button picture on that slot
	local pickStroke = Ui.make("UIStroke", { Color = Ui.GOLD, Thickness = 4, Enabled = false })
	local pickGlyph = Ui.gamepadGlyph(gui, Enum.KeyCode.ButtonR2, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(30, 30),
	})
	local function refreshPick()
		local id = ownedOrder[selected]
		local slot = id and slots[id]
		local gamepad = Ui.inputKind() == "Gamepad"
		pickStroke.Enabled = gamepad and slot ~= nil
		pickStroke.Parent = if slot then slot.Button else nil
		pickGlyph.Parent = if slot then slot.Button else gui
		pickGlyph.Position = UDim2.new(1, -4, 0, 4)
		pickGlyph.Visible = gamepad and slot ~= nil
		for _, label in keyLabels do
			label.Visible = Ui.inputKind() == "Keyboard" -- number keys only mean something on a keyboard
		end
	end
	Ui.onInputKind(refreshPick)

	local function useTroll(trollId: string)
		trollRemote:FireServer(trollId)
	end

	local function rebuild()
		-- (keep the gamepad pick markers: they're moved onto the new slots below)
		pickStroke.Parent = nil
		pickGlyph.Parent = gui
		for _, child in bar:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		for _, name in bound do
			ContextActionService:UnbindAction(name)
		end
		table.clear(bound)
		table.clear(slots)
		table.clear(ownedOrder)
		table.clear(keyLabels)

		local owned: { [string]: boolean } = Profile.Get().Trolls or {}
		local keyIndex = 0
		for order, troll in Trolls.List do
			if owned[troll.Id] then
				keyIndex += 1
				local button = Ui.make("TextButton", {
					LayoutOrder = order,
					Size = UDim2.fromOffset(68, 68),
					BackgroundColor3 = Color3.fromRGB(45, 45, 60),
					BackgroundTransparency = 0.1,
					Text = "",
				}, bar)
				Ui.round(button, 14)
				Ui.border(button, 3)
				Ui.press(button)
				Ui.icon(button, `Troll_{troll.Id}`, {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.48),
					Size = UDim2.fromOffset(46, 46),
				})
				table.insert(ownedOrder, troll.Id)
				local keyLabel = Ui.outlined(button, {
					Position = UDim2.fromOffset(5, 2),
					Size = UDim2.fromOffset(20, 20),
					TextSize = 18,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = tostring(keyIndex),
					ZIndex = 3,
				})
				table.insert(keyLabels, keyLabel)
				-- Cooldown shade (drains from full to empty)
				local shade = Ui.make("Frame", {
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.fromScale(1, 0),
					BackgroundColor3 = Color3.new(0, 0, 0),
					BackgroundTransparency = 0.45,
					ZIndex = 4,
				}, button)
				Ui.round(shade, 14)
				button.Activated:Connect(function()
					useTroll(troll.Id)
				end)
				slots[troll.Id] = { Button = button, Shade = shade }

				local key = Trolls.Keys[keyIndex]
				if key then
					local name = `Troll_{troll.Id}`
					ContextActionService:BindAction(name, function(_n: string, state: Enum.UserInputState)
						if state == Enum.UserInputState.Begin then
							useTroll(troll.Id)
						end
						return Enum.ContextActionResult.Pass
					end, false, key)
					table.insert(bound, name)
				end
			end
		end
		gui.Enabled = keyIndex > 0 and player:GetAttribute("Stage") ~= "Box"
		selected = math.clamp(selected, 1, math.max(1, #ownedOrder))
		refreshPick()
	end

	-- Gamepad: R1 = next item, R2 = use it
	ContextActionService:BindAction("TrollNext", function(_n: string, state: Enum.UserInputState)
		if state ~= Enum.UserInputState.Begin or #ownedOrder == 0 or not gui.Enabled then
			return Enum.ContextActionResult.Pass
		end
		selected = selected % #ownedOrder + 1
		refreshPick()
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.ButtonR1)
	ContextActionService:BindAction("TrollUse", function(_n: string, state: Enum.UserInputState)
		local id = ownedOrder[selected]
		if state ~= Enum.UserInputState.Begin or not id or not gui.Enabled then
			return Enum.ContextActionResult.Pass
		end
		useTroll(id)
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.ButtonR2)

	local ownedKey = ""
	Profile.Watch(function()
		-- Only rebuild when the set of owned items changes
		local owned: { [string]: boolean } = Profile.Get().Trolls or {}
		local list = {}
		for id in owned do
			table.insert(list, id)
		end
		table.sort(list)
		local key = table.concat(list, ",")
		if key ~= ownedKey then
			ownedKey = key
			rebuild()
		end
	end)
	player:GetAttributeChangedSignal("Stage"):Connect(function()
		gui.Enabled = next(slots) ~= nil and player:GetAttribute("Stage") ~= "Box"
	end)

	notify.OnClientEvent:Connect(function(kind: string, data: { [string]: any })
		if kind == "TrollUsed" then
			local slot = slots[data.Id]
			if slot then
				slot.Shade.Size = UDim2.fromScale(1, 1)
				TweenService:Create(slot.Shade, TweenInfo.new(data.Cooldown, Enum.EasingStyle.Linear), {
					Size = UDim2.fromScale(1, 0),
				}):Play()
			end
		end
	end)
end

return TrollBar
