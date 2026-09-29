"""
Mail chute upgrades (the basic chute is MailChute in town.py). For the planned "carry boxes in your inventory
and mail them yourself" system, where the chute can be upgraded. Everything faces -Y.

Build all:   blender --background --factory-startup --python art/blender_scripts/chutes.py
"""

import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from common import ball, box, cone, cyl, limb, run, torus  # noqa: E402

POSTAL_BLUE = (60, 90, 170)
DARK_BLUE = (35, 50, 100)
GOLD = (240, 200, 60)
DARK = (40, 40, 45)
METAL = (175, 180, 190)
HAZARD = (245, 205, 40)


def express():
    rollers = [cyl(0.25, 3.0, (0, y, 1.35), rotation=(0, 90, 0), vertices=8) for y in (-2.6, -3.3, -4.0, -4.7, -5.4)]
    # Short slanted hazard stripes along the top of the front, kept inside the chute's outline
    stripes = [box((0.35, 0.05, 1.1), (x, -2.53, 4.3), rotation=(0, 30, 0)) for x in (-1.9, -1.2, -0.5, 0.2, 0.9, 1.6)]
    return [
        ("Body", POSTAL_BLUE, [box((5, 5, 5.2), (0, 0, 2.6)), box((5.4, 5.4, 0.45), (0, 0, 5.4))]),
        ("Hazard", HAZARD, stripes),
        ("Mouth", DARK, [box((3.2, 0.3, 1.8), (0, -2.45, 1.9))]),
        ("Belt", (60, 60, 65), [box((3.2, 3.6, 0.15), (0, -4.0, 1.6))]),
        ("Rollers", METAL, rollers + [box((0.2, 3.8, 1.3), (x, -4.0, 0.65)) for x in (-1.7, 1.7)]),
        ("Light", (90, 230, 90), [ball(0.3, (0, 0, 5.9), subdivisions=1)]),
    ]


def pneumatic():
    return [
        ("Base", POSTAL_BLUE, [box((4, 4, 1.4), (0, 0, 0.7)), box((3, 3, 0.4), (0, 0, 7.3))]),
        ("Tube", (170, 220, 250, 0.55), [cyl(1.2, 5.6, (0, 0, 4.2), vertices=16)]),
        ("Rings", METAL, [torus(1.25, 0.1, (0, 0, z), major_segments=16, minor_segments=4) for z in (1.6, 4.2, 6.8)]),
        ("Pipe", METAL, [
            limb((0, 0, 7.5), (0, 0, 9.5), 0.6),
            limb((0, 0, 9.5), (0, 3.5, 10.5), 0.6),
            ball(0.6, (0, 0, 9.5), subdivisions=1),
        ]),
        ("Hatch", DARK_BLUE, [box((1.8, 0.2, 1.4), (0, -2.05, 2.3))]),
        ("Parcel", (198, 156, 109), [box((1.1, 1.1, 1.1), (0, 0, 5.2), rotation=(20, 15, 0))]),
        ("Gauge", GOLD, [cyl(0.35, 0.12, (1.6, -2.05, 1.0), rotation=(90, 0, 0), vertices=10)]),
    ]


def rocket():
    return [
        ("Pad", (120, 120, 125), [cyl(3.0, 0.5, (0, 0, 0.25), vertices=16)]),
        ("Hazard", HAZARD, [torus(2.7, 0.15, (0, 0, 0.52), major_segments=24)]),
        ("Rocket", (240, 240, 245), [
            cyl(0.9, 3.6, (0, 0, 2.6), vertices=12),
            cone(0.9, 0, 1.6, (0, 0, 5.2), vertices=12),
        ]),
        ("Fins", (220, 50, 50), [
            box((0.15, 1.1, 1.3), (x, y, 1.4), rotation=(0, 0, angle))
            for (x, y, angle) in ((0.95, 0, 0), (-0.95, 0, 0), (0, 0.95, 90), (0, -0.95, 90))
        ]),
        ("Window", (120, 190, 240), [cyl(0.35, 0.1, (0, -0.9, 3.6), rotation=(90, 0, 0), vertices=10)]),
        ("Tower", DARK, [limb((2.2, 0.5, 0.5), (2.2, 0.5, 5.5), 0.15, vertices=6), box((1.4, 0.2, 0.2), (1.5, 0.5, 4.2))]),
        ("Light", (240, 60, 60), [ball(0.25, (2.2, 0.5, 5.7), subdivisions=1)]),
    ]


run({
    "MailChuteExpress": express,
    "MailChutePneumatic": pneumatic,
    "MailChuteRocket": rocket,
})
