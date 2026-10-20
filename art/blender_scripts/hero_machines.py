"""The seven Post Office machines (docs/ASSET_PLAN.md 3b), as hero models for client/MachineStations.luau.

Each machine is the same chunky arch over a conveyor belt (bolted steel legs, a coloured housing with a glowing
strip, vents and a nameplate on the plaza side), topped by what it does. The parts the game animates are
separate pieces with the names it looks for: Plunger + Rod (Stamp), Needle (Scale), Roller1/Roller2 (Fragile),
Arm (Sorter), Flash (Express), Drone1/Drone2 (Drone), RocketBody/RocketNose/Flame (Rocket).

Frame: the same as the old block machines (MachineStations.build, before its 1.4x scale): the origin is the
middle of the belt at the floor, the belt runs along Y (Roblox Z), +X faces the plaza. An "Origin" marker part
sits at (0,0,0) so the game can line the model up exactly; it removes the marker.

    python tools/blender/bmcp.py run art/blender_scripts/hero_machines.py
"""

import importlib
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kk  # noqa: E402

importlib.reload(kk)

# (machine id, housing swatch, light range on that swatch)
MACHINES = [
    ("Stamp", "Red", (0.1, 0.6)),
    ("Scale", "Blue", (0.05, 0.45)),
    ("Fragile", "Gold", (0.25, 0.6)),
    ("Sorter", "Green", (0.05, 0.6)),
    ("Express", "Olive", (0.0, 0.35)),
    ("Drone", "Magenta", (0.85, 1.0)),
    ("Rocket", "Orange", (0.0, 0.5)),
]
STEEL, DARK = (0.1, 0.6), (0.3, 0.8)


def chassis(color, light):
    """The arch every machine shares."""
    kk.box("Origin", (0.1, 0.1, 0.1), (0, 0, 0.05), "Origin", "Ink", bevel=0.0)
    # Conveyor: frame, belt, end rollers, a little in-tray lip
    kk.box("BeltFrame", (3.3, 5.4, 0.85), (0, 0, 0.43), "Frame", "Slate", bevel=0.12, light=DARK)
    kk.box("Belt", (2.7, 5.6, 0.22), (0, 0, 0.98), "Belt", "Charcoal", bevel=0.04, light=(0.2, 0.6))
    for y in (-2.75, 2.75):
        kk.cylinder_x(f"EndRoller{y}", 0.32, 3.0, (0, y, 0.88), "Frame", "Steel", light=STEEL)
    for k in range(5):
        kk.box(f"BeltSlat{k}", (2.72, 0.12, 0.05), (0, -2.0 + k, 1.11), "Belt", "Slate", bevel=0.0, light=DARK)
    # Legs with feet and bolts
    for side in (-1, 1):
        x = side * 2.35
        kk.box(f"Leg{side}", (1.0, 3.0, 4.2), (x, 0, 2.5), "Frame", "Steel", bevel=0.18, light=STEEL)
        kk.box(f"Foot{side}", (1.5, 3.6, 0.45), (x, 0, 0.23), "Frame", "Slate", bevel=0.12, light=DARK)
        for z in (1.5, 3.4):
            for y in (-1.0, 1.0):
                kk.cylinder_x(f"Bolt{side}{z}{y}", 0.13, 1.08, (x, y, z), "Trim", "Gold", sides=8, bevel=0.0,
                              light=(0.0, 0.4))
    # Housing: coloured, chunky, with a dark trim band, a glowing strip and vents
    kk.box("Housing", (5.9, 3.6, 2.0), (0, 0, 5.4), "Body", color, bevel=0.28, light=light)
    kk.box("HousingTrim", (6.1, 3.8, 0.34), (0, 0, 4.45), "Frame", "Slate", bevel=0.1, light=DARK)
    kk.box("HousingCap", (5.3, 3.0, 0.3), (0, 0, 6.5), "Frame", "Slate", bevel=0.1, light=DARK)
    kk.box("LightStrip", (4.6, 0.22, 0.28), (0, -1.86, 5.35), "Glow", "Amber", bevel=0.04, light=(0.0, 0.3))
    kk.box("LightStripBack", (4.6, 0.22, 0.28), (0, 1.86, 5.35), "Glow", "Amber", bevel=0.04, light=(0.0, 0.3))
    for k in range(3):
        kk.box(f"Vent{k}", (0.12, 1.9, 0.16), (-2.98, 0, 5.0 + k * 0.38), "Frame", "Ink", bevel=0.0)
    # Nameplate facing the plaza (+X)
    kk.box("Nameplate", (0.16, 2.4, 1.0), (3.0, 0, 5.4), "Trim", "Gold", bevel=0.06, light=(0.0, 0.4))
    kk.box("NameplateFace", (0.18, 1.9, 0.6), (3.05, 0, 5.4), "Trim", "White", bevel=0.04, light=(0.0, 0.3))


