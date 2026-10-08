--!strict
-- The Post Office machines round the plaza, as YOU see them. The server puts an invisible station at each spot
-- (MapBuilder) and does the work (MachineService); this draws each machine over its station:
--   * one you own: bright, in its own colors, and it works away while it has your parcels (the Stamp Machine
--     stamps, the Postage Scale's needle swings, the Fragile Handler's rollers spin...)
--   * one you don't: a glassy hologram with a sign saying the level it opens at, or its price
-- Its prompt says what holding E will do for you: buy it, drop your parcels in, or collect them, and the sign
-- over it counts down while it works. Machines and their numbers: Config/Machines.luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Profile = require(script.Parent.Profile)

local Machines = Config.Machines
type Machine = typeof(Machines.List[1])

local MachineStations = {}

local GHOST = Color3.fromRGB(196, 214, 236)
local SCALE = 1.4 -- (machines are drawn at this size; 2.1 crowded the plaza)
local METAL = Color3.fromRGB(86, 92, 108)

type Look = {
	Model: Model,
	Moving: { [string]: BasePart }, -- named parts the effects move
	Rest: { [string]: CFrame },
}

-- A part of a machine, placed relative to the station (origin on the belt at the ground, -Z along the belt,
-- +X toward the plaza)
local function piece(
	look: Look,
	base: CFrame,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	props: { [string]: any }?
): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = base * offset
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for key, value in props do
			(p :: any)[key] = value
		end
	end
	p.Parent = look.Model
	return p
end

local function moving(look: Look, p: BasePart)
	look.Moving[p.Name] = p
end

