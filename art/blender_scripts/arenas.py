"""
Props for the five catching arenas (plus the shared arena gate). Everything faces -Y.
Sizes roughly match the graybox parts they'll replace (see art/MODEL_LIST.md).

Build all:   blender --background --factory-startup --python art/blender_scripts/arenas.py
Build some:  blender --background --factory-startup --python art/blender_scripts/arenas.py -- Barn HayBale
"""

import math
import os
import random
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from common import ball, box, chain, cone, cyl, limb, run, spike, torus  # noqa: E402

WHITE = (245, 245, 240)
WOOD = (160, 110, 70)
DARK_WOOD = (105, 70, 45)
STONE = (175, 175, 170)
LEAF = (70, 150, 60)
LEAF_DARK = (45, 115, 50)
BARN_RED = (170, 50, 45)
HAY = (230, 200, 100)
MUD = (95, 68, 45)
METAL = (170, 175, 180)
DARK = (40, 40, 45)
EYE = (25, 25, 30)


# ---------------------------------------------------------------------------------------------------------
# All arenas


def arena_gate():
    return [
        ("Posts", STONE, [box((1.2, 1.2, 8.5), (x, 0, 4.25)) for x in (-5.6, 5.6)]),
        ("Caps", (140, 140, 135), [box((1.5, 1.5, 0.4), (x, 0, 8.7)) for x in (-5.6, 5.6)]),
        ("Sign", WOOD, [box((10.5, 0.6, 1.8), (0, 0, 7.6))]),
        ("Lanterns", (255, 220, 120), [box((0.45, 0.45, 0.6), (x, -0.8, 6.2)) for x in (-5.6, 5.6)]),
        ("Brackets", DARK, [box((0.12, 0.8, 0.12), (x, -0.45, 6.6)) for x in (-5.6, 5.6)]),
    ]


# ---------------------------------------------------------------------------------------------------------
# Backyard


def picket_fence():
    pickets, points = [], []
    for i in range(10):
        x = -3.6 + i * 0.8
        pickets.append(box((0.4, 0.15, 2.2), (x, 0, 1.1)))
        points.append(cone(0.29, 0, 0.35, (x, 0, 2.37), rotation=(0, 0, 45), vertices=4, scale=(1, 0.37, 1)))
    rails = [box((8.2, 0.12, 0.3), (0, 0.14, z)) for z in (0.6, 1.7)]
    return [("Pickets", WHITE, pickets + points), ("Rails", (225, 225, 220), rails)]


def bush():
    random.seed(4)
    light = [ball(random.uniform(0.8, 1.1), (random.uniform(-0.8, 0.8), random.uniform(-0.6, 0.6), random.uniform(1.1, 1.6))) for _ in range(4)]
    dark = [ball(random.uniform(0.9, 1.2), (random.uniform(-1.0, 1.0), random.uniform(-0.8, 0.8), random.uniform(0.7, 1.0))) for _ in range(4)]
    return [("Leaves", LEAF, light), ("LeavesDark", LEAF_DARK, dark)]


def doghouse():
    w, d, h = 3.0, 3.4, 2.2
    side = w / math.sqrt(2)  # a square this size, turned 45 degrees, is a triangle w wide and w/2 tall
    slab = (w / 2) * math.sqrt(2) + 0.35
    return [
        ("Walls", (200, 70, 60), [
            box((w, d, h), (0, 0, h / 2)),
            box((side, d, side), (0, 0, h), rotation=(0, 45, 0)),
        ]),
        ("Roof", (90, 60, 45), [
            box((slab, d + 0.4, 0.18), (-w / 4 - 0.05, 0, h + w / 4 + 0.1), rotation=(0, -45, 0)),
            box((slab, d + 0.4, 0.18), (w / 4 + 0.05, 0, h + w / 4 + 0.1), rotation=(0, 45, 0)),
        ]),
        ("Door", DARK, [cyl(0.7, 0.2, (0, -d / 2, 1.0), rotation=(90, 0, 0), vertices=12), box((1.4, 0.2, 1.0), (0, -d / 2, 0.5))]),
        ("Bowl", (60, 110, 200), [cyl(0.4, 0.25, (1.1, -2.3, 0.12), vertices=10)]),
        ("Bone", WHITE, [box((0.6, 0.15, 0.12), (-0.9, -2.3, 0.08)), *[ball(0.1, (x, -2.3, 0.08), subdivisions=1) for x in (-1.2, -0.6)]]),
    ]


