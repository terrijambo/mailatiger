--!strict
-- Tools you upgrade at the Rebirth Market (Rebirth Beach), with Rebirth Points. Each level costs more than the last.
--   MaxLevel     : highest level
--   BasePrice    : cost of level 1
--   PriceGrowth  : each level costs this many times the previous one
--   PerLevel     : how much each level helps (meaning depends on the tool, see Description)
--   Effect       : what the Shop shows for your current level. {} becomes the total bonus
--   Percent      : true if the bonus is a fraction shown as a percent (0.15 per level -> "15%")

export type Tool = {
	Id: string,
	DisplayName: string,
	Description: string,
	MaxLevel: number,
	BasePrice: number,
	PriceGrowth: number,
	PerLevel: number,
	Effect: string,
	Percent: boolean?,
	RPPerLevel: number, -- Rebirth Points: the next level costs ceil((level + 1) x this)
}

local List: { Tool } = {
	{
		Id = "Gloves",
		DisplayName = "Grabbing Gloves",
		Description = "Grab animals faster: -15% hold time per level.",
		MaxLevel = 5,
		BasePrice = 200,
		PriceGrowth = 3,
		PerLevel = 0.15,
		RPPerLevel = 10,
		Effect = "grab {}% faster",
		Percent = true,
	},
	{
		Id = "Sneakers",
		DisplayName = "Sneakers",
		-- 15 levels: you start at 16 speed and end at 76 (nearly 5x). The last few levels are pricey.
		Description = "Run faster: +4 speed per level, 15 levels (you start at 16, max 76!).",
		MaxLevel = 15,
		BasePrice = 150,
		PriceGrowth = 1.9,
		PerLevel = 4,
		RPPerLevel = 5,
		Effect = "+{} speed",
	},
	{
		Id = "TapeGun",
		DisplayName = "Tape Gun",
		Description = "Smoother taping: each strip annoys the animal 15% less per level.",
		MaxLevel = 5,
		BasePrice = 400,
		PriceGrowth = 3,
		PerLevel = 0.15,
		RPPerLevel = 10,
		Effect = "tape annoys {}% less",
		Percent = true,
	},
	{
		Id = "Net",
		DisplayName = "Butterfly Net",
		Description = "Grab from farther away: +2 studs per level (you start at 6).",
		MaxLevel = 3,
		BasePrice = 1000,
		PriceGrowth = 4,
		PerLevel = 2,
		RPPerLevel = 15,
		Effect = "+{} studs of reach",
	},
	{
		Id = "MailBag",
		DisplayName = "Mail Bag",
		Description = "Carry more parcels: +2 per level (you start with room for 3).",
		MaxLevel = 5,
		BasePrice = 500,
		PriceGrowth = 3,
		PerLevel = 2,
		RPPerLevel = 10,
		Effect = "+{} bag slots",
	},
}

local ById: { [string]: Tool } = {}
for _, tool in List do
	ById[tool.Id] = tool
end

-- The price of the NEXT level when the tool is currently at `currentLevel`.
-- Tools are bought with Rebirth Points (from rebirthing, Config/Machines.luau) and kept forever
local function PointsFor(tool: Tool, currentLevel: number): number
	return math.ceil((currentLevel + 1) * tool.RPPerLevel)
end

local function PriceFor(tool: Tool, currentLevel: number): number
	return math.round(tool.BasePrice * tool.PriceGrowth ^ currentLevel)
end

-- What a tool does at a level, for the Shop: e.g. "+4 speed" or "grab 30% faster"
local function EffectText(tool: Tool, level: number): string
	local bonus = tool.PerLevel * level
	local shown = if tool.Percent then math.round(bonus * 100) else bonus
	return (string.gsub(tool.Effect, "{}", tostring(shown)))
end

return {
	EffectText = EffectText,
	List = List,
	ById = ById,
	PriceFor = PriceFor,
	PointsFor = PointsFor,
}
