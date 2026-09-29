# Roblox Crash Course (for Mail a Tiger)

This covers only what you need before Phase 1. Read it top to bottom once, and try each ✋ exercise in Studio.

---

## 1. Everything is an Instance in a tree
Everything in a Roblox game is an **Instance**: a part, a script, a sound, a GUI. Instances sit inside each other like folders. Studio's **Explorer** window shows the tree.

The important top-level containers:
| Container | Who sees it | We use it for |
|---|---|---|
| `Workspace` | Everyone, rendered in 3D | The map, boxes, animals |
| `ReplicatedStorage` | Server + all clients | Shared code (`Shared/Config`) |
| `ServerScriptService` | Server only | Trusted game logic |
| `StarterPlayer.StarterPlayerScripts` | Copied to each player | Client code |

✋ In Studio, insert a Part (**Home → Part**). Find it in Explorer under Workspace. In **Properties**, change `Color`, `Size` and `Anchored`. Press Play: unanchored parts fall, and anchored ones stay put.

## 2. Server vs. Client
A Roblox game runs on **one server** and **one client per player**.
- **The server** is the boss. It decides coins, box HP and whether a delivery counts. Exploiters can't touch it.
- **Clients** are players' devices. They draw the screen, read the keyboard and play effects. Exploiters **can** change anything on their own client.

**Golden rule:** never trust the client with anything that matters. The client can say "I'd like to deliver this box." The server checks whether they're actually at the Post Office and whether the box is intact, and only then pays.

| File name | Runs on |
|---|---|
| `something.server.luau` | Server (a `Script`) |
| `something.client.luau` | Client (a `LocalScript`) |
| `something.luau` | Nowhere by itself. It's a **ModuleScript** other scripts `require` |

## 3. ModuleScripts: sharing code
A ModuleScript returns a value, usually a table. Other scripts `require` it to use it.

```lua
-- src/shared/Config/Boxes.luau returns a table of boxes
local Config = require(game.ReplicatedStorage.Shared.Config)
print(Config.Boxes.ById.Cardboard.MaxHP) --> 100
```
Mail a Tiger keeps **every tunable number** in `src/shared/Config/`, so balancing the game never means digging through gameplay code.

## 4. RemoteEvents: server ↔ client messages
Server and client can't call each other's functions directly. They send messages through **RemoteEvents**.

```lua
-- Client: "I pressed E to deliver"
DeliverRemote:FireServer()

-- Server: checks everything before paying
DeliverRemote.OnServerEvent:Connect(function(player)
	if isNearPostOffice(player) and boxIsIntact(player) then
		giveCoins(player, payout)
	end
end)

-- Server → one client: "show the delivery receipt"
ReceiptRemote:FireClient(player, stars, coins)
```

## 5. Luau basics you'll see constantly
```lua
local coins = 0                         -- variable
local animal = { Name = "Hamster", Value = 5 }  -- table (like an object)
print(animal.Name)                      -- "Hamster"

local function payout(base: number, mult: number): number  -- function with types
	return base * mult
end

for _, a in Config.Animals.List do      -- loop over a list
	print(a.DisplayName)
end

if coins >= 50 then ... elseif ... else ... end

part.Touched:Connect(function(hit)      -- events: run code when something happens
	print(hit.Name, "touched the part")
end)

task.wait(1)                            -- pause this code for 1 second
print(`You have {coins} coins`)         -- string interpolation (backticks)
```

## 6. How the boxing game uses these ideas
- **The arena animal** is an *anchored* part. The server moves it a little every frame (`Heartbeat`) by setting its `CFrame`, so it goes exactly where the AI says: flee, dodge, hop. See `src/server/CatchAI.luau`.
- **Grabbing** uses a **ProximityPrompt** (the "hold E" popup). Its `HoldDuration` is longer for harder animals.
- **Stuff and Tape** are screens on the client (`src/client/Minigames.luau`), but the client only *sends button presses* through a RemoteEvent. The server decides hit or miss (golden rule from §2!).
- **Synced clock:** `Workspace:GetServerTimeNow()` gives the same time on the server and every client. The Stuff bar is drawn from it, and the server judges your press with it, so what you see is what's judged.
- **State machine:** each player's job is in one stage at a time (`"Catch"` → `"Stuff"` → `"Tape"`), stored on the player as the `Stage` attribute so the UI knows what to show.

## 7. Testing
- **Play** (F5): you in the game, with server and client in one window.
- **Test → Clients and Servers → 2 players**: opens a real server plus two player windows. Use this for co-op and to check players don't interfere with each other.
- **Output window** (View → Output): shows `print` messages and errors. When you connect Rojo and press Play, you should see:
  ```
  [Mail a Tiger] Server started. 26 animals loaded.
  [Mail a Tiger] Client started for <your name>.
  ```

✋ **Phase 0 checkpoint:** follow the README's Daily workflow, press Play, and confirm both lines appear in Output. If you see them, Phase 0 is done.

## 8. Glossary
- **Humanoid**: the object that makes a character walk, jump and have health. `WalkSpeed` lives here, and we'll lower it for heavy boxes.
- **CFrame**: a position plus a rotation. It's how you move or rotate things in code.
- **DataStore**: Roblox's save system (Phase 3).
- **Attribute**: a custom value you stick on any Instance, like `box:SetAttribute("HP", 100)`. Easy and visible in Properties.
