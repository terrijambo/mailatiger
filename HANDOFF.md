# Handoff: Mail a Tiger

For the next coding agent. **Updated 2026-10-07** (after the wild-animals, Post Office machines, rarities and
eggs redesign). Read this, then `README.md` (how the game plays today, controls, owner checklists) and
`ROADMAP.md` → **Decisions** and **Post Office Machines** (the reasons behind the design).

> `ROADMAP.md` is a history log: its Phase 1–5 sections still describe the old Pen / arenas / travel pads /
> co-op crews. Where it disagrees with this file, the newest dated entry (and `git log`) wins.

## The owner
- A beginner. Explain things in plain words, and give numbered steps for anything they have to click.
- Likes to choose from a few concrete options. Decide small things yourself and log them in `ROADMAP.md` → Decisions.
- Their Roblox account, Studio and Creator Dashboard are theirs. Anything public, anything that spends Robux,
  and legal or rating answers (the maturity questionnaire) are theirs to do: give them the steps.

## The game in one paragraph
Islands round a town plaza, each with **wild animals** roaming (4 per island). Walk up and **hold E** to grab
one, which opens the **BOX** screen: rub the ♥ spots to keep ANGER down while you drag tape along every seam.
Anger 100 = **VINE BOOM** (ragdoll launch, the animal runs off). A taped box becomes a **parcel** in your bag.
Drop parcels into your **Post Office machines** round the plaza (hold E, wait, collect) to stamp them; each
stamp multiplies that parcel's XP. **Mail** them at Gruff's chute for XP and a 30% coin tip. XP raises your
**chute level**, which *is* your player level: it opens islands, unlocks machines, and sets the coins per
minute the chute pays you. Rebirth at chute level 20. On top: rarities and eggs, Shiny/Golden variants,
quests/orders/challenges, diamonds, events every 10 minutes and an hourly co-op boss, and opt-in Chaos Mode PvP.

## The project
- A Roblox game synced with **Rojo 7.7**. `src/` is the source of truth; Studio gets it through a live
  `rojo serve` (port 34872). Tools are pinned in `rokit.toml` (Rojo, selene, StyLua, luau-lsp, lune).
- Luau with `--!strict` everywhere. Formatting: StyLua. Linting: selene.
- `src/server/`: server-authoritative services, started from `init.server.luau`. Client→server remotes go
  through `Remotes.Listen(remote, perSecond, handler)`, which rate-limits them. Validate every argument.
- `src/client/`: UI and effects, started from `init.client.luau`. The UI kit is `Ui.luau`; windows are
  registered in `Menus.luau`; the left-side buttons are in `SideButtons.luau`.
- `src/shared/Config/`: **all tunable content and numbers**. Change numbers there, not in gameplay code.
- The player's save is `DataService.Profile` (DataStore `PlayerData_launch1`, session-locked). It's copied to
  the client as the JSON `Profile` attribute (read with `client/Profile.luau`). A new field goes in: the
  `Profile` type, `newProfile()` (DataService), and the client `Data` type + `EMPTY`.
- `DataService.Loaded` hands handlers a **copy** (BindableEvent). Use `DataService.Get(player)` to change a save.
- The map is built by code (`server/MapBuilder.luau`, scenery in `server/Scenery/`); Blender models from
  the owner's place file are laid over the grey blocks. Models live only in `MailATiger.rbxl` (untracked).
- No git remote: the repo is local only. Commit after each working piece.

