--!strict
-- Client entry point. Runs on each player's own device.
-- Clients handle what the player sees and presses: UI, camera, input, effects.

local Players = game:GetService("Players")

local Effects = require(script.Effects)
local Hud = require(script.Hud)
local BoxingScreen = require(script.BoxingScreen)
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

print(`[Mail a Tiger] Client started for {Players.LocalPlayer.Name}.`)
