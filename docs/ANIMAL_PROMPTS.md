# Animal prompts (Roblox Studio's AI mesh generator)

How the animals were made (decided 2026-10-20, docs/ASSET_PLAN.md section 4): Roblox Studio's built-in mesh generator
(the Assistant's "generate mesh"), free, one animal at a time, split into named parts so the game can animate them.
To remake one, run the same prompt with the same part names and size, then install it like the others (below).

Every prompt follows one template so the set matches:

> A cute (chubby) chibi cartoon **<animal>**, stylized like a premium mobile game toy: **<its look>**, big glossy black
> eyes with white highlights, soft rounded shapes, simple flat colors, no realistic fur.

Settings: about 6,000 triangles (8,000 for big animals), segmentation "explicit" with the part names below.

Lessons from tier 1:
- Add "like a collectible toy figure" (and "sitting upright" or "standing") so the animal comes out posed, not lying flat.
- Name the parts the game animates: ears, tail, legs/feet/paws, arms, wings (flippers too), fins, tentacles, head
  and beak (see `Animate.luau`). An animal that's all head (the Octopus) has its head renamed to Body at install,
  so it doesn't nod away from its tentacles.
- The generator doesn't always face the animal forward. If it shows its side or back, set its turn in the install
  script (the Goldfish and the Parrot both needed 180). "(turn N)" in the table below is that number.
- Roblox's content check sometimes refuses a harmless prompt ("Moderation failed"). The first Pig prompt ("piglet",
  "pink snout") was refused; rewording it ("farm pig", "round snout") went through. The first Gorilla ("baby
  gorilla", "big strong arms with knuckles") was refused too; "jungle gorilla plush toy figure" went through.
- The generator allows 8 parts at most, so four-legged animals with ears and a tail use one "back legs" part.

| Tier | Animal | Look | Parts | Size (x, y, z) |
|---|---|---|---|---|
| 1 | Hamster | round orange body, cream belly, puffy cream cheeks, small round pink ears, tiny pink nose, little pink paws, short stubby legs | body, head, left ear, right ear, left front paw, right front paw, left foot, right foot | 3, 3, 3 |
| 1 | Bunny | **sitting upright like a collectible toy figure**: round white body sitting on the ground, big round head on top, two long upright ears with pink insides, tiny pink nose, small smile, pink blush cheeks, small front paws held together on its chest, big back feet flat on the ground in front, fluffy cotton-ball tail | body, head, left ear, right ear, tail, left foot, right foot | 2.6, 3.6, 2.6 |
| 1 | Hedgehog | soft rounded brown cartoon quills, cream face and belly, small round ears, black button nose, pink blush | body, head, quills, left ear, right ear, left foot, right foot | 2.6, 2.4, 2.8 |
| 1 | Goldfish | **like a collectible toy figure**: round plump bright orange body, white belly, big flowing fan tail, small rounded fins, small happy open mouth, pink blush cheeks, no realistic scales | body, tail, top fin, left fin, right fin | 2.4, 2.4, 3.2 (turn 180) |
| 1 | Parrot | **standing like a collectible toy figure**: round chubby bright green body, big round head, yellow curved beak, little red tuft on top, blue wings folded at its sides, short red and blue tail, pink blush cheeks, small orange feet, no realistic feathers | body, head, beak, left wing, right wing, tail, left foot, right foot | 2.6, 3.4, 2.6 (turn 180) |
| 2 | Chicken | **standing like a collectible toy figure**: round plump white body, big round head, red comb on top and a little red wattle, small yellow-orange beak, small white wings folded at its sides, short fluffy white tail, pink blush cheeks, small orange feet, no realistic feathers | body, head, beak, left wing, right wing, tail, left foot, right foot | 2.6, 3.2, 2.6 |
| 2 | Goat | baby goat **standing on four legs like a collectible toy figure**: round chubby cream-white body, big round head with two small curved tan horns, floppy ears, tiny tuft beard, pink nose, pink blush cheeks, short chunky legs with little dark hooves, short perky tail | body, head, left ear, right ear, front left leg, front right leg, back left leg, back right leg | 2.8, 3.4, 4 |
| 2 | Pig | **farm pig** standing on four legs like a collectible toy figure: round light pink body, big round head with a big round snout, small floppy triangle ears, rosy cheeks, happy smile, short stubby legs with little hooves, curly tail (no "no realistic ..." ending) | body, head, left ear, right ear, tail, front left leg, front right leg, back legs | 2.8, 3, 3.6 |
| 2 | Skunk | **standing on four legs like a collectible toy figure**: round black body with a white stripe down its back, big round black head with a white forehead stripe, small round ears, tiny pink nose, pink blush cheeks, short stubby legs, huge fluffy black-and-white tail curling up over its back | body, head, tail, left ear, right ear, front left leg, front right leg, back legs | 2.8, 3.6, 4 |
| 3 | Monkey | **standing like a collectible toy figure**: round brown body with a tan belly, big round brown head with a tan heart-shaped face, big round ears with tan insides, cheeky smile, pink blush cheeks, short arms, short stubby legs, long curly tail | body, head, left ear, right ear, tail, left arm, right arm, legs | 3, 3.4, 2.6 |
| 3 | Kangaroo | **standing upright like a collectible toy figure**: round tan-orange body with a cream belly and a little front pouch, big round head, two tall upright ears with pink insides, small dark nose, pink blush cheeks, tiny short arms, big long back feet flat on the ground, thick tail resting behind | body, head, left ear, right ear, tail, arms, left foot, right foot | 2.8, 3.8, 3.4 |
| 3 | Raccoon | **standing on four legs like a collectible toy figure**: round grey body with a light grey belly, big round grey head with a black eye mask and a white muzzle, small round ears with white tips, tiny black nose, pink blush cheeks, short stubby dark legs, big fluffy tail with black and grey rings | body, head, tail, left ear, right ear, front left leg, front right leg, back legs | 2.8, 3.2, 4 |
| 3 | Penguin | **standing like a collectible toy figure**: round plump body, black back and head with a white belly and white face, small orange beak, pink blush cheeks, little black flippers at its sides, small orange feet, tiny tail, no realistic feathers | body, head, beak, left wing, right wing, tail, left foot, right foot | 2.6, 3.2, 2.4 |
| 3 | Octopus | **like a collectible toy figure**: big round soft purple head, small happy smile, pink blush cheeks, a few lighter purple spots, eight short chunky curled tentacles spread around its base so it sits on them (no "no realistic ..." ending) | head (installed as Body), front left tentacles, front right tentacles, back left tentacles, back right tentacles | 3.4, 3, 3.4 |
| 4 | Crocodile | baby crocodile **standing on four short legs like a collectible toy figure** (it came out standing up, which suits the set): round plump green body, light yellow-green belly, big round head with a short wide rounded snout and a friendly toothy grin with a few small blunt white teeth, bumpy eyes on top, pink blush cheeks, rounded bumps along its back, short stubby legs, thick tail, no realistic scales | body, head, tail, front left leg, front right leg, back left leg, back right leg | 3, 2.8, 5 (8,000 triangles) |
| 4 | Gorilla | **jungle gorilla plush toy figure sitting upright**: round slate grey body, light grey tummy, big round head with a light grey face, small round ears, friendly smile, rosy cheeks, long arms with big round hands resting on the ground, short stubby legs (no "no realistic ..." ending) | body, head, left ear, right ear, left arm, right arm, left leg, right leg | 3.6, 3.6, 3 (8,000 triangles) |
| 4 | Bear | bear cub **standing on four legs like a collectible toy figure**: round plump brown body, big round head with a light tan muzzle, small round ears, small black nose, pink blush cheeks, happy smile, short chunky legs with big round paws, no realistic fur | body, head, left ear, right ear, front left leg, front right leg, back left leg, back right leg | 3.2, 3.4, 4.2 (8,000 triangles) |
| 4 | Tiger | tiger cub: big round head, orange with bold black stripes, white muzzle and chest, round ears with white insides, cheeky grin, big paws, striped tail curling up | body, head, tail, front left leg, front right leg, back left leg, back right leg | 3, 3.6, 5 |

## Installing a generated animal

The generator drops the model into Workspace, named after its prompt. In Studio (or by the agent), the install step:
1. moves the old model from `ReplicatedStorage > AnimalModels > <Id>` to `ServerStorage > OldAnimalModels` (backup)
2. renames the parts to clean names (Body, Head, LeftEar...), anchors them, turns off collisions and queries
3. turns it to face forward if it needs it (the "turn" number), then sets the Body as PrimaryPart with the pivot
   flat at the bottom centre of all its parts
4. renames the model to the animal's Id and moves it into `AnimalModels`

The model gets a `Generated` attribute. That tells `Animate.luau` to move its parts: ears twitch, tails wag,
legs and feet paddle while it runs, arms swing, wings flap, fins sway, tentacles wave, and the head (with its ears
and beak) nods.

The game then uses it everywhere (wild animals, the BOX screen, the Pen icons). `ModelFit.Paint` leaves textured parts
alone, so the old colour files in `src/shared/ArtColors/` don't tint them.
