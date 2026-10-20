--!strict
-- The shared texture of each imported model pack (KayKit). A whole pack is colored by one small image, so it
-- is uploaded ONCE and every model of the pack uses it (shared/ModelFit.ApplyAtlas). Which models belong to
-- which pack: src/shared/ArtAtlas/<Pack>.json, written by tools/import/kaykit.py.
--
-- How to fill one in (Studio):
--   1. Window → Asset Manager → Images → Bulk Import, and pick the pack's texture
--      (Forest: Textures/forest_texture.png, City: Assets/texture/citybits_texture.png, in the pack's zip)
--   2. Right-click the uploaded image → Copy Asset ID
--   3. Paste it below as "rbxassetid://<the number>"
-- Left empty, the models keep whatever texture the importer gave them.

return {
	Forest = "",
	City = "",
} :: { [string]: string }
