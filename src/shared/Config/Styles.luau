--!strict
-- Cosmetics: tape colors (on the BOX screen and on your parcel) and a run trail in the same color.
-- Classic is free. Gold comes with the VIP pass. Every other color, and the trail, come with the
-- Style Pack pass (Config/Monetization.luau). Pick them in the Store (STYLE section).

export type Tape = {
	Id: string,
	DisplayName: string,
	Color: Color3,
	Needs: string?, -- the pass that unlocks it (nil = free)
}

local tapes: { Tape } = {
	{ Id = "Classic", DisplayName = "Classic", Color = Color3.fromRGB(235, 205, 120) },
	{ Id = "Gold", DisplayName = "Gold", Color = Color3.fromRGB(255, 200, 40), Needs = "VIP" },
	{ Id = "Red", DisplayName = "Red", Color = Color3.fromRGB(235, 60, 70), Needs = "StylePack" },
	{ Id = "Orange", DisplayName = "Orange", Color = Color3.fromRGB(255, 140, 40), Needs = "StylePack" },
	{ Id = "Green", DisplayName = "Green", Color = Color3.fromRGB(80, 210, 110), Needs = "StylePack" },
	{ Id = "Blue", DisplayName = "Blue", Color = Color3.fromRGB(60, 160, 255), Needs = "StylePack" },
	{ Id = "Purple", DisplayName = "Purple", Color = Color3.fromRGB(150, 90, 240), Needs = "StylePack" },
	{ Id = "Pink", DisplayName = "Pink", Color = Color3.fromRGB(255, 120, 190), Needs = "StylePack" },
	{ Id = "Black", DisplayName = "Black", Color = Color3.fromRGB(40, 40, 48), Needs = "StylePack" },
	{ Id = "White", DisplayName = "White", Color = Color3.fromRGB(245, 245, 245), Needs = "StylePack" },
}

local byId: { [string]: Tape } = {}
for _, tape in tapes do
	byId[tape.Id] = tape
end

-- The tape a player actually gets. `chosen` is their saved pick; `owns(passKey)` says which passes they have.
-- A pick they no longer own falls back to Gold for VIPs (as before the Style Pack existed), else Classic.
local function tapeFor(chosen: string?, owns: (string) -> boolean): Tape
	local tape = byId[chosen or ""]
	if tape and (tape.Needs == nil or owns(tape.Needs)) and tape.Id ~= "Classic" then
		return tape
	end
	if chosen ~= "Classic" and owns("VIP") then
		return byId.Gold
	end
	return byId.Classic
end

return {
	Tapes = tapes,
	TapeById = byId,
	TapeFor = tapeFor,
	-- The run trail (Style Pack): how long it lingers, in seconds
	TrailSeconds = 0.6,
}