def word(text):
    """The machine's word on its nameplate (facing the plaza)."""
    kk.text3d("Word", text, 0.5 if len(text) <= 5 else 0.42, (3.12, 0, 5.4), depth=0.06, group="Trim",
              color="Ink", rot=(math.pi / 2, 0, math.pi / 2), light=(0.1, 0.5))


def stamp():
    # The big rubber stamp: a red block with a black rubber pad, on a steel rod (both move down)
    kk.box("PlungerBlock", (2.1, 2.1, 0.9), (0, 0, 3.75), "Plunger", "Red", bevel=0.18, light=(0.1, 0.6))
    kk.box("PlungerPad", (1.9, 1.9, 0.3), (0, 0, 3.2), "Plunger", "Ink", bevel=0.06, light=(0.2, 0.6))
    kk.box("PlungerHeart", (0.7, 0.7, 0.08), (0, 0, 3.02), "Plunger", "Coral", bevel=0.02, light=(0.0, 0.3))
    kk.prism("Rod", 8, 0.28, 0.28, 1.0, (0, 0, 4.15), "Rod", "Steel", bevel=0.03, light=STEEL)
    # The handle and red knob on top
    kk.prism("Handle", 8, 0.22, 0.22, 1.7, (0, 0, 6.6), "Trim", "Steel", bevel=0.02, light=STEEL)
    kk.ball("Knob", 0.6, (0, 0, 8.55), "Trim", "Red", light=(0.0, 0.5))
    word("STAMP")


def scale():
    # (its dial covers the nameplate, so the word goes on the back)
    # A big dial on the plaza side with ticks, a gold rim and a red needle; a weighing pan on top with weights
    kk.prism("DialRim", 20, 1.75, 1.75, 0.25, (3.0, 0, 5.75), "Trim", "Gold", bevel=0.04, light=(0.0, 0.4),
             rot=(0, math.pi / 2, 0))
    kk.prism("DialFace", 20, 1.55, 1.55, 0.27, (3.03, 0, 5.75), "Trim", "White", bevel=0.0, light=(0.0, 0.2),
             rot=(0, math.pi / 2, 0))
    for k in range(9):
        a = math.radians(-120 + k * 30)
        kk.box(f"Tick{k}", (0.3, 0.1, 0.3), (3.18, math.sin(a) * 1.25, 5.75 + math.cos(a) * 1.25), "Trim", "Ink",
               bevel=0.0, rot=(-a, 0, 0))
    kk.box("Needle", (0.12, 0.16, 1.25), (3.24, 0, 5.75 + 0.55), "Needle", "Red", bevel=0.02, light=(0.0, 0.4))
    kk.prism("NeedleHub", 8, 0.2, 0.2, 0.2, (3.25, 0, 5.75), "Trim", "Ink", bevel=0.0, rot=(0, math.pi / 2, 0))
    kk.prism("PanPost", 8, 0.3, 0.3, 0.6, (0, 0, 6.6), "Trim", "Steel", bevel=0.03, light=STEEL)
    kk.prism("Pan", 16, 1.5, 1.8, 0.35, (0, 0, 7.15), "Trim", "Steel", bevel=0.05, light=STEEL)
    for k, (x, y, r) in enumerate([(-0.5, -0.4, 0.45), (0.5, 0.2, 0.35), (0.0, 0.7, 0.28)]):
        kk.prism(f"Weight{k}", 8, r, r * 0.8, r * 1.3, (x, y, 7.5), "Trim", "Gold", bevel=0.05, light=(0.1, 0.5))


