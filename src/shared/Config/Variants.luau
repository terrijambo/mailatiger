--!strict
-- Shiny and Golden animals: every job has a small chance that your animal is a special one. It looks
-- different (sparkles, or solid gold), pays more, gives more XP, and everyone in the server hears about it.
-- Earned only, never sold.
--
--   Chance   odds per job (Golden is rolled first)
--   PayMult  coins x this
--   XPMult   XP x this when you mail it

export type Variant = {
	Id: string,
	DisplayName: string,
	Emoji: string,
	Chance: number,
	PayMult: number,
	XPMult: number,
	Color: Color3,
}

local list: { Variant } = {
	{
		Id = "Golden",
		DisplayName = "GOLDEN",
		Emoji = "🌟",
		Chance = 1 / 400,
		PayMult = 10,
		XPMult = 5,
		Color = Color3.fromRGB(255, 200, 40),
	},
	{
		Id = "Shiny",
		DisplayName = "Shiny",
		Emoji = "✨",
		Chance = 1 / 40,
		PayMult = 3,
		XPMult = 2,
		Color = Color3.fromRGB(140, 230, 255),
	},
}

local byId: { [string]: Variant } = {}
for _, variant in list do
	byId[variant.Id] = variant
end

local Variants = {
	List = list,
	ById = byId,
	-- A lucky start: your Nth job ever is always Shiny, so every new player sees one early
	LuckyJob = 3,
}

-- Rolls for one job. luck multiplies the chances (events like Golden Hour). `roll` is 0..1 (math.random()).
function Variants.Roll(roll: number, luck: number?): Variant?
	local edge = 0
	for _, variant in list do
		edge += variant.Chance * (luck or 1)
		if roll < edge then
			return variant
		end
	end
	return nil
end

return Variants
