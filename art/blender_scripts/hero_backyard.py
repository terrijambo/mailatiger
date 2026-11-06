"""The Backyard realm (docs/REALMS_PLAN.md, realm 1): its landmark and garden props, in the KayKit style.
Front faces -Y (the game turns each one). Built on the City atlas like every hero model. Sizes in studs
(the player is 3.1 tall).

    MA_Treehouse       the landmark: a big oak with a plank clubhouse on a railed platform, a ladder, a round
                       window, a pennant on the roof and a rope swing on a branch (about 22 tall)
    MA_GardenHouseA    a cream cottage with a blue roof, red door, shutters and flower boxes
    MA_GardenHouseB    the same cottage in sky blue with a red roof and a teal door
    MA_PicketFence     one 9-stud white picket fence segment, 3 tall (lines yards and gardens)
    MA_Doghouse        a red doghouse with a name plate and a food bowl
    MA_VeggieBed       a raised bed of carrots and cabbages with a seed-packet marker
    MA_LilyPond        a stone-rimmed pond with lily pads, lilies, cattails and rocks
    MA_SwingSet        a red A-frame swing set with two swings
    MA_Gnome           a garden gnome
    MA_Flowerbed       a round stone flower bed full of blooms

    python tools/blender/bmcp.py run <absolute path to this file>
    (MA_ONLY=Treehouse runs one; names without the MA_)
"""

import importlib
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kk  # noqa: E402

importlib.reload(kk)

WOOD = (0.25, 0.85)
PLANK = (0.15, 0.6)
LEAF = (0.05, 0.7)


def start():
    kk.fresh_scene()
    kk.PARTS.clear()


