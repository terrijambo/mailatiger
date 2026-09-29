"""
The box set (the Cardboard box has its own script, cardboard_box.py). Each is 3x3x3 studs and open on top
so the animal can poke out. Names match the game's box Ids.

Build all:   blender --background --factory-startup --python art/blender_scripts/boxes.py
Build some:  blender --background --factory-startup --python art/blender_scripts/boxes.py -- Vault
"""

import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from common import apply_modifier, box, cyl, limb, remove_faces, run, torus  # noqa: E402

SIZE = 3.0


def open_shell(size=SIZE, wall=0.1):
    """A box with no top, with some wall thickness (grows inward so the outside stays size x size x size)."""
    shell = box((size, size, size), (0, 0, size / 2))
    remove_faces(shell, lambda face: face.normal.z > 0.9)
    thickness = shell.modifiers.new("Walls", "SOLIDIFY")
    thickness.thickness = wall
    thickness.offset = -1
    apply_modifier(shell, thickness)
    return shell


def wood():
    planks = []
    # Horizontal planks on each side (slightly proud of the walls), with gaps between them
    for z in (0.45, 1.15, 1.85, 2.55):
        planks.append(box((SIZE + 0.08, 0.1, 0.55), (0, -SIZE / 2 - 0.02, z)))
        planks.append(box((SIZE + 0.08, 0.1, 0.55), (0, SIZE / 2 + 0.02, z)))
        planks.append(box((0.1, SIZE + 0.08, 0.55), (-SIZE / 2 - 0.02, 0, z)))
        planks.append(box((0.1, SIZE + 0.08, 0.55), (SIZE / 2 + 0.02, 0, z)))
    posts = [box((0.3, 0.3, SIZE + 0.05), (sx * (SIZE / 2 - 0.05), sy * (SIZE / 2 - 0.05), SIZE / 2)) for sx in (-1, 1) for sy in (-1, 1)]
    braces = [
        limb((-SIZE / 2 + 0.2, -SIZE / 2 - 0.1, 0.25), (SIZE / 2 - 0.2, -SIZE / 2 - 0.1, SIZE - 0.25), 0.1, vertices=4),
        limb((-SIZE / 2 - 0.1, SIZE / 2 - 0.2, 0.25), (-SIZE / 2 - 0.1, -SIZE / 2 + 0.2, SIZE - 0.25), 0.1, vertices=4),
    ]
    return [
        ("Walls", (160, 110, 65), [open_shell()]),
        ("Planks", (185, 135, 85), planks),
        ("Posts", (125, 85, 50), posts + braces),
        ("Nails", (90, 90, 95), [cyl(0.05, 0.06, (x, -SIZE / 2 - 0.08, z), rotation=(90, 0, 0), vertices=6) for x in (-1.3, 1.3) for z in (0.45, 1.15, 1.85, 2.55)]),
    ]


def band(z, height=0.25, thickness=0.08):
    """A metal band around the outside at height z (four slabs, so the box stays open inside)."""
    out = SIZE / 2 + thickness / 2
    return [
        box((SIZE + 2 * thickness, thickness, height), (0, -out, z)),
        box((SIZE + 2 * thickness, thickness, height), (0, out, z)),
        box((thickness, SIZE + 2 * thickness, height), (-out, 0, z)),
        box((thickness, SIZE + 2 * thickness, height), (out, 0, z)),
    ]


def steel():
    bands = [slab for z in (0.3, SIZE / 2, SIZE - 0.2) for slab in band(z)]
    rivets = [
        cyl(0.07, 0.08, (x, -SIZE / 2 - 0.08, z), rotation=(90, 0, 0), vertices=6)
        for x in (-1.2, -0.4, 0.4, 1.2)
        for z in (0.3, SIZE / 2, SIZE - 0.2)
    ]
    handles = [torus(0.3, 0.06, (s * (SIZE / 2 + 0.1), 0, 2.1), rotation=(0, 90, 0)) for s in (-1, 1)]
    return [
        ("Walls", (150, 155, 165), [open_shell(wall=0.12)]),
        ("Bands", (105, 110, 120), bands + handles),
        ("Rivets", (200, 205, 210), rivets),
        ("Hazard", (240, 200, 40), [box((1.4, 0.05, 0.5), (0, -SIZE / 2 - 0.03, 0.95))]),
    ]


def vault():
    lid_hinge_z = SIZE
    lid = box((SIZE + 0.1, 0.35, SIZE + 0.1), (0, SIZE / 2 + 0.9, lid_hinge_z + 1.2), rotation=(-20, 0, 0))
    wheel = [
        torus(0.5, 0.07, (0, -SIZE / 2 - 0.25, 1.5), rotation=(90, 0, 0)),
        *[limb((0, -SIZE / 2 - 0.25, 1.5), (dx * 0.5, -SIZE / 2 - 0.25, 1.5 + dz * 0.5), 0.05, vertices=6) for (dx, dz) in ((1, 0), (-1, 0), (0, 1), (0, -1))],
        cyl(0.12, 0.25, (0, -SIZE / 2 - 0.15, 1.5), rotation=(90, 0, 0)),
    ]
    bolts = [
        cyl(0.1, 0.1, (x * 1.25, -SIZE / 2 - 0.08, z), rotation=(90, 0, 0), vertices=8)
        for x in (-1, 1)
        for z in (0.35, 2.65)
    ]
    return [
        ("Walls", (70, 75, 90), [open_shell(wall=0.3)]),
        ("Lid", (85, 90, 105), [lid]),
        ("Rim", (180, 150, 70), [
            box((SIZE + 0.15, 0.2, 0.2), (0, -SIZE / 2, SIZE)),
            box((SIZE + 0.15, 0.2, 0.2), (0, SIZE / 2, SIZE)),
            box((0.2, SIZE + 0.15, 0.2), (-SIZE / 2, 0, SIZE)),
            box((0.2, SIZE + 0.15, 0.2), (SIZE / 2, 0, SIZE)),
            box((SIZE + 0.15, 0.2, 0.3), (0, SIZE / 2 + 0.05, SIZE - 0.1)),
        ]),
        ("Wheel", (215, 185, 90), wheel),
        ("Bolts", (200, 205, 210), bolts),
    ]


run({
    "Wood": wood,
    "Steel": steel,
    "Vault": vault,
})
