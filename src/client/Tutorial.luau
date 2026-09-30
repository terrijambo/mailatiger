--!strict
-- Gruff's first-time walkthrough: pick an animal -> catch it -> box it -> mail it -> go shopping.
-- A panel with Gruff says what to do next, and a glowing arrow (a beam from you, plus a bouncing marker) points
-- at where to go. It follows what you actually do, so it can't get stuck: if the animal escapes, it sends you
-- back to catching. "Skip" ends it for good. Finishing it pays a small bonus (the server checks it).
-- Lines are in src/shared/Config/Gruff.luau (Tutorial).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local ModelFit = require(ReplicatedStorage.Shared.ModelFit)
local Profile = require(script.Parent.Profile)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Ui = require(script.Parent.Ui)

local Lines = Config.Gruff.Tutorial
local player = Players.LocalPlayer

local Tutorial = {}

local YELLOW = Color3.fromRGB(255, 220, 70)
local SHOP_STEP_SECONDS = 12

local function buildPanel(): (ScreenGui, TextLabel, TextButton)
	local gui = Ui.make("ScreenGui", {
		Name = "Tutorial",
		ResetOnSpawn = false,
		Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))
	local panel = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.6, 0),
		Size = UDim2.fromOffset(360, 132),
		BackgroundColor3 = Ui.PAPER,
	}, gui)
	Ui.round(panel, 14)
	Ui.make("UIStroke", { Thickness = 3, Color = Ui.BROWN }, panel)
	Ui.make("UISizeConstraint", { MaxSize = Vector2.new(360, 160) }, panel)

	-- Gruff's face: his Blender model if imported, otherwise a name badge
	local portrait = Ui.make("ViewportFrame", {
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(88, 88),
		BackgroundColor3 = Color3.fromRGB(60, 90, 170),
		Ambient = Color3.fromRGB(170, 170, 170),
		LightDirection = Vector3.new(-0.4, -1, 0.6),
	}, panel)
	Ui.round(portrait, 44)
	local gruff = ModelFit.Spawn("AnimalModels", "Gruff", CFrame.identity, 4, nil, { ByHeight = true })
	if gruff then
		local camera = Instance.new("Camera")
		camera.FieldOfView = 30
		camera.Parent = portrait
		portrait.CurrentCamera = camera
		-- Frame his head and shoulders (the top 55% of him), from the front (models face -Z)
		local _, size = gruff:GetBoundingBox()
		local focus = Vector3.new(0, size.Y * 0.72, 0)
		camera.CFrame = CFrame.lookAt(focus + Vector3.new(0, 0, -size.Y * 1.25), focus)
		gruff.Parent = portrait
	else
		Ui.label(portrait, {
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextScaled = true,
			TextColor3 = Ui.WHITE,
			Text = "G",
		})
	end
	Ui.label(panel, {
		Position = UDim2.fromOffset(8, 100),
		Size = UDim2.fromOffset(88, 24),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 13,
		TextColor3 = Ui.BROWN,
		Text = "Postmaster Gruff",
	})
	local text = Ui.label(panel, {
		Position = UDim2.fromOffset(106, 10),
		Size = UDim2.new(1, -116, 1, -48),
		TextSize = 17,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
	})
	local skip = Ui.button(panel, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -10, 1, -8),
		Size = UDim2.fromOffset(110, 28),
		BackgroundColor3 = Ui.GREY,
		TextSize = 14,
		Text = "Skip tutorial",
	})
	return gui, text, skip
end

-- The arrow: a glowing beam from you to the target, and a bouncing marker above the target
type Arrow = {
	Beam: Beam,
	From: Attachment,
	To: Attachment,
	Marker: BillboardGui,
}

local function buildArrow(): Arrow
	local from = Instance.new("Attachment")
	from.Name = "TutorialFrom"
	local to = Instance.new("Attachment")
	to.Name = "TutorialTo"
	to.Parent = Workspace.Terrain
	local beam = Instance.new("Beam")
	beam.Name = "TutorialArrow"
	beam.Attachment0 = from
	beam.Attachment1 = to
	beam.Width0 = 0.6
	beam.Width1 = 0.6
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Color = ColorSequence.new(YELLOW)
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9),
		NumberSequenceKeypoint.new(0.15, 0.3),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	beam.Segments = 20
	beam.Enabled = false
	beam.Parent = Workspace.Terrain

	local marker = Ui.make("BillboardGui", {
		Name = "TutorialMarker",
		Size = UDim2.fromOffset(60, 60),
		AlwaysOnTop = true,
		Enabled = false,
	}, player:WaitForChild("PlayerGui"))
	Ui.label(marker, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextScaled = true,
		TextColor3 = YELLOW,
		TextStrokeTransparency = 0,
		Text = "▼",
	})
	return { Beam = beam, From = from, To = to, Marker = marker }
