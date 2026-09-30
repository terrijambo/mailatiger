# Handoff: finish the launch of Mail a Tiger

For the next coding agent (Codex). Written 2026-09-30. Read this, then `README.md` (how the game works, checklists) and `ROADMAP.md` (every design decision, with the reasons).

## The owner
- A beginner. Explain things in plain words, and give them numbered steps for anything they have to click.
- Likes to choose from a few concrete options. Decide small things yourself and log them in `ROADMAP.md` → Decisions.
- Their Roblox account, Studio and Creator Dashboard are theirs. Anything public, anything that spends Robux, and legal or rating answers (the maturity questionnaire) are theirs to do: give them the steps.

## The project
- A Roblox game, synced with **Rojo 7.7**. `src/` is the source of truth; Studio gets it through a live `rojo serve` (port 34872).
- Luau with `--!strict` everywhere. Formatting: StyLua. Linting: selene.
- `src/server/`: server-authoritative services, started from `init.server.luau`. Client→server remotes go through `Remotes.Listen(remote, perSecond, handler)`, which rate-limits them. Validate every argument.
- `src/client/`: UI and effects, started from `init.client.luau`. The UI kit is `Ui.luau`; windows are registered in `Menus.luau`.
- `src/shared/Config/`: **all tunable content and numbers** (animals, zones, levels, quests, trolls, diamonds, sounds, icons, Robux items, badges). Change numbers there, not in gameplay code.
- The player's save is `DataService.Profile`. It's copied to the client as the JSON `Profile` attribute (read with `client/Profile.luau`). A new field goes in: the `Profile` type, `newProfile()` (DataService), and the client `Data` type + `EMPTY`.
- `DataService.Loaded` hands handlers a **copy** (BindableEvent). Use `DataService.Get(player)` to change a save.

## Checks (run all of them before every commit)
```bash
export PATH="$HOME/.rokit/bin:$PATH"
stylua src
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --platform=roblox --definitions=<globalTypes.d.luau> --sourcemap=sourcemap.json src
selene src
rojo build -o "$TEMP/check.rbxl"
lune run tests/run.luau        # 708 checks, all passing
```
- For `globalTypes.d.luau`, download it from the luau-lsp repo (`scripts/globalTypes.d.luau`). It was kept at `C:/Users/Owner/AppData/Local/Temp/claude/luau-types/`.
- **Never** `rojo build` into `MailATiger.rbxl`. That's the owner's place file, with their models in it.
- **Automated playtest:** `bash tools/e2e/run.sh` opens a throwaway Studio and plays the whole game. It refuses to run while the owner's Studio is open; ask them to close it. `tools/smoke/run.sh` is a quicker boot test.
- On Windows Git Bash, heredocs with apostrophes break. Write files with a file tool instead.

## State right now
- All game systems are done and committed: catch → box → mail; the shop; orders; levels/XP with zones that open by level; a 27-step quest line; troll items (coins only, and they only hit Chaos Mode players); the inventory; diamonds with 7 permanent upgrades; the 2x Coins Server Boost; the Robux Store; daily paycheck; codes; badges; leaderboards; the tutorial.
- The game is **published** as "Mail a Tiger" (still private). Robux ids are in `Config/Monetization.luau`: 2 passes and 10 developer products.
- **Not verified yet:** the automated playtest hasn't run since progression, diamonds and the boost were added (the owner's Studio was open). **Run it first** and fix any failures. Its steps are in `tools/e2e/client.lua`, and each step logs PASS or FAIL.

## Your tasks

### A. Code (yours)
1. **Run `bash tools/e2e/run.sh`** once the owner closes Studio. Fix anything that fails. New steps to watch: the zone lock refusal, the level-25 jump, the Banana Peel purchase and use, the server boost, the diamond pack, and Golden Paws.
2. **UI images:** the owner will send image ids. Paste each one into `src/shared/Config/Icons.luau` as `Image = "rbxassetid://ID"`, keeping the key (the emoji stays as a fallback). The keys and what each picture is are in `docs/UI_IMAGES.md`. After pasting, check them in Play: side buttons, HUD, Store, Upgrades, Inventory, Pen and Orders.
3. **Badge ids:** paste them into `src/shared/Config/Badges.luau` (0 means off).
4. **Sound ids:** paste them into `src/shared/Config/Sounds.luau`. Which ones to replace first is in `docs/SOUNDS_TO_REPLACE.md`.
5. After each batch: run the checks, commit, and tell the owner to press Play in Studio (Rojo syncs it live).

### B. Owner's steps (give them these; you can't do them)
1. **Saving:** Studio → File → Game Settings → Security → turn on *Enable Studio Access to API Services*. Test: Play, earn, Stop, Play again, and progress should be kept. When saving works, the free 2M Studio test coins no longer appear.
2. **Put both passes on sale:** Creator Dashboard → Mail a Tiger → Monetization → Passes → each pass → Sales. VIP Postie 149, Big Mail Bag 99. Both are Offsale right now.
3. **Badges:** Dashboard → Mail a Tiger → Engagement → Badges (older layout: Associated Items → Badges). There are 7; names and descriptions are in `Config/Badges.luau`. Badges past the daily free limit cost Robux.
4. **Maturity questionnaire:** Dashboard → Experience Questionnaire. It's required before going public. Cartoon slapstick, no blood; players can shove each other in the opt-in Chaos Mode.
5. **Store page:** paste the description (below), set the icon and thumbnails (drafts in `art/marketing/`), Genre Simulation, max players 12–16.
6. **Go public:** use the Private switch on the experience. Optionally run sponsored ads (they spend the owner's Robux, so the owner sets them up).

Game description (under Roblox's 1,000-character limit):
```
Postmaster Gruff has one job for you: catch animals, stuff them in a box, and mail them. They do NOT want to be mailed.

🐹 CATCH: chase hamsters, goats, penguins, crocodiles, tigers and more across the Backyard, Barn, Jungle, Ice Rink and Rooftop.
📦 BOX: pet their happy spots, avoid the angry ones, and tape the box shut before they explode out and launch you across town. RETURN TO SENDER!
📮 MAIL: fire parcels down the chute and get paid.

⭐ Level up to open new zones
📜 Finish Gruff's quests and side orders
💎 Earn diamonds for permanent upgrades
🛒 Upgrade your boxes, tools, stamps and mail chute
🔄 Rebirth for bigger payouts
🔥 Turn on Chaos Mode: +50% pay, but other players can shove you, spook your animal, and hit you with banana peels and stink bombs

Can you mail a tiger? 🐯

👍 Like and ⭐ Favorite for updates!
```

## Rules to keep
- No random crates or loot boxes. **Nothing sold for Robux, and no diamond upgrade, helps in Chaos Mode fights** (shove, spook, speed, trolls). Troll items are coins-only.
- Studio-only helpers must stay Studio-only: `Config.Dev.*`, the Store's TEST buttons (`ShopAction "StudioBuy"`, which checks `RunService:IsStudio()`), and the E2E scripts (which only run in a place marked with the `MailATigerTestPlace` attribute).
- Robux receipts: `MonetizationService.processReceipt` records the purchase id in the save before returning `PurchaseGranted`. Keep it that way, so a purchase is never granted twice or charged for nothing.
- Popups stay short (at most 2 waiting). Numbers display through `Format.Short` (1k, 1M).
- Log new decisions in `ROADMAP.md`, and commit after each working piece.
