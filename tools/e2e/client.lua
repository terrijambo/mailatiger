-- E2E test, client side (injected into StarterPlayerScripts by driver.lua). Plays the core loop the way a
-- player would: the same remotes the UI fires, and the real ProximityPrompts.
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ScriptContext = game:GetService("ScriptContext")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer
local steps, clientErrors = {}, {}
ScriptContext.Error:Connect(function(message, trace)
	if #clientErrors < 30 then
		table.insert(clientErrors, message .. " @ " .. string.sub(trace, 1, 160))
	end
end)

local lastMessage
local function log(ok, text)
	-- A failure also shows the last thing the game said (usually why it refused)
	table.insert(steps, (if ok then "PASS " else "FAIL ") .. text .. (if ok then "" else "   [last message: " .. tostring(lastMessage) .. "]"))
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
	elseif kind == "Message" then
		lastMessage = tostring(data.Speaker) .. ": " .. tostring(data.Text)
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

-- Layout dump: every visible UI element's screen rectangle, so tools/e2e/draw_ui.py can draw the screen
local function dumpUi(tag)
	local gui = player:WaitForChild("PlayerGui")
	local camera = workspace.CurrentCamera
	local lines = { string.format("UI %s SCREEN %d %d", tag, math.floor(camera.ViewportSize.X), math.floor(camera.ViewportSize.Y)) }
	local screens = gui:GetChildren()
	table.sort(screens, function(a, b)
		local da = if a:IsA("ScreenGui") then a.DisplayOrder else 0
		local db = if b:IsA("ScreenGui") then b.DisplayOrder else 0
		return da < db
	end)
	for _, screen in screens do
		if screen:IsA("ScreenGui") and screen.Enabled then
			for _, d in screen:GetDescendants() do
				if d:IsA("GuiObject") and d.Visible and d.AbsoluteSize.X > 2 then
					local visible = true
					local p = d.Parent
					while p and p:IsA("GuiObject") do
						if not p.Visible then
							visible = false
						end
						p = p.Parent
					end
					if visible then
						local text = ""
						if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
							-- (cut at a whole character: half an emoji is invalid text and breaks run-in-roblox)
							local cut = utf8.offset(d.Text, 41)
							text = string.gsub(if cut then string.sub(d.Text, 1, cut - 1) else d.Text, "[%c|]", " ")
						end
						local c = d.BackgroundColor3
						table.insert(lines, string.format("UI %s %s|%s|%d|%d|%d|%d|%d|%d|%d|%.2f|%s", tag, screen.Name, d.ClassName,
							math.floor(d.AbsolutePosition.X), math.floor(d.AbsolutePosition.Y),
							math.floor(d.AbsoluteSize.X), math.floor(d.AbsoluteSize.Y),
							math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255), d.BackgroundTransparency, text))
					end
				end
			end
		end
	end
	table.insert(steps, "UIDUMP " .. table.concat(lines, string.char(10)))
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
	for _, name in { "MailATigerHud", "Travel", "Shop", "Store", "Settings", "OrdersBoard" } do
		log(gui:WaitForChild(name, 5) ~= nil, "UI " .. name .. " built")
	end
	log(gui:WaitForChild("Tutorial", 8) ~= nil, "tutorial started for a new player")
	log(gui:FindFirstChild("SideButtons") ~= nil and #gui.SideButtons:GetDescendants() > 10, "side buttons built")

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
		dumpUi("box")
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
	log(waitFor(function()
		return (profile().XP or 0) > 0 or (profile().Level or 1) > 1
	end, 3), "mailing gave XP")
	log(waitFor(function()
		return (profile().Quest or 1) >= 2
	end, 3), "first quest (mail a Hamster) completed")
	log(((profile().Species or {}).Hamster or 0) == 1, "the Hamster is in the collection")

	dumpUi("hud")

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
	task.wait(0.5)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local sneakerSpeed = 16 + Config.Tools.ById.Sneakers.PerLevel
	log(
		player:GetAttribute("WalkSpeed") == sneakerSpeed and humanoid.WalkSpeed == sneakerSpeed,
		"Sneakers work in town (speed " .. humanoid.WalkSpeed .. ")"
	)
	for _, tool in { "Gloves", "Net", "TapeGun", "MailBag" } do
		task.wait(0.2)
		remotes.ShopAction:FireServer("UpgradeTool", tool)
		log(waitFor(function()
			return (profile().Tools[tool] or 0) >= 1
		end, 3), "upgraded " .. tool)
	end
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

	-- Robux Store (Studio TEST buttons) and diamonds
	remotes.ShopAction:FireServer("StudioBuy", "ServerBoost")
	log(waitFor(function()
		local untilTime = Workspace:GetAttribute("BoostUntil")
		return type(untilTime) == "number" and untilTime > Workspace:GetServerTimeNow() + 100
	end, 3), "server boost started (2x coins for everyone)")
	local gems = profile().Diamonds or 0
	remotes.ShopAction:FireServer("StudioBuy", "DiamondsSmall")
	log(waitFor(function()
		return (profile().Diamonds or 0) >= gems + 40
	end, 3), "bought 40 diamonds (Studio test)")
	task.wait(0.3)
	remotes.ShopAction:FireServer("BuyUpgrade", "GoldenPaws")
	log(waitFor(function()
		return ((profile().Upgrades or {}).GoldenPaws or 0) == 1
	end, 3), "bought Golden Paws with diamonds")
	gui:WaitForChild("Upgrades", 3)
	log(gui:FindFirstChild("Upgrades") ~= nil and gui:FindFirstChild("Store") ~= nil, "Upgrades and Store windows exist")
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
	local penSpot = root.Position
	holdPrompt(map.PenCounter:FindFirstChildOfClass("ProximityPrompt"))
	log(waitFor(function()
		return (root.Position - penSpot).Magnitude > 40
	end, 4), "Pen counter teleports you to your best zone")

	-- 7b. Wild animals: every zone has some roaming, grabbing one you can take goes straight to BOX, and one
	-- that's too strong VINE BOOMs you back to town
	log(waitFor(function()
		local count = 0
		for _, ball in CollectionService:GetTagged("Critter") do
			if ball:GetAttribute("Wild") == true then
				count += 1
			end
		end
		return count >= 20
	end, 5), "wild animals roam the zones")
	remotes.ShopAction:FireServer("Travel", "Backyard")
	task.wait(1)
	local function wildNamed(animalId)
		for _, ball in CollectionService:GetTagged("Critter") do
			if ball:GetAttribute("Wild") == true and ball:GetAttribute("AnimalId") == animalId then
				local distance = (ball.Position - root.Position).Magnitude
				if distance < 20 then
					return ball
				end
			end
		end
		return nil
	end
	remotes.ShopAction:FireServer("Promo", "Wild:Hamster")
	local wildHamster = nil
	waitFor(function()
		wildHamster = wildNamed("Hamster")
		return wildHamster ~= nil
	end, 3)
	if wildHamster then
		-- (stand right next to it first: Roblox only shows the closest prompt for each key)
		root.CFrame = wildHamster.CFrame * CFrame.new(0, 1, 1.5)
		task.wait(0.4)
		holdPrompt(wildHamster:FindFirstChildOfClass("ProximityPrompt"), wildHamster)
	end
	log(waitFor(function()
		return player:GetAttribute("Stage") == "Box"
	end, 4), "grabbed a wild Hamster: straight to the BOX screen")
	-- (give it up: the Pen counter twice)
	goTo(map.PenCounter)
	local penPrompt = map.PenCounter:FindFirstChildOfClass("ProximityPrompt")
	holdPrompt(penPrompt)
	task.wait(0.3)
	holdPrompt(penPrompt)
	waitFor(function()
		return player:GetAttribute("Stage") == ""
	end, 3)
	remotes.ShopAction:FireServer("Travel", "Backyard")
	task.wait(1)
	remotes.ShopAction:FireServer("Promo", "Wild:Unicorn")
	local wildDragon = nil
	waitFor(function()
		wildDragon = wildNamed("Unicorn")
		return wildDragon ~= nil
	end, 3)
	lastMessage = nil
	if wildDragon then
		root.CFrame = wildDragon.CFrame * CFrame.new(0, 1, 3)
		task.wait(0.4)
		holdPrompt(wildDragon:FindFirstChildOfClass("ProximityPrompt"), wildDragon)
	end
	log(waitFor(function()
		return string.find(lastMessage or "", "RETURN TO SENDER", 1, true) ~= nil
	end, 4), "a too-strong wild Unicorn (10+ levels above) VINE BOOMs you")
	log(player:GetAttribute("Stage") == "", "...and no job started")
	task.wait(3)
	remotes.ShopAction:FireServer("BuyLure")
	log(waitFor(function()
		local untilTime = player:GetAttribute("LureUntil")
		return typeof(untilTime) == "number" and untilTime > Workspace:GetServerTimeNow()
	end, 3), "bought an Animal Lure")
	goTo(map.OrdersBoard)
	holdPrompt(map.OrdersBoard:FindFirstChildOfClass("ProximityPrompt"))
	log(waitFor(function()
		return gui.OrdersBoard.Enabled
	end, 3), "Orders prompt opens Gruff's Orders")
	task.wait(0.4)
	dumpUi("orders")
	gui.OrdersBoard.Enabled = false
	goTo(map.ShopCounter)
	holdPrompt(map.ShopCounter:FindFirstChildOfClass("ProximityPrompt"))
	log(waitFor(function()
		return gui.Shop.Enabled
	end, 3), "Shop counter opens the Supply Shop")
	task.wait(0.4)
	dumpUi("shop")
	gui.Shop.Enabled = false

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
		return waitFor(function()
			return player:GetAttribute("Stage") == ""
		end, 3)
	end
	-- Zone locks: a low-level player can't take a Tiger yet
	goTo(map.PenCounter)
	remotes.RequestAnimal:FireServer("Tiger", false)
	task.wait(1)
	log(player:GetAttribute("Stage") == "" and string.find(lastMessage or "", "Level", 1, true) ~= nil, "Tiger refused while its zone is locked")
	-- The test place lets the test jump to a high level (E2EServer), to try the later zones and troll items
	ReplicatedStorage:WaitForChild("E2ESetLevel"):FireServer(25)
	log(waitFor(function()
		return (profile().Level or 1) >= 25
	end, 3), "test player set to level 25")
	remotes.ShopAction:FireServer("BuyTroll", "BananaPeel")
	log(waitFor(function()
		return (profile().Trolls or {}).BananaPeel == true
	end, 3), "bought a Banana Peel")
	log(gui:WaitForChild("TrollBar", 3) ~= nil and gui.TrollBar.Enabled, "troll hotbar shows up")
	local used = events.TrollUsed or 0
	remotes.Troll:FireServer("BananaPeel")
	log(waitFor(function()
		return (events.TrollUsed or 0) > used
	end, 3), "used the Banana Peel")
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
	local building = map.Arenas.RooftopBuilding
	root.CFrame = CFrame.new(building.Position.X - building.Size.X / 2 - 4, 12, building.Position.Z) -- just off the edge, falling
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
	task.wait(0.5)
	for _, b in CollectionService:GetTagged("Critter") do
		local prompt = b:GetAttribute("OwnerId") == player.UserId and b:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			log(math.abs(prompt.HoldDuration - 0.3 * 0.85) < 0.01, "Gloves shorten the grab (" .. prompt.HoldDuration .. " s)")
			log(prompt.MaxActivationDistance == 8, "Net adds reach (" .. prompt.MaxActivationDistance .. " studs)")
		end
	end
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

	-- 13. Every sound id in Config.Sounds actually loads (a private or deleted sound would fail here)
	local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
	local broken, loaded = {}, 0
	local ContentProvider = game:GetService("ContentProvider")
	for name, def in Config.Sounds do
		if def.Id ~= "" then
			local sound = Instance.new("Sound")
			sound.SoundId = def.Id
			sound.Parent = game:GetService("SoundService")
			pcall(function()
				ContentProvider:PreloadAsync({ sound })
			end)
			waitFor(function()
				return sound.IsLoaded
			end, 4)
			if sound.IsLoaded and sound.TimeLength > 0 then
				loaded += 1
			else
				table.insert(broken, name)
			end
			sound:Destroy()
		end
	end
	log(#broken == 0, "sounds load: " .. loaded .. " ok" .. (if #broken > 0 then ", broken: " .. table.concat(broken, ", ") else ""))
	log(player:GetAttribute("MusicOff") == true, "music-off setting reached the music player")

	-- The GRUFF button: teleport to Postmaster Gruff
	task.wait(3.2)
	remotes.ShopAction:FireServer("GoToGruff")
	log(waitFor(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local gruff = map:FindFirstChild("Gruff")
		return root ~= nil and gruff ~= nil and (root.Position - gruff.Position).Magnitude < 20
	end, 3), "GRUFF button teleports you to Postmaster Gruff")

	-- Events (started with the Studio test buttons)
	remotes.ShopAction:FireServer("StudioEvent", "GoldenHour")
	log(waitFor(function()
		return Workspace:GetAttribute("EventId") == "GoldenHour" and Workspace:GetAttribute("VariantLuck") == 5
	end, 3), "Golden Hour started (Shiny odds x5)")
	task.wait(0.5)
	remotes.ShopAction:FireServer("StudioEvent", "Stampede")
	local stuff = Workspace:WaitForChild("EventStuff", 5)
	log(waitFor(function()
		return stuff and stuff:FindFirstChild("StampedeCritter") ~= nil
	end, 3), "stampede animals are running")
	local coinsBefore = profile().Coins
	-- (they run fast, so try up to 3 of them: walk up to one, then hold the grab while sticking to it)
	for _ = 1, 3 do
		local critter = stuff and stuff:FindFirstChild("StampedeCritter")
		if not critter or profile().Coins > coinsBefore then
			break
		end
		local stick = game:GetService("RunService").Heartbeat:Connect(function()
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and critter.Parent then
				root.CFrame = critter.CFrame * CFrame.new(0, 1, 2.5)
			end
		end)
		task.wait(0.6)
		stick:Disconnect()
		holdPrompt(critter:FindFirstChildOfClass("ProximityPrompt"), critter)
		task.wait(0.5)
	end
	log(waitFor(function()
		return profile().Coins > coinsBefore
	end, 3), "grabbed a stampede animal")

	-- The boss: pin it by holding a rope, then box it
	task.wait(0.5)
	remotes.ShopAction:FireServer("StudioEvent", "Boss")
	log(waitFor(function()
		return Workspace:GetAttribute("BossPhase") == "Pin"
	end, 3), "the boss landed")
	local arena = Workspace:FindFirstChild("BossArena")
	-- (it crash-lands in a parcel first: wait for it)
	local bossBall = arena and arena:WaitForChild("Boss", 6)
	local handle = arena and arena:FindFirstChild("BossHandle")
	local pinned = false
	if handle and bossBall then
		local prompt = handle:FindFirstChildOfClass("ProximityPrompt")
		local stick = game:GetService("RunService").Heartbeat:Connect(function()
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			-- (let go once it's pinned: the tape rolls drop out of sight then)
			if root and handle.Parent and handle.Position.Y > -10 and player:GetAttribute("Stage") ~= "Box" then
				local away = handle.Position - bossBall.Position
				away = Vector3.new(away.X, 0, away.Z).Unit
				root.CFrame = CFrame.new(handle.Position + away * 3)
			end
		end)
		local started = os.clock()
		while os.clock() - started < 30 and player:GetAttribute("Stage") ~= "Box" do
			pcall(function()
				prompt:InputHoldEnd()
				prompt:InputHoldBegin()
			end)
			task.wait(1.5)
		end
		pcall(function()
			prompt:InputHoldEnd()
		end)
		stick:Disconnect()
		pinned = player:GetAttribute("Stage") == "Box"
	end
	log(pinned, "pinned the boss (BOX stage for everyone there)")
	if pinned then
		for seam = 1, 5 do
			remotes.BoxingInput:FireServer("Tape", seam)
			task.wait(0.45)
		end
	end
	log(waitFor(function()
		return Workspace:GetAttribute("BossPhase") == "Mail"
	end, 5), "boxed the boss: now MAIL IT")
	-- Push the sealed box into the giant chute
	local bossBox = arena and arena:WaitForChild("BossBox", 3)
	local push = game:GetService("RunService").Heartbeat:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and bossBox and bossBox.Parent then
			root.CFrame = bossBox:GetPivot() * CFrame.new(0, 0, 12)
		end
	end)
	log(waitFor(function()
		return (events.BossWin or 0) > 0
	end, 45), "pushed the box into the chute and won")
	push:Disconnect()
	log(waitFor(function()
		return (events.BossReward or 0) > 0 and profile().LuckyNext == true and (profile().BossKills or {}).Tiger == 1
	end, 3), "boss reward: diamonds, coins and a Shiny next job")

	log(true, "events seen: " .. HttpService:JSONEncode(events))
	local challenges = profile().Challenges
	log(challenges ~= nil and #challenges.Daily == 3 and #challenges.Weekly == 1, "3 daily + 1 weekly challenge picked")
	log((events.VariantFound or 0) >= 1, "the lucky 3rd job was a Shiny")
	log(gui:FindFirstChild("OrdersBoard") ~= nil, "orders and challenges board exists")
	log(frames / frameTime > 30, string.format("average %.0f FPS, %d hitches over 0.1 s", frames / frameTime, hitches))
end

local ok, err = pcall(run)
if not ok then
	log(false, "test crashed: " .. tostring(err))
end
ReplicatedStorage:WaitForChild("E2EReport"):FireServer({ Steps = steps, Errors = clientErrors })
