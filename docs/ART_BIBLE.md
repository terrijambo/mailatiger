# Art Bible: Mail Animals!

The rules every model, color and scene follows during the overhaul (`docs/OVERHAUL_PLAN.md`). When a new
piece breaks one of these, fix the piece, not the rule. Changing a rule is a decision: log it in
`ROADMAP.md` → Decisions.

## 1. Style: KayKit (decided 2026-10-20)

- **Look:** chunky, rounded, bevelled low-poly; soft cartoon proportions (big heads, short legs, thick
  trunks); bright but not neon. Think a toy diorama in the sun.
- **One texture for the world:** KayKit models are colored by one small gradient atlas (1024×1024, fine at
  256×256 on phones). Every world model uses that atlas or plain SmoothPlastic colors from the palette below.
  No photo textures, no default Roblox textured materials (Brick, Grass, Cobblestone…) on anything visible.
- **No outlines, no black lines.** Shape and color carry the read; the lighting (Future + bloom) does the rest.
- **Other packs** (Quaternius, Cozy Animals) only where KayKit has nothing, and only after recoloring to the
  palette and checking them next to a KayKit model in the same shot.
- **Packs to use** (all CC0, from https://kaylousberg.itch.io/): Forest Nature Pack (trees, bushes, rocks,
  grass, modular terrain), City Builder Bits (town, park), Holiday Bits (snow), Resource Bits (farm crates,
  logs, hay), Furniture Bits + Restaurant Bits (shop, Post Office, stalls), Platformer Pack (event props).

## 2. Palette

The world and the UI share one palette, so the screens look like they belong to the world.

| Family | Light | Mid | Dark | World use | UI use (UIPack Plus family) |
|---|---|---|---|---|---|
| Grass | `#9DED6D` | `#6FDD3F` | `#4CB428` | lawns, leaves, Backyard | `green`: confirm, buy, go |
| Sky / water | `#A9F5FF` | `#45CFF0` | `#1E9AC2` | sea, ice, glass | `cyan`: info, selected |
| Sun / gold | `#FFE79B` | `#FFB724` | `#DD7F0B` | coins, Golden variants, lamps | `amber`: coins, rewards |
| Brick / alert | `#FFAB9D` | `#F4523F` | `#C2281B` | roofs, mailboxes, vine boom | `red`: danger, close |
| Post blue | `#C3AEFF` | `#8A6BF0` | `#5C3FBE` | Post Office trim, magic | `violet`: Robux store, rare |
| Candy | `#FFB6CF` | `#F26A97` | `#D24A78` | flowers, hearts, petting | `pink`: love meter, events |
| Stone | `#8095B8` | `#5D719A` | `#41527A` | rocks, paths, cliffs | `slate`: disabled, neutral |
| Outline (UI only) | | `#0D1524` | | — | every UI piece's outline |

Island ground colors stay as in `Config/World.luau` (`Ground` per island) until Phase 3 replaces the ground.
Each island also has a color grade (`Config/Look.luau` → `Zones`) that tints the whole view while you're there.

## 3. Scale

Players are drawn at 60% (`Config/World.PlayerScale`), so a player stands about **3.1 studs** tall and the
world feels big. Everything is measured against that.

| Thing | Height (studs) | Note |
|---|---|---|
| Player | 3.1 | the ruler |
| Door | 6 | about 2× a player |
| One-floor house | 12–14 | KayKit houses at 1:1 land close to this |
| Post Office (hero building) | 20 | the tallest thing in the plaza |
| Lamppost | 7–8 | |
| Bench | 1.6 seat | |
| Small tree | 10–14 | Large tree 18–24 |
| Bush | 2–3 | never hides a player completely |
| Hamster / small animal | 1.5–2.5 | tier 1 |
| Tiger / big animal | 5–7 | tier 4 |
| Elephant / whale / dragon | 9–14 | tier 5–6 |
| Gruff | 6.5 | bigger than the player on purpose |

Imported models get their target height from the import tool's table (`tools/import/`), never by eye.

## 4. Building a scene: three layers

Every area is built in this order, and isn't done until all three are there:
1. **Big shapes:** ground, cliffs, the landmark, buildings. Readable as a silhouette from the plaza.
2. **Medium props:** trees, fences, stalls, benches, lamps, crates. Grouped in clusters of 3–5 with gaps
   between clusters; never evenly spaced in a grid.
3. **Small clutter:** grass tufts, flowers, pebbles, leaves, signs. Breaks up every flat surface and every
   seam where two big pieces meet.

Keep the gameplay space clean: animal play areas, paths, prompts and machine fronts have nothing that
blocks movement or the camera.

## 5. Technical rules for every model

- **Pivot** at the bottom center, facing −Z (the way the game rotates models).
- **Decoration** (clutter, trees, most props): `CanCollide`, `CanTouch` and `CanQuery` off,
  `CollisionFidelity = Box`. Things you should bump into (buildings, big rocks, fences) keep `CanCollide`
  on with a simple collision shape.
- **Shadows:** `CastShadow` off on small clutter (grass, flowers, pebbles), on for everything bigger.
- **Names:** the model's name says what it is (`OakTree`, `CityBench`), matching what `MapBuilder` /
  `Scenery` look up in `MapModels` / `PropModels`.
- **Grounded:** every model touches what it stands on. Trees and rocks may sink up to 15% of their height
  into the ground, never more.
- **No coplanar faces:** two different-colored faces never sit on the same plane (they flicker). Inset or
  raise one by 0.02 studs, or merge them.

## 6. Lighting

- Lighting → Properties: **LightingStyle = Realistic** and **PrioritizeLightingQuality = on** (Studio settings saved in
  the place; they replaced the old `Technology = Future` in 2026 Studio).
- Shared light, day/night cycle, atmosphere, bloom and sun rays: `Config/Look.luau`, applied by
  `server/Look.luau`.
- Per-island mood: `Config/Look.luau` → `Zones`, applied on each player's screen by `client/ZoneLook.luau`.
- Lamps and windows: warm `#FFD9A0` light, tagged `NightLight` so they brighten at night.

## 7. Checks: an area is finished when

1. `bash tools/layout/run.sh` prints `GLITCHES: 0   OVER BUDGET: 0` for it (floating, sunk, z-fighting,
   invisible walls, plus the road/overlap checks above them).
2. Its row in the zone budget is under every limit (`tools/layout/check.py` → `BUDGET`).
3. `bash tools/photo/run.sh` pictures are added to `docs/overhaul/` (before / after).
4. `bash tools/devices/run.sh` is clean (UI on phones).

**Baseline on 2026-10-20 (before the overhaul):** 128 glitches (1 floating, 5 sunk, 122 z-fighting,
0 invisible walls) and the Town over budget (2,767 visible parts, 57 lights). 7,069 visible graybox parts.
