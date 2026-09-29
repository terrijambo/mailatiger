# Mail a Tiger — Roadmap

## Pitch
Catch increasingly wild animals, wrestle them into a box, tape it shut before they burst out, and mail them. Earn, upgrade, mail something bigger.

## Core Loop
1. **Pick an animal** at the Animal Pen (starts with a hamster, ends with a tiger… and beyond).
2. **CATCH:** it's released into the catching arena. Corner it, then hold E to grab it. Faster animals juke past you, and many have tricks.
3. **STUFF:** a marker bounces across a bar. Press when it's in the green zone to stuff the animal into the box. Wild animals need several hits, and the zone shrinks and wiggles.
4. **TAPE:** the animal pushes the lid up. Mash to shove it down and fill the tape bar before the lid bursts. It pushes harder the longer it takes.
5. **MAIL:** the box flies into the mail chute, and Gruff rates the job from 1 to 5 stamps and pays coins.
6. **Upgrade:** better boxes, tools and stamps, then rarer animals.

Fail STUFF (too many misses) or TAPE (the lid bursts) and the animal escapes back into the arena. Each escape costs a stamp and halves the pay.

### What makes it hard (all scales with the animal's tier)
- **Catch:** animal speed (tier 6 outruns you), how often it jukes when cornered, how long you must hold E, and how well it avoids walls.
- **Stuff:** marker speed, zone size, and hits needed (1 → 3).
- **Tape:** push strength, presses needed, and twists like Pound, Snap and Squeeze.

---

## The Boss: Postmaster Gruff
A huge, grumpy walrus with a mustache, a tiny postal cap, and a rubber stamp he slams on everything.
- **Tutorial:** he's the one who teaches you, reluctantly. His first line: "You. New hire. Pick an animal at the Pen, catch it, box it, tape it. Don't mess it up."
- **Orders board (Phase 3):** he gives orders ("Two skunks, no escapes") for bonus pay.
- **Rating:** every job gets 1–5 stamps from Gruff, with a grumpy line for each score. A 5-stamp gets a rare "...Acceptable."
- **Running gag:** things keep happening to his hat.
- **Final job:** the last late-game order is boxing Gruff himself for his vacation. It's co-op, and he complains the whole way.

## Animal Roster and Twists
Twists are set per animal in `Config/Boxing.luau → Twists`.

| Tier | Zone | Animals and their tricks |
|---|---|---|
| 1 | Backyard | Hamster (none) · Bunny (hops) · Goldfish (slippery, wiggly zone) · Hedgehog (poke: some tape presses go "ouch") · Parrot (flies out of reach) |
| 2 | Farm | Chicken (drops eggs worth bonus coins) · Goat (charges you, pounds the lid) · Pig (slippery) · Skunk (sprays: green, blurry screen) |
| 3 | Wild | Monkey (flies/climbs, wiggly zone) · Kangaroo (hops, pounds) · Porcupine (poke) · Penguin (slippery) · Octopus (turns invisible, wiggly zone, tape peels) |
| 4 | Apex | Crocodile (charges, lid snaps) · Gorilla (charges, pounds) · Bear (asleep: sneak up with C or it wakes and bolts) · **Tiger** (roar stuns you, snaps, **Breakout**) |
| 5 | Giants | Giraffe (wiggly zone) · Elephant and Whale (co-op, Phase 5) |
| 6 | Silly | Yeti (freezes you) · Dragon (flies, roars, tape burns off) · Alien (teleports, wiggly zone) · Unicorn (teleports, hops) · **Postmaster Gruff** (co-op, roars, pounds, Breakout) |

## Signature Clip Moment: "RETURN TO SENDER"
The tiger fights the tape. The lid creeps up, you're mashing, and the tape is almost full...
- If the lid bursts, the tiger explodes out of the box, Gruff's hat flies off, and a giant red **RETURN TO SENDER** stamp slams onto everyone's screen nearby. The tiger is loose in the arena again.
- If you finish taping, the box sails into the mail chute and Gruff gives you his rare "...Acceptable."
- **Why it's clippable:** the fail happens at the last second, it's loud and visual, and it's funny whether you win or lose. It's the thumbnail and trailer shot.

