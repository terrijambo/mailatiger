--!strict
-- Animal rarities. Every animal has one (Config/Wild.luau works them out): within each island its animals go
-- from Common (the easy, everyday ones) up to Legendary (its rarest), and later islands start higher, so the
-- Rooftop's rarest reach Ethereal. Secret is Postmaster Gruff himself.
-- Weight: how likely an egg is to hatch an animal of this rarity, compared with the others (Config/Eggs.luau).

export type Rarity = {
	Id: string,
	DisplayName: string,
	Color: Color3,
	Weight: number,
}

local List: { Rarity } = {
	{ Id = "Common", DisplayName = "Common", Color = Color3.fromRGB(205, 205, 210), Weight = 40 },
	{ Id = "Uncommon", DisplayName = "Uncommon", Color = Color3.fromRGB(110, 210, 90), Weight = 26 },
	{ Id = "Rare", DisplayName = "Rare", Color = Color3.fromRGB(70, 150, 255), Weight = 16 },
	{ Id = "Epic", DisplayName = "Epic", Color = Color3.fromRGB(175, 95, 255), Weight = 9 },
	{ Id = "Legendary", DisplayName = "Legendary", Color = Color3.fromRGB(255, 190, 40), Weight = 5 },
	{ Id = "Mythic", DisplayName = "Mythic", Color = Color3.fromRGB(255, 70, 100), Weight = 2.5 },
	{ Id = "Ethereal", DisplayName = "Ethereal", Color = Color3.fromRGB(110, 255, 235), Weight = 1.2 },
	{ Id = "Secret", DisplayName = "Secret", Color = Color3.fromRGB(40, 36, 52), Weight = 0.3 },
}

local ById: { [string]: Rarity } = {}
local Index: { [string]: number } = {}
for index, rarity in List do
	ById[rarity.Id] = rarity
	Index[rarity.Id] = index
end

return {
	List = List,
	ById = ById,
	Index = Index, -- 1 = Common ... 8 = Secret
}
