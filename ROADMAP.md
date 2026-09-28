# Mail a Tiger — Roadmap

## Pitch
Box up increasingly wild animals and get them to the Post Office without the box breaking — or the animal breaking out. Deliver, earn, upgrade, mail something bigger.

## Core Loop
1. **Get an animal** — pick from the Animal Pen (starts with a hamster, ends with a tiger… and beyond).
2. **Box it** — choose a box (cardboard → wood → steel → vault). Tougher boxes = more HP, heavier = slower.
3. **Carry it** — walk the route on foot to the Post Office. Bumps, falls, and hazards damage the box. The animal gets angrier over time.
4. **Deliver** — payout based on animal rarity, box condition, and speed.
5. **Upgrade** — better boxes, stamps (modifiers), carry perks, new routes, rarer animals.

### Key tension meters
- **Box HP** — drops on impact. 0 = box breaks, animal escapes.
- **Rage meter** — fills over time and when jostled. High rage = animal rattles the box (extra damage, screen shake). Calm it with treats/toys.
- **Escape** — if the box breaks, the animal runs loose; you catch it again for a reduced payout (or lose it).

---

## The Boss: Postmaster Gruff
A huge, grumpy walrus with a mustache, a tiny postal cap, and a rubber stamp he slams on everything.
- **Tutorial:** he's the one who teaches you, reluctantly. His first line: "You. New hire. Box the hamster. Don't mess it up."
- **Orders board:** he gives delivery orders ("Two skunks to Route 2, no damage") for bonus pay.
- **Delivery rating:** every delivery gets 1–5 stamps from Gruff, with a grumpy line for each score. A 5-stamp gets a rare "...Acceptable."
- **Running gag:** things keep happening to his hat.
- **Final delivery:** the last late-game order is mailing Gruff himself on vacation. It's a co-op carry, and he complains the whole way.

## Animal Roster (v1)
| Tier | Zone | Animals | Special behavior |
|---|---|---|---|
| 1 | Backyard | Hamster, Bunny, Goldfish, Hedgehog, Parrot | Goldfish bowl sloshes when you turn fast. Hedgehog pokes the box a little. Parrot squawks your location on sabotage routes |
| 2 | Farm | Chicken, Goat, Pig, Skunk | Chicken lays bonus eggs if calm. Goat headbutts the box forward. Skunk sprays and blurs the screen |
| 3 | Wild | Monkey, Kangaroo, Porcupine, Penguin, Octopus | Monkey steals a stamp. Kangaroo makes the box hop. Porcupine damages from inside. Penguin slides on slopes. Octopus squeezes out of any crack |
| 4 | Apex | Crocodile, Gorilla, Bear, **Tiger** | Croc snaps and the box lunges. Gorilla pounds the box. Bear falls asleep and gets heavy. Tiger roars and stuns nearby players |
| 5 | Giants (co-op) | Giraffe, Elephant, Whale | Giraffe box is too tall, so you duck under signs. Elephant needs 2 players. Whale needs 4 and a water tank |
| 6 | Silly | Yeti, Dragon, Alien, Unicorn, **Postmaster Gruff** | Yeti freezes the path. Dragon burns cardboard instantly. Alien floats the box up. Unicorn leaves a rainbow trail that speeds up other players |

## Signature Clip Moment: "Doorstep Breakout"
Animals hate the Post Office door bell. On the last few steps to the counter, the bell rings and every animal's rage spikes.
- For most animals this is just a tense final stretch.
- A **tiger at high rage** can burst out right on the doorstep: the camera slows down, the tiger roars, Gruff's hat flies off, and a big **RETURN TO SENDER** stamp slams across the screen. The tiger then runs through the lobby knocking over mail piles.
- If you get the tiger through the door anyway, you get a big "DELIVERED" slam and Gruff's rare "...Acceptable."
- **Why it's clippable:** the fail happens at the very end, it's loud and visual, and it's funny whether you win or lose. Make it look great early, because it's the thumbnail and trailer shot.

---

## Phase 0 — Project Setup
- [x] Install Rokit, Rojo 7.7, Selene and StyLua (pinned in `rokit.toml`), plus VS Code with its extensions and the Rojo Studio plugin
- [x] Beginner crash course written: [docs/LEARN.md](docs/LEARN.md)
- [x] Place file (`MailATiger.rbxl`) and folder structure (`ReplicatedStorage/Shared`, `ServerScriptService/Server`, `StarterPlayerScripts/Client`)
- [x] Config modules for data-driven content (`Animals`, `Boxes`, `Stamps`, `Routes`)
- [x] Git repo in this folder
- [ ] **You:** open the place in Studio, connect Rojo, press Play, and see both startup lines in Output (see LEARN.md §7)

## Phase 1 — Graybox Prototype (prove it's fun)
Goal: one animal, one box, one route, one post office. Is carrying a fragile box fun for 5 minutes?
- [ ] Pick up / carry a box (held in front of character, affects walk speed)
- [ ] Box HP + impact damage (fall height, collision velocity)
- [ ] Delivery zone at Post Office → coin payout
- [ ] Rage meter + box rattle
- [ ] Box break → animal escapes → re-catch
- [ ] Basic HUD: coins, box HP bar, rage bar
- **Playtest checkpoint** before moving on