---

## Phase 0 — Project Setup ✅
- [x] Install Rokit, Rojo 7.7, Selene, StyLua and luau-lsp (pinned in `rokit.toml`), plus VS Code with its extensions and the Rojo Studio plugin
- [x] Beginner crash course written: [docs/LEARN.md](docs/LEARN.md)
- [x] Place file, folder structure, config modules, Git repo
- [x] Studio playtest verified: Rojo connects, and both startup lines print in Output

## Phase 1 — Boxing Prototype (prove it's fun)
Goal: is catching, stuffing and taping one animal fun for 5 minutes? *(The original "carry it down an obstacle course" design was replaced by this on 2026-09-29.)*
- [x] Graybox map (`src/server/MapBuilder.luau`): spawn, Animal Pen counter, fenced catching arena with a gate, and the Post Office with Gruff, his hat and the mail chute
- [x] **CATCH** (`src/server/CatchAI.luau`): the animal wanders, flees, avoids walls (smarter at higher tiers), and jukes past you when cornered. Hold E to grab
- [x] **STUFF** (`BoxingService` + `src/shared/StuffMath.luau`): a bouncing marker and green zone, judged by the server using the synced server clock with lag allowance
- [x] **TAPE**: lid vs tape meters, mash to win. There's an auto-clicker limit (14 presses/sec), and push grows over time
- [x] Escapes: fail Stuff or burst the lid and the animal runs back into the arena
- [x] **MAIL**: the box flies into the chute, then a 1–5 stamp rating and payout
- [x] UI: coins, tip banner, minigame panels, a big tap button for mobile, Gruff popups and receipts
- [x] "Use the Pen twice within 5s" gives up on the current animal
- [ ] **Playtest checkpoint** (checklist in README)

## Phase 2 — Animal System
- [x] Animal config: tier (also sets difficulty), price, value, carriers, placeholder color (`Config/Animals.luau`)
- [x] Animal Pen menu: pick any animal, pay its price once to unlock it (free in Studio for testing, via `Config.Dev`)
- [x] 17 twists across the three stages (see the roster table), tuned in `Config/Boxing.luau → TwistTuning`
- [x] **RETURN TO SENDER** breakout for the tiger and Gruff
- [x] Placeholder visuals: colored balls with name labels, plus a **model hook**. Put a Model named after the animal's Id (e.g. `Tiger`) in `ReplicatedStorage > AnimalModels`, and the arena animal uses it automatically
- [ ] Final models/animations: this is the Art Track (your Blender work)
- [ ] **Playtest checkpoint** (checklist in README)

## Phase 3 — Progression & Economy
- [ ] Box tiers (cardboard → wood → steel → vault): the lid starts lower and gets pushed up more slowly
- [ ] Tools: grabbing gloves (shorter hold), sneakers (run faster in the arena), tape gun (more tape per press), net (longer grab range)
- [ ] Stamps, reworked for boxing: *Fragile* (+50% pay, but only 1 stuff miss allowed), *Express* (+pay if under par), *Priority* (double pay, and the lid starts at 50)
- [ ] Gruff's orders board
- [ ] Rebirth system (reset for a permanent multiplier)
- [ ] DataStore saving (coins, unlocks, inventory) with session locking
- [ ] Economy tuning spreadsheet (time-to-unlock per tier)

## Phase 4 — World & Arenas
- [ ] Hub town: Animal Pen, Tool Shop, Post Office
- [ ] Themed arenas that unlock by tier: Backyard (open lawn), Barn (hay-bale cover), Jungle (trees, water), Ice Rink (you slide), Rooftop (edges!)
- [ ] Arena obstacles the animal AI steers around

