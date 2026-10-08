# Mail a Tiger

Grab wild animals, pet them calm while you tape them into a box, stamp the parcels in your Post Office
machines, and mail them. Postmaster Gruff is watching.

- Where things stand and what's next: [HANDOFF.md](HANDOFF.md)
- Every design decision, with the reasons: [ROADMAP.md](ROADMAP.md) (a history log: the newest dated entries win)
- New to Roblox scripting? Start with [docs/LEARN.md](docs/LEARN.md)

## Tools (already installed)
| Tool | What it does |
|---|---|
| [Rokit](https://github.com/rojo-rbx/rokit) | Installs the exact tool versions listed in `rokit.toml` |
| [Rojo](https://rojo.space) | Syncs the code in `src/` into Roblox Studio live |
| Selene | Linter: catches mistakes before you playtest |
| StyLua | Formatter: tidies code every time you save |
| Lune | Runs the automatic tests and the model checker outside Studio |
| VS Code + extensions | Where you write code (`.vscode/extensions.json` lists them) |

On a new computer: install Rokit, then run `rokit install` in this folder.

## Daily workflow
1. Open this folder in VS Code (**File → Open Folder → E:\Mail a Tiger**).
2. Start Rojo: press `Ctrl+Shift+P`, type **Rojo: Open menu**, and click ▶ next to `default.project.json`.
   (Terminal alternative: `rojo serve`.)
3. Open **`MailATiger.rbxl`** in Roblox Studio (double-click it).
4. In Studio: **Plugins tab → Rojo → Connect**.
5. Edit code in VS Code, and it appears in Studio instantly. Press **Play** in Studio to test.
6. The map is built by code each time the game starts. Your Blender models live in the place file, so save
   it with `Ctrl+S` after importing any.

> The `.rbxl` isn't tracked by Git (it's binary and huge), and this Git repo has no online copy. Back up the
> whole folder yourself, and keep the game published to Roblox. If you ever lose the `.rbxl`,
> `rojo build -o MailATiger.rbxl` rebuilds the code part (but not your imported models).

## Where things go
```
src/
  shared/   → ReplicatedStorage.Shared      code both server and client can use
    Config/     all tunable numbers and content: animals, machines, levels, eggs, prices, sounds, icons
  server/   → ServerScriptService.Server    trusted game logic (grabbing, boxing, mailing, coins, saves)
  client/   → StarterPlayerScripts.Client   UI, camera, input, effects
art/        Blender sources, exports, icons and marketing art
docs/       how-tos and plans (UI images, sounds, events, boss looks, promo posts, ad plan)
tools/      automated playtest and other checks
tests/      automatic config checks (lune run tests/run.luau)
```

## How to play
1. **The map:** you start by the fountain in the town plaza. Gruff, his counter, the mail chute, the orders
   board and the Post Office are to the east; the Supply Shop is northeast. The seven Post Office
   **machines** stand round the plaza. Roads lead out to the islands.
2. **Islands open by level:** Backyard (level 1), Barn (4), Jungle (8), Ice Rink (12), Rooftop (18). A
   locked island has a shimmering barrier with its level on it. **MENU → TRAVEL** teleports you to Gruff,
   any island you've opened, or the boss arena.
3. **GRAB:** every island has wild animals roaming. Each one has a level and a **rarity** (Common → Ethereal;
   Gruff is Secret) on its name tag. Walk up and **hold E**. Animals a bit above your level are allowed but
   make the BOX harder (orange tag, "HARD +N"); too far above (red tag) and you get VINE BOOM'd back to town.
   Wild animals wind up (red **!!**) and attack if you get close, so **dive** (Q) to dodge, or dive into an
   animal to grab it instantly.
4. **BOX:** the animal and the box pop up on screen, and the ANGER bar keeps rising.
   - **Rub** (click-and-drag back and forth, or swipe) over the pink **♥** spots to calm it. Never touch the red **✖** spots!
   - **Tape:** drag from one black dot to the other along each dashed seam. Every strip makes it angrier.
   - Tape every seam and it goes into your **bag** as a parcel (you'll see it in your arms).
   - ANGER hits 100: *VINE BOOM*. You're launched as a ragdoll and the animal escapes.
5. **STAMP (optional, but it's where the XP is):** buy machines at their stations (they unlock with your
   level and cost coins). **Hold E** at a machine to drop in your parcels, wait a few seconds, then hold E
   again to collect them stamped. Use any machines, in any order; every stamp multiplies that parcel's XP.
   **Bag → Parcels** shows each parcel's stamps.
6. **MAIL:** take your parcels to the chute next to Gruff and **hold E**. You get the XP and a 30% coin tip.
7. **Level up:** XP raises your **chute level**, which is your level. It opens islands, unlocks machines,
   upgrades the chute's look, and raises the **coins per minute** the chute pays you (shown under your coins).
8. **Rebirth** (Shop → Rebirth) at chute level 20 + coins: resets level, machines, coins, animals, boxes and
   stamps, for x1.5 coins per minute (stacking) and **Rebirth Points**, which buy **Tools** (Sneakers,
   Gloves, Tape Gun, Net, Mail Bag) that you keep forever.

**Also in the game**
- **Eggs:** a stand on every island. Pay coins, it wobbles and cracks, and one of that island's animals
  hatches next to you (rarer ones less often). Good for hunting the animal an order needs.
- **Shiny and Golden** animals (3x and 10x pay), with server-wide shout-outs. **Lures** (Shop → Lures, or
  the Robux MEGA Lure) bring rarer animals to you for a few minutes.
- **Gruff's quests** (banner at the top), **side orders** and **daily/weekly challenges** on the Orders
  board; finished ones wait for a **CLAIM** button (red ! on MENU and ORDERS).
- **Diamonds** (from levels, quests, rebirths, invites) buy permanent **Upgrades**.
- **Events** every 10 minutes (Golden Hour, Double XP, Speed Tape, Rush Order, Coin Rain, Mystery Parcel,
  Stampede) and an **hourly boss**: everyone pins it with rope handles, then boxes it together on one giant box.
- **Chaos Mode** (on by default, switch in Settings): +50% pay, but other players can spook your animal,
  shove you (F) and hit you with troll items (Banana Peel, Stink Bomb, Glue Puddle, Tape Bomb, Air Horn).
  Only Chaos Mode players can be hit.
- Daily paycheck, delivery streak combo, friend bonus, invite rewards, reward codes, leaderboards, a
  day/night cycle and Gruff's tutorial for new players.

### Buttons and controls
| | Keyboard / mouse | Controller | Phone |
|---|---|---|---|
| Grab, drop in, collect, mail, buy | hold **E** | hold **X** | tap the prompt |
| Dive | **Q** (or double jump) | **L1** | Dive button |
| Sneak | **C** | **L2** | |
| Shove (Chaos Mode) | **F** | **B** | |
| Troll items | click the hotbar | **R1** pick / **R2** use | tap the hotbar |
| Mail from anywhere (Rocket Launcher) | **M** | **Y** | Mail button |

Left-side buttons: **GRUFF** (teleport to Gruff; shows **PEN** while you're there, which takes you to your
best island), **SHOP**, **STORE** (Robux) and **MENU** (Orders, Bag, Upgrades, Travel, Settings, Invite).
SHOP, STORE and MENU appear as the tutorial goes on.

### Studio-only test helpers (never in the live game)
- Every animal is free and you start with 2,000,000 test coins while saving is off (`Config/init.luau` → `Dev`).
- The Store shows a purple **TEST** button on every Robux item and every event.
- **Promo Kit:** **F7** opens a panel to start bosses and events, force Shiny/Golden, unlock every animal and
  set sunset/day/night. **F8** hides the UI for filming.

## Playtest checklist (the Oct 7 changes)
Play once with a fresh save (saving is off in Studio, so every Play is fresh).
- [ ] You're smaller than before (60%) and the animals feel big. Anything look odd, too big or clipping?
- [ ] Machines round the plaza: buy the Stamp Machine (level 2), drop parcels in, collect them, see "Parcels
      ready!" if you walked away, and the stamps on the mail receipt.
- [ ] Coins per minute under your coins goes up when you level.
- [ ] Each island's egg stand: the sign is readable, hatching pops an animal next to you, the toast shows its rarity.
- [ ] Rarity shows as a second line on wild animals' name tags and on the Bag → Collection cards.
- [ ] Rebirth at chute level 20: Rebirth Points, then buy a Tool.
- [ ] On a phone size (**Test → Device**): nothing overlaps the thumbstick or jump button.
- [ ] Anything that looks wrong: tell me what and where (a screenshot helps).

## Sounds
Every sound effect and music track has a slot in `src/shared/Config/Sounds.luau`, filled with free sounds
from Roblox's library (the vine boom is a real one now). `docs/SOUNDS_TO_REPLACE.md` lists which ones most
need replacing. To swap one:
1. In Studio, open **Toolbox → Marketplace → Audio**, search for the sound, and pick one you're allowed to use
   (or upload your own in the Creator Dashboard).
2. Right-click it → **Copy Asset ID**.
3. Paste it into the slot, e.g. `Pop = { Id = "rbxassetid://THE_ID", Volume = 1, ... }`.

## Saving (DataStores)
Progress saves automatically: every 60 seconds, when you leave, and when a server shuts down. Two servers can
never write the same save (session locking).
- **In Studio**, saving only works once **Game Settings → Security → Enable Studio Access to API Services**
  is on. Until then the game still runs, but the HUD shows "⚠ Progress isn't saving".
- Saves are in `PlayerData_launch1` (fresh for launch on 2026-10-06). Changing `StoreName` in
  `Config/Progression.luau` wipes **everyone's** progress, so only do it on purpose.
- Economy sheet: `python tools/economy_sheet.py` writes `docs/economy.csv` from the real config numbers.

## Adding your Blender models
Models live in [`art/`](art/README.md): `.blend` sources, `.fbx` exports and preview renders. The full list
is `art/MODEL_LIST.md`. In Studio they go in folders in **ReplicatedStorage** (Rojo leaves them alone), each
named exactly like its `.fbx` file:

| Folder | What goes there |
|---|---|
| `AnimalModels` | All 25 animals + `Gruff` |
| `BoxModels` | `Cardboard`, `Wood`, `Steel`, `Vault` |
| `PropModels` | `Parcel`, the chutes, `GruffHat`, `BossCrown`, `Egg`, `Envelope`, shop tools, `TapeRoll`, `RubberStamp` |
| `MapModels` | Town pieces, island props and the scenery pack (trees, windmill, lighthouse, igloo, cottage...) |

A missing model is never a problem: that spot keeps its grey block.

**For each model:**
1. **Home → Import 3D** → pick the file in `art/export/`.
2. Keep it as **one Model** with its parts. It looks grey in Studio; the game paints it from `src/shared/ArtColors/`.
3. Click **Import**, drag the Model into its folder, and check its **name matches the file** exactly.
4. Save (Ctrl+S), then run `lune run tools/check_models.luau MailATiger.rbxl`: it lists missing models,
   models in the wrong folder, and any that face backwards. **Facing backwards?** Add a Number attribute
   `YawOffset` = `180` to the Model.

## Launch checklist (things only you can do)
**The game is public.** Done: Robux items created and both passes on sale, icon sheets uploaded, the vine
boom, 5 badges, fresh launch saves, maturity questionnaire passed, store page set up.
1. **Thumbnails:** Creator Dashboard → Mail a Tiger → Places / Configure → upload them from `art/marketing/final/`.
2. **Last 3 badges (optional, they cost Robux):** Chaos Courier, Reborn, Boss Hunter (names and descriptions
   in `Config/Badges.luau`). Send me the ids if you make them.
3. Optional: private servers price, a Roblox group (`GroupId` in `Config/Monetization.luau`, +10% coins for
   members), new codes in `Config/Codes.luau` (`LAUNCH` and `GRUFF` exist).
4. Watch **Analytics → Onboarding funnel** to see where new players drop off. Promo posts:
   `docs/PROMO_POSTS.md`; ad plan: `docs/AD_PLAN.md`.

> Since the game is live, code changes reach players only when you **publish** from Studio
> (**File → Publish to Roblox**) after testing.

## Handy commands
```
rojo serve                     # live-sync to Studio
selene src                     # lint
stylua src                     # format everything
lune run tests/run.luau        # ~1,200 automatic checks on the Config files and box math (seconds, no Studio)
lune run tools/check_models.luau MailATiger.rbxl   # after Ctrl+S in Studio: are all models imported correctly?
# These open their own temporary Studio: save and CLOSE your Studio first
bash tools/smoke/run.sh        # quick boot test with your models
bash tools/e2e/run.sh          # full automated playtest (a few minutes)
bash tools/devices/run.sh      # phone/tablet layout check, pictures in tools/devices/out/
bash tools/photo/run.sh        # photo tour, pictures in tools/photo/out/
```
**Never** run `rojo build -o MailATiger.rbxl` unless you've lost the file: it replaces your place file,
including every model you imported.
