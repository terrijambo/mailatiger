"""
Puts model previews side by side on one image, with names, so a batch can be reviewed at a glance.
  python art/contact_sheet.py OUTPUT.png Name1 Name2 ...     (previews come from art/previews/)
"""

import os
import sys

from PIL import Image, ImageDraw

ART = os.path.dirname(os.path.abspath(__file__))
TILE = 300
COLUMNS = 4


def main():
    output, names = sys.argv[1], sys.argv[2:]
    rows = (len(names) + COLUMNS - 1) // COLUMNS
    sheet = Image.new("RGB", (TILE * min(COLUMNS, len(names)), TILE * rows), (40, 40, 48))
    draw = ImageDraw.Draw(sheet)
    for index, name in enumerate(names):
        path = os.path.join(ART, "previews", f"{name}.png")
        x, y = (index % COLUMNS) * TILE, (index // COLUMNS) * TILE
        if os.path.exists(path):
            sheet.paste(Image.open(path).convert("RGB").resize((TILE, TILE)), (x, y))
        draw.rectangle([x, y, x + TILE, y + 22], fill=(0, 0, 0))
        draw.text((x + 6, y + 5), name, fill=(255, 255, 255))
    sheet.save(output)
    print(f"sheet: {output}")


main()
