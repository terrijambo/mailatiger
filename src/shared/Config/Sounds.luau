--!strict
-- Every sound in the game. Roblox only plays audio uploaded to Roblox, so each Id has to be a real asset id
-- like "rbxassetid://1234567890". While an Id is "" that sound is simply silent, and nothing breaks.
--
-- HOW TO FILL ONE IN: in Studio open the Toolbox -> Marketplace -> Audio, search for the sound (e.g.
-- "vine boom"), pick one you're allowed to use, right-click it -> Copy Asset ID, and paste it below.
-- (Or upload your own sound in the Creator Dashboard.)
--
--   Volume    0..10 (1 is normal)
--   Pitch     1 is normal, 1.2 is higher and faster. Leave it out for 1.
--   Cooldown  seconds before it can play again (stops rapid sounds like purring from stacking up)
--   Heard     just a note: "Everyone" sounds are played by the server in the world, so everyone nearby hears
--             them. All the others play only for the player they happen to.

export type Sound = {
	Id: string,
	Volume: number,
	Pitch: number?,
	Cooldown: number?,
	Heard: string?,
}

local sounds: { [string]: Sound } = {
	-- The big clip moment: the animal launches you out of the box
	VineBoom = { Id = "", Volume = 2, Heard = "Everyone" },

	-- BOX stage
	Pop = { Id = "", Volume = 0.8 }, -- the animal pops up out of the box
	Purr = { Id = "", Volume = 0.6, Cooldown = 0.8 }, -- rubbing a ♥ spot (purr, chirp or coo)
	AngryHit = { Id = "", Volume = 0.9, Cooldown = 0.4 }, -- touched an ✖ spot ("OW!")
	Growl = { Id = "", Volume = 0.9, Cooldown = 0.5 }, -- the animal thumps the box / gets angry
	TapeRip = { Id = "", Volume = 0.8 }, -- a strip of tape goes on (that screechy tape sound)
	TapePeel = { Id = "", Volume = 0.8 }, -- the animal peels a strip off
	StampThud = { Id = "", Volume = 1 }, -- box finished and stamped: a parcel goes in your bag

	-- CATCH stage and animal twists
	Escape = { Id = "", Volume = 0.8 }, -- the animal breaks out and runs off
	Roar = { Id = "", Volume = 1.2 }, -- tiger roar / breakout
	Spray = { Id = "", Volume = 0.8 }, -- skunk spray
	Freeze = { Id = "", Volume = 0.8 }, -- frozen by the yeti
	Bonk = { Id = "", Volume = 0.8, Cooldown = 0.3 }, -- knocked back or shoved

	-- Mail, coins and menus
	MailWhoosh = { Id = "", Volume = 0.9 }, -- parcels fly down the chute
	CoinJingle = { Id = "", Volume = 0.8 }, -- getting paid
	Kaching = { Id = "", Volume = 0.8 }, -- buying something
	Click = { Id = "", Volume = 0.5, Cooldown = 0.05 }, -- opening a menu
	Ding = { Id = "", Volume = 0.7 }, -- tutorial step done
}

return sounds
