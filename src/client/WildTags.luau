--!strict
-- Name tags over wild animals ("Tiger  Lv 7"): normal when it's your level or below, orange with ⚠ when it's
-- above you but within reach (a harder BOX), red with a 🔒 when it's too far above or from a realm you haven't
-- bought (grabbing it VINE BOOMs you out of the zone). Compared by power (Config/Realms.luau).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Profile = require(script.Parent.Profile)

local WildTags = {}

local TOO_STRONG = Color3.fromRGB(255, 85, 85)
local HARDER = Color3.fromRGB(255, 165, 60)

local function refresh(ball: Instance, myPower: number)
	local level = ball:GetAttribute("Power")
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
	local tooStrong = level > myPower + Config.Wild.MaxLevelGap
	local harder = not tooStrong and level > myPower
	local saved = label:GetAttribute("BaseText")
	local baseText = if typeof(saved) == "string" then saved else label.Text
	local baseColor = label:GetAttribute("BaseColor")
	label.Text = if tooStrong then `🔒 {baseText}` elseif harder then `⚠ {baseText}` else baseText
	label.TextColor3 = if tooStrong
		then TOO_STRONG
		elseif harder then HARDER
		elseif typeof(baseColor) == "Color3" then baseColor
		else label.TextColor3
end

function WildTags.Start()
	task.spawn(function()
		while true do
			local data = Profile.Get()
			local myPower = Config.Realms.Power(data.Realm or 1, data.Level or 1)
			for _, ball in CollectionService:GetTagged("Critter") do
				refresh(ball, myPower)
			end
			task.wait(0.5)
		end
	end)
end

return WildTags
