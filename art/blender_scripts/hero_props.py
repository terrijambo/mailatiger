"""Gruff's counter, the mail chute (and its three upgrades) and the orders board (docs/ASSET_PLAN.md 3b).
Front faces -Y (the game turns each to face the plaza). Built on the City atlas like every hero model.

    MA_PostCounter            wood counter with blue panels, a brass bell, letter trays, parcels, a stamp and pad
    MA_MailChute              the basic chute: a round-topped blue mail drop with a brass flap and MAIL letters
    MA_MailChuteExpress       the same drop fed by a conveyor, with hazard stripes and a warning light
    MA_MailChutePneumatic     a glass suction tube rising out of it, with a parcel inside
    MA_MailChuteRocket        a launch pad beside it with a little parcel rocket and countdown lights
    MA_OrdersBoard            a cork board on posts under a little shingle roof, pinned slips, ORDERS sign

    python tools/blender/bmcp.py run art/blender_scripts/hero_props.py
"""

import importlib
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kk  # noqa: E402

importlib.reload(kk)

WOOD = (0.25, 0.85)
STEEL = (0.1, 0.6)


def parcel(tag, size, at, turn=0.0, group="Parcels"):
    kk.box(tag, size, at, group, "Sand", bevel=0.06, rot=(0, 0, turn), light=(0.15, 0.7))
    kk.box(f"{tag}Tape", (size[0] + 0.03, 0.2, size[2] + 0.03), at, group, "Gold", bevel=0.02, rot=(0, 0, turn),
           light=(0.0, 0.3))


# --- Gruff's counter ---------------------------------------------------------------------------------------
def counter():
    kk.box("Plinth", (10.4, 2.9, 0.3), (0, 0, 0.15), "Stone", "WarmGrey", bevel=0.08, light=(0.3, 0.7))
    kk.box("Body", (10.0, 2.3, 3.0), (0, 0, 1.8), "Wood", "Taupe", bevel=0.12, light=WOOD)
    for k, x in enumerate((-3.25, 0, 3.25)):
        kk.box(f"PanelFrame{k}", (2.9, 0.16, 2.0), (x, -1.16, 1.75), "Trim", "Gold", bevel=0.04, light=(0.1, 0.5))
        kk.box(f"Panel{k}", (2.6, 0.2, 1.7), (x, -1.18, 1.75), "Paint", "Blue", bevel=0.05, light=(0.1, 0.5))
    kk.box("Top", (10.6, 2.9, 0.32), (0, 0, 3.46), "Wood", "Gold", bevel=0.08, light=(0.35, 0.85))
    kk.box("Kick", (10.1, 0.25, 0.35), (0, -1.18, 0.48), "Trim", "Slate", bevel=0.03, light=(0.3, 0.7))
    # A brass bell
    kk.prism("BellBase", 10, 0.32, 0.32, 0.08, (-3.6, -0.4, 3.62), "Trim", "Gold", bevel=0.0, light=(0.1, 0.4))
    kk.prism("Bell", 10, 0.3, 0.06, 0.32, (-3.6, -0.4, 3.7), "Trim", "Gold", bevel=0.0, light=(0.0, 0.35))
    kk.prism("BellButton", 6, 0.07, 0.07, 0.12, (-3.6, -0.4, 4.0), "Trim", "Gold", bevel=0.0)
    # Letter trays with letters
    for k in range(3):
        kk.box(f"Tray{k}", (1.5, 1.1, 0.12), (2.7, 0.3, 3.7 + k * 0.42), "Trim", "Steel", bevel=0.02, light=STEEL)
        kk.box(f"Letters{k}", (1.3, 0.9, 0.18), (2.7, 0.3, 3.82 + k * 0.42), "Trim", ("White", "Cream", "Sky")[k],
               bevel=0.02, light=(0.0, 0.3))
    for sx in (-1, 1):
        kk.box(f"TrayPost{sx}", (0.08, 0.08, 1.1), (2.7 + sx * 0.72, 0.8, 4.15), "Trim", "Steel", bevel=0.0)
    # A rubber stamp on its ink pad
    kk.box("InkPad", (0.8, 0.55, 0.1), (-1.6, -0.3, 3.67), "Trim", "Ink", bevel=0.02)
    kk.box("StampBlock", (0.45, 0.45, 0.28), (-1.0, -0.25, 3.78), "Trim", "Red", bevel=0.05, light=(0.1, 0.5))
    kk.prism("StampHandle", 8, 0.12, 0.12, 0.35, (-1.0, -0.25, 3.92), "Trim", "Taupe", bevel=0.0)
    kk.ball("StampKnob", 0.17, (-1.0, -0.25, 4.36), "Trim", "Red")
    # Parcels waiting to go
    parcel("ParcelA", (1.2, 1.0, 0.85), (4.35, 0.35, 4.05), 0.2)
    parcel("ParcelB", (0.8, 0.7, 0.6), (4.2, 0.4, 4.78), -0.15)
    # A little potted plant
    kk.prism("Pot", 8, 0.3, 0.38, 0.5, (-4.55, 0.4, 3.62), "Trim", "Orange", bevel=0.03, light=(0.3, 0.7))
    kk.ball("Leaves", 0.45, (-4.55, 0.4, 4.4), "Plants", "Green", light=(0.1, 0.5))
    kk.finish("MA_PostCounter", views=((-60, 20), (-120, 30)))


