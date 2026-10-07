--!strict
-- The image ids of the UI icon sprite sheets (art/ui_atlas/icons_sheet_1.png, _2, ...), in order.
-- Until a sheet's id is here, the icons on it show as emoji instead, so nothing looks broken.
--
-- HOW: in Studio open View -> Asset Manager -> Bulk Import, pick the sheet PNGs, then right-click each
-- uploaded image -> Copy ID to Clipboard, and paste it below as "rbxassetid://THE_NUMBER".
-- (Made with tools/pack_icons.py from art/ui_icons. A single Image in Config/Icons.luau still wins over
-- the sheet, if you ever want to swap one icon without re-packing.)

return {
	"rbxassetid://84623444085843", -- icons_sheet_1.png
	"rbxassetid://139025452598007", -- icons_sheet_2.png
	"rbxassetid://134256527637959", -- icons_sheet_3.png
	"rbxassetid://83772096277078", -- icons_sheet_4.png
	"rbxassetid://92610855396781", -- icons_sheet_5.png (animals)
	"rbxassetid://107127042838804", -- icons_sheet_6.png (animals, upgrades)
	"rbxassetid://140060988191617", -- icons_sheet_7.png (upgrades, zones)
	"rbxassetid://116182107896753", -- icons_sheet_8.png (MENU, MENU with "!", TRAVEL, Gruff)
} :: { string }
