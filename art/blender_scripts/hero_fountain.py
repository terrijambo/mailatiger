"""The plaza fountain (docs/ASSET_PLAN.md 3b): the first thing every player sees.

Three tiers of bevelled stone in the KayKit style, on the City atlas:
  * an octagonal basin of separate stone blocks on a plinth, with cream cap stones and gold stamp plaques
  * a blue mosaic floor with a gold ring, coins and lily pads under clear water
  * a carved pedestal, a middle bowl with four bronze spouts, an upper bowl
  * on top, a bronze winged parcel ("airmail"); it becomes a bronze Gruff once his model exists
Size: 25 studs across, about 14.5 tall (the game scales it by the size table anyway).

Run in the open Blender:  python tools/blender/bmcp.py run art/blender_scripts/hero_fountain.py
or headless:              blender --background --python art/blender_scripts/hero_fountain.py
"""

import importlib
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kk  # noqa: E402

importlib.reload(kk)

MODEL = "MA_Fountain"
TAU = math.pi * 2

kk.fresh_scene()
kk.PARTS.clear()

# --- Basin -------------------------------------------------------------------------------------------------
O = math.pi / 8  # (octagons turned so a flat side faces each path)
kk.prism("Step", 8, 12.6, 12.3, 0.45, (0, 0, 0), "Stone", "WarmGrey", bevel=0.15, spin=O, light=(0.3, 0.7))
kk.ring_blocks("Plinth", 8, 10.7, 1.9, 0.55, 0.45, "Stone", "WarmGrey", gap=0.08, bevel=0.12, light=(0.35, 0.8))
kk.masonry_ring("Wall", 8, 10.45, 1.3, 2.0, 1.0, courses=2, per_side=(2, 3), color="Sand", bevel=0.1,
                light=(0.05, 0.6))
kk.ring_blocks("Cap", 8, 10.45, 2.0, 0.5, 3.0, "Stone", "Cream", gap=0.08, bevel=0.16, light=(0.3, 0.65))
# Gold stamp plaques on the four faces that look down the paths
for i in range(0, 8, 2):
    a = (i + 0.5) * TAU / 8
    r = 10.45 + 1.3 / 2 + 0.04
    kk.box(f"Plaque{i}", (0.12, 2.1, 1.25), (math.cos(a) * r, math.sin(a) * r, 2.0), "Metal", "Gold", bevel=0.05,
           rot=(0, 0, a), light=(0.0, 0.45))
    kk.box(f"PlaqueStamp{i}", (0.14, 1.25, 0.8), (math.cos(a) * (r + 0.05), math.sin(a) * (r + 0.05), 2.0), "Stone",
           "Blue", bevel=0.04, rot=(0, 0, a), light=(0.15, 0.55))
    kk.box(f"PlaqueHeart{i}", (0.16, 0.45, 0.4), (math.cos(a) * (r + 0.1), math.sin(a) * (r + 0.1), 2.0), "Stone",
           "Red", bevel=0.08, rot=(0, 0, a), light=(0.0, 0.4))

# Mosaic floor: blue, with a gold ring and a gold star of tiles
kk.prism("Floor", 8, 9.8, 9.8, 0.4, (0, 0, 0.45), "Stone", "Blue", bevel=0.0, spin=O, light=(0.15, 0.5))
kk.ring_blocks("FloorRing", 16, 6.0, 0.5, 0.08, 0.85, "Metal", "Gold", gap=0.05, bevel=0.02, light=(0.0, 0.3))
for i in range(8):
    a = i * TAU / 8
    kk.box(f"StarTile{i}", (2.6, 0.45, 0.08), (math.cos(a) * 3.4, math.sin(a) * 3.4, 0.89), "Metal", "Gold",
           bevel=0.02, rot=(0, 0, a), light=(0.0, 0.3))
coin_spots = [(7.0, 0.3), (7.6, 1.2), (6.6, 2.4), (8.2, 3.3), (6.9, 4.0), (7.5, 5.1), (6.5, 5.7), (8.3, 6.0),
              (7.1, 0.9 + math.pi), (7.9, 2.0 + math.pi), (6.7, 3.0 + math.pi), (8.0, 4.6 + math.pi)]
for index, (r, a) in enumerate(coin_spots):
    kk.prism(f"Coin{index}", 10, 0.3, 0.3, 0.07, (math.cos(a) * r, math.sin(a) * r, 0.86), "Metal", "Gold",
             bevel=0.0, spin=a, light=(0.0, 0.25))
kk.ngon_slab("BasinWater", 8, 9.75, 2.05, 0.85, "Water", "Sky", spin=O, light=(0.0, 0.3))
for index, (r, a) in enumerate([(7.9, 0.6), (8.4, 2.9), (7.6, 4.4), (8.2, 5.6)]):
    x, y = math.cos(a) * r, math.sin(a) * r
    kk.prism(f"Lily{index}", 9, 0.9, 0.9, 0.08, (x, y, 2.9), "Plants", "Green", bevel=0.0, spin=a, light=(0.1, 0.4))
    kk.prism(f"LilyFlower{index}", 6, 0.28, 0.14, 0.25, (x + 0.25, y, 2.96), "Plants", "Coral", bevel=0.0,
             light=(0.0, 0.3))

# --- Pedestal and middle bowl ------------------------------------------------------------------------------
kk.prism("PedestalFoot", 8, 2.7, 2.2, 0.9, (0, 0, 0.85), "Stone", "WarmGrey", bevel=0.14, spin=O, light=(0.25, 0.65))
kk.prism("Pedestal", 8, 1.65, 1.4, 3.6, (0, 0, 1.75), "Stone", "Sand", bevel=0.12, spin=O, light=(0.05, 0.6))
for z in (2.9, 4.5):
    kk.prism(f"PedestalBand{z}", 8, 1.78, 1.78, 0.32, (0, 0, z), "Metal", "Gold", bevel=0.06, spin=O,
             light=(0.0, 0.4))
