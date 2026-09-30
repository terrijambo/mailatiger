--!strict
-- Client entry point. Runs on each player's own device.
-- Clients handle what the player sees and presses: UI, camera, input, effects.

local Players = game:GetService("Players")

local Animate = require(script.Animate)
local Audio = require(script.Audio)
local Effects = require(script.Effects)
local Hud = require(script.Hud)
local Inventory = require(script.Inventory)
local BoxingScreen = require(script.BoxingScreen)
local DiamondUpgrades = require(script.DiamondUpgrades)
local ChuteVisual = require(script.ChuteVisual)
local Movement = require(script.Movement)
local Music = require(script.Music)
local OrdersBoard = require(script.OrdersBoard)
local PenMenu = require(script.PenMenu)
local Settings = require(script.Settings)
local SideButtons = require(script.SideButtons)
local Shop = require(script.Shop)
local Store = require(script.Store)
local TrollBar = require(script.TrollBar)
local Tutorial = require(script.Tutorial)
local ZoneLocks = require(script.ZoneLocks)

Hud.Start()
PenMenu.Start()
Shop.Start()
Store.Start()
Settings.Start()
OrdersBoard.Start()
Inventory.Start()
DiamondUpgrades.Start()
SideButtons.Start() -- after the windows it opens
BoxingScreen.Start()
Effects.Start()
Movement.Start()
Animate.Start()
Audio.Start()
Music.Start()
ZoneLocks.Start()
TrollBar.Start()
task.spawn(ChuteVisual.Start) -- waits for the map to load, so it runs on its own
task.spawn(Tutorial.Start) -- waits for your save to load

print(`[Mail a Tiger] Client started for {Players.LocalPlayer.Name}.`)
