--!strict
-- Fits an imported model (e.g. from Blender) into place, whatever scale or pivot it was imported with:
-- it's resized to the width we want, stood on the floor spot we give, and turned to face the same way.
--
-- If a model ends up facing backwards, give the Model a number attribute "YawOffset" = 180 in Studio
-- (Properties > Attributes > +). Any angle works, in degrees.

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

return ModelFit
