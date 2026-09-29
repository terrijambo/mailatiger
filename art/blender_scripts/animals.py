"""
All the animals except the Hamster (which has its own script, hamster.py).
Every animal faces -Y and stands on the ground at the origin. Names match the game's animal Ids.

Build all:   blender --background --factory-startup --python art/blender_scripts/animals.py
Build some:  blender --background --factory-startup --python art/blender_scripts/animals.py -- Tiger Bear
"""

import math
import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from common import ball, both, box, chain, cone, cyl, limb, run, spike, torus  # noqa: E402

EYE = (25, 25, 30)
WHITE = (245, 245, 245)
PINK = (245, 165, 185)
CREAM = (245, 225, 190)
BEAK = (245, 175, 50)
HOOF = (70, 60, 55)


def eyes(x, y, z, r=0.09):
    return both(lambda s: ball(r, (s * x, y, z), subdivisions=1))


def legs(x, y_front, y_back, top, bottom, r):
    """Four legs: front pair at y_front, back pair at y_back."""
    return [limb((s * x, y, top), (s * x, y, bottom), r) for s in (-1, 1) for y in (y_front, y_back)]


def quills(center, radii, length, radius, rows, per_row, min_z=0.0):
    """Spikes sticking out of the back half of an ellipsoid (hedgehog, porcupine)."""
    cx, cy, cz = center
    rx, ry, rz = radii
    spikes = []
    for row in range(rows):
        up = math.radians(15 + row * (70 / max(1, rows - 1)))  # from the sides up to the top
        for i in range(per_row):
            around = math.radians(-15 + i * (210 / max(1, per_row - 1)))  # sweep over the back (+Y side)
            nx = math.cos(up) * math.cos(around)
            ny = math.cos(up) * math.sin(around)
            nz = math.sin(up)
            if cz + rz * nz < min_z:
                continue
            base = (cx + rx * nx * 0.85, cy + ry * ny * 0.85, cz + rz * nz * 0.85)
            spikes.append(spike(base, (nx, ny * 0.9 + 0.3, nz + 0.2), length, radius))
    return spikes


# ---------------------------------------------------------------------------------------------------------
# Tier 1


def bunny():
    return [
        ("Fur", WHITE, [
            ball(0.9, (0, 0.2, 0.85), scale=(0.9, 1.1, 0.9)),
            ball(0.6, (0, -0.6, 1.45)),
            *both(lambda s: ball(0.18, (s * 0.22, -0.45, 2.35), scale=(1, 0.6, 3.2))),
            ball(0.25, (0, 1.2, 0.95)),
            *both(lambda s: ball(0.2, (s * 0.45, 0.35, 0.12), scale=(1, 1.9, 0.5))),
        ]),
        ("Pink", PINK, [
            *both(lambda s: ball(0.11, (s * 0.22, -0.55, 2.35), scale=(1, 0.5, 2.6))),
            ball(0.08, (0, -1.18, 1.4), subdivisions=1),
        ]),
        ("Eyes", EYE, eyes(0.27, -1.08, 1.58)),
    ]


def goldfish():
    return [
        ("Bowl", (200, 230, 255, 0.65), [ball(1.1, (0, 0, 1.15), scale=(1, 1, 0.95))]),
        ("Water", (90, 170, 230, 0.55), [ball(0.98, (0, 0, 1.05), scale=(1, 1, 0.85))]),
        ("Base", (40, 70, 140), [cyl(0.6, 0.18, (0, 0, 0.09), vertices=12)]),
        ("Fish", (255, 140, 30), [
            ball(0.36, (0, 0, 1.05), scale=(0.6, 1.05, 0.85)),
            spike((0, 0.3, 1.05), (0, 1, 0), 0.4, 0.3, vertices=4),
            spike((0, 0, 1.3), (0, 0.4, 1), 0.2, 0.12, vertices=4),
        ]),
        ("Eyes", EYE, eyes(0.14, -0.28, 1.12, r=0.05)),
    ]


