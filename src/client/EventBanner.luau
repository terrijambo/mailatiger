--!strict
-- The event banner (top-right; top-center on phones): what's coming up next and what's running now, with a
-- countdown. It only reads Workspace attributes set by the server (EventService and BossService):
--   coming up    "Next: 🌟 GOLDEN HOUR in 0:24"   (the boss is announced 5 minutes early)
--   running      name, time left and what to do, plus live details:
--                Rush Order: the animal to mail and the top 3 so far
--                Boss: PIN IT (how many are holding on, and a pin bar) or BOX IT (seams done)
-- While a boss is coming or on and you're not in the arena, the banner has GO (teleport straight there) and
-- SKIP (no more boss banners, title card or popups until this fight is over).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Profile = require(script.Parent.Profile)
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

	-- GO / SKIP for the boss
	local shopAction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ShopAction") :: RemoteEvent
	local bossButtons = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -8),
		Size = UDim2.new(1, -24, 0, 36),
		BackgroundTransparency = 1,
		Visible = false,
	}, card)
	Ui.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
	}, bossButtons)
	local goButton = Ui.button(bossButtons, {
		Size = UDim2.new(0.62, -4, 1, 0),
		BackgroundColor3 = Ui.RED,
		Text = "⚔️ GO FIGHT",
		TextSize = 18,
		LayoutOrder = 1,
	})
	local skipButton = Ui.button(bossButtons, {
		Size = UDim2.new(0.38, -4, 1, 0),
		BackgroundColor3 = Ui.GREY,
		Text = "Skip",
		TextSize = 18,
		LayoutOrder = 2,
	})
	local skipped = false
	goButton.Activated:Connect(function()
		shopAction:FireServer("GoToBoss")
	end)
	skipButton.Activated:Connect(function()
		skipped = true
		player:SetAttribute("SkipBoss", true) -- (the HUD skips its boss popups too)
	end)
	local function inArena(): boolean
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return false
		end
		local offset = root.Position - Events.Boss.ArenaCenter
		return math.abs(offset.X) < Events.Boss.ArenaSize / 2 + 10
			and math.abs(offset.Z) < Events.Boss.ArenaSize / 2 + 10
	end

	local function refresh()
		local now = Workspace:GetServerTimeNow()
		local running = attr("EventId")
		local bossPhase = attr("BossPhase")
		local nextId = attr("EventNext")
		local nextAt = attr("EventNextAt")
		barBack.Visible = false
		if Profile.Learning() then
			card.Visible = false -- (simple start: events and the boss show up after Gruff's walkthrough)
			return
		end

		-- A boss coming or on? (SKIP lasts until it's over)
		local bossComing = nextId == "Boss" and typeof(nextAt) == "number" and nextAt > now
		local bossSoon = typeof(bossPhase) == "string" or bossComing
		if not bossSoon and skipped then
			skipped = false
			player:SetAttribute("SkipBoss", nil)
		end
		-- Coming up, but more than GoSeconds away (or any small event coming up): just a small timer
		local small = typeof(nextId) == "string"
			and typeof(nextAt) == "number"
			and typeof(bossPhase) ~= "string"
			and typeof(running) ~= "string"
			and (nextId ~= "Boss" or nextAt - now > Events.Boss.GoSeconds)
		local buttons = bossSoon and not skipped and not inArena() and attr("BossPadOpen") == true
		bossButtons.Visible = buttons
		line.Visible = not small
		card.Size = if small then UDim2.fromOffset(290, 40) else UDim2.fromOffset(330, if buttons then 136 else 92)
		barBack.Position = UDim2.new(0, 12, 1, if buttons then -56 else -18)
		title.TextSize = if small then 20 else 24

		if typeof(bossPhase) == "string" and not skipped then
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
			elseif bossPhase == "Mail" then
				local mailEnds = attr("BossMailEndsAt")
				line.Text = `MAIL IT! Push the box into the giant chute! Bonus x1.5 if it's in within {if typeof(
						mailEnds
					) == "number"
					then clock(mailEnds - now)
					else "?"}`
				barBack.Visible = true
				barFill.Size = UDim2.fromScale(1 - math.clamp(attr("BossMailLeft") or 1, 0, 1), 1)
				barFill.BackgroundColor3 = Color3.fromRGB(255, 120, 60)
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
				line.Text = if inArena()
					then "You're in the arena. Get ready!"
					else "A giant boss is landing! Press GO FIGHT to join the whole server."
				if skipped then
					card.Visible = false
					return
				end
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

	-- THE BIG ONE title card: slams in across the middle of the screen when a boss lands
	local titleLayer = Ui.make("ScreenGui", {
		Name = "BossTitle",
		ResetOnSpawn = false,
		DisplayOrder = 8,
		IgnoreGuiInset = true,
	}, gui.Parent)
	local strip = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.new(1.2, 0, 0, 150),
		Rotation = -4,
		BackgroundColor3 = Color3.fromRGB(150, 20, 30),
		BackgroundTransparency = 0.05,
		Visible = false,
	}, titleLayer)
	Ui.border(strip, 4)
	local bigName = Ui.outlined(strip, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.new(0.8, 0, 0, 84),
		TextScaled = true,
		TextColor3 = Ui.GOLD,
		Text = "",
	})
	Ui.outlined(strip, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 98),
		Size = UDim2.new(0.8, 0, 0, 36),
		TextScaled = true,
		Text = "⚔️ THE BIG ONE ⚔️  ·  red BOSS pad in the plaza",
	})
	local notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent
	-- The victory screen: the top 3 helpers with their avatars (for everyone near the arena)
	local victory = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(460, 300),
		BackgroundColor3 = Color3.fromRGB(40, 25, 60),
		BackgroundTransparency = 0.05,
		Visible = false,
	}, titleLayer)
	Ui.round(victory, 18)
	Ui.border(victory, 4)
	local victoryScale = Ui.autoScale(victory)
	local victoryTitle = Ui.outlined(victory, {
		Position = UDim2.fromOffset(0, 10),
		Size = UDim2.new(1, 0, 0, 48),
		TextScaled = true,
		TextColor3 = Ui.GOLD,
		Text = "",
	})
	local rows: { Frame } = {}
	local MEDALS = { "🥇", "🥈", "🥉" }
	for i = 1, 3 do
		local row = Ui.make("Frame", {
			Position = UDim2.fromOffset(20, 64 + (i - 1) * 74),
			Size = UDim2.new(1, -40, 0, 66),
			BackgroundColor3 = Color3.fromRGB(70, 50, 100),
		}, victory)
		Ui.round(row, 12)
		Ui.make("ImageLabel", {
			Name = "Face",
			Position = UDim2.fromOffset(6, 3),
			Size = UDim2.fromOffset(60, 60),
			BackgroundColor3 = Color3.fromRGB(30, 20, 45),
			Image = "",
		}, row)
		Ui.outlined(row, {
			Name = "Name",
			Position = UDim2.fromOffset(76, 6),
			Size = UDim2.new(1, -86, 0, 30),
			TextSize = 24,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "",
		})
		Ui.outlined(row, {
			Name = "Share",
			Position = UDim2.fromOffset(76, 36),
			Size = UDim2.new(1, -86, 0, 24),
			Font = Ui.FONT,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = MEDALS[i],
		})
		table.insert(rows, row)
	end
	local function nearArena(): boolean
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return false
		end
		local offset = root.Position - Events.Boss.ArenaCenter
		return math.abs(offset.X) < 150 and math.abs(offset.Z) < 150
	end
	local function showVictory(data: { [string]: any })
		local ranking = data.Ranking or {}
		if #ranking == 0 or not nearArena() then
			return
		end
		victoryTitle.Text = `🏆 {data.Boss} BOXED! 🏆`
		for i, row in rows do
			local entry = ranking[i]
			row.Visible = entry ~= nil
			if entry then
				(row:FindFirstChild("Name") :: TextLabel).Text =
					`{MEDALS[i]} {entry.Name}{if i == 1 then "  👑" else ""}`
				(row:FindFirstChild("Share") :: TextLabel).Text = `{entry.Share}% of the top helper's work`
				local face = row:FindFirstChild("Face") :: ImageLabel
				face.Image = ""
				task.spawn(function()
					local ok, image = pcall(
						Players.GetUserThumbnailAsync,
						Players,
						entry.UserId,
						Enum.ThumbnailType.HeadShot,
						Enum.ThumbnailSize.Size100x100
					)
					if ok then
						face.Image = image
					end
				end)
			end
		end
		victory.Size = UDim2.fromOffset(460, 74 + #ranking * 74)
		victory.Visible = true
		local full = Ui.screenScale()
		victoryScale.Scale = full * 0.6
		TweenService:Create(victoryScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = full,
		}):Play()
		task.delay(6, function()
			victory.Visible = false
		end)
	end

	notify.OnClientEvent:Connect(function(kind: string, data: { [string]: any })
		if kind == "BossWin" then
			showVictory(data)
			return
		end
		if kind ~= "BossTitle" or skipped or Profile.Learning() then
			return
		end
		bigName.Text = `👑 {data.Boss} 👑`
		strip.Visible = true
		strip.Position = UDim2.fromScale(-0.7, 0.38)
		TweenService:Create(strip, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(0.5, 0.38),
		}):Play()
		task.delay(2.8, function()
			local out = TweenService:Create(strip, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.fromScale(1.7, 0.38),
			})
			out:Play()
			out.Completed:Once(function()
				strip.Visible = false
			end)
		end)
	end)
end

return EventBanner
