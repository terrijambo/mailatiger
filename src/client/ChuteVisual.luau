--!strict
-- Your Mail Chute (at every realm's hub), as only YOU see it:
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
local Hubs = require(script.Parent.Hubs)
local Profile = require(script.Parent.Profile)

local ChuteVisual = {}

-- One hub's chute (client/Hubs.luau): its plain block, its prompt, and the model drawn over it
type Chute = { Part: BasePart, Prompt: ProximityPrompt, Shown: Model?, ShownName: string }

-- Shows a chute upgrade's model over one chute (or keeps the plain block when it isn't imported)
local function showModel(chute: Chute, modelName: string)
	if modelName == chute.ShownName then
		return
	end
	chute.ShownName = modelName
	local shown = chute.Shown
	if shown then
		shown:Destroy()
		chute.Shown = nil
	end
	local chutePart = chute.Part
	-- Our hero version (MapModels > MA_<name>, art/blender_scripts/hero_props.py) first, then the older model
	local heroes = ReplicatedStorage:FindFirstChild("MapModels")
	local models = ReplicatedStorage:FindFirstChild("PropModels")
	local template = heroes and heroes:FindFirstChild(`MA_{modelName}`)
	if template then
		modelName = `MA_{modelName}`
	else
		template = models and models:FindFirstChild(modelName)
	end
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
	chute.Shown = model
end

function ChuteVisual.Start()
	local mailAnywhere = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MailAnywhere") :: RemoteEvent
	local chutes: { [BasePart]: Chute } = {}
	local rocketBound = false

	local function onMailKey(_name: string, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			mailAnywhere:FireServer()
		end
		return Enum.ContextActionResult.Pass
	end

	-- Your chute (it upgrades with your level) on one hub's chute
	local function refreshChute(chute: Chute)
		local data = Profile.Get()
		local look = Config.Mail.ChuteFor(data.Level or 1)
		local count = #data.Parcels
		chute.Prompt.HoldDuration = look.HoldTime
		chute.Prompt.ActionText = if count > 0
			then `Mail {count} Parcel{if count == 1 then "" else "s"}`
			else "Mail Parcels"
		chute.Prompt.ObjectText = `{look.DisplayName} (Lv {data.Level or 1})`
		showModel(chute, look.Model)
	end

	Hubs.Each("HubChute", function(instance: Instance)
		if not instance:IsA("BasePart") or chutes[instance] then
			return
		end
		local chute: Chute = {
			Part = instance,
			Prompt = instance:WaitForChild("ProximityPrompt") :: ProximityPrompt,
			ShownName = "",
		}
		chutes[instance] = chute
		instance.AncestryChanged:Connect(function()
			if not instance:IsDescendantOf(Workspace) then
				local shown = chute.Shown
				if shown then
					shown:Destroy()
				end
				chutes[instance] = nil
			end
		end)
		refreshChute(chute)
	end)

	Profile.Watch(function()
		for _, chute in chutes do
			refreshChute(chute)
		end
		local data = Profile.Get()
		local mailAnywhereOn = data.Machines ~= nil and data.Machines.Rocket == true
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