def flowerbed():
    random.seed(7)
    colors = {"FlowersRed": (230, 60, 70), "FlowersYellow": (250, 210, 60), "FlowersPink": (245, 140, 190)}
    groups = {name: [] for name in colors}
    stems = []
    for i in range(12):
        x, y = random.uniform(-2.6, 2.6), random.uniform(-0.7, 0.7)
        stems.append(limb((x, y, 0.5), (x, y, 1.1), 0.05, vertices=5))
        groups[list(colors)[i % 3]].append(ball(0.22, (x, y, 1.2), scale=(1, 1, 0.6), subdivisions=1))
    return [
        ("Logs", DARK_WOOD, [
            box((6.4, 0.35, 0.5), (0, -1.1, 0.25)), box((6.4, 0.35, 0.5), (0, 1.1, 0.25)),
            box((0.35, 2.55, 0.5), (-3.2, 0, 0.25)), box((0.35, 2.55, 0.5), (3.2, 0, 0.25)),
        ]),
        ("Soil", (90, 60, 40), [box((6.1, 1.9, 0.4), (0, 0, 0.3))]),
        ("Stems", LEAF, stems),
        *[(name, color, groups[name]) for name, color in colors.items()],
    ]


# ---------------------------------------------------------------------------------------------------------
# Barn


def barn():
    w, d, h = 16, 22, 9
    side = w / math.sqrt(2)
    slab = (w / 2) * math.sqrt(2) + 1.0
    front = -d / 2
    return [
        ("Walls", BARN_RED, [
            box((w, d, h), (0, 0, h / 2)),
            box((side, d, side), (0, 0, h), rotation=(0, 45, 0)),
        ]),
        ("Roof", (110, 110, 115), [
            box((slab, d + 1.2, 0.45), (-w / 4 - 0.2, 0, h + w / 4 + 0.25), rotation=(0, -45, 0)),
            box((slab, d + 1.2, 0.45), (w / 4 + 0.2, 0, h + w / 4 + 0.25), rotation=(0, 45, 0)),
        ]),
        ("Trim", WHITE, [
            box((8.4, 0.3, 0.4), (0, front - 0.1, 7.2)),
            box((0.4, 0.3, 7.2), (-4.1, front - 0.1, 3.6)),
            box((0.4, 0.3, 7.2), (4.1, front - 0.1, 3.6)),
            limb((-3.9, front - 0.2, 0.3), (3.9, front - 0.2, 6.9), 0.2, vertices=4),
            limb((3.9, front - 0.2, 0.3), (-3.9, front - 0.2, 6.9), 0.2, vertices=4),
            box((3.6, 0.3, 3.0), (0, front - 0.05, h + 2.6)),
            box((w + 0.2, 0.3, 0.3), (0, front - 0.1, h - 0.1)),
        ]),
        ("Doors", (140, 40, 38), [box((7.8, 0.2, 6.9), (0, front - 0.02, 3.5))]),
        ("Loft", (60, 40, 30), [box((2.8, 0.35, 2.3), (0, front - 0.1, h + 2.6))]),
    ]


def hay_bale():
    return [
        ("Hay", HAY, [box((5, 5, 4), (0, 0, 2))]),
        ("Twine", (160, 120, 60), [box((5.1, 0.25, 4.1), (0, y, 2)) for y in (-1.3, 1.3)]),
        ("Straws", (245, 220, 130), [box((0.1, 0.1, 0.6), (random.Random(i).uniform(-2, 2), -2.5, 4.1), rotation=(random.Random(i + 9).uniform(-40, 40), 0, random.Random(i + 3).uniform(-40, 40))) for i in range(6)]),
    ]


def farm_fence():
    return [
        ("Posts", DARK_WOOD, [box((0.45, 0.45, 3.4), (x, 0, 1.7)) for x in (-4, 0, 4)]),
        ("Rails", BARN_RED, [box((8.6, 0.2, 0.4), (0, -0.25, z)) for z in (0.9, 1.9, 2.9)]),
    ]


def trough():
    return [
        ("Wood", WOOD, [
            box((4, 0.25, 1.2), (0, -0.8, 1.0)), box((4, 0.25, 1.2), (0, 0.8, 1.0)),
            box((0.25, 1.85, 1.2), (-2, 0, 1.0)), box((0.25, 1.85, 1.2), (2, 0, 1.0)),
            box((4, 1.85, 0.2), (0, 0, 0.5)),
        ]),
        ("Legs", DARK_WOOD, [box((0.3, 2.0, 0.5), (x, 0, 0.25)) for x in (-1.6, 1.6)]),
        ("Water", (80, 150, 220, 0.3), [box((3.7, 1.5, 0.7), (0, 0, 0.95))]),
    ]


# ---------------------------------------------------------------------------------------------------------
# Jungle


