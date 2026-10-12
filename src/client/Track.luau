--!strict
-- Analytics from this player's screen: which windows they open, the tutorial step they're on, purchase
-- prompts, their device and how smoothly the game runs. It only sends; the server (server/Analytics.luau)
-- checks every value and decides what reaches Roblox's dashboard.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local Track = {}

local PERF_EVERY = 120 -- seconds between performance samples
local PERF_SAMPLE = 10 -- seconds each sample measures

function Track.Send(name: string, a: any?, b: any?)
	task.spawn(function()
		local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Track") :: RemoteEvent
		remote:FireServer(name, a, b)
	end)
end

local function inputKind(): string
	local last = UserInputService:GetLastInputType()
	if string.sub(last.Name, 1, 7) == "Gamepad" then
		return "Gamepad"
	elseif
		last == Enum.UserInputType.Touch or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
	then
		return "Touch"
	end
	return "KeyboardMouse"
end

local function screenKind(): string
	local camera = Workspace.CurrentCamera
	if not camera then
		return "Unknown"
	end
	local size = camera.ViewportSize
	local short = math.min(size.X, size.Y)
	return if short < 500 then "Small" elseif short < 800 then "Medium" else "Large"
end

function Track.Start()
	-- The device: sent once, then again if they switch (e.g. pick up a controller), at most every 30 seconds
	local current = inputKind()
	local sentAt = os.clock()
	Track.Send("Device", current, screenKind())
	UserInputService.LastInputTypeChanged:Connect(function()
		local kind = inputKind()
		if kind ~= current and os.clock() - sentAt > 30 then
			current, sentAt = kind, os.clock()
			Track.Send("Device", kind, screenKind())
		end
	end)

	-- Performance: frames per second over a short sample, and the network ping, every couple of minutes
	task.spawn(function()
		while true do
			task.wait(PERF_EVERY)
			local frames = 0
			local start = os.clock()
			local counting = RunService.RenderStepped:Connect(function()
				frames += 1
			end)
			task.wait(PERF_SAMPLE)
			counting:Disconnect()
			local fps = frames / math.max(0.1, os.clock() - start)
			local ok, ping = pcall(function()
				return player:GetNetworkPing() * 1000
			end)
			Track.Send("Perf", fps, if ok and typeof(ping) == "number" then ping else 0)
		end
	end)
end

return Track
