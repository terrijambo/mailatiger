--!strict
-- "Mail it yourself": taped boxes become Parcels in your bag. Carry them to the Mail Chute and mail them there
-- to get paid. Upgrade the chute (Supply Shop, Chutes tab) to mail faster and earn more.
--   BagCapacity : parcels you can carry before upgrading the Mail Bag tool (each level adds its PerLevel)
--
-- Chutes, in upgrade order (you buy them one after another):
--   HoldTime   : seconds to hold E at the chute to mail everything
--   PayMult    : multiplies what each parcel pays
--   MailAnywhere : true = press M to mail your bag from anywhere
--   Model      : the Blender model shown for your chute (ReplicatedStorage > PropModels), if you've imported it

export type Chute = {
	Id: string,
	DisplayName: string,
	Description: string,
	Price: number,
	HoldTime: number,
	PayMult: number,
	MailAnywhere: boolean,
	Model: string,
}

local Chutes: { Chute } = {
	{
		Id = "Basic",
		DisplayName = "Mail Chute",
		Description = "The old reliable. Hold E for a moment to mail your bag.",
		Price = 0,
		HoldTime = 1.5,
		PayMult = 1,
		MailAnywhere = false,
		Model = "MailChute",
	},
	{
		Id = "Express",
		DisplayName = "Express Chute",
		Description = "Conveyor belt feed: mails faster and pays +15%.",
		Price = 20000,
		HoldTime = 0.9,
		PayMult = 1.15,
		MailAnywhere = false,
		Model = "MailChuteExpress",
	},
	{
		Id = "Pneumatic",
		DisplayName = "Pneumatic Chute",
		Description = "WHOOSH. Almost instant, and pays +30%.",
		Price = 150000,
		HoldTime = 0.4,
		PayMult = 1.3,
		MailAnywhere = false,
		Model = "MailChutePneumatic",
	},
	{
		Id = "Rocket",
		DisplayName = "Rocket Chute",
		Description = "Pays +50%, and press M to launch your bag from ANYWHERE.",
		Price = 1000000,
		HoldTime = 0.2,
		PayMult = 1.5,
		MailAnywhere = true,
		Model = "MailChuteRocket",
	},
}

local ChuteById: { [string]: Chute } = {}
local ChuteIndex: { [string]: number } = {}
for index, chute in Chutes do
	ChuteById[chute.Id] = chute
	ChuteIndex[chute.Id] = index
end

return {
	BagCapacity = 3,
	Chutes = Chutes,
	ChuteById = ChuteById,
	ChuteIndex = ChuteIndex, -- position in the upgrade order (1 = Basic)
}
