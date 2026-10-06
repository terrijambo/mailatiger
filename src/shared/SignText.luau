--!strict
-- Big, readable text on signs in the world (SurfaceGuis on parts).
-- Roblox's "TextScaled" can shrink sign text to a tiny line (emoji and wide fonts throw its measuring off),
-- so signs work out their own text size instead: from the sign's size in studs and how many letters there
-- are, as big as fits on one line. It also re-fits whenever the text changes (e.g. a countdown).
--
--   SignText.Fit(gui, label, part)       gui is on `part`, label fills `share` of the face (default all of it)

local SignText = {}

-- The size (studs) of the face a SurfaceGui is on
local function faceSize(part: BasePart, face: Enum.NormalId): Vector2
	local s = part.Size
	if face == Enum.NormalId.Front or face == Enum.NormalId.Back then
		return Vector2.new(s.X, s.Y)
	elseif face == Enum.NormalId.Left or face == Enum.NormalId.Right then
		return Vector2.new(s.Z, s.Y)
	end
	return Vector2.new(s.X, s.Z)
end

-- Returns the pixels per stud it picked (for sizing outlines to match)
function SignText.Fit(gui: SurfaceGui, label: TextLabel, part: BasePart): number
	local size = faceSize(part, gui.Face)
	-- About 110 pixels top to bottom, so text can fill the sign (Roblox text tops out at 100 pixels)
	local pixelsPerStud = math.clamp(110 / size.Y, 4, 40)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud
	label.TextScaled = false
	label.TextWrapped = false
	local function fit()
		local width = size.X * pixelsPerStud * label.Size.X.Scale + label.Size.X.Offset
		local height = size.Y * pixelsPerStud * label.Size.Y.Scale + label.Size.Y.Offset
		local text = if label.ContentText ~= "" then label.ContentText else label.Text
		local letters = math.max(1, utf8.len(text) or #text)
		local bySpace = width / (letters * 0.66) -- (bold sign fonts are about 2/3 as wide as tall per letter)
		label.TextSize = math.floor(math.clamp(math.min(height * 0.85, bySpace), 8, 100))
	end
	fit()
	label:GetPropertyChangedSignal("Text"):Connect(fit)
	return pixelsPerStud
end

return SignText
