# Model List

Every 3D model Mail a Tiger needs, by category. Each one is built by a script in `art/blender_scripts/`,
and outputs `art/models/<Name>.blend`, `art/export/<Name>.fbx`, `art/previews/<Name>.png` and
`src/shared/ArtColors/<Name>.json` (the colors the game paints on after import).

**Hooked into the game** means the game already swaps the model in automatically when it's imported into
the right folder in Studio. The rest are built and ready, and get hooked up as the graybox map is replaced
(each one replaces a specific placeholder, listed in "Replaces").

## 1. Animals (25) → `ReplicatedStorage > AnimalModels`, hooked into the game
Named by animal Id. Used running around the arena and poking out of the box.

| Tier | Model | Script | Look |
|---|---|---|---|
| 1 | Hamster | `hamster.py` | Round orange fluffball, cream belly and cheeks |
| 1 | Bunny | `animals.py` | White, long pink-lined ears, cotton tail |
| 1 | Goldfish | `animals.py` | Orange fish in a see-through bowl of water |
| 1 | Hedgehog | `animals.py` | Brown spiky back, cream face |
| 1 | Parrot | `animals.py` | Green body, blue wings, red tail, yellow beak |
| 2 | Chicken | `animals.py` | White hen, red comb and wattle, orange legs |
| 2 | Goat | `animals.py` | Beige, curved horns, little beard |
| 2 | Pig | `animals.py` | Pink, round snout, curly tail |
| 2 | Skunk | `animals.py` | Black with a white stripe and a huge bushy tail |
| 3 | Monkey | `animals.py` | Brown with tan face, long arms, curly tail |
| 3 | Kangaroo | `animals.py` | Big feet, thick tail, belly pouch |
| 3 | Porcupine | `animals.py` | Long cream-tipped quills |
| 3 | Penguin | `animals.py` | Black and white, orange beak and feet |
| 3 | Octopus | `animals.py` | Purple head, big eyes, eight curling tentacles |
| 4 | Crocodile | `animals.py` | Long and low, toothy snout, ridged back |
| 4 | Gorilla | `animals.py` | Huge arms, grey face and chest |
| 4 | Bear | `animals.py` | Brown, round ears, tan muzzle |
| 4 | Tiger | `animals.py` | Orange with black stripes, white muzzle |
| 5 | Giraffe | `animals.py` | Long neck and legs, brown spots |
| 5 | Elephant | `animals.py` | Big ears, trunk, tusks |
| 5 | Whale | `animals.py` | Blue with pale belly, tail flukes, water spout |
| 6 | Yeti | `animals.py` | Shaggy white, blue face |
| 6 | Dragon | `animals.py` | Red with wings, horns and back spikes |
| 6 | Alien | `animals.py` | Green, huge black eyes, antennae |
| 6 | Unicorn | `animals.py` | White with a gold horn and rainbow mane |

(Postmaster Gruff is also a tier-6 animal. He uses the character model below, `Gruff`.)

## 2. Boxes (4) → `ReplicatedStorage > BoxModels`, hooked into the game
Named by box Id. Open-topped so the animal can poke out.

| Model | Script | Look |
|---|---|---|
| Cardboard | `cardboard_box.py` | Open cardboard box, four flaps folded out |
| Wood | `boxes.py` | Wooden crate with planks and corner posts |
| Steel | `boxes.py` | Grey metal crate with bands and rivets |
| Vault | `boxes.py` | Dark bank vault with a thick rim, lid open, and a wheel handle |

## 3. Characters (2)
| Model | Script | Look | Replaces |
|---|---|---|---|
| Gruff | `characters.py` | Postmaster Gruff: grumpy walrus, huge mustache, tusks, postal jacket | The grey ball behind the counter, and the Gruff animal (**hooked** via `AnimalModels > Gruff`) |
| GruffHat | `characters.py` | His tiny blue postal cap with a gold badge (separate so a breakout can knock it off) | The blue hat block |
| BossCrown | `characters.py` | A gold crown with five pearl-tipped points, red velvet, a red gem in front and two blue ones; worn by the top helper of each hourly boss fight | A crown built from plain parts |

Players use their own Roblox avatars, so there's no player model.

## 4. Town / Hub (13)
| Model | Script | Look | Replaces |
|---|---|---|---|
| PostOffice | `town.py` | Red-brick post office with a blue roof, sign, windows and a door | Post office wall + roof blocks |
| PostCounter | `town.py` | Wooden service counter with a bell and letter trays | Counter block |
| MailChute | `town.py` | Big blue mail chute with a slot and an arrow | Mail chute block |
| PenCounter | `town.py` | Animal Pen stall: counter, little fence and a sloped roof | Pen counter block |
| ShopStall | `town.py` | Supply Shop stall with a striped awning and crates of tape | Shop counter block |
| OrdersBoard | `town.py` | Cork board on posts with pinned order slips | Orders board block |
| LeaderboardStand | `town.py` | Tall framed board with a gold trophy on top (the game draws the scores on its face) | Leaderboard blocks |
| TravelPad | `town.py` | Round stone pad with a glowing ring (the game recolors the ring per arena) | Travel pads + return pads |
| SpawnPad | `town.py` | Round blue pad with a mail-stamp emblem | Spawn location |
| Lamppost | `town.py` | Old-style street lamp | New decoration |
| Bench | `town.py` | Park bench | New decoration |
| Mailbox | `town.py` | Classic blue street mailbox | New decoration |
| Planter | `town.py` | Square planter with flowers | New decoration |

