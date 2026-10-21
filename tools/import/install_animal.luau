--!nocheck
-- Installs animals made with Roblox Studio's AI mesh generator (docs/ANIMAL_PROMPTS.md). The generator drops each
-- model into Workspace named after its prompt; list them below as keyword in that name = animal Id, or
-- = { Id = ..., Turn = degrees } when it came out facing sideways or backwards (it should face -Z, like the camera).
-- For each: the old model moves to ServerStorage > OldAnimalModels (a backup), the parts get clean names and
-- decoration settings, it's turned to face forward, the Body becomes the PrimaryPart with a flat pivot at the bottom
-- centre of all its parts, and the model goes into
-- ReplicatedStorage > AnimalModels under the animal's Id. Run it in Studio's command bar, then save (Ctrl+S).

local INSTALL = {
	-- ["chibi cartoon bunny"] = "Bunny",
	-- ["chibi cartoon parrot"] = { Id = "Parrot", Turn = 180 },
}

local RS, SS = game:GetService("ReplicatedStorage"), game:GetService("ServerStorage")
local folder = RS:FindFirstChild("AnimalModels")
local backup = SS:FindFirstChild("OldAnimalModels") or Instance.new("Folder")
backup.Name = "OldAnimalModels"
backup.Parent = SS

local function clean(name)
	name = string.gsub(name, "_geom", "")
	name = string.gsub(name, "[^%a ]", "")
	local out = ""
	for word in string.gmatch(name, "%a+") do
		out ..= string.upper(string.sub(word, 1, 1)) .. string.sub(word, 2)
	end
	return out
end

local done = {}
for keyword, entry in INSTALL do
	local id = if type(entry) == "table" then entry.Id else entry
	local turn = if type(entry) == "table" then entry.Turn or 0 else 0
	local model
	for _, c in workspace:GetChildren() do
		if c:IsA("Model") and string.find(string.lower(c.Name), string.lower(keyword), 1, true) then
			model = c
		end
	end
	if model then
		local old = folder:FindFirstChild(id)
		if old then
			local older = backup:FindFirstChild(id)
			if older then
				older:Destroy()
			end
			old.Parent = backup
		end
		local body, biggest, volume = nil, nil, -1
		for _, p in model:GetDescendants() do
			if p:IsA("MeshPart") then
				p.Name = clean(p.Name)
				p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
				p.PivotOffset = CFrame.new()
				if p.Name == "Body" then
					body = p
				end
				if p.Size.X * p.Size.Y * p.Size.Z > volume then
					biggest, volume = p, p.Size.X * p.Size.Y * p.Size.Z
				end
			end
		end
		for _, p in model:GetDescendants() do
			if p:IsA("MeshPart") and p.Parent ~= model then
				p.Parent = model
			end
		end
		for _, c in model:GetChildren() do
			if not c:IsA("BasePart") then
				c:Destroy()
			end
		end
		local primary = body or biggest
		model.PrimaryPart = primary
		if turn ~= 0 then
			model:PivotTo(model:GetPivot() * CFrame.Angles(0, math.rad(turn), 0))
		end
		-- The pivot: flat (no tilt) at the bottom centre of every part's corners
		local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
		for _, p in model:GetChildren() do
			local half = p.Size / 2
			for _, corner in { Vector3.new(1, 1, 1), Vector3.new(1, 1, -1), Vector3.new(1, -1, 1), Vector3.new(1, -1, -1) } do
				for _, sign in { 1, -1 } do
					local w = p.CFrame:PointToWorldSpace(half * corner * sign)
					lo, hi = lo:Min(w), hi:Max(w)
				end
			end
		end
		primary.PivotOffset = primary.CFrame:ToObjectSpace(CFrame.new((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2))
		model.Name = id
		model:SetAttribute("Generated", "Roblox Studio mesh generator (docs/ANIMAL_PROMPTS.md)")
		model.Parent = folder
		table.insert(done, id)
	end
end
print(`[install_animal] installed: {table.concat(done, ", ")}. Now save: Ctrl+S.`)
return done