# --- The treehouse -----------------------------------------------------------------------------------------
def treehouse():
    # Roots and a fat, slightly tapered trunk
    for k in range(5):
        a = k * math.tau / 5 + 0.3
        kk.box(f"Root{k}", (3.4, 1.1, 0.9), (math.cos(a) * 2.2, math.sin(a) * 2.2, 0.35), "Wood", "Taupe",
               bevel=0.25, rot=(0, math.radians(-12), a), light=WOOD)
    kk.prism("Trunk", 10, 2.3, 1.7, 9.6, (0, 0, 0), "Wood", "Taupe", bevel=0.2, light=WOOD)
    kk.prism("TrunkUpper", 10, 1.7, 1.3, 5.0, (0, 0.3, 9.4), "Wood", "Taupe", bevel=0.2, light=WOOD)
    # Bark knots
    for k, (a, z) in enumerate(((0.9, 3.2), (2.8, 5.6), (4.6, 2.1))):
        kk.ball(f"Knot{k}", 0.45, (math.cos(a) * 2.05, math.sin(a) * 2.05, z), "Wood", "Taupe", subdivisions=1,
                light=(0.4, 0.9))

    # Platform on beams, with a railing (gap at the front for the ladder)
    PZ = 9.0
    kk.box("Platform", (9.4, 9.0, 0.6), (0, 0, PZ), "Wood", "Sand", bevel=0.12, light=PLANK)
    for k in range(-4, 5):
        kk.box(f"PlatformBoard{k}", (0.08, 9.05, 0.62), (k * 1.04, 0, PZ), "Wood", "Taupe", bevel=0.0, light=WOOD)
    for sx in (-1, 1):
        for sy in (-1, 1):
            kk.box(f"Brace{sx}{sy}", (0.5, 0.5, 4.6), (sx * 2.4, sy * 2.3, PZ - 1.9), "Wood", "Taupe", bevel=0.08,
                   rot=(sy * math.radians(-32), sx * math.radians(32), 0), light=WOOD)
    rail_z = PZ + 0.3
    for sx in (-1, 1):
        for sy in (-1, 1):
            kk.box(f"RailPost{sx}{sy}", (0.4, 0.4, 2.0), (sx * 4.5, sy * 4.3, rail_z + 1.0), "Wood", "Taupe",
                   bevel=0.06, light=WOOD)
    for sx in (-1, 1):
        kk.box(f"RailSide{sx}", (0.3, 8.6, 0.3), (sx * 4.5, 0, rail_z + 1.9), "Wood", "Sand", bevel=0.05,
               light=PLANK)
        kk.box(f"RailSideLow{sx}", (0.25, 8.6, 0.25), (sx * 4.5, 0, rail_z + 1.0), "Wood", "Sand", bevel=0.04,
               light=PLANK)
    kk.box("RailBack", (9.0, 0.3, 0.3), (0, 4.3, rail_z + 1.9), "Wood", "Sand", bevel=0.05, light=PLANK)
    for sx in (-1, 1):  # the front rail stops short of the ladder
        kk.box(f"RailFront{sx}", (2.8, 0.3, 0.3), (sx * 3.1, -4.3, rail_z + 1.9), "Wood", "Sand", bevel=0.05,
               light=PLANK)
        kk.box(f"LadderPost{sx}", (0.4, 0.4, 2.0), (sx * 1.7, -4.3, rail_z + 1.0), "Wood", "Taupe", bevel=0.06,
               light=WOOD)

    # The clubhouse: plank walls, a red shingle roof, a round window, a door, a sign
    HZ0, HZ1 = PZ + 0.3, PZ + 4.6
    kk.box("HouseWalls", (6.0, 5.4, HZ1 - HZ0), (0, 0.9, (HZ0 + HZ1) / 2), "Wall", "Gold", bevel=0.12,
           light=(0.2, 0.55))
    for k in range(5):  # plank lines on the front and sides
        z = HZ0 + 0.85 * (k + 1)
        kk.box(f"PlankFront{k}", (6.06, 0.08, 0.1), (0, 0.9 - 2.72, z), "Wood", "Taupe", bevel=0.0, light=WOOD)
        for sx in (-1, 1):
            kk.box(f"PlankSide{sx}{k}", (0.08, 5.46, 0.1), (sx * 3.03, 0.9, z), "Wood", "Taupe", bevel=0.0,
                   light=WOOD)
    for sx in (-1, 1):
        for sy in (-1, 1):
            kk.box(f"HouseCorner{sx}{sy}", (0.45, 0.45, HZ1 - HZ0), (sx * 3.0, 0.9 + sy * 2.7, (HZ0 + HZ1) / 2),
                   "Wood", "Taupe", bevel=0.06, light=WOOD)
    RISE = 2.8
    kk.gable("HouseGable", 6.0, 5.4, RISE, (0, 0.9, HZ1), "Wall", "Gold", bevel=0.08, light=(0.1, 0.4))
    kk.shingles("HouseShingle", 6.0, 5.4, RISE, HZ1, rows=4, overhang=0.7, group="Roof", color="Red",
                light=(0.05, 0.75), thickness=0.3, center=(0, 0.9))
    kk.box("HouseRidge", (0.6, 6.9, 0.45), (0, 0.9, HZ1 + RISE + 0.3), "Roof", "BrickDark", bevel=0.1,
           light=(0.1, 0.6))
    # Round window (left) and a door (right)
    kk.prism("WindowFrame", 12, 0.95, 0.95, 0.3, (-1.4, 0.9 - 2.78, HZ0 + 2.4), "Trim", "White", bevel=0.05,
             light=(0.0, 0.3), rot=(math.pi / 2, 0, 0))
    kk.prism("WindowGlass", 12, 0.7, 0.7, 0.3, (-1.4, 0.9 - 2.86, HZ0 + 2.4), "Glass", "Sky", bevel=0.0,
             light=(0.0, 0.4), rot=(math.pi / 2, 0, 0))
    kk.box("WindowCrossH", (1.5, 0.1, 0.14), (-1.4, 0.9 - 2.98, HZ0 + 2.4), "Trim", "White", bevel=0.0)
    kk.box("WindowCrossV", (0.14, 0.1, 1.5), (-1.4, 0.9 - 2.98, HZ0 + 2.4), "Trim", "White", bevel=0.0)
    kk.box("DoorFrame", (1.9, 0.3, 3.3), (1.5, 0.9 - 2.75, HZ0 + 1.65), "Trim", "White", bevel=0.05)
    kk.box("Door", (1.5, 0.3, 3.0), (1.5, 0.9 - 2.85, HZ0 + 1.5), "Door", "Blue", bevel=0.06, light=(0.1, 0.5))
    kk.ball("DoorKnob", 0.13, (2.0, 0.9 - 3.05, HZ0 + 1.5), "Trim", "Gold", subdivisions=1)
    kk.box("SignBoard", (2.6, 0.2, 0.8), (0, 0.9 - 2.9, HZ1 + 0.9), "Wood", "Sand", bevel=0.06,
           rot=(0, math.radians(-4), 0), light=PLANK)
    kk.text3d("SignWord", "CLUB", 0.5, (0, 0.9 - 3.03, HZ1 + 0.9), depth=0.05, group="Trim", color="Red")
    # A pennant on a pole at the back of the roof
    kk.prism("FlagPole", 6, 0.08, 0.08, 3.0, (2.4, 2.9, HZ1 + 1.6), "Trim", "White", bevel=0.0)
    kk.box("Pennant", (1.6, 0.06, 0.9), (3.2, 2.9, HZ1 + 4.1), "Paint", "Amber", bevel=0.02, light=(0.0, 0.3))

    # The ladder up the front
    for sx in (-1, 1):
        kk.box(f"LadderRail{sx}", (0.28, 0.28, 10.2), (sx * 0.85, -4.9, 4.8), "Wood", "Sand", bevel=0.05,
               rot=(math.radians(-6), 0, 0), light=PLANK)
    for k in range(9):
        z = 0.9 + k * 1.05
        kk.box(f"Rung{k}", (1.7, 0.22, 0.22), (0, -4.9 - (9.6 - z) * 0.1 + 0.48, z), "Wood", "Taupe", bevel=0.03,
               light=WOOD)

    # A branch out to the right with a rope swing
    kk.box("SwingBranch", (6.0, 0.9, 0.8), (4.6, 0.2, 8.2), "Wood", "Taupe", bevel=0.2,
           rot=(0, math.radians(-10), 0), light=WOOD)
    for sy in (-1, 1):
        kk.box(f"SwingRope{sy}", (0.08, 0.08, 6.0), (6.2, 0.2 + sy * 0.6, 4.9), "Trim", "Sand", bevel=0.0)
    kk.box("SwingSeat", (0.9, 1.6, 0.2), (6.2, 0.2, 1.9), "Paint", "Blue", bevel=0.05, light=(0.1, 0.5))

    # The canopy: big faceted leaf clumps above and behind the clubhouse (the front stays visible)
    clumps = (
        ((0, 3.4, 19.2), 5.0, "Green"),
        ((-4.2, 1.8, 17.4), 3.8, "DeepGreen"),
        ((4.4, 2.2, 17.8), 4.0, "Green"),
        ((-1.6, 5.4, 16.2), 3.6, "DeepGreen"),
        ((2.8, 5.0, 21.4), 3.2, "Green"),
        ((-3.0, 3.2, 21.6), 3.0, "Olive"),
        ((6.6, 1.0, 14.6), 2.4, "DeepGreen"),
        ((-6.4, 0.6, 15.0), 2.2, "Green"),
    )
    for k, (at, radius, color) in enumerate(clumps):
        kk.ball(f"Leaves{k}", radius, at, "Plants", color, subdivisions=1, light=LEAF)
    kk.finish("MA_Treehouse", views=((-55, 15), (-125, 20)))


