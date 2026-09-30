# Mail a Tiger — Roadmap

## Pitch
Catch increasingly wild animals, pet them calm while you tape them into a box, and mail them. If they get too angry: VINE BOOM, you're launched into the sky. Earn, upgrade, mail something bigger.

## Core Loop
1. **Pick an animal** at the Animal Pen (starts with a hamster, ends with a tiger… and beyond). You're teleported to its arena.
2. **CATCH:** corner it in the arena, then hold E to grab it. Faster animals juke past you, and many have tricks.
3. **BOX:** the animal and an open box pop up on your screen, and its **ANGER** keeps rising. **Rub its ♥ sweet spots** to calm it (never the ✖ angry spots!) while you **drag tape across each seam** of the box. Every strip of tape makes it angrier, so you have to keep going back to petting.
4. **Anger hits 100:** *VINE BOOM*. You're launched into the air as a ragdoll, and the animal escapes back into the arena.
5. **All seams taped:** the box flies into the mail chute, and Gruff rates the job from 1 to 5 stamps and pays coins.
6. **Upgrade:** better boxes, tools and stamps, then rarer animals.

Each escape costs a stamp and halves the pay.

### What makes it hard (all scales with the animal's tier)
- **Catch:** animal speed (tier 6 outruns you), how often it jukes when cornered, how long you must hold E, and how well it avoids walls.
- **Box:** how fast anger rises (and keeps speeding up), seams to tape (2 → 5), smaller and drifting sweet spots, more angry spots, and twists like Pound, Snap, Squeeze, Wiggle and Poke.

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
| 1 | Backyard | Hamster (none) · Bunny (hops) · Goldfish (slippery, drifting spots) · Hedgehog (poke: big angry spots) · Parrot (flies out of reach) |
| 2 | Farm | Chicken (drops eggs worth bonus coins) · Goat (charges you, anger spikes) · Pig (slippery) · Skunk (sprays: green, blurry screen) |
| 3 | Wild | Monkey (flies/climbs, drifting spots) · Kangaroo (hops, anger spikes) · Porcupine (poke) · Penguin (slippery) · Octopus (turns invisible, drifting spots, peels tape off) |
| 4 | Apex | Crocodile (charges, anger jolts) · Gorilla (charges, anger spikes) · Bear (asleep: sneak up with C or it wakes and bolts) · **Tiger** (roar stuns you, anger jolts, **Breakout**) |
| 5 | Giants | Giraffe (drifting spots) · Elephant and Whale (co-op, Phase 5) |
| 6 | Silly | Yeti (freezes you) · Dragon (flies, roars, peels tape off) · Alien (teleports, drifting spots) · Unicorn (teleports, hops) · **Postmaster Gruff** (co-op, roars, anger spikes, Breakout) |

## Signature Clip Moment: "VINE BOOM → RETURN TO SENDER"
You're one strip of tape away. The tiger's anger is at 95, and you go for the last seam...
- *VINE BOOM.* You're launched into the sky as a flailing ragdoll. For the tiger (and Gruff), Gruff's hat also flies off and a giant red **RETURN TO SENDER** stamp slams onto everyone's screen nearby. The tiger is loose in the arena again.
- Pet it back down, tape the last seam, and the box sails into the mail chute. Gruff gives you his rare "...Acceptable."
- **Why it's clippable:** the fail happens at the last second, it's loud and visual (a ragdoll flying off a rooftop!), and it's funny whether you win or lose. It's the thumbnail and trailer shot.

---

## Phase 0 — Project Setup ✅
- [x] Install Rokit, Rojo 7.7, Selene, StyLua and luau-lsp (pinned in `rokit.toml`), plus VS Code with its extensions and the Rojo Studio plugin
- [x] Beginner crash course written: [docs/LEARN.md](docs/LEARN.md)
- [x] Place file, folder structure, config modules, Git repo
- [x] Studio playtest verified: Rojo connects, and both startup lines print in Output

