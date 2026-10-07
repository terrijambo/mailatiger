"""
Scenery for the archipelago: trees, farm machines, beach and ice set pieces, cottages.
These are the "nice" versions of things the game otherwise builds from plain blocks
(src/server/Scenery/). Import them into ReplicatedStorage > MapModels and the game swaps them in.
Everything faces -Y and stands on the origin. Sizes are in studs.

Build all:   blender --background --factory-startup --python art/blender_scripts/scenery.py
Build some:  blender --background --factory-startup --python art/blender_scripts/scenery.py -- OakTree Tractor
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from common import ball, box, cone, cyl, limb, run, torus  # noqa: E402

BARK = (110, 78, 52)
BARK_DARK = (84, 58, 40)
LEAF = (62, 146, 62)
LEAF_LIGHT = (104, 176, 74)
LEAF_DARK = (44, 112, 58)
PINE = (38, 104, 74)
SNOW = (244, 248, 255)
WOOD = (166, 116, 72)
DARK_WOOD = (104, 70, 44)
STRAW = (226, 190, 102)
RED = (200, 52, 46)
WHITE = (240, 238, 230)
IRON = (52, 52, 58)
RUBBER = (36, 36, 40)
GLASS = (160, 210, 240)
STONE = (168, 164, 156)
GOLD = (240, 196, 60)


# ---------------------------------------------------------------------------------------------------------
# Extra shapes


def _jitter(obj, amount, seed):
    """Nudges every vertex a little, so round things look hand-made instead of perfect."""
    rng = random.Random(seed)
    mesh = bmesh.new()
    mesh.from_mesh(obj.data)
    for vertex in mesh.verts:
        vertex.co += Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * amount
    mesh.to_mesh(obj.data)
    mesh.free()
    return obj


def blob(radius, location, seed, scale=(1, 1, 1), subdivisions=2):
    """A lumpy ball: a canopy of leaves, a bush, a boulder."""
    obj = ball(radius, location, scale=scale, subdivisions=subdivisions)
    return _jitter(obj, radius * 0.11, seed)


def _bake(obj):
    """Applies an object's rotation and scale to its mesh (so face tests can use world directions)."""
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return obj


def cut_below_ground(obj):
    """Slices the object at z = 0 and throws away everything under the ground."""
    _bake(obj)
    mesh = bmesh.new()
    mesh.from_mesh(obj.data)
    offset = obj.location.z
    geometry = mesh.verts[:] + mesh.edges[:] + mesh.faces[:]
    bmesh.ops.bisect_plane(mesh, geom=geometry, plane_co=(0, 0, -offset), plane_no=(0, 0, 1), clear_inner=True)
    mesh.to_mesh(obj.data)
    mesh.free()
    return obj


