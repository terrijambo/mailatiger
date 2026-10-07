--!strict
-- Your Mail Chute, as only YOU see it:
--   * Shows your chute upgrade's Blender model (from ReplicatedStorage > PropModels, if imported) in place of
--     the plain block. Other players see their own upgrades.
--   * Sets how long you hold E to mail (faster chutes = shorter hold) and shows how many parcels you have.
--   * Your chute upgrades by itself as your level (chute level) goes up (Config/Mail.luau).
--   * Rocket Launcher machine: press M (or the on-screen button) to mail your bag from anywhere.

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local ModelFit = require(ReplicatedStorage.Shared.ModelFit)
local Profile = require(script.Parent.Profile)

local ChuteVisual = {}

function ChuteVisual.Start()
	local map = Workspace:WaitForChild("GrayboxMap")
	local chutePart = map:WaitForChild("MailChute") :: BasePart
	local prompt = chutePart:WaitForChild("ProximityPrompt") :: ProximityPrompt
	local mailAnywhere = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MailAnywhere") :: RemoteEvent

	local shownModel: Model? = nil
	local shownName = ""
	local rocketBound = false

	local function showModel(modelName: string)
		if modelName == shownName then
			return
		end
		shownName = modelName
		if shownModel then
			shownModel:Destroy()
			shownModel = nil
		end
		local models = ReplicatedStorage:FindFirstChild("PropModels")
		local template = models and models:FindFirstChild(modelName)
		if not (template and template:IsA("Model")) then
			chutePart.LocalTransparencyModifier = 0 -- no art imported yet: keep the plain block
			return
		end
		local model = template:Clone()
		ModelFit.Paint(model, modelName)
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
			end
		end
		local floor = chutePart.CFrame * CFrame.new(0, -chutePart.Size.Y / 2, 0)
		ModelFit.Fit(model, floor, chutePart.Size.X * 1.2)
		model.Parent = Workspace -- a local copy: only this player sees it
		chutePart.LocalTransparencyModifier = 1 -- hide the block (the name tag and prompt stay)
		shownModel = model
	end

	local function onMailKey(_name: string, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			mailAnywhere:FireServer()
		end
		return Enum.ContextActionResult.Pass
	end

	Profile.Watch(function()
		local data = Profile.Get()
		local chute = Config.Mail.ChuteFor(data.Level or 1)
		local mailAnywhereOn = data.Machines ~= nil and data.Machines.Rocket == true
		local count = #data.Parcels

		prompt.HoldDuration = chute.HoldTime
		prompt.ActionText = if count > 0 then `Mail {count} Parcel{if count == 1 then "" else "s"}` else "Mail Parcels"
		prompt.ObjectText = `{chute.DisplayName} (Lv {data.Level or 1})`
		showModel(chute.Model)

		if mailAnywhereOn and not rocketBound then
			rocketBound = true
			ContextActionService:BindAction("MailAnywhere", onMailKey, true, Enum.KeyCode.M, Enum.KeyCode.ButtonY)
			ContextActionService:SetTitle("MailAnywhere", "Mail!")
		elseif not mailAnywhereOn and rocketBound then
			rocketBound = false
			ContextActionService:UnbindAction("MailAnywhere")
		end
	end)
end

return ChuteVisual
