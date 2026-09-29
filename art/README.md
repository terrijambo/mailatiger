# Art

Low-poly models for Mail a Tiger, built with Blender 5.2.

| Folder | What's in it |
|---|---|
| `blender_scripts/` | Python scripts that build each model from scratch (`common.py` holds the shared helpers) |
| `models/` | Editable `.blend` files. Open these in Blender to tweak by hand |
| `export/` | `.fbx` files to import into Roblox Studio |
| `previews/` | Quick renders so you can see a model without opening Blender |

## Conventions (so models drop straight into the game)
- **1 Blender unit = 1 stud.** The model stands on the ground at the origin (0, 0, 0).
- The model **faces -Y**, toward you in Blender's Front view (numpad 1).
- **One object per color**, named for what it is (Body, Belly, Eyes...). Roblox imports each as its own MeshPart.
- Low-poly and flat-shaded. Colors are plain materials (no textures yet).
- Name the export after the game's id: animals use the animal Id (`Hamster`, `Tiger`...), boxes use the box Id (`Cardboard`, `Wood`, `Steel`, `Vault`).

The game resizes and re-centers imported models itself (`src/server/ModelFit.luau`), so the exact import scale doesn't matter.

## Rebuild a model from its script
```
"E:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup --python art/blender_scripts/hamster.py
```
This overwrites the `.blend`, `.fbx` and preview for that model. **If you've hand-edited the `.blend`, export from Blender yourself instead** (File → Export → FBX with the settings in `common.py`), or your edits get replaced.

## Get it into the game
See "Adding your Blender models" in the main [README](../README.md).

## Models
| Model | Script | Status |
|---|---|---|
| Hamster | `hamster.py` | Pipeline test. Round body, cream belly and cheeks, pink ears, nose and paws |
| Cardboard box | `cardboard_box.py` | Pipeline test. Open 3×3×3 box with four flaps folded out |
