# Overhaul Plan: making Mail Animals! look and feel like a top-100 Roblox game

Written 2026-10-20. This is the master plan for the visual and feel overhaul. Work through it phase by phase,
in order: each phase has a **Done when** line, and nothing moves on until that line is true. Log decisions in
`ROADMAP.md` → Decisions as usual.

The game is live with real saves, so every phase ships as a normal live update: no save wipes, no
`StoreName` changes, the same rules as `HANDOFF.md`.

---

## The quality bar ("top 100" in checkable terms)

Every phase is judged against this list. If something fails one line, it isn't done.

1. **Nothing grey or placeholder is visible anywhere a player can walk.** Today: 7,069 visible code-built
   blocks against 37 real models (smoke test, 2026-10-20). Target: 0 visible graybox parts.
2. **One art style.** Every model comes from one style family (see Phase 0), and every color comes from one
   palette. Mixing a detailed asset next to a flat one looks worse than both.
3. **No glitches you can see in 10 minutes of play:** nothing floating, nothing sunk into the ground,
   nothing clipping through something else, no invisible walls, no z-fighting (flickering faces), no seams
   between island pieces, no falling through the map.
4. **Every screen uses one UI kit** (UIPack Plus), with the same buttons, panels, fonts, sounds and motion.
5. **Every action has three kinds of feedback:** an animation, a sound and an effect (particles, a camera
   kick or a UI pop). Grab, tape, pet, stamp, mail, level up, hatch, rebirth: all of them.
6. **Animals are characters, not props:** rigged, with real idle / walk / run / panic / in-the-box
   animations, faces that react, and a silhouette you can name from across the island.
7. **Runs well on a phone:** 60 FPS on a mid-range phone in the plaza with 12 players, under ~900 MB
   client memory. Checked with `tools/devices/run.sh` and the MicroProfiler.
8. **The first 60 seconds sell the game:** a new player sees a beautiful plaza, Gruff talking to them, and a
   funny animal to grab within 20 seconds of spawning.

---

## Already done (2026-10-20)

- **ZeroPanel (admin panel) installed.** Synced from `vendor/ZeroPanel/` by Rojo. Its owner is whoever owns
  the game (the pack shipped with its author's Roblox account, `sebattfg`, in the owner list; that was
  replaced). Chat commands start with `!` (for example `!kick Name spam`).
- **UIPack Plus installed.** The library is in `ReplicatedStorage.ShardUI`; the demo screens are in
  `ServerStorage.ShardUIReference` (Studio only, never sent to players: they hold ~5,000 images, and the
  pack's "Idle" setup guide would otherwise pop up for real players).
- Both packs are **proprietary**: their licenses forbid putting them in any repository, and this repo is
  public. So `vendor/` is git-ignored and rebuilt with
  `lune run tools/vendor_packs.luau <UIPackPlus.rbxm> <ZeroPanel.rbxm>`. Keep the two `.rbxm` files backed up
  somewhere private. A fresh clone without them still builds (the paths are optional).

---

## Phase 0 — Decide the direction (owner, ~1 evening)

The owner picks; the agent records the answers in `ROADMAP.md` → Decisions.

1. **Style family for the world** (the biggest choice; everything else follows it):
   - **A. KayKit (recommended).** Cute, chunky, bright, very close to the current look but more detailed.
     Every pack uses the same single gradient texture, so they all match each other, they're tiny (great on
     phones), and the author lists Roblox as supported. Weakest at: very fine detail.
   - **B. Quaternius Stylized Nature + Downtown City.** More detail and real textures (a softer, Ghibli-like
     look). Heavier on memory, and the city kit is realistic-ish Boston brick, which fights the cartoon tone.
   - Recommendation: **A for everything**, plus Quaternius only where KayKit has nothing (and recolored to
     the palette).
2. **Animals:** keep our own 25-animal roster (it's the game's identity, and no pack has all of them),
   rebuilt to a higher-detail spec (Phase 4). Packs are used as a **style reference** and for a few fill-ins.
