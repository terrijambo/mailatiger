"""
Shared helpers for the Mail a Tiger model scripts.

Every model is built from simple shapes, then finish() (or make(), which calls it):
  * saves an editable .blend to art/models/
  * exports an .fbx for Roblox to art/export/
  * writes the part colors to src/shared/ArtColors/<Name>.json (Roblox's importer drops colors, so the
    game paints them back on by part name)
  * renders a preview .png to art/previews/

Conventions (so models drop straight into the game):
  * 1 Blender unit = 1 Roblox stud. Models stand on the ground at the origin (0, 0, 0).
  * The model FACES -Y (toward you in Blender's Front view, numpad 1). +Z is up.
  * One object per color, named for what it is (Body, Belly, Eyes...). Roblox imports each as a MeshPart.
  * Low-poly, flat-shaded.
The game re-scales and re-centers imported models itself, so exact import settings don't matter much.

Multi-model scripts use run(): pass model names after "--" to build only some of them, e.g.
  blender --background --factory-startup --python animals.py -- Tiger Bear
"""

import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

ART = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def srgb_to_linear(channel: float) -> float:
    return channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4


def reset():
    """Start from an empty scene."""
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, rgb, roughness=0.8, transparency=0.0):
    """A flat color. rgb is 0-255, like Roblox's Color3.fromRGB. transparency is 0 (solid) to 1 (invisible)."""
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat["mailatiger_rgb"] = list(rgb)  # remembered so finish() can write the game's color file
    mat["mailatiger_transparency"] = transparency
    color = tuple(srgb_to_linear(c / 255) for c in rgb) + (1.0 - transparency,)
    mat.diffuse_color = color  # what the preview render shows
    try:
        mat.use_nodes = True  # (always on in newer Blender versions)
    except AttributeError:
        pass
    bsdf = mat.node_tree.nodes.get("Principled BSDF") if mat.node_tree else None
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color  # what the FBX export carries
        bsdf.inputs["Roughness"].default_value = roughness
        if transparency > 0:
            bsdf.inputs["Alpha"].default_value = 1.0 - transparency
    return mat


# ---------------------------------------------------------------------------------------------------------
# Shapes. Rotations are in degrees. Every shape returns the new object.


def _active():
    return bpy.context.active_object


def _rotate(obj, rotation):
    obj.rotation_euler = tuple(math.radians(angle) for angle in rotation)


def _aim(obj, direction):
    """Points the object's +Z axis along direction."""
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(Vector(direction).normalized())


def ball(radius, location, scale=(1, 1, 1), subdivisions=2, rotation=(0, 0, 0)):
    """A low-poly ball (icosphere)."""
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=radius, location=location)
    obj = _active()
    obj.scale = scale
    _rotate(obj, rotation)
    return obj