def hedgehog():
    center, radii = (0, 0.1, 0.6), (0.8, 0.95, 0.65)
    return [
        ("Spines", (95, 65, 45), [
            ball(1.0, center, scale=radii),
            *quills(center, radii, 0.45, 0.1, rows=4, per_row=9, min_z=0.25),
        ]),
        ("Face", CREAM, [
            ball(0.45, (0, -0.75, 0.5), scale=(0.85, 1.25, 0.75)),
            *both(lambda s: ball(0.13, (s * 0.35, -0.3, 0.12), scale=(1, 1.3, 0.6), subdivisions=1)),
        ]),
        ("Nose", EYE, [ball(0.09, (0, -1.3, 0.55), subdivisions=1)]),
        ("Eyes", EYE, eyes(0.22, -1.0, 0.72, r=0.07)),
    ]


def parrot():
    return [
        ("Feathers", (60, 190, 80), [
            ball(0.7, (0, 0, 1.3), scale=(0.75, 0.85, 1.15)),
            ball(0.48, (0, -0.25, 2.1)),
        ]),
        ("Wings", (40, 110, 220), both(lambda s: ball(0.5, (s * 0.52, 0.15, 1.35), scale=(0.3, 0.9, 1.2)))),
        ("Tail", (220, 50, 50), [
            box((0.25, 0.12, 1.1), (0, 0.55, 0.55), rotation=(-25, 0, 0)),
            box((0.2, 0.1, 0.9), (0.18, 0.5, 0.6), rotation=(-25, 0, 12)),
            box((0.2, 0.1, 0.9), (-0.18, 0.5, 0.6), rotation=(-25, 0, -12)),
        ]),
        ("Beak", BEAK, [spike((0, -0.62, 2.05), (0, -0.7, -0.7), 0.4, 0.15)]),
        ("Feet", (120, 120, 120), [
            *both(lambda s: ball(0.12, (s * 0.25, -0.1, 0.1), scale=(1, 1.6, 0.6), subdivisions=1)),
            *both(lambda s: limb((s * 0.25, -0.05, 0.62), (s * 0.25, -0.1, 0.1), 0.05)),
        ]),
        ("Eyes", EYE, eyes(0.3, -0.52, 2.25, r=0.07)),
    ]


# ---------------------------------------------------------------------------------------------------------
# Tier 2


def chicken():
    return [
        ("Feathers", WHITE, [
            ball(0.9, (0, 0.1, 1.0), scale=(0.85, 1.1, 0.9)),
            ball(0.45, (0, -0.55, 1.8)),
            ball(0.45, (0, 0.95, 1.5), scale=(0.5, 0.7, 1.1)),
            *both(lambda s: ball(0.5, (s * 0.72, 0.15, 1.05), scale=(0.25, 0.9, 0.7))),
        ]),
        ("Comb", (225, 40, 40), [
            ball(0.13, (0, -0.65, 2.28), subdivisions=1),
            ball(0.15, (0, -0.5, 2.32), subdivisions=1),
            ball(0.13, (0, -0.35, 2.25), subdivisions=1),
            ball(0.12, (0, -0.95, 1.5), scale=(0.7, 0.7, 1.3), subdivisions=1),
        ]),
        ("Beak", BEAK, [spike((0, -0.9, 1.8), (0, -1, -0.2), 0.3, 0.12, vertices=4)]),
        ("Legs", BEAK, [
            *[limb((s * 0.3, 0.1, 0.5), (s * 0.3, 0.1, 0.08), 0.06) for s in (-1, 1)],
            *both(lambda s: box((0.35, 0.4, 0.06), (s * 0.3, -0.05, 0.04))),
        ]),
        ("Eyes", EYE, eyes(0.25, -0.88, 1.92, r=0.06)),
    ]


def goat():
    body = (220, 210, 190)
    horns = both(lambda s: chain(
        [(s * 0.18, -1.3, 2.4), (s * 0.28, -1.1, 2.8), (s * 0.35, -0.75, 2.95), (s * 0.4, -0.5, 2.75)],
        0.1, end_radius=0.04))
    return [
        ("Fur", body, [
            ball(0.8, (0, 0.2, 1.45), scale=(0.8, 1.45, 0.75)),
            ball(0.45, (0, -1.35, 2.05), scale=(0.75, 1.15, 0.85)),
            limb((0, -1.0, 1.6), (0, -1.3, 1.95), 0.3),
            *both(lambda s: ball(0.22, (s * 0.42, -1.2, 2.2), scale=(1.4, 0.4, 0.5), subdivisions=1)),
            ball(0.15, (0, 1.35, 1.7), scale=(0.8, 1, 1.4), subdivisions=1),
        ]),
        ("Legs", (185, 175, 155), legs(0.35, -0.65, 0.95, 1.1, 0.15, 0.13)),
        ("Horns", (120, 110, 100), horns[0] + horns[1]),
        ("Beard", (150, 140, 125), [spike((0, -1.75, 1.8), (0, -0.2, -1), 0.4, 0.1, vertices=5)]),
        ("Hooves", HOOF, [cyl(0.15, 0.15, (s * 0.35, y, 0.075)) for s in (-1, 1) for y in (-0.65, 0.95)]),
        ("Eyes", EYE, eyes(0.27, -1.7, 2.2, r=0.07)),
    ]