# --- Garden houses -----------------------------------------------------------------------------------------
def garden_house(model, wall, roof, door, shutter):
    W, D = 10.0, 8.0
    FRONT = -D / 2
    G0, G1 = 0.9, 6.6
    kk.box("Foundation", (W + 0.8, D + 0.8, G0), (0, 0, G0 / 2), "Stone", "WarmGrey", bevel=0.15, light=(0.3, 0.8))
    kk.box("Walls", (W, D, G1 - G0), (0, 0, (G0 + G1) / 2), "Wall", wall, bevel=0.12, light=(0.1, 0.45))
    for sx in (-1, 1):
        for sy in (-1, 1):
            kk.box(f"Corner{sx}{sy}", (0.55, 0.55, G1 - G0), (sx * W / 2, sy * D / 2, (G0 + G1) / 2), "Trim",
                   "White", bevel=0.06, light=(0.0, 0.3))
    kk.box("Eave", (W + 0.6, D + 0.6, 0.4), (0, 0, G1 + 0.1), "Trim", "White", bevel=0.08, light=(0.0, 0.3))
    RISE = 4.2
    kk.gable("Gable", W, D, RISE, (0, 0, G1 + 0.2), "Wall", wall, bevel=0.08, light=(0.05, 0.35), rot_z=0)
    kk.shingles("Shingle", W, D, RISE, G1 + 0.2, rows=5, overhang=0.8, group="Roof", color=roof,
                light=(0.05, 0.75), thickness=0.3)
    kk.box("Ridge", (0.7, D + 1.8, 0.5), (0, 0, G1 + RISE + 0.5), "Roof", "Slate", bevel=0.1, light=(0.1, 0.6))
    kk.box("Chimney", (1.4, 1.4, 3.8), (2.8, 1.8, G1 + 3.2), "Stone", "BrickDark", bevel=0.1, light=(0.1, 0.7))
    kk.box("ChimneyCap", (1.8, 1.8, 0.35), (2.8, 1.8, G1 + 5.2), "Stone", "WarmGrey", bevel=0.08, light=(0.2, 0.6))
    # Front door under a little porch roof, with a step
    kk.box("Step", (3.0, 1.2, 0.45), (0, FRONT - 0.8, 0.22), "Stone", "WarmGrey", bevel=0.1, light=(0.2, 0.6))
    kk.box("DoorFrame", (2.4, 0.3, 3.9), (0, FRONT - 0.05, G0 + 1.95), "Trim", "White", bevel=0.05,
           light=(0.0, 0.3))
    kk.box("Door", (1.9, 0.3, 3.5), (0, FRONT - 0.15, G0 + 1.75), "Door", door, bevel=0.06, light=(0.1, 0.5))
    kk.box("DoorWindow", (1.0, 0.32, 0.8), (0, FRONT - 0.2, G0 + 2.7), "Glass", "Sky", bevel=0.03)
    kk.ball("Knob", 0.12, (0.6, FRONT - 0.38, G0 + 1.7), "Trim", "Gold", subdivisions=1)
    kk.gable("PorchRoof", 3.4, 1.6, 0.9, (0, FRONT - 0.7, G0 + 4.1), "Roof", roof, bevel=0.06, light=(0.05, 0.6),
             rot_z=0)
    for sx in (-1, 1):
        kk.box(f"PorchBracket{sx}", (0.2, 0.9, 0.2), (sx * 1.4, FRONT - 0.55, G0 + 3.95), "Trim", "White",
               bevel=0.0)
    # Two shuttered windows with flower boxes
    flower_colors = ("Magenta", "Amber", "Coral", "White")
    for k, sx in enumerate((-1, 1)):
        x = sx * 3.0
        z = G0 + 2.6
        kk.box(f"WinFrame{sx}", (2.0, 0.3, 1.9), (x, FRONT - 0.05, z), "Trim", "White", bevel=0.05,
               light=(0.0, 0.3))
        kk.box(f"WinGlass{sx}", (1.6, 0.32, 1.5), (x, FRONT - 0.1, z), "Glass", "Sky", bevel=0.0)
        kk.box(f"WinBarV{sx}", (0.12, 0.36, 1.5), (x, FRONT - 0.14, z), "Trim", "White", bevel=0.0)
        kk.box(f"WinBarH{sx}", (1.6, 0.36, 0.12), (x, FRONT - 0.14, z), "Trim", "White", bevel=0.0)
        for side in (-1, 1):
            kk.box(f"Shutter{sx}{side}", (0.6, 0.2, 1.9), (x + side * 1.35, FRONT - 0.1, z), "Paint", shutter,
                   bevel=0.04, light=(0.1, 0.5))
        kk.box(f"FlowerBox{sx}", (2.2, 0.7, 0.5), (x, FRONT - 0.4, z - 1.15), "Wood", "Taupe", bevel=0.06,
               light=WOOD)
        for i in range(4):
            kk.ball(f"Bloom{sx}{i}", 0.3, (x - 0.75 + i * 0.5, FRONT - 0.42, z - 0.75), "Plants",
                    flower_colors[(i + k) % 4], subdivisions=1, light=(0.0, 0.3))
        kk.box(f"Leaves{sx}", (2.0, 0.5, 0.25), (x, FRONT - 0.4, z - 0.85), "Plants", "Green", bevel=0.05,
               light=LEAF)
    # A round attic window in the gable
    kk.prism("AtticFrame", 10, 0.7, 0.7, 0.25, (0, FRONT - 0.05, G1 + 1.6), "Trim", "White", bevel=0.04,
             rot=(math.pi / 2, 0, 0), light=(0.0, 0.3))
    kk.prism("AtticGlass", 10, 0.5, 0.5, 0.25, (0, FRONT - 0.12, G1 + 1.6), "Glass", "Sky", bevel=0.0,
             rot=(math.pi / 2, 0, 0))
    kk.finish(model, views=((-55, 15), (-125, 22)))


