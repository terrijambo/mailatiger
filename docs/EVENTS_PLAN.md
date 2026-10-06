# Events plan: a small event every 10 minutes, a boss every hour

**Status: built (2026-10-06).** Phases A–D and most of E are in: the clock schedule and banner, all 7 small events, and the hourly boss (Mega Tiger, King Yeti and Mama Dragon in turn) with pin it, box it, rewards, a crown for the top helper and a Boss Hunter badge slot. Not built yet: Phase 3 "mail it" (pushing the giant parcel to the chute) and a Boss Hunters leaderboard. Numbers to tune are in `src/shared/Config/Events.luau`. In Studio, the Store has purple TEST buttons that start any event right away.

## The rhythm

| When (server clock) | What | Lasts |
|---|---|---|
| :10, :20, :30, :40, :50 | a **small event**, picked at random (never the same twice in a row) | 2–3 min |
| :00 (on the hour) | **THE BIG ONE**: a boss fight for the whole server | 6–8 min |

- Every event is announced **30 seconds early** with a countdown banner at the top of the screen, and a sound.
- While it runs, a banner shows its name, a timer, and what to do ("🌟 GOLDEN HOUR: Shiny ×5 · 2:41").
- Times follow the real clock, so every server runs the same event at the same time. "The boss is at 7:00" becomes something players plan around and tell friends about.
- Events stack with the Robux server boost and with each other's rewards.
- Players can join any event at any level; rewards scale with their best animal, like orders do.

## Small events (the pool)

| Event | What happens | Why it's fun | Effort |
|---|---|---|---|
| 🌟 **Golden Hour** | Shiny/Golden odds ×5 for 3 min | everyone rushes to start jobs; announcements fly | tiny (the odds hook is already built) |
| ⚡ **Double XP** | 2× XP for 3 min | quick level-ups | tiny |
| 🩹 **Speed Tape** | animals get angry half as fast; 5-stamp jobs pay +50% | easy streaks and perfect jobs | small |
| 📮 **Rush Order** | Gruff posts one animal. The first 3 to mail it win diamonds (5/3/2) and coins, with a live top-3 on screen | a race, with names shown to the whole server | small |
| 🪙 **Coin Rain** | coins and a few diamonds rain over the plaza and arenas for 60 s; walk over them to collect | everyone runs around grabbing loot | medium |
| 📦 **Mystery Parcel** | a glowing parcel lands somewhere on the map, shown with a compass arrow. The first to grab it and mail it wins a prize (diamonds, boost minutes or stamps). Chaos players can shove the carrier | a server-wide chase | medium |
| 🐹 **Stampede** | 20 wild hamsters and bunnies run through town. Grab one with a quick press for instant coins and XP, no boxing | chaotic fun; great for new players | medium |

## THE BIG ONE: the hourly boss

A giant animal (rotating each hour: **Mega Tiger**, **King Yeti**, **Mama Dragon**) crashes into a boss arena next to town. The whole server works together to **catch it, box it and mail it**: the normal game, but huge.

**5:00 before:** a warning banner. A BOSS ARENA travel pad lights up in the plaza.

**Phase 1, PIN IT (about 2 min).**
- The boss stomps around the arena. It has glowing rope handles on its sides.
- Players grab handles with the usual hold-E. The boss is pinned only when enough handles are held at once (half the players there, 2 to 6).
- It fights back:
  - stomp shockwaves (jump over them, or get flattened for 2 seconds);
  - a roar that throws everyone back;
  - it kicks crates across the arena.

**Phase 2, BOX IT (about 2–3 min).**
- A giant box slams down. Everyone gets the BOX screen at once, sharing one anger meter and one huge box with about 20 seams spread across all players.
- Petters keep the anger down while tapers seal it, with live "17 / 20 sealed" progress.
- The boss rages at 50% and 80% (anger spikes).
- If the anger hits 100: a **MEGA VINE BOOM** launches everyone into the sky and you're back to Phase 1 with less time.

**Phase 3, MAIL IT (later version).** The giant parcel has to be pushed down the boulevard to the chute while it wobbles and tries to escape. This is a fun extra, but not needed for the first version.

**Rewards** are based on how much each player helped (handles held, seams taped, pets):
- 10–30 diamonds and coins worth about 20 jobs, plus a guaranteed Shiny on your next job.
- **Top helper:** a golden crown over their head until the next boss, and their name on a "Boss Hunters" board.
- **Win or lose:** the boss counts in a boss collection (in the Bag) and toward a "Boss Hunter" badge.

**If time runs out:** Gruff stamps the boss RETURN TO SENDER and everyone gets a small consolation reward.

## How it fits the code we have

- One new server module, **EventService**, runs the schedule from the clock and sets Workspace attributes (`EventId`, `EventEndsAt`, plus the event's settings) that the client banner reads.
- Golden Hour uses the `VariantLuck` hook that already exists. Double XP and Speed Tape are multipliers in `ProgressionService.AddXP` and the boxing anger code.
- Rush Order and Mystery Parcel reuse the mail chute, and Stampede reuses the catch AI with tiny animals.
- The boss reuses the catch AI (scaled up), the BOX screen (a shared mode), the launch, the vine boom and your Blender animal models at 6× size, so no new art is needed to start.

## Build order

| Phase | What | Size |
|---|---|---|
| A | Schedule, banner and countdown, plus Golden Hour, Double XP and Speed Tape | 1 session |
| B | Rush Order, Coin Rain, Mystery Parcel | 1 session |
| C | Stampede | ½ session |
| D | Boss v1: Mega Tiger, pin it, box it, rewards | 2 sessions |
| E | Boss rotation (Yeti, Dragon), crowns, Boss Hunters board, badge, Phase 3 "mail it" | 1–2 sessions |

## Decisions for you

1. **Timing:** a small event every 10 minutes and the boss on the hour, as you asked. Small events last about 3 minutes, so roughly a third of playtime has an event running. Too much or about right?
2. **Private servers:** run events there too? I'd say yes, since they're fun even with friends only.
3. **Boss difficulty with few players:** I'd scale handles needed and seam count to the number of players in the arena, so even 2 players can win.
4. **Start with Phase A?** It's quick and makes every 10 minutes feel different straight away.