def mesh_object(name, verts, faces, thickness=0.0):
    """A mesh straight from vertices and faces (optionally given thickness, for leaves and planks)."""
    data = bpy.data.meshes.new(name)
    data.from_pydata([tuple(v) for v in verts], [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    if thickness:
        modifier = obj.modifiers.new("Thick", "SOLIDIFY")
        modifier.thickness = thickness
        modifier.offset = 0
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def loft(sections, closed=False, cap=False, thickness=0.0):
    """Joins rings of points (all the same length) into a surface: boat hulls, bent leaves."""
    count = len(sections[0])
    verts = [v for section in sections for v in section]
    faces = []
    for s in range(len(sections) - 1):
        for i in range(count if closed else count - 1):
            j = (i + 1) % count
            a, b = s * count + i, s * count + j
            faces.append((a, b, b + count, a + count))
    if cap:
        faces.append(tuple(range(count))[::-1])
        last = (len(sections) - 1) * count
        faces.append(tuple(range(last, last + count)))
    return mesh_object("Loft", verts, faces, thickness)


def frond(base, angle, length, width, droop, seed):
    """A palm leaf: a folded strip that arcs out from base and droops at the tip."""
    rng = random.Random(seed)
    direction = Vector((math.cos(angle), math.sin(angle), 0))
    side = Vector((-direction.y, direction.x, 0))
    steps = 6
    sections = []
    for i in range(steps + 1):
        t = i / steps
        center = Vector(base) + direction * length * t + Vector((0, 0, length * 0.35 * t - droop * t * t))
        w = width * math.sin(math.pi * min(1, t * 1.1 + 0.08)) * 0.5 + 0.05
        fold = Vector((0, 0, w * 0.35))
        sections.append([center - side * w, center + fold, center + side * w])
    leaf = loft(sections, thickness=0.12)
    return _jitter(leaf, 0.03, seed + rng.randint(0, 99))


def wheel(radius, width, center, spokes_list, hubs_list, seed=0):
    """A wheel turning around X: a tire, a colored hub and a few spokes."""
    x, y, z = center
    tire = cyl(radius, width, center, rotation=(0, 90, 0), vertices=16)
    hub = cyl(radius * 0.55, width + 0.06, center, rotation=(0, 90, 0), vertices=12)
    hubs_list.append(hub)
    hubs_list.append(cyl(radius * 0.18, width + 0.2, center, rotation=(0, 90, 0), vertices=8))
    for k in range(4):
        a = k * math.pi / 4
        spokes_list.append(box((width + 0.1, radius * 1.05, 0.12), center, rotation=(math.degrees(a), 0, 0)))
    return tire


# ---------------------------------------------------------------------------------------------------------
# Trees


def oak_tree():
    trunk = [
        limb((0, 0, 0), (0, 0, 7.5), 1.0, vertices=8, end_radius=0.55),
        limb((0, 0, 5.4), (2.6, 0.6, 8.8), 0.42, vertices=6, end_radius=0.22),
        limb((0, 0, 5.8), (-2.4, -0.9, 9.0), 0.4, vertices=6, end_radius=0.2),
        limb((0, 0, 6.4), (0.4, 2.2, 9.6), 0.36, vertices=6, end_radius=0.2),
    ]
    roots = [limb((0, 0, 1.2), (math.cos(a) * 1.8, math.sin(a) * 1.8, 0), 0.38, vertices=5, end_radius=0.12) for a in (0.3, 1.9, 3.5, 5.0)]
    dark = [
        blob(3.2, (2.6, 0.7, 9.6), 1),
        blob(3.3, (-2.5, -1.0, 9.8), 2),
        blob(3.0, (0.6, -2.6, 10.2), 3),
        blob(3.1, (-0.8, 2.5, 10.6), 4),
    ]
    light = [
        blob(4.0, (0, 0, 11.6), 5, scale=(1, 1, 0.9)),
        blob(2.6, (1.4, -0.6, 13.6), 6),
        blob(2.4, (-1.3, 1.0, 13.4), 7),
    ]
    return [
        ("Trunk", BARK, trunk + roots),
        ("Leaves", LEAF, dark),
        ("LeavesLight", LEAF_LIGHT, light),
    ]


def birch_tree():
    trunk = [limb((0, 0, 0), (0.3, 0, 11), 0.5, vertices=8, end_radius=0.28)]
    marks = []
    rng = random.Random(11)
    for i in range(10):
        z = 1 + i * 0.95
        a = rng.uniform(0, math.pi * 2)
        r = 0.5 - z * 0.02
        marks.append(box((0.5, 0.12, 0.16), (math.cos(a) * r + z * 0.027, math.sin(a) * r, z), rotation=(0, 0, math.degrees(a) + 90)))
    branches = [
        limb((0.15, 0, 6.5), (1.6, 0.4, 8.8), 0.16, vertices=5, end_radius=0.08),
        limb((0.2, 0, 7.5), (-1.4, -0.5, 9.6), 0.15, vertices=5, end_radius=0.08),
    ]
    leaves = [
        blob(2.2, (0.3, 0, 12.0), 21, scale=(1, 1, 1.4)),
        blob(1.9, (1.6, 0.4, 9.8), 22, scale=(1, 1, 1.3)),
        blob(1.9, (-1.4, -0.5, 10.4), 23, scale=(1, 1, 1.3)),
        blob(1.7, (0.2, 1.4, 10.8), 24, scale=(1, 1, 1.3)),
        blob(1.6, (0.4, 0.2, 14.2), 25, scale=(1, 1, 1.2)),
    ]
    return [
        ("Trunk", (236, 232, 222), trunk + branches),
        ("Marks", (52, 50, 48), marks),
        ("Leaves", (148, 196, 82), leaves),
    ]


def _pine(snowy):
    rng = random.Random(31 if snowy else 30)
    tiers = []
    caps = []
    for i in range(5):
        t = i / 5
        r = 4.4 - t * 3.2
        z = 2.4 + i * 2.6
        tier = cone(r, 0.15, 4.4 - t * 0.8, (0, 0, z + 2.0), vertices=9, rotation=(0, 0, rng.uniform(0, 40)))
        tiers.append(_jitter(tier, 0.12, 40 + i))
        if snowy:
            # snow on the part of this tier that shows below the next one: a band near its top edge
            depth = 4.4 - t * 0.8
            bottom = z + 2.0 - depth / 2

            def radius_at(height, r=r, bottom=bottom, depth=depth):
                return r + (0.15 - r) * (height - bottom) / depth

            lo, hi = bottom + 1.3, bottom + 2.7
            band = cone(radius_at(lo) * 1.05, radius_at(hi) * 1.05, hi - lo, (0, 0, (lo + hi) / 2), vertices=9, rotation=tier.rotation_euler[:] and (0, 0, math.degrees(tier.rotation_euler[2])))
            caps.append(_jitter(band, 0.05, 60 + i))
    parts = [
        ("Trunk", BARK_DARK, [limb((0, 0, 0), (0, 0, 4), 0.7, vertices=7, end_radius=0.45)]),
        ("Needles", (36, 98, 74) if snowy else PINE, tiers),
    ]
    if snowy:
        parts.append(("Snow", SNOW, caps + [_jitter(ball(0.55, (0, 0, 16.4), subdivisions=1), 0.05, 70)]))
    return parts


def pine_tree():
    return _pine(False)


def snow_pine():
    return _pine(True)


def palm_tree():
    # A trunk that leans and curves, with rings, then a crown of drooping fronds and coconuts
    points = []
    for i in range(9):
        t = i / 8
        points.append(Vector((t * t * 3.2, 0, t * 13)))
    trunk = []
    rings = []
    for i in range(8):
        r0 = 0.62 - i * 0.035
        trunk.append(limb(points[i], points[i + 1], r0, vertices=8, end_radius=r0 - 0.035))
        rings.append(torus(r0 + 0.02, 0.09, points[i] + (points[i + 1] - points[i]) * 0.5, major_segments=10, minor_segments=4))
        d = points[i + 1] - points[i]
        rings[-1].rotation_mode = "QUATERNION"
        rings[-1].rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    top = points[-1]
    fronds = []
    fronds_dark = []
    for k in range(8):
        angle = k * math.pi * 2 / 8 + 0.2
        leaf = frond(top + Vector((0, 0, 0.2)), angle, 6.2 + (k % 2) * 0.8, 1.7, 4.2, 80 + k)
        (fronds if k % 2 == 0 else fronds_dark).append(leaf)
    coconuts = [ball(0.42, top + Vector((math.cos(a) * 0.5, math.sin(a) * 0.5, -0.5)), subdivisions=1) for a in (0.4, 2.5, 4.4)]
    return [
        ("Trunk", (150, 112, 74), trunk + [ball(0.6, top, subdivisions=1)]),
        ("Rings", (112, 82, 54), rings),
        ("Fronds", (70, 156, 64), fronds),
        ("FrondsDark", (50, 128, 60), fronds_dark),
        ("Coconuts", (110, 74, 44), coconuts),
    ]


# ---------------------------------------------------------------------------------------------------------
# Farm


def tractor():
    spokes, hubs = [], []
    tires = [
        wheel(2.0, 1.1, (-2.0, 1.6, 2.0), spokes, hubs),
        wheel(2.0, 1.1, (2.0, 1.6, 2.0), spokes, hubs),
        wheel(1.1, 0.8, (-1.6, -3.0, 1.1), spokes, hubs),
        wheel(1.1, 0.8, (1.6, -3.0, 1.1), spokes, hubs),
    ]
    body = [
        box((2.4, 4.6, 1.6), (0, -1.9, 2.4)),  # engine hood
        box((3.0, 2.8, 1.4), (0, 1.4, 2.6)),  # under the cab
        box((2.5, 0.4, 1.3), (0, -4.25, 2.3)),  # nose
        box((5.4, 2.2, 0.25), (0, 1.6, 4.1)),  # mudguards
        box((1.0, 2.2, 0.5), (-2.25, 1.6, 4.0), rotation=(0, -18, 0)),
        box((1.0, 2.2, 0.5), (2.25, 1.6, 4.0), rotation=(0, 18, 0)),
    ]
    cab_frame = [
        box((0.25, 0.25, 3.0), (x, y, 5.4)) for x in (-1.4, 1.4) for y in (0.3, 2.6)
    ] + [box((3.2, 2.7, 0.35), (0, 1.45, 7.0))]
    glass = [box((2.6, 0.08, 2.3), (0, 0.3, 5.3)), box((0.08, 2.0, 2.0), (-1.4, 1.45, 5.4)), box((0.08, 2.0, 2.0), (1.4, 1.45, 5.4))]
    grille = [box((2.0, 0.1, 1.0), (0, -4.46, 2.4))] + [box((1.8, 0.12, 0.08), (0, -4.5, 2.05 + i * 0.22)) for i in range(4)]
    return [
        ("Body", (204, 46, 40), body),
        ("Roof", (232, 230, 222), [cab_frame[-1]]),
        ("Frame", IRON, cab_frame[:-1] + [limb((-0.8, -2.4, 3.2), (-0.8, -2.4, 5.8), 0.16, vertices=8)]),
        ("Glass", (170, 215, 240, 0.35), glass),
        ("Grille", (40, 40, 44), grille),
        ("Lights", (255, 236, 160), [ball(0.25, (x, -4.45, 2.85), subdivisions=1) for x in (-0.85, 0.85)]),
        ("Tires", RUBBER, tires),
        ("Hubs", (246, 200, 50), hubs),
        ("Spokes", (226, 180, 40), spokes),
        ("Seat", (40, 40, 44), [box((1.1, 1.0, 0.3), (0, 1.8, 3.6)), box((1.1, 0.3, 1.0), (0, 2.3, 4.1))]),
        ("Wheel", RUBBER, [torus(0.45, 0.07, (0, 0.6, 4.6), rotation=(-55, 0, 0), major_segments=12, minor_segments=4), limb((0, 0.6, 4.6), (0, 0.9, 3.4), 0.07, vertices=5)]),
    ]


def windmill():
    tower = [cone(4.2, 2.6, 13, (0, 0, 6.5), vertices=8)]
    trims = [torus(4.2 - (2.6 - 4.2) * -0 - 1.6 * (z / 13), 0.18, (0, 0, z), major_segments=8, minor_segments=4) for z in (0.3, 6.5)]
    cap = [cone(3.6, 0.3, 4.6, (0, 0, 15.3), vertices=8), cyl(3.3, 0.6, (0, 0, 13.2), vertices=8)]
    hub = [cyl(0.7, 1.2, (0, -3.5, 13.6), rotation=(90, 0, 0), vertices=10)]
    frames, cloth = [], []
    for k in range(4):
        a = math.radians(45 + k * 90)
        d = Vector((math.cos(a), 0, math.sin(a)))
        s = Vector((-d.z, 0, d.x))
        center = Vector((0, -4.1, 13.6))
        frames.append(limb(center, center + d * 9.5, 0.2, vertices=4))
        for j in range(5):
            p = center + d * (2.5 + j * 1.75)
            frames.append(limb(p - s * 0.1, p + s * 1.9, 0.07, vertices=4))
        frames.append(limb(center + d * 2.4 + s * 1.9, center + d * 9.4 + s * 1.9, 0.07, vertices=4))
        quad = [center + d * 2.5 + s * 0.15, center + d * 9.3 + s * 0.15, center + d * 9.3 + s * 1.8, center + d * 2.5 + s * 1.8]
        cloth.append(mesh_object("Sail", [q + Vector((0, 0.08, 0)) for q in quad], [(0, 1, 2, 3)], thickness=0.06))
    door = [box((1.8, 0.4, 3.0), (0, -3.95, 1.5)), cyl(0.9, 0.4, (0, -3.95, 3.0), rotation=(90, 0, 0), vertices=10)]
    windows = [box((1.0, 0.3, 1.3), (0, -3.25, 8.8)), box((0.3, 1.0, 1.3), (3.2, 0, 7.6)), box((0.3, 1.0, 1.3), (-3.2, 0, 7.6))]
    return [
        ("Tower", (236, 226, 204), tower),
        ("Trim", DARK_WOOD, trims),
        ("Cap", (150, 60, 50), cap),
        ("Hub", IRON, hub),
        ("SailFrame", (130, 92, 60), frames),
        ("Sails", (250, 246, 236), cloth),
        ("Door", DARK_WOOD, door),
        ("Windows", (60, 80, 110), windows),
    ]


def silo():
    bands = [torus(3.05, 0.12, (0, 0, z), major_segments=16, minor_segments=4) for z in (2, 5, 8, 11, 14)]
    ladder = [limb((x, -3.05, 0.5), (x, -3.05, 15.5), 0.08, vertices=5) for x in (-0.45, 0.45)]
    ladder += [box((0.9, 0.12, 0.12), (0, -3.05, 1 + i * 1.0)) for i in range(15)]
    return [
        ("Walls", (222, 220, 214), [cyl(3.0, 16, (0, 0, 8), vertices=16)]),
        ("Bands", (150, 150, 156), bands),
        ("Dome", (196, 60, 50), [ball(3.1, (0, 0, 16), scale=(1, 1, 0.75), subdivisions=2), cyl(0.4, 1.0, (0, 0, 18.6), vertices=8)]),
        ("Ladder", IRON, ladder),
        ("Base", STONE, [cyl(3.3, 0.6, (0, 0, 0.3), vertices=16)]),
    ]


def scarecrow():
    return [
        ("Post", DARK_WOOD, [box((0.35, 0.35, 7), (0, 0, 3.5)), box((5.0, 0.3, 0.3), (0, 0, 5.2))]),
        ("Shirt", (70, 110, 180), [box((2.0, 1.0, 2.4), (0, 0, 4.6)), box((4.2, 0.8, 0.8), (0, 0, 5.2))]),
        ("Patches", (220, 90, 70), [box((0.6, 0.1, 0.6), (-0.4, -0.52, 4.3)), box((0.5, 0.1, 0.5), (1.6, -0.42, 5.2))]),
        ("Pants", (120, 92, 60), [box((1.8, 0.9, 1.4), (0, 0, 2.9))]),
        ("Straw", STRAW, [
            box((0.4, 0.4, 0.5), (x, 0, 5.2), rotation=(0, 0, 20)) for x in (-2.3, 2.3)
        ] + [box((0.5, 0.5, 0.6), (0, 0, 2.0))]),
        ("Head", (232, 206, 140), [ball(0.95, (0, 0, 6.6), subdivisions=2)]),
        ("Face", (40, 30, 24), [ball(0.12, (x, -0.88, 6.75), subdivisions=1) for x in (-0.3, 0.3)] + [box((0.6, 0.08, 0.1), (0, -0.9, 6.3))]),
        ("Hat", (120, 84, 50), [cyl(1.6, 0.12, (0, 0, 7.35), vertices=12), cone(0.9, 0.2, 1.4, (0, 0, 8.0), vertices=10, rotation=(6, 0, 0))]),
        ("Crow", (36, 34, 40), [ball(0.35, (2.1, 0, 5.65), scale=(1.3, 1, 1), subdivisions=1), ball(0.2, (2.45, -0.05, 5.95), subdivisions=1)]),
        ("Beak", (240, 170, 50), [limb((2.6, -0.05, 5.95), (2.85, -0.05, 5.9), 0.07, vertices=4, end_radius=0.01)]),
    ]


# ---------------------------------------------------------------------------------------------------------
# Beach


def lighthouse():
    stripes = []
    whites = []
    for i in range(6):
        z0 = i * 3.0
        r0 = 3.6 - z0 * 0.09
        r1 = 3.6 - (z0 + 3.0) * 0.09
        (stripes if i % 2 == 0 else whites).append(cone(r0, r1, 3.0, (0, 0, z0 + 1.5), vertices=14))
    rail = [torus(2.7, 0.08, (0, 0, 20.0), major_segments=16, minor_segments=4)]
    for k in range(12):
        a = k * math.pi * 2 / 12
        rail.append(limb((math.cos(a) * 2.7, math.sin(a) * 2.7, 18.4), (math.cos(a) * 2.7, math.sin(a) * 2.7, 20.0), 0.06, vertices=4))
    return [
        ("Stripes", (210, 50, 50), stripes),
        ("White", WHITE, whites + [cyl(2.9, 0.5, (0, 0, 18.2), vertices=14)]),
        ("Rail", IRON, rail),
        ("Lamp", (255, 230, 140), [cyl(1.4, 2.4, (0, 0, 19.7), vertices=10)]),
        ("LampFrame", IRON, [limb((math.cos(a) * 1.45, math.sin(a) * 1.45, 18.5), (math.cos(a) * 1.45, math.sin(a) * 1.45, 20.9), 0.08, vertices=4) for a in [k * math.pi / 3 for k in range(6)]]),
        ("Dome", (200, 50, 50), [ball(1.7, (0, 0, 21.0), scale=(1, 1, 0.7), subdivisions=2), cone(0.2, 0.02, 1.2, (0, 0, 22.6), vertices=6)]),
        ("Door", (60, 90, 150), [box((1.4, 0.4, 2.4), (0, -3.5, 1.2))]),
        ("Windows", (60, 80, 110), [box((0.8, 0.3, 1.1), (0, -3.0, 7.5)), box((0.8, 0.3, 1.1), (0, -2.4, 13.5))]),
        ("Base", STONE, [_jitter(cyl(4.2, 1.0, (0, 0, 0.3), vertices=12), 0.12, 90)]),
    ]


def _hull_sections(length, width, depth, rng_seed=0):
    sections = []
    steps = 8
    for i in range(steps + 1):
        t = i / steps
        y = -length / 2 + length * t
        # pointed at the bow (-Y), squarer at the stern
        w = width * (math.sin(math.pi * min(1.0, t * 1.15)) ** 0.6 if t < 0.85 else 0.92)
        w = max(w, 0.05)
        sheer = depth + (0.5 if t < 0.15 else 0) * (1 - t / 0.15) * depth * 0.6
        sections.append([
            (-w, y, sheer),
            (-w * 0.92, y, depth * 0.45),
            (-w * 0.55, y, depth * 0.08),
            (0, y, 0),
            (w * 0.55, y, depth * 0.08),
            (w * 0.92, y, depth * 0.45),
            (w, y, sheer),
        ])
    return sections


def rowboat():
    hull = loft(_hull_sections(7, 1.5, 1.1), thickness=0.12)
    return [
        ("Hull", (70, 130, 180), [hull]),
        ("Trim", WHITE, [limb((-1.45, -2.2, 1.1), (-1.45, 3.4, 1.1), 0.08, vertices=4), limb((1.45, -2.2, 1.1), (1.45, 3.4, 1.1), 0.08, vertices=4)]),
        ("Seats", WOOD, [box((2.7, 0.6, 0.12), (0, y, 0.75)) for y in (-0.8, 1.6)]),
        ("Oars", (196, 160, 110), [
            limb((-1.2, 0.4, 0.95), (-2.9, -1.6, 0.35), 0.07, vertices=5),
            limb((1.2, 0.4, 0.95), (2.9, 1.8, 0.35), 0.07, vertices=5),
            box((0.12, 0.9, 0.35), (-3.1, -1.85, 0.3), rotation=(0, 0, 40)),
            box((0.12, 0.9, 0.35), (3.1, 2.05, 0.3), rotation=(0, 0, 40)),
        ]),
    ]


def shipwreck():
    sections = _hull_sections(22, 4.6, 4.2)
    # broken off at the stern: drop the last sections
    hull = loft(sections[:-2], thickness=0.3)
    hull.rotation_euler = (math.radians(0), math.radians(-16), math.radians(0))
    planks = []
    for i in range(6):
        y = -6 + i * 2.6
        planks.append(box((0.3, 2.0, 0.25), (1.8 + (i % 2) * 0.7, y, 2.7 - i * 0.12), rotation=(0, -24, 0)))
    mast = [limb((0.3, -1, 1.5), (-3.5, -0.5, 10.5), 0.32, vertices=7, end_radius=0.22), limb((-1.9, -0.5, 7.0), (-1.0, 3.2, 6.6), 0.12, vertices=5)]
    sail = mesh_object("Sail", [(-2.2, -0.4, 9.4), (-1.8, 2.8, 7.0), (-0.9, 3.0, 4.6), (-0.4, -0.2, 3.8)], [(0, 1, 2, 3)], thickness=0.06)
    sail = _jitter(sail, 0.15, 101)
    ribs = []
    for i in range(5):
        y = -4 + i * 2.4
        ribs.append(limb((2.2, y, 2.2), (3.0 + (i % 2) * 0.5, y + 0.3, 5.2 - i * 0.3), 0.16, vertices=5, end_radius=0.1))
    mast.extend(ribs)
    rocks = [blob(1.4, (3.4, 4.5, 0.2), 102, scale=(1.3, 1, 0.7), subdivisions=1), blob(1.0, (-3.0, -7.5, 0.2), 103, subdivisions=1)]
    return [
        ("Hull", (110, 78, 54), [hull]),
        ("Planks", (138, 98, 66), planks),
        ("Mast", (96, 66, 44), mast),
        ("Sail", (228, 220, 196), [sail]),
        ("Rocks", (120, 116, 112), rocks),
        ("Moss", (90, 140, 80), [blob(0.7, (1.5, -6.5, 1.1), 104, scale=(1.2, 1, 0.5), subdivisions=1)]),
    ]


def tiki_hut():
    posts = [limb((x, y, 0), (x, y, 5.2), 0.22, vertices=6) for x in (-3, 3) for y in (-2.2, 2.2)]
    roof_layers = [_jitter(cone(5.4 - i * 1.2, 1.4 - i * 0.6 if i < 2 else 0.05, 1.6, (0, 0, 5.6 + i * 1.1), vertices=10), 0.12, 110 + i) for i in range(3)]
    fringe = []
    for k in range(20):
        a = k * math.pi * 2 / 20
        fringe.append(limb((math.cos(a) * 5.2, math.sin(a) * 5.2, 4.95), (math.cos(a) * 5.35, math.sin(a) * 5.35, 4.2), 0.18, vertices=4, end_radius=0.04))
    bamboo = [limb((x, -2.3, 0), (x, -2.3, 2.5), 0.13, vertices=6) for x in [-2.6 + i * 0.35 for i in range(16)]]
    return [
        ("Posts", (124, 88, 56), posts),
        ("Roof", (214, 178, 96), roof_layers),
        ("Fringe", (190, 152, 76), fringe),
        ("Counter", (120, 170, 90), bamboo),
        ("Top", WOOD, [box((6.4, 1.2, 0.25), (0, -2.4, 2.6))]),
        ("Cups", (250, 120, 160), [cyl(0.2, 0.5, (x, -2.4, 2.98), vertices=8) for x in (-1.8, 0.6)]),
        ("Straws", (250, 240, 120), [limb((x, -2.4, 3.1), (x + 0.15, -2.4, 3.6), 0.04, vertices=4) for x in (-1.8, 0.6)]),
    ]


# ---------------------------------------------------------------------------------------------------------
# Ice


def igloo():
    # A smooth snow dome with the block joints drawn on as slightly raised seams, and an arched tunnel
    dome = ball(4.6, (0, 0, 0), subdivisions=3)
    cut_below_ground(dome)
    seams = []
    rows = 5
    for row in range(1, rows):
        phi = row / rows * math.pi / 2
        seams.append(torus(math.cos(phi) * 4.62, 0.07, (0, 0, math.sin(phi) * 4.62), major_segments=24, minor_segments=3))
    for row in range(rows - 1):
        phi0, phi1 = row / rows * math.pi / 2, (row + 1) / rows * math.pi / 2
        count = max(3, int(math.cos(phi0) * 6))
        for k in range(count):
            a = (k + (row % 2) * 0.5) / count * math.pi * 2
            p0 = Vector((math.cos(a) * math.cos(phi0), math.sin(a) * math.cos(phi0), math.sin(phi0))) * 4.62
            p1 = Vector((math.cos(a) * math.cos(phi1), math.sin(a) * math.cos(phi1), math.sin(phi1))) * 4.62
            seams.append(limb(p0, p1, 0.07, vertices=4))
    tunnel = cut_below_ground(cyl(1.9, 3.0, (0, -4.6, 0), rotation=(90, 0, 0), vertices=14))
    hole = cut_below_ground(cyl(1.3, 0.2, (0, -6.05, 0), rotation=(90, 0, 0), vertices=12))
    rim = cut_below_ground(torus(1.9, 0.09, (0, -6.1, 0), rotation=(90, 0, 0), major_segments=14, minor_segments=3))
    return [
        ("Blocks", (236, 244, 252), [dome]),
        ("Tunnel", (226, 238, 250), [tunnel]),
        ("Seams", (196, 214, 232), seams + [rim]),
        ("Inside", (50, 70, 100), [hole]),
    ]


# ---------------------------------------------------------------------------------------------------------
# Town


def cottage():
    w, d, h = 9.0, 7.0, 5.0
    side = w / math.sqrt(2)
    slab = (w / 2) * math.sqrt(2) + 0.9
    front = -d / 2
    beams = [box((0.3, 0.3, h), (x, front - 0.12, h / 2)) for x in (-w / 2 + 0.15, -1.4, 1.4, w / 2 - 0.15)]
    beams += [box((w, 0.3, 0.3), (0, front - 0.12, h - 0.15)), box((w, 0.3, 0.3), (0, front - 0.12, 0.3))]
    shingles = []
    for i in range(5):
        off = 0.35 + i * 1.25
        for s in (-1, 1):
            shingles.append(box((1.1, d + 1.2, 0.18), (s * (w / 2 + 0.3 - off * 0.72), 0, h + off * 0.72 + 0.35), rotation=(0, s * 45, 0)))
    windows = []
    shutters = []
    for x in (-3.0, 3.0):
        windows.append(box((1.5, 0.2, 1.5), (x, front - 0.06, 2.9)))
        shutters += [box((0.55, 0.15, 1.6), (x - 1.05, front - 0.1, 2.9)), box((0.55, 0.15, 1.6), (x + 1.05, front - 0.1, 2.9))]
    flowers = [ball(0.24, (x, front - 0.65, 2.25), subdivisions=1) for x in (-3.5, -3.0, -2.5, 2.5, 3.0, 3.5)]
    return [
        ("Walls", (244, 236, 216), [box((w, d, h), (0, 0, h / 2)), box((side, d, side), (0, 0, h), rotation=(0, 45, 0))]),
        ("Beams", (110, 76, 52), beams),
        ("Roof", (186, 84, 64), [
            box((slab, d + 1.2, 0.35), (-w / 4 - 0.15, 0, h + w / 4 + 0.15), rotation=(0, -45, 0)),
            box((slab, d + 1.2, 0.35), (w / 4 + 0.15, 0, h + w / 4 + 0.15), rotation=(0, 45, 0)),
        ]),
        ("Shingles", (160, 66, 52), shingles),
        ("Chimney", (150, 140, 132), [box((1.1, 1.1, 3.2), (2.3, 1.3, h + 3.0)), box((1.4, 1.4, 0.3), (2.3, 1.3, h + 4.6))]),
        ("Door", (70, 110, 160), [box((1.6, 0.25, 2.8), (0, front - 0.08, 1.4))]),
        ("Knob", GOLD, [ball(0.1, (0.5, front - 0.25, 1.4), subdivisions=1)]),
        ("Windows", (150, 200, 235), windows),
        ("Shutters", (70, 130, 90), shutters),
        ("FlowerBox", DARK_WOOD, [box((1.8, 0.5, 0.4), (x, front - 0.4, 2.0)) for x in (-3.0, 3.0)]),
        ("Flowers", (236, 90, 110), flowers),
        ("Step", STONE, [box((2.4, 1.0, 0.3), (0, front - 0.6, 0.15))]),
    ]


run({
    "OakTree": oak_tree,
    "BirchTree": birch_tree,
    "PineTree": pine_tree,
    "SnowPine": snow_pine,
    "PalmTree": palm_tree,
    "Tractor": tractor,
    "Windmill": windmill,
    "Silo": silo,
    "Scarecrow": scarecrow,
    "Lighthouse": lighthouse,
    "Rowboat": rowboat,
    "Shipwreck": shipwreck,
    "TikiHut": tiki_hut,
    "Igloo": igloo,
    "Cottage": cottage,
})