def pig():
    skin = (250, 170, 180)
    return [
        ("Skin", skin, [
            ball(1.0, (0, 0.1, 1.1), scale=(0.95, 1.35, 0.85)),
            ball(0.62, (0, -1.1, 1.35)),
            *legs(0.45, -0.6, 0.8, 0.7, 0.1, 0.18),
            *both(lambda s: spike((s * 0.35, -1.0, 1.85), (s * 0.4, -0.4, 1), 0.35, 0.2, vertices=4)),
        ]),
        ("Snout", (235, 130, 150), [
            cyl(0.28, 0.25, (0, -1.72, 1.25), rotation=(90, 0, 0), vertices=10),
            torus(0.14, 0.04, (0, 1.45, 1.35), rotation=(0, 90, 0)),
        ]),
        ("Nostrils", (140, 60, 80), both(lambda s: ball(0.06, (s * 0.1, -1.86, 1.25), subdivisions=1))),
        ("Eyes", EYE, eyes(0.28, -1.55, 1.55, r=0.07)),
    ]


def skunk():
    black = (35, 35, 40)
    return [
        ("Fur", black, [
            ball(0.9, (0, 0.1, 0.8), scale=(0.85, 1.25, 0.75)),
            ball(0.5, (0, -1.0, 0.95)),
            *legs(0.4, -0.5, 0.65, 0.4, 0.06, 0.13),
            ball(0.75, (0, 1.4, 1.5), scale=(0.75, 0.75, 1.1)),
            ball(0.55, (0, 1.2, 2.3), scale=(0.8, 0.8, 1)),
        ]),
        ("Stripe", WHITE, [
            ball(0.9, (0, 0.1, 1.2), scale=(0.28, 1.15, 0.4)),
            ball(0.4, (0, -0.95, 1.33), scale=(0.3, 0.8, 0.3)),
            ball(0.75, (0, 1.55, 1.8), scale=(0.3, 0.75, 1.0)),
        ]),
        ("Nose", PINK, [ball(0.07, (0, -1.5, 0.9), subdivisions=1)]),
        ("Eyes", EYE, eyes(0.22, -1.38, 1.05, r=0.07)),
    ]


# ---------------------------------------------------------------------------------------------------------
# Tier 3


def monkey():
    fur = (140, 95, 55)
    face = (225, 185, 145)
    return [
        ("Fur", fur, [
            ball(0.7, (0, 0.1, 1.35), scale=(0.8, 0.7, 1.0)),
            ball(0.6, (0, -0.1, 2.3)),
            *both(lambda s: ball(0.2, (s * 0.62, -0.1, 2.35), scale=(0.5, 1, 1))),
            *both(lambda s: limb((s * 0.55, 0, 1.8), (s * 0.95, -0.3, 0.3), 0.14)),
            *both(lambda s: limb((s * 0.3, 0.1, 0.8), (s * 0.35, -0.1, 0.1), 0.16)),
            *chain([(0, 0.6, 0.8), (0, 1.2, 0.6), (0, 1.5, 1.1), (0, 1.3, 1.6)], 0.08),
        ]),
        ("Face", face, [
            ball(0.42, (0, -0.52, 2.25), scale=(1, 0.5, 0.9)),
            *both(lambda s: ball(0.12, (s * 0.63, -0.2, 2.35), scale=(0.5, 1, 1), subdivisions=1)),
            ball(0.45, (0, -0.4, 1.3), scale=(0.9, 0.45, 1.1)),
        ]),
        ("Eyes", EYE, eyes(0.17, -0.7, 2.4, r=0.07)),
    ]


