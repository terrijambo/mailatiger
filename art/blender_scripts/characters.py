"""
Characters: Postmaster Gruff (the grumpy walrus boss) and his postal cap. The cap is a separate model so
a tiger breakout can knock it off his head. Gruff is also the tier-6 animal "Gruff".

Build all:   blender --background --factory-startup --python art/blender_scripts/characters.py
"""

import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import math

from common import ball, both, box, cyl, limb, run, spike, torus  # noqa: E402

SKIN = (130, 110, 100)
EYE = (25, 25, 30)
POSTAL_BLUE = (60, 90, 170)
GOLD = (240, 200, 60)


def gruff():
    return [
        ("Skin", SKIN, [
            ball(1.3, (0, 0.1, 1.45), scale=(1.0, 0.9, 1.1)),
            ball(0.85, (0, -0.35, 2.85)),
            *both(lambda s: ball(0.45, (s * 1.25, -0.2, 1.2), scale=(0.35, 0.9, 1.1), rotation=(0, s * 20, 0))),
            *both(lambda s: ball(0.5, (s * 0.55, -0.4, 0.15), scale=(0.9, 1.4, 0.35))),
        ]),
        ("Jacket", POSTAL_BLUE, [
            ball(1.33, (0, 0.1, 1.25), scale=(1.0, 0.92, 0.85)),
        ]),
        ("Buttons", GOLD, [ball(0.08, (0, -1.16, z), subdivisions=1) for z in (0.85, 1.25, 1.65)]),
        ("Mustache", (235, 225, 205), [
            *both(lambda s: ball(0.42, (s * 0.35, -1.05, 2.6), scale=(1.1, 0.6, 0.75))),
        ]),
        ("Tusks", (250, 245, 230), both(lambda s: spike((s * 0.32, -1.1, 2.4), (s * 0.05, -0.2, -1), 0.8, 0.09))),
        ("Nose", (60, 45, 40), [ball(0.18, (0, -1.12, 2.95), scale=(1.2, 0.8, 0.8))]),
        ("Brows", (80, 65, 60), both(lambda s: box((0.35, 0.12, 0.1), (s * 0.3, -0.95, 3.35), rotation=(0, s * -18, 0)))),
        ("Eyes", EYE, both(lambda s: ball(0.08, (s * 0.3, -0.95, 3.18), subdivisions=1))),
        ("Bag", (140, 95, 55), [
            box((0.9, 0.35, 0.7), (1.05, -0.35, 0.85), rotation=(0, 0, -15)),
            limb((-0.9, -0.3, 2.3), (1.0, -0.55, 1.1), 0.06, vertices=6),
        ]),
    ]


def gruff_hat():
    # Sized to sit on Gruff's head (his head is about 1.7 studs wide)
    return [
        ("Cap", POSTAL_BLUE, [
            cyl(0.55, 0.45, (0, 0, 0.25), vertices=12),
            cyl(0.62, 0.08, (0, 0, 0.5), vertices=12),
        ]),
        ("Brim", (35, 45, 80), [box((0.9, 0.5, 0.06), (0, -0.55, 0.05))]),
        ("Badge", GOLD, [box((0.25, 0.05, 0.2), (0, -0.56, 0.3))]),
    ]


def boss_crown():
    # The Boss Hunter crown: worn by the top helper of each hourly boss fight. About 2 studs across, so it
    # sits on a player's head; the game scales it to fit anyway. The front (red gem) faces -Y.
    points = []
    pearls = []
    for i in range(5):
        angle = math.radians(90 + i * 72)  # one point straight over the front gem
        x, y = math.cos(angle) * 0.92, -math.sin(angle) * 0.92
        out = (x * 0.25, y * 0.25, 1.0)  # leaning outward a little
        points.append(spike((x, y, 0.6), out, 0.75, 0.24, vertices=4))
        length = math.sqrt(out[0] ** 2 + out[1] ** 2 + out[2] ** 2)
        tip = (x + out[0] / length * 0.78, y + out[1] / length * 0.78, 0.6 + out[2] / length * 0.78)
        pearls.append(ball(0.11, tip, subdivisions=1))
    return [
        ("Band", GOLD, [cyl(1.0, 0.6, (0, 0, 0.3), vertices=16)]),
        ("Trim", (205, 150, 40), [
            torus(1.0, 0.07, (0, 0, 0.02), major_segments=16, minor_segments=4),
            torus(1.0, 0.07, (0, 0, 0.6), major_segments=16, minor_segments=4),
        ]),
        ("Points", GOLD, points),
        ("Pearls", (250, 250, 245), pearls),
        ("Velvet", (175, 30, 55), [ball(0.86, (0, 0, 0.5), scale=(1, 1, 0.55))]),
        ("RedGem", (225, 40, 60), [ball(0.17, (0, -1.0, 0.3), scale=(1, 0.6, 1.2))]),
        ("BlueGem", (60, 130, 255), [
            ball(0.13, (math.cos(math.radians(235)) * 1.0, math.sin(math.radians(235)) * 1.0, 0.3), scale=(1, 0.6, 1)),
            ball(0.13, (math.cos(math.radians(305)) * 1.0, math.sin(math.radians(305)) * 1.0, 0.3), scale=(1, 0.6, 1)),
        ]),
    ]


run({
    "Gruff": gruff,
    "GruffHat": gruff_hat,
    "BossCrown": boss_crown,
})
