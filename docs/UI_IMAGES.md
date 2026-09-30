# 2D images for the UI

Every button and icon in the game reads its picture from `src/shared/Config/Icons.luau`. Until you paste in
an image id there, the game shows an emoji, so you can add these one at a time, in any order.

## Style (so they all match)
- **512 × 512 PNG with a transparent background.** One object, centered, filling about 80% of the square.
- **Thick dark outline** (about 14–18 px at 512, near-black like #19161E) around the whole shape.
- **Bright, saturated flat colors** with one soft highlight on the top-left and a slightly darker shade on
  the bottom-right. Cartoony, chunky shapes, like the icons in popular simulators.
- **No text in the images.** The labels (PEN, SHOP...) are added by the game.
- Buttons sit on colored tiles (green PEN, orange SHOP, purple ORDERS, gold STORE, grey SETTINGS, blue
  INVITE, pink INVENTORY), so icons should read well on those colors.

## How to add one
1. Creator Dashboard → **Development Items → Decals** → upload the PNG.
2. Copy its asset id (the number in the page address, or right-click it in Studio's Toolbox → Copy Asset ID).
3. In `src/shared/Config/Icons.luau`, paste it into that icon's line: `Image = "rbxassetid://123456"`.

## The list
Priority: **A** = seen all the time, do these first. **B** = in menus. **C** = nice to have.

### Side buttons (A)
| Key | Picture | Where |
|---|---|---|
| `Button_Pen` | a hamster face peeking over a fence | PEN button (pick an animal) |
| `Button_Shop` | a striped shop awning / roll of tape | SHOP button |
| `Button_Orders` | a clipboard with a letter and a red wax seal | ORDERS button (Gruff's orders and quests) |
| `Button_Inventory` | a backpack stuffed with parcels | INVENTORY button |
| `Button_Store` | a shopping bag with a gift bow | STORE button (Robux) |
| `Button_Upgrades` | a big shiny blue diamond with an up arrow | UPGRADES button (diamond upgrades) |
| `Button_Settings` | a gear | SETTINGS button |
| `Button_Invite` | a waving hand / two friends | INVITE button |

### HUD icons (A)
| Key | Picture | Where |
|---|---|---|
| `Hud_Coins` | a bag or stack of gold coins | next to your coins |
| `Hud_Bag` | a taped cardboard parcel | next to your bag count (0/3) |
| `Hud_Boost` | a lightning bolt | coin boost line |
| `Hud_Level` | a gold star badge | level and XP bar |
| `Hud_Quest` | a scroll with an exclamation mark | quest tracker |
| `Hud_Lock` | a padlock | locked zones and items |
| `Hud_Diamonds` | a blue diamond | diamond counter |
| `Hud_ServerBoost` | a rocket | server boost timer |
| `Gruff_Portrait` | Postmaster Gruff's grumpy face (walrus, mustache, blue cap) in a circle | tutorial panel, Gruff's popups |

### Troll items (B)
| Key | Picture |
|---|---|
| `Troll_BananaPeel` | a banana peel |
| `Troll_StinkBomb` | a green stinky cloud with a fuse |
| `Troll_GluePuddle` | a glue bottle with a drip |
| `Troll_TapeBomb` | a round bomb wrapped in tape |
| `Troll_AirHorn` | an air horn |

### Mail boxes, stamps, tools, chutes (B)
| Key | Picture |
|---|---|
| `Box_Cardboard`, `Box_Wood`, `Box_Steel`, `Box_Vault` | cardboard box, wooden crate, steel crate, bank vault |
| `Stamp_Fragile`, `Stamp_Express`, `Stamp_Priority` | red FRAGILE-style stamp (cracked egg), blue EXPRESS (lightning), orange PRIORITY (flame). Draw the stamp shape, no words |
| `Tool_Gloves`, `Tool_Sneakers`, `Tool_TapeGun`, `Tool_Net`, `Tool_MailBag` | grabbing gloves, sneakers, tape gun, butterfly net, mail bag |
| `Chute_Basic`, `Chute_Express`, `Chute_Pneumatic`, `Chute_Rocket` | the four mail chutes |

### Store (B)
| Key | Picture |
|---|---|
| `Store_ServerBoost` | a rocket with "2x" coins trailing behind it |
| `Store_DiamondsSmall`, `Store_DiamondsMedium`, `Store_DiamondsLarge` | a few diamonds, a pouch of diamonds, an open chest of diamonds |
| `Store_BigBag` | big overstuffed mail bag |
| `Store_VIP` | gold crown |
| `Store_CoinsSmall`, `Store_CoinsMedium`, `Store_CoinsLarge` | a sack, a crate and a vault of coins |
| `Store_UnlockNext` | an open padlock with a paw print |
| `Store_PriorityStamps` | a stack of orange stamps |
| `Store_GruffCoffee` | a coffee mug with a walrus mustache |

### Diamond upgrades (B)
| Key | Picture |
|---|---|
| `Upgrade_GoldenPaws` | a golden paw print |
| `Upgrade_QuickStudy` | a stack of books with a star |
| `Upgrade_DeepPockets` | jeans with a bulging pocket |
| `Upgrade_CalmHands` | an open hand with little calm hearts |
| `Upgrade_PayRaise` | a paycheck envelope with an up arrow |
| `Upgrade_BusyDesk` | a clipboard with a checklist |
| `Upgrade_RebirthKit` | a toolbox with a circular "rebirth" arrow |

### Zones (C)
| Key | Picture |
|---|---|
| `Zone_Backyard`, `Zone_Barn`, `Zone_Jungle`, `Zone_IceRink`, `Zone_Rooftop` | a little scene badge for each: house and lawn, red barn, jungle leaves and waterfall, ice rink with snowflake, city rooftop |

### Animal portraits (C, 26)
Head-and-shoulders portraits, facing the viewer, same framing for all:
`Animal_Hamster`, `Animal_Bunny`, `Animal_Goldfish`, `Animal_Hedgehog`, `Animal_Parrot`, `Animal_Chicken`,
`Animal_Goat`, `Animal_Pig`, `Animal_Skunk`, `Animal_Monkey`, `Animal_Kangaroo`, `Animal_Porcupine`,
`Animal_Penguin`, `Animal_Octopus`, `Animal_Crocodile`, `Animal_Gorilla`, `Animal_Bear`, `Animal_Tiger`,
`Animal_Giraffe`, `Animal_Elephant`, `Animal_Whale`, `Animal_Yeti`, `Animal_Dragon`, `Animal_Alien`,
`Animal_Unicorn`, `Animal_Gruff`.

Tip: you can render these from the Blender models (same camera for all, flat lighting, thick outline via
Blender's Freestyle or a solidify-flipped-normals outline) so they match the 3D animals exactly.
