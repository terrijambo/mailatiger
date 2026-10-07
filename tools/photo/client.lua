-- Photo tour, client side (used instead of tools/e2e/client.lua by tools/photo/run.sh). Hides the UI, sets
-- bright daylight, and flies the camera through a list of shots (the whole archipelago from above, the
-- town, each island), holding each one while tools/photo/shoot.py screenshots the test window.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ScriptContext = game:GetService("ScriptContext")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local steps, clientErrors = {}, {}
ScriptContext.Error:Connect(function(message, trace)
	if #clientErrors < 30 then
		table.insert(clientErrors, message .. " @ " .. string.sub(trace, 1, 160))
	end
end)

local HOLD = tonumber(os.getenv and os.getenv("PHOTO_HOLD") or nil) or 7

local function run()
	local map = Workspace:WaitForChild("GrayboxMap", 30)
	if not map then
		table.insert(steps, "FAIL no map")
		return
	end
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remotes.ShopAction:FireServer("Promo", "Noon")
	task.wait(8) -- (let the models and the islands finish loading)
	local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
	local World = Config.World

	local camera = Workspace.CurrentCamera
	local function hideUi()
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, false)
		for _, gui in player.PlayerGui:GetChildren() do
			if gui:IsA("ScreenGui") and gui.Name ~= "PhotoTag" then
				gui.Enabled = false
			end
		end
	end

	local shots = {}
	local function shot(name, from, to, fov)
		table.insert(shots, { Name = name, CFrame = CFrame.lookAt(from, to), Fov = fov or 60 })
	end
	-- The whole archipelago, from high up in the south (like the concept art)
	shot("overview", Vector3.new(0, 640, 520), Vector3.new(0, 0, -20), 62)
	shot("overview_west", Vector3.new(-520, 560, 260), Vector3.new(-40, 0, 0), 62)
	shot("overview_north", Vector3.new(160, 600, -560), Vector3.new(0, 0, 0), 62)
	-- The town
	shot("town", Vector3.new(0, 150, 190), Vector3.new(0, 0, -10), 55)
	shot("town_low", Vector3.new(30, 26, 70), Vector3.new(0, 8, -40), 60)
	shot("leaderboards", Vector3.new(-30, 10, 0), Vector3.new(-55, 5, 0), 60)
	shot("leaderboards_side", Vector3.new(-40, 8, 26), Vector3.new(-55, 5, -4), 60)
	shot("mailroom", Vector3.new(30, 20, -24), Vector3.new(44, 3, -60), 62)
	shot("mailroom_side", Vector3.new(74, 14, -44), Vector3.new(38, 3, -56), 60)
	table.insert(shots, { Name = "@AllMachines" })
	shot("mailroom_owned", Vector3.new(30, 20, -24), Vector3.new(44, 3, -60), 62)
	shot("mailroom_owned_close", Vector3.new(34, 10, -38), Vector3.new(36, 5, -56), 62)
	shot("road", Vector3.new(9, 6, 64), Vector3.new(0, 0, 92), 60)
	shot("howto", Vector3.new(-16, 7, 66), Vector3.new(-22, 6, 50), 60)
	shot("plaza_postoffice", Vector3.new(-18, 14, 20), Vector3.new(0, 8, -55), 65)
	-- Each island, from its town side and a bit above
	for _, island in World.Islands do
		local toTown = (Vector3.zero - island.Center)
		toTown = Vector3.new(toTown.X, 0, toTown.Z).Unit
		local from = island.Center + toTown * (island.Radius + 70) + Vector3.new(0, 95, 0)
		shot(island.Id, from, island.Center + Vector3.new(0, 4, 0), 58)
		local side = Vector3.new(0, 1, 0):Cross(toTown)
		local bridgeFrom, bridgeTo = World.Bridge(island)
		if bridgeFrom and bridgeTo then
			local inward = Vector3.new(island.Center.X - bridgeTo.X, 0, island.Center.Z - bridgeTo.Z).Unit
			shot(island.Id .. "_arrive", bridgeTo - inward * 14 + Vector3.new(0, 26, 0), bridgeTo + inward * 40, 60)
		end
		shot(island.Id .. "_close", island.Center + side * 75 + toTown * 55 + Vector3.new(0, 52, 0), island.Center + Vector3.new(0, 6, 0), 65)
	end
	-- A bridge up close
	local barn = World.ById.Barn
	local from, to = World.Bridge(barn)
	shot("bridge", (from + to) / 2 + Vector3.new(26, 12, 10), (from + to) / 2 + Vector3.new(0, 1, 0), 60)

	local tagGui = Instance.new("ScreenGui")
	tagGui.Name = "PhotoTag"
	tagGui.IgnoreGuiInset = true
	local tag = Instance.new("TextLabel")
	tag.Size = UDim2.fromOffset(260, 22)
	tag.Position = UDim2.new(1, -270, 1, -30)
	tag.BackgroundColor3 = Color3.new(0, 0, 0)
	tag.TextColor3 = Color3.new(1, 1, 1)
	tag.Font = Enum.Font.Code
	tag.TextSize = 16
	tag.Parent = tagGui
	tagGui.Parent = player.PlayerGui
	for index, s in shots do
		if s.Name == "@AllMachines" then
			remotes.ShopAction:FireServer("Promo", "AllMachines")
			task.wait(1.5)
			continue
		end
		tag.Text = s.Name
		hideUi()
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = s.Fov
		camera.CFrame = s.CFrame
		print(string.format("PHOTO %d %s %.1f", index, s.Name, os.clock()))
		table.insert(steps, string.format("PASS shot %d %s", index, s.Name))
		local started = os.clock()
		while os.clock() - started < HOLD do
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = s.CFrame
			task.wait()
		end
	end
end

local ok, err = pcall(run)
if not ok then
	table.insert(steps, "FAIL photo tour crashed: " .. tostring(err))
end
ReplicatedStorage:WaitForChild("E2EReport"):FireServer({ Steps = steps, Errors = clientErrors })
