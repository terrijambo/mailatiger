# Analytics: what the game tracks

Everything below shows up in **Creator Dashboard → Mail a Tiger → Analytics** about a day after players do it.
Studio playtests are not counted. The code is `src/server/Analytics.luau` (server) and `src/client/Track.luau`
(what the player's screen reports).

**Fields.** Each event can carry up to 3 text fields (Field01, Field02, Field03 in the dashboard's
breakdown menu). They hold small sets of values, so every breakdown stays readable:

| Value looks like | Meaning |
|---|---|
| `D0`, `D1`, `D2-6`, `D7-29`, `D30+` | How long since the player first joined (D0 = their first day) |
| `L1-3`, `L4-7`, `L8-11`, `L12-17`, `L18+` | Chute level band |
| `D0\|L1-3` (a "segment") | Both of the above; `\|R` on the end = has rebirthed |
| `Touch`, `KeyboardMouse`, `Gamepad` | Device (from the player's screen) |
| `Guessed` | A player who was already playing before tracking started (Oct 12, 2026), so their "first join" is a guess |

**Value** is the number the dashboard adds up and averages (a count, seconds, or minutes; listed per event).

**Limits.** Roblox allows 100 custom event names per game. The game sends 53. Event names never contain ids
(the id goes in a field), so adding a new machine or animal never adds a name. The game also stays under
Roblox's per-server rate limit, and when a full server gets close it drops the nice-to-have events
(BOX stats, menus, zones, performance) before anything important.

## Where people leave (the friction events)

| Event | Value | Field01 | Field02 | Field03 | What it tells you |
|---|---|---|---|---|---|
| `SessionEnd` | minutes this visit | minutes bucket (`<1m`, `1-3m`...) | where they were (`Town`, an island, `BoxScreen`, `Menu_Store`...) | segment | How long visits last and where people are standing when they leave |
| `QuitAfter` | seconds since their last action | their last action (`Grabbed`, `VineBoomed`, `Blocked_MachineCoins`, `Menu_Shop`...) | `Active<30s` / `Quiet30s-2m` / `Quiet2-5m` / `Away5m+` | segment | What happened right before they quit. A pile of `VineBoomed` + `Active<30s` = rage quits |
| `QuitAt` | minutes this visit | `L{level}` | `Q{quest}` | `WithFriends` / `Solo` | The exact level and quest people stop at |
| `FirstSessionEnd` | minutes | furthest onboarding step | tutorial step on screen (`Tut_Wild`...) or `TutorialDone` | device | Brand-new players only: how far the first visit got |
| `Blocked` | 1 | reason (list below) | which item, machine or island | segment | Something they tried that didn't work. The most direct "this is annoying" signal |
| `WildAttack` | 1 | `Hit` / `Dodged` | attack kind (`Roar`, `Charge`...) | segment | How often wild animals knock players over |
| `WildBoom` | levels above the player | animal id | player's level band | | Grabbed an animal that was too strong and got launched to town |
| `Fell` | 1 | `Sea` / `Roof` | segment | | Fell off the map |
| `Chaos` | 1 | `Hit` / `Attack` | `Shove`, `Shove_MidBox`, a troll id... | segment | Chaos Mode griefing, from both sides |
| `SettingChanged` | 1 | setting (`Chaos`, `Music`...) | `On` / `Off` | segment | People turning Chaos Mode off is a sign it annoys them |
| `Perf` | frames per second | `FPS<20` ... `FPS58+` | `Ping<100` ... `Ping400+` | device | Lag. Sent every 2 minutes |
| `Device` | 1 | `Touch` / `KeyboardMouse` / `Gamepad` | screen `Small` / `Medium` / `Large` | segment | What people play on |

`Blocked` reasons: `MailEmptyBag`, `GrabBagFull`, `CollectBagFull`, `TooStrong`, `ZoneLocked`, `MachineLevel`,
`MachineCoins`, `MachineBusy`, `MachineBagEmpty`, `MachineAlreadyStamped`, `BoxCoins`, `StampCoins`,
`LureCoins`, `ToolPoints`, `ToolMaxed`, `UpgradeNotBought`, `RebirthLevel`, `RebirthCoins`, `MarketOffBeach`,
`EggLocked`, `EggTooStrong`, `EggCoins`.

## The first visit (onboarding funnel)

**Analytics → Funnels → Onboarding.** Brand-new players only, each step once:

1 Joined → 2 Spawned → 3 Moved → 4 ReachedIsland → 5 PickedAnimal → 6 Caught (BOX screen opened) →
7 FirstHeart → 8 FirstTape → 9 Taped → 10 Mailed → 11 TutorialDone

(Before Oct 12, 2026 this funnel had 6 steps with different numbers. Read it from the day this update went live.)

| Event | Value | Field01 | Field02 | Field03 |
|---|---|---|---|---|
| `OnboardingSeconds` | seconds since joining | the step | device | |
| `TutorialStepTime` | seconds spent on a walkthrough step | the step they left (`Pen`, `Wild`, `Catch`, `Escaped`, `Box`, `Mail`, `Shop`) | the step they moved to | device |
| `TutorialSkipped` | minutes played | the step they skipped at | device | |

## The core loop (funnels, every parcel)

**Analytics → Funnels**, two recurring funnels, one run per parcel:

- `CoreLoop`: 1 Grab → 2 Boxed → 3 Mailed
- `StampLoop`: 1 DroppedIn → 2 Collected → 3 MailedStamped

| Event | Value | Field01 | Field02 | Field03 |
|---|---|---|---|---|
| `WildGrab` | 1 | rarity | `Hard` / `Normal` | Shiny/Golden, or segment |
| `BoxEnd` | seconds on the BOX screen | outcome: `Taped`, `Launched`, `Cancelled` (`_Idle` added if they never touched anything) | rarity (`_Hard` if above their level) | device |
| `BoxStat` | the number | which: `Hearts`, `RedSpots`, `MaxAnger`, `SeamsOf5`..., `Peels`, `FirstTouchSeconds`, `Stars` | outcome | rarity\|device |
| `BoxAnimal` | seconds | animal id | outcome | level band |
| `Launched` | 1 | animal id | rarity | segment |
| `StampUsed` / `VariantFound` | 1 | stamp id / `Shiny` or `Golden` | | segment |
| `MachineDrop` | parcels dropped in | machine id | `Left{n}` parcels still in the bag | segment |
| `MachineCollect` | parcels collected | machine id | `All` / `BagFull` | segment |
| `MailTrip` | parcels mailed | `Chute` / `Rocket` | `Stamped{n}of{m}` | segment |

## Progress, rebirth and coming back

| Event | Value | Field01 | Field02 | Field03 |
|---|---|---|---|---|
| `SessionStart` | visit number | `S1`, `S2`... | `First`, `SameDay`, `Gap1d`, `Gap2d`, `Gap3-6d`... | segment |
| `ReturnDay` | days since first join | `D1`...`D7`, `D8-13`, `D14-29`... | different days played so far (`2days`...) | segment or `Guessed` |
| `Milestone` | minutes of total playtime it took | which first (list below) | `Tracked` / `Guessed` | days band |
| `LevelReached` | minutes of total playtime | `L{level}` | `R{rebirths}` | days band |
| `QuestReached` | minutes of total playtime | `Q{quest}` | level band | days band |
| `Rebirth` | rebirth number | days band | playtime (30-minute steps) | `R{n}` |
| `ZoneEnter` | minutes of total playtime | zone | segment | |
| `Claimed`, `DailyChallengeDone`, `WeeklyChallengeDone`, `AllDailiesDone`, `BossJoined`, `BossWon`, `BossLost`, `PaycheckStreak` | | | | |

Also **Analytics → Progression**: paths `ChuteLevel` and `Rebirth`.

`Milestone` ids: `FirstGrab`, `FirstBox`, `FirstFiveStars`, `FirstEscape`, `FirstMail`, `FirstStamp`,
`FirstStampedMail`, `FirstMachine`, `FirstEgg`, `FirstClaim`, `FirstChallenge`, `FirstDodge`, `FirstBoxUpgrade`,
`FirstTool`, `FirstUpgrade`, `FirstStoreOpen`, `FirstPurchase`, `Bought_{item}`, `FirstInviteSent`,
`FirstBossJoin`, `TutorialDone`, `Visit_{island}`, `Visit_Beach`, `Unlock_{island}`, `Rebirth{n}`.

## Money

- **Analytics → Economy**: two currencies, `Coins` and `RebirthPoints`, every source and every spend by item.
  (Level-up and quest coins are now included; before Oct 12, 2026 they were missing.)
- `Bought`: value 1 (or the level bought), Field01 `Machine` / `Box` / `Stamp` / `Tool` / `Upgrade` / `Lure` / `Egg`,
  Field02 which one.
- `RebirthPointsEarned`: value points, Field01 where from.

## Robux and the menus

| Event | Value | Field01 | Field02 | Field03 |
|---|---|---|---|---|
| `Menu` | 1 when opened; seconds when closed | window (`Shop`, `Market`, `Store`, `Inventory`, `Settings`) | `Opened` / `SecondsOpen` | segment |
| `PurchasePrompt` | 1 | item key | `Pass` / `Product` | segment |
| `PurchaseResult` | Robux price | `Pass_VIP`, `Product_ServerBoost`... | `Bought` / `Cancelled` | how long the prompt was up (`<3s`...) |
| `FollowPrompt` | 1 | `Shown`, `Favorite`, `Updates`, `Close`, `Favorite_Success`... | segment | |
| `Invite` | 1 (opened) or friends invited (sent) | `Opened` / `Sent` | segment | |

The store funnel: `Menu` (Store, Opened) → `PurchasePrompt` → `PurchaseResult` Bought.

## Checking it works

1. In Studio, set the Workspace attribute `AnalyticsDebug` to true, then press Play. Every event prints in the
   Output window (Roblox ignores Studio events, so this is the only way to see them there).
2. After publishing, play one visit on the live game and check **Analytics → Custom Events** the next day.

## Save fields added for this (additive; nothing is reset)

`FirstJoin`, `FirstJoinGuessed`, `LastJoin`, `LastDay`, `DaysPlayed`, `Sessions`, `PlaySeconds`, `Milestones`,
and `Loop` on each parcel. Older saves start counting on their next join.
