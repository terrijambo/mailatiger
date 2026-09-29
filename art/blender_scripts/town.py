"""
The hub town: buildings, counters, boards, pads and street decoration.
Sizes roughly match the graybox parts they'll replace (see art/MODEL_LIST.md). Everything faces -Y.

Build all:   blender --background --factory-startup --python art/blender_scripts/town.py
Build some:  blender --background --factory-startup --python art/blender_scripts/town.py -- PostOffice Bench
"""

import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from common import ball, both, box, cone, cyl, limb, run, torus  # noqa: E402

BRICK = (185, 75, 60)
POSTAL_BLUE = (60, 90, 170)
DARK_BLUE = (35, 50, 100)
GOLD = (240, 200, 60)
WOOD = (160, 110, 70)
DARK_WOOD = (110, 75, 45)
WHITE = (240, 240, 235)
IRON = (45, 45, 50)
GLASS = (170, 215, 245)
STONE = (175, 175, 170)


def post_office():
    w, d, h = 20, 14, 10
    windows = [box((2.6, 0.2, 2.4), (x, -d / 2 - 0.05, 5.2)) for x in (-6, 6)]
    frames = []
    for x in (-6, 6):
        frames += [
            box((3.0, 0.25, 0.25), (x, -d / 2 - 0.1, 6.5)),
            box((3.0, 0.25, 0.25), (x, -d / 2 - 0.1, 3.9)),
            box((0.25, 0.25, 2.8), (x - 1.4, -d / 2 - 0.1, 5.2)),
            box((0.25, 0.25, 2.8), (x + 1.4, -d / 2 - 0.1, 5.2)),
            box((0.15, 0.22, 2.4), (x, -d / 2 - 0.1, 5.2)),
        ]
    return [
        ("Walls", BRICK, [box((w, d, h), (0, 0, h / 2))]),
        ("Roof", POSTAL_BLUE, [
            box((w + 1.2, d + 1.2, 0.6), (0, 0, h + 0.3)),
            box((w + 1.2, 0.5, 1.0), (0, -d / 2 - 0.35, h + 0.8)),
        ]),
        ("Trim", WHITE, [
            box((w + 0.3, d + 0.3, 0.4), (0, 0, 0.2)),
            box((w + 0.3, 0.3, 0.35), (0, -d / 2 - 0.05, h - 0.2)),
            *frames,
            box((4.0, 0.3, 0.35), (0, -d / 2 - 0.1, 5.4)),
        ]),
        ("Windows", GLASS, windows),
        ("Door", DARK_BLUE, [box((3.4, 0.25, 5.0), (0, -d / 2 - 0.05, 2.9))]),
        ("Sign", GOLD, [
            box((9, 0.4, 1.8), (0, -d / 2 - 0.35, 8.2)),
            ball(0.12, (1.2, -d / 2 - 0.2, 2.9), subdivisions=1),
        ]),
        ("Steps", STONE, [box((6, 1.6, 0.35), (0, -d / 2 - 0.8, 0.18)), box((5, 0.8, 0.35), (0, -d / 2 - 0.4, 0.5))]),
    ]


def post_counter():
    return [
        ("Desk", WOOD, [box((10, 2, 3.2), (0, 0, 1.6))]),
        ("Top", DARK_WOOD, [box((10.4, 2.4, 0.3), (0, 0, 3.35))]),
        ("Trays", WHITE, [box((1.4, 1.0, 0.3), (3.5, 0.2, 3.65 + i * 0.35)) for i in range(3)]),
        ("Letters", (250, 245, 220), [box((1.1, 0.8, 0.08), (3.5, 0.2, 3.72 + i * 0.35), rotation=(0, 0, 8)) for i in range(3)]),
        ("Bell", GOLD, [
            ball(0.35, (-3.5, 0, 3.55), scale=(1, 1, 0.75)),
            cyl(0.4, 0.06, (-3.5, 0, 3.53), vertices=10),
            ball(0.08, (-3.5, 0, 3.85), subdivisions=1),
        ]),
        ("Panel", POSTAL_BLUE, [box((9.4, 0.1, 1.6), (0, -1.02, 1.8))]),
    ]


def mail_chute():
    return [
        ("Body", POSTAL_BLUE, [box((4, 4, 4.4), (0, 0, 2.2)), box((4.3, 4.3, 0.4), (0, 0, 4.5))]),
        ("Slot", IRON, [box((2.6, 0.2, 0.5), (0, -2.02, 3.6))]),
        ("Lip", (200, 200, 205), [box((2.9, 0.4, 0.12), (0, -2.1, 3.3))]),
        ("Arrow", GOLD, [
            box((0.5, 0.1, 1.2), (0, -2.05, 2.0)),
            cone(0.7, 0, 0.8, (0, -2.05, 2.9), rotation=(90, 0, 0), vertices=3, scale=(1, 1, 1)),
        ]),
        ("Base", DARK_BLUE, [box((4.2, 4.2, 0.3), (0, 0, 0.15))]),
    ]


