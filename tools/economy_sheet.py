"""
Economy tuning sheet for Mail a Tiger.

Reads the REAL numbers from the game's config files (so it never goes out of date) and estimates how long
each unlock takes if a player always boxes the best animal they own. Writes docs/economy.csv (opens in
Excel / Google Sheets) and prints a summary.

Run from the project folder:   python tools/economy_sheet.py

Assumptions you can tweak below (they're guesses until we have real playtest timings):
  JOB_SECONDS_BASE / JOB_SECONDS_PER_TIER  how long one catch-stuff-tape job takes, by tier
  TYPICAL_STARS                            average rating (4 stamps = 1.0x pay)
"""

import csv
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG = ROOT / "src" / "shared" / "Config"

JOB_SECONDS_BASE = 30  # a tier-1 job, including walking to the Pen and back
JOB_SECONDS_PER_TIER = 12  # each tier up adds this much (harder catch, more stuff hits, longer tape)
TYPICAL_STARS = 4


def read(name: str) -> str:
    return (CONFIG / name).read_text(encoding="utf-8")


def number(text: str, key: str) -> float:
    match = re.search(rf"\b{key}\s*=\s*([\d.]+)", text)
    if not match:
        raise ValueError(f"Couldn't find {key}")
    return float(match.group(1))


def parse_animals() -> list[dict]:
    text = read("Animals.luau")
    animals = []
    # Each animal is a { ... } block containing Id = "...", Tier = n, Price = n, BaseValue = n, Carriers = n
    for block in re.findall(r"\{[^{}]*?Id\s*=\s*\"[^\"]+\"[^{}]*?\}", text, re.S):
        get = lambda key: re.search(rf"\b{key}\s*=\s*\"?([\w.]+)\"?", block).group(1)
        animals.append(
            {
                "Id": get("Id"),
                "Tier": int(get("Tier")),
                "Price": int(get("Price")),
                "BaseValue": int(get("BaseValue")),
                "Carriers": int(get("Carriers")),
            }
        )
    return animals


def star_payout_mult(stars: int) -> float:
    text = read("Boxing.luau")
    values = re.search(r"StarPayoutMult\s*=\s*\{([^}]*)\}", text).group(1)
    return [float(v) for v in values.split(",") if v.strip()][stars - 1]


def main() -> None:
    animals = [a for a in parse_animals() if a["Carriers"] == 1]  # co-op animals come later
    progression = read("Progression.luau")
    rebirth_cost = number(progression, "BaseCost")
    pay_mult = star_payout_mult(TYPICAL_STARS)

    rows = []
    best_rate = 0.0  # coins/minute of the best animal owned so far
    total_minutes = 0.0
    for animal in animals:
        job_seconds = JOB_SECONDS_BASE + JOB_SECONDS_PER_TIER * (animal["Tier"] - 1)
        rate = animal["BaseValue"] * pay_mult / job_seconds * 60
        minutes = 0.0 if animal["Price"] == 0 else animal["Price"] / best_rate
        total_minutes += minutes
        rows.append(
            {
                "Animal": animal["Id"],
                "Tier": animal["Tier"],
                "Price": animal["Price"],
                "Pays (4 stamps)": round(animal["BaseValue"] * pay_mult),
                "Est. job seconds": job_seconds,
                "Coins per minute": round(rate),
                "Minutes to afford": round(minutes, 1),
                "Total hours so far": round(total_minutes / 60, 2),
            }
        )
        best_rate = max(best_rate, rate)

    rebirth_minutes = rebirth_cost / best_rate
    rows.append(
        {
            "Animal": "REBIRTH #1",
            "Tier": "",
            "Price": int(rebirth_cost),
            "Pays (4 stamps)": "",
            "Est. job seconds": "",
            "Coins per minute": "",
            "Minutes to afford": round(rebirth_minutes, 1),
            "Total hours so far": round((total_minutes + rebirth_minutes) / 60, 2),
        }
    )

    out = ROOT / "docs" / "economy.csv"
    with out.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

    print(f"Wrote {out.relative_to(ROOT)}\n")
    print(f"{'Animal':<11}{'Price':>10}{'Pays':>8}{'Coins/min':>11}{'Min to buy':>12}{'Total h':>9}")
    for row in rows:
        print(
            f"{row['Animal']:<11}{row['Price']:>10}{str(row['Pays (4 stamps)']):>8}"
            f"{str(row['Coins per minute']):>11}{row['Minutes to afford']:>12}{row['Total hours so far']:>9}"
        )
    slow = [r for r in rows if isinstance(r["Minutes to afford"], float) and r["Minutes to afford"] > 20]
    if slow:
        print("\nGrind walls (over 20 minutes to afford):", ", ".join(r["Animal"] for r in slow))


if __name__ == "__main__":
    main()