def kangaroo():
    fur = (190, 120, 70)
    return [
        ("Fur", fur, [
            ball(0.9, (0, 0.3, 1.25), scale=(0.8, 1.0, 1.15)),
            ball(0.55, (0, -0.15, 2.3), scale=(0.7, 0.8, 0.9)),
            ball(0.4, (0, -0.35, 2.95), scale=(0.75, 1.3, 0.8)),
            *both(lambda s: ball(0.15, (s * 0.2, -0.1, 3.45), scale=(0.7, 0.4, 2.2), subdivisions=1)),
            *both(lambda s: ball(0.25, (s * 0.55, 0.5, 0.18), scale=(0.9, 2.6, 0.6))),
            *both(lambda s: ball(0.35, (s * 0.55, 0.45, 0.8), scale=(0.8, 1.2, 1.3))),
            *both(lambda s: limb((s * 0.4, -0.35, 2.0), (s * 0.45, -0.75, 1.5), 0.09)),
            limb((0, 1.0, 0.9), (0, 2.4, 0.15), 0.35, end_radius=0.1),
        ]),
        ("Pouch", CREAM, [ball(0.5, (0, -0.45, 1.25), scale=(0.9, 0.5, 0.9))]),
        ("Eyes", EYE, eyes(0.2, -0.75, 3.1, r=0.07)),
        ("Nose", EYE, [ball(0.08, (0, -0.85, 2.92), subdivisions=1)]),
    ]


def porcupine():
    center, radii = (0, 0.15, 0.75), (0.9, 1.15, 0.75)
    return [
        ("Body", (110, 95, 80), [
            ball(1.0, center, scale=radii),
            ball(0.45, (0, -1.05, 0.6), scale=(0.9, 1.1, 0.8)),
            *both(lambda s: ball(0.15, (s * 0.4, -0.4, 0.12), scale=(1, 1.4, 0.6), subdivisions=1)),
        ]),
        ("Quills", (235, 228, 210), quills(center, radii, 0.85, 0.07, rows=4, per_row=10, min_z=0.35)),
        ("Nose", EYE, [ball(0.1, (0, -1.5, 0.6), subdivisions=1)]),
        ("Eyes", EYE, eyes(0.22, -1.3, 0.78, r=0.07)),
    ]


def penguin():
    black = (30, 35, 45)
    return [
        ("Body", black, [
            ball(0.9, (0, 0, 1.25), scale=(0.85, 0.8, 1.3)),
            ball(0.55, (0, -0.05, 2.5)),
            *both(lambda s: ball(0.5, (s * 0.8, 0, 1.4), scale=(0.18, 0.5, 1.2), rotation=(0, s * 15, 0))),
        ]),
        ("Belly", WHITE, [
            ball(0.75, (0, -0.35, 1.2), scale=(0.9, 0.6, 1.3)),
            ball(0.35, (0, -0.4, 2.5), scale=(1, 0.5, 0.8)),
        ]),
        ("Orange", BEAK, [
            spike((0, -0.55, 2.4), (0, -1, -0.15), 0.35, 0.12, vertices=5),
            *both(lambda s: ball(0.22, (s * 0.3, -0.2, 0.06), scale=(1, 1.6, 0.35), subdivisions=1)),
        ]),
        ("Eyes", EYE, eyes(0.2, -0.46, 2.62, r=0.07)),
    ]


def octopus():
    skin = (200, 70, 150)
    tentacles = []
    for i in range(8):
        angle = math.radians(i * 45 + 22.5)
        out = (math.cos(angle), math.sin(angle))
        pts = [
            (out[0] * 0.5, out[1] * 0.5, 0.8),
            (out[0] * 1.0, out[1] * 1.0, 0.3),
            (out[0] * 1.5, out[1] * 1.5, 0.12),
            (out[0] * 1.8 - out[1] * 0.3, out[1] * 1.8 + out[0] * 0.3, 0.35),
        ]
        tentacles += chain(pts, 0.2, end_radius=0.06)
    return [
        ("Skin", skin, [ball(0.9, (0, 0, 1.6), scale=(1, 1, 1.2)), *tentacles]),
        ("Spots", (160, 40, 115), [
            ball(0.12, (0.35, 0.3, 2.45), subdivisions=1),
            ball(0.1, (-0.4, 0.25, 2.2), subdivisions=1),
            ball(0.14, (0.1, 0.6, 2.1), subdivisions=1),
        ]),
        ("EyeWhites", WHITE, both(lambda s: ball(0.24, (s * 0.35, -0.7, 1.7), scale=(1, 0.6, 1.1)))),
        ("Eyes", EYE, eyes(0.35, -0.85, 1.68, r=0.12)),
    ]