3. **Name:** the game has been **Mail Animals!** since 2026-10-12 (internal names stay MailATiger). The new
   logo, thumbnails and store art made in Phase 7 use Mail Animals!.
4. **Budget:** the free tiers below are enough to start. Paid tiers add more pieces and color variants; the
   full recommended set is about **$35** (all one-time, all optional).

## Asset shortlist (from itch.io, checked 2026-10-20)

All CC0 unless noted: free for commercial use, no credit required (credit Kay Lousberg / Quaternius in the
game's description anyway; it's good manners). Formats are FBX/GLTF, which the Roblox 3D Importer reads.

| Use it for | Pack | Free tier | Paid tier | Link |
|---|---|---|---|---|
| Trees, bushes, rocks, grass on every island | **KayKit Forest Nature Pack** | 100+ models | $9.99: 200+ models, modular terrain, 8 color variants each | https://kaylousberg.itch.io/kaykit-forest |
| Town plaza: buildings, roads, park pieces | **KayKit City Builder Bits** | 32+ models | $3.95: +16 park pieces | https://kaylousberg.itch.io/city-builder-bits |
| Snow island (Ice Rink) decorations | **KayKit Holiday Bits** | yes | optional | https://kaylousberg.itch.io/holiday-bits |
| Farm/Barn crates, hay, resources | **KayKit Resource Bits** | yes | optional | https://kaylousberg.itch.io/resource-bits |
| Shop, Post Office interior, market stalls | **KayKit Furniture Bits**, **Restaurant Bits** | yes | optional | https://kaylousberg.itch.io/furniture-bits |
| Platforms, clouds, power-up props, event props | **Quaternius Ultimate Platformer Pack** | all (pay what you want) | — | https://quaternius.itch.io/ultimate-platformer-pack |
| Jungle / Beach plants with more detail | **Quaternius Stylized Nature MegaKit** | 81 models | $9.99 Pro | https://quaternius.itch.io/stylized-nature-megakit |
| Farm buildings | **Quaternius LowPoly Farm Buildings** | all | — | https://quaternius.itch.io/lowpoly-farm-buildings |
| Animal style reference, possible fill-ins (walrus, parrot, elephant, giraffe, polar bear) | **Cozy Animals 3D** (Gamideo), rigged + animated | all (CC0) | — | https://dragofive.itch.io/cozy-animals-3d |
| Animal style reference (chibi hamster, rabbit, penguin, bear), 26 animations | **Plumberry Plains Vol. 2** (ChibiPup). Commercial use OK; not CC0, no reselling raw files | all | — | https://chibipup.itch.io/plumberry-plains-vol-2-even-more-free-animal-friends-for-your-village |
| Extra rigged animals with attack/walk clips | **Gobkit Free Animal Pack** (CC0, 10 animals incl. hippo, rhino, duck, corgi) | all | — | https://gobkit.itch.io/gobkit-free-animal-pack |

Looked at and **not** recommended: PSX/PS1-style packs (wrong look), voxel packs (wrong look), Uqel's
"Animal Models Pack" ($21.99, no animations, no species list, no license stated).

---

## Phase 1 — Foundations (agent; ~2 sessions)

Before any art goes in, set the rules and the tools that keep it clean.

1. **Art bible** (`docs/ART_BIBLE.md`): the palette (taken from UIPack Plus's `Palette` gem families so the
   world and the UI match), scale rules (a door is 8 studs, a player is 5, a hamster 2.5, a tiger 7),
   the material list (SmoothPlastic + the pack atlas only; no default Roblox textures), outline/rim rules,
   and one reference screenshot per island.
2. **Import pipeline** (`tools/import/`): a Blender script that batch-imports a downloaded pack, applies the
   palette, sets the pivot to the bottom-center, and exports FBX per model with clean names; then the owner
   imports them in Studio (3D Importer → "Import as Model"). Model naming stays as today: the game finds
   them by name in `MapModels` / `PropModels`.
