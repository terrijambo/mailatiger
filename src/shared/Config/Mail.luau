--!strict
-- "Mail it yourself": taped boxes become Parcels in your bag. Carry them to the Mail Chute and mail them there
-- to get paid. Upgrade the chute (Supply Shop, Chutes tab) to mail faster and earn more.
--   BagCapacity : parcels you can carry before upgrading the Mail Bag tool (each level adds its PerLevel)
--
-- Chutes: your chute upgrades by itself as your chute level goes up (Config/Machines.luau). Each one looks
-- fancier and mails faster.
--   Level      : the chute level it arrives at
--   HoldTime   : seconds to hold E at the chute to mail everything
--   Model      : the Blender model shown for your chute (ReplicatedStorage > PropModels), if you've imported it

export type Chute = {
	Id: string,
	DisplayName: string,
	Description: string,
	Level: number,
	HoldTime: number,
	Model: string,
}

local Chutes: { Chute } = {
	{
		Id = "Basic",
		DisplayName = "Mail Chute",
		Description = "The old reliable.",
		Level = 1,
		HoldTime = 1.5,
		Model = "MailChute",
	},
	{
		Id = "Express",
		DisplayName = "Express Chute",
		Description = "Conveyor belt feed: mails faster.",
		Level = 10,
		HoldTime = 0.9,
		Model = "MailChuteExpress",
	},
	{
		Id = "Pneumatic",
		DisplayName = "Pneumatic Chute",
		Description = "WHOOSH. Almost instant.",
		Level = 20,
		HoldTime = 0.4,
		Model = "MailChutePneumatic",
	},
	{
		Id = "Rocket",
		DisplayName = "Rocket Chute",
		Description = "The fastest chute there is.",
		Level = 30,
		HoldTime = 0.2,
		Model = "MailChuteRocket",
	},
}

-- What the old chutes cost, for refunding saves from when you bought them
local OldPrices: { [string]: number } = { Basic = 0, Express = 20000, Pneumatic = 170000, Rocket = 1170000 }

local ChuteById: { [string]: Chute } = {}
local ChuteIndex: { [string]: number } = {}
for index, chute in Chutes do
	ChuteById[chute.Id] = chute
	ChuteIndex[chute.Id] = index
end

-- Your chute at a chute level
local function ChuteFor(level: number): Chute
	local best = Chutes[1]
	for _, chute in Chutes do
		if level >= chute.Level then
			best = chute
		end
	end
	return best
end

return {
	BagCapacity = 3,
	Chutes = Chutes,
	ChuteFor = ChuteFor,
	OldPrices = OldPrices,
	ChuteById = ChuteById,
	ChuteIndex = ChuteIndex, -- position in the upgrade order (1 = Basic)
}
