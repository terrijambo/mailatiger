"""Gruff's Post Office (docs/ASSET_PLAN.md 3b): the plaza's hero building, in the cozy-village style of the owner's
concept art (a timber cottage with a red roof, lanterns, a hanging sign and parcels out front).

  * stone foundation and front steps, cream plaster walls in a dark timber frame, an overhanging upper floor
  * a red shingle roof (gable end to the plaza) with a brick chimney and a clock tower on the ridge (the landmark)
  * a blue double door under a porch canopy, gold 3D letters POST OFFICE, shuttered windows with flower boxes
  * an envelope emblem in the gable, wall lanterns, a hanging envelope sign, and a loading dock stacked with parcels
Front faces -Y (the game turns it to face the plaza). About 20 x 16 studs, 24.5 tall to the clock tower's tip.

Run in the open Blender:  python tools/blender/bmcp.py run art/blender_scripts/hero_post_office.py
"""

import importlib
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kk  # noqa: E402

importlib.reload(kk)

MODEL = "MA_PostOffice"
W, D = 20.0, 16.0  # width (X), depth (Y)
FRONT = -D / 2  # y of the front wall
G0, G1 = 1.2, 8.2  # ground floor from / to
U1 = 12.8  # upper floor top (it overhangs 0.3 on every side)
WOOD, WOOD_LIGHT = (0.25, 0.85), (0.1, 0.6)

kk.fresh_scene()
kk.PARTS.clear()

# --- Foundation, walls and the timber frame --------------------------------------------------------------
kk.box("Foundation", (W + 1.2, D + 1.2, G0), (0, 0, G0 / 2), "Stone", "WarmGrey", bevel=0.18, light=(0.3, 0.8))
kk.box("StepTop", (7.0, 1.8, 0.6), (0, FRONT - 1.3, 0.3 + 0.3), "Stone", "WarmGrey", bevel=0.14, light=(0.2, 0.6))
kk.box("StepLow", (8.4, 1.4, 0.4), (0, FRONT - 2.4, 0.2), "Stone", "WarmGrey", bevel=0.12, light=(0.3, 0.7))
kk.box("GroundWalls", (W, D, G1 - G0), (0, 0, (G0 + G1) / 2), "Wall", "Cream", bevel=0.12, light=(0.15, 0.5))
kk.box("UpperWalls", (W + 0.6, D + 0.6, U1 - G1), (0, 0, (G1 + U1) / 2), "Wall", "Cream", bevel=0.12,
       light=(0.1, 0.45))

# Corner posts and the beams between the floors
for sx in (-1, 1):
    for sy in (-1, 1):
        kk.box(f"CornerPost{sx}{sy}", (0.8, 0.8, G1 - G0), (sx * W / 2, sy * D / 2, (G0 + G1) / 2), "Wood", "Taupe",
               bevel=0.1, light=WOOD)
        kk.box(f"UpperPost{sx}{sy}", (0.7, 0.7, U1 - G1), (sx * (W / 2 + 0.3), sy * (D / 2 + 0.3), (G1 + U1) / 2),
               "Wood", "Taupe", bevel=0.1, light=WOOD)
kk.box("JettyBeamFront", (W + 1.4, 0.9, 0.8), (0, FRONT - 0.3, G1), "Wood", "Taupe", bevel=0.12, light=WOOD)
kk.box("JettyBeamBack", (W + 1.4, 0.9, 0.8), (0, -FRONT + 0.3, G1), "Wood", "Taupe", bevel=0.12, light=WOOD)
for sx in (-1, 1):
    kk.box(f"JettyBeamSide{sx}", (0.9, D + 1.4, 0.8), (sx * (W / 2 + 0.3), 0, G1), "Wood", "Taupe", bevel=0.12,
           light=WOOD)
kk.box("SillBeam", (W + 0.4, 0.5, 0.5), (0, FRONT - 0.2, G0 + 0.25), "Wood", "Taupe", bevel=0.08, light=WOOD)
kk.box("EaveBeam", (W + 1.2, 0.7, 0.6), (0, FRONT - 0.5, U1), "Wood", "Taupe", bevel=0.1, light=WOOD)
# Studs either side of the sign on the upper floor
for sx in (-1, 1):
    kk.box(f"UpperStud{sx}", (0.5, 0.4, U1 - G1), (sx * 4.75, FRONT - 0.42, (G1 + U1) / 2), "Wood", "Taupe",
           bevel=0.06, light=WOOD)

