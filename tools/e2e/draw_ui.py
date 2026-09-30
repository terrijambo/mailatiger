"""Draws the UI layout recorded by the automated playtest (tools/e2e/run.sh) as a picture, so the screen
layout can be checked without looking at Studio:

    bash tools/e2e/run.sh > e2e.txt
    python tools/e2e/draw_ui.py e2e.txt hud ui_hud.png      (or "pen" for the Pen menu open)

Each UI element is drawn as its box in its own background color, with its text on top.
"""

import sys

from PIL import Image, ImageDraw


def main(dump_path: str, tag: str, out_path: str) -> None:
    width, height = 1280, 720
    boxes = []
    for line in open(dump_path, encoding="utf-8", errors="ignore"):
        if not line.startswith(f"UI {tag} "):
            continue
        rest = line[len(f"UI {tag} ") :].rstrip("\n")
        if rest.startswith("SCREEN "):
            _, w, h = rest.split()
            width, height = int(w), int(h)
            continue
        fields = rest.split("|")
        if len(fields) < 11:
            continue
        screen, cls = fields[0], fields[1]
        x, y, w, h, r, g, b = (int(float(v)) for v in fields[2:9])
        transparency = float(fields[9])
        text = "|".join(fields[10:])
        boxes.append((screen, cls, x, y, w, h, (r, g, b), transparency, text))

    image = Image.new("RGB", (width, height), (120, 170, 110))  # stand-in for the 3D world
    draw = ImageDraw.Draw(image, "RGBA")
    for screen, cls, x, y, w, h, color, transparency, text in boxes:
        alpha = int(255 * (1 - transparency))
        if cls in ("Frame", "TextButton", "TextBox", "ScrollingFrame") and alpha > 0:
            draw.rectangle([x, y, x + w, y + h], fill=color + (alpha,), outline=(20, 20, 30, 255))
        elif cls == "ViewportFrame":
            draw.rectangle([x, y, x + w, y + h], outline=(255, 0, 255, 255))
        if text:
            draw.text((x + 3, y + 2), text, fill=(0, 0, 0, 255))
            draw.text((x + 2, y + 1), text, fill=(255, 255, 255, 255))
    image.save(out_path)
    print(f"{len(boxes)} elements, screen {width}x{height} -> {out_path}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3])
