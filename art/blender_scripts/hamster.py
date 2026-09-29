"""
Hamster: a round orange fluffball with a cream belly and chubby cheeks. About 2 studs tall.
Run:  blender --background --factory-startup --python art/blender_scripts/hamster.py
"""

import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402

common.reset()

ORANGE = common.material("HamsterOrange", (235, 160, 70))
CREAM = common.material("HamsterCream", (250, 235, 210))
PINK = common.material("HamsterPink", (240, 150, 140))
DARK = common.material("HamsterEyes", (30, 25, 25), roughness=0.3)

# Body + head (one round blob with a head bulging out the front)
body = common.combine(
    [
        common.ball(1.0, (0, 0.1, 0.95), scale=(0.95, 1.05, 0.9)),
        common.ball(0.68, (0, -0.62, 1.25), scale=(1.0, 0.95, 0.95)),
    ],
    "Body",
    ORANGE,
)

# Cream belly and puffy cheeks
belly = common.combine(
    [
        common.ball(0.62, (0, -0.55, 0.72), scale=(0.95, 0.55, 0.85)),
        common.ball(0.3, (-0.4, -0.92, 1.05)),
        common.ball(0.3, (0.4, -0.92, 1.05)),
    ],
    "Belly",
    CREAM,
)

# Ears, nose and little feet (tucked under the body so they don't float)
pink = common.combine(
    [
        common.ball(0.22, (-0.42, -0.5, 1.8), scale=(1, 0.5, 1)),
        common.ball(0.22, (0.42, -0.5, 1.8), scale=(1, 0.5, 1)),
        common.ball(0.08, (0, -1.3, 1.2), subdivisions=1),
        common.ball(0.17, (-0.36, -0.38, 0.22), scale=(1, 1.3, 0.6), subdivisions=1),
        common.ball(0.17, (0.36, -0.38, 0.22), scale=(1, 1.3, 0.6), subdivisions=1),
        common.ball(0.15, (-0.42, 0.55, 0.2), scale=(1, 1.3, 0.6), subdivisions=1),
        common.ball(0.15, (0.42, 0.55, 0.2), scale=(1, 1.3, 0.6), subdivisions=1),
    ],
    "Pink",
    PINK,
)

# Beady eyes
eyes = common.combine(
    [
        common.ball(0.1, (-0.27, -1.18, 1.42), subdivisions=1),
        common.ball(0.1, (0.27, -1.18, 1.42), subdivisions=1),
    ],
    "Eyes",
    DARK,
)

common.finish("Hamster", [body, belly, pink, eyes], target_height=1.0, distance=6.5)
