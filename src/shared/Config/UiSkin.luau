--!strict
-- The painted look of windows and buttons (made with ForgeGUI, packed into art/ui_skins/ui_skin_sheet.png).
-- Until Sheet has an id, the UI keeps its plain drawn look, so nothing ever shows up blank.
--
-- Each part is a cut-out of the sheet (Offset and Size in sheet pixels). Slice is the stretchy middle for
-- 9-slicing: the corners outside it keep their shape whatever size the window or button is.
-- FitHeight: the part is scaled to the height it's drawn at (buttons and title bars keep their bevel).

export type Part = {
	Offset: Vector2,
	Size: Vector2,
	Slice: { number }?, -- left, top, right, bottom
	SliceScale: number?,
	FitHeight: boolean?,
}

return {
	Sheet = "rbxassetid://120764229448606", -- "" turns the painted look off

	Parts = {
		-- Cream paper window with a cardboard bottom edge and stamp-perforation corners
		Panel = {
			Offset = Vector2.new(0, 0),
			Size = Vector2.new(384, 236),
			Slice = { 56, 56, 328, 180 },
			SliceScale = 1.2,
		},
		-- Title bar plaque (white, tinted to the window's color)
		Ribbon = {
			Offset = Vector2.new(392, 0),
			Size = Vector2.new(384, 85),
			Slice = { 44, 38, 340, 44 },
			FitHeight = true,
		},
		-- Glossy button (white, tinted to the button's color)
		Button = {
			Offset = Vector2.new(392, 100),
			Size = Vector2.new(256, 91),
			Slice = { 46, 40, 210, 46 },
			FitHeight = true,
		},
		-- Square side-button tile (white, tinted)
		Tile = {
			Offset = Vector2.new(784, 0),
			Size = Vector2.new(160, 158),
		},
		-- Red X close button
		Close = {
			Offset = Vector2.new(656, 100),
			Size = Vector2.new(128, 128),
		},
	} :: { [string]: Part },
}
