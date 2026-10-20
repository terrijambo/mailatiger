--!strict
-- How the world is lit. Applied when a server starts (server/Look.luau).
-- Set Apply = false to keep whatever you set up in Studio's Lighting instead.
--
-- For the nicest shadows on the low-poly models, also set Lighting -> Technology to "Future" (or
-- "ShadowMap") in Studio's Properties window. Scripts aren't allowed to change that one.

return {
	Apply = true,

	ClockTime = 13.2, -- (only used when the day/night cycle is off)
	GeographicLatitude = 35,
	Brightness = 2.2, -- (was 3: a bit easier on the eyes)
	GlobalShadows = true,
	Ambient = Color3.fromRGB(115, 115, 130), -- light in shadowed/indoor spots (bright, cartoony shadows)
	OutdoorAmbient = Color3.fromRGB(145, 145, 160), -- light in outdoor shadows
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

	-- Vivid color (the bright, saturated look of popular simulators), toned down a little
	Saturation = 0.02,
	Contrast = 0.12,
	Exposure = -0.04, -- (ColorCorrection brightness: slightly darker overall)

	-- A soft glow on bright things (lamps, gold, the sea's sparkle) and light rays when you look toward the sun
	Bloom = { Intensity = 0.35, Size = 28, Threshold = 1.6 },
	SunRays = { Intensity = 0.04, Spread = 0.7 },

	-- Each area's own mood: a color grade laid over the world while you stand in it (client/ZoneLook.luau),
	-- blended over ZoneBlendSeconds when you cross a bridge. Tint is multiplied in (white = no change);
	-- Saturation, Contrast and Brightness are added to the world's own grade above.
	ZoneBlendSeconds = 1.5,
	Zones = {
		Town = { Tint = Color3.fromRGB(255, 252, 245), Saturation = 0.04, Contrast = 0, Brightness = 0 },
		Backyard = { Tint = Color3.fromRGB(250, 255, 240), Saturation = 0.08, Contrast = 0, Brightness = 0.01 },
		Beach = { Tint = Color3.fromRGB(255, 248, 230), Saturation = 0.1, Contrast = -0.02, Brightness = 0.03 },
		Barn = { Tint = Color3.fromRGB(255, 244, 222), Saturation = 0.05, Contrast = 0.02, Brightness = 0.01 },
		Jungle = { Tint = Color3.fromRGB(232, 255, 228), Saturation = 0.12, Contrast = 0.04, Brightness = -0.02 },
		IceRink = { Tint = Color3.fromRGB(228, 242, 255), Saturation = -0.06, Contrast = 0.02, Brightness = 0.03 },
		Rooftop = { Tint = Color3.fromRGB(240, 238, 255), Saturation = -0.02, Contrast = 0.06, Brightness = 0 },
		Boss = { Tint = Color3.fromRGB(255, 226, 210), Saturation = 0.06, Contrast = 0.08, Brightness = -0.03 },
		Sea = { Tint = Color3.fromRGB(245, 252, 255), Saturation = 0.04, Contrast = 0, Brightness = 0.01 },
	},

	-- Day and night: a full day is DayMinutes of daylight (6:00 to 18:00) and NightMinutes of night. Every
	-- server shares the same clock. Street lamps and the fountain glow brighter at night.
	DayNight = {
		Enabled = true,
		DayMinutes = 14,
		NightMinutes = 6,
		-- How things look in the middle of the night (blended in at dusk, out at dawn)
		Night = {
			Brightness = 0.9,
			Ambient = Color3.fromRGB(70, 75, 110),
			OutdoorAmbient = Color3.fromRGB(85, 95, 140),
			AtmosphereColor = Color3.fromRGB(70, 85, 130),
			AtmosphereDecay = Color3.fromRGB(40, 45, 70),
			Saturation = 0.05,
			Exposure = -0.02,
		},
	},
}
