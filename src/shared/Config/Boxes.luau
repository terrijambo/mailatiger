--!strict
-- Boxes you buy at the Supply Shop and equip. A better box makes the BOX stage easier.
--   Price     : coins (bought once, then you own it)
--   StartAnger : how angry the animal starts when boxing begins (100 = you get launched)
--   AngerMult  : multiplies how fast it gets angry (a sturdier box feels safer to be in)

export type Box = {
	Id: string,
	DisplayName: string,
	Price: number,
	StartAnger: number,
	AngerMult: number,
	Color: Color3,
}

local List: { Box } = {
	{
		Id = "Cardboard",
		DisplayName = "Cardboard Box",
		Price = 0,
		StartAnger = 20,
		AngerMult = 1,
		Color = Color3.fromRGB(198, 156, 109),
	},
	{
		Id = "Wood",
		DisplayName = "Wooden Crate",
		Price = 1500,
		StartAnger = 15,
		AngerMult = 0.9,
		Color = Color3.fromRGB(150, 100, 60),
	},
	{
		Id = "Steel",
		DisplayName = "Steel Crate",
		Price = 40000,
		StartAnger = 10,
		AngerMult = 0.8,
		Color = Color3.fromRGB(150, 155, 165),
	},
	{
		Id = "Vault",
		DisplayName = "Bank Vault",
		Price = 600000,
		StartAnger = 5,
		AngerMult = 0.7,
		Color = Color3.fromRGB(80, 85, 100),
	},
}

local ById: { [string]: Box } = {}
for _, box in List do
	ById[box.Id] = box
end

return {
	List = List,
	ById = ById,
}
