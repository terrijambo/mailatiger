--!strict
-- "Mail it yourself":
--   * When you finish taping, the animal becomes a Parcel in your bag (saved with your progress).
--   * You carry your parcels (they show in your hands) to the Mail Chute and hold E to mail them.
--     That's when you get paid, orders get filled and the leaderboards update.
--   * Your chute upgrade (Supply Shop, Chutes tab) makes each parcel pay more. The Rocket Chute also lets you
--     press M to mail from anywhere.
-- Chute upgrades and bag size are in src/shared/Config/Mail.luau.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Analytics = require(script.Parent.Analytics)
local Badges = require(script.Parent.Badges)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local LeaderboardService = require(script.Parent.LeaderboardService)
local MapBuilder = require(script.Parent.MapBuilder)
local ModelFit = require(ReplicatedStorage.Shared.ModelFit)
local Format = require(ReplicatedStorage.Shared.Format)
local Orders = require(script.Parent.Orders)
local Remotes = require(script.Parent.Remotes)

type Parcel = DataService.Parcel

local MailService = {}

local PARCEL_SIZE = 1.0
local SHOWN_IN_HANDS = 3 -- at most this many parcels are drawn in your arms
local CARDBOARD = Color3.fromRGB(198, 156, 109)
local TAPE = Color3.fromRGB(215, 175, 105)

local map: MapBuilder.Map

local function notify(player: Player, kind: string, data: { [string]: any })
	Remotes.Notify:FireClient(player, kind, data)
end

