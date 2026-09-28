--!strict
-- All game content lives in these config modules. To tweak a number, change it here, not in gameplay code.
-- Usage: local Config = require(ReplicatedStorage.Shared.Config)
--        Config.Animals.ById.Hamster.BaseValue

return {
	Animals = require(script.Animals),
	Boxes = require(script.Boxes),
	Stamps = require(script.Stamps),
	Routes = require(script.Routes),
	Carry = require(script.Carry),
	Gruff = require(script.Gruff),
}