-- Builds a machine's look. owned = false: everything comes out as a see-through grey hologram.
local function build(machine: Machine, station: BasePart, owned: boolean): Look
	local model = Instance.new("Model")
	model.Name = `Machine_{machine.Id}`
	local look: Look = { Model = model, Moving = {}, Rest = {} }
	local base = station.CFrame * CFrame.new(0, -station.Size.Y / 2 + 0.6, 0) -- (on top of its stone base)
	local color = machine.Color
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.35)
	local light = color:Lerp(Color3.new(1, 1, 1), 0.45)
	local neon = { Material = Enum.Material.Neon }

	-- Every machine is an arch the belt runs through: two legs and a housing on top
	for _, side in { -1, 1 } do
		piece(look, base, "Leg", Vector3.new(0.9, 4.6, 3), CFrame.new(side * 2.3, 2.3, 0), METAL)
		piece(look, base, "Foot", Vector3.new(1.4, 0.4, 3.6), CFrame.new(side * 2.3, 0.2, 0), dark)
	end
	piece(look, base, "Housing", Vector3.new(5.6, 1.8, 3.4), CFrame.new(0, 5.3, 0), color)
	piece(look, base, "Trim", Vector3.new(5.8, 0.3, 3.6), CFrame.new(0, 4.4, 0), dark)
	piece(look, base, "Light", Vector3.new(4.6, 0.25, 0.2), CFrame.new(0, 5.3, -1.75), light, neon)
	-- a short belt through the arch, with an in-tray on the plaza side
	piece(look, base, "Belt", Vector3.new(2.6, 0.25, 5), CFrame.new(0, 1.1, 0), Color3.fromRGB(34, 34, 40))
	piece(look, base, "BeltFrame", Vector3.new(3.2, 0.9, 5.2), CFrame.new(0, 0.5, 0), METAL)

	local id = machine.Id
	if id == "Stamp" then
		-- a big stamp that slams down on each parcel
		local plunger = piece(look, base, "Plunger", Vector3.new(2, 1.2, 2), CFrame.new(0, 3.6, 0), dark)
		moving(look, plunger)
		local rod = piece(look, base, "Rod", Vector3.new(0.5, 1, 0.5), CFrame.new(0, 4.4, 0), METAL)
		moving(look, rod)
		piece(look, base, "Handle", Vector3.new(0.4, 1.6, 0.4), CFrame.new(0, 6.9, 0), METAL)
		piece(
			look,
			base,
			"Knob",
			Vector3.new(1, 1, 1),
			CFrame.new(0, 7.9, 0),
			Color3.fromRGB(220, 60, 60),
			{ Shape = Enum.PartType.Ball }
		)
	elseif id == "Scale" then
		-- a dial on the plaza side with a swinging needle
		piece(
			look,
			base,
			"Dial",
			Vector3.new(0.2, 3.2, 3.2),
			CFrame.new(2.9, 5.6, 0) * CFrame.Angles(0, 0, 0),
			Color3.new(1, 1, 1),
			{ Shape = Enum.PartType.Cylinder }
		)
		local needle = piece(
			look,
			base,
			"Needle",
			Vector3.new(0.12, 1.3, 0.2),
			CFrame.new(3.02, 5.6, 0) * CFrame.new(0, 0.55, 0),
			Color3.fromRGB(220, 50, 50),
			neon
		)
		moving(look, needle)
		piece(look, base, "Pan", Vector3.new(3.2, 0.2, 3), CFrame.new(0, 6.3, 0), METAL)
	elseif id == "Fragile" then
		-- two padded rollers that spin as parcels go under
		for _, z in { -0.8, 0.8 } do
			local roller = piece(
				look,
				base,
				`Roller{z}`,
				Vector3.new(4, 1.1, 1.1),
				CFrame.new(0, 3.2, z),
				Color3.fromRGB(200, 230, 255),
				{ Shape = Enum.PartType.Cylinder, Transparency = 0.15 }
			)
			moving(look, roller)
		end
		for k = 1, 6 do
			piece(
				look,
				base,
				"Bubble",
				Vector3.one * 0.6,
				CFrame.new(-2 + k * 0.6, 6.4, math.sin(k) * 0.8),
				Color3.fromRGB(220, 240, 255),
				{ Shape = Enum.PartType.Ball, Transparency = 0.25 }
			)
		end
		piece(look, base, "Sign", Vector3.new(3, 0.8, 0.2), CFrame.new(0, 7.0, 0), Color3.fromRGB(240, 60, 60))
	elseif id == "Sorter" then
		-- a wall of pigeon holes on top
		for row = 0, 1 do
			for col = 0, 3 do
				piece(
					look,
					base,
					"Slot",
					Vector3.new(1.15, 0.9, 0.3),
					CFrame.new(-1.8 + col * 1.2, 6.7 + row * 1, 1.4),
					if (row + col) % 2 == 0 then light else dark
				)
			end
		end
		local arm = piece(
			look,
			base,
			"Arm",
			Vector3.new(0.3, 0.3, 2.6),
			CFrame.new(0, 3.9, 0),
			Color3.fromRGB(250, 220, 60),
			neon
		)
		moving(look, arm)
	elseif id == "Express" then
		-- a lightning bolt and racing stripes
		piece(
			look,
			base,
			"Bolt",
			Vector3.new(0.3, 2.4, 0.9),
			CFrame.new(0, 7.3, 0) * CFrame.Angles(0, 0, 0.5),
			Color3.fromRGB(255, 230, 60),
			neon
		)
		piece(
			look,
			base,
			"Bolt",
			Vector3.new(0.3, 1.6, 0.9),
			CFrame.new(0.5, 6.4, 0) * CFrame.Angles(0, 0, -0.5),
			Color3.fromRGB(255, 230, 60),
			neon
		)
		for _, side in { -1, 1 } do
			piece(
				look,
				base,
				"Stripe",
				Vector3.new(0.2, 4, 0.5),
				CFrame.new(side * 2.8, 2.4, -0.8),
				Color3.fromRGB(255, 230, 60),
				neon
			)
		end
		local flash = piece(
			look,
			base,
			"Flash",
			Vector3.new(2.4, 0.2, 2.6),
			CFrame.new(0, 4.2, 0),
			Color3.fromRGB(255, 250, 200),
			{ Material = Enum.Material.Neon, Transparency = 1 }
		)
		moving(look, flash)
	elseif id == "Drone" then
		-- a landing pad with two little drones bobbing over it
		piece(
			look,
			base,
			"Pad",
			Vector3.new(0.2, 4.2, 3.2),
			CFrame.new(0, 6.3, 0) * CFrame.Angles(0, 0, math.pi / 2),
			dark,
			{ Shape = Enum.PartType.Cylinder }
		)
		for k, x in { -1.1, 1.1 } do
			local drone = piece(
				look,
				base,
				`Drone{k}`,
				Vector3.new(1, 0.5, 1),
				CFrame.new(x, 7.6, 0),
				Color3.fromRGB(240, 240, 250)
			)
			moving(look, drone)
			for _, corner in { { -0.6, -0.6 }, { 0.6, -0.6 }, { -0.6, 0.6 }, { 0.6, 0.6 } } do
				local rotor = piece(
					look,
					base,
					`Rotor{k}`,
					Vector3.new(0.08, 0.7, 0.7),
					CFrame.new(x + corner[1], 7.95, corner[2]) * CFrame.Angles(0, 0, math.pi / 2),
					light,
					{ Shape = Enum.PartType.Cylinder, Transparency = 0.3 }
				)
				local weld = rotor -- (rotors ride along with their drone: see the effects)
				weld:SetAttribute("Drone", k)
				weld:SetAttribute("OffsetX", corner[1])
				weld:SetAttribute("OffsetZ", corner[2])
			end
		end
	elseif id == "Rocket" then
		-- a rocket on its launch tower
		piece(look, base, "Tower", Vector3.new(0.4, 5, 0.4), CFrame.new(-1.6, 8.6, 0), METAL)
		local body = piece(
			look,
			base,
			"RocketBody",
			Vector3.new(1.3, 3.2, 1.3),
			CFrame.new(0, 7.9, 0),
			Color3.fromRGB(240, 240, 245),
			{ Shape = Enum.PartType.Cylinder }
		)
		body.CFrame = base * CFrame.new(0, 7.9, 0) * CFrame.Angles(0, 0, math.pi / 2)
		moving(look, body)
		local nose = piece(
			look,
			base,
			"RocketNose",
			Vector3.new(1.2, 1, 1.2),
			CFrame.new(0, 10, 0),
			Color3.fromRGB(230, 70, 60),
			{ Shape = Enum.PartType.Ball }
		)
		moving(look, nose)
		local flame = piece(
			look,
			base,
			"Flame",
			Vector3.new(0.8, 1.2, 0.8),
			CFrame.new(0, 5.9, 0),
			Color3.fromRGB(255, 160, 40),
			{ Material = Enum.Material.Neon, Transparency = 0.2 }
		)
		moving(look, flame)
	end

	if not owned then
		-- a see-through hologram
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") then
				p.Color = GHOST
				p.Material = Enum.Material.Glass
				p.Transparency = math.max(p.Transparency, 0.55)
			end
		end
	end
	-- grow it from the ground up, then remember where the moving parts rest
	model.WorldPivot = base
	model:ScaleTo(SCALE)
	for name, p in look.Moving do
		look.Rest[name] = p.CFrame
	end
	model.Parent = Workspace
	return look
