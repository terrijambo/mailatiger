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
3. **STUFF:** press **SPACE** (or tap the big button) when the white marker is inside the green zone.
4. **TAPE:** mash **E / SPACE** to keep the red LID bar down until the TAPE bar is full.
5. The box flies into the mail chute and Gruff rates you from 1 to 5 stamps.
- Changed your mind? Use the Pen counter twice within 5 seconds to give up on the current animal.

## Playtest checklist
All the difficulty numbers live in `src/shared/Config/Boxing.luau`.
- [ ] **Hamster:** easy start to finish. Does it feel fun? Is corner-and-grab satisfying?
- [ ] **Stuff:** miss on purpose 3 times, and the animal escapes back into the arena.
- [ ] **Tape:** stop mashing, and the lid bursts and the animal escapes.
- [ ] **Bear:** it starts asleep. Walk up normally and it wakes and bolts. Sneak with **C** and you can grab it.
- [ ] **Goldfish / Pig / Penguin:** grabs sometimes slip. **Parrot / Monkey** fly out of reach. **Octopus** vanishes. **Alien / Unicorn** teleport.
- [ ] **Goat / Crocodile / Gorilla** charge and knock you back. **Skunk** sprays your screen. **Yeti** freezes you.
- [ ] **Chicken:** picking up its eggs adds bonus coins.
- [ ] **Tiger:** hard! Its roar stuns you, and if the lid bursts during Tape you get **RETURN TO SENDER** and Gruff's hat flies off.
- [ ] Two players (**Test → Clients and Servers → 2 players**): each player's animal ignores the other player, and you can't grab someone else's.

## Phase 3 checklist: shop, orders, rebirth
- [ ] **Supply Shop** (blue counter behind the Pen): buy the Wooden Crate. It's equipped, and during Tape the lid starts lower and the box is brown.
- [ ] Upgrade **Sneakers** and you run faster. Sneak with C, let go, and you're back to your upgraded speed.
- [ ] Upgrade **Gloves** / **Net**: grabbing is quicker, and works from farther away.
- [ ] Buy a **FRAGILE** stamp. The coins line says "Next job: FRAGILE". Box an animal and you only get 1 stuff miss, and the receipt shows FRAGILE with higher pay.
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

## Saving (DataStores)
Progress saves automatically: every 60 seconds, when you leave, and when a server shuts down.
- **In Studio**, saving only works once the place is published to Roblox **and** you turn on **Game Settings → Security → Enable Studio Access to API Services**. Until then the game still runs, but the HUD shows "⚠ Progress isn't saving".
- To **wipe everyone's data** (e.g. before launch), change `StoreName` in `Config/Progression.luau` to a new version like `PlayerData_v2`.
- Economy sheet: `python tools/economy_sheet.py` writes `docs/economy.csv` from the real config numbers. Re-run it whenever you change prices or payouts.

## Adding your Blender models
1. Import your model in Studio (**Home → Import 3D**) and name the Model after the animal's Id, e.g. `Hamster`.
2. In Explorer, create a Folder named `AnimalModels` inside **ReplicatedStorage**, and put the model in it.
3. The animal in the arena now uses your model instead of a colored ball. (Rojo leaves this folder alone.)

## Handy commands
```
rojo serve                     # live-sync to Studio
rojo build -o MailATiger.rbxl  # build a fresh place file
selene src                     # lint
stylua src                     # format everything
```

Type-check (catches misspelled Roblox API names). The VS Code Luau extension does this live, and every file starts with `--!strict`:
```
rojo sourcemap -o sourcemap.json
luau-lsp analyze --platform=roblox --definitions=<path to globalTypes.d.luau> --sourcemap=sourcemap.json src
```
