--!strict
-- How the world is lit. Applied when a server starts (server/Look.luau).
-- Set Apply = false to keep whatever you set up in Studio's Lighting instead.
--
-- For the nicest shadows on the low-poly models, also set Lighting -> Technology to "Future" (or
-- "ShadowMap") in Studio's Properties window. Scripts aren't allowed to change that one.

return {
	Apply = true,

	ClockTime = 14.2, -- early afternoon: warm light, shadows that aren't too long
	GeographicLatitude = 35,
	Brightness = 2.6,
	GlobalShadows = true,
	Ambient = Color3.fromRGB(95, 95, 110), -- light in shadowed/indoor spots
	OutdoorAmbient = Color3.fromRGB(140, 140, 155), -- light in outdoor shadows
	EnvironmentDiffuseScale = 0.6,
	EnvironmentSpecularScale = 0.25,

	-- Soft haze in the distance (makes the arenas feel far away and the sky feel big)
	Atmosphere = {
		Density = 0.28,
		Offset = 0.2,
		Color = Color3.fromRGB(199, 222, 255),
		Decay = Color3.fromRGB(106, 120, 140),
		Glare = 0.2,
		Haze = 1.4,
	},

	-- A touch more color
	Saturation = 0.12,
	Contrast = 0.06,
}