## Phase 1 — Boxing Prototype (prove it's fun) ✅
Goal: is catching, stuffing and taping one animal fun for 5 minutes? *(The original "carry it down an obstacle course" design was replaced by this on 2026-09-29.)*
- [x] Graybox map (`src/server/MapBuilder.luau`): spawn, Animal Pen counter, fenced catching arena with a gate, and the Post Office with Gruff, his hat and the mail chute
- [x] **CATCH** (`src/server/CatchAI.luau`): the animal wanders, flees, avoids walls (smarter at higher tiers), and jukes past you when cornered. Hold E to grab
- [x] **STUFF** (`BoxingService` + `src/shared/StuffMath.luau`): a bouncing marker and green zone, judged by the server using the synced server clock with lag allowance
- [x] **TAPE**: lid vs tape meters, mash to win. There's an auto-clicker limit (14 presses/sec), and push grows over time
- [x] Escapes: fail Stuff or burst the lid and the animal runs back into the arena
- [x] **MAIL**: the box flies into the chute, then a 1–5 stamp rating and payout
- [x] UI: coins, tip banner, minigame panels, a big tap button for mobile, Gruff popups and receipts
- [x] "Use the Pen twice within 5s" gives up on the current animal
- [x] **Playtest checkpoint:** passed in Studio on 2026-09-29 ("works and feels good")
- *Stuff and Tape were replaced on 2026-09-29 by the **Pet & Tape BOX stage**, see "Box Rework" below.*

## Box Rework — Pet & Tape (2026-09-29) ✅
One combined BOX stage replaces Stuff and Tape. You pet the animal to keep it calm while you tape the box, and if you fail you get launched.
- [x] BOX screen (`client/BoxingScreen.luau`): the animal on the left with drifting ♥ sweet spots and ✖ angry spots, the box on the right with dashed seams, and an ANGER meter on top. Floating hearts show while you rub
- [x] Rub detection needs actual rubbing (movement), not just holding. The server caps calming at 30/sec no matter how many messages arrive
- [x] Tape strokes (`shared/BoxMath.luau`): drag from one end dot to the other, staying on the line. The server allows at most one strip per 0.35s
- [x] Anger rises with time (tier-scaled, speeds up the longer it takes), jumps with every strip, and jumps when you touch an angry spot
- [x] Anger 100: **VINE BOOM** (server-played so everyone nearby hears it, sound id in `Config/Sounds.luau`), then a **ragdoll launch** (`client/Ragdoll.luau`: swaps joints for ball sockets and flings you up), then the animal escapes
- [x] Twists reworked for the Box stage: Pound and Snap (anger spikes), Squeeze (tape peels off), Wiggle (spots drift faster), Poke (bigger angry spots), Breakout (RETURN TO SENDER on launch)
- [x] Boxes, stamps and the Tape Gun now use anger: better boxes start calmer and anger slower, FRAGILE angers 30% faster, PRIORITY starts at 50 anger, and the Tape Gun makes each strip annoy it 10% less per level
- [x] Rating: −1 stamp each for anger ≥75, touching angry spots 3+ times, going over par, and each escape
- [ ] **Vine boom sound id:** paste one into `Config/Sounds.luau` (see README → Vine boom)
- [x] **Playtest checkpoint:** passed in Studio on 2026-09-29 ("works great", after the seam-layer fix)

