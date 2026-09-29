--!strict
-- Types shared between server modules.

-- One animal being carried to the Post Office.
export type Delivery = {
	Player: Player,
	Box: Part,
	Hold: Attachment, -- the point on the character the box is pulled toward
	AnimalId: string,
	BoxId: string,

	HP: number,
	MaxHP: number,
	Rage: number,
	RageLocked: boolean, -- true = rage doesn't build (e.g. a sleeping bear)

	PayoutMult: number,
	Bonus: number, -- extra coins added on delivery (e.g. chicken eggs)
	WeightMult: number,
	SpeedMult: number,
	RattleDamageMult: number,
	RattleImpulseMult: number,

	BellRung: boolean,
	StartTime: number,
	History: { { T: number, V: Vector3 } },
	LastImpact: number,
	ImpactGraceUntil: number, -- impacts before this time don't hurt (e.g. a kangaroo's own hop)
	NextRattle: number,

	State: { [string]: any }, -- scratch space for the animal's behavior
}

return {}