# --- Picket fence segment ----------------------------------------------------------------------------------
def picket_fence():
    L = 9.0
    for sx in (-1, 1):
        kk.box(f"Post{sx}", (0.55, 0.55, 3.1), (sx * (L / 2 - 0.27), 0, 1.55), "Wood", "White", bevel=0.06,
               light=(0.0, 0.35))
        kk.prism(f"PostCap{sx}", 4, 0.42, 0.05, 0.45, (sx * (L / 2 - 0.27), 0, 3.1), "Wood", "White", bevel=0.0,
                 spin=math.pi / 4, light=(0.0, 0.3))
    for z in (0.85, 2.05):
        kk.box(f"Rail{z}", (L - 0.4, 0.22, 0.3), (0, 0.18, z), "Wood", "White", bevel=0.04, light=(0.05, 0.4))
    count = 10
    for i in range(count):
        x = -L / 2 + 0.9 + i * (L - 1.8) / (count - 1)
        kk.box(f"Picket{i}", (0.48, 0.16, 2.4), (x, 0, 1.35), "Wood", "White", bevel=0.04, light=(0.0, 0.35))
        kk.prism(f"PicketTip{i}", 4, 0.34, 0.03, 0.4, (x, 0, 2.55), "Wood", "White", bevel=0.0, spin=math.pi / 4,
                 light=(0.0, 0.3))
    kk.finish("MA_PicketFence", views=((-55, 15), (-125, 25)))


