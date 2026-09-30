--!strict
-- Hides the glowing lock barriers (and their LEVEL signs) in front of zones you've unlocked. Everyone sees
-- the barriers for zones they haven't reached yet.

local CollectionService = game:GetService("CollectionService")

local Profile = require(script.Parent.Profile)

local ZoneLocks = {}

local function apply(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local need = part:GetAttribute("Level")
	local open = typeof(need) == "number" and (Profile.Get().Level or 1) >= need
	part.LocalTransparencyModifier = if open then 1 else 0
	local gui = part:FindFirstChildOfClass("SurfaceGui")
	if gui then
		gui.Enabled = not open
	end
end

function ZoneLocks.Start()
	local function refreshAll()
		for _, part in CollectionService:GetTagged("ZoneLock") do
			apply(part)
		end
	end
	CollectionService:GetInstanceAddedSignal("ZoneLock"):Connect(apply)
	Profile.Watch(refreshAll)
end

return ZoneLocks
