--!strict
-- The BOX screen. Left: your animal, with ♥ sweet spots (rub them to calm it) and ✖ angry spots (don't!).
-- Right: the box. Drag tape along each dashed seam, from one end dot to the other.
-- Top: the ANGER meter. It keeps rising, and every strip of tape makes it jump. At 100 you get launched.
--
-- This screen only reports what you did ("Pet spot 2", "Tape seam 1"). The server decides what it means.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local BoxMath = require(ReplicatedStorage.Shared.BoxMath)
local Config = require(ReplicatedStorage.Shared.Config)
local ModelFit = require(ReplicatedStorage.Shared.ModelFit)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local BoxingScreen = {}

local PINK = Color3.fromRGB(255, 120, 170)
local ANGRY = Color3.fromRGB(220, 50, 50)
local TAPE = Color3.fromRGB(235, 205, 120)
local CARDBOARD = Color3.fromRGB(205, 165, 115)
local DARK = Color3.fromRGB(30, 30, 36)
local PET_SEND_INTERVAL = 0.1

local function line(parent: Instance, a: Vector2, b: Vector2, thickness: number, color: Color3, z: number): Frame
	-- Works in 0..1 "scale" coordinates, which is fine because both cards are square
	local delta = b - a
	local frame = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale((a.X + b.X) / 2, (a.Y + b.Y) / 2),
		Size = UDim2.new(delta.Magnitude, 0, 0, thickness),
		Rotation = math.deg(math.atan2(delta.Y, delta.X)),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = z,
	}, parent)
	return frame
end

local function dot(parent: Instance, at: Vector2, size: number, color: Color3, z: number): Frame
	local frame = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(at.X, at.Y),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		ZIndex = z,
	}, parent)
	Ui.round(frame, size)
	return frame
end

local function shake(frame: GuiObject)
	local home = frame.Position
	task.spawn(function()
		for _ = 1, 6 do
			frame.Position = home + UDim2.fromOffset(math.random(-8, 8), math.random(-6, 6))
			task.wait(0.03)
		end
		frame.Position = home
	end)
end

