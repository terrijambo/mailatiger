--!strict
-- The event banner (top-right; top-center on phones): what's coming up next and what's running now, with a
-- countdown. It only reads Workspace attributes set by the server (EventService and BossService):
--   coming up    "Next: 🌟 GOLDEN HOUR in 0:24"   (the boss is announced 5 minutes early)
--   running      name, time left and what to do, plus live details:
--                Rush Order: the animal to mail and the top 3 so far
--                Boss: PIN IT (how many are holding on, and a pin bar) or BOX IT (seams done)

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer
local Events = Config.Events

local EventBanner = {}

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function attr(name: string): any
	return Workspace:GetAttribute(name)
end

function EventBanner.Start()
	local gui = Ui.make("ScreenGui", {
		Name = "EventBanner",
		ResetOnSpawn = false,
		DisplayOrder = 2,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))
	local card = Ui.make("Frame", {
		Size = UDim2.fromOffset(330, 92),
		BackgroundColor3 = Color3.fromRGB(40, 30, 70),
		BackgroundTransparency = 0.15,
		Visible = false,
	}, gui)
	Ui.round(card, 14)
	Ui.border(card, 3)
	Ui.autoScale(card)
	Ui.onResize(function()
		local compact = Ui.compact()
		card.AnchorPoint = Vector2.new(if compact then 0.5 else 1, 0)
		card.Position = if compact then UDim2.new(0.5, 0, 0, 96) else UDim2.new(1, -Ui.margin(), 0, 8)
	end)
	local title = Ui.outlined(card, {
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.new(1, -24, 0, 30),
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	})
	local line = Ui.outlined(card, {
		Position = UDim2.fromOffset(12, 34),
		Size = UDim2.new(1, -24, 0, 34),
		Font = Ui.FONT,
		TextSize = 15,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
	})
	local barBack = Ui.make("Frame", {
		Position = UDim2.new(0, 12, 1, -18),
		Size = UDim2.new(1, -24, 0, 10),
		BackgroundColor3 = Color3.fromRGB(20, 15, 35),
		Visible = false,
	}, card)
	Ui.round(barBack, 5)
	local barFill = Ui.make("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Ui.GOLD,
	}, barBack)
	Ui.round(barFill, 5)

	local function refresh()
		local now = Workspace:GetServerTimeNow()
		local running = attr("EventId")
		local bossPhase = attr("BossPhase")
		local nextId = attr("EventNext")
		local nextAt = attr("EventNextAt")
		barBack.Visible = false

		if typeof(bossPhase) == "string" then
			-- THE BIG ONE
			local name = attr("BossName") or "BOSS"
			local endsAt = attr("BossEndsAt")
			card.BackgroundColor3 = Color3.fromRGB(110, 25, 30)
			title.Text = `⚔️ {name}  {if typeof(endsAt) == "number" then clock(endsAt - now) else ""}`
			if bossPhase == "Pin" then
				local held, need = attr("BossHeld") or 0, attr("BossNeed") or 1
				line.Text = `PIN IT! Hold the glowing ropes ({held}/{need} holding). Jump over its stomps!`
				barBack.Visible = true
				barFill.Size = UDim2.fromScale(math.clamp(attr("BossPin") or 0, 0, 1), 1)
				barFill.BackgroundColor3 = Ui.GOLD
			else
				local taped, seams = attr("BossTaped") or 0, attr("BossSeams") or 5
				line.Text = `BOX IT! Tape together, pet to keep it calm. Seams: {taped}/{seams}`
				barBack.Visible = true
				barFill.Size = UDim2.fromScale(taped / math.max(1, seams), 1)
				barFill.BackgroundColor3 = Ui.GREEN
			end
			card.Visible = true
		elseif typeof(running) == "string" then
			local event = Events.ById[running]
			local endsAt = attr("EventEndsAt")
			if event then
				card.BackgroundColor3 = Color3.fromRGB(40, 30, 70)
				title.Text = `{event.Emoji} {event.DisplayName}  {if typeof(endsAt) == "number"
					then clock(endsAt - now)
					else ""}`
				local text = event.Description
				if running == "RushOrder" then
					local animalId = attr("RushAnimal")
					local animal = if typeof(animalId) == "string" then Config.Animals.ById[animalId] else nil
					local ok, names = pcall(HttpService.JSONDecode, HttpService, attr("RushWinners") or "[]")
					local winners = if ok and type(names) == "table" then names else {}
					text = `Mail a {if animal then animal.DisplayName else "?"}! `
						.. (
							if #winners > 0
								then "Winners: " .. table.concat(winners, ", ")
								else "First 3 to mail one win!"
						)
				end
				line.Text = text
				card.Visible = true
			else
				card.Visible = false
			end
		elseif typeof(nextId) == "string" and typeof(nextAt) == "number" and nextAt > now then
			card.BackgroundColor3 = Color3.fromRGB(30, 40, 60)
			if nextId == "Boss" then
				title.Text = `⚔️ {attr("BossName") or "BOSS"} in {clock(nextAt - now)}`
				line.Text = "A giant boss is coming! Step on the red BOSS pad in the plaza to join the fight."
			else
				local event = Events.ById[nextId]
				title.Text = if event then `Next: {event.Emoji} {event.DisplayName} in {clock(nextAt - now)}` else ""
				line.Text = if event then event.Description else ""
			end
			card.Visible = true
		else
			card.Visible = false
		end
		-- Out of the way during the BOX screen
		if player:GetAttribute("Stage") == "Box" and typeof(bossPhase) ~= "string" then
			card.Visible = false
		end
	end

	task.spawn(function()
		while gui.Parent do
			refresh()
			task.wait(0.25)
		end
	end)
end

return EventBanner
