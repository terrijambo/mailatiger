-- Server entry point. Runs once when a server starts.
-- Server scripts own the truth: coins, box HP, deliveries. Players can't tamper with them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

print(`[Mail a Tiger] Server started. {#Config.Animals.List} animals loaded.`)