function BoxingScreen.Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local input = remotes:WaitForChild("BoxingInput") :: RemoteEvent
	local notify = remotes:WaitForChild("Notify") :: RemoteEvent

	local gui = Ui.make("ScreenGui", {
		Name = "BoxingScreen",
		ResetOnSpawn = false,
		Enabled = false,
		-- Sibling: children always draw on top of their parent (so the seams show ON the box, not behind it)
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))
	local backdrop = Ui.make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Active = true, -- swallow touches so the camera doesn't spin while you rub and tape
	}, gui)

	-- ANGER meter
	local meterBack = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.new(0.6, 0, 0, 34),
		BackgroundColor3 = Color3.fromRGB(60, 60, 68),
	}, backdrop)
	Ui.round(meterBack, 10)
	local meterFill = Ui.make("Frame", { Size = UDim2.fromScale(0.2, 1), BackgroundColor3 = Ui.GREEN }, meterBack)
	Ui.round(meterFill, 10)
	local meterText = Ui.label(meterBack, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 20,
		TextColor3 = Ui.WHITE,
		TextStrokeTransparency = 0.4,
		ZIndex = 3,
		Text = "ANGER",
	})
	local help = Ui.label(backdrop, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 108),
		Size = UDim2.new(0.8, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Ui.WHITE,
		TextStrokeTransparency = 0.5,
		Text = "",
	})

	-- One picture: the animal popping out of the top of the open box.
	-- The scene is square. The animal fills the top 60%, and the box covers the bottom 56%, hiding the
	-- animal's lower half. (The server only puts pet spots on the part you can see, see BoxMath.)
	local scene = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.57),
		Size = UDim2.fromScale(0.62, 0.66),
		BackgroundTransparency = 1,
	}, backdrop)
	Ui.make("UIAspectRatioConstraint", { AspectRatio = 1 }, scene)

	local ANIMAL_HOME = UDim2.fromScale(0.5, 0)
	local ANIMAL_HIDDEN = UDim2.fromScale(0.5, 0.42) -- tucked inside the box, before it pops out
	local animalCard = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = ANIMAL_HOME,
		Size = UDim2.fromScale(0.6, 0.6),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, scene)
	-- The plain circle-with-a-face animal (used when its Blender model isn't imported)
	local animalBody = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 2,
	}, animalCard)
	Ui.round(animalBody, 1000)
	local bodyStroke = Ui.make("UIStroke", { Thickness = 4, Color = DARK }, animalBody)
	-- Your Blender animal in 3D, when imported
	local viewport = Ui.make("ViewportFrame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(170, 170, 170),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-0.4, -1, 0.6),
		ZIndex = 2,
	}, animalCard)
	local viewportCamera = Instance.new("Camera")
	viewportCamera.FieldOfView = 30
	viewportCamera.Parent = viewport
	viewport.CurrentCamera = viewportCamera
	local viewportModel: Model? = nil
	local squishUntil = 0
	local face = Ui.label(animalBody, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromScale(0.6, 0.22),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextScaled = true,
		TextColor3 = DARK,
		ZIndex = 3,
		Text = "• ᴥ •",
	})
	local animalTitle = Ui.label(scene, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -8),
		Size = UDim2.new(1, 0, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 22,
		TextColor3 = Ui.WHITE,
		TextStrokeTransparency = 0.4,
		Text = "",
	})

	-- The open box: two flaps folded out, and the front face you tape
	for _, side in { -1, 1 } do
		local flap = Ui.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + side * 0.34, 0.41),
			Size = UDim2.fromScale(0.2, 0.06),
			Rotation = side * -22,
			BackgroundColor3 = CARDBOARD:Lerp(DARK, 0.15),
			ZIndex = 4,
		}, scene)
		Ui.round(flap, 6)
		Ui.make("UIStroke", { Thickness = 3, Color = DARK }, flap)
	end
	local boxCard = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(0.56, 0.56),
		BackgroundColor3 = CARDBOARD,
		ZIndex = 5, -- in front of the animal
	}, scene)
	Ui.round(boxCard, 10)
	Ui.make("UIStroke", { Thickness = 4, Color = DARK }, boxCard)
	local boxTitle = Ui.label(scene, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 8),
		Size = UDim2.new(1, 0, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 22,
		TextColor3 = Ui.WHITE,
		TextStrokeTransparency = 0.4,
		Text = "",
	})
	local popping = false

	-- Co-op roles: "Both" when solo. In a crew you only pet OR tape, and the other half is shaded.
	local role = "Both"
	local function shade(parent: GuiObject, text: string, corner: number): Frame
		local frame = Ui.make("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.55,
			Visible = false,
			ZIndex = 20,
		}, parent)
		Ui.round(frame, corner)
		Ui.label(frame, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.3),
			Size = UDim2.fromScale(0.9, 0.2),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextScaled = true,
			TextColor3 = Ui.WHITE,
			ZIndex = 21,
			Text = text,
		})
		return frame
	end
	local petShade = shade(animalCard, "Your crewmate is petting!", 1000)
	local tapeShade = shade(boxCard, "Your crewmate is taping!", 10)
	local function applyRole(newRole: string)
		role = newRole
		petShade.Visible = role == "Tape"
		tapeShade.Visible = role == "Pet"
	end

	-- State for the current job
	local start = 0
	local spots: { BoxMath.Spot } = {}
	local spotFrames: { Frame } = {}
	local seams: { BoxMath.Seam } = {}
	local taped: { boolean } = {}
	local seamLayer: Frame? = nil

	local mode: string? = nil -- "Pet" or "Tape" while the mouse/finger is down
	local lastPoint = Vector2.zero
	local path: { Vector2 } = {}
	local preview: Frame? = nil
	local lastPetSend = 0
	local lastAngrySend = 0

	local function toCard(frame: GuiObject, screen: Vector2): Vector2
		return (screen - frame.AbsolutePosition) / frame.AbsoluteSize
	end

	local function inside(frame: GuiObject, screen: Vector2): boolean
		local p = toCard(frame, screen)
		return p.X >= 0 and p.X <= 1 and p.Y >= 0 and p.Y <= 1
	end

	local function drawSeams()
		if seamLayer then
			seamLayer:Destroy()
		end
		local layer = Ui.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, boxCard)
		seamLayer = layer
		local done = 0
		for index, seam in seams do
			if taped[index] then
				done += 1
				line(layer, seam.A, seam.B, 22, TAPE, 3)
			else
				-- a dashed seam: short dark segments with a dot at each end
				for step = 0, 9 do
					local a = seam.A:Lerp(seam.B, step / 10)
					local b = seam.A:Lerp(seam.B, (step + 0.55) / 10)
					line(layer, a, b, 5, DARK, 2)
				end
				dot(layer, seam.A, 16, DARK, 2)
				dot(layer, seam.B, 16, DARK, 2)
			end
		end
		boxTitle.Text = `Tape the seams: {done} / {#seams}`
	end

	local function floatText(text: string, at: Vector2, color: Color3)
		local label = Ui.label(gui, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(at.X, at.Y),
			Size = UDim2.fromOffset(40, 40),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextSize = 30,
			TextColor3 = color,
			TextStrokeTransparency = 0.3,
			ZIndex = 10,
			Text = text,
		})
		local tween = TweenService:Create(label, TweenInfo.new(0.7), {
			Position = UDim2.fromOffset(at.X, at.Y - 50),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		})
		tween:Play()
		tween.Completed:Once(function()
			label:Destroy()
		end)
	end

	local function setup(data: { [string]: any })
		start = data.Start
		spots = data.Spots
		taped = {}
		seams = BoxMath.Seams(data.SeamCount)
		for index = 1, #seams do
			taped[index] = false
		end
		local animal = Config.Animals.ById[data.AnimalId]
		animalTitle.Text = `Calm your {if animal then animal.DisplayName else "animal"}`
		animalBody.BackgroundColor3 = if animal and animal.Color then animal.Color else Color3.new(1, 1, 1)

		-- Show the 3D model if there is one, looking at its face; otherwise the circle
		if viewportModel then
			viewportModel:Destroy()
			viewportModel = nil
		end
		local model = ModelFit.Spawn("AnimalModels", data.AnimalId, CFrame.identity, 4, nil)
		if model then
			local _, size = model:GetBoundingBox()
			local focus = Vector3.new(0, size.Y / 2, 0)
			local distance = math.max(size.X, size.Y) / 2 / math.tan(math.rad(15)) * 1.05
			-- Models face -Z (see ModelFit), so the camera stands on that side
			viewportCamera.CFrame = CFrame.lookAt(focus + Vector3.new(0, size.Y * 0.08, -distance), focus)
			model.Parent = viewport
			viewportModel = model
		end
		animalBody.BackgroundTransparency = if model then 1 else 0
		bodyStroke.Enabled = model == nil
		face.Visible = model == nil

		for _, frame in spotFrames do
			frame:Destroy()
		end
		spotFrames = {}
		for _, spot in spots do
			local sweet = spot.Kind == "Sweet"
			local frame = Ui.make("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromScale(spot.Radius * 2, spot.Radius * 2),
				BackgroundColor3 = if sweet then PINK else ANGRY,
				BackgroundTransparency = 0.25,
				ZIndex = 4,
			}, animalCard)
			Ui.round(frame, 1000)
			Ui.label(frame, {
				Size = UDim2.fromScale(1, 1),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextScaled = true,
				TextColor3 = Ui.WHITE,
				ZIndex = 5,
				Text = if sweet then "♥" else "✖",
			})
			table.insert(spotFrames, frame)
		end
		drawSeams()
		applyRole(data.Role or "Both")
		help.Text = if role == "Pet"
			then "YOU PET: rub the ♥ spots to keep it calm while your crewmate tapes · Don't touch the ✖ spots"
			elseif
				role == "Tape"
			then "YOU TAPE: drag from dot to dot along each seam while your crewmate keeps it calm"
			else "Rub the ♥ spots · Don't touch the ✖ spots · Drag tape from dot to dot along each seam"

		-- POP! The animal springs up out of the box
		popping = true
		animalCard.Position = ANIMAL_HIDDEN
		local pop = TweenService:Create(
			animalCard,
			TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Position = ANIMAL_HOME }
		)
		pop:Play()
		pop.Completed:Once(function()
			popping = false
		end)
	end

	-- Spots drift around (same math and clock as the server)
	RunService.RenderStepped:Connect(function()
		if not gui.Enabled then
			return
		end
		local t = Workspace:GetServerTimeNow()
		for index, spot in spots do
			local frame = spotFrames[index]
			if frame then
				local p = BoxMath.SpotPosition(spot, start, t)
				frame.Position = UDim2.fromScale(p.X, p.Y)
			end
		end
		-- The 3D animal looks around a little, and squishes happily when petted
		local now = os.clock()
		local squish = if now < squishUntil then math.sin((squishUntil - now) / 0.25 * math.pi) * 0.1 else 0
		local squash = UDim2.fromScale(1 + squish, 1 - squish)
		animalBody.Size = squash
		viewport.Size = squash
		if viewportModel then
			viewportModel:PivotTo(CFrame.Angles(0, math.sin(now * 1.3) * 0.3, math.sin(now * 0.9) * 0.05))
		end
		-- A furious animal trembles and strains to get out of the box
		if not popping then
			local anger = (player:GetAttribute("Anger") :: number?) or 0
			local tremble = if anger >= 75 then 0.012 else 0
			animalCard.Position = ANIMAL_HOME
				+ UDim2.fromScale((math.random() - 0.5) * tremble, (math.random() - 0.5) * tremble)
		end
	end)

	-- Anger meter
	local function refreshAnger()
		local anger = (player:GetAttribute("Anger") :: number?) or 0
		local fraction = math.clamp(anger / 100, 0, 1)
		meterFill.Size = UDim2.fromScale(fraction, 1)
		meterFill.BackgroundColor3 = Ui.GREEN:Lerp(ANGRY, fraction)
		meterText.Text = if anger >= 75 then `ANGER {anger}  - PET IT!!` else `ANGER {anger}`
		face.Text = if anger >= 75 then "ಠ 益 ಠ" elseif anger >= 40 then "¬ _ ¬" else "• ᴥ •"
	end
	player:GetAttributeChangedSignal("Anger"):Connect(refreshAnger)

	-- Mouse / touch
	local function pointerMoved(screen: Vector2)
		if mode == "Pet" then
			local p = toCard(animalCard, screen)
			local rubbing = (screen - lastPoint).Magnitude > 2 -- you have to actually rub, not just hold still
			lastPoint = screen
			local t = Workspace:GetServerTimeNow()
			local now = os.clock()
			for index, spot in spots do
				local center = BoxMath.SpotPosition(spot, start, t)
				if (p - center).Magnitude <= spot.Radius then
					if spot.Kind == "Sweet" and rubbing and now - lastPetSend >= PET_SEND_INTERVAL then
						lastPetSend = now
						input:FireServer("Pet", index)
						floatText("♥", screen, PINK)
						squishUntil = now + 0.25
						Sfx.Play("Purr")
					elseif spot.Kind == "Angry" and now - lastAngrySend >= 0.5 then
						lastAngrySend = now
						input:FireServer("Angry", index)
					end
				end
			end
		elseif mode == "Tape" then
			local p = toCard(boxCard, screen)
			if #path == 0 or (p - path[#path]).Magnitude > 0.01 then
				table.insert(path, p)
			end
			if preview then
				preview:Destroy()
			end
			preview = line(boxCard, path[1], p, 18, TAPE:Lerp(Color3.new(1, 1, 1), 0.3), 6)
		end
	end

	UserInputService.InputBegan:Connect(function(inputObject: InputObject)
		if not gui.Enabled then
			return
		end
		local kind = inputObject.UserInputType
		if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
			return
		end
		local screen = Vector2.new(inputObject.Position.X, inputObject.Position.Y)
		-- The box is in front of the animal's lower half, so check the box first
		if inside(boxCard, screen) then
			if role ~= "Pet" then
				mode = "Tape"
				path = { toCard(boxCard, screen) }
			end
		elseif inside(animalCard, screen) then
			if role ~= "Tape" then
				mode = "Pet"
				lastPoint = screen
			end
		end
	end)

	UserInputService.InputChanged:Connect(function(inputObject: InputObject)
		local kind = inputObject.UserInputType
		if mode and (kind == Enum.UserInputType.MouseMovement or kind == Enum.UserInputType.Touch) then
			pointerMoved(Vector2.new(inputObject.Position.X, inputObject.Position.Y))
		end
	end)

	UserInputService.InputEnded:Connect(function(inputObject: InputObject)
		local kind = inputObject.UserInputType
		if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
			return
		end
		if mode == "Tape" then
			for index, seam in seams do
				if not taped[index] and BoxMath.IsTapeStroke(seam, path) then
					input:FireServer("Tape", index)
					break
				end
			end
		end
		if preview then
			preview:Destroy()
			preview = nil
		end
		mode = nil
		path = {}
	end)

	-- Show the screen only during the BOX stage
	player:GetAttributeChangedSignal("Stage"):Connect(function()
		gui.Enabled = player:GetAttribute("Stage") == "Box"
		if not gui.Enabled then
			mode = nil
		end
	end)

	notify.OnClientEvent:Connect(function(kind: string, data: { [string]: any })
		if kind == "BoxStart" then
			setup(data)
			refreshAnger()
			gui.Enabled = true
		elseif kind == "Role" then
			applyRole(data.Role) -- a crewmate left, so the jobs got reshuffled
			help.Text = `Your job now: {if role == "Both" then "pet AND tape" else string.lower(role)}!`
		elseif kind == "SeamTaped" then
			taped[data.Seam] = true
			drawSeams()
		elseif kind == "Peel" then
			taped[data.Seam] = false
			drawSeams()
			shake(boxCard)
			help.Text = "It peeled a strip of tape off! Re-tape that seam!"
		elseif kind == "AngryTouch" then
			shake(animalCard)
			help.Text = "OW! Not there! Rub the ♥ spots!"
		elseif kind == "Thump" then
			shake(boxCard)
			shake(meterBack)
		elseif kind == "BoxDone" or kind == "Launch" then
			gui.Enabled = false
		end
	end)
end

return BoxingScreen