# ---------------------------------------------------------------------------------------------------------
# Tier 4


def crocodile():
    green = (70, 120, 60)
    ridges = [spike((0, y, 0.85), (0, 0, 1), 0.25, 0.12, vertices=4) for y in (-0.4, 0.1, 0.6, 1.1, 1.6, 2.1)]
    teeth = [spike((s * 0.35, y, 0.45), (0, 0, -1), 0.15, 0.05, vertices=4) for s in (-1, 1) for y in (-1.5, -1.8, -2.1, -2.4)]
    return [
        ("Scales", green, [
            ball(1.0, (0, 0.4, 0.55), scale=(0.8, 1.8, 0.45)),
            box((0.75, 1.4, 0.35), (0, -1.8, 0.55)),
            box((0.7, 1.1, 0.18), (0, -1.9, 0.35)),
            limb((0, 1.8, 0.55), (0, 3.6, 0.3), 0.4, end_radius=0.05),
            *[limb((s * 0.7, y, 0.4), (s * 1.0, y, 0.08), 0.13) for s in (-1, 1) for y in (-0.5, 1.2)],
        ]),
        ("Ridges", (45, 85, 40), ridges),
        ("Teeth", WHITE, teeth),
        ("Eyes", (240, 210, 60), both(lambda s: ball(0.14, (s * 0.25, -1.15, 0.78), subdivisions=1))),
        ("Pupils", EYE, both(lambda s: ball(0.07, (s * 0.25, -1.26, 0.8), subdivisions=1))),
    ]


def gorilla():
    dark = (50, 50, 55)
    grey = (115, 110, 115)
    return [
        ("Fur", dark, [
            ball(1.1, (0, 0.1, 1.8), scale=(1.1, 0.85, 1.0)),
            ball(0.6, (0, -0.25, 2.95)),
            *both(lambda s: limb((s * 1.0, 0, 2.3), (s * 1.3, -0.5, 0.3), 0.3, end_radius=0.24)),
            *both(lambda s: ball(0.3, (s * 1.3, -0.55, 0.25), scale=(1, 1.2, 0.8))),
            *both(lambda s: limb((s * 0.5, 0.2, 1.0), (s * 0.55, 0, 0.15), 0.3)),
        ]),
        ("Skin", grey, [
            ball(0.42, (0, -0.72, 2.85), scale=(1, 0.5, 0.9)),
            ball(0.8, (0, -0.65, 1.7), scale=(0.9, 0.35, 0.9)),
            box((0.8, 0.2, 0.15), (0, -0.72, 3.15)),
        ]),
        ("Eyes", EYE, eyes(0.18, -0.9, 3.0, r=0.07)),
    ]


def bear():
    fur = (110, 70, 40)
    return [
        ("Fur", fur, [
            ball(1.0, (0, 0.25, 1.25), scale=(1.0, 1.4, 0.95)),
            ball(0.7, (0, -1.15, 1.8)),
            *both(lambda s: ball(0.22, (s * 0.5, -1.0, 2.45), scale=(1, 0.6, 1))),
            *legs(0.55, -0.6, 1.0, 0.9, 0.1, 0.27),
        ]),
        ("Muzzle", (200, 160, 110), [
            ball(0.35, (0, -1.75, 1.65), scale=(1, 0.8, 0.75)),
            *both(lambda s: ball(0.12, (s * 0.5, -1.02, 2.45), scale=(1, 0.5, 1), subdivisions=1)),
        ]),
        ("Nose", EYE, [ball(0.12, (0, -2.02, 1.78), subdivisions=1)]),
        ("Eyes", EYE, eyes(0.3, -1.7, 2.0, r=0.08)),
    ]