3. **Glitch detectors**, added to the existing `tools/layout` dump:
   floating objects (bottom more than 0.2 studs above whatever is under it), sunk objects, overlapping
   colliders, z-fighting (two coplanar faces), invisible collidable parts outside zone locks, and gaps
   between island pieces. Each prints a list with positions. **The overhaul is only done when it prints
   zero.**
4. **Performance budget check** in `tools/devices`: part count, triangle count and texture memory per zone,
   with a fail line if a zone goes over budget.
5. **Lighting setup:** `Future` lighting, one `Atmosphere`, `Bloom`, `SunRays` and a color grade per zone in
   `server/Look.luau` (it already has the hooks), so moving between islands changes the mood.
6. Turn on **StreamingEnabled** (if it isn't already) and check every system that looks up map parts copes
   with parts that aren't loaded yet on the client.

**Done when:** the art bible exists, the glitch tools run and report the current mess, and a test pack
imports end to end.

**Status (2026-10-20): done, except the owner's steps below.**
- Art bible: `docs/ART_BIBLE.md` (KayKit style, palette, scale, layers, model rules, checks).
- Glitch detectors + zone budget: `bash tools/layout/run.sh` now ends with `GLITCHES: n   OVER BUDGET: n`.
  Baseline: 128 glitches (1 floating, 5 sunk, 122 z-fighting, 0 invisible walls), Town over budget.
- Import tool: `tools/import/kaykit.py` (tested on the free Forest pack, 101 models, and City Builder Bits,
  41 models; pictures to pick from in `art/export/kaykit/*_sheet.png`). Pack textures: `Config/Atlases.luau`.
- Lighting: bloom + sun rays (`Config/Look.luau`), and each island's own color grade (`Zones`,
  `client/ZoneLook.luau`).
- StreamingEnabled: **left off on purpose.** The map is ~8k parts, and several client scripts look up plaza
  objects by name (Gruff, the chute, the machines, tutorial targets), which streaming could unload. Revisit
  after Phase 3 if client memory is over budget; those models then need `ModelStreamingMode = Persistent`.

**Owner steps for Phase 1** (Studio, about 5 minutes):
1. Lighting → Properties → **LightingStyle → Realistic**, and tick **PrioritizeLightingQuality**. Ctrl+S.
   (Newer Studio has no "Technology" property any more; these two replaced it.)
2. Upload the two pack textures and paste their ids in `src/shared/Config/Atlases.luau` (steps at the top
   of that file). The textures are in the KayKit zips; the agent can hand them over.

---

## Phase 2 — UI overhaul with UIPack Plus (agent; ~4–5 sessions)

The game has ~9,300 lines of client UI built on its own kit (`client/Ui.luau`). The plan is to swap the kit
underneath, not rewrite every screen at once.

1. **Adapter:** rebuild `Ui.luau`'s functions (buttons, panels, windows, bars, tabs, cards) on top of
   ShardUI's `Button`, `IconButton`, `Panel`, `Card`, `Bar`, `Chip`, `Badge`, `Slot`, `Toggle`, `Field`.
   Every screen that already uses `Ui.luau` changes look in one go.
2. **Animator:** start ShardUI's `Shared/Animate` runner from `init.client.luau` (clone it into
   PlayerScripts when `ReplicatedStorage.ShardUI` exists), so hover, press, bevel and auto-scale work.
   Keep a plain fallback when the pack is missing (fresh clone), so nothing errors.
3. **HUD first** (`Hud.luau`, `SideButtons.luau`): level, coins, XP bar, the side buttons, using the pack's
   `ShardHud` kit layout as the model (open `ServerStorage.ShardUIReference.Kits` in Studio to see it).
4. **Then each window**, one per session, in this order (most seen first): Inventory/Pen, Shop, Store
   (Robux), Tasks (OrdersBoard), Settings, Welcome Back, Rebirth Market, Eggs roller.
5. **The BOX screen** (`BoxingScreen.luau`) last and with the most care: it's the core of the game. Bigger
   ♥ spots with a glow, tape that looks like real tape (texture + shine), an anger meter with a face that
   changes, and the box shaking harder as anger rises.
