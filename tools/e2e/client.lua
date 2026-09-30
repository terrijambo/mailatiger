-- E2E test, client side (injected into StarterPlayerScripts by driver.lua). Plays the core loop the way a
-- player would: the same remotes the UI fires, and the real ProximityPrompts.
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ScriptContext = game:GetService("ScriptContext")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local steps, clientErrors = {}, {}
ScriptContext.Error:Connect(function(message, trace)
	if #clientErrors < 30 then
		table.insert(clientErrors, message .. " @ " .. string.sub(trace, 1, 160))
	end
end)

local function log(ok, text)
	table.insert(steps, (if ok then "PASS " else "FAIL ") .. text)
end
local function profile()
	local raw = player:GetAttribute("Profile")
	return if typeof(raw) == "string" then HttpService:JSONDecode(raw) else nil
end
local function waitFor(check, timeout)
	local start = os.clock()
	while os.clock() - start < timeout do
		if check() then
			return true
		end
		task.wait(0.1)
	end
	return false
end

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local notify = remotes:WaitForChild("Notify")
local events = {}
local lastBoxStart = nil
notify.OnClientEvent:Connect(function(kind, data)
	events[kind] = (events[kind] or 0) + 1
	if kind == "BoxStart" then
		lastBoxStart = data
	end
end)

local function holdPrompt(prompt)
	local ok = pcall(function()
		prompt:InputHoldBegin()
	end)
	task.wait(prompt.HoldDuration + 0.3)
	pcall(function()
		prompt:InputHoldEnd()
	end)
	return ok
end

local function run()
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart")
	log(waitFor(function()
		return profile() ~= nil
	end, 15), "save loaded (Profile attribute)")
	local map = Workspace:WaitForChild("GrayboxMap", 10)
	log(map ~= nil, "map exists")
	local gui = player:WaitForChild("PlayerGui")
	for _, name in { "MailATigerHud", "PenMenu", "Shop", "Store", "Settings", "OrdersBoard" } do
		log(gui:WaitForChild(name, 5) ~= nil, "UI " .. name .. " built")
	end
	log(gui:WaitForChild("Tutorial", 8) ~= nil, "tutorial started for a new player")
	local startCoins = profile().Coins

	-- 1. Pick a Hamster at the Pen
	root.CFrame = map.PenCounter.CFrame * CFrame.new(0, 2, 5)
	task.wait(0.5)
	remotes.RequestAnimal:FireServer("Hamster", false)
	log(waitFor(function()
		return player:GetAttribute("Stage") == "Catch"
	end, 5), "picked a Hamster, CATCH started")
	task.wait(1)
	local animalModel = Workspace:FindFirstChild("HamsterArt") ~= nil
	log(animalModel, "client draws the Hamster model on the runner ball")

	-- 2. Catch it: stand on it and hold the grab prompt
	local caught = false
	for _ = 1, 25 do
		local ball = nil
		for _, b in CollectionService:GetTagged("Critter") do
			if b:GetAttribute("OwnerId") == player.UserId then
				ball = b
			end
		end
		if ball then
			root.CFrame = ball.CFrame * CFrame.new(0, 1, 1.5)
			task.wait(0.15)
			local prompt = ball:FindFirstChildOfClass("ProximityPrompt")
			if prompt and not holdPrompt(prompt) then
				log(false, "InputHoldBegin is not allowed for scripts")
				break
			end
		end
		if player:GetAttribute("Stage") == "Box" then
			caught = true
			break
		end
		task.wait(0.2)
	end
	log(caught, "grabbed it, BOX started")

	-- 3. Box it: keep petting a sweet spot and tape every seam
	if caught then
		waitFor(function()
			return lastBoxStart ~= nil
		end, 3)
		local sweet = 1
		for i, spot in (lastBoxStart and lastBoxStart.Spots) or {} do
			if spot.Kind == "Sweet" then
				sweet = i
				break
			end
		end
		local seams = (lastBoxStart and lastBoxStart.SeamCount) or 2
		log(lastBoxStart ~= nil, "BoxStart data arrived (" .. seams .. " seams)")
		for seam = 1, seams do
			for _ = 1, 6 do
				remotes.BoxingInput:FireServer("Pet", sweet)
				task.wait(0.1)
			end
			remotes.BoxingInput:FireServer("Tape", seam)
			task.wait(0.4)
		end
		log(waitFor(function()
			return (events.Parcel or 0) > 0
		end, 5), "taped it: parcel in the bag")
		log(#(profile().Parcels or {}) == 1, "bag shows 1 parcel")
	end

	-- 4. Mail it at the chute
	local chute = map.MailChute
	root.CFrame = chute.CFrame * CFrame.new(0, 1, 5)
	task.wait(0.4)
	holdPrompt(chute:FindFirstChildOfClass("ProximityPrompt"))
	log(waitFor(function()
		return (events.MailReceipt or 0) > 0
	end, 5), "mailed it at the chute (receipt)")
	local after = profile()
	log(after.Mailed == 1 and #after.Parcels == 0, "save: Mailed=1 and the bag is empty")
	log(after.Coins > startCoins, "got paid (" .. startCoins .. " -> " .. after.Coins .. ")")

	-- 5. Shop, codes, settings
	root.CFrame = map.ShopCounter.CFrame * CFrame.new(0, 2, 5)
	task.wait(0.5)
	remotes.ShopAction:FireServer("BuyStamp", "Fragile")
	log(waitFor(function()
		return (profile().Stamps.Fragile or 0) >= 1
	end, 3), "bought a Fragile stamp")
	task.wait(0.2)
	remotes.ShopAction:FireServer("UpgradeTool", "Sneakers")
	log(waitFor(function()
		return (profile().Tools.Sneakers or 0) >= 1
	end, 3), "upgraded Sneakers")
	local before = profile().Coins
	remotes.RedeemCode:FireServer("launch")
	log(waitFor(function()
		return profile().Coins > before
	end, 3), "code LAUNCH paid out")
	task.wait(1.1)
	local again = profile().Coins
	remotes.RedeemCode:FireServer("LAUNCH")
	task.wait(1)
	log(profile().Coins == again, "code LAUNCH can't be used twice")
	remotes.Setting:FireServer("Music", false)
	log(waitFor(function()
		local settings = profile().Settings
		return settings ~= nil and settings.Music == false
	end, 3), "setting saved (music off)")

	-- 6. The tutorial finishes (its shop step times out after 12 s) and is remembered
	log(waitFor(function()
		return profile().TutorialDone == true
	end, 16), "tutorial finished and remembered")
	task.wait(0.2)
	log(gui:FindFirstChild("Tutorial") == nil, "tutorial UI cleaned up")
	log(true, "events seen: " .. HttpService:JSONEncode(events))
end

local ok, err = pcall(run)
if not ok then
	log(false, "test crashed: " .. tostring(err))
end
ReplicatedStorage:WaitForChild("E2EReport"):FireServer({ Steps = steps, Errors = clientErrors })
