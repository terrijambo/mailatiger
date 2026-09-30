--!strict
-- How the world is lit. Applied when a server starts (server/Look.luau).
-- Set Apply = false to keep whatever you set up in Studio's Lighting instead.
--
-- For the nicest shadows on the low-poly models, also set Lighting -> Technology to "Future" (or
-- "ShadowMap") in Studio's Properties window. Scripts aren't allowed to change that one.

return {
	Apply = true,

	ClockTime = 13.2, -- early afternoon: bright light, short shadows
	GeographicLatitude = 35,
	Brightness = 3,
	GlobalShadows = true,
	Ambient = Color3.fromRGB(135, 135, 150), -- light in shadowed/indoor spots (bright, cartoony shadows)
	OutdoorAmbient = Color3.fromRGB(175, 175, 190), -- light in outdoor shadows
	EnvironmentDiffuseScale = 1,
	EnvironmentSpecularScale = 0.4,

	-- A light haze in the distance (just enough to make the mountains feel far away)
	Atmosphere = {
		Density = 0.14,
		Offset = 0.1,
		Color = Color3.fromRGB(199, 222, 255),
		Decay = Color3.fromRGB(106, 120, 140),
		Glare = 0,
		Haze = 0.4,
	},

	-- Vivid color (the bright, saturated look of popular simulators)
	Saturation = 0.22,
	Contrast = 0.08,
}
