"""
Shared helpers for the Mail a Tiger model scripts.

Every model script builds its model from simple shapes, then calls finish() which:
  * saves an editable .blend to art/models/
  * exports an .fbx for Roblox to art/export/
  * renders a preview .png to art/previews/

Conventions (so models drop straight into the game):
  * 1 Blender unit = 1 Roblox stud. Models stand on the ground at the origin (0, 0, 0).
  * The model FACES -Y (toward you in Blender's Front view, numpad 1).
  * One object per color, named for what it is (Body, Belly, Eyes...). Roblox imports each as a MeshPart.
  * Low-poly, flat-shaded.
The game re-scales and re-centers imported models itself, so exact import settings don't matter much.
"""

import math
import os

import bpy
import bmesh

ART = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def srgb_to_linear(channel: float) -> float:
    return channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4


def reset():
    """Start from an empty scene."""
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, rgb, roughness=0.8):
    """A flat color. rgb is 0-255, like Roblox's Color3.fromRGB."""
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    color = tuple(srgb_to_linear(c / 255) for c in rgb) + (1.0,)
    mat.diffuse_color = color  # what the preview render shows
    try:
        mat.use_nodes = True  # (always on in newer Blender versions)
    except AttributeError:
        pass
    bsdf = mat.node_tree.nodes.get("Principled BSDF") if mat.node_tree else None
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color  # what the FBX export carries
        bsdf.inputs["Roughness"].default_value = roughness
    return mat


def ball(radius, location, scale=(1, 1, 1), subdivisions=2):
    """A low-poly ball (icosphere)."""
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=radius, location=location)
    obj = bpy.context.active_object
    obj.scale = scale
    return obj


def box(size, location):
    """A box of the given (x, y, z) size, centered on location."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.active_object
    obj.scale = size
    return obj


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
    obj = bpy.context.active_object
    obj.name = name
    obj.data.name = name
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    for polygon in obj.data.polygons:
        polygon.use_smooth = False
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    return obj


def render_preview(name, target_height, distance):
    """A simple studio render so the model can be checked without opening Blender."""
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
    scene.render.resolution_x = 800
    scene.render.resolution_y = 800

    target = bpy.data.objects.new("CameraTarget", None)
    target.location = (0, 0, target_height)
    scene.collection.objects.link(target)
    camera_data = bpy.data.cameras.new("Camera")
    camera_data.lens = 50
    camera = bpy.data.objects.new("Camera", camera_data)
    # front-left, a bit above (the model faces -Y)
    angle = math.radians(-120)
    camera.location = (
        math.cos(angle) * distance,
        math.sin(angle) * distance,
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


def finish(name, parts, target_height=1.0, distance=6.0):
    """Save the .blend, export the .fbx and render the preview."""
    render_preview(name, target_height, distance)

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
    print(f"MAILATIGER_DONE {name}: {len(parts)} parts")