### Where the main systems live
| System | Server | Client | Config |
|---|---|---|---|
| Wild animals, grabbing, lures | `WildService`, `CatchAI` | `WildTags` | `Wild`, `Animals`, `Rarity`, `Variants` |
| BOX stage | `BoxingService` | `BoxingScreen` | `Boxing`, `Boxes`, `Stamps`, `shared/BoxMath` |
| Parcels and mailing | `MailService`, `Economy` | `ChuteVisual` | `Mail` |
| Machines, chute level, rebirth | `MachineService`, `ProgressionService` | `MachineStations` | `Machines`, `Levels`, `Tools` |
| Eggs | `EggService` | (prompts on the stands) | `Eggs` |
| Travel / zone locks | `Travel` | `TravelMenu`, `ZoneLocks` | `Arenas`, `Levels.ZoneLevels`, `World` |
| Quests, orders, challenges | `Orders`, `ChallengeService`, `TutorialService` | `OrdersBoard`, `QuestText`, `Tutorial` | `Quests`, `Challenges` |
| Events and the hourly boss | `EventService`, `BossService`, `BossArena` | `EventBanner`, `BossLook` | `Events` |
| Dive | `DiveService` | `Dive` | `Dive` |
| Chaos Mode, trolls, shove | `TrollService` | `TrollBar`, `Effects` | `Social`, `Trolls` |
| Diamonds, Robux | `MonetizationService` | `DiamondUpgrades`, `Store` | `Diamonds`, `Monetization` |
| Leaderboards, invites, badges, codes, paycheck, streaks | `LeaderboardService`, `InviteService`, `Badges`, `CodesService`, `PaycheckService`, `StreakService` | `Settings` | `Social`, `Badges`, `Codes`, `Progression` |
| Studio-only filming panel | | `PromoKit` (F7 / F8) | |

## Checks (run all of them before every commit)
```bash
export PATH="$HOME/.rokit/bin:$PATH"
stylua src
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --platform=roblox --definitions=<globalTypes.d.luau> --sourcemap=sourcemap.json src
selene src
rojo build -o "$TEMP/check.rbxl"
lune run tests/run.luau        # 1,177 checks, all passing on 2026-10-07
```
- `globalTypes.d.luau`: download it from the luau-lsp repo (`scripts/globalTypes.d.luau`). It was kept at
  `C:/Users/Owner/AppData/Local/Temp/claude/luau-types/`.
- **Never** `rojo build` into `MailATiger.rbxl`. That's the owner's place file, with their models in it.
- On Windows Git Bash, heredocs with apostrophes break. Write files with a file tool instead.

### Studio tests (each opens its own throwaway Studio; the owner's Studio must be closed, and they should Ctrl+S first)
| Command | What it does |
|---|---|
| `bash tools/e2e/run.sh` | Full automated playtest (`tools/e2e/client.lua`): grab, box, mail, machines, eggs, shop, codes, dive, events, the boss. Each step logs PASS/FAIL. Last recorded full pass: **98/98 on 2026-10-06** |
| `bash tools/smoke/run.sh` | Quick boot test: builds the real map with the owner's models and loads every module |
| `bash tools/devices/run.sh` | Shrinks the test Studio from laptop to phone size; lists UI overlaps, off-screen UI and thumbstick/jump clashes, with pictures in `tools/devices/out/` |
| `bash tools/layout/run.sh` | Dumps the built map and draws `tools/layout/map.png`; flags things on roads, lamps on asphalt, overlaps |
| `bash tools/photo/run.sh` | Photo tour of the game (captures only the test Studio window) into `tools/photo/out/` |
| `lune run tools/check_models.luau MailATiger.rbxl` | Lists missing, misplaced or backwards models in the owner's saved place |

The E2E scripts only run in a place marked with the `MailATigerTestPlace` attribute, so they can never touch the real game.

## State right now (2026-10-07)
- **Published** as "Mail a Tiger", still **private**. Fresh launch data stores are already set
  (`PlayerData_launch1`, leaderboards `launch1`, referrals `Referrals_launch1`).
- **Filled in:** all Robux pass/product ids (`Config/Monetization.luau`), all 8 icon sheets
  (`Config/IconSheets.luau`), the real vine boom sound, 5 of 8 badge ids.
- **Built Oct 7 and not yet confirmed by a full playtest:** machines round the plaza (drop, wait, collect),
  chute level as the player level, coins per minute, rebirth points, rarities, egg stands, the 60% player
  scale with bigger animals, the Parcels tab in the Bag. The playtest steps for them exist; the run hasn't
  been reported passing.

## Your tasks
### A. Code (yours)
1. **Run `bash tools/e2e/run.sh`** (ask the owner to save and close Studio first). Fix whatever fails, then
   run `tools/devices/run.sh` for the phone layout.
