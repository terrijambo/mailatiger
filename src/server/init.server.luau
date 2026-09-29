--!strict
-- Server entry point. Runs once when a server starts.
-- Server scripts own the truth: coins, boxing progress, payouts. Players can't tamper with them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BoxingService = require(script.BoxingService)
local Economy = require(script.Economy)
local MapBuilder = require(script.MapBuilder)

local map = MapBuilder.Build()
Economy.Start()
BoxingService.Start(map)

print(`[Mail a Tiger] Server started. {#Config.Animals.List} animals loaded.`)
