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
- Low-poly and flat-shaded. Colors are plain materials. **Roblox's importer drops those colors**, so each script also writes `src/shared/ArtColors/<Name>.json`, and the game paints each part by name when it spawns the model (`ModelFit.Paint`). Keep part names the same if you edit a model by hand, or add the new names to its JSON.
- Name the export after the game's id: animals use the animal Id (`Hamster`, `Tiger`...), boxes use the box Id (`Cardboard`, `Wood`, `Steel`, `Vault`).

The game resizes and re-centers imported models itself (`src/server/ModelFit.luau`), so the exact import scale doesn't matter.

## Rebuild a model from its script
```
"E:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup --python art/blender_scripts/hamster.py
```
This overwrites the `.blend`, `.fbx`, color file and preview for that model. **If you've hand-edited the `.blend`, export from Blender yourself instead** (File → Export → FBX with the settings in `common.py`), or your edits get replaced.

## Get it into the game
See "Adding your Blender models" in the main [README](../README.md).

## Models
**All 75 models are built.** The full list, by category, is in [MODEL_LIST.md](MODEL_LIST.md): 25 animals,
4 boxes, 2 characters, 13 town pieces, 19 arena props, 5 gameplay props, 3 chute upgrades and 4 tools.

| Script | Builds |
|---|---|
| `hamster.py` | Hamster |
| `cardboard_box.py` | Cardboard |
| `animals.py` | The other 24 animals |
| `boxes.py` | Wood, Steel, Vault |
| `characters.py` | Gruff, GruffHat |
| `town.py` | Post office, counters, chute, boards, pads, street decoration |
| `arenas.py` | Arena gate and the props for each arena |
| `props.py` | Egg, tape roll, stamp, envelope, parcel, and the four shop tools |
| `chutes.py` | The three mail chute upgrades |

Multi-model scripts can rebuild just some models: add `-- Name1 Name2` to the end of the command.

## Review a batch at a glance
```
python art/contact_sheet.py sheet.png Tiger Bear Gorilla
```
This puts the previews side by side with their names.
