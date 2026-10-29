"""A street mailbox for the plaza (and the first prop imported into Studio by the agent, end to end).
Front faces -Y (the game turns it to face the plaza). Built on the City atlas like every hero model.

    MA_Mailbox    a round-topped red letter box on a post, brass slot flap, MAIL letters, a side flag,
                  and a letter poking out of the slot

    python tools/blender/bmcp.py run art/blender_scripts/hero_mailbox.py
"""

import importlib
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kk  # noqa: E402

importlib.reload(kk)

PAINT = (0.3, 0.75)


def mailbox():
    # Footing and post
    kk.box("Footing", (2.0, 2.0, 0.3), (0, 0, 0.15), "Stone", "WarmGrey", bevel=0.08, light=(0.3, 0.7))
    kk.prism("PostCollar", 8, 0.55, 0.5, 0.25, (0, 0, 0.3), "Trim", "Slate", bevel=0.04, light=(0.3, 0.8))
    kk.prism("Post", 8, 0.36, 0.36, 1.6, (0, 0, 0.55), "Trim", "Slate", bevel=0.04, light=(0.3, 0.8))
    kk.box("Saddle", (2.2, 1.9, 0.22), (0, 0, 2.2), "Trim", "Slate", bevel=0.05, light=(0.3, 0.8))
    # The box: a red body with a round top
    kk.box("Body", (2.4, 2.0, 1.9), (0, 0, 3.25), "Paint", "Red", bevel=0.14, light=PAINT)
    kk.cylinder_y("Dome", 1.2, 2.0, (0, 0, 4.2), "Paint", "Red", sides=16, bevel=0.08, light=(0.25, 0.6))
    kk.box("Band", (2.48, 2.08, 0.2), (0, 0, 2.45), "Trim", "Gold", bevel=0.04, light=(0.1, 0.5))
    # Slot, brass flap, and a letter half posted
    kk.box("Slot", (1.5, 0.16, 0.32), (0, -1.02, 4.05), "Trim", "Ink", bevel=0.04)
    kk.box("Flap", (1.6, 0.18, 0.24), (0, -1.08, 4.3), "Trim", "Gold", bevel=0.04, rot=(math.radians(-30), 0, 0),
           light=(0.0, 0.4))
    kk.box("Letter", (1.0, 0.05, 0.7), (0.05, -1.12, 4.25), "Paper", "White", bevel=0.01,
           rot=(math.radians(-20), 0, math.radians(6)), light=(0.0, 0.3))
    kk.box("LetterStamp", (0.2, 0.06, 0.24), (0.42, -1.16, 4.38), "Paper", "Red", bevel=0.0,
           rot=(math.radians(-20), 0, math.radians(6)), light=(0.0, 0.3))
    kk.text3d("MailWord", "MAIL", 0.55, (0, -1.02, 3.42), depth=0.07, group="Trim", color="Gold")
    kk.box("PlateBack", (1.7, 0.08, 0.5), (0, -1.0, 2.75), "Trim", "Cream", bevel=0.03, light=(0.0, 0.4))
    kk.text3d("TimesWord", "9 - 12 - 5", 0.2, (0, -1.05, 2.75), depth=0.04, group="Trim", color="Ink")
    # The side flag (up: there's mail to collect)
    kk.box("FlagPivot", (0.12, 0.3, 0.3), (1.26, 0.3, 3.2), "Trim", "Slate", bevel=0.02)
    kk.box("FlagArm", (0.08, 0.14, 1.4), (1.32, 0.3, 3.85), "Trim", "Gold", bevel=0.02, light=(0.1, 0.5))
    kk.box("Flag", (0.1, 0.75, 0.48), (1.34, 0.62, 4.36), "Paint", "Amber", bevel=0.04, light=(0.0, 0.35))
    # Rivets on the dome edge
    for sx in (-1, 1):
        for k in range(3):
            kk.ball(f"Rivet{sx}{k}", 0.07, (sx * 1.0, -1.02, 2.75 + k * 0.6), "Trim", "Gold")
    kk.finish("MA_Mailbox", views=((-55, 18), (-125, 25)))


kk.fresh_scene()
kk.PARTS.clear()
mailbox()
