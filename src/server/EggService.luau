--!strict
-- Egg stands (one per island, next to the arrival circle: Scenery/Zones.luau builds them, tagged "EggStand"
-- with a ZoneId). Hold E to buy an egg: it wobbles and cracks, and the animal it rolled (Config/Eggs.luau)
-- pops out right next to you, wild, to grab and box.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local ProgressionService = require(script.Parent.ProgressionService)
local Remotes = require(script.Parent.Remotes)
local WildService = require(script.Parent.WildService)

local Eggs = Config.Eggs

local EggService = {}

local hatching: { [Player]: boolean } = {}

local function say(player: Player, text: string)
	Remotes.Notify:FireClient(player, "Message", { Speaker = "Egg Stand", Text = text })
end

-- The egg on the stand wobbles, then a copy flies up and bursts
local function crack(stand: BasePart)
	local egg = stand:FindFirstChild("Egg") :: BasePart?
	if not egg then
		return
	end
	local rest = egg.CFrame
	for i = 1, 8 do
		egg.CFrame = rest * CFrame.Angles(0, 0, (if i % 2 == 0 then 1 else -1) * 0.18)
		task.wait(Eggs.HatchSeconds / 10)
	end
	egg.CFrame = rest
	local burst = Instance.new("Part")
	burst.Anchored = true
	burst.CanCollide = false
	burst.CanQuery = false
	burst.Shape = Enum.PartType.Ball
	burst.Material = Enum.Material.Neon
	burst.Color = Color3.new(1, 1, 1)
	burst.Size = Vector3.one * 2
	burst.CFrame = rest
	burst.Parent = Workspace
	TweenService:Create(burst, TweenInfo.new(0.35), { Size = Vector3.one * 9, Transparency = 1 }):Play()
	task.delay(0.4, function()
		burst:Destroy()
	end)
end

function EggService.Hatch(player: Player, stand: BasePart)
	local zoneId = stand:GetAttribute("ZoneId")
	local profile = DataService.Get(player)
	if typeof(zoneId) ~= "string" or not profile or hatching[player] then
		return
	end
	if not ProgressionService.ZoneOpen(player, zoneId) then
		say(player, "This island isn't open for you yet.")
		return
	end
	local animalId = Eggs.Roll(zoneId, profile.Level, math.random())
	if not animalId then
		say(player, "Everything in this egg is too strong for you right now. Level up first!")
		return
	end
	local price = Eggs.Price(zoneId)
	if not Economy.TrySpend(player, price, `Egg_{zoneId}`) then
		say(player, `An egg here costs {Format.Short(price)} coins.`)
		return
	end
	hatching[player] = true
	Analytics.Custom(player, `Egg_{zoneId}`, 1)
	crack(stand)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local at = if root then root.Position + root.CFrame.LookVector * 7 else stand.Position + stand.CFrame.LookVector * 7
	WildService.Hatch(animalId, at, player)
	local animal = Config.Animals.ById[animalId]
	local rarityId = Config.Wild.RarityOf[animalId] or "Common"
	Remotes.Notify:FireClient(player, "EggHatched", {
		Animal = if animal then animal.DisplayName else animalId,
		AnimalId = animalId,
		Rarity = rarityId,
	})
	hatching[player] = nil
end

function EggService.Start()
	local function hook(stand: Instance)
		local prompt = stand:FindFirstChildOfClass("ProximityPrompt")
		if stand:IsA("BasePart") and prompt then
			prompt.Triggered:Connect(function(player: Player)
				EggService.Hatch(player, stand)
			end)
		end
	end
	for _, stand in CollectionService:GetTagged("EggStand") do
		hook(stand)
	end
	CollectionService:GetInstanceAddedSignal("EggStand"):Connect(hook)
end

return EggService