## Phase 5 — Multiplayer / Social
- [ ] Co-op giants (Elephant, Whale, Gruff): herd together to catch, then one player holds the lid while the other tapes
- [ ] Opt-in **Chaos Arena**: higher payout, but other players can spook your animal and bump you. The normal arena stays PvP-free
- [ ] Global leaderboards (fastest tiger, most 5-stamp jobs, rarest animal mailed)

## Art Track (runs in parallel from Phase 2 on)
- [ ] Blender → Roblox pipeline test: export one low-poly box + hamster as FBX, import with the 3D Importer, and check scale and pivot
- [ ] Style guide: palette, poly budget per animal (~500–2k tris), flat or gradient-texture shading
- [ ] Rigging + animations per animal: idle, run, caught (dangling), struggling in the box, bursting out
- [ ] Box set: cardboard, wood, steel, vault, plus a lid and tape strips
- [ ] Hub buildings: Post Office, Animal Pen, Tool Shop
- [ ] Priority: finish the Tier 1 animals first. Everything else stays as placeholders until launch-critical.

## Phase 6 — Juice, UI & Audio
- [ ] Final UI kit (Pen menu, shop, receipt screen)
- [ ] SFX: tape screech, lid thumps, animal sounds, Gruff's stamp slam
- [ ] Camera punch-ins during Tape, particles, box wobble while stuffing
- [ ] Tutorial / first-time user experience (first 60 seconds matter most)

## Phase 7 — Monetization
- [ ] Game passes: 2x coins, VIP box skins, golden tape gun
- [ ] Dev products: coin packs, skip-the-unlock for the next animal (no random crates)
- [ ] No pay-to-win in the Chaos Arena
- [ ] Private servers

## Phase 8 — Launch Prep
- [ ] Icon + thumbnails + trailer clip (RETURN TO SENDER!)
- [ ] Analytics events (funnel: join → first catch → first mail → first unlock → rebirth)
- [ ] Soft launch → fix retention drop-offs → sponsored ads
- [ ] Anti-exploit review: the server already judges every press. Tighten the Stuff lag allowance if needed

## Phase 9 — Live Ops
- [ ] Weekly limited animal
- [ ] Seasonal events (Holiday Rush: box reindeer)
- [ ] New arena every major update

---

## Open Questions
Answer these to lock direction. Answers get recorded under **Decisions** below.

_None right now. New questions get added here as they come up, always as a multiple-choice list._

## Decisions
- **Workflow:** Rojo + VS Code + Git. Code lives in this folder, and Studio is used for building and playtesting.
- **Core mechanic (2026-09-29):** boxing is the challenge, with three stages: Catch → Stuff → Tape. There's **no carrying and no obstacle course**, and the box is mailed right away.
- **Difficulty:** scales with the animal's tier, plus per-animal twists. Hard animals should be genuinely hard.
- **PvP:** opt-in Chaos Arena that pays more. Everywhere else is PvP-free, with co-op for giant animals.
- **Experience:** beginner. Keep the architecture simple, and explain each system as it's built.
- **Art:** low-poly cartoon, modeled and animated by you in Blender. Graybox with Parts first, and swap in models as they're ready.
- **Audience:** all ages. Easy to pick up, with depth at high tiers.
- **Progression:** simulator-style. Numbers go up, with lots of unlocks and rebirths.
- **Vibe:** chaotic comedy. Loud sound effects, and failing is entertaining.
- **Getting animals:** buy them with coins at the Animal Pen once they're unlocked. No random crates, so no odds disclosure is needed.
- **Boss:** Postmaster Gruff, a grumpy walrus. He runs the tutorial and the orders board, rates jobs, and is the final job.
- **Signature moment:** "RETURN TO SENDER", where the tiger bursts the lid during Tape.
- **Roster:** real animals through the mid-game (hamster → tiger), then silly ones at late tiers (dragon, alien, a mailman).
