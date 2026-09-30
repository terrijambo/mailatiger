--!strict
-- Server entry point. Runs once when a server starts.
-- Server scripts own the truth: coins, boxing progress, payouts, saves. Players can't tamper with them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BoxingService = require(script.BoxingService)
local CodesService = require(script.CodesService)
local DataService = require(script.DataService)
local Economy = require(script.Economy)
local LeaderboardService = require(script.LeaderboardService)
local Look = require(script.Look)
local MailService = require(script.MailService)
local MapBuilder = require(script.MapBuilder)
local MonetizationService = require(script.MonetizationService)
local PaycheckService = require(script.PaycheckService)
local ShopService = require(script.ShopService)
local Travel = require(script.Travel)
local TutorialService = require(script.TutorialService)

Look.Apply()
local map = MapBuilder.Build()
Travel.Start(map)

-- Everything that listens for "a player's save finished loading" connects first...
Economy.Start()
ShopService.Start(map)
BoxingService.Start(map)
MailService.Start(map)
TutorialService.Start()
CodesService.Start()
MonetizationService.Start()
PaycheckService.Start()
-- ...then we start loading saves.
DataService.Start()
-- Leaderboards need to know whether DataStores work, so they start last.
LeaderboardService.Start(map)

print(`[Mail a Tiger] Server started. {#Config.Animals.List} animals loaded.`)