6. **Icons:** one icon set in the pack's style for coins, XP, Rebirth Points, eggs and each machine.
7. **Phone pass:** `tools/devices/run.sh` after every window; no overlaps, nothing under the thumbstick.

**Done when:** every screen uses ShardUI pieces, `tools/devices/run.sh` reports no problems, and the full
E2E playtest (`tools/e2e/run.sh`) passes.

**Status (2026-10-20): first pass done.** The adapter is `client/ShardSkin.luau`. It paints the pack's pieces
inside the game's own frames (no layout changes), with the older look kept as a fallback when the pack is
missing (`Config.UiSkin.Shard` switches it off). Checked in Play: Shop, Robux Store, Bag, Settings (windows:
faceted frame, dark header, cream paper, red gem X), all `Ui.button`s (gem, family picked from the button's
color), `Ui.card`s (flat outlined plates), side buttons, the TASKS panel and the MENU flyout (`Ui.hudPanel`),
and the XP bar (`Ui.bar`). The pack's own animator script is not needed (nothing is built with its tags).

Second pass (2026-10-20, checked in Play): HUD stat rows on dark plates that fit their numbers (`Ui.pill`),
popups and speech bubbles on outlined cream plates (`Ui.plate`: toasts, Tutorial, Welcome Back, follow
prompt), the 2x Coins timer as a gem (`Ui.gem`), event card, boss title strip and victory card as HUD panels,
the event and ANGER bars as pack bars (the ANGER fill turns green to amber to red), the code box as the pack's
dark input well (`Ui.field`), and the BOX screen's box and flaps as cardboard plates.

Still to do in Phase 2:
- The top quest banner (a soft dark strip; fine for now) and the thin progress lines inside the TASKS panel.
- TrollBar, EggRoller, the ♥ / ✖ spots and tape on the BOX screen (drawn shapes, could use pack icons).
- Phone pass: `bash tools/devices/run.sh` (needs Studio closed).

---

## Phase 3 — World rebuild (agent builds, owner imports models; ~1–2 sessions per area)

Rebuild in the order players see things. Each area is finished (detail, lighting, glitch check, phone check)
before the next one starts.