# --- Doghouse ----------------------------------------------------------------------------------------------
def doghouse():
    W, D, H = 3.6, 4.4, 2.6
    kk.box("Base", (W + 0.4, D + 0.4, 0.3), (0, 0, 0.15), "Wood", "Taupe", bevel=0.06, light=WOOD)
    kk.box("Walls", (W, D, H), (0, 0, 0.3 + H / 2), "Wall", "Red", bevel=0.1, light=(0.1, 0.5))
    for k in range(3):
        kk.box(f"Plank{k}", (W + 0.04, 0.06, 0.08), (0, -D / 2, 0.3 + 0.7 * (k + 1)), "Wood", "BrickDark",
               bevel=0.0)
    kk.gable("Gable", W, D, 1.6, (0, 0, 0.3 + H), "Wall", "Red", bevel=0.06, light=(0.05, 0.4))
    kk.shingles("Shingle", W, D, 1.6, 0.3 + H, rows=3, overhang=0.4, group="Roof", color="Blue",
                light=(0.05, 0.7), thickness=0.24)
    kk.box("Door", (1.5, 0.3, 1.6), (0, -D / 2 - 0.02, 0.3 + 0.8), "Trim", "Ink", bevel=0.05)
    kk.prism("DoorArch", 12, 0.75, 0.75, 0.3, (0, -D / 2 - 0.02, 0.3 + 1.6), "Trim", "Ink", bevel=0.0,
             rot=(math.pi / 2, 0, 0))
    kk.box("DoorTrim", (1.9, 0.26, 0.2), (0, -D / 2 - 0.08, 0.3 + 2.45), "Trim", "White", bevel=0.03)
    kk.box("NamePlate", (1.4, 0.15, 0.45), (0, -D / 2 - 0.1, 0.3 + 2.75), "Wood", "Sand", bevel=0.04,
           light=PLANK)
    kk.text3d("Name", "REX", 0.32, (0, -D / 2 - 0.2, 0.3 + 2.75), depth=0.04, group="Trim", color="Ink")
    # A food bowl with kibble, and a bone
    kk.prism("Bowl", 12, 0.55, 0.7, 0.35, (1.9, -D / 2 - 0.9, 0), "Trim", "Blue", bevel=0.04, light=(0.1, 0.5))
    kk.prism("Kibble", 10, 0.55, 0.55, 0.1, (1.9, -D / 2 - 0.9, 0.3), "Trim", "Orange", bevel=0.0)
    kk.box("BoneMid", (0.9, 0.22, 0.2), (-1.7, -D / 2 - 0.8, 0.1), "Trim", "White", bevel=0.05, rot=(0, 0, 0.4))
    for side in (-1, 1):
        for k in (-1, 1):
            kk.ball(f"BoneEnd{side}{k}", 0.16,
                    (-1.7 + side * 0.45 * math.cos(0.4) - k * 0.1 * math.sin(0.4),
                     -D / 2 - 0.8 + side * 0.45 * math.sin(0.4) + k * 0.1 * math.cos(0.4), 0.12),
                    "Trim", "White", subdivisions=1)
    kk.finish("MA_Doghouse", views=((-55, 18), (-125, 25)))


