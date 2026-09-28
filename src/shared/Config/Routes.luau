--!strict
-- Routes from the hub to the Post Office.
--   UnlockTier   : the animal tier needed to enter
--   PayoutMult   : multiplies payouts earned on this route
--   Sabotage     : true = opt-in PvP route (bumping + traps allowed)

export type Route = {
	Id: string,
	DisplayName: string,
	UnlockTier: number,
	PayoutMult: number,
	Sabotage: boolean,
}

local List: { Route } = {
	{ Id = "Town", DisplayName = "Town Streets", UnlockTier = 1, PayoutMult = 1, Sabotage = false },
	{ Id = "Construction", DisplayName = "Construction Site", UnlockTier = 2, PayoutMult = 1.5, Sabotage = false },
	{ Id = "Jungle", DisplayName = "Jungle Trail", UnlockTier = 3, PayoutMult = 2, Sabotage = false },
	{ Id = "Alley", DisplayName = "Back Alley (Sabotage)", UnlockTier = 2, PayoutMult = 2.5, Sabotage = true },
}

local ById: { [string]: Route } = {}
for _, route in List do
	ById[route.Id] = route
end

return {
	List = List,
	ById = ById,
}
