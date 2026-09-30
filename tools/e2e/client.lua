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
local lastBoxStart, lastParcel = nil, nil
notify.OnClientEvent:Connect(function(kind, data)
	events[kind] = (events[kind] or 0) + 1
	if kind == "BoxStart" then
		lastBoxStart = data
	elseif kind == "Parcel" then
		lastParcel = data
	end
end)

-- Holds a prompt for its full duration. With `follow`, the character sticks to that part while holding
-- (like a player chasing an animal that keeps running).
local function holdPrompt(prompt, follow)
	local ok = pcall(function()
		prompt:InputHoldBegin()
	end)
	local stick = nil
	if follow then
		stick = game:GetService("RunService").Heartbeat:Connect(function()
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and follow.Parent then
				root.CFrame = follow.CFrame * CFrame.new(0, 1, 1.5)
			end
		end)
	end
	task.wait(prompt.HoldDuration + 0.3)
	if stick then
		stick:Disconnect()
	end
	pcall(function()
		prompt:InputHoldEnd()
	end)
	return ok
end

-- Frame-rate sampling once the game has loaded: average FPS, and how many frames hitched (> 0.1 s)
local frames, frameTime, hitches, sampling = 0, 0, 0, false
game:GetService("RunService").RenderStepped:Connect(function(dt)
	if sampling then
		frames += 1
		frameTime += dt
		if dt > 0.1 then
			hitches += 1
		end
	end
end)

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
	sampling = true
	log(waitFor(function()
		return #(profile().Orders or {}) == 3
	end, 5), "Gruff's orders are ready (3)")
	log(waitFor(function()
		return profile().PaycheckStreak == 1
	end, 10), "daily paycheck paid (streak day 1)")

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
			if prompt and not holdPrompt(prompt, ball) then
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
		local boxGui = gui:FindFirstChild("BoxingScreen")
		log(boxGui ~= nil and boxGui.Enabled, "BOX screen is showing")
		local viewportModel = false
		for _, d in (boxGui and boxGui:GetDescendants()) or {} do
			if d:IsA("ViewportFrame") and d:FindFirstChildOfClass("Model") then
				viewportModel = true
			end
		end
		log(viewportModel, "BOX screen shows the 3D animal")
		local jobBox = #CollectionService:GetTagged("JobBox") > 0
		log(jobBox, "the box in the arena is tagged for the anger wiggle")
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

	-- 7. Prompts open their menus
	local function goTo(part)
		root.CFrame = part.CFrame * CFrame.new(0, 2, 5)
		task.wait(0.4)
	end
	goTo(map.PenCounter)
	holdPrompt(map.PenCounter:FindFirstChildOfClass("ProximityPrompt"))
	log(waitFor(function()
		return gui.PenMenu.Enabled
	end, 3), "Pen prompt opens the Pen menu")
	gui.PenMenu.Enabled = false
	goTo(map.OrdersBoard)
	holdPrompt(map.OrdersBoard:FindFirstChildOfClass("ProximityPrompt"))
	log(waitFor(function()
		return gui.OrdersBoard.Enabled
	end, 3), "Orders prompt opens Gruff's Orders")
	gui.OrdersBoard.Enabled = false

	-- 8. Chute upgrades, in order, up to the Rocket (mail from anywhere)
	goTo(map.ShopCounter)
	for _, chute in { "Express", "Pneumatic", "Rocket" } do
		remotes.ShopAction:FireServer("BuyChute", chute)
		log(waitFor(function()
			return profile().ChuteTier == chute
		end, 3), "bought the " .. chute .. " chute")
		task.wait(0.2)
	end
	task.wait(0.5)
	local rocketModel = false
	for _, d in Workspace:GetChildren() do
		if d:IsA("Model") and d.Name == "MailChuteRocket" then
			rocketModel = true
		end
	end
	log(rocketModel, "your chute now shows the Rocket Chute model")
	local board = map:FindFirstChild("Leaderboard_FiveStamps")
	log(board ~= nil and board:FindFirstChild("Board") ~= nil, "leaderboards are drawn")
	local messages = events.Message or 0
	remotes.MailAnywhere:FireServer()
	log(waitFor(function()
		return (events.Message or 0) > messages
	end, 3), "Rocket mail-anywhere answers (empty bag)")

	-- 9. The tiger: grab it, then make it furious. VINE BOOM, launch, RETURN TO SENDER, Gruff's cap flies.
	local function catchMine(tries)
		for _ = 1, tries do
			for _, b in CollectionService:GetTagged("Critter") do
				if b:GetAttribute("OwnerId") == player.UserId then
					root.CFrame = b.CFrame * CFrame.new(0, 1, 1.5)
					task.wait(0.15)
					local prompt = b:FindFirstChildOfClass("ProximityPrompt")
					if prompt then
						holdPrompt(prompt, b)
					end
				end
			end
			if player:GetAttribute("Stage") == "Box" then
				return true
			end
			task.wait(0.2)
		end
		return false
	end
	local function giveUp()
		goTo(map.PenCounter)
		local pen = map.PenCounter:FindFirstChildOfClass("ProximityPrompt")
		holdPrompt(pen)
		task.wait(0.3)
		holdPrompt(pen)
		gui.PenMenu.Enabled = false
		return waitFor(function()
			return player:GetAttribute("Stage") == ""
		end, 3)
	end
	goTo(map.PenCounter)
	remotes.RequestAnimal:FireServer("Tiger", false)
	log(waitFor(function()
		return player:GetAttribute("Stage") == "Catch"
	end, 5), "picked a Tiger (sent to the Ice Rink)")
	if catchMine(90) then -- tigers are hard (and roar at you), so allow lots of tries
		log(true, "grabbed the tiger")
		waitFor(function()
			return lastBoxStart ~= nil and lastBoxStart.AnimalId == "Tiger"
		end, 3)
		local angry = nil
		for i, spot in (lastBoxStart and lastBoxStart.Spots) or {} do
			if spot.Kind == "Angry" then
				angry = i
			end
		end
		log(angry ~= nil, "tiger has an angry spot to poke")
		local launches = events.Launch or 0
		for _ = 1, 30 do
			if (events.Launch or 0) > launches then
				break
			end
			if angry then
				remotes.BoxingInput:FireServer("Angry", angry)
			end
			task.wait(0.55)
		end
		log((events.Launch or 0) > launches, "anger hit 100: launched")
		log(waitFor(function()
			return (events.Breakout or 0) > 0
		end, 3), "RETURN TO SENDER (breakout)")
		task.wait(0.3)
		log(map.GruffHat.Anchored == false, "Gruff's cap was knocked flying")
		log(waitFor(function()
			return player:GetAttribute("Stage") == "Catch"
		end, 8), "tiger escaped back into the arena")
	else
		log(false, "could not grab the tiger in 90 tries")
	end
	task.wait(5) -- let the ragdoll finish
	log(giveUp(), "used the Pen twice to give up on the tiger")

	-- 10. Rooftop: walk off the edge and get put back up
	remotes.RequestAnimal:FireServer("Dragon", false)
	log(waitFor(function()
		return player:GetAttribute("Stage") == "Catch"
	end, 5), "picked a Dragon (sent to the Rooftop)")
	task.wait(1)
	log(root.Position.Y > 28, "standing on the roof")
	root.CFrame = CFrame.new(76, 12, -125) -- just off the edge, falling
	task.wait(2)
	log(root.Position.Y > 28, "fell off the roof and was put back up")
	task.wait(2.5)
	log(giveUp(), "gave up on the dragon")

	-- 11. Chicken in Chaos Mode: wait for an egg, pick it up, then box and mail it (CHAOS pay)
	remotes.RequestAnimal:FireServer("Chicken", true)
	log(waitFor(function()
		return player:GetAttribute("Stage") == "Catch" and player:GetAttribute("Chaos") == true
	end, 5), "picked a Chicken in Chaos Mode")
	local egg = nil
	waitFor(function()
		for _, d in Workspace:GetDescendants() do
			if d.Name == "Egg" and d:IsA("BasePart") then
				egg = d
				return true
			end
		end
		return false
	end, 12)
	log(egg ~= nil, "the chicken laid an egg")
	if egg then
		log(egg:FindFirstChildOfClass("Model") ~= nil, "the egg uses your Egg model")
		local before = events.Message or 0
		root.CFrame = egg.CFrame
		log(waitFor(function()
			return egg.Parent == nil and (events.Message or 0) > before
		end, 3), "picked up the egg (bonus coins)")
	end
	if catchMine(40) then
		waitFor(function()
			return lastBoxStart ~= nil and lastBoxStart.AnimalId == "Chicken"
		end, 3)
		local sweet = 1
		for i, spot in lastBoxStart.Spots do
			if spot.Kind == "Sweet" then
				sweet = i
				break
			end
		end
		for seam = 1, lastBoxStart.SeamCount do
			for _ = 1, 8 do
				remotes.BoxingInput:FireServer("Pet", sweet)
				task.wait(0.1)
			end
			remotes.BoxingInput:FireServer("Tape", seam)
			task.wait(0.4)
		end
		local parcels = events.Parcel or 0
		log(waitFor(function()
			return (events.Parcel or 0) >= parcels and #profile().Parcels == 1
		end, 5), "boxed the chicken")
		local receipts = events.MailReceipt or 0
		remotes.MailAnywhere:FireServer() -- Rocket chute: mail from right here
		log(waitFor(function()
			return (events.MailReceipt or 0) > receipts
		end, 5), "Rocket-mailed the chicken from the arena")
	else
		log(false, "could not grab the chicken")
	end

	-- 12. A Wooden Crate and a FRAGILE stamp on a Hamster job
	goTo(map.ShopCounter)
	remotes.ShopAction:FireServer("BuyBox", "Wood")
	log(waitFor(function()
		return profile().EquippedBox == "Wood"
	end, 3), "bought and equipped the Wooden Crate")
	task.wait(0.2)
	remotes.ShopAction:FireServer("BuyStamp", "Fragile")
	log(waitFor(function()
		return profile().SelectedStamp == "Fragile"
	end, 3), "FRAGILE stamp selected for the next job")
	goTo(map.PenCounter)
	lastBoxStart = nil
	remotes.RequestAnimal:FireServer("Hamster", false)
	waitFor(function()
		return player:GetAttribute("Stage") == "Catch"
	end, 5)
	log(profile().SelectedStamp == nil, "the stamp was used up by the job")
	if catchMine(25) then
		waitFor(function()
			return lastBoxStart ~= nil
		end, 3)
		log(lastBoxStart.BoxId == "Wood", "the job uses the Wooden Crate")
		local sweet = 1
		for i, spot in lastBoxStart.Spots do
			if spot.Kind == "Sweet" then
				sweet = i
				break
			end
		end
		lastParcel = nil
		for seam = 1, lastBoxStart.SeamCount do
			for _ = 1, 8 do
				remotes.BoxingInput:FireServer("Pet", sweet)
				task.wait(0.1)
			end
			remotes.BoxingInput:FireServer("Tape", seam)
			task.wait(0.4)
		end
		log(waitFor(function()
			return lastParcel ~= nil
		end, 5) and lastParcel.Stamp == "FRAGILE", "the parcel is stamped FRAGILE")
	else
		log(false, "could not grab the second hamster")
	end

	log(true, "events seen: " .. HttpService:JSONEncode(events))
	log(frames / frameTime > 30, string.format("average %.0f FPS, %d hitches over 0.1 s", frames / frameTime, hitches))
end

local ok, err = pcall(run)
if not ok then
	log(false, "test crashed: " .. tostring(err))
end
ReplicatedStorage:WaitForChild("E2EReport"):FireServer({ Steps = steps, Errors = clientErrors })
