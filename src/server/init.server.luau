--!strict
-- Server entry point. Runs once when a server starts.
-- Server scripts own the truth: coins, box HP, deliveries. Players can't tamper with them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BoxService = require(script.BoxService)
local Economy = require(script.Economy)
local MapBuilder = require(script.MapBuilder)

local map = MapBuilder.Build()
Economy.Start()
BoxService.Start(map)

print(`[Mail a Tiger] Server started. {#Config.Animals.List} animals loaded.`)