def jungle_tree():
    random.seed(11)
    trunk = chain([(0, 0, 0), (0.4, 0.2, 4), (-0.3, -0.1, 8), (0.2, 0.1, 11.5)], 1.1, end_radius=0.55)
    roots = [spike((math.cos(a) * 0.6, math.sin(a) * 0.6, 1.3), (math.cos(a), math.sin(a), -0.75), 1.9, 0.45, vertices=5) for a in (0.5, 2.3, 4.1, 5.6)]
    canopy = [ball(random.uniform(2.6, 3.4), (random.uniform(-2.5, 2.5), random.uniform(-2.5, 2.5), random.uniform(11, 13.5)), scale=(1, 1, 0.6)) for _ in range(5)]
    canopy_top = [ball(2.6, (0.2, 0, 14.2), scale=(1, 1, 0.6))]
    vines = []
    for i in range(6):
        a = i * 1.05
        x, y = math.cos(a) * 3.2, math.sin(a) * 3.2
        vines.append(limb((x, y, 11.2), (x * 1.05, y * 1.05, 7.0 + random.uniform(-1, 1)), 0.08, vertices=5))
    return [
        ("Bark", (100, 70, 45), trunk + roots),
        ("Leaves", LEAF, canopy),
        ("LeavesTop", (95, 175, 70), canopy_top),
        ("Vines", (60, 120, 50), vines),
    ]


def mud_puddle():
    random.seed(3)
    blobs = [ball(random.uniform(1.8, 2.6), (random.uniform(-2.5, 2.5), random.uniform(-1.5, 1.5), 0), scale=(1, 1, 0.07)) for _ in range(6)]
    bubbles = [ball(0.2, (random.uniform(-2, 2), random.uniform(-1, 1), 0.12), scale=(1, 1, 0.6), subdivisions=1) for _ in range(4)]
    return [("Mud", MUD, blobs), ("Bubbles", (125, 95, 65), bubbles)]


def bamboo_fence():
    poles, rings = [], []
    for i in range(11):
        x = -4 + i * 0.8
        height = 3.0 + (0.4 if i % 2 else 0)
        poles.append(cyl(0.28, height, (x, 0, height / 2), vertices=8))
        rings += [torus(0.29, 0.05, (x, 0, z), major_segments=8, minor_segments=4) for z in (1.0, 2.0)]
    return [
        ("Bamboo", (160, 185, 80), poles),
        ("Rings", (120, 145, 55), rings),
        ("Rope", (190, 160, 110), [box((8.6, 0.65, 0.18), (0, 0, z)) for z in (0.8, 2.3)]),
    ]


def rock():
    return [
        ("Stone", (125, 125, 120), [ball(1.8, (0, 0, 1.0), scale=(1.2, 1, 0.8), subdivisions=1), ball(1.0, (1.4, 0.3, 0.6), subdivisions=1)]),
        ("Moss", (90, 140, 60), [ball(1.4, (-0.2, 0.2, 1.9), scale=(1, 0.9, 0.25), subdivisions=1)]),
    ]


# ---------------------------------------------------------------------------------------------------------
# Ice Rink


def rink_board():
    return [
        ("Board", WHITE, [box((8, 0.4, 3.0), (0, 0, 1.5))]),
        ("Stripe", (60, 110, 210), [box((8.02, 0.42, 0.35), (0, 0, 2.2))]),
        ("Kickplate", (240, 200, 60), [box((8.02, 0.42, 0.35), (0, 0, 0.18))]),
        ("Rail", (200, 205, 215), [box((8.05, 0.55, 0.2), (0, 0, 3.05))]),
    ]


def hockey_goal():
    frame = [
        limb((-2, 0, 0), (-2, 0, 2.4), 0.1), limb((2, 0, 0), (2, 0, 2.4), 0.1),
        limb((-2, 0, 2.4), (2, 0, 2.4), 0.1),
        limb((-2, 0, 0.05), (-2, 1.6, 0.05), 0.08), limb((2, 0, 0.05), (2, 1.6, 0.05), 0.08),
        limb((-2, 1.6, 0.05), (2, 1.6, 0.05), 0.08),
        limb((-2, 0, 2.4), (-2, 1.6, 0.05), 0.08), limb((2, 0, 2.4), (2, 1.6, 0.05), 0.08),
    ]
    net = [
        box((4, 0.05, 2.9), (0, 0.8, 1.2), rotation=(-34, 0, 0)),
        box((0.05, 1.6, 2.4), (-2, 0.8, 1.0), rotation=(0, 0, 0)),
        box((0.05, 1.6, 2.4), (2, 0.8, 1.0), rotation=(0, 0, 0)),
    ]
    return [("Frame", (220, 40, 40), frame), ("Net", (245, 245, 245, 0.45), net)]


