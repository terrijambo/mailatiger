--!strict
-- Tools you upgrade at the Supply Shop. Each level costs more than the last.
--   MaxLevel     : highest level
--   BasePrice    : cost of level 1
--   PriceGrowth  : each level costs this many times the previous one
--   PerLevel     : how much each level helps (meaning depends on the tool, see Description)

export type Tool = {
	Id: string,
	DisplayName: string,
	Description: string,
	MaxLevel: number,
	BasePrice: number,
	PriceGrowth: number,
	PerLevel: number,
}

local List: { Tool } = {
	{
		Id = "Gloves",
		DisplayName = "Grabbing Gloves",
		Description = "Grab animals faster: -10% hold time per level.",
		MaxLevel = 5,
		BasePrice = 200,
		PriceGrowth = 3,
		PerLevel = 0.1,
	},
	{
		Id = "Sneakers",
		DisplayName = "Sneakers",
		Description = "Run faster: +1 speed per level.",
		MaxLevel = 5,
		BasePrice = 300,
		PriceGrowth = 3,
		PerLevel = 1,
	},
	{
		Id = "TapeGun",
		DisplayName = "Tape Gun",
		Description = "Smoother taping: each strip annoys the animal 10% less per level.",
		MaxLevel = 5,
		BasePrice = 400,
		PriceGrowth = 3,
		PerLevel = 0.1,
	},
	{
		Id = "Net",
		DisplayName = "Butterfly Net",
		Description = "Grab from farther away: +1 stud per level.",
		MaxLevel = 3,
		BasePrice = 1000,
		PriceGrowth = 4,
		PerLevel = 1,
	},
}

local ById: { [string]: Tool } = {}
for _, tool in List do
	ById[tool.Id] = tool
end

-- The price of the NEXT level when the tool is currently at `currentLevel`.
local function PriceFor(tool: Tool, currentLevel: number): number
	return math.round(tool.BasePrice * tool.PriceGrowth ^ currentLevel)
end

return {
	List = List,
	ById = ById,
	PriceFor = PriceFor,
}
