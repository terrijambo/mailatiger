--!strict
-- Boxes you buy at the Supply Shop and equip. A better box makes the TAPE stage easier.
--   Price     : coins (bought once, then you own it)
--   StartLid  : where the lid starts when taping begins (0 = shut, 100 = bursts open)
--   PushMult  : multiplies how hard the animal pushes the lid up

export type Box = {
	Id: string,
	DisplayName: string,
	Price: number,
	StartLid: number,
	PushMult: number,
	Color: Color3,
}

local List: { Box } = {
	{
		Id = "Cardboard",
		DisplayName = "Cardboard Box",
		Price = 0,
		StartLid = 20,
		PushMult = 1,
		Color = Color3.fromRGB(198, 156, 109),
	},
	{
		Id = "Wood",
		DisplayName = "Wooden Crate",
		Price = 1500,
		StartLid = 15,
		PushMult = 0.9,
		Color = Color3.fromRGB(150, 100, 60),
	},
	{
		Id = "Steel",
		DisplayName = "Steel Crate",
		Price = 40000,
		StartLid = 10,
		PushMult = 0.8,
		Color = Color3.fromRGB(150, 155, 165),
	},
	{
		Id = "Vault",
		DisplayName = "Bank Vault",
		Price = 600000,
		StartLid = 5,
		PushMult = 0.7,
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