2. **Badge ids:** paste the owner's ids into `src/shared/Config/Badges.luau` (0 = off). Missing: Chaos
   Courier, Reborn, Boss Hunter.
3. **Sound ids:** paste into `src/shared/Config/Sounds.luau`. What to replace first is in `docs/SOUNDS_TO_REPLACE.md`.
4. **Economy check after the machines rework:** `python tools/economy_sheet.py` → `docs/economy.csv`.
   Look for walls in the chute level curve and the time to the first rebirth.
5. `ROADMAP.md` Phases 1–5 still describe the retired Pen/arena/crew design; mark the retired parts when you
   touch them.
6. After each batch: run the checks, commit, and tell the owner to press Play in Studio (Rojo syncs it live).

### B. Owner's steps (give them these; you can't do them)
1. **Saving in Studio:** File → Game Settings → Security → turn on *Enable Studio Access to API Services*.
   Test: Play, earn, Stop, Play again; progress is kept, and the free 2M Studio test coins stop appearing.
2. **Passes on sale:** Creator Dashboard → Mail a Tiger → Monetization → Passes → each pass → Sales.
   VIP Postie 149, Big Mail Bag 99.
3. **Badges:** Dashboard → Mail a Tiger → Engagement → Badges. Create Chaos Courier, Reborn and Boss Hunter
   (names and descriptions in `Config/Badges.luau`) and send the ids.
4. **Maturity questionnaire:** Dashboard → Experience Questionnaire. Cartoon slapstick, no blood; players can
   shove each other in Chaos Mode.
5. **Store page:** paste the description (below), icon and thumbnails from `art/marketing/final/`,
   Genre Simulation, max players 12–16. Optional: private servers price, a Roblox group (`GroupId`).
6. **Go public:** Dashboard → Access → Public. Then watch Analytics → onboarding funnel. Promo posts are in
   `docs/PROMO_POSTS.md`, the ad plan in `docs/AD_PLAN.md`.

Game description (under Roblox's 1,000-character limit):
```
Postmaster Gruff has one job for you: grab wild animals, stuff them in a box, and mail them. They do NOT want to be mailed.

🐹 GRAB: hamsters, goats, penguins, crocodiles, tigers and dragons roam the islands. Hold E and they're yours.
📦 BOX: pet their happy spots, avoid the angry ones, and tape the box shut before they explode out and launch you across town. RETURN TO SENDER!
🏭 STAMP: run your parcels through Post Office machines for huge XP.
📮 MAIL: fire them down the chute and level up.

⭐ Level up your chute to open new islands
🥚 Hatch eggs for Rare, Mythic and Ethereal animals
👑 Team up every hour to box a giant boss
💎 Earn diamonds for permanent upgrades
🔄 Rebirth for bigger payouts
🔥 Chaos Mode: +50% pay, but other players can shove you, spook your animal, and hit you with banana peels

Can you mail a tiger? 🐯

👍 Like and ⭐ Favorite for updates!
```

## Rules to keep
- No random crates or loot boxes for Robux. Eggs cost **coins only**. **Nothing sold for Robux, and no
  diamond upgrade, helps in Chaos Mode fights** (shove, spook, speed, trolls). Troll items are coins-only.
- Studio-only helpers must stay Studio-only: `Config.Dev.*` (free animals, 2M test coins), the Store's TEST
  buttons (`ShopAction "StudioBuy"`, checks `RunService:IsStudio()`), the Promo Kit (F7/F8), and the E2E
  scripts (only in a place with the `MailATigerTestPlace` attribute).
- Robux receipts: `MonetizationService.processReceipt` records the purchase id in the save before returning
  `PurchaseGranted`. Keep it that way, so a purchase is never granted twice or charged for nothing.
- Don't change `StoreName` / `StoreVersion` again without the owner's say-so: that wipes real players now.
- Popups stay short (at most 2 waiting). Numbers display through `Format.Short` (1k, 1M).
- Every animal is solo now (no crews), except the hourly boss, which is the co-op moment.
- Log new decisions in `ROADMAP.md`, and commit after each working piece.
