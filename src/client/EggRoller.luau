--!strict
-- The egg roller: when you buy an egg (server/EggService.luau), a slot-machine reel of the island's animals
-- spins across your screen, slows down, ticks past the marker one card at a time, and lands on the animal
-- you got (the server has already rolled it; this only shows it). The card it lands on pops in its rarity's
-- color, and the animal hatches next to you as the reel stops. Timings are in Config/Eggs.luau.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Ui = require(script.Parent.Ui)

local EggRoller = {}

local CARD_W = 112
local CARD_H = 138
local GAP = 10
local STEP = CARD_W + GAP
local WINDOW_W = 620
local WINDOW_H = CARD_H + 20

type Odd = { AnimalId: string, Chance: number }

local function rarityOf(animalId: string)
	return Config.Rarity.ById[Config.Wild.RarityOf[animalId] or "Common"] or Config.Rarity.List[1]
end

-- Picks reel filler: weighted like the egg, but flattened (square root) so rarer animals still flash past
local function pickFiller(odds: { Odd }): string
	local total = 0
	for _, odd in odds do
		total += math.sqrt(odd.Chance)
	end
	local roll = math.random() * total
	for _, odd in odds do
		roll -= math.sqrt(odd.Chance)
		if roll <= 0 then
			return odd.AnimalId
		end
	end
	return odds[#odds].AnimalId
end

local function rarest(odds: { Odd }): string
	local best = odds[1]
	for _, odd in odds do
		if odd.Chance < best.Chance then
			best = odd
		end
	end
	return best.AnimalId
end

local function makeCard(parent: Instance, animalId: string, index: number): Frame
	local rarity = rarityOf(animalId)
	local animal = Config.Animals.ById[animalId]
	local card = Ui.card(parent, {
		Name = `Card{index}`,
		Size = UDim2.fromOffset(CARD_W, CARD_H),
		Position = UDim2.fromOffset((index - 1) * STEP, 10),
		BackgroundColor3 = Ui.PAPER,
	})
	local stroke = card:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = rarity.Color
		stroke.Thickness = 4
	end
	Ui.icon(card, `Animal_{animalId}`, {
		Size = UDim2.fromOffset(72, 72),
		Position = UDim2.new(0.5, 0, 0, 8),
		AnchorPoint = Vector2.new(0.5, 0),
	})
	Ui.label(card, {
		Text = if animal then animal.DisplayName else animalId,
		Font = Ui.TITLE_FONT,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		TextScaled = true,
		Size = UDim2.new(1, -10, 0, 20),
		Position = UDim2.fromOffset(5, 84),
	})
	local band = Ui.make("Frame", {
		BackgroundColor3 = rarity.Color,
		Size = UDim2.new(1, -12, 0, 22),
		Position = UDim2.new(0, 6, 1, -28),
	}, card)
	Ui.round(band, 8)
	Ui.outlined(band, {
		Text = string.upper(rarity.DisplayName),
		TextSize = 14,
		Font = Ui.FONT,
		Size = UDim2.fromScale(1, 1),
	})
	Ui.make("UIScale", { Scale = 1 }, card)
	return card
end

local playing = false

local function play(data: { [string]: any })
	local odds = data.Odds :: { Odd }
	local resultId = data.AnimalId :: string
	if playing or typeof(odds) ~= "table" or #odds == 0 or typeof(resultId) ~= "string" then
		return
	end
	playing = true
	local player = Players.LocalPlayer
	local rarity = rarityOf(resultId)
	local zone = Config.Arenas.ById[data.ZoneId or ""]

	local gui = Ui.make("ScreenGui", {
		Name = "EggRoller",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 9, -- above popups and the HUD
	}, player:WaitForChild("PlayerGui"))
	local root = Ui.make("CanvasGroup", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(WINDOW_W + 40, WINDOW_H + 140),
		GroupTransparency = 1,
	}, gui)
	local scale = Ui.autoScale(root)
	scale.Scale = math.min(scale.Scale, (Ui.viewSize().X - 24) / (WINDOW_W + 40))

	Ui.outlined(root, {
		Text = `🥚 {string.upper(if zone then zone.DisplayName else "")} EGG`,
		TextSize = 34,
		Size = UDim2.new(1, 0, 0, 40),
	})

	-- The reel window, with the gold marker over its middle
	local window = Ui.make("Frame", {
		BackgroundColor3 = Color3.fromRGB(45, 38, 60),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 52),
		Size = UDim2.fromOffset(WINDOW_W, WINDOW_H),
		ClipsDescendants = true,
	}, root)
	Ui.round(window, 16)
	Ui.border(window, 4)
	Ui.make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(0.18, 0),
			NumberSequenceKeypoint.new(0.82, 0),
			NumberSequenceKeypoint.new(1, 0.55),
		}),
	}, window)
	local strip = Ui.make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, window)
	local line = Ui.make("Frame", {
		BackgroundColor3 = Ui.GOLD,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(0, 4, 1, 0),
		ZIndex = 5,
	}, window)
	local markers: { { Text: string, Y: number, Anchor: number } } = {
		{ Text = "▼", Y = 52 + 6, Anchor = 1 }, -- just above the window
		{ Text = "▲", Y = 52 + WINDOW_H - 6, Anchor = 0 }, -- just below it
	}
	for _, marker in markers do
		Ui.outlined(root, {
			Text = marker.Text,
			TextSize = 30,
			TextColor3 = Ui.GOLD,
			AnchorPoint = Vector2.new(0.5, marker.Anchor),
			Position = UDim2.new(0.5, 0, 0, marker.Y),
			Size = UDim2.fromOffset(40, 30),
			ZIndex = 6,
		})
	end

	local result = Ui.outlined(root, {
		Text = `{string.upper(rarity.DisplayName)} {string.upper(
			Config.Animals.ById[resultId] and Config.Animals.ById[resultId].DisplayName or resultId
		)}!`,
		TextSize = 36,
		TextColor3 = rarity.Color,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 52 + WINDOW_H + 30),
		Size = UDim2.new(1, 0, 0, 40),
		TextTransparency = 1,
	})
	local resultStroke = result:FindFirstChildOfClass("UIStroke")
	if resultStroke then
		resultStroke.Transparency = 1
	end

	-- The reel: filler, the result, then the rarest animal right after it (so close!), then a little more
	local count = Config.Eggs.ReelCards
	local cards: { Frame } = {}
	for i = 1, count + 3 do
		local animalId = if i == count then resultId elseif i == count + 1 then rarest(odds) else pickFiller(odds)
		cards[i] = makeCard(strip, animalId, i)
	end

	-- Where the strip sits so card `i`'s middle (plus a nudge) is under the marker
	local function offsetFor(i: number, nudge: number): number
		return WINDOW_W / 2 - ((i - 1) * STEP + CARD_W / 2) - nudge
	end
	local from = offsetFor(2, 0)
	local to = offsetFor(count, (math.random() - 0.5) * CARD_W * 0.6)
	strip.Position = UDim2.fromOffset(from, 0)

	TweenService:Create(root, TweenInfo.new(0.2), { GroupTransparency = 0 }):Play()
	local seconds = Config.Eggs.RollSeconds
	local start = os.clock()
	local lastIndex = 0
	while true do
		local t = math.min((os.clock() - start) / seconds, 1)
		local eased = 1 - (1 - t) ^ 4
		local x = from + (to - from) * eased
		strip.Position = UDim2.fromOffset(x, 0)
		local under = math.floor((WINDOW_W / 2 - x) / STEP) + 1
		if under ~= lastIndex then
			lastIndex = under
			Sfx.Play("EggTick")
		end
		if t >= 1 then
			break
		end
		RunService.RenderStepped:Wait()
	end

	-- Landed: the winning card pops and glows, the name comes up in its rarity's color
	Sfx.Play("EggWin")
	line.BackgroundColor3 = rarity.Color
	local winner = cards[count]
	winner.ZIndex = 4
	local winScale = winner:FindFirstChildOfClass("UIScale")
	if winScale then
		TweenService:Create(winScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1.08,
		}):Play()
	end
	local glow = Ui.make("Frame", {
		BackgroundColor3 = rarity.Color,
		BackgroundTransparency = 0.2,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = winner.Position + UDim2.fromOffset(CARD_W / 2, CARD_H / 2),
		Size = UDim2.fromOffset(CARD_W, CARD_H),
		ZIndex = 3,
	}, strip)
	Ui.round(glow, 18)
	TweenService:Create(glow, TweenInfo.new(0.6), {
		Size = UDim2.fromOffset(CARD_W + 60, CARD_H + 30),
		BackgroundTransparency = 1,
	}):Play()
	for i, card in cards do
		if i ~= count then
			TweenService:Create(card, TweenInfo.new(0.3), { BackgroundTransparency = 0.5 }):Play()
		end
	end
	TweenService:Create(result, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
	if resultStroke then
		TweenService:Create(resultStroke, TweenInfo.new(0.25), { Transparency = 0 }):Play()
	end

	task.wait(Config.Eggs.RevealSeconds)
	local fade = TweenService:Create(root, TweenInfo.new(0.3), { GroupTransparency = 1 })
	fade:Play()
	fade.Completed:Wait()
	gui:Destroy()
	playing = false
end

function EggRoller.Start()
	local notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent
	notify.OnClientEvent:Connect(function(kind: string, data: any)
		if kind == "EggRoll" and typeof(data) == "table" then
			task.spawn(play, data)
		end
	end)
end

return EggRoller
