# Boss fights: making them look as good as they play

**Status (2026-10-06): Phases 1–5 built**, plus the Phase 6 sound slots (borrowing other sounds until you pick real ones; see `docs/SOUNDS_TO_REPLACE.md`). The optional art (a 3D crown, title cards, portraits) isn't in yet. The crown is still a text tag.

The boss fight works: pin it, box it, MEGA VINE BOOM, rewards. It looks plain, though: a scaled-up animal on a flat green island with yellow balls for handles. This roadmap turns it into the moment players screenshot and come back for every hour.

Nothing here changes the rules. It's all looks, sound and camera. Each phase is shippable on its own.

## Phase 1: the arena (one session, code only)

The flat island becomes a **postal arena**.

- **A stadium bowl:** stepped stands around the edge in post-office red and blue, with giant stamp-shaped banners (MEGA TIGER / KING YETI / MAMA DRAGON) and a scoreboard over the entrance showing the timer, pin bar and seams.
- **A themed floor per boss:**
  - Tiger: jungle ruins, vines, cracked stone.
  - Yeti: an ice rink floor with snow drifts.
  - Dragon: a volcanic rock floor with glowing lava cracks.
  - Swapped in when the boss lands, built from parts (no new art needed).
- **A crowd in the stands:** rows of little postal-worker NPCs (simple block figures) that cheer and wave. They go wild on a win and boo a MEGA VINE BOOM.
- **Lighting and sky** change for the fight: the sky darkens, a coloured rim light matches the boss, and fog closes in outside the arena.
- **Floodlights** on tall posts sweep across the floor.
- **A better entrance:** a glowing red archway pad replaces the flat plaza pad, with a ⚔️ countdown over it.

## Phase 2: the boss itself (one session, code only)

- **An entrance cinematic (about 4 seconds):** the boss arrives in a giant falling parcel that slams into the arena. The box bursts open in a dust cloud, the camera shakes, and a big **title card** slides in (name and "THE BIG ONE"). Players who join late skip it.
- **An aura:** a coloured glow and slow particle swirl (embers for the Dragon, snowflakes for the Yeti, leaves for the Tiger), plus a crown floating over its head.
- **Real ropes:** glowing **rope beams** from each handle to the hands of whoever holds it. When enough people hold on, the ropes turn gold and tighten. Handles become little golden rings, not balls.
- **Pinning feels physical:** the boss leans and strains against the ropes, its walk slows down, and the ground under it cracks. When it's fully pinned it drops flat with a THUD and a dust ring.
- **Rage looks:** the boss's colour pulses red, steam puffs from its head, and its eyes glow.

## Phase 3: attacks and hits (one session, code only)

- **Stomp:** the red warning ring becomes a proper shockwave: a dust ring racing outward, cracks left behind for a few seconds, and players who get hit spinning and bouncing (the comic ragdoll you already have).
- **Roar:** a visible pulse sphere, nearby grass and props blown flat, a short camera zoom on the boss, and the screen-edge blur you already have.
- **Kicked crates:** crates fly across the arena with a whoosh. Getting hit is a small bonk. They're also good cover from roars.
- **Hit numbers:** "+HELP" pops over a player's head when they help a lot (a long rope hold, a full seam), to show who's carrying.

## Phase 4: BOX IT on the big screen (one session, code only)

- **A giant 3D box drops from the sky** over the pinned boss, and the camera swings to frame it while the shared BOX screen opens.
- **A boss-themed BOX screen:** a heavier border, a boss portrait instead of the regular animal, a team progress bar, and live **"Name taped a seam!"** callouts.
- **The 3D box in the world** gets strips of tape as seams finish, so players who aren't boxing can watch it happen.
- **The finish:** the lid slams shut, a giant **SEALED!** stamp hits the box in 3D, and it's launched into the sky like a firework that bursts into confetti and coins raining on the arena.
- **MEGA VINE BOOM** gets the big version: everyone flies out of the arena in slow motion with the bass boom and lands back on the island. A screen-wide "RETURN TO SENDER" stamp shows.

## Phase 5: rewards and bragging (half a session)

- **A victory screen** listing the top 3 helpers with their avatars (headshot thumbnails), their share, and their rewards.
- The **Boss Hunter crown** becomes a real 3D crown model on the head, not a text tag. It needs a Blender model; see below.
- A **Boss Hunters leaderboard** in the plaza (most bosses beaten this week).
- A **boss collection** in the Bag: a card for each boss beaten, with the date and your share.

## Phase 6: sound and music (needs your audio ids)

| Slot | Plays | Look for |
|---|---|---|
| `BossMusic` | while a boss fight runs | epic, silly orchestra or drums (loops) |
| `BossLand` | the parcel slams down | huge crash, crate smash |
| `BossStomp` | each stomp | heavy thud, earth rumble |
| `BossRoar` per boss | roars | lion roar, yeti howl, dragon screech |
| `BossWin` | the box launches into the sky | fanfare and fireworks |
| `CrowdCheer` / `CrowdBoo` | the stands react | stadium cheer, comedic boo |

## Art that would help (optional; the phases above work without it)

| Item | For | Who |
|---|---|---|
| a 3D crown (low poly, gold) | the Boss Hunter crown | Blender |
| a giant parcel and lid | the entrance and the BOX IT drop | Blender (or I build it from parts) |
| 3 title cards (1024×512 PNG): MEGA TIGER, KING YETI, MAMA DRAGON | the entrance card | Codex / an image tool |
| a boss portrait per boss (512×512) | the BOX screen and the victory screen | Codex / an image tool |
| arena banner art (stamp-style, 1024×256) | arena banners | Codex / an image tool |

## Performance budget (phones)

- Crowds are simple block figures (about 40, animated on each player's own device, not the server).
- Particles are capped and turned down on phones (the existing `Ui.compact` check, plus Roblox's quality level).
- Arena dressing is only built while a boss is coming or on, then removed.

## Suggested order

| Phase | What | Session size |
|---|---|---|
| 1 | Arena: stands, themed floors, crowd, lighting, entrance arch | 1 |
| 2 | Entrance cinematic, title card, aura, rope beams, pin effects | 1 |
| 3 | Stomp and roar effects, flying crates, help pops | 1 |
| 4 | Giant 3D box, boss BOX screen, SEALED launch finale, big MEGA VINE BOOM | 1 |
| 5 | Victory screen, Boss Hunters board, boss collection | ½ |
| 6 | Sounds and music, once you've picked ids | small |

I'd start with **Phase 2** (entrance and ropes). It's the biggest wow per hour of work, and it improves every fight right away. **Phase 1** (the arena) comes next.
