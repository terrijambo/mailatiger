"""Reads the device layout test output (tools/devices/run.sh) and reports, for each screen size measured:
  * OVERLAP     two separate pieces of HUD covering each other
  * OFF SCREEN  something sticking out past the edge
  * THUMBSTICK / JUMP   on phone-sized screens, HUD sitting where the touch thumbstick or jump button go
and draws a picture of each size (tools/devices/out/hud_WxH.png and shop_WxH.png).

    python tools/devices/check.py devices.txt
"""

import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "e2e"))
from draw_ui import main as draw  # noqa: E402

# Pieces that are meant to sit on top of others (popups, the level-up burst, the tutorial arrow...)
ALLOWED = ("Popups/", "LevelUp/")


def rect_overlap(a, b):
    w = min(a[0] + a[2], b[0] + b[2]) - max(a[0], b[0])
    h = min(a[1] + a[3], b[1] + b[3]) - max(a[1], b[1])
    return w > 2 and h > 2


def main(path):
    out_dir = os.path.join(os.path.dirname(__file__), "out")
    os.makedirs(out_dir, exist_ok=True)
    screens, widgets = {}, {}
    for line in open(path, encoding="utf-8", errors="ignore"):
        m = re.match(r"UI (\S+) SCREEN (\d+) (\d+)", line)
        if m:
            screens[m.group(1)] = (int(m.group(2)), int(m.group(3)))
            continue
        m = re.match(r"UI (\S+) WIDGET (.+)\|(-?\d+)\|(-?\d+)\|(\d+)\|(\d+)", line.strip())
        if m:
            widgets.setdefault(m.group(1), []).append((m.group(2), tuple(int(m.group(i)) for i in range(3, 7))))

    total = 0
    for tag in sorted(screens, key=lambda t: (t.split("_")[0], -screens[t][0])):
        width, height = screens[tag]
        problems = []
        items = widgets.get(tag, [])
        for name, r in items:
            if r[0] < -2 or r[1] < -2 or r[0] + r[2] > width + 2 or r[1] + r[3] > height + 2:
                problems.append(f"OFF SCREEN  {name} at {r}")
        for i in range(len(items)):
            for j in range(i + 1, len(items)):
                (na, ra), (nb, rb) = items[i], items[j]
                if na.startswith(ALLOWED) or nb.startswith(ALLOWED):
                    continue
                if tag.startswith("shop_") and ("Shop/" in na or "Shop/" in nb):
                    continue  # a window covering the HUD is expected
                if rect_overlap(ra, rb):
                    problems.append(f"OVERLAP     {na} {ra}  <->  {nb} {rb}")
        if tag.startswith("hud_") and (height < 600 or width < 1000):
            # Roblox's touch controls on small screens: thumbstick area bottom-left, jump button bottom-right
            thumb = (0, int(height * 0.55), int(width * 0.32), height - int(height * 0.55))
            jump = (width - 120, height - 110, 100, 95)
            for name, r in items:
                if name.startswith(ALLOWED) or "TrollBar" in name or "Tutorial" in name:
                    continue
                if rect_overlap(r, thumb):
                    problems.append(f"THUMBSTICK  {name} at {r}")
                if rect_overlap(r, jump):
                    problems.append(f"JUMP        {name} at {r}")
        print(f"== {tag} ({width}x{height}): {len(problems)} problems")
        for p in problems:
            print("   " + p)
        total += len(problems)
        draw(path, tag, os.path.join(out_dir, f"{tag}.png"))
    print(f"\n{len(screens)} layouts, {total} problems. Pictures in {out_dir}")


if __name__ == "__main__":
    main(sys.argv[1])
