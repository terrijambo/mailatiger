--!strict
-- Server entry point. Runs once when a server starts.
-- Server scripts own the truth: coins, boxing progress, payouts, saves. Players can't tamper with them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BoxingService = require(script.BoxingService)
local DataService = require(script.DataService)
local Economy = require(script.Economy)
local MapBuilder = require(script.MapBuilder)
local ShopService = require(script.ShopService)

local map = MapBuilder.Build()

-- Everything that listens for "a player's save finished loading" connects first...
Economy.Start()
ShopService.Start(map)
BoxingService.Start(map)
-- ...then we start loading saves.
DataService.Start()

print(`[Mail a Tiger] Server started. {#Config.Animals.List} animals loaded.`)
