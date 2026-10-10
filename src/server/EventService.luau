--!strict
-- Server events on the clock (numbers in src/shared/Config/Events.luau, plan in docs/EVENTS_PLAN.md):
--   :10 :20 :30 :40 :50   a small event (Golden Hour, Double XP, Speed Tape, Rush Order, Coin Rain, Mystery
--                         Parcel, Stampede), announced 30 seconds early
--   :00                   the boss (BossService), warned 5 minutes early
-- The client banner reads Workspace attributes:
--   EventNext / EventNextAt    what's coming up, and when (unix time)
--   EventId / EventEndsAt      what's running now, and when it ends
--   plus event settings: VariantLuck, XPMult, AngerMult, PerfectMult, RushAnimal, RushWinners
-- In Studio, ShopAction "StudioEvent" (any small event id, or "Boss") starts one right away for testing.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Analytics = require(script.Parent.Analytics)
local BossService = require(script.Parent.BossService)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local MailService = require(script.Parent.MailService)
local MapBuilder = require(script.Parent.MapBuilder)
local ProgressionService = require(script.Parent.ProgressionService)
local Remotes = require(script.Parent.Remotes)

local Events = Config.Events
type SmallEvent = typeof(Events.Small[1])

local EventService = {}

local map: MapBuilder.Map
local folder: Folder
local running: SmallEvent? = nil
local runningSlot = -1
local studioRun = false
local endsAt = 0
local cleanup: { () -> () } = {}
local rushWinners: { Player } = {}
local mysteryCarrier: Player? = nil
local mysteryPart: BasePart? = nil

local function toAll(kind: string, data: { [string]: any })
	Remotes.Notify:FireAllClients(kind, data)
end

local function say(text: string)
	toAll("Message", { Speaker = "Postmaster Gruff", Text = text })
end

local function playerFrom(hit: BasePart): Player?
	local model = hit:FindFirstAncestorOfClass("Model")
	return if model then Players:GetPlayerFromCharacter(model) else nil
end