def pen_counter():
    pickets = [box((0.25, 0.12, 1.4), (x, 0.9, 0.7)) for x in (-4.6, -4.2, -3.8, 3.8, 4.2, 4.6)]
    return [
        ("Counter", WOOD, [box((8, 2, 3), (0, 0, 1.5)), box((8.4, 2.4, 0.25), (0, 0, 3.12))]),
        ("Posts", DARK_WOOD, [box((0.35, 0.35, 6.2), (x, y, 3.1)) for x in (-4, 4) for y in (-0.9, 0.9)]),
        ("Roof", (90, 150, 70), [box((9.4, 3.4, 0.3), (0, 0, 6.3), rotation=(-12, 0, 0))]),
        ("Fence", WHITE, [*pickets, box((1.6, 0.1, 0.2), (-4.2, 0.9, 1.0)), box((1.6, 0.1, 0.2), (4.2, 0.9, 1.0))]),
        ("Sign", (245, 225, 150), [box((5, 0.2, 1.2), (0, -1.05, 5.3))]),
        ("Paw", (150, 95, 55), [
            ball(0.3, (0, -1.2, 5.2), scale=(1, 0.3, 0.9), subdivisions=1),
            *[ball(0.13, (dx, -1.2, 5.6), scale=(1, 0.3, 1), subdivisions=1) for dx in (-0.3, -0.1, 0.1, 0.3)],
        ]),
    ]


def shop_stall():
    stripes = []
    colors = ([], [])
    for i in range(8):
        slat = box((1.1, 3.4, 0.2), (-3.85 + i * 1.1, -0.6, 6.1), rotation=(18, 0, 0))  # slopes down toward the customer
        colors[i % 2].append(slat)
    tape = [torus(0.3, 0.14, (x, 0.3, 3.45), rotation=(90, 0, 0)) for x in (-2.5, -1.8, 2.8)]
    return [
        ("Counter", POSTAL_BLUE, [box((8, 2, 3), (0, 0, 1.5))]),
        ("Top", DARK_WOOD, [box((8.4, 2.4, 0.25), (0, 0, 3.12))]),
        ("Posts", WHITE, [box((0.3, 0.3, 6.2), (x, y, 3.1)) for x in (-4, 4) for y in (-0.9, 0.9)]),
        ("AwningRed", (220, 60, 60), colors[0]),
        ("AwningWhite", WHITE, colors[1]),
        ("Crates", (190, 150, 100), [box((1.2, 1.0, 0.8), (1.2, 0.2, 3.65)), box((0.9, 0.9, 0.6), (0.2, 0.3, 3.55))]),
        ("Tape", (205, 160, 95), tape),
    ]


def orders_board():
    papers = [
        box((0.9, 0.05, 1.1), (x, -0.2, z), rotation=(0, 0, 0))
        for (x, z) in ((-1.8, 4.6), (-0.4, 4.9), (1.1, 4.5), (-1.2, 3.2), (0.6, 3.1), (1.9, 3.4))
    ]
    pins = [ball(0.08, (x, -0.25, z + 0.45), subdivisions=1) for (x, z) in ((-1.8, 4.6), (-0.4, 4.9), (1.1, 4.5), (-1.2, 3.2), (0.6, 3.1), (1.9, 3.4))]
    return [
        ("Posts", DARK_WOOD, [box((0.35, 0.35, 6.5), (x, 0, 3.25)) for x in (-3.2, 3.2)]),
        ("Frame", WOOD, [box((6.6, 0.35, 4.6), (0, 0, 4.0))]),
        ("Cork", (205, 160, 110), [box((6.0, 0.4, 4.0), (0, -0.02, 4.0))]),
        ("Papers", (250, 248, 235), papers),
        ("Pins", (220, 50, 50), pins),
        ("Roof", DARK_WOOD, [box((7.4, 1.2, 0.25), (0, 0, 6.5), rotation=(-10, 0, 0))]),
    ]


def leaderboard_stand():
    cup = [
        cone(0.5, 0.25, 0.9, (0, 0, 9.7), vertices=10),
        cyl(0.18, 0.4, (0, 0, 9.05), vertices=8),
        cyl(0.45, 0.2, (0, 0, 8.8), vertices=10),
        *both(lambda s: torus(0.25, 0.05, (s * 0.55, 0, 9.7), rotation=(90, 0, 0))),
    ]
    return [
        ("Plinth", STONE, [box((9, 2, 0.8), (0, 0, 0.4))]),
        ("Frame", GOLD, [box((8.8, 0.6, 8.2), (0, 0, 4.6)), *cup]),
        ("Face", (30, 40, 80), [box((8.2, 0.7, 7.6), (0, -0.02, 4.6))]),
        ("Star", WHITE, [ball(0.35, (0, -0.4, 7.9), scale=(1, 0.3, 1), subdivisions=1)]),
    ]