def tiger():
    orange = (245, 140, 30)
    def ring(y):
        f = math.sqrt(max(0.0, 1 - ((y - 0.2) / 1.55) ** 2))  # body's cross-section size at y
        return ball(1.0, (0, y, 1.3), scale=(0.8 * f + 0.02, 0.045, 0.75 * f + 0.02))

    stripes = [ring(y) for y in (-0.5, -0.1, 0.3, 0.7, 1.1)]
    stripes += both(lambda s: box((0.08, 0.3, 0.5), (s * 0.45, -1.3, 2.35), rotation=(0, s * 25, 0)))
    stripes += [ball(0.3, (0, 2.6, 0.95), subdivisions=1)]
    return [
        ("Fur", orange, [
            ball(1.0, (0, 0.2, 1.3), scale=(0.8, 1.55, 0.75)),
            ball(0.62, (0, -1.35, 1.95)),
            *both(lambda s: spike((s * 0.35, -1.25, 2.4), (s * 0.3, 0, 1), 0.35, 0.18, vertices=4)),
            *legs(0.45, -0.65, 1.0, 1.0, 0.1, 0.2),
            limb((0, 1.6, 1.5), (0, 2.5, 1.0), 0.13),
        ]),
        ("Stripes", (25, 20, 20), stripes),
        ("Muzzle", WHITE, [
            ball(0.35, (0, -1.85, 1.8), scale=(1.1, 0.7, 0.7)),
            ball(0.5, (0, -0.6, 0.95), scale=(0.9, 1.2, 0.5)),
        ]),
        ("Nose", PINK, [ball(0.1, (0, -2.08, 1.95), subdivisions=1)]),
        ("Eyes", (140, 200, 60), eyes(0.28, -1.85, 2.15, r=0.09)),
    ]


# ---------------------------------------------------------------------------------------------------------
# Tier 5


def giraffe():
    coat = (235, 190, 90)
    spot = (150, 90, 40)
    spots = [
        ball(0.22, (x, y, z), scale=(0.2, 1, 1), subdivisions=1)
        for (x, y, z) in [(0.62, -0.2, 2.7), (0.6, 0.5, 2.9), (0.55, 1.0, 2.5), (-0.62, 0.1, 2.8), (-0.6, 0.8, 2.6)]
    ]
    spots += [ball(0.16, (s * 0.2, -0.9 - 0.12 * i, 3.4 + i * 0.5), subdivisions=1) for s in (-1, 1) for i in range(3)]
    return [
        ("Coat", coat, [
            ball(0.9, (0, 0.3, 2.7), scale=(0.7, 1.2, 0.7)),
            *legs(0.35, -0.3, 0.95, 2.4, 0.15, 0.12),
            limb((0, -0.6, 3.0), (0, -1.4, 5.3), 0.28, end_radius=0.2),
            ball(0.4, (0, -1.7, 5.45), scale=(0.7, 1.4, 0.7)),
            *both(lambda s: ball(0.12, (s * 0.35, -1.45, 5.65), scale=(1.5, 0.5, 0.6), subdivisions=1)),
        ]),
        ("Spots", spot, [*spots, *[cyl(0.05, 0.3, (s * 0.12, -1.5, 5.85)) for s in (-1, 1)]]),
        ("Horns", (100, 60, 30), both(lambda s: ball(0.08, (s * 0.12, -1.5, 6.02), subdivisions=1))),
        ("Hooves", HOOF, [cyl(0.13, 0.15, (s * 0.35, y, 0.075)) for s in (-1, 1) for y in (-0.3, 0.95)]),
        ("Eyes", EYE, eyes(0.22, -1.9, 5.55, r=0.06)),
    ]


def elephant():
    grey = (150, 150, 160)
    return [
        ("Skin", grey, [
            ball(1.2, (0, 0.3, 2.0), scale=(1.0, 1.35, 0.95)),
            ball(0.9, (0, -1.25, 2.45)),
            *legs(0.65, -0.45, 1.1, 1.6, 0.2, 0.35),
            *both(lambda s: ball(0.8, (s * 0.85, -0.95, 2.5), scale=(0.15, 0.9, 1.1))),
            *chain([(0, -2.0, 2.2), (0, -2.3, 1.5), (0, -2.35, 0.8), (0, -2.1, 0.4)], 0.3, end_radius=0.16),
            limb((0, 1.8, 2.3), (0, 2.1, 1.3), 0.08),
        ]),
        ("Tusks", (250, 245, 230), both(lambda s: spike((s * 0.35, -1.9, 1.95), (s * 0.2, -0.7, 0.4), 0.9, 0.1))),
        ("Toenails", (230, 225, 210), [cyl(0.36, 0.2, (s * 0.65, y, 0.1)) for s in (-1, 1) for y in (-0.45, 1.1)]),
        ("Eyes", EYE, eyes(0.45, -1.95, 2.75, r=0.09)),
    ]