def box(size, location, rotation=(0, 0, 0)):
    """A box of the given (x, y, z) size, centered on location."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = _active()
    obj.scale = size
    _rotate(obj, rotation)
    return obj


def cyl(radius, depth, location, rotation=(0, 0, 0), vertices=8, scale=(1, 1, 1)):
    """A cylinder standing along Z (before rotation), centered on location."""
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location)
    obj = _active()
    obj.scale = scale
    _rotate(obj, rotation)
    return obj


def cone(radius_bottom, radius_top, depth, location, rotation=(0, 0, 0), vertices=8, scale=(1, 1, 1)):
    """A cone (or tapered cylinder) along Z, centered on location."""
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices, radius1=radius_bottom, radius2=radius_top, depth=depth, location=location
    )
    obj = _active()
    obj.scale = scale
    _rotate(obj, rotation)
    return obj


def torus(major, minor, location, rotation=(0, 0, 0), major_segments=12, minor_segments=6):
    """A ring. Lies flat (around Z) before rotation."""
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major,
        minor_radius=minor,
        major_segments=major_segments,
        minor_segments=minor_segments,
        location=location,
    )
    obj = _active()
    _rotate(obj, rotation)
    return obj


def limb(start, end, radius, vertices=8, end_radius=None):
    """A cylinder (or taper, with end_radius) from one point to another: legs, arms, necks, poles."""
    a, b = Vector(start), Vector(end)
    if end_radius is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=(b - a).length, location=(a + b) / 2)
    else:
        bpy.ops.mesh.primitive_cone_add(
            vertices=vertices, radius1=radius, radius2=end_radius, depth=(b - a).length, location=(a + b) / 2
        )
    obj = _active()
    _aim(obj, b - a)
    return obj


def spike(base, direction, length, radius, vertices=6):
    """A cone sitting on base and pointing along direction: horns, quills, teeth, beaks."""
    d = Vector(direction).normalized()
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices, radius1=radius, radius2=0, depth=length, location=Vector(base) + d * length / 2
    )
    obj = _active()
    _aim(obj, d)
    return obj


def both(make):
    """Builds a left (-X) and right (+X) copy: make(side) is called with side = -1 and side = 1."""
    return [make(-1), make(1)]


def chain(points, radius, vertices=8, end_radius=None):
    """Limbs joined end to end through the points (tails, trunks, tentacles), with balls at the joints.
    If end_radius is given, the chain tapers to it."""
    pieces = []
    count = len(points) - 1
    for index in range(count):
        r0 = radius if end_radius is None else radius + (end_radius - radius) * index / count
        r1 = radius if end_radius is None else radius + (end_radius - radius) * (index + 1) / count
        pieces.append(limb(points[index], points[index + 1], r0, vertices, end_radius=r1))
        if index > 0:
            pieces.append(ball(r0, points[index], subdivisions=1))
    return pieces


def remove_faces(obj, test):
    """Deletes the faces for which test(face) is true (e.g. to open the top of a box)."""
    mesh = bmesh.new()
    mesh.from_mesh(obj.data)
    doomed = [face for face in mesh.faces if test(face)]
    bmesh.ops.delete(mesh, geom=doomed, context="FACES")
    mesh.to_mesh(obj.data)
    mesh.free()


def apply_modifier(obj, modifier):
    select_only([obj])
    bpy.ops.object.modifier_apply(modifier=modifier.name)


def select_only(objects):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]


def combine(objects, name, mat):
    """Joins pieces into one flat-shaded object with one material, origin at the world origin."""
    select_only(objects)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if len(objects) > 1:
        bpy.ops.object.join()
    obj = _active()
    obj.name = name
    obj.data.name = name
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    for polygon in obj.data.polygons:
        polygon.use_smooth = False
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    return obj


# ---------------------------------------------------------------------------------------------------------
# Output


def _bounds(parts):
    corners = [part.matrix_world @ Vector(corner) for part in parts for corner in part.bound_box]
    low = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
    high = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
    return low, high


def render_preview(name, parts, target_height=None, distance=None):
    """A simple studio render so the model can be checked without opening Blender.
    The camera frames the model automatically unless target_height/distance are given."""
    low, high = _bounds(parts)
    size = high - low
    if target_height is None:
        target_height = (low.z + high.z) / 2
    if distance is None:
        distance = max(size.x, size.y, size.z) * 1.7 + 1.0
    center = (low + high) / 2

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.view_settings.view_transform = "Standard"  # true colors (the default "AgX" mutes them)
    shading = scene.display.shading
    shading.light = "STUDIO"
    shading.color_type = "MATERIAL"
    shading.show_shadows = True
    shading.show_cavity = True
    shading.cavity_type = "WORLD"
    shading.show_object_outline = True

    world = bpy.data.worlds.new("Sky")
    world.color = (0.45, 0.65, 0.9)
    scene.world = world
    scene.render.film_transparent = False
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512

    target = bpy.data.objects.new("CameraTarget", None)
    target.location = (center.x, center.y, target_height)
    scene.collection.objects.link(target)
    camera_data = bpy.data.cameras.new("Camera")
    camera_data.lens = 50
    camera_data.clip_end = 1000
    camera = bpy.data.objects.new("Camera", camera_data)
    # front-left, a bit above (the model faces -Y)
    angle = math.radians(-120)
    camera.location = (
        center.x + math.cos(angle) * distance,
        center.y + math.sin(angle) * distance,
        target_height + distance * 0.45,
    )
    scene.collection.objects.link(camera)
    track = camera.constraints.new(type="TRACK_TO")
    track.target = target
    scene.camera = camera

    scene.render.filepath = os.path.join(ART, "previews", f"{name}.png")
    bpy.ops.render.render(write_still=True)

    # Don't leave the camera rig in the saved model
    bpy.data.objects.remove(camera)
    bpy.data.objects.remove(target)


def write_colors(name, parts):
    """Roblox's importer drops plain material colors, so the game paints imported parts itself.
    This writes each part's color to src/shared/ArtColors/<name>.json, which Rojo syncs into the game.
    Each entry is [r, g, b] or [r, g, b, transparency]."""
    colors = {}
    for part in parts:
        mat = part.data.materials[0] if part.data.materials else None
        if mat and "mailatiger_rgb" in mat:
            entry = [int(channel) for channel in mat["mailatiger_rgb"]]
            transparency = float(mat.get("mailatiger_transparency", 0))
            if transparency > 0:
                entry.append(round(transparency, 2))
            colors[part.name] = entry
    folder = os.path.join(os.path.dirname(ART), "src", "shared", "ArtColors")
    os.makedirs(folder, exist_ok=True)
    with open(os.path.join(folder, f"{name}.json"), "w", encoding="utf-8", newline="\n") as file:
        json.dump(colors, file, indent="\t")
        file.write("\n")


def finish(name, parts, target_height=None, distance=None):
    """Save the .blend, export the .fbx, write the game's color file and render the preview."""
    write_colors(name, parts)
    render_preview(name, parts, target_height, distance)

    select_only(parts)
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(ART, "export", f"{name}.fbx"),
        use_selection=True,
        object_types={"MESH"},
        mesh_smooth_type="FACE",
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z",
        axis_up="Y",
        add_leaf_bones=False,
    )
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ART, "models", f"{name}.blend"))
    backup = os.path.join(ART, "models", f"{name}.blend1")
    if os.path.exists(backup):
        os.remove(backup)
    print(f"MAILATIGER_DONE {name}: {len(parts)} parts")


def make(name, spec):
    """Builds a model from a spec: a list of (PartName, color, [shapes]).
    color is (r, g, b) or (r, g, b, transparency). Parts with no shapes are skipped."""
    parts = []
    for part_name, color, shapes in spec:
        shapes = [shape for shape in shapes if shape is not None]
        if not shapes:
            continue
        rgb = tuple(color[:3])
        transparency = color[3] if len(color) > 3 else 0.0
        mat = material(f"{name}_{part_name}", rgb, transparency=transparency)
        parts.append(combine(shapes, part_name, mat))
    finish(name, parts)


def run(models):
    """models: {Name: function returning a spec}. Builds them all, or only the names given after "--"."""
    wanted = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else list(models)
    for name in wanted:
        if name not in models:
            print(f"MAILATIGER_UNKNOWN {name}")
            continue
        reset()
        make(name, models[name]())