def travel_pad():
    return [
        ("Stone", STONE, [cyl(3.0, 0.4, (0, 0, 0.2), vertices=16)]),
        ("Ring", WHITE, [torus(2.4, 0.18, (0, 0, 0.42), major_segments=24)]),
        ("Center", (140, 140, 138), [cyl(1.2, 0.1, (0, 0, 0.42), vertices=12)]),
    ]


def spawn_pad():
    return [
        ("Pad", POSTAL_BLUE, [cyl(3.2, 0.5, (0, 0, 0.25), vertices=16)]),
        ("Rim", WHITE, [torus(3.1, 0.14, (0, 0, 0.5), major_segments=24)]),
        ("Stamp", WHITE, [box((2.2, 1.6, 0.08), (0, 0, 0.52))]),
        ("StampDot", (220, 60, 60), [cyl(0.5, 0.1, (0, 0, 0.58), vertices=12)]),
    ]


def lamppost():
    return [
        ("Iron", IRON, [
            cyl(0.4, 0.4, (0, 0, 0.2), vertices=8),
            limb((0, 0, 0.3), (0, 0, 7.2), 0.12, vertices=8),
            cone(0.55, 0.15, 0.5, (0, 0, 8.55), vertices=6),
            box((0.9, 0.9, 0.15), (0, 0, 7.25)),
        ]),
        ("Light", (255, 225, 120), [box((0.7, 0.7, 1.0), (0, 0, 7.8))]),
    ]


def bench():
    seat = [box((5, 0.35, 0.12), (0, y, 1.5)) for y in (-0.5, 0, 0.5)]
    back = [box((5, 0.12, 0.35), (0, 0.75, z), rotation=(-12, 0, 0)) for z in (2.1, 2.6)]
    return [
        ("Wood", WOOD, seat + back),
        ("Iron", IRON, [
            *[box((0.15, 1.5, 0.15), (x, 0, 1.4)) for x in (-2.1, 2.1)],
            *[limb((x, -0.6, 1.4), (x, -0.6, 0), 0.08, vertices=6) for x in (-2.1, 2.1)],
            *[limb((x, 0.6, 1.4), (x, 0.7, 0), 0.08, vertices=6) for x in (-2.1, 2.1)],
            *[limb((x, 0.65, 1.4), (x, 0.85, 2.9), 0.08, vertices=6) for x in (-2.1, 2.1)],
        ]),
    ]


def mailbox():
    return [
        ("Body", POSTAL_BLUE, [
            box((1.6, 1.4, 2.0), (0, 0, 1.6)),
            cyl(0.8, 1.4, (0, 0, 2.6), rotation=(90, 0, 0), vertices=12, scale=(1, 1, 1)),
        ]),
        ("Legs", IRON, [box((0.12, 0.12, 0.6), (x, y, 0.3)) for x in (-0.65, 0.65) for y in (-0.55, 0.55)]),
        ("Slot", IRON, [box((0.9, 0.1, 0.15), (0, -0.72, 2.5))]),
        ("Label", WHITE, [box((0.8, 0.06, 0.5), (0, -0.72, 1.7))]),
    ]


def planter():
    flower_colors = {"FlowersRed": (230, 60, 70), "FlowersYellow": (250, 210, 60), "FlowersPurple": (170, 90, 220)}
    spots = [(-1.1, -0.5), (-0.4, 0.4), (0.3, -0.3), (1.0, 0.5), (1.3, -0.4), (-1.3, 0.5)]
    groups = {name: [] for name in flower_colors}
    names = list(flower_colors)
    stems = []
    for i, (x, y) in enumerate(spots):
        stems.append(limb((x, y, 1.0), (x, y, 1.7), 0.05, vertices=5))
        groups[names[i % 3]].append(ball(0.25, (x, y, 1.8), scale=(1, 1, 0.6), subdivisions=1))
    return [
        ("Box", WOOD, [box((3.6, 1.8, 1.0), (0, 0, 0.5))]),
        ("Soil", (90, 60, 40), [box((3.3, 1.5, 0.1), (0, 0, 1.0))]),
        ("Leaves", (70, 150, 60), stems + [ball(0.3, (x, y, 1.15), scale=(1.2, 1.2, 0.5), subdivisions=1) for (x, y) in spots]),
        *[(name, color, groups[name]) for name, color in flower_colors.items()],
    ]


run({
    "PostOffice": post_office,
    "PostCounter": post_counter,
    "MailChute": mail_chute,
    "PenCounter": pen_counter,
    "ShopStall": shop_stall,
    "OrdersBoard": orders_board,
    "LeaderboardStand": leaderboard_stand,
    "TravelPad": travel_pad,
    "SpawnPad": spawn_pad,
    "Lamppost": lamppost,
    "Bench": bench,
    "Mailbox": mailbox,
    "Planter": planter,
})