local function pick(list: { string }): string
	return list[math.random(1, #list)]
end

local function animalIndex(animalId: string): number
	for index, animal in Config.Animals.List do
		if animal.Id == animalId then
			return index
		end
	end
	return 0
end

function MailService.Capacity(player: Player): number
	local bigBag = if player:GetAttribute("Pass_BigBag") == true then Config.Monetization.BigBagSlots else 0
	return Config.Mail.BagCapacity + Economy.ToolBonus(player, "MailBag") + bigBag
end

function MailService.Count(player: Player): number
	local profile = DataService.Get(player)
	return if profile then #profile.Parcels else 0
end

function MailService.HasRoom(player: Player): boolean
	return MailService.Count(player) < MailService.Capacity(player)
end

-- One parcel to show or throw: your Blender "Parcel" model if it's in ReplicatedStorage > PropModels,
-- otherwise a plain taped box. Anchored and not collidable; the caller moves or welds it.
local function makeParcel(floor: CFrame): Model
	local models = ReplicatedStorage:FindFirstChild("PropModels")
	local template = models and models:FindFirstChild("Parcel")
	local model: Model
	if template and template:IsA("Model") then
		model = template:Clone()
		ModelFit.Paint(model, "Parcel")
	else
		model = Instance.new("Model")
		local box = Instance.new("Part")
		box.Size = Vector3.one * PARCEL_SIZE
		box.Color = CARDBOARD
		box.Parent = model
		local tape = Instance.new("Part")
		tape.Size = Vector3.new(0.3, PARCEL_SIZE + 0.02, PARCEL_SIZE + 0.02)
		tape.Color = TAPE
		tape.CFrame = box.CFrame
		tape.Parent = model
	end
	model.Name = "Parcel"
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	ModelFit.Fit(model, floor, PARCEL_SIZE)
	return model
end

-- Draws up to SHOWN_IN_HANDS parcels stacked in front of the player's chest.
local function refreshCarried(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (character and root) then
		return
	end
	local old = character:FindFirstChild("CarriedParcels")
	if old then
		old:Destroy()
	end
	local count = math.min(MailService.Count(player), SHOWN_IN_HANDS)
	if count == 0 then
		return
	end

	local stack = Instance.new("Model")
	stack.Name = "CarriedParcels"
	for i = 1, count do
		local floor = root.CFrame * CFrame.new(0, -1.0 + (i - 1) * (PARCEL_SIZE + 0.05), -1.4)
		makeParcel(floor).Parent = stack
	end
	stack.Parent = character
	-- Weld after everything is in place and in the world, so the offsets are right
	for _, part in stack:GetDescendants() do
		if part:IsA("BasePart") then
			part.Massless = true
			part.Anchored = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = part
			weld.Parent = part
		end
	end
end

function MailService.AddParcel(player: Player, parcel: Parcel)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	table.insert(profile.Parcels, parcel)
	Economy.Sync(player)
	refreshCarried(player)
end

-- Throws parcels in an arc from the player into the chute
local function flyParcels(player: Player, count: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local from = root.CFrame * CFrame.new(0, 0, -1.4)
	local to = map.Chute.CFrame * CFrame.new(0, map.Chute.Size.Y / 2 + 0.5, 0)
	for i = 1, math.min(count, 5) do
		task.delay((i - 1) * 0.12, function()
			local parcel = makeParcel(from)
			parcel.Parent = Workspace
			local start = parcel:GetPivot()
			local distance = (to.Position - start.Position).Magnitude
			local frames = math.clamp(math.round(distance / 3), 20, 80)
			local height = math.max(4, distance / 4)
			for step = 1, frames do
				local t = step / frames
				parcel:PivotTo(CFrame.new(0, math.sin(t * math.pi) * height, 0) * start:Lerp(to, t))
				task.wait()
			end
			parcel:Destroy()
		end)
	end
end

-- Mail everything in the player's bag. fromChute = false means they pressed M (Rocket Chute only).
function MailService.MailAll(player: Player, fromChute: boolean)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local chute = Config.Mail.ChuteById[profile.ChuteTier] or Config.Mail.ChuteById.Basic
	if not fromChute and not chute.MailAnywhere then
		return
	end
	if #profile.Parcels == 0 then
		notify(player, "Message", { Speaker = "Mail Chute", Text = "Your bag is empty. Go box an animal!" })
		return
	end

	local total, orderBonus, best = 0, 0, 1
	local lines = {}
	for _, parcel in profile.Parcels do
		local pay = math.max(1, math.round(parcel.Coins * chute.PayMult))
		total += pay
		orderBonus += Orders.OnMailed(profile, parcel.AnimalId, {
			Stars = parcel.Stars,
			Escapes = parcel.Escapes,
			UnderPar = parcel.UnderPar,
		})
		-- Leaderboard stats
		profile.Mailed += 1
		if parcel.Stars == 5 then
			profile.FiveStampJobs += 1
		end
		if
			parcel.AnimalId == "Tiger"
			and parcel.Seconds >= Config.Social.Leaderboards.MinTigerSeconds
			and (profile.BestTigerSeconds == 0 or parcel.Seconds < profile.BestTigerSeconds)
		then
			profile.BestTigerSeconds = parcel.Seconds
		end
		profile.RarestIndex = math.max(profile.RarestIndex, animalIndex(parcel.AnimalId))
		best = math.max(best, parcel.Stars)

		-- Badges (only awarded once you've set their ids in Config/Badges.luau)
		Badges.Award(player, "FirstDelivery")
		if parcel.AnimalId == "Tiger" then
			Badges.Award(player, "TigerMailed")
		elseif parcel.AnimalId == "Gruff" then
			Badges.Award(player, "SpecialDelivery")
		end
		if parcel.Stars == 5 then
			Badges.Award(player, "FiveStamps")
		end
		if parcel.Stamp == "CHAOS" then
			Badges.Award(player, "ChaosCourier")
		end

		local animal = Config.Animals.ById[parcel.AnimalId]
		local name = if animal then animal.DisplayName else parcel.AnimalId
		table.insert(lines, `{name} {string.rep("★", parcel.Stars)} +{Format.Short(pay)}`)
	end

	local count = #profile.Parcels
	profile.Parcels = {}
	Economy.AddCoins(player, total + orderBonus, "MailPayout") -- (one update, so the HUD shows one "+N")
	Analytics.Onboarding(player, "Mailed")
	refreshCarried(player)
	LeaderboardService.Submit(player)
	flyParcels(player, count)
	notify(player, "MailReceipt", {
		Count = count,
		Coins = total,
		OrderBonus = orderBonus,
		Chute = chute.DisplayName,
		Lines = lines,
		Line = pick(Config.Gruff.Ratings[best]),
		Best = best, -- the best star rating in this bag (the receipt stamps it)
	})
end

function MailService.Start(builtMap: MapBuilder.Map)
	map = builtMap

	map.ChutePrompt.Triggered:Connect(function(player: Player)
		MailService.MailAll(player, true)
	end)
	Remotes.Listen(Remotes.MailAnywhere, 2, function(player: Player)
		MailService.MailAll(player, false)
	end)

	-- Show carried parcels when a save loads and after every respawn
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart")
			refreshCarried(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	DataService.Loaded:Connect(function(player: Player)
		refreshCarried(player)
	end)
end

return MailService
