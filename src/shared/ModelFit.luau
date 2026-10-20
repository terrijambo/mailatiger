--!strict
-- Helpers for imported models (e.g. from Blender):
--   Fit:   resize a model, stand it on a floor spot, and turn it the right way, whatever scale or pivot it
--          was imported with.
--   Paint: color its parts. Roblox's importer drops plain material colors, so each Blender script writes
--          its colors to src/shared/ArtColors/<ModelName>.json, and this paints each part by its name.
--
-- If a model ends up facing backwards, give the Model a number attribute "YawOffset" = 180 in Studio
-- (Properties > Attributes > +). Any angle works, in degrees.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModelFit = {}

-- floor: where the model's bottom-center should be (and which way it should face)
-- width: how wide (X or Z, whichever is bigger) it should be, in studs
-- byHeight: true = `width` is the height instead (better for tall, thin things like lampposts)
function ModelFit.Fit(model: Model, floor: CFrame, width: number, byHeight: boolean?)
	local _, size = model:GetBoundingBox()
	local measured = if byHeight then size.Y else math.max(size.X, size.Z)
	if measured > 0 then
		model:ScaleTo(model:GetScale() * width / measured)
	end

	local yaw = model:GetAttribute("YawOffset")
	local turn = if typeof(yaw) == "number" then CFrame.Angles(0, math.rad(yaw), 0) else CFrame.identity
	local boxCFrame, newSize = model:GetBoundingBox()
	local target = floor * turn * CFrame.new(0, newSize.Y / 2, 0)
	-- Move the model so its bounding box's center lands on the target
	model:PivotTo(target * boxCFrame:ToObjectSpace(model:GetPivot()))
end

-- Models from a texture pack (KayKit: tools/import/kaykit.py) are listed in src/shared/ArtAtlas/<Pack>.json.
-- The whole pack shares one texture, uploaded once (its id goes in Config/Atlases.luau), and this puts it on
-- every part of such a model. Until the id is filled in, the model keeps whatever the importer gave it.
local atlasOf: { [string]: string }? = nil
function ModelFit.ApplyAtlas(model: Model, artName: string)
	if not atlasOf then
		local index: { [string]: string } = {}
		local shared = ReplicatedStorage:FindFirstChild("Shared")
		local folder = shared and shared:FindFirstChild("ArtAtlas")
		if folder then
			for _, module in folder:GetChildren() do
				if module:IsA("ModuleScript") then
					local list = require(module) :: any
					for _, name in list.Models do
						index[name] = module.Name
					end
				end
			end
		end
		atlasOf = index
	end
	local pack = (atlasOf :: { [string]: string })[artName]
	if not pack then
		return
	end
	local Atlases = require(ReplicatedStorage.Shared.Config).Atlases
	local texture = Atlases[pack]
	if not texture or texture == "" then
		return
	end
	for _, part in model:GetDescendants() do
		if part:IsA("MeshPart") then
			part.TextureID = texture
			part.Color = Color3.new(1, 1, 1)
			part.Material = Enum.Material.SmoothPlastic
			-- Hero models are split into parts by what they're made of (kk.py groups): a few get their own look
			if part.Name == "Water" then
				part.Transparency = 0.35
				part.Reflectance = 0.08
			elseif part.Name == "Glass" then
				part.Reflectance = 0.12
			elseif part.Name == "Glow" then
				part.Material = Enum.Material.Neon
				part.Color = Color3.fromRGB(255, 200, 110)
			end
		end
	end
end

-- Colors each part using src/shared/ArtColors/<artName>.json (e.g. "Hamster", "Cardboard").
-- Parts are matched by name: "Body" gets the Body color. Names with extra bits (like "Hamster_Body") match too.
function ModelFit.Paint(model: Model, artName: string)
	ModelFit.ApplyAtlas(model, artName)
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local folder = shared and shared:FindFirstChild("ArtColors")
	local module = folder and folder:FindFirstChild(artName)
	if not (module and module:IsA("ModuleScript")) then
		return
	end
	local colors = require(module) :: any

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			-- Exact name first; otherwise a name that contains it (the importer sometimes adds prefixes)
			local entry = colors[part.Name]
			if not entry then
				for name, candidate in colors do
					if string.find(string.lower(part.Name), string.lower(name), 1, true) then
						entry = candidate
						break
					end
				end
			end
			if entry then
				part.Color = Color3.fromRGB(entry[1], entry[2], entry[3])
				part.Material = Enum.Material.SmoothPlastic
				if entry[4] then
					part.Transparency = entry[4] -- see-through parts, like the goldfish bowl
				end
			end
		end
	end
end

export type SpawnOptions = {
	ByHeight: boolean?, -- `size` is the height, not the width
	Solid: boolean?, -- players and animals bump into it
}

-- Makes a colored, fitted copy of ReplicatedStorage > <folderName> > <name> (e.g. "MapModels", "Barn"),
-- as decoration: anchored, invisible to clicks and raycasts, and walk-through unless options.Solid.
-- Returns nil when you haven't imported that model yet, so callers can keep their plain-block fallback.
function ModelFit.Spawn(
	folderName: string,
	name: string,
	floor: CFrame,
	size: number,
	parent: Instance?,
	options: SpawnOptions?
): Model?
	local solid = options ~= nil and options.Solid == true
	local byHeight = options ~= nil and options.ByHeight
	-- The size table wins (Config/ModelSizes.luau): one size per model, wherever it's spawned from
	local listed = (require(ReplicatedStorage.Shared.Config) :: any).ModelSizes[name]
	if listed then
		if listed.Height then
			size, byHeight = listed.Height, true
		elseif listed.Width then
			size, byHeight = listed.Width, false
		end
	end
	local folder = ReplicatedStorage:FindFirstChild(folderName)
	local template = folder and folder:FindFirstChild(name)
	local model: Model
	if template and template:IsA("Model") then
		model = template:Clone()
	elseif template and template:IsA("BasePart") then
		-- Imported as a single mesh instead of a model: wrap it
		model = Instance.new("Model")
		model.Name = name
		template:Clone().Parent = model
	else
		return nil
	end
	ModelFit.Paint(model, name)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = solid
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	ModelFit.Fit(model, floor, size, byHeight)
	model.Parent = parent
	return model
end

-- Slides a model along one axis so its bounding box's face on that side lands at `value`.
-- e.g. Align(barn, Vector3.zAxis, -52) puts the barn's +Z face at z = -52 (just behind a fence).
function ModelFit.Align(model: Model, axis: Vector3, value: number)
	local box, size = model:GetBoundingBox()
	local extent = math.abs(axis.X) * size.X + math.abs(axis.Y) * size.Y + math.abs(axis.Z) * size.Z
	local face = box.Position:Dot(axis) + extent / 2
	model:PivotTo(model:GetPivot() + axis * (value - face))
end

return ModelFit