def whale():
    blue = (60, 90, 160)
    return [
        ("Skin", blue, [
            ball(1.2, (0, 0, 1.25), scale=(1.1, 2.3, 1.0)),
            limb((0, 2.2, 1.35), (0, 3.4, 1.6), 0.45, end_radius=0.2),
            *both(lambda s: ball(0.7, (s * 0.65, 3.6, 1.7), scale=(1.1, 0.5, 0.15), rotation=(0, 0, s * 20))),
            *both(lambda s: ball(0.5, (s * 1.25, -0.6, 0.8), scale=(1.1, 0.6, 0.2), rotation=(0, s * 30, 20 * s))),
        ]),
        ("Belly", (185, 205, 235), [ball(1.0, (0, -0.6, 0.75), scale=(0.95, 1.75, 0.55))]),
        ("Spout", (160, 210, 250, 0.4), [
            cone(0.1, 0.3, 0.9, (0, -0.8, 2.75)),
            *[ball(0.15, (math.cos(a) * 0.35, -0.8 + math.sin(a) * 0.35, 3.25), subdivisions=1) for a in (0, 2.1, 4.2)],
        ]),
        ("Eyes", EYE, eyes(0.9, -1.6, 1.35, r=0.1)),
    ]


# ---------------------------------------------------------------------------------------------------------
# Tier 6


def yeti():
    fur = (225, 238, 255)
    return [
        ("Fur", fur, [
            ball(1.0, (0, 0, 1.6), scale=(1.0, 0.8, 1.15)),
            ball(0.7, (0, -0.1, 2.85)),
            *both(lambda s: limb((s * 0.95, 0, 2.2), (s * 1.25, -0.3, 0.9), 0.3, end_radius=0.35)),
            *both(lambda s: limb((s * 0.45, 0, 0.8), (s * 0.5, -0.1, 0.2), 0.3)),
            *both(lambda s: ball(0.32, (s * 0.5, -0.3, 0.12), scale=(1, 1.5, 0.5))),
            *[spike((x, 0.3, 3.4), (x, 0.3, 1), 0.3, 0.12) for x in (-0.25, 0, 0.25)],
        ]),
        ("Face", (165, 190, 225), [
            ball(0.48, (0, -0.62, 2.8), scale=(1, 0.45, 0.9)),
            *both(lambda s: ball(0.2, (s * 1.28, -0.35, 0.75), scale=(1, 1, 0.7), subdivisions=1)),
        ]),
        ("Mouth", (60, 60, 90), [box((0.4, 0.1, 0.12), (0, -0.84, 2.6))]),
        ("Eyes", EYE, eyes(0.2, -0.82, 2.95, r=0.08)),
    ]


def dragon():
    red = (200, 40, 40)
    gold = (240, 200, 80)
    return [
        ("Scales", red, [
            ball(1.0, (0, 0.2, 1.4), scale=(0.8, 1.4, 0.8)),
            limb((0, -0.8, 1.9), (0, -1.3, 2.6), 0.35),
            ball(0.5, (0, -1.55, 2.75), scale=(0.75, 1.3, 0.7)),
            *legs(0.45, -0.6, 0.9, 1.0, 0.1, 0.18),
            *chain([(0, 1.3, 1.3), (0, 2.1, 0.9), (0, 2.8, 0.6), (0, 3.3, 0.8)], 0.3, end_radius=0.06),
        ]),
        ("Wings", (240, 120, 60), both(lambda s: cone(1.3, 0.05, 0.08, (s * 1.2, 0.3, 2.4), rotation=(0, s * 70, 0), vertices=3, scale=(1, 1.2, 1)))),
        ("Belly", gold, [ball(0.7, (0, -0.4, 1.15), scale=(0.9, 1.3, 0.6))]),
        ("Horns", gold, [
            *both(lambda s: spike((s * 0.22, -1.35, 3.05), (s * 0.2, 0.7, 0.7), 0.5, 0.1)),
            *[spike((0, y, z), (0, 0.2, 1), 0.35, 0.13, vertices=4) for (y, z) in [(-0.3, 2.1), (0.3, 2.15), (0.9, 2.0), (1.6, 1.5)]],
        ]),
        ("Eyes", (255, 230, 60), eyes(0.25, -1.9, 2.9, r=0.08)),
    ]


