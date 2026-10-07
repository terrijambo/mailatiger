--!strict
-- Every 2D image in the UI (buttons, HUD icons, item pictures). Until an image is available, the UI shows
-- the emoji instead, so nothing ever looks broken. The full list, with sizes and style notes, is in
-- docs/UI_IMAGES.md.
--
-- The finished icons (art/ui_icons) are packed into sprite sheets by tools/pack_icons.py; paste the sheets'
-- ids into IconSheets.luau and every icon lights up. Image below is only for a one-off override.
--
-- HOW TO ADD A SINGLE ONE: Creator Dashboard -> Development Items -> Decals -> upload your PNG. Open it, copy the
-- number from the page address (or right-click the decal in Studio's Toolbox -> Copy Asset ID), and paste
-- it below as Image = "rbxassetid://THE_NUMBER".

export type Icon = { Image: string, Emoji: string }

local function icon(emoji: string): Icon
	return { Image = "", Emoji = emoji }
end

local icons: { [string]: Icon } = {
	-- Side buttons
	Button_Pen = icon("🐹"),
	Button_Shop = icon("🛒"),
	Button_Orders = icon("📜"),
	Button_Inventory = icon("🎒"),
	Button_Store = icon("🛍️"),
	Button_Upgrades = icon("💎"),
	Button_Settings = icon("⚙️"),
	Button_Invite = icon("👋"),
	Button_Travel = icon("🗺️"),
	Button_Menu = icon("📬"), -- (Roblox can't draw "☰"; a mailbox fits the game anyway)

	-- HUD
	Hud_Coins = icon("💰"),
	Hud_Bag = icon("📦"),
	Hud_Boost = icon("⚡"),
	Hud_Level = icon("⭐"),
	Hud_Quest = icon("❗"),
	Hud_Lock = icon("🔒"),
	Hud_Diamonds = icon("💎"),
	Hud_ServerBoost = icon("🚀"),

	-- Mail boxes
	Box_Cardboard = icon("📦"),
	Box_Wood = icon("🪵"),
	Box_Steel = icon("🔩"),
	Box_Vault = icon("🏦"),

	-- Stamps
	Stamp_Fragile = icon("🥚"),
	Stamp_Express = icon("⚡"),
	Stamp_Priority = icon("🔥"),

	-- Tools
	Tool_Gloves = icon("🧤"),
	Tool_Sneakers = icon("👟"),
	Tool_TapeGun = icon("🔫"),
	Tool_Net = icon("🥅"),
	Tool_MailBag = icon("👜"),

	-- Chutes
	Chute_Basic = icon("📮"),
	Chute_Express = icon("🚚"),
	Chute_Pneumatic = icon("🌀"),
	Chute_Rocket = icon("🚀"),

	-- Troll items
	Troll_BananaPeel = icon("🍌"),
	Troll_StinkBomb = icon("💨"),
	Troll_GluePuddle = icon("🧴"),
	Troll_TapeBomb = icon("💣"),
	Troll_AirHorn = icon("📯"),

	-- Store (Robux)
	Store_ServerBoost = icon("🚀"),
	Store_DiamondsSmall = icon("💎"),
	Store_DiamondsMedium = icon("💠"),
	Store_DiamondsLarge = icon("👑"),
	Store_BigBag = icon("🎒"),
	Store_VIP = icon("👑"),
	Store_CoinsSmall = icon("🪙"),
	Store_CoinsMedium = icon("💰"),
	Store_CoinsLarge = icon("🏦"),
	Store_UnlockNext = icon("🔓"),
	Store_PriorityStamps = icon("🔥"),
	Store_GruffCoffee = icon("☕"),

	-- Diamond upgrades
	Upgrade_GoldenPaws = icon("🐾"),
	Upgrade_QuickStudy = icon("📚"),
	Upgrade_DeepPockets = icon("👖"),
	Upgrade_CalmHands = icon("🫳"),
	Upgrade_PayRaise = icon("💵"),
	Upgrade_BusyDesk = icon("📋"),
	Upgrade_RebirthKit = icon("🧰"),

	-- Zones
	Zone_Backyard = icon("🏡"),
	Zone_Barn = icon("🐔"),
	Zone_Jungle = icon("🌴"),
	Zone_IceRink = icon("❄️"),
	Zone_Rooftop = icon("🏙️"),

	-- Animals (Pen cards, orders, quests, inventory collection)
	Animal_Hamster = icon("🐹"),
	Animal_Bunny = icon("🐰"),
	Animal_Goldfish = icon("🐟"),
	Animal_Hedgehog = icon("🦔"),
	Animal_Parrot = icon("🦜"),
	Animal_Chicken = icon("🐔"),
	Animal_Goat = icon("🐐"),
	Animal_Pig = icon("🐷"),
	Animal_Skunk = icon("🦨"),
	Animal_Monkey = icon("🐒"),
	Animal_Kangaroo = icon("🦘"),
	Animal_Porcupine = icon("🦔"),
	Animal_Penguin = icon("🐧"),
	Animal_Octopus = icon("🐙"),
	Animal_Crocodile = icon("🐊"),
	Animal_Gorilla = icon("🦍"),
	Animal_Bear = icon("🐻"),
	Animal_Tiger = icon("🐯"),
	Animal_Giraffe = icon("🦒"),
	Animal_Elephant = icon("🐘"),
	Animal_Whale = icon("🐳"),
	Animal_Yeti = icon("🥶"),
	Animal_Dragon = icon("🐉"),
	Animal_Alien = icon("👽"),
	Animal_Unicorn = icon("🦄"),
	Animal_Gruff = icon("🦭"),

	-- Gruff's face (tutorial panel, popups)
	Gruff_Portrait = icon("🦭"),
}

return icons