## 5. Arena props (19)
| Arena | Model | Script | Look | Replaces |
|---|---|---|---|---|
| All | ArenaGate | `arenas.py` | Stone posts and a sign board (the game writes the arena name on it) | Gate posts + sign |
| Backyard | PicketFence | `arenas.py` | White picket fence section (tiles along the edge) | Backyard fence |
| Backyard | Bush | `arenas.py` | Round leafy bush | Bush balls |
| Backyard | Doghouse | `arenas.py` | Little red doghouse | New decoration |
| Backyard | Flowerbed | `arenas.py` | Wooden bed of flowers | New decoration |
| Barn | Barn | `arenas.py` | Big red barn with white trim and hay-loft door | Barn wall + roof |
| Barn | HayBale | `arenas.py` | Square hay bale with twine | Hay bale blocks |
| Barn | FarmFence | `arenas.py` | Red rail fence section | Barn fence |
| Barn | Trough | `arenas.py` | Water trough | New decoration |
| Jungle | JungleTree | `arenas.py` | Curvy trunk, layered leafy canopy, hanging vines | Tree trunk + canopy |
| Jungle | MudPuddle | `arenas.py` | Flat, lumpy mud puddle | Mud pit blocks |
| Jungle | BambooFence | `arenas.py` | Bamboo fence section | Jungle fence |
| Jungle | Rock | `arenas.py` | Mossy boulder | New decoration |
| Ice Rink | RinkBoard | `arenas.py` | White rink wall section with a blue stripe | Rink fence |
| Ice Rink | HockeyGoal | `arenas.py` | Red goal frame with a net | Goal blocks |
| Ice Rink | Snowman | `arenas.py` | Three-ball snowman with a carrot nose | New decoration |
| Rooftop | ACUnit | `arenas.py` | Rooftop air-conditioner with a fan grille | AC unit blocks |
| Rooftop | WaterTower | `arenas.py` | Wooden water tower on legs | New decoration |
| Rooftop | Chimney | `arenas.py` | Brick chimney | New decoration |

## 6. Gameplay props (5)
| Model | Script | Look | Used for |
|---|---|---|---|
| Egg | `props.py` | Chicken egg | Chicken's bonus eggs |
| TapeRoll | `props.py` | Roll of packing tape | Taping effects, shop display |
| RubberStamp | `props.py` | Gruff's big rubber stamp | Rating moment, decoration |
| Envelope | `props.py` | Letter with a stamp | Orders board, decoration |
| Parcel | `props.py` | Sealed, taped-up box with an address label and a FRAGILE sticker | The boxed animal you carry to the chute (inventory system, see below) |

## 6b. Mail chute upgrades (3)
For the planned **inventory + mail it yourself** system: taped boxes go into your inventory, you carry them to
your chute and mail them, and the chute can be upgraded. The basic chute is `MailChute` (Town).

| Model | Script | Look |
|---|---|---|
| MailChuteExpress | `chutes.py` | Bigger chute with a conveyor belt feeding it and hazard stripes |
| MailChutePneumatic | `chutes.py` | Glass suction tube shooting parcels up a pipe |
| MailChuteRocket | `chutes.py` | Launch pad with a parcel rocket and a countdown light |

## 7. Tools (4)
Shop display models for the Supply Shop tools.

| Model | Script | Look |
|---|---|---|
| GrabbingGloves | `props.py` | Pair of padded work gloves |
| Sneakers | `props.py` | Pair of sneakers |
| TapeGun | `props.py` | Packing-tape dispenser gun |
| ButterflyNet | `props.py` | Net on a long handle |

## Not 3D (so not in this list)
Stamps (FRAGILE / EXPRESS / PRIORITY), coins, the BOX screen and all menus are 2D UI. Particles and effects
are built in Roblox.

**Total: 75 models**: 25 animals (including the hamster), 4 boxes (including cardboard), 2 characters,
13 town, 19 arena props, 5 gameplay props, 3 chute upgrades and 4 tools.

## Scenery (15) → `ReplicatedStorage > MapModels`, hooked into the game
Built by `scenery.py`. Each replaces a block-built piece in `src/server/Scenery/` (the blocks stay as the fallback).

| Model | Look | Replaces |
|---|---|---|
| OakTree | Thick trunk with roots and branches, lumpy two-tone canopy | Most round trees (recolored per island) |
| BirchTree | Slim white trunk with dark marks, tall yellow-green canopy | About 1 in 5 town/backyard trees |
| PineTree | Five jagged needle tiers | Pines |
| SnowPine | The pine with snow on every tier | Ice Rink pines |
| PalmTree | Curved ringed trunk, eight drooping fronds, coconuts | Beach palms |
| Tractor | Red tractor, big yellow-hubbed wheels, glass cab, grille and lights | Barn tractor |
| Windmill | Tapered tower, red cap, four lattice sails with cloth | Barn windmill |
| Silo | Banded silo, red dome, ladder | Barn silo |
| Scarecrow | Patched shirt, straw hat, a crow on one arm | Barn scarecrow |
| Lighthouse | Red/white striped tower, railing, glowing lamp room (beam added by the game) | Beach lighthouse |
| Rowboat | Blue rowboat with seats and oars | Pier boat |
| Shipwreck | Broken leaning hull with ribs, snapped mast, torn sail | Beach shipwreck |
| TikiHut | Layered thatch with a fringe, bamboo counter, smoothies | Beach smoothie hut (the sign stays) |
| Igloo | Smooth snow dome with block seams, arched tunnel | Ice Rink igloo |
| Cottage | Timber-framed cottage, shingled roof, shutters, flower boxes, chimney | Town and Backyard cottages (recolored) |
