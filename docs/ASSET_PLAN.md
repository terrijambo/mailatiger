# Asset Plan: every model in Mail Animals! at top-100 quality

Written 2026-10-20, after the owner's review of the first KayKit town pass ("sizing is inconsistent", "make sure
the fountain, Gruff, all the animals and the map don't look low-effort or vibe-coded"). This replaces the
"Phase 3 / Phase 4" asset parts of `docs/OVERHAUL_PLAN.md` with a full list: **every visible asset, where its
replacement comes from, the spec it must meet, and the order.** Rules for style, palette and scale stay in
`docs/ART_BIBLE.md`.

Before-photos: `docs/overhaul/before/` (fountain, Gruff and the Post Office, a wild Bear, a machine).

---

## 1. The honest audit (what fails the bar today)

| Area | What it is now | Why it fails |
|---|---|---|
| Animals (25) | Blender shapes built by script, flat colors, dot eyes, no rig, hops faked in code | No faces that react, no real animation, stiff silhouettes. The single biggest gap: they're the game. |
| Gruff (mascot) | Simple flat-colored walrus, mostly hidden behind the counter | The mascot reads as a placeholder. |
| Fountain (plaza centerpiece) | ~30 plain cylinders and a gift box | Looks like a graybox. It's the first thing every player sees. |
| Post Office (hero building) | A red box, a blank yellow sign, flat windows | Not a landmark. |
| Machines (7), counters, chute, boards, pads, egg stands | Block-built parts | Grey posts and slabs. |
| Map | Islands of stacked parts, cliffs of blocks, part-built lamps (57 lights in Town), plaza grout lines | Square edges, seams, and 2,700+ visible parts in the Town alone. |
| Sizing | About 40 hand-typed sizes across the code, some by width and some by height | Nothing shares a scale: pines tower over the bears, townhouses and cottages don't match (the owner's note). |
| New KayKit trees | Fine, but the "umbrella" trees (Tree3) have odd curly orange trunks at this size | Drop them from the town mix. |

The KayKit trees, bushes, rocks and grass from the first pass are the quality floor everything else must meet:
consistent, bevelled, colored by one shared texture. **Everything below is judged against them.**

---

## 2. Three rules that make it all look like one game

1. **One texture for the world.** Every new model, whether bought, generated or built, is colored by a KayKit
   gradient atlas (`forest_texture.png`, `citybits_texture.png`, already uploaded: `Config/Atlases.luau`).
   Models we make ourselves are UV-mapped onto the same atlas in Blender. That alone makes a custom fountain
   sit next to a KayKit tree as if they came from the same artist.
2. **One size table.** A new `Config/ModelSizes.luau` gives every model its real height in studs, measured
   against the player (3.1 studs at 60% scale). Every spawn reads it, so no code types a size again. A test in
   `tests/` fails if any `ModelFit.Spawn` / `Kit.model` call passes a hand-typed number. This is step 1
   (section 5) because it fixes the owner's "inconsistent sizing" across the whole map at once.
3. **Hero assets get the most care.** In order of how often players look at them: animals, Gruff, the fountain,
   the Post Office, the machines and the BOX-screen box. Those get custom work; background scenery comes
   from packs.

---

## 3. Where each asset comes from