def fragile():
    word("HANDLE")
    # Two padded rollers that spin (they hang under the housing), bubbles and a FRAGILE sign on top
    for k, y in enumerate((-0.8, 0.8), start=1):
        kk.cylinder_x(f"Roller{k}", 0.55, 4.0, (0, y, 3.25), f"Roller{k}", "Sky", sides=14, bevel=0.06,
                      light=(0.0, 0.4))
        kk.cylinder_x(f"RollerAxle{k}", 0.16, 4.6, (0, y, 3.25), f"Roller{k}", "Steel", sides=8, bevel=0.0)
    for k in range(9):
        a = k * 2.399
        r = 0.35 + (k % 3) * 0.12
        kk.ball(f"Bubble{k}", r, (math.cos(a) * 1.4, math.sin(a) * 0.9, 6.9 + (k % 3) * 0.3), "Bubbles", "Sky",
                light=(0.0, 0.3))
    kk.box("SignBoard", (0.3, 3.4, 1.05), (0.9, 0, 7.2), "Trim", "Red", bevel=0.1, light=(0.05, 0.5))
    kk.text3d("SignWord", "FRAGILE", 0.62, (1.08, 0, 7.2), depth=0.06, group="Trim", color="White",
              rot=(math.pi / 2, 0, math.pi / 2))


def sorter():
    word("SORT")
    # A wall of pigeonholes with letters sticking out, and a yellow sorting arm under the housing
    kk.box("SlotWall", (1.2, 5.0, 2.3), (-0.4, 0, 7.65), "Frame", "Taupe", bevel=0.1, light=(0.2, 0.8))
    for row in range(2):
        for col in range(4):
            y = -1.8 + col * 1.2
            z = 7.1 + row * 1.1
            kk.box(f"Hole{row}{col}", (0.2, 0.95, 0.75), (0.22, y, z), "Frame", "Ink", bevel=0.03)
            if (row + col) % 3 != 1:
                kk.box(f"Letter{row}{col}", (0.6, 0.7, 0.42), (0.35, y + 0.05, z - 0.08), "Trim",
                       ("White", "Cream", "Sky")[(row + col) % 3], bevel=0.04, light=(0.0, 0.3))
    kk.box("Arm", (0.35, 2.7, 0.35), (0, 0, 3.9), "Arm", "Amber", bevel=0.08, light=(0.0, 0.3))
    kk.prism("ArmHub", 8, 0.35, 0.35, 0.4, (0, 0, 4.1), "Trim", "Steel", bevel=0.03, light=STEEL)


def express():
    # A big lightning bolt on top, racing stripes down the legs, and the flash plate under the housing
    # Three chunky segments zig-zagging down: right, left, right
    for k, (y, z, tilt) in enumerate([(0.35, 8.55, -0.55), (-0.15, 7.75, 0.0), (0.2, 7.0, -0.55)]):
        size = (0.4, 1.9, 0.55) if k == 1 else (0.4, 0.55, 1.6)
        kk.box(f"Bolt{k}", size, (0, y, z), "Glow", "Amber", bevel=0.08, rot=(tilt, 0, 0), light=(0.0, 0.3))
    kk.prism("BoltTip", 4, 0.35, 0.02, 0.9, (0, 0.45, 6.05), "Glow", "Amber", bevel=0.0, light=(0.0, 0.3),
             rot=(math.pi, 0, 0))
    for side in (-1, 1):
        for y in (-0.9, 0.9):
            kk.box(f"Stripe{side}{y}", (1.04, 0.26, 3.6), (side * 2.35, y, 2.6), "Glow", "Amber", bevel=0.02,
                   light=(0.0, 0.3))
    kk.box("Flash", (2.4, 2.6, 0.2), (0, 0, 4.15), "Flash", "White", bevel=0.02, light=(0.0, 0.2))
    word("EXPRESS")


