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
	Gruff = require(script.Gruff),

	Dev = {
		-- In Roblox Studio every animal is free, so you can test any of them right away.
		-- Has no effect in the live game.
		FreeAnimalsInStudio = true,
	},
}