# --- Roof: a cream gable wall, red shingles, ridge cap, chimney ----------------------------------------------
RISE = 6.2
kk.gable("GableCore", W + 0.6, D + 0.6, RISE, (0, 0, U1), "Wall", "Cream", bevel=0.1, light=(0.05, 0.4))
kk.shingles("Shingle", W + 0.6, D + 0.6, RISE, U1, rows=7, overhang=1.0, group="Roof", color="Red",
            light=(0.05, 0.75), thickness=0.32)
kk.box("RidgeCap", (0.9, D + 2.8, 0.6), (0, 0, U1 + RISE + 0.35), "Roof", "BrickDark", bevel=0.14, light=(0.1, 0.6))
# Barge boards along the front gable's two sloping edges (each rises from its eave up to the ridge)
slope = math.atan2(RISE, (W + 0.6) / 2)
edge = math.hypot((W + 0.6) / 2, RISE) + 0.6
for sx in (-1, 1):
    kk.box(f"Barge{sx}", (edge, 0.5, 0.55), (sx * (W + 0.6) / 4, FRONT - 1.25, U1 + RISE / 2 + 0.3), "Wood", "Taupe",
           bevel=0.08, rot=(0, sx * slope, 0), light=WOOD)
kk.box("Chimney", (1.9, 1.9, 6.0), (6.0, 3.5, U1 + 3.6), "Stone", "BrickDark", bevel=0.12, light=(0.1, 0.7))
kk.box("ChimneyCap", (2.4, 2.4, 0.45), (6.0, 3.5, U1 + 6.8), "Stone", "WarmGrey", bevel=0.1, light=(0.2, 0.6))

# Envelope emblem in the front gable: white letter, flap lines, red heart seal
EZ = U1 + 2.5
kk.box("Envelope", (3.6, 0.3, 2.4), (0, FRONT - 0.45, EZ), "Trim", "White", bevel=0.1, light=(0.0, 0.3))
for sx in (-1, 1):
    kk.box(f"Flap{sx}", (2.15, 0.34, 0.16), (sx * 0.82, FRONT - 0.5, EZ + 0.45), "Trim", "Slate", bevel=0.03,
           rot=(0, sx * math.radians(33), 0), light=(0.1, 0.5))
kk.prism("Seal", 10, 0.42, 0.42, 0.25, (0, FRONT - 0.62, EZ - 0.1), "Trim", "Red", bevel=0.05,
         light=(0.0, 0.4))
bpy_seal = kk.PARTS[-1][0]
bpy_seal.rotation_euler = (math.pi / 2, 0, 0)

# --- Clock tower on the ridge (the landmark) -------------------------------------------------------------
TZ = U1 + RISE - 1.0
kk.box("TowerBody", (3.6, 3.6, 3.8), (0, -3.2, TZ + 1.9), "Wall", "Cream", bevel=0.14, light=(0.05, 0.45))
for sx in (-1, 1):
    for sy in (-1, 1):
        kk.box(f"TowerPost{sx}{sy}", (0.45, 0.45, 3.8), (sx * 1.8, -3.2 + sy * 1.8, TZ + 1.9), "Wood", "Taupe",
               bevel=0.06, light=WOOD)
kk.box("TowerBelt", (4.0, 4.0, 0.45), (0, -3.2, TZ + 3.85), "Wood", "Taupe", bevel=0.08, light=WOOD)
for k in range(4):
    a = k * math.pi / 2
    nx, ny = math.sin(a), -math.cos(a)  # 0 = front (-Y)
    cx, cy = nx * 1.86, -3.2 + ny * 1.86
    kk.prism(f"ClockFace{k}", 16, 1.15, 1.15, 0.16, (cx, cy, TZ + 2.0), "Trim", "White", bevel=0.03,
             light=(0.0, 0.25))
    face = kk.PARTS[-1][0]
    face.rotation_euler = (math.pi / 2, 0, a)
    face.location = (cx, cy, TZ + 2.0)
    kk.box(f"HandLong{k}", (0.12, 0.08, 0.95), (cx + nx * 0.12, cy + ny * 0.12, TZ + 2.35), "Trim", "Ink",
           bevel=0.0, rot=(0, 0, a))
    kk.box(f"HandShort{k}", (0.6, 0.08, 0.12), (cx + nx * 0.12 + math.cos(a) * 0.25, cy + ny * 0.12 + math.sin(a) * 0.25,
                                                 TZ + 2.0), "Trim", "Ink", bevel=0.0, rot=(0, 0, a))
kk.prism("TowerRoof", 4, 3.2, 0.12, 3.2, (0, -3.2, TZ + 4.05), "Roof", "Blue", bevel=0.1, spin=math.pi / 4,
         light=(0.05, 0.6))
