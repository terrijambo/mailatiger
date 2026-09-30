"""
Draft marketing images made from the game's own models: the game icon and two thumbnails.
Writes art/marketing/icon.png (512x512), thumbnail_tiger.png and thumbnail_lineup.png (1920x1080).

    blender --background --factory-startup --python art/blender_scripts/marketing.py

They're drafts to get you started. Tweak the poses, colors or text below and re-run.
"""

import math
import os

import bpy
from mathutils import Vector

ART = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ART, "marketing")
FONT = "C:/Windows/Fonts/ariblk.ttf"  # Arial Black if it's there, otherwise Blender's own font


def srgb(c):
    c = c / 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def color(rgb, alpha=1.0):
    return (srgb(rgb[0]), srgb(rgb[1]), srgb(rgb[2]), alpha)


def flat_material(name, rgb, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = color(rgb)
    bsdf.inputs["Roughness"].default_value = 0.8
    if emission > 0:
        bsdf.inputs["Emission Color"].default_value = color(rgb)
        bsdf.inputs["Emission Strength"].default_value = emission
    mat.diffuse_color = color(rgb)
    return mat


def new_scene(width, height, sky):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE"
    scene.view_settings.view_transform = "Standard"
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("Sky")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = color(sky)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0
    scene.world = world
    # Key light (sun) + soft fill
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-35))
    scene.collection.objects.link(sun)
    fill = bpy.data.objects.new("Fill", bpy.data.lights.new("Fill", "SUN"))
    fill.data.energy = 1.2
    fill.data.use_shadow = False
    fill.rotation_euler = (math.radians(60), 0, math.radians(150))
    scene.collection.objects.link(fill)
    return scene


def place(name, location, rotation=(0, 0, 0), scale=1.0):
    """Appends every mesh from art/models/<name>.blend under one empty, and poses the empty.
    Rotation is in degrees. Models face -Y and stand on the ground at their origin."""
    path = os.path.join(ART, "models", f"{name}.blend")
    with bpy.data.libraries.load(path) as (source, target):
        target.objects = list(source.objects)
    rig = bpy.data.objects.new(f"{name}_Rig", None)
    bpy.context.scene.collection.objects.link(rig)
    for obj in target.objects:
        if obj is None or obj.type != "MESH":
            continue
        bpy.context.scene.collection.objects.link(obj)
        obj.parent = rig
    rig.location = location
    rig.rotation_euler = tuple(math.radians(a) for a in rotation)
    rig.scale = (scale, scale, scale)
    return rig


def sunburst(center, radius, rays, colors, y):
    """A comic-book burst of alternating colored wedges on a vertical plane (behind the action)."""
    mats = [flat_material(f"Burst{i}", c, emission=1.0) for i, c in enumerate(colors)]
    for i in range(rays):
        a0 = 2 * math.pi * i / rays
        a1 = 2 * math.pi * (i + 1) / rays
        verts = [
            (center[0], y, center[1]),
            (center[0] + math.cos(a0) * radius, y, center[1] + math.sin(a0) * radius),
            (center[0] + math.cos(a1) * radius, y, center[1] + math.sin(a1) * radius),
        ]
        mesh = bpy.data.meshes.new(f"Ray{i}")
        mesh.from_pydata(verts, [], [(0, 1, 2)])
        obj = bpy.data.objects.new(f"Ray{i}", mesh)
        obj.data.materials.append(mats[i % len(mats)])
        bpy.context.scene.collection.objects.link(obj)


def ground(size, rgb):
    bpy.ops.mesh.primitive_plane_add(size=size, location=(0, 0, 0))
    plane = bpy.context.active_object
    plane.data.materials.append(flat_material("Ground", rgb))
    return plane


def text(body, location, size, rgb, outline=(30, 25, 25), rotation=(90, 0, 0), extrude=0.15):
    """Big chunky title text facing the camera (-Y), with a dark outline behind it."""
    font = bpy.data.fonts.load(FONT) if os.path.exists(FONT) else None

    def one(offset, rgb_, grow):
        curve = bpy.data.curves.new("Text", "FONT")
        curve.body = body
        curve.size = size
        curve.extrude = extrude
        curve.offset = grow
        curve.align_x = "CENTER"
        curve.align_y = "CENTER"
        if font:
            curve.font = font
        obj = bpy.data.objects.new("Text", curve)
        obj.location = (location[0], location[1] + offset, location[2])
        obj.rotation_euler = tuple(math.radians(a) for a in rotation)
        obj.data.materials.append(flat_material("TextMat", rgb_, emission=0.4))
        bpy.context.scene.collection.objects.link(obj)
        return obj

    one(0.25, outline, size * 0.06)  # outline: a fatter dark copy just behind
    return one(0, rgb, 0)


