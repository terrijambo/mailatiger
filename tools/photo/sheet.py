"""Picks one frame per photo-tour shot (the shot name is in the corner tag) and saves a labelled
contact sheet plus each shot as its own picture in tools/photo/out/shots/."""
import os
import sys

from PIL import Image, ImageChops, ImageStat

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
VIEW = (10, 176, 1376, 980)  # the game viewport inside the maximized Studio window
TAG = (1112, 948, 1356, 966)  # the shot-name tag (bottom right of the viewport)


def main():
    files = sorted(f for f in os.listdir(OUT) if f.endswith(".png"))
    shots = []
    last = None
    for name in files:
        image = Image.open(os.path.join(OUT, name)).convert("RGB")
        if image.size != (1936, 1056):
            continue
        tag = image.crop(TAG).convert("L")
        if last is None or ImageStat.Stat(ImageChops.difference(tag, last)).mean[0] > 6:
            shots.append([image])
        else:
            shots[-1].append(image)
        last = tag
    folder = os.path.join(OUT, "shots")
    os.makedirs(folder, exist_ok=True)
    for old in os.listdir(folder):
        os.remove(os.path.join(folder, old))
    picks = []
    for index, group in enumerate(shots):
        image = group[min(1, len(group) - 1)].crop(VIEW)  # the 2nd frame: settled
        image.save(os.path.join(folder, f"{index:02d}.png"))
        picks.append(image)
    cols = 5
    w, h = 340, 200
    rows = (len(picks) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * w, rows * h))
    for i, image in enumerate(picks):
        sheet.paste(image.resize((w, h)), ((i % cols) * w, (i // cols) * h))
    sheet.save(sys.argv[1] if len(sys.argv) > 1 else os.path.join(OUT, "sheet.png"))
    print(f"{len(picks)} shots")


main()
