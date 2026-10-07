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
	Badges = require(script.Badges),
	Levels = require(script.Levels),
	Quests = require(script.Quests),
	Trolls = require(script.Trolls),
	Icons = require(script.Icons),
	IconAtlas = require(script.IconAtlas),
	IconSheets = require(script.IconSheets),
	Diamonds = require(script.Diamonds),
	Variants = require(script.Variants),
	Challenges = require(script.Challenges),
	Events = require(script.Events),
	World = require(script.World),
	Wild = require(script.Wild),
	Machines = require(script.Machines),
	Rarity = require(script.Rarity),
	Eggs = require(script.Eggs),
	Dive = require(script.Dive),

	Dev = {
		-- In Roblox Studio every animal is free, so you can test any of them right away.
		-- Has no effect in the live game.
		FreeAnimalsInStudio = true,
		-- Coins you start with in Studio when progress isn't being saved, for testing shops and upgrades.
		-- Never touches real saves or the live game. Set to 0 to turn off.
		StudioTestCoins = 2000000,
	},
}
