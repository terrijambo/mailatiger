"""Puts every hero model (art/export/hero/MA_*.fbx) into ONE file, art/export/hero/MA_all.fbx, so getting all of them
into Studio is a single import (then tools/import/split_pack.luau makes one Model per hero).

    "E:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" --background --factory-startup
        --python tools/blender/combine_heroes.py

Each hero keeps its parts' names (MA_Fountain__Stone, MA_Fountain__Water...), all at the origin.
"""

import glob
import os

import bpy

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FOLDER = os.path.join(ROOT, "art", "export", "hero")

bpy.ops.wm.read_factory_settings(use_empty=True)
files = sorted(f for f in glob.glob(os.path.join(FOLDER, "MA_*.fbx")) if not f.endswith("MA_all.fbx"))
for path in files:
    bpy.ops.import_scene.fbx(filepath=path)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in bpy.context.scene.objects:
    o.select_set(o.type == "MESH")
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.export_scene.fbx(
    filepath=os.path.join(FOLDER, "MA_all.fbx"),
    use_selection=True,
    object_types={"MESH"},
    mesh_smooth_type="FACE",
    apply_scale_options="FBX_SCALE_ALL",
    axis_forward="-Z",
    axis_up="Y",
    add_leaf_bones=False,
    path_mode="STRIP",
    embed_textures=False,
)
print(f"HEROES_DONE {len(files)} models, {len(meshes)} parts -> MA_all.fbx")