# --- Vegetable bed -----------------------------------------------------------------------------------------
def veggie_bed():
    L, W = 8.0, 3.2
    kk.box("BedFrame", (L, W, 0.8), (0, 0, 0.4), "Wood", "Taupe", bevel=0.08, light=WOOD)
    kk.box("Soil", (L - 0.5, W - 0.5, 0.2), (0, 0, 0.75), "Stone", "BrickDark", bevel=0.05, light=(0.3, 0.8))
    for sx in (-1, 1):
        for sy in (-1, 1):
            kk.box(f"CornerPost{sx}{sy}", (0.4, 0.4, 1.0), (sx * (L / 2 - 0.1), sy * (W / 2 - 0.1), 0.5), "Wood",
                   "Sand", bevel=0.05, light=PLANK)
    # Front row: carrots (orange shoulders peeking out under leafy tops); back row: cabbages
    for i in range(6):
        x = -L / 2 + 0.9 + i * 1.24
        kk.prism(f"Carrot{i}", 8, 0.26, 0.2, 0.3, (x, -0.65, 0.78), "Plants", "Orange", bevel=0.0,
                 light=(0.0, 0.3))
        for k in range(3):
            a = k * math.tau / 3
            kk.box(f"CarrotLeaf{i}{k}", (0.12, 0.12, 0.8), (x + math.cos(a) * 0.12, -0.65 + math.sin(a) * 0.12, 1.4),
                   "Plants", "Green", bevel=0.0, rot=(math.sin(a) * 0.4, math.cos(a) * 0.4, 0), light=LEAF)
    for i in range(4):
        x = -L / 2 + 1.2 + i * 1.85
        kk.ball(f"Cabbage{i}", 0.55, (x, 0.65, 1.25), "Plants", "Olive", subdivisions=1, light=LEAF)
        for k in range(4):
            a = k * math.tau / 4 + 0.4
            kk.ball(f"CabbageLeaf{i}{k}", 0.38, (x + math.cos(a) * 0.45, 0.65 + math.sin(a) * 0.45, 1.05), "Plants",
                    "Green", subdivisions=1, light=LEAF)
    # A seed-packet marker on a stick
    kk.box("MarkerStick", (0.1, 0.1, 1.4), (L / 2 - 0.7, -W / 2 + 0.3, 1.4), "Wood", "Sand", bevel=0.0)
    kk.box("SeedPacket", (0.7, 0.08, 0.9), (L / 2 - 0.7, -W / 2 + 0.25, 2.2), "Paint", "White", bevel=0.02,
           light=(0.0, 0.3))
    kk.box("PacketCarrot", (0.3, 0.1, 0.4), (L / 2 - 0.7, -W / 2 + 0.2, 2.15), "Paint", "Orange", bevel=0.0)
    kk.finish("MA_VeggieBed", views=((-55, 25), (-125, 30)))