## Phase 2 — Animal System
- [ ] Animal config: rarity, base value, weight, rage rate, special behavior
- [ ] Starter roster (~10–15 animals across tiers) *(see Open Questions)*
- [ ] Special behaviors (examples):
  - Hamster — calm, cheap
  - Skunk — sprays when angry, blurs screen
  - Kangaroo — box hops on its own
  - Porcupine — damages box from inside
  - Octopus — squeezes out of any gap
  - Tiger — high rage, roars stun nearby players
- [ ] Animal models/animations (placeholder → final)

## Phase 3 — Progression & Economy
- [ ] Box tiers (HP, weight, cost)
- [ ] Stamps: consumable/equippable modifiers (e.g. *Fragile* = +payout, *Express* = speed bonus, *Bubble Wrap* = −damage)
- [ ] On-foot carry upgrades (no vehicles): grip strength, sprint stamina, balance, "steady hands" perk that reduces jostle
- [ ] Rebirth system (reset for permanent multiplier)
- [ ] DataStore saving (coins, unlocks, inventory) with session locking
- [ ] Economy tuning spreadsheet (time-to-unlock per tier)

## Phase 4 — World & Routes
- [ ] Hub town: Animal Pen, Box Shop, Post Office
- [ ] Route 1 (easy): town streets, potholes, curbs
- [ ] Route 2: construction site — moving beams, drops
- [ ] Route 3: jungle/zoo — other loose animals, rivers
- [ ] Later routes: mountain pass, city rush hour, volcano…
- [ ] Route unlock gates tied to progression

## Phase 5 — Multiplayer / Social
- [ ] Co-op carry for giant animals (elephant, whale) — 2+ players needed
- [ ] Opt-in **Sabotage Routes**: higher payout, but players can bump each other and drop traps (banana peels, puddles, loud horns that spike rage). Normal routes stay PvP-free.
- [ ] Global leaderboards (deliveries, rarest delivery, fastest route)
- [ ] Trading? *(probably later / maybe never — adds scam/moderation load)*

## Art Track (runs in parallel from Phase 2 on)
- [ ] Blender → Roblox pipeline test: export one low-poly box + hamster as FBX, import with the 3D Importer, and check scale and pivot
- [ ] Style guide: palette, poly budget per animal (~500–2k tris), flat or gradient-texture shading
- [ ] Rigging + animations per animal: idle, angry rattle, escape run, caught
- [ ] Box set: cardboard, wood, steel, vault, plus damage states (dented, cracked)
- [ ] Hub buildings: Post Office, Animal Pen, Box Shop
- [ ] Priority: finish the Tier 1 animals first. Everything else stays as placeholders until launch-critical.

## Phase 6 — Juice, UI & Audio
- [ ] Final UI kit (shop, inventory, delivery receipt screen)
- [ ] Box shake/creak SFX, animal sounds, delivery "stamp" jingle
- [ ] Camera shake, particle hits, damage decals on boxes
- [ ] Tutorial / first-time user experience (first 60 seconds matter most)

## Phase 7 — Monetization
- [ ] Game passes: 2x coins, VIP box skin, extra pet slot, auto-calm treat
- [ ] Dev products: coin packs, instant box repair, skip-the-unlock for the next animal (no random crates)
- [ ] Premium payouts compliance / no pay-to-win in PvP
- [ ] Private servers

## Phase 8 — Launch Prep
- [ ] Icon + thumbnails + trailer clip
- [ ] Analytics events (funnel: join → first delivery → first upgrade → rebirth)
- [ ] Soft launch → fix retention drop-offs → sponsored ads
- [ ] Moderation/report basics, anti-exploit checks (server-authoritative coins & damage)

## Phase 9 — Live Ops
- [ ] Weekly limited animal
- [ ] Seasonal events (Holiday Rush: mail reindeer)
- [ ] New route every major update

---

## Open Questions
Answer these to lock direction. Answers get recorded under **Decisions** below.

_None right now. New questions get added here as they come up, always as a multiple-choice list._

## Decisions
- **Workflow:** Rojo + VS Code + Git. Code lives in this folder, and Studio is used for building and playtesting.
- **Carrying:** on foot only. There are no vehicles, and progression comes from boxes, stamps and carry perks.
- **PvP:** opt-in sabotage routes that pay more. Everywhere else is PvP-free, with co-op carrying for giant animals.
- **Experience:** beginner. Keep the architecture simple, and explain each system as it's built.
- **Art:** low-poly cartoon, modeled and animated by you in Blender. Graybox with Parts first, and swap in models as they're ready.
- **Audience:** all ages. Easy to pick up, with depth at high tiers and on sabotage routes.
- **Carry feel:** wobbly physics. The box sways, and turning fast, jumping or bumping into things causes damage. Aim for "funny when you fail," like Carry a Friend.
- **Progression:** simulator-style. Numbers go up, with lots of unlocks and rebirths.
- **Vibe:** chaotic comedy. Loud sound effects, ragdolls, and failing is entertaining.
- **Getting animals:** buy them with coins at the Animal Pen once they're unlocked. No random crates, so no odds disclosure is needed.
- **Boss:** Postmaster Gruff, a grumpy walrus. He runs the tutorial and the orders board, rates deliveries, and is the final delivery.
- **Signature moment:** "Doorstep Breakout", where the Post Office bell spikes rage on the last few steps.
- **Roster:** real animals through the mid-game (hamster → tiger), then silly ones at late tiers (dragon, alien, a mailman).