# --- Mail chutes -------------------------------------------------------------------------------------------
def chute_body(color="Blue"):
    """The mail drop every chute shares: blue body with a round top, brass flap, MAIL letters, little legs."""
    for sx in (-1, 1):
        for sy in (-1, 1):
            kk.box(f"Leg{sx}{sy}", (0.45, 0.45, 0.6), (sx * 1.45, sy * 1.15, 0.3), "Trim", "Slate", bevel=0.06,
                   light=(0.3, 0.8))
    kk.box("Body", (3.6, 3.0, 3.0), (0, 0, 2.1), "Paint", color, bevel=0.2, light=(0.35, 0.8))
    kk.cylinder_y("Dome", 1.8, 3.0, (0, 0, 3.6), "Paint", color, sides=16, bevel=0.1, light=(0.3, 0.6))
    kk.box("Band", (3.7, 3.1, 0.25), (0, 0, 1.0), "Trim", "Gold", bevel=0.05, light=(0.1, 0.5))
    kk.box("Slot", (2.4, 0.2, 0.55), (0, -1.55, 3.1), "Trim", "Ink", bevel=0.05)
    kk.box("Flap", (2.5, 0.22, 0.35), (0, -1.62, 3.45), "Trim", "Gold", bevel=0.05, rot=(math.radians(-25), 0, 0),
           light=(0.0, 0.4))
    kk.text3d("MailWord", "MAIL", 0.75, (0, -1.62, 2.1), depth=0.08, group="Trim", color="Gold")
    kk.prism("ArrowHead", 3, 0.35, 0.35, 0.1, (0, -1.58, 1.42), "Trim", "White", bevel=0.0,
             rot=(math.pi / 2, math.pi, 0))


def chutes():
    kk.fresh_scene()
    kk.PARTS.clear()
    chute_body()
    kk.finish("MA_MailChute", views=((-60, 18), (-130, 25)))

    # Express: fed by a conveyor, hazard stripes, a spinning warning light
    kk.fresh_scene()
    kk.PARTS.clear()
    chute_body()
    kk.box("BeltFrame", (2.2, 3.4, 0.6), (0, -3.1, 1.3), "Trim", "Slate", bevel=0.08, light=(0.3, 0.8))
    kk.box("Belt", (1.8, 3.6, 0.15), (0, -3.1, 1.68), "Trim", "Charcoal", bevel=0.02)
    for sy in (-1, 1):
        kk.box(f"BeltLeg{sy}", (1.8, 0.3, 1.0), (0, -3.1 + sy * 1.4, 0.5), "Trim", "Slate", bevel=0.04)
    for k in range(6):
        kk.box(f"Hazard{k}", (0.32, 0.12, 0.85), (-1.5 + k * 0.6, -1.6, 0.7), "Glow", "Amber", bevel=0.0,
               rot=(0, math.radians(35), 0), light=(0.0, 0.3))
    kk.prism("BeaconBase", 8, 0.35, 0.35, 0.2, (0, 0, 5.4), "Trim", "Slate", bevel=0.0)
    kk.prism("Beacon", 8, 0.3, 0.22, 0.45, (0, 0, 5.6), "Glow", "Orange", bevel=0.04, light=(0.0, 0.3))
    parcel("BeltParcel", (0.9, 0.8, 0.7), (0, -3.6, 2.1), 0.1)
    kk.finish("MA_MailChuteExpress", views=((-60, 18), (-130, 25)))

    # Pneumatic: a glass tube from the drop up and over, with a parcel inside
    kk.fresh_scene()
    kk.PARTS.clear()
    chute_body()
    kk.prism("TubeRing", 16, 0.95, 0.95, 0.4, (0, 0, 5.3), "Trim", "Gold", bevel=0.05, light=(0.0, 0.4))
    kk.prism("Tube", 16, 0.8, 0.8, 4.0, (0, 0, 5.6), "Glass", "Sky", bevel=0.0, light=(0.0, 0.4))
    kk.prism("TubeCap", 16, 0.95, 0.95, 0.4, (0, 0, 9.5), "Trim", "Gold", bevel=0.05, light=(0.0, 0.4))
    kk.cylinder_x("TubeBend", 0.8, 2.6, (1.3, 0, 9.7), "Glass", "Sky", sides=16)
    parcel("TubeParcel", (0.8, 0.8, 0.8), (0, 0, 7.4), 0.4)
    kk.finish("MA_MailChutePneumatic", views=((-60, 15), (-130, 22)))

    # Rocket: a launch pad beside the drop, with a little parcel rocket and countdown lights
    kk.fresh_scene()
    kk.PARTS.clear()
    chute_body()
    kk.prism("Pad", 12, 1.5, 1.6, 0.4, (3.2, 0, 0), "Trim", "Slate", bevel=0.06, light=(0.3, 0.8))
    kk.prism("PadRing", 12, 1.3, 1.3, 0.05, (3.2, 0, 0.4), "Glow", "Amber", bevel=0.0, light=(0.0, 0.3))
    kk.prism("Rocket", 12, 0.5, 0.5, 2.2, (3.2, 0, 0.9), "Paint", "White", bevel=0.04, light=(0.0, 0.35))
    kk.prism("RocketNose", 12, 0.5, 0.04, 0.9, (3.2, 0, 3.1), "Paint", "Red", bevel=0.03, light=(0.0, 0.45))
    for k in range(3):
        a = k * math.tau / 3
        kk.box(f"Fin{k}", (0.1, 0.55, 0.8), (3.2 + math.cos(a) * 0.55, math.sin(a) * 0.55, 1.2), "Paint", "Red",
               bevel=0.03, rot=(0, 0, a + math.pi / 2), light=(0.0, 0.4))
    parcel("RocketParcel", (0.55, 0.55, 0.45), (3.2, 0, 1.75), 0.0)
    for k in range(3):
        kk.ball(f"Countdown{k}", 0.2, (1.6, -1.55, 4.2 - k * 0.5), "Glow", ("Red", "Amber", "Green")[k])
    kk.finish("MA_MailChuteRocket", views=((-60, 15), (-130, 22)))


