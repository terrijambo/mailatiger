--!strict
-- MENU > TRAVEL: teleport to Postmaster Gruff, any zone you've unlocked, or the boss arena while a boss is
-- coming or on. Locked zones show the level they open at. (The server checks everything: Travel.luau.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Menus = require(script.Parent.Menus)
local Profile = require(script.Parent.Profile)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local TravelMenu = {}

function TravelMenu.Start()
	local shopAction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ShopAction") :: RemoteEvent
	local gui, window = Ui.window(player:WaitForChild("PlayerGui"), "Travel", "Travel", Ui.BLUE, Vector2.new(460, 560))

	local list = Ui.make("ScrollingFrame", {
		Position = UDim2.fromOffset(16, 60),
		Size = UDim2.new(1, -32, 1, -76),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, window)
	Ui.make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)

	local function row(
		order: number,
		icon: string,
		name: string,
		detail: string,
		color: Color3,
		locked: boolean,
		id: string
	)
		local card = Ui.card(list, { LayoutOrder = order, Size = UDim2.new(1, -12, 0, 64) })
		Ui.icon(card, icon, { Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(48, 48) })
		Ui.label(card, {
			Position = UDim2.fromOffset(68, 6),
			Size = UDim2.new(1, -200, 0, 28),
			Font = Ui.TITLE_FONT,
			TextSize = 22,
			Text = name,
		})
		Ui.label(card, {
			Position = UDim2.fromOffset(68, 34),
			Size = UDim2.new(1, -200, 0, 22),
			TextSize = 15,
			TextColor3 = Color3.fromRGB(110, 100, 90),
			Text = detail,
		})
		local go = Ui.button(card, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(110, 44),
			BackgroundColor3 = if locked then Ui.GREY else color,
			Text = if locked then "🔒" else "GO",
			TextSize = 22,
		})
		if not locked then
			go.Activated:Connect(function()
				shopAction:FireServer("Travel", id)
				Menus.CloseAll()
			end)
		end
	end

	local function redraw()
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local level = Profile.Get().Level or 1
		row(1, "Button_Gruff", "Postmaster Gruff", "Town: the Mail Chute and the shops", Ui.RED, false, "Gruff")
		for index, def in Config.Arenas.List do
			local need = Config.Levels.ZoneLevels[def.Id] or 1
			local locked = level < need
			row(
				1 + index,
				`Zone_{def.Id}`,
				def.DisplayName,
				if locked then `Opens at Level {need}` else `Tier {table.concat(def.Tiers, " & ")} animals`,
				def.Color,
				locked,
				def.Id
			)
		end
		if Workspace:GetAttribute("BossPadOpen") == true then
			local name = Workspace:GetAttribute("BossName")
			row(
				20,
				"Hud_Quest",
				`⚔️ {if typeof(name) == "string" then name else "BOSS"}`,
				"The boss arena: the whole server vs. one giant",
				Ui.RED,
				false,
				"Boss"
			)
		end
	end

	Menus.Register("Travel", gui, redraw)
	Profile.Watch(function()
		if gui.Enabled then
			redraw()
		end
	end)
	Workspace:GetAttributeChangedSignal("BossPadOpen"):Connect(function()
		if gui.Enabled then
			redraw()
		end
	end)
end

return TravelMenu