kk.prism("Finial", 8, 0.22, 0.08, 1.1, (0, -3.2, TZ + 7.2), "Metal", "Gold", bevel=0.0, light=(0.0, 0.4))
kk.prism("FinialBall", 8, 0.35, 0.35, 0.5, (0, -3.2, TZ + 7.0), "Metal", "Gold", bevel=0.12, light=(0.0, 0.4))

# --- Front door, porch canopy, the sign -------------------------------------------------------------------
DY = FRONT - 0.15
kk.box("DoorFrame", (5.6, 0.5, 5.6), (0, DY - 0.05, G0 + 2.8), "Wood", "Taupe", bevel=0.1, light=WOOD)
for sx in (-1, 1):
    kk.box(f"Door{sx}", (2.15, 0.5, 4.9), (sx * 1.12, DY - 0.1, G0 + 2.45), "Door", "Blue", bevel=0.08,
           light=(0.1, 0.5))
    kk.box(f"DoorPanelTop{sx}", (1.5, 0.56, 1.6), (sx * 1.12, DY - 0.12, G0 + 3.6), "Door", "SlateBlue",
           bevel=0.06, light=(0.1, 0.5))
    kk.box(f"DoorPanelLow{sx}", (1.5, 0.56, 1.6), (sx * 1.12, DY - 0.12, G0 + 1.4), "Door", "SlateBlue",
           bevel=0.06, light=(0.1, 0.5))
    kk.box(f"Handle{sx}", (0.18, 0.3, 0.7), (sx * 0.35, DY - 0.42, G0 + 2.5), "Metal", "Gold", bevel=0.05,
           light=(0.0, 0.4))
# Porch canopy on two posts, with its own little shingles
kk.box("CanopyBoard", (7.6, 3.2, 0.35), (0, FRONT - 1.7, G0 + 6.2), "Roof", "Red", bevel=0.08,
       rot=(math.radians(-16), 0, 0), light=(0.1, 0.6))
for r in range(3):
    kk.box(f"CanopyShingle{r}", (7.8, 1.2, 0.22), (0, FRONT - 0.9 - r * 1.0, G0 + 6.55 - r * 0.29), "Roof", "Red",
           bevel=0.06, rot=(math.radians(-16), 0, 0), light=(0.05, 0.6))
for sx in (-1, 1):
    kk.box(f"PorchPost{sx}", (0.45, 0.45, 5.9), (sx * 3.4, FRONT - 3.0, G0 + 2.95 - 0.6), "Wood", "Taupe",
           bevel=0.06, light=WOOD)
# POST OFFICE: a blue board on the upper floor, gold letters in front
kk.box("SignBoard", (8.4, 0.4, 1.9), (0, FRONT - 0.55, G1 + 2.35), "Trim", "Blue", bevel=0.12, light=(0.1, 0.5))
kk.box("SignTrim", (8.9, 0.32, 2.35), (0, FRONT - 0.42, G1 + 2.35), "Metal", "Gold", bevel=0.08, light=(0.0, 0.4))
kk.text3d("Letters", "POST OFFICE", 1.05, (0, FRONT - 0.8, G1 + 2.33), depth=0.12)

# --- Windows with shutters and flower boxes ---------------------------------------------------------------
def window(tag, x, z, w=3.0, h=3.0, flowers=True):
    y = FRONT - 0.12
    kk.box(f"{tag}Frame", (w + 0.6, 0.4, h + 0.6), (x, y, z), "Wood", "Taupe", bevel=0.08, light=WOOD)
    kk.box(f"{tag}Glass", (w, 0.42, h), (x, y - 0.02, z), "Glass", "Sky", bevel=0.0, light=(0.0, 0.6))
    kk.box(f"{tag}MullionV", (0.2, 0.46, h), (x, y - 0.04, z), "Wood", "Taupe", bevel=0.0, light=WOOD)
    kk.box(f"{tag}MullionH", (w, 0.46, 0.2), (x, y - 0.04, z), "Wood", "Taupe", bevel=0.0, light=WOOD)
    for sx in (-1, 1):
        kk.box(f"{tag}Shutter{sx}", (1.15, 0.3, h + 0.3), (x + sx * (w / 2 + 0.95), y - 0.1, z), "Door", "Blue",
               bevel=0.07, light=(0.1, 0.55))
    if flowers:
        kk.box(f"{tag}Box", (w + 0.8, 0.9, 0.65), (x, y - 0.55, z - h / 2 - 0.5), "Wood", "Taupe", bevel=0.08,
               light=WOOD)
        for k in range(5):
            fx = x - w / 2 + 0.3 + k * (w - 0.6) / 4
            kk.prism(f"{tag}Leaf{k}", 6, 0.38, 0.2, 0.45, (fx, y - 0.55, z - h / 2 - 0.2), "Plants", "Green",
                     bevel=0.0, light=(0.1, 0.5))
            kk.prism(f"{tag}Bloom{k}", 6, 0.26, 0.18, 0.28, (fx, y - 0.55, z - h / 2 + 0.2), "Plants",
                     ("Coral", "Amber", "Magenta")[k % 3], bevel=0.0, light=(0.0, 0.35))


