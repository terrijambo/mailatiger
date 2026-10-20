--!nocheck
-- Splits an imported KayKit pack (art/export/kaykit/<Pack>_all.fbx, imported with Studio's 3D Importer) into
-- one Model per piece in ReplicatedStorage.MapModels, named like "Forest_Tree1A", so the map code can spawn
-- them by name (shared/ModelFit.Spawn, Scenery/Kit.model). Runs in Studio's command bar (or by the agent):
-- paste the whole file, then run it. It looks for imported models in Workspace and ServerStorage whose
-- MeshParts are named "<Pack>_..." (Forest_, City_), moves each MeshPart into its own Model, and removes what's
-- left of the import. Running it twice is safe: a piece that already exists in MapModels is replaced.
--
-- After it runs: File → Save (Ctrl+S). The models live only in the place (MailATiger.rbxl), not in git.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local PREFIXES = { "Forest_", "City_" }

local mapModels = ReplicatedStorage:FindFirstChild("MapModels")
if not mapModels then
	mapModels = Instance.new("Folder")
	mapModels.Name = "MapModels"
	mapModels.Parent = ReplicatedStorage
end

local function packName(name)
	for _, prefix in PREFIXES do
		if string.sub(name, 1, #prefix) == prefix then
			return prefix
		end
	end
	return nil
end

local made, imports = 0, {}
for _, root in { workspace, ServerStorage } do
	for _, top in root:GetChildren() do
		if top:IsA("Model") or top:IsA("Folder") then
			local found = false
			for _, mesh in top:GetDescendants() do
				if mesh:IsA("MeshPart") and packName(mesh.Name) then
					found = true
					-- The importer sometimes adds a suffix ("Forest_Tree1A_Mesh"): keep the piece's own name
					local name = string.gsub(mesh.Name, "_[Mm]esh$", "")
					local old = mapModels:FindFirstChild(name)
					if old then
						old:Destroy()
					end
					local model = Instance.new("Model")
					model.Name = name
					mesh.Name = "Mesh"
					mesh.Anchored = true
					mesh.CanCollide = false
					mesh.CanTouch = false
					mesh.CanQuery = false
					mesh.Parent = model
					-- Pivot flat, at the bottom center. The importer tilts each piece's pivot 90 degrees (Blender's
					-- "Z is up"), and the game places models by their pivot, so without this they lie on their side.
					mesh.PivotOffset = CFrame.new(0, -mesh.Size.Y / 2, 0)
					model.PrimaryPart = mesh
					model.Parent = mapModels
					made += 1
				end
			end
			if found then
				table.insert(imports, top)
			end
		end
	end
end
for _, top in imports do
	top:Destroy()
end
print(`[split_pack] {made} KayKit models in ReplicatedStorage.MapModels (from {#imports} import(s)). Now save: Ctrl+S.`)
