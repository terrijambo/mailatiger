--!strict
-- Each area's own mood: while you stand on an island, its color grade (Config.Look.Zones) is laid over the
-- world, and it blends to the next one when you cross a bridge. Only on your own screen: the light itself
-- (sun, day/night) is shared and set by the server (server/Look.luau).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local ZoneLook = {}

function ZoneLook.Start()
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "ZoneLook"
	grade.Parent = Lighting

	local current: string? = nil
	task.spawn(function()
		while true do
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local zone = Config.World.ZoneAt(root.Position)
				local look = Config.Look.Zones[zone]
				if zone ~= current and look then
					current = zone
					local blend = TweenInfo.new(Config.Look.ZoneBlendSeconds, Enum.EasingStyle.Sine)
					TweenService:Create(grade, blend, {
						TintColor = look.Tint,
						Saturation = look.Saturation,
						Contrast = look.Contrast,
						Brightness = look.Brightness,
					}):Play()
				end
			end
			task.wait(0.5)
		end
	end)
end

return ZoneLook