def snowman():
    return [
        ("Snow", (245, 250, 255), [ball(1.3, (0, 0, 1.2)), ball(0.95, (0, 0, 2.9)), ball(0.65, (0, 0, 4.2))]),
        ("Carrot", (245, 130, 40), [spike((0, -0.6, 4.2), (0, -1, -0.05), 0.7, 0.13)]),
        ("Coal", EYE, [
            *[ball(0.08, (x, -0.58, 4.4), subdivisions=1) for x in (-0.22, 0.22)],
            *[ball(0.1, (0, -0.93, z), subdivisions=1) for z in (2.65, 3.0, 3.35)],
        ]),
        ("Hat", (30, 30, 35), [cyl(0.45, 0.8, (0, 0, 5.1), vertices=10), cyl(0.7, 0.08, (0, 0, 4.75), vertices=12)]),
        ("Scarf", (220, 50, 50), [torus(0.7, 0.16, (0, 0, 3.6)), box((0.3, 0.12, 0.9), (0.45, -0.55, 3.1), rotation=(0, 10, 0))]),
        ("Sticks", (110, 75, 45), [limb((0.85, 0, 3.0), (2.0, -0.1, 3.8), 0.07, vertices=5), limb((-0.85, 0, 3.0), (-2.0, -0.1, 3.6), 0.07, vertices=5)]),
    ]


# ---------------------------------------------------------------------------------------------------------
# Rooftop


def ac_unit():
    blades = [box((1.5, 0.3, 0.06), (0, 0, 3.1), rotation=(0, 0, a)) for a in (0, 60, 120)]
    vents = [box((3.6, 0.06, 0.12), (0, -2.02, z)) for z in (0.6, 0.9, 1.2, 1.5, 1.8)]
    return [
        ("Casing", METAL, [box((4, 4, 3), (0, 0, 1.5))]),
        ("Grille", DARK, [cyl(1.6, 0.1, (0, 0, 3.02), vertices=16), *vents]),
        ("Fan", (120, 125, 130), blades + [cyl(0.25, 0.25, (0, 0, 3.12), vertices=8)]),
        ("Pipes", (200, 150, 80), [limb((1.6, 2.0, 0.6), (1.6, 3.2, 0.6), 0.12), limb((1.6, 3.2, 0.6), (1.6, 3.2, 0.0), 0.12)]),
    ]


def water_tower():
    legs = [limb((x * 1.8, y * 1.8, 0), (x * 1.4, y * 1.4, 6), 0.18, vertices=6) for x in (-1, 1) for y in (-1, 1)]
    braces = [box((3.2, 0.15, 0.15), (0, y * 1.6, 3), rotation=(0, 0, 0)) for y in (-1, 1)] + [box((0.15, 3.2, 0.15), (x * 1.6, 0, 3)) for x in (-1, 1)]
    bands = [torus(2.05, 0.08, (0, 0, z), major_segments=16, minor_segments=4) for z in (7.0, 8.4, 9.8)]
    ladder = [limb((x, -2.1, 0), (x, -2.1, 10.5), 0.05, vertices=4) for x in (-0.3, 0.3)] + [box((0.6, 0.08, 0.08), (0, -2.1, z)) for z in range(1, 11)]
    return [
        ("Tank", (150, 100, 60), [cyl(2.0, 4.5, (0, 0, 8.25), vertices=16)]),
        ("Roof", (90, 90, 95), [cone(2.4, 0.1, 1.6, (0, 0, 11.3), vertices=16)]),
        ("Legs", DARK, legs + braces + bands),
        ("Ladder", (120, 120, 125), ladder),
    ]


def chimney():
    bricks = [box((0.9, 0.08, 0.35), (x + (0.45 if row % 2 else 0), -1.02, 0.3 + row * 0.55)) for row in range(8) for x in (-0.6, 0.35) if abs(x + (0.45 if row % 2 else 0)) < 0.9]
    return [
        ("Mortar", (190, 175, 160), [box((2, 2, 4.5), (0, 0, 2.25))]),
        ("Brick", (175, 80, 60), bricks),
        ("Cap", (120, 115, 110), [box((2.4, 2.4, 0.35), (0, 0, 4.6))]),
        ("Hole", (25, 20, 20), [box((1.3, 1.3, 0.1), (0, 0, 4.78))]),
    ]


run({
    "ArenaGate": arena_gate,
    "PicketFence": picket_fence,
    "Bush": bush,
    "Doghouse": doghouse,
    "Flowerbed": flowerbed,
    "Barn": barn,
    "HayBale": hay_bale,
    "FarmFence": farm_fence,
    "Trough": trough,
    "JungleTree": jungle_tree,
    "MudPuddle": mud_puddle,
    "BambooFence": bamboo_fence,
    "Rock": rock,
    "RinkBoard": rink_board,
    "HockeyGoal": hockey_goal,
    "Snowman": snowman,
    "ACUnit": ac_unit,
    "WaterTower": water_tower,
    "Chimney": chimney,
})
