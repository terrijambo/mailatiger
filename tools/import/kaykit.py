"""Turns a KayKit pack (or any glTF pack that shares one texture) into FBX files ready for Roblox Studio.

    "E:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" --background --factory-startup
        --python tools/import/kaykit.py -- <pack's Assets/gltf folder> <PackName>

For every model in the folder it:
  * joins it into ONE mesh (one MeshPart in Roblox: cheapest to draw), keeping its texture coordinates
  * puts its pivot at the bottom center, facing -Y (the art/ convention: Roblox imports it facing -Z)
  * names it <PackName>_<Model> in PascalCase (Forest_Bush1A, City_BuildingA), so it never collides with the
    game's own model names; MapBuilder / Scenery pick which one to use in Phase 3
  * exports art/export/kaykit/<PackName>/<Name>.fbx WITHOUT the texture: the pack's single texture is uploaded
    once and ModelFit puts it on every model of the pack (Config/Atlases.luau)

It also writes:
  * src/shared/ArtAtlas/<PackName>.json   which models use which texture (read by ModelFit.Paint)
  * art/export/kaykit/<PackName>/manifest.csv   name, size in studs, triangles
  * art/export/kaykit/<PackName>_sheet.png      every model in a grid, to pick from (1 unit = 1 stud)
  * art/export/kaykit/<PackName>_all.fbx        the whole pack in one file: ONE import in Studio, then
                                                tools/import/split_pack.luau makes the named models

Skips the bare "_Mesh" files (shapes without color). The packs themselves are not in the repo: download the
free (or bought) tier from https://kaylousberg.itch.io/ and point this at its Assets/gltf folder.
"""

import csv
import json
import math
import os
import re
import sys

import bpy
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def pascal(source_name, pack):
    stem = re.sub(r"_Color\d+$", "", source_name)
    bits = re.split(r"[_\s\-]+", stem)
    return pack + "_" + "".join(b[:1].upper() + b[1:] for b in bits if b)


def new_objects(before):
    return [o for o in bpy.context.scene.objects if o.name not in before]


def process(path, name):
    """Imports one glTF, joins it into one mesh with its pivot at the bottom center. Returns the object."""
    before = {o.name for o in bpy.context.scene.objects}
    bpy.ops.import_scene.gltf(filepath=path)
    added = new_objects(before)
    meshes = [o for o in added if o.type == "MESH"]
    if not meshes:
        for o in added:
            bpy.data.objects.remove(o, do_unlink=True)
        return None

    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    for o in added:
        if o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    points = [v.co for v in obj.data.vertices]
    low = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    high = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    center = Vector(((low.x + high.x) / 2, (low.y + high.y) / 2, low.z))
    obj.data.transform(Matrix.Translation(-center))
    obj.location = (0, 0, 0)
    obj.name = name
    obj.data.name = name
    return obj, high - low


def export(obj, folder):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(folder, obj.name + ".fbx"),
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


def triangles(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def contact_sheet(objects, sizes, path):
    """Lays every model out in a grid and renders one picture (Workbench, with the pack's texture)."""
    # Every model is blown up to fill its own cell (only in the picture: the files are already exported),
    # with its name underneath. The real sizes are in manifest.csv.
    count = len(objects)
    columns = max(1, math.ceil(math.sqrt(count * 1.6)))
    rows = math.ceil(count / columns)
    step_x, step_z = 1.0, 1.25
    label_material = bpy.data.materials.new("Label")
    label_material.diffuse_color = (0.08, 0.1, 0.16, 1)
    for i, (obj, size) in enumerate(zip(objects, sizes)):
        fit = 0.72 / max(size.x, size.y, size.z, 0.01)
        obj.scale = (fit, fit, fit)
        obj.rotation_euler = (0, 0, math.radians(30))  # a three-quarter view
        obj.location = ((i % columns) * step_x, 0, -(i // columns) * step_z)
        text_data = bpy.data.curves.new(obj.name + "_label", "FONT")
        text_data.body = obj.name.split("_", 1)[-1]
        text_data.size = 0.085
        text_data.align_x = "CENTER"
        text_data.materials.append(label_material)
        label = bpy.data.objects.new(obj.name + "_label", text_data)
        label.location = obj.location + Vector((0, -0.6, -0.16))
        label.rotation_euler = (math.radians(90), 0, 0)
        bpy.context.scene.collection.objects.link(label)
    width, height = columns * step_x, rows * step_z

    # Straight from the front, tilted down a little
    camera_data = bpy.data.cameras.new("SheetCamera")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = max(width, height) * 1.04
    camera = bpy.data.objects.new("SheetCamera", camera_data)
    bpy.context.scene.collection.objects.link(camera)
    camera.location = Vector((width / 2 - step_x / 2, -50, -height / 2 + step_z * 0.7))
    camera.rotation_euler = (math.radians(90), 0, 0)
    bpy.context.scene.camera = camera
    depth = height / 1.1

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.background_type = "VIEWPORT"
    scene.display.shading.background_color = (0.78, 0.86, 0.95)
    scene.display.shading.show_shadows = True
    scene.render.resolution_x = 2400
    scene.render.resolution_y = int(2400 * (depth * 1.1) / max(width, depth * 1.1))
    scene.render.film_transparent = False
    scene.world = scene.world or bpy.data.worlds.new("World")
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    if len(argv) < 2:
        print("usage: blender --background --python tools/import/kaykit.py -- <gltf folder> <PackName>")
        sys.exit(1)
    source, pack = argv[0], argv[1]
    out = os.path.join(ROOT, "art", "export", "kaykit", pack)
    os.makedirs(out, exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    files = sorted(f for f in os.listdir(source) if f.lower().endswith((".gltf", ".glb")))
    done, sizes, rows = [], [], []
    for file in files:
        stem = os.path.splitext(file)[0]
        if stem.endswith("_Mesh"):
            continue
        name = pascal(stem, pack)
        result = process(os.path.join(source, file), name)
        if not result:
            print(f"KAYKIT skip {file}: no mesh")
            continue
        obj, size = result
        export(obj, out)
        done.append(obj)
        sizes.append(size)
        rows.append([name, f"{size.x:.2f}", f"{size.y:.2f}", f"{size.z:.2f}", triangles(obj)])
        # park it out of the way of the next import
        obj.location = (10000, 0, 0)

    with open(os.path.join(out, "manifest.csv"), "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["name", "width_x", "depth_y", "height_z", "triangles"])
        writer.writerows(rows)

    atlas_folder = os.path.join(ROOT, "src", "shared", "ArtAtlas")
    os.makedirs(atlas_folder, exist_ok=True)
    with open(os.path.join(atlas_folder, pack + ".json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump({"Models": [r[0] for r in rows]}, f, indent="\t")
        f.write("\n")

    if done:
        # Every model in ONE file too (each still its own named object at the origin), so getting the whole
        # pack into Studio is a single import; tools/import/split_pack.luau then splits it into named models.
        bpy.ops.object.select_all(action="DESELECT")
        for obj in done:
            obj.location = (0, 0, 0)
            obj.select_set(True)
        bpy.context.view_layer.objects.active = done[0]
        bpy.ops.export_scene.fbx(
            filepath=os.path.join(ROOT, "art", "export", "kaykit", pack + "_all.fbx"),
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
        contact_sheet(done, sizes, os.path.join(ROOT, "art", "export", "kaykit", pack + "_sheet.png"))
    print(f"KAYKIT_DONE {pack}: {len(done)} models -> {out}")


main()
