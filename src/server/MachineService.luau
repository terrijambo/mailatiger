--!strict
-- The Post Office machines and the chute's income (rules and numbers: Config/Machines.luau).
--   * Buy a machine (Supply Shop > Machines, or at the machine itself) once your chute level reaches it.
--     Machines multiply the XP of every parcel you mail (ProgressionService asks Economy.MachineXPMult).
--   * Every few seconds the chute pays you your coins-per-minute share (Economy.ChuteRate).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local MapBuilder = require(script.Parent.MapBuilder)
local Remotes = require(script.Parent.Remotes)

local Machines = Config.Machines

local MachineService = {}

local function say(player: Player, text: string)
	Remotes.Notify:FireClient(player, "Message", { Speaker = "Postmaster Gruff", Text = text })
end

-- Buys a machine. Returns whether it worked (and tells the player why not).
function MachineService.Buy(player: Player, machineId: string): boolean
	local profile = DataService.Get(player)
	local machine = Machines.ById[machineId]
	if not profile or not machine or profile.Machines[machineId] then
		return false
	end
	if profile.Level < machine.Level then
		say(player, `The {machine.DisplayName} needs a Level {machine.Level} chute. Keep mailing!`)
		return false
	end
	local price = Machines.Price(machine)
	if not Economy.TrySpend(player, price, `Machine_{machineId}`) then
		say(player, `The {machine.DisplayName} costs {Format.Short(price)} coins.`)
		return false
	end
	profile.Machines[machineId] = true
	Analytics.Custom(player, `Machine_{machineId}`, profile.Level)
	Remotes.Notify:FireClient(player, "MachineBought", {
		Id = machineId,
		XPMult = Machines.XPMult(profile.Machines),
	})
	say(
		player,
		`{machine.Emoji} {machine.DisplayName} installed! Every parcel now gives x{Machines.XPMult(profile.Machines)} XP.`
	)
	Economy.Sync(player)
	return true
end

function MachineService.Start(map: MapBuilder.Map)
	-- Hold E at a machine in the Mail Room to buy it (the client changes what its prompt says for you)
	for machineId, station in map.MailRoom.Stations do
		local buy = station:FindFirstChild("BuyPrompt") :: ProximityPrompt?
		if buy then
			buy.Triggered:Connect(function(player: Player)
				MachineService.Buy(player, machineId)
			end)
		end
	end

	-- The chute pays out in small chunks every few seconds (so the coins keep ticking up)
	task.spawn(function()
		local every = Machines.PayEverySeconds
		while true do
			task.wait(every)
			for player in DataService.GetAll() do
				local coins = math.floor(Economy.ChuteRate(player) * every / 60)
				if coins > 0 then
					Economy.AddCoins(player, coins, "Chute")
				end
			end
		end
	end)
end

return MachineService
