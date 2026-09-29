"""
Cardboard Box: an open 3x3x3 stud box with its four flaps folded out. The game's BOX stage
puts it in the arena while you pet and tape (see ReplicatedStorage > BoxModels in README).
Run:  blender --background --factory-startup --python art/blender_scripts/cardboard_box.py
"""

import math
import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402

common.reset()

CARDBOARD = common.material("Cardboard", (198, 156, 109))
FLAP = common.material("CardboardFlap", (182, 140, 95))
INSIDE = common.material("CardboardInside", (150, 112, 72))

SIZE = 3.0
WALL = 0.08

# Walls and bottom: a cube with the top removed, given some thickness
shell = common.box((SIZE, SIZE, SIZE), (0, 0, SIZE / 2))
common.remove_faces(shell, lambda face: face.normal.z > 0.9)
thickness = shell.modifiers.new("Walls", "SOLIDIFY")
thickness.thickness = WALL
thickness.offset = -1  # grow inward so the outside stays exactly 3x3x3
common.apply_modifier(shell, thickness)
body = common.combine([shell], "Body", CARDBOARD)

# A darker floor inside so the box reads as open and empty
inside = common.combine([common.box((SIZE - 2 * WALL, SIZE - 2 * WALL, 0.02), (0, 0, WALL + 0.01))], "Inside", INSIDE)

# Four flaps, hinged at the top edges and folded outward
FLAP_HEIGHT = 1.4
TILT = math.radians(40)


def flap(width_x, width_y, hinge, rotation):
    piece = common.box((width_x, width_y, FLAP_HEIGHT), (0, 0, 0))
    # Shift the mesh up so the object's origin is the flap's bottom edge (the hinge)...
    for vertex in piece.data.vertices:
        vertex.co.z += 0.5
    # ...then put the hinge on the box's top edge and fold the flap outward around it
    piece.location = hinge
    piece.rotation_euler = rotation
    return piece


flaps = common.combine(
    [
        flap(SIZE, WALL, (0, -SIZE / 2, SIZE), (TILT, 0, 0)),  # front (-Y)
        flap(SIZE, WALL, (0, SIZE / 2, SIZE), (-TILT, 0, 0)),  # back (+Y)
        flap(WALL, SIZE, (-SIZE / 2, 0, SIZE), (0, -TILT, 0)),  # left (-X)
        flap(WALL, SIZE, (SIZE / 2, 0, SIZE), (0, TILT, 0)),  # right (+X)
    ],
    "Flaps",
    FLAP,
)

common.finish("Cardboard", [body, inside, flaps], target_height=1.6, distance=11)
