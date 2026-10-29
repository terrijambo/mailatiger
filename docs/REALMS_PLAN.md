# Realms: one map per animal tier (plan for the owner to approve)

Decided 2026-10-29: the game becomes **6 realms**, one per animal tier, each its own map. You start in the
first realm; when you've grown enough there, you **buy the next realm with coins** and move in. Moving
realms is a big reset, separate from rebirthing (which stays the smaller reset inside a realm). This plan
replaces Phase 3's "plaza + 7 islands" layout (docs/OVERHAUL_PLAN.md). Nothing here is built yet.

---

## 1. The 6 realms

Every realm has the same three parts, so the game feels the same everywhere and only the world changes:

- **The hub:** Gruff's branch Post Office with his counter, the mail chute, the 7 machines, the orders board,
  the egg stand, a Rebirth Market stall, and the **Realm Gate** to the next realm.
- **The catching grounds:** 2–3 habitats around the hub where that tier's animals live.
- **A landmark** you can see from the hub (built in Blender, like the fountain).

Each of today's arena twists (hay, mud, ice, edges) moves into a realm, so none of that gameplay is lost.

| # | Realm | Animals | The look | Twist | Landmark |
|---|---|---|---|---|---|
| 1 | **Backyard** | Hamster, Bunny, Goldfish, Hedgehog, Parrot | Garden houses with picket fences, a lily pond, a vegetable patch, a treehouse | None: the gentle start | The treehouse |
| 2 | **Sunny Farm** | Chicken, Goat, Pig, Skunk | Your concept picture: Gruff's cottage, chicken coop, flower field, pumpkin patch, windmill orchard | Hay bales the animals duck around (today's Barn) | The windmill |
| 3 | **Wild Cove** | Monkey, Kangaroo, Raccoon, Penguin, Octopus | Jungle cliffs, a campsite in the woods, a rocky cove with tide pools | Mud that slows you (today's Jungle) | A waterfall into the cove |
| 4 | **Temple Jungle** | Crocodile, Gorilla, Bear, Tiger | A jungle river with temple ruins and rope bridges | The river current pushes you downstream | The tiger temple |
| 5 | **Giant Savanna** | Giraffe, Elephant, Whale | Open grassland, acacia trees, a watering hole, a bay with a pier | Wide open space for the big co-op animals | A huge baobab tree |
| 6 | **Wonder Peaks** | Yeti, Dragon, Alien, Unicorn, Gruff | Snowy peaks, a little volcano, a crashed UFO, a rainbow meadow on floating rocks | Ice (today's Ice Rink) and edges you can fall off (today's Rooftop) | The rainbow bridge |

**Shared by all realms:**
- The **hourly boss arena** (the Mega Tiger, Yeti and Dragon) stays one place. Its portal opens in every
  hub when a boss fight starts.
- **Rebirth Beach goes away:** its Rebirth Market becomes a stall in every hub.

---

## 2. Rebirth vs moving realms

| | **Rebirth** (unchanged, inside a realm) | **Realm move** (new) |
|---|---|---|
| How often | Every 20–60 minutes | A few times in the whole game (5 moves in total) |
| Needs | A chute level + coins (as today) | Chute level 25 in this realm, 2 rebirths in this realm, and coins (about 60 minutes of chute income) |
| Resets | Coins, machines, chute level | Coins, machines, chute level **and your rebirths** (so rebirths are cheap again in the new realm) |
| Keeps | Everything else | Rebirth Points, Rebirth Upgrades, tools, your collection (every animal you've mailed), badges, codes, game passes |
| Gives | x1.5 chute income per rebirth, Rebirth Points | The new realm's animals (the best animal in each tier pays 6–8x the best in the one before), a new world, and **x2 Rebirth Points forever** for each realm you've reached |

Why it works: rebirth is the quick loop and the realm move is the big goal above it. Losing your rebirth
bonus hurts for a moment, but the new realm's animals pay so much more that you're soon ahead.

**Pacing targets** (tuned in playtests):
- Realm 1 → 2: 45–60 minutes, so new players unlock a realm in their first session.
- Each realm after that: 3–5 hours.
- Realm 6: endless (rebirths and collecting).

**Going back:** you can visit any realm you've unlocked from a **Realm Map** window (a side button), to
catch older animals for your collection, side orders and quests. You still earn from your home realm.

---

## 3. Players who already play

The game has been live since 2026-10-06. Nobody should lose progress on the switch:

- Each player's **home realm** becomes the highest one their level had opened in the old layout. Level 1 is
  Backyard, level 4 Farm, level 8 Cove, level 12 Temple Jungle, and level 18 Wonder Peaks. Today the Ice Rink
  holds both tier 4 and tier 5, so a level-12 player goes to Temple Jungle and buys the Savanna as normal.
- They keep their level, coins, machines and rebirths as they are. Every realm below their home realm is
  open to visit.
- A one-time "Gruff's moving day" gift: coins worth 10 minutes of chute income.
- The save keeps its name, so no wipe.

---

## 4. How it gets built

**Systems first, on placeholder maps** (about 3–4 sessions), so the loop can be played before the art exists:
1. `Config/Realms.luau`: the 6 realms (animals, level and rebirths needed, price, look, where each sits).
2. `RealmService`: buying the next realm, the reset rules in section 2, saving the home realm and unlocked
   realms, the x2 Rebirth Points, and the move-in for existing players (with tests).
3. The Realm Gate (a big arch showing what's still needed and the price) and the Realm Map window, using
   the fade that travel already uses.
4. Wild animals, eggs, side orders and quests draw from the realm you're in.
5. **One place, realms far apart, with StreamingEnabled on**, so each player only loads the realm they're
   in. Streaming was left off because some client scripts expect the whole map to be loaded; those get
   fixed here. This is the biggest technical risk, so it comes first.
   (Rejected: a separate Roblox place per realm. Friends would end up on different servers, and every
   update would mean publishing 6 places.)

**Then the maps, one realm at a time** (about 3–4 nights each; these can run while you sleep):
- The ground as Roblox Terrain (smooth shores and real water, no block edges). KayKit for buildings, trees
  and props; Blender for the landmark and hero props; Studio's generator for the odd prop.
- Each realm passes the glitch tool at 0, stays inside the part budget (2,500 visible parts, 30 lights), and
  passes the phone-size check before the next one starts.
- Order: **Backyard** (the first impression) → **Sunny Farm** (your concept picture) → Cove → Temple Jungle
  → Savanna → Wonder Peaks. Then the old town and islands are removed and the boss arena is connected to
  the hubs.

**Total:** about 4 sessions of systems plus about 20–24 nights of map building.

---

## 5. Questions for you

1. **Rebirth bonus on a realm move:** the plan resets your rebirths (and their x1.5 income) when you move.
   OK, or should rebirths carry over? (Recommended: reset. Otherwise realm 6 becomes far too fast.)
2. **Going back to old realms:** visiting only, as above? (Recommended: yes.)
3. **The 6 themes** in section 1: anything to swap?
4. **KayKit Complete ($150, optional):** adds the village, windmill, snow and holiday pieces. It would make
   the Farm and Wonder Peaks faster and richer to build. Without it, those pieces get built in Blender
   instead, which is slower but free.
