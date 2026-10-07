--!strict
-- How the boss arena looks (BossService runs the fight; this only dresses the stage):
--   * stands around three sides, packed with a cheering crowd of little postal workers (the client makes
--     them bounce: see client/BossLook.luau), floodlights on the corners, and giant stamp banners
--   * a scoreboard over the entrance that shows the fight live
--   * a themed floor for each boss, built when it lands and cleared after: jungle ruins for the Tiger, ice
--     and snow drifts for the Yeti, black rock and glowing lava cracks for the Dragon
-- Everything is plain parts, so no extra art is needed.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SignText = require(ReplicatedStorage.Shared.SignText)

local BossArena = {}

local banners: { TextLabel } = {}
local scoreboard: TextLabel? = nil
local themeFolder: Folder? = nil

local function block(
	parent: Instance,
	name: string,
	cframe: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function sign(part: BasePart, face: Enum.NormalId, text: string, color: Color3): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.92, 0.84)
	label.Position = UDim2.fromScale(0.04, 0.08)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.LuckiestGuy
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = gui
	SignText.Fit(gui, label, part)
	gui.Parent = part
	return label
end

-- A little postal worker for the stands: a body, a head and a blue cap
local CROWD_SHIRTS = {
	Color3.fromRGB(70, 120, 225),
	Color3.fromRGB(226, 72, 66),
	Color3.fromRGB(255, 200, 60),
	Color3.fromRGB(110, 200, 120),
	Color3.fromRGB(240, 240, 245),
}
local function fan(parent: Instance, at: CFrame, index: number)
	local model = Instance.new("Model")
	model.Name = "Fan"
	local body = block(
		model,
		"Body",
		at * CFrame.new(0, 1.2, 0),
		Vector3.new(1.6, 2.4, 1),
		CROWD_SHIRTS[index % #CROWD_SHIRTS + 1]
	)
	local head =
		block(model, "Head", at * CFrame.new(0, 3, 0), Vector3.new(1.4, 1.4, 1.4), Color3.fromRGB(255, 205, 160))
	head.Shape = Enum.PartType.Ball
	block(model, "Cap", at * CFrame.new(0, 3.75, 0), Vector3.new(1.5, 0.4, 1.5), Color3.fromRGB(40, 70, 160))
	for _, part in model:GetChildren() do
		(part :: BasePart).CanCollide = false
	end
	model.PrimaryPart = body
	model:SetAttribute("Seed", index)
	model.Parent = parent
	CollectionService:AddTag(model, "BossCrowd")
end

-- The permanent dressing: stands, crowd, floodlights, banners, the scoreboard and the Boss Hunters board.
-- Returns the part the Boss Hunters leaderboard is drawn on (its +X face looks into the arena).
function BossArena.Build(parent: Instance, center: Vector3, size: number, entrance: Vector3): BasePart
	local half = size / 2
	local steps = 4
	local across = Vector3.new(0, 1, 0):Cross(entrance)
	-- Stands on the three sides away from the way in
	for _, out in { -entrance, across, -across } do
		local facing = CFrame.lookAt(center, center - out) -- looking from the stands toward the middle
		for step = 1, steps do
			local distance = half + 2 + (step - 0.5) * 4
			local height = step * 3
			local frame = CFrame.new(center + out * distance + Vector3.new(0, height / 2 - 1, 0))
				* (facing - facing.Position)
			block(
				parent,
				"Stand",
				frame,
				Vector3.new(size + 2 * (step * 4 + 2), height + 2, 4),
				if step % 2 == 0 then Color3.fromRGB(70, 120, 225) else Color3.fromRGB(226, 72, 66)
			)
			-- A row of fans on each step
			local seatCF = CFrame.new(center + out * distance + Vector3.new(0, height, 0)) * (facing - facing.Position)
			for i = -6, 6 do
				fan(parent, seatCF * CFrame.new(i * 7 + (step % 2) * 3.5, 0, 0), step * 20 + i)
			end
		end
		-- A giant stamp banner above the back row
		local bannerCF = CFrame.new(center + out * (half + 2 + steps * 4 + 1) + Vector3.new(0, steps * 3 + 12, 0))
			* (facing - facing.Position)
		local banner = block(parent, "Banner", bannerCF, Vector3.new(44, 12, 1), Color3.fromRGB(250, 245, 230))
		local stroke = Instance.new("SelectionBox")
		stroke.Adornee = banner
		stroke.Color3 = Color3.fromRGB(200, 40, 40)
		stroke.LineThickness = 0.4
		stroke.Parent = banner
		table.insert(banners, sign(banner, Enum.NormalId.Front, "THE BIG ONE", Color3.fromRGB(210, 40, 40)))
		for _, x in { -24, 24 } do
			block(
				parent,
				"BannerPole",
				bannerCF * CFrame.new(x, -8, 0.8),
				Vector3.new(1, 28, 1),
				Color3.fromRGB(60, 60, 70)
			)
		end
	end
	-- Floodlights on the four corners (the client sweeps them around during a fight)
	for _, corner in { Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, -1) } do
		local base = center + corner * (half + 6)
		block(
			parent,
			"LightPole",
			CFrame.new(base + Vector3.new(0, 14, 0)),
			Vector3.new(1.5, 28, 1.5),
			Color3.fromRGB(60, 60, 70)
		)
		local lamp = block(
			parent,
			"Floodlight",
			CFrame.lookAt(base + Vector3.new(0, 28, 0), center),
			Vector3.new(4, 3, 2),
			Color3.fromRGB(255, 250, 220),
			Enum.Material.Neon
		)
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Front
		light.Range = 60
		light.Angle = 35
		light.Brightness = 3
		light.Enabled = false
		light.Parent = lamp
		CollectionService:AddTag(lamp, "BossFloodlight")
	end
	-- The scoreboard over the way in
	local boardCF =
		CFrame.lookAt(center + entrance * (half - 2) + Vector3.new(0, 26, 0), center + Vector3.new(0, 26, 0))
	local board = block(parent, "Scoreboard", boardCF, Vector3.new(36, 14, 2), Color3.fromRGB(25, 25, 35))
	for _, x in { -16, 16 } do
		block(
			parent,
			"ScoreboardPost",
			boardCF * CFrame.new(x, -16, 0),
			Vector3.new(1.5, 20, 1.5),
			Color3.fromRGB(60, 60, 70)
		)
	end
	local label = sign(board, Enum.NormalId.Front, "NEXT BOSS: ON THE HOUR", Color3.fromRGB(255, 220, 90))
	label.Font = Enum.Font.FredokaOne
	scoreboard = label

	-- The Boss Hunters board, on one side near the way in, facing into the arena (LeaderboardService draws on
	-- its Right face, so its right points inward)
	local inward = across
	local hunterAt = center - across * (half - 4) + entrance * (half - 22)
	local turned = CFrame.fromMatrix(Vector3.zero, inward, Vector3.yAxis)
	block(
		parent,
		"HunterBoardStand",
		CFrame.new(hunterAt + Vector3.new(0, 6.5, 0) - inward * 0.8) * turned,
		Vector3.new(1, 13, 12),
		Color3.fromRGB(150, 25, 35)
	)
	return block(
		parent,
		"HunterBoard",
		CFrame.new(hunterAt + Vector3.new(0, 7, 0)) * turned,
		Vector3.new(0.2, 10, 10),
		Color3.fromRGB(30, 40, 80)
	)
