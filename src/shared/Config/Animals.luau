--!strict
-- Every animal you can mail. Numbers are first-pass guesses; tune them in playtests.
--   Tier       : unlock group AND boxing difficulty (1 Backyard ... 6 Silly), see Boxing.luau
--   Price      : coins to buy at the Animal Pen
--   BaseValue  : coins paid for a perfect (4-stamp) boxing job
--   Carriers   : players needed to box it (co-op animals arrive in Phase 5)
--   Color      : placeholder color until the Blender model exists (set below)

export type Animal = {
	Id: string,
	DisplayName: string,
	Tier: number,
	Price: number,
	BaseValue: number,
	Carriers: number,
	Color: Color3?,
}

local List: { Animal } = {
	-- Tier 1: Backyard
	{
		Id = "Hamster",
		DisplayName = "Hamster",
		Tier = 1,
		Price = 0,
		BaseValue = 8,
		Carriers = 1,
	},
	{
		Id = "Bunny",
		DisplayName = "Bunny",
		Tier = 1,
		Price = 40,
		BaseValue = 12,
		Carriers = 1,
	},
	{
		Id = "Goldfish",
		DisplayName = "Goldfish",
		Tier = 1,
		Price = 120,
		BaseValue = 20,
		Carriers = 1,
	},
	{
		Id = "Hedgehog",
		DisplayName = "Hedgehog",
		Tier = 1,
		Price = 250,
		BaseValue = 30,
		Carriers = 1,
	},
	{
		Id = "Parrot",
		DisplayName = "Parrot",
		Tier = 1,
		Price = 400,
		BaseValue = 45,
		Carriers = 1,
	},

	-- Tier 2: Farm
	{
		Id = "Chicken",
		DisplayName = "Chicken",
		Tier = 2,
		Price = 800,
		BaseValue = 80,
		Carriers = 1,
	},
	{
		Id = "Goat",
		DisplayName = "Goat",
		Tier = 2,
		Price = 1500,
		BaseValue = 140,
		Carriers = 1,
	},
	{
		Id = "Pig",
		DisplayName = "Pig",
		Tier = 2,
		Price = 2500,
		BaseValue = 220,
		Carriers = 1,
	},
	{
		Id = "Skunk",
		DisplayName = "Skunk",
		Tier = 2,
		Price = 4000,
		BaseValue = 350,
		Carriers = 1,
	},

	-- Tier 3: Wild
	{
		Id = "Monkey",
		DisplayName = "Monkey",
		Tier = 3,
		Price = 7000,
		BaseValue = 600,
		Carriers = 1,
	},
	{
		Id = "Kangaroo",
		DisplayName = "Kangaroo",
		Tier = 3,
		Price = 11000,
		BaseValue = 900,
		Carriers = 1,
	},
	{
		Id = "Porcupine",
		DisplayName = "Porcupine",
		Tier = 3,
		Price = 16000,
		BaseValue = 1300,
		Carriers = 1,
	},
	{
		Id = "Penguin",
		DisplayName = "Penguin",
		Tier = 3,
		Price = 23000,
		BaseValue = 1800,
		Carriers = 1,
	},
	{
		Id = "Octopus",
		DisplayName = "Octopus",
		Tier = 3,
		Price = 32000,
		BaseValue = 2500,
		Carriers = 1,
	},

	-- Tier 4: Apex
	{
		Id = "Crocodile",
		DisplayName = "Crocodile",
		Tier = 4,
		Price = 50000,
		BaseValue = 3800,
		Carriers = 1,
	},
	{
		Id = "Gorilla",
		DisplayName = "Gorilla",
		Tier = 4,
		Price = 75000,
		BaseValue = 5500,
		Carriers = 1,
	},
	{
		Id = "Bear",
		DisplayName = "Bear",
		Tier = 4,
		Price = 110000,
		BaseValue = 8000,
		Carriers = 1,
	},
	{
		Id = "Tiger",
		DisplayName = "Tiger",
		Tier = 4,
		Price = 160000,
		BaseValue = 12000,
		Carriers = 1,
	},

	-- Tier 5: Giants (co-op)
	{
		Id = "Giraffe",
		DisplayName = "Giraffe",
		Tier = 5,
		Price = 250000,
		BaseValue = 20000,
		Carriers = 1,
	},
	{
		Id = "Elephant",
		DisplayName = "Elephant",
		Tier = 5,
		Price = 400000,
		BaseValue = 35000,
		Carriers = 2,
	},
	{
		Id = "Whale",
		DisplayName = "Whale",
		Tier = 5,
		Price = 700000,
		BaseValue = 65000,
		Carriers = 4,
	},

	-- Tier 6: Silly
	{
		Id = "Yeti",
		DisplayName = "Yeti",
		Tier = 6,
		Price = 500000,
		BaseValue = 100000,
		Carriers = 1,
	},
	{
		Id = "Dragon",
		DisplayName = "Dragon",
		Tier = 6,
		Price = 2000000,
		BaseValue = 170000,
		Carriers = 1,
	},
	{
		Id = "Alien",
		DisplayName = "Alien",
		Tier = 6,
		Price = 3200000,
		BaseValue = 260000,
		Carriers = 1,
	},
	{
		Id = "Unicorn",
		DisplayName = "Unicorn",
		Tier = 6,
		Price = 5000000,
		BaseValue = 400000,
		Carriers = 1,
	},
	{
		Id = "Gruff",
		DisplayName = "Postmaster Gruff",
		Tier = 6,
		Price = 10000000,
		BaseValue = 1000000,
		Carriers = 4,
	},
}

-- Placeholder colors (used for the loose-animal ball and the Pen menu until real models exist)
local Colors: { [string]: Color3 } = {
	Hamster = Color3.fromRGB(235, 160, 70),
	Bunny = Color3.fromRGB(240, 240, 240),
	Goldfish = Color3.fromRGB(255, 140, 30),
	Hedgehog = Color3.fromRGB(120, 90, 60),
	Parrot = Color3.fromRGB(60, 200, 80),
	Chicken = Color3.fromRGB(255, 250, 235),
	Goat = Color3.fromRGB(200, 190, 170),
	Pig = Color3.fromRGB(250, 170, 180),
	Skunk = Color3.fromRGB(30, 30, 35),
	Monkey = Color3.fromRGB(140, 95, 55),
	Kangaroo = Color3.fromRGB(190, 120, 70),
	Porcupine = Color3.fromRGB(90, 75, 60),
	Penguin = Color3.fromRGB(25, 25, 30),
	Octopus = Color3.fromRGB(200, 70, 150),
	Crocodile = Color3.fromRGB(70, 120, 60),
	Gorilla = Color3.fromRGB(50, 50, 55),
	Bear = Color3.fromRGB(110, 70, 40),
	Tiger = Color3.fromRGB(245, 140, 30),
	Giraffe = Color3.fromRGB(235, 190, 90),
	Elephant = Color3.fromRGB(150, 150, 160),
	Whale = Color3.fromRGB(60, 90, 160),
	Yeti = Color3.fromRGB(220, 235, 255),
	Dragon = Color3.fromRGB(200, 40, 40),
	Alien = Color3.fromRGB(120, 255, 120),
	Unicorn = Color3.fromRGB(255, 180, 240),
	Gruff = Color3.fromRGB(130, 110, 100),
}

local ById: { [string]: Animal } = {}
for _, animal in List do
	animal.Color = Colors[animal.Id]
	ById[animal.Id] = animal
end

return {
	List = List,
	ById = ById,
}