# --- Orders board -----------------------------------------------------------------------------------------
def orders_board():
    for sx in (-1, 1):
        kk.box(f"Post{sx}", (0.45, 0.45, 6.4), (sx * 2.95, 0, 3.2), "Wood", "Taupe", bevel=0.08, light=WOOD)
        kk.box(f"Foot{sx}", (0.9, 0.9, 0.3), (sx * 2.95, 0, 0.15), "Stone", "WarmGrey", bevel=0.06,
               light=(0.3, 0.7))
    kk.box("Frame", (6.1, 0.4, 3.9), (0, 0, 3.6), "Wood", "Taupe", bevel=0.1, light=WOOD)
    kk.box("Cork", (5.4, 0.45, 3.2), (0, 0, 3.6), "Cork", "Sand", bevel=0.04, light=(0.4, 0.9))
    slips = [(-1.9, 4.6, 0.12, "White"), (-0.6, 4.75, -0.08, "Cream"), (0.8, 4.55, 0.1, "Amber"),
             (2.0, 4.7, -0.15, "White"), (-1.5, 3.1, -0.1, "Sky"), (0.0, 3.2, 0.14, "White"),
             (1.5, 3.0, -0.05, "Cream"), (-0.9, 2.3, 0.05, "Coral")]
    for k, (x, z, tilt, color) in enumerate(slips):
        kk.box(f"Slip{k}", (1.05, 0.08, 1.15), (x, -0.27, z - 0.3), "Paper", color, bevel=0.02,
               rot=(0, tilt, 0), light=(0.0, 0.3))
        kk.ball(f"Pin{k}", 0.09, (x, -0.33, z + 0.2), "Paper", "Red", subdivisions=1)
    # A little shingle roof over it and the ORDERS sign under the roof
    kk.box("RoofBoard", (7.2, 1.7, 0.25), (0, -0.2, 6.48), "Roof", "Red", bevel=0.06,
           rot=(math.radians(-14), 0, 0), light=(0.1, 0.6))
    for r in range(2):
        kk.box(f"RoofShingle{r}", (7.3, 0.9, 0.18), (0, -0.55 + r * 0.7, 6.6 + r * 0.17), "Roof", "Red",
               bevel=0.05, rot=(math.radians(-14), 0, 0), light=(0.05, 0.55))
    kk.box("SignBoard", (4.2, 0.3, 0.9), (0, -0.25, 5.95), "Trim", "Blue", bevel=0.08, light=(0.1, 0.5))
    kk.text3d("SignWord", "ORDERS", 0.6, (0, -0.42, 5.95), depth=0.06, group="Trim", color="Gold")
    kk.finish("MA_OrdersBoard", views=((-60, 15), (-120, 22)))


only = os.environ.get("MA_ONLY")
if not only or only == "Counter":
    kk.fresh_scene()
    kk.PARTS.clear()
    counter()
if not only or only == "Chutes":
    chutes()
if not only or only == "Orders":
    kk.fresh_scene()
    kk.PARTS.clear()
    orders_board()