Four sources, chosen per asset:
- **PACK:** bought or free KayKit / Quaternius models (CC0), recolored to the atlas if needed. Background scenery.
- **BUILD:** made in Blender by the agent with a script: hard-surface things (buildings, machines, props) that
  are boxes, cylinders and bevels underneath. The agent can do this well *if* it follows a detailed spec and
  uses the KayKit atlas. (The old scripts used flat colors and too few bevels; that's the "vibe-coded" look.)
- **GENERATE:** organic characters (animals, Gruff's face) made with an AI 3D generator from a consistent style
  sheet, then cleaned up, re-textured onto the atlas, rigged and animated. Script-built shapes can't make
  good animals (proven by the current ones), and **no pack has our 25 species in one style** (checked
  2026-10-20: the closest packs cover 8–12 different animals each, all different styles).
- **COMMISSION:** a human 3D artist, only if a generated animal can't reach the bar after cleanup.

### 3a. Characters

| Asset | Source | Spec |
|---|---|---|
| **The 25 animals** | GENERATE, then Blender cleanup | One style sheet for all 25 (section 4): chibi proportions (head about 40% of height), big glossy eyes with eyelids, a mouth that can open, 2–3 color tones, soft bevelled forms like KayKit. 3–6k triangles. Rigged with real animations: idle, walk, run, panic (being chased), grabbed (wriggle), in-box happy, in-box angry, launch (vine boom). Faces: happy, angry and shocked swaps. |
| **Gruff** (walrus, the mascot) | GENERATE (or COMMISSION if the pilot isn't good enough) | The best-looking character in the game: postal jacket with brass buttons and a satchel, tiny cap, huge mustache and tusks, grumpy brows. Animations: idle (tapping the counter), talk (mouth moves while dialogue types), point, angry stamp, laugh, celebrate. Reference: Cozy Animals 3D has a CC0 rigged walrus to study for proportions. |
| **Shiny / Golden variants** | Material work on the same models | Golden: metallic gold material plus a sparkle particle aura. Shiny: hue shift plus a glint sweep. Not just a recolor. |
| **Boss crown** | BUILD | Chunky gold crown on the atlas, gem bevels. |

### 3b. The plaza (first impression: do this first)

| Asset | Source | Spec |
|---|---|---|
| **Fountain** | BUILD | 3 tiers of bevelled stone blocks (not cylinders): a wide octagonal basin with a stone rim and a mosaic of the postal-stamp emblem on its floor, a middle bowl on a carved pillar, and on top a **bronze statue of Gruff holding a parcel over his head** (the plaza's landmark; generated with the Gruff model, then made bronze). Water: animated textured surfaces in each bowl, Beam arcs falling from bowl to bowl, splash particles, coins glinting in the basin. 6–10k tris, KayKit atlas plus one water texture. |
| **Post Office** | BUILD, using KayKit City Builder Extra pieces | Two-story corner building with a clock tower, 3D gold letters "POST OFFICE", striped awnings, a big brass mail slot, flags, window boxes, and a loading dock where the chute meets it. The tallest thing in the plaza (20 studs; the size table enforces it). |
| Post counter, Pen counter, Shop stall | BUILD plus KayKit Restaurant / Furniture Bits | Wood counters with trim, tills, letter trays, a bell, awnings, crates of tape (Resource Bits crates). |
| **Mail chute** + 3 upgrades | BUILD | Brass-and-blue chute with an animated flap. Upgrades: conveyor (moving belt texture), pneumatic glass tube (parcels visibly fly up it), rocket pad (countdown lights). |
| **The 7 machines** (Stamp Machine, Postage Scale, Fragile Handler, Sorting Belt, Express Sorter, Airmail Drone Dock, Rocket Launcher) | BUILD, with KayKit Platformer and Space Base bits for gears, lights and pipes | Each one gets a readable silhouette from 30 studs away and one moving part (stamp arm, scale needle, belt, drone, rocket). A shared base plinth with a brass plaque. The machine you can afford next glows. |
| Orders board, Leaderboards, Spawn / Travel pads, Egg stands (5) | BUILD | Cork board with pinned slips and a roof; framed boards with a trophy; stone pads with the stamp emblem and a glowing ring; egg pedestals with a velvet cushion and a rarity-colored crystal ring. |
| Lamps, benches, mailboxes, planters, bins, hydrants | PACK (KayKit City Builder Extra) | Replace the part-built lamps (they're most of the Town's 57 lights; keep about 16 real lights and make the rest glowing material only). |
| Paving, plaza floor | BUILD (one mesh) | One plaza-floor mesh with the sunburst paving modeled in, instead of ~170 grout parts. |
| Townhouses, cottages | PACK (KayKit City Builder, Medieval Hexagon houses) | Already started. Use the size table, and give every lot a fence, path and garden so none looks dropped in. |

### 3c. Boxes and gameplay props (seen up close on the BOX screen)

| Asset | Source | Spec |
|---|---|---|
| Boxes: Cardboard, Wood, Steel, Vault | BUILD | Cardboard: folded flaps, tape seams, a printed "FRAGILE" label, a dent shape key for when the animal kicks. Wood: planks with nails. Steel: rivets and bands. Vault: a dial that spins. Open-top for the animal. |
| Parcel, tape roll, rubber stamp, envelope, egg | BUILD | Same atlas, chunky bevels. |
| Tools (gloves, sneakers, tape gun, net, etc.) | BUILD | Shop display models, slowly spinning on a pedestal. |

### 3d. The islands (in unlock order)

The ground itself becomes **Roblox Terrain** (smooth sculpted shores, real water, no square seams) with a
stylized grass material, and KayKit rocks for cliffs. Each island gets one landmark you can see from the plaza.

| Island | Packs | Landmark (BUILD or PACK) |
|---|---|---|
| Backyard | KayKit City Builder Extra (park), Furniture Bits, Forest | A big treehouse |
| Barn / Farm | KayKit Medieval Hexagon (windmill, well, houses), Resource Bits (hay, crates, logs), Quaternius LowPoly Farm Buildings | The red barn and windmill (rebuilt on the atlas) |
| Jungle | KayKit Forest Extra, Quaternius Stylized Nature MegaKit (recolored) | A giant hollow tree with vines and a waterfall |
| Ice Rink | KayKit Holiday Bits, Forest Extra snow colors | An ice castle |
| Rooftop | KayKit City Builder Extra | A billboard tower with neon |
| Rebirth Beach | KayKit Platformer, Quaternius palms | The lighthouse (rebuilt on the atlas) |
| Volcano / Boss | KayKit Dungeon / Halloween Bits, Forest rocks recolored dark | The volcano with lava flows |

### 3e. Sky, water, light

- A **custom stylized skybox** (soft clouds, warm horizon). ForgeGUI's skybox route can turn a painted panorama
  into Roblox's 6 faces; the panorama itself can be generated, then checked by eye.
- Water: Terrain water with tuned color and waves, plus foam where it meets the shore.
- Lighting: Realistic + quality on (done), per-island color grades (done), night lamps tagged `NightLight`.

### 3f. UI icons

All HUD and window icons re-rendered from the new 3D models in Blender (one lighting setup, transparent
background), so the side buttons, shop cards and Pen thumbnails match the world. Replaces the mixed emoji and
older icons.

---

## 4. How the animals get made (the pipeline)

Script-built shapes have been tried and aren't good enough, and no pack exists, so this is a production line:

1. **Style sheet first.** One reference image per animal in one art style (chibi, glossy eyes, KayKit-like soft
   bevels, the palette from the art bible), front and three-quarter views. The owner approves the sheet
   before any 3D work. This is what keeps 26 characters consistent.
2. **Generate the 3D model** from that sheet (ForgeGUI `generation_model_3d` is available in this setup; Meshy,
   Tripo or Roblox's own mesh generator are alternatives). Use the same style reference images for every animal.
3. **Clean up in Blender** (agent, scripted): decimate to 3–6k tris, separate eyes and eyelids, add mouth shape
   keys, re-texture onto the palette (bake the generated texture down to the atlas colors so they match the
   world), set the pivot at the feet, apply the size from the size table.
4. **Rig and animate:** quadrupeds and bipeds (ForgeGUI `generation_rig_3d` / `generation_animate_3d`, or Blender
   with Auto-Rig Pro), the 8 clips listed in 3a. Exported as Roblox animations and played by an
   AnimationController. `client/Animate.luau` keeps only the extras (squash when petted, shake by anger).
5. **Review gate:** a turntable picture of each animal next to a KayKit tree and the player, checked by the owner.
   Not good enough after one retry → COMMISSION that animal instead.

**Pilot result (2026-10-20): done, with Roblox Studio's own AI mesh generator.** ForgeGUI was out of credits
(71 left; an image costs 1,600, refills 2026-11-10) and Higgsfield had ~1, so the pilot used Studio's built-in
generator (no credits), with each animal split into named parts (Body, Head, Ears/Tail, legs or paws). Hamster
(8 parts) and Tiger (7 parts) are installed in `ReplicatedStorage > AnimalModels`; the old ones are kept in
`ServerStorage > OldAnimalModels`. Checked in Play: the wild Hamster and the Tiger on the BOX screen look like a
matching, premium set (soft chibi shapes, big glossy eyes, textured colors). `ModelFit.Paint` now leaves textured
parts alone. Still to do for these two: real animations (the separate parts make a code wiggle easy; a proper rig
needs ForgeGUI credits or Blender). If the owner approves, the other 23 animals and Gruff go through the same
generator with the same prompt style (see the pilot prompts in this file's history).

**Pilot before committing:** Hamster (tier 1, seen first) and Tiger (the title animal) go through all 5 steps
first. The owner judges them in Play. Only then do the other 23 and Gruff. The pilot costs a few ForgeGUI
credits; the agent asks before spending any.

---

## 5. Order of work

| Step | What | Who | Done when |
|---|---|---|---|
| 1 | **Size table** (`Config/ModelSizes.luau`), every spawn uses it, plus a test that blocks hand-typed sizes. Drop the umbrella trees from the town mix. | Agent | Every model in the town is in proportion to the player; test passes |
| 2 | **Buy the packs** (section 6), import them with the KayKit tool (2 imports per pack, same as tonight) | Owner (purchase), agent (tools) | Packs in `MapModels` |
| 3 | **Plaza heroes:** fountain, Post Office, counters, chute, plaza floor mesh, lamps | Agent (BUILD) | Plaza photos side by side with a top game; glitch tool 0; Town under budget |
| 4 | **Animal pilot:** style sheet → Hamster + Tiger through the pipeline | Agent; owner approves the sheet, the credits and the result | Owner says "yes" in Play |
| 5 | **Gruff** (and his bronze statue for the fountain) | Agent (GENERATE) or commission | Owner says "yes" |
| 6 | **Machines, boxes, props, egg stands, boards** | Agent (BUILD) | All in the atlas; BOX screen box with dents |
| 7 | **The other 23 animals**, tier by tier | Agent; owner reviews each tier | Turntables approved |
| 8 | **Islands** in unlock order: terrain, packs, landmark | Agent; owner imports packs | Glitch tool 0 and in budget per island |
| 9 | **Sky, water, icons** | Agent | Icons re-rendered |
| 10 | **Full review:** play 15 minutes on PC and phone, fix the list, then publish | Owner + agent | Owner happy, then Publish |

Steps 3 and 4 can run side by side (map files vs. character files).

---

## 6. Budget (all one-time, all optional; the free tiers already work)

| Item | Price | Why |
|---|---|---|
| **The Complete KayKit** (every KayKit pack with Extra + Source) | $150 | Recommended. Everything in one consistent style: Forest Extra (terrain, 8 color variants incl. snow), City Extra (park), Medieval Hexagon Extra (village, windmill, well), Platformer Extra, Holiday, Halloween, Dungeon, Restaurant, Furniture, Resource, Space Base. Cheaper than buying the Extras one by one. |
| or just the Extras we use | about $55 | Forest $9.99, City $3.95, Medieval Hexagon $9.99, Platformer $9.99, Holiday $4.99, Resource $4.99, Furniture/Restaurant Extras |
| Quaternius Stylized Nature MegaKit Pro | $9.99 | Jungle plants with more detail (optional) |
| ForgeGUI credits | per their plan | Animal and Gruff generation, rigging, animation; pilot first |
| Auto-Rig Pro (Blender add-on) | about $40 | Only if ForgeGUI's rigs aren't good enough for quadrupeds |
| Commission fallback | about $40–120 per animal | Only for animals that fail the review gate |

Licenses: KayKit and Quaternius are CC0 (free for commercial use, no credit required; credit them anyway in
the game description). Cozy Animals 3D is CC0. Plumberry Plains allows commercial use but not redistribution
of raw files (fine for a Roblox game).

---

## 7. The quality gate (every asset, before it ships)

1. Colored by the atlas (or a material listed in the art bible); no default Roblox textures.
2. Its size comes from `Config/ModelSizes.luau` and looks right next to the player and a KayKit tree.
3. Under its triangle budget (props 1–3k, animals 3–6k, heroes 6–15k).
4. Pivot at the bottom center, facing -Z, decoration flags set (art bible section 5).
5. Glitch tool: no floating, sinking, z-fighting or invisible walls where it's placed.
6. A side-by-side picture with the same kind of thing in a top-100 game (Pet Simulator 99, Adopt Me!, Grow a
   Garden). If it looks worse, it isn't done.

---

## Sources checked (2026-10-20)

- KayKit packs: https://kaylousberg.itch.io/ (Complete KayKit $150; Medieval Hexagon, Platformer, Holiday, Resource
  Bits pages read for contents and CC0 terms)
- Quaternius: Medieval Village MegaKit, Fantasy Props MegaKit, Stylized Nature MegaKit, Ultimate Animated Animals
  (12 animals, not our roster) https://quaternius.itch.io/ and https://quaternius.com/
- Animal packs: Felz lab Cute Cartoon Animals (8: cow, bear, panda, fox, cat, rabbit, dog, pig),
  https://felzlab.itch.io/cute-cartoon-animals-pack-8-rigged-3d-character-models-blender-fbx ; Cube Pets (30
  blocky animals), https://superhivemarket.com/products/cube-pets-30-animated-low-poly-animals ; Gobkit Free Animal
  Pack, Cozy Animals 3D, Plumberry Plains (see `docs/OVERHAUL_PLAN.md`). None covers our 25 species in one style.