1. **Spawn plaza and town** (first impression). Real buildings around the plaza (Post Office as the hero
   building, Gruff's counter, Shop, Supply stall, Orders board), real paving instead of flat tiles, street
   furniture, planters, banners with the logo, little ambient life (birds, bunting moving in the wind,
   fountain water). Machines get proper bases that look built into the plaza.
2. **Islands, in unlock order** (Backyard → Barn/Farm → Jungle → Ice Rink → Rooftop → Beach → Volcano):
   - Replace the stacked-part islands with **Terrain** (smooth sculpted shores, real water around them) or
     the KayKit modular terrain, so there are no seams or square edges.
   - Each island gets a **landmark** visible from the plaza (a windmill, a giant tree, an ice castle, the
     volcano), a clear path, 3 layers of detail (big shapes → medium props → small clutter like grass and
     flowers) and its own color grade and ambient sound.
   - Animal spawn areas are open and readable: no props where animals get stuck.
3. **Zone locks:** a nicer lock than a barrier (a glowing gate with the level needed and a little Gruff sign).
4. **Travel:** smooth fade or a short flying-parcel animation between islands, never a hard cut.
5. After each area: `tools/layout/run.sh` + the new glitch detectors print zero, `tools/photo/run.sh` for a
   before/after picture in `docs/overhaul/`.

**Done when:** 0 visible graybox parts, all glitch detectors at zero, every zone inside its performance
budget.

---

## Phase 4 — Animals and Gruff (owner + agent; the most work, ~2–3 weeks)

The animals are why people play and what's on the thumbnail. Today they're simple Blender shapes moved by
code (no rig).

1. **Spec sheet** per animal: silhouette, 3 signature features, face (big readable eyes with eyelids and a
   mouth that can open), poly budget (~3–6k tris), one atlas texture in the palette.
2. **Rebuild in Blender** to that spec, tier 1 first (hamster, bunny, goldfish, hedgehog, parrot), since new
   players see those. Use the Cozy Animals / Plumberry packs as the reference for how much detail "cute but
   detailed" means. Where a pack animal fits our roster and the style, it can be used directly (recolored).
3. **Rig and animate** each one: idle, walk, run, panic (being chased), grabbed (wriggling), in-box
   (angry/happy versions), launch (vine boom). Replace the code-driven hops in `client/Animate.luau` with
   real animations, keeping the code layer only for extras (squash on pet, shake by anger).
4. **Faces:** swap face decals or a face-shape key so animals look happy when petted and furious near
   anger 100.
5. **Shiny / Golden variants:** proper materials (sparkle texture, gold with a shine), plus a particle aura,
   not just a recolor.
6. **Gruff:** fully rigged walrus with talking, pointing, angry and laughing animations, and a mouth that
   moves while his dialogue types out. He's the mascot: he should look as good as the thumbnail art.
7. **Boxes:** the four boxes get tape, labels, stamps and a dent animation when the animal kicks.

**Done when:** all 25 animals + Gruff are rigged, animated, and pass the glitch tools (no feet through the
floor, no clipping out of the box).

---

## Phase 5 — Juice, sound and music (agent; ~2 sessions)

1. **Sounds:** replace every stand-in in `docs/SOUNDS_TO_REPLACE.md` (each one by ear, in Studio).
2. **Music:** one loop per zone plus a BOX-stage track and a boss track, cross-fading between zones.
3. **Effects checklist** (quality bar line 5): go through every action and add what's missing: grab
   (dust puff + animal yelp), tape (tape-stretch sound + shine sweep), pet (hearts), stamp (ink splat +
   camera thud), mail (whoosh + parcel flies down the chute), level up (full-screen burst + fanfare), egg
   hatch, rebirth, vine boom (screen shake + slow-mo).
4. **Camera:** gentle zoom-in on the BOX stage, a short cinematic when a new island unlocks.

**Done when:** every row in the effects checklist has animation + sound + effect, checked in Play.

---

## Phase 6 — Performance and glitch sweep (agent; ~1–2 sessions)

1. Run all checks: `tools/devices`, `tools/layout` + glitch detectors, `tools/e2e`, `tools/smoke`, unit tests.
2. MicroProfiler in a 12-player test server: fix anything over budget (merge meshes, lower collision
   fidelity on decorations to Box, turn `CanCollide`/`CanTouch`/`CanQuery` off on decoration, `CastShadow`
   off on small clutter).
3. A **10-minute play-through on a real phone** by the owner, writing down anything that looks wrong.

**Done when:** every check passes and the owner's phone list is empty.

---

## Phase 7 — Relaunch (owner, with step lists from the agent)

1. New thumbnails, icon and a 30-second trailer shot in the new world (`PromoKit`, F7/F8 in Studio).
2. Update the store page text and "New this week" (`Config/News.luau`).
3. Publish, then watch Analytics → retention and the onboarding funnel for a week against the numbers
   from before the overhaul.
4. Ads / promo posts (`docs/AD_PLAN.md`, `docs/PROMO_POSTS.md`) only after the first week's numbers look
   better.

---

## Order and rough size

| Phase | Who | Size |
|---|---|---|
| 0 Decide | Owner | 1 evening |
| 1 Foundations | Agent | ~2 sessions |
| 2 UI | Agent | ~4–5 sessions |
| 3 World | Agent + owner imports | ~10 sessions |
| 4 Animals + Gruff | Owner/agent in Blender | the biggest: weeks |
| 5 Juice + audio | Agent + owner's ears | ~2 sessions |
| 6 Sweep | Agent + owner's phone | ~2 sessions |
| 7 Relaunch | Owner | 1 week of watching |

Phases 2 and 3 can run at the same time (UI files and map files don't overlap). Phase 4 can start any time
after Phase 1; it's long, so start the tier 1 animals early.
