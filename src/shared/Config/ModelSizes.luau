--!strict
-- How big each model is in the game, in studs, in ONE place (docs/ASSET_PLAN.md step 1). shared/ModelFit.Spawn
-- reads this first: a model listed here always comes out this size, whatever size the calling code asks for,
-- so the same thing is never drawn at two different scales.
--
-- Measured against the player: 3.1 studs tall (drawn at 60%). A door is about 6, a one-floor house 12-14, the
-- Post Office 26 with its clock tower (the tallest thing in the plaza). Height = the model's height; Width =
-- its bigger side seen from above (for flat things like benches and pads).
--
-- Plants and rocks aren't listed: the scenery code picks their sizes on purpose, in ranges, so a lawn isn't
-- full of identical trees.

export type Size = { Height: number?, Width: number? }

local sizes: { [string]: Size } = {
	-- Hero models (art/blender_scripts/hero_*.py)
	MA_Fountain = { Height = 14.5 },
	MA_PostOffice = { Height = 26 },

	-- The older Blender models (kept until each has a hero replacement)
	PostOffice = { Height = 21 },
	Cottage = { Height = 12 },
	Barn = { Height = 21 },

	-- KayKit townhouses: one width for all, so their floors match (2 to 3 floors: 11 to 20 tall)
	City_BuildingA = { Width = 13 },
	City_BuildingB = { Width = 13 },
	City_BuildingC = { Width = 13 },
	City_BuildingD = { Width = 13 },
	City_BuildingE = { Width = 13 },
	City_BuildingF = { Width = 13 },
	City_BuildingG = { Width = 13 },
	City_BuildingH = { Width = 13 },
}

return sizes