end

-- The sign over a machine: its name, what it does, and (if you don't own it) its level or price
local function sign(station: BasePart, machine: Machine): (BillboardGui, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = "MachineSign"
	gui.Size = UDim2.fromScale(7, 2.2)
	gui.StudsOffset = Vector3.new(0, 10.5, 0)
	gui.MaxDistance = 110
	gui.LightInfluence = 0
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.5)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.LuckiestGuy
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0
	title.Text = `{machine.Emoji} {string.upper(machine.DisplayName)}`
	title.Parent = gui
	local status = Instance.new("TextLabel")
	status.Size = UDim2.fromScale(1, 0.42)
	status.Position = UDim2.fromScale(0, 0.55)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.FredokaOne
	status.TextScaled = true
	status.TextStrokeTransparency = 0
	status.Text = ""
	status.Parent = gui
	gui.Adornee = station
	gui.Parent = station
	return gui, status
end

-- "x1.5 XP" floating up from one of your parcels as it goes through a machine you own
local function pop(at: Vector3, text: string, color: Color3)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.Position = at
	anchor.Parent = Workspace
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 40)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = gui
	gui.Parent = anchor
	TweenService:Create(anchor, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = at + Vector3.new(0, 4, 0),
	}):Play()
	TweenService:Create(label, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(1.2, function()
		anchor:Destroy()
	end)
end

function MachineStations.Start()
	local map = Workspace:WaitForChild("GrayboxMap")
	local room = map:WaitForChild("Machines", 30)
	if not room then
		return
	end
	task.wait(1) -- (let the stations replicate)
	local notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent

	type Station = {
		Machine: Machine,
		Part: BasePart,
		Prompt: ProximityPrompt?,
		Status: TextLabel,
		Look: Look?,
		Owned: boolean?,
		Busy: number, -- when its working motion last started
		Working: boolean,
		Boxes: { BasePart }, -- your parcels sitting on its belt
	}
	local stations: { Station } = {}
	local byId: { [string]: Station } = {}
	for _, part in room:GetChildren() do
		local id = part:GetAttribute("MachineId")
		local machine = if typeof(id) == "string" then Machines.ById[id] else nil
		if part:IsA("BasePart") and machine then
			local _, status = sign(part, machine)
			local station: Station = {
				Machine = machine,
				Part = part,
				Prompt = part:FindFirstChild("UsePrompt") :: ProximityPrompt?,
				Status = status,
				Busy = 0,
				Working = false,
				Boxes = {},
			}
			table.insert(stations, station)
			byId[machine.Id] = station
		end
	end

	-- Little parcels on a machine's belt while it has yours
	local function showBoxes(station: Station, count: number)
		local want = math.min(count, 4)
		while #station.Boxes > want do
			local box = table.remove(station.Boxes)
			if box then
				box:Destroy()
			end
		end
		local base = station.Part.CFrame * CFrame.new(0, -station.Part.Size.Y / 2 + 0.6, 0)
		while #station.Boxes < want do
			local i = #station.Boxes
			local box = Instance.new("Part")
			box.Name = "WaitingParcel"
			box.Anchored = true
			box.CanCollide = false
			box.CanQuery = false
			box.Size = Vector3.one * 1.2
			box.Color = Color3.fromRGB(198, 156, 109)
			box.CFrame = base * CFrame.new(0, 1.23 * SCALE + 0.6, (i - 1.5) * 1.3)
			box.Parent = Workspace
			table.insert(station.Boxes, box)
		end
	end

	-- Words, signs and looks for every machine (from your saved progress, and the clock while one works)
	local function refresh()
		local data = Profile.Get()
		local owned = data.Machines or {}
		local processing = data.Processing or {}
		local level = data.Level or 1
		local now = Workspace:GetServerTimeNow()
		for _, station in stations do
			local machine = station.Machine
			local has = owned[machine.Id] == true
			if station.Owned ~= has or not station.Look then
				if station.Look then
					station.Look.Model:Destroy()
				end
				station.Look = build(machine, station.Part, has)
				station.Owned = has
			end
			local prompt = station.Prompt
			local batch = processing[machine.Id]
			local status, color, action
			station.Working = false
			if batch then
				local left = math.ceil(batch.ReadyAt - now)
				local count = #batch.Parcels
				showBoxes(station, count)
				if left > 0 then
					station.Working = true
					status, color = `⏳ WORKING... {left}s`, Color3.fromRGB(255, 220, 80)
					action = `Working ({left}s)`
				else
					status, color =
						`✅ READY: {count} PARCEL{if count == 1 then "" else "S"}`, Color3.fromRGB(120, 255, 140)
					action = `Collect {count} parcel{if count == 1 then "" else "s"}`
				end
			elseif has then
				showBoxes(station, 0)
				local waiting = 0
				for _, parcel in data.Parcels do
					if not (parcel.Machines and parcel.Machines[machine.Id]) then
						waiting += 1
					end
				end
				status, color = `x{string.format("%g", machine.XPMult)} XP PER PARCEL`, Color3.fromRGB(255, 255, 255)
				action = if waiting > 0
					then `Drop in {waiting} parcel{if waiting == 1 then "" else "s"}`
					else "Nothing to stamp"
			elseif level < machine.Level then
				showBoxes(station, 0)
				status, color = `🔒 LEVEL {machine.Level}`, Color3.fromRGB(200, 210, 230)
				action = `Opens at Level {machine.Level}`
			else
				showBoxes(station, 0)
				local price = Machines.Price(machine)
				status = `BUY: {Format.Short(price)}  (x{string.format("%g", machine.XPMult)} XP)`
				color = if data.Coins >= price then Color3.fromRGB(255, 220, 80) else Color3.fromRGB(255, 140, 120)
				action = `Buy ({Format.Short(price)})`
			end
			station.Status.Text = status
			station.Status.TextColor3 = color
			if prompt then
				prompt.ActionText = action
			end
		end
	end
	Profile.Watch(refresh)
	refresh()
	task.spawn(function()
		while true do
			task.wait(0.5)
			refresh() -- (the countdowns)
		end
	end)

	notify.OnClientEvent:Connect(function(kind: string, data: any)
		local station = if type(data) == "table" and data.Id then byId[data.Id] else nil
		if not station then
			return
		end
		local top = station.Part.Position + Vector3.new(0, 7, 0)
		if kind == "MachineReady" then
			pop(top, "READY!", Color3.fromRGB(120, 255, 140))
		elseif kind == "MachineCollected" and (data.Count or 0) > 0 then
			pop(
				top,
				`x{string.format("%g", data.XPMult or 1)} XP STAMPED!`,
				station.Machine.Color:Lerp(Color3.new(1, 1, 1), 0.3)
			)
		elseif kind == "MachineStarted" then
			station.Busy = os.clock()
		end
	end)

	-- Motion: owned machines idle (drones bob, the rocket's flame flickers) and work while they have parcels
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for _, station in stations do
			local look = station.Look
			if not (look and station.Owned) then
				continue
			end
			if station.Working and now - station.Busy > 0.8 then
				station.Busy = now
			end
			local machine = station.Machine
			local t = now - station.Busy
			-- idle motion
			if machine.Id == "Drone" then
				for k = 1, 2 do
					local drone = look.Moving[`Drone{k}`]
					local rest = look.Rest[`Drone{k}`]
					if drone and rest then
						drone.CFrame = rest * CFrame.new(0, math.sin(now * 3 + k) * 0.3, 0)
					end
				end
				for _, p in look.Model:GetChildren() do
					local k = p:GetAttribute("Drone")
					local drone = if typeof(k) == "number" then look.Moving[`Drone{k}`] else nil
					if drone and p:IsA("BasePart") then
						p.CFrame = drone.CFrame
							* CFrame.new(
								(p:GetAttribute("OffsetX") :: number) * SCALE,
								0.35 * SCALE,
								(p:GetAttribute("OffsetZ") :: number) * SCALE
							)
							* CFrame.Angles(0, now * 30, math.pi / 2)
					end
				end
			elseif machine.Id == "Rocket" then
				local flame = look.Moving.Flame
				local rest = look.Rest.Flame
				if flame and rest then
					flame.CFrame = rest * CFrame.new(0, 0, 0)
					flame.Size = Vector3.new(0.8, 1 + math.abs(math.sin(now * 20)) * 0.6, 0.8) * SCALE
				end
			end
			-- a parcel's effect, for a moment after one passed
			if t < 0.5 then
				local k = math.sin(t / 0.5 * math.pi)
				if machine.Id == "Stamp" then
					for _, name in { "Plunger", "Rod" } do
						local p, rest = look.Moving[name], look.Rest[name]
						if p and rest then
							p.CFrame = rest * CFrame.new(0, -1.3 * SCALE * k, 0)
						end
					end
				elseif machine.Id == "Scale" then
					local p, rest = look.Moving.Needle, look.Rest.Needle
					if p and rest then
						p.CFrame = rest
							* CFrame.new(0, -0.55 * SCALE, 0)
							* CFrame.Angles(k * 1.4, 0, 0)
							* CFrame.new(0, 0.55 * SCALE, 0)
					end
				elseif machine.Id == "Fragile" then
					for name, p in look.Moving do
						local rest = look.Rest[name]
						if string.find(name, "Roller", 1, true) and rest then
							p.CFrame = rest * CFrame.Angles(t * 25, 0, 0)
						end
					end
				elseif machine.Id == "Sorter" then
					local p, rest = look.Moving.Arm, look.Rest.Arm
					if p and rest then
						p.CFrame = rest * CFrame.Angles(0, k * 1.2, 0)
					end
				elseif machine.Id == "Express" then
					local p = look.Moving.Flash
					if p then
						p.Transparency = 1 - k * 0.8
					end
				elseif machine.Id == "Rocket" then
					for _, name in { "RocketBody", "RocketNose" } do
						local p, rest = look.Moving[name], look.Rest[name]
						if p and rest then
							p.CFrame = rest + Vector3.new(0, k * 1.5 * SCALE, 0)
						end
					end
				end
			end
		end
	end)
end

return MachineStations
