"""Reads the map dump from tools/layout/dump.lua and reports things that look wrong from above:
  * ON ROAD      something standing on a road or sidewalk (a tree, rock, post, fence...)
  * LAMP         a lamppost on the asphalt instead of the sidewalk
  * OVERLAP      two solid things at ground level poking into each other (from different groups)
and draws a top-down picture of the whole map.

    python tools/layout/check.py dump.txt map.png
"""

import sys
from collections import defaultdict

from PIL import Image, ImageDraw

ROAD_SURFACE = {"Road", "Sidewalk"}
ROAD_MARKS = {"Crosswalk", "RoadLine"}
# Flat things you walk on (never "in the way")
GROUND = {
    "Island", "Beach", "ZoneGround", "Verge", "Lawn", "FrozenLake", "Road", "Sidewalk", "Crosswalk",
    "RoadLine", "CityStreet", "Grout", "Floor", "Plaza", "PlazaFloor", "PlazaBorder", "Pond", "Water",
}


def load(path):
    items = []
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            if not line.startswith("L|"):
                continue
            parts = line.strip().split("|")
            if len(parts) != 8:
                continue
            name_path = parts[1]
            numbers = [float(v) for v in parts[2:]]
            items.append({"path": name_path, "name": name_path.split("/")[-1], "box": numbers})
    return items


def overlap(a, b, pad=0.0):
    ax0, ay0, az0, ax1, ay1, az1 = a
    bx0, by0, bz0, bx1, by1, bz1 = b
    return (
        min(ax1, bx1) - max(ax0, bx0) > pad
        and min(ay1, by1) - max(ay0, by0) > pad
        and min(az1, bz1) - max(az0, bz0) > pad
    )


def area(a, b):
    return max(0, min(a[3], b[3]) - max(a[0], b[0])) * max(0, min(a[5], b[5]) - max(a[2], b[2]))


def group(item):
    # e.g. "Scenery/Wilderness/Trunk" -> "Scenery/Wilderness"
    bits = item["path"].split("/")
    return "/".join(bits[:-1]) if len(bits) > 1 else bits[0]


ROUND = {"SnowHill"}  # balls: their box corners are empty, so test against the real sphere


def round_miss(a, b):
    """True when one of the two is a ball whose actual sphere doesn't reach the other's box"""
    for ball, other in ((a, b), (b, a)):
        if ball["name"] in ROUND:
            box = ball["box"]
            center = [(box[0] + box[3]) / 2, (box[1] + box[4]) / 2, (box[2] + box[5]) / 2]
            radius = (box[3] - box[0]) / 2
            o = other["box"]
            closest = [min(max(center[i], o[i]), o[i + 3]) for i in range(3)]
            distance = sum((closest[i] - center[i]) ** 2 for i in range(3)) ** 0.5
            return distance > radius - 0.5
    return False


def is_ground(item):
    name = item["name"]
    if name in GROUND:
        return True
    b = item["box"]
    return b[4] - b[1] < 0.8 and b[4] < 1.2  # a flat slab


