--!strict
-- Client entry point. Runs on each player's own device.
-- Clients handle what the player sees and presses: UI, camera, input, effects.

local Players = game:GetService("Players")

local Effects = require(script.Effects)
local Hud = require(script.Hud)
local Minigames = require(script.Minigames)
local PenMenu = require(script.PenMenu)

Hud.Start()
PenMenu.Start()
Minigames.Start()
Effects.Start()

print(`[Mail a Tiger] Client started for {Players.LocalPlayer.Name}.`)