def camera(location, look_at, lens=50):
    scene = bpy.context.scene
    cam_data = bpy.data.cameras.new("Camera")
    cam_data.lens = lens
    cam_data.clip_end = 1000
    cam = bpy.data.objects.new("Camera", cam_data)
    cam.location = location
    direction = Vector(look_at) - Vector(location)
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(cam)
    scene.camera = cam


def render(filename):
    os.makedirs(OUT, exist_ok=True)
    bpy.context.scene.render.filepath = os.path.join(OUT, filename)
    bpy.ops.render.render(write_still=True)
    print("wrote", filename)


def tiger_bursting_out(at=(0, 0, 0)):
    """The signature moment: a tiger springing out of a cardboard box."""
    x, y, z = at
    place("Cardboard", (x, y, z))
    # Side-on leap: nose up and to the left, back legs still in the box
    place("Tiger", (x - 0.6, y, z + 3.6), rotation=(-38, 0, -90), scale=1.25)
    # A strip of tape flying off
    tape = flat_material("LooseTape", (235, 205, 120))
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x + 2.6, y - 0.5, z + 4.8))
    strip = bpy.context.active_object
    strip.scale = (1.6, 0.05, 0.35)
    strip.rotation_euler = (0, math.radians(35), math.radians(20))
    strip.data.materials.append(tape)


def make_icon():
    new_scene(512, 512, (255, 200, 60))
    sunburst((0, 3.2), 30, 20, [(255, 170, 40), (255, 215, 80)], y=6)
    ground(40, (106, 170, 84))
    tiger_bursting_out()
    camera((0.8, -9.5, 2.4), (0, 0, 4.6), lens=40)
    render("icon.png")


def make_tiger_thumbnail():
    new_scene(1920, 1080, (255, 200, 60))
    sunburst((3, 3.5), 60, 28, [(255, 170, 40), (255, 215, 80)], y=8)
    ground(80, (106, 170, 84))
    tiger_bursting_out((3.5, 0, 0))
    # Postmaster Gruff, furious, his cap flying off
    place("Gruff", (-4.5, -0.5, 0), rotation=(0, 0, -25), scale=1.3)
    place("GruffHat", (-4.2, -0.2, 6.6), rotation=(25, -30, 40), scale=1.3)
    # Parcels everywhere
    place("Parcel", (-1.2, -2.5, 0), rotation=(0, 0, 15), scale=0.8)
    place("Parcel", (7.8, -1.0, 0), rotation=(0, 0, -20), scale=0.9)
    place("Parcel", (7.2, -1.3, 2.0), rotation=(10, 0, 30), scale=0.7)
    text("MAIL A TIGER", (0, -2.0, 8.9), 2.4, (255, 255, 255))
    camera((0, -25, 4.8), (0, 0, 4.9), lens=45)
    render("thumbnail_tiger.png")


def make_lineup_thumbnail():
    new_scene(1920, 1080, (120, 190, 255))
    ground(120, (106, 170, 84))
    # Big animals at the back, small ones up front, each turned a little toward the middle
    back = ["Giraffe", "Dragon", "Elephant", "Yeti"]
    front = ["Hamster", "Bunny", "Penguin", "Pig", "Tiger", "Skunk"]
    for _, names, spacing, y, scale in (("back", back, 4.8, 4.5, 1.0), ("front", front, 3.0, 0.0, 1.0)):
        start = -spacing * (len(names) - 1) / 2
        for index, name in enumerate(names):
            x = start + index * spacing
            place(name, (x, y, 0), rotation=(0, 0, -x * 3), scale=scale)
    for x, rot in ((-7.6, 20), (7.8, -15), (7.1, 30)):
        place("Parcel", (x, -1.6, 0), rotation=(0, 0, rot), scale=0.6)
    text("25 ANIMALS. ONE MAILROOM.", (0, 3.0, 8.2), 1.35, (255, 255, 255))
    camera((0, -15.5, 4.8), (0, 2.0, 3.6), lens=35)
    render("thumbnail_lineup.png")


make_icon()
make_tiger_thumbnail()
make_lineup_thumbnail()
