# Mail a Tiger

Catch increasingly wild animals, stuff them in a box, and tape it shut before they burst out. Postmaster Gruff is watching.

- Plan and decisions: [ROADMAP.md](ROADMAP.md)
- New to Roblox scripting? Start with [docs/LEARN.md](docs/LEARN.md)

## Tools (already installed)
| Tool | What it does |
|---|---|
| [Rokit](https://github.com/rojo-rbx/rokit) | Installs the exact tool versions listed in `rokit.toml` |
| [Rojo](https://rojo.space) | Syncs the code in `src/` into Roblox Studio live |
| Selene | Linter: catches mistakes before you playtest |
| StyLua | Formatter: tidies code every time you save |
| VS Code + extensions | Where you write code (`.vscode/extensions.json` lists them) |

On a new computer: install Rokit, then run `rokit install` in this folder.

## Daily workflow
1. Open this folder in VS Code (**File → Open Folder → E:\Mail a Tiger**).
2. Start Rojo: press `Ctrl+Shift+P`, type **Rojo: Open menu**, and click ▶ next to `default.project.json`.
   (Terminal alternative: `rojo serve`.)
3. Open **`MailATiger.rbxl`** in Roblox Studio (double-click it).
4. In Studio: **Plugins tab → Rojo → Connect**.
5. Edit code in VS Code, and it appears in Studio instantly. Press **Play** in Studio to test.
6. **Build the map in Studio** and save the place file with `Ctrl+S`. Code lives in `src/`, and the map lives in the `.rbxl`.

> The `.rbxl` isn't tracked by Git (it's binary and huge). Back it up yourself, or publish it to Roblox. If you ever lose it, `rojo build -o MailATiger.rbxl` rebuilds the code part.

## Where things go
```
src/
  shared/   → ReplicatedStorage.Shared      code both server and client can use
    Config/     all tunable numbers: animals, boxing difficulty, boxes, stamps, Gruff's lines
  server/   → ServerScriptService.Server    trusted game logic (the boxing stages, coins)
  client/   → StarterPlayerScripts.Client   UI, camera, input, effects
```

## How to play
1. Hold **E** at the **Animal Pen** counter and pick an animal. (In Studio they're all free, set in `Config/init.luau` under `Dev`.)
2. **CATCH:** chase it around the fenced arena, corner it, and hold **E** to grab it. Hold **C** to sneak.
3. **BOX:** the animal and the box pop up on screen, and the ANGER bar keeps rising.
   - **Rub** (click-and-drag back and forth, or swipe) over the pink **♥** spots on the animal to calm it. Never touch the red **✖** spots!
   - **Tape:** drag from one black dot to the other along each dashed seam on the box. Every strip makes it angrier, so keep going back to petting.
   - Tape every seam and the animal goes into your **bag** as a Parcel (you'll see it in your arms).
   - If ANGER hits 100: *VINE BOOM*. You're launched into the sky as a ragdoll, and the animal escapes back into the arena.
4. **MAIL IT:** carry your parcels to the **Mail Chute** in town and hold **E**. That's when you get paid and Gruff rates you. Your bag holds 3 to start (upgrade the **Mail Bag** in the Supply Shop).
- Changed your mind? Use the Pen counter twice within 5 seconds to give up on the current animal.

## Playtest checklist
All the difficulty numbers live in `src/shared/Config/Boxing.luau` (the `Box` section).
- [ ] **Hamster:** easy start to finish. Does rubbing and taping feel good?
- [ ] **Box:** tape all the seams without petting. Anger climbs, you get launched as a ragdoll, and the animal escapes.
- [ ] Touch a red ✖ spot: the animal card shakes and anger jumps.
- [ ] **Octopus / Dragon:** a taped seam can peel back off, so re-tape it.
- [ ] **Bear:** it starts asleep. Walk up normally and it wakes and bolts. Sneak with **C** and you can grab it.
- [ ] **Goldfish / Pig / Penguin:** grabs sometimes slip. **Parrot / Monkey** fly out of reach. **Octopus** vanishes. **Alien / Unicorn** teleport.
- [ ] **Goat / Crocodile / Gorilla** charge and knock you back. **Skunk** sprays your screen. **Yeti** freezes you.
- [ ] **Chicken:** picking up its eggs adds bonus coins.
- [ ] **Tiger:** hard! Its roar stuns you, and if you get launched you also get **RETURN TO SENDER** and Gruff's hat flies off.
- [ ] Two players (**Test → Clients and Servers → 2 players**): each player's animal ignores the other player, and you can't grab someone else's.

## Phase 3 checklist: shop, orders, rebirth
- [ ] **Supply Shop** (blue counter behind the Pen): buy the Wooden Crate. It's equipped, the animal starts calmer during BOX, and the box is brown.
- [ ] Upgrade **Sneakers** and you run faster. Sneak with C, let go, and you're back to your upgraded speed.
- [ ] Upgrade **Gloves** / **Net**: grabbing is quicker, and works from farther away.
- [ ] Buy a **FRAGILE** stamp. The coins line says "Next job: FRAGILE". Box an animal and it gets angry faster, and the receipt shows FRAGILE with higher pay.
- [ ] **Gruff's Orders** (board right of the Post Office): mail a matching animal and the receipt shows "+X order!". The board then marks it DONE.
- [ ] **Rebirth** tab: shows the cost. (To test it quickly, temporarily set `Rebirth.BaseCost` to 10 in `Config/Progression.luau`.)
- [ ] The player list shows Coins and Rebirths.

## Phase 4 checklist: arenas
Arena tuning (mud slowdown, ice grip, rooftop fall stun) is in `src/shared/Config/Arenas.luau`.
- [ ] Town has a row of 5 glowing **travel pads**. Each one takes you to its arena, and each arena's **BACK TO TOWN** pad brings you home.
- [ ] Pick a **Chicken** (tier 2): you're teleported to the **Barn**. The chicken dodges around hay bales, and you can trap it against one.
- [ ] Pick a **Monkey** (tier 3): the **Jungle**. Mud pits slow you down, and animals weave between the trees.
- [ ] Pick a **Tiger** (tier 4): the **Ice Rink**. You slide and turn slowly. Is it fun-hard or annoying-hard? (`IceGrip`: higher = more grip)
- [ ] Pick a **Dragon** (tier 6): the **Rooftop**. Walk off the edge and you're put back up, dazed.
- [ ] Finish a job in a far arena: the box flies all the way to the mail chute in town.

## Mail It Yourself checklist
- [ ] Box a Hamster: the "Taped!" popup says it's in your bag, a parcel appears in your arms, and the top bar shows **Bag 1/3**.
- [ ] The bottom tip tells you to take it to the Mail Chute. Hold **E** at the chute: the parcel flies in, and Gruff's receipt shows the pay.
- [ ] Fill your bag (3 parcels), then try to pick another animal: Gruff says your bag is full.
- [ ] **Supply Shop → Chutes:** buy the Express Chute (in Studio you start with 2,000,000 test coins while saving is off). The receipt says "+15%" and the hold at the chute is shorter.
- [ ] **Supply Shop → Tools → Mail Bag:** upgrade it and the bag shows 5 slots.
- [ ] Leave and rejoin with parcels in your bag: they're still there (needs saving to be on).

## Phase 5 checklist: multiplayer
Test with several players: in Studio, **Test tab → Clients and Servers → 2 players** (or 4 for the Whale and Gruff). Tuning is in `src/shared/Config/Social.luau`.
- [ ] **Co-op:** Player 1 picks the **Elephant** (the card says "co-op 2p"). Player 2 walks to the Ice Rink (travel pad) and presses **E** on the elephant: "joined the crew". The label shows crew 2/2.
- [ ] Grabbing with only one player nearby says someone is too far. With both close, it works.
- [ ] **BOX with a crew:** Player 1 only tapes (the animal is shaded "Your crewmate is petting!"), and Player 2 only pets. Both get paid when it's mailed.
- [ ] Let anger hit 100: *both* players get launched.
- [ ] **Chaos Mode:** Player 1 turns on the red Chaos toggle in the Pen menu and picks a Hamster. Player 2 presses **E** on it (spooked, it darts off) and presses **F** near Player 1 (shoved). The receipt shows CHAOS and +50% pay.
- [ ] A normal (non-Chaos) job can't be spooked or shoved.
- [ ] **Leaderboards** (west side of the plaza): mail a 5-stamp job and the "Most 5-Stamp Jobs" board updates. It says "(this server only)" until saving is on.

## Overnight build checklist: new map, animation, tutorial, store
**Already verified by machine:** an automated playtest (`bash tools/e2e/run.sh`) played the whole loop in Studio with your models: catch, box, mail, shop, codes, settings, tutorial, chute upgrades, a tiger launch with RETURN TO SENDER, and the rooftop fall. All 49 steps passed with no script errors. So this list is mostly about **how things look and feel**, which only you can judge.

Play once with a **fresh save** (saving is off in Studio, so every Play is fresh) and once as usual.
- [ ] **Town:** the Post Office building now faces the plaza, with Gruff in front of it, his counter, and the chute on the right. Is anything floating, sunk into the ground, or facing backwards? (Fix: add a Number attribute `YawOffset` = `180` to that model in its folder.)
- [ ] Lampposts, benches, planters, the mailbox and the leaderboard stands are placed sensibly and the scores sit on the leaderboard boards.
- [ ] A little letter spins over **Gruff's Orders**, and the tools spin on the table next to the **Supply Shop**.
- [ ] **Arenas:** fences are made of fence models (pickets, farm rails, bamboo, rink boards) with no big gaps, and there's a gate at each entrance. Barn, hay bales, trees, mud puddles, hockey goals, snowmen, AC units, water tower and chimney all look right, and animals still can't get out.
- [ ] **Gruff** bobs and turns to watch you when you're close. A tiger breakout still knocks his cap off, and it comes back.
- [ ] **Animals** hop and lean when running, breathe and glance around when still. The **Chicken's** eggs are egg models.
- [ ] **BOX screen:** your animal is the real 3D model (not a circle), it sways a little, and squishes when you rub a ♥ spot. In the arena the box rattles and the animal thrashes when anger is high.
- [ ] **Tutorial** (fresh save): Gruff's panel on the left says to go to the Pen, with a glowing yellow line and a bouncing ▼ pointing there. It updates for catching (points at your animal), boxing, mailing (points at the chute) and shopping, then disappears. You get +100 coins at the end. "Skip tutorial" also works.
- [ ] **Juice:** confetti when you finish a box and when you mail. The camera zooms on launches. The coin counter rolls up with a "+N", and big numbers show as 12.5K / 3.2M.
- [ ] **Menus:** 3D pictures in the Pen (animals you can't afford are dark silhouettes) and in every Shop tab. Windows pop open, and buttons squish when pressed.
- [ ] **Store** (green button, top-left): says "The Store opens soon!" until you add ids. After you add one, it lists it and Roblox's (test) purchase popup appears.
- [ ] **Lighting:** the world now has shadows, an early-afternoon sun and soft haze (from `Config/Look.luau`). For crisper shadows, in Studio select **Lighting** and set **Technology** to **Future** (scripts can't change that one). Don't like the look? Set `Apply = false` in `Config/Look.luau`.
- [ ] **Popups** queue up instead of replacing each other, and receipts get a red star-rating stamp.
- [ ] **Daily paycheck:** a few seconds after joining, Gruff pays you for showing up (day 1 of your streak).
- [ ] **Settings** button (top-left, next to Store): turn music, sound effects or camera shake off and on. Choices stick after a rejoin (with saving on).
- [ ] **Codes:** in Settings, type `launch` and press Redeem: Gruff gives you coins. Type it again: "already used". Try `gruff` for 2 Priority stamps. (Codes are in `Config/Codes.luau`.)
- [ ] **Sounds and music** play (starter sounds from Roblox's library). Note any that are annoying or wrong.
- [ ] Anything that looks wrong: tell me what and where (a screenshot helps).

## Sounds
Every sound effect and music track has a slot in `src/shared/Config/Sounds.luau`. **Starter sounds are already filled in**: free ones from Roblox's own library, picked by name, not by ear (the vine boom is a cannon for now). Play the game, then swap any you don't like. Roblox can only play sounds uploaded to Roblox:
1. In Studio, open the **Toolbox → Marketplace → Audio**, search for the sound, and pick one you're allowed to use (or upload your own in the Creator Dashboard).
2. Right-click it → **Copy Asset ID**.
3. Paste it into the slot, e.g. `VineBoom = { Id = "rbxassetid://THE_ID", Volume = 2, ... }`.

Search ideas: **VineBoom** "vine boom", **Pop** "cartoon pop", **Purr** "cat purr" / "happy chirp", **AngryHit** "ow" / "cartoon hit", **Growl** "animal growl", **TapeRip** "tape rip" / "duct tape", **TapePeel** "tape peel", **StampThud** "stamp" / "thud", **Escape** "cartoon run away" / "boing", **Roar** "tiger roar", **Spray** "spray hiss", **Freeze** "ice freeze", **Bonk** "bonk", **MailWhoosh** "whoosh", **CoinJingle** "coins", **Kaching** "cash register", **Click** "ui click", **Ding** "ding" / "success".

## Launch checklist (things only you can do)
In rough order. Each one is a few minutes.
1. **Sounds:** listen to the starter sounds and swap the ones you don't like in `Config/Sounds.luau` (see Sounds above). Most important: a real **vine boom**, since it's the big clip moment. Pick one you're allowed to use.
2. **Publish:** in Studio, **File → Publish to Roblox**, and create a new experience called *Mail a Tiger*.
3. **Turn on saving:** **Game Settings → Security → Enable Studio Access to API Services** (this is for testing in Studio; live servers save automatically once published).
4. **Live save test** (moved here from Phase 3): in a published test, earn coins → leave → rejoin (coins kept). Rejoin twice quickly (no lost progress, maybe a short wait). Parcels in your bag survive a rejoin.
5. **Robux items** (optional, see ROADMAP → Phase 7 for the plan to approve): Creator Dashboard → your experience → **Monetization** → create each **Pass** and **Developer Product**, then paste each id into `src/shared/Config/Monetization.luau`. Keep the prices the same as the table.
6. **Group bonus** (optional): create a Roblox group for the game, then paste its id into `GroupId` in `Config/Monetization.luau`. Members earn +10% coins (Premium members get +10% already, automatically).
7. **Private servers** (optional): Monetization → Private Servers → set a price (free or 100 Robux is typical).
8. **Icon and thumbnails:** drafts rendered from your models are in `art/marketing/` (icon.png 512×512, two 1920×1080 thumbnails; re-render with `art/blender_scripts/marketing.py`). Use them or take in-game screenshots, then Creator Dashboard → your experience → **Places / Configure** → upload. Good in-game shots: the RETURN TO SENDER stamp mid-launch, a player taping an angry tiger, the town with Gruff.
9. **Game settings:** Genre *Simulation* (or *Comedy*), max players 12–16, **Maturity questionnaire** (Creator Dashboard → Experience Questionnaire; the ragdoll launch is cartoon slapstick), and allow **Private Servers** if you did step 7 (Private servers).
10. **Badges** (optional): Creator Dashboard → your experience → **Associated Items → Badges**, create the 7 badges listed in `Config/Badges.luau` (names and descriptions are there), and paste each id in.
11. **Reward codes:** edit `Config/Codes.luau` (e.g. a `LAUNCH` code for launch day) and share them in your game description, group or videos.
12. **Fresh data for launch:** change `StoreName` in `Config/Progression.luau` to `PlayerData_v2` (wipes test saves) and `StoreVersion` in `Config/Social.luau` to `"v2"` (resets leaderboards).
13. **Studio free animals** are Studio-only and turn off by themselves in the live game. Nothing to do.
14. **Go public:** Creator Dashboard → your experience → **Access → Public**. Then watch **Analytics** → Onboarding funnel to see where new players drop off.

## Saving (DataStores)
Progress saves automatically: every 60 seconds, when you leave, and when a server shuts down.
- **In Studio**, saving only works once the place is published to Roblox **and** you turn on **Game Settings → Security → Enable Studio Access to API Services**. Until then the game still runs, but the HUD shows "⚠ Progress isn't saving".
- To **wipe everyone's data** (e.g. before launch), change `StoreName` in `Config/Progression.luau` to a new version like `PlayerData_v2`.
- Economy sheet: `python tools/economy_sheet.py` writes `docs/economy.csv` from the real config numbers. Re-run it whenever you change prices or payouts.

## Adding your Blender models
Models live in the [`art/`](art/README.md) folder: `.blend` sources, `.fbx` exports and preview renders.

**Folders** (in **ReplicatedStorage**, Rojo leaves them alone). Every model goes in one of these, named exactly like its `.fbx` file:

| Folder | Models | Used by the game? |
|---|---|---|
| `AnimalModels` | All 25 animals + `Gruff` | Yes |
| `BoxModels` | `Cardboard`, `Wood`, `Steel`, `Vault` | Yes |
| `PropModels` | `Parcel`, `MailChute`, `MailChuteExpress`, `MailChutePneumatic`, `MailChuteRocket`, `GruffHat`, `Egg`, `Envelope`, `GrabbingGloves`, `Sneakers`, `TapeGun`, `ButterflyNet`, `TapeRoll`, `RubberStamp` | Yes (the tools spin on the shop table and show in the Shop menu) |
| `MapModels` | Town: `PostOffice`, `PostCounter`, `PenCounter`, `ShopStall`, `OrdersBoard`, `LeaderboardStand`, `TravelPad`, `SpawnPad`, `Lamppost`, `Bench`, `Mailbox`, `Planter` | Yes (laid over the grey map blocks) |
| `MapModels` | Arenas: `ArenaGate`, `PicketFence`, `Bush`, `Doghouse`, `Flowerbed`, `Barn`, `HayBale`, `FarmFence`, `Trough`, `JungleTree`, `MudPuddle`, `BambooFence`, `Rock`, `RinkBoard`, `HockeyGoal`, `Snowman`, `ACUnit`, `WaterTower`, `Chimney` | Yes (laid over the grey map blocks) |

A missing model is never a problem: that spot just keeps its grey block.

**Check your imports:** save in Studio (Ctrl+S), then run `lune run tools/check_models.luau MailATiger.rbxl`. It lists missing models, models in the wrong folder, and any that face backwards. (Last check, 2026-09-29: `Mailbox` and `MudPuddle` are missing from MapModels, `ButterflyNet` from PropModels, and there's a spare `Chimney` in AnimalModels you can delete. Everything else is in place and facing the right way.)

**For each model:**
1. **Home → Import 3D** → pick the file in `art/export/`.
2. In the import preview, keep it as **one Model** with its parts (don't merge them into one mesh). It will look grey in Studio, which is fine: the game paints each part from `src/shared/ArtColors/` when it spawns.
3. Click **Import**, then drag the Model into its folder from the table.
4. Check the Model's **name matches the file** exactly (no "(1)" or extra words).

**What happens in game:** the arena animal uses your model (animated by code: hops, bobs, twitches), during BOX the box in the arena uses your box model with your animal poking out of it, the BOX screen and menus show little 3D pictures, and the map models sit on top of the grey blocks (which turn invisible but still do the collisions). The game sizes and places models automatically, so import scale doesn't matter. **Facing backwards?** Select the Model and add a Number attribute `YawOffset` = `180`.

## Handy commands
```
rojo serve                     # live-sync to Studio
rojo build -o MailATiger.rbxl  # build a fresh place file (REPLACES the .rbxl: anything you made in Studio is lost)
selene src                     # lint
stylua src                     # format everything
lune run tools/check_models.luau MailATiger.rbxl   # after Ctrl+S in Studio: are all models imported, in the right folders, facing the right way?
lune run tests/run.luau        # ~550 automatic checks on the Config files and box math. Run after changing any Config file
bash tools/smoke/run.sh        # builds the real map with your models in a temporary Studio and reports errors (Ctrl+S first)
bash tools/e2e/run.sh          # automated playtest in a temporary Studio: 49 steps incl. catch, box, mail, shop, tiger launch (~2 min, Ctrl+S first)
```

Type-check (catches misspelled Roblox API names). The VS Code Luau extension does this live, and every file starts with `--!strict`:
```
rojo sourcemap -o sourcemap.json
luau-lsp analyze --platform=roblox --definitions=<path to globalTypes.d.luau> --sourcemap=sourcemap.json src
```