end

local function myCritter(): BasePart?
	for _, ball in CollectionService:GetTagged("Critter") do
		if ball:IsA("BasePart") and ball:GetAttribute("OwnerId") == player.UserId then
			return ball
		end
	end
	return nil
end

function Tutorial.Start()
	-- Wait for your save to load, then only run for players who haven't done it
	while typeof(player:GetAttribute("Profile")) ~= "string" do
		player:GetAttributeChangedSignal("Profile"):Wait()
	end
	if Profile.Get().TutorialDone then
		return
	end

	local map = Workspace:WaitForChild("GrayboxMap")
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Tutorial") :: RemoteEvent
	local notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent
	local gui, text, skip = buildPanel()
	local arrow = buildArrow()

	local step = ""
	local escaped = false
	local shopUntil = 0
	local finished = false
	local connections: { RBXScriptConnection } = {}

	local function finish(action: string)
		if finished then
			return
		end
		finished = true
		remote:FireServer(action)
		gui:Destroy()
		arrow.Beam:Destroy()
		arrow.To:Destroy()
		arrow.From:Destroy()
		arrow.Marker:Destroy()
		for _, connection in connections do
			connection:Disconnect()
		end
	end

	local function wanted(): string
		-- Mailed something (your save counts it the moment the chute pays you): last step
		if Profile.Get().Mailed > 0 then
			return "Shop"
		end
		local stage = player:GetAttribute("Stage")
		if stage == "Box" then
			return "Box"
		elseif stage == "Catch" then
			return if escaped then "Escaped" else "Catch"
		elseif #Profile.Get().Parcels > 0 then
			return "Mail"
		end
		return "Pen"
	end

	local function refresh()
		if finished then
			return
		end
		local nextStep = wanted()
		if nextStep == step then
			return
		end
		if step ~= "" and nextStep ~= "Escaped" then
			Sfx.Play("Ding")
		end
		step = nextStep
		text.Text = (Lines :: any)[step] or ""
		gui.Enabled = true
		if step == "Shop" then
			shopUntil = os.clock() + SHOP_STEP_SECONDS
		end
	end

	-- What the arrow points at right now (nil = no arrow, e.g. while the Box screen is up)
	local function target(): BasePart?
		if step == "Pen" then
			return map:FindFirstChild("PenCounter") :: BasePart?
		elseif step == "Catch" or step == "Escaped" then
			return myCritter()
		elseif step == "Mail" then
			return map:FindFirstChild("MailChute") :: BasePart?
		elseif step == "Shop" then
			return map:FindFirstChild("ShopCounter") :: BasePart?
		end
		return nil
	end

	skip.Activated:Connect(function()
		finish("Skip")
	end)
	table.insert(
		connections,
		notify.OnClientEvent:Connect(function(kind: string)
			if kind == "Break" then
				escaped = true
			elseif kind == "BoxStart" then
				escaped = false
			elseif kind == "OpenShop" and step == "Shop" then
				finish("Done")
				return
			end
			refresh()
		end)
	)
	table.insert(connections, player:GetAttributeChangedSignal("Stage"):Connect(refresh))
	table.insert(
		connections,
		player:GetAttributeChangedSignal("Profile"):Connect(function()
			if Profile.Get().TutorialDone then
				finish("Skip") -- already done (e.g. skipped on another device)
			else
				refresh()
			end
		end)
	)
	table.insert(
		connections,
		RunService.RenderStepped:Connect(function()
			if step == "Shop" and os.clock() > shopUntil then
				finish("Done")
				return
			end
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local goal = target()
			local show = goal ~= nil and root ~= nil and gui.Enabled
			arrow.Beam.Enabled = show
			arrow.Marker.Enabled = show
			if goal and root then
				if arrow.From.Parent ~= root then
					arrow.From.Parent = root
				end
				local top = goal.Position + Vector3.new(0, goal.Size.Y / 2 + 1, 0)
				arrow.To.WorldPosition = top
				arrow.Marker.Adornee = goal
				arrow.Marker.StudsOffset = Vector3.new(0, goal.Size.Y / 2 + 3 + math.abs(math.sin(os.clock() * 4)), 0)
			end
		end)
	)
	refresh()
end

return Tutorial
