# Mail a Tiger

Box up increasingly wild animals and carry them to the Post Office before the box breaks. Postmaster Gruff is watching.

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
    Config/     all tunable numbers: animals, boxes, stamps, routes
  server/   → ServerScriptService.Server    trusted game logic (coins, damage, saving)
  client/   → StarterPlayerScripts.Client   UI, camera, input, effects
```

## Phase 1 playtest checklist
Press Play and try each one. Every number mentioned lives in `src/shared/Config/Carry.luau`.
- [ ] Gruff greets you. Walk to the **Animal Pen** counter and hold **E** to box a hamster.
- [ ] The box floats in front of you and sways when you turn. Does the wobble feel good, too floppy, or too stiff? (`PositionResponsiveness`, `RotationResponsiveness`)
- [ ] Walk over the speed bumps, jump a few times and bump a wall. Does the box HP drop a fair amount? (`ImpactThreshold`, `DamagePerSpeed`)
- [ ] Rage rises. Past 70 the box rattles and the camera shakes.
- [ ] Get past the potholes, the plank bridge, the two spinning sweepers and the hill.
- [ ] The bell dings at the Post Office door and rage jumps.
- [ ] Drop off inside the green zone. You get a stamp rating from Gruff and coins.
- [ ] Break a box on purpose (the sweepers are good for this). The hamster escapes, hops around, and you can hold **E** to catch it for half pay.

## Phase 2 playtest checklist
In Studio every animal is free (set in `Config/init.luau`, under `Dev`). Walk to the Animal Pen, hold **E**, and pick an animal. Behavior numbers live in `src/shared/Config/Behaviors.luau`.
- [ ] The Pen menu opens, shows all 26 animals, and the co-op ones are greyed out.
- [ ] **Goldfish:** spin in circles and the water sloshes (rage and damage).
- [ ] **Chicken:** stay calm for 10s and it lays an egg (+bonus shown on the receipt).
- [ ] **Skunk:** let rage pass 60 and your screen goes green and blurry.
- [ ] **Kangaroo / Goat / Crocodile:** the box hops, lurches forward, or lunges sideways by itself.
- [ ] **Bear:** walk gently for 15s and it falls asleep (you get slower). Bump something and it wakes up angry.
- [ ] **Giraffe:** tall box. Hold **C** to duck under the LOW CLEARANCE signs.
- [ ] **Tiger:** reach the door at 100 rage, and about half the time you get RETURN TO SENDER and Gruff's hat flies off.
- [ ] **Dragon / Alien / Yeti / Unicorn:** burning box / floating box / ice trail / rainbow trail.
- [ ] Two-player test (**Test → Clients and Servers → 2 players**): the tiger's roar stuns the other player, yeti ice freezes them, and unicorn rainbows speed them up.

## Adding your Blender models
1. Import your model in Studio (**Home → Import 3D**) and name the Model after the animal's Id, e.g. `Hamster`.
2. In Explorer, create a Folder named `AnimalModels` inside **ReplicatedStorage**, and put the model in it.
3. Escaped animals now use your model instead of a colored ball. (Rojo leaves this folder alone.)

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