def alien():
    green = (120, 255, 120)
    return [
        ("Skin", green, [
            ball(0.85, (0, 0, 2.3), scale=(1, 0.95, 1.1)),
            cone(0.55, 0.3, 1.3, (0, 0, 0.95)),
            *both(lambda s: limb((s * 0.35, 0, 1.35), (s * 0.75, -0.2, 0.8), 0.08)),
            *both(lambda s: limb((s * 0.2, 0, 0.35), (s * 0.25, 0, 0.0), 0.12)),
            *both(lambda s: limb((s * 0.25, 0, 3.1), (s * 0.45, 0, 3.7), 0.04)),
        ]),
        ("Eyes", EYE, both(lambda s: ball(0.3, (s * 0.35, -0.75, 2.35), scale=(1.1, 0.45, 0.75), rotation=(0, s * -25, 0)))),
        ("Glow", (230, 255, 120), both(lambda s: ball(0.12, (s * 0.45, 0, 3.75), subdivisions=1))),
    ]


def unicorn():
    white = (255, 245, 250)
    rainbow = [(255, 90, 90), (255, 200, 60), (90, 210, 110), (90, 150, 255), (190, 110, 240)]
    mane = [[] for _ in rainbow]
    neck_bottom, neck_top = (0, -0.25, 2.35), (0, -0.7, 3.8)  # just behind the neck line
    for i in range(10):
        t = i / 9
        point = tuple(neck_bottom[k] + (neck_top[k] - neck_bottom[k]) * t for k in range(3))
        mane[i % len(rainbow)].append(ball(0.2, point, scale=(0.8, 1, 1), subdivisions=1))
    for i in range(5):
        mane[i].append(ball(0.2, (0, 1.55 + i * 0.1, 2.1 - i * 0.3), scale=(0.8, 0.8, 1.2), subdivisions=1))
    return [
        ("Coat", white, [
            ball(0.9, (0, 0.3, 1.9), scale=(0.75, 1.4, 0.75)),
            *legs(0.35, -0.3, 0.95, 1.6, 0.15, 0.13),
            limb((0, -0.5, 2.2), (0, -0.95, 3.6), 0.3, end_radius=0.24),
            ball(0.35, (0, -1.25, 3.75), scale=(0.75, 1.4, 0.75)),
            *both(lambda s: spike((s * 0.18, -0.95, 4.0), (0, 0, 1), 0.3, 0.1, vertices=4)),
        ]),
        ("Horn", (245, 205, 70), [spike((0, -1.35, 4.05), (0, -0.4, 1), 0.8, 0.1)]),
        ("Hooves", (200, 170, 230), [cyl(0.14, 0.15, (s * 0.35, y, 0.075)) for s in (-1, 1) for y in (-0.3, 0.95)]),
        ("ManeRed", rainbow[0], mane[0]),
        ("ManeYellow", rainbow[1], mane[1]),
        ("ManeGreen", rainbow[2], mane[2]),
        ("ManeBlue", rainbow[3], mane[3]),
        ("ManePurple", rainbow[4], mane[4]),
        ("Eyes", EYE, eyes(0.22, -1.55, 3.85, r=0.06)),
    ]


run({
    "Bunny": bunny,
    "Goldfish": goldfish,
    "Hedgehog": hedgehog,
    "Parrot": parrot,
    "Chicken": chicken,
    "Goat": goat,
    "Pig": pig,
    "Skunk": skunk,
    "Monkey": monkey,
    "Kangaroo": kangaroo,
    "Porcupine": porcupine,
    "Penguin": penguin,
    "Octopus": octopus,
    "Crocodile": crocodile,
    "Gorilla": gorilla,
    "Bear": bear,
    "Tiger": tiger,
    "Giraffe": giraffe,
    "Elephant": elephant,
    "Whale": whale,
    "Yeti": yeti,
    "Dragon": dragon,
    "Alien": alien,
    "Unicorn": unicorn,
})
