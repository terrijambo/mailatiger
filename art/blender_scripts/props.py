"""
Gameplay props and the Supply Shop tools. Everything faces -Y.

Build all:   blender --background --factory-startup --python art/blender_scripts/props.py
Build some:  blender --background --factory-startup --python art/blender_scripts/props.py -- Parcel
"""

import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from common import ball, both, box, chain, cone, cyl, limb, run, torus  # noqa: E402

CARDBOARD = (198, 156, 109)
TAPE = (215, 175, 105)
WHITE = (245, 245, 240)
RED = (215, 55, 55)
DARK = (40, 40, 45)
WOOD = (160, 110, 70)


# ---------------------------------------------------------------------------------------------------------
# Gameplay props


def egg():
    return [("Shell", (250, 245, 230), [ball(0.5, (0, 0, 0.62), scale=(0.85, 0.85, 1.2), subdivisions=3)])]


def tape_roll():
    return [
        ("Tape", TAPE, [torus(0.55, 0.28, (0, 0, 0.62), rotation=(90, 0, 0), major_segments=16, minor_segments=6)]),
        ("Core", (170, 130, 85), [torus(0.3, 0.06, (0, 0, 0.62), rotation=(90, 0, 0), major_segments=12, minor_segments=4)]),
        ("Strip", (230, 200, 140), [box((0.5, 0.05, 0.5), (0.2, -0.3, 0.12), rotation=(0, -30, 0))]),
    ]


def rubber_stamp():
    return [
        ("Handle", (140, 85, 50), [ball(0.45, (0, 0, 2.2), scale=(1, 1, 0.8)), limb((0, 0, 1.0), (0, 0, 1.9), 0.22)]),
        ("Block", WOOD, [box((1.6, 1.0, 0.5), (0, 0, 0.75))]),
        ("Rubber", RED, [box((1.5, 0.9, 0.25), (0, 0, 0.38))]),
        ("Ink", (150, 20, 20), [box((1.3, 0.7, 0.05), (0, 0, 0.23))]),
    ]


def envelope():
    return [
        ("Paper", (250, 245, 225), [box((2.2, 0.08, 1.4), (0, 0, 0.7))]),
        # The flap's fold: a V of two thin strips meeting in the middle of the front
        ("Flap", (205, 195, 170), [
            box((1.3, 0.1, 0.07), (-0.55, -0.02, 1.05), rotation=(0, -33, 0)),
            box((1.3, 0.1, 0.07), (0.55, -0.02, 1.05), rotation=(0, 33, 0)),
        ]),
        ("Stamp", RED, [box((0.35, 0.1, 0.4), (-0.7, -0.03, 1.05))]),
        ("Address", (90, 90, 110), [box((0.8, 0.1, 0.06), (0.25, -0.03, z)) for z in (0.55, 0.45, 0.35)]),
    ]


def parcel():
    size = 2.4
    return [
        ("Box", CARDBOARD, [box((size, size, size), (0, 0, size / 2))]),
        ("Tape", TAPE, [
            box((0.5, size + 0.04, size + 0.04), (0, 0, size / 2)),
            box((size + 0.04, 0.5, 0.05), (0, 0, size + 0.02)),
        ]),
        ("Label", WHITE, [box((1.1, 0.05, 0.75), (0.55, -size / 2 - 0.02, size * 0.62))]),
        ("Fragile", RED, [box((0.9, 0.05, 0.35), (-0.65, -size / 2 - 0.02, size * 0.3))]),
        ("Holes", DARK, [cyl(0.08, 0.06, (x, -size / 2 - 0.01, size * 0.82), rotation=(90, 0, 0), vertices=6) for x in (-0.8, -0.55)]),
    ]


# ---------------------------------------------------------------------------------------------------------
# Tools (Supply Shop)


def grabbing_gloves():
    def glove(side):
        x = side * 0.8
        return [
            ball(0.5, (x, 0, 0.45), scale=(0.9, 0.55, 1.0)),
            *[limb((x + side * dx, 0, 0.8), (x + side * dx, -0.05, 1.3), 0.11, vertices=6) for dx in (-0.28, -0.09, 0.1, 0.29)],
            limb((x - side * 0.45, 0, 0.5), (x - side * 0.7, -0.05, 0.85), 0.12, vertices=6),
        ]

    cuffs = both(lambda s: cyl(0.45, 0.3, (s * 0.8, 0, 0.05), vertices=10, scale=(1, 0.6, 1)))
    left, right = glove(-1), glove(1)
    return [
        ("Glove", (240, 190, 60), left + right),
        ("Cuff", (60, 90, 170), cuffs),
        ("Grip", (170, 120, 40), both(lambda s: ball(0.3, (s * 0.8, -0.28, 0.45), scale=(1, 0.2, 1), subdivisions=1))),
    ]


def sneakers():
    def shoe(side):
        x = side * 0.7
        return [ball(0.5, (x, -0.2, 0.35), scale=(0.7, 1.4, 0.55)), ball(0.4, (x, 0.35, 0.65), scale=(0.8, 0.8, 0.9))]

    return [
        ("Upper", (220, 60, 60), shoe(-1) + shoe(1)),
        ("Sole", WHITE, both(lambda s: box((0.75, 1.6, 0.18), (s * 0.7, -0.05, 0.09)))),
        ("Laces", WHITE, [box((0.35, 0.06, 0.05), (s * 0.7, -0.35 + i * 0.15, 0.62 + i * 0.03), rotation=(-30, 0, 0)) for s in (-1, 1) for i in range(3)]),
        ("Swoosh", (60, 90, 170), both(lambda s: box((0.05, 0.7, 0.12), (s * 1.06, -0.15, 0.35), rotation=(15, 0, 0)))),
    ]


def tape_gun():
    return [
        ("Frame", RED, [
            box((0.3, 1.8, 0.3), (0, 0, 1.3)),
            limb((0, 0.4, 1.2), (0, 0.6, 0.2), 0.16, vertices=6),
            box((0.3, 0.4, 1.0), (0, -0.85, 1.0)),
        ]),
        ("Tape", TAPE, [torus(0.5, 0.2, (0, 0, 1.8), rotation=(0, 90, 0), major_segments=14, minor_segments=5)]),
        ("Blade", (190, 195, 200), [box((0.35, 0.1, 0.3), (0, -1.1, 0.55))]),
        ("Grip", DARK, [limb((0, 0.45, 1.05), (0, 0.62, 0.3), 0.19, vertices=6)]),
    ]


def butterfly_net():
    hoop_center = (0, -1.3, 2.9)  # the hoop stands upright, facing forward (-Y)
    return [
        ("Handle", WOOD, [limb((0, 1.2, 0.15), (0, -1.3, 2.1), 0.07, vertices=6)]),
        ("Hoop", (190, 195, 200), [torus(0.8, 0.05, hoop_center, rotation=(90, 0, 0), major_segments=16, minor_segments=4)]),
        # The net hangs out the front of the hoop and narrows to a point
        ("Net", (245, 245, 245, 0.35), [cone(0.8, 0.1, 1.3, (0, -1.95, 2.9), rotation=(90, 0, 0), vertices=12)]),
        ("Grip", (60, 90, 170), [limb((0, 1.05, 0.3), (0, 0.55, 0.8), 0.09, vertices=6)]),
    ]


run({
    "Egg": egg,
    "TapeRoll": tape_roll,
    "RubberStamp": rubber_stamp,
    "Envelope": envelope,
    "Parcel": parcel,
    "GrabbingGloves": grabbing_gloves,
    "Sneakers": sneakers,
    "TapeGun": tape_gun,
    "ButterflyNet": butterfly_net,
})