-- Which small event a slot gets (the same in every server; never the same as the slot before)
local function rawPick(slot: number): number
	return Random.new(slot * 31 + 7):NextInteger(1, #Events.Small)
end
local function pick(slot: number): SmallEvent
	local index = rawPick(slot)
	if index == rawPick(slot - 1) then
		index = index % #Events.Small + 1
	end
	return Events.Small[index]
end

local function isBossSlot(slot: number): boolean
	return slot % (3600 // Events.SlotSeconds) == 0
end

---------------------------------------------------------------------------------------------------
-- The small events

local function coinRain()
	local cfg = Events.CoinRain
	task.spawn(function()
		local spacing = 60 / cfg.Drops
		for _ = 1, cfg.Drops do
			if running == nil or running.Id ~= "CoinRain" then
				break
			end
			local angle, distance = math.random() * math.pi * 2, math.sqrt(math.random()) * cfg.Radius
			local at = cfg.Center
				+ Vector3.new(math.cos(angle) * distance, 40 + math.random() * 15, math.sin(angle) * distance)
			local big = math.random() < cfg.BigCoinChance -- (a rare big coin worth BigCoinJobs)
			local drop = Instance.new("Part")
			drop.Name = if big then "BigCoinDrop" else "CoinDrop"
			drop.Shape = Enum.PartType.Cylinder
			drop.Size = if big then Vector3.new(0.8, 4.4, 4.4) else Vector3.new(0.5, 2.4, 2.4)
			drop.Color = if big then Color3.fromRGB(255, 170, 30) else Color3.fromRGB(255, 205, 50)
			drop.Material = Enum.Material.Neon
			drop.CFrame = CFrame.new(at) * CFrame.Angles(0, math.random() * 6, math.rad(90))
			drop.Parent = folder
			local taken = false
			drop.Touched:Connect(function(hit)
				local player = if taken then nil else playerFrom(hit)
				if player then
					taken = true
					drop:Destroy()
					local jobs = if big then cfg.BigCoinJobs else cfg.CoinJobs
					Economy.AddCoins(player, math.max(1, math.round(Economy.BestBaseValue(player) * jobs)), "CoinRain")
				end
			end)
			task.delay(25, function()
				if drop.Parent then
					drop:Destroy()
				end
			end)
			task.wait(spacing)
		end
	end)
end

local function endMystery(delivered: Player?)
	local part = mysteryPart
	mysteryPart, mysteryCarrier = nil, nil
	if part then
		part:Destroy()
	end
	if delivered then
		local cfg = Events.Mystery
		local profile = DataService.Get(delivered)
		if profile then
			Economy.AddCoins(delivered, Economy.BestBaseValue(delivered) * cfg.Jobs, "MysteryParcel")
		end
		toAll(
			"EventWinner",
			{ Event = "MysteryParcel", Player = delivered.DisplayName, Text = "delivered the MYSTERY PARCEL!" }
		)
		Analytics.Custom(delivered, "MysteryParcelDelivered")
	end
end

local function dropMystery()
	local part, carrier = mysteryPart, mysteryCarrier
	if not part or not carrier then
		return
	end
	mysteryCarrier = nil
	local weld = part:FindFirstChild("CarryWeld")
	if weld then
		weld:Destroy()
	end
	part.Anchored = true
	part.CFrame = CFrame.new(part.Position.X, 1.6, part.Position.Z)
end

local function mysteryParcel()
	local cfg = Events.Mystery
	local at = cfg.Spots[math.random(1, #cfg.Spots)]
	local part = Instance.new("Part")
	part.Name = "MysteryParcel"
	part.Size = Vector3.new(3, 3, 3)
	part.Color = Color3.fromRGB(190, 90, 255)
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CFrame = CFrame.new(at + Vector3.new(0, 1.6, 0))
	part.Parent = folder
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 40)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 2000
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(230, 170, 255)
	label.TextStrokeTransparency = 0
	label.Text = "📦 MYSTERY PARCEL"
	label.Parent = gui
	gui.Parent = part
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Grab"
	prompt.ObjectText = "Mystery Parcel"
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	mysteryPart = part
	-- Grab it (or steal it from whoever has it!)
	prompt.Triggered:Connect(function(player: Player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or mysteryCarrier == player then
			return
		end
		local thief = mysteryCarrier
		dropMystery()
		part.Anchored = false
		part.Massless = true
		part.CFrame = root.CFrame * CFrame.new(0, 4.5, 0)
		local weld = Instance.new("WeldConstraint")
		weld.Name = "CarryWeld"
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		mysteryCarrier = player
		local text = if thief
			then `stole the Mystery Parcel from {thief.DisplayName}!`
			else "grabbed the Mystery Parcel! Mail it at the chute!"
		toAll("EventWinner", { Event = "MysteryGrab", Player = player.DisplayName, Text = text })
		local humanoid = (character :: Model):FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Died:Once(function()
				if mysteryCarrier == player then
					dropMystery()
				end
			end)
		end
	end)
	table.insert(cleanup, function()
		if mysteryPart then
			say("Nobody mailed the Mystery Parcel. It went back to the sorting office.")
			endMystery(nil)
		end
	end)
end

local function stampede()
	local cfg = Events.Stampede
	local critters: { { Ball: BasePart, Target: Vector3, Speed: number } } = {}
	local function newTarget(): Vector3
		local angle, distance = math.random() * math.pi * 2, math.sqrt(math.random()) * cfg.Radius
		return cfg.Center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
	end
	for _ = 1, cfg.Count do
		local animalId = cfg.Animals[math.random(1, #cfg.Animals)]
		local animal = Config.Animals.ById[animalId]
		local ball = Instance.new("Part")
		ball.Name = "StampedeCritter"
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.new(2, 2, 2)
		ball.Color = animal.Color or Color3.new(1, 1, 1)
		ball.Anchored = true
		ball.CanCollide = false
		ball:SetAttribute("AnimalId", animalId)
		ball.CFrame = CFrame.new(newTarget() + Vector3.new(0, 1, 0))
		ball.Parent = folder
		CollectionService:AddTag(ball, "Critter")
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Grab"
		prompt.ObjectText = animal.DisplayName
		prompt.HoldDuration = 0.35
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.Parent = ball
		local entry: { Ball: BasePart, Target: Vector3, Speed: number } =
			{ Ball = ball, Target = newTarget(), Speed = 9 + math.random() * 6 }
		table.insert(critters, entry)
		prompt.Triggered:Connect(function(player: Player)
			if not ball.Parent then
				return
			end
			ball:Destroy()
			Economy.AddCoins(player, math.max(1, math.round(Economy.BestBaseValue(player) * cfg.Jobs)), "Stampede")
			ProgressionService.AddXP(player, cfg.XP, "Stampede")
			Remotes.Notify:FireClient(player, "StampedeCatch", { Animal = animal.DisplayName })
		end)
	end
	local connection = RunService.Heartbeat:Connect(function(dt)
		for _, entry in critters do
			local ball = entry.Ball
			if ball.Parent then
				local flat = Vector3.new(ball.Position.X, 0, ball.Position.Z)
				local toTarget = entry.Target - flat
				if toTarget.Magnitude < 2 then
					entry.Target = newTarget()
				else
					local step = flat + toTarget.Unit * math.min(entry.Speed * dt, toTarget.Magnitude)
					ball.CFrame = CFrame.lookAt(step + Vector3.new(0, 1, 0), entry.Target + Vector3.new(0, 1, 0))
				end
			end
		end
	end)
	table.insert(cleanup, function()
		connection:Disconnect()
	end)
end

local function startSmall(event: SmallEvent, untilTime: number)
	running = event
	endsAt = untilTime
	rushWinners = {}
	Workspace:SetAttribute("EventId", event.Id)
	Workspace:SetAttribute("EventEndsAt", untilTime)
	if event.Id == "GoldenHour" then
		Workspace:SetAttribute("VariantLuck", Events.GoldenHourLuck)
	elseif event.Id == "DoubleXP" then
		Workspace:SetAttribute("XPMult", Events.DoubleXPMult)
	elseif event.Id == "SpeedTape" then
		Workspace:SetAttribute("AngerMult", Events.SpeedTapeAngerMult)
		Workspace:SetAttribute("PerfectMult", Events.SpeedTapePerfectMult)
	elseif event.Id == "RushOrder" then
		local options = Events.Rush.Animals
		Workspace:SetAttribute("RushAnimal", options[math.random(1, #options)])
		Workspace:SetAttribute("RushWinners", "[]")
	elseif event.Id == "CoinRain" then
		coinRain()
	elseif event.Id == "MysteryParcel" then
		mysteryParcel()
	elseif event.Id == "Stampede" then
		stampede()
	end
	toAll("EventStart", { Id = event.Id })
end

local function endSmall()
	local event = running
	if not event then
		return
	end
	running = nil
	for _, undo in cleanup do
		undo()
	end
	table.clear(cleanup)
	folder:ClearAllChildren()
	for _, name in
		{ "EventId", "EventEndsAt", "VariantLuck", "XPMult", "AngerMult", "PerfectMult", "RushAnimal", "RushWinners" }
	do
		Workspace:SetAttribute(name, nil)
	end
	toAll("EventEnd", { Id = event.Id })
end

---------------------------------------------------------------------------------------------------
-- Hooks from the rest of the game

-- One animal mailed (MailService): Rush Order winners
function EventService.OnMailed(player: Player, animalId: string)
	if not running or running.Id ~= "RushOrder" or Workspace:GetAttribute("RushAnimal") ~= animalId then
		return
	end
	if #rushWinners >= #Events.Rush.Jobs or table.find(rushWinners, player) then
		return
	end
	table.insert(rushWinners, player)
	local place = #rushWinners
	local profile = DataService.Get(player)
	if profile then
		Economy.AddCoins(player, Economy.BestBaseValue(player) * Events.Rush.Jobs[place], "RushOrder")
	end
	local names = {}
	for _, winner in rushWinners do
		table.insert(names, winner.DisplayName)
	end
	Workspace:SetAttribute("RushWinners", HttpService:JSONEncode(names))
	local placeText = ({ "1st", "2nd", "3rd" })[place] or `{place}th`
	toAll(
		"EventWinner",
		{ Event = "RushOrder", Player = player.DisplayName, Text = `finished the Rush Order {placeText}!` }
	)
end

-- Studio only: start an event right now (from the Store's test buttons, or the playtest)
function EventService.StudioStart(id: string)
	if not RunService:IsStudio() then
		return
	end
	if id == "Boss" then
		BossService.Begin(os.time() + Events.Boss.Seconds, true)
		return
	end
	local event = Events.ById[id]
	if event then
		endSmall()
		studioRun = true
		startSmall(event, os.time() + event.Seconds)
	end
end

function EventService.Start(builtMap: MapBuilder.Map)
	map = builtMap
	folder = Instance.new("Folder")
	folder.Name = "EventStuff"
	folder.Parent = Workspace
	BossService.Init(builtMap)
	MailService.OnMailed = EventService.OnMailed

	-- Delivering the Mystery Parcel at the chute
	map.ChutePrompt.Triggered:Connect(function(player: Player)
		if mysteryCarrier == player then
			endMystery(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		if mysteryCarrier == player then
			dropMystery()
		end
	end)

	task.spawn(function()
		while true do
			local now = os.time()
			local slot = now // Events.SlotSeconds
			local slotStart = slot * Events.SlotSeconds
			local nextStart = slotStart + Events.SlotSeconds

			-- What's coming up (the boss is announced earlier)
			local nextSlot = slot + 1
			local warn = if isBossSlot(nextSlot) then Events.Boss.WarnSeconds else Events.AnnounceSeconds
			if nextStart - now <= warn then
				Workspace:SetAttribute("EventNext", if isBossSlot(nextSlot) then "Boss" else pick(nextSlot).Id)
				Workspace:SetAttribute("EventNextAt", nextStart)
				BossService.SetWarning(isBossSlot(nextSlot), nextStart)
			else
				Workspace:SetAttribute("EventNext", nil)
				Workspace:SetAttribute("EventNextAt", nil)
				BossService.SetWarning(false, 0)
			end

			-- What's running now
			if studioRun then
				-- (a test event started from Studio runs its full time, whatever the clock says)
				if now >= endsAt then
					studioRun = false
					endSmall()
				end
			elseif runningSlot ~= slot then
				-- A new slot (or the server just started part-way through one)
				runningSlot = slot
				endSmall()
				if isBossSlot(slot) then
					BossService.Begin(slotStart + Events.Boss.Seconds, false)
				else
					local event = pick(slot)
					local untilTime = slotStart + event.Seconds
					if now < untilTime then
						startSmall(event, untilTime)
					end
				end
			elseif running and now >= endsAt then
				endSmall()
			end
			task.wait(0.5)
		end
	end)
end

return EventService
