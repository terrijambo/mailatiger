-- Boxes you can put an animal in.
--   MaxHP      : damage the box can take before it breaks
--   Weight     : added to the animal's weight (tougher = heavier = slower)
--   RageDamp   : multiplies rage gain (lower = calmer animal)

export type Box = {
	Id: string,
	DisplayName: string,
	Price: number,
	MaxHP: number,
	Weight: number,
	RageDamp: number,
}

local List: { Box } = {
	{ Id = "Cardboard", DisplayName = "Cardboard Box", Price = 0, MaxHP = 100, Weight = 0.5, RageDamp = 1 },
	{ Id = "Wood", DisplayName = "Wooden Crate", Price = 1000, MaxHP = 250, Weight = 1, RageDamp = 0.95 },
	{ Id = "Steel", DisplayName = "Steel Crate", Price = 25000, MaxHP = 700, Weight = 2, RageDamp = 0.9 },
	{ Id = "Vault", DisplayName = "Bank Vault", Price = 400000, MaxHP = 2000, Weight = 3.5, RageDamp = 0.8 },
}

local ById: { [string]: Box } = {}
for _, box in List do
	ById[box.Id] = box
end

return {
	List = List,
	ById = ById,
}