def drone():
    word("DRONE")
    # A round landing pad on top with an H, and two little quadcopters hovering over it
    kk.prism("PadPost", 8, 0.5, 0.4, 0.5, (0, 0, 6.6), "Frame", "Slate", bevel=0.04, light=DARK)
    kk.prism("Pad", 20, 2.1, 2.1, 0.22, (0, 0, 7.05), "Frame", "Slate", bevel=0.04, light=DARK)
    kk.prism("PadRing", 20, 1.75, 1.75, 0.04, (0, 0, 7.27), "Trim", "Amber", bevel=0.0, light=(0.0, 0.3))
    for k, (size, at) in enumerate([((0.25, 1.4, 0.03), (-0.4, 0, 7.3)), ((0.25, 1.4, 0.03), (0.4, 0, 7.3)),
                                     ((0.8, 0.25, 0.03), (0, 0, 7.3))]):
        kk.box(f"PadH{k}", size, at, "Trim", "White", bevel=0.0)
    for k, x in enumerate((-1.1, 1.1), start=1):
        group = f"Drone{k}"
        kk.box(f"Body{k}", (0.85, 0.85, 0.42), (x, 0, 7.6), group, "White", bevel=0.14, light=(0.0, 0.4))
        kk.box(f"Eye{k}", (0.1, 0.4, 0.16), (x + 0.43, 0, 7.62), group, "Sky", bevel=0.02, light=(0.0, 0.3))
        for cx in (-0.55, 0.55):
            for cy in (-0.55, 0.55):
                kk.box(f"ArmD{k}{cx}{cy}", (0.6, 0.1, 0.08), (x + cx / 2, cy / 2, 7.78), group, "Slate",
                       bevel=0.0, rot=(0, 0, math.atan2(cy, cx)))
                kk.prism(f"Rotor{k}{cx}{cy}", 12, 0.32, 0.32, 0.05, (x + cx, cy, 7.84), group, "Sky", bevel=0.0,
                         light=(0.0, 0.4))
        kk.box(f"Parcel{k}", (0.45, 0.45, 0.35), (x, 0, 7.22), group, "Sand", bevel=0.05, light=(0.1, 0.6))


def rocket():
    word("ROCKET")
    # A lattice launch tower and a striped rocket (body, nose and flame move)
    for k, (dx, dy) in enumerate([(-0.25, -0.25), (-0.25, 0.25), (0.25, -0.25), (0.25, 0.25)]):
        kk.box(f"TowerPost{k}", (0.14, 0.14, 5.2), (-1.75 + dx, dy, 8.7), "Frame", "Steel", bevel=0.0,
               light=STEEL)
    for k in range(6):
        kk.box(f"TowerBar{k}", (0.6, 0.6, 0.1), (-1.75, 0, 6.6 + k * 0.85), "Frame", "Red", bevel=0.0,
               light=(0.1, 0.6))
    kk.prism("RocketBodyMain", 12, 0.65, 0.65, 3.2, (0, 0, 6.3), "RocketBody", "White", bevel=0.05,
             light=(0.0, 0.35))
    for k, z in enumerate((6.7, 8.9)):
        kk.prism(f"RocketStripe{k}", 12, 0.67, 0.67, 0.3, (0, 0, z), "RocketBody", "Red", bevel=0.0,
                 light=(0.0, 0.4))
    kk.prism("RocketWindow", 12, 0.24, 0.24, 0.1, (0.66, 0, 8.1), "RocketBody", "Sky", bevel=0.0,
             rot=(0, math.pi / 2, 0))
    for k in range(3):
        a = k * math.tau / 3 + 0.5
        kk.box(f"Fin{k}", (0.12, 0.75, 1.0), (math.cos(a) * 0.75, math.sin(a) * 0.75, 6.65), "RocketBody", "Red",
               bevel=0.04, rot=(0, 0, a + math.pi / 2), light=(0.0, 0.4))
    kk.prism("RocketNoseCone", 12, 0.65, 0.05, 1.3, (0, 0, 9.5), "RocketNose", "Red", bevel=0.04,
             light=(0.0, 0.45))
    kk.prism("FlameCone", 10, 0.5, 0.05, 1.3, (0, 0, 5.85), "Flame", "Amber", bevel=0.0, light=(0.0, 0.3),
             rot=(math.pi, 0, 0))


BUILDERS = {"Stamp": stamp, "Scale": scale, "Fragile": fragile, "Sorter": sorter, "Express": express,
            "Drone": drone, "Rocket": rocket}

only = os.environ.get("MA_ONLY")  # build one machine: set MA_ONLY=Stamp
for machine_id, color, light in MACHINES:
    if only and machine_id != only:
        continue
    kk.fresh_scene()
    kk.PARTS.clear()
    chassis(color, light)
    BUILDERS[machine_id]()
    kk.finish(f"MA_Machine{machine_id}", views=((25, 22), (150, 15)))
