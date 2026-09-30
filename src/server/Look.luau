--!strict
-- Lights the world from Config.Look when the server starts: sun, shadows, ambient light, distance haze and
-- a little extra color. Turn it off with Config.Look.Apply = false.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Look = {}

function Look.Apply()
	local look = Config.Look
	if not look.Apply then
		return
	end
	Lighting.ClockTime = look.ClockTime
	Lighting.GeographicLatitude = look.GeographicLatitude
	Lighting.Brightness = look.Brightness
	Lighting.GlobalShadows = look.GlobalShadows
	Lighting.Ambient = look.Ambient
	Lighting.OutdoorAmbient = look.OutdoorAmbient
	Lighting.EnvironmentDiffuseScale = look.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = look.EnvironmentSpecularScale

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	for key, value in look.Atmosphere do
		(atmosphere :: any)[key] = value
	end
	atmosphere.Parent = Lighting

	local existing = Lighting:FindFirstChild("MailATigerColor")
	local color: ColorCorrectionEffect = if existing and existing:IsA("ColorCorrectionEffect")
		then existing
		else Instance.new("ColorCorrectionEffect")
	color.Name = "MailATigerColor"
	color.Saturation = look.Saturation
	color.Contrast = look.Contrast
	color.Parent = Lighting
end

return Look
