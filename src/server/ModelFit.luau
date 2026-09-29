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
function ModelFit.Fit(model: Model, floor: CFrame, width: number)
	local _, size = model:GetBoundingBox()
	local widest = math.max(size.X, size.Z)
	if widest > 0 then
		model:ScaleTo(model:GetScale() * width / widest)
	end

	local yaw = model:GetAttribute("YawOffset")
	local turn = if typeof(yaw) == "number" then CFrame.Angles(0, math.rad(yaw), 0) else CFrame.identity
	local boxCFrame, newSize = model:GetBoundingBox()
	local target = floor * turn * CFrame.new(0, newSize.Y / 2, 0)
	-- Move the model so its bounding box's center lands on the target
	model:PivotTo(target * boxCFrame:ToObjectSpace(model:GetPivot()))
end

-- Colors each part using src/shared/ArtColors/<artName>.json (e.g. "Hamster", "Cardboard").
-- Parts are matched by name: "Body" gets the Body color. Names with extra bits (like "Hamster_Body") match too.
function ModelFit.Paint(model: Model, artName: string)
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local folder = shared and shared:FindFirstChild("ArtColors")
	local module = folder and folder:FindFirstChild(artName)
	if not (module and module:IsA("ModuleScript")) then
		return
	end
	local colors = require(module) :: any

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			for name, rgb in colors do
				if part.Name == name or string.find(string.lower(part.Name), string.lower(name), 1, true) then
					part.Color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
					part.Material = Enum.Material.SmoothPlastic
					break
				end
			end
		end
	end
end

return ModelFit