def main():
    items = load(sys.argv[1])
    out = sys.argv[2] if len(sys.argv) > 2 else "map.png"
    roads = [i for i in items if i["name"] in ROAD_SURFACE and "/Roads/" in "/" + i["path"]]
    asphalt = [i for i in roads if i["name"] == "Road"]
    solid = [
        i for i in items
        if not is_ground(i) and i["box"][1] < 3 and i["box"][4] > 0.6 and i["name"] not in ROAD_MARKS
    ]
    problems = []

    # Things standing on roads (lamps are fine on sidewalks, not on asphalt)
    for thing in solid:
        is_lamp = thing["name"].startswith("Lamp")
        for road in (asphalt if is_lamp else roads):
            if area(thing["box"], road["box"]) > 0.3 and thing["box"][1] < road["box"][4] + 2:
                label = "LAMP" if is_lamp else "ON ROAD"
                if is_lamp and "/Roads/" not in "/" + thing["path"]:
                    label = "ON ROAD"
                problems.append((label, thing["path"], road["path"], thing["box"]))
                break

    # Lampposts poking into anything at any height (tree branches, signs...)
    for lamp in items:
        if lamp["name"] not in ("LampPole", "LamppostArt"):
            continue
        for thing in items:
            if thing is lamp or is_ground(thing) or thing["name"].startswith("Lamp"):
                continue
            if overlap(lamp["box"], thing["box"], 0.05):
                problems.append(("LAMP HIT", lamp["path"], thing["path"], lamp["box"]))
                break

    # Solid things poking into each other (different groups only; parts of one thing overlap on purpose)
    cell = 20
    grid = defaultdict(list)
    for index, thing in enumerate(solid):
        b = thing["box"]
        for gx in range(int(b[0] // cell), int(b[3] // cell) + 1):
            for gz in range(int(b[2] // cell), int(b[5] // cell) + 1):
                grid[(gx, gz)].append(index)
    seen = set()
    for bucket in grid.values():
        for i in range(len(bucket)):
            for j in range(i + 1, len(bucket)):
                a, b = solid[bucket[i]], solid[bucket[j]]
                key = (min(bucket[i], bucket[j]), max(bucket[i], bucket[j]))
                if key in seen:
                    continue
                seen.add(key)
                if group(a) == group(b):
                    continue
                # (a zone lock is a see-through barrier across the way in: it crosses the bridge on purpose)
                if a["path"].startswith("ZoneLock_") or b["path"].startswith("ZoneLock_"):
                    continue
                if overlap(a["box"], b["box"], 0.4) and area(a["box"], b["box"]) > 2 and not round_miss(a, b):
                    problems.append(("OVERLAP", a["path"], b["path"], a["box"]))

    for kind, a, b, box in sorted(problems):
        print(f"{kind:8} {a}  <->  {b}   at x={(box[0] + box[3]) / 2:.0f} z={(box[2] + box[5]) / 2:.0f}")
    print(f"\n{len(items)} pieces, {len(problems)} problems")
    glitches = report_glitches(sys.argv[1])

    # Top-down picture
    xs = [i["box"][0] for i in items] + [i["box"][3] for i in items]
    zs = [i["box"][2] for i in items] + [i["box"][5] for i in items]
    x0, x1 = max(min(xs), -320), min(max(xs), 320)
    z0, z1 = max(min(zs), -480), min(max(zs), 220)
    scale = 2
    image = Image.new("RGB", (int((x1 - x0) * scale), int((z1 - z0) * scale)), (70, 150, 220))
    draw = ImageDraw.Draw(image)

    def rect(b, fill=None, outline=None):
        draw.rectangle(
            [(b[0] - x0) * scale, (b[2] - z0) * scale, (b[3] - x0) * scale, (b[5] - z0) * scale],
            fill=fill, outline=outline,
        )

    order = sorted(items, key=lambda i: (not is_ground(i), i["box"][4]))
    for item in order:
        name = item["name"]
        if name == "Island":
            color = (122, 204, 92)
        elif name == "Beach":
            color = (236, 206, 148)
        elif name == "Road":
            color = (78, 80, 92)
        elif name == "Sidewalk":
            color = (186, 188, 196)
        elif name in ROAD_MARKS:
            color = (250, 250, 250)
        elif name.startswith("Lamp"):
            color = (255, 230, 120)
        elif name in ("Trunk", "Leaves", "Needles", "Snow", "Frond", "PalmTrunk"):
            color = (60, 150, 60)
        elif is_ground(item):
            color = (150, 200, 120)
        else:
            color = (200, 110, 90)
        rect(item["box"], fill=color)
    for kind, _, _, box in problems:
        rect(box, outline=(255, 0, 255))
    for g in glitches:
        x, z = g["x"], g["z"]
        draw.ellipse([(x - x0) * scale - 3, (z - z0) * scale - 3, (x - x0) * scale + 3, (z - z0) * scale + 3],
                     outline=(255, 255, 0))
    image.save(out)
    print("picture:", out)


# Things allowed to hang in the air (clouds, birds...). Add a name here only when it floats on purpose.
MAY_FLOAT = {"Cloud", "Bird", "Balloon", "Glow", "Sparkle", "OrdersLetter"}

# Per-zone budget (overhaul quality bar line 7). Starting numbers: tighten them once the KayKit world is in.
#   visible      parts you can see        meshes     different mesh ids (each one is a download)
#   textures     different texture ids    lights     PointLights/SpotLights/SurfaceLights
BUDGET = {"visible": 2500, "meshes": 150, "textures": 40, "lights": 30, "emitters": 40}


def report_glitches(path):
    """Prints the overhaul glitch report (floating, sunk, z-fighting, invisible walls) and the zone budget.
    Returns the glitches with positions so the map picture can circle them."""
    found = {"FLOATING": [], "SUNK": [], "Z-FIGHT": [], "INVISIBLE WALL": []}
    budget = []
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            bits = line.strip().split("|")
            kind = bits[0]
            try:
                if kind == "F" and len(bits) == 7:
                    if bits[1].split("/")[-1] in MAY_FLOAT:
                        continue
                    gap = float(bits[6])
                    note = "over nothing" if gap < 0 else f"{gap:.1f} above what's under it"
                    found["FLOATING"].append({"text": f"{bits[1]}  ({note})", "zone": bits[2],
                                              "x": float(bits[3]), "z": float(bits[5])})
                elif kind == "S" and len(bits) == 8:
                    found["SUNK"].append({"text": f"{bits[1]}  ({float(bits[6]):.1f} of {float(bits[7]):.1f} studs under)",
                                          "zone": bits[2], "x": float(bits[3]), "z": float(bits[5])})
                elif kind == "Z" and len(bits) == 8:
                    found["Z-FIGHT"].append({"text": f"{bits[1]}  <->  {bits[2]}", "zone": bits[3],
                                             "x": float(bits[4]), "z": float(bits[6])})
                elif kind == "W" and len(bits) == 9:
                    found["INVISIBLE WALL"].append({"text": f"{bits[1]}  ({bits[6]} x {bits[7]} x {bits[8]})",
                                                    "zone": bits[2], "x": float(bits[3]), "z": float(bits[5])})
                elif kind == "B" and len(bits) == 9:
                    budget.append((bits[1], {"visible": int(bits[2]), "total": int(bits[3]), "meshParts": int(bits[4]),
                                             "meshes": int(bits[5]), "textures": int(bits[6]), "lights": int(bits[7]),
                                             "emitters": int(bits[8])}))
            except ValueError:
                continue

    everything = []
    print("\n=== Overhaul glitch report (target: 0 of everything) ===")
    for kind, rows in found.items():
        by_zone = defaultdict(int)
        for row in rows:
            by_zone[row["zone"]] += 1
        zones = ", ".join(f"{z} {n}" for z, n in sorted(by_zone.items(), key=lambda kv: -kv[1]))
        print(f"{kind:15} {len(rows):5}   {zones}")
        everything += rows
    for kind, rows in found.items():
        if rows:
            print(f"\n{kind} (first 40):")
            for row in rows[:40]:
                print(f"  [{row['zone']}] {row['text']}   at x={row['x']:.0f} z={row['z']:.0f}")

    over = 0
    if budget:
        print("\n=== Zone budget ===")
        print(f"{'zone':10} {'visible':>8} {'total':>7} {'meshes':>7} {'textures':>9} {'lights':>7} {'emitters':>9}")
        for zone, s in sorted(budget):
            flags = [k for k, limit in BUDGET.items() if s[k] > limit]
            over += len(flags)
            print(f"{zone:10} {s['visible']:8} {s['total']:7} {s['meshes']:7} {s['textures']:9} {s['lights']:7} "
                  f"{s['emitters']:9}  {'OVER: ' + ', '.join(flags) if flags else 'ok'}")
    print(f"\nGLITCHES: {len(everything)}   OVER BUDGET: {over}")
    return everything


if __name__ == "__main__":
    main()