# --- Lily pond ---------------------------------------------------------------------------------------------
def lily_pond():
    kk.masonry_ring("Rim", 12, 4.4, 0.9, 0.7, 0.0, courses=1, per_side=(2,), group="Stone", color="WarmGrey",
                    light=(0.2, 0.7))
    kk.ngon_slab("Water", 12, 4.1, 0.15, 0.35, group="Water", color="Sky")
    kk.ngon_slab("PondBed", 12, 4.1, 0.1, 0.1, group="Stone", color="Teal")
    pads = ((-1.6, -1.2, 0.8), (1.4, 0.8, 0.65), (0.2, 2.1, 0.7), (-2.2, 1.4, 0.55), (2.3, -1.6, 0.6),
            (0.6, -2.4, 0.5))
    for k, (x, y, r) in enumerate(pads):
        kk.prism(f"Pad{k}", 9, r, r, 0.08, (x, y, 0.5), "Plants", "Green", bevel=0.0, spin=k * 0.9, light=LEAF)
    for k, (x, y, color) in enumerate(((-1.5, -1.0, "Magenta"), (1.5, 0.9, "White"), (-2.2, 1.5, "Coral"))):
        for p in range(5):
            a = p * math.tau / 5
            kk.box(f"Petal{k}{p}", (0.42, 0.18, 0.12), (x + math.cos(a) * 0.2, y + math.sin(a) * 0.2, 0.68),
                   "Plants", color, bevel=0.03, rot=(0, math.radians(-25), a), light=(0.0, 0.3))
        kk.ball(f"LilyHeart{k}", 0.12, (x, y, 0.72), "Plants", "Amber", subdivisions=1)
    # Cattails at the back edge and a few rocks
    for k in range(5):
        a = math.radians(70 + k * 12)
        x, y = math.cos(a) * 4.6, math.sin(a) * 4.6
        h = 2.0 + (k % 3) * 0.4
        kk.box(f"Reed{k}", (0.1, 0.1, h), (x, y, 0.7 + h / 2), "Plants", "Olive", bevel=0.0,
               rot=(0, (k - 2) * 0.08, 0), light=LEAF)
        kk.prism(f"Cattail{k}", 6, 0.16, 0.16, 0.6, (x, y, 0.7 + h - 0.3), "Plants", "Taupe", bevel=0.0)
    for k, (a, r) in enumerate(((3.6, 0.7), (4.3, 0.5), (5.4, 0.6))):
        kk.ball(f"Rock{k}", r, (math.cos(a) * 5.2, math.sin(a) * 5.2, 0.3), "Stone", "Grey", subdivisions=1,
                light=(0.3, 0.8))
    kk.finish("MA_LilyPond", views=((-55, 35), (-125, 40)))


# --- Swing set ---------------------------------------------------------------------------------------------
def swing_set():
    H, Wd = 8.0, 11.0
    for sx in (-1, 1):
        for sy in (-1, 1):
            kk.box(f"Leg{sx}{sy}", (0.45, 0.45, 8.4), (sx * Wd / 2, sy * 1.2, H / 2), "Paint", "Red", bevel=0.06,
                   rot=(sy * math.radians(-9), 0, 0), light=(0.1, 0.5))
        kk.box(f"Brace{sx}", (0.3, 2.0, 0.3), (sx * Wd / 2, 0, 2.6), "Paint", "Red", bevel=0.04, light=(0.1, 0.5))
    kk.cylinder_x("TopBar", 0.3, Wd + 0.8, (0, 0, H), "Paint", "Amber", sides=10)
    for k, x in enumerate((-2.4, 2.4)):
        for side in (-0.55, 0.55):
            kk.box(f"Chain{k}{side}", (0.08, 0.08, 5.4), (x + side, 0, H - 2.75), "Metal", "Steel", bevel=0.0)
        kk.box(f"Seat{k}", (1.5, 0.8, 0.22), (x, 0, H - 5.5), "Paint", ("Blue", "Teal")[k], bevel=0.06,
               light=(0.1, 0.5))
    kk.finish("MA_SwingSet", views=((-55, 15), (-125, 22)))