end

function BossArena.SetBanners(text: string)
	for _, label in banners do
		label.Text = text
	end
end

function BossArena.SetScoreboard(text: string)
	if scoreboard then
		scoreboard.Text = text
	end
end

-- The floor dressing for one boss (built when it lands, cleared after the fight). Kept near the rim and in
-- the corners, so it never gets in the way of the fight.
function BossArena.Theme(parent: Instance, center: Vector3, size: number, animalId: string)
	BossArena.ClearTheme()
	local folder = Instance.new("Folder")
	folder.Name = "BossTheme"
	folder.Parent = parent
	themeFolder = folder
	local half = size / 2
	local random = Random.new(42)
	local function patch(color: Color3, material: Enum.Material?, count: number, height: number)
		for _ = 1, count do
			local x, z = random:NextNumber(-half + 6, half - 6), random:NextNumber(-half + 6, half - 6)
			local w = random:NextNumber(6, 14)
			block(
				folder,
				"Patch",
				CFrame.new(center + Vector3.new(x, height, z)) * CFrame.Angles(0, random:NextNumber(0, 6.28), 0),
				Vector3.new(w, 0.1, w * random:NextNumber(0.4, 1)),
				color,
				material
			).CanCollide =
				false
		end
	end
	local corners = { Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, -1) }
	if animalId == "Tiger" then
		-- Jungle ruins: cracked stone tiles, broken pillars in the corners, vines on the rim
		patch(Color3.fromRGB(150, 150, 140), Enum.Material.Slate, 14, 0.06)
		for _, corner in corners do
			local at = center + corner * (half - 5)
			block(
				folder,
				"RuinPillar",
				CFrame.new(at + Vector3.new(0, 5, 0)),
				Vector3.new(4, 10, 4),
				Color3.fromRGB(160, 155, 140),
				Enum.Material.Slate
			)
			block(
				folder,
				"Vine",
				CFrame.new(at + Vector3.new(0, 6, 2.1)),
				Vector3.new(1, 9, 0.3),
				Color3.fromRGB(60, 150, 60)
			)
		end
	elseif animalId == "Yeti" then
		-- Ice: shiny ice sheets and snow drifts in the corners
		patch(Color3.fromRGB(190, 225, 245), Enum.Material.Ice, 16, 0.06)
		for _, corner in corners do
			local drift = block(
				folder,
				"SnowDrift",
				CFrame.new(center + corner * (half - 6) + Vector3.new(0, -2, 0)),
				Vector3.new(14, 14, 14),
				Color3.fromRGB(248, 250, 255)
			)
			drift.Shape = Enum.PartType.Ball
		end
	elseif animalId == "Dragon" then
		-- Volcano: black rock and glowing lava cracks
		patch(Color3.fromRGB(55, 50, 55), Enum.Material.Basalt, 16, 0.06)
		for _ = 1, 12 do
			local x, z = random:NextNumber(-half + 8, half - 8), random:NextNumber(-half + 8, half - 8)
			local crack = block(
				folder,
				"LavaCrack",
				CFrame.new(center + Vector3.new(x, 0.09, z)) * CFrame.Angles(0, random:NextNumber(0, 6.28), 0),
				Vector3.new(random:NextNumber(6, 12), 0.1, 0.6),
				Color3.fromRGB(255, 120, 30),
				Enum.Material.Neon
			)
			crack.CanCollide = false
		end
		for _, corner in corners do
			block(
				folder,
				"VolcanoRock",
				CFrame.new(center + corner * (half - 5) + Vector3.new(0, 3, 0))
					* CFrame.Angles(0.2, random:NextNumber(0, 6.28), 0.15),
				Vector3.new(7, 6, 6),
				Color3.fromRGB(45, 40, 45),
				Enum.Material.Basalt
			)
		end
	end
end

function BossArena.ClearTheme()
	if themeFolder then
		themeFolder:Destroy()
		themeFolder = nil
	end
end

-- The red archway in the plaza that takes you to the arena (built around the BOSS pad)
function BossArena.Arch(pad: BasePart)
	local at = pad.CFrame
	for _, x in { -6.5, 6.5 } do
		block(pad, "ArchPillar", at * CFrame.new(x, 7, 0), Vector3.new(1.6, 14, 1.6), Color3.fromRGB(200, 40, 40))
	end
	local beam =
		block(pad, "ArchTop", at * CFrame.new(0, 14.5, 0), Vector3.new(15, 2.4, 2), Color3.fromRGB(200, 40, 40))
	sign(beam, Enum.NormalId.Back, "⚔️ BOSS ⚔️", Color3.fromRGB(255, 220, 90))
	sign(beam, Enum.NormalId.Front, "⚔️ BOSS ⚔️", Color3.fromRGB(255, 220, 90))
	for _, part in pad:GetChildren() do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end
end

return BossArena