## Mail It Yourself (requested 2026-09-29)
Taped boxes go into your **inventory** instead of mailing themselves. You carry them to the **mail chute** and mail
them yourself, and the chute can be **upgraded** (models ready: `Parcel`, `MailChute` → `MailChuteExpress` →
`MailChutePneumatic` → `MailChuteRocket`).
- [x] Inventory: taped boxes become **Parcels** in your bag (`MailService.luau`), saved with your progress. Up to 3 show stacked in your arms (your Blender `Parcel` model if it's imported), and the HUD shows **Bag N/Max**. A full bag blocks starting or joining a job
- [x] Mail them yourself: hold E at the Mail Chute and the parcels fly in. Pay, orders, stats and leaderboards all happen at mailing time, with one receipt for the whole bag
- [x] Chute upgrades (Supply Shop → **Chutes**, bought in order, `Config/Mail.luau`): Basic → Express (+15%, faster) → Pneumatic (+30%) → Rocket (+50%, and **press M to mail from anywhere**). Each player sees their own chute model at the Mail Chute (client-side)
- [x] **Mail Bag** tool (Tools tab): +2 capacity per level, up to 13
- [ ] **Playtest checkpoint**

## Phase 2 — Animal System ✅
- [x] Animal config: tier (also sets difficulty), price, value, carriers, placeholder color (`Config/Animals.luau`)
- [x] Animal Pen menu: pick any animal, pay its price once to unlock it (free in Studio for testing, via `Config.Dev`)
- [x] 17 twists across the three stages (see the roster table), tuned in `Config/Boxing.luau → TwistTuning`
- [x] **RETURN TO SENDER** breakout for the tiger and Gruff
- [x] Placeholder visuals: colored balls with name labels, plus a **model hook**. Put a Model named after the animal's Id (e.g. `Tiger`) in `ReplicatedStorage > AnimalModels`, and the arena animal uses it automatically
- [ ] Final models/animations: moved to the Art Track below (your Blender work, not blocking)
- [x] **Playtest checkpoint:** passed in Studio on 2026-09-29 ("works and feels good")

## Phase 3 — Progression & Economy ✅
- [x] **Supply Shop** counter behind the Animal Pen, with Boxes / Tools / Stamps / Rebirth tabs (`ShopService` + `client/Shop.luau`)
- [x] Box tiers (`Config/Boxes.luau`): cardboard → wood → steel → vault. Animals start calmer (anger 20 → 5) and anger slower (100% → 70%) *(updated in the Box Rework)*
- [x] Tools with 3–5 upgrade levels (`Config/Tools.luau`): Grabbing Gloves (−10% hold per level), Sneakers (+1 speed), Tape Gun (each strip annoys it 10% less per level), Butterfly Net (+1 stud reach)
- [x] Stamps, reworked for boxing (`Config/Stamps.luau`): *Fragile* (+50% pay, angers 30% faster), *Express* (+75% if under par), *Priority* (double pay, starts at 50 anger). Buy them, pick one for your next job, and it's used up when the job starts
- [x] Gruff's orders board next to the Post Office (`Orders.luau`): 3 saved orders like "Mail a Skunk without it escaping" for 2–4.5× bonus, refreshed every 10 min, only for animals you own
- [x] Rebirth: resets coins, animals, boxes, tools and stamps for a permanent +25% coins per rebirth. The first costs 10M, and each one after costs 2.5× more. Click twice to confirm
- [x] DataStore saving with **session locking** (`DataService.luau`): autosave every 60s, save on leave and on server shutdown, a lock so two servers never write the same save, stale-lock takeover so nobody gets stuck, and old saves get new fields filled in automatically. If DataStores are off, the HUD warns that progress isn't saving
- [x] Economy tuning sheet: `python tools/economy_sheet.py` reads the real config and writes `docs/economy.csv`. The first pass fixed a 78-minute Yeti wall (1.2M → 500k) and a too-cheap rebirth (1M → 10M). Currently about 7 hours to the first rebirth, with late unlocks taking ~20–35 min each
- [x] **Playtest checkpoint:** passed in Studio on 2026-09-29 (shop, tools, stamps, orders all work)
- [ ] **Save test on Roblox:** deferred to Phase 8 (Launch Prep) at your request. Needs the place published

## Phase 4 — World & Arenas
- [x] Hub town: a cobblestone plaza with the spawn, Animal Pen, Supply Shop, Post Office (Gruff and the chute), Gruff's Orders, and a row of **travel pads**, one per arena
- [x] Five themed arenas (`MapBuilder.luau`, tiers in `Config/Arenas.luau`). Picking an animal **teleports you to its arena**:
  - **Backyard** (tier 1): open lawn with a few bushes, next to town
  - **Barn** (tier 2): six hay bales to duck around, with a big red barn behind
  - **Jungle** (tier 3): seven trees, plus **mud pits** that halve your speed
  - **Ice Rink** (tiers 4–5): **you slide** on the ice (momentum, slow turning). The animals don't
  - **Rooftop** (tier 6): 30 studs up with **no fences**. Fall off and you're put back on the roof, dazed, with a word from Gruff
- [x] Each arena has a BACK TO TOWN pad. Mailed boxes fly all the way to the chute in town (farther = higher arc)
- [x] Obstacle-aware AI (`CatchAI.luau`): animals steer around trees, bales, bushes and AC units, slide along them instead of passing through, and use them as corners you can trap them against
- [x] Client movement module (`client/Movement.luau`): sneak (C), mud slow, and ice sliding, all built on the server's speed so Sneakers upgrades and stuns still apply
- [x] "Roof didn't work" (your Phase 4 note): my best guess is that falling off only put you back up while you were **on a job**. Visiting by travel pad and stepping off left you stuck on the ground. Fixed on 2026-09-29: now anyone who falls off the roof is put back up (verified by the automated playtest). If it was something else, tell me what happened
- [ ] **Playtest checkpoint** (checklist in README)

## Phase 5 — Multiplayer / Social ✅
- [x] **Co-op giants** (Elephant 2p, Whale 4p, Postmaster Gruff 4p): now pickable at the Pen. Other players press E on the animal to **join the crew**, and the grab only works with a full crew all within 14 studs. Giants get a double-size box
- [x] **Co-op BOX roles:** the owner tapes and helpers alternate Pet / Tape. Each player's screen shades the part that isn't theirs, and the server only accepts your role's actions. Two petters calm twice as fast. Giants anger 1.4× faster. If a crewmate leaves mid-BOX, roles reshuffle. A burst launches the whole crew
- [x] Everyone in the crew gets the full payout (with their own rebirth bonus), their own orders progress, and leaderboard credit. Use the Pen twice to leave a crew
- [x] **Chaos Mode** (a toggle in the Pen menu instead of a separate arena, so it works in every arena): +50% pay, but any other player can **spook** your animal (E on it: it darts off and runs faster for 3s) and **shove** you (F: knockback, plus +10 anger if you're mid-BOX). Non-Chaos jobs can't be touched
- [x] **Leaderboards** (`LeaderboardService.luau`): three boards on the west side of the plaza for Fastest Tiger, Most 5-Stamp Jobs and Rarest Animal Mailed. They use global OrderedDataStores when saving works, rank this server's players when it doesn't, and refresh every 60s. Stats live in the profile and survive rebirths
- [x] **Playtest checkpoint:** passed in a multi-client Studio test on 2026-09-29 (crews, roles, Chaos Mode, leaderboards)

## Art Track (runs in parallel from Phase 2 on)
- [x] Blender → Roblox pipeline test: scripted hamster + cardboard box (`art/`), imported in Studio. Auto-fit (`ModelFit.Fit`) and auto-color (`ModelFit.Paint`, since the importer drops colors) confirmed working on 2026-09-29
- [ ] Style guide: palette, poly budget per animal (~500–2k tris), flat or gradient-texture shading
- [x] Animations are **code-driven** instead of rigged (see Decisions): hop + lean while running, breathe/bob + head-turn twitches while idle, box rattle and thrashing by anger, happy squish when petted, Gruff bobbing and turning to watch you
- [x] **All 75 models built in Blender** (`art/`, list in `art/MODEL_LIST.md`): every animal, the box set, Gruff and his hat, the town, props for all five arenas, gameplay props, shop tools and chute upgrades. Animals and boxes are already hooked into the game. Town and arena props replace the graybox parts in a later pass
- [x] Models imported into Studio (all four folders) and **map swap done** (`MapBuilder.luau`): every grey block with a model gets it laid on top. The block stays invisible as the collider, prompt holder and name tag. Fences are lined with fence segments, and there's new scenery (doghouse, flowerbed, trough, rocks, snowmen, water tower, chimney, lampposts, benches, planters, mailbox). Missing models just leave the grey block
- [x] Props hooked up: Gruff's model + his cap (still gets knocked flying), eggs, a spinning tool display at the shop, a spinning letter over the orders board, and 3D icons in the Pen and Shop menus
- [ ] Priority: finish the Tier 1 animals first. Everything else stays as placeholders until launch-critical.

## Phase 6 — Juice, UI & Audio
- [x] UI polish: your 3D animal on the BOX screen (squishes when petted), 3D model icons in the Pen (locked animals show as dark silhouettes) and Shop, windows pop open, buttons squish, the coin counter rolls up with a floating "+N" and short numbers (12.5K, 3.2M)
- [x] SFX **slots** for everything (`Config/Sounds.luau`): vine boom, pop, purr, OW, growl, tape rip/peel, stamp thud, escape, roar, spray, freeze, bonk, mail whoosh, coin jingle, ka-ching, click, ding. All silent until you paste in ids (checklist in README)
- [x] Camera punches (launch, tape done, mail), confetti when you finish a box and when you mail, box rattle by anger
- [x] **Gruff's walkthrough** (`client/Tutorial.luau`): Pen → catch → box → mail → shop, with a glowing arrow and a bouncing marker. It follows what you actually do (an escape sends you back to catching), can be skipped, and pays a 100-coin bonus the server checks. Saves from before it existed skip it if they've mailed anything
- [ ] **Playtest checkpoint** (checklist in README)

## Phase 7 — Monetization
**⚠ PLAN NEEDS YOUR APPROVAL.** The code is written and wired up, but nothing can be bought until you create each item on Roblox and paste its id into `src/shared/Config/Monetization.luau` (id 0 = hidden). Change any price or cut any item there before you create it.

| Item | Type | Robux | What it does |
|---|---|---|---|
| Big Mail Bag | pass | 99 | +3 bag slots |
| VIP Postie | pass | 149 | Golden tape (on screen and on the box) and a golden ★ VIP ★ tag. Cosmetic only |
| 2x Coins Server Boost | product | 99 | **Everyone** in the server earns 2x coins for 3 minutes. Buying again adds 3 more minutes (up to 60 left). Everyone sees who bought it |
| Handful / Pouch / Chest of Diamonds | product | 49 / 129 / 349 | 40 / 120 / 400 💎 for Diamond Upgrades |
| Sack / Crate / Vault of Coins | product | 49 / 129 / 349 | Coins worth 20 / 60 / 200 jobs of your best owned animal, so packs stay useful all game |
| Skip the Wait | product | 99 | Unlocks the next animal you don't own, tiers 1–4 only (the big late-game animals must be earned), and only in zones you've opened. Hidden when there's nothing left to unlock |
| Priority Stamp Pack | product | 29 | 5 Priority stamps |
| Buy Gruff a Coffee | product | 5 | Nothing. Gruff says thanks, grudgingly. A tip jar |
| Roblox Premium perk | free | – | Premium members earn +10% coins (Roblox pays you for Premium players' playtime) |
| Group bonus | free | – | +10% coins for members of your Roblox group (off until you set `GroupId`) |

- [x] Code: `server/MonetizationService.luau` (pass checks on join and on purchase, safe ProcessReceipt that writes the purchase id into the save before telling Roblox "granted", so retries never pay twice), `client/Store.luau` (green **Store** button at the top-left, only lists items you've set up), hooks for 2x coins (Economy), bag size (server + client) and VIP tape/tag
- [x] No random crates. **Nothing affects Chaos Mode fights**: no pass or diamond upgrade changes shove, spook, speed, trolls or anger from other players
- [x] 2026-09-30: Double Coins pass replaced by the **2x Coins Server Boost** (product). Added **Diamonds** 💎 (`Config/Diamonds.luau`): earned by leveling up (+3, +10 more every 5th level), Gruff's quests (+2) and rebirths (+25), or bought with Robux. Spent on 7 permanent **Diamond Upgrades** (UPGRADES button, or tap your 💎 counter), kept through rebirths: Golden Paws (+10% coins/level), Quick Study (+10% XP), Deep Pockets (+1 bag slot), Calm Hands (animals start 3 anger calmer), Pay Raise (+25% paycheck), Busy Desk (+1 side order), Rebirth Toolkit (tools start at level N after a rebirth). All 7 maxed cost about 1,000 💎; a free player reaching level 50 with all quests earns about 330 plus 25 per rebirth
- [x] Store always lists everything. Items with Id 0 show a purple **TEST** button in Studio (free, to try them) and "Soon" in the live game
- [ ] **You:** approve or edit the table, then create the passes and products (steps in README → Launch checklist)
- [ ] **You:** private servers: Creator Dashboard → your game → Monetization → Private Servers (suggest free or 100 Robux)

## Phase 8 — Launch Prep
- [ ] **You:** icon + thumbnails + trailer clip (RETURN TO SENDER!). Steps in README → Launch checklist
- [x] Analytics (`server/Analytics.luau`, Roblox's built-in dashboards): onboarding funnel (joined → picked animal → caught → taped → mailed → tutorial done), every coin source and sink with item names, and custom events for launches, escapes, rebirths and tutorial skips
- [ ] Soft launch → fix retention drop-offs → sponsored ads
- [x] Anti-exploit review (2026-09-29): every client → server remote has a per-player rate limit (`Remotes.Listen`). Every handler checks its argument types, and the server re-checks distance, coins, ownership, stage and role. Pet calm is time-based, so spamming can't calm faster than a perfect human. Tape has a minimum gap per seam. Tiger times under 5s are ignored on the leaderboard. Robux receipts are idempotent. **Known limits (normal for Roblox):** an exploiter can teleport or speed-hack their own character (Roblox gives clients control of their character), and can "play perfectly" in the BOX stage, which is no faster than a skilled human
- [ ] **You:** live save test (moved from Phase 3): publish, enable API access, then check join/leave/rejoin, two quick rejoins (session lock), and a server shutdown
- [x] Launch checklist written (README → Launch checklist)

## Overnight extras (2026-09-29)
Things added beyond the plan while you were away:
- [x] **Daily paycheck** from Gruff (`server/PaycheckService.luau`): the first time you play each day you're paid 5 jobs' worth of your best animal × your streak (days in a row, max 7). Tune in `Config/Progression.luau` → `Paycheck`
- [x] **Settings** and **Invite** buttons (top-left, next to Store): music, sound effects, camera shake & zoom on/off, saved with your progress
- [x] **Badges** (`Config/Badges.luau`, `server/Badges.luau`): First Delivery, Mail a Tiger, RETURN TO SENDER, Five Stamps, Special Delivery (mail Gruff), Chaos Courier, Reborn. Off until you create them on Roblox and paste the ids
- [x] **Reward codes** (`Config/Codes.luau`, `server/CodesService.luau`): typed into Settings, once per player, server-checked, optional expiry. Starts with `LAUNCH` (10 jobs of coins) and `GRUFF` (2 Priority stamps)
- [x] **Music** slots for town, arena and BOX that fade into each other
- [x] **Starter sounds**: every slot has a free sound from Roblox's own library (placeholders picked by name, so give them a listen)
- [x] **Draft icon + thumbnails** rendered from your models (`art/marketing/`)
- [x] **Model checker** (`tools/check_models.luau`): reads your saved place and lists missing, misplaced or backwards models
- [x] **Automated playtest** (`tools/e2e/run.sh`): opens a temporary Studio, and a test player picks a Hamster, catches it, pets and tapes it, mails it, buys a stamp, upgrades Sneakers, redeems a code and changes a setting, using the real code and your models. Also: the Pen and Orders prompts, all chute upgrades and Rocket mail-anywhere, a tiger launch with RETURN TO SENDER (cap flies), falling off the roof, a Chaos Mode chicken (egg pickup, Rocket mail from the arena), and visual checks (BOX screen 3D animal, chute model swap, leaderboards). **All 65 steps pass (2026-09-29), including a check that all 21 starter sounds actually load, with no script errors, at 59 FPS on this PC**. It found one real bug from Phase 3: new orders were made on a copy of your save at join, so they only appeared after opening the board (fixed)
- [x] **Studio smoke test** (`tools/smoke/run.sh`): builds the real map with your models and loads every module
- [x] **Automatic tests** (`tests/run.luau`, ~550 checks): Config consistency and box math, runs in seconds without Studio
- [x] Layout pass using the real model sizes (post office depth, fence heights, barn size, mud puddles, cap size, leaderboard board)

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
- **Core mechanic (2026-09-29):** Catch → **BOX** (pet the animal calm while dragging tape across the box seams, with an anger meter). Anger at 100 = vine boom + ragdoll launch + escape. **No carrying and no obstacle course**, and the box is mailed right away.
- **Difficulty:** scales with the animal's tier, plus per-animal twists. Hard animals should be genuinely hard.
- **PvP:** opt-in **Chaos Mode** (a Pen toggle, +50% pay: others can spook your animal and shove you). Everything else is PvP-free, with co-op crews for giant animals.
- **Experience:** beginner. Keep the architecture simple, and explain each system as it's built.
- **Art:** low-poly cartoon, modeled and animated by you in Blender. Graybox with Parts first, and swap in models as they're ready.
- **Audience:** all ages. Easy to pick up, with depth at high tiers.
- **Progression:** simulator-style. Numbers go up, with lots of unlocks and rebirths.
- **Vibe:** chaotic comedy. Loud sound effects, and failing is entertaining.
- **Getting animals:** buy them with coins at the Animal Pen once they're unlocked. No random crates, so no odds disclosure is needed.
- **Boss:** Postmaster Gruff, a grumpy walrus. He runs the tutorial and the orders board, rates jobs, and is the final job.
- **Signature moment:** VINE BOOM ragdoll launch, plus "RETURN TO SENDER" for the tiger.
- **Roster:** real animals through the mid-game (hamster → tiger), then silly ones at late tiers (dragon, alien, a mailman).
- **Working unattended (2026-09-29):** build everything through launch prep, including monetization code from a plan logged here for your approval. Ambiguous calls get decided and logged in this section. Commit after each working piece, with no check-ins. Things only you can do (sound ids, publishing, API access, game passes, icon) get a checklist.
- **Tutorial:** Gruff walks new players through it (Pen → catch a hamster → box it → mail it) with an arrow pointing where to go, and it can be skipped.
- **Map swap (decided 2026-09-29):** models are laid over the grey blocks instead of replacing them, so collisions, prompts and name tags keep working exactly as tested, and a missing model can't break anything. The Post Office now faces the plaza (building behind Gruff, counter and chute in front). If a model faces the wrong way, give it a `YawOffset` attribute (degrees) in Studio.
- **Animation (decided 2026-09-29):** code-driven, not rigged. The Blender models are one mesh per color (ears are part of "Fur"), so there are no separate limbs to animate. Whole-model motion (hop, lean, bob, twitch, squish) sells it for a low-poly comedy game, and there's nothing to re-export.
- **Animal models are drawn by each client** following the server's invisible ball, so the animation costs no network traffic. The server only moves the ball.
- **Shop tools buffed (2026-09-30, after "I don't think all the tools work"):** Sneakers were broken in town (speed only updated when a job started), now fixed. The others worked but were too weak to feel, so: Sneakers +1 → **+2 speed**/level, Gloves 10% → **15%**/level, Tape Gun 10% → **15%**/level, Net +1 → **+2 studs**/level. The Shop now shows each tool's current effect (e.g. "now: +4 speed"), and the automated playtest checks each one.
- **Bigger world (2026-09-30, from your reference screenshots):** the map is now a whole island made of terrain: beaches, ocean, snow-capped mountains on the horizon. The hub is much bigger (fountain, raised terraces with brick sides, how-to-play / daily-paycheck countdown / like-and-join boards, a giant MAIL A TIGER sign). The five arenas are spread out as themed zones joined by stone paths with lampposts and a signpost, each with a giant entrance banner: a house by the Backyard, a farm (silo, crops) by the Barn, a waterfall cliff and giant trees in the Jungle, a snowy winter zone with pines and falling snow around the Ice Rink, and a city of skyscrapers around the Rooftop (with an elevator pad). Trees, rocks and flowers fill the land in between. The chase areas themselves kept their sizes, so difficulty tuning is unchanged. Layout lives in `MapBuilder.luau` (ARENA_LAYOUT) and `Scenery.luau`.
- **Progression (2026-09-30, "make it feel like an actual game"):**
  - **Levels and XP** (`Config/Levels.luau`, `server/ProgressionService.luau`): XP from mailing (tier × stars), side orders, quests, the tutorial, and a big bonus the first time you mail each animal. Leveling up pays coins with a LEVEL UP celebration. Levels are kept through rebirths. Old saves start at a level that keeps their zones open.
  - **Zones open by level:** Backyard 1, Barn 4, Jungle 8, Ice Rink 12, Rooftop 18. Locked zones have a shimmering barrier with a "🔒 LEVEL N" sign. Travel pads, the Pen and walking in all respect it, except that crew helpers on a job there are allowed.
  - **Gruff's main quests** (`Config/Quests.luau`, 27 steps): one at a time, shown under the top banner and at the top of the Orders window. They keep asking for new animals ("Unlock the Bunny", "Mail a Chicken", "MAIL A TIGER") and new zones.
  - **Troll items** (`Config/Trolls.luau`, `server/TrollService.luau`): Banana Peel (Lv 5), Stink Bomb (9), Glue Puddle (13), Tape Bomb (17), Air Horn (22). Bought with coins (never Robux), used from a hotbar (keys 1-5), and they ONLY affect players in Chaos Mode, keeping PvP opt-in.
  - **Inventory** (BAG button): troll items, mail boxes (equip), stamps (pick for the next job), tools, and an animal collection with mystery silhouettes for animals you haven't mailed.
  - **Short numbers** everywhere (1k, 12.5k, 1M, 1B), in menus and in Gruff's messages (`shared/Format.luau`).
  - **No 3D models as buttons:** every button and menu icon comes from `Config/Icons.luau` (your 2D images, or emoji until you add them). The image list is in `docs/UI_IMAGES.md`.
- **Popups (2026-09-30):** about 3.5 s each (1.2 s if another is waiting), at most 2 waiting, repeats skipped.
- **Map restyle (2026-09-30, "textures and vibe look like shit", reference: a bright city sim):** the island ground is now flat smooth parts at exactly y = 0. Roblox terrain bulges above its fill line, which is what buried the plaza and half-sank the counters, pads and stands. Everything is smooth plastic in bright flat colors instead of gritty textures (only Ice, Mud, Neon and Glass keep theirs). There's a peach plaza with lawn beds and hedges, a ring road with white dashes, sidewalks and crosswalks around it, dark roads with white dashes out to each zone, blobby cartoon trees, palm trees on the beach, puffy clouds, brighter lighting with lighter shadows, and smaller floating name tags that only show up close. Terrain is only used for the ocean and the distant mountains now.
- **New UI style (2026-09-30, from your reference screenshots):** one UI kit (`client/Ui.luau`) gives every window and button a chunky look: thick dark outlines, glossy gradients and bold outlined text (Luckiest Guy font). Big square side buttons with 3D icons (left: PEN, SHOP, ORDERS; right: STORE, SETTINGS, INVITE). Coins, bag and total coin boost are stacked bottom-left in big outlined numbers. The current goal shows as a big banner across the top. Popups have a colored header and never cover a menu or the BOX screen (they move to the corner), and they sit above everything. The Pen is now chunky tier-colored cards with a PLAY/BUY button. Everything shrinks automatically on small screens (phones).
- **Pen and Shop work from anywhere (2026-09-30):** with a map this big, walking back to the counters every time is a chore, so the new PEN and SHOP buttons open them anywhere and the server no longer requires standing at the counter. Coins and everything else are still checked. The counters still work too.
- **Tutorial bonus:** 100 coins, only if you actually mailed an animal (the server checks), none for skipping.