window("WinL", -6.3, G0 + 3.6)
window("WinR", 6.3, G0 + 3.6)
window("UpL", -7.0, G1 + 2.4, w=2.4, h=2.4, flowers=False)
window("UpR", 7.0, G1 + 2.4, w=2.4, h=2.4, flowers=False)

# --- Lanterns, the hanging sign, the parcel dock -----------------------------------------------------------
for sx in (-1, 1):
    x = sx * 3.55
    kk.box(f"LanternArm{sx}", (0.18, 0.9, 0.18), (x, FRONT - 0.55, G0 + 4.9), "Metal", "Ink", bevel=0.0)
    kk.box(f"LanternCage{sx}", (0.75, 0.75, 1.0), (x, FRONT - 1.05, G0 + 4.4), "Metal", "Ink", bevel=0.06,
           light=(0.2, 0.6))
    kk.box(f"LanternGlow{sx}", (0.55, 0.8, 0.8), (x, FRONT - 1.05, G0 + 4.4), "Glow", "Amber", bevel=0.04,
           light=(0.0, 0.3))
    kk.prism(f"LanternCap{sx}", 4, 0.62, 0.1, 0.45, (x, FRONT - 1.05, G0 + 4.9), "Metal", "Ink", bevel=0.0,
             spin=math.pi / 4)
# Hanging sign on an iron bracket at the front-right corner
kk.box("SignArm", (0.2, 2.6, 0.2), (W / 2 + 0.2, FRONT - 1.3, G1 - 1.0), "Metal", "Ink", bevel=0.0)
kk.box("SignChainA", (0.08, 0.08, 0.6), (W / 2 + 0.2, FRONT - 0.6, G1 - 1.35), "Metal", "Ink", bevel=0.0)
kk.box("SignChainB", (0.08, 0.08, 0.6), (W / 2 + 0.2, FRONT - 2.2, G1 - 1.35), "Metal", "Ink", bevel=0.0)
kk.box("HangingBoard", (0.3, 2.4, 1.7), (W / 2 + 0.2, FRONT - 1.4, G1 - 2.45), "Wood", "Gold", bevel=0.1,
       light=(0.3, 0.8))
for side in (-1, 1):
    kk.box(f"HangingLetter{side}", (0.36, 1.4, 0.95), (W / 2 + 0.2 + side * 0.05, FRONT - 1.4, G1 - 2.45), "Trim",
           "White", bevel=0.06, light=(0.0, 0.3))
# Loading dock on the right side, stacked with taped parcels
kk.box("Dock", (4.0, 9.0, 1.0), (W / 2 + 2.0, 1.5, 0.5), "Wood", "Taupe", bevel=0.1, light=WOOD)
for k in range(6):
    kk.box(f"DockPlank{k}", (4.1, 1.3, 0.12), (W / 2 + 2.0, -2.4 + k * 1.5, 1.04), "Wood", "Gold", bevel=0.03,
           light=(0.4, 0.9))
parcels = [((1.6, 1.4, 1.2), (W / 2 + 1.4, -1.6, 1.6)), ((1.3, 1.3, 1.0), (W / 2 + 2.9, -1.2, 1.5)),
           ((1.2, 1.1, 0.9), (W / 2 + 1.6, -1.4, 2.65)), ((1.8, 1.5, 1.4), (W / 2 + 2.2, 2.4, 1.7)),
           ((1.1, 1.0, 0.9), (W / 2 + 2.0, 2.5, 2.85)), ((1.4, 1.2, 1.1), (W / 2 + 1.5, 4.6, 1.55))]
for k, (size, at) in enumerate(parcels):
    turn = math.radians((k * 23) % 30 - 15)
    kk.box(f"Parcel{k}", size, at, "Parcels", "Sand", bevel=0.08, rot=(0, 0, turn), light=(0.15, 0.7))
    kk.box(f"ParcelTape{k}", (size[0] + 0.04, 0.28, size[2] + 0.04), at, "Parcels", "Gold", bevel=0.02,
           rot=(0, 0, turn), light=(0.0, 0.3))

parts = kk.joined_groups(MODEL)
print("parts:", [o.name for o in parts], "triangles:", kk.triangles(parts))
print("fbx:", kk.export_fbx(MODEL, parts))
print("previews:", kk.render_preview(MODEL, parts, views=((-60, 18), (-120, 28))))
