--!strict
-- Client entry point. Runs on each player's own device.
-- Clients handle what the player sees and presses: UI, camera, input, effects.

local Players = game:GetService("Players")

local Effects = require(script.Effects)
local Hud = require(script.Hud)
local BoxingScreen = require(script.BoxingScreen)
local ChuteVisual = require(script.ChuteVisual)
local Movement = require(script.Movement)
local OrdersBoard = require(script.OrdersBoard)
local PenMenu = require(script.PenMenu)
local Shop = require(script.Shop)

Hud.Start()
PenMenu.Start()
Shop.Start()
OrdersBoard.Start()
BoxingScreen.Start()
Effects.Start()
Movement.Start()
task.spawn(ChuteVisual.Start) -- waits for the map to load, so it runs on its own

print(`[Mail a Tiger] Client started for {Players.LocalPlayer.Name}.`)
