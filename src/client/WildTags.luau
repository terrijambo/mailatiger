--!strict
-- Name tags over wild animals ("Tiger  Lv 15"): red with a 🔒 when the animal is above your level (grabbing
-- it VINE BOOMs you out of the zone), normal when you can take it.

local CollectionService = game:GetService("CollectionService")

local Profile = require(script.Parent.Profile)

local WildTags = {}

local TOO_STRONG = Color3.fromRGB(255, 85, 85)

local function refresh(ball: Instance, myLevel: number)
	local level = ball:GetAttribute("Level")
	if ball:GetAttribute("Wild") ~= true or typeof(level) ~= "number" then
		return
	end
	local gui = ball:FindFirstChild("Label")
	local label = gui and gui:FindFirstChildOfClass("TextLabel")
	if not label then
		return
	end
	-- Remember the tag's own text and color the first time
	if label:GetAttribute("BaseText") == nil then
		label:SetAttribute("BaseText", label.Text)
		label:SetAttribute("BaseColor", label.TextColor3)
	end
	local tooStrong = level > myLevel
	local saved = label:GetAttribute("BaseText")
	local baseText = if typeof(saved) == "string" then saved else label.Text
	local baseColor = label:GetAttribute("BaseColor")
	label.Text = if tooStrong then `🔒 {baseText}` else baseText
	label.TextColor3 = if tooStrong
		then TOO_STRONG
		elseif typeof(baseColor) == "Color3" then baseColor
		else label.TextColor3
end

function WildTags.Start()
	task.spawn(function()
		while true do
			local myLevel = Profile.Get().Level or 1
			for _, ball in CollectionService:GetTagged("Critter") do
				refresh(ball, myLevel)
			end
			task.wait(0.5)
		end
	end)
end

return WildTags
