-- E2E test, server side (injected into ServerScriptService by driver.lua). Collects errors and waits for
-- the client's report, then ends the Play session and hands everything back to the driver.
local LogService = game:GetService("LogService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StudioTestService = game:GetService("StudioTestService")

local errors = {}
LogService.MessageOut:Connect(function(message, kind)
	if kind == Enum.MessageType.MessageError or kind == Enum.MessageType.MessageWarning then
		if #errors < 40 then
			table.insert(errors, (if kind == Enum.MessageType.MessageError then "ERROR " else "WARN ") .. message)
		end
	end
end)

local report = Instance.new("RemoteEvent")
report.Name = "E2EReport"
report.Parent = ReplicatedStorage

local result = nil
report.OnServerEvent:Connect(function(_player, clientResult)
	result = clientResult
end)

local started = os.clock()
while not result and os.clock() - started < 150 do
	task.wait(0.5)
end
StudioTestService:EndTest({ Server = errors, Client = result or { Steps = { "client never reported (timed out)" } } })
