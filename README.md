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

## Handy commands
```
rojo serve                     # live-sync to Studio
rojo build -o MailATiger.rbxl  # build a fresh place file
selene src                     # lint
stylua src                     # format everything
```
