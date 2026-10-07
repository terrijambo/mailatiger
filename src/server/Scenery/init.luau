--!strict
-- Everything in the world that's just for looks, laid out from src/shared/Config/World.luau: the sea, the
-- islands with their cliffs, the wooden bridges, the town plaza, each zone's themed island, the beach, the
-- volcano where the boss lands, and a big floating name over every island.
-- Gameplay pieces (the play areas, counters, pads) are built in MapBuilder, which calls Scenery.Build.
--   Kit       the toolkit: colors, trees, rocks, lamps, benches, cottages, signs
--   Islands   the sea, the island shapes and cliffs, the bridges
--   Town      the plaza, the fountain, the paths and arches, the green ring
--   Zones     the five zone islands
--   Beach     the beach island
--   Volcano   the boss island

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Beach = require(script.Beach)
local Islands = require(script.Islands)
local Town = require(script.Town)
local Volcano = require(script.Volcano)
local Zones = require(script.Zones)

local World = Config.World

local Scenery = {}

export type Zone = Zones.Zone

export type Layout = {
	Zones: { Zone },
	Keep: { { number } }, -- spots in town to keep clear: { x, z, radius }
}

-- A big name floating over an island, readable from far away (like the labels on a game map)
local function islandName(island: Islands.Island, title: string, subtitle: string, color: Color3, height: number)
	local anchor = Instance.new("Part")
	anchor.Name = "IslandName"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = island.Center + Vector3.new(0, height, 0)
	anchor.Parent = island.Folder
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(46, 14) -- (in studs: it shrinks with distance like a real sign)
	gui.LightInfluence = 0
	gui.MaxDistance = 900
	gui.Parent = anchor
	local name = Instance.new("TextLabel")
	name.Size = UDim2.fromScale(1, 0.62)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.LuckiestGuy
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.Text = title
	name.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = color:Lerp(Color3.new(0, 0, 0), 0.55)
	stroke.Parent = name
	if subtitle ~= "" then
		local pill = Instance.new("Frame")
		pill.AnchorPoint = Vector2.new(0.5, 0)
		pill.Position = UDim2.fromScale(0.5, 0.66)
		pill.Size = UDim2.fromScale(0.36, 0.32)
		pill.BackgroundColor3 = color
		pill.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = pill
		local border = Instance.new("UIStroke")
		border.Thickness = 3
		border.Color = Color3.new(1, 1, 1)
		border.Parent = pill
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(0.9, 0.8)
		label.Position = UDim2.fromScale(0.05, 0.1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.LuckiestGuy
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = subtitle
		label.Parent = pill
	end
end

function Scenery.Build(parent: Instance, layout: Layout)
	local folder = Instance.new("Folder")
	folder.Name = "Scenery"
	folder.Parent = parent

	local all = { { Center = World.Town.Center, Radius = World.Town.Radius } }
	for _, island in World.Islands do
		table.insert(all, { Center = island.Center, Radius = island.Radius })
	end
	Islands.Sea(all)

	-- The islands
	local town = Islands.Island(folder, {
		Id = "TownIsland",
		Center = World.Town.Center,
		Radius = World.Town.Radius,
		Seed = 1,
		Ground = World.Town.Ground,
	})
	local built: { [string]: Islands.Island } = {}
	for _, spec in World.Islands do
		local id = spec.Id
		built[id] = Islands.Island(folder, {
			Id = `{id}Island`,
			Center = spec.Center,
			Radius = spec.Radius,
			Seed = spec.Seed,
			Ground = spec.Ground,
			GroundMaterial = if id == "Jungle" then Enum.Material.SmoothPlastic else nil,
			Shore = id == "Beach",
			CliffColors = if id == "Boss"
				then { Color3.fromRGB(62, 56, 58), Color3.fromRGB(74, 66, 66), Color3.fromRGB(54, 50, 54) }
				elseif id == "IceRink" then {
					Color3.fromRGB(176, 196, 214),
					Color3.fromRGB(196, 214, 230),
					Color3.fromRGB(160, 182, 204),
				}
				else nil,
			CliffDark = if id == "Boss"
				then { Color3.fromRGB(40, 36, 38), Color3.fromRGB(48, 42, 44) }
				elseif id == "IceRink" then { Color3.fromRGB(120, 146, 170), Color3.fromRGB(110, 134, 160) }
				else nil,
		})
	end

	-- Bridges (and what the town's arches say about where each one goes)
	local destinations: { Town.Destination } = {}
	local bridgeEnds: { [string]: Vector3 } = {}
	for _, spec in World.Islands do
		local from, to = World.Bridge(spec)
		Islands.Bridge(folder, from, to, spec.Id)
		bridgeEnds[spec.Id] = to
		local def = Config.Arenas.ById[spec.Id]
		local zone: Zone? = nil
		for _, z in layout.Zones do
			if z.Id == spec.Id then
				zone = z
			end
		end
		local title, subtitle, color
		if spec.Id == "Boss" then
			title, subtitle, color = "⚔️ BOSS ARENA", "EVERY HOUR", Color3.fromRGB(200, 40, 40)
		elseif spec.Id == "Beach" then
			title, subtitle, color = "🏖️ BEACH", "", Color3.fromRGB(60, 170, 230)
		elseif def and zone then
			local level = Config.Levels.ZoneLevels[spec.Id] or 1
			title, subtitle, color = `{zone.Icon} {string.upper(def.DisplayName)}`, `LEVEL {level}`, def.Color
		end
		if title then
			if spec.BridgeFrom == nil then
				table.insert(
					destinations,
					{ Id = spec.Id, Name = title, Subtitle = subtitle, Color = color, From = from, To = to }
				)
			else
				-- (a bridge from another island gets its arch over there)
				local along = Vector3.new(to.X - from.X, 0, to.Z - from.Z).Unit
				Town.Arch(built[spec.BridgeFrom].Folder, from - along * 3, along, title, subtitle, color)
			end
			islandName(built[spec.Id], title, subtitle, color, if spec.Id == "Rooftop" then 110 else 60)
		end
	end

	Town.Build(folder, town, destinations, layout.Keep)
	for _, zone in layout.Zones do
		local island = built[zone.Id]
		if island then
			Zones.Build(island, zone, bridgeEnds[zone.Id])
		end
	end
	Beach.Build(built.Beach, bridgeEnds.Beach)
	Volcano.Build(built.Boss, bridgeEnds.Boss)

	-- A sky with a bit of drama (only if you haven't added your own)
	if not Lighting:FindFirstChildOfClass("Sky") then
		local sky = Instance.new("Sky")
		sky.SunAngularSize = 14
		sky.Parent = Lighting
	end
end

return Scenery