# --- Garden gnome ------------------------------------------------------------------------------------------
def gnome():
    kk.prism("Boots", 8, 0.5, 0.5, 0.25, (0, 0, 0), "Paint", "Taupe", bevel=0.04)
    kk.prism("Body", 10, 0.55, 0.42, 0.9, (0, 0, 0.22), "Paint", "Blue", bevel=0.06, light=(0.1, 0.5))
    kk.prism("Belt", 10, 0.5, 0.5, 0.12, (0, 0, 0.55), "Paint", "Ink", bevel=0.0)
    kk.box("Buckle", (0.18, 0.06, 0.14), (0, -0.5, 0.61), "Trim", "Gold", bevel=0.0)
    kk.ball("Head", 0.38, (0, 0, 1.35), "Paint", "Sand", subdivisions=2, light=(0.0, 0.3))
    kk.ball("Nose", 0.12, (0, -0.37, 1.32), "Paint", "Coral", subdivisions=1)
    kk.prism("Beard", 8, 0.42, 0.05, 0.75, (0, -0.12, 1.25), "Paint", "White", bevel=0.0,
             rot=(math.pi, 0, 0), light=(0.0, 0.3))
    kk.prism("Hat", 10, 0.45, 0.02, 1.0, (0, 0.05, 1.55), "Paint", "Red", bevel=0.0, light=(0.0, 0.4))
    for sx in (-1, 1):
        kk.ball(f"Eye{sx}", 0.05, (sx * 0.13, -0.34, 1.44), "Trim", "Ink", subdivisions=1)
    kk.finish("MA_Gnome", views=((-35, 10), (-145, 15)))


# --- Flower bed --------------------------------------------------------------------------------------------
def flowerbed():
    kk.masonry_ring("Edge", 10, 2.8, 0.6, 0.6, 0.0, courses=1, per_side=(2,), group="Stone", color="Sand",
                    light=(0.2, 0.7))
    kk.ngon_slab("Soil", 10, 2.6, 0.2, 0.4, group="Stone", color="BrickDark")
    colors = ("Magenta", "Amber", "White", "Coral", "Red", "SlateBlue")
    k = 0
    for ring, (radius, count) in enumerate(((0.0, 1), (1.1, 6), (2.0, 10))):
        for i in range(count):
            a = i * math.tau / count + ring * 0.3
            x, y = math.cos(a) * radius, math.sin(a) * radius
            h = 0.7 + (2 - ring) * 0.35
            kk.box(f"Stem{k}", (0.08, 0.08, h), (x, y, 0.55 + h / 2), "Plants", "Green", bevel=0.0)
            kk.ball(f"Leaf{k}", 0.22, (x + 0.12, y, 0.75), "Plants", "DeepGreen", subdivisions=1, light=LEAF)
            kk.ball(f"Bloom{k}", 0.3 if ring < 2 else 0.24, (x, y, 0.55 + h + 0.1), "Plants",
                    colors[k % len(colors)], subdivisions=1, light=(0.0, 0.3))
            k += 1
    kk.finish("MA_Flowerbed", views=((-55, 30), (-125, 35)))


BUILDS = {
    "Treehouse": treehouse,
    "GardenHouseA": lambda: garden_house("MA_GardenHouseA", "Cream", "Blue", "Red", "Blue"),
    "GardenHouseB": lambda: garden_house("MA_GardenHouseB", "Sky", "Red", "Teal", "White"),
    "PicketFence": picket_fence,
    "Doghouse": doghouse,
    "VeggieBed": veggie_bed,
    "LilyPond": lily_pond,
    "SwingSet": swing_set,
    "Gnome": gnome,
    "Flowerbed": flowerbed,
}

only = os.environ.get("MA_ONLY")
for key, build in BUILDS.items():
    if not only or only == key:
        start()
        build()
