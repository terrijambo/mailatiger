--!strict
-- Gruff's first-time walkthrough: grab the animal in front of you -> box it -> mail it -> go shopping.
-- To keep it quick, the server starts a new hire on the Backyard next to a calm, easy animal, makes that first
-- box gentle, and zips them back to the chute once it's taped (TutorialService, WildService, BoxingService).
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
local Profile = require(script.Parent.Profile)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Track = require(script.Parent.Track)
local Ui = require(script.Parent.Ui)

local Lines = Config.Gruff.Tutorial
local player = Players.LocalPlayer

local Tutorial = {}

local YELLOW = Color3.fromRGB(255, 220, 70)
local SHOP_STEP_SECONDS = 6

local function buildPanel(): (ScreenGui, TextLabel, TextButton)
	local gui = Ui.make("ScreenGui", {
		Name = "Tutorial",
		ResetOnSpawn = false,
		Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))
	-- Bottom center, between the side buttons and clear of the phone thumbstick and jump button
	local panel = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(420, 132),
		BackgroundColor3 = Ui.PAPER,
	}, gui)
	Ui.round(panel, 16)
	Ui.border(panel, 3)
	Ui.autoScale(panel)
	Ui.make("UISizeConstraint", { MaxSize = Vector2.new(420, 160) }, panel)

	-- Gruff's face: his portrait icon (Button_Gruff, the same one as in MENU > TRAVEL)
	Ui.icon(panel, "Button_Gruff", {
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(88, 88),
	})
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

-- The closest wild animal you're strong enough to grab (within `range` studs)
local function nearestWild(range: number): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local myLevel = Profile.Get().Level or 1
	local best, bestDistance = nil, range
	for _, ball in CollectionService:GetTagged("Critter") do
		local level = ball:GetAttribute("Level")
		if
			ball:IsA("BasePart")
			and ball:GetAttribute("Wild") == true
			and typeof(level) == "number"
			and level <= myLevel
			and (ball:GetAttribute("LuredFor") == nil or ball:GetAttribute("LuredFor") == player.UserId)
		then
			local distance = (ball.Position - root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = ball, distance
			end
		end
	end
	return best
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
		player:SetAttribute("TutorialStep", nil)
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
		elseif nearestWild(90) then
			return "Wild" -- in a zone, with animals around: go grab one
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
		player:SetAttribute("TutorialStep", step) -- (this screen only: SideButtons shows PEN when it's needed)
		Track.Send("TutorialStep", step) -- (analytics: how long each step takes, and where people stop)
		text.Text = (Lines :: any)[step] or ""
		-- The BOX screen shows the same instructions itself, and on phones the panel would cover the box
		gui.Enabled = step ~= "Box"
		if step == "Shop" then
			shopUntil = os.clock() + SHOP_STEP_SECONDS
		end
	end

	local function partNamed(name: string): BasePart?
		local found = map:FindFirstChild(name)
		return if found and found:IsA("BasePart") then found else nil
	end

	-- What the arrow points at right now (nil = no arrow, e.g. while the Box screen is up)
	local function target(): BasePart?
		if step == "Pen" then
			return nil -- (the PEN side button: Gruff's line points you to it)
		elseif step == "Catch" or step == "Escaped" then
			return myCritter()
		elseif step == "Wild" then
			return nearestWild(90)
		elseif step == "Mail" then
			return partNamed("MailChute")
		elseif step == "Shop" then
			return partNamed("Counter") -- (you shop by talking to Gruff)
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
			if step == "Pen" or step == "Wild" then
				refresh() -- (arrived in a zone, or walked away from it)
			end
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local goal = target()
			local show = goal ~= nil and root ~= nil
			arrow.Beam.Enabled = show
			arrow.Marker.Enabled = show
			if goal and root then
				if arrow.From.Parent ~= root then
					-- (a respawn can destroy the old character with the attachment in it: make a new one)
					if not pcall(function()
						arrow.From.Parent = root
					end) then
						local from = Instance.new("Attachment")
						from.Name = "TutorialFrom"
						from.Parent = root
						arrow.From = from
						arrow.Beam.Attachment0 = from
					end
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
