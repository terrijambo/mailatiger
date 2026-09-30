--!strict
-- All game content lives in these config modules. To tweak a number, change it here, not in gameplay code.
-- Usage: local Config = require(ReplicatedStorage.Shared.Config)
--        Config.Animals.ById.Hamster.BaseValue

return {
	Animals = require(script.Animals),
	Arenas = require(script.Arenas),
	Boxing = require(script.Boxing),
	Boxes = require(script.Boxes),
	Stamps = require(script.Stamps),
	Tools = require(script.Tools),
	Progression = require(script.Progression),
	Sounds = require(script.Sounds),
	Social = require(script.Social),
	Mail = require(script.Mail),
	Gruff = require(script.Gruff),
	Monetization = require(script.Monetization),
	Look = require(script.Look),
	Codes = require(script.Codes),

	Dev = {
		-- In Roblox Studio every animal is free, so you can test any of them right away.
		-- Has no effect in the live game.
		FreeAnimalsInStudio = true,
		-- Coins you start with in Studio when progress isn't being saved, for testing shops and upgrades.
		-- Never touches real saves or the live game. Set to 0 to turn off.
		StudioTestCoins = 2000000,
	},
}