kk.prism("MidBowl", 8, 1.5, 5.5, 1.35, (0, 0, 5.3), "Stone", "Sand", bevel=0.16, spin=O, light=(0.05, 0.6))
kk.ring_blocks("MidRim", 8, 5.35, 0.9, 0.45, 6.6, "Stone", "Cream", gap=0.08, bevel=0.12, light=(0.3, 0.65))
kk.ngon_slab("MidWater", 8, 4.95, 0.55, 6.4, "Water", "Sky", spin=O, light=(0.0, 0.3))
for i in range(4):
    a = i * TAU / 4
    x, y = math.cos(a) * 5.95, math.sin(a) * 5.95
    kk.box(f"Spout{i}", (1.1, 0.42, 0.36), (x, y, 6.75), "Metal", "Orange", bevel=0.08,
           rot=(0, math.radians(20), a), light=(0.35, 0.85))

# --- Upper column, bowl and the statue ----------------------------------------------------------------------
kk.prism("Column", 8, 1.05, 0.9, 2.8, (0, 0, 6.6), "Stone", "Sand", bevel=0.1, spin=O, light=(0.05, 0.6))
kk.prism("ColumnBand", 8, 1.15, 1.15, 0.28, (0, 0, 7.7), "Metal", "Gold", bevel=0.05, spin=O, light=(0.0, 0.4))
kk.prism("TopBowl", 8, 0.95, 3.1, 0.85, (0, 0, 9.3), "Stone", "Sand", bevel=0.12, spin=O, light=(0.05, 0.6))
kk.ring_blocks("TopRim", 8, 3.0, 0.6, 0.36, 10.15, "Stone", "Cream", gap=0.06, bevel=0.09, light=(0.3, 0.65))
kk.ngon_slab("TopWater", 8, 2.7, 0.42, 10.0, "Water", "Sky", spin=O, light=(0.0, 0.3))
kk.prism("StatuePlinth", 8, 1.3, 1.1, 1.0, (0, 0, 10.05), "Stone", "WarmGrey", bevel=0.1, spin=O, light=(0.2, 0.6))

# The bronze winged parcel: a box with a gold ribbon and bow, and swept feather wings
base = 11.05
turn = math.radians(8)
kk.box("Parcel", (2.5, 2.5, 2.0), (0, 0, base + 1.0), "Metal", "Orange", bevel=0.16, rot=(0, 0, turn),
       light=(0.3, 0.85))
kk.box("RibbonA", (2.56, 0.46, 2.06), (0, 0, base + 1.0), "Metal", "Gold", bevel=0.05, rot=(0, 0, turn),
       light=(0.0, 0.4))
kk.box("RibbonB", (0.46, 2.56, 2.06), (0, 0, base + 1.0), "Metal", "Gold", bevel=0.05, rot=(0, 0, turn),
       light=(0.0, 0.4))
for side in (-1, 1):
    kk.box(f"Bow{side}", (1.05, 0.32, 0.62), (side * 0.45, 0, base + 2.25), "Metal", "Gold", bevel=0.12,
           rot=(0, side * math.radians(28), turn), light=(0.0, 0.4))
    # Two layers of rounded feathers: four long ones behind, three short ones in front
    for k in range(4):
        length = 3.3 - k * 0.45
        lift = math.radians(14 + k * 19)
        cx = side * (1.3 + math.cos(lift) * length / 2)
        cz = base + 1.25 + math.sin(lift) * length / 2
        kk.box(f"Feather{side}_{k}", (length, 0.3, 0.78), (cx, -0.3 + k * 0.06, cz), "Metal", "Gold", bevel=0.24,
               rot=(0, -side * lift, 0), light=(0.0, 0.5))
    for k in range(3):
        length = 1.9 - k * 0.3
        lift = math.radians(22 + k * 22)
        cx = side * (1.3 + math.cos(lift) * length / 2)
        cz = base + 1.15 + math.sin(lift) * length / 2
        kk.box(f"Covert{side}_{k}", (length, 0.34, 0.66), (cx, 0.2, cz), "Metal", "Orange", bevel=0.22,
               rot=(0, -side * lift, 0), light=(0.2, 0.7))

# --- Water streams: four arcs from the spouts into the basin, and short falls over the top bowl's lip -------
for i in range(4):
    a = i * TAU / 4
    d = (math.cos(a), math.sin(a))
    kk.stream(f"SpoutStream{i}", [(d[0] * 6.45, d[1] * 6.45, 6.6), (d[0] * 7.4, d[1] * 7.4, 5.6),
                                    (d[0] * 7.9, d[1] * 7.9, 2.9)], thickness=0.2)
for i in range(8):
    a = (i + 0.5) * TAU / 8
    d = (math.cos(a), math.sin(a))
    kk.stream(f"LipFall{i}", [(d[0] * 3.25, d[1] * 3.25, 10.35), (d[0] * 3.6, d[1] * 3.6, 9.4),
                                (d[0] * 3.75, d[1] * 3.75, 6.95)], thickness=0.12)

parts = kk.joined_groups(MODEL)
print("parts:", [o.name for o in parts], "triangles:", kk.triangles(parts))
print("fbx:", kk.export_fbx(MODEL, parts))
print("previews:", kk.render_preview(MODEL, parts))
