--!strict
-- Every sound in the game. Roblox only plays audio uploaded to Roblox, so each Id has to be a real asset id
-- like "rbxassetid://1234567890". Set an Id to "" to silence that sound; nothing breaks.
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

-- STARTER SOUNDS: everything below comes from Roblox's own audio library (uploaded by the official
-- "Roblox" account), so any game may use it. They're placeholders picked by name, not by ear. Swap any
-- of them for something better, especially the vine boom (a cannon for now).
local sounds: { [string]: Sound } = {
	-- The big clip moment: the animal launches you out of the box
	VineBoom = { Id = "rbxassetid://140367458608473", Volume = 2, Heard = "Everyone" }, -- the real vine boom

	-- BOX stage
	Pop = { Id = "rbxassetid://15675055424", Volume = 0.8 }, -- the animal pops up out of the box ("Cute Pop")
	Purr = { Id = "rbxassetid://79205036324023", Volume = 0.5, Cooldown = 1.5 }, -- rubbing a ♥ spot ("BirdHello", a happy chirp)
	AngryHit = { Id = "rbxassetid://12222046", Volume = 0.9, Cooldown = 0.4 }, -- touched an ✖ spot ("hit")
	Growl = { Id = "rbxassetid://16480557599", Volume = 0.9, Cooldown = 0.5 }, -- the animal thumps the box ("Joystick Slam")
	TapeRip = { Id = "rbxassetid://15675037413", Volume = 0.8 }, -- a strip of tape goes on ("Paper Swipe")
	TapePeel = { Id = "rbxassetid://12222106", Volume = 0.8 }, -- the animal peels a strip off ("Rubber band")
	StampThud = { Id = "rbxassetid://16480560696", Volume = 1 }, -- box finished and stamped ("Giant Button Press")

	-- CATCH stage and animal twists
	Escape = { Id = "rbxassetid://12222124", Volume = 0.8 }, -- the animal breaks out and runs off ("Short spring")
	Roar = { Id = "rbxassetid://9120031442", Volume = 1.2 }, -- tiger roar / breakout ("Lion Roar")
	Spray = { Id = "rbxassetid://17208402198", Volume = 0.8 }, -- skunk spray ("Spraypaint")
	Freeze = { Id = "rbxassetid://12222005", Volume = 0.8 }, -- frozen by the yeti ("glassbreak")
	Bonk = { Id = "rbxassetid://12222054", Volume = 0.8, Cooldown = 0.3 }, -- knocked back or shoved ("Kerplunk")

	-- Mail, coins and menus
	MailWhoosh = { Id = "rbxassetid://15674975792", Volume = 0.9 }, -- parcels fly down the chute ("Whoosh 03")
	CoinJingle = { Id = "rbxassetid://127645268874265", Volume = 0.8 }, -- getting paid ("CoinTransfer")
	Kaching = { Id = "rbxassetid://16480570986", Volume = 0.8 }, -- buying something ("Low Bells")
	Click = { Id = "rbxassetid://15675059323", Volume = 0.5, Cooldown = 0.05 }, -- opening a menu ("Bright Click")
	Ding = { Id = "rbxassetid://12221990", Volume = 0.7 }, -- tutorial step done ("electronic ping")

	-- Progression, Robux and troll items. NEW SLOTS: these borrow another sound (at a different pitch) until
	-- you pick real ones (docs/SOUNDS_TO_REPLACE.md)
	LevelUp = { Id = "rbxassetid://12221990", Volume = 1, Pitch = 0.8 }, -- LEVEL UP popup (borrows Ding)
	QuestDone = { Id = "rbxassetid://127645268874265", Volume = 0.9, Pitch = 1.15 }, -- quest finished (borrows CoinJingle)
	Diamond = { Id = "rbxassetid://12221990", Volume = 0.7, Pitch = 1.6 }, -- got diamonds (borrows Ding)
	EggTick = { Id = "rbxassetid://15675059323", Volume = 0.35, Pitch = 1.4, Cooldown = 0.03 }, -- each card passing on the egg roller (borrows Click)
	EggWin = { Id = "rbxassetid://16480570986", Volume = 0.9, Pitch = 1.2 }, -- the egg roller lands (borrows Kaching)
	ServerBoost = { Id = "rbxassetid://16480570986", Volume = 1, Pitch = 1.3 }, -- 2x coins server boost (borrows Kaching)
	Troll_BananaPeel = { Id = "rbxassetid://12222054", Volume = 1, Pitch = 1.3, Heard = "Everyone" }, -- (borrows Bonk)
	Troll_StinkBomb = { Id = "rbxassetid://17208402198", Volume = 1, Pitch = 0.7, Heard = "Everyone" }, -- (borrows Spray)
	Troll_GluePuddle = { Id = "rbxassetid://12222106", Volume = 1, Pitch = 0.6, Heard = "Everyone" }, -- (borrows TapePeel)
	Troll_TapeBomb = { Id = "rbxassetid://3149249837", Volume = 1, Pitch = 1.3, Heard = "Everyone" }, -- (borrows VineBoom)
	Troll_AirHorn = { Id = "rbxassetid://9120031442", Volume = 1.2, Pitch = 1.8, Heard = "Everyone" }, -- (borrows Roar)

	-- Hourly boss fights. NEW SLOTS that borrow other sounds for now (docs/BOSS_VISUALS_ROADMAP.md, Phase 6)
	BossMusic = { Id = "rbxassetid://17422163655", Volume = 0.35, Pitch = 0.9 }, -- the fight theme (loops; borrows MusicArena)
	BossStomp = { Id = "rbxassetid://9125404769", Volume = 1.6, Heard = "Everyone" }, -- "Boomy Footsteps Giant Thumpy Dinosaur" (Pro Sound Effects, free for every Roblox game)
	CrowdCheer = { Id = "rbxassetid://127645268874265", Volume = 0.8, Pitch = 0.8 }, -- the stands go wild (borrows CoinJingle)

	-- Background music (loops)
	MusicTown = { Id = "rbxassetid://15930255433", Volume = 0.25 }, -- walking around town ("Retro Flute Music")
	MusicArena = { Id = "rbxassetid://17422163655", Volume = 0.25 }, -- chasing an animal ("Cloud Blitz")
	MusicBox = { Id = "rbxassetid://16480577096", Volume = 0.3 }, -- the BOX stage ("8-bit Tone Loop")
}

return sounds
