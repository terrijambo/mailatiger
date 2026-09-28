--!strict
-- Client entry point. Runs on each player's own device.
-- Clients handle what the player sees and presses: UI, camera, input, effects.

local Players = game:GetService("Players")

local BoxEffects = require(script.BoxEffects)
local Hud = require(script.Hud)

Hud.Start()
BoxEffects.Start()

print(`[Mail a Tiger] Client started for {Players.LocalPlayer.Name}.`)
