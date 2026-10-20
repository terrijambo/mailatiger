--!strict
-- Lights the world from Config.Look when the server starts: sun, shadows, ambient light, distance haze and
-- a little extra color. Turn it off with Config.Look.Apply = false.
-- Then runs the day/night cycle (Config.Look.DayNight): the clock moves, and the light blends to the night
-- look at dusk and back at dawn. Lights tagged "NightLight" (street lamps, the fountain) brighten at night.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

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
	color.Brightness = look.Exposure
	color.Parent = Lighting

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = look.Bloom.Intensity
	bloom.Size = look.Bloom.Size
	bloom.Threshold = look.Bloom.Threshold
	bloom.Parent = Lighting

	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect") or Instance.new("SunRaysEffect")
	rays.Intensity = look.SunRays.Intensity
	rays.Spread = look.SunRays.Spread
	rays.Parent = Lighting

	if look.DayNight.Enabled then
		task.spawn(Look.RunCycle, atmosphere, color)
	end
end

-- The Promo Kit can hold the clock at a time (sunset shots); nil lets it run again
local frozenClock: number? = nil
function Look.SetClock(clockTime: number?)
	frozenClock = clockTime
end

-- Where the shared day is right now (0..24)
local function clockNow(): number
	local cycle = Config.Look.DayNight
	local day, night = cycle.DayMinutes * 60, cycle.NightMinutes * 60
	local t = Workspace:GetServerTimeNow() % (day + night)
	if t < day then
		return 6 + 12 * t / day
	end
	return (18 + 12 * (t - day) / night) % 24
end

-- 0 in the day, 1 in the middle of the night, blending at dusk (17-19) and dawn (5-7)
local function nightness(clockTime: number): number
	if clockTime >= 7 and clockTime <= 17 then
		return 0
	elseif clockTime > 17 and clockTime < 19 then
		return (clockTime - 17) / 2
	elseif clockTime > 5 and clockTime < 7 then
		return 1 - (clockTime - 5) / 2
	end
	return 1
end

function Look.RunCycle(atmosphere: Atmosphere, color: ColorCorrectionEffect)
	local look = Config.Look
	local night = look.DayNight.Night
	while true do
		local clockTime = frozenClock or clockNow()
		local n = nightness(clockTime)
		Lighting.ClockTime = clockTime
		Lighting.Brightness = look.Brightness + (night.Brightness - look.Brightness) * n
		Lighting.Ambient = look.Ambient:Lerp(night.Ambient, n)
		Lighting.OutdoorAmbient = look.OutdoorAmbient:Lerp(night.OutdoorAmbient, n)
		atmosphere.Color = look.Atmosphere.Color:Lerp(night.AtmosphereColor, n)
		atmosphere.Decay = look.Atmosphere.Decay:Lerp(night.AtmosphereDecay, n)
		color.Saturation = look.Saturation + (night.Saturation - look.Saturation) * n
		color.Brightness = look.Exposure + (night.Exposure - look.Exposure) * n
		Workspace:SetAttribute("Night", n) -- (anything else that wants to know how dark it is)
		for _, light in CollectionService:GetTagged("NightLight") do
			if light:IsA("Light") then
				local dayBrightness = light:GetAttribute("DayBrightness")
				local nightBrightness = light:GetAttribute("NightBrightness")
				if typeof(dayBrightness) == "number" and typeof(nightBrightness) == "number" then
					light.Brightness = dayBrightness + (nightBrightness - dayBrightness) * n
				end
			end
		end
		task.wait(0.5)
	end
end

return Look
